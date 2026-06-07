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
--   Steuerlich relevant sind derzeit nur an die Buchhaltung uebermittelte
--   Eingangsrechnungen. Wenn Gruppe 4 weitere finale Statuswerte einfuehrt,
--   muss nur diese View angepasst werden.

CREATE OR ALTER VIEW list_views.V_LIST_INPUT_VAT
AS
SELECT
    CAST('T_SUPPLIER_INVOICE' AS VARCHAR(50)) AS SOURCE_TABLE,
    inv.INVOICE_ID                           AS SOURCE_INVOICE_ID,
    inv.INVOICE_DATE                         AS SOURCE_INVOICE_DATE,
    inv.INVOICE_ID,
    inv.INVOICE_DATE,
    inv.INVOICE_STATUS,
    CAST(
        ISNULL(
            SUM(
                COALESCE(
                    item.UNIT_NET_VALUE,
                    CAST(item.UNIT_PRICE AS DECIMAL(18,4))
                        * item.QUANTITY
                        * (1 - COALESCE(item.UNIT_DISCOUNT_PCT, 0) / 100.0),
                    CAST(mat.TRANSFER_PRICE AS DECIMAL(18,4)) * item.QUANTITY
                )
                * COALESCE(item.UNIT_VAT_PCT, mat.VAT, 0) / 100.0
            ),
            0
        ) AS DECIMAL(12,2)
    ) AS TAX_AMOUNT,
    CAST(0 AS BIT)                          AS IS_CORRECTION,
    CAST(NULL AS INT)                       AS ORIGINAL_INVOICE_ID
FROM dbo.T_SUPPLIER_INVOICE       inv
JOIN dbo.T_SUPPLIER_INVOICE_ITEM item
  ON item.INVOICE_ID = inv.INVOICE_ID
LEFT JOIN dbo.T_MATERIAL mat
  ON mat.ID_MAT = item.ID_MAT
JOIN dbo.T_CODE status_code
  ON status_code.ID_CODE = inv.INVOICE_STATUS
 AND status_code.CODE_TYPE = 'SUPPLIER_INVOICE'
WHERE status_code.CODE_NAME = 'AN BUCHHALTUNG UEBERMITTELT'
GROUP BY inv.INVOICE_ID, inv.INVOICE_DATE, inv.INVOICE_STATUS;
