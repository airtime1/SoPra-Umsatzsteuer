-- ============================================================
-- stored_proc.sp_approve_vat_statement
-- DRAFT -> APPROVED. Aufrufer: CFO (Stufe 3).
-- ============================================================
-- Hinweis: Rollencheck koennte spaeter ueber T_USER.SECURITYLEVEL
-- oder T_CODE_NEXT.SECURITY_LEVEL erfolgen. Erstmal Trust on Caller.

CREATE OR ALTER PROCEDURE stored_proc.sp_approve_vat_statement
    @statement_id INT,
    @approved_by  VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

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
