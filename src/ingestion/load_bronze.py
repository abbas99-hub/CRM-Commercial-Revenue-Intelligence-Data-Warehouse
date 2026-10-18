#!/usr/bin/env python3
"""Repeatable SQL Server Bronze CSV loader. Requires pyodbc and ODBC Driver 18 for SQL Server.

Example (PowerShell):
  $env:WAREHOUSE_SQL_CONNECTION='DRIVER={ODBC Driver 18 for SQL Server};SERVER=localhost;DATABASE=CommercialRevenueIntelligence;Trusted_Connection=yes;TrustServerCertificate=yes'
  python src/ingestion/load_bronze.py --source-dir C:\\data\\CRM_Data

The loader appends every run (no deduplication), validates headers, logs batch status,
row counts, timestamps and errors, and stores all source values as NVARCHAR(MAX).
"""
from __future__ import annotations
import argparse, csv, hashlib, json, os, sys, traceback
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / 'src' / 'ingestion' / 'source_manifest.json'
BATCH_SIZE = 1000

def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode('utf-8')).hexdigest()

def main() -> int:
    parser = argparse.ArgumentParser(description='Load source CSVs into SQL Server Bronze tables.')
    parser.add_argument('--source-dir', required=True, help='Folder containing the 11 source CSV files')
    parser.add_argument('--only', nargs='*', help='Optional entity names, e.g. Accounts Opportunities')
    parser.add_argument('--dry-run', action='store_true', help='Validate files and headers without connecting to SQL Server')
    parser.add_argument('--batch-size', type=int, default=BATCH_SIZE)
    args = parser.parse_args()
    source_dir = Path(args.source_dir)
    manifest = json.loads(MANIFEST_PATH.read_text(encoding='utf-8'))
    entities = args.only or list(manifest)
    unknown = sorted(set(entities) - set(manifest))
    if unknown: parser.error('Unknown entity/entities: ' + ', '.join(unknown))
    conn_str = os.getenv('WAREHOUSE_SQL_CONNECTION')
    if not args.dry_run and not conn_str:
        parser.error('Set WAREHOUSE_SQL_CONNECTION or use --dry-run.')
    try:
        import pyodbc
    except ImportError:
        if not args.dry_run:
            print('Missing dependency: pip install -r requirements.txt', file=sys.stderr); return 2
        pyodbc = None
    conn = None
    if not args.dry_run:
        conn = pyodbc.connect(conn_str, autocommit=False)
    overall_errors = 0
    try:
        for entity in entities:
            spec = manifest[entity]
            path = source_dir / spec['file']
            batch_id = None; rows_read = rows_loaded = 0; status = 'SUCCEEDED'; error_text = None
            if not path.is_file():
                print(f'ERROR {entity}: missing file {path}', file=sys.stderr); overall_errors += 1; continue
            try:
                with path.open('r', encoding=spec.get('encoding','utf-8-sig'), newline='') as f:
                    reader = csv.reader(f, delimiter=spec.get('delimiter', ','))
                    header = next(reader, None)
                    if header != spec['columns']:
                        raise ValueError(f'SCHEMA_DRIFT: expected headers {spec["columns"]}; got {header}')
                    header_hash = sha256_text('|'.join(header))
                    expected_header_hash = spec.get('expected_header_sha256')
                    if expected_header_hash and header_hash != expected_header_hash:
                        raise ValueError(f'SCHEMA_DRIFT: header hash mismatch for {entity}')
                    # First pass validates row width and counts source rows; preserves blanks as empty strings.
                    valid_rows = []
                    for row_num, row in enumerate(reader, start=2):
                        rows_read += 1
                        if len(row) != len(header):
                            raise ValueError(f'SCHEMA_DRIFT at source row {row_num}: expected {len(header)} fields, got {len(row)}')
                        valid_rows.append((row_num, row))
                if args.dry_run:
                    print(f'VALID {entity}: {rows_read:,} rows; header_sha256={header_hash}; no database changes')
                    continue
                cur = conn.cursor()
                out = cur.execute("DECLARE @id BIGINT; EXEC ctl.usp_StartIngestionBatch ?, ?, @id OUTPUT; SELECT @id;", 'CRM_CSV', path.name).fetchone()
                batch_id = int(out[0]); conn.commit()
                # Audit the file contract and source counts before inserting.
                cur.execute("""INSERT ctl.SourceFileAudit(IngestionBatchID,EntityName,SourcePath,SourceFileName,SourceFileSizeBytes,SourceLastWriteUtc,ExpectedHeaderHash,ActualHeaderHash,HeaderStatus,SourceRowCount,InsertedRowCount)
                               VALUES(?,?,?,?,?,?,?,?,?,?,0)""",
                            batch_id, entity, str(path.resolve()), path.name, path.stat().st_size,
                            datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).replace(tzinfo=None), expected_header_hash or header_hash, header_hash, 'MATCH', rows_read)
                colnames = spec['columns']
                sql_cols = ['IngestionBatchID','SourceFileName','SourceRowNumber'] + colnames
                quoted = ','.join('[' + c.replace(']', ']]') + ']' for c in sql_cols)
                placeholders = ','.join('?' for _ in sql_cols)
                insert_sql = f'INSERT INTO {spec["table"]} ({quoted}) VALUES ({placeholders})'
                cur.fast_executemany = True
                for start in range(0, len(valid_rows), max(1,args.batch_size)):
                    chunk = valid_rows[start:start+max(1,args.batch_size)]
                    payload = [(batch_id, path.name, rn, *[v if v != '' else None for v in row]) for rn,row in chunk]
                    if payload:
                        cur.executemany(insert_sql, payload); rows_loaded += len(payload)
                cur.execute("UPDATE ctl.SourceFileAudit SET InsertedRowCount=? WHERE IngestionBatchID=? AND EntityName=?", rows_loaded, batch_id, entity)
                cur.execute("EXEC ctl.usp_CompleteIngestionBatch ?, ?, ?, ?, ?, ?", batch_id, status, rows_read, rows_loaded, 0, None)
                conn.commit()
                print(f'{status} {entity}: batch={batch_id}, source={rows_read:,}, loaded={rows_loaded:,}')
            except Exception as exc:
                overall_errors += 1; status = 'FAILED'; error_text = str(exc)[:4000]
                if conn is not None:
                    try:
                        conn.rollback()
                        rows_loaded = 0
                        cur = conn.cursor()
                        if batch_id is not None:
                            cur.execute("INSERT ctl.IngestionError(IngestionBatchID,EntityName,SourceFileName,ErrorStage,ErrorMessage) VALUES(?,?,?,?,?)", batch_id, entity, path.name, 'CSV_LOAD', error_text)
                            cur.execute("EXEC ctl.usp_CompleteIngestionBatch ?, ?, ?, ?, ?, ?", batch_id, status, rows_read, rows_loaded, max(0,rows_read-rows_loaded), error_text)
                        else:
                            cur.execute("INSERT ctl.IngestionError(EntityName,SourceFileName,ErrorStage,ErrorMessage) VALUES(?,?,?,?)", entity, path.name, 'CSV_VALIDATE', error_text)
                        conn.commit()
                    except Exception:
                        conn.rollback()
                print(f'FAILED {entity}: {error_text}', file=sys.stderr)
        return 1 if overall_errors else 0
    finally:
        if conn is not None: conn.close()

if __name__ == '__main__':
    raise SystemExit(main())
