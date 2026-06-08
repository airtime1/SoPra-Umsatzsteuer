# docs/konzepte — Hinweise fuer Team und Agents

Dieser Ordner enthaelt die offiziellen Konzept-Dokumente der Gruppe 15 zum Modul Umsatzsteuerabrechnung. Die meisten Dateien sind Referenzartefakte aus frueheren Meilensteinen und werden inhaltlich nicht mehr veraendert. Aktive Pflege findet ausschliesslich an den MS5-Dokumenten statt.

## Dateien

| Datei | Typ | Stand | Inhalt |
|---|---|---|---|
| `MS1_Projektplan_G15.pdf` | Referenz | MS1 | Projektplan, Gantt, Rollenverteilung |
| `MS2_Anforderung_G15.pdf` | Referenz | MS2 | Anforderungsanalyse, F/NF/SPC |
| `MS3_Fachkonzept_G15.pdf` | Referenz | MS3 | Fachkonzept |
| `MS4_Systemkonzept_G15.pdf` | Referenz | MS4 | Systemkonzept (urspruengliches Architekturbild) |
| `MS5_Testkonzept_G15_Intern.docx` | aktiv | 2026-06-08 | **Technische Vollversion** des Test- und Abnahmekonzepts. Zielgruppe: Team, Reviewer, Architekt, KI-Agents. Enthaelt Test-IDs, SPC-Tabelle, konkrete Objektnamen. |
| `MS5_Testkonzept_G15_Abgabe.docx` | aktiv | 2026-06-08 | **Kompakte Abgabe-/Praesentationsfassung** im Stil der Prof-Vorlage. Inhaltlich gleicher Stand, aber bewusst weniger technisch und ohne Test-IDs. Zielgruppe: Prof + externe Lesende. |
| `Fragekatalog.pdf` | Referenz | Coaching | Fragen ans Coaching / an Partnergruppen |

## Verhaeltnis der beiden MS5-Dokumente

Die zwei MS5-Dateien beschreiben den **gleichen fachlichen Stand**. Sie unterscheiden sich in Detailtiefe und Sprachstil, nicht in der Aussage:

- `..._Intern.docx`: vollstaendige technische Sicht. Pflegen, wenn sich Architektur, Tests oder Abnahmekriterien aendern.
- `..._Abgabe.docx`: bewusst schlanke Praesentationsversion. Pflegen, wenn die Intern-Version sich aendert; nicht eigenstaendig veraendern.

**Regel fuer Agents:** Wenn der Inhalt aktualisiert werden soll, zuerst `_Intern.docx` aendern; danach `_Abgabe.docx` nachziehen, ohne neue Inhalte einzufuehren, die nicht in der Intern-Version stehen.

## Fachliche Quellen

Beide MS5-Dokumente bauen auf folgenden mitgepflegten Quellen auf:

- `AGENTS.md` (Repository-Root) — aktueller technischer Aufbau, DB-Objekte, Regeln
- `docs/zielbild.md` — fachliches Soll-Bild der Umsatzsteuer-App
- `docs/schnittstellen_annahmen.md` — gepflegte Annahmen je Schnittstelle
- `docs/entscheidungen/` — ADRs (insb. 001, 003, 004, 005, 007)
- `tests/test_cases.md`, `tests/abnahmekriterien.md` — Testfall-Katalog und SPC-Kriterien
- Uebergabe-Doku Systemkonzept V2 vom 2026-06-08 — Anlass der strukturellen Ueberarbeitung (V2.0 der MS5-Dokumente)

Wenn eine dieser Quellen sich aendert, pruefen, ob das MS5-Konzept ebenfalls fortgeschrieben werden muss (Regel aus `AGENTS.md`, Abschnitt "Dokumentationsregel fuer alle Aenderungen").

## Generatorhinweis

Die DOCX-Dateien sind nicht handgeschrieben; sie werden aus Generatorskripten gebaut, die nicht im Repo eingecheckt sind (`gen_intern.js` / `gen_abgabe.js`). Bei groesseren Inhalts-Updates ist es meist einfacher, den Generator anzupassen und die Datei neu zu erzeugen, als das DOCX direkt zu editieren. Das Generatorskript laesst sich aus dem Inhalt des Dokuments und dieser README rekonstruieren — der entscheidende Inhalt sind die Markdown-Quellen, die hier verlinkt sind.
