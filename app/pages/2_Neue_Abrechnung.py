"""Neue Umsatzsteuerabrechnung ueber die DB-Procedure anlegen."""

from __future__ import annotations

import sys
from pathlib import Path

import streamlit as st

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from app import ui
from app.services import vat


st.set_page_config(
    page_title="Umsatzsteuerabrechnung · Neue Abrechnung",
    page_icon="%",
    layout="wide",
    initial_sidebar_state="expanded",
)

ui.apply_theme()
user = ui.require_login()
ui.render_sidebar("new")

try:
    statements = vat.list_statements()
    period_options = vat.list_period_options()
except Exception as exc:
    ui.show_error_dialog("DB-Zugriff fehlgeschlagen", exc)
    st.stop()

user = ui.render_header("Umsatzsteuerabrechnung", user)

valid_options = period_options[period_options["CHECK_RESULT"] == 0].copy()
valid_options = valid_options.sort_values("VAT_PERIOD", ascending=False)
periods = valid_options["VAT_PERIOD"].astype(str).tolist()


def format_period(period: str) -> str:
    row = valid_options[valid_options["VAT_PERIOD"].astype(str) == str(period)]
    if row.empty:
        return str(period)
    row = row.iloc[0]
    source_rows = int(row.get("SOURCE_ROWS") or 0)
    return str(period) if source_rows == 0 else f"{period} · {source_rows} Belege"


with st.container(border=True):
    ui.card_title("Neue Abrechnung", "file-plus")
    form_cols = st.columns([0.52, 0.12, 0.24], vertical_alignment="bottom")
    with form_cols[0]:
        if periods:
            selected_period = st.selectbox(
                "Periode",
                periods,
                index=None,
                placeholder="Periode auswählen",
                format_func=format_period,
            )
        else:
            selected_period = st.selectbox(
                "Periode",
                [],
                index=None,
                placeholder="Keine zulässige Periode",
            )

    create_clicked = False
    with form_cols[2]:
        if ui.has_security_level(user, 1):
            create_clicked = st.button(
                "Abrechnung anlegen",
                type="primary",
                use_container_width=True,
                disabled=selected_period is None,
            )

if create_clicked and selected_period:
    selected_existing = statements[statements["VAT_PERIOD"].astype(str) == str(selected_period)]
    if not selected_existing.empty:
        existing_id = int(selected_existing.iloc[0]["VAT_STATEMENT_ID"])
        ui.existing_statement_dialog(existing_id, str(selected_period))
        st.stop()

    try:
        check_result = vat.check_period(str(selected_period))
        if check_result != 0:
            ui.message_dialog(
                "Periode nicht zulässig",
                "Die Datenbanklogik lässt diese Periode aktuell nicht zur Abrechnung zu.",
            )
        else:
            new_id = vat.create_statement(str(selected_period), user.username)
            st.session_state["selected_statement_id"] = int(new_id)
            st.session_state["flash_success"] = "Abrechnung wurde angelegt."
            st.switch_page("pages/3_Abrechnung_auswählen.py")
    except Exception as exc:
        ui.show_error_dialog("Abrechnung konnte nicht angelegt werden", exc)
