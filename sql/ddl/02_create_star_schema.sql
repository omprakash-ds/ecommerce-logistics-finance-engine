-- =========================================================================
-- Olist Data Warehouse: Production Star Schema (Core Layer)
-- =========================================================================

CREATE SCHEMA IF NOT EXISTS core;

-- 1. Date Dimension (Generated via PostgreSQL series: 2016 to 2018)
DROP TABLE IF EXISTS core.dim_date CASCADE;
CREATE TABLE core.dim_date AS
SELECT
    TO_CHAR(datum, 'YYYYMMDD')::INT AS date_key,
    datum AS full_date,
    EXTRACT(YEAR FROM datum)::INT AS year,
    EXTRACT(QUARTER FROM datum)::INT AS quarter,
    EXTRACT(MONTH FROM datum)::INT AS month,
    TO_CHAR(datum, 'Month') AS month_name,
    EXTRACT(DAY FROM datum)::INT AS day,
    EXTRACT(ISODOW FROM datum)::INT AS day_of_week,
    TO_CHAR(datum, 'Day') AS day_name,
    CASE WHEN EXTRACT(ISODOW FROM datum) IN (6, 7) THEN TRUE ELSE FALSE END AS is_weekend
FROM GENERATE_SERIES(
    '2016-01-01'::DATE,
    '2018-12-31'::DATE,
    '1 day'::INTERVAL
) AS datum;

ALTER TABLE core.dim_date ADD PRIMARY KEY (date_key);

-- 2. Customer Dimension
DROP TABLE IF EXISTS core.dim_customers CASCADE;
CREATE TABLE core.dim_customers AS
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    INITCAP(customer_city) AS customer_city,
    UPPER(customer_state) AS customer_state
FROM staging.raw_customers;

ALTER TABLE core.dim_customers ADD PRIMARY KEY (customer_id);
CREATE INDEX idx_dim_customers_unique ON core.dim_customers(customer_unique_id);

-- 3. Product Dimension (Merged with English category translations)
DROP TABLE IF EXISTS core.dim_products CASCADE;
CREATE TABLE core.dim_products AS
SELECT
    p.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name, 'unlabeled') AS product_category,
    p.product_name_lenght AS name_length,
    p.product_description_lenght AS description_length,
    p.product_photos_qty AS photos_qty,
    p.product_weight_g AS weight_g,
    p.product_length_cm AS length_cm,
    p.product_height_cm AS height_cm,
    p.product_width_cm AS width_cm
FROM staging.raw_products p
LEFT JOIN staging.raw_category_translation t
    ON p.product_category_name = t.product_category_name;

ALTER TABLE core.dim_products ADD PRIMARY KEY (product_id);

-- 4. Seller Dimension
DROP TABLE IF EXISTS core.dim_sellers CASCADE;
CREATE TABLE core.dim_sellers AS
SELECT
    seller_id,
    seller_zip_code_prefix,
    INITCAP(seller_city) AS seller_city,
    UPPER(seller_state) AS seller_state
FROM staging.raw_sellers;

ALTER TABLE core.dim_sellers ADD PRIMARY KEY (seller_id);

-- 5. Fact Table: Line Item Level Transactions with SLA & Financial Metrics
DROP TABLE IF EXISTS core.fact_order_items CASCADE;
CREATE TABLE core.fact_order_items AS
SELECT
    oi.order_id,
    oi.order_item_id,
    o.customer_id,
    oi.product_id,
    oi.seller_id,
    TO_CHAR(o.order_purchase_timestamp::timestamp, 'YYYYMMDD')::INT AS purchase_date_key,
    o.order_purchase_timestamp::timestamp AS order_purchase_timestamp,
    o.order_delivered_customer_date::timestamp AS order_delivered_date,
    o.order_estimated_delivery_date::timestamp AS order_estimated_delivery_date,
    o.order_status,
    oi.price,
    oi.freight_value,
    ROUND((oi.price + oi.freight_value)::NUMERIC, 2) AS total_item_value,
    -- SLA Metrics: Days to deliver and SLA breach flag
    ROUND(EXTRACT(EPOCH FROM (o.order_delivered_customer_date::timestamp - o.order_purchase_timestamp::timestamp)) / 86400.0, 2) AS actual_delivery_days,
    ROUND(EXTRACT(EPOCH FROM (o.order_estimated_delivery_date::timestamp - o.order_purchase_timestamp::timestamp)) / 86400.0, 2) AS estimated_delivery_days,
    CASE
        WHEN o.order_delivered_customer_date::timestamp > o.order_estimated_delivery_date::timestamp THEN 1
        ELSE 0
    END AS is_sla_breach
FROM staging.raw_order_items oi
JOIN staging.raw_orders o ON oi.order_id = o.order_id;

ALTER TABLE core.fact_order_items ADD PRIMARY KEY (order_id, order_item_id);
CREATE INDEX idx_fact_cust ON core.fact_order_items(customer_id);
CREATE INDEX idx_fact_prod ON core.fact_order_items(product_id);
CREATE INDEX idx_fact_seller ON core.fact_order_items(seller_id);
CREATE INDEX idx_fact_date ON core.fact_order_items(purchase_date_key);