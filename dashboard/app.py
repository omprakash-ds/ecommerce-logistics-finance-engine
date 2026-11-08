import streamlit as st
import pandas as pd
import plotly.express as px
from sqlalchemy import create_engine, text

# 1. Database Connection
DB_URI = "postgresql+psycopg2://admin:admin_password@localhost:5432/olist_analytics"
engine = create_engine(DB_URI)

st.set_page_config(page_title="E-Commerce Financial & Logistics Engine", layout="wide")

st.title("Enterprise Marketplace Intelligence & SLA Risk Engine")
st.markdown("Automated warehouse analytics powered by PostgreSQL Star Schema & Python.")

# 2. High-Level Metrics (Using sqlalchemy.text)
with engine.connect() as conn:
    total_orders = conn.execute(text("SELECT COUNT(DISTINCT order_id) FROM core.fact_order_items WHERE order_status = 'delivered';")).scalar()
    total_gmv = conn.execute(text("SELECT ROUND(SUM(price)::numeric, 2) FROM core.fact_order_items WHERE order_status = 'delivered';")).scalar()
    avg_breach_rate = conn.execute(text("SELECT ROUND(100.0 * SUM(is_sla_breach) / COUNT(DISTINCT order_id), 2) FROM core.fact_order_items WHERE order_status = 'delivered';")).scalar()

kpi1, kpi2, kpi3 = st.columns(3)
kpi1.metric("Delivered Orders", f"{total_orders:,}")
kpi2.metric("Gross Merchandise Value (GMV)", f"${total_gmv:,.2f}")
kpi3.metric("Platform SLA Breach Rate", f"{avg_breach_rate}%")

st.divider()

col_left, col_right = st.columns(2)

with col_left:
    st.subheader("Regional SLA Breach Rates by State")
    query_sla = """
        SELECT 
            c.customer_state,
            ROUND((100.0 * SUM(f.is_sla_breach) / COUNT(DISTINCT f.order_id))::numeric, 2) AS sla_breach_rate_pct
        FROM core.fact_order_items f
        JOIN core.dim_customers c ON f.customer_id = c.customer_id
        WHERE f.order_status = 'delivered'
        GROUP BY c.customer_state
        HAVING COUNT(DISTINCT f.order_id) >= 500
        ORDER BY sla_breach_rate_pct DESC;
    """
    df_sla = pd.read_sql(text(query_sla), engine.connect())
    fig_sla = px.bar(
        df_sla,
        x="customer_state",
        y="sla_breach_rate_pct",
        labels={"customer_state": "State", "sla_breach_rate_pct": "Breach Rate (%)"},
        color="sla_breach_rate_pct",
        color_continuous_scale="Reds"
    )
    st.plotly_chart(fig_sla, use_container_width=True)

with col_right:
    st.subheader("Freight Cost vs. Product Price by Category")
    query_freight = """
        SELECT 
            p.product_category,
            ROUND(AVG(f.price)::numeric, 2) AS avg_price,
            ROUND(AVG(f.freight_value)::numeric, 2) AS avg_freight
        FROM core.fact_order_items f
        JOIN core.dim_products p ON f.product_id = p.product_id
        WHERE f.order_status = 'delivered'
        GROUP BY p.product_category
        HAVING COUNT(f.order_id) >= 500
        ORDER BY (SUM(f.freight_value) / NULLIF(SUM(f.price), 0)) DESC
        LIMIT 10;
    """
    df_freight = pd.read_sql(text(query_freight), engine.connect())
    fig_freight = px.bar(
        df_freight,
        x="product_category",
        y=["avg_price", "avg_freight"],
        barmode="group",
        labels={"value": "Amount ($)", "product_category": "Category"},
        title="Top Categories by Freight Drag Ratio"
    )
    st.plotly_chart(fig_freight, use_container_width=True)