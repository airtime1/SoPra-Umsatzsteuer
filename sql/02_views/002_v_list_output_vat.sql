-- ============================================================
-- list_views.V_LIST_OUTPUT_VAT
-- Alle umsatzsteuerrelevanten Belege fuer eine Periode:
--   - Ausgangsrechnungen aus G7 (Fernabsatz)        AKTIV
--   - Ausgangsrechnungen aus G9 (Bar Rosenberg)     STUB
--   - Ausgangsrechnungen aus G10 (Bar Freiburg)     STUB
--   - Skonto-Korrekturen aus G8 (Zahlungseingaenge) STUB
-- ============================================================
-- Konvention (ADR-008): G15 berechnet keine Steuerbetraege.
-- Wir konsumieren TAX_AMOUNT / TAX_CORRECTION_AMOUNT
-- direkt aus der jeweiligen Partner-Lese-View.
-- SOURCE_TABLE ist die fachliche Kategorie, nicht der View-Name:
--   T_INVOICE          = Ausgangsrechnung (G7, G9, G10)
--   T_PAYMENT_RECEIPT  = Skonto-Korrektur (G8)
-- Stubs liefern Spalten mit korrekter Signatur, aber 0 Zeilen
-- (WHERE 1 = 0). Aktivierung = auskommentierten Block einsetzen.

CREATE OR ALTER VIEW list_views.V_LIST_OUTPUT_VAT
AS

-- QUELLE 1/4: G7 Fernabsatz (AKTIV)
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

UNION ALL

-- QUELLE 2/4: G9 Bar Rosenberg (STUB - View existiert, TAX_AMOUNT fehlt)
-- Aktivieren bei Lieferung von G9:
--   SELECT
--       CAST('T_INVOICE' AS VARCHAR(50)), g9.INVOICE_ID, g9.INVOICE_DATE,
--       g9.INVOICE_ID, g9.INVOICE_DATE, g9.TAX_AMOUNT,
--       CAST(0 AS BIT), CAST(NULL AS INT)
--   FROM list_views.V_LIST_G09_INVOICE_TAX_B2C g9
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

-- QUELLE 3/4: G10 Bar Freiburg (STUB - V_LIST_G10_* existiert nicht)
-- Aktivieren bei Lieferung von G10, erwarteter View-Name analog zu G9:
--   SELECT
--       CAST('T_INVOICE' AS VARCHAR(50)), g10.INVOICE_ID, g10.INVOICE_DATE,
--       g10.INVOICE_ID, g10.INVOICE_DATE, g10.TAX_AMOUNT,
--       CAST(0 AS BIT), CAST(NULL AS INT)
--   FROM list_views.V_LIST_G10_INVOICE_BAR_FREIBURG g10
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

-- QUELLE 4/4: G8 Skonto-Korrektur (STUB - View existiert, TAX_CORRECTION_AMOUNT fehlt)
-- Aktivieren bei Lieferung von G8:
--   SELECT
--       CAST('T_PAYMENT_RECEIPT' AS VARCHAR(50)),
--       g8.RECEIPT_ID, g8.RECEIPT_DATE,
--       g8.INVOICE_ID, g8.RECEIPT_DATE,
--       -1 * g8.TAX_CORRECTION_AMOUNT,
--       CAST(1 AS BIT), g8.INVOICE_ID
--   FROM list_views.V_LIST_G08_PAYMENT_RECEIPT g8
--   WHERE g8.SKONTO_BERECHTIGT_YN = 'Y'
--     AND ISNULL(g8.STORNO_YN, 'N') <> 'Y'
--     AND g8.TAX_CORRECTION_AMOUNT IS NOT NULL
--     AND g8.TAX_CORRECTION_AMOUNT <> 0
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
