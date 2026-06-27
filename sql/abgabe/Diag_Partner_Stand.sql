-- =================================================================
-- DIAGNOSE ERPDEV26S — Partner-Lese-Views (frischer Stand)
-- Zweck: Was hat sich seit 2026-06-13 getan? Reicht G7s View fuer
--        alle Ausgangsrechnungen (G7/G9/G10)? Sind die fehlenden
--        Felder G4/G8/G9 inzwischen geliefert?
-- Read-only. Jede Query einzeln ausfuehren und Ergebnis zurueckgeben.
-- =================================================================

-- -----------------------------------------------------------------
-- Query A: Alle Views im list_views-Schema (neue seit 06-13 sichtbar
--          an create_date/modify_date). Suchen v.a. G04 / G10.
-- -----------------------------------------------------------------
SELECT
    s.name      AS [schema],
    v.name      AS [view_name],
    o.create_date,
    o.modify_date
FROM sys.views v
JOIN sys.schemas s ON s.schema_id = v.schema_id
JOIN sys.objects o ON o.object_id = v.object_id
WHERE s.name = 'list_views'
ORDER BY v.name;

-- -----------------------------------------------------------------
-- Query B: Spalten der fuer uns relevanten Quell-Views.
--          Hier sehen wir, ob TAX_AMOUNT (G4/G7/G9) bzw.
--          TAX_CORRECTION_AMOUNT (G8) inzwischen existieren.
-- -----------------------------------------------------------------
SELECT
    v.name      AS [view_name],
    c.column_id AS [col_pos],
    c.name      AS [column_name],
    t.name      AS [data_type]
FROM sys.views v
JOIN sys.schemas s ON s.schema_id = v.schema_id
JOIN sys.columns c ON c.object_id = v.object_id
JOIN sys.types   t ON t.user_type_id = c.user_type_id
WHERE s.name = 'list_views'
  AND v.name IN (
        'V_LIST_G04_SUPPLIER_INVOICE',
        'V_LIST_G07_INVOICE',
        'V_LIST_G08_PAYMENT_RECEIPT',
        'V_LIST_G09_INVOICE_TAX_B2C'
  )
ORDER BY v.name, c.column_id;

-- -----------------------------------------------------------------
-- Query C (ENTSCHEIDEND): Definition von V_LIST_G07_INVOICE.
--          Filtert die View auf G7-Fernabsatz, oder liefert sie ALLE
--          T_INVOICE-Zeilen (also auch G9 Rosenberg / G10 Freiburg)?
--          -> sagt uns, ob wir G9/G10-Stubs ersatzlos streichen koennen.
-- -----------------------------------------------------------------
SELECT m.definition
FROM sys.sql_modules m
JOIN sys.objects o ON o.object_id = m.object_id
JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE s.name = 'list_views' AND o.name = 'V_LIST_G07_INVOICE';

-- -----------------------------------------------------------------
-- Query D: Stichprobe aus V_LIST_G07_INVOICE. Gibt es eine Spalte,
--          die Vertriebskanal/Quelle (Fernabsatz vs. Bar B2C)
--          unterscheidet, und ist BetragUstEUR ueberall gefuellt?
-- -----------------------------------------------------------------
SELECT TOP (25) *
FROM list_views.V_LIST_G07_INVOICE
ORDER BY RechnungsDatum DESC;

-- -----------------------------------------------------------------
-- Query E: Sind UNSERE G15-Objekte schon deployed?
--          (zeigt, ob Lehmann die dbo-Tabellen angelegt hat und ob
--           unser Bundle schon gegen ERPDEV laeuft)
-- -----------------------------------------------------------------
SELECT
    s.name      AS [schema],
    o.type_desc AS [type],
    o.name      AS [name]
FROM sys.objects o
JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE (
        (s.name IN ('list_views','stored_func','stored_proc')
         AND o.name IN (
            'LOV_VAT_STATUS',
            'V_LIST_G15_OUTPUT_VAT','V_LIST_G15_INPUT_VAT',
            'V_LIST_G15_VAT_STATEMENT','V_LIST_G15_VAT_STATEMENT_ITEM','V_LIST_G15_VAT_USER',
            'fn_G15_check_vat_period','fn_G15_calculate_vat_balance',
            'sp_G15_create_vat_statement','sp_G15_approve_vat_statement',
            'sp_G15_pay_vat_statement','sp_G15_reject_vat_statement'))
      OR (s.name = 'dbo'
         AND o.name IN ('T_VAT_STATEMENT','T_VAT_STATEMENT_ITEM','fn_chk_status_folge','fn_get_user_securitylevel'))
      )
ORDER BY s.name, o.type_desc, o.name;


-- =================================================================
-- RUNDE 2 — nach Befund: G7-View ist B2B-only (INNER-JOIN-Kette).
--           Jetzt klaeren: wo liegt die B2C-Steuer (G9/G10) wirklich?
-- =================================================================

-- -----------------------------------------------------------------
-- Query F: Spalten der B2C-Steuer-/Export-Views. Welche View traegt
--          einen fertigen Steuerbetrag, den wir konsumieren koennen?
-- -----------------------------------------------------------------
SELECT
    v.name      AS [view_name],
    c.column_id AS [col_pos],
    c.name      AS [column_name],
    t.name      AS [data_type]
FROM sys.views v
JOIN sys.schemas s ON s.schema_id = v.schema_id
JOIN sys.columns c ON c.object_id = v.object_id
JOIN sys.types   t ON t.user_type_id = c.user_type_id
WHERE s.name = 'list_views'
  AND v.name IN (
        'V_LIST_G09_TAX_EXPORT_B2C',
        'V_LIST_G09_DAILY_CLOSING_B2C',
        'V_LIST_G10_DAILY_CLOSING_B2C',
        'V_LIST_G10_INVOICE_ITEM_B2C',
        'V_LIST_G10_PAYMENT_B2C'
  )
ORDER BY v.name, c.column_id;

-- -----------------------------------------------------------------
-- Query G: Beweis-Query — erscheinen G9-Rechnungen ueberhaupt in G7s
--          View? Wenn n_in_g7 = 0, ist G7 definitiv B2B-only und wir
--          MUESSEN G9/G10 als eigene Quellen behalten.
-- -----------------------------------------------------------------
SELECT 'g9_total'        AS kennzahl, COUNT(*) AS n FROM list_views.V_LIST_G09_INVOICE_TAX_B2C
UNION ALL
SELECT 'g9_davon_in_g7', COUNT(*)
FROM list_views.V_LIST_G09_INVOICE_TAX_B2C g9
JOIN list_views.V_LIST_G07_INVOICE g7 ON g7.INVOICE_ID = g9.INVOICE_ID;


-- =================================================================
-- RUNDE 3 — frischer Stand gegen die NEUE Architektur (Beschluss
--           2026-06-16): G7 = eine Quelle, G8 = finaler Steuerbetrag
--           + IS_SKONTO (ueberschreiben), G4 = Vorsteuer.
-- =================================================================

-- -----------------------------------------------------------------
-- Query H: Hat G7 die View inzwischen auf ALLE Ausgangsrechnungen
--          erweitert? Wenn g9_quote ~100% statt 50% -> erledigt.
--          Zusatz: g10-Abdeckung (falls G10 INVOICE_ID in T_INVOICE hat).
-- -----------------------------------------------------------------
SELECT 'g9_total'        AS kennzahl, COUNT(*) AS n FROM list_views.V_LIST_G09_INVOICE_TAX_B2C
UNION ALL
SELECT 'g9_davon_in_g7', COUNT(*)
FROM list_views.V_LIST_G09_INVOICE_TAX_B2C g9
JOIN list_views.V_LIST_G07_INVOICE g7 ON g7.INVOICE_ID = g9.INVOICE_ID;

-- -----------------------------------------------------------------
-- Query I: Hat G8 die NEUEN Felder (finaler Steuerbetrag + IS_SKONTO)?
--          Wir suchen Spaltennamen mit TAX / SKONTO / FINAL / KORREKT.
-- -----------------------------------------------------------------
SELECT c.name AS column_name, t.name AS data_type
FROM sys.columns c
JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('list_views.V_LIST_G08_PAYMENT_RECEIPT')
  AND (
        c.name LIKE '%TAX%'
     OR c.name LIKE '%SKONTO%'
     OR c.name LIKE '%FINAL%'
     OR c.name LIKE '%KORREKT%'
     OR c.name LIKE '%CORRECTION%'
  )
ORDER BY c.column_id;

-- -----------------------------------------------------------------
-- Query J: Hat G4 endlich eine Vorsteuer-View geliefert?
-- -----------------------------------------------------------------
SELECT s.name AS [schema], v.name AS [view_name], o.modify_date
FROM sys.views v
JOIN sys.schemas s ON s.schema_id = v.schema_id
JOIN sys.objects o ON o.object_id = v.object_id
WHERE s.name = 'list_views'
  AND (v.name LIKE '%G04%' OR v.name LIKE '%SUPPLIER%')
ORDER BY v.name;

-- -----------------------------------------------------------------
-- Query K: Stehen unsere G15-Objekte + Lehmanns Tabellen schon in der DB?
--          (zeigt, ob seit letztem Mal deployed wurde)
-- -----------------------------------------------------------------
SELECT s.name AS [schema], o.type_desc AS [type], o.name AS [name]
FROM sys.objects o
JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE (
        (s.name IN ('list_views','stored_func','stored_proc')
         AND o.name IN (
            'LOV_VAT_STATUS','V_LIST_G15_OUTPUT_VAT','V_LIST_G15_VAT_SKONTO',
            'V_LIST_G15_INPUT_VAT','V_LIST_G15_VAT_STATEMENT','V_LIST_G15_VAT_STATEMENT_ITEM',
            'V_LIST_G15_VAT_USER','fn_G15_check_vat_period','fn_G15_calculate_vat_balance',
            'sp_G15_create_vat_statement',
            'sp_G15_approve_vat_statement','sp_G15_pay_vat_statement','sp_G15_reject_vat_statement'))
      OR (s.name = 'dbo'
          AND o.name IN ('T_VAT_STATEMENT','T_VAT_STATEMENT_ITEM','fn_chk_status_folge','fn_get_user_securitylevel'))
      )
ORDER BY s.name, o.type_desc, o.name;
