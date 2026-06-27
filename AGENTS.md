# Agenten-Briefing — SoPra Umsatzsteuerabrechnung

Diese Datei ist die gemeinsame Arbeitsgrundlage fuer Claude, Codex und andere KI-Agents in diesem Repository. Tool-spezifische Einstiegspunkte wie `CLAUDE.md` duerfen nur auf diese Datei verweisen oder sehr kurze Tool-Hinweise enthalten. Projektregeln, Architekturwissen und Arbeitsablaeufe werden hier nur einmal gepflegt.

## Projekt in einem Satz

Gruppe 15 baut fuer das HdM-SoPra SoSe 2026 ein Konzern-ERP-Modul zur monatlichen Umsatzsteuerabrechnung: Ein- und Ausgangsrechnungen werden je Periode aggregiert, Zahllast oder Ueberhang berechnet, in einem Status-Workflow verarbeitet und revisionssicher als Abrechnungsbeleg gespeichert.

Nicht Teil dieses Moduls: Erzeugung von Rechnungen, Rechnungskorrekturen in vorgelagerten Modulen, Steuerberechnung pro Rechnungsposition, elektronische Uebermittlung ans Finanzamt und vollstaendige FiBu.

## Wer arbeitet womit

- Nils arbeitet mit Claude.
- Moritz arbeitet mit Codex.
- Abel arbeitet im gleichen Team-Repo mit.
- Claude liest `CLAUDE.md` als Einstieg und wird von dort hierher verwiesen.
- Codex und andere Agents lesen `AGENTS.md` als gemeinsamen Projektkontext.

## Vor jeder Aufgabe lesen

Immer zuerst:
- `AGENTS.md`
- `CONTRIBUTING.md`
- `README.md`

## Git-Synchronisation vor neuen Aufgaben

Vor Beginn jeder neuen Aufgabe pruefen Agents den aktuellen Git-Zustand:
- aktuellen Branch und Status anzeigen (`git status --short --branch`)
- lokale Basis gegen `origin/main` einordnen (`git fetch origin` und geeignete Log-/Status-Pruefung)
- neue Branches nur von einem aktuellen `main` bzw. `origin/main` erstellen

Wenn uncommitted Aenderungen vorhanden sind, darf der Agent nicht eigenmaechtig Branches wechseln, rebasen, pullen oder stashen. Der Agent meldet zuerst die betroffenen Dateien, ordnet ein, ob sie zur aktuellen Aufgabe gehoeren, und wartet auf Freigabe.

Wenn der lokale Stand nicht aktuell ist, aktualisiert der Agent ihn vor Beginn der Aufgabe sauber auf `origin/main` oder meldet, warum das nicht moeglich ist. Nach der Synchronisation bestaetigt der Agent kurz, auf welchem Branch und welcher Basis weitergearbeitet wird.

Je nach Aufgabe zusaetzlich:

| Aufgabe | Zusaetzlich lesen |
|---|---|
| SQL-Objekte, DB-Logik, Stored Procs/Functions | `sql/README.md`, relevante Dateien in `sql/`, `docs/entscheidungen/`, `docs/namenskonventionen/INDEX.md` |
| Frontend / Streamlit | `app/main.py`, `app/services/vat.py`, relevante Datei in `app/pages/`, ADR-006 |
| Tests / Abnahme | `tests/README.md`, `tests/test_cases.md`, `tests/abnahmekriterien.md`, `tests/sql/README.md` |
| Deployment / Sandbox | `scripts/deploy_sandbox.py`, `scripts/deploy_dev.py`, `sql/README.md`, `.env.example` |
| Fachliche oder Architekturentscheidung | passende ADR in `docs/entscheidungen/`; bei neuer Entscheidung neue ADR nach `000-template.md` |
| Schnittstellen zu anderen Gruppen | `docs/offene_fragen.md`, Kommentare in `sql/02_views/`, GitHub Issues |
| Namensgebung | `docs/namenskonventionen/INDEX.md`, ADR-003, ADR-007 |
| Onboarding / Setup | `ONBOARDING.md`, `README.md` |

## Dokumentationsregel fuer alle Aenderungen

Bei jeder Aenderung pruefen Claude und Codex automatisch, ob Markdown-Dokumentation im selben Commit angepasst werden muss.

Dokumentation muss aktualisiert werden, wenn sich eines davon aendert:
- Architektur, Datenmodell, DB-Objekte oder Objekt-Namen
- App-Flow, zentrale Service-Logik oder sichtbare UI-Ablaeufe
- Deployment-, Sandbox- oder Umgebungslogik
- Teststrategie, Testskripte oder Abnahmekriterien
- Team-Workflow, Branch-/PR-Regeln oder Agenten-Arbeitsregeln
- bekannte Einschraenkungen, offene Punkte oder Schnittstellenannahmen

Arbeitsdokumentation beschreibt immer den aktuellen Soll-Zustand. Veraltete Aussagen werden ueberschrieben oder geloescht, nicht daneben relativiert. Historie, Gruende und alte Zustaende gehoeren nur in passende ADRs, Changelog-/Decision-Bereiche, Commit-Bodies oder GitHub Issues.

## Aktueller technischer Aufbau

- Datenbank: MS SQL Server auf `edu.hdm-server.eu`.
- Gemeinsame Entwicklungsdatenbank: `ERPDEV26S`.
- Eigene Sandbox: persoenliche Datenbank nach Muster `s26s5xx_DATAMART`.
- Frontend: Python 3.11+, Streamlit, pyodbc, python-dotenv, pandas.
- Die finale Streamlit-App nutzt den vorgesehenen APP-Zugang direkt (`get_app_conn()`), nicht die Sandbox. `APP_DB_PROFILE`/`get_active_conn()` existiert noch fuer Legacy-/Hilfszwecke, ist aber nicht mehr die Laufzeitquelle der UI.
- Tests: SQL-Testskripte gegen Sandbox; pytest ist als geplanter Wrapper in `requirements.txt`, eine Python-Test-Suite ist noch nicht angelegt.
- Repo-Workflow: GitHub Team-Repo mit Feature-Branches, Pull Requests, mindestens einem Review und Squash-Merge.

## Datenbank- und Objektmodell

Eigene Tabellen liegen fachlich in `dbo`, koennen dort aber nur durch den Architekten angelegt werden. Die Skripte in `sql/00_setup/` und `sql/01_tables/` sind deshalb Lieferartefakte fuer den Architekten und duerfen in der gemeinsamen Dev-DB nicht eigenmaechtig ausgefuehrt werden.

Wichtige eigene Objekte:

| Objekt | Zweck |
|---|---|
| `dbo.T_VAT_STATEMENT` | Kopf einer monatlichen Umsatzsteuerabrechnung |
| `dbo.T_VAT_STATEMENT_ITEM` | Detailzeilen mit einzelnen Steuerfaellen |
| `list_views.LOV_VAT_STATUS` | Werteliste fuer `DRAFT`, `APPROVED`, `PAID` |
| `list_views.V_LIST_G15_OUTPUT_VAT` | Umsatzsteuer aus allen Ausgangsrechnungen; konsumiert `TAX_AMOUNT` direkt, keine Eigenberechnung (ADR-008) |
| `list_views.V_LIST_G15_VAT_SKONTO` | finaler Steuerbetrag je Rechnung aus G8 (Skonto); Quelle fuer den Ueberschreib-Schritt in `sp_G15_create_vat_statement` (ADR-010), aktuell Stub |
| `list_views.V_LIST_G15_INPUT_VAT` | Vorsteuer aus G4 (Wareneingaenge); konsumiert `TAX_AMOUNT` direkt aus der Partner-Lese-View, keine Eigenberechnung (ADR-008) |
| `list_views.V_LIST_G15_VAT_STATEMENT` | Anzeige-View fuer Abrechnungskopf |
| `list_views.V_LIST_G15_VAT_STATEMENT_ITEM` | Anzeige-View fuer Abrechnungspositionen |
| `dbo.T_USER` / `dbo.fn_get_user_securitylevel` | APP-lesbare Demo-User und zentrale Security-Level-Function; in ERPDEV26S gibt es aktuell keine G15-User-View |
| `stored_func.fn_G15_check_vat_period` | Prueft Periodenformat, 10.-des-Folgemonats-Regel und Sperrstatus |
| `stored_func.fn_G15_calculate_vat_balance` | Berechnet `VAT_BALANCE` als Absolutbetrag und `VAT_TYPE` |
| `stored_proc.sp_G15_create_vat_statement` | Legt Abrechnung an oder berechnet bestehenden `DRAFT` neu |
| `stored_proc.sp_G15_approve_vat_statement` | Statuswechsel `DRAFT` -> `APPROVED` |
| `stored_proc.sp_G15_pay_vat_statement` | Statuswechsel `APPROVED` -> `PAID` |
| `stored_proc.sp_G15_reject_vat_statement` | Rueckgabe `APPROVED` -> `DRAFT` |

Datenquellen (Beschluss 2026-06-16): Umsatzsteuer aus **einer** Quelle `V_LIST_G07_INVOICE` (G7-View ueber `dbo.T_INVOICE`; G9 Bar Rosenberg und G10 Bar Freiburg schreiben ueber dieselbe Tabelle und laufen darueber mit); Vorsteuer aus G4 (Wareneingaenge); finaler Steuerbetrag nach Skonto aus G8 (Zahlungseingaenge), der den Rechnungsbetrag ueberschreibt (ADR-010). Wir lesen `RechnungsID`, `RechnungsDatum`, `Steuerbetrag` direkt aus den Partner-Lese-Views, keine Eigenberechnung. Details und aktueller Lieferstand: `docs/zielbild.md`, `docs/schnittstellen_annahmen.md`.

Verbindliche DB-Regeln:
- `dbo` nicht direkt veraendern; Skripte fuer Tabellen und `T_CODE`/`T_CODE_NEXT` an den Architekten liefern (`sql/abgabe/MS5_G15_ARCHITEKT_dbo.sql`).
- Keine eigene Steuerberechnung: Steuerbetraege kommen fertig aus den Partner-Views, fehlende Felder/Views sind Bring-Schuld der Partner (ADR-008). Noch nicht gelieferte Quellen laufen als Stub (`WHERE 1 = 0`).
- Statusuebergaenge pruefen die Status-Procedures ueber die zentrale Architekten-Function `dbo.fn_chk_status_folge` (liest `dbo.T_CODE_NEXT`, ADR-009); die Rolle bleibt eigene Pruefung.
- Geschaeftslogik liegt moeglichst in Stored Functions/Procedures, nicht im Frontend.
- HdM-Namenskonventionen strikt einhalten: Tabellen und Tabellenspalten UPPER_CASE, Procedures/Functions klein mit `sp_`/`fn_`, Views mit `LOV_`, `V_LIST_`, `V_INS_`, `V_UPD_`.
- `VAT_BALANCE` ist immer ein nicht-negativer Absolutbetrag; `VAT_TYPE` unterscheidet `ZAHLLAST`, `UEBERHANG`, `NEUTRAL`.
- Abgeschlossene oder freigegebene Abrechnungen duerfen nicht neu berechnet werden; nur `DRAFT` darf durch `stored_proc.sp_G15_create_vat_statement` ersetzt werden.
- Eine Periode darf nur einmal existieren (`VAT_PERIOD` eindeutig). Bestehende Sandbox-/DEV-Instanzen werden ueber idempotente Constraint-Skripte nachgezogen.
- Status-Procedures pruefen Rollen ueber `T_CODE_NEXT.SECURITY_LEVEL` und `T_USER.SECURITYLEVEL`: Sachbearbeiter `1`, Leitung FiBu `2`, CFO `3`.

## App-Flow

Streamlit findet die Seiten automatisch unter `app/pages/`.

1. `app/main.py` rendert die mockup-nahe Hauptseite/Übersicht.
2. `app/pages/1_Übersicht.py` rendert dieselbe Übersicht fuer Streamlit-Multipage-Navigation.
3. `app/pages/2_Neue_Abrechnung.py` leitet Perioden aus Quellbelegen, bestehenden Abrechnungen und `stored_func.fn_G15_check_vat_period` ab und legt ueber `stored_proc.sp_G15_create_vat_statement` an.
4. `app/pages/3_Abrechnung_auswählen.py` zeigt Auswahl, Kopf, Positionen, Verlauf und ruft die `stored_proc.sp_G15_*`-Status-Procedures rollenabhaengig auf.
5. `app/ui.py` enthaelt nur gemeinsame Darstellung, Formatierung, Dialoge und Navigation.
6. `app/services/vat.py` ist die duenne Service-Schicht fuer Datenbankaufrufe, liest aus den G15-Anzeige-Views und nutzt fuer die UI direkt `get_app_conn()`.
7. `app/db.py` liest `.env` und stellt App-, Dev- und Sandbox-Verbindungen bereit; die finale App nutzt davon den APP-Zugang.

Die Sandbox ist fuer die finale UI nicht mehr Laufzeitbasis. Lokale UI-Pruefung erfolgt gegen den vorgesehenen APP-Zugang auf `ERPDEV26S`.

Die UI enthaelt weiterhin keine echte Authentifizierung. Sie ordnet die Dropdowns `Fachkraft 1/2/3` den APP-lesbaren Demo-Usern `fachb1/2/3` aus `dbo.T_USER` zu; die verbindliche Rollenpruefung liegt in den Stored Procedures.

## Deployment und Sandbox

- `scripts/deploy_sandbox.py` fuehrt die Ordner aus `sql/` in definierter Reihenfolge gegen die eigene Sandbox aus: `00_setup`, `01_tables`, `02_views`, `03_stored_func`, `04_stored_proc`, `05_ins_upd_views`, `99_seed`.
- `scripts/deploy_dev.py` deployt nur Objekte in erlaubten Schemata gegen `ERPDEV26S`: `02_views`, `03_stored_func`, `04_stored_proc`, `05_ins_upd_views`.
- `deploy_dev.py` fragt interaktiv nach Bestaetigung. Nicht automatisiert oder ohne ausdrueckliche Freigabe gegen die gemeinsame Dev-DB deployen.
- `.env.example` ist nur ein Template und enthaelt `APP_DB_PROFILE=app` als Default. `.env` und echte Credentials niemals committen, anzeigen oder in Logs ausgeben.

## Tests und Abnahme

- `tests/test_cases.md` ist der Testfall-Katalog.
- `tests/abnahmekriterien.md` beschreibt SPC-1 bis SPC-9.
- `tests/sql/fn_calculate_vat_balance_basic.sql` prueft die Saldo-/Typberechnung.
- `tests/sql/sp_create_vat_statement_demo.sql` prueft die Anlage der Demo-Abrechnung gegen Seed-Daten.
- `tests/sql/sp_status_workflow_roles_demo.sql` prueft Statusfolge, Rollen und Sperre bezahlter Perioden.
- `tests/sql/README.md` beschreibt die Konvention fuer weitere SQL-Tests.
- Ein `tests/python/`-pytest-Wrapper ist dokumentiert, aber noch nicht umgesetzt.
- Tests laufen gegen eine bekannte Sandbox mit Seed-Daten; `sql/99_seed/001_demo_vat_workflow.sql` erzeugt realistische Demo-Belege.

## Dauerhaft relevante Entscheidungen

Die ADRs in `docs/entscheidungen/` dokumentieren den aktuellen Entscheidungsstand. Akzeptierte ADRs sind verbindlich; vorgeschlagene ADRs markieren bewusst noch offene Entscheidungen.

| ADR | Entscheidung |
|---|---|
| 001 | Statusmodell `DRAFT` -> `APPROVED` -> `PAID`, Rueckgabe `APPROVED` -> `DRAFT` |
| 002 | Rollen: Sachbearbeiter legt an, CFO gibt frei, Leitung FiBu zahlt aus |
| 003 | Fachliche Namen: `VAT_STATUS`, `SOURCE_INVOICE_DATE` |
| 004 | Saldo als Absolutbetrag plus `VAT_TYPE` |
| 005 | ~~Korrekturen als eigene Item-Zeilen~~ — abgeloest durch ADR-010 |
| 006 | Frontend vorerst Python/Streamlit/pyodbc, Logik bleibt DB-nah wegen moeglichem phpRunner-Wechsel |
| 007 | HdM-Namenskonventionen und Dev-DB-Befunde sind massgeblich |
| 008 | Keine eigene Steuerberechnung; Partner-Lese-Views konsumieren; Stub-Pattern fuer fehlende Quellen |
| 009 | Status-Procedures nutzen zentrale `dbo.fn_chk_status_folge` fuer Uebergangspruefung |
| 010 | Skonto-Korrektur ueberschreibt finalen Steuerbetrag der Rechnung (loest ADR-005 ab); G8 liefert Endbetrag + `IS_SKONTO` |

Aus der Git-Historie dauerhaft relevant:
- PR #17 bereinigte alte Grossschreibungs-Referenzen auf Function-/Procedure-Namen. Neue Doku darf nicht mehr `SF_*`/`SP_*` als aktuelle Objektnamen verwenden, ausser beim historischen MS4-Mapping.
- PR #18 fuegte `ONBOARDING.md` als Setup-Leitfaden fuer neue Team-Mitglieder hinzu.
- PR #19 fuegte `APP_DB_PROFILE` fuer umschaltbare App-Verbindungen (`app`, `dev`, `sandbox`) hinzu, stabilisierte Streamlit-Page-Imports und stellte die App-Services auf `get_active_conn()` um. (Die damalige Item-Aggregation in `V_LIST_OUTPUT_VAT` wurde mit ADR-008 durch direkten Konsum der Partner-Lese-Views ersetzt.)
- Der Team-Repo-Workflow mit GitHub-Issues, PR-Template und Issue-Templates wurde in `CONTRIBUTING.md` etabliert.
- Die HdM-Namenskonventionen und Dev-DB-Befunde wurden in ADR-007, `docs/namenskonventionen/INDEX.md`, SQL-Kommentaren und `docs/offene_fragen.md` eingearbeitet. Die lokale Dev-DB-Kopie selbst wird nicht committed.

## Bekannte Einschraenkungen und offene Punkte

- Partner-Lieferstand 2026-06-16 gegen ERPDEV26S: G7 (`V_LIST_G07_INVOICE`) aktiv, aber deutsche Spaltennamen (Mapping in unserer View) und **nur Fernabsatz** — die View filtert ueber INNER JOINs auf die Angebot->Auftrag->Lieferung-Kette, B2C-Barverkaeufe (G9/G10) fehlen noch (78 von 156 G9-Rechnungen sichtbar). G7 muss die View auf alle `T_INVOICE`-Rechnungen erweitern. G4 weiterhin ohne View (`V_LIST_INPUT_VAT` Stub). G8 (`V_LIST_G08_PAYMENT_RECEIPT`) ohne finalen `TAX_AMOUNT`/`IS_SKONTO` (`V_LIST_VAT_SKONTO` Stub). Bring-Schulden als Issues #24-#28 dokumentiert.
- Status-Workflow haengt zur Laufzeit an `dbo.fn_chk_status_folge` (in ERPDEV vorhanden, in der lokalen Sandbox nicht). Vollstaendiger Workflow-Test nur gegen ERPDEV26S.
- APP-Schreibtest 2026-06-27: Die live vorhandenen G15-Procedures in ERPDEV26S wurden auf `dbo.fn_get_user_securitylevel` sowie die vorhandenen `list_views.V_LIST_G15_*`-/`stored_func.fn_G15_*`-Objekte korrigiert. Anlage, Freigabe, Rueckweisung und Bezahlung liefen ueber den APP-Zugang in einer Rollback-Transaktion erfolgreich.
- APP-Rechte nach DEV-DB-Kopie 2026-06-27: `ERP_REMOTE_USER` benoetigt `EXECUTE` auf `stored_func.fn_G15_check_vat_period` und die vier `stored_proc.sp_G15_*`-Procedures sowie `SELECT` auf `stored_func.fn_G15_calculate_vat_balance` (table-valued Function). Diese Grants wurden nachgezogen.
- Append-only Verlauf ist DB-seitig noch offen: Es gibt keine VAT-spezifische Historientabelle und G15 hat kein `CREATE TABLE`-/`dbo ALTER`-Recht. Die UI liest defensiv `list_views.V_LIST_G15_VAT_STATEMENT_HISTORY` bzw. `dbo.T_G15_VAT_STATEMENT_HISTORY`, falls der Architekt die saubere Historie anlegt; bis dahin bleiben nur aktuelle Audit-Spalten als Fallback.
- Rollenpruefungen in den Status-Procedures sind technisch umgesetzt, ersetzen aber keine echte Authentifizierung im Streamlit-Prototyp.
- `ins_views`/`upd_views` sind als Ordner vorgesehen, aber aktuell nicht implementiert und moeglicherweise durch Stored Procedures ersetzbar.
- Eine automatisierte pytest-Suite fehlt noch.
- Finale Frontend-Entscheidung Python/Streamlit vs. phpRunner bleibt offen; deshalb Frontend duenn halten.
- Offene Punkte werden primaer als GitHub Issues gepflegt. `docs/offene_fragen.md` bleibt Archiv und Uebersicht fuer fachliche Klaerungen.

## Arbeitsregeln fuer Agents

- Keine fachliche Logik aendern, wenn die Aufgabe nur Dokumentation betrifft.
- Keine `.env`-Dateien, Secrets oder echten Credentials committen oder ausgeben.
- Nicht direkt auf `main` pushen, keine PRs ohne menschliches Review mergen.
- Keine Force-Pushes ohne ausdrueckliche Freigabe; falls noetig nur `--force-with-lease`.
- Git-Synchronisationsregel aus dieser Datei einhalten, bevor neue Aufgaben oder Branches begonnen werden.
- Bei SQL-Aenderungen zuerst HdM-Konventionen und vorhandene Dev-DB-Patterns pruefen.
- Bei Schnittstellenannahmen nicht raten: offene Frage oder GitHub Issue aktualisieren und im Ergebnis nennen.
- Nach Aenderungen sinnvolle lokale Checks ausfuehren, mindestens Markdown-/Link-/Textsuche oder relevante Tests, wenn sie ohne Secrets laufen.

## Uebergabe zwischen Claude und Codex

Am Ende einer Agenten-Session kurz festhalten:
- geaenderte Dateien und Zweck
- relevante Entscheidungen oder Annahmen
- ausgefuehrte Checks und deren Ergebnis
- offene Punkte, die der naechste Agent nicht aus Chatkontext rekonstruieren soll

Wenn ein Punkt dauerhaft wichtig ist, gehoert er in `AGENTS.md`, eine passende README, eine ADR, `docs/offene_fragen.md` oder ein GitHub Issue. Chatverlauf allein ist keine Dokumentation.
