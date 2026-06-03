-- ============================================================
-- stored_proc.SP_CREATE_VAT_STATEMENT
-- Erzeugt (oder neu berechnet) eine Umsatzsteuerabrechnung
-- fuer die uebergebene Periode.
--
-- Ablauf:
--   1. SF_CK_VAT_PERIOD pruefen
--      - 1: Fehler "Periode noch nicht abrechenbar"
--      - 2: Fehler "Periode bereits abgeschlossen"
--      - 0: Weiter
--   2. Falls vorhandener DRAFT existiert: Items loeschen, Kopf
--      auf 0 zuruecksetzen. Sonst Kopf anlegen.
--   3. Items aus list_views.OUTPUT_VAT_TOTAL (USt) und
--      list_views.INPUT_VAT_TOTAL (VSt) einlesen, gefiltert
--      auf den Abrechnungsmonat.
--   4. Summen + SF_CAL_VAT -> Kopf aktualisieren.
--   5. Erfolg: VAT_STATEMENT_ID zurueckgeben.
-- ============================================================

CREATE OR ALTER PROCEDURE stored_proc.SP_CREATE_VAT_STATEMENT
    @VAT_PERIOD CHAR(7),
    @CREATED_BY VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @check_result INT;
    SET @check_result = stored_func.SF_CK_VAT_PERIOD(@VAT_PERIOD, CAST(GETDATE() AS DATE));

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
    DECLARE @period_start DATE = CAST(@VAT_PERIOD + '-01' AS DATE);
    DECLARE @period_end   DATE = EOMONTH(@period_start);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1) Kopf: existierender DRAFT -> resetten, sonst anlegen
        SELECT @statement_id = VAT_STATEMENT_ID
        FROM dbo.T_VAT_STATEMENT
        WHERE VAT_PERIOD = @VAT_PERIOD
          AND VAT_STATUS = 'DRAFT';

        IF @statement_id IS NULL
        BEGIN
            INSERT INTO dbo.T_VAT_STATEMENT
                (VAT_PERIOD, VAT_STATUS, OUTPUT_VAT_TOTAL, INPUT_VAT_TOTAL,
                 VAT_BALANCE, VAT_TYPE, CREATED_BY, CREATED_AT)
            VALUES
                (@VAT_PERIOD, 'DRAFT', 0, 0, 0, NULL, @CREATED_BY, GETDATE());
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
                CREATED_BY       = @CREATED_BY,
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
            @CREATED_BY
        FROM list_views.OUTPUT_VAT_TOTAL
        WHERE INVOICE_DATE BETWEEN @period_start AND @period_end;

        -- 3) Items: Vorsteuer (Eingangsrechnungen)
        INSERT INTO dbo.T_VAT_STATEMENT_ITEM
            (VAT_STATEMENT_ID, SOURCE_TABLE, SOURCE_INVOICE_ID,
             SOURCE_INVOICE_DATE, TAX_AMOUNT, IS_CORRECTION,
             ORIGINAL_INVOICE_ID, CREATED_BY)
        SELECT
            @statement_id, 'T_SUPPLIER_INVOICE', INVOICE_ID,
            INVOICE_DATE, TAX_AMOUNT,
            0,            -- Korrekturen aus T_SUPPLIER_INVOICE: Klaerung mit Gruppe 4 offen
            NULL,
            @CREATED_BY
        FROM list_views.INPUT_VAT_TOTAL
        WHERE INVOICE_DATE BETWEEN @period_start AND @period_end;

        -- 4) Summen + Saldo
        DECLARE @output_sum DECIMAL(12,2);
        DECLARE @input_sum  DECIMAL(12,2);

        SELECT @output_sum = ISNULL(SUM(TAX_AMOUNT), 0)
        FROM dbo.T_VAT_STATEMENT_ITEM
        WHERE VAT_STATEMENT_ID = @statement_id AND SOURCE_TABLE = 'T_INVOICE';

        SELECT @input_sum = ISNULL(SUM(TAX_AMOUNT), 0)
        FROM dbo.T_VAT_STATEMENT_ITEM
        WHERE VAT_STATEMENT_ID = @statement_id AND SOURCE_TABLE = 'T_SUPPLIER_INVOICE';

        DECLARE @balance DECIMAL(12,2);
        DECLARE @vat_type VARCHAR(20);

        SELECT @balance = VAT_BALANCE, @vat_type = VAT_TYPE
        FROM stored_func.SF_CAL_VAT(@output_sum, @input_sum);

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
