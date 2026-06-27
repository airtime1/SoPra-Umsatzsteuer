-- ============================================================
-- stored_proc.sp_G15_approve_vat_statement
-- DRAFT -> APPROVED. Aufrufer: CFO (Stufe 3).
-- ------------------------------------------------------------
-- Transitionspruefung ueber die zentrale Architekten-Function
-- dbo.fn_chk_status_folge (liest dbo.T_CODE_NEXT). Die Rollen-
-- pruefung (SECURITY_LEVEL der Transition) bleibt eigene Logik,
-- weil fn_chk_status_folge keine Rollen prueft.
-- ============================================================
CREATE OR ALTER PROCEDURE stored_proc.sp_G15_approve_vat_statement
    @statement_id INT,
    @approved_by  VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- Status-IDs aufloesen (fn_chk_status_folge arbeitet mit IDs, nicht Namen)
    DECLARE @old_id INT = (SELECT ID_CODE FROM dbo.T_CODE WHERE CODE_TYPE = 'VAT_STATUS' AND CODE_NAME = 'DRAFT');
    DECLARE @new_id INT = (SELECT ID_CODE FROM dbo.T_CODE WHERE CODE_TYPE = 'VAT_STATUS' AND CODE_NAME = 'APPROVED');

    IF @old_id IS NULL OR @new_id IS NULL
    BEGIN
        THROW 50023, 'VAT_STATUS-Codewerte fehlen in dbo.T_CODE.', 1;
        RETURN;
    END

    -- Zentrale Transitionspruefung (Prof-Function dbo.fn_chk_status_folge)
    DECLARE @folge_check NVARCHAR(200) = dbo.fn_chk_status_folge(@old_id, @new_id);
    IF @folge_check <> 'OK'
    BEGIN
        THROW 50022, 'Statusuebergang DRAFT -> APPROVED ist nicht erlaubt (dbo.fn_chk_status_folge).', 1;
        RETURN;
    END

    -- Rollenpruefung ueber SECURITY_LEVEL der Transition
    DECLARE @required_security_level INT = (
        SELECT SECURITY_LEVEL FROM dbo.T_CODE_NEXT
        WHERE CODE_ID = @old_id AND CODE_NEXT_ID = @new_id
    );

    DECLARE @actual_security_level INT = dbo.fn_get_user_securitylevel(@approved_by);
    IF @actual_security_level IS NULL
    BEGIN
        THROW 50020, 'Unbekannter Benutzer fuer Umsatzsteuerabrechnung.', 1;
        RETURN;
    END

    IF @required_security_level IS NULL OR @actual_security_level <> @required_security_level
    BEGIN
        THROW 50021, 'Benutzer hat nicht die benoetigte Rolle fuer diese Aktion.', 1;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1 FROM dbo.T_VAT_STATEMENT
            WHERE VAT_STATEMENT_ID = @statement_id
              AND VAT_STATUS = 'DRAFT'
        )
        BEGIN
            THROW 50010, 'Abrechnung ist nicht im Status DRAFT oder existiert nicht.', 1;
            RETURN;
        END

        UPDATE dbo.T_VAT_STATEMENT
        SET VAT_STATUS  = 'APPROVED',
            APPROVED_BY = @approved_by,
            APPROVED_AT = GETDATE()
        WHERE VAT_STATEMENT_ID = @statement_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
