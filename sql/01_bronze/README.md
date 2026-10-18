# Bronze layer

Run `100_create_bronze_tables.sql` after the admin schemas/control tables and `030_ingestion_procedures.sql`. Raw source attributes are `NVARCHAR(MAX)` by design; conversion belongs in Silver. Every loaded row carries `BronzeRowID`, `IngestionBatchID`, `SourceFileName`, `SourceRowNumber`, and `IngestedAtUtc`. Re-runs append a new batch; they do not deduplicate or truncate.

The manifest covers the 11 business source files. `Data_Dictionary.csv` and `Dataset_Summary.csv` are helper artifacts and are intentionally not treated as source entities.
