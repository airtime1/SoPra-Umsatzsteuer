# ADR-002: Rollen-Reihenfolge — Sachbearbeiter → CFO → FiBu

- **Status:** akzeptiert
- **Datum:** 2026-06-03
- **Ergänzt durch:** ADR-011 (DB-Login und hierarchische Rollenlogik)

## Kontext

In MS3 Fachkonzept ist die Rollenzuordnung mit dem Vermerk "2 & 3 tauschen?" markiert. MS4 hat den Tausch vorgenommen: Stufe 2 = Leitung FiBu (zahlt aus), Stufe 3 = CFO (gibt frei). MS3 hatte das umgekehrt.

## Optionen

1. **MS4-Reihenfolge:** Sachbearbeiter (anlegen) → CFO (freigeben, `DRAFT → APPROVED`) → Leitung FiBu (auszahlen, `APPROVED → PAID`).
2. **MS3-Reihenfolge:** Sachbearbeiter (anlegen) → Leitung FiBu (prüfen/freigeben) → CFO (auszahlen).

## Entscheidung

**Option 1 (MS4).**

Begründung:
- Vier-Augen-Prinzip auf Geschäftsleitungsebene: Der CFO ist der formelle Freigeber für Zahlungsanweisungen ans Finanzamt. Das ist die übliche Verantwortungsverteilung in Unternehmen.
- Die Leitung FiBu ist operativ verantwortlich für die Durchführung der Zahlung — sie löst sie nicht eigenmächtig aus, sondern nur nach Freigabe.
- Berechtigungsstufe 3 als "höchste" Rolle = Freigabe-Recht. Das spiegelt der Status `APPROVED` (englisch für "freigegeben") direkt wider.

## Konsequenzen

- Berechtigungsmatrix in DB:
  - Level 1 (`Sachbearbeitung`) darf Abrechnungen anlegen und `DRAFT` neu berechnen.
  - Level 2 (`Leitung FiBu`) darf zusätzlich Level-2-Aktionen wie `APPROVED → PAID`.
  - Level 3 (`CFO`) darf zusätzlich Level-3-Aktionen wie `DRAFT → APPROVED` und `APPROVED → DRAFT`.
- Hohe Rollen schließen niedrige Berechtigungen ein (`actual_level >= required_level`, siehe ADR-011).
- UI muss die Buttons rollenabhängig nach derselben Hierarchie ein-/ausblenden.
- Auditspur: `CREATED_BY/AT`, `APPROVED_BY/AT` (CFO), `CLOSED_BY/AT` (FiBu) — Spalten in `T_VAT_STATEMENT`.
