/* ============================================================================
   Test: row count invariant
   Staging rows must equal curated fact rows per month.
   ============================================================================ */

USE FlightData_Curated_v2;
GO

DECLARE @drift INT = (
    SELECT COUNT(*) FROM dq.vw_pipeline_reconciliation WHERE [Status] = 'DRIFT'
);

IF @drift > 0
BEGIN
    SELECT * FROM dq.vw_pipeline_reconciliation WHERE [Status] = 'DRIFT';
    RAISERROR('FAIL: row count drift detected in %d month(s).', 16, 1, @drift);
END
ELSE
    PRINT 'PASS: staging and curated row counts agree per month.';
GO
