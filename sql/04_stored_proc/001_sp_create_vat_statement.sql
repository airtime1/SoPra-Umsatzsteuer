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
--   4. Skonto-Korrektur (ADR-010): finalen Steuerbetrag aus
--      list_views.V_LIST_VAT_SKONTO ueber INVOICE_ID auf die
--      erfassten Rechnungs-Items schreiben (kein eigener Beleg,
--      sondern Ueberschreiben des urspruenglichen TAX_AMOUNT).
--   5. Summen + fn_calculate_vat_balance -> Kopf aktualisieren.
--   6. VAT_STATEMENT_ID zurueckgeben.
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
    DECLARE @creator_security_level INT = stored_func.fn_get_user_security_level(@created_by);

    IF @creator_security_level IS NULL
    BEGIN
        THROW 50020, 'Unbekannter Benutzer fuer Umsatzsteuerabrechnung.', 1;
        RETURN;
    END

    IF @creator_security_level <> 1
    BEGIN
        THROW 50021, 'Benutzer hat nicht die benoetigte Rolle fuer diese Aktion.', 1;
        RETURN;
    END

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
            @statement_id, SOURCE_TABLE, SOURCE_INVOICE_ID,
            SOURCE_INVOICE_DATE, TAX_AMOUNT,
            ISNULL(IS_CORRECTION, 0),
            ORIGINAL_INVOICE_ID,
            @created_by
        FROM list_views.V_LIST_OUTPUT_VAT
        WHERE SOURCE_INVOICE_DATE BETWEEN @period_start AND @period_end;

        -- 3) Items: Vorsteuer (Eingangsrechnungen)
        INSERT INTO dbo.T_VAT_STATEMENT_ITEM
            (VAT_STATEMENT_ID, SOURCE_TABLE, SOURCE_INVOICE_ID,
             SOURCE_INVOICE_DATE, TAX_AMOUNT, IS_CORRECTION,
             ORIGINAL_INVOICE_ID, CREATED_BY)
        SELECT
            @statement_id, SOURCE_TABLE, SOURCE_INVOICE_ID,
            SOURCE_INVOICE_DATE, TAX_AMOUNT,
            ISNULL(IS_CORRECTION, 0),
            ORIGINAL_INVOICE_ID,
            @created_by
        FROM list_views.V_LIST_INPUT_VAT
        WHERE SOURCE_INVOICE_DATE BETWEEN @period_start AND @period_end;

        -- 3b) Skonto-Korrektur (ADR-010, loest ADR-005 ab)
        -- G8 liefert je Rechnung den finalen Steuerbetrag nach Skonto.
        -- Wir ueberschreiben den urspruenglichen TAX_AMOUNT der bereits
        -- erfassten Rechnung (Match ueber INVOICE_ID) und markieren die
        -- Zeile als Korrektur. ORIGINAL_INVOICE_ID zeigt auf dieselbe
        -- Rechnung (erfuellt CHK_VAT_ITEM_CORRECTION_HAS_ORIGINAL).
        -- Periodensicher durch 7-Tage-Skontofrist + 10.-des-Folgemonats-
        -- Regel: bei Abrechnung der Periode sind alle Skonto-Zahlungen
        -- der enthaltenen Rechnungen bereits eingegangen.
        UPDATE itm
        SET itm.TAX_AMOUNT          = sk.TAX_AMOUNT,        -- finaler Betrag von G8 ersetzt den Rechnungsbetrag
            itm.IS_CORRECTION       = 1,                    -- markiert: hier hat Skonto gewirkt
            itm.ORIGINAL_INVOICE_ID = itm.SOURCE_INVOICE_ID -- zeigt auf dieselbe Rechnung (erfuellt Constraint)
        FROM dbo.T_VAT_STATEMENT_ITEM itm
        JOIN list_views.V_LIST_VAT_SKONTO sk
          ON sk.INVOICE_ID = itm.SOURCE_INVOICE_ID
        WHERE itm.VAT_STATEMENT_ID = @statement_id
          AND itm.SOURCE_TABLE = 'T_INVOICE'
          AND sk.IS_SKONTO = 'Y';

        -- 4) Summen + Saldo
        DECLARE @output_sum DECIMAL(12,2);
        DECLARE @input_sum  DECIMAL(12,2);

        -- Output = Ausgangsrechnungen (T_INVOICE). Skonto ist bereits in
        -- den TAX_AMOUNT dieser Zeilen eingerechnet (Schritt 3b), nicht
        -- als eigene Belegzeile.
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
