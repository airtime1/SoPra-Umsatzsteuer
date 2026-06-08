"""Übersichts-Seite — alle Abrechnungen tabellarisch."""

import sys
from pathlib import Path

import streamlit as st

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

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
    status_filter = st.multiselect(
        "Status",
        options=sorted(df["VAT_STATUS"].dropna().unique()),
        default=sorted(df["VAT_STATUS"].dropna().unique()),
    )
    filtered = df[df["VAT_STATUS"].isin(status_filter)] if status_filter else df

    metric_cols = st.columns(3)
    metric_cols[0].metric("Abrechnungen", len(filtered))
    metric_cols[1].metric(
        "Zahllast gesamt",
        f"{filtered.loc[filtered['VAT_TYPE'] == 'ZAHLLAST', 'VAT_BALANCE'].sum():.2f} €",
    )
    metric_cols[2].metric(
        "Überhang gesamt",
        f"{filtered.loc[filtered['VAT_TYPE'] == 'UEBERHANG', 'VAT_BALANCE'].sum():.2f} €",
    )

    st.dataframe(filtered, use_container_width=True, hide_index=True)
