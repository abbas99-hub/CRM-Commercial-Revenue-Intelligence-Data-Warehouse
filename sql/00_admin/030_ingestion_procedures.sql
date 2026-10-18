/* Batch lifecycle procedures used by the Python CSV loader. */
CREATE OR ALTER PROCEDURE ctl.usp_StartIngestionBatch
    @SourceSystem NVARCHAR(100), @SourceFileName NVARCHAR(260), @IngestionBatchID BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT ctl.IngestionBatch(SourceSystem, SourceFileName, BatchStatus, RowsRead, RowsLoaded, RowsRejected)
    VALUES (@SourceSystem, @SourceFileName, 'RUNNING', 0, 0, 0);
    SET @IngestionBatchID = SCOPE_IDENTITY();
END;
GO
CREATE OR ALTER PROCEDURE ctl.usp_CompleteIngestionBatch
    @IngestionBatchID BIGINT, @BatchStatus VARCHAR(20), @RowsRead BIGINT,
    @RowsLoaded BIGINT, @RowsRejected BIGINT, @ErrorMessage NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE ctl.IngestionBatch
       SET CompletedAtUtc = SYSUTCDATETIME(), BatchStatus = @BatchStatus,
           RowsRead = @RowsRead, RowsLoaded = @RowsLoaded, RowsRejected = @RowsRejected,
           ErrorMessage = @ErrorMessage
     WHERE IngestionBatchID = @IngestionBatchID;
    IF @@ROWCOUNT = 0 THROW 51001, 'IngestionBatchID not found.', 1;
END;
GO
