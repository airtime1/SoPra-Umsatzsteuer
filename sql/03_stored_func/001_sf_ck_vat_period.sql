-- ============================================================
-- stored_func.SF_CK_VAT_PERIOD
-- Prueft, ob fuer die uebergebene Periode eine Abrechnung
-- erzeugt/ueberschrieben werden darf.
--
-- Regeln (aus MS4 + ADRs):
--   - Periode (YYYY-MM) muss bereits "abgeschlossen" sein und
--     der heutige Tag mindestens der 10. des Folgemonats sein.
--   - Falls Abrechnung zur Periode existiert: nur erlaubt, wenn
--     Status = DRAFT (Reset/Neuberechnung).
--   - APPROVED / PAID sind gesperrt.
-- ============================================================
-- Rueckgabe:
--   0 = Anlage / Neuberechnung erlaubt (keine vorhandene Abr.
--       ODER vorhandene Abr. ist DRAFT)
--   1 = Periode noch nicht abrechenbar (zu frueh)
--   2 = Abrechnung existiert und ist gesperrt (APPROVED/PAID)
--
-- Die Procedure SP_CREATE_VAT_STATEMENT entscheidet auf Basis
-- des Rueckgabewerts, ob sie weitermacht oder Fehler wirft.

CREATE OR ALTER FUNCTION stored_func.SF_CK_VAT_PERIOD
(
    @VAT_PERIOD  CHAR(7),     -- 'YYYY-MM'
    @CHECK_DATE  DATE         -- i. d. R. CAST(GETDATE() AS DATE)
)
RETURNS INT
AS
BEGIN
    DECLARE @result INT;

    -- 1) Frueheste Abrechnung: 10. des Folgemonats
    DECLARE @period_start DATE = TRY_CAST(@VAT_PERIOD + '-01' AS DATE);
    DECLARE @earliest     DATE = DATEADD(DAY, 9, DATEADD(MONTH, 1, @period_start));

    IF @period_start IS NULL OR @CHECK_DATE < @earliest
    BEGIN
        SET @result = 1;
        RETURN @result;
    END

    -- 2) Existiert bereits eine Abrechnung?
    DECLARE @existing_status VARCHAR(20);

    SELECT TOP 1 @existing_status = VAT_STATUS
    FROM dbo.T_VAT_STATEMENT
    WHERE VAT_PERIOD = @VAT_PERIOD;

    IF @existing_status IS NULL
        SET @result = 0;
    ELSE IF @existing_status = 'DRAFT'
        SET @result = 0;
    ELSE
        SET @result = 2;

    RETURN @result;
END;
