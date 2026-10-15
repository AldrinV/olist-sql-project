/*
	WINDOW FUNCTIONS
*/

-- Top 5 products by revenue within each category
WITH product_categ_rank AS (
	SELECT p.product_id, p.product_category_name, r.rev,
		DENSE_RANK() OVER (PARTITION BY p.product_category_name ORDER BY r.rev DESC) AS ranking
	FROM products p
	JOIN (
		SELECT oi.product_id, SUM(oi.price) AS rev
		FROM order_items oi
		GROUP BY oi.product_id
	) r ON r.product_id = p.product_id
)
SELECT *
FROM product_categ_rank pc
WHERE pc.ranking <= 5;

-- Running monthly revenue total (resets each year)
SELECT
	EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
	TRIM(TO_CHAR(o.order_purchase_timestamp, 'Month')) AS months,
	SUM(oi.price) AS monthly_revenue,
	SUM(SUM(oi.price)) OVER (
		PARTITION BY EXTRACT(YEAR FROM o.order_purchase_timestamp)
		ORDER BY EXTRACT(MONTH FROM o.order_purchase_timestamp)
	) AS monthly_rolling
FROM orders o
JOIN order_items oi
	ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY EXTRACT(MONTH FROM o.order_purchase_timestamp),
	EXTRACT(YEAR FROM o.order_purchase_timestamp),
	TRIM(TO_CHAR(o.order_purchase_timestamp, 'Month'))
ORDER BY order_year, EXTRACT(MONTH FROM o.order_purchase_timestamp);

-- Customer lifetime spend rank
SELECT c.customer_unique_id, SUM(oi.price) AS lifetime_spend,
	ROW_NUMBER() OVER (ORDER BY SUM(oi.price) DESC) AS ranking
FROM customers c
JOIN orders o
	ON c.customer_id = o.customer_id
JOIN order_items oi
	ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_unique_id
ORDER BY lifetime_spend DESC;

-- Delivery time quartiles (percentile 1 = fastest, 4 = slowest)
SELECT o.order_id, o.order_delivered_customer_date, o.order_purchase_timestamp,
	o.order_delivered_customer_date - o.order_purchase_timestamp AS delivery_time,
	NTILE(4) OVER (ORDER BY o.order_delivered_customer_date - o.order_purchase_timestamp) AS percentile
FROM orders o
WHERE o.order_delivered_customer_date IS NOT NULL
	AND o.order_purchase_timestamp IS NOT NULL
	AND o.order_status NOT IN ('canceled', 'unavailable')
ORDER BY delivery_time;
