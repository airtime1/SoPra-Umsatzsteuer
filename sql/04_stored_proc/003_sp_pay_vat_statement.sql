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
