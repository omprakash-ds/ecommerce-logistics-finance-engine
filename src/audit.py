from pathlib import Path
import pandas as pd
from sqlalchemy import create_engine, text

DB_URI = "postgresql+psycopg2://admin:admin_password@localhost:5432/olist_analytics"
engine = create_engine(DB_URI)

SQL_FILE = Path(__file__).resolve().parent.parent / "sql" / "queries" / "01_staging_audit.sql"

def run_audit():
    with open(SQL_FILE, "r") as f:
        sql_content = f.read()

    # Split queries by semicolon
    queries = [q.strip() for q in sql_content.split(";") if q.strip()]

    print("=" * 60)
    print("RUNNING STAGING INTEGRITY & RECONCILIATION AUDIT")
    print("=" * 60)

    with engine.connect() as conn:
        for idx, query in enumerate(queries, 1):
            print(f"\n--- [Audit Query #{idx}] ---")
            df = pd.read_sql(text(query), conn)
            print(df.to_string(index=False))

if __name__ == "__main__":
    run_audit()
