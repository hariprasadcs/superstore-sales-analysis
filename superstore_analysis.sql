create database superstore_db;
use superstore_db;

CREATE TABLE orders (
    row_id INT,
    order_id VARCHAR(20),
    order_date VARCHAR(20),
    ship_date VARCHAR(20),
    ship_mode VARCHAR(20),
    customer_id VARCHAR(20),
    customer_name VARCHAR(100),
    segment VARCHAR(20),
    country VARCHAR(50),
    city VARCHAR(50),
    state VARCHAR(50),
    postal_code VARCHAR(10),
    region VARCHAR(20),
    product_id VARCHAR(20),
    category VARCHAR(30),
    sub_category VARCHAR(30),
    product_name VARCHAR(200),
    sales DECIMAL(10,2),
    quantity INT,
    discount DECIMAL(4,2),
    profit DECIMAL(10,2)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/superstore_sales.csv'
INTO TABLE orders
CHARACTER SET latin1
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

select * from orders;
select count(*) from orders;

ALTER TABLE orders 
ADD COLUMN order_date_clean DATE,
ADD COLUMN ship_date_clean DATE;

SET SQL_SAFE_UPDATES = 0;

UPDATE orders
SET order_date_clean = STR_TO_DATE(order_date, '%d-%m-%Y'),
    ship_date_clean = STR_TO_DATE(ship_date, '%d-%m-%Y');
    
select * from orders limit 15;
select * from orders where order_date_clean is null;
   
SELECT
  SUM(CASE WHEN order_id IS NULL OR order_id = '' THEN 1 ELSE 0 END) AS missing_order_id,
  SUM(CASE WHEN customer_id IS NULL OR customer_id = '' THEN 1 ELSE 0 END) AS missing_customer_id,
  SUM(CASE WHEN product_id IS NULL OR product_id = '' THEN 1 ELSE 0 END) AS missing_product_id,
  SUM(CASE WHEN sales IS NULL THEN 1 ELSE 0 END) AS missing_sales,
  SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END) AS missing_quantity,
  SUM(CASE WHEN discount IS NULL THEN 1 ELSE 0 END) AS missing_discount,
  SUM(CASE WHEN profit IS NULL THEN 1 ELSE 0 END) AS missing_profit,
  SUM(CASE WHEN order_date_clean IS NULL THEN 1 ELSE 0 END) AS missing_order_date,
  SUM(CASE WHEN region IS NULL OR region = '' THEN 1 ELSE 0 END) AS missing_region
FROM orders;

select row_id, count(*) as cnt from orders group by row_id having cnt>1;

SELECT 
  MIN(sales) AS min_sales, MAX(sales) AS max_sales,
  MIN(quantity) AS min_qty, MAX(quantity) AS max_qty,
  MIN(discount) AS min_discount, MAX(discount) AS max_discount,
  MIN(profit) AS min_profit, MAX(profit) AS max_profit
FROM orders;

select * from orders;

select region, count(distinct order_id) as total_orders,
sum(sales) as total_sales,
sum(profit) as total_profit,
round(sum(profit)/sum(sales)*100,2) as profit_margin_pct
from orders group by region order by total_sales desc;

SELECT 
    category,
    sub_category,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(sales) AS total_sales,
    SUM(profit) AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM orders
GROUP BY category, sub_category
ORDER BY total_profit ASC;

SELECT 
    category,
    sub_category,
    ROUND(AVG(discount), 3) AS avg_discount,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM orders
GROUP BY category, sub_category
ORDER BY avg_discount DESC;

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

SELECT
    DATE_FORMAT(order_date_clean, '%Y-%m') AS order_month,
    SUM(sales) AS total_sales
FROM orders
GROUP BY order_month
ORDER BY order_month;

WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(order_date_clean, '%Y-%m') AS order_month,
        SUM(sales) AS total_sales
    FROM orders
    GROUP BY order_month
)
SELECT
    order_month,
    total_sales,
    LAG(total_sales, 1) OVER (ORDER BY order_month) AS prev_month_sales,
    ROUND(
        (total_sales - LAG(total_sales, 1) OVER (ORDER BY order_month)) 
        / LAG(total_sales, 1) OVER (ORDER BY order_month) * 100
    , 2) AS mom_growth_pct
FROM monthly_sales
ORDER BY order_month;

WITH product_monthly_sales AS (
    SELECT
        product_name,
        DATE_FORMAT(order_date_clean, '%Y-%m') AS order_month,
        SUM(sales) AS total_sales
    FROM orders
    GROUP BY product_name, order_month
)
SELECT * FROM product_monthly_sales
ORDER BY product_name, order_month
LIMIT 20;

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
)
SELECT * FROM product_growth
ORDER BY product_name, order_month
LIMIT 20;

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
    FROM product_growth
    WHERE prev_sales IS NOT NULL
      AND total_sales >= 100
      AND prev_sales >= 100
)
SELECT * FROM ranked_growth
WHERE growth_rank = 1
ORDER BY order_month;

WITH customer_first_purchase AS (
    SELECT
        customer_id,
        MIN(order_date_clean) AS first_purchase_date,
        DATE_FORMAT(MIN(order_date_clean), '%Y-%m') AS cohort_month
    FROM orders
    GROUP BY customer_id
)
SELECT * FROM customer_first_purchase
ORDER BY first_purchase_date
LIMIT 15;

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
        DATE_FORMAT(o.order_date_clean, '%Y-%m') AS order_month,
        TIMESTAMPDIFF(MONTH, cfp.first_purchase_date, o.order_date_clean) AS months_since_first_purchase
    FROM orders o
    JOIN customer_first_purchase cfp
        ON o.customer_id = cfp.customer_id
)
SELECT * FROM customer_orders_with_cohort
ORDER BY customer_id, order_month
LIMIT 20;

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
ORDER BY cohort_month, months_since_first_purchase
LIMIT 20;

SET @region_filter = 'south';

PREPARE region_report FROM
'SELECT 
    category,
    sub_category,
    SUM(sales) AS total_sales,
    SUM(profit) AS total_profit
FROM orders
WHERE region = ?
GROUP BY category, sub_category
ORDER BY total_sales DESC';

EXECUTE region_report USING @region_filter;

SELECT 
    row_id, order_id, order_date_clean AS order_date, ship_date_clean AS ship_date,
    ship_mode, customer_id, customer_name, segment, country, city, state,
    postal_code, region, product_id, category, sub_category, product_name,
    sales, quantity, discount, profit
FROM orders;

select * from orders;

(SELECT 'row_id','order_id','order_date','ship_date','ship_mode','customer_id','customer_name','segment','country','city','state','postal_code','region','product_id','category','sub_category','product_name','sales','quantity','discount','profit')
UNION ALL
(SELECT row_id, order_id, order_date_clean, ship_date_clean, ship_mode, customer_id, customer_name, segment, country, city, state, postal_code, region, product_id, category, sub_category, product_name, sales, quantity, discount, profit
FROM orders)
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/superstore_cleaned4.csv'
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n';