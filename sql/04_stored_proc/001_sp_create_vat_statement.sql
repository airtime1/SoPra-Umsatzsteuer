-- ============================================================
-- stored_proc.sp_create_vat_statement
-- Erzeugt (oder neu berechnet) eine Umsatzsteuerabrechnung
-- fuer die uebergebene Periode.
--
-- Ablauf:
--   1. fn_check_vat_period pruefen.
--   2. Vorhandener DRAFT -> Items loeschen, Kopf zuruecksetzen.
--      Sonst Kopf neu anlegen.
--   3. Items aus list_views.V_LIST_OUTPUT_VAT (USt) und
--      list_views.V_LIST_INPUT_VAT (VSt) einlesen, gefiltert auf
--      den Abrechnungsmonat.
--   4. Summen + fn_calculate_vat_balance -> Kopf aktualisieren.
--   5. VAT_STATEMENT_ID zurueckgeben.
-- ============================================================

CREATE OR ALTER PROCEDURE stored_proc.sp_create_vat_statement
    @vat_period  CHAR(7),
    @created_by  VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @check_result INT;
    SET @check_result = stored_func.fn_check_vat_period(@vat_period, CAST(GETDATE() AS DATE));

    IF @check_result = 1
    BEGIN
        THROW 50001, 'Periode noch nicht abrechenbar (frueher als 10. des Folgemonats).', 1;
        RETURN;
    END
    IF @check_result = 2
    BEGIN
        THROW 50002, 'Fuer diese Periode existiert bereits eine abgeschlossene Abrechnung.', 1;
        RETURN;
    END

    DECLARE @statement_id INT;
    DECLARE @period_start DATE = CAST(@vat_period + '-01' AS DATE);
    DECLARE @period_end   DATE = EOMONTH(@period_start);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1) Kopf: vorhandenen DRAFT resetten, sonst anlegen
        SELECT @statement_id = VAT_STATEMENT_ID
        FROM dbo.T_VAT_STATEMENT
        WHERE VAT_PERIOD = @vat_period
          AND VAT_STATUS = 'DRAFT';

        IF @statement_id IS NULL
        BEGIN
            INSERT INTO dbo.T_VAT_STATEMENT
                (VAT_PERIOD, VAT_STATUS, OUTPUT_VAT_TOTAL, INPUT_VAT_TOTAL,
                 VAT_BALANCE, VAT_TYPE, CREATED_BY, CREATED_AT)
            VALUES
                (@vat_period, 'DRAFT', 0, 0, 0, NULL, @created_by, GETDATE());
            SET @statement_id = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            DELETE FROM dbo.T_VAT_STATEMENT_ITEM
            WHERE VAT_STATEMENT_ID = @statement_id;

            UPDATE dbo.T_VAT_STATEMENT
            SET OUTPUT_VAT_TOTAL = 0,
                INPUT_VAT_TOTAL  = 0,
                VAT_BALANCE      = 0,
                VAT_TYPE         = NULL,
                CREATED_BY       = @created_by,
                CREATED_AT       = GETDATE()
            WHERE VAT_STATEMENT_ID = @statement_id;
        END

        -- 2) Items: Umsatzsteuer (Ausgangsrechnungen)
        INSERT INTO dbo.T_VAT_STATEMENT_ITEM
            (VAT_STATEMENT_ID, SOURCE_TABLE, SOURCE_INVOICE_ID,
             SOURCE_INVOICE_DATE, TAX_AMOUNT, IS_CORRECTION,
             ORIGINAL_INVOICE_ID, CREATED_BY)
        SELECT
            @statement_id, 'T_INVOICE', INVOICE_ID,
            INVOICE_DATE, TAX_AMOUNT,
            ISNULL(IS_CORRECTION, 0),
            ORIGINAL_INVOICE_ID,
            @created_by
        FROM list_views.V_LIST_OUTPUT_VAT
        WHERE INVOICE_DATE BETWEEN @period_start AND @period_end;

        -- 3) Items: Vorsteuer (Eingangsrechnungen)
        INSERT INTO dbo.T_VAT_STATEMENT_ITEM
            (VAT_STATEMENT_ID, SOURCE_TABLE, SOURCE_INVOICE_ID,
             SOURCE_INVOICE_DATE, TAX_AMOUNT, IS_CORRECTION,
             ORIGINAL_INVOICE_ID, CREATED_BY)
        SELECT
            @statement_id, 'T_SUPPLIER_INVOICE', INVOICE_ID,
            INVOICE_DATE, TAX_AMOUNT,
            0,            -- Korrekturen aus T_SUPPLIER_INVOICE: Klaerung Gruppe 4
            NULL,
            @created_by
        FROM list_views.V_LIST_INPUT_VAT
        WHERE INVOICE_DATE BETWEEN @period_start AND @period_end;

        -- 4) Summen + Saldo
        DECLARE @output_sum DECIMAL(12,2);
        DECLARE @input_sum  DECIMAL(12,2);

        SELECT @output_sum = ISNULL(SUM(TAX_AMOUNT), 0)
        FROM dbo.T_VAT_STATEMENT_ITEM
        WHERE VAT_STATEMENT_ID = @statement_id
          AND SOURCE_TABLE = 'T_INVOICE';

        SELECT @input_sum = ISNULL(SUM(TAX_AMOUNT), 0)
        FROM dbo.T_VAT_STATEMENT_ITEM
        WHERE VAT_STATEMENT_ID = @statement_id
          AND SOURCE_TABLE = 'T_SUPPLIER_INVOICE';

        DECLARE @balance DECIMAL(12,2);
        DECLARE @vat_type VARCHAR(20);

        SELECT @balance = VAT_BALANCE, @vat_type = VAT_TYPE
        FROM stored_func.fn_calculate_vat_balance(@output_sum, @input_sum);

        UPDATE dbo.T_VAT_STATEMENT
        SET OUTPUT_VAT_TOTAL = @output_sum,
            INPUT_VAT_TOTAL  = @input_sum,
            VAT_BALANCE      = @balance,
            VAT_TYPE         = @vat_type
        WHERE VAT_STATEMENT_ID = @statement_id;

        COMMIT TRANSACTION;

        SELECT @statement_id AS VAT_STATEMENT_ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
