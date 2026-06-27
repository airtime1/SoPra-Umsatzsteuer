-- ============================================================
-- list_views.V_LIST_G15_VAT_USER
-- Minimale User-/Rollen-View fuer die Umsatzsteuer-App.
-- Keine Passwoerter, nur Login und Security-Level.
-- ============================================================

CREATE OR ALTER VIEW list_views.V_LIST_G15_VAT_USER
AS
SELECT
    USERNAME,
    SECURITYLEVEL,
    CASE SECURITYLEVEL
        WHEN 1 THEN 'Sachbearbeiter'
        WHEN 2 THEN 'Leitung FiBu'
        WHEN 3 THEN 'CFO'
        ELSE 'Unbekannt'
    END AS VAT_ROLE
FROM dbo.T_USER;
