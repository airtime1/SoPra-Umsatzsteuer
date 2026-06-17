-- ============================================================================
-- MS5 Abgabe-Bundle — Gruppe 15 — Umsatzsteuerabrechnung
-- Stand: 2026-06-16
-- ============================================================================
-- Dieses Skript baut alle Objekte von Gruppe 15 auf, die in eigenen
-- Schemata liegen (list_views, stored_func, stored_proc).
--
-- INHALT:
--   A) Schemas anlegen, falls nicht vorhanden
--   B) list_views.* — Anzeige- und Konsumenten-Views
--   C) stored_func.fn_* — Stored Functions
--   D) stored_proc.sp_* — Stored Procedures (Statusworkflow)
--
-- AUSFUEHRUNG:
--   - In SSMS / Azure Data Studio / VS Code MSSQL gegen die Ziel-DB oeffnen.
--   - Skript komplett ausfuehren. Batch-Trenner ist GO.
--
-- VORAUSSETZUNG:
--   Vor diesem Bundle muss der dbo-Anteil vom Datenbank-Architekten
--   bereitgestellt sein (siehe MS5_G15_ARCHITEKT_dbo.sql):
--     - T_CODE-Eintraege fuer VAT_STATUS
--     - dbo.T_CODE_NEXT-Eintraege fuer die VAT_STATUS-Uebergaenge
--     - dbo.T_VAT_STATEMENT, dbo.T_VAT_STATEMENT_ITEM
--   Ausserdem nutzen die Status-Procedures die zentrale Architekten-
--   Function dbo.fn_chk_status_folge (in ERPDEV26S vorhanden). Sie prueft
--   anhand dbo.T_CODE_NEXT, ob ein Statusuebergang erlaubt ist.
--
-- ARCHITEKTUR-LEITLINIE (siehe ADR-008 / ADR-010):
--   Gruppe 15 berechnet keine Steuerbetraege. Wir konsumieren
--   Partner-Lese-Views und lesen direkt TAX_AMOUNT.
--   Quellen:
--     - list_views.V_LIST_G07_INVOICE          (ALLE Ausgangsrechnungen ueber
--                                                T_INVOICE; G9 Bar Rosenberg und
--                                                G10 Bar Freiburg laufen mit)
--     - list_views.V_LIST_G08_PAYMENT_RECEIPT  (finaler Steuerbetrag nach
--                                                Skonto, ueberschreibt, STUB)
--     - list_views.V_LIST_G04_SUPPLIER_INVOICE (Eingangsrechnungen, STUB)
--
-- IDEMPOTENZ:
--   - Schemas: per IF-NOT-EXISTS-Wrapper, kein Crash bei zweitem Lauf
--   - Views / Funcs / Procs: CREATE OR ALTER
-- ============================================================================



-- ============================================================================
-- A) Schemas anlegen
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'list_views')
    EXEC sys.sp_executesql N'CREATE SCHEMA list_views';
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'stored_func')
    EXEC sys.sp_executesql N'CREATE SCHEMA stored_func';
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'stored_proc')
    EXEC sys.sp_executesql N'CREATE SCHEMA stored_proc';
GO



-- ============================================================================
-- B) list_views.* — Lese-Views
-- ============================================================================

-- ----------------------------------------------------------------------------
-- list_views.LOV_VAT_STATUS — Werteliste der VAT-Status fuer das Frontend.
-- Quelle: sql/02_views/001_lov_vat_status.sql
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW list_views.LOV_VAT_STATUS
AS
SELECT
    ID_CODE     AS CODE_ID,
    CODE_NAME   AS VAT_STATUS
FROM dbo.T_CODE
WHERE CODE_TYPE = 'VAT_STATUS';
GO

-- ----------------------------------------------------------------------------
-- list_views.V_LIST_OUTPUT_VAT — Umsatzsteuer aus allen Ausgangsrechnungen.
-- Quelle: sql/02_views/002_v_list_output_vat.sql
-- ----------------------------------------------------------------------------
-- Eine Quelle (Beschluss 2026-06-16): G7 stellt mit V_LIST_G07_INVOICE die
-- gemeinsame Rechnungs-View ueber dbo.T_INVOICE bereit. G9 (Bar Rosenberg) und
-- G10 (Bar Freiburg) schreiben ueber dieselbe T_INVOICE und werden darueber
-- mitgeliefert -> kein eigener G9/G10-Block, keine UNIONs.
-- Skonto laeuft nicht mehr hier, sondern als Ueberschreiben in
-- sp_create_vat_statement (ADR-010, Quelle list_views.V_LIST_VAT_SKONTO).
-- OFFEN (Bring-Schuld G7, Issue #27/#28): V_LIST_G07_INVOICE liefert aktuell
-- nur Fernabsatz (INNER JOINs auf Angebot->Auftrag->Lieferung); B2C-Bar-
-- verkaeufe fehlen noch (Diagnose 2026-06-16: 78 von 156 G9-Rechnungen).
CREATE OR ALTER VIEW list_views.V_LIST_OUTPUT_VAT
AS
SELECT
    CAST('T_INVOICE' AS VARCHAR(50))   AS SOURCE_TABLE,
    g7.INVOICE_ID                      AS SOURCE_INVOICE_ID,
    g7.RechnungsDatum                  AS SOURCE_INVOICE_DATE,
    g7.INVOICE_ID                      AS INVOICE_ID,
    g7.RechnungsDatum                  AS INVOICE_DATE,
    g7.BetragUstEUR                    AS TAX_AMOUNT,
    CAST(0 AS BIT)                     AS IS_CORRECTION,
    CAST(NULL AS INT)                  AS ORIGINAL_INVOICE_ID
FROM list_views.V_LIST_G07_INVOICE g7;
GO

-- ----------------------------------------------------------------------------
-- list_views.V_LIST_VAT_SKONTO — finaler Steuerbetrag je Rechnung aus G8.
-- Quelle: sql/02_views/007_v_list_vat_skonto.sql
-- ----------------------------------------------------------------------------
-- G8 liefert je Zahlungseingang den FINALEN Steuerbetrag der Rechnung nach
-- Skonto. sp_create_vat_statement ueberschreibt damit den urspruenglichen
-- TAX_AMOUNT (Match ueber INVOICE_ID), wenn IS_SKONTO = 'Y' (ADR-010).
-- STUB (WHERE 1 = 0): G8 liefert finalen TAX_AMOUNT / IS_SKONTO noch nicht
-- (Issue #26). Aktivieren bei Lieferung:
--   SELECT g8.INVOICE_ID, g8.TAX_AMOUNT, g8.IS_SKONTO
--   FROM list_views.V_LIST_G08_PAYMENT_RECEIPT g8
--   WHERE ISNULL(g8.STORNO_YN, 'N') <> 'Y'
CREATE OR ALTER VIEW list_views.V_LIST_VAT_SKONTO
AS
SELECT
    CAST(NULL AS INT)            AS INVOICE_ID,
    CAST(NULL AS DECIMAL(12,2))  AS TAX_AMOUNT,
    CAST(NULL AS CHAR(1))        AS IS_SKONTO
WHERE 1 = 0;
GO

-- ----------------------------------------------------------------------------
-- list_views.V_LIST_INPUT_VAT — Vorsteuer aus G4 (STUB)
-- Quelle: sql/02_views/003_v_list_input_vat.sql
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW list_views.V_LIST_INPUT_VAT
AS

-- QUELLE 1/1: G4 Wareneingaenge (STUB - View existiert nicht)
-- Aktivieren bei Lieferung:
--   SELECT CAST('T_SUPPLIER_INVOICE' AS VARCHAR(50)),
--          g4.INVOICE_ID, g4.INVOICE_DATE,
--          g4.INVOICE_ID, g4.INVOICE_DATE, g4.TAX_AMOUNT,
--          CAST(0 AS BIT), CAST(NULL AS INT)
--   FROM list_views.V_LIST_G04_SUPPLIER_INVOICE g4
SELECT
    CAST('T_SUPPLIER_INVOICE' AS VARCHAR(50)) AS SOURCE_TABLE,
    CAST(NULL AS INT)                         AS SOURCE_INVOICE_ID,
    CAST(NULL AS DATE)                        AS SOURCE_INVOICE_DATE,
    CAST(NULL AS INT)                         AS INVOICE_ID,
    CAST(NULL AS DATE)                        AS INVOICE_DATE,
    CAST(NULL AS DECIMAL(12,2))               AS TAX_AMOUNT,
    CAST(0 AS BIT)                            AS IS_CORRECTION,
    CAST(NULL AS INT)                         AS ORIGINAL_INVOICE_ID
WHERE 1 = 0;
GO

-- ----------------------------------------------------------------------------
-- list_views.V_LIST_VAT_STATEMENT — Anzeige-View Abrechnungskoepfe.
-- Quelle: sql/02_views/004_v_list_vat_statement.sql
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW list_views.V_LIST_VAT_STATEMENT
AS
SELECT
    VAT_STATEMENT_ID,
    VAT_PERIOD,
    VAT_STATUS,
    OUTPUT_VAT_TOTAL,
    INPUT_VAT_TOTAL,
    VAT_BALANCE,
    VAT_TYPE,
    CREATED_BY,
    CREATED_AT,
    APPROVED_BY,
    APPROVED_AT,
    CLOSED_BY,
    CLOSED_AT
FROM dbo.T_VAT_STATEMENT;
GO

-- ----------------------------------------------------------------------------
-- list_views.V_LIST_VAT_STATEMENT_ITEM — Anzeige-View Beleg-Items.
-- Quelle: sql/02_views/005_v_list_vat_statement_item.sql
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW list_views.V_LIST_VAT_STATEMENT_ITEM
AS
SELECT
    VAT_STATEMENT_ITEM_ID,
    VAT_STATEMENT_ID,
    SOURCE_TABLE,
    SOURCE_INVOICE_ID,
    SOURCE_INVOICE_DATE,
    TAX_AMOUNT,
    IS_CORRECTION,
    ORIGINAL_INVOICE_ID,
    CREATED_BY,
    CREATED_AT
FROM dbo.T_VAT_STATEMENT_ITEM;
GO

-- ----------------------------------------------------------------------------
-- list_views.V_LIST_VAT_USER — Login + Rollen-Demo (keine Passwoerter).
-- Quelle: sql/02_views/006_v_list_vat_user.sql
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW list_views.V_LIST_VAT_USER
AS
SELECT
    USERNAME,
    SECURITYLEVEL,
    CASE SECURITYLEVEL
        WHEN 1 THEN 'Sachbearbeiter'
        WHEN 2 THEN 'Leitung FiBu'
        WHEN 3 THEN 'CFO'
        ELSE 'Unbekannt'
    END AS VAT_ROLE
FROM dbo.T_USER;
GO



-- ============================================================================
-- C) stored_func.fn_* — Stored Functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- stored_func.fn_check_vat_period
-- Quelle: sql/03_stored_func/001_fn_check_vat_period.sql
-- ----------------------------------------------------------------------------
CREATE OR ALTER FUNCTION stored_func.fn_check_vat_period
(
    @vat_period  CHAR(7),     -- 'YYYY-MM'
    @check_date  DATE         -- i. d. R. CAST(GETDATE() AS DATE)
)
RETURNS INT
AS
BEGIN
    DECLARE @result INT;

    DECLARE @period_start DATE = TRY_CAST(@vat_period + '-01' AS DATE);
    DECLARE @earliest     DATE = DATEADD(DAY, 9, DATEADD(MONTH, 1, @period_start));

    IF @period_start IS NULL OR @check_date < @earliest
    BEGIN
        SET @result = 1;
        RETURN @result;
    END

    DECLARE @existing_status VARCHAR(20);

    SELECT TOP 1 @existing_status = VAT_STATUS
    FROM dbo.T_VAT_STATEMENT
    WHERE VAT_PERIOD = @vat_period;

    IF @existing_status IS NULL
        SET @result = 0;
    ELSE IF @existing_status = 'DRAFT'
        SET @result = 0;
    ELSE
        SET @result = 2;

    RETURN @result;
END;
GO

-- ----------------------------------------------------------------------------
-- stored_func.fn_calculate_vat_balance
-- Quelle: sql/03_stored_func/002_fn_calculate_vat_balance.sql
-- ----------------------------------------------------------------------------
CREATE OR ALTER FUNCTION stored_func.fn_calculate_vat_balance
(
    @output_vat_total DECIMAL(12,2),
    @input_vat_total  DECIMAL(12,2)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        CASE
            WHEN @output_vat_total >= @input_vat_total
                THEN @output_vat_total - @input_vat_total
            ELSE @input_vat_total - @output_vat_total
        END AS VAT_BALANCE,
        CASE
            WHEN @output_vat_total >  @input_vat_total THEN 'ZAHLLAST'
            WHEN @output_vat_total <  @input_vat_total THEN 'UEBERHANG'
            ELSE 'NEUTRAL'
        END AS VAT_TYPE
);
GO

-- ----------------------------------------------------------------------------
-- stored_func.fn_get_user_security_level
-- Quelle: sql/03_stored_func/003_fn_get_user_security_level.sql
-- ----------------------------------------------------------------------------
CREATE OR ALTER FUNCTION stored_func.fn_get_user_security_level
(
    @username VARCHAR(50)
)
RETURNS INT
AS
BEGIN
    DECLARE @security_level INT;

    SELECT TOP 1 @security_level = SECURITYLEVEL
    FROM dbo.T_USER
    WHERE USERNAME = @username;

    RETURN @security_level;
END;
GO



-- ============================================================================
-- D) stored_proc.sp_* — Stored Procedures (Statusworkflow)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- stored_proc.sp_create_vat_statement — Anlegen / Neuberechnen einer Periode.
-- Quelle: sql/04_stored_proc/001_sp_create_vat_statement.sql
-- ----------------------------------------------------------------------------
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

        -- Skonto-Korrektur (ADR-010, loest ADR-005 ab): finalen Steuerbetrag
        -- aus G8 auf die erfasste Rechnung schreiben (Match ueber INVOICE_ID),
        -- IS_CORRECTION setzen, ORIGINAL_INVOICE_ID = SOURCE_INVOICE_ID
        -- (erfuellt CHK_VAT_ITEM_CORRECTION_HAS_ORIGINAL). Periodensicher durch
        -- 7-Tage-Skontofrist + 10.-des-Folgemonats-Regel.
        UPDATE itm
        SET itm.TAX_AMOUNT          = sk.TAX_AMOUNT,
            itm.IS_CORRECTION       = 1,
            itm.ORIGINAL_INVOICE_ID = itm.SOURCE_INVOICE_ID
        FROM dbo.T_VAT_STATEMENT_ITEM itm
        JOIN list_views.V_LIST_VAT_SKONTO sk
          ON sk.INVOICE_ID = itm.SOURCE_INVOICE_ID
        WHERE itm.VAT_STATEMENT_ID = @statement_id
          AND itm.SOURCE_TABLE = 'T_INVOICE'
          AND sk.IS_SKONTO = 'Y';

        DECLARE @output_sum DECIMAL(12,2);
        DECLARE @input_sum  DECIMAL(12,2);

        -- Output = Ausgangsrechnungen (T_INVOICE); Skonto ist bereits in deren
        -- TAX_AMOUNT eingerechnet, keine eigene Belegzeile.
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
GO

-- ----------------------------------------------------------------------------
-- stored_proc.sp_approve_vat_statement — DRAFT -> APPROVED (CFO, Stufe 3).
-- Transitionspruefung ueber zentrale dbo.fn_chk_status_folge.
-- Quelle: sql/04_stored_proc/002_sp_approve_vat_statement.sql
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE stored_proc.sp_approve_vat_statement
    @statement_id INT,
    @approved_by  VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @old_id INT = (SELECT ID_CODE FROM dbo.T_CODE WHERE CODE_TYPE = 'VAT_STATUS' AND CODE_NAME = 'DRAFT');
    DECLARE @new_id INT = (SELECT ID_CODE FROM dbo.T_CODE WHERE CODE_TYPE = 'VAT_STATUS' AND CODE_NAME = 'APPROVED');

    IF @old_id IS NULL OR @new_id IS NULL
    BEGIN
        THROW 50023, 'VAT_STATUS-Codewerte fehlen in dbo.T_CODE.', 1;
        RETURN;
    END

    DECLARE @folge_check NVARCHAR(200) = dbo.fn_chk_status_folge(@old_id, @new_id);
    IF @folge_check <> 'OK'
    BEGIN
        THROW 50022, 'Statusuebergang DRAFT -> APPROVED ist nicht erlaubt (dbo.fn_chk_status_folge).', 1;
        RETURN;
    END

    DECLARE @required_security_level INT = (
        SELECT SECURITY_LEVEL FROM dbo.T_CODE_NEXT
        WHERE CODE_ID = @old_id AND CODE_NEXT_ID = @new_id
    );

    DECLARE @actual_security_level INT = stored_func.fn_get_user_security_level(@approved_by);
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
GO

-- ----------------------------------------------------------------------------
-- stored_proc.sp_pay_vat_statement — APPROVED -> PAID (Leitung FiBu, Stufe 2).
-- Transitionspruefung ueber zentrale dbo.fn_chk_status_folge.
-- Quelle: sql/04_stored_proc/003_sp_pay_vat_statement.sql
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE stored_proc.sp_pay_vat_statement
    @statement_id INT,
    @paid_by      VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @old_id INT = (SELECT ID_CODE FROM dbo.T_CODE WHERE CODE_TYPE = 'VAT_STATUS' AND CODE_NAME = 'APPROVED');
    DECLARE @new_id INT = (SELECT ID_CODE FROM dbo.T_CODE WHERE CODE_TYPE = 'VAT_STATUS' AND CODE_NAME = 'PAID');

    IF @old_id IS NULL OR @new_id IS NULL
    BEGIN
        THROW 50023, 'VAT_STATUS-Codewerte fehlen in dbo.T_CODE.', 1;
        RETURN;
    END

    DECLARE @folge_check NVARCHAR(200) = dbo.fn_chk_status_folge(@old_id, @new_id);
    IF @folge_check <> 'OK'
    BEGIN
        THROW 50022, 'Statusuebergang APPROVED -> PAID ist nicht erlaubt (dbo.fn_chk_status_folge).', 1;
        RETURN;
    END

    DECLARE @required_security_level INT = (
        SELECT SECURITY_LEVEL FROM dbo.T_CODE_NEXT
        WHERE CODE_ID = @old_id AND CODE_NEXT_ID = @new_id
    );

    DECLARE @actual_security_level INT = stored_func.fn_get_user_security_level(@paid_by);
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
GO

-- ----------------------------------------------------------------------------
-- stored_proc.sp_reject_vat_statement — APPROVED -> DRAFT (CFO, Stufe 3).
-- Transitionspruefung ueber zentrale dbo.fn_chk_status_folge.
-- Quelle: sql/04_stored_proc/004_sp_reject_vat_statement.sql
-- ----------------------------------------------------------------------------
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
GO



-- ============================================================================
-- ENDE — MS5 Abgabe-Bundle Gruppe 15
-- ----------------------------------------------------------------------------
-- Aktivierung der Stub-Quellen nach Partner-Lieferung:
--   - G7 erweitert V_LIST_G07_INVOICE auf ALLE T_INVOICE-Ausgangsrechnungen
--       (inkl. B2C G9/G10 ohne Angebot->Auftrag->Lieferung-Kette).
--       -> V_LIST_OUTPUT_VAT bleibt unveraendert, liefert dann automatisch alle.
--   - G4 ergaenzt list_views.V_LIST_G04_SUPPLIER_INVOICE
--       -> Stub-Block in V_LIST_INPUT_VAT durch aktiven SELECT ersetzen.
--   - G8 ergaenzt finalen TAX_AMOUNT + IS_SKONTO in V_LIST_G08_PAYMENT_RECEIPT
--       -> Stub in V_LIST_VAT_SKONTO durch aktiven SELECT ersetzen (ADR-010).
-- ============================================================================
