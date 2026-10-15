/*
	JOINS
*/

-- Full details for one order (quantity is derived: order_items has one row per unit)
WITH quantity_price AS (
	SELECT order_id, product_id, COUNT(*) AS quantity, SUM(price) AS line_total
	FROM order_items
	GROUP BY order_id, product_id
)
SELECT qp.order_id,
	p.product_category_name AS product_name,
	c.customer_city AS city,
	qp.quantity,
	qp.line_total AS total_price
FROM orders o
JOIN customers c
	ON o.customer_id = c.customer_id
JOIN quantity_price qp
	ON qp.order_id = o.order_id
JOIN products p
	ON p.product_id = qp.product_id
WHERE o.order_id = '00143d0f86d6fbd9f9b38ab440ac16f5'; -- change to look up a different order

-- Customer order history (all orders for one real person, via customer_unique_id)
SELECT c.customer_unique_id, c.customer_id, o.order_id
FROM orders o
JOIN customers c
	ON o.customer_id = c.customer_id
WHERE c.customer_unique_id = '00172711b30d52eea8b313a7f2cced02'; -- change to look up a different customer

-- Seller product catalog (distinct categories one seller has sold)
SELECT DISTINCT p.product_category_name AS products_being_sold
FROM sellers s
JOIN order_items oi
	ON oi.seller_id = s.seller_id
JOIN products p
	ON p.product_id = oi.product_id
WHERE s.seller_id = '586a871d4f1221763fddb6ceefdeb95e'; -- change to look up a different seller

-- Orders with no review (LEFT JOIN + IS NULL on the review's primary key)
SELECT o.order_id
FROM orders o
LEFT JOIN order_reviews orr
	ON orr.order_id = o.order_id
WHERE orr.review_id IS NULL;

-- Multi-payment orders (orders paid with more than one payment row)
SELECT o.order_id, op.payment_type
FROM orders o
JOIN order_payments op
	ON op.order_id = o.order_id
WHERE o.order_id IN (
	SELECT op1.order_id
	FROM order_payments op1
	GROUP BY op1.order_id
	HAVING COUNT(op1.order_id) > 1
);

-- Products never ordered
SELECT p.product_id
FROM products p
LEFT JOIN order_items oi
	ON oi.product_id = p.product_id
WHERE oi.order_id IS NULL;
