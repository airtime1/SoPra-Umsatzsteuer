-- ============================================================
-- 002_t_vat_statement_item.sql
-- Detailtabelle: einzelne Steuerfaelle einer Abrechnung.
-- Zielschema: dbo (gesperrt) — Skript an Architekt liefern.
-- ============================================================
-- Konventionen (siehe docs/entscheidungen/):
--   ADR-003: Belegdatum heisst SOURCE_INVOICE_DATE
--   ADR-005: Korrekturen als eigene Zeile mit IS_CORRECTION=1,
--            ORIGINAL_INVOICE_ID zeigt auf Ursprung, negativer TAX_AMOUNT

CREATE TABLE dbo.T_VAT_STATEMENT_ITEM (
    VAT_STATEMENT_ITEM_ID   INT IDENTITY(1,1) PRIMARY KEY,
    VAT_STATEMENT_ID        INT NOT NULL,
    SOURCE_TABLE            VARCHAR(50) NOT NULL,   -- z. B. 'T_INVOICE', 'T_SUPPLIER_INVOICE'
    SOURCE_INVOICE_ID       INT NOT NULL,
    SOURCE_INVOICE_DATE     DATE NOT NULL,
    TAX_AMOUNT              DECIMAL(12,2) NOT NULL,
    IS_CORRECTION           BIT NOT NULL DEFAULT 0,
    ORIGINAL_INVOICE_ID     INT NULL,               -- nur bei IS_CORRECTION=1 zwingend
    CREATED_BY              VARCHAR(50) NOT NULL,
    CREATED_AT              DATETIME    NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_VAT_ITEM_STATEMENT
        FOREIGN KEY (VAT_STATEMENT_ID)
        REFERENCES dbo.T_VAT_STATEMENT (VAT_STATEMENT_ID),

    CONSTRAINT CHK_VAT_ITEM_SOURCE_TABLE
        CHECK (SOURCE_TABLE IN ('T_INVOICE', 'T_SUPPLIER_INVOICE')),

    -- Wenn Korrektur, dann Ursprungsrechnung pflicht
    CONSTRAINT CHK_VAT_ITEM_CORRECTION_HAS_ORIGINAL
        CHECK (IS_CORRECTION = 0 OR ORIGINAL_INVOICE_ID IS NOT NULL),

    -- Doppelte Beruecksichtigung in DERSELBEN Abrechnung verhindern (F13)
    -- (Belegherkunft + ID + ggf. Korrektur-Flag macht jede Item-Zeile eindeutig
    --  innerhalb einer Abrechnung. Korrekturen koennen wiederholt vorkommen,
    --  aber dann mit unterschiedlicher Quell-ID).
    CONSTRAINT UQ_VAT_ITEM_PER_STATEMENT
        UNIQUE (VAT_STATEMENT_ID, SOURCE_TABLE, SOURCE_INVOICE_ID, IS_CORRECTION)
);

CREATE INDEX IX_VAT_ITEM_STATEMENT
    ON dbo.T_VAT_STATEMENT_ITEM (VAT_STATEMENT_ID);

CREATE INDEX IX_VAT_ITEM_SOURCE
    ON dbo.T_VAT_STATEMENT_ITEM (SOURCE_TABLE, SOURCE_INVOICE_ID);
