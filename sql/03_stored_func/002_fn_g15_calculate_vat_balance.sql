-- ============================================================
-- stored_func.fn_G15_calculate_vat_balance
-- Berechnet aus Umsatzsteuer- und Vorsteuersumme den Saldo
-- (Absolutbetrag) und den Typ (ZAHLLAST/UEBERHANG/NEUTRAL).
--
-- Konvention (ADR-004):
--   OUTPUT > INPUT  -> ZAHLLAST,  BALANCE = OUTPUT - INPUT
--   OUTPUT < INPUT  -> UEBERHANG, BALANCE = INPUT  - OUTPUT
--   OUTPUT = INPUT  -> NEUTRAL,   BALANCE = 0
--
-- Inline-Table-Valued-Function, damit zwei Spalten in einem Aufruf
-- zurueckgegeben werden koennen.
-- ============================================================

CREATE OR ALTER FUNCTION stored_func.fn_G15_calculate_vat_balance
(
    @output_vat_total DECIMAL(12,2),
    @input_vat_total  DECIMAL(12,2)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        CASE
            WHEN @output_vat_total >= @input_vat_total
                THEN @output_vat_total - @input_vat_total
            ELSE @input_vat_total - @output_vat_total
        END AS VAT_BALANCE,
        CASE
            WHEN @output_vat_total >  @input_vat_total THEN 'ZAHLLAST'
            WHEN @output_vat_total <  @input_vat_total THEN 'UEBERHANG'
            ELSE 'NEUTRAL'
        END AS VAT_TYPE
);
