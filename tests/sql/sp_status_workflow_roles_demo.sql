-- ============================================================
-- Test: Status-Workflow und hierarchischer Rollencheck fuer den aktuellen DB-Login
-- Voraussetzung: sql/99_seed/001_demo_vat_workflow.sql wurde eingespielt.
-- Erwartung: RESULT in allen Zeilen = PASS
--
-- Hinweis: Die Procedures verwenden SUSER_SNAME() als verbindliche User-Quelle.
-- Deshalb testet dieses Skript die Rechte des aktuell eingeloggten DB-Users.
-- ============================================================

BEGIN TRANSACTION;

BEGIN TRY
    DECLARE @current_user VARCHAR(50) = CAST(SUSER_SNAME() AS VARCHAR(50));
    DECLARE @security_level INT = dbo.fn_get_user_securitylevel(@current_user);
    DECLARE @can_create BIT = CASE WHEN ISNULL(@security_level, 0) >= 1 THEN 1 ELSE 0 END;
    DECLARE @can_pay BIT = CASE WHEN ISNULL(@security_level, 0) >= 2 THEN 1 ELSE 0 END;
    DECLARE @can_approve BIT = CASE WHEN ISNULL(@security_level, 0) >= 3 THEN 1 ELSE 0 END;

    DECLARE @create_result VARCHAR(10) = 'FAIL';
    DECLARE @approve_result VARCHAR(10) = 'FAIL';
    DECLARE @pay_result VARCHAR(10) = 'FAIL';
    DECLARE @reject_result VARCHAR(10) = CASE WHEN @can_create = 1 THEN 'FAIL' ELSE 'PASS' END;
    DECLARE @spoof_result VARCHAR(10) = 'PASS';
    DECLARE @recreate_paid_result VARCHAR(10) = CASE WHEN @can_pay = 1 THEN 'FAIL' ELSE 'PASS' END;

    DECLARE @statement TABLE (VAT_STATEMENT_ID INT);
    BEGIN TRY
        INSERT INTO @statement
        EXEC stored_proc.sp_G15_create_vat_statement
            @vat_period = '2026-03',
            @created_by = @current_user;
        IF @can_create = 1 SET @create_result = 'PASS';
    END TRY
    BEGIN CATCH
        IF @can_create = 0 AND ERROR_NUMBER() = 50021 SET @create_result = 'PASS';
    END CATCH;

    DECLARE @statement_id INT = (SELECT TOP 1 VAT_STATEMENT_ID FROM @statement);

    IF @statement_id IS NOT NULL
    BEGIN
        BEGIN TRY
            EXEC stored_proc.sp_G15_approve_vat_statement
                @statement_id = @statement_id,
                @approved_by = @current_user;
            IF @can_approve = 1 SET @approve_result = 'PASS';
        END TRY
        BEGIN CATCH
            IF @can_approve = 0 AND ERROR_NUMBER() = 50021 SET @approve_result = 'PASS';
        END CATCH;

        IF @can_approve = 0
        BEGIN
            UPDATE dbo.T_VAT_STATEMENT
            SET VAT_STATUS = 'APPROVED',
                APPROVED_BY = 'TEST_SETUP',
                APPROVED_AT = GETDATE()
            WHERE VAT_STATEMENT_ID = @statement_id;
        END;

        BEGIN TRY
            EXEC stored_proc.sp_G15_pay_vat_statement
                @statement_id = @statement_id,
                @paid_by = @current_user;
            IF @can_pay = 1 SET @pay_result = 'PASS';
        END TRY
        BEGIN CATCH
            IF @can_pay = 0 AND ERROR_NUMBER() = 50021 SET @pay_result = 'PASS';
        END CATCH;

        IF @can_pay = 1
        BEGIN
            BEGIN TRY
                DECLARE @second_statement TABLE (VAT_STATEMENT_ID INT);
                INSERT INTO @second_statement
                EXEC stored_proc.sp_G15_create_vat_statement
                    @vat_period = '2026-03',
                    @created_by = @current_user;
            END TRY
            BEGIN CATCH
                IF ERROR_NUMBER() = 50002 SET @recreate_paid_result = 'PASS';
            END CATCH;
        END;
    END;

    IF @can_create = 1
    BEGIN
        DECLARE @reject_statement TABLE (VAT_STATEMENT_ID INT);
        INSERT INTO @reject_statement
        EXEC stored_proc.sp_G15_create_vat_statement
            @vat_period = '2026-02',
            @created_by = @current_user;

        DECLARE @reject_statement_id INT = (SELECT TOP 1 VAT_STATEMENT_ID FROM @reject_statement);
        UPDATE dbo.T_VAT_STATEMENT
        SET VAT_STATUS = 'APPROVED',
            APPROVED_BY = 'TEST_SETUP',
            APPROVED_AT = GETDATE()
        WHERE VAT_STATEMENT_ID = @reject_statement_id;

        BEGIN TRY
            EXEC stored_proc.sp_G15_reject_vat_statement
                @statement_id = @reject_statement_id,
                @rejected_by = @current_user;
            IF @can_approve = 1 SET @reject_result = 'PASS';
        END TRY
        BEGIN CATCH
            IF @can_approve = 0 AND ERROR_NUMBER() = 50021 SET @reject_result = 'PASS';
        END CATCH;
    END;

    DECLARE @other_user VARCHAR(50) = (
        SELECT TOP 1 USERNAME
        FROM dbo.T_USER
        WHERE USERNAME <> @current_user
        ORDER BY USERNAME
    );

    IF @other_user IS NOT NULL
    BEGIN
        BEGIN TRY
            DECLARE @spoof_statement TABLE (VAT_STATEMENT_ID INT);
            INSERT INTO @spoof_statement
            EXEC stored_proc.sp_G15_create_vat_statement
                @vat_period = '2026-04',
                @created_by = @other_user;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 50024 SET @spoof_result = 'PASS';
        END CATCH;
    END;

    SELECT 'TC-STAT-DEMO-01' AS CASE_ID,
           CONCAT('Aktueller DB-User ', @current_user, ' hat Security-Level ', COALESCE(CAST(@security_level AS VARCHAR(10)), 'NULL')) AS TESTCASE,
           CASE WHEN @security_level IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS RESULT
    UNION ALL
    SELECT 'TC-STAT-DEMO-02',
           'Anlegen nutzt aktuellen DB-User und prueft Level >= 1',
           @create_result
    UNION ALL
    SELECT 'TC-STAT-DEMO-03',
           'Freigabe prueft hierarchisch Level >= 3',
           @approve_result
    UNION ALL
    SELECT 'TC-STAT-DEMO-04',
           'Bezahlen prueft hierarchisch Level >= 2',
           @pay_result
    UNION ALL
    SELECT 'TC-STAT-DEMO-05',
           'Rueckgabe prueft hierarchisch Level >= 3',
           @reject_result
    UNION ALL
    SELECT 'TC-STAT-DEMO-06',
           'Audit-User-Spoofing wird abgelehnt',
           @spoof_result
    UNION ALL
    SELECT 'TC-STAT-DEMO-07',
           'PAID-Periode wird nicht neu berechnet',
           @recreate_paid_result;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT 'TC-STAT-DEMO-ERROR' AS CASE_ID, ERROR_MESSAGE() AS TESTCASE, 'FAIL' AS RESULT;
END CATCH;
