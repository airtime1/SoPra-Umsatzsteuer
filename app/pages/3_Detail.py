"""Detail-Ansicht einer Abrechnung — Items + Status-Aktionen."""

import sys
from pathlib import Path

import streamlit as st

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from app.services import vat

st.title("Abrechnungsdetail")

try:
    df = vat.list_statements()
    users = vat.list_users()
except Exception as exc:
    st.error(f"DB-Zugriff fehlgeschlagen: {exc}")
    st.stop()

if df.empty:
    st.info("Keine Abrechnungen verfügbar. Zuerst eine anlegen.")
    st.stop()

selected = st.selectbox(
    "Abrechnung auswählen",
    options=df["VAT_STATEMENT_ID"].tolist(),
    format_func=lambda i: f"#{i} — {df.set_index('VAT_STATEMENT_ID').loc[i, 'VAT_PERIOD']} "
                          f"({df.set_index('VAT_STATEMENT_ID').loc[i, 'VAT_STATUS']})",
)

head = df.set_index("VAT_STATEMENT_ID").loc[selected]

col1, col2, col3, col4, col5 = st.columns(5)
col1.metric("Periode", head["VAT_PERIOD"])
col2.metric("Status", head["VAT_STATUS"])
col3.metric("Umsatzsteuer", f"{head['OUTPUT_VAT_TOTAL']:.2f} €")
col4.metric("Vorsteuer", f"{head['INPUT_VAT_TOTAL']:.2f} €")
col5.metric(head["VAT_TYPE"] or "Saldo", f"{head['VAT_BALANCE']:.2f} €")

audit_cols = st.columns(3)
audit_cols[0].caption(f"Erstellt: {head['CREATED_BY']} / {head['CREATED_AT']}")
audit_cols[1].caption(f"Freigegeben: {head['APPROVED_BY'] or '—'} / {head['APPROVED_AT'] or '—'}")
audit_cols[2].caption(f"Abgeschlossen: {head['CLOSED_BY'] or '—'} / {head['CLOSED_AT'] or '—'}")

st.divider()
st.subheader("Steuerfälle")
items = vat.get_statement_items(int(selected))
st.dataframe(items, use_container_width=True, hide_index=True)

st.divider()
st.subheader("Status-Aktionen")

def choose_user(level: int, label: str) -> str:
    candidates = users[users["SECURITYLEVEL"] == level]
    if candidates.empty:
        return st.text_input(label, value="")
    return st.selectbox(
        label,
        options=candidates["USERNAME"].tolist(),
        format_func=lambda user: f"{user} — {candidates.set_index('USERNAME').loc[user, 'VAT_ROLE']}",
    )

if head["VAT_STATUS"] == "DRAFT":
    approved_by = choose_user(3, "Freigabe durch")
    if st.button("Freigeben (DRAFT → APPROVED)", type="primary"):
        try:
            vat.approve_statement(int(selected), approved_by=approved_by)
            st.rerun()
        except Exception as exc:
            st.error(f"Freigabe fehlgeschlagen: {exc}")
elif head["VAT_STATUS"] == "APPROVED":
    col_a, col_b = st.columns(2)
    with col_a:
        paid_by = choose_user(2, "Zahlung durch")
        if st.button("Auszahlen (APPROVED → PAID)", type="primary"):
            try:
                vat.pay_statement(int(selected), paid_by=paid_by)
                st.rerun()
            except Exception as exc:
                st.error(f"Auszahlung fehlgeschlagen: {exc}")
    with col_b:
        rejected_by = choose_user(3, "Rückgabe durch")
        if st.button("Zurückweisen (APPROVED → DRAFT)"):
            try:
                vat.reject_statement(int(selected), rejected_by=rejected_by)
                st.rerun()
            except Exception as exc:
                st.error(f"Rückgabe fehlgeschlagen: {exc}")
else:
    st.info("Abrechnung ist abgeschlossen und kann nicht weiter bearbeitet werden.")
