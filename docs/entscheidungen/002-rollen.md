# ADR-002: Rollen-Reihenfolge — Sachbearbeiter → CFO → FiBu

- **Status:** akzeptiert
- **Datum:** 2026-06-03

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

- Berechtigungsmatrix in DB (Rollencheck z. B. in Stored Proc oder über `T_USER_ROLE`-Lookup):
  - `Sachbearbeiter` darf: `INSERT` auf `T_VAT_STATEMENT`, Status `DRAFT` setzen
  - `CFO` darf: Status `DRAFT → APPROVED`, `APPROVED → DRAFT` (Zurückweisung)
  - `Leitung FiBu` darf: Status `APPROVED → PAID`
- UI muss die Buttons rollenabhängig ein-/ausblenden.
- Auditspur: `CREATED_BY/AT`, `APPROVED_BY/AT` (CFO), `CLOSED_BY/AT` (FiBu) — Spalten in `T_VAT_STATEMENT`.
