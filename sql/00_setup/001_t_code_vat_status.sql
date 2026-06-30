-- ============================================================
-- 001_t_code_vat_status.sql
-- Stammdaten-Einträge fuer Umsatzsteuerabrechnung-Status.
-- Zielschema: dbo (gesperrt) — Skript an Architekt liefern.
-- ============================================================
-- Hinweis: dbo.T_CODE.ID_CODE ist KEIN IDENTITY (Dev-DB-Kopie geprueft).
-- IDs muessen explizit vergeben werden; konkrete Werte vom Architekt
-- bekommen. Hier 9001..9003 als Platzhalter (ausreichend weit weg
-- von vorhandenen Bereichen).

IF NOT EXISTS (
    SELECT 1 FROM dbo.T_CODE WHERE CODE_TYPE = 'VAT_STATUS' AND CODE_NAME = 'DRAFT'
)
BEGIN
    INSERT INTO dbo.T_CODE (ID_CODE, CODE_TYPE, CODE_NAME)
    VALUES (9001, 'VAT_STATUS', 'DRAFT');
END;

IF NOT EXISTS (
    SELECT 1 FROM dbo.T_CODE WHERE CODE_TYPE = 'VAT_STATUS' AND CODE_NAME = 'APPROVED'
)
BEGIN
    INSERT INTO dbo.T_CODE (ID_CODE, CODE_TYPE, CODE_NAME)
    VALUES (9002, 'VAT_STATUS', 'APPROVED');
END;

IF NOT EXISTS (
    SELECT 1 FROM dbo.T_CODE WHERE CODE_TYPE = 'VAT_STATUS' AND CODE_NAME = 'PAID'
)
BEGIN
    INSERT INTO dbo.T_CODE (ID_CODE, CODE_TYPE, CODE_NAME)
    VALUES (9003, 'VAT_STATUS', 'PAID');
END;

-- Erlaubte Statusuebergaenge in dbo.T_CODE_NEXT
-- Spalten: CODE_TYPE, CODE_ID, CODE_NEXT_ID, SECURITY_LEVEL
-- SECURITY_LEVEL entspricht dem Mindest-Level, das den Wechsel ausloesen darf
-- (siehe ADR-002: 3 = CFO, 2 = Leitung FiBu; hoehere Level schliessen niedrigere ein).
DECLARE @draft_status_id INT = (
    SELECT ID_CODE FROM dbo.T_CODE WHERE CODE_TYPE = 'VAT_STATUS' AND CODE_NAME = 'DRAFT'
);
DECLARE @approved_status_id INT = (
    SELECT ID_CODE FROM dbo.T_CODE WHERE CODE_TYPE = 'VAT_STATUS' AND CODE_NAME = 'APPROVED'
);
DECLARE @paid_status_id INT = (
    SELECT ID_CODE FROM dbo.T_CODE WHERE CODE_TYPE = 'VAT_STATUS' AND CODE_NAME = 'PAID'
);

IF @draft_status_id IS NULL OR @approved_status_id IS NULL OR @paid_status_id IS NULL
BEGIN
    THROW 50030, 'VAT_STATUS-Codewerte konnten nicht ermittelt werden.', 1;
END;

IF NOT EXISTS (
    SELECT 1 FROM dbo.T_CODE_NEXT
    WHERE CODE_TYPE = 'VAT_STATUS'
      AND CODE_ID = @draft_status_id
      AND CODE_NEXT_ID = @approved_status_id
)
BEGIN
    INSERT INTO dbo.T_CODE_NEXT (CODE_TYPE, CODE_ID, CODE_NEXT_ID, SECURITY_LEVEL)
    VALUES ('VAT_STATUS', @draft_status_id, @approved_status_id, 3);  -- DRAFT -> APPROVED durch CFO
END;

IF NOT EXISTS (
    SELECT 1 FROM dbo.T_CODE_NEXT
    WHERE CODE_TYPE = 'VAT_STATUS'
      AND CODE_ID = @approved_status_id
      AND CODE_NEXT_ID = @paid_status_id
)
BEGIN
    INSERT INTO dbo.T_CODE_NEXT (CODE_TYPE, CODE_ID, CODE_NEXT_ID, SECURITY_LEVEL)
    VALUES ('VAT_STATUS', @approved_status_id, @paid_status_id, 2);  -- APPROVED -> PAID durch Leitung FiBu
END;

IF NOT EXISTS (
    SELECT 1 FROM dbo.T_CODE_NEXT
    WHERE CODE_TYPE = 'VAT_STATUS'
      AND CODE_ID = @approved_status_id
      AND CODE_NEXT_ID = @draft_status_id
)
BEGIN
    INSERT INTO dbo.T_CODE_NEXT (CODE_TYPE, CODE_ID, CODE_NEXT_ID, SECURITY_LEVEL)
    VALUES ('VAT_STATUS', @approved_status_id, @draft_status_id, 3);  -- APPROVED -> DRAFT Rueckgabe durch CFO
END;
