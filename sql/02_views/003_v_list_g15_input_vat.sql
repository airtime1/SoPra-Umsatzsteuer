-- ============================================================
-- list_views.V_LIST_G15_INPUT_VAT
-- Vorsteuerrelevante Belege fuer eine Periode:
--   - Eingangsrechnungen aus G4 (Lieferantenrechnungen)
-- ============================================================
-- Konvention (ADR-008): G15 berechnet keine Steuerbetraege.
-- Wir konsumieren den Steuerbetrag direkt aus der Partner-Lese-View.
-- SOURCE_TABLE = 'T_SUPPLIER_INVOICE' ist die fachliche Kategorie.
--
-- AKTIV seit 2026-06-23: G4 liefert list_views.V_LIST_SUPPLIER_INVOICE
-- (Kopf-View ueber Lieferantenrechnungen) mit INVOICE_ID, INVOICE_DATE
-- und TOTAL_VAT_AMOUNT. Wir lesen TOTAL_VAT_AMOUNT direkt als TAX_AMOUNT
-- (keine Eigenberechnung). Hinweis: die View heisst V_LIST_SUPPLIER_INVOICE
-- (nicht V_LIST_G04_SUPPLIER_INVOICE) und nutzt TOTAL_VAT_AMOUNT
-- (nicht TAX_AMOUNT).
--
-- Stand 2026-06-23: G4 hat die View angelegt, aber noch keine
-- Rechnungsdaten eingespielt (0 Zeilen). Die View kompiliert und liefert
-- automatisch Zeilen, sobald G4 Lieferantenrechnungen befuellt.

CREATE OR ALTER VIEW list_views.V_LIST_G15_INPUT_VAT
AS

-- QUELLE 1/1: G4 Lieferantenrechnungen
SELECT
    CAST('T_SUPPLIER_INVOICE' AS VARCHAR(50))  AS SOURCE_TABLE,
    g4.INVOICE_ID                              AS SOURCE_INVOICE_ID,
    g4.INVOICE_DATE                            AS SOURCE_INVOICE_DATE,
    g4.INVOICE_ID                              AS INVOICE_ID,
    g4.INVOICE_DATE                            AS INVOICE_DATE,
    CAST(g4.TOTAL_VAT_AMOUNT AS DECIMAL(12,2)) AS TAX_AMOUNT,
    CAST(0 AS BIT)                             AS IS_CORRECTION,
    CAST(NULL AS INT)                          AS ORIGINAL_INVOICE_ID
FROM list_views.V_LIST_SUPPLIER_INVOICE g4;
