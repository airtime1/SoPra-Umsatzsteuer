# ins_views / upd_views — Schreib-Wrapper

`ERP_REMOTE_USER` (Frontend) hat nur read/write/execute auf bestimmten Objekten. Direkter Schreibzugriff auf `dbo.T_VAT_STATEMENT` ist vermutlich nicht erlaubt — alle Schreibwege gehen über Stored Procs oder Views in `ins_views.` / `upd_views.`.

**Status: OFFEN** — wir wissen noch nicht, welche dieser Wrapper tatsächlich nötig sind. Klärung mit Architekt steht aus (siehe `docs/offene_fragen.md`).

Mögliche Wrapper, falls benötigt:

- `upd_views.V_UPD_VAT_STATEMENT_APPROVE` — setzt Status auf APPROVED inkl. APPROVED_BY/_AT
- `upd_views.V_UPD_VAT_STATEMENT_REJECT` — APPROVED → DRAFT
- `upd_views.V_UPD_VAT_STATEMENT_PAY` — APPROVED → PAID inkl. CLOSED_BY/_AT

Alternativ: weitere Stored Procs in `sql/04_stored_proc/`. Vorteil von SPs gegenüber INSTEAD-OF-Triggern auf Views: explizite Eingabevalidierung und einfacher zu testen.
