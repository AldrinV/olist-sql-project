-- ============================================================
-- OLIST E-COMMERCE PROJECT — SCHEMA + IMPORT SCRIPT
-- ============================================================
-- Strategy: load raw CSVs into staging tables (all TEXT, no
-- constraints), then transform into a typed, constrained schema.
-- Run this against its own database (e.g. ecommercedb).
-- ============================================================


-- ============================================================
-- STEP 1: STAGING TABLES (mirror the raw CSV structure)
-- ============================================================

DROP TABLE IF EXISTS staging_customers;
CREATE TABLE staging_customers (
    customer_id                TEXT,
    customer_unique_id         TEXT,
    customer_zip_code_prefix   TEXT,
    customer_city              TEXT,
    customer_state             TEXT
);

DROP TABLE IF EXISTS staging_orders;
CREATE TABLE staging_orders (
    order_id                        TEXT,
    customer_id                     TEXT,
    order_status                    TEXT,
    order_purchase_timestamp        TEXT,
    order_approved_at               TEXT,
    order_delivered_carrier_date    TEXT,
    order_delivered_customer_date   TEXT,
    order_estimated_delivery_date   TEXT
);

DROP TABLE IF EXISTS staging_order_items;
CREATE TABLE staging_order_items (
    order_id             TEXT,
    order_item_id        TEXT,
    product_id           TEXT,
    seller_id            TEXT,
    shipping_limit_date  TEXT,
    price                TEXT,
    freight_value        TEXT
);

DROP TABLE IF EXISTS staging_order_payments;
CREATE TABLE staging_order_payments (
    order_id               TEXT,
    payment_sequential     TEXT,
    payment_type           TEXT,
    payment_installments   TEXT,
    payment_value          TEXT
);

DROP TABLE IF EXISTS staging_order_reviews;
CREATE TABLE staging_order_reviews (
    review_id                TEXT,
    order_id                 TEXT,
    review_score             TEXT,
    review_comment_title     TEXT,
    review_comment_message   TEXT,
    review_creation_date     TEXT,
    review_answer_timestamp  TEXT
);

DROP TABLE IF EXISTS staging_products;
CREATE TABLE staging_products (
    product_id                   TEXT,
    product_category_name        TEXT,
    product_name_lenght          TEXT,  -- typo is in Olist's source file
    product_description_lenght   TEXT,  -- typo is in Olist's source file
    product_photos_qty           TEXT,
    product_weight_g             TEXT,
    product_length_cm            TEXT,
    product_height_cm            TEXT,
    product_width_cm             TEXT
);

DROP TABLE IF EXISTS staging_sellers;
CREATE TABLE staging_sellers (
    seller_id               TEXT,
    seller_zip_code_prefix  TEXT,
    seller_city             TEXT,
    seller_state            TEXT
);

DROP TABLE IF EXISTS staging_category_translation;
CREATE TABLE staging_category_translation (
    product_category_name          TEXT,
    product_category_name_english  TEXT
);


-- ============================================================
-- STEP 2: IMPORT — run from psql, adjust paths to your folder
-- ============================================================
-- Double-check each file is going into the matching table, and
-- that your prompt shows the right database before running.

-- SET client_encoding TO 'UTF8';
-- \copy staging_customers FROM 'D:/path/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- \copy staging_orders FROM 'D:/path/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- \copy staging_order_items FROM 'D:/path/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- \copy staging_order_payments FROM 'D:/path/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- \copy staging_order_reviews FROM 'D:/path/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- \copy staging_products FROM 'D:/path/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- \copy staging_sellers FROM 'D:/path/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- \copy staging_category_translation FROM 'D:/path/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');


-- ============================================================
-- STEP 3: FINAL SCHEMA
-- Tables are created parents-first so foreign keys resolve.
-- ============================================================

DROP TABLE IF EXISTS order_reviews;
DROP TABLE IF EXISTS order_payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS sellers;
DROP TABLE IF EXISTS customers;

-- customer_id is unique PER ORDER; customer_unique_id identifies
-- the actual person across orders. Use customer_unique_id for any
-- repeat-customer analysis.
CREATE TABLE customers (
    customer_id                TEXT PRIMARY KEY,
    customer_unique_id         TEXT,
    customer_zip_code_prefix   TEXT,    -- TEXT, not INTEGER: preserves leading zeros
    customer_city              TEXT,
    customer_state             TEXT
);

CREATE TABLE sellers (
    seller_id               TEXT PRIMARY KEY,
    seller_zip_code_prefix  TEXT,
    seller_city             TEXT,
    seller_state            TEXT
);

CREATE TABLE products (
    product_id                  TEXT PRIMARY KEY,
    product_category_name       TEXT,   -- English name where a translation exists
    product_name_length         INTEGER,
    product_description_length  INTEGER,
    product_photos_qty          INTEGER,
    product_weight_g            INTEGER,
    product_length_cm           INTEGER,
    product_height_cm           INTEGER,
    product_width_cm            INTEGER
);

-- Delivery and approval timestamps are legitimately NULL for
-- canceled or in-transit orders, so they are NOT constrained.
CREATE TABLE orders (
    order_id                       TEXT PRIMARY KEY,
    customer_id                    TEXT REFERENCES customers(customer_id),
    order_status                   TEXT,
    order_purchase_timestamp       TIMESTAMP,
    order_approved_at              TIMESTAMP,
    order_delivered_carrier_date   TIMESTAMP,
    order_delivered_customer_date  TIMESTAMP,
    order_estimated_delivery_date  TIMESTAMP
);

-- No quantity column exists: buying 2 units creates 2 rows with
-- order_item_id 1 and 2. Derive quantity with COUNT(*).
CREATE TABLE order_items (
    order_id             TEXT REFERENCES orders(order_id),
    order_item_id        INTEGER,
    product_id           TEXT REFERENCES products(product_id),
    seller_id            TEXT REFERENCES sellers(seller_id),
    shipping_limit_date  TIMESTAMP,
    price                NUMERIC(10,2),
    freight_value        NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE order_payments (
    order_id               TEXT REFERENCES orders(order_id),
    payment_sequential     INTEGER,
    payment_type           TEXT,
    payment_installments   INTEGER,
    payment_value          NUMERIC(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- review_id alone is NOT unique in the source data: different
-- orders can share a review_id, so the key is composite.
CREATE TABLE order_reviews (
    review_id                TEXT,
    order_id                 TEXT REFERENCES orders(order_id),
    review_score             INTEGER,
    review_comment_title     TEXT,
    review_comment_message   TEXT,
    review_creation_date     TIMESTAMP,
    review_answer_timestamp  TIMESTAMP,
    PRIMARY KEY (review_id, order_id)
);


-- ============================================================
-- STEP 4: TRANSFORM STAGING -> FINAL (parents before children)
-- ============================================================

INSERT INTO customers (customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state)
SELECT customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state
FROM staging_customers;

INSERT INTO sellers (seller_id, seller_zip_code_prefix, seller_city, seller_state)
SELECT seller_id, seller_zip_code_prefix, seller_city, seller_state
FROM staging_sellers;

-- LEFT JOIN keeps products with no translation; COALESCE falls
-- back to the original Portuguese name for those.
INSERT INTO products (
    product_id, product_category_name, product_name_length,
    product_description_length, product_photos_qty,
    product_weight_g, product_length_cm, product_height_cm, product_width_cm
)
SELECT
    p.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name),
    NULLIF(p.product_name_lenght, '')::INTEGER,
    NULLIF(p.product_description_lenght, '')::INTEGER,
    NULLIF(p.product_photos_qty, '')::INTEGER,
    NULLIF(p.product_weight_g, '')::INTEGER,
    NULLIF(p.product_length_cm, '')::INTEGER,
    NULLIF(p.product_height_cm, '')::INTEGER,
    NULLIF(p.product_width_cm, '')::INTEGER
FROM staging_products p
LEFT JOIN staging_category_translation t
    ON t.product_category_name = p.product_category_name;

INSERT INTO orders (
    order_id, customer_id, order_status,
    order_purchase_timestamp, order_approved_at,
    order_delivered_carrier_date, order_delivered_customer_date,
    order_estimated_delivery_date
)
SELECT
    order_id, customer_id, order_status,
    NULLIF(order_purchase_timestamp, '')::TIMESTAMP,
    NULLIF(order_approved_at, '')::TIMESTAMP,
    NULLIF(order_delivered_carrier_date, '')::TIMESTAMP,
    NULLIF(order_delivered_customer_date, '')::TIMESTAMP,
    NULLIF(order_estimated_delivery_date, '')::TIMESTAMP
FROM staging_orders;

INSERT INTO order_items (
    order_id, order_item_id, product_id, seller_id,
    shipping_limit_date, price, freight_value
)
SELECT
    order_id,
    NULLIF(order_item_id, '')::INTEGER,
    product_id,
    seller_id,
    NULLIF(shipping_limit_date, '')::TIMESTAMP,
    NULLIF(price, '')::NUMERIC(10,2),
    NULLIF(freight_value, '')::NUMERIC(10,2)
FROM staging_order_items;

INSERT INTO order_payments (
    order_id, payment_sequential, payment_type,
    payment_installments, payment_value
)
SELECT
    order_id,
    NULLIF(payment_sequential, '')::INTEGER,
    payment_type,
    NULLIF(payment_installments, '')::INTEGER,
    NULLIF(payment_value, '')::NUMERIC(10,2)
FROM staging_order_payments;

INSERT INTO order_reviews (
    review_id, order_id, review_score, review_comment_title,
    review_comment_message, review_creation_date, review_answer_timestamp
)
SELECT
    review_id,
    order_id,
    NULLIF(review_score, '')::INTEGER,
    review_comment_title,
    review_comment_message,
    NULLIF(review_creation_date, '')::TIMESTAMP,
    NULLIF(review_answer_timestamp, '')::TIMESTAMP
FROM staging_order_reviews;


-- ============================================================
-- STEP 5: SANITY CHECKS — compare against staging row counts
-- ============================================================
-- Expected: customers 99,441 | sellers 3,095 | products 32,951 |
-- orders 99,441 | order_items 112,650 | order_payments 103,886 |
-- order_reviews 99,224

-- SELECT 'customers' AS table_name, COUNT(*) FROM customers
-- UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
-- UNION ALL SELECT 'products', COUNT(*) FROM products
-- UNION ALL SELECT 'orders', COUNT(*) FROM orders
-- UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
-- UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
-- UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews;
