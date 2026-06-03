-- ============================================================
-- list_views.LOV_VAT_STATUS
-- List-of-Values fuer Status-Dropdown im Frontend.
-- ============================================================

CREATE OR ALTER VIEW list_views.LOV_VAT_STATUS
(
    CODE_ID,
    VAT_STATUS
) AS
SELECT
    ID_CODE      AS CODE_ID,
    CODE_NAME    AS VAT_STATUS
FROM dbo.T_CODE
WHERE CODE_TYPE = 'VAT_STATUS';
