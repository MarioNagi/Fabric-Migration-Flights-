/* ============================================================================
   04_load_dimensions.sql
   Populates DimDate, DimCarrier, DimAirport in FlightData_Curated_v2.

   - DimDate: generated 2020-01-01 → 2030-12-31 (4,018 days).
   - DimCarrier: seeded with the 15 codes present in staging + names from BTS.
                 SCD2 inserts (initial load = all current).
   - DimAirport: seeded from staging + enriched from a small reference table.

   Hash keys: HASHBYTES('SHA2_256', CAST(UPPER(LTRIM(RTRIM(business_key))) AS NVARCHAR(20))).
   The explicit NVARCHAR cast is required: HASHBYTES is byte-sensitive, so
   VARCHAR('AA') and NVARCHAR(N'AA') produce different hashes. Forcing
   NVARCHAR on both the seed and the fact-load join eliminates that mismatch.
   ============================================================================ */

USE FlightData_Curated_v2;
GO

DECLARE @RunId UNIQUEIDENTIFIER = NEWID();

/* ---------- DimDate -------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM dim.DimDate)
BEGIN
    ;WITH days AS (
        SELECT CAST('2020-01-01' AS DATE) AS d
        UNION ALL
        SELECT DATEADD(DAY, 1, d) FROM days WHERE d < '2030-12-31'
    )
    INSERT INTO dim.DimDate
        (DateKey, DateValue, [Year], [Quarter], [Month], MonthName,
         [Day], DayOfWeek, DayName, IsWeekend, FiscalYear, FiscalQuarter)
    SELECT
        CONVERT(INT, CONVERT(CHAR(8), d, 112)),
        d,
        DATEPART(YEAR, d),
        DATEPART(QUARTER, d),
        DATEPART(MONTH, d),
        DATENAME(MONTH, d),
        DATEPART(DAY, d),
        DATEPART(WEEKDAY, d),
        DATENAME(WEEKDAY, d),
        CASE WHEN DATEPART(WEEKDAY, d) IN (1,7) THEN 1 ELSE 0 END,
        CASE WHEN DATEPART(MONTH, d) >= 7 THEN DATEPART(YEAR, d) + 1 ELSE DATEPART(YEAR, d) END,
        CASE
            WHEN DATEPART(MONTH, d) BETWEEN 7 AND 9   THEN 1
            WHEN DATEPART(MONTH, d) BETWEEN 10 AND 12 THEN 2
            WHEN DATEPART(MONTH, d) BETWEEN 1 AND 3   THEN 3
            ELSE 4
        END
    FROM days
    OPTION (MAXRECURSION 0);
END
GO

/* ---------- DimCarrier (SCD2 initial load) -------------------------------- */
;WITH src AS (
    SELECT CarrierCode, CarrierName, CarrierType, Country FROM (VALUES
        ('AA', 'American Airlines',         'Major',    'USA'),
        ('AS', 'Alaska Airlines',           'Major',    'USA'),
        ('B6', 'JetBlue Airways',           'Major',    'USA'),
        ('DL', 'Delta Air Lines',           'Major',    'USA'),
        ('F9', 'Frontier Airlines',         'Low-Cost', 'USA'),
        ('G4', 'Allegiant Air',             'Low-Cost', 'USA'),
        ('HA', 'Hawaiian Airlines',         'Major',    'USA'),
        ('MQ', 'Envoy Air',                 'Regional', 'USA'),
        ('NK', 'Spirit Airlines',           'Low-Cost', 'USA'),
        ('OH', 'PSA Airlines',              'Regional', 'USA'),
        ('OO', 'SkyWest Airlines',          'Regional', 'USA'),
        ('UA', 'United Airlines',           'Major',    'USA'),
        ('WN', 'Southwest Airlines',        'Major',    'USA'),
        ('YX', 'Republic Airways',          'Regional', 'USA'),
        ('9E', 'Endeavor Air',              'Regional', 'USA')
    ) AS v(CarrierCode, CarrierName, CarrierType, Country)
)
INSERT INTO dim.DimCarrier
    (CarrierHK, CarrierCode, CarrierName, CarrierType, Country,
     ValidFrom, ValidTo, IsCurrent, RecordHash, RecordSource)
SELECT
    HASHBYTES('SHA2_256', CAST(UPPER(LTRIM(RTRIM(s.CarrierCode))) AS NVARCHAR(20))),
    s.CarrierCode,
    s.CarrierName,
    s.CarrierType,
    s.Country,
    '2020-01-01',
    NULL,
    1,
    HASHBYTES('SHA2_256',
        CAST(CONCAT_WS('|', s.CarrierCode, s.CarrierName, s.CarrierType, s.Country) AS NVARCHAR(400))),
    'BTS'
FROM src s
WHERE NOT EXISTS (
    SELECT 1 FROM dim.DimCarrier d
    WHERE d.CarrierHK = HASHBYTES('SHA2_256', CAST(UPPER(LTRIM(RTRIM(s.CarrierCode))) AS NVARCHAR(20)))
);
GO

/* ---------- DimAirport ---------------------------------------------------- */
-- seed from staging codes; enrichment columns left NULL where unknown.
-- A separate reference loader can hydrate AirportName/State/Country/Lat/Lon
-- from the BTS L_AIRPORT.csv file.
INSERT INTO dim.DimAirport
    (AirportHK, AirportCode, CityName, RecordSource)
SELECT DISTINCT
    HASHBYTES('SHA2_256', CAST(UPPER(LTRIM(RTRIM(s.OriginCode))) AS NVARCHAR(20))),
    s.OriginCode,
    s.OriginCity,
    'STAGING'
FROM FlightData_Staging.dbo.Flights_2024 s
WHERE s.OriginCode IS NOT NULL
  AND NOT EXISTS (
        SELECT 1 FROM dim.DimAirport d
        WHERE d.AirportHK = HASHBYTES('SHA2_256', CAST(UPPER(LTRIM(RTRIM(s.OriginCode))) AS NVARCHAR(20)))
  );

INSERT INTO dim.DimAirport
    (AirportHK, AirportCode, CityName, RecordSource)
SELECT DISTINCT
    HASHBYTES('SHA2_256', CAST(UPPER(LTRIM(RTRIM(s.DestCode))) AS NVARCHAR(20))),
    s.DestCode,
    s.DestCity,
    'STAGING'
FROM FlightData_Staging.dbo.Flights_2024 s
WHERE s.DestCode IS NOT NULL
  AND NOT EXISTS (
        SELECT 1 FROM dim.DimAirport d
        WHERE d.AirportHK = HASHBYTES('SHA2_256', CAST(UPPER(LTRIM(RTRIM(s.DestCode))) AS NVARCHAR(20)))
  );
GO

/* ---------- Mark major hubs ---------------------------------------------- */
UPDATE dim.DimAirport
SET IsHub = 1, UpdatedAt = SYSUTCDATETIME()
WHERE AirportCode IN
    ('ATL','DFW','DEN','ORD','LAX','JFK','LAS','MCO','MIA','CLT',
     'SEA','PHX','EWR','SFO','IAH','BOS','MSP','LGA','DTW','PHL');
GO
