--case study 7
SET search_path = case_study_7;


SELECT * FROM product_details;
SELECT * FROM product_hierarchy;
SELECT * FROM product_prices;
SELECT * FROM sales LIMIT 100;

-- 1. High Level Sales Analysis
-- 1 What was the total quantity sold for all products?
SELECT
	prod_id,
	product_name,
	SUM(qty) AS "total_qty"
FROM sales s
JOIN product_details pd
ON s.prod_id = pd.product_id
GROUP BY prod_id,product_name
ORDER BY prod_id,product_name;

--answer
SELECT
	SUM(qty) AS "total_sale_qty"
FROM sales;

-- 2 What is the total generated revenue for all products before discounts?
SELECT 
	SUM(qty*price) AS "total_revenue"
FROM sales;

-- 3 What was the total discount amount for all products?
SELECT
	SUM(price*qty*discount*0.01) AS "total_discount"
FROM sales;



-- 2. Transaction Analysis
-- 1 How many unique transactions were there?
SELECT
	COUNT(DISTINCT txn_id) AS "unique_txn"
FROM sales;

-- 2 What is the average unique products purchased in each transaction?
WITH cte AS
(	SELECT
		txn_id,
		COUNT(DISTINCT prod_id) AS "cnt"
	FROM sales
	GROUP BY txn_id)
SELECT
	ROUND(AVG(cnt))
FROM cte;

-- 3 What are the 25th, 50th and 75th percentile values for the revenue per transaction?
WITH cte AS
(	SELECT
		txn_id,
		SUM((qty*price)-(price*qty*discount*0.01)) AS "sale"
 	FROM sales
 	GROUP BY txn_id)
SELECT
	PERCENTILE_DISC(0.25) WITHIN GROUP (ORDER BY sale) AS "25th_percent",
	PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY sale) AS "50th_percent",
	PERCENTILE_DISC(0.75) WITHIN GROUP (ORDER BY sale) AS "75th_percent"
from cte;

-- 4 What is the average discount value per transaction?
WITH cte AS
(	SELECT
		txn_id,
		SUM(price*qty*discount*0.01) AS "dis_per_txn"
	FROM sales
	GROUP BY txn_id)
SELECT
	ROUND(AVG(dis_per_txn),2)
FROM cte;

-- 5 What is the percentage split of all transactions for members vs non-members?
SELECT 
	CASE
		WHEN member THEN 'member'
		ELSE 'non_member'
	END AS "membership",
	ROUND((COUNT(*)*100.0) / (SELECT COUNT(*) FROM sales),2)||' %' AS "percent_split"
FROM sales
GROUP BY member;

-- 6 What is the average revenue for member transactions and non-member transactions?
WITH cte AS
(	SELECT
 		CASE
 			WHEN member THEN 'member'
 			ELSE 'non-member'
 		END AS "membership",
  		txn_id,
 		SUM(price*qty - (price*qty*discount*0.01)) AS "rev"
 	FROM sales
 	GROUP BY member,txn_id)
SELECT
	membership,
	ROUND(AVG(rev),2) AS "avg_rev_member"
FROM cte
GROUP BY membership;



-- 3.Product Analysis
-- 1 What are the top 3 products by total revenue before discount?
SELECT
	prod_id,
	product_name,
	SUM(s.price*qty) AS "rev"
FROM sales s
JOIN product_details pd
ON s.prod_id = pd.product_id
GROUP BY prod_id,product_name
ORDER BY rev DESC
LIMIT 3;

-- 2 What is the total quantity, revenue and discount for each segment?
SELECT 
	segment_name,
	SUM(qty) AS "quantity",
	SUM(s.price*qty-(s.price*qty*discount*0.01)) AS "revenue",
	SUM(s.price*qty*discount*0.01) AS "discount"
FROM sales s
JOIN product_details pd
ON s.prod_id = pd.product_id
GROUP BY segment_name;

-- 3 What is the top selling product for each segment?
WITH cte AS
(	SELECT
		segment_name,
		product_name,
		SUM(qty) AS "sold_quant"
	FROM product_details pd
	JOIN sales s
	ON pd.product_id = s.prod_id
	GROUP BY segment_name,product_name)
SELECT
	DISTINCT ON(segment_name)
	segment_name,
	sold_quant,
	FIRST_VALUE(product_name) OVER(PARTITION BY segment_name
								  ORDER BY sold_quant DESC) AS "top_selling"
FROM cte;

-- 4 What is the total quantity, revenue and discount for each category?
SELECT
	category_name,
	SUM(qty) AS "total_quantity",
	SUM((s.price*qty)-(s.price*qty*discount*0.01)) AS "total_revenue",
	SUM(s.price*qty*discount*0.01) AS "total_discount"
FROM product_details pd
JOIN sales s
ON pd.product_id=s.prod_id
GROUP BY category_name;

-- 5 What is the top selling product for each category?
WITH cte AS
(	SELECT
		category_name,
		product_name,
		SUM(qty) AS "sold_quant"
	FROM product_details pd
	JOIN sales s
	ON pd.product_id = s.prod_id
	GROUP BY category_name,product_name)
SELECT
	DISTINCT ON(category_name)
	category_name,
	sold_quant,
	FIRST_VALUE(product_name) OVER(PARTITION BY category_name
								  ORDER BY sold_quant DESC) AS "top_selling"
FROM cte;

-- 6 What is the percentage split of revenue by product for each segment?
--next solution is better
SELECT
	segment_name,
	product_name,
	ROUND(SUM((s1.price*qty)-(s1.price*qty*discount*0.01))*100.0
		  /(SELECT SUM((s2.price*qty)-(s2.price*qty*discount*0.01)) 
			FROM sales s2 
			JOIN product_details pd2 
			ON s2.prod_id=pd2.product_id 
			WHERE pd.segment_name=pd2.segment_name ),2)||' %' AS "revenue_split"
FROM sales s1
JOIN product_details pd
ON s1.prod_id = pd.product_id
GROUP BY segment_name,product_name
ORDER BY segment_name;


--right solutions
WITH cte AS
(	SELECT
		segment_name,
		product_name,
		SUM((s.price*qty)-(s.price*qty*discount*0.01)) AS "revenue"
	FROM sales s
	JOIN product_details pd
	ON s.prod_id=pd.product_id
	GROUP BY segment_name,product_name)
SELECT
	segment_name,
	product_name,
	ROUND((revenue*100.0)/(SELECT SUM(revenue) 
						   FROM cte c1 
						   WHERE c1.segment_name=cte.segment_name),2) AS "revenue_split"
FROM cte
ORDER BY segment_name;


SELECT * FROM sales;

-- 7 What is the percentage split of revenue by segment for each category?
WITH cte AS
(	SELECT
 		category_name,
 		product_name,
 		SUM((s.price*qty) - (s.price*qty*discount*0.01)) AS "revenue"
 	FROM sales s
 	JOIN product_details pd
 	ON s.prod_id=pd.product_id
 	GROUP BY category_name,product_name)
SELECT
	category_name,
	product_name,
	(revenue*100.0) / (SELECT SUM(revenue) FROM cte)
FROM cte;
-- 8 What is the percentage split of total revenue by category?
SELECT
	category_name,
	ROUND(SUM((s.price*qty)-(s.price*qty*discount*0.01))*100/(SELECT SUM((price*qty)-(price*qty*discount*0.01)) FROM sales),2) AS "revenue_split"
FROM sales s
JOIN product_details pd
ON s.prod_id = pd.product_id
GROUP BY category_name;


-- 9 What is the total transaction “penetration” for each product? 
--   (hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)
SELECT 
	ROUND(COUNT(DISTINCT txn_id)*1.0 / COUNT(txn_id),2) AS "penetration"
FROM sales;

-- 10 What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?
WITH cte AS
(	SELECT
		pd1.product_name,
		txn_id
	FROM sales s
	JOIN product_details pd1
	ON s.prod_id=pd1.product_id),
cte_1 AS
(	SELECT
		c1.product_name AS "product_1",
		c2.product_name AS "product_2",
		c3.product_name AS "product_3",
		COUNT(*) as "buying_freq",
		DENSE_RANK() OVER(ORDER BY COUNT(*) DESC) AS "comb_rank"
	FROM cte c1
	JOIN cte c2
	ON c1.txn_id=c2.txn_id AND c1.product_name!=c2.product_name -- prevent pairing of same products in a txn
		AND c1.product_name<c2.product_name -- prevent duplicate pairing (not combination and not permuataion) because A,B == B,A
	JOIN cte c3
	ON c1.txn_id=c3.txn_id AND c1.product_name!=c3.product_name  AND c2.product_name!=c3.product_name 
		AND c1.product_name<c3.product_name AND c2.product_name<c3.product_name
	GROUP BY c1.product_name,c2.product_name,c3.product_name)
SELECT
	product_1,
	product_2,
	product_3,
	buying_freq
FROM cte_1
WHERE comb_rank=1;






-- 4.Reporting Challenge
-- Write a single SQL script that combines all of the previous questions into a scheduled report 
-- that the Balanced Tree team can run at the beginning of each month to calculate the previous month’s values.

-- Imagine that the Chief Financial Officer (which is also Danny) has asked for all of these questions at the end of every month.
-- He first wants you to generate the data for January only - but then he also wants you to demonstrate 
-- that you can easily run the samne analysis for February without many changes (if at all).
-- Feel free to split up your final outputs into as many tables as you need 
-- - but be sure to explicitly reference which table outputs relate to which question for full marks :)
DROP PROCEDURE IF EXISTS schedule_report;
CREATE OR REPLACE PROCEDURE schedule_report(str)
LANGUAGE plpgsql
AS
$$
BEGIN
	-- High Level Sales Analysis
	CALL high_sales_analysis();
	-- 	Transaction Analysis
	CALL transaction_analysis();
	-- 	Product Analysis
	CALL product_analysis();
END
$$;

CALL schedule_report(high sales);


CREATE OR REPLACE PROCEDURE high_sales_analysis()
LANGUAGE plpgsql
AS
$$
BEGIN
-- 	RAISE NOTICE 'High Level Sales Analysis';
	-- 1 What was the total quantity sold for all products?
	SELECT
		SUM(qty) AS "total_sale_qty"
	FROM sales;

	-- 2 What is the total generated revenue for all products before discounts?
	SELECT 
		SUM(qty*price) AS "total_revenue"
	FROM sales;

	-- 3 What was the total discount amount for all products?
	SELECT
		SUM(price*qty*discount*0.01) AS "total_discount"
	FROM sales;
END
$$;

CREATE OR REPLACE PROCEDURE transaction_analysis()
LANGUAGE plpgsql
AS
$$
BEGIN
	RAISE NOTICE 'Transaction Analysis';
END
$$;

CREATE OR REPLACE PROCEDURE product_analysis()
LANGUAGE plpgsql
AS
$$
BEGIN
	RAISE NOTICE 'Product Analysis';
END
$$;





-- Bonus Challenge
-- Use a single SQL query to transform the product_hierarchy and product_prices datasets to the product_details table.
-- Hint: you may want to consider using a recursive CTE to solve this problem!
SELECT
	product_id,
	price,
	CONCAT(a.level_text, ' ', b.level_text, ' - ', c.level_text) product_name,
	c.id category_id,
	b.id segment_id,
	a.id style_id,
	c.level_text category_name,
	b.level_text segment_name,
	a.level_text style_name
FROM
	product_hierarchy a
	JOIN product_hierarchy b 
	ON a.parent_id = b.id
	JOIN product_hierarchy c 
	ON b.parent_id = c.id
	JOIN product_prices x 
	ON a.id = x.id