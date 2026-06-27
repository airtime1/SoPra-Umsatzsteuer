-- ============================================================
-- list_views.V_LIST_G15_VAT_STATEMENT_ITEM
-- Anzeige-View fuer die Belegbasis einer Umsatzsteuerabrechnung.
-- Frontend liest ueber diese View statt direkt aus dbo.
-- ============================================================

CREATE OR ALTER VIEW list_views.V_LIST_G15_VAT_STATEMENT_ITEM
AS
SELECT
    VAT_STATEMENT_ITEM_ID,
    VAT_STATEMENT_ID,
    SOURCE_TABLE,
    SOURCE_INVOICE_ID,
    SOURCE_INVOICE_DATE,
    TAX_AMOUNT,
    IS_CORRECTION,
    ORIGINAL_INVOICE_ID,
    CREATED_BY,
    CREATED_AT
FROM dbo.T_VAT_STATEMENT_ITEM;
