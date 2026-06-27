-- ============================================================
-- Test: stored_func.fn_G15_calculate_vat_balance — Grundfaelle
-- (Testfaelle TC-CAL-01..06 aus test_cases.md)
-- Ausfuehrung: gegen Sandbox-DB (s26s5xx_DATAMART)
-- Erwartung: Spalte RESULT in allen Zeilen = 'PASS'
-- ============================================================

WITH expected (case_id, output_vat, input_vat, exp_balance, exp_type) AS (
    SELECT 'TC-CAL-01', 200, 100, 100, 'ZAHLLAST'  UNION ALL
    SELECT 'TC-CAL-02', 100, 200, 100, 'UEBERHANG' UNION ALL
    SELECT 'TC-CAL-03',   0, 100, 100, 'UEBERHANG' UNION ALL
    SELECT 'TC-CAL-04', 100,   0, 100, 'ZAHLLAST'  UNION ALL
    SELECT 'TC-CAL-05', 100, 100,   0, 'NEUTRAL'   UNION ALL
    SELECT 'TC-CAL-06',   0,   0,   0, 'NEUTRAL'
),
actual AS (
    SELECT
        e.case_id,
        e.exp_balance,
        e.exp_type,
        f.VAT_BALANCE AS act_balance,
        f.VAT_TYPE    AS act_type
    FROM expected e
    CROSS APPLY stored_func.fn_G15_calculate_vat_balance(e.output_vat, e.input_vat) f
)
SELECT
    case_id,
    exp_balance,
    act_balance,
    exp_type,
    act_type,
    CASE
        WHEN exp_balance = act_balance AND exp_type = act_type THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM actual
ORDER BY case_id;
