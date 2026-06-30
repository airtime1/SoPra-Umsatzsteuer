-- ============================================================
-- Test: stored_proc.sp_G15_create_vat_statement — Demo-Periode 2026-04
-- Voraussetzung: sql/99_seed/001_demo_vat_workflow.sql wurde eingespielt.
-- Erwartung: RESULT in allen Zeilen = PASS
-- ============================================================

BEGIN TRANSACTION;

BEGIN TRY
    DECLARE @current_user VARCHAR(50) = CAST(SUSER_SNAME() AS VARCHAR(50));

    DECLARE @statement TABLE (VAT_STATEMENT_ID INT);
    INSERT INTO @statement
    EXEC stored_proc.sp_G15_create_vat_statement
        @vat_period = '2026-04',
        @created_by = @current_user;

    DECLARE @statement_id INT = (SELECT TOP 1 VAT_STATEMENT_ID FROM @statement);
    DECLARE @has_payment_corrections BIT =
        CASE
            WHEN COL_LENGTH('dbo.T_PAYMENT_RECEIPT', 'DIFFERENCE_AMOUNT') IS NOT NULL
             AND COL_LENGTH('dbo.T_PAYMENT_RECEIPT', 'SKONTO_BERECHTIGT_YN') IS NOT NULL
             AND COL_LENGTH('dbo.T_PAYMENT_RECEIPT', 'STORNO_YN') IS NOT NULL
            THEN 1 ELSE 0
        END;

    DECLARE @period_start DATE = '2026-04-01';
    DECLARE @period_end DATE = EOMONTH(@period_start);
    DECLARE @expected_output DECIMAL(12,2) = (
        SELECT ISNULL(SUM(TAX_AMOUNT), 0)
        FROM list_views.V_LIST_G15_OUTPUT_VAT
        WHERE SOURCE_INVOICE_DATE BETWEEN @period_start AND @period_end
    );
    DECLARE @expected_input DECIMAL(12,2) = (
        SELECT ISNULL(SUM(TAX_AMOUNT), 0)
        FROM list_views.V_LIST_G15_INPUT_VAT
        WHERE SOURCE_INVOICE_DATE BETWEEN @period_start AND @period_end
    );
    DECLARE @expected_balance DECIMAL(12,2);
    DECLARE @expected_type VARCHAR(20);
    DECLARE @expected_items INT = (
        SELECT COUNT(*)
        FROM (
            SELECT SOURCE_TABLE, SOURCE_INVOICE_ID
            FROM list_views.V_LIST_G15_OUTPUT_VAT
            WHERE SOURCE_INVOICE_DATE BETWEEN @period_start AND @period_end
            UNION ALL
            SELECT SOURCE_TABLE, SOURCE_INVOICE_ID
            FROM list_views.V_LIST_G15_INPUT_VAT
            WHERE SOURCE_INVOICE_DATE BETWEEN @period_start AND @period_end
        ) src
    );

    SELECT @expected_balance = VAT_BALANCE, @expected_type = VAT_TYPE
    FROM stored_func.fn_G15_calculate_vat_balance(@expected_output, @expected_input);

    SELECT
        'TC-SP-DEMO-01' AS CASE_ID,
        'Kopfwerte fuer 2026-04 inkl. Skonto/spaeter Korrektur' AS TESTCASE,
        CASE
            WHEN VAT_STATUS = 'DRAFT'
             AND OUTPUT_VAT_TOTAL = @expected_output
             AND INPUT_VAT_TOTAL = @expected_input
             AND VAT_BALANCE = @expected_balance
             AND VAT_TYPE = @expected_type
            THEN 'PASS'
            ELSE 'FAIL'
        END AS RESULT
    FROM dbo.T_VAT_STATEMENT
    WHERE VAT_STATEMENT_ID = @statement_id

    UNION ALL

    SELECT
        'TC-SP-DEMO-02',
        'Belegzeilen vollstaendig fuer vorhandenes Schnittstellenprofil',
        CASE WHEN COUNT(*) = @expected_items THEN 'PASS' ELSE 'FAIL' END
    FROM dbo.T_VAT_STATEMENT_ITEM
    WHERE VAT_STATEMENT_ID = @statement_id

    UNION ALL

    SELECT
        'TC-SP-DEMO-03',
        'Skonto-/Spaetkorrektur: vorhanden oder als Schnittstellenluecke erkannt',
        CASE
            WHEN @has_payment_corrections = 0 THEN 'PASS'
            WHEN COUNT(*) = 1 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM dbo.T_VAT_STATEMENT_ITEM
    WHERE VAT_STATEMENT_ID = @statement_id
      AND SOURCE_TABLE = 'T_PAYMENT_RECEIPT'
      AND SOURCE_INVOICE_ID = 159202
      AND TAX_AMOUNT = -9.50
      AND ORIGINAL_INVOICE_ID = 159004;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT 'TC-SP-DEMO-ERROR' AS CASE_ID, ERROR_MESSAGE() AS TESTCASE, 'FAIL' AS RESULT;
END CATCH;
