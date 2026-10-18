/* Control/lineage tables for repeatable ingestion and audit. */
CREATE TABLE ctl.IngestionBatch (
    IngestionBatchID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    SourceSystem NVARCHAR(100) NOT NULL,
    SourceFileName NVARCHAR(260) NOT NULL,
    StartedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_IngestionBatch_Started DEFAULT SYSUTCDATETIME(),
    CompletedAtUtc DATETIME2(3) NULL,
    BatchStatus VARCHAR(20) NOT NULL,
    RowsRead BIGINT NULL,
    RowsLoaded BIGINT NULL,
    RowsRejected BIGINT NULL,
    ErrorMessage NVARCHAR(MAX) NULL
);
GO
CREATE TABLE ctl.DataQualityException (
    DataQualityExceptionID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    IngestionBatchID BIGINT NULL,
    SourceEntity SYSNAME NOT NULL,
    SourceBusinessKey NVARCHAR(500) NULL,
    RuleCode VARCHAR(50) NOT NULL,
    Severity VARCHAR(20) NOT NULL,
    ExceptionDetails NVARCHAR(MAX) NOT NULL,
    DetectedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_DQException_Detected DEFAULT SYSUTCDATETIME(),
    ResolutionStatus VARCHAR(20) NOT NULL CONSTRAINT DF_DQException_Status DEFAULT 'Open',
    ResolvedAtUtc DATETIME2(3) NULL,
    ResolutionNote NVARCHAR(MAX) NULL,
    CONSTRAINT FK_DQException_Batch FOREIGN KEY (IngestionBatchID) REFERENCES ctl.IngestionBatch(IngestionBatchID)
);
GO
