--case study 5
SET search_path = case_study_5;

SELECT *
FROM weekly_sales
LIMIT 100;

SELECT DISTINCT week_date FROM weekly_sales;
SELECT DISTINCT region FROM weekly_sales;
SELECT DISTINCT platform FROM weekly_sales;
SELECT DISTINCT segment FROM weekly_sales;
SELECT DISTINCT customer_type FROM weekly_sales;
SELECT MIN(transactions),MAX(transactions) FROM weekly_sales;
SELECT MIN(sales),MAX(sales) FROM weekly_sales;

-- 1. Data Cleansing Steps
-- In a single query, perform the following operations and generate a new table in the data_mart schema named clean_weekly_sales:
--   Convert the week_date to a DATE format
--   Add a week_number as the second column for each week_date value, 
--   - for example any value from the 1st of January to 7th of January will be 1, 8th to 14th will be 2 etc
--   Add a month_number with the calendar month for each week_date value as the 3rd column
--   Add a calendar_year column as the 4th column containing either 2018, 2019 or 2020 values
--   Add a new column called age_band after the original segment column using the following mapping on the number inside the segment value
--   Add a new demographic column using the following mapping for the first letter in the segment values:
--   Ensure all null string values with an "unknown" string value in the original segment column as well as the new age_band and demographic columns
--   Generate a new avg_transaction column as the sales value divided by transactions rounded to 2 decimal places for each record
DROP TABLE IF EXISTS clean_weekly_sales;

CREATE TABLE clean_weekly_sales
AS 	
SELECT
	week_date::date AS "week_date",
	EXTRACT(WEEK FROM week_date::date) AS "week_number",
	EXTRACT(MONTH FROM week_date::date) AS "month_number",
	EXTRACT(YEAR FROM week_date::date) AS "calendar_year",
	CASE WHEN segment = 'null' THEN 'unkonwn'
		 ELSE segment
	END AS "segment",
	CASE SUBSTRING(segment,2,1)
		WHEN '1' THEN 'Young Adults'
		WHEN '2' THEN 'Middle Aged'
		WHEN '3' THEN 'Retirees' 
		WHEN '4' THEN 'Retirees'
		ELSE 'unknown'
	END AS "age_band",
	CASE
		WHEN segment LIKE 'C%' THEN 'Couples'
		WHEN segment LIKE 'F%' THEN 'Families'
		ELSE 'unknown'
	END AS "demographic",
	ROUND((sales/transactions),2) AS "avg_transaction",
	region,
	platform,
	customer_type,
	transactions,
	sales
FROM weekly_sales;

SELECT *
FROM clean_weekly_sales
LIMIT 100;

-- 2. Data Exploration:
-- 1 What day of the week is used for each week_date value?
SELECT DISTINCT week_date,
	   TO_CHAR(week_date,'Day') AS "day_of_week"
FROM clean_weekly_sales;

-- 2 What range of week numbers are missing from the dataset?
-------------------------------------------------------------
SELECT DISTINCT week_number 
FROM clean_weekly_sales
ORDER BY week_number;
SELECT MIN(week_number),MAX(week_number)
FROM clean_weekly_sales;
--missing week range (1-12) and (37-52)



-- 3 How many total transactions were there for each year in the dataset?
SELECT 
	calendar_year,
	COUNT(transactions) AS "total_transactions"
FROM clean_weekly_sales
GROUP BY calendar_year
ORDER BY calendar_year;

-- 4 What is the total sales for each region for each month?
SELECT
	region,
	month_number,
	COUNT(sales) AS "total_sales"
FROM clean_weekly_sales
GROUP BY region,month_number
ORDER BY region,month_number;

-- 5 What is the total count of transactions for each platform
SELECT
	platform,
	COUNT(transactions) AS "total_transaction"
FROM clean_weekly_sales
GROUP BY platform;

-- 6.What is the percentage of sales for Retail vs Shopify for each month?
WITH sales_cte AS
(	SELECT calendar_year,
          month_number,
          SUM(CASE
                  WHEN platform = 'Retail' THEN sales
              END) ret_sales,
		  SUM(CASE
                  WHEN platform = 'Shopify' THEN sales
              END) shop_sales,
          sum(sales) total_sales
   FROM clean_weekly_sales
   GROUP BY calendar_year,
            month_number)
SELECT calendar_year,
       month_number,
       ROUND((ret_sales*100.00)/ total_sales) retail_p,
       ROUND((shop_sales*100.00) / total_sales) shopify_p
FROM sales_cte;

-- 7 What is the percentage of sales by demographic for each year in the dataset?
WITH cte AS
(	SELECT 
 		calendar_year,
-- 		demographic,
		SUM(CASE
				WHEN demographic='Couples' THEN sales
			END) AS "c_sale",
		SUM(CASE
				WHEN demographic='Families' THEN sales
			END) AS "f_sale",
 		SUM(CASE
				WHEN demographic='unknown' THEN sales
			END) AS "un_sale",
		SUM(sales) AS "total_sale"
	FROM clean_weekly_sales
	GROUP BY calendar_year)
SELECT
	calendar_year,
-- 	demographic,
	ROUND((c_sale*100.00)/total_sale,2)||' %' AS "couple_sales",
	ROUND((f_sale*100.00)/total_sale,2)||' %' AS "family_sales",
	ROUND((un_sale*100.00)/total_sale,2)||' %' AS "unknown_sales"
FROM cte
ORDER BY calendar_year;

-- 8 Which age_band and demographic values contribute the most to Retail sales?
SELECT
	age_band,
	demographic,
	ROUND((SUM(sales)*100.00)/(SELECT SUM(sales) FROM clean_weekly_sales WHERE platform='Retail' ),2)||' %' AS "sales"
FROM clean_weekly_sales
WHERE platform='Retail'
GROUP BY age_band,demographic
ORDER BY sales;

-- 9 Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify? 
--   If not - how would you calculate it instead?

SELECT
	calendar_year,
	month_number,
	ROUND(AVG(avg_transaction),2)
FROM clean_weekly_sales
GROUP BY calendar_year,month_number
ORDER BY calendar_year,month_number;
--next
SELECT
	calendar_year,
	month_number,
	ROUND((SUM(sales)/SUM(transactions)),2)
FROM clean_weekly_sales
GROUP BY calendar_year,month_number
ORDER BY calendar_year,month_number;




-- 3. Before & After Analysis
-- Taking the week_date value of 2020-06-15 as the baseline week where the Data Mart sustainable packaging changes came into effect.
-- afterchange start date is 2020-06-15 and the previous week_date values would be before
-- 1 What is the total sales for the 4 weeks before and after 2020-06-15? 
--   What is the growth or reduction rate in actual values and percentage of sales?

--before 4 week sale
SELECT
	SUM(sales) AS "before_sale"
FROM clean_weekly_sales
WHERE week_date> '2020-06-15'::DATE - INTERVAL '4 week' AND week_date<'2020-06-15';

--after 4 week sale
SELECT
	SUM(sales) AS "after_sale"
FROM clean_weekly_sales
WHERE week_date< '2020-06-15'::DATE + INTERVAL '4 week' AND week_date>='2020-06-15';

-- GROWTH and reduction_rate
WITH cte AS
(	SELECT
		SUM(sales) AS "before_sale"
	FROM clean_weekly_sales
	WHERE week_date >='2020-06-15'::DATE - INTERVAL '4 week' AND week_date< '2020-06-15')
SELECT 
	before_sale,
	SUM(sales) AS "after_sale",
	SUM(sales)-before_sale AS "difference",
	ROUND(((SUM(sales)-before_sale)*100.00)/(SUM(sales)+before_sale),2)||' %' AS "diff_rate"
FROM clean_weekly_sales,cte
WHERE week_date BETWEEN '2020-06-15' AND '2020-06-15'::DATE + INTERVAL '4 week'
GROUP BY before_sale;


--2nd
WITH cte AS
(	SELECT
		SUM(CASE
				WHEN week_date>= ('2020-06-15'::DATE - INTERVAL '4 week') AND week_date<'2020-06-15'
					THEN sales
			END) AS "before_sale",
		SUM(CASE
				WHEN week_date BETWEEN '2020-06-15' AND '2020-06-15'::DATE+ INTERVAL '4 week'
					THEN sales
			END) AS "after_sale"
	FROM clean_weekly_sales)
SELECT
	before_sale,
	after_sale,
	after_sale-before_sale AS "difference",
	ROUND(((after_sale-before_sale)*100.00)/(before_sale+after_sale),2)||' %' AS "percent_rate",
	CASE
		WHEN after_sale-before_sale > 0 THEN 'GROWTH (↑)'
		WHEN after_sale-before_sale < 0 THEN 'REDUCTION (↓)'
		ELSE 'Balanced (=)'
	END AS "growth/reduction"
FROM cte;


-- 2 What about the entire 12 weeks before and after?
WITH cte AS
(	SELECT
		SUM(CASE
				WHEN week_date>= ('2020-06-15'::DATE - INTERVAL '12 week') AND week_date<'2020-06-15'
					THEN sales
			END) AS "before_sale",
		SUM(CASE
				WHEN week_date BETWEEN '2020-06-15' AND '2020-06-15'::DATE+ INTERVAL '12 week'
					THEN sales
			END) AS "after_sale"
	FROM clean_weekly_sales)
SELECT
	before_sale,
	after_sale,
	after_sale-before_sale AS "difference",
	ROUND(((after_sale-before_sale)*100.00)/(before_sale+after_sale),2)||' %' AS "percent_rate",
	CASE
		WHEN after_sale-before_sale > 0 THEN 'GROWTH (↑)'
		WHEN after_sale-before_sale < 0 THEN 'REDUCTION (↓)'
		ELSE 'Balanced (=)'
	END AS "growth/reduction"
FROM cte;

-- 3 How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
WITH cte AS
(	SELECT '2018' AS "year",
		SUM(CASE
				WHEN week_date>= ('2018-06-15'::DATE - INTERVAL '4 week') AND week_date<'2018-06-15'
					THEN sales
			END) AS "before_sale",
		SUM(CASE
				WHEN week_date BETWEEN '2018-06-15' AND '2018-06-15'::DATE+ INTERVAL '4 week'
					THEN sales
			END) AS "after_sale"
	FROM clean_weekly_sales sale_2018
 	UNION
	SELECT '2019' AS "year",
		SUM(CASE
				WHEN week_date>= ('2019-06-15'::DATE - INTERVAL '4 week') AND week_date<'2019-06-15'
					THEN sales
			END) AS "before_sale",
		SUM(CASE
				WHEN week_date BETWEEN '2019-06-15' AND '2019-06-15'::DATE+ INTERVAL '4 week'
					THEN sales
			END) AS "after_sale"
	FROM clean_weekly_sales sale_2019
 	UNION
	SELECT '2020' AS "year",
		SUM(CASE
				WHEN week_date>= ('2020-06-15'::DATE - INTERVAL '4 week') AND week_date<'2020-06-15'
					THEN sales
			END) AS "before_sale",
		SUM(CASE
				WHEN week_date BETWEEN '2020-06-15' AND '2020-06-15'::DATE+ INTERVAL '4 week'
					THEN sales
			END) AS "after_sale"
	FROM clean_weekly_sales sale_2020)
SELECT
	year,
	before_sale,
	after_sale,
	after_sale-before_sale AS "difference",
	ROUND(((after_sale-before_sale)*100.00)/(before_sale+after_sale),2) AS "percent_rate",
	CASE
		WHEN after_sale-before_sale > 0 THEN 'GROWTH (↑)'
		WHEN after_sale-before_sale < 0 THEN 'REDUCTION (↓)'
		ELSE 'Balanced (=)'
	END AS "growth/reduction"
FROM cte;




-- 4. Bonus Question
--   Which areas of the business have the highest negative impact in sales metrics performance in 2020 for the 12 week before and after period?
--   -region
--   -platform
--   -age_band
--   -demographic
--   -customer_type
-- Do you have any further recommendations for Danny’s team at Data Mart or any interesting insights based off this analysis?
SELECT * FROM region_sales;
SELECT * FROM platform_sales; 
SELECT * FROM age_band_sales;
SELECT * FROM demographic_sales;
SELECT * FROM cust_type_sales;


-- region
DROP TABLE IF EXISTS region_sales;
CREATE TEMP TABLE region_sales
AS
WITH cte AS
(	SELECT
 		region,
		SUM(CASE
				WHEN week_date>= ('2020-06-15'::DATE - INTERVAL '12 week') AND week_date<'2020-06-15'
					THEN sales
			END) AS "before_sale",
		SUM(CASE
				WHEN week_date BETWEEN '2020-06-15' AND '2020-06-15'::DATE+ INTERVAL '12 week'
					THEN sales
			END) AS "after_sale"
	FROM clean_weekly_sales
	GROUP BY region)
SELECT
	region,
	before_sale,
	after_sale,
	after_sale-before_sale AS "difference",
	ROUND(((after_sale-before_sale)*100.00)/(before_sale+after_sale),2)||' %' AS "percent_rate",
	CASE
		WHEN after_sale-before_sale > 0 THEN 'GROWTH (↑)'
		WHEN after_sale-before_sale < 0 THEN 'REDUCTION (↓)'
		ELSE 'Balanced (=)'
	END AS "growth/reduction"
FROM cte;

-- platform
DROP TABLE IF EXISTS platform_sales;
CREATE TEMP TABLE platform_sales
AS
WITH cte AS
(	SELECT
 		platform,
		SUM(CASE
				WHEN week_date>= ('2020-06-15'::DATE - INTERVAL '12 week') AND week_date<'2020-06-15'
					THEN sales
			END) AS "before_sale",
		SUM(CASE
				WHEN week_date BETWEEN '2020-06-15' AND '2020-06-15'::DATE+ INTERVAL '12 week'
					THEN sales
			END) AS "after_sale"
	FROM clean_weekly_sales
	GROUP BY platform)
SELECT
	platform,
	before_sale,
	after_sale,
	after_sale-before_sale AS "difference",
	ROUND(((after_sale-before_sale)*100.00)/(before_sale+after_sale),2)||' %' AS "percent_rate",
	CASE
		WHEN after_sale-before_sale > 0 THEN 'GROWTH (↑)'
		WHEN after_sale-before_sale < 0 THEN 'REDUCTION (↓)'
		ELSE 'Balanced (=)'
	END AS "growth/reduction"
FROM cte;

-- age_band
DROP TABLE IF EXISTS age_band_sales;
CREATE TEMP TABLE age_band_sales
AS
WITH cte AS
(	SELECT
 		age_band,
		SUM(CASE
				WHEN week_date>= ('2020-06-15'::DATE - INTERVAL '12 week') AND week_date<'2020-06-15'
					THEN sales
			END) AS "before_sale",
		SUM(CASE
				WHEN week_date BETWEEN '2020-06-15' AND '2020-06-15'::DATE+ INTERVAL '12 week'
					THEN sales
			END) AS "after_sale"
	FROM clean_weekly_sales
	GROUP BY age_band)
SELECT
	age_band,
	before_sale,
	after_sale,
	after_sale-before_sale AS "difference",
	ROUND(((after_sale-before_sale)*100.00)/(before_sale+after_sale),2)||' %' AS "percent_rate",
	CASE
		WHEN after_sale-before_sale > 0 THEN 'GROWTH (↑)'
		WHEN after_sale-before_sale < 0 THEN 'REDUCTION (↓)'
		ELSE 'Balanced (=)'
	END AS "growth/reduction"
FROM cte;

-- demographic
DROP TABLE IF EXISTS demographic_sales;
CREATE TEMP TABLE demographic_sales
AS
WITH cte AS
(	SELECT
 		demographic,
		SUM(CASE
				WHEN week_date>= ('2020-06-15'::DATE - INTERVAL '12 week') AND week_date<'2020-06-15'
					THEN sales
			END) AS "before_sale",
		SUM(CASE
				WHEN week_date BETWEEN '2020-06-15' AND '2020-06-15'::DATE+ INTERVAL '12 week'
					THEN sales
			END) AS "after_sale"
	FROM clean_weekly_sales
	GROUP BY demographic)
SELECT
	demographic,
	before_sale,
	after_sale,
	after_sale-before_sale AS "difference",
	ROUND(((after_sale-before_sale)*100.00)/(before_sale+after_sale),2)||' %' AS "percent_rate",
	CASE
		WHEN after_sale-before_sale > 0 THEN 'GROWTH (↑)'
		WHEN after_sale-before_sale < 0 THEN 'REDUCTION (↓)'
		ELSE 'Balanced (=)'
	END AS "growth/reduction"
FROM cte;

-- customer_type
DROP TABLE IF EXISTS cus_type_sales;
CREATE TEMP TABLE cust_type_sales
AS
WITH cte AS
(	SELECT
 		customer_type,
		SUM(CASE
				WHEN week_date>= ('2020-06-15'::DATE - INTERVAL '12 week') AND week_date<'2020-06-15'
					THEN sales
			END) AS "before_sale",
		SUM(CASE
				WHEN week_date BETWEEN '2020-06-15' AND '2020-06-15'::DATE+ INTERVAL '12 week'
					THEN sales
			END) AS "after_sale"
	FROM clean_weekly_sales
	GROUP BY customer_type)
SELECT
	customer_type,
	before_sale,
	after_sale,
	after_sale-before_sale AS "difference",
	ROUND(((after_sale-before_sale)*100.00)/(before_sale+after_sale),2)||' %' AS "percent_rate",
	CASE
		WHEN after_sale-before_sale > 0 THEN 'GROWTH (↑)'
		WHEN after_sale-before_sale < 0 THEN 'REDUCTION (↓)'
		ELSE 'Balanced (=)'
	END AS "growth/reduction"
FROM cte;

