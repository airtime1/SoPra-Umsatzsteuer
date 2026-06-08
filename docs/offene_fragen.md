# Offene Fragen

> **Hinweis (ab 2026-06-05):** Die laufende Verwaltung offener Punkte erfolgt über [GitHub Issues](https://github.com/airtime1/SoPra-Umsatzsteuer/issues). Diese Datei bleibt als Archiv und Übersicht — historischer Kontext und Auflösungen werden hier festgehalten, neue offene Punkte aber als Issue anlegen (Templates: `kind: question`, `kind: schnittstelle`, etc.). So sieht das ganze Team Status, Assignee und Fortschritt an einem Ort.

Punkte, die wir extern klären müssen — ans Team, an Prof. Meth / Lehmann, oder an Partner-Gruppen.

Format: `[Status] Frage — Adressat — Datum erstellt`. Status ∈ {OFFEN, GEKLÄRT, OBSOLET}.

## Architektur & Datenbank

- [OFFEN] In welchem Schema werden unsere Tabellen `T_VAT_STATEMENT` und `T_VAT_STATEMENT_ITEM` angelegt? `dbo` ist gesperrt, aber kein eigenes Schema für Tabellen erwähnt — gehen die ans `dbo`-Architekt-Schema? — Architekt (Peter Lehmann)
- [OFFEN] Wie ist der konkrete Prozess zur Anlage von Tabellen / T_CODE-Einträgen? Skript per Mail an den Architekt? Pull-Request? — Architekt
- [OFFEN] Brauchen wir `ins_views` / `upd_views` für jeden Schreibvorgang aus dem Frontend, oder darf `ERP_REMOTE_USER` direkt auf Tabellen schreiben? — Architekt
- [GEKLÄRT 2026-06-03] HdM-Namenskonventionen liegen in `docs/namenskonventionen/Lerneinheit_7_Datenbankentwicklung.docx` (+ Zusammenfassung in `INDEX.md`). SQL-Skelette entsprechend refactored (ADR-007).
- [GEKLÄRT 2026-06-03] Dev-DB-Snapshot wurde ausgewertet, wird aber nicht committed (siehe `sql/99_devdb_kopie/README.md`). Wichtigste Befunde: `T_INVOICE`/`T_SUPPLIER_INVOICE` haben aktuell KEINE `TAX_AMOUNT`-Spalte; `T_CODE.ID_CODE` ist KEIN IDENTITY; `T_CODE_NEXT` hat `SECURITY_LEVEL`-Spalte für Rollencheck.

## Schnittstellen zu anderen Gruppen

Stand der aktuellen Repository-Dokumentation: Werte und Inhalt sind fachlich vorgeklaert, konkrete Schnittstellenfragen bleiben aber offen. Die lesende DEV-Pruefung am 2026-06-07 bestaetigte `T_INVOICE`, `T_INVOICE_ITEM`, `T_SUPPLIER_INVOICE`, `T_SUPPLIER_INVOICE_ITEM`, `T_PAYMENT_RECEIPT`, `T_CODE`, `T_CODE_NEXT` und `T_USER` als relevante Integrationsbereiche. Details stehen in `docs/schnittstellen_annahmen.md`. Wenn Schnittstellen finalisiert werden, sollen primaer die Views angepasst werden; der Rest der Pipeline (`stored_proc.sp_create_vat_statement`, `stored_func.fn_*`) bleibt möglichst unverändert.

- [OFFEN] Gruppe 4 (Eingangsrechnungen): Exakte Spaltennamen für `TAX_AMOUNT` auf `T_SUPPLIER_INVOICE` (oder bleibt es bei Item-Aggregation aus `T_SUPPLIER_INVOICE_ITEM.UNIT_VAT_PCT`)?
- [OFFEN] Gruppe 4 (Eingangsrechnungen): Finale Statuswerte fuer steuerlich relevante Vorsteuer bestaetigen; aktuell nutzt `V_LIST_INPUT_VAT` `AN BUCHHALTUNG UEBERMITTELT`.
- [GEKLÄRT 2026-06-06] Gruppe 7 (Ausgangsrechnungen): `T_INVOICE` hat keine `TAX_AMOUNT`-Spalte; `list_views.V_LIST_OUTPUT_VAT` aggregiert über `T_INVOICE_ITEM` und `T_MATERIAL.VAT`.
- [OFFEN] Gruppe 7 (Ausgangsrechnungen): Belastbare Schnittstelle für `IS_CORRECTION` und `ORIGINAL_INVOICE_ID`.
- [OFFEN] Gruppe 8 (Zahlungen / Skonto): Skonto als eigene Korrektur-Rechnung, Zahlungskorrektur in `T_PAYMENT_RECEIPT` oder Mutation der Ursprungsrechnung?
- [OFFEN] Gruppe 8 (Zahlungen / Skonto): Bedeutung von `DIFFERENCE_AMOUNT`, `SKONTO_BERECHTIGT_YN`, `STORNO_YN` und `STORNO_REFERENCE_ID` verbindlich klaeren; DEV-Spalten existieren, sind aber kaum gefuellt, bekannte Sandbox kann aelter sein.
- [OFFEN] Gruppen 9/10 (Barrechnung Freiburg/Rosenberg): Eigene Tabelle oder Eintrag in `T_INVOICE`?
- [OFFEN] Gruppe 19 (FiBu) ist unbesetzt — bestätigen, dass wir nur theoretisch ausgeben und keinen abnehmenden Konsumenten haben.

## Fachlich

- [OFFEN] Behandlung leerer Perioden (F17): erzeugen wir eine leere Abrechnung mit Hinweis, oder verweigern wir den Anlage-Versuch?
- [OFFEN] Mehrere Steuersätze (Anforderung D): bauen wir vereinfacht mit 19% Fixwert, oder vorbereitend per Steuercode?
- [OFFEN] Wer prüft die zeitliche Cut-off-Logik aus Sicht der Steuerlogik — ist das wirklich nur "Tag ≥ 10"? Aktuelle Umsetzung: spaete Belege/Korrekturen fliessen ueber ihr eigenes Belegdatum in die naechste offene Periode und veraendern abgeschlossene Perioden nicht.

## Team-intern

- [OFFEN] Finale Frontend-Entscheidung: Python (vorläufig) vs. phpRunner — Stichtag für Wechsel-Option?
- [GEKLÄRT 2026-06-05] Repo-Host ist GitHub (`airtime1/SoPra-Umsatzsteuer`) mit Issues, PR-Template und Issue-Templates.
- [OFFEN] Aufgabenteilung MS5: Wer baut welchen Teil (SQL / Frontend / Tests / Doku)?

## Organisatorisch / Abgabe

- [OFFEN] Abgabeform Implementierungsphase: deployen wir die DB-Artefakte direkt auf `ERPDEV26S` (dann ist das die "Abgabe")? Wo wird das Test-/Abnahmekonzept eingereicht? Gibt es einen Phase-5-Aufgabentext auf Moodle? — beim nächsten Coaching/Treffen klären
- [OFFEN] Präsentationstermin Phase 5 (Implementierung + Test/Abnahmekonzept) — Datum und Dauer?
- [OFFEN] Aufwände eintragen in den "Dev-Tools" — wer im Team trägt für welche Phase ein?
