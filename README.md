# Olist E-Commerce — SQL Analytics Project

A PostgreSQL project built on the Brazilian e-commerce public dataset by Olist.
It covers loading raw CSVs through a staging layer, designing a typed and
constrained schema, and answering business questions with progressively
advanced SQL: aggregates, subqueries, window functions, CTEs, and cohort retention.

## What this project covers

- Staging raw CSV data, then transforming it into a clean relational schema
- Designing keys around real data quirks (non-unique IDs, nullable timestamps)
- Business analytics: revenue trends, customer value, seller performance, delivery delays
- Cohort retention analysis using window functions and conditional aggregation

## Dataset

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
on Kaggle: real, anonymized orders from a Brazilian marketplace (2016-2018).

## Schema

Seven tables, loaded from eight staging tables:

- `customers`: one row per `customer_id`, with `customer_unique_id` identifying the actual person
- `sellers`: seller location info
- `products`: dimensions, weight, and English category name (translation joined in during load)
- `orders`: order status and lifecycle timestamps
- `order_items`: one row per item in an order, linked to products and sellers
- `order_payments`: one or more payment rows per order
- `order_reviews`: review scores and comments per order

*(Add your ER diagram image here.)*

See [`schema/olist_schema.sql`](schema/olist_schema.sql) for the full staging, schema, and transform pipeline.

## Queries

| File | Covers |
|---|---|
| [`queries/01_basic.sql`](queries/01_basic.sql) | Filtering, sorting, date ranges, NULL handling |
| [`queries/02_joins.sql`](queries/02_joins.sql) | Multi-table joins, LEFT JOIN anti-joins |
| [`queries/03_aggregates.sql`](queries/03_aggregates.sql) | GROUP BY, revenue and distribution analysis |
| [`queries/04_subqueries.sql`](queries/04_subqueries.sql) | Scalar subqueries, NOT EXISTS, multi-level aggregation |
| [`queries/05_window_functions.sql`](queries/05_window_functions.sql) | RANK, ROW_NUMBER, NTILE, running totals |
| [`queries/06_ctes.sql`](queries/06_ctes.sql) | Multi-step CTEs, delivery delays, cohort retention |

## Data quirks and how I handled them

- **`customer_id` is per order, not per person.** Every order gets its own `customer_id`, so grouping by it makes every customer look like a one-time buyer. All repeat-customer analysis uses `customer_unique_id`.
- **`review_id` isn't unique.** Duplicate-key errors on load turned out to be different orders sharing a review ID, not true duplicates. Deduplicating would have deleted real reviews, so I switched to a composite key of `(review_id, order_id)`.
- **No quantity column.** Multiple units appear as multiple `order_items` rows, so quantity is derived with `COUNT(*)`.
- **Timestamps are legitimately NULL.** Canceled and in-transit orders have no delivery date, so those columns can't be `NOT NULL`. An over-strict constraint failed the load and was removed.
- **Zip codes stored as text.** Treating them as integers would drop leading zeros.
- **Dataset typos preserved in staging.** `product_name_lenght` and `product_description_lenght` are misspelled in the source files; the final schema corrects them.

## Lessons learned

- **Aggregation granularity.** Several bugs came from mixing levels: averaging item prices instead of order totals, or grouping by a line-item column when ranking customers. The fix each time was to aggregate to one row per order, then aggregate again.
- **Check exact values before filtering.** A filter on `'cancelled'` silently did nothing because the data uses `'canceled'`. I now run `SELECT DISTINCT` on a column before hard-coding values into `WHERE`.
- **`OR` vs `AND` when excluding values.** `status != 'a' OR status != 'b'` is always true. Excluding multiple values needs `AND` or `NOT IN`.
- **`NOT EXISTS` looks for the disqualifier.** The inner query should find a row that breaks the rule, not one that satisfies it.
- **Load order matters.** Foreign keys mean parent tables must be populated before children.

## Key findings

*(Fill these in from your own query results, for example: peak revenue month, share of customers who reordered, retention rate by cohort, which sellers deliver latest.)*

## Tools

- PostgreSQL
- pgAdmin / psql

## Setup

1. Download the dataset from Kaggle and extract the CSVs
2. Create a database and run [`schema/olist_schema.sql`](schema/olist_schema.sql): create staging tables, import with `\copy`, create the final schema, then run the transforms
3. Explore the queries in `queries/`
