"""
Duenne Service-Schicht zwischen Streamlit und Datenbank.

Alle fachliche Logik liegt in Stored Procs / Functions (HdM-konform
benamst: sp_*, fn_*, klein-snake_case). Diese Modul-Funktionen sind
nur Aufruf-Wrapper.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Optional

import pandas as pd

from app.db import get_active_conn


@dataclass
class VatStatement:
    statement_id: int
    period: str
    status: str
    output_vat_total: Decimal
    input_vat_total: Decimal
    vat_balance: Decimal
    vat_type: Optional[str]
    created_by: str
    created_at: date


def list_statements() -> pd.DataFrame:
    """Alle Abrechnungen — direkt aus dbo.T_VAT_STATEMENT, bis es eine
    list_views.V_LIST_VAT_STATEMENT gibt."""
    sql = """
        SELECT VAT_STATEMENT_ID, VAT_PERIOD, VAT_STATUS,
               OUTPUT_VAT_TOTAL, INPUT_VAT_TOTAL,
               VAT_BALANCE, VAT_TYPE,
               CREATED_BY, CREATED_AT,
               APPROVED_BY, APPROVED_AT,
               CLOSED_BY, CLOSED_AT
        FROM dbo.T_VAT_STATEMENT
        ORDER BY VAT_PERIOD DESC
    """
    with get_active_conn() as conn:
        return pd.read_sql(sql, conn)


def get_statement_items(statement_id: int) -> pd.DataFrame:
    sql = """
        SELECT VAT_STATEMENT_ITEM_ID, SOURCE_TABLE, SOURCE_INVOICE_ID,
               SOURCE_INVOICE_DATE, TAX_AMOUNT,
               IS_CORRECTION, ORIGINAL_INVOICE_ID,
               CREATED_BY, CREATED_AT
        FROM dbo.T_VAT_STATEMENT_ITEM
        WHERE VAT_STATEMENT_ID = ?
        ORDER BY SOURCE_TABLE, SOURCE_INVOICE_DATE
    """
    with get_active_conn() as conn:
        return pd.read_sql(sql, conn, params=[statement_id])


def create_statement(period: str, created_by: str) -> int:
    """Ruft stored_proc.sp_create_vat_statement auf. Gibt die neue ID zurueck."""
    with get_active_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "EXEC stored_proc.sp_create_vat_statement @vat_period = ?, @created_by = ?",
            period,
            created_by,
        )
        row = cur.fetchone()
        conn.commit()
        return int(row.VAT_STATEMENT_ID)


def approve_statement(statement_id: int, approved_by: str) -> None:
    """DRAFT -> APPROVED via stored_proc.sp_approve_vat_statement."""
    with get_active_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "EXEC stored_proc.sp_approve_vat_statement @statement_id = ?, @approved_by = ?",
            statement_id,
            approved_by,
        )
        conn.commit()


def reject_statement(statement_id: int, rejected_by: str) -> None:
    """APPROVED -> DRAFT via stored_proc.sp_reject_vat_statement."""
    with get_active_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "EXEC stored_proc.sp_reject_vat_statement @statement_id = ?, @rejected_by = ?",
            statement_id,
            rejected_by,
        )
        conn.commit()


def pay_statement(statement_id: int, paid_by: str) -> None:
    """APPROVED -> PAID via stored_proc.sp_pay_vat_statement."""
    with get_active_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "EXEC stored_proc.sp_pay_vat_statement @statement_id = ?, @paid_by = ?",
            statement_id,
            paid_by,
        )
        conn.commit()
