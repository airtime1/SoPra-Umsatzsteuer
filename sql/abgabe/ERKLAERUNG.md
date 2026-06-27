# Erklärung der MS5-Abgabe-Dateien

Stand: 2026-06-23

Dieses Dokument erklärt die beiden Abgabe-Skripte Zeile für Zeile in einfacher Sprache, damit man sie versteht, kleine Teile sicher umbauen und dem Prüfer erklären kann. Es ist Lern- und Referenzmaterial, **keine** Upload-Datei (für den Google-Drive-Upload gelten die `.txt`-Versionen).

## Inhalt

1. [Die zwei Dateien und warum es zwei sind](#1-die-zwei-dateien)
2. [Vereinbarte Partner-Parameter](#2-vereinbarte-partner-parameter)
3. [SQL-Grundbausteine (Glossar)](#3-sql-grundbausteine-glossar)
4. [Datei 1 — Architekten-Anteil (dbo)](#4-datei-1--architekten-anteil)
5. [Datei 2 — G15-Bundle (Views, Funcs, Procs)](#5-datei-2--g15-bundle)
6. [Wo du kleine Teile umbaust](#6-wo-du-kleine-teile-umbaust)

---

## 1. Die zwei Dateien

| Datei | Inhalt | Wer führt aus | Schema |
|---|---|---|---|
| `MS5_G15_ARCHITEKT_dbo.sql` | T_CODE-Codes, T_CODE_NEXT-Übergänge, die zwei Tabellen | **Architekt (Lehmann)** | `dbo` (gesperrt) |
| `MS5_G15_Umsatzsteuerabrechnung.sql` | Schemas, Views, Functions, Procedures | **wir selbst** | `list_views`, `stored_func`, `stored_proc` |

**Warum getrennt?** In der gemeinsamen DB `ERPDEV26S` dürfen wir nur in unsere drei eigenen Schemata schreiben. Das `dbo`-Schema (wo Tabellen und zentrale Code-Tabellen liegen) ist gesperrt — nur der Architekt darf da rein. Würden wir `CREATE TABLE dbo.…` selbst ausführen, käme „Zugriff verweigert". Deshalb liefern wir den dbo-Teil als eigenes Skript an den Architekten.

**Reihenfolge:** Erst der Architekt (Fundament: Tabellen + Codes), dann wir (Aufbau: Views/Funcs/Procs, die auf den Tabellen aufbauen). Andersherum würde unser Skript scheitern, weil z. B. `V_LIST_G15_VAT_STATEMENT` aus `dbo.T_VAT_STATEMENT` liest — die Tabelle muss vorher existieren.

---

## 2. Vereinbarte Partner-Parameter

Wir berechnen keine Steuerbeträge selbst (ADR-008). Wir bekommen von jeder Quellgruppe nur wenige, fest vereinbarte Werte über deren Lese-View und verarbeiten sie.

### Umsatzsteuer (Output) — eine Quelle für alle Verkaufskanäle

Beschluss 2026-06-16: Alle Ausgangsrechnungen — Fernabsatz (G7) **und** die Barverkäufe von G9 (Rosenberg) und G10 (Freiburg) — laufen über dieselbe `dbo.T_INVOICE` und werden über **eine** Lese-View von G7 zugänglich gemacht. Wir lesen also nur noch eine Quelle.

| Gruppe | Kanal | Erwartete View | Erwartetes Feld (Konvention) | Heute in ERPDEV | Issue |
|---|---|---|---|---|---|
| G7 | alle Ausgangsrechnungen | `list_views.V_LIST_G07_INVOICE` | `TAX_AMOUNT` | **da**, heißt aber `BetragUstEUR`; liefert aktuell nur Fernabsatz (B2C fehlt) | #25, #27, #28 |

> **Offen (G7s Bring-Schuld):** `V_LIST_G07_INVOICE` ist über INNER JOINs auf die Fernabsatz-Kette (Angebot→Auftrag→Lieferung) gebaut. Bar-/B2C-Verkäufe ohne diese Kette fallen heraus — Diagnose 2026-06-23: nur 83 von 161 G9-Rechnungen sichtbar. G7 muss die View auf alle `T_INVOICE`-Rechnungen erweitern. Bis dahin zählt nur Fernabsatz; unsere Logik bleibt unverändert.

### Vorsteuer (Input)

| Gruppe | Bereich | Erwartete View | Erwartetes Feld | Heute in ERPDEV | Issue |
|---|---|---|---|---|---|
| G4 | Lieferantenrechnungen | `list_views.V_LIST_SUPPLIER_INVOICE` | `TOTAL_VAT_AMOUNT`, `INVOICE_ID`, `INVOICE_DATE` | View **da** (seit 23.06.), **0 Datenzeilen** | #24 |

### Umsatzsteuer-Korrektur (Skonto) — Überschreiben statt Korrekturzeile

| Gruppe | Bereich | Erwartete View | Erwartete Felder | Heute in ERPDEV | Issue |
|---|---|---|---|---|---|
| G8 | Zahlungseingänge | `list_views.V_LIST_G08_PAYMENT_RECEIPT` | `INVOICE_ID`, finaler Steuerbetrag, Skonto-Flag | Flag `SKONTO_BERECHTIGT_YN` **da** (seit 23.06.), finaler Steuerbetrag **fehlt** | #26 |

**Neues Skonto-Verfahren (ADR-010, löst ADR-005 ab):** G8 liefert je Zahlungseingang den **finalen** Steuerbetrag der Rechnung nach Skonto (nicht mehr einen separaten Korrekturbetrag). Wir erfassen erst alle Rechnungen normal und **überschreiben** dann bei `IS_SKONTO = 'Y'` den Steuerbetrag der passenden Rechnung (Match über `INVOICE_ID`). Es gibt keine eigene Minus-Korrekturzeile und kein `-1 * …` mehr.

**Gemeinsame Felder bei allen:** zusätzlich zu `TAX_AMOUNT` immer `INVOICE_ID` (RechnungsID) und `INVOICE_DATE` (RechnungsDatum). Das Rechnungsdatum bestimmt, in welche Abrechnungsperiode der Beleg fällt.

---

## 3. SQL-Grundbausteine (Glossar)

Diese Konstrukte tauchen in beiden Dateien auf:

| Konstrukt | Was es tut | Warum wir es nutzen |
|---|---|---|
| `GO` | Trennt das Skript in **Batches** (Teil-Blöcke), die der Server nacheinander ausführt. Kein SQL-Befehl, sondern ein Trenner des Editors. | Manche Befehle (`CREATE SCHEMA`, `CREATE VIEW`) müssen allein am Batch-Anfang stehen. |
| `CREATE OR ALTER` | Legt das Objekt an, oder überschreibt es, falls es schon existiert. | **Idempotenz** — das Skript läuft mehrfach ohne Fehler. |
| `IF NOT EXISTS (…)` | Führt etwas nur aus, wenn die Zeile/das Objekt noch nicht da ist. | Idempotenz bei INSERTs und Schemas. |
| `IF OBJECT_ID('…') IS NULL` | Prüft, ob ein Objekt (z. B. Tabelle) existiert. | Tabelle nur anlegen, wenn sie fehlt. |
| `CONSTRAINT … CHECK (…)` | Regel, die jede Zeile erfüllen muss, sonst lehnt die DB das Schreiben ab. | Datenqualität direkt in der DB erzwingen. |
| `CAST(x AS TYP)` | Wandelt einen Wert in einen Datentyp um. | Spaltentypen festlegen (wichtig bei `UNION ALL` und Stubs). |
| `ISNULL(a, b)` / `COALESCE(a,b,…)` | Gibt `a` zurück, oder `b`, wenn `a` NULL ist. | Standardwerte / Fallbacks. |
| `UNION ALL` | Hängt mehrere SELECT-Ergebnisse untereinander (ohne Duplikate zu entfernen). | Mehrere Quell-Views zu einer Liste zusammenführen. |
| `WHERE 1 = 0` | Bedingung immer falsch → SELECT liefert **0 Zeilen**, behält aber die Spalten. | **Stub-Pattern** für noch nicht gelieferte Partner-Quellen. |
| `BEGIN TRY … BEGIN CATCH` | Fehlerbehandlung: Fehler im TRY springt in den CATCH. | Saubere Transaktion + Rollback bei Fehlern. |
| `THROW nummer, 'text', 1` | Wirft einen Fehler mit eigener Nummer und Meldung. | Fachliche Fehler klar melden (z. B. „falsche Rolle"). |
| `BEGIN TRAN / COMMIT / ROLLBACK` | Transaktion: alles oder nichts. | Bei Mehrfach-Änderungen Konsistenz sichern. |
| `SCOPE_IDENTITY()` | Liefert die zuletzt vergebene IDENTITY-ID (Auto-Nummer). | Die ID der gerade eingefügten Abrechnung holen. |
| `EOMONTH(datum)` | Letzter Tag des Monats. | Periodenende berechnen. |

---

## 4. Datei 1 — Architekten-Anteil

`MS5_G15_ARCHITEKT_dbo.sql` — vier Blöcke.

### Block 1: Status-Codes + Übergänge (`T_CODE` / `T_CODE_NEXT`)

```sql
IF NOT EXISTS (SELECT 1 FROM dbo.T_CODE WHERE CODE_TYPE = 'VAT_STATUS' AND CODE_NAME = 'DRAFT')
BEGIN
    INSERT INTO dbo.T_CODE (ID_CODE, CODE_TYPE, CODE_NAME) VALUES (9001, 'VAT_STATUS', 'DRAFT');
END;
```

- `T_CODE` ist die zentrale Code-Tabelle der ganzen ERP-DB. Wir tragen drei eigene Status ein: `DRAFT` (9001), `APPROVED` (9002), `PAID` (9003).
- Die IDs 9001–9003 sind **Platzhalter** — der Architekt darf sie ändern. Unser restlicher Code arbeitet mit den **Namen** (`'DRAFT'` etc.), nicht mit den Zahlen, deshalb ist das unkritisch.
- `IF NOT EXISTS` sorgt dafür, dass ein zweiter Lauf nicht doppelt einfügt.

Dann (nach `GO`) die **erlaubten Übergänge** in `T_CODE_NEXT`:

```sql
DECLARE @draft_status_id INT = (SELECT ID_CODE FROM dbo.T_CODE WHERE … 'DRAFT');
…
INSERT INTO dbo.T_CODE_NEXT (CODE_TYPE, CODE_ID, CODE_NEXT_ID, SECURITY_LEVEL)
VALUES ('VAT_STATUS', @draft_status_id, @approved_status_id, 3);
```

- Erst werden die IDs der drei Status in Variablen geholt (`DECLARE @… = (SELECT …)`). So funktioniert es auch, wenn der Architekt andere IDs vergibt.
- `THROW 50030` bricht ab, falls ein Status fehlt — schützt vor halbgaren Einträgen.
- Drei Übergänge werden eingetragen, jeweils mit der Rolle (`SECURITY_LEVEL`), die ihn auslösen darf:

| Übergang | SECURITY_LEVEL | Rolle |
|---|---|---|
| DRAFT → APPROVED | 3 | CFO |
| APPROVED → PAID | 2 | Leitung FiBu |
| APPROVED → DRAFT (Rückgabe) | 3 | CFO |

Diese Tabelle ist reine **Konfiguration** (Daten). Die Durchsetzung passiert später in unseren Procedures (Datei 2).

### Block 2: Tabelle `T_VAT_STATEMENT` (Abrechnungskopf)

Eine Zeile = eine Monatsabrechnung. Wichtige Spalten:

| Spalte | Bedeutung |
|---|---|
| `VAT_STATEMENT_ID` | Auto-Nummer (`IDENTITY(1,1)`), Primärschlüssel |
| `VAT_PERIOD` | Periode `YYYY-MM` |
| `VAT_STATUS` | DRAFT / APPROVED / PAID |
| `OUTPUT_VAT_TOTAL` | Summe Umsatzsteuer |
| `INPUT_VAT_TOTAL` | Summe Vorsteuer |
| `VAT_BALANCE` | Saldo als Absolutbetrag (immer ≥ 0) |
| `VAT_TYPE` | ZAHLLAST / UEBERHANG / NEUTRAL |
| `CREATED_BY/_AT`, `APPROVED_BY/_AT`, `CLOSED_BY/_AT` | Audit-Spuren je Workflow-Schritt |

Die **CHECK-Constraints** erzwingen fachliche Regeln direkt in der DB:

- `CHK_VAT_STATEMENT_PERIOD`: `VAT_PERIOD` muss dem Muster `JJJJ-MM` mit Monat 01–12 entsprechen.
- `UQ_VAT_STATEMENT_PERIOD`: jede Periode darf nur **einmal** existieren.
- `CHK_VAT_STATEMENT_STATUS`: nur die drei erlaubten Status.
- `CHK_VAT_STATEMENT_BALANCE_NONNEG`: Saldo nie negativ (Vorzeichen steckt in `VAT_TYPE`, ADR-004).
- `CHK_VAT_STATEMENT_APPROVED_FIELDS` / `…_CLOSED_FIELDS`: wer APPROVED/PAID ist, **muss** die zugehörigen Audit-Felder gesetzt haben. Konsistenz-Schutz.

`IF OBJECT_ID(... ) IS NULL` davor: Tabelle nur anlegen, wenn sie fehlt.

### Block 3: Tabelle `T_VAT_STATEMENT_ITEM` (Detailzeilen)

Eine Zeile = ein einzelner Steuerfall einer Abrechnung (eine Rechnung oder eine Korrektur).

| Spalte | Bedeutung |
|---|---|
| `SOURCE_TABLE` | fachliche Kategorie: `T_INVOICE` (Ausgang), `T_SUPPLIER_INVOICE` (Eingang). `T_PAYMENT_RECEIPT` ist weiterhin erlaubt, wird aber seit ADR-010 nicht mehr als eigene Zeile erzeugt |
| `SOURCE_INVOICE_ID` | RechnungsID aus der Quelle |
| `SOURCE_INVOICE_DATE` | Rechnungsdatum (steuert die Periode) |
| `TAX_AMOUNT` | der Steuerbetrag; bei Skonto der **finale** Betrag nach Korrektur (überschrieben, nicht negativ) |
| `IS_CORRECTION` | 0 = unverändert, 1 = durch Skonto überschrieben |
| `ORIGINAL_INVOICE_ID` | bei überschriebenen Zeilen = dieselbe Rechnung (erfüllt den Constraint) |

Constraints:

- `FK_VAT_ITEM_STATEMENT`: jede Detailzeile gehört zu genau einem Kopf (Fremdschlüssel).
- `CHK_VAT_ITEM_SOURCE_TABLE`: nur die drei Kategorien erlaubt.
- `CHK_VAT_ITEM_CORRECTION_HAS_ORIGINAL`: wenn `IS_CORRECTION=1`, muss `ORIGINAL_INVOICE_ID` gesetzt sein.
- `UQ_VAT_ITEM_PER_STATEMENT`: verhindert, dass derselbe Beleg doppelt in einer Abrechnung landet.
- Zwei Indizes für schnelleres Suchen.

### Block 4: Nachzieh-Constraints

Reiner Sicherheitsnetz-Block: Falls die Tabellen aus einem **älteren** Lauf schon existieren (und Block 2/3 deshalb übersprungen wurden), werden hier die wichtigsten Constraints nachträglich angebracht. Auf einer frischen DB tut dieser Block nichts (No-op).

---

## 5. Datei 2 — G15-Bundle

`MS5_G15_Umsatzsteuerabrechnung.sql` — vier Abschnitte A–D.

### A) Schemas anlegen

```sql
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'list_views')
    EXEC sys.sp_executesql N'CREATE SCHEMA list_views';
GO
```

`CREATE SCHEMA` muss das erste Statement im Batch sein. Damit wir es trotzdem in eine `IF`-Bedingung packen können, führen wir es über `sp_executesql` (dynamisches SQL) aus. Drei Schemas: `list_views`, `stored_func`, `stored_proc`.

### B) Views

**`LOV_VAT_STATUS`** — Dropdown-Werte (DRAFT/APPROVED/PAID) für das Frontend, liest aus `T_CODE`.

**`V_LIST_G15_OUTPUT_VAT`** — das Herzstück. Seit dem Beschluss 2026-06-16 nur noch **ein** `SELECT` (kein `UNION ALL` mehr): er liest `list_views.V_LIST_G07_INVOICE` und mappt die deutschen Spalten auf unsere Namen:
```sql
g7.RechnungsDatum  AS SOURCE_INVOICE_DATE,
g7.BetragUstEUR    AS TAX_AMOUNT,
```
G9 (Rosenberg) und G10 (Freiburg) brauchen keinen eigenen Block mehr, weil sie über dieselbe `T_INVOICE` laufen und über G7s View mitkommen (sobald G7 die View auf B2C erweitert).

**`V_LIST_G15_VAT_SKONTO`** — finaler Steuerbetrag je Rechnung aus G8 (Signatur `INVOICE_ID`, `TAX_AMOUNT`, `IS_SKONTO`). Aktuell **Stub** (`WHERE 1 = 0`): G8 liefert seit 23.06. zwar das Flag `SKONTO_BERECHTIGT_YN`, aber noch keinen finalen Steuerbetrag nach Skonto. Diese View ist keine Output-Quelle, sondern wird in `sp_G15_create_vat_statement` zum **Überschreiben** genutzt (ADR-010).

**`V_LIST_G15_INPUT_VAT`** — nur ein Block (G4), **aktiv seit 23.06.**: liest `list_views.V_LIST_SUPPLIER_INVOICE` und mappt `TOTAL_VAT_AMOUNT` auf `TAX_AMOUNT`. Liefert aktuell 0 Zeilen, weil G4 noch keine Rechnungsdaten eingespielt hat.

**`V_LIST_G15_VAT_STATEMENT` / `V_LIST_G15_VAT_STATEMENT_ITEM`** — einfache Anzeige-Views auf unsere eigenen Tabellen (damit das Frontend nicht direkt auf `dbo` zugreift).

**`V_LIST_G15_VAT_USER`** — Login + Rolle (übersetzt `SECURITYLEVEL` 1/2/3 in Klartext), keine Passwörter.

### C) Functions

**`fn_G15_check_vat_period(@vat_period, @check_date)`** → INT. Prüft, ob eine Periode abgerechnet werden darf:
- `0` = erlaubt, `1` = zu früh (vor dem 10. des Folgemonats), `2` = gesperrt (APPROVED/PAID existiert).
- Die 10.-Regel: `@earliest = DATEADD(DAY, 9, DATEADD(MONTH, 1, @period_start))`. Beispiel Periode 2026-03 → erlaubt ab 2026-04-10. Grund: bis dahin ist die 7-Tage-Skontofrist durch.

**`fn_G15_calculate_vat_balance(@output, @input)`** → Tabelle mit zwei Spalten. Das ist eine **Inline-Table-Valued-Function** (gibt zwei Werte auf einmal zurück):
- `VAT_BALANCE` = Absolutbetrag der Differenz.
- `VAT_TYPE` = ZAHLLAST (Output > Input), UEBERHANG (Input > Output), NEUTRAL (gleich).

**`dbo.fn_get_user_securitylevel(@username)`** → INT. Zentrale Architekten-Funktion (liest `SECURITYLEVEL` aus `dbo.T_USER`) für die Rollenprüfung. Gruppe 15 legt **keine eigene** Security-Level-Funktion mehr an — die vorhandene zentrale Funktion wird direkt eingebunden (Coaching-Feedback Prof. Lehmann).

### D) Procedures

**`sp_G15_create_vat_statement(@vat_period, @created_by)`** — der Hauptablauf:
1. `fn_G15_check_vat_period` prüfen → ggf. Fehler werfen.
2. Rolle prüfen (`@creator_security_level <> 1` → nur Sachbearbeiter legt an).
3. Vorhandenen DRAFT zurücksetzen oder neuen Kopf anlegen (`SCOPE_IDENTITY()` holt die neue ID).
4. Items **erfassen**: alle Zeilen aus `V_LIST_G15_OUTPUT_VAT` und `V_LIST_G15_INPUT_VAT`, **gefiltert auf den Periodenmonat** über `SOURCE_INVOICE_DATE BETWEEN @period_start AND @period_end`.
5. Skonto **überschreiben** (ADR-010): per `UPDATE … JOIN V_LIST_G15_VAT_SKONTO` bekommt jede Rechnung mit `IS_SKONTO='Y'` den finalen Steuerbetrag (Match über `INVOICE_ID`), `IS_CORRECTION=1`, `ORIGINAL_INVOICE_ID=SOURCE_INVOICE_ID`. Periodensicher durch die 7-Tage-Skontofrist + 10.-des-Folgemonats-Regel.
6. Summen bilden (`OUTPUT` = T_INVOICE, `INPUT` = T_SUPPLIER_INVOICE), Saldo via `fn_G15_calculate_vat_balance`, Kopf aktualisieren.
7. Alles in einer Transaktion (`BEGIN TRAN … COMMIT`, bei Fehler `ROLLBACK`).

**`sp_approve` / `sp_pay` / `sp_reject`** — Statuswechsel, gleiche Bauweise:
1. Status-IDs per Name aus `T_CODE` holen.
2. **Übergang prüfen** über die zentrale Architekten-Funktion `dbo.fn_chk_status_folge(@old_id, @new_id)` (ADR-009) — die liest `T_CODE_NEXT` und gibt `'OK'` oder einen Fehlertext zurück.
3. **Rolle prüfen**: `SECURITY_LEVEL` der Transition aus `T_CODE_NEXT` holen, gegen `dbo.fn_get_user_securitylevel` abgleichen.
4. Prüfen, ob die Abrechnung im passenden Ausgangsstatus ist, dann `UPDATE` + Audit-Felder setzen, in Transaktion.

**Wichtig (Abhängigkeit):** `dbo.fn_chk_status_folge` existiert in ERPDEV26S, aber **nicht** in der lokalen Sandbox. Der Status-Workflow ist daher nur gegen ERPDEV vollständig testbar.

---

## 6. Wo du kleine Teile umbaust

Die wahrscheinlichsten kleinen Änderungen — und wo genau:

| Wenn… | dann ändere… | konkret |
|---|---|---|
| G7 erweitert die View auf alle Ausgangsrechnungen (B2C inkl.) | nichts | `V_LIST_G15_OUTPUT_VAT` liefert dann automatisch G9/G10 mit |
| G8 liefert finalen Steuerbetrag nach Skonto (Flag `SKONTO_BERECHTIGT_YN` ist schon da) | `V_LIST_G15_VAT_SKONTO` | Stub durch den auskommentierten echten SELECT ersetzen |
| ~~G4 liefert ihre View~~ — erledigt 23.06. (`V_LIST_SUPPLIER_INVOICE` angebunden); offen nur noch: G4 spielt Rechnungsdaten ein | `V_LIST_G15_INPUT_VAT` | aktiv, kein Schritt mehr nötig |
| G7 benennt Spalten um (z. B. `BetragUstEUR` → `TAX_AMOUNT`) | `V_LIST_G15_OUTPUT_VAT` | nur die zwei `g7.…`-Quellspaltennamen anpassen |
| Ein Partner nutzt einen anderen Feldnamen | betroffene View | nur den Quellspaltennamen vor `AS TAX_AMOUNT` tauschen |

**Goldene Regeln beim Umbau:**

1. **Spalten-Signatur nie verändern** — `V_LIST_G15_OUTPUT_VAT`, `V_LIST_G15_INPUT_VAT` und `V_LIST_G15_VAT_SKONTO` haben eine feste Spaltensignatur, von der `sp_G15_create_vat_statement` abhängt. Beim Aktivieren eines Stubs den vorgefertigten Kommentar-SELECT nehmen, der passt schon.
2. **Immer im Einzelfile *und* im Bundle ändern.** Quelle der Wahrheit sind die Einzelfiles in `sql/02_views/` etc.; das Bundle `sql/abgabe/MS5_G15_Umsatzsteuerabrechnung.sql` ist die zusammengeführte Kopie. Nach jeder Änderung Bundle aktualisieren.
3. **`.txt` nachziehen.** Für den Upload zählt die `.txt`-Version — nach jeder `.sql`-Änderung neu kopieren (inhaltlich identisch).
4. **Nach dem Umbau:** `py scripts/smoke_test_bundle.py --no-db` laufen lassen — er zählt, ob noch 7 Views / 3 Funcs / 4 Procs / 3 Schemas drin sind.
