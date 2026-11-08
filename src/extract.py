from pathlib import Path
import pandas as pd
from sqlalchemy import create_engine, text

# 1. Database Connection Configuration (Explicit psycopg2 driver)
DB_URI = "postgresql+psycopg2://admin:admin_password@localhost:5432/olist_analytics"
engine = create_engine(DB_URI)

# 2. Path Setup
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data" / "raw"

# 3. File-to-Table Mapping
TABLE_MAP = {
    "olist_customers_dataset.csv": "raw_customers",
    "olist_order_items_dataset.csv": "raw_order_items",
    "olist_order_payments_dataset.csv": "raw_order_payments",
    "olist_order_reviews_dataset.csv": "raw_order_reviews",
    "olist_orders_dataset.csv": "raw_orders",
    "olist_products_dataset.csv": "raw_products",
    "olist_sellers_dataset.csv": "raw_sellers",
    "product_category_name_translation.csv": "raw_category_translation",
}


def init_staging_schema():
    with engine.connect() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS staging;"))
        conn.commit()
    print("[INIT] Staging schema ready.")


def load_raw_data():
    init_staging_schema()

    for filename, table_name in TABLE_MAP.items():
        file_path = DATA_DIR / filename
        if not file_path.exists():
            print(f"[MISSING] {filename} not found in {DATA_DIR}. Skipping.")
            continue

        print(f"[INGESTING] Reading {filename}...")
        df = pd.read_csv(file_path)

        # Load into PostgreSQL under 'staging' schema
        df.to_sql(
            name=table_name,
            con=engine,
            schema="staging",
            if_exists="replace",
            index=False,
            chunksize=10000
        )
        print(f"[SUCCESS] {table_name} populated with {len(df):,} records.")


if __name__ == "__main__":
    load_raw_data()