--case study 6
SET search_path = case_study_6;
SELECT * FROM users;
SELECT * FROM event_identifier;
SELECT * FROM events;
SELECT * FROM page_hierarchy;
SELECT * FROM campaign_identifier;



-- 1. Enterprise Relationship Diagram
-- Using the following DDL schema details to create an ERD for all the Clique Bait datasets.
--DONE




-- 2. Digital Analysis
-- Using the available datasets - answer the following questions using a single query for each one:
-- 1 How many users are there?
SELECT 
	COUNT(DISTINCT user_id)
FROM users;

-- 2 How many cookies does each user have on average?
WITH cte AS
(	SELECT 
		user_id,
		COUNT(cookie_id) AS "cnt"
	FROM users
	GROUP BY user_id)
SELECT 
	ROUND(AVG(cnt))
FROM cte;

-- 3 What is the unique number of visits by all users per month?
SELECT
	EXTRACT(MONTH FROM event_time) AS "months",
	TO_CHAR(event_time, 'Month') AS "month",
	COUNT(DISTINCT visit_id)
FROM events
GROUP BY months,month;

-- 4 What is the number of events for each event type?
SELECT
	event_name,
	COUNT(*)
FROM events
JOIN event_identifier
USING(event_type)
GROUP BY event_name;

-- 5 What is the percentage of visits which have a purchase event?
SELECT (COUNT(*)*100.00)/(SELECT COUNT(*) FROM events)
FROM events
WHERE event_type=3
LIMIT 100;

SELECT 
	ROUND((COUNT(DISTINCT visit_id)*100.00)/(SELECT COUNT(DISTINCT visit_id) FROM events),2) AS "purchase_%"
FROM events
WHERE event_type=3 AND page_id=13;

-- 6 What is the percentage of visits which view the checkout page but do not have a purchase event?
SELECT
	ROUND((COUNT(DISTINCT visit_id)*100.0) / (SELECT COUNT(DISTINCT visit_id) FROM events),2) AS "not_purchase_%"
FROM events
WHERE event_type<>3 AND page_id=12;

-- 7 What are the top 3 pages by number of views?
SELECT
	page_id,
	page_name,
	COUNT(*) AS "cnt"
FROM events
JOIN page_hierarchy
USING(page_id)
WHERE event_type=1
GROUP BY page_id,page_name
ORDER BY cnt DESC
LIMIT 3;

-- 8 What is the number of views and cart adds for each product category?
SELECT
	product_category,
	SUM(CASE
		  	WHEN event_name='Page View' THEN 1
		  	ELSE NULL
		  END) AS "view_count",
	SUM(CASE
		  	WHEN event_name='Add to Cart' THEN 1
		  	ELSE NULL
		  END) AS "cart_add_count"
FROM events
JOIN event_identifier
USING(event_type)
JOIN page_hierarchy
USING(page_id)
WHERE product_id IS NOT NULL
-- WHERE event_name='Page View' OR event_name='Add to Cart'
GROUP BY product_category;

-- 9 What are the top 3 products by purchases?
SELECT * FROM events;
SELECT * FROM event_identifier;
SELECT * FROM page_hierarchy;
SELECT * FROM campaign_identifier;

WITH cte AS
(	SELECT
		visit_id,
		page_id,
		page_name,
 
		eve.event_type
	FROM events eve
	JOIN event_identifier ei
	USING(event_type)
	JOIN page_hierarchy ph
	USING(page_id)
	WHERE event_name='Add to Cart' AND visit_id IN (SELECT visit_id FROM events WHERE event_type=3))
SELECT
 	page_name,
	COUNT(visit_id) AS "product_cnt"
FROM cte
GROUP BY page_name
ORDER BY product_cnt DESC
LIMIT 3;

SELECT
	*
FROM events
WHERE event_type=3;

-- 3. Product Funnel Analysis
-- Using a single SQL query - create a new output table which has the following details:
-- How many times was each product viewed?
-- How many times was each product added to cart?
-- How many times was each product added to a cart but not purchased (abandoned)?
-- How many times was each product purchased?
SELECT * FROM events;
SELECT * FROM event_identifier;
SELECT * FROM page_hierarchy;



DROP TABLE IF EXISTS prod_funnel;
CREATE TEMP TABLE prod_funnel
AS
WITH cte AS
(	SELECT
		visit_id,
		event_type,
		event_name,
		page_name,
		product_id,
 		product_category,
		FIRST_VALUE(event_name) OVER(PARTITION BY visit_id
									ORDER BY sequence_number DESC) AS "last_event"
	FROM
	events
	JOIN event_identifier
	USING(event_type)
	JOIN page_hierarchy
	USING(page_id))
SELECT
	product_id,
	page_name,
	SUM(CASE
		WHEN event_name='Page View' THEN 1
		ELSE NULL
	END) AS "viewed",
	SUM(CASE
		WHEN event_name='Add to Cart' THEN 1
		ELSE NULL
	END) AS "added_to_cart",
	SUM(CASE
		WHEN event_name='Add to Cart' AND last_event!='Purchase' THEN 1
		ELSE NULL
	END) AS "abandoned",
	SUM(CASE
		WHEN event_name='Add to Cart' AND last_event='Purchase' THEN 1
		ELSE NULL
	END) AS "purchased"
FROM cte
WHERE product_category IS NOT NULL
GROUP BY product_id,page_name
ORDER BY product_id,page_name;

SELECT * FROM prod_funnel;
-------------pr

SELECT
	page_name,
	SUM(CASE
		WHEN event_name='Page View' THEN 1
		ELSE NULL
	END) AS "viewed",
	SUM(CASE
		WHEN event_name='Add to Cart' THEN 1
		ELSE NULL
	END) AS "added_to_cart",
	SUM(CASE
		WHEN event_name='Add to Cart' AND page_id!=13 THEN 1
		ELSE NULL
	END) AS "abandoned",
	SUM(CASE
		WHEN event_type=2 AND page_id=13 THEN 1
		ELSE NULL
	END) AS "purchased"
FROM
events
JOIN event_identifier
USING(event_type)
JOIN page_hierarchy
USING(page_id)
-- WHERE product_id IS NOT NULL
GROUP BY page_name
LIMIT 100;


-- Additionally, create another table which further aggregates the data for the above points 
-- but this time for each product category instead of individual products.
DROP TABLE IF EXISTS cat_wise_funnel;

CREATE TEMP TABLE cat_wise_funnel
AS
WITH cte AS
(	SELECT
		visit_id,
		event_type,
		event_name,
		page_name,
		product_id,
 		product_category,
		FIRST_VALUE(event_name) OVER(PARTITION BY visit_id
									ORDER BY sequence_number DESC) AS "last_event"
	FROM
	events
	JOIN event_identifier
	USING(event_type)
	JOIN page_hierarchy
	USING(page_id))
SELECT
	product_category,
	SUM(CASE
		WHEN event_name='Page View' THEN 1
		ELSE NULL
	END) AS "viewed",
	SUM(CASE
		WHEN event_name='Add to Cart' THEN 1
		ELSE NULL
	END) AS "added_to_cart",
	SUM(CASE
		WHEN event_name='Add to Cart' AND last_event!='Purchase' THEN 1
		ELSE NULL
	END) AS "abandoned",
	SUM(CASE
		WHEN event_name='Add to Cart' AND last_event='Purchase' THEN 1
		ELSE NULL
	END) AS "purchased"
FROM cte
WHERE product_category IS NOT NULL
GROUP BY product_category
ORDER BY product_category;

SELECT * FROM cat_wise_funnel;

-- Use your 2 new output tables - answer the following questions:
-- 1 Which product had the most views, cart adds and purchases?
SELECT * FROM prod_funnel;
SELECT MAX(viewed) FROM prod_funnel;
-- most views and 
SELECT
	page_name AS "product_name",
	viewed
FROM prod_funnel
ORDER BY viewed DESC
LIMIT 1;
-- most cart adds 
SELECT
	page_name AS "product_name",
	added_to_cart
FROM prod_funnel
ORDER BY viewed DESC
LIMIT 1;
-- most purchases
SELECT
	page_name AS "product_name",
	purchased
FROM prod_funnel
ORDER BY purchased DESC
LIMIT 1;

-- 2 Which product was most likely to be abandoned?
SELECT
	page_name AS "product_name",
	abandoned
FROM prod_funnel
ORDER BY abandoned DESC
LIMIT 1;

-- 3 Which product had the highest view to purchase percentage?
SELECT
	page_name AS "product_name",
	viewed,
	purchased,
	ROUND((purchased*100.0)/viewed,2) AS "purchase_to_view"
FROM prod_funnel
ORDER BY purchase_to_view DESC
LIMIT 1;

-- 4 What is the average conversion rate from view to cart add?
WITH cte AS
(	SELECT
		ROUND((added_to_cart*100.0)/viewed,2) AS "view_to_cartadd"
	FROM prod_funnel)
SELECT
	ROUND(AVG(view_to_cartadd),2)||' %' AS "avg_view_to_cart"
FROM cte;

-- 5 What is the average conversion rate from cart add to purchase?
WITH cte AS
(	SELECT
		ROUND((purchased*100.0)/added_to_cart,2) AS "cart_to_purchase"
	FROM prod_funnel)
SELECT
	ROUND(AVG(cart_to_purchase),2)||' %' AS "avg_cart_to_purchase"
FROM cte;






-- 3(4). Campaigns Analysis
-- Generate a table that has 1 single row for every unique visit_id record and has the following columns:
--  - user_id
--  - visit_id
--  - visit_start_time: the earliest event_time for each visit
--  - page_views: count of page views for each visit
--  - cart_adds: count of product cart add events for each visit
--  - purchase: 1/0 flag if a purchase event exists for each visit
--  - campaign_name: map the visit to a campaign if the visit_start_time falls between the start_date and end_date
--  - impression: count of ad impressions for each visit
--  - click: count of ad clicks for each visit
--  - (Optional column) cart_products: a comma separated text value with products added to the cart sorted by the order they were added to the cart 
-- (hint: use the sequence_number)
SELECT * FROM events_identifier;

-- SELECT
-- 	user_id,
-- 	visit_id,
-- 	MIN(event_time),
-- 	COUNT(page_id),
-- 	SUM(CASE
-- 		WHEN event_type=2 THEN 1
-- 		ELSE 0
-- 	END) AS "cart_add"
-- -- 	CASE
-- -- 		WHEN event_type=3 THEN 1
-- -- 		ELSE 0
-- -- 	END AS "purchase_flag"
-- FROM users
-- JOIN events
-- USING(cookie_id)
-- GROUP BY user_id,visit_id
-- ORDER BY user_id,visit_id
-- LIMIT 100

DROP TABLE IF EXISTS campaign_table;

CREATE TEMP TABLE campaign_table
AS
WITH cte
AS(
	SELECT 
		visit_id,
		STRING_AGG(page_name, ', ') AS cart_prod
	FROM events e
	JOIN page_hierarchy p
	USING(page_id)
	WHERE p.page_id NOT IN  (1, 2, 12, 13)
	GROUP BY visit_id
	)
SELECT
	user_id,
	e.visit_id,
	MIN(event_time) visit_start_time,
	SUM(CASE
			WHEN event_type = 1 THEN 1
			ELSE 0
	END)view_count,
	SUM(CASE
			WHEN event_type = 2 THEN 1
			ELSE 0
	END) cart_count,
	SUM(CASE
			WHEN event_type = 3 THEN 1
			ELSE 0
	END) purchase,
	campaign_name,
	SUM(CASE
			WHEN event_type = 4 THEN 1
			ELSE 0
	END) impression,
	SUM(CASE
			WHEN event_type = 5 THEN 1
			ELSE 0
	END) click,
	cart_prod
FROM events e
JOIN cte c
USING(visit_id)
JOIN users u
USING(cookie_id)
JOIN campaign_identifier ci
ON event_time BETWEEN ci.start_date AND ci.end_date
GROUP BY user_id, e.visit_id, campaign_name, cart_prod
ORDER BY user_id;

SELECT * FROM campaign_table;

--1 Identifying users who have received impressions during each campaign period 
--  and comparing each metric with other users who did not have an impression event
CREATE TEMP TABLE imp_wise_events
AS
WITH cte AS
(	SELECT
		user_id,
 		visit_id,
		CASE impression
			WHEN 1 THEN 'imp_user'
			WHEN 0 THEN 'non_imp_user'
		END AS "imp_user"
	FROM campaign_table),
cte_1 AS
(	SELECT
		visit_id,
 		imp_user,
		event_type,
		event_name,
		page_name,
		product_id,
 		product_category,
		FIRST_VALUE(event_name) OVER(PARTITION BY visit_id
									ORDER BY sequence_number DESC) AS "last_event"
	FROM
	events
	JOIN event_identifier
	USING(event_type)
	JOIN page_hierarchy
	USING(page_id)
	JOIN cte
	USING(visit_id))
SELECT
	imp_user,
	SUM(CASE
		WHEN event_name='Page View' THEN 1
		ELSE NULL
	END) AS "viewed",
	SUM(CASE
		WHEN event_name='Add to Cart' THEN 1
		ELSE NULL
	END) AS "added_to_cart",
	SUM(CASE
		WHEN event_name='Add to Cart' AND last_event!='Purchase' THEN 1
		ELSE NULL
	END) AS "abandoned",
	SUM(CASE
		WHEN event_name='Add to Cart' AND last_event='Purchase' THEN 1
		ELSE NULL
	END) AS "purchased"
FROM cte_1
WHERE product_category IS NOT NULL
GROUP BY imp_user;

SELECT * FROM imp_wise_events;

--2 Does clicking on an impression lead to higher purchase rates?
SELECT
	imp_user,
	ROUND((purchased*100.0) / (SELECT SUM(purchased) FROM imp_wise_events),2)||' %' AS "purchase_rate"
FROM imp_wise_events;
-- This data clearly shows that clicking on impression leads to higher purchase rate



--3 What is the uplift in purchase rate when comparing users who click on a campaign impression versus users who do not receive an impression? 
--  What if we compare them with users who just an impression but do not click?
WITH cte AS
(	SELECT
		*,
		CASE
			WHEN impression=1 AND click=1 THEN 'imp_clicked'
			WHEN impression=1 AND click=0 THEN 'imp_not_click'
			WHEN impression=0 THEN 'imp_not_recieved'
		END AS "click_on_imp"
	FROM campaign_table)
SELECT
	click_on_imp,
	ROUND((SUM(purchase)*100.0)/(SELECT SUM(purchase) FROM campaign_table),2) AS "purchase_rate"
FROM cte
GROUP BY click_on_imp;

-- comparing users who click on a campaign impression versus users who do not receive an impression
-- WITH cte AS
-- (	SELECT
-- 		*,
-- 		CASE
-- 			WHEN impression=1 AND click=1 THEN 'imp_clicked'
-- 			WHEN impression=1 AND click=0 THEN 'imp_not_click'
-- 			WHEN impression=0 THEN 'imp_not_recieved'
-- 		END AS "click_on_imp"
-- 	FROM campaign_table)
-- SELECT
-- 	ROUND((SUM(purchase)*100.0)/(SELECT SUM(purchase) FROM cte),2) AS "purchase_rate"
-- FROM cte
-- WHERE click_on_imp='imp_clicked'
-- comparing users who click on a campaign impression versus users who just an impression but do not click


--4 What metrics can you use to quantify the success or failure of each campaign compared to eachother?
-- number of purcharse with respect to campaign
-- number of view count during campaign period
-- 
