-- ============================================================
-- list_views.LOV_VAT_STATUS
-- Werteliste der Status fuer Umsatzsteuerabrechnung.
-- Verwendung im Frontend (z.B. Status-Dropdown).
-- ============================================================
-- Vorbild: dbo.LOV_STATUS_ORDER (Dev-DB)

CREATE OR ALTER VIEW list_views.LOV_VAT_STATUS
AS
SELECT
    ID_CODE     AS CODE_ID,
    CODE_NAME   AS VAT_STATUS
FROM dbo.T_CODE
WHERE CODE_TYPE = 'VAT_STATUS';
