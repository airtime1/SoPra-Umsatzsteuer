-- ============================================================
-- 001_t_code_vat_status.sql
-- Stammdaten-Einträge für Umsatzsteuerabrechnung-Status.
-- Zielschema: dbo (gesperrt) — Skript an Architekt liefern.
-- ============================================================
-- Hinweis: ID_CODE-Werte sind Beispielwerte aus MS4. Tatsächliche
-- IDs vom Architekt vergeben lassen.

-- DRAFT, APPROVED, PAID in T_CODE
INSERT INTO dbo.T_CODE (CODE_TYPE, CODE_NAME) VALUES
    ('VAT_STATUS', 'DRAFT'),
    ('VAT_STATUS', 'APPROVED'),
    ('VAT_STATUS', 'PAID');

-- Erlaubte Statusübergänge in T_CODE_NEXT
-- (ID_CODE-Werte aus dem vorherigen INSERT übernehmen)
-- DRAFT -> APPROVED         (CFO gibt frei)
-- APPROVED -> PAID          (Leitung FiBu zahlt aus)
-- APPROVED -> DRAFT         (CFO weist zurück)
INSERT INTO dbo.T_CODE_NEXT (ID_CODE, CODE_NEXT_ID)
SELECT
    src.ID_CODE,
    dst.ID_CODE
FROM dbo.T_CODE src
JOIN dbo.T_CODE dst
    ON src.CODE_TYPE = 'VAT_STATUS' AND dst.CODE_TYPE = 'VAT_STATUS'
WHERE (src.CODE_NAME = 'DRAFT'    AND dst.CODE_NAME = 'APPROVED')
   OR (src.CODE_NAME = 'APPROVED' AND dst.CODE_NAME = 'PAID')
   OR (src.CODE_NAME = 'APPROVED' AND dst.CODE_NAME = 'DRAFT');
