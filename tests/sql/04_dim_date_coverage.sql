/* ============================================================================
   Test: DimDate covers every distinct flight date.
   ============================================================================ */

USE FlightData_Curated_v2;
GO

DECLARE @missing INT = (
    SELECT COUNT(*) FROM (
        SELECT DISTINCT DateKey FROM fact.FactFlight
    ) f
    LEFT JOIN dim.DimDate d ON d.DateKey = f.DateKey
    WHERE d.DateKey IS NULL
);

IF @missing > 0 RAISERROR('FAIL: %d distinct fact dates missing from DimDate.', 16, 1, @missing);
ELSE PRINT 'PASS: DimDate covers all fact dates.';
GO
