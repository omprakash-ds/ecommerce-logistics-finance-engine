from pathlib import Path
import pandas as pd
from sqlalchemy import create_engine, text

DB_URI = "postgresql+psycopg2://admin:admin_password@localhost:5432/olist_analytics"
engine = create_engine(DB_URI)

SQL_FILE = Path(__file__).resolve().parent.parent / "sql" / "queries" / "02_production_analytics.sql"

def run_analytics():
    with open(SQL_FILE, "r") as f:
        sql_content = f.read()

    # Split distinct queries separated by semicolons
    queries = [q.strip() for q in sql_content.split(";") if q.strip()]
    query_titles = [
        "Query 1: Logistics SLA Slippage & Delivery Bottleneck by State",
        "Query 2: Unit Economics & Margin Drag (Freight-to-Price Ratio)",
        "Query 3: Monthly Customer Cohort Retention"
    ]

    print("=" * 80)
    print("EXECUTING ADVANCED FINANCIAL & LOGISTICS ANALYTICS")
    print("=" * 80)

    with engine.connect() as conn:
        for idx, (title, query) in enumerate(zip(query_titles, queries), 1):
            print(f"\n>>> [{title}] <<<")
            df = pd.read_sql(text(query), conn)
            print(df.to_string(index=False))

if __name__ == "__main__":
    run_analytics()