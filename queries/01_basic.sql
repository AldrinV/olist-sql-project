/*
	BASIC SELECT QUERIES
*/

-- Recent orders (most recent 3 months of the dataset)
SELECT *
FROM orders o
WHERE o.order_purchase_timestamp >= (
	SELECT MAX(order_purchase_timestamp) FROM orders
) - INTERVAL '3 months'
ORDER BY o.order_purchase_timestamp DESC;

-- Order status breakdown
SELECT DISTINCT o.order_status
FROM orders o;

-- High-value line items (items over $200)
SELECT oi.product_id, oi.price
FROM order_items oi
WHERE oi.price > 200
ORDER BY oi.price DESC;

-- Products missing weight data
SELECT *
FROM products p
WHERE p.product_weight_g IS NULL;

-- Late deliveries (delivered after the estimated date)
SELECT o.order_id,
	o.order_estimated_delivery_date AS estimated_delivery_date,
	o.order_delivered_customer_date AS delivery_date
FROM orders o
WHERE o.order_delivered_customer_date > o.order_estimated_delivery_date;
