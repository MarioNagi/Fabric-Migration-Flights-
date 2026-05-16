/* ============================================================================
   22_reconciliation_view.sql
   Surfaces row counts at every layer per month so any drift is visible at a
   glance. Power BI consumes this view directly.
   ============================================================================ */

USE FlightData_Curated_v2;
GO

IF OBJECT_ID('dq.vw_pipeline_reconciliation', 'V') IS NOT NULL
    DROP VIEW dq.vw_pipeline_reconciliation;
GO

CREATE VIEW dq.vw_pipeline_reconciliation AS
WITH staging AS (
    SELECT [Year], [Month], COUNT_BIG(*) AS StagingRows
    FROM FlightData_Staging.dbo.Flights_2024
    GROUP BY [Year], [Month]
),
curated AS (
    SELECT d.[Year], d.[Month], COUNT_BIG(*) AS CuratedRows
    FROM fact.FactFlight f
    JOIN dim.DimDate d ON d.DateKey = f.DateKey
    GROUP BY d.[Year], d.[Month]
)
SELECT
    COALESCE(s.[Year], c.[Year])   AS [Year],
    COALESCE(s.[Month], c.[Month]) AS [Month],
    ISNULL(s.StagingRows, 0)       AS StagingRows,
    ISNULL(c.CuratedRows, 0)       AS CuratedRows,
    ISNULL(s.StagingRows, 0) - ISNULL(c.CuratedRows, 0) AS Variance,
    CASE WHEN ISNULL(s.StagingRows,0) = ISNULL(c.CuratedRows,0) THEN 'OK' ELSE 'DRIFT' END AS [Status]
FROM staging s
FULL OUTER JOIN curated c
    ON c.[Year] = s.[Year] AND c.[Month] = s.[Month];
GO
