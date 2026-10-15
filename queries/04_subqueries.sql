/*
	SUBQUERIES
*/

-- Above-average order value
-- (the threshold is the average of per-order totals, not of item prices)
SELECT oi.order_id, SUM(oi.price) AS order_total
FROM order_items oi
GROUP BY oi.order_id
HAVING SUM(oi.price) > (
	SELECT AVG(order_total)
	FROM (
		SELECT SUM(oi1.price) AS order_total
		FROM order_items oi1
		GROUP BY oi1.order_id
	) AS order_totals
)
ORDER BY order_total DESC;

-- Top-spending customers (above the average customer's lifetime spend)
-- Subquery version; the CTE version of this lives in 06_ctes.sql
SELECT c.customer_unique_id, SUM(oi.price) AS total_spend
FROM customers c
JOIN orders o
	ON o.customer_id = c.customer_id
JOIN order_items oi
	ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_unique_id
HAVING SUM(oi.price) > (
	SELECT AVG(customer_total)
	FROM (
		SELECT SUM(oi2.price) AS customer_total
		FROM customers c2
		JOIN orders o2
			ON o2.customer_id = c2.customer_id
		JOIN order_items oi2
			ON oi2.order_id = o2.order_id
		WHERE o2.order_status NOT IN ('canceled', 'unavailable')
		GROUP BY c2.customer_unique_id
	) AS customer_totals
)
ORDER BY total_spend DESC;

-- One-time buyers (customers with exactly one order)
-- COUNT(DISTINCT order_id) because a customer's orders can have many line items
SELECT c.customer_unique_id
FROM customers c
JOIN orders o
	ON o.customer_id = c.customer_id
GROUP BY c.customer_unique_id
HAVING COUNT(DISTINCT o.order_id) = 1;

-- Sellers with only 5-star reviews
-- NOT EXISTS looks for a disqualifying review; the EXISTS clause drops sellers with no reviews at all
SELECT s.seller_id
FROM sellers s
WHERE NOT EXISTS (
	SELECT 1
	FROM order_items oi
	JOIN order_reviews ors
		ON oi.order_id = ors.order_id
	WHERE ors.review_score < 5
		AND oi.seller_id = s.seller_id
)
AND EXISTS (
	SELECT 1
	FROM order_items oi2
	JOIN order_reviews ors2
		ON oi2.order_id = ors2.order_id
	WHERE oi2.seller_id = s.seller_id
);
