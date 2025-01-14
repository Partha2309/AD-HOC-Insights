-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

CREATE TABLE Q1 AS
SELECT DISTINCT MARKET FROM dim_customer
WHERE CUSTOMER = "Atliq Exclusive" AND REGION = "APAC";

-- 2. What is the percentage of unique product increase in 2021 vs. 2020? 
-- The final output contains these fields (unique_products_2020 , unique_products_2021 , percentage_chg)

CREATE TABLE Q2 AS
WITH UP20 AS (
SELECT COUNT(DISTINCT PRODUCT_CODE) AS C20
FROM fact_sales_monthly
WHERE FISCAL_YEAR = 2020
),
UP21 AS (
SELECT COUNT(DISTINCT PRODUCT_CODE) AS C21
FROM fact_sales_monthly
WHERE FISCAL_YEAR = 2021
)
SELECT B.C21 AS UNIQUE_PROD_21 , A.C20 AS UNIQUES_PROD_20 ,
(B.C21 - A.C20)*100 / A.C20 AS PCT_DIFFERENCE
FROM UP20 A , UP21 B;

-- 3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.
-- The final output contains 2 fields, segment , product_count

CREATE TABLE Q3 AS
SELECT SEGMENT , COUNT(DISTINCT PRODUCT_CODE) AS PROD_COUNT
FROM DIM_PRODUCT
GROUP BY SEGMENT
ORDER BY PROD_COUNT DESC;

-- 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
-- The final output contains these fields- (segment , product_count_2020,  product_count_2021, difference)


CREATE TABLE Q4 AS
WITH PROD_20 AS (
SELECT P.SEGMENT , COUNT(DISTINCT P.PRODUCT_CODE) AS PROD_COUNT_20
FROM  FACT_SALES_MONTHLY S 
INNER JOIN DIM_PRODUCT P
ON S.PRODUCT_CODE = P.PRODUCT_CODE
WHERE S.FISCAL_YEAR = 2020
GROUP BY P.SEGMENT
ORDER BY PROD_COUNT_20 DESC),
PROD_21 AS (
SELECT P.SEGMENT , COUNT(DISTINCT P.PRODUCT_CODE) AS PROD_COUNT_21
FROM  FACT_SALES_MONTHLY S 
INNER JOIN DIM_PRODUCT P
ON S.PRODUCT_CODE = P.PRODUCT_CODE
WHERE S.FISCAL_YEAR = 2021
GROUP BY P.SEGMENT
ORDER BY PROD_COUNT_21 DESC
)
SELECT A.SEGMENT , A.PROD_COUNT_20 , B.PROD_COUNT_21 , 
(B.PROD_COUNT_21 - A.PROD_COUNT_20) AS DIFFERENCE
FROM PROD_20 A 
INNER JOIN PROD_21 B 
ON A.SEGMENT = B.SEGMENT
ORDER BY DIFFERENCE DESC;

-- 5. Get the products that have the highest and lowest manufacturing costs.
-- The final output should contain these fields( product_code , product , manufacturing_cost)

CREATE TABLE Q5 AS
SELECT P.PRODUCT , M.PRODUCT_CODE , M.MANUFACTURING_COST
FROM fact_manufacturing_cost M 
INNER JOIN dim_product P 
ON M.PRODUCT_CODE = P.PRODUCT_CODE
WHERE M.MANUFACTURING_COST IN 
				(SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost
				UNION
				SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)
ORDER BY M.MANUFACTURING_COST DESC;


-- 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
-- The final output contains these fields,( customer_code, customer, average_discount_percentage)

CREATE TABLE Q6 AS 
SELECT C.CUSTOMER , D.CUSTOMER_CODE , ROUND(AVG(D.PRE_INVOICE_DISCOUNT_PCT)*100,2) AS AVG_DISCOUNT_PCT
FROM DIM_CUSTOMER C 
INNER JOIN fact_pre_invoice_deductions D 
ON C.CUSTOMER_CODE = D.CUSTOMER_CODE
WHERE D.FISCAL_YEAR = 2021 AND C.MARKET = "INDIA"
GROUP BY C.CUSTOMER , D.CUSTOMER_CODE
ORDER BY AVG_DISCOUNT_PCT DESC
LIMIT 5;

-- 7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . 
-- This analysis helps to get an idea of low and high-performing months and take strategic decisions.
-- The final report contains these columns:( Month, Year, Gross sales Amount)

CREATE TABLE Q7 AS
SELECT MONTHNAME(S.DATE) AS MONTH ,YEAR(S.DATE) AS YEAR , 
ROUND((SUM(G.GROSS_PRICE*S.SOLD_QUANTITY))/1000000,2) AS GROSS_SALES_AMOUNT_ML
FROM FACT_SALES_MONTHLY S
INNER JOIN FACT_GROSS_PRICE G 
ON S.PRODUCT_CODE = G.PRODUCT_CODE
INNER JOIN DIM_CUSTOMER C 
ON S.CUSTOMER_CODE = C.CUSTOMER_CODE
WHERE CUSTOMER = "ATLIQ EXCLUSIVE"
GROUP BY MONTH , YEAR
ORDER BY YEAR;

-- 8. In which quarter of 2020, got the maximum total_sold_quantity? 
-- The final output contains these fields sorted by the total_sold_quantity,( Quarter, total_sold_quantity)

CREATE TABLE Q8 AS
SELECT QUARTER(DATE_ADD(DATE, INTERVAL 4 MONTH)) AS QUARTER  , SUM(SOLD_QUANTITY) AS TOTAL_SOLD_QTY
FROM FACT_SALES_MONTHLY
WHERE FISCAL_YEAR = 2020
GROUP BY QUARTER
ORDER BY TOTAL_SOLD_QTY DESC;

-- 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
-- The final output contains these fields, (channel, gross_sales_mln, percentage)

CREATE TABLE Q9 AS
WITH CS_21 AS (
SELECT C.CHANNEL , 
ROUND(SUM(G.GROSS_PRICE * S.SOLD_QUANTITY)/1000000,2) AS GROSS_SALES_MLN
FROM FACT_SALES_MONTHLY S 
INNER JOIN FACT_GROSS_PRICE G 
ON S.PRODUCT_CODE = G.PRODUCT_CODE AND 
   S.FISCAL_YEAR = G.FISCAL_YEAR
INNER JOIN DIM_CUSTOMER C
ON S.CUSTOMER_CODE = C.CUSTOMER_CODE
WHERE G.FISCAL_YEAR = 2021
GROUP BY C.CHANNEL
ORDER BY GROSS_SALES_MLN DESC
) ,
TS_21 AS (
SELECT SUM(GROSS_SALES_MLN) AS TOTAL_GROSS_SALES_MLN
FROM CS_21
)
SELECT C.* ,
	     ROUND(C.GROSS_SALES_MLN *100 / T.TOTAL_GROSS_SALES_MLN, 2 ) AS PERCENTAGE
FROM CS_21 C , TS_21 T;

-- 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
-- The final output contains these fields, (division, product_code, product, total_sold_quantity, rank_order)

CREATE TABLE Q10 AS
WITH CTE1 AS (
SELECT P.DIVISION , P.PRODUCT_CODE , P.PRODUCT , SUM(S.SOLD_QUANTITY) AS TOTAL_SOLD_QTY 
FROM DIM_PRODUCT P
INNER JOIN FACT_SALES_MONTHLY S
ON P.PRODUCT_CODE = S.PRODUCT_CODE
WHERE S.FISCAL_YEAR = 2021
GROUP BY P.DIVISION , P.PRODUCT_CODE , P.PRODUCT
ORDER BY TOTAL_SOLD_QTY DESC
),
CTE2 AS (
SELECT * ,
	   DENSE_RANK() OVER(PARTITION BY DIVISION ORDER BY TOTAL_SOLD_QTY DESC) AS RANK_ORDER
FROM CTE1
)
SELECT * FROM CTE2 
WHERE RANK_ORDER <= 3;


