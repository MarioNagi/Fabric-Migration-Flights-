/* ============================================================================
   11_cdc_window_function.sql
   Creates dbo.tvf_FlightsCDC — a reusable inline TVF that returns CDC changes
   between two LSNs with __$operation decoded into INSERT/UPDATE/DELETE.

   This is what the Fabric Copy Activity invokes over the on-prem gateway.
   ============================================================================ */

USE FlightData_Staging;
GO

IF OBJECT_ID('dbo.tvf_FlightsCDC', 'IF') IS NOT NULL DROP FUNCTION dbo.tvf_FlightsCDC;
GO

CREATE FUNCTION dbo.tvf_FlightsCDC
(
    @from_lsn BINARY(10),
    @to_lsn   BINARY(10)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        CASE c.[__$operation]
            WHEN 1 THEN 'DELETE'
            WHEN 2 THEN 'INSERT'
            WHEN 3 THEN 'UPDATE_BEFORE'
            WHEN 4 THEN 'UPDATE_AFTER'
        END                                AS Operation,
        c.[__$start_lsn]                   AS StartLSN,
        c.[__$seqval]                      AS SeqVal,
        c.FlightID,
        c.[Year],
        c.[Month],
        c.FlightDate,
        c.CarrierCode,
        c.OriginAirportID,
        c.OriginCode,
        c.OriginCity,
        c.DestAirportID,
        c.DestCode,
        c.DestCity,
        c.DepTime,
        c.DepDelay,
        c.ArrTime,
        c.ArrDelay,
        c.Cancelled,
        c.CancellationCode,
        c.Diverted,
        c.Distance
    FROM cdc.fn_cdc_get_all_changes_dbo_Flights_2024(@from_lsn, @to_lsn, 'all') AS c
    WHERE c.[__$operation] IN (1, 2, 4)   -- skip the UPDATE_BEFORE rows
);
GO
