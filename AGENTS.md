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
- Aktive DB-Verbindung der Streamlit-App wird ueber `APP_DB_PROFILE` gesteuert: `app`, `dev` oder `sandbox`.
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
| `list_views.V_LIST_OUTPUT_VAT` | Ausgangsrechnungen / Umsatzsteuer aus Gruppe 7; Steuerbetrag aus `T_INVOICE_ITEM` und `T_MATERIAL.VAT` aggregiert |
| `list_views.V_LIST_INPUT_VAT` | Eingangsrechnungen / Vorsteuer aus Gruppe 4; Steuerbetrag aus Supplier-Invoice-Items aggregiert |
| `stored_func.fn_check_vat_period` | Prueft Periodenformat, 10.-des-Folgemonats-Regel und Sperrstatus |
| `stored_func.fn_calculate_vat_balance` | Berechnet `VAT_BALANCE` als Absolutbetrag und `VAT_TYPE` |
| `stored_proc.sp_create_vat_statement` | Legt Abrechnung an oder berechnet bestehenden `DRAFT` neu |
| `stored_proc.sp_approve_vat_statement` | Statuswechsel `DRAFT` -> `APPROVED` |
| `stored_proc.sp_pay_vat_statement` | Statuswechsel `APPROVED` -> `PAID` |
| `stored_proc.sp_reject_vat_statement` | Rueckgabe `APPROVED` -> `DRAFT` |

Verbindliche DB-Regeln:
- `dbo` nicht direkt veraendern; Skripte fuer Tabellen und `T_CODE` an den Architekten liefern.
- Geschaeftslogik liegt moeglichst in Stored Functions/Procedures, nicht im Frontend.
- HdM-Namenskonventionen strikt einhalten: Tabellen und Tabellenspalten UPPER_CASE, Procedures/Functions klein mit `sp_`/`fn_`, Views mit `LOV_`, `V_LIST_`, `V_INS_`, `V_UPD_`.
- `VAT_BALANCE` ist immer ein nicht-negativer Absolutbetrag; `VAT_TYPE` unterscheidet `ZAHLLAST`, `UEBERHANG`, `NEUTRAL`.
- Abgeschlossene oder freigegebene Abrechnungen duerfen nicht neu berechnet werden; nur `DRAFT` darf durch `sp_create_vat_statement` ersetzt werden.

## App-Flow

Streamlit findet die Seiten automatisch unter `app/pages/`.

1. `app/main.py` initialisiert die App und erklaert die Navigation.
2. `app/pages/1_Übersicht.py` zeigt bestehende Abrechnungen.
3. `app/pages/2_Neue_Abrechnung.py` legt eine Periode ueber `stored_proc.sp_create_vat_statement` an oder berechnet einen `DRAFT` neu.
4. `app/pages/3_Detail.py` zeigt Kopf und Items und ruft die Status-Procedures auf.
5. `app/services/vat.py` ist die duenne Service-Schicht fuer Datenbankaufrufe und nutzt `get_active_conn()`.
6. `app/db.py` liest `.env`, stellt App-, Dev- und Sandbox-Verbindungen bereit und waehlt die aktive App-Verbindung ueber `APP_DB_PROFILE`.

Nach PR #19 koennen lokale UI-Tests gegen die Sandbox laufen, ohne den Code umzubauen: In `.env` `APP_DB_PROFILE=sandbox` setzen, Sandbox deployen und dann `streamlit run app/main.py` starten.

Die UI enthaelt aktuell einen einfachen User-Login-Text/Hack (`s26s5xx`). Eine echte Authentifizierung oder rollenbasierte UI-Steuerung ist noch offen.

## Deployment und Sandbox

- `scripts/deploy_sandbox.py` fuehrt die Ordner aus `sql/` in definierter Reihenfolge gegen die eigene Sandbox aus: `00_setup`, `01_tables`, `02_views`, `03_stored_func`, `04_stored_proc`, `05_ins_upd_views`, `99_seed`.
- `scripts/deploy_dev.py` deployt nur Objekte in erlaubten Schemata gegen `ERPDEV26S`: `02_views`, `03_stored_func`, `04_stored_proc`, `05_ins_upd_views`.
- `deploy_dev.py` fragt interaktiv nach Bestaetigung. Nicht automatisiert oder ohne ausdrueckliche Freigabe gegen die gemeinsame Dev-DB deployen.
- `.env.example` ist nur ein Template und enthaelt `APP_DB_PROFILE=app` als Default. `.env` und echte Credentials niemals committen, anzeigen oder in Logs ausgeben.

## Tests und Abnahme

- `tests/test_cases.md` ist der Testfall-Katalog.
- `tests/abnahmekriterien.md` beschreibt SPC-1 bis SPC-9.
- `tests/sql/fn_calculate_vat_balance_basic.sql` ist der aktuell vorhandene ausfuehrbare SQL-Test.
- `tests/sql/README.md` beschreibt die Konvention fuer weitere SQL-Tests.
- Ein `tests/python/`-pytest-Wrapper ist dokumentiert, aber noch nicht umgesetzt.
- Tests laufen gegen eine bekannte Sandbox mit Seed-Daten; `sql/99_seed/` enthaelt derzeit nur die README und noch keine Seed-Skripte.

## Dauerhaft relevante Entscheidungen

Die ADRs in `docs/entscheidungen/` dokumentieren den aktuellen Entscheidungsstand. Akzeptierte ADRs sind verbindlich; vorgeschlagene ADRs markieren bewusst noch offene Entscheidungen.

| ADR | Entscheidung |
|---|---|
| 001 | Statusmodell `DRAFT` -> `APPROVED` -> `PAID`, Rueckgabe `APPROVED` -> `DRAFT` |
| 002 | Rollen: Sachbearbeiter legt an, CFO gibt frei, Leitung FiBu zahlt aus |
| 003 | Fachliche Namen: `VAT_STATUS`, `SOURCE_INVOICE_DATE` |
| 004 | Saldo als Absolutbetrag plus `VAT_TYPE` |
| 005 | Korrekturen als eigene Item-Zeilen |
| 006 | Frontend vorerst Python/Streamlit/pyodbc, Logik bleibt DB-nah wegen moeglichem phpRunner-Wechsel |
| 007 | HdM-Namenskonventionen und Dev-DB-Befunde sind massgeblich |

Aus der Git-Historie dauerhaft relevant:
- PR #17 bereinigte alte Grossschreibungs-Referenzen auf Function-/Procedure-Namen. Neue Doku darf nicht mehr `SF_*`/`SP_*` als aktuelle Objektnamen verwenden, ausser beim historischen MS4-Mapping.
- PR #18 fuegte `ONBOARDING.md` als Setup-Leitfaden fuer neue Team-Mitglieder hinzu.
- PR #19 fuegte `APP_DB_PROFILE` fuer umschaltbare App-Verbindungen (`app`, `dev`, `sandbox`) hinzu, stabilisierte Streamlit-Page-Imports, stellte die App-Services auf `get_active_conn()` um und korrigierte `list_views.V_LIST_OUTPUT_VAT` auf echte Aggregation aus `T_INVOICE_ITEM` und `T_MATERIAL.VAT`.
- Der Team-Repo-Workflow mit GitHub-Issues, PR-Template und Issue-Templates wurde in `CONTRIBUTING.md` etabliert.
- Die HdM-Namenskonventionen und Dev-DB-Befunde wurden in ADR-007, `docs/namenskonventionen/INDEX.md`, SQL-Kommentaren und `docs/offene_fragen.md` eingearbeitet. Die lokale Dev-DB-Kopie selbst wird nicht committed.

## Bekannte Einschraenkungen und offene Punkte

- Konkrete finale Schnittstellen-Spalten von Gruppe 4 und Gruppe 7 sind noch teilweise offen. `T_INVOICE` hat laut dokumentiertem Dev-DB-Befund keine fertige `TAX_AMOUNT`-Spalte; die Ausgangssteuer wird deshalb aktuell aus `T_INVOICE_ITEM` und `T_MATERIAL.VAT` berechnet.
- `list_views.V_LIST_OUTPUT_VAT` liefert echte `TAX_AMOUNT`-Aggregation, aber `IS_CORRECTION` und `ORIGINAL_INVOICE_ID` bleiben feste Defaultwerte, bis Gruppe 7 die Korrektur-Schnittstelle finalisiert.
- `list_views.V_LIST_INPUT_VAT` ist implementiert, lieferte im Professor-Snapshot laut PR #19 aber aktuell keine Daten.
- Rollenpruefungen in den Status-Procedures sind noch nicht technisch umgesetzt; aktuell gilt Trust on Caller.
- `ins_views`/`upd_views` sind als Ordner vorgesehen, aber aktuell nicht implementiert und moeglicherweise durch Stored Procedures ersetzbar.
- Seed-Daten fuer Sandbox und eine automatisierte pytest-Suite fehlen noch.
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
