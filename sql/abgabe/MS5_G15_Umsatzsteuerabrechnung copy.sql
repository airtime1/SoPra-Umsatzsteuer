-- A) Schemas anlegen
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'list_views')
    EXEC sys.sp_executesql N'CREATE SCHEMA list_views';
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'stored_func')
    EXEC sys.sp_executesql N'CREATE SCHEMA stored_func';
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'stored_proc')
    EXEC sys.sp_executesql N'CREATE SCHEMA stored_proc';
GO


-- B) list_views.* — Lese-Views


-- Status-Werteliste für die Umsatzsteuerabrechnung.
-- Die Werte liegen zentral in dbo.T_CODE und werden hier für App und Tests in einer kleinen View bereitgestellt.
CREATE OR ALTER VIEW list_views.LOV_VAT_STATUS
AS
SELECT
    ID_CODE     AS CODE_ID,
    CODE_NAME   AS VAT_STATUS
FROM dbo.T_CODE
WHERE CODE_TYPE = 'VAT_STATUS';
GO



-- Gemeinsame View auf alle Quellen der Umsatzsteuer.
-- Die Partnergruppen liefern unterschiedliche Views, deshalb bringen wir die Daten hier auf ein einheitliches Format für die Abrechnung.
CREATE OR ALTER VIEW list_views.V_LIST_OUTPUT_VAT
AS

-- Gruppe 7: Eingangsrechnungen
-- aktuell die einzige aktive Quelle.
-- Die gelieferten deutschen Spaltennamen werden hier auf unsere interne Struktur gemappt.
SELECT
    CAST('T_INVOICE' AS VARCHAR(50))   AS SOURCE_TABLE,
    g7.INVOICE_ID                      AS SOURCE_INVOICE_ID,
    g7.RechnungsDatum                  AS SOURCE_INVOICE_DATE,
    g7.INVOICE_ID                      AS INVOICE_ID,
    g7.RechnungsDatum                  AS INVOICE_DATE,
    g7.BetragUstEUR                    AS TAX_AMOUNT,
    CAST(0 AS BIT)                     AS IS_CORRECTION,
    CAST(NULL AS INT)                  AS ORIGINAL_INVOICE_ID
FROM list_views.V_LIST_G07_INVOICE g7



-- Platzhalter fuer eine noch nicht vollständig gelieferte Partnerquelle.
-- Der Block hat schon die richtige Spaltenstruktur, liefert aber bewusst keine Zeilen.

UNION ALL

-- Gruppe 9: Barrechnung Rosenheim 
SELECT
    CAST('T_INVOICE' AS VARCHAR(50))   AS SOURCE_TABLE,
    CAST(NULL AS INT)                  AS SOURCE_INVOICE_ID,
    CAST(NULL AS DATE)                 AS SOURCE_INVOICE_DATE,
    CAST(NULL AS INT)                  AS INVOICE_ID,
    CAST(NULL AS DATE)                 AS INVOICE_DATE,
    CAST(NULL AS DECIMAL(12,2))        AS TAX_AMOUNT,
    CAST(0 AS BIT)                     AS IS_CORRECTION,
    CAST(NULL AS INT)                  AS ORIGINAL_INVOICE_ID
WHERE 1 = 0

UNION ALL

-- Gruppe 10: Barrechnung Freiburg 

SELECT
    CAST('T_INVOICE' AS VARCHAR(50))   AS SOURCE_TABLE,
    CAST(NULL AS INT)                  AS SOURCE_INVOICE_ID,
    CAST(NULL AS DATE)                 AS SOURCE_INVOICE_DATE,
    CAST(NULL AS INT)                  AS INVOICE_ID,
    CAST(NULL AS DATE)                 AS INVOICE_DATE,
    CAST(NULL AS DECIMAL(12,2))        AS TAX_AMOUNT,
    CAST(0 AS BIT)                     AS IS_CORRECTION,
    CAST(NULL AS INT)                  AS ORIGINAL_INVOICE_ID
WHERE 1 = 0


-- Gruppe 8: Zahlungseingänge
-- Skonto-Korrekturen sollen später als eigene negative Zeilen einfliessen.
-- Bis die benötigte Steuerkorrektur-Spalte geliefert wird, bleibt der Block ein Stub.

UNION ALL

SELECT
    CAST('T_PAYMENT_RECEIPT' AS VARCHAR(50)) AS SOURCE_TABLE,
    CAST(NULL AS INT)                        AS SOURCE_INVOICE_ID,
    CAST(NULL AS DATE)                       AS SOURCE_INVOICE_DATE,
    CAST(NULL AS INT)                        AS INVOICE_ID,
    CAST(NULL AS DATE)                       AS INVOICE_DATE,
    CAST(NULL AS DECIMAL(12,2))              AS TAX_AMOUNT,
    CAST(1 AS BIT)                           AS IS_CORRECTION,
    CAST(NULL AS INT)                        AS ORIGINAL_INVOICE_ID
WHERE 1 = 0;
GO


-- list_views.V_LIST_INPUT_VAT — Vorsteuer aus G4 (STUB)

CREATE OR ALTER VIEW list_views.V_LIST_INPUT_VAT
AS

-- Gruppe 4: Wareneingänge 

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


-- list_views.V_LIST_VAT_STATEMENT — Anzeige-View Abrechnungskoepfe.


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


-- list_views.V_LIST_VAT_STATEMENT_ITEM — Anzeige-View Beleg-Items.

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


-- list_views.V_LIST_VAT_USER — Login + Rollen-Demo (keine Passwoerter).

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




-- C) stored_func.fn_* — Stored Functions

-- stored_func.fn_check_vat_period

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


-- stored_func.fn_calculate_vat_balance

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


-- stored_func.fn_get_user_security_level


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




-- D) stored_proc.sp_* — Stored Procedures (Statusworkflow)

-- stored_proc.sp_create_vat_statement — Anlegen / Neuberechnen einer Periode.

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

        DECLARE @output_sum DECIMAL(12,2);
        DECLARE @input_sum  DECIMAL(12,2);

        SELECT @output_sum = ISNULL(SUM(TAX_AMOUNT), 0)
        FROM dbo.T_VAT_STATEMENT_ITEM
        WHERE VAT_STATEMENT_ID = @statement_id
          AND SOURCE_TABLE IN ('T_INVOICE', 'T_PAYMENT_RECEIPT');

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

-- stored_proc.sp_approve_vat_statement — DRAFT -> APPROVED (CFO, Stufe 3).
-- Transitionspruefung ueber zentrale dbo.fn_chk_status_folge.

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


-- stored_proc.sp_pay_vat_statement — APPROVED -> PAID (Leitung FiBu, Stufe 2).
-- Transitionspruefung ueber zentrale dbo.fn_chk_status_folge.

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


-- stored_proc.sp_reject_vat_statement — APPROVED -> DRAFT (CFO, Stufe 3).
-- Transitionspruefung ueber zentrale dbo.fn_chk_status_folge.
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
