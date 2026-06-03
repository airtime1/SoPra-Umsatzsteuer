-- ============================================================
-- list_views.V_LIST_INPUT_VAT
-- Auflistung aller Vorsteuerfaelle (Eingangsrechnungen).
-- Quelle: dbo.T_SUPPLIER_INVOICE + dbo.T_SUPPLIER_INVOICE_ITEM
-- (Gruppe 4).
-- ============================================================
-- WICHTIG / OFFEN:
--   T_SUPPLIER_INVOICE hat KEINE TAX_AMOUNT-Spalte.
--   T_SUPPLIER_INVOICE_ITEM hat UNIT_PRICE, QUANTITY,
--   UNIT_DISCOUNT_PCT und UNIT_VAT_PCT.
--   Steuerbetrag pro Item: UNIT_NET_VALUE * UNIT_VAT_PCT / 100
--     mit UNIT_NET_VALUE = UNIT_PRICE * QUANTITY * (1 - UNIT_DISCOUNT_PCT/100)
--   (UNIT_NET_VALUE ist in T_SUPPLIER_INVOICE_ITEM bereits als computed
--    column vorhanden.)
--
--   Diese View aggregiert je INVOICE_ID. Sobald Gruppe 4 eine
--   TAX_AMOUNT-Spalte direkt auf dem Kopf liefert (vermutlich der Plan),
--   wird das stark vereinfacht.

CREATE OR ALTER VIEW list_views.V_LIST_INPUT_VAT
AS
SELECT
    inv.INVOICE_ID,
    inv.INVOICE_DATE,
    inv.INVOICE_STATUS,
    CAST(ISNULL(SUM(item.UNIT_NET_VALUE * (item.UNIT_VAT_PCT / 100.0)), 0)
         AS DECIMAL(12,2))                AS TAX_AMOUNT
FROM dbo.T_SUPPLIER_INVOICE       inv
LEFT JOIN dbo.T_SUPPLIER_INVOICE_ITEM item
       ON item.INVOICE_ID = inv.INVOICE_ID
GROUP BY inv.INVOICE_ID, inv.INVOICE_DATE, inv.INVOICE_STATUS;
