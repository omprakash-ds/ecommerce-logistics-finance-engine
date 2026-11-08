from pathlib import Path
from sqlalchemy import create_engine, text

DB_URI = "postgresql+psycopg2://admin:admin_password@localhost:5432/olist_analytics"
engine = create_engine(DB_URI)

DDL_FILE = Path(__file__).resolve().parent.parent / "sql" / "ddl" / "02_create_star_schema.sql"

def build_star_schema():
    print("[WAREHOUSE] Reading Star Schema DDL...")
    with open(DDL_FILE, "r") as f:
        ddl_script = f.read()

    with engine.connect() as conn:
        print("[WAREHOUSE] Executing DDL statements in PostgreSQL...")
        conn.execute(text(ddl_script))
        conn.commit()
        print("[SUCCESS] Core schema and Star Schema tables successfully deployed!")

        # Verification of record counts
        tables = ["dim_date", "dim_customers", "dim_products", "dim_sellers", "fact_order_items"]
        print("\n--- Warehouse Layer Table Counts ---")
        for table in tables:
            count = conn.execute(text(f"SELECT COUNT(*) FROM core.{table};")).scalar()
            print(f"core.{table}: {count:,} records")

if __name__ == "__main__":
    build_star_schema()