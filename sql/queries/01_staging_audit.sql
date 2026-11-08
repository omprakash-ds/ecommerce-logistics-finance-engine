-- 1. Temporal Sequence Audit: Orders delivered before they were purchased
SELECT
    COUNT(*) AS delivered_before_purchase_count
FROM staging.raw_orders
WHERE order_delivered_customer_date::timestamp < order_purchase_timestamp::timestamp;

-- 2. Estimated vs. Actual Delivery Outliers (SLA Breach Indicator)
SELECT
    order_status,
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN order_delivered_customer_date::timestamp > order_estimated_delivery_date::timestamp THEN 1 END) AS delayed_orders,
    ROUND(
        100.0 * COUNT(CASE WHEN order_delivered_customer_date::timestamp > order_estimated_delivery_date::timestamp THEN 1 END) / COUNT(*),
        2
    ) AS pct_delayed
FROM staging.raw_orders
WHERE order_status = 'delivered'
GROUP BY order_status;

-- 3. Referential Integrity Check: Orphan Line Items (No Parent Order)
SELECT
    COUNT(*) AS orphan_order_items
FROM staging.raw_order_items oi
LEFT JOIN staging.raw_orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 4. Double-Entry Reconciliation: Order Total vs. Payment Value Mismatch
WITH order_totals AS (
    SELECT
        order_id,
        ROUND(SUM(price + freight_value)::numeric, 2) AS calculated_order_value
    FROM staging.raw_order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        ROUND(SUM(payment_value)::numeric, 2) AS total_payment_value
    FROM staging.raw_order_payments
    GROUP BY order_id
)
SELECT
    COUNT(*) AS total_orders_compared,
    COUNT(CASE WHEN ABS(o.calculated_order_value - p.total_payment_value) > 0.05 THEN 1 END) AS payment_mismatch_count,
    ROUND(
        AVG(p.total_payment_value - o.calculated_order_value), 4
    ) AS avg_discrepancy
FROM order_totals o
JOIN payment_totals p ON o.order_id = p.order_id;