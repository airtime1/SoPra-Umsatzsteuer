-- ============================================================
-- list_views.V_LIST_VAT_SKONTO
-- Skonto-Korrektur je Rechnung aus G8 (Zahlungseingaenge).
-- ============================================================
-- Konvention (ADR-008 / ADR-010): G15 berechnet keine Steuer.
-- G8 liefert je Zahlungseingang den FINALEN Steuerbetrag der
-- Rechnung nach Skonto. stored_proc.sp_create_vat_statement
-- ueberschreibt damit den urspruenglichen TAX_AMOUNT der Rechnung
-- (Match ueber INVOICE_ID), wenn IS_SKONTO = 'Y'.
--
-- Signatur:
--   INVOICE_ID  - Rechnung, auf die sich der Zahlungseingang bezieht
--   TAX_AMOUNT  - finaler (nach Skonto reduzierter) Steuerbetrag
--   IS_SKONTO   - 'Y' = Skonto gezogen -> ueberschreiben, sonst 'N'
--
-- STUB (WHERE 1 = 0): G8 liefert die neuen Felder noch nicht
-- (Stand 2026-06-16: V_LIST_G08_PAYMENT_RECEIPT hat weder finalen
-- Steuerbetrag noch IS_SKONTO, Issue #26). Aktivieren bei Lieferung:
--   SELECT
--       g8.INVOICE_ID,
--       g8.TAX_AMOUNT,                       -- finaler Steuerbetrag
--       g8.IS_SKONTO                         -- 'Y' / 'N'
--   FROM list_views.V_LIST_G08_PAYMENT_RECEIPT g8
--   WHERE ISNULL(g8.STORNO_YN, 'N') <> 'Y'

CREATE OR ALTER VIEW list_views.V_LIST_VAT_SKONTO
AS
SELECT
    CAST(NULL AS INT)            AS INVOICE_ID,
    CAST(NULL AS DECIMAL(12,2))  AS TAX_AMOUNT,
    CAST(NULL AS CHAR(1))        AS IS_SKONTO
WHERE 1 = 0;
