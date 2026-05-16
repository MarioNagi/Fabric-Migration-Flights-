/* ============================================================================
   21_dq_framework.sql
   Data quality framework: expectations table, results table, runner proc,
   quarantine table.
   ============================================================================ */

USE FlightData_Curated_v2;
GO

IF OBJECT_ID('dq.expectations', 'U') IS NULL
BEGIN
    CREATE TABLE dq.expectations
    (
        RuleId          INT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
        TableName       NVARCHAR(200) NOT NULL,
        ColumnName      NVARCHAR(100) NULL,
        RuleType        NVARCHAR(20)  NOT NULL,
        RuleDefinition  NVARCHAR(500) NOT NULL,
        Severity        NVARCHAR(10)  NOT NULL,
        IsActive        BIT           NOT NULL CONSTRAINT DF_expectations_IsActive DEFAULT 1
    );
END
GO

IF OBJECT_ID('dq.expectation_results', 'U') IS NULL
BEGIN
    CREATE TABLE dq.expectation_results
    (
        ResultId        BIGINT IDENTITY(1,1) PRIMARY KEY,
        RunId           UNIQUEIDENTIFIER NOT NULL,
        RuleId          INT NOT NULL,
        EvaluatedAt     DATETIME2(0)  NOT NULL CONSTRAINT DF_results_Evaluated DEFAULT SYSUTCDATETIME(),
        FailingRowCount BIGINT NOT NULL,
        Passed          BIT NOT NULL
    );
END
GO

IF OBJECT_ID('dq.quarantine_flights', 'U') IS NULL
BEGIN
    CREATE TABLE dq.quarantine_flights
    (
        QuarantineId    BIGINT IDENTITY(1,1) PRIMARY KEY,
        StagingFlightID BIGINT NULL,
        FailedRuleId    INT NOT NULL,
        FailedAt        DATETIME2(0) NOT NULL CONSTRAINT DF_quar_FailedAt DEFAULT SYSUTCDATETIME(),
        RawPayload      NVARCHAR(MAX) NULL
    );
END
GO

/* ---------- Seed rules ---------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM dq.expectations)
BEGIN
    INSERT INTO dq.expectations (TableName, ColumnName, RuleType, RuleDefinition, Severity) VALUES
        ('FlightData_Staging.dbo.Flights_2024', 'DepDelay',    'range',    'DepDelay BETWEEN -120 AND 1440',                    'WARN'),
        ('FlightData_Staging.dbo.Flights_2024', 'ArrDelay',    'range',    'ArrDelay BETWEEN -120 AND 1440',                    'WARN'),
        ('FlightData_Staging.dbo.Flights_2024', 'OriginCode',  'not_null', 'OriginCode IS NOT NULL',                            'ERROR'),
        ('FlightData_Staging.dbo.Flights_2024', 'DestCode',    'not_null', 'DestCode IS NOT NULL',                              'ERROR'),
        ('FlightData_Staging.dbo.Flights_2024', 'Cancelled',   'enum',     'Cancelled IN (0, 1)',                               'ERROR'),
        ('FlightData_Staging.dbo.Flights_2024', 'FlightDate',  'range',    'FlightDate BETWEEN ''2020-01-01'' AND ''2030-12-31''','ERROR'),
        ('FlightData_Staging.dbo.Flights_2024', 'Distance',    'range',    'Distance BETWEEN 0 AND 5000',                       'WARN'),
        ('FlightData_Staging.dbo.Flights_2024', 'CarrierCode', 'lookup',   'CarrierCode IN (SELECT CarrierCode FROM FlightData_Curated_v2.dim.DimCarrier)', 'ERROR');
END
GO

/* ---------- Runner proc --------------------------------------------------- */
IF OBJECT_ID('dq.usp_RunExpectations', 'P') IS NOT NULL DROP PROCEDURE dq.usp_RunExpectations;
GO
CREATE PROCEDURE dq.usp_RunExpectations
    @RunId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RuleId INT, @TableName NVARCHAR(200), @RuleDef NVARCHAR(500);
    DECLARE @Sql NVARCHAR(MAX), @Failing BIGINT;

    DECLARE rule_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT RuleId, TableName, RuleDefinition
        FROM dq.expectations WHERE IsActive = 1;

    OPEN rule_cur;
    FETCH NEXT FROM rule_cur INTO @RuleId, @TableName, @RuleDef;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Sql = N'SELECT @cnt = COUNT(*) FROM ' + @TableName + N' WHERE NOT (' + @RuleDef + N')';
        BEGIN TRY
            EXEC sp_executesql @Sql, N'@cnt BIGINT OUTPUT', @cnt = @Failing OUTPUT;

            INSERT INTO dq.expectation_results (RunId, RuleId, FailingRowCount, Passed)
            VALUES (@RunId, @RuleId, @Failing, CASE WHEN @Failing = 0 THEN 1 ELSE 0 END);
        END TRY
        BEGIN CATCH
            INSERT INTO dq.expectation_results (RunId, RuleId, FailingRowCount, Passed)
            VALUES (@RunId, @RuleId, -1, 0);
        END CATCH

        FETCH NEXT FROM rule_cur INTO @RuleId, @TableName, @RuleDef;
    END

    CLOSE rule_cur;
    DEALLOCATE rule_cur;
END
GO
