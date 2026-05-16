/* ============================================================================
   Test: hash key uniqueness in dimensions (excluding SCD2 history rows).
   ============================================================================ */

USE FlightData_Curated_v2;
GO

DECLARE @dup INT = (
    SELECT COUNT(*) FROM (
        SELECT CarrierHK FROM dim.DimCarrier WHERE IsCurrent = 1
        GROUP BY CarrierHK HAVING COUNT(*) > 1
    ) x
);

IF @dup > 0 RAISERROR('FAIL: duplicate current CarrierHK values.', 16, 1);
ELSE PRINT 'PASS: DimCarrier current rows are unique by hash.';
GO

DECLARE @dup2 INT = (
    SELECT COUNT(*) FROM (
        SELECT AirportHK FROM dim.DimAirport
        GROUP BY AirportHK HAVING COUNT(*) > 1
    ) x
);

IF @dup2 > 0 RAISERROR('FAIL: duplicate AirportHK values.', 16, 1);
ELSE PRINT 'PASS: DimAirport hash keys unique.';
GO
