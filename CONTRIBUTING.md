# Mitarbeiten

Dieses Dokument beschreibt, wie wir im Team-Repo arbeiten — Branches, Commits, Pull Requests, Review. Bitte einmal durchlesen, bevor du das erste Mal pushst. Gilt sowohl für Menschen als auch für KI-Agents (Claude, Codex, etc.) die im Repo arbeiten.

## Grundprinzipien

1. **Niemals direkt auf `main` pushen.** Immer eigener Branch + Pull Request, auch wenn die Änderung trivial wirkt.
2. **Ein Branch = ein Thema.** Vermische nicht „SQL-Refactor" und „neue Streamlit-Seite" in einem Branch. Wenn du zwei Sachen machen willst, zwei Branches.
3. **Kleine, fokussierte PRs.** Lieber drei PRs à 50 Zeilen als einer mit 800. Review ist dann ehrlich, nicht abgenickt.
4. **Niemals `.env` committen.** Keine Credentials, keine Hochschul-Passwörter. `.gitignore` hilft, aber Hirn ist wichtiger.
5. **Bei Unklarheit fragen — auf dem PR, in WhatsApp, oder beim Coaching.** Lieber einmal nachfragen als später refactoren.

## Branches

Format: `<typ>/<kurz-beschreibung>`

| Typ | Verwendung | Beispiel |
|---|---|---|
| `feat/` | Neue Funktionalität | `feat/sp-pay-vat-statement` |
| `fix/` | Bugfix | `fix/saldo-vorzeichen` |
| `refactor/` | Umbau ohne Funktionsänderung | `refactor/views-naming` |
| `docs/` | Doku, ADRs, README | `docs/adr-rollencheck` |
| `test/` | Testfälle, Testdaten | `test/fn-calculate-vat-balance` |
| `chore/` | Build, Tooling, .gitignore | `chore/precommit-hook` |

Branch von aktuellem `main` bzw. `origin/main` abzweigen, klein halten, oft mergen.

## Git-Synchronisation vor Arbeitsbeginn

Vor jeder neuen Aufgabe gilt:

1. Aktuellen Zustand pruefen: Branch, uncommitted Aenderungen und Beziehung zu `origin/main`.
2. Vor dem Erstellen eines neuen Branches sicherstellen, dass die Arbeitsbasis dem aktuellen `origin/main` entspricht.
3. Neue Branches nur von einem aktuellen `main` bzw. `origin/main` erstellen.
4. Wenn uncommitted Aenderungen vorhanden sind: nicht einfach Branch wechseln, rebasen, pullen oder stashen. Erst die betroffenen Dateien melden und auf Freigabe warten.
5. Wenn der lokale Stand nicht aktuell ist: sauber aktualisieren oder melden, warum das nicht moeglich ist.
6. Nach der Synchronisation kurz bestaetigen, auf welchem Branch und welcher Basis weitergearbeitet wird.

## Commits

Wir folgen [Conventional Commits](https://www.conventionalcommits.org/) – locker, aber konsistent.

Format:
```
<typ>(<scope>): <kurzbeschreibung>

<optionaler body mit warum, nicht was>
```

Beispiele:
```
feat(stored-proc): sp_pay_vat_statement APPROVED→PAID

Spiegelt sp_approve_vat_statement, setzt CLOSED_BY/AT,
prueft Status-Vorbedingung.
```
```
docs(adr): ADR-008 — Periodenwechsel ab dem 10.

Klarstellung mit Prof. Lehmann beim Coaching am 03.06.
```
```
fix(view): V_LIST_OUTPUT_VAT — Tippfehler im JOIN
```

Typ-Liste passt zu Branch-Typen oben (`feat`, `fix`, `refactor`, `docs`, `test`, `chore`).

Scope ist optional, hilft aber: `(sql)`, `(stored-proc)`, `(view)`, `(streamlit)`, `(adr)`, `(test)`.

Sprache **Deutsch oder Englisch**, aber pro Commit konsistent.

## Pull Requests

1. Push deinen Branch: `git push -u origin <branch-name>`
2. Auf GitHub PR öffnen — Template wird automatisch ausgefüllt
3. Mindestens **1 Reviewer** anpingen (im Idealfall jemand anderen aus dem Team)
4. PR wird gemergt mit **"Squash and merge"** → eine saubere Commit-Historie auf `main`
5. Branch nach dem Merge löschen

### Was im PR drinstehen muss

(Template fragt das ab — bitte ausfüllen, nicht durchklicken)

- **Was ändert sich** — knapp, in 1–3 Sätzen
- **Warum** — Bezug zu ADR, Issue, offener Frage
- **Wie getestet** — Sandbox-Lauf, SQL-Test, UI-Walkthrough
- **Risiken / Nebenwirkungen** — bricht das was, wenn ja was?

### Wann mergen?

Mergen, wenn:
- Mindestens ein anderes Team-Mitglied genehmigt hat
- Du selbst nochmal überflogen hast
- Tests (falls relevant) lokal laufen

Nicht mergen, wenn:
- Pending Diskussionen im PR
- Du allein hier arbeitest und niemand reviewen kann — dann mind. 24h warten und im WhatsApp pingen
- CI rot (sobald wir CI haben)

## Code-Review — wie man andere reviewt

- **Sei freundlich, sei konkret.** „Hier wäre `SOURCE_INVOICE_ID` konsistenter als `INVOICE_ID`, weil…" statt „falsch".
- **Frage, statt zu fordern.** „Warum nicht über `V_LIST_OUTPUT_VAT`? Verstehe ich die Anforderung falsch?"
- **Approve auch ohne Perfektion**, wenn es vorwärtskommt. Perfekt ist der Feind von gut.
- **Mark als „Request changes" nur bei echten Blockern** (Bug, Sicherheit, Konventionsverletzung).

## Konfliktlösung mit `main`

Wenn dein Branch hinter `main` zurückfällt:
```bash
git fetch origin
git rebase origin/main
# Konflikte lösen, dann:
git push --force-with-lease
```
Niemals `git push --force` ohne `--with-lease` — du überschreibst sonst potenziell die Arbeit anderer.

## Issues

Wir tracken offene Punkte als GitHub-Issues. Labels:
- `area: sql`, `area: frontend`, `area: docs`
- `kind: question` (offene Frage ans Team/Prof/Gruppe X)
- `kind: schnittstelle` (an Nachbargruppe gerichtet)
- `kind: bug`, `kind: enhancement`
- `prio: hoch`, `prio: mittel`, `prio: niedrig`
- `phase: ms5`, `phase: integration`, `phase: golive`

Wenn du eine offene Frage in `docs/offene_fragen.md` ergänzt → bitte gleich ein Issue dafür anlegen, damit es im Team sichtbar wird.

## Arbeiten mit KI-Agents (Claude / Codex / etc.)

Wenn ihr Claude Code oder andere Agents im Repo nutzt:

1. **`AGENTS.md` ist der zentrale Briefingpunkt fuer alle Agents.** `CLAUDE.md` bleibt nur ein Claude-spezifischer Einstieg und verweist darauf.
2. **Git-Synchronisation vor Arbeitsbeginn einfordern.** Der Agent soll Status/Basis pruefen, keine uncommitted Aenderungen eigenmaechtig wegbewegen und neue Branches nur von aktuellem `main` / `origin/main` erstellen.
3. **Sag dem Agent explizit, dass es ein Team-Repo ist** — er soll keine direkten Commits auf `main`, keine Force-Pushes, keine `.env`-Aktionen.
4. **Lasse Agents PRs erstellen, nicht direkt mergen.** Reviews schreibt der Mensch.
5. **ADRs vor jeder groesseren Architektur-Aenderung** durch den Agent — bitte ein ADR in `docs/entscheidungen/` aufmachen, bevor Code geschrieben wird.
6. **Agent-Sessions sind nicht selbstdokumentierend.** Wichtige Erkenntnisse aus einer Session immer in `AGENTS.md`, ADR, passender README, `docs/offene_fragen.md`, GitHub Issue oder Commit-Body festhalten.
7. **Doku im selben Commit pruefen.** Wenn Architektur, Datenmodell, App-Flow, zentrale Logik, Deployment, Tests, Arbeitsregeln oder bekannte Einschraenkungen geaendert werden, muss die passende Markdown-Dokumentation im selben Commit aktualisiert werden.

## Pre-Commit Hooks (optional, nice-to-have)

Wenn du magst:
```bash
pip install pre-commit
pre-commit install
```
Die Konfiguration kommt in `.pre-commit-config.yaml`, falls jemand Lust hat, das aufzusetzen. Aktuell nicht zwingend.

## Hilfe

- Setup-Probleme: `README.md` → Quickstart
- Architektur-Hintergrund: `AGENTS.md` und `docs/entscheidungen/`
- Konventionen / Naming: `docs/namenskonventionen/INDEX.md`
- Offene Fragen / Status: GitHub Issues und `docs/offene_fragen.md`
- Im Zweifel: WhatsApp „Fiskal aut morere" oder Montagstreffen
