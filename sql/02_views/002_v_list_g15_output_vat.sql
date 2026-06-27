-- ============================================================
-- list_views.V_LIST_G15_OUTPUT_VAT
-- Alle umsatzsteuerrelevanten Ausgangsrechnungen einer Periode.
-- ============================================================
-- Konvention (ADR-008): G15 berechnet keine Steuerbetraege.
-- Wir konsumieren TAX_AMOUNT direkt aus der Partner-Lese-View.
--
-- EINE QUELLE fuer alle Ausgangsrechnungen (Beschluss 2026-06-16):
--   G7 stellt mit list_views.V_LIST_G07_INVOICE die gemeinsame
--   Rechnungs-View ueber dbo.T_INVOICE bereit. Die Barverkaeufe von
--   G9 (Rosenberg) und G10 (Freiburg) schreiben ueber dieselbe
--   T_INVOICE und werden kuenftig ueber diese View mitgeliefert.
--   -> kein eigener G9/G10-Block mehr, keine UNIONs.
--
-- Skonto wird NICHT mehr hier als Korrektur-Zeile gefuehrt
-- (loest ADR-005 ab, siehe ADR-010): die Skonto-Korrektur
-- ueberschreibt den finalen Steuerbetrag der Rechnung erst in
-- stored_proc.sp_G15_create_vat_statement, Quelle list_views.V_LIST_G15_VAT_SKONTO.
--
-- OFFEN (Bring-Schuld G7, Issue #27/#28): V_LIST_G07_INVOICE liefert
-- aktuell nur Fernabsatz-Rechnungen mit vollstaendiger
-- Angebot->Auftrag->Lieferung-Kette (INNER JOINs). B2C-Barverkaeufe
-- ohne diese Kette fehlen noch (Diagnose 2026-06-16: 78 von 156
-- G9-Rechnungen sichtbar). G7 muss die View so erweitern, dass alle
-- T_INVOICE-Ausgangsrechnungen erscheinen. Bis dahin zaehlt nur
-- Fernabsatz; unsere Logik bleibt unveraendert.

CREATE OR ALTER VIEW list_views.V_LIST_G15_OUTPUT_VAT
AS
SELECT
    CAST('T_INVOICE' AS VARCHAR(50))   AS SOURCE_TABLE,
    g7.INVOICE_ID                      AS SOURCE_INVOICE_ID,
    g7.RechnungsDatum                  AS SOURCE_INVOICE_DATE,
    g7.INVOICE_ID                      AS INVOICE_ID,
    g7.RechnungsDatum                  AS INVOICE_DATE,
    g7.BetragUstEUR                    AS TAX_AMOUNT,
    CAST(0 AS BIT)                     AS IS_CORRECTION,
    CAST(NULL AS INT)                  AS ORIGINAL_INVOICE_ID
FROM list_views.V_LIST_G07_INVOICE g7;
