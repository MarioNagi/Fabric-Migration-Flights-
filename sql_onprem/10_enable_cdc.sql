/* ============================================================================
   10_enable_cdc.sql
   Enables CDC on FlightData_Staging.dbo.Flights_2024.
   Bumps retention to 7 days (default 3) so weekly Fabric pulls do not lose data.
   Requires SQL Server Agent running.
   ============================================================================ */

USE FlightData_Staging;
GO

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = DB_NAME() AND is_cdc_enabled = 1)
BEGIN
    EXEC sys.sp_cdc_enable_db;
    PRINT 'CDC enabled at the database level.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.tables t
    JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = 'dbo' AND t.name = 'Flights_2024' AND t.is_tracked_by_cdc = 1
)
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema        = N'dbo',
        @source_name          = N'Flights_2024',
        @role_name            = NULL,
        @supports_net_changes = 1;
    PRINT 'CDC enabled on dbo.Flights_2024.';
END
GO

-- bump retention from default 4320 minutes (3 days) to 10080 (7 days)
EXEC sys.sp_cdc_change_job
    @job_type  = N'cleanup',
    @retention = 10080;
GO
