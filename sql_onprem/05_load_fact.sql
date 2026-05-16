/* ============================================================================
   05_load_fact.sql
   Loads fact.FactFlight from FlightData_Staging.dbo.Flights_2024.

   Hash key generation is inline — no surrogate-key lookup required, since
   HASHBYTES of the same business key always produces the same value.

   Idempotent: re-running this script will not duplicate rows, because the
   final INSERT skips FlightHKs that already exist.
   ============================================================================ */

USE FlightData_Curated_v2;
GO

DECLARE @RunId UNIQUEIDENTIFIER = NEWID();

;WITH src AS (
    SELECT
        s.FlightID                        AS StagingFlightID,
        s.FlightDate,
        CONVERT(INT, CONVERT(CHAR(8), s.FlightDate, 112))               AS DateKey,
        HASHBYTES('SHA2_256', CAST(UPPER(LTRIM(RTRIM(s.CarrierCode))) AS NVARCHAR(20)))  AS CarrierHK,
        HASHBYTES('SHA2_256', CAST(UPPER(LTRIM(RTRIM(s.OriginCode)))  AS NVARCHAR(20)))  AS OriginHK,
        HASHBYTES('SHA2_256', CAST(UPPER(LTRIM(RTRIM(s.DestCode)))    AS NVARCHAR(20)))  AS DestHK,
        CASE
            WHEN s.DepTime IS NULL OR s.DepTime = 2400 THEN NULL
            ELSE CAST(STUFF(RIGHT('0000' + CAST(s.DepTime AS VARCHAR(4)), 4), 3, 0, ':') + ':00' AS TIME(0))
        END AS DepTime,
        CASE
            WHEN s.ArrTime IS NULL OR s.ArrTime = 2400 THEN NULL
            ELSE CAST(STUFF(RIGHT('0000' + CAST(s.ArrTime AS VARCHAR(4)), 4), 3, 0, ':') + ':00' AS TIME(0))
        END AS ArrTime,
        s.DepDelay                                                      AS DepDelayMin,
        s.ArrDelay                                                      AS ArrDelayMin,
        ISNULL(s.Cancelled, 0)                                          AS Cancelled,
        s.CancellationCode,
        ISNULL(s.Diverted, 0)                                           AS Diverted,
        s.Distance                                                      AS DistanceMiles,
        CASE WHEN ISNULL(s.ArrDelay, 0) < 15 AND ISNULL(s.Cancelled,0)=0 THEN 1 ELSE 0 END AS IsOnTime,
        HASHBYTES('SHA2_256',
            CAST(CONCAT_WS('|',
                CONVERT(VARCHAR(20), s.FlightID),
                CONVERT(VARCHAR(20), s.FlightDate, 112),
                s.CarrierCode, s.OriginCode, s.DestCode,
                CONVERT(VARCHAR(10), s.DepTime)
            ) AS NVARCHAR(200))
        ) AS FlightHK
    FROM FlightData_Staging.dbo.Flights_2024 s
)
INSERT INTO fact.FactFlight
    (FlightHK, DateKey, CarrierHK, OriginHK, DestHK,
     DepTime, ArrTime, DepDelayMin, ArrDelayMin,
     Cancelled, CancellationCode, Diverted, DistanceMiles, IsOnTime,
     StagingFlightID, RecordSource, RunId)
SELECT
    src.FlightHK, src.DateKey, src.CarrierHK, src.OriginHK, src.DestHK,
    src.DepTime, src.ArrTime, src.DepDelayMin, src.ArrDelayMin,
    src.Cancelled, src.CancellationCode, src.Diverted, src.DistanceMiles, src.IsOnTime,
    src.StagingFlightID, 'SSIS', @RunId
FROM src
WHERE NOT EXISTS (
    SELECT 1 FROM fact.FactFlight f WHERE f.FlightHK = src.FlightHK
);
GO
