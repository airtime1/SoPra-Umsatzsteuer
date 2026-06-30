"""Bestehende Umsatzsteuerabrechnung auswaehlen und bearbeiten."""

from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd
import streamlit as st

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from app import ui
from app.services import vat


st.set_page_config(
    page_title="Umsatzsteuerabrechnung · Abrechnung auswählen",
    page_icon="%",
    layout="wide",
    initial_sidebar_state="expanded",
)

ui.apply_theme()
user = ui.require_login()
ui.render_sidebar("select")

try:
    statements = vat.list_statements()
    transitions = vat.list_status_transitions()
except Exception as exc:
    ui.show_error_dialog("DB-Zugriff fehlgeschlagen", exc)
    st.stop()

user = ui.render_header("Umsatzsteuerabrechnung", user)

flash = st.session_state.pop("flash_success", None)
if flash:
    st.success(flash)

sorted_statements = ui.sortable_statements(statements)
statement_ids = [int(row["VAT_STATEMENT_ID"]) for _, row in sorted_statements.iterrows()]
statement_by_id = {
    int(row["VAT_STATEMENT_ID"]): row for _, row in sorted_statements.iterrows()
}


def format_statement_option(statement_id: int) -> str:
    row = statement_by_id[int(statement_id)]
    return (
        f"{row['VAT_PERIOD']} (ID: {ui.format_id(row['VAT_STATEMENT_ID'])}) "
        f"– {ui.status_label(row['VAT_STATUS'])}"
    )


with st.container(border=True):
    ui.card_title("Abrechnung auswählen", "folder")
    query_statement_id = st.query_params.get("statement_id")
    if query_statement_id is not None:
        try:
            st.session_state["selected_statement_id"] = int(query_statement_id)
        except (TypeError, ValueError):
            st.session_state.pop("selected_statement_id", None)

    selected_from_state = st.session_state.get("selected_statement_id")
    selected_index = None
    if selected_from_state is not None and int(selected_from_state) in statement_ids:
        selected_index = statement_ids.index(int(selected_from_state))

    if statement_ids:
        selected_id = st.selectbox(
            "Abrechnung",
            statement_ids,
            index=selected_index,
            placeholder="Abrechnung auswählen",
            format_func=format_statement_option,
        )
    else:
        selected_id = st.selectbox(
            "Abrechnung",
            [],
            index=None,
            placeholder="Keine Abrechnungen vorhanden",
        )

if selected_id is None:
    st.session_state.pop("selected_statement_id", None)
    st.stop()

selected_id = int(selected_id)
st.session_state["selected_statement_id"] = selected_id
head = statement_by_id[selected_id]

try:
    items = vat.get_statement_items(selected_id)
except Exception as exc:
    items = pd.DataFrame()
    ui.show_error_dialog("Positionen konnten nicht geladen werden", exc)

try:
    history = vat.get_statement_history(selected_id)
except Exception:
    history = pd.DataFrame()

status = str(head["VAT_STATUS"])

with st.container(border=True):
    header_cols = st.columns([1, 0.38], vertical_alignment="center")
    with header_cols[0]:
        st.markdown(
            f"""
            <div class="card-title">
                <span class="icon-badge">{ui.icon_svg("calendar")}</span>
                <h2>{str(head["VAT_PERIOD"])}</h2>
                {ui.status_badge(head["VAT_STATUS"])}
            </div>
            """,
            unsafe_allow_html=True,
        )
    with header_cols[1]:
        action_labels: list[str] = []

        if status == "DRAFT" and ui.has_security_level(user, 1):
            action_labels.append("recalculate")
        if status == "DRAFT" and ui.transition_allowed(transitions, user, "DRAFT", "APPROVED"):
            action_labels.append("approve")
        if status == "APPROVED" and ui.transition_allowed(transitions, user, "APPROVED", "DRAFT"):
            action_labels.append("reject")
        if status == "APPROVED" and ui.transition_allowed(transitions, user, "APPROVED", "PAID"):
            action_labels.append("pay")

        if action_labels:
            action_cols = st.columns(len(action_labels))
            for idx, action in enumerate(action_labels):
                with action_cols[idx]:
                    if action == "recalculate" and st.button("Neu berechnen", use_container_width=True):
                        try:
                            new_id = vat.create_statement(str(head["VAT_PERIOD"]), user.username)
                            st.session_state["selected_statement_id"] = int(new_id)
                            st.session_state["flash_success"] = "Abrechnung wurde neu berechnet."
                            st.rerun()
                        except Exception as exc:
                            ui.show_error_dialog("Neuberechnung fehlgeschlagen", exc)

                    if action == "approve" and st.button("Freigeben", type="primary", use_container_width=True):
                        try:
                            vat.approve_statement(selected_id, user.username)
                            st.session_state["flash_success"] = "Abrechnung wurde freigegeben."
                            st.rerun()
                        except Exception as exc:
                            ui.show_error_dialog("Freigabe fehlgeschlagen", exc)

                    if action == "reject" and st.button("Zurückweisen", use_container_width=True):
                        try:
                            vat.reject_statement(selected_id, user.username)
                            st.session_state["flash_success"] = "Abrechnung wurde zurückgewiesen."
                            st.rerun()
                        except Exception as exc:
                            ui.show_error_dialog("Zurückweisung fehlgeschlagen", exc)

                    if action == "pay" and st.button("Bezahlen", type="primary", use_container_width=True):
                        try:
                            vat.pay_statement(selected_id, user.username)
                            st.session_state["flash_success"] = "Abrechnung wurde bezahlt."
                            st.rerun()
                        except Exception as exc:
                            ui.show_error_dialog("Abschluss fehlgeschlagen", exc)

    ui.render_statement_header_table(head)

left, right = st.columns([0.54, 0.46])

with left:
    with st.container(border=True):
        ui.card_title("Positionen", "document")
        ui.render_item_rows(items, limit=4)
        if st.button("Alle Positionen anzeigen", key="all-items"):
            ui.positions_dialog(items)

with right:
    with st.container(border=True):
        ui.card_title("Verlauf", "clock")
        timeline = ui.build_timeline(head, items, history)
        ui.render_timeline(timeline[:3])
        if st.button("Gesamten Verlauf anzeigen", key="all-history"):
            ui.timeline_dialog(timeline)
