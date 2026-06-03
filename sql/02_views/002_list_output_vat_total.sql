-- ============================================================
-- list_views.OUTPUT_VAT_TOTAL
-- Auflistung aller Umsatzsteuerfaelle aus Kundenrechnungen.
-- Quelle: T_INVOICE (Gruppe 7). Erwartet ergaenzte Spalten
-- TAX_AMOUNT, IS_CORRECTION, ORIGINAL_INVOICE_ID.
-- ============================================================

CREATE OR ALTER VIEW list_views.OUTPUT_VAT_TOTAL
AS
SELECT
    INVOICE_ID,
    INVOICE_DATE,
    INVOICE_STATUS,
    TAX_AMOUNT,
    IS_CORRECTION,
    ORIGINAL_INVOICE_ID
FROM dbo.T_INVOICE
WHERE TAX_AMOUNT IS NOT NULL;
