"""
Duenne Service-Schicht zwischen Streamlit und der APP-Datenbank.

Die App liest live aus ERPDEV26S ueber den APP-Zugang. Schreibende Aktionen
laufen ausschliesslich ueber die vorhandenen G15-Stored-Procedures.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Any
import warnings

import pandas as pd

from app.db import get_app_conn


STATEMENT_VIEW = "list_views.V_LIST_G15_VAT_STATEMENT"
STATEMENT_ITEM_VIEW = "list_views.V_LIST_G15_VAT_STATEMENT_ITEM"
OUTPUT_VAT_VIEW = "list_views.V_LIST_G15_OUTPUT_VAT"
INPUT_VAT_VIEW = "list_views.V_LIST_G15_INPUT_VAT"
STATUS_LOV_VIEW = "list_views.LOV_VAT_STATUS"

CHECK_PERIOD_FUNCTION = "stored_func.fn_G15_check_vat_period"
BALANCE_FUNCTION = "stored_func.fn_G15_calculate_vat_balance"

CREATE_PROC = "stored_proc.sp_G15_create_vat_statement"
APPROVE_PROC = "stored_proc.sp_G15_approve_vat_statement"
PAY_PROC = "stored_proc.sp_G15_pay_vat_statement"
REJECT_PROC = "stored_proc.sp_G15_reject_vat_statement"


ROLE_LABELS = {
    1: "Sachbearbeitung",
    2: "Leitung FiBu",
    3: "CFO",
}


@dataclass(frozen=True)
class Fachkraft:
    label: str
    level: int
    username: str
    role: str


def _read_sql(sql: str, params: list[Any] | tuple[Any, ...] | None = None) -> pd.DataFrame:
    with get_app_conn() as conn:
        with warnings.catch_warnings():
            warnings.filterwarnings(
                "ignore",
                message="pandas only supports SQLAlchemy connectable",
                category=UserWarning,
            )
            return pd.read_sql(sql, conn, params=params)


def list_statements() -> pd.DataFrame:
    """Alle vorhandenen Umsatzsteuerabrechnungen aus der Anzeige-View."""

    sql = f"""
        SELECT VAT_STATEMENT_ID, VAT_PERIOD, VAT_STATUS,
               OUTPUT_VAT_TOTAL, INPUT_VAT_TOTAL,
               VAT_BALANCE, VAT_TYPE,
               CREATED_BY, CREATED_AT,
               APPROVED_BY, APPROVED_AT,
               CLOSED_BY, CLOSED_AT
        FROM {STATEMENT_VIEW}
        ORDER BY VAT_PERIOD DESC, VAT_STATEMENT_ID DESC
    """
    return _read_sql(sql)


def get_statement(statement_id: int) -> pd.Series | None:
    df = list_statements()
    if df.empty:
        return None

    match = df[df["VAT_STATEMENT_ID"] == int(statement_id)]
    if match.empty:
        return None
    return match.iloc[0]


def get_statement_items(statement_id: int) -> pd.DataFrame:
    sql = f"""
        SELECT VAT_STATEMENT_ITEM_ID, VAT_STATEMENT_ID, SOURCE_TABLE,
               SOURCE_INVOICE_ID, SOURCE_INVOICE_DATE, TAX_AMOUNT,
               IS_CORRECTION, ORIGINAL_INVOICE_ID,
               CREATED_BY, CREATED_AT
        FROM {STATEMENT_ITEM_VIEW}
        WHERE VAT_STATEMENT_ID = ?
        ORDER BY SOURCE_INVOICE_DATE, SOURCE_TABLE, SOURCE_INVOICE_ID
    """
    return _read_sql(sql, [statement_id])


def list_status_codes() -> pd.DataFrame:
    sql = f"""
        SELECT CODE_ID, VAT_STATUS
        FROM {STATUS_LOV_VIEW}
        ORDER BY CODE_ID
    """
    return _read_sql(sql)


def list_status_transitions() -> pd.DataFrame:
    """Liest erlaubte VAT-Statusuebergaenge samt benoetigtem Security-Level."""

    sql = """
        SELECT old.CODE_NAME AS OLD_STATUS,
               new.CODE_NAME AS NEW_STATUS,
               n.SECURITY_LEVEL
        FROM dbo.T_CODE_NEXT n
        JOIN dbo.T_CODE old
          ON old.ID_CODE = n.CODE_ID
         AND old.CODE_TYPE = n.CODE_TYPE
        JOIN dbo.T_CODE new
          ON new.ID_CODE = n.CODE_NEXT_ID
         AND new.CODE_TYPE = n.CODE_TYPE
        WHERE n.CODE_TYPE = 'VAT_STATUS'
        ORDER BY n.CODE_ID, n.CODE_NEXT_ID
    """
    return _read_sql(sql)


def list_users() -> pd.DataFrame:
    """
    APP-seitig lesbare Demo-User fuer die Fachkraft-Auswahl.

    Die DB hat aktuell keine G15-User-View; die APP-Connection darf aber die
    nicht geheimen Spalten USERNAME und SECURITYLEVEL aus dbo.T_USER lesen.
    """

    sql = """
        SELECT USERNAME, SECURITYLEVEL
        FROM dbo.T_USER
        WHERE SECURITYLEVEL IN (1, 2, 3)
        ORDER BY SECURITYLEVEL, USERNAME
    """
    users = _read_sql(sql)
    if users.empty:
        return pd.DataFrame(columns=["USERNAME", "SECURITYLEVEL", "VAT_ROLE"])

    users["VAT_ROLE"] = users["SECURITYLEVEL"].map(ROLE_LABELS).fillna("Fachkraft")
    return users


def list_fachkraefte() -> list[Fachkraft]:
    users = list_users()
    profiles: list[Fachkraft] = []

    for level in (1, 2, 3):
        candidates = users[users["SECURITYLEVEL"] == level]
        preferred_name = f"fachb{level}"
        username = preferred_name
        if not candidates.empty:
            names = [str(name) for name in candidates["USERNAME"].tolist()]
            username = preferred_name if preferred_name in names else names[0]

        profiles.append(
            Fachkraft(
                label=f"Fachkraft {level}",
                level=level,
                username=username,
                role=ROLE_LABELS[level],
            )
        )

    return profiles


def get_fachkraft_by_label(label: str | None) -> Fachkraft:
    profiles = list_fachkraefte()
    for profile in profiles:
        if profile.label == label:
            return profile
    return profiles[0]


def check_period(period: str, check_date: date | None = None) -> int:
    """Rueckgabe der DB-Function: 0 = zulaessig, 1 = gesperrt/ungueltig."""

    check_date = check_date or date.today()
    sql = f"SELECT {CHECK_PERIOD_FUNCTION}(?, ?) AS CHECK_RESULT"
    with get_app_conn() as conn:
        cur = conn.cursor()
        return int(cur.execute(sql, period, check_date).fetchval())


def calculate_balance(output_vat_total: Decimal | float, input_vat_total: Decimal | float) -> dict[str, Any]:
    sql = f"SELECT VAT_BALANCE, VAT_TYPE FROM {BALANCE_FUNCTION}(?, ?)"
    with get_app_conn() as conn:
        cur = conn.cursor()
        row = cur.execute(sql, output_vat_total, input_vat_total).fetchone()
        return {"VAT_BALANCE": row.VAT_BALANCE, "VAT_TYPE": row.VAT_TYPE}


def list_period_options(months_back: int = 18) -> pd.DataFrame:
    """
    Fachlich defensive Periodenauswahl.

    Basis sind vorhandene Quellbelege, bestehende Abrechnungen und die letzten
    Monate. Die DB-Function entscheidet, welche Perioden zulaessig sind.
    """

    sql = f"""
        WITH generated AS (
            SELECT 0 AS offset_month
            UNION ALL
            SELECT offset_month + 1
            FROM generated
            WHERE offset_month + 1 < ?
        ),
        candidate_periods AS (
            SELECT CONVERT(char(7), DATEADD(month, -offset_month, CAST(GETDATE() AS date)), 120) AS VAT_PERIOD
            FROM generated
            UNION
            SELECT CONVERT(char(7), SOURCE_INVOICE_DATE, 120)
            FROM {OUTPUT_VAT_VIEW}
            UNION
            SELECT CONVERT(char(7), SOURCE_INVOICE_DATE, 120)
            FROM {INPUT_VAT_VIEW}
            UNION
            SELECT VAT_PERIOD
            FROM {STATEMENT_VIEW}
        ),
        source_counts AS (
            SELECT VAT_PERIOD, SUM(ROW_COUNT) AS SOURCE_ROWS
            FROM (
                SELECT CONVERT(char(7), SOURCE_INVOICE_DATE, 120) AS VAT_PERIOD, COUNT(*) AS ROW_COUNT
                FROM {OUTPUT_VAT_VIEW}
                GROUP BY CONVERT(char(7), SOURCE_INVOICE_DATE, 120)
                UNION ALL
                SELECT CONVERT(char(7), SOURCE_INVOICE_DATE, 120) AS VAT_PERIOD, COUNT(*) AS ROW_COUNT
                FROM {INPUT_VAT_VIEW}
                GROUP BY CONVERT(char(7), SOURCE_INVOICE_DATE, 120)
            ) rows_by_source
            GROUP BY VAT_PERIOD
        )
        SELECT c.VAT_PERIOD,
               {CHECK_PERIOD_FUNCTION}(c.VAT_PERIOD, CAST(GETDATE() AS date)) AS CHECK_RESULT,
               s.VAT_STATEMENT_ID,
               s.VAT_STATUS,
               COALESCE(sc.SOURCE_ROWS, 0) AS SOURCE_ROWS
        FROM candidate_periods c
        LEFT JOIN {STATEMENT_VIEW} s
          ON s.VAT_PERIOD = c.VAT_PERIOD
        LEFT JOIN source_counts sc
          ON sc.VAT_PERIOD = c.VAT_PERIOD
        WHERE c.VAT_PERIOD IS NOT NULL
        ORDER BY c.VAT_PERIOD DESC
        OPTION (MAXRECURSION 100)
    """
    return _read_sql(sql, [months_back])


def latest_billable_period(months_back: int = 18) -> str:
    """Letzte Periode, die laut DB-Periodencheck abrechenbar ist."""

    options = list_period_options(months_back=months_back)
    valid = options[options["CHECK_RESULT"] == 0].copy()
    if valid.empty:
        today = date.today()
        month = today.month - 1
        year = today.year
        if month == 0:
            month = 12
            year -= 1
        return f"{year:04d}-{month:02d}"

    valid = valid.sort_values("VAT_PERIOD", ascending=False)
    return str(valid.iloc[0]["VAT_PERIOD"])


def get_statement_history(statement_id: int) -> pd.DataFrame:
    """
    Append-only Verlauf, sobald die DB eine G15-Historie bereitstellt.

    Aktuell existiert in ERPDEV26S keine VAT-spezifische Historientabelle.
    Die Funktion ist defensiv: Wenn die View/Tabelle fehlt, liefert sie ein
    leeres DataFrame und die UI nutzt die vorhandenen Audit-Spalten als Fallback.
    """

    sql = """
        IF OBJECT_ID('list_views.V_LIST_G15_VAT_STATEMENT_HISTORY') IS NOT NULL
        BEGIN
            SELECT VAT_STATEMENT_ID, EVENT_TYPE, OLD_STATUS, NEW_STATUS,
                   EVENT_BY, EVENT_AT
            FROM list_views.V_LIST_G15_VAT_STATEMENT_HISTORY
            WHERE VAT_STATEMENT_ID = ?
            ORDER BY EVENT_AT, VAT_STATEMENT_HISTORY_ID
        END
        ELSE IF OBJECT_ID('dbo.T_G15_VAT_STATEMENT_HISTORY') IS NOT NULL
        BEGIN
            SELECT VAT_STATEMENT_ID, EVENT_TYPE, OLD_STATUS, NEW_STATUS,
                   EVENT_BY, EVENT_AT
            FROM dbo.T_G15_VAT_STATEMENT_HISTORY
            WHERE VAT_STATEMENT_ID = ?
            ORDER BY EVENT_AT, VAT_STATEMENT_HISTORY_ID
        END
        ELSE
        BEGIN
            SELECT CAST(NULL AS int) AS VAT_STATEMENT_ID,
                   CAST(NULL AS varchar(40)) AS EVENT_TYPE,
                   CAST(NULL AS varchar(20)) AS OLD_STATUS,
                   CAST(NULL AS varchar(20)) AS NEW_STATUS,
                   CAST(NULL AS varchar(50)) AS EVENT_BY,
                   CAST(NULL AS datetime) AS EVENT_AT
            WHERE 1 = 0
        END
    """
    return _read_sql(sql, [statement_id, statement_id])


def create_statement(period: str, created_by: str) -> int:
    with get_app_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            f"EXEC {CREATE_PROC} @vat_period = ?, @created_by = ?",
            period,
            created_by,
        )
        row = cur.fetchone()
        conn.commit()
        return int(row.VAT_STATEMENT_ID)


def approve_statement(statement_id: int, approved_by: str) -> None:
    with get_app_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            f"EXEC {APPROVE_PROC} @statement_id = ?, @approved_by = ?",
            statement_id,
            approved_by,
        )
        conn.commit()


def reject_statement(statement_id: int, rejected_by: str) -> None:
    with get_app_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            f"EXEC {REJECT_PROC} @statement_id = ?, @rejected_by = ?",
            statement_id,
            rejected_by,
        )
        conn.commit()


def pay_statement(statement_id: int, paid_by: str) -> None:
    with get_app_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            f"EXEC {PAY_PROC} @statement_id = ?, @paid_by = ?",
            statement_id,
            paid_by,
        )
        conn.commit()
