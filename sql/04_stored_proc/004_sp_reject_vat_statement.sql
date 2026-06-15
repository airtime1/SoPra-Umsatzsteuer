-- ============================================================
-- stored_proc.sp_reject_vat_statement
-- APPROVED -> DRAFT (Rueckgabe / Zurueckweisung).
-- Aufrufer: CFO (Stufe 3).
-- Setzt APPROVED_BY/_AT zurueck, damit beim naechsten Freigeben
-- ein neuer Audit-Eintrag entsteht.
-- ------------------------------------------------------------
-- Transitionspruefung ueber die zentrale Architekten-Function
-- dbo.fn_chk_status_folge (liest dbo.T_CODE_NEXT).
-- ============================================================
CREATE OR ALTER PROCEDURE stored_proc.sp_reject_vat_statement
    @statement_id INT,
    @rejected_by  VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @old_id INT = (SELECT ID_CODE FROM dbo.T_CODE WHERE CODE_TYPE = 'VAT_STATUS' AND CODE_NAME = 'APPROVED');
    DECLARE @new_id INT = (SELECT ID_CODE FROM dbo.T_CODE WHERE CODE_TYPE = 'VAT_STATUS' AND CODE_NAME = 'DRAFT');

    IF @old_id IS NULL OR @new_id IS NULL
    BEGIN
        THROW 50023, 'VAT_STATUS-Codewerte fehlen in dbo.T_CODE.', 1;
        RETURN;
    END

    DECLARE @folge_check NVARCHAR(200) = dbo.fn_chk_status_folge(@old_id, @new_id);
    IF @folge_check <> 'OK'
    BEGIN
        THROW 50022, 'Statusuebergang APPROVED -> DRAFT ist nicht erlaubt (dbo.fn_chk_status_folge).', 1;
        RETURN;
    END

    DECLARE @required_security_level INT = (
        SELECT SECURITY_LEVEL FROM dbo.T_CODE_NEXT
        WHERE CODE_ID = @old_id AND CODE_NEXT_ID = @new_id
    );

    DECLARE @actual_security_level INT = stored_func.fn_get_user_security_level(@rejected_by);
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
              AND VAT_STATUS = 'APPROVED'
        )
        BEGIN
            THROW 50012, 'Abrechnung ist nicht im Status APPROVED oder existiert nicht.', 1;
            RETURN;
        END

        UPDATE dbo.T_VAT_STATEMENT
        SET VAT_STATUS  = 'DRAFT',
            APPROVED_BY = NULL,
            APPROVED_AT = NULL
        WHERE VAT_STATEMENT_ID = @statement_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
