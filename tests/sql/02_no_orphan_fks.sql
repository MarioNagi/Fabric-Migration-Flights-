/* ============================================================================
   Test: no orphan foreign keys in FactFlight.
   ============================================================================ */

USE FlightData_Curated_v2;
GO

DECLARE @orphans INT = (
    SELECT COUNT(*) FROM fact.FactFlight f
    LEFT JOIN dim.DimDate d ON d.DateKey   = f.DateKey
    LEFT JOIN dim.DimCarrier c ON c.CarrierHK = f.CarrierHK
    LEFT JOIN dim.DimAirport o ON o.AirportHK = f.OriginHK
    LEFT JOIN dim.DimAirport e ON e.AirportHK = f.DestHK
    WHERE d.DateKey IS NULL OR c.CarrierHK IS NULL
       OR o.AirportHK IS NULL OR e.AirportHK IS NULL
);

IF @orphans > 0
    RAISERROR('FAIL: %d orphan FK rows in FactFlight.', 16, 1, @orphans);
ELSE
    PRINT 'PASS: no orphan FKs in FactFlight.';
GO
