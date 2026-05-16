/* ============================================================================
   03_create_star_schema.sql
   Curated v2 star schema with hash surrogate keys and SCD2 on DimCarrier.

   Design notes:
   - Hash keys (BINARY(32)) instead of INT IDENTITY so the same business key
     produces the same surrogate everywhere (on-prem AND Fabric). See
     docs/adr/0001-hash-keys-over-identity.md.
   - DimCarrier is SCD2 (ValidFrom/ValidTo/IsCurrent/RecordHash).
   - DimAirport and DimDate are SCD1 (overwrite).
   - FactFlight uses a clustered columnstore index — see ADR 0007.
   ============================================================================ */

USE FlightData_Curated_v2;
GO

IF SCHEMA_ID('dim') IS NULL EXEC('CREATE SCHEMA dim');
IF SCHEMA_ID('fact') IS NULL EXEC('CREATE SCHEMA fact');
IF SCHEMA_ID('etl') IS NULL EXEC('CREATE SCHEMA etl');
IF SCHEMA_ID('dq')  IS NULL EXEC('CREATE SCHEMA dq');
GO

/* ---------- DimCarrier — SCD Type 2 ---------------------------------------- */
IF OBJECT_ID('dim.DimCarrier', 'U') IS NULL
BEGIN
    CREATE TABLE dim.DimCarrier
    (
        CarrierHK     BINARY(32)    NOT NULL,
        CarrierCode   NVARCHAR(10)  NOT NULL,
        CarrierName   NVARCHAR(100) NULL,
        CarrierType   NVARCHAR(20)  NULL,
        Country       NVARCHAR(50)  NULL,
        ValidFrom     DATETIME2(0)  NOT NULL CONSTRAINT DF_DimCarrier_ValidFrom DEFAULT SYSUTCDATETIME(),
        ValidTo       DATETIME2(0)  NULL,
        IsCurrent     BIT           NOT NULL CONSTRAINT DF_DimCarrier_IsCurrent DEFAULT 1,
        RecordHash    BINARY(32)    NOT NULL,
        LoadedAt      DATETIME2(0)  NOT NULL CONSTRAINT DF_DimCarrier_LoadedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt     DATETIME2(0)  NULL,
        RecordSource  NVARCHAR(50)  NOT NULL CONSTRAINT DF_DimCarrier_Source DEFAULT 'BTS',
        RunId         UNIQUEIDENTIFIER NULL,
        CONSTRAINT PK_DimCarrier PRIMARY KEY CLUSTERED (CarrierHK)
    );

    CREATE NONCLUSTERED INDEX IX_DimCarrier_Code_Current
        ON dim.DimCarrier (CarrierCode)
        INCLUDE (CarrierHK, IsCurrent)
        WHERE IsCurrent = 1;
END
GO

/* ---------- DimAirport — SCD Type 1 ---------------------------------------- */
IF OBJECT_ID('dim.DimAirport', 'U') IS NULL
BEGIN
    CREATE TABLE dim.DimAirport
    (
        AirportHK     BINARY(32)    NOT NULL,
        AirportCode   NVARCHAR(10)  NOT NULL,
        AirportName   NVARCHAR(150) NULL,
        CityName      NVARCHAR(100) NULL,
        [State]       NVARCHAR(50)  NULL,
        Country       NVARCHAR(50)  NULL,
        Latitude      DECIMAL(9, 6) NULL,
        Longitude     DECIMAL(9, 6) NULL,
        TimeZone      NVARCHAR(50)  NULL,
        IsHub         BIT           NOT NULL CONSTRAINT DF_DimAirport_Hub DEFAULT 0,
        LoadedAt      DATETIME2(0)  NOT NULL CONSTRAINT DF_DimAirport_LoadedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt     DATETIME2(0)  NULL,
        RecordSource  NVARCHAR(50)  NOT NULL CONSTRAINT DF_DimAirport_Source DEFAULT 'BTS',
        RunId         UNIQUEIDENTIFIER NULL,
        CONSTRAINT PK_DimAirport PRIMARY KEY CLUSTERED (AirportHK)
    );

    CREATE UNIQUE NONCLUSTERED INDEX UX_DimAirport_Code
        ON dim.DimAirport (AirportCode);
END
GO

/* ---------- DimDate — SCD Type 1, populated 2020-2030 ---------------------- */
IF OBJECT_ID('dim.DimDate', 'U') IS NULL
BEGIN
    CREATE TABLE dim.DimDate
    (
        DateKey       INT           NOT NULL,           -- yyyymmdd
        DateValue     DATE          NOT NULL,
        [Year]        INT           NOT NULL,
        [Quarter]     INT           NOT NULL,
        [Month]       INT           NOT NULL,
        MonthName     NVARCHAR(20)  NOT NULL,
        [Day]         INT           NOT NULL,
        DayOfWeek     INT           NOT NULL,
        DayName       NVARCHAR(20)  NOT NULL,
        IsWeekend     BIT           NOT NULL,
        IsHoliday     BIT           NOT NULL CONSTRAINT DF_DimDate_IsHoliday DEFAULT 0,
        FiscalYear    INT           NOT NULL,
        FiscalQuarter INT           NOT NULL,
        LoadedAt      DATETIME2(0)  NOT NULL CONSTRAINT DF_DimDate_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_DimDate PRIMARY KEY CLUSTERED (DateKey)
    );

    CREATE UNIQUE NONCLUSTERED INDEX UX_DimDate_DateValue
        ON dim.DimDate (DateValue);
END
GO

/* ---------- FactFlight ----------------------------------------------------- */
IF OBJECT_ID('fact.FactFlight', 'U') IS NULL
BEGIN
    CREATE TABLE fact.FactFlight
    (
        FlightHK         BINARY(32)    NOT NULL,
        DateKey          INT           NOT NULL,
        CarrierHK        BINARY(32)    NOT NULL,
        OriginHK         BINARY(32)    NOT NULL,
        DestHK           BINARY(32)    NOT NULL,
        DepTime          TIME(0)       NULL,
        ArrTime          TIME(0)       NULL,
        DepDelayMin      INT           NULL,
        ArrDelayMin      INT           NULL,
        Cancelled        BIT           NOT NULL,
        CancellationCode NVARCHAR(10)  NULL,
        Diverted         BIT           NOT NULL,
        DistanceMiles    INT           NULL,
        IsOnTime         BIT           NOT NULL,
        StagingFlightID  BIGINT        NULL,        -- lineage back to staging
        LoadedAt         DATETIME2(0)  NOT NULL CONSTRAINT DF_FactFlight_LoadedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt        DATETIME2(0)  NULL,
        RecordSource     NVARCHAR(50)  NOT NULL CONSTRAINT DF_FactFlight_Source DEFAULT 'SSIS',
        RunId            UNIQUEIDENTIFIER NULL
    );

    -- clustered columnstore is the right choice for an analytics fact at this scale
    CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactFlight ON fact.FactFlight;

    -- supporting btree indexes for common dim joins
    CREATE NONCLUSTERED INDEX IX_FactFlight_DateKey      ON fact.FactFlight (DateKey);
    CREATE NONCLUSTERED INDEX IX_FactFlight_CarrierHK    ON fact.FactFlight (CarrierHK);
    CREATE NONCLUSTERED INDEX IX_FactFlight_OriginHK     ON fact.FactFlight (OriginHK);
    CREATE NONCLUSTERED INDEX IX_FactFlight_DestHK       ON fact.FactFlight (DestHK);
END
GO

/* ---------- Foreign keys --------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactFlight_DimDate')
    ALTER TABLE fact.FactFlight ADD CONSTRAINT FK_FactFlight_DimDate
        FOREIGN KEY (DateKey) REFERENCES dim.DimDate (DateKey);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactFlight_DimCarrier')
    ALTER TABLE fact.FactFlight ADD CONSTRAINT FK_FactFlight_DimCarrier
        FOREIGN KEY (CarrierHK) REFERENCES dim.DimCarrier (CarrierHK);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactFlight_DimAirport_Origin')
    ALTER TABLE fact.FactFlight ADD CONSTRAINT FK_FactFlight_DimAirport_Origin
        FOREIGN KEY (OriginHK) REFERENCES dim.DimAirport (AirportHK);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactFlight_DimAirport_Dest')
    ALTER TABLE fact.FactFlight ADD CONSTRAINT FK_FactFlight_DimAirport_Dest
        FOREIGN KEY (DestHK) REFERENCES dim.DimAirport (AirportHK);
GO

/* ---------- Replacement for old dbo.Flights flat table -------------------- */
IF OBJECT_ID('dbo.vw_Flights', 'V') IS NOT NULL DROP VIEW dbo.vw_Flights;
GO

CREATE VIEW dbo.vw_Flights AS
SELECT
    f.StagingFlightID,
    d.DateValue        AS FlightDate,
    c.CarrierCode,
    c.CarrierName,
    o.AirportCode      AS OriginCode,
    o.AirportName      AS OriginName,
    o.CityName         AS OriginCity,
    o.[State]          AS OriginState,
    de.AirportCode     AS DestCode,
    de.AirportName     AS DestName,
    de.CityName        AS DestCity,
    de.[State]         AS DestState,
    f.DepTime,
    f.ArrTime,
    f.DepDelayMin,
    f.ArrDelayMin,
    f.Cancelled,
    f.CancellationCode,
    f.Diverted,
    f.DistanceMiles,
    f.IsOnTime
FROM fact.FactFlight f
JOIN dim.DimDate     d  ON d.DateKey   = f.DateKey
JOIN dim.DimCarrier  c  ON c.CarrierHK = f.CarrierHK AND c.IsCurrent = 1
JOIN dim.DimAirport  o  ON o.AirportHK = f.OriginHK
JOIN dim.DimAirport  de ON de.AirportHK = f.DestHK;
GO
