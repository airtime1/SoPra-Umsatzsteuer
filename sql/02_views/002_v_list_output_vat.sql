-- ============================================================
-- list_views.V_LIST_OUTPUT_VAT
-- Auflistung aller Umsatzsteuerfaelle (Ausgangsrechnungen)
-- inkl. optionaler Skonto-Korrekturen aus Zahlungseingaengen.
-- Quellen: dbo.T_INVOICE / dbo.T_INVOICE_ITEM (Gruppe 7),
--          optional dbo.T_PAYMENT_RECEIPT (Gruppe 8).
-- ============================================================
-- Live-DB-Befund 2026-06-07:
--   DEV hat detaillierte Item-Spalten (UNIT_PRICE, UNIT_VAT_PCT usw.)
--   und Zahlungskorrekturspalten. Die aktuell genutzte Sandbox kann noch
--   einen aelteren Stand haben, in dem T_INVOICE_ITEM nur Material/Menge
--   und T_PAYMENT_RECEIPT noch keine Skonto/Storno-Spalten enthaelt.
--   Deshalb wird die View dynamisch passend zum vorhandenen Schema erzeugt.

DECLARE @has_invoice_item_amounts BIT =
    CASE WHEN COL_LENGTH('dbo.T_INVOICE_ITEM', 'UNIT_NET_VALUE') IS NOT NULL THEN 1 ELSE 0 END;

DECLARE @has_payment_corrections BIT =
    CASE
        WHEN COL_LENGTH('dbo.T_PAYMENT_RECEIPT', 'DIFFERENCE_AMOUNT') IS NOT NULL
         AND COL_LENGTH('dbo.T_PAYMENT_RECEIPT', 'SKONTO_BERECHTIGT_YN') IS NOT NULL
         AND COL_LENGTH('dbo.T_PAYMENT_RECEIPT', 'STORNO_YN') IS NOT NULL
        THEN 1 ELSE 0
    END;

DECLARE @sql NVARCHAR(MAX);

IF @has_invoice_item_amounts = 1 AND @has_payment_corrections = 1
BEGIN
    SET @sql = N'
CREATE OR ALTER VIEW list_views.V_LIST_OUTPUT_VAT
AS
WITH invoice_lines AS (
    SELECT
        inv.INVOICE_ID,
        inv.INVOICE_DATE,
        inv.INVOICE_STATUS,
        CAST(
            COALESCE(
                item.UNIT_NET_VALUE,
                CAST(item.UNIT_PRICE AS DECIMAL(18,4))
                    * item.QUANTITY
                    * (1 - COALESCE(item.UNIT_DISCOUNT_PCT, 0) / 100.0),
                CAST(mat.SALES_PRICE AS DECIMAL(18,4)) * item.QUANTITY
            ) AS DECIMAL(18,4)
        ) AS NET_AMOUNT,
        CAST(COALESCE(item.UNIT_VAT_PCT, mat.VAT, 0) AS DECIMAL(9,4)) AS VAT_PCT
    FROM dbo.T_INVOICE inv
    JOIN dbo.T_INVOICE_ITEM item
      ON item.INVOICE_ID = inv.INVOICE_ID
    LEFT JOIN dbo.T_MATERIAL mat
      ON mat.ID_MAT = item.ID_MAT
),
invoice_totals AS (
    SELECT
        il.INVOICE_ID,
        il.INVOICE_DATE,
        il.INVOICE_STATUS,
        CAST(SUM(il.NET_AMOUNT) AS DECIMAL(18,4)) AS NET_AMOUNT,
        CAST(SUM(il.NET_AMOUNT * il.VAT_PCT / 100.0) AS DECIMAL(18,4)) AS TAX_AMOUNT,
        CAST(SUM(il.NET_AMOUNT * (1 + il.VAT_PCT / 100.0)) AS DECIMAL(18,4)) AS GROSS_AMOUNT
    FROM invoice_lines il
    GROUP BY il.INVOICE_ID, il.INVOICE_DATE, il.INVOICE_STATUS
)
SELECT
    CAST(''T_INVOICE'' AS VARCHAR(50)) AS SOURCE_TABLE,
    it.INVOICE_ID                      AS SOURCE_INVOICE_ID,
    it.INVOICE_DATE                    AS SOURCE_INVOICE_DATE,
    it.INVOICE_ID                      AS INVOICE_ID,
    it.INVOICE_DATE                    AS INVOICE_DATE,
    it.INVOICE_STATUS                  AS INVOICE_STATUS,
    CAST(it.TAX_AMOUNT AS DECIMAL(12,2)) AS TAX_AMOUNT,
    CAST(0 AS BIT)                     AS IS_CORRECTION,
    CAST(NULL AS INT)                  AS ORIGINAL_INVOICE_ID
FROM invoice_totals it
JOIN dbo.T_CODE status_code
  ON status_code.ID_CODE = it.INVOICE_STATUS
 AND status_code.CODE_TYPE = ''INVOICESTATUS''
WHERE status_code.CODE_NAME IN (''SEND TO CUSTOMER'', ''OVERDUE'', ''PAID'')

UNION ALL

SELECT
    CAST(''T_PAYMENT_RECEIPT'' AS VARCHAR(50)) AS SOURCE_TABLE,
    receipt.RECEIPT_ID                         AS SOURCE_INVOICE_ID,
    receipt.RECEIPT_DATE                       AS SOURCE_INVOICE_DATE,
    receipt.INVOICE_ID                         AS INVOICE_ID,
    receipt.RECEIPT_DATE                       AS INVOICE_DATE,
    receipt.RECEIPT_STATUS                     AS INVOICE_STATUS,
    CAST(
        -1 * ABS(CAST(receipt.DIFFERENCE_AMOUNT AS DECIMAL(18,4)))
           * (it.TAX_AMOUNT / NULLIF(it.GROSS_AMOUNT, 0))
        AS DECIMAL(12,2)
    ) AS TAX_AMOUNT,
    CAST(1 AS BIT)                             AS IS_CORRECTION,
    receipt.INVOICE_ID                         AS ORIGINAL_INVOICE_ID
FROM dbo.T_PAYMENT_RECEIPT receipt
JOIN invoice_totals it
  ON it.INVOICE_ID = receipt.INVOICE_ID
JOIN dbo.T_CODE receipt_status
  ON receipt_status.ID_CODE = receipt.RECEIPT_STATUS
 AND receipt_status.CODE_TYPE = ''RECEIPTSTATUS''
WHERE receipt_status.CODE_NAME = ''PAID''
  AND receipt.SKONTO_BERECHTIGT_YN = ''Y''
  AND ISNULL(receipt.STORNO_YN, ''N'') <> ''Y''
  AND receipt.DIFFERENCE_AMOUNT IS NOT NULL
  AND receipt.DIFFERENCE_AMOUNT <> 0
  AND it.GROSS_AMOUNT <> 0;';
END
ELSE
BEGIN
    SET @sql = N'
CREATE OR ALTER VIEW list_views.V_LIST_OUTPUT_VAT
AS
SELECT
    CAST(''T_INVOICE'' AS VARCHAR(50)) AS SOURCE_TABLE,
    inv.INVOICE_ID                     AS SOURCE_INVOICE_ID,
    inv.INVOICE_DATE                   AS SOURCE_INVOICE_DATE,
    inv.INVOICE_ID,
    inv.INVOICE_DATE,
    inv.INVOICE_STATUS,
    CAST(ISNULL(SUM(item.QUANTITY * mat.SALES_PRICE * (mat.VAT / 100.0)), 0)
         AS DECIMAL(12,2))             AS TAX_AMOUNT,
    CAST(0 AS BIT)                     AS IS_CORRECTION,
    CAST(NULL AS INT)                  AS ORIGINAL_INVOICE_ID
FROM dbo.T_INVOICE inv
JOIN dbo.T_INVOICE_ITEM item
  ON item.INVOICE_ID = inv.INVOICE_ID
JOIN dbo.T_MATERIAL mat
  ON mat.ID_MAT = item.ID_MAT
JOIN dbo.T_CODE status_code
  ON status_code.ID_CODE = inv.INVOICE_STATUS
 AND status_code.CODE_TYPE = ''INVOICESTATUS''
WHERE status_code.CODE_NAME IN (''SEND TO CUSTOMER'', ''OVERDUE'', ''PAID'')
GROUP BY inv.INVOICE_ID, inv.INVOICE_DATE, inv.INVOICE_STATUS;';
END;

EXEC sys.sp_executesql @sql;
