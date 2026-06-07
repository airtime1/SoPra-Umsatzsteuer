-- ============================================================
-- Test: Status-Workflow und Rollencheck
-- Voraussetzung: sql/99_seed/001_demo_vat_workflow.sql wurde eingespielt.
-- Erwartung: RESULT in allen Zeilen = PASS
-- ============================================================

BEGIN TRANSACTION;

BEGIN TRY
    DECLARE @clerk VARCHAR(50) = (
        SELECT TOP 1 USERNAME FROM dbo.T_USER WHERE SECURITYLEVEL = 1 ORDER BY USERNAME
    );
    DECLARE @fibu VARCHAR(50) = (
        SELECT TOP 1 USERNAME FROM dbo.T_USER WHERE SECURITYLEVEL = 2 ORDER BY USERNAME
    );
    DECLARE @cfo VARCHAR(50) = (
        SELECT TOP 1 USERNAME FROM dbo.T_USER WHERE SECURITYLEVEL = 3 ORDER BY USERNAME
    );

    DECLARE @statement TABLE (VAT_STATEMENT_ID INT);
    INSERT INTO @statement
    EXEC stored_proc.sp_create_vat_statement
        @vat_period = '2026-03',
        @created_by = @clerk;

    DECLARE @statement_id INT = (SELECT TOP 1 VAT_STATEMENT_ID FROM @statement);
    DECLARE @approve_wrong_result VARCHAR(10) = 'FAIL';
    DECLARE @pay_wrong_result VARCHAR(10) = 'FAIL';
    DECLARE @recreate_paid_result VARCHAR(10) = 'FAIL';

    BEGIN TRY
        EXEC stored_proc.sp_approve_vat_statement
            @statement_id = @statement_id,
            @approved_by = @clerk;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50021 SET @approve_wrong_result = 'PASS';
    END CATCH;

    EXEC stored_proc.sp_approve_vat_statement
        @statement_id = @statement_id,
        @approved_by = @cfo;

    BEGIN TRY
        EXEC stored_proc.sp_pay_vat_statement
            @statement_id = @statement_id,
            @paid_by = @cfo;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50021 SET @pay_wrong_result = 'PASS';
    END CATCH;

    EXEC stored_proc.sp_pay_vat_statement
        @statement_id = @statement_id,
        @paid_by = @fibu;

    BEGIN TRY
        DECLARE @second_statement TABLE (VAT_STATEMENT_ID INT);
        INSERT INTO @second_statement
        EXEC stored_proc.sp_create_vat_statement
            @vat_period = '2026-03',
            @created_by = @clerk;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50002 SET @recreate_paid_result = 'PASS';
    END CATCH;

    SELECT 'TC-STAT-DEMO-01' AS CASE_ID,
           'Sachbearbeiter darf nicht freigeben' AS TESTCASE,
           @approve_wrong_result AS RESULT
    UNION ALL
    SELECT 'TC-STAT-DEMO-02',
           'CFO darf freigeben',
           CASE WHEN VAT_STATUS IN ('APPROVED', 'PAID') AND APPROVED_BY = @cfo THEN 'PASS' ELSE 'FAIL' END
    FROM dbo.T_VAT_STATEMENT
    WHERE VAT_STATEMENT_ID = @statement_id
    UNION ALL
    SELECT 'TC-STAT-DEMO-03',
           'CFO darf nicht auszahlen',
           @pay_wrong_result
    UNION ALL
    SELECT 'TC-STAT-DEMO-04',
           'Leitung FiBu darf auszahlen',
           CASE WHEN VAT_STATUS = 'PAID' AND CLOSED_BY = @fibu THEN 'PASS' ELSE 'FAIL' END
    FROM dbo.T_VAT_STATEMENT
    WHERE VAT_STATEMENT_ID = @statement_id
    UNION ALL
    SELECT 'TC-STAT-DEMO-05',
           'PAID-Periode wird nicht neu berechnet',
           @recreate_paid_result;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT 'TC-STAT-DEMO-ERROR' AS CASE_ID, ERROR_MESSAGE() AS TESTCASE, 'FAIL' AS RESULT;
END CATCH;
