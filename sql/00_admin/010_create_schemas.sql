/* Phase 2 architecture bootstrap: SQL Server */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'brz') EXEC('CREATE SCHEMA brz');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'slv') EXEC('CREATE SCHEMA slv');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gld') EXEC('CREATE SCHEMA gld');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'rpt') EXEC('CREATE SCHEMA rpt');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ctl') EXEC('CREATE SCHEMA ctl');
GO
