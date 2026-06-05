-- ============================================================
-- 001_t_vat_statement.sql
-- Kopftabelle: eine Zeile = eine monatliche Umsatzsteuerabrechnung.
-- Zielschema: dbo (gesperrt) — Skript an Architekt liefern.
-- ============================================================
-- Konventionen (siehe docs/entscheidungen/):
--   ADR-001: Status DRAFT/APPROVED/PAID
--   ADR-003: Spalte heißt VAT_STATUS (nicht STATUS)
--   ADR-004: VAT_BALANCE >= 0 (Absolutbetrag), VAT_TYPE klassifiziert

CREATE TABLE dbo.T_VAT_STATEMENT (
    VAT_STATEMENT_ID    INT IDENTITY(1,1) PRIMARY KEY,
    VAT_PERIOD          CHAR(7) NOT NULL,                  -- Format YYYY-MM
    VAT_STATUS          VARCHAR(20) NOT NULL,              -- DRAFT, APPROVED, PAID
    OUTPUT_VAT_TOTAL    DECIMAL(12,2) NOT NULL DEFAULT 0,  -- Summe Umsatzsteuer
    INPUT_VAT_TOTAL     DECIMAL(12,2) NOT NULL DEFAULT 0,  -- Summe Vorsteuer
    VAT_BALANCE         DECIMAL(12,2) NOT NULL DEFAULT 0,  -- Absolutbetrag des Saldos
    VAT_TYPE            VARCHAR(20) NULL,                  -- ZAHLLAST, UEBERHANG, NEUTRAL

    CREATED_BY          VARCHAR(50) NOT NULL,
    CREATED_AT          DATETIME    NOT NULL DEFAULT GETDATE(),
    APPROVED_BY         VARCHAR(50) NULL,
    APPROVED_AT         DATETIME    NULL,
    CLOSED_BY           VARCHAR(50) NULL,
    CLOSED_AT           DATETIME    NULL,

    -- Format YYYY-MM erzwingen
    CONSTRAINT CHK_VAT_STATEMENT_PERIOD
        CHECK (VAT_PERIOD LIKE '[0-9][0-9][0-9][0-9]-[0-1][0-9]'),

    -- Status nur erlaubte Werte
    CONSTRAINT CHK_VAT_STATEMENT_STATUS
        CHECK (VAT_STATUS IN ('DRAFT', 'APPROVED', 'PAID')),

    -- Saldo immer >= 0 (Absolutbetrag)
    CONSTRAINT CHK_VAT_STATEMENT_BALANCE_NONNEG
        CHECK (VAT_BALANCE >= 0),

    -- Typ nur erlaubte Werte (oder NULL solange im DRAFT)
    CONSTRAINT CHK_VAT_STATEMENT_TYPE
        CHECK (VAT_TYPE IN ('ZAHLLAST', 'UEBERHANG', 'NEUTRAL') OR VAT_TYPE IS NULL),

    -- Pro Periode nur eine finale Abrechnung (F14): hier nicht als UNIQUE,
    -- weil der Reset auf DRAFT mehrere Versuche erlauben muss. Eindeutigkeit
    -- wird in fn_check_vat_period / sp_create_vat_statement geprueft.

    -- Konsistenz: wer APPROVED ist, hat APPROVED_BY/_AT gesetzt
    CONSTRAINT CHK_VAT_STATEMENT_APPROVED_FIELDS
        CHECK (
            (VAT_STATUS IN ('APPROVED', 'PAID') AND APPROVED_BY IS NOT NULL AND APPROVED_AT IS NOT NULL)
            OR VAT_STATUS = 'DRAFT'
        ),

    -- Konsistenz: wer PAID ist, hat CLOSED_BY/_AT gesetzt
    CONSTRAINT CHK_VAT_STATEMENT_CLOSED_FIELDS
        CHECK (
            (VAT_STATUS = 'PAID' AND CLOSED_BY IS NOT NULL AND CLOSED_AT IS NOT NULL)
            OR VAT_STATUS IN ('DRAFT', 'APPROVED')
        )
);

-- Index für die häufigste Filterung (Periode)
CREATE INDEX IX_VAT_STATEMENT_PERIOD
    ON dbo.T_VAT_STATEMENT (VAT_PERIOD);
