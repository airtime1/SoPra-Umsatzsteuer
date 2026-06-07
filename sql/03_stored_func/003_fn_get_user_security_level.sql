-- ============================================================
-- stored_func.fn_get_user_security_level
-- Liefert den SECURITYLEVEL eines Logins aus dbo.T_USER.
-- Wird fuer Statuswechsel der Umsatzsteuerabrechnung verwendet.
-- ============================================================

CREATE OR ALTER FUNCTION stored_func.fn_get_user_security_level
(
    @username VARCHAR(50)
)
RETURNS INT
AS
BEGIN
    DECLARE @security_level INT;

    SELECT TOP 1 @security_level = SECURITYLEVEL
    FROM dbo.T_USER
    WHERE USERNAME = @username;

    RETURN @security_level;
END;
