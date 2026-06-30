# Offene Fragen

> **Hinweis (ab 2026-06-05):** Die laufende Verwaltung offener Punkte erfolgt über [GitHub Issues](https://github.com/airtime1/SoPra-Umsatzsteuer/issues). Diese Datei bleibt als Archiv und Übersicht — historischer Kontext und Auflösungen werden hier festgehalten, neue offene Punkte aber als Issue anlegen (Templates: `kind: question`, `kind: schnittstelle`, etc.). So sieht das ganze Team Status, Assignee und Fortschritt an einem Ort.

Punkte, die wir extern klären müssen — ans Team, an Prof. Meth / Lehmann, oder an Partner-Gruppen.

Format: `[Status] Frage — Adressat — Datum erstellt`. Status ∈ {OFFEN, GEKLÄRT, OBSOLET}.

## Architektur & Datenbank

- [GEKLÄRT 2026-06-15] Tabellen `T_VAT_STATEMENT`/`T_VAT_STATEMENT_ITEM` und die `T_CODE`/`T_CODE_NEXT`-Einträge liegen in `dbo` und werden vom Architekten angelegt. Wir liefern sie als separates Skript `sql/abgabe/MS5_G15_ARCHITEKT_dbo.sql` (.txt). Unser eigener Anteil (Views/Funcs/Procs in `list_views`/`stored_func`/`stored_proc`) deployen wir selbst.
- [GEKLÄRT 2026-06-15] Prozess: dbo-Skript als .txt an den Architekten (Mail), G15-Bundle deployen wir nach Tabellen-Anlage selbst gegen ERPDEV26S.
- [GEKLÄRT 2026-06-15] Keine `ins_views`/`upd_views` nötig — jeder Schreibvorgang trägt Geschäftslogik und läuft über Stored Procedures; Frontend-User brauchen dafür nur definierte Read-/Execute-Rechte.
- [GEKLÄRT 2026-06-03] HdM-Namenskonventionen liegen in `docs/namenskonventionen/Lerneinheit_7_Datenbankentwicklung.docx` (+ Zusammenfassung in `INDEX.md`). SQL-Skelette entsprechend refactored (ADR-007).
- [GEKLÄRT 2026-06-03] Dev-DB-Snapshot wurde ausgewertet, wird aber nicht committed (siehe `sql/99_devdb_kopie/README.md`). Wichtigste Befunde: `T_INVOICE`/`T_SUPPLIER_INVOICE` haben aktuell KEINE `TAX_AMOUNT`-Spalte; `T_CODE.ID_CODE` ist KEIN IDENTITY; `T_CODE_NEXT` hat `SECURITY_LEVEL`-Spalte für Rollencheck.
- [GEKLÄRT 2026-06-27] APP-Schreibtest gegen ERPDEV26S: Die G15-Procedures referenzierten intern teils alte Objekt-/Function-Namen (`stored_func.fn_get_user_securitylevel`, `V_LIST_OUTPUT_VAT`, `fn_calculate_vat_balance`). Die live vorhandenen Procedures wurden auf `dbo.fn_get_user_securitylevel`, `list_views.V_LIST_G15_*` und `stored_func.fn_G15_*` korrigiert; Anlage, Freigabe, Rueckweisung und Bezahlung liefen ueber den APP-Zugang in einer Rollback-Transaktion erfolgreich.
- [GEKLÄRT 2026-06-27] Nach DEV-DB-Kopie fehlten dem damaligen APP-User-Prototyp (`ERP_REMOTE_USER`) die G15-Ausführungsrechte. Wieder gesetzt wurden `GRANT EXECUTE ON OBJECT::stored_func.fn_G15_check_vat_period`, `GRANT SELECT ON OBJECT::stored_func.fn_G15_calculate_vat_balance` sowie `GRANT EXECUTE` auf `stored_proc.sp_G15_create_vat_statement`, `sp_G15_approve_vat_statement`, `sp_G15_pay_vat_statement`, `sp_G15_reject_vat_statement`.
- [GEKLÄRT 2026-06-29] Die Streamlit-App nutzt keinen gemeinsamen APP-Laufzeituser mehr. Benutzer melden sich mit echten DB-Credentials an; die UI liest den Login via `SUSER_SNAME()` und den Level via `dbo.fn_get_user_securitylevel(SUSER_SNAME())`. Live-Pruefung: `list_views.V_LIST_G15_VAT_USER` ist in ERPDEV26S nicht deployed und daher keine UI-Laufzeitvoraussetzung.
- [OFFEN 2026-06-27] Append-only Verlauf: ERPDEV26S enthaelt keine VAT-spezifische Historientabelle und G15 hat kein `CREATE TABLE`-/`dbo ALTER`-Recht. Saubere DB-Erweiterung durch Prof/Architekt: `dbo.T_G15_VAT_STATEMENT_HISTORY(VAT_STATEMENT_HISTORY_ID IDENTITY PK, VAT_STATEMENT_ID FK, EVENT_TYPE, OLD_STATUS, NEW_STATUS, EVENT_BY, EVENT_AT DEFAULT GETDATE())`, plus passende Grants fuer die echten DB-Frontend-User oder Insert ausschliesslich ueber entsprechend angepasste G15-Procedures. Die UI kann eine passende View `list_views.V_LIST_G15_VAT_STATEMENT_HISTORY` bereits defensiv lesen.

## Schnittstellen zu anderen Gruppen

Stand der aktuellen Repository-Dokumentation: Werte und Inhalt sind fachlich vorgeklaert, konkrete Schnittstellenfragen bleiben aber offen. Die lesende DEV-Pruefung am 2026-06-07 bestaetigte `T_INVOICE`, `T_INVOICE_ITEM`, `T_SUPPLIER_INVOICE`, `T_SUPPLIER_INVOICE_ITEM`, `T_PAYMENT_RECEIPT`, `T_CODE`, `T_CODE_NEXT` und `T_USER` als relevante Integrationsbereiche. Details stehen in `docs/schnittstellen_annahmen.md`. Wenn Schnittstellen finalisiert werden, sollen primaer die Views angepasst werden; der Rest der Pipeline (`stored_proc.sp_G15_create_vat_statement`, `stored_func.fn_*`) bleibt möglichst unverändert.

> **Grundsatzentscheidung 2026-06-15 (ADR-008):** Wir berechnen keine Steuerbeträge selbst. Jede Partner-Gruppe liefert `RechnungsID`, `RechnungsDatum`, `Steuerbetrag` (bzw. `Steuerkorrekturbetrag`) über ihre `list_views.V_LIST_*`-View. Fehlt ein Feld/eine View, ist das Bring-Schuld der Partner; bis dahin Stub. Issues #24-#28 erfasst den konkreten Stand.

- [AKTUALISIERT 2026-06-23] Gruppe 4 (Eingangsrechnungen): G4 hat seit 23.06. `list_views.V_LIST_SUPPLIER_INVOICE` (UPPER_SNAKE, mit `INVOICE_ID, INVOICE_DATE, TOTAL_VAT_AMOUNT`) geliefert. `V_LIST_G15_INPUT_VAT` ist aktiv und liest `TOTAL_VAT_AMOUNT` als `TAX_AMOUNT`. Offen nur noch: G4 muss Rechnungsdaten einspielen (View aktuell 0 Zeilen). Hinweis: View heißt `V_LIST_SUPPLIER_INVOICE` (nicht `V_LIST_G04_SUPPLIER_INVOICE`), Spalte `TOTAL_VAT_AMOUNT` statt `TAX_AMOUNT`. Status-Filterung ist Sache von G4 (Issue #24).
- [GEKLÄRT 2026-06-13/ADR-008] Gruppe 7 (Ausgangsrechnungen): `list_views.V_LIST_G07_INVOICE` ist vorhanden und liefert `BetragUstEUR`/`RechnungsDatum`. Wir konsumieren das direkt (Mapping auf `TAX_AMOUNT`/`INVOICE_DATE`); die frühere Item-Aggregation über `T_MATERIAL.VAT` ist damit obsolet. Offen: Umbenennung auf UPPER_SNAKE (Issue #25) und Erweiterung der View auf **alle** Ausgangsrechnungen (auch B2C G9/G10 ohne Angebot→Auftrag→Lieferung-Kette; Diagnose 2026-06-23: nur 83 von 161 G9-Rechnungen sichtbar).
- [AKTUALISIERT 2026-06-23/ADR-010] Gruppe 8 (Zahlungen / Skonto): G8 liefert künftig je Zahlungseingang den **finalen** Steuerbetrag der Rechnung nach Skonto + `INVOICE_ID` + Skonto-Flag, keinen separaten Korrekturbetrag mehr. Wir überschreiben damit den Rechnungsbetrag (Match über `INVOICE_ID`), kein `-1 * …` mehr. Stand 23.06.: `V_LIST_G08_PAYMENT_RECEIPT` hat das Skonto-Flag `SKONTO_BERECHTIGT_YN` (Y/N), aber noch **keinen finalen Steuerbetrag** → `V_LIST_G15_VAT_SKONTO` bleibt Stub. Wir leiten den Steueranteil NICHT aus `DIFFERENCE_AMOUNT` ab (ADR-008). Bring-Schuld: finaler Steuerbetrag, Issue #26.
- [GEKLÄRT 2026-06-16] Gruppen 9/10 (Barrechnung Rosenberg/Freiburg): keine eigenen Quellen mehr. G9/G10 schreiben über dieselbe `dbo.T_INVOICE` wie G7 und laufen über `V_LIST_G07_INVOICE` mit. Voraussetzung: G7 erweitert die View auf alle T_INVOICE-Rechnungen (Issues #27/#28 jetzt G7-seitig). Eigene G9/G10-Blöcke in `V_LIST_G15_OUTPUT_VAT` entfallen.
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
