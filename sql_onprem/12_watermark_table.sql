/* ============================================================================
   12_watermark_table.sql
   Tracks the high-water LSN per CDC-enabled table so Fabric pulls are
   incremental and gap-free.
   ============================================================================ */

USE FlightData_Staging;
GO

IF SCHEMA_ID('etl') IS NULL EXEC('CREATE SCHEMA etl');
GO

IF OBJECT_ID('etl.cdc_watermark', 'U') IS NULL
BEGIN
    CREATE TABLE etl.cdc_watermark
    (
        TableName     SYSNAME       NOT NULL CONSTRAINT PK_cdc_watermark PRIMARY KEY,
        LastLSN       BINARY(10)    NULL,
        LastRunAt     DATETIME2(0)  NULL,
        LastRowCount  BIGINT        NULL
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM etl.cdc_watermark WHERE TableName = 'dbo.Flights_2024')
    INSERT INTO etl.cdc_watermark (TableName, LastLSN, LastRunAt, LastRowCount)
    VALUES ('dbo.Flights_2024', NULL, NULL, NULL);
GO

/* ---------- helper proc — pulls a CDC window and updates watermark -------- */
IF OBJECT_ID('etl.usp_GetFlightsCDCWindow', 'P') IS NOT NULL
    DROP PROCEDURE etl.usp_GetFlightsCDCWindow;
GO

CREATE PROCEDURE etl.usp_GetFlightsCDCWindow
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @from_lsn BINARY(10) = (SELECT LastLSN FROM etl.cdc_watermark WHERE TableName = 'dbo.Flights_2024');
    DECLARE @to_lsn   BINARY(10) = sys.fn_cdc_get_max_lsn();

    IF @from_lsn IS NULL
        SET @from_lsn = sys.fn_cdc_get_min_lsn('dbo_Flights_2024');

    IF @from_lsn IS NULL OR @to_lsn IS NULL OR @from_lsn > @to_lsn
    BEGIN
        PRINT 'No CDC window available — capture jobs may not have run yet.';
        RETURN;
    END

    SELECT * FROM dbo.tvf_FlightsCDC(@from_lsn, @to_lsn);

    DECLARE @rowcount BIGINT = @@ROWCOUNT;

    UPDATE etl.cdc_watermark
       SET LastLSN      = @to_lsn,
           LastRunAt    = SYSUTCDATETIME(),
           LastRowCount = @rowcount
     WHERE TableName    = 'dbo.Flights_2024';
END
GO
