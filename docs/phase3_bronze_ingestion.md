# Phase 3 — Bronze ingestion

## Scope delivered
- SQL Server Bronze raw tables for 11 source entities. All business fields are `NVARCHAR(MAX)` to preserve raw input and defer type conversion to Silver.
- Per-row lineage: generated Bronze row ID, ingestion batch ID, source file, source row number and UTC ingestion timestamp.
- Batch lifecycle procedures and audit/error tables.
- Python CSV loader with configurable source directory, exact-header/schema-drift validation, field-count validation, row counts, batch logging, errors and dry-run mode.
- Append-only/repeatable semantics: each run adds a new batch; no deduplication, source mutation or silent overwrite.

## SQL execution order
1. `sql/00_admin/010_create_schemas.sql`
2. `sql/00_admin/020_create_control_tables.sql`
3. `sql/00_admin/030_ingestion_procedures.sql`
4. `sql/01_bronze/100_create_bronze_tables.sql`

Execute each script in SQL Server Management Studio or sqlcmd against the target database. The database itself must be created separately with your environment's naming and access standards.

## Run the loader
Install Python 3.10+ and ODBC Driver 18 for SQL Server, then `pip install -r requirements.txt`. Set `WAREHOUSE_SQL_CONNECTION` to a SQL Server connection string, and run:

```bash
python src/ingestion/load_bronze.py --source-dir "/path/to/CRM_Data" --dry-run
python src/ingestion/load_bronze.py --source-dir "/path/to/CRM_Data"
```

On PowerShell, set the connection string with `$env:WAREHOUSE_SQL_CONNECTION='DRIVER={ODBC Driver 18 for SQL Server};SERVER=localhost;DATABASE=CommercialRevenueIntelligence;Trusted_Connection=yes;TrustServerCertificate=yes'`. Replace server/database/authentication values for your environment.

Optional targeted load: `python src/ingestion/load_bronze.py --source-dir "/path/to/CRM_Data" --only Accounts Opportunities`.

## Logging and guarantees
- `ctl.IngestionBatch`: start/completion, status, rows read/loaded/rejected, error summary.
- `ctl.SourceFileAudit`: source path/name, file size/modified timestamp, expected/actual header hash, schema status, source count and inserted count.
- `ctl.IngestionError`: failure stage, message, entity/file and batch where available.
- `brz.*`: original values plus row-level lineage. Blank CSV fields are represented as SQL NULL in raw attributes; if strict empty-string preservation is required, change the loader to preserve empty strings before first production use.
