-- ============================================================
-- list_views.V_LIST_G15_VAT_STATEMENT
-- Anzeige-View fuer Umsatzsteuerabrechnungs-Kopfdatensaetze.
-- Frontend liest ueber diese View statt direkt aus dbo.
-- ============================================================

CREATE OR ALTER VIEW list_views.V_LIST_G15_VAT_STATEMENT
AS
SELECT
    VAT_STATEMENT_ID,
    VAT_PERIOD,
    VAT_STATUS,
    OUTPUT_VAT_TOTAL,
    INPUT_VAT_TOTAL,
    VAT_BALANCE,
    VAT_TYPE,
    CREATED_BY,
    CREATED_AT,
    APPROVED_BY,
    APPROVED_AT,
    CLOSED_BY,
    CLOSED_AT
FROM dbo.T_VAT_STATEMENT;
