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

col1, col2, col3, col4 = st.columns(4)
col1.metric("Periode", head["VAT_PERIOD"])
col2.metric("Status", head["VAT_STATUS"])
col3.metric("Saldo", f"{head['VAT_BALANCE']:.2f} €")
col4.metric("Typ", head["VAT_TYPE"] or "—")

st.divider()
st.subheader("Steuerfälle")
items = vat.get_statement_items(int(selected))
st.dataframe(items, use_container_width=True, hide_index=True)

st.divider()
st.subheader("Status-Aktionen")

if head["VAT_STATUS"] == "DRAFT":
    if st.button("Freigeben (DRAFT → APPROVED)", type="primary"):
        try:
            vat.approve_statement(int(selected), approved_by="s26s5xx")
            st.rerun()
        except NotImplementedError as exc:
            st.warning(str(exc))
elif head["VAT_STATUS"] == "APPROVED":
    col_a, col_b = st.columns(2)
    with col_a:
        if st.button("Auszahlen (APPROVED → PAID)", type="primary"):
            try:
                vat.pay_statement(int(selected), paid_by="s26s5xx")
                st.rerun()
            except NotImplementedError as exc:
                st.warning(str(exc))
    with col_b:
        if st.button("Zurückweisen (APPROVED → DRAFT)"):
            try:
                vat.reject_statement(int(selected), rejected_by="s26s5xx")
                st.rerun()
            except NotImplementedError as exc:
                st.warning(str(exc))
else:
    st.info("Abrechnung ist abgeschlossen und kann nicht weiter bearbeitet werden.")
