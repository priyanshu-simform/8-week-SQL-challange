--case study 4
SET search_path=case_study_4;
SELECT *
FROM regions;

SELECT * FROM customer_transactions
ORDER BY customer_id
LIMIT 20;
SELECT DISTINCT txn_type FROM customer_transactions;


SELECT * FROM customer_nodes
LIMIT 100;



-- A. Customer Nodes Exploration
-- 1 How many unique nodes are there on the Data Bank system?
SELECT COUNT(DISTINCT node_id)
FROM customer_nodes;

-- 2 What is the number of nodes per region?
SELECT
	region_id,
	region_name,
	COUNT(node_id)
FROM customer_nodes
JOIN regions
USING(region_id)
GROUP BY region_id,region_name;

-- 3 How many customers are allocated to each region?
SELECT
	region_id,
	region_name,
	COUNT(DISTINCT customer_id)
FROM customer_nodes
JOIN regions
USING(region_id)
GROUP BY region_id,region_name;

-- 4 How many days on average are customers reallocated to a different node?
SELECT max(end_date) FROM customer_nodes;

SELECT ROUND(AVG(end_date-start_date)) AS "average_rellocation_days"
FROM customer_nodes
WHERE end_date<(SELECT max(end_date) 
				 FROM customer_nodes);

-- 5 What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
SELECT 
	region_id,
	ROUND(AVG(end_date-start_date)) AS "average_rellocation_days"
FROM customer_nodes
WHERE end_date<(SELECT max(end_date) 
				 FROM customer_nodes)
GROUP BY region_id;





-- B. Customer Transactions
-- 1 What is the unique count and total amount for each transaction type?
SELECT 
	txn_type,
	COUNT(*) AS "unique_count",
	SUM(txn_amount) AS "total_amount"
FROM customer_transactions
GROUP BY txn_type;

-- 2 What is the average total historical deposit counts and amounts for all customers?
WITH cte AS
(	SELECT
		customer_id,
		COUNT(customer_id) AS "deposit_count",
		SUM(txn_amount) AS "total_amount"
	FROM customer_transactions
	WHERE txn_type = 'deposit'
	GROUP BY customer_id)
SELECT 
	ROUND(AVG(deposit_count),2) AS "avg_deposit_count",
	ROUND(AVG(total_amount), 2) AS "avg_total_amount"
FROM cte;

-- 3 For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
SELECT DISTINCT txn_type FROM customer_transactions;
WITH cte AS
(	SELECT
		customer_id,
		EXTRACT(MONTH FROM txn_date) AS "month",
		SUM(CASE WHEN txn_type='deposit' THEN 1 ELSE 0 END) AS "deposit",
		SUM(CASE WHEN txn_type='purchase' THEN 1 ELSE 0 END) AS "purchase",
		SUM(CASE WHEN txn_type='withdrawal' THEN 1 ELSE 0 END) AS "withdrawal"
	FROM customer_transactions
	GROUP BY month,customer_id)
SELECT
	month,
	COUNT(customer_id)
FROM cte
WHERE deposit>1 AND (purchase>=1 OR withdrawal>=1)
GROUP BY month
ORDER BY month;


-- 4 What is the closing balance for each customer at the end of the month?
WITH cte AS
(	SELECT
		EXTRACT(MONTH FROM txn_date) AS "month",
		customer_id,
		(CASE
			WHEN txn_type='deposit' THEN txn_amount
			ELSE -txn_amount
		END) AS "amount"
	FROM customer_transactions
	ORDER BY month,customer_id)
SELECT 
	month,
	customer_id,
-- 	amount,
	SUM(amount) AS "closing_amt_per_month"
FROM cte
GROUP BY month,customer_id
ORDER BY month,customer_id;

SELECT *,
	ROW_NUMBER() OVER(PARTITION BY customer_id
					  ORDER BY txn_date)
FROM customer_transactions
LIMIT 100;

-- 5 What is the percentage of customers who increase their closing balance by more than 5%?
WITH cte AS
(	SELECT
		EXTRACT(MONTH FROM txn_date) AS "month",
		customer_id,
		SUM(CASE
			WHEN txn_type='deposit' THEN +txn_amount
			ELSE -txn_amount
		END) AS "amount"
	FROM customer_transactions
	GROUP BY month,customer_id),
cte_1 AS
(	SELECT 
		month,
		customer_id,
		amount,
		SUM(amount) OVER(PARTITION BY customer_id
						 ORDER BY month) AS "final_amount"
	FROM cte)
SELECT (COUNT(DISTINCT customer_id)*100.00) /(SELECT COUNT(DISTINCT customer_id) FROM customer_transactions)
FROM cte_1
WHERE final_amount>=amount*0.05;
--new
WITH cte AS
(	SELECT
		EXTRACT(MONTH FROM txn_date) AS "month",
		customer_id,
		SUM(CASE
			WHEN txn_type='deposit' THEN txn_amount
			ELSE -txn_amount
		END) AS "amount"
	FROM customer_transactions
 	GROUP BY customer_id,month
	ORDER BY customer_id),
cte_1 AS
(	SELECT 
		month,
		customer_id,
	-- 	amount,
		SUM(amount) OVER(PARTITION BY customer_id
						 ORDER BY month) AS "cls_amt_month"
	FROM cte
	ORDER BY month,customer_id),
cte_2 AS
(	SELECT 
		*,
		LAG(cls_amt_month) OVER(PARTITION BY customer_id
									ORDER BY month) AS "prev_amt_month",
		cls_amt_month-LAG(cls_amt_month) OVER(PARTITION BY customer_id
									ORDER BY month) AS "diff"
	FROM cte_1
	ORDER BY customer_id,month)
SELECT
	ROUND((COUNT(customer_id)*100.00)/(SELECT COUNT(customer_id) FROM customer_transactions),2)||' %' AS "percentage"
FROM cte_2
WHERE diff>=(cls_amt_month*0.05);



-- C. Data Allocation Challenge
-- Option 1: data is allocated based off the amount of money at the end of the previous month
-- Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days
-- Option 3: data is updated real-time
-- For this multi-part challenge question - you have been requested to generate the following data elements 
-- to help the Data Bank team estimate how much data will need to be provisioned for each option:
-- 1.running customer balance column that includes the impact each transaction
DROP TABLE IF EXISTS temp_running_bal;
CREATE TEMP TABLE temp_running_bal
AS
WITH cte AS
(	SELECT
		customer_id,
		txn_type,
		txn_amount,
		CASE
			WHEN txn_type='deposit' THEN txn_amount
			ELSE -txn_amount
		END AS "signed_amt",
		txn_date
	FROM customer_transactions
	ORDER BY customer_id,txn_date)
SELECT
	*,
	SUM(signed_amt) OVER(PARTITION BY customer_id
						 ORDER BY txn_date) AS "cum_sum"
FROM cte;
SELECT * FROM temp_running_bal
WHERE cum_sum<-7000;
-- 2. customer balance at the end of each month
WITH cte AS
(	SELECT
		customer_id,
		txn_type,
		txn_date,
		txn_amount,
		CASE
			WHEN txn_type='deposit' THEN txn_amount
			ELSE -txn_amount
		END AS "actual_amt",
 		EXTRACT(MONTH FROM txn_date)::INT AS "month"
	FROM customer_transactions)
SELECT
	customer_id,
	month,
	TO_CHAR(txn_date,'Month') AS "mon_name",
	SUM(actual_amt) AS "bal_end_of_month"
FROM cte
GROUP BY customer_id,month,mon_name
ORDER BY customer_id;
-- 3. minimum, average and maximum values of the running balance for each customer
SELECT 
	MIN(cum_sum) AS "min_running_bal",
	ROUND(AVG(cum_sum),2) AS "avg_running_bal",
	MAX(cum_sum) AS "max_running_bal"
FROM temp_running_bal;



-- D. Extra Challenge
-- Data Bank wants to try another option which is a bit more difficult to implement 
-- - they want to calculate data growth using an interest calculation, just like in a traditional savings account you might have with a bank.
--annual interest rate 6%

WITH cte AS
(	SELECT 
		customer_id,
		txn_type,
		txn_amount,
		CASE
			WHEN txn_type='deposit' THEN txn_amount
			ELSE -txn_amount
		END AS "actual_amt",
		txn_date,
		EXTRACT(YEAR FROM txn_date) AS "year"
	FROM customer_transactions)
SELECT
	customer_id,
	year,
	SUM(actual_amt) AS "total_amt",
	SUM(actual_amt)*0.06*1 AS "interest"
FROM cte
GROUP BY customer_id,year
ORDER BY customer_id;