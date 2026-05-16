/* ============================================================================
   06_drop_legacy_flat_table.sql
   Removes the denormalised dbo.Flights duplicate from the original
   FlightData_Curated database. Replaced by FlightData_Curated_v2.dbo.vw_Flights.

   Run this only after validating row counts match between FactFlight and the
   view. See tests/sql/02_reconciliation.sql.
   ============================================================================ */

USE FlightData_Curated;
GO

IF OBJECT_ID('dbo.Flights', 'U') IS NOT NULL
BEGIN
    PRINT 'Dropping dbo.Flights (denormalised duplicate)';
    DROP TABLE dbo.Flights;
END
GO
