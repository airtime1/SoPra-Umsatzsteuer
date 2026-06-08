-- ============================================================
-- 001_demo_vat_workflow.sql
-- Realistische Demo-Daten fuer den kompletten Umsatzsteuer-Workflow.
-- Nur fuer die eigene Sandbox gedacht.
--
-- Rollen kommen aus vorhandenen dbo.T_USER-Daten:
--   SECURITYLEVEL 1  Sachbearbeiter
--   SECURITYLEVEL 2  Leitung FiBu
--   SECURITYLEVEL 3  CFO
--
-- Demo-Perioden:
--   2026-03  Vorsteuerueberhang
--   2026-04  Zahllast inkl. Skonto und spaeter Korrektur
--   2026-02  bewusst leerer Monat fuer Neutral-Test
-- ============================================================

DECLARE @demo_user NVARCHAR(50) = N'G15_DEMO';

DELETE item
FROM dbo.T_VAT_STATEMENT_ITEM item
JOIN dbo.T_VAT_STATEMENT head
  ON head.VAT_STATEMENT_ID = item.VAT_STATEMENT_ID
WHERE head.VAT_PERIOD IN ('2026-02', '2026-03', '2026-04');

DELETE FROM dbo.T_VAT_STATEMENT
WHERE VAT_PERIOD IN ('2026-02', '2026-03', '2026-04');

DELETE FROM dbo.T_PAYMENT_RECEIPT
WHERE RECEIPT_ID IN (159201, 159202);

DELETE FROM dbo.T_SUPPLIER_INVOICE_ITEM
WHERE INVOICE_ID IN (159101, 159102);

DELETE FROM dbo.T_SUPPLIER_INVOICE
WHERE INVOICE_ID IN (159101, 159102);

DELETE FROM dbo.T_INVOICE_ITEM
WHERE INVOICE_ID IN (159001, 159002, 159003, 159004);

DELETE FROM dbo.T_INVOICE
WHERE INVOICE_ID IN (159001, 159002, 159003, 159004);

-- Ausgangsrechnungen: steuerlich relevante Status = PAID (84).
-- Nur Spalten verwenden, die in DEV und in der bekannten Sandbox vorhanden sind.
INSERT INTO dbo.T_INVOICE
    (INVOICE_ID, DELIVERY_ID, SALESORG_ID, INVOICE_DATE, DUE_DATE,
     INVOICE_STATUS, INS_USER, INS_DATE, UPD_USER, UPD_DATE)
VALUES
    (159001, NULL, 1, '2026-04-15', '2026-04-30', 84, @demo_user, GETDATE(), NULL, NULL),
    (159002, NULL, 1, '2026-04-18', '2026-05-02', 84, @demo_user, GETDATE(), NULL, NULL),
    (159003, NULL, 1, '2026-03-12', '2026-03-27', 84, @demo_user, GETDATE(), NULL, NULL),
    (159004, NULL, 1, '2026-01-20', '2026-02-04', 84, @demo_user, GETDATE(), NULL, NULL);

INSERT INTO dbo.T_INVOICE_ITEM
    (INVOICE_ID, INVOICE_ITEM_ID, ID_MAT, QUANTITY,
     INS_USER, INS_DATE, UPD_USER, UPD_DATE)
VALUES
    (159001, 1, 2, 1, @demo_user, GETDATE(), NULL, NULL),
    (159002, 1, 3, 1, @demo_user, GETDATE(), NULL, NULL),
    (159003, 1, 4, 1, @demo_user, GETDATE(), NULL, NULL),
    (159004, 1, 3, 1, @demo_user, GETDATE(), NULL, NULL);

-- Eingangsrechnungen: steuerlich relevant = an Buchhaltung uebermittelt (301)
INSERT INTO dbo.T_SUPPLIER_INVOICE
    (INVOICE_ID, PO_ID, INVOICE_DATE, DUE_DATE, PAYMENT_TERMS,
     INVOICE_STATUS, INS_USER, INS_DATE, UPD_USER, UPD_DATE)
VALUES
    (159101, NULL, '2026-04-20', '2026-05-05', NULL, 301, @demo_user, GETDATE(), NULL, NULL),
    (159102, NULL, '2026-03-15', '2026-03-30', NULL, 301, @demo_user, GETDATE(), NULL, NULL);

INSERT INTO dbo.T_SUPPLIER_INVOICE_ITEM
    (INVOICE_ID, INVOICE_ITEM_ID, ID_MAT, QUANTITY, UNIT_PRICE,
     UNIT_DISCOUNT_PCT, UNIT_VAT_PCT,
     INS_USER, INS_DATE, UPD_USER, UPD_DATE)
VALUES
    (159101, 1, 6, 1,  400.00, 0.00, 19.00, @demo_user, GETDATE(), NULL, NULL),
    (159102, 1, 2, 1, 1000.00, 0.00, 19.00, @demo_user, GETDATE(), NULL, NULL);

-- Optionale Skonto-Korrekturen aus Zahlungseingaengen.
-- In der bekannten Sandbox fehlen die Spalten noch; dann bleibt die Demo
-- bei Rechnung + Vorsteuer. In DEV/aktualisierter Sandbox werden die
-- Korrekturen als negative Umsatzsteuerfaelle sichtbar.
IF COL_LENGTH('dbo.T_PAYMENT_RECEIPT', 'DIFFERENCE_AMOUNT') IS NOT NULL
   AND COL_LENGTH('dbo.T_PAYMENT_RECEIPT', 'SKONTO_BERECHTIGT_YN') IS NOT NULL
   AND COL_LENGTH('dbo.T_PAYMENT_RECEIPT', 'STORNO_YN') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql
        N'
        INSERT INTO dbo.T_PAYMENT_RECEIPT
            (RECEIPT_ID, INVOICE_ID, RECEIPT_DATE, PAYMENT_METHOD, RECEIPT_VALUE,
             RECEIPT_STATUS, INS_USER, INS_DATE, UPD_USER, UPD_DATE,
             DIFFERENCE_AMOUNT, SKONTO_BERECHTIGT_YN, VERWENDUNGSZWECK,
             ESKALATION_AM, CLARIFY_REASON, STORNO_YN, STORNO_REFERENCE_ID)
        VALUES
            (159201, 159002, ''2026-04-25'', 80,  476.00, 100, @demo_user, GETDATE(), NULL, NULL,
              119.00, ''Y'', N''G15 Demo Skonto April'', NULL, NULL, ''N'', NULL),
            (159202, 159004, ''2026-04-10'', 80,  535.50, 100, @demo_user, GETDATE(), NULL, NULL,
               59.50, ''Y'', N''G15 Demo spaete Korrektur'', NULL, NULL, ''N'', NULL);',
        N'@demo_user NVARCHAR(50)',
        @demo_user = @demo_user;
END;
