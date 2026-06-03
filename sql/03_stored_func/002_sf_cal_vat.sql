-- ============================================================
-- stored_func.SF_CAL_VAT
-- Berechnet aus Umsatzsteuer- und Vorsteuersumme den Saldo
-- (Absolutbetrag) und den Typ (ZAHLLAST/UEBERHANG/NEUTRAL).
--
-- Konvention (ADR-004):
--   OUTPUT > INPUT  -> ZAHLLAST, BALANCE = OUTPUT - INPUT
--   OUTPUT < INPUT  -> UEBERHANG, BALANCE = INPUT - OUTPUT
--   OUTPUT = INPUT  -> NEUTRAL, BALANCE = 0
--
-- Implementiert als Inline-Table-Valued-Function, damit der
-- aufrufende Code zwei Spalten (BALANCE, TYPE) direkt
-- weiterverwenden kann.
-- ============================================================

CREATE OR ALTER FUNCTION stored_func.SF_CAL_VAT
(
    @OUTPUT_VAT_TOTAL DECIMAL(12,2),
    @INPUT_VAT_TOTAL  DECIMAL(12,2)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        CASE
            WHEN @OUTPUT_VAT_TOTAL >= @INPUT_VAT_TOTAL
                THEN @OUTPUT_VAT_TOTAL - @INPUT_VAT_TOTAL
            ELSE @INPUT_VAT_TOTAL - @OUTPUT_VAT_TOTAL
        END AS VAT_BALANCE,
        CASE
            WHEN @OUTPUT_VAT_TOTAL >  @INPUT_VAT_TOTAL THEN 'ZAHLLAST'
            WHEN @OUTPUT_VAT_TOTAL <  @INPUT_VAT_TOTAL THEN 'UEBERHANG'
            ELSE 'NEUTRAL'
        END AS VAT_TYPE
);
