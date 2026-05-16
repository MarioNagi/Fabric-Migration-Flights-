/* ============================================================================
   Test: data semantics — cancelled flights cannot have an ArrTime.
   ============================================================================ */

USE FlightData_Curated_v2;
GO

DECLARE @bad INT = (
    SELECT COUNT(*) FROM fact.FactFlight
    WHERE Cancelled = 1 AND ArrTime IS NOT NULL
);

IF @bad > 0 RAISERROR('FAIL: %d cancelled flights have ArrTime set.', 16, 1, @bad);
ELSE PRINT 'PASS: cancelled flights have no arrival time.';
GO
