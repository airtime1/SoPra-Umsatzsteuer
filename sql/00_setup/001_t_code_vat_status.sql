-- ============================================================
-- 001_t_code_vat_status.sql
-- Stammdaten-Einträge fuer Umsatzsteuerabrechnung-Status.
-- Zielschema: dbo (gesperrt) — Skript an Architekt liefern.
-- ============================================================
-- Hinweis: dbo.T_CODE.ID_CODE ist KEIN IDENTITY (Dev-DB-Kopie geprueft).
-- IDs muessen explizit vergeben werden; konkrete Werte vom Architekt
-- bekommen. Hier 9001..9003 als Platzhalter (ausreichend weit weg
-- von vorhandenen Bereichen).

INSERT INTO dbo.T_CODE (ID_CODE, CODE_TYPE, CODE_NAME) VALUES
    (9001, 'VAT_STATUS', 'DRAFT'),
    (9002, 'VAT_STATUS', 'APPROVED'),
    (9003, 'VAT_STATUS', 'PAID');

-- Erlaubte Statusuebergaenge in dbo.T_CODE_NEXT
-- Spalten: CODE_TYPE, CODE_ID, CODE_NEXT_ID, SECURITY_LEVEL
-- SECURITY_LEVEL entspricht der Rolle, die den Wechsel ausloesen darf
-- (siehe ADR-002: 3 = CFO, 2 = Leitung FiBu).
INSERT INTO dbo.T_CODE_NEXT (CODE_TYPE, CODE_ID, CODE_NEXT_ID, SECURITY_LEVEL) VALUES
    ('VAT_STATUS', 9001, 9002, 3),  -- DRAFT     -> APPROVED  durch CFO
    ('VAT_STATUS', 9002, 9003, 2),  -- APPROVED  -> PAID       durch Leitung FiBu
    ('VAT_STATUS', 9002, 9001, 3);  -- APPROVED  -> DRAFT      Rueckgabe durch CFO
