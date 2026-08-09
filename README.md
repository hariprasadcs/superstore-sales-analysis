# Superstore Sales Performance Analysis

End-to-end sales analytics project using SQL (MySQL) and Excel/Power Query to uncover profitability drivers, seasonal trends, and customer behavior patterns for a retail superstore.

## Business Problem
A retail superstore wants to understand which regions, products, and customer segments drive profitability — and which are quietly losing money — to guide smarter discounting, inventory, and regional strategy decisions.

## Dataset
- **Source:** [Superstore Sales Dataset](https://www.kaggle.com/datasets/nayakganesh007/superstore-sales-dataset) by nayakganesh007 (Kaggle)
- **Size:** 9,994 rows, 21 columns
- **Fields:** Order/ship dates, customer info, product details, sales, quantity, discount, and profit

## Approach
1. Imported and cleaned raw CSV data in MySQL (fixed inconsistent date formats, verified no missing values/duplicates)
2. Built analytical SQL queries using CTEs, window functions (`LAG`, `RANK`), and `JOIN`s to answer key business questions
3. Performed cohort analysis to study customer retention behavior
4. Exported cleaned data and built a dynamic Excel dashboard using Power Query, PivotTables, PivotCharts, and slicers

## Key SQL Queries

### 1. Discount Sensitivity by Customer Segment
Buckets orders by discount range to identify the exact threshold where discounting turns unprofitable.

```sql
WITH discount_buckets AS (
    SELECT
        segment,
        CASE 
            WHEN discount = 0 THEN '0% - No Discount'
            WHEN discount > 0 AND discount <= 0.10 THEN '1-10%'
            WHEN discount > 0.10 AND discount <= 0.20 THEN '11-20%'
            WHEN discount > 0.20 AND discount <= 0.30 THEN '21-30%'
            WHEN discount > 0.30 AND discount <= 0.50 THEN '31-50%'
            ELSE '50%+'
        END AS discount_range,
        sales,
        profit
    FROM orders
)
SELECT
    segment,
    discount_range,
    COUNT(*) AS num_orders,
    SUM(sales) AS total_sales,
    SUM(profit) AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM discount_buckets
GROUP BY segment, discount_range
ORDER BY segment, discount_range;
```

### 2. Month-over-Month Product Growth (Window Functions)
Ranks products by growth using `LAG()` to compare against the previous month and `RANK()` to find the top performer each month, filtered to exclude low-volume noise.

```sql
WITH product_monthly_sales AS (
    SELECT
        product_name,
        DATE_FORMAT(order_date_clean, '%Y-%m') AS order_month,
        SUM(sales) AS total_sales
    FROM orders
    GROUP BY product_name, order_month
),
product_growth AS (
    SELECT
        product_name,
        order_month,
        total_sales,
        LAG(total_sales) OVER (PARTITION BY product_name ORDER BY order_month) AS prev_sales,
        ROUND(
            (total_sales - LAG(total_sales) OVER (PARTITION BY product_name ORDER BY order_month))
            / LAG(total_sales) OVER (PARTITION BY product_name ORDER BY order_month) * 100
        , 2) AS mom_growth_pct
    FROM product_monthly_sales
),
ranked_growth AS (
    SELECT
        product_name,
        order_month,
        total_sales,
        prev_sales,
        mom_growth_pct,
        RANK() OVER (PARTITION BY order_month ORDER BY mom_growth_pct DESC) AS growth_rank
    FROM product_growth WHERE prev_sales IS NOT NULL
      AND total_sales >= 100
      AND prev_sales >= 100
)
SELECT * FROM ranked_growth
WHERE growth_rank = 1
ORDER BY order_month;
```

### 3. Customer Cohort Retention Analysis
Groups customers by their first purchase month (cohort), then tracks how many unique customers from each cohort remain active in subsequent months.
```sql
WITH customer_first_purchase AS (
    SELECT
        customer_id,
        MIN(order_date_clean) AS first_purchase_date,
        DATE_FORMAT(MIN(order_date_clean), '%Y-%m') AS cohort_month
    FROM orders
    GROUP BY customer_id
),
customer_orders_with_cohort AS (
    SELECT
        o.customer_id,
        cfp.cohort_month,
        TIMESTAMPDIFF(MONTH, cfp.first_purchase_date, o.order_date_clean) AS months_since_first_purchase
    FROM orders o
    JOIN customer_first_purchase cfp
        ON o.customer_id = cfp.customer_id
),
cohort_retention AS (
    SELECT
        cohort_month,
        months_since_first_purchase,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM customer_orders_with_cohort
    GROUP BY cohort_month, months_since_first_purchase
)
SELECT * FROM cohort_retention
ORDER BY cohort_month, months_since_first_purchase;
```
## Dashboard



<img width="966" height="666" alt="Screenshot 2026-08-09 023552" src="https://github.com/user-attachments/assets/d0128cce-b44c-4e35-909d-db856d763497" />



## Key Insights & Recommendations

**1. Discounts above 20% consistently erode profit across all customer segments.**
Consumer, Corporate, and Home Office segments all turn unprofitable once discounts exceed 20-30%, with margins collapsing to -100%+ at 50%+ discount levels.
**Recommendation:** Cap standard discounts at 15-20% company-wide; require managerial approval for anything higher.

**2. Tables and Bookcases are structurally unprofitable sub-categories.**
Tables lost -$17,725 in total profit (-8.56% margin), driven by high average discounts (26.1%) relative to other products.
**Recommendation:** Reassess pricing/discount policy specifically for Furniture sub-categories, or renegotiate supplier costs.

**3. Central region generates strong sales but the weakest profit margin (7.92%) of all four regions.**
Despite $501K in sales, Central's margin trails West (14.94%) and East (13.48%), suggesting a costlier product mix or heavier discounting in that region.
**Recommendation:** Audit Central region's discount practices and product mix against West/East to identify the margin gap's root cause.

**4. Customer retention is sporadic, not habitual.**
Cohort analysis shows most customers purchase once and don't return in the immediate following months, with re-engagement happening unpredictably months later rather than in a steady monthly pattern.
**Recommendation:** Shift retention strategy toward periodic re-engagement campaigns (quarterly emails, loyalty triggers) rather than assuming monthly repeat behavior.

**5. Sales show a strong seasonal pattern, peaking in November and dipping in January.**
This pattern repeats consistently across 2014-2017, indicating predictable holiday-driven demand.
**Recommendation:** Align inventory stocking and staffing plans with this seasonal cycle to avoid stockouts in Q4 and excess inventory in Q1.

## Tools Used
- MySQL Workbench (SQL analysis)
- Excel + Power Query (data cleaning, dashboard)
- Kaggle (dataset source)
