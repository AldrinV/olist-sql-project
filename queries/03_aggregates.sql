/*
	AGGREGATES & GROUP BY
*/

-- Monthly revenue for 2018, sorted chronologically
SELECT
	EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month_number,
	TRIM(TO_CHAR(o.order_purchase_timestamp, 'Month')) AS month_name,
	SUM(oi.price) AS revenue
FROM orders o
JOIN order_items oi
	ON oi.order_id = o.order_id
WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
	AND o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY month_number, month_name
ORDER BY month_number;

-- Top 10 products by revenue
SELECT p.product_id, p.product_category_name, SUM(oi.price) AS product_revenue
FROM products p
JOIN order_items oi
	ON oi.product_id = p.product_id
GROUP BY p.product_id, p.product_category_name
ORDER BY product_revenue DESC
LIMIT 10;

-- Average order value by customer state
-- (aggregate to one row per order first, then average those order totals)
WITH agg_orders AS (
	SELECT o.customer_id, SUM(oi.price) AS agg_price
	FROM orders o
	JOIN order_items oi
		ON oi.order_id = o.order_id
	GROUP BY o.order_id
)
SELECT c.customer_state, ROUND(AVG(ao.agg_price), 2) AS avg_order_value
FROM customers c
JOIN agg_orders ao
	ON ao.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY avg_order_value DESC;

-- Review score distribution
SELECT review_score, COUNT(*) AS review_count
FROM order_reviews
GROUP BY review_score
ORDER BY review_score DESC;
