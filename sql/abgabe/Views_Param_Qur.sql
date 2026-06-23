-- =================================================================
-- DIAGNOSE ERPDEV26S — Partner-Lese-Views
-- Datum: 2026-06-13
-- Zweck: Welche list_views.*-Views haben die anderen Gruppen bereitgestellt?
-- Read-only.
-- =================================================================

-- Query A: Alle Views im list_views-Schema, geordnet nach vermuteter Gruppe
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

-- Query B: Spalten der Views, die wahrscheinlich G4/G7/G8 gehoeren
-- (nach Schluesselwort im Namen)
SELECT
    s.name      AS [schema],
    v.name      AS [view_name],
    c.column_id AS [col_pos],
    c.name      AS [column_name],
    t.name      AS [data_type]
FROM sys.views v
JOIN sys.schemas s   ON s.schema_id = v.schema_id
JOIN sys.columns c   ON c.object_id = v.object_id
JOIN sys.types   t   ON t.user_type_id = c.user_type_id
WHERE s.name = 'list_views'
  AND (
        v.name LIKE '%INVOICE%'        -- G4 / G7
     OR v.name LIKE '%PAYMENT%'        -- G8
     OR v.name LIKE '%RECEIPT%'        -- G8
     OR v.name LIKE '%SUPPLIER%'       -- G4
     OR v.name LIKE '%VAT%'            -- evtl. uns
     OR v.name LIKE '%TAX%'
  )
ORDER BY v.name, c.column_id;

-- Query C: Existieren UNSERE G15-Objekte schon dort?
-- (Moritz/Abel koennten vorab deployed haben)
SELECT
    s.name      AS [schema],
    o.type_desc AS [type],
    o.name      AS [name]
FROM sys.objects o
JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE s.name IN ('list_views','stored_func','stored_proc')
  AND o.name IN (
        'LOV_VAT_STATUS',
        'V_LIST_OUTPUT_VAT','V_LIST_INPUT_VAT',
        'V_LIST_VAT_STATEMENT','V_LIST_VAT_STATEMENT_ITEM','V_LIST_VAT_USER',
        'fn_check_vat_period','fn_calculate_vat_balance','fn_get_user_security_level',
        'sp_create_vat_statement','sp_approve_vat_statement',
        'sp_pay_vat_statement','sp_reject_vat_statement'
  )
ORDER BY s.name, o.type_desc, o.name;