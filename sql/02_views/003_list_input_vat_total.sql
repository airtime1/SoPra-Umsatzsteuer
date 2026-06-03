-- ============================================================
-- list_views.INPUT_VAT_TOTAL
-- Auflistung aller Vorsteuerfaelle aus Lieferantenrechnungen.
-- Quelle: T_SUPPLIER_INVOICE (Gruppe 4). Erwartet ergaenzte
-- Spalte TAX_AMOUNT (Korrekturlogik dort noch zu klaeren, siehe
-- docs/offene_fragen.md).
-- ============================================================

CREATE OR ALTER VIEW list_views.INPUT_VAT_TOTAL
AS
SELECT
    INVOICE_ID,
    INVOICE_DATE,
    INVOICE_STATUS,
    TAX_AMOUNT
FROM dbo.T_SUPPLIER_INVOICE
WHERE TAX_AMOUNT IS NOT NULL;
