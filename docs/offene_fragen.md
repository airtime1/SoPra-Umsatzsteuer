# Offene Fragen

Punkte, die wir extern klären müssen — ans Team, an Prof. Meth / Lehmann, oder an Partner-Gruppen.

Format: `[Status] Frage — Adressat — Datum erstellt`. Status ∈ {OFFEN, GEKLÄRT, OBSOLET}.

## Architektur & Datenbank

- [OFFEN] In welchem Schema werden unsere Tabellen `T_VAT_STATEMENT` und `T_VAT_STATEMENT_ITEM` angelegt? `dbo` ist gesperrt, aber kein eigenes Schema für Tabellen erwähnt — gehen die ans `dbo`-Architekt-Schema? — Architekt (Peter Lehmann)
- [OFFEN] Wie ist der konkrete Prozess zur Anlage von Tabellen / T_CODE-Einträgen? Skript per Mail an den Architekt? Pull-Request? — Architekt
- [OFFEN] Brauchen wir `ins_views` / `upd_views` für jeden Schreibvorgang aus dem Frontend, oder darf `ERP_REMOTE_USER` direkt auf Tabellen schreiben? — Architekt
- [GEKLÄRT 2026-06-03] HdM-Namenskonventionen liegen in `docs/namenskonventionen/Lerneinheit_7_Datenbankentwicklung.docx` (+ Zusammenfassung in `INDEX.md`). SQL-Skelette entsprechend refactored (ADR-007).
- [GEKLÄRT 2026-06-03] Dev-DB-Snapshot liegt in `sql/99_devdb_kopie/cre_devdb_11.05.2026.utf8.sql`. Wichtigste Befunde: `T_INVOICE`/`T_SUPPLIER_INVOICE` haben aktuell KEINE `TAX_AMOUNT`-Spalte; `T_CODE.ID_CODE` ist KEIN IDENTITY; `T_CODE_NEXT` hat `SECURITY_LEVEL`-Spalte für Rollencheck.

## Schnittstellen zu anderen Gruppen

Stand laut User: Werte und Inhalt sind geklärt, **konkrete Spaltennamen** der anderen Gruppen stehen noch aus. Sobald die kommen, müssen `list_views.V_LIST_OUTPUT_VAT` und `list_views.V_LIST_INPUT_VAT` angepasst werden — der Rest der Pipeline (sp_create_vat_statement, fn_*) bleibt unverändert.

- [OFFEN] Gruppe 4 (Eingangsrechnungen): Exakte Spaltennamen für `TAX_AMOUNT` auf `T_SUPPLIER_INVOICE` (oder bleibt es bei Item-Aggregation aus `T_SUPPLIER_INVOICE_ITEM.UNIT_VAT_PCT`)?
- [OFFEN] Gruppe 7 (Ausgangsrechnungen): Exakte Spaltennamen für `TAX_AMOUNT`, `IS_CORRECTION`, `ORIGINAL_INVOICE_ID` auf `T_INVOICE`?
- [OFFEN] Gruppe 8 (Zahlungen / Skonto): Skonto als eigene Korrektur-Rechnung oder Mutation der Ursprungsrechnung?
- [OFFEN] Gruppen 9/10 (Barrechnung Freiburg/Rosenberg): Eigene Tabelle oder Eintrag in `T_INVOICE`?
- [OFFEN] Gruppe 19 (FiBu) ist unbesetzt — bestätigen, dass wir nur theoretisch ausgeben und keinen abnehmenden Konsumenten haben.

## Fachlich

- [OFFEN] Behandlung leerer Perioden (F17): erzeugen wir eine leere Abrechnung mit Hinweis, oder verweigern wir den Anlage-Versuch?
- [OFFEN] Mehrere Steuersätze (Anforderung D): bauen wir vereinfacht mit 19% Fixwert, oder vorbereitend per Steuercode?
- [OFFEN] Wer prüft die zeitliche Cut-off-Logik aus Sicht der Steuerlogik — ist das wirklich nur "Tag ≥ 10"? Was passiert mit Belegen, die nach dem 10. noch nachgeliefert werden?

## Team-intern

- [OFFEN] Finale Frontend-Entscheidung: Python (vorläufig) vs. phpRunner — Stichtag für Wechsel-Option?
- [OFFEN] Repo-Host: GitHub privat, HdM-Gitlab, oder lokal?
- [OFFEN] Aufgabenteilung MS5: Wer baut welchen Teil (SQL / Frontend / Tests / Doku)?

## Organisatorisch / Abgabe

- [OFFEN] Abgabeform Implementierungsphase: deployen wir die DB-Artefakte direkt auf `ERPDEV26S` (dann ist das die "Abgabe")? Wo wird das Test-/Abnahmekonzept eingereicht? Gibt es einen Phase-5-Aufgabentext auf Moodle? — beim nächsten Coaching/Treffen klären
- [OFFEN] Präsentationstermin Phase 5 (Implementierung + Test/Abnahmekonzept) — Datum und Dauer?
- [OFFEN] Aufwände eintragen in den "Dev-Tools" — wer im Team trägt für welche Phase ein?
