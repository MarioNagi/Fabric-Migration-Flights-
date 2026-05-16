/* ============================================================================
   01_create_databases.sql
   Creates the on-prem databases used by this project.
   FlightData_Staging   — SSIS landing zone (already exists in the dev env)
   FlightData_Curated_v2 — rebuilt curated layer with hash keys + enriched dims
   ============================================================================ */

IF DB_ID('FlightData_Staging') IS NULL
BEGIN
    CREATE DATABASE FlightData_Staging;
END
GO

IF DB_ID('FlightData_Curated_v2') IS NULL
BEGIN
    CREATE DATABASE FlightData_Curated_v2;
END
GO

ALTER DATABASE FlightData_Curated_v2 SET RECOVERY SIMPLE;
ALTER DATABASE FlightData_Staging    SET RECOVERY SIMPLE;
GO
