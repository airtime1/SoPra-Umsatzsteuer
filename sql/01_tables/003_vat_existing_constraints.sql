-- ============================================================
-- 003_vat_existing_constraints.sql
-- Nachzieh-Skript fuer bestehende Sandbox-/Dev-Installationen.
-- Frische Installationen erhalten dieselben Regeln bereits aus
-- 001_t_vat_statement.sql und 002_t_vat_statement_item.sql.
-- ============================================================

IF OBJECT_ID('dbo.T_VAT_STATEMENT', 'U') IS NOT NULL
BEGIN
    IF EXISTS (
        SELECT 1
        FROM sys.check_constraints
        WHERE name = 'CHK_VAT_STATEMENT_PERIOD'
          AND parent_object_id = OBJECT_ID('dbo.T_VAT_STATEMENT')
    )
    BEGIN
        ALTER TABLE dbo.T_VAT_STATEMENT
            DROP CONSTRAINT CHK_VAT_STATEMENT_PERIOD;
    END;

    ALTER TABLE dbo.T_VAT_STATEMENT
        ADD CONSTRAINT CHK_VAT_STATEMENT_PERIOD
        CHECK (
            VAT_PERIOD LIKE '[0-9][0-9][0-9][0-9]-[0-1][0-9]'
            AND RIGHT(VAT_PERIOD, 2) BETWEEN '01' AND '12'
        );

    IF NOT EXISTS (
        SELECT 1
        FROM sys.key_constraints
        WHERE name = 'UQ_VAT_STATEMENT_PERIOD'
          AND parent_object_id = OBJECT_ID('dbo.T_VAT_STATEMENT')
    )
    BEGIN
        ALTER TABLE dbo.T_VAT_STATEMENT
            ADD CONSTRAINT UQ_VAT_STATEMENT_PERIOD UNIQUE (VAT_PERIOD);
    END;
END;

IF OBJECT_ID('dbo.T_VAT_STATEMENT_ITEM', 'U') IS NOT NULL
BEGIN
    IF EXISTS (
        SELECT 1
        FROM sys.check_constraints
        WHERE name = 'CHK_VAT_ITEM_SOURCE_TABLE'
          AND parent_object_id = OBJECT_ID('dbo.T_VAT_STATEMENT_ITEM')
    )
    BEGIN
        ALTER TABLE dbo.T_VAT_STATEMENT_ITEM
            DROP CONSTRAINT CHK_VAT_ITEM_SOURCE_TABLE;
    END;

    ALTER TABLE dbo.T_VAT_STATEMENT_ITEM
        ADD CONSTRAINT CHK_VAT_ITEM_SOURCE_TABLE
        CHECK (SOURCE_TABLE IN ('T_INVOICE', 'T_SUPPLIER_INVOICE', 'T_PAYMENT_RECEIPT'));
END;
