/* ============================================================================
   02_create_staging.sql
   Defines dbo.Flights_2024 in FlightData_Staging.
   Schema matches the SSIS package output (Load_Flights_2024.dtsx).
   ============================================================================ */

USE FlightData_Staging;
GO

IF OBJECT_ID('dbo.Flights_2024', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Flights_2024
    (
        FlightID         BIGINT IDENTITY(1,1) NOT NULL,
        [Year]           INT          NULL,
        [Month]          INT          NULL,
        FlightDate       DATE         NULL,
        CarrierCode      NVARCHAR(10) NULL,
        OriginAirportID  INT          NULL,
        OriginCode       NVARCHAR(10) NULL,
        OriginCity       NVARCHAR(100) NULL,
        DestAirportID    INT          NULL,
        DestCode         NVARCHAR(10) NULL,
        DestCity         NVARCHAR(100) NULL,
        DepTime          INT          NULL,
        DepDelay         INT          NULL,
        ArrTime          INT          NULL,
        ArrDelay         INT          NULL,
        Cancelled        BIT          NULL,
        CancellationCode NVARCHAR(10) NULL,
        Diverted         BIT          NULL,
        Distance         INT          NULL,
        LoadedAt         DATETIME2(0) NOT NULL CONSTRAINT DF_Flights_2024_LoadedAt DEFAULT SYSUTCDATETIME(),
        SourceFile       NVARCHAR(260) NULL,
        CONSTRAINT PK_Flights_2024 PRIMARY KEY CLUSTERED (FlightID)
    );

    CREATE NONCLUSTERED INDEX IX_Flights_2024_FlightDate
        ON dbo.Flights_2024 (FlightDate)
        INCLUDE (CarrierCode, OriginCode, DestCode);
END
GO
