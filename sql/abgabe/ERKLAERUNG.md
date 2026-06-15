# Erklärung der MS5-Abgabe-Dateien

Stand: 2026-06-15

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

**Reihenfolge:** Erst der Architekt (Fundament: Tabellen + Codes), dann wir (Aufbau: Views/Funcs/Procs, die auf den Tabellen aufbauen). Andersherum würde unser Skript scheitern, weil z. B. `V_LIST_VAT_STATEMENT` aus `dbo.T_VAT_STATEMENT` liest — die Tabelle muss vorher existieren.

---

## 2. Vereinbarte Partner-Parameter

Wir berechnen keine Steuerbeträge selbst (ADR-008). Wir bekommen von jeder Quellgruppe nur wenige, fest vereinbarte Werte über deren Lese-View und verarbeiten sie.

> **Hinweis/Rückfrage:** In der mündlichen Vereinbarung wurden „Gruppe 4, 7, 8 & 10" für `Steuerbetrag` genannt — das ist vermutlich ein Verschreiber für **4, 7, 9 & 10**, denn Gruppe 8 (Zahlungseingänge) liefert den **Korrekturbetrag**, nicht den normalen Steuerbetrag. Unten in der korrigierten Logik. Bitte kurz gegenprüfen.

### Umsatzsteuer (Output) — drei gleichwertige Verkaufskanäle

| Gruppe | Kanal | Erwartete View | Erwartetes Feld (Konvention) | Heute in ERPDEV | Issue |
|---|---|---|---|---|---|
| G7 | Rechnungen Fernabsatz | `list_views.V_LIST_G07_INVOICE` | `TAX_AMOUNT` | **da**, heißt aber `BetragUstEUR` | #25 |
| G9 | Barrechnung Rosenberg | `list_views.V_LIST_G09_INVOICE_TAX_B2C` | `TAX_AMOUNT` | View da, Feld **fehlt** | #27 |
| G10 | Barrechnung Freiburg | `list_views.V_LIST_G10_INVOICE_BAR_FREIBURG` (Name offen) | `TAX_AMOUNT` | View **fehlt** | #28 |

### Vorsteuer (Input)

| Gruppe | Bereich | Erwartete View | Erwartetes Feld | Heute in ERPDEV | Issue |
|---|---|---|---|---|---|
| G4 | Wareneingänge | `list_views.V_LIST_G04_SUPPLIER_INVOICE` | `TAX_AMOUNT` | View **fehlt** | #24 |

### Umsatzsteuer-Korrektur (Skonto)

| Gruppe | Bereich | Erwartete View | Erwartetes Feld | Heute in ERPDEV | Issue |
|---|---|---|---|---|---|
| G8 | Zahlungseingänge | `list_views.V_LIST_G08_PAYMENT_RECEIPT` | `TAX_CORRECTION_AMOUNT` | View da, Feld **fehlt** | #26 |

**Gemeinsame Felder bei allen:** zusätzlich zu `TAX_AMOUNT`/`TAX_CORRECTION_AMOUNT` immer `INVOICE_ID` (RechnungsID) und `INVOICE_DATE` (RechnungsDatum). Das Rechnungsdatum bestimmt, in welche Abrechnungsperiode der Beleg fällt.

**Vorzeichen Korrektur:** G8 liefert den Korrekturbetrag positiv; wir drehen ihn in unserer View auf negativ (`-1 * …`), damit er die Umsatzsteuer mindert.

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
| `SOURCE_TABLE` | fachliche Kategorie: `T_INVOICE` (Ausgang), `T_SUPPLIER_INVOICE` (Eingang), `T_PAYMENT_RECEIPT` (Korrektur) |
| `SOURCE_INVOICE_ID` | RechnungsID aus der Quelle |
| `SOURCE_INVOICE_DATE` | Rechnungsdatum (steuert die Periode) |
| `TAX_AMOUNT` | der Steuerbetrag (bei Korrekturen negativ) |
| `IS_CORRECTION` | 0 = normale Rechnung, 1 = Skonto-Korrektur |
| `ORIGINAL_INVOICE_ID` | bei Korrekturen: auf welche Rechnung sie sich bezieht |

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

**`V_LIST_OUTPUT_VAT`** — das Herzstück. Vier `SELECT`-Blöcke per `UNION ALL`:

1. **G7 (aktiv):** liest `list_views.V_LIST_G07_INVOICE`, mappt die deutschen Spalten auf unsere Namen:
   ```sql
   g7.RechnungsDatum  AS SOURCE_INVOICE_DATE,
   g7.BetragUstEUR    AS TAX_AMOUNT,
   ```
2. **G9 (Stub):** liefert 0 Zeilen (`WHERE 1 = 0`), aber die richtigen Spalten. Der echte SELECT steht als Kommentar darüber.
3. **G10 (Stub):** dito.
4. **G8 (Stub):** Korrektur-Zweig (`IS_CORRECTION` würde 1 sein, Betrag negativ).

Jeder Block liefert **dieselbe Spalten-Signatur** (8 Spalten in gleicher Reihenfolge und Typ) — das ist Pflicht bei `UNION ALL`. Deshalb die `CAST(NULL AS DECIMAL(12,2))` etc. in den Stubs: sie fixieren den Typ jeder Spalte, obwohl keine Zeile kommt.

**`V_LIST_INPUT_VAT`** — nur ein Block (G4), aktuell Stub.

**`V_LIST_VAT_STATEMENT` / `V_LIST_VAT_STATEMENT_ITEM`** — einfache Anzeige-Views auf unsere eigenen Tabellen (damit das Frontend nicht direkt auf `dbo` zugreift).

**`V_LIST_VAT_USER`** — Login + Rolle (übersetzt `SECURITYLEVEL` 1/2/3 in Klartext), keine Passwörter.

### C) Functions

**`fn_check_vat_period(@vat_period, @check_date)`** → INT. Prüft, ob eine Periode abgerechnet werden darf:
- `0` = erlaubt, `1` = zu früh (vor dem 10. des Folgemonats), `2` = gesperrt (APPROVED/PAID existiert).
- Die 10.-Regel: `@earliest = DATEADD(DAY, 9, DATEADD(MONTH, 1, @period_start))`. Beispiel Periode 2026-03 → erlaubt ab 2026-04-10. Grund: bis dahin ist die 7-Tage-Skontofrist durch.

**`fn_calculate_vat_balance(@output, @input)`** → Tabelle mit zwei Spalten. Das ist eine **Inline-Table-Valued-Function** (gibt zwei Werte auf einmal zurück):
- `VAT_BALANCE` = Absolutbetrag der Differenz.
- `VAT_TYPE` = ZAHLLAST (Output > Input), UEBERHANG (Input > Output), NEUTRAL (gleich).

**`fn_get_user_security_level(@username)`** → INT. Holt `SECURITYLEVEL` aus `T_USER` für die Rollenprüfung.

### D) Procedures

**`sp_create_vat_statement(@vat_period, @created_by)`** — der Hauptablauf:
1. `fn_check_vat_period` prüfen → ggf. Fehler werfen.
2. Rolle prüfen (`@creator_security_level <> 1` → nur Sachbearbeiter legt an).
3. Vorhandenen DRAFT zurücksetzen oder neuen Kopf anlegen (`SCOPE_IDENTITY()` holt die neue ID).
4. Items einlesen: alle Zeilen aus `V_LIST_OUTPUT_VAT` und `V_LIST_INPUT_VAT`, **gefiltert auf den Periodenmonat** über `SOURCE_INVOICE_DATE BETWEEN @period_start AND @period_end`.
5. Summen bilden (`OUTPUT` = T_INVOICE + T_PAYMENT_RECEIPT, `INPUT` = T_SUPPLIER_INVOICE), Saldo via `fn_calculate_vat_balance`, Kopf aktualisieren.
6. Alles in einer Transaktion (`BEGIN TRAN … COMMIT`, bei Fehler `ROLLBACK`).

**`sp_approve` / `sp_pay` / `sp_reject`** — Statuswechsel, gleiche Bauweise:
1. Status-IDs per Name aus `T_CODE` holen.
2. **Übergang prüfen** über die zentrale Architekten-Funktion `dbo.fn_chk_status_folge(@old_id, @new_id)` (ADR-009) — die liest `T_CODE_NEXT` und gibt `'OK'` oder einen Fehlertext zurück.
3. **Rolle prüfen**: `SECURITY_LEVEL` der Transition aus `T_CODE_NEXT` holen, gegen `fn_get_user_security_level` abgleichen.
4. Prüfen, ob die Abrechnung im passenden Ausgangsstatus ist, dann `UPDATE` + Audit-Felder setzen, in Transaktion.

**Wichtig (Abhängigkeit):** `dbo.fn_chk_status_folge` existiert in ERPDEV26S, aber **nicht** in der lokalen Sandbox. Der Status-Workflow ist daher nur gegen ERPDEV vollständig testbar.

---

## 6. Wo du kleine Teile umbaust

Die wahrscheinlichsten kleinen Änderungen — und wo genau:

| Wenn… | dann ändere… | konkret |
|---|---|---|
| G9 liefert `TAX_AMOUNT` | `V_LIST_OUTPUT_VAT`, Block 2 | Stub-SELECT durch den auskommentierten echten SELECT ersetzen |
| G10 liefert ihre View | `V_LIST_OUTPUT_VAT`, Block 3 | Stub ersetzen, View-Namen einsetzen |
| G8 liefert `TAX_CORRECTION_AMOUNT` | `V_LIST_OUTPUT_VAT`, Block 4 | Stub durch Korrektur-SELECT ersetzen (`-1 * …`) |
| G4 liefert ihre View | `V_LIST_INPUT_VAT` | Stub durch echten SELECT ersetzen |
| G7 benennt Spalten um (z. B. `BetragUstEUR` → `TAX_AMOUNT`) | `V_LIST_OUTPUT_VAT`, Block 1 | nur die zwei `g7.…`-Quellspaltennamen anpassen |
| Ein Partner nutzt einen anderen Feldnamen | betroffener Block | nur den Quellspaltennamen vor `AS TAX_AMOUNT` tauschen |

**Goldene Regeln beim Umbau:**

1. **Spalten-Signatur nie verändern** — alle vier Blöcke von `V_LIST_OUTPUT_VAT` müssen exakt dieselben 8 Ausgabespalten in derselben Reihenfolge/Typ liefern. Beim Aktivieren eines Stubs einfach den vorgefertigten Kommentar-SELECT nehmen, der passt schon.
2. **Immer im Einzelfile *und* im Bundle ändern.** Quelle der Wahrheit sind die Einzelfiles in `sql/02_views/` etc.; das Bundle `sql/abgabe/MS5_G15_Umsatzsteuerabrechnung.sql` ist die zusammengeführte Kopie. Nach jeder Änderung Bundle aktualisieren.
3. **`.txt` nachziehen.** Für den Upload zählt die `.txt`-Version — nach jeder `.sql`-Änderung neu kopieren (inhaltlich identisch).
4. **Nach dem Umbau:** `py scripts/smoke_test_bundle.py --no-db` laufen lassen — er zählt, ob noch 6 Views / 3 Funcs / 4 Procs / 3 Schemas drin sind.
