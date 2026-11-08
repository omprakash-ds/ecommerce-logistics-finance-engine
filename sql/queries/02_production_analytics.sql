-- =========================================================================
-- Olist Data Warehouse: Production Financial & Operational Analytics Suite
-- =========================================================================

-- -------------------------------------------------------------------------
-- Query 1: Logistics SLA Slippage & Delivery Bottleneck by Brazilian State
-- Evaluates route performance, actual vs. estimated variance, and SLA breach rate.
-- -------------------------------------------------------------------------
WITH state_delivery_metrics AS (
    SELECT
        c.customer_state,
        COUNT(DISTINCT f.order_id) AS total_orders,
        ROUND(AVG(f.actual_delivery_days)::numeric, 1) AS avg_actual_delivery_days,
        ROUND(AVG(f.estimated_delivery_days)::numeric, 1) AS avg_estimated_delivery_days,
        ROUND(AVG(f.actual_delivery_days - f.estimated_delivery_days)::numeric, 1) AS delivery_variance_days,
        SUM(f.is_sla_breach) AS total_sla_breaches,
        ROUND((100.0 * SUM(f.is_sla_breach) / COUNT(DISTINCT f.order_id))::numeric, 2) AS sla_breach_rate_pct
    FROM core.fact_order_items f
    JOIN core.dim_customers c ON f.customer_id = c.customer_id
    WHERE f.order_status = 'delivered'
      AND f.actual_delivery_days IS NOT NULL
    GROUP BY c.customer_state
)
SELECT
    customer_state,
    total_orders,
    avg_actual_delivery_days,
    avg_estimated_delivery_days,
    delivery_variance_days,
    sla_breach_rate_pct,
    DENSE_RANK() OVER (ORDER BY sla_breach_rate_pct DESC) AS risk_rank
FROM state_delivery_metrics
WHERE total_orders >= 500
ORDER BY sla_breach_rate_pct DESC;


-- -------------------------------------------------------------------------
-- Query 2: Unit Economics & Margin Drag (Freight-to-Price Ratio Analysis)
-- Identifies product categories where freight cost destroys merchant unit economics.
-- -------------------------------------------------------------------------
WITH category_financials AS (
    SELECT
        p.product_category,
        COUNT(f.order_id) AS total_units_sold,
        ROUND(SUM(f.price)::numeric, 2) AS gross_merchandise_value,
        ROUND(SUM(f.freight_value)::numeric, 2) AS total_freight_cost,
        ROUND(AVG(f.price)::numeric, 2) AS avg_ticket_price,
        ROUND(AVG(f.freight_value)::numeric, 2) AS avg_freight_per_unit,
        ROUND((100.0 * SUM(f.freight_value) / NULLIF(SUM(f.price), 0))::numeric, 2) AS freight_to_price_ratio_pct
    FROM core.fact_order_items f
    JOIN core.dim_products p ON f.product_id = p.product_id
    WHERE f.order_status = 'delivered'
    GROUP BY p.product_category
)
SELECT
    product_category,
    total_units_sold,
    gross_merchandise_value,
    total_freight_cost,
    avg_ticket_price,
    avg_freight_per_unit,
    freight_to_price_ratio_pct,
    ROUND(
        (100.0 * gross_merchandise_value / SUM(gross_merchandise_value) OVER ())::numeric, 2
    ) AS pct_share_of_total_gmv
FROM category_financials
WHERE total_units_sold >= 200
ORDER BY freight_to_price_ratio_pct DESC
LIMIT 15;


-- -------------------------------------------------------------------------
-- Query 3: Monthly Customer Cohort Retention (Repurchase Dynamics)
-- Computes initial acquisition cohort and tracks repeat orders over subsequent months.
-- -------------------------------------------------------------------------
WITH customer_first_purchase AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(f.order_purchase_timestamp))::date AS cohort_month
    FROM core.fact_order_items f
    JOIN core.dim_customers c ON f.customer_id = c.customer_id
    WHERE f.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_orders AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', f.order_purchase_timestamp)::date AS order_month
    FROM core.fact_order_items f
    JOIN core.dim_customers c ON f.customer_id = c.customer_id
    WHERE f.order_status = 'delivered'
    GROUP BY c.customer_unique_id, DATE_TRUNC('month', f.order_purchase_timestamp)::date
),
cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS total_cohort_customers
    FROM customer_first_purchase
    GROUP BY cohort_month
),
retention_matrix AS (
    SELECT
        fp.cohort_month,
        (EXTRACT(YEAR FROM o.order_month) - EXTRACT(YEAR FROM fp.cohort_month)) * 12 +
        (EXTRACT(MONTH FROM o.order_month) - EXTRACT(MONTH FROM fp.cohort_month)) AS month_number,
        COUNT(DISTINCT o.customer_unique_id) AS active_customers
    FROM customer_first_purchase fp
    JOIN customer_orders o ON fp.customer_unique_id = o.customer_unique_id
    GROUP BY fp.cohort_month, month_number
)
SELECT
    TO_CHAR(rm.cohort_month, 'YYYY-MM') AS cohort,
    cs.total_cohort_customers AS cohort_size,
    rm.month_number,
    rm.active_customers,
    ROUND((100.0 * rm.active_customers / cs.total_cohort_customers)::numeric, 2) AS retention_rate_pct
FROM retention_matrix rm
JOIN cohort_size cs ON rm.cohort_month = cs.cohort_month
WHERE rm.cohort_month BETWEEN '2017-01-01' AND '2017-06-01'
  AND rm.month_number BETWEEN 0 AND 4
ORDER BY rm.cohort_month, rm.month_number;