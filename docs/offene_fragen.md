# Offene Fragen

> **Hinweis (ab 2026-06-05):** Die laufende Verwaltung offener Punkte erfolgt über [GitHub Issues](https://github.com/airtime1/SoPra-Umsatzsteuer/issues). Diese Datei bleibt als Archiv und Übersicht — historischer Kontext und Auflösungen werden hier festgehalten, neue offene Punkte aber als Issue anlegen (Templates: `kind: question`, `kind: schnittstelle`, etc.). So sieht das ganze Team Status, Assignee und Fortschritt an einem Ort.

Punkte, die wir extern klären müssen — ans Team, an Prof. Meth / Lehmann, oder an Partner-Gruppen.

Format: `[Status] Frage — Adressat — Datum erstellt`. Status ∈ {OFFEN, GEKLÄRT, OBSOLET}.

## Architektur & Datenbank

- [GEKLÄRT 2026-06-15] Tabellen `T_VAT_STATEMENT`/`T_VAT_STATEMENT_ITEM` und die `T_CODE`/`T_CODE_NEXT`-Einträge liegen in `dbo` und werden vom Architekten angelegt. Wir liefern sie als separates Skript `sql/abgabe/MS5_G15_ARCHITEKT_dbo.sql` (.txt). Unser eigener Anteil (Views/Funcs/Procs in `list_views`/`stored_func`/`stored_proc`) deployen wir selbst.
- [GEKLÄRT 2026-06-15] Prozess: dbo-Skript als .txt an den Architekten (Mail), G15-Bundle deployen wir nach Tabellen-Anlage selbst gegen ERPDEV26S.
- [GEKLÄRT 2026-06-15] Keine `ins_views`/`upd_views` nötig — jeder Schreibvorgang trägt Geschäftslogik und läuft über Stored Procedures; `ERP_REMOTE_USER` hat nur EXECUTE/Read.
- [GEKLÄRT 2026-06-03] HdM-Namenskonventionen liegen in `docs/namenskonventionen/Lerneinheit_7_Datenbankentwicklung.docx` (+ Zusammenfassung in `INDEX.md`). SQL-Skelette entsprechend refactored (ADR-007).
- [GEKLÄRT 2026-06-03] Dev-DB-Snapshot wurde ausgewertet, wird aber nicht committed (siehe `sql/99_devdb_kopie/README.md`). Wichtigste Befunde: `T_INVOICE`/`T_SUPPLIER_INVOICE` haben aktuell KEINE `TAX_AMOUNT`-Spalte; `T_CODE.ID_CODE` ist KEIN IDENTITY; `T_CODE_NEXT` hat `SECURITY_LEVEL`-Spalte für Rollencheck.

## Schnittstellen zu anderen Gruppen

Stand der aktuellen Repository-Dokumentation: Werte und Inhalt sind fachlich vorgeklaert, konkrete Schnittstellenfragen bleiben aber offen. Die lesende DEV-Pruefung am 2026-06-07 bestaetigte `T_INVOICE`, `T_INVOICE_ITEM`, `T_SUPPLIER_INVOICE`, `T_SUPPLIER_INVOICE_ITEM`, `T_PAYMENT_RECEIPT`, `T_CODE`, `T_CODE_NEXT` und `T_USER` als relevante Integrationsbereiche. Details stehen in `docs/schnittstellen_annahmen.md`. Wenn Schnittstellen finalisiert werden, sollen primaer die Views angepasst werden; der Rest der Pipeline (`stored_proc.sp_create_vat_statement`, `stored_func.fn_*`) bleibt möglichst unverändert.

> **Grundsatzentscheidung 2026-06-15 (ADR-008):** Wir berechnen keine Steuerbeträge selbst. Jede Partner-Gruppe liefert `RechnungsID`, `RechnungsDatum`, `Steuerbetrag` (bzw. `Steuerkorrekturbetrag`) über ihre `list_views.V_LIST_*`-View. Fehlt ein Feld/eine View, ist das Bring-Schuld der Partner; bis dahin Stub. Issues #24-#28 erfasst den konkreten Stand.

- [GEKLÄRT 2026-06-13] Gruppe 4 (Eingangsrechnungen): Keine `V_LIST_G04_*`-View in ERPDEV vorhanden → Stub in `V_LIST_INPUT_VAT`. Erwartet: `list_views.V_LIST_G04_SUPPLIER_INVOICE` mit `INVOICE_ID, INVOICE_DATE, TAX_AMOUNT` (Issue #24). Status-Filterung ist Sache von G4.
- [GEKLÄRT 2026-06-13/ADR-008] Gruppe 7 (Ausgangsrechnungen): `list_views.V_LIST_G07_INVOICE` ist vorhanden und liefert `BetragUstEUR`/`RechnungsDatum`. Wir konsumieren das direkt (Mapping auf `TAX_AMOUNT`/`INVOICE_DATE`); die frühere Item-Aggregation über `T_MATERIAL.VAT` ist damit obsolet. Offen nur: Umbenennung auf UPPER_SNAKE (Issue #25).
- [GEKLÄRT 2026-06-13] Gruppe 8 (Zahlungen / Skonto): `list_views.V_LIST_G08_PAYMENT_RECEIPT` vorhanden, aber ohne `TAX_CORRECTION_AMOUNT`. G8 liefert den Steuerkorrekturbetrag (positiv), wir negieren ihn als Korrekturzeile. Wir leiten den Steueranteil NICHT aus `DIFFERENCE_AMOUNT` ab (ADR-008). Bring-Schuld: Issue #26.
- [GEKLÄRT 2026-06-13] Gruppen 9/10 (Barrechnung Rosenberg/Freiburg): fachlich gleichwertig zu G7, fließen per `UNION ALL` in `V_LIST_OUTPUT_VAT`. G9 `V_LIST_G09_INVOICE_TAX_B2C` vorhanden, aber ohne `TAX_AMOUNT` (Issue #27); G10-View fehlt komplett (Issue #28). Beide als Stub.
- [OFFEN] Gruppe 19 (FiBu) ist unbesetzt — bestätigen, dass wir nur theoretisch ausgeben und keinen abnehmenden Konsumenten haben.

## Fachlich

- [OFFEN] Behandlung leerer Perioden (F17): erzeugen wir eine leere Abrechnung mit Hinweis, oder verweigern wir den Anlage-Versuch?
- [OFFEN] Mehrere Steuersätze (Anforderung D): bauen wir vereinfacht mit 19% Fixwert, oder vorbereitend per Steuercode?
- [GEKLÄRT 2026-06-15] Zeitliche Cut-off-Logik: Zwei getrennte Datumsregeln. (1) Belegzuordnung zur Periode rein über das Rechnungsdatum (`SOURCE_INVOICE_DATE BETWEEN`). (2) Frueheste Abrechenbarkeit = 10. des Folgemonats, weil dann die 7-Tage-Skontofrist abgelaufen ist und alle Skonto-Korrekturen feststehen (passt zu § 18 UStG). Spaete Belege/Korrekturen fliessen über ihr eigenes Belegdatum in die naechste offene Periode und veraendern abgeschlossene Perioden nicht.

## Team-intern

- [OFFEN] Finale Frontend-Entscheidung: Python (vorläufig) vs. phpRunner — Stichtag für Wechsel-Option?
- [GEKLÄRT 2026-06-05] Repo-Host ist GitHub (`airtime1/SoPra-Umsatzsteuer`) mit Issues, PR-Template und Issue-Templates.
- [OFFEN] Aufgabenteilung MS5: Wer baut welchen Teil (SQL / Frontend / Tests / Doku)?

## Organisatorisch / Abgabe

- [OFFEN] Abgabeform Implementierungsphase: deployen wir die DB-Artefakte direkt auf `ERPDEV26S` (dann ist das die "Abgabe")? Wo wird das Test-/Abnahmekonzept eingereicht? Gibt es einen Phase-5-Aufgabentext auf Moodle? — beim nächsten Coaching/Treffen klären
- [OFFEN] Präsentationstermin Phase 5 (Implementierung + Test/Abnahmekonzept) — Datum und Dauer?
- [OFFEN] Aufwände eintragen in den "Dev-Tools" — wer im Team trägt für welche Phase ein?
