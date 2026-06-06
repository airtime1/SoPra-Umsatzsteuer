-- ============================================================
-- list_views.V_LIST_OUTPUT_VAT
-- Auflistung aller Umsatzsteuerfaelle (Ausgangsrechnungen).
-- Quelle: dbo.T_INVOICE (Gruppe 7).
-- ============================================================
-- Dev-DB-Kopie Stand 11.05.2026: T_INVOICE hat keine TAX_AMOUNT-Spalte.
-- Steuerbetrag wird deshalb aus den Rechnungspositionen und T_MATERIAL.VAT
-- aggregiert. Korrekturen bleiben offen, bis Gruppe 7 eine belastbare
-- Schnittstelle fuer IS_CORRECTION / ORIGINAL_INVOICE_ID liefert.

CREATE OR ALTER VIEW list_views.V_LIST_OUTPUT_VAT
AS
SELECT
    inv.INVOICE_ID,
    inv.INVOICE_DATE,
    inv.INVOICE_STATUS,
    CAST(ISNULL(SUM(item.QUANTITY * mat.SALES_PRICE * (mat.VAT / 100.0)), 0)
         AS DECIMAL(12,2))       AS TAX_AMOUNT,
    CAST(0 AS BIT)               AS IS_CORRECTION,       -- TODO: Gruppe 7
    CAST(NULL AS INT)            AS ORIGINAL_INVOICE_ID  -- TODO: Gruppe 7
FROM dbo.T_INVOICE inv
LEFT JOIN dbo.T_INVOICE_ITEM item
       ON item.INVOICE_ID = inv.INVOICE_ID
LEFT JOIN dbo.T_MATERIAL mat
       ON mat.ID_MAT = item.ID_MAT
GROUP BY inv.INVOICE_ID, inv.INVOICE_DATE, inv.INVOICE_STATUS;
