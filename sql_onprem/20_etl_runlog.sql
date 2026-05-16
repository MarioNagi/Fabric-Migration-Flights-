/* ============================================================================
   20_etl_runlog.sql
   Cross-system run log written to by SSIS event handlers, Fabric pipelines,
   and the SQL load scripts. Single source of truth for "did the load succeed?"
   ============================================================================ */

USE FlightData_Curated_v2;
GO

IF SCHEMA_ID('etl') IS NULL EXEC('CREATE SCHEMA etl');
GO

IF OBJECT_ID('etl.run_log', 'U') IS NULL
BEGIN
    CREATE TABLE etl.run_log
    (
        RunId          UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_run_log_RunId DEFAULT NEWID(),
        PipelineName   NVARCHAR(100) NOT NULL,
        SystemName     NVARCHAR(50)  NOT NULL,        -- SSIS / Fabric / SQL
        StartedAt      DATETIME2(0)  NOT NULL CONSTRAINT DF_run_log_Started DEFAULT SYSUTCDATETIME(),
        EndedAt        DATETIME2(0)  NULL,
        Status         NVARCHAR(20)  NOT NULL CONSTRAINT DF_run_log_Status DEFAULT 'RUNNING',
        RowsIn         BIGINT        NULL,
        RowsOut        BIGINT        NULL,
        RowsRejected   BIGINT        NULL,
        ErrorMessage   NVARCHAR(MAX) NULL,
        SourceFile     NVARCHAR(260) NULL,
        CONSTRAINT PK_run_log PRIMARY KEY CLUSTERED (RunId)
    );

    CREATE NONCLUSTERED INDEX IX_run_log_Pipeline_Started
        ON etl.run_log (PipelineName, StartedAt DESC);
END
GO

/* ---------- helper procs --------------------------------------------------- */
IF OBJECT_ID('etl.usp_RunStart', 'P') IS NOT NULL DROP PROCEDURE etl.usp_RunStart;
GO
CREATE PROCEDURE etl.usp_RunStart
    @PipelineName NVARCHAR(100),
    @SystemName   NVARCHAR(50),
    @SourceFile   NVARCHAR(260) = NULL,
    @RunId        UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET @RunId = NEWID();
    INSERT INTO etl.run_log (RunId, PipelineName, SystemName, SourceFile)
    VALUES (@RunId, @PipelineName, @SystemName, @SourceFile);
END
GO

IF OBJECT_ID('etl.usp_RunEnd', 'P') IS NOT NULL DROP PROCEDURE etl.usp_RunEnd;
GO
CREATE PROCEDURE etl.usp_RunEnd
    @RunId        UNIQUEIDENTIFIER,
    @Status       NVARCHAR(20),
    @RowsIn       BIGINT       = NULL,
    @RowsOut      BIGINT       = NULL,
    @RowsRejected BIGINT       = NULL,
    @ErrorMessage NVARCHAR(MAX)= NULL
AS
BEGIN
    UPDATE etl.run_log
       SET EndedAt      = SYSUTCDATETIME(),
           Status       = @Status,
           RowsIn       = @RowsIn,
           RowsOut      = @RowsOut,
           RowsRejected = @RowsRejected,
           ErrorMessage = @ErrorMessage
     WHERE RunId        = @RunId;
END
GO
