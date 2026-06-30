"""
Duenne Service-Schicht zwischen Streamlit und der APP-Datenbank.

Die App liest live aus ERPDEV26S mit den DB-Credentials des eingeloggten
Users. Schreibende Aktionen laufen ausschliesslich ueber die vorhandenen
G15-Stored-Procedures.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Any
import warnings

import pandas as pd

from app.db import get_authenticated_conn, get_user_conn


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


@dataclass(frozen=True)
class AuthenticatedUser:
    username: str
    level: int
    role: str


def _read_sql(sql: str, params: list[Any] | tuple[Any, ...] | None = None) -> pd.DataFrame:
    with get_authenticated_conn() as conn:
        with warnings.catch_warnings():
            warnings.filterwarnings(
                "ignore",
                message="pandas only supports SQLAlchemy connectable",
                category=UserWarning,
            )
            return pd.read_sql(sql, conn, params=params)


def authenticate_user(username: str, password: str) -> AuthenticatedUser:
    """
    Prueft echte DB-Credentials und liest den Security-Level aus der zentralen DB-Logik.

    SUSER_SNAME() ist die tatsaechliche SQL-Server-Login-Identitaet der Verbindung.
    dbo.fn_get_user_securitylevel bleibt die massgebliche Quelle fuer G15-Rollen.
    """

    if not username.strip() or not password:
        raise ValueError("Benutzername und Passwort muessen ausgefuellt sein.")

    sql = """
        DECLARE @login_name VARCHAR(50) = CAST(SUSER_SNAME() AS VARCHAR(50));
        DECLARE @security_level INT = dbo.fn_get_user_securitylevel(@login_name);

        SELECT
            @login_name AS USERNAME,
            @security_level AS SECURITYLEVEL,
            CASE
                WHEN @security_level = 1 THEN 'Sachbearbeitung'
                WHEN @security_level = 2 THEN 'Leitung FiBu'
                WHEN @security_level = 3 THEN 'CFO'
                WHEN @security_level IS NULL OR @security_level < 1 THEN 'Nicht berechtigt'
                ELSE CONCAT('Level ', @security_level)
            END AS VAT_ROLE
    """
    with get_user_conn(username.strip(), password) as conn:
        cur = conn.cursor(as_dict=True)
        cur.execute(sql)
        row = cur.fetchone()

    if row is None:
        raise RuntimeError("Benutzer konnte nicht aus der Datenbank ermittelt werden.")

    level = row.get("SECURITYLEVEL")
    if level is None or int(level) < 1:
        raise PermissionError("Benutzer hat keine Umsatzsteuer-Berechtigung.")

    return AuthenticatedUser(
        username=str(row["USERNAME"]),
        level=int(level),
        role=str(row["VAT_ROLE"]),
    )


def list_statements() -> pd.DataFrame:
    """Alle vorhandenen Umsatzsteuerabrechnungen aus der Anzeige-View."""

    sql = f"""
        SELECT VAT_STATEMENT_ID, VAT_PERIOD, VAT_STATUS,
               OUTPUT_VAT_TOTAL, INPUT_VAT_TOTAL,
               VAT_BALANCE, VAT_TYPE,
               CREATED_BY, CREATED_AT,
               APPROVED_BY, APPROVED_AT,
               CLOSED_BY, CLOSED_AT
        FROM list_views.V_LIST_G15_VAT_STATEMENT
        ORDER BY VAT_PERIOD DESC
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
        FROM list_views.V_LIST_G15_VAT_STATEMENT_ITEM
        WHERE VAT_STATEMENT_ID = %s
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


def check_period(period: str, check_date: date | None = None) -> int:
    """Rueckgabe der DB-Function: 0 = zulaessig, 1 = gesperrt/ungueltig."""

    check_date = check_date or date.today()
    sql = f"SELECT {CHECK_PERIOD_FUNCTION}(%s, %s) AS CHECK_RESULT"
    with get_authenticated_conn() as conn:
        cur = conn.cursor()
        cur.execute(sql, (period, check_date))
        return int(cur.fetchone()[0])


def calculate_balance(output_vat_total: Decimal | float, input_vat_total: Decimal | float) -> dict[str, Any]:
    sql = f"SELECT VAT_BALANCE, VAT_TYPE FROM {BALANCE_FUNCTION}(%s, %s)"
    with get_authenticated_conn() as conn:
        cur = conn.cursor()
        cur.execute(sql, (output_vat_total, input_vat_total))
        row = cur.fetchone()
        return {"VAT_BALANCE": row[0], "VAT_TYPE": row[1]}


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
            WHERE offset_month + 1 < %s
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
            WHERE VAT_STATEMENT_ID = %s
            ORDER BY EVENT_AT, VAT_STATEMENT_HISTORY_ID
        END
        ELSE IF OBJECT_ID('dbo.T_G15_VAT_STATEMENT_HISTORY') IS NOT NULL
        BEGIN
            SELECT VAT_STATEMENT_ID, EVENT_TYPE, OLD_STATUS, NEW_STATUS,
                   EVENT_BY, EVENT_AT
            FROM dbo.T_G15_VAT_STATEMENT_HISTORY
            WHERE VAT_STATEMENT_ID = %s
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
    """Ruft stored_proc.sp_G15_create_vat_statement auf. Gibt die neue ID zurueck."""
    with get_authenticated_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "EXEC stored_proc.sp_G15_create_vat_statement @vat_period = %s, @created_by = %s",
            (period, created_by),
        )
        row = cur.fetchone()
        conn.commit()
        return int(row[0])


def approve_statement(statement_id: int, approved_by: str) -> None:
    """DRAFT -> APPROVED via stored_proc.sp_G15_approve_vat_statement."""
    with get_authenticated_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "EXEC stored_proc.sp_G15_approve_vat_statement @statement_id = %s, @approved_by = %s",
            (statement_id, approved_by),
        )
        conn.commit()


def reject_statement(statement_id: int, rejected_by: str) -> None:
    """APPROVED -> DRAFT via stored_proc.sp_G15_reject_vat_statement."""
    with get_authenticated_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "EXEC stored_proc.sp_G15_reject_vat_statement @statement_id = %s, @rejected_by = %s",
            (statement_id, rejected_by),
        )
        conn.commit()


def pay_statement(statement_id: int, paid_by: str) -> None:
    """APPROVED -> PAID via stored_proc.sp_G15_pay_vat_statement."""
    with get_authenticated_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "EXEC stored_proc.sp_G15_pay_vat_statement @statement_id = %s, @paid_by = %s",
            (statement_id, paid_by),
        )
        conn.commit()
