-- ============================================================
-- list_views.V_LIST_OUTPUT_VAT
-- Auflistung aller Umsatzsteuerfaelle (Ausgangsrechnungen).
-- Quelle: dbo.T_INVOICE (Gruppe 7).
-- ============================================================
-- WICHTIG / OFFEN:
--   Die Dev-DB-Kopie (Stand 11.05.2026) hat in T_INVOICE NOCH KEINE
--   TAX_AMOUNT-Spalte. Steuersatz liegt aktuell nur auf Item-Ebene
--   und auch dort indirekt (T_INVOICE_ITEM hat nur QUANTITY/ID_MAT,
--   keine UNIT_VAT_PCT; vermutlich Aggregation ueber JOIN auf T_MATERIAL
--   und Preise).
--
--   Sobald Gruppe 7 die Schnittstelle final liefert, hier anpassen:
--   - Variante A: T_INVOICE.TAX_AMOUNT existiert    -> Spalte direkt durchreichen.
--   - Variante B: nur Items                        -> JOIN auf T_INVOICE_ITEM +
--                                                     T_MATERIAL, aggregieren.
--   - Variante C: separate Tabelle fuer Korrekturen -> UNION ALL.
--
-- Aktueller Stand: Skelett-Variante mit TAX_AMOUNT als Platzhalter,
-- damit die Stored Procedure schon mal compiliert. Schmiert beim Ausfuehren
-- ab, wenn die Spalte real noch fehlt — gewuenscht als Frueh-Indikator.

CREATE OR ALTER VIEW list_views.V_LIST_OUTPUT_VAT
AS
SELECT
    INVOICE_ID,
    INVOICE_DATE,
    INVOICE_STATUS,
    CAST(0 AS DECIMAL(12,2))  AS TAX_AMOUNT,           -- TODO: Gruppe 7
    CAST(0 AS BIT)            AS IS_CORRECTION,        -- TODO: Gruppe 7
    CAST(NULL AS INT)         AS ORIGINAL_INVOICE_ID   -- TODO: Gruppe 7
FROM dbo.T_INVOICE;
