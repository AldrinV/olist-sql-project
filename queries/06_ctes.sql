/*
	CTEs
*/

-- Top-spending customers, rewritten with a CTE
-- (same question as the subquery version in 04_subqueries.sql)
WITH customer_spend AS (
	SELECT c.customer_unique_id, SUM(oi.price) AS total_spend
	FROM customers c
	JOIN orders o
		ON o.customer_id = c.customer_id
	JOIN order_items oi
		ON oi.order_id = o.order_id
	WHERE o.order_status NOT IN ('canceled', 'unavailable')
	GROUP BY c.customer_unique_id
)
SELECT *
FROM customer_spend cs
WHERE cs.total_spend > (
	SELECT AVG(total_spend)
	FROM customer_spend
)
ORDER BY cs.total_spend DESC;

-- Repeat customers who are also above-average spenders per order
-- CTE 1: order count per customer; CTE 2: average order value per customer
WITH customer_orders AS (
	SELECT c.customer_unique_id AS unique_id, COUNT(o.order_id) AS order_count
	FROM orders o
	JOIN customers c
		ON o.customer_id = c.customer_id
	WHERE o.order_status NOT IN ('canceled', 'unavailable')
	GROUP BY c.customer_unique_id
),
customer_avg AS (
	SELECT customer_unique_id AS unique_id, ROUND(AVG(order_total), 2) AS avg_order
	FROM (
		SELECT c.customer_unique_id, o.order_id, SUM(oi.price) AS order_total
		FROM orders o
		JOIN customers c
			ON o.customer_id = c.customer_id
		JOIN order_items oi
			ON oi.order_id = o.order_id
		WHERE o.order_status NOT IN ('canceled', 'unavailable')
		GROUP BY c.customer_unique_id, o.order_id
	) AS per_order_totals
	GROUP BY customer_unique_id
)
SELECT co.unique_id, co.order_count, ca.avg_order
FROM customer_orders co
JOIN customer_avg ca
	ON co.unique_id = ca.unique_id
WHERE ca.avg_order > (
	SELECT AVG(ca2.avg_order)
	FROM customer_avg ca2
)
	AND co.order_count > 1
ORDER BY co.order_count, ca.avg_order DESC;


/*
	ADVANCED ANALYSIS
*/

-- Delivery delay by seller
-- Positive = delivered after the promised date; negative = early
SELECT seller_id, ROUND(AVG(delay_days), 2) AS avg_delay_days
FROM (
	SELECT oi.seller_id, o.order_id,
		EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400 AS delay_days
	FROM orders o
	JOIN order_items oi
		ON o.order_id = oi.order_id
	WHERE o.order_status = 'delivered'
) AS order_delays
GROUP BY seller_id
ORDER BY avg_delay_days DESC;

-- Customer retention by cohort
-- Cohort = month of a customer's first order; retained = second order within 90 days.
-- Cohorts without a full 90-day observation window are excluded.
WITH customer_orders AS (
	SELECT c.customer_unique_id, o.order_id,
		o.order_purchase_timestamp AS order_date,
		ROW_NUMBER() OVER (
			PARTITION BY c.customer_unique_id
			ORDER BY o.order_purchase_timestamp, o.order_id
		) AS order_seq
	FROM orders o
	JOIN customers c
		ON c.customer_id = o.customer_id
	WHERE o.order_status NOT IN ('canceled', 'unavailable')
),
first_second_order AS (
	SELECT co.customer_unique_id,
		MIN(CASE WHEN co.order_seq = 1 THEN co.order_date END) AS first_date,
		MIN(CASE WHEN co.order_seq = 2 THEN co.order_date END) AS second_date,
		DATE_TRUNC('month', MIN(CASE WHEN co.order_seq = 1 THEN co.order_date END))::DATE AS order_month
	FROM customer_orders co
	GROUP BY co.customer_unique_id
)
SELECT
	order_month AS cohort_month,
	COUNT(*) AS cohort_size,
	COUNT(*) FILTER (WHERE second_date <= first_date + INTERVAL '90 days') AS retained_customers,
	ROUND(
		100.0 * COUNT(*) FILTER (WHERE second_date <= first_date + INTERVAL '90 days') / COUNT(*),
		2
	) AS retention_rate_pct
FROM first_second_order
WHERE first_date + INTERVAL '90 days' <= (SELECT MAX(order_date) FROM customer_orders)
GROUP BY order_month
ORDER BY order_month;
