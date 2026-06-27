-- ============================================================
-- list_views.V_LIST_G15_VAT_SKONTO
-- Skonto-Korrektur je Rechnung aus G8 (Zahlungseingaenge).
-- ============================================================
-- Konvention (ADR-008 / ADR-010): G15 berechnet keine Steuer.
-- G8 liefert je Zahlungseingang den FINALEN Steuerbetrag der
-- Rechnung nach Skonto. stored_proc.sp_G15_create_vat_statement
-- ueberschreibt damit den urspruenglichen TAX_AMOUNT der Rechnung
-- (Match ueber INVOICE_ID), wenn IS_SKONTO = 'Y'.
--
-- Signatur:
--   INVOICE_ID  - Rechnung, auf die sich der Zahlungseingang bezieht
--   TAX_AMOUNT  - finaler (nach Skonto reduzierter) Steuerbetrag
--   IS_SKONTO   - 'Y' = Skonto gezogen -> ueberschreiben, sonst 'N'
--
-- STUB (WHERE 1 = 0): G8 liefert nur EINEN Teil der noetigen Felder.
-- Stand 2026-06-23: V_LIST_G08_PAYMENT_RECEIPT hat zwar das Skonto-Flag
-- SKONTO_BERECHTIGT_YN (char(1), 'Y'/'N'), aber KEINEN finalen
-- Steuerbetrag nach Skonto. Ohne diesen koennen wir den TAX_AMOUNT der
-- Rechnung nicht ueberschreiben (ADR-010, keine Eigenberechnung).
-- Bring-Schuld G8 bleibt offen (Issue #26): finaler Steuerbetrag fehlt.
-- Aktivieren, sobald G8 den finalen Steuerbetrag liefert:
--   SELECT
--       g8.INVOICE_ID,
--       g8.<FINALER_STEUERBETRAG>,           -- finaler Steuerbetrag, fehlt noch
--       g8.SKONTO_BERECHTIGT_YN              -- 'Y' / 'N'
--   FROM list_views.V_LIST_G08_PAYMENT_RECEIPT g8
--   WHERE ISNULL(g8.STORNO_YN, 'N') <> 'Y'

CREATE OR ALTER VIEW list_views.V_LIST_G15_VAT_SKONTO
AS
SELECT
    CAST(NULL AS INT)            AS INVOICE_ID,
    CAST(NULL AS DECIMAL(12,2))  AS TAX_AMOUNT,
    CAST(NULL AS CHAR(1))        AS IS_SKONTO
WHERE 1 = 0;
