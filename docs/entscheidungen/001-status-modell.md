# ADR-001: Status-Modell mit 3 englischen Status

- **Status:** akzeptiert
- **Datum:** 2026-06-03
- **Beteiligte:** Nils, Moritz, Abel

## Kontext

MS3 Fachkonzept definiert vier deutsche Status für die Umsatzsteuerabrechnung: `ENTWURF` → `IN PRÜFUNG` → `FREIGEGEBEN` → `ABGESCHLOSSEN`. MS4 Systemkonzept verwendet drei englische Status: `DRAFT` → `APPROVED` → `PAID`. Der Übergang `IN PRÜFUNG` ist im DB-Modell weggefallen.

## Optionen

1. **3 Status EN (DRAFT / APPROVED / PAID)** — wie MS4 spezifiziert.
2. **4 Status DE (ENTWURF / IN PRÜFUNG / FREIGEGEBEN / ABGESCHLOSSEN)** — wie MS3.
3. **4 Status EN (DRAFT / IN_REVIEW / APPROVED / PAID)** — Kompromiss mit explizitem Review-State.

## Entscheidung

**Option 1 — 3 Status englisch.** Zusätzlich erlaubter Rückgabe-Pfad `APPROVED → DRAFT` für Korrekturfälle (entspricht `T_CODE_NEXT` in MS4).

Begründung:
- MS4 ist die jüngere und konkretere Spezifikation, daran halten wir uns laut Team-Konvention.
- Englisch passt zu allen SQL-Bezeichnern (`CREATED_BY`, `APPROVED_AT`, `CLOSED_AT`) und vermeidet Sprachmix.
- Ein expliziter `IN_REVIEW`-Status ist redundant: solange `DRAFT` nicht freigegeben ist, wird ohnehin geprüft. Der Übergang `DRAFT → APPROVED` ist der "Freigabe-Klick" durch den CFO.

## Konsequenzen

- Wir verlieren die explizite Sichtbarkeit "Sachbearbeiter hat eingereicht, CFO hat noch nicht entschieden". Wenn das Team das gegenüber dem Prüfer braucht, müssen wir Option 3 nachziehen.
- DB-Constraint: `CHECK (VAT_STATUS IN ('DRAFT', 'APPROVED', 'PAID'))`.
- `T_CODE_NEXT`-Übergänge:
  - `DRAFT → APPROVED` (Sachbearbeiter reicht ein / CFO gibt frei — abhängig von ADR-002)
  - `APPROVED → PAID` (Leitung FiBu zahlt aus)
  - `APPROVED → DRAFT` (CFO weist zurück)
