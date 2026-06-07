-- ============================================================
-- stored_proc.sp_pay_vat_statement
-- APPROVED -> PAID. Aufrufer: Leitung FiBu (Stufe 2).
-- Stellt PAID dar als "ausgezahlt / Vorgang abgeschlossen".
-- ============================================================

CREATE OR ALTER PROCEDURE stored_proc.sp_pay_vat_statement
    @statement_id INT,
    @paid_by      VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @required_security_level INT;
    SELECT @required_security_level = next_status.SECURITY_LEVEL
    FROM dbo.T_CODE current_status
    JOIN dbo.T_CODE paid_status
      ON paid_status.CODE_TYPE = current_status.CODE_TYPE
     AND paid_status.CODE_NAME = 'PAID'
    JOIN dbo.T_CODE_NEXT next_status
      ON next_status.CODE_TYPE = current_status.CODE_TYPE
     AND next_status.CODE_ID = current_status.ID_CODE
     AND next_status.CODE_NEXT_ID = paid_status.ID_CODE
    WHERE current_status.CODE_TYPE = 'VAT_STATUS'
      AND current_status.CODE_NAME = 'APPROVED';

    IF @required_security_level IS NULL
    BEGIN
        THROW 50022, 'Statusuebergang APPROVED -> PAID ist nicht konfiguriert.', 1;
        RETURN;
    END

    DECLARE @actual_security_level INT = stored_func.fn_get_user_security_level(@paid_by);
    IF @actual_security_level IS NULL
    BEGIN
        THROW 50020, 'Unbekannter Benutzer fuer Umsatzsteuerabrechnung.', 1;
        RETURN;
    END

    IF @actual_security_level <> @required_security_level
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
            THROW 50011, 'Abrechnung ist nicht im Status APPROVED oder existiert nicht.', 1;
            RETURN;
        END

        UPDATE dbo.T_VAT_STATEMENT
        SET VAT_STATUS = 'PAID',
            CLOSED_BY  = @paid_by,
            CLOSED_AT  = GETDATE()
        WHERE VAT_STATEMENT_ID = @statement_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
