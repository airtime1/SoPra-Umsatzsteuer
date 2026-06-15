-- ============================================================
-- list_views.V_LIST_INPUT_VAT
-- Vorsteuerrelevante Belege fuer eine Periode:
--   - Eingangsrechnungen aus G4 (Wareneingaenge)    STUB
-- ============================================================
-- Konvention (ADR-008): G15 berechnet keine Steuerbetraege.
-- Wir konsumieren TAX_AMOUNT direkt aus der Partner-Lese-View.
-- SOURCE_TABLE = 'T_SUPPLIER_INVOICE' ist die fachliche Kategorie.
-- Stub liefert Spalten mit korrekter Signatur, aber 0 Zeilen.

CREATE OR ALTER VIEW list_views.V_LIST_INPUT_VAT
AS

-- QUELLE 1/1: G4 Wareneingaenge (STUB - V_LIST_G04_* existiert nicht)
-- Aktivieren bei Lieferung von G4, erwarteter View-Name:
--   SELECT
--       CAST('T_SUPPLIER_INVOICE' AS VARCHAR(50)),
--       g4.INVOICE_ID, g4.INVOICE_DATE,
--       g4.INVOICE_ID, g4.INVOICE_DATE, g4.TAX_AMOUNT,
--       CAST(0 AS BIT), CAST(NULL AS INT)
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
