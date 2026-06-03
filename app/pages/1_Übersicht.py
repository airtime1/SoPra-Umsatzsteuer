"""Übersichts-Seite — alle Abrechnungen tabellarisch."""

import streamlit as st

from app.services import vat

st.title("Abrechnungs-Übersicht")

try:
    df = vat.list_statements()
except Exception as exc:
    st.error(f"DB-Zugriff fehlgeschlagen: {exc}")
    st.stop()

if df.empty:
    st.info("Noch keine Abrechnungen vorhanden.")
else:
    st.dataframe(df, use_container_width=True, hide_index=True)
