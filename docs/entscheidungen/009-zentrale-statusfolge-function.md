# ADR-009 — Status-Procedures nutzen zentrale dbo.fn_chk_status_folge

Status: Akzeptiert
Datum: 2026-06-15

## Kontext

Der Datenbank-Architekt (Prof Lehmann) stellt in ERPDEV26S zentrale,
gruppenuebergreifende Bausteine fuer den Statusworkflow bereit:

- `dbo.T_CODE_NEXT` — Datentabelle mit allen erlaubten Statusuebergaengen
  je `CODE_TYPE`, inkl. `SECURITY_LEVEL` pro Uebergang.
- `dbo.fn_chk_status_folge(@status_alt INT, @status_neu INT)` — Function,
  die anhand `T_CODE_NEXT` prueft, ob ein Uebergang erlaubt ist
  (Rueckgabe `'OK'` oder ein Fehlertext).
- `dbo.sp_upd_object_status` — generische Status-Update-Procedure, aber
  fest verdrahtet auf OFFER / ORDER / INVOICE / RECEIPT. Sie kennt
  `T_VAT_STATEMENT` nicht und kann unseren Beleg nicht aktualisieren.

Unsere Status-Procedures (`sp_approve`, `sp_pay`, `sp_reject`) haben die
Uebergangspruefung zuvor mit einem eigenen 3-fach-JOIN ueber `T_CODE` /
`T_CODE_NEXT` selbst nachgebaut.

## Entscheidung

1. **Die Uebergangspruefung delegieren wir an `dbo.fn_chk_status_folge`.**
   Das ist die zentrale, vom Architekten fuer Gruppen vorgesehene Funktion.
   Wir bauen die T_CODE_NEXT-Logik nicht mehr selbst nach.

2. **Die Procedures bleiben bestehen** — sie sind nicht ueberfluessig.
   `T_CODE_NEXT` ist nur Konfiguration (Daten), `fn_chk_status_folge` nur
   die Gueltigkeitspruefung. Den eigentlichen Statuswechsel,
   die Audit-Felder (APPROVED_BY/_AT, CLOSED_BY/_AT) und die
   Transaktionsklammer macht weiterhin unsere Procedure. Die generische
   `sp_upd_object_status` deckt unseren Beleg nicht ab.

3. **Die Rollenpruefung bleibt eigene Logik.** `fn_chk_status_folge`
   prueft keine Rollen. Wir lesen `SECURITY_LEVEL` weiterhin direkt aus
   `T_CODE_NEXT` und pruefen hierarchisch gegen `dbo.fn_get_user_securitylevel`
   (`actual_level >= required_level`, siehe ADR-011).

4. **`sp_G15_create_vat_statement` bleibt unveraendert.** Das Anlegen eines
   neuen DRAFT ist kein Uebergang in `T_CODE_NEXT` (es gibt keinen
   Von-Status). Die Rollenpruefung dort bleibt auf Mindest-Stufe 1
   (Sachbearbeitung), hoehere Level duerfen die Aktion ebenfalls.

## Konsequenzen

Positiv:
- Konsistent mit dem zentralen Architektur-Pattern; in der Abnahme gut
  vertretbar ("wir nutzen die zentrale fn_chk_status_folge").
- Weniger eigener Code; die Uebergangsregeln liegen an genau einer Stelle
  (T_CODE_NEXT), ausgewertet durch genau eine Funktion.

Negativ / Risiken:
- Neue Laufzeit-Abhaengigkeit: `dbo.fn_chk_status_folge` muss in der
  Ziel-DB existieren (in ERPDEV26S vorhanden; in der lokalen Sandbox
  nicht). Wegen Deferred Name Resolution scheitert nicht der Deploy,
  sondern erst ein EXECUTE, falls die Funktion fehlt.
- Cross-Schema-Aufruf (stored_proc -> dbo): setzt voraus, dass der
  ausfuehrende Login EXECUTE-Recht auf `dbo.fn_chk_status_folge` hat.
  Laut Architekt sind die zentralen Bausteine fuer Gruppen-Nutzung
  vorgesehen.

## Verbindung zu anderen ADRs

- ADR-001 (Statusmodell) bleibt unveraendert; ADR-002 (Rollen) wird durch ADR-011 hierarchisch ergaenzt.
- Ergaenzt die Umsetzung, nicht die fachliche Entscheidung.
