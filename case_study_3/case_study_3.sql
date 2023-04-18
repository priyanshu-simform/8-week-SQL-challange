--case study 3
SET search_path = case_study_3;

  
SELECT * 
FROM subscriptions
LIMIT 100;

-- A. Customer Journey
--    Based off the 8 sample customers provided in the sample from the subscriptions table, 
--    write a brief description about each customer’s onboarding journey.
--    Try to keep it as short as possible - you may also want to run some sort of join to make your explanations a bit easier!
SELECT 
	customer_id,
	s.plan_id,
	plan_name,
	price,
	start_date
FROM subscriptions s
JOIN plans p
ON s.plan_id = p.plan_id
WHERE customer_id < 9;




-- B. Data Analysis Questions
-- 1 How many customers has Foodie-Fi ever had?
SELECT COUNT(DISTINCT customer_id) AS "total_customer"
FROM subscriptions;

-- 2 What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
SELECT EXTRACT(MONTH FROM start_date) AS "months",
	   COUNT(*) AS "total_trial_plans"
FROM subscriptions 
WHERE plan_id=1
GROUP BY months
ORDER BY months;

-- 3 What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
SELECT plan_id,
	   plan_name,
	   COUNT(*)
FROM subscriptions
JOIN plans
USING(plan_id)
WHERE EXTRACT(YEAR FROM start_date) > 2020
GROUP BY plan_id,plan_name
ORDER BY plan_id;

SELECT EXTRACT(YEAR FROM start_date) AS year,COUNT(start_date)
FROM subscriptions
GROUP BY year;

-- 4 What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
SELECT COUNT(*) AS "customer_count",
	   ROUND((COUNT(*)*100)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions),1)||' %' AS "percentage"
FROM subscriptions
WHERE plan_id = 4;

-- 5 How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
WITH cte AS
(	SELECT
		customer_id,
		plan_id,
		ROW_NUMBER() OVER(PARTITION BY customer_id
						  ORDER BY plan_id) AS "rnk"
	FROM subscriptions)
SELECT 
	COUNT(customer_id) AS "customer_count",
	ROUND((COUNT(customer_id)*100)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions))||' %' AS "percentage"
FROM cte
WHERE rnk=2 AND plan_id=4;

-- 6 What is the number and percentage of customer plans after their initial free trial?
SELECT * FROM plans;

WITH cte AS
(	SELECT
 		customer_id,
 		plan_id,
 		start_date,
 		ROW_NUMBER() OVER(PARTITION BY customer_id
						 	ORDER BY plan_id) AS "row"
 	FROM subscriptions)
SELECT
	plan_name,
	COUNT(customer_id) AS "total_customer",
	ROUND((COUNT(customer_id)*100)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions),2)||' %' AS "percentage"
FROM cte
JOIN plans
USING(plan_id)
WHERE row=2
GROUP BY plan_name;



--simple
WITH cte AS
(	SELECT
		customer_id,
		plan_id,
		ROW_NUMBER() OVER(PARTITION BY customer_id
					ORDER BY plan_id) AS "row",
 		LEAD(plan_id) OVER(PARTITION BY customer_id) AS "next"
	FROM subscriptions
	ORDER BY plan_id)
SELECT 
	'basic monthly' AS "plan_after_trial",
	COUNT(customer_id) AS "customer_count",
	ROUND((COUNT(customer_id)*100)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions))||' %' AS "percentage"
FROM cte
WHERE row=2 AND plan_id=1
UNION
SELECT 
	'pro monthly' AS plan_after_trial,
	COUNT(customer_id) AS "customer_count",
	ROUND((COUNT(customer_id)*100)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions))||' %' AS "percentage"
FROM cte
WHERE row=2 AND plan_id=2
UNION
SELECT 
	'pro annual' AS plan_after_trial,
	COUNT(customer_id) AS "customer_count",
	ROUND((COUNT(customer_id)*100)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions))||' %' AS "percentage"
FROM cte
WHERE row=2 AND plan_id=3
UNION
SELECT 
	'churn' AS plan_after_trial,
	COUNT(customer_id) AS "customer_count",
	ROUND((COUNT(customer_id)*100)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions))||' %' AS "percentage"
FROM cte
WHERE row=2 AND plan_id=4;




	
-- 7 What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
WITH cte AS
(	SELECT
		customer_id,
		plan_id,
		start_date,
		LEAD(start_date) OVER(PARTITION BY customer_id
							  ORDER BY plan_id) AS "next"
	FROM subscriptions)
SELECT 
	customer_id,
	plan_id,
	start_date,
	next
FROM cte
WHERE start_date<'2020-12-31' 
	AND next>'2020-12-31' OR (plan_id=4 AND next IS NULL)
		OR start_date+6>'2020-12-31' OR start_date+30>'2020-12-31'OR start_date+31>'2020-12-31'OR EXTRACT(YEAR FROM start_date)>2020 AND ;
SELECT * FROM plans;
SELECT
	customer_id,
	plan_id,
	start_date,
	CASE plan_id
		WHEN 0 THEN start_date+6
		WHEN 1 THEN start_date+30
		WHEN 2 THEN start_date+30
		WHEN 3 THEN start_date+365
	END AS "end_date"
FROM subscriptions
WHERE plan_id<4;

-- 8 How many customers have upgraded to an annual plan in 2020?
SELECT
	COUNT(DISTINCT customer_id) AS "total_customer"
FROM subscriptions
WHERE plan_id=3 AND EXTRACT(YEAR FROM start_date)=2020;

-- 9 How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
WITH cte AS
(	SELECT
		*,
		LAST_VALUE(start_date) OVER(PARTITION BY customer_id ORDER BY plan_id) -
		FIRST_VALUE(start_date) OVER(PARTITION BY customer_id ORDER BY plan_id) AS "difference"
	FROM subscriptions
	WHERE plan_id=0 OR plan_id=3)
SELECT ROUND(AVG(difference))
FROM cte
WHERE difference>0;



-- 10 Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH cte AS
(	SELECT
		*,
		LAST_VALUE(start_date) OVER(PARTITION BY customer_id ORDER BY plan_id) -
		FIRST_VALUE(start_date) OVER(PARTITION BY customer_id ORDER BY plan_id) AS "difference"
	FROM subscriptions
	WHERE plan_id=0 OR plan_id=3),
cte_1 AS
(	SELECT ROUND(AVG(difference)) AS "diff"
	FROM cte
	WHERE difference>0)
-- SELECT * FROM cte_1;
SELECT CAST((30 * FLOOR(diff / 30)) AS VARCHAR) || '-' || CAST((30 * (FLOOR(diff/ 30) + 1)) AS VARCHAR) day_range,
	count(*) AS no_of_times 
FROM cte_1
GROUP BY 30 * FLOOR(diff/ 30), 30 * (FLOOR(diff / 30) + 1)
ORDER BY MIN(diff);
;


WITH trial_plan AS(
	SELECT customer_id, start_date AS trial_date 
	FROM subscriptions 
	WHERE plan_id = 0),
annual_plan AS(
	SELECT customer_id, start_date AS annual_date 
	FROM subscriptions 
	WHERE plan_id = 3),
diff AS (
	SELECT ROUND((annual_date-trial_date),0) AS datediff 
	FROM trial_plan tp 
	JOIN annual_plan an ON tp.customer_id=an.customer_id)
SELECT CAST((30 * FLOOR(datediff / 30)) AS VARCHAR) || '-' || CAST((30 * (FLOOR(datediff/ 30) + 1)) AS VARCHAR) day_range,
	count(*) AS no_of_times 
FROM diff 
GROUP BY 30 * FLOOR(datediff/ 30), 30 * (FLOOR(datediff / 30) + 1)
ORDER BY MIN(datediff);

-- 11 How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
WITH cte AS
(	SELECT
		customer_id,
		plan_id,
		start_date,
		LEAD(plan_id) OVER(PARTITION BY customer_id
							ORDER BY start_date) AS "next"
	FROM subscriptions
	WHERE EXTRACT(YEAR FROM start_date)=2020)
SELECT COUNT(customer_id)
FROM cte
WHERE plan_id=2 AND next=1;







-- C. Challenge Payment Question
-- The Foodie-Fi team wants you to create a new payments table for the year 2020 
-- that includes amounts paid by each customer in the subscriptions table with the following requirements:
--    - monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
--    - upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
--    - upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
--    - once a customer churns they will no longer make payments
DROP TABLE IF EXISTS payment;

CREATE TABLE payment
AS
WITH cte AS
(	SELECT
		customer_id,
		plan_id,
 		plan_name,
 		price,
		LEAD(plan_id) OVER(PARTITION BY customer_id
							ORDER BY start_date) AS "next_plan",
		start_date,
		LEAD(start_date) OVER(PARTITION BY customer_id) AS "next_date",
 		LEAD(price) OVER(PARTITION BY customer_id) AS "next_price",
 		CASE
 			WHEN plan_id IN (1,2) THEN '1 Month'
 			WHEN plan_id = 3 THEN '1 year'
 			ELSE NULL
		END AS "interval"
	FROM subscriptions
 	JOIN plans
 	USING(plan_id)
	WHERE plan_id>0),
cte_1 AS
(	SELECT
		customer_id,
 		plan_id,
 		plan_name,
 		price AS "amount",
 		next_price,
		GENERATE_SERIES(start_date,LEAST(next_date,'2020-12-31'::DATE),interval::INTERVAL)::DATE AS "payment_date"
	FROM cte)
-- SELECT * FROM cte_1
SELECT
	customer_id,
	plan_id,
	plan_name,
	payment_date,
-- 	amount,
	CASE
		WHEN LAG(payment_date) OVER(PARTITION BY customer_id ORDER BY payment_date) + '1 Month'::interval>payment_date
			THEN amount-LAG(amount) OVER(PARTITION BY customer_id ORDER BY payment_date)
		ELSE amount
	END AS "new_amount",
	ROW_NUMBER() OVER(PARTITION BY customer_id) AS "payment_order"
FROM cte_1;

SELECT * FROM plans;
SELECT * FROM subscriptions;
SELECT * FROM payment;

SELECT 
	customer_id,
	plan_id,
	plan_name,
	start_date,
	LEAD(plan_id) OVER(PARTITION BY customer_id
					  	ORDER BY start_date) AS "next_plan"
-- 	amount
FROM plans
JOIN subscriptions
USING(plan_id)
WHERE plan_id >0;

SELECT *
FROM subscriptions
WHERE plan_id=4;




CREATE TEMP TABLE temp_sub
AS
SELECT * FROM subscriptions LIMIT 50;

SELECT * FROM temp_sub;


WITH RECURSIVE cte AS
(	SELECT * 
 	FROM temp_sub
 	WHERE plan_id!=4
 	UNION
 	SELECT *
 	FROM cte
 	WHERE plan_id=4
)
SELECT * FROM cte;


WITH cte AS
(	SELECT *,
		LEAD(plan_id) OVER(PARTITION BY customer_id
							ORDER BY plan_id) AS "next_plan",
		LEAD(start_date) OVER(PARTITION BY customer_id
							ORDER BY plan_id) AS "next_date"
	FROM temp_sub
	ORDER BY customer_id)
;
SELECT COUNT(*)
FROM subscriptions
WHERE plan_id=4;







WITH RECURSIVE cte AS
(	SELECT 1 AS n,
 		   1 AS n1,
 		   1 AS cnt
	UNION
	SELECT n1,n+n1,cnt+1
	FROM cte
	WHERE cnt<45)
SELECT * FROM cte;

SELECT 901408733+1134903170;
SELECT 2147483647;



-- D. Outside The Box Questions
-- 1 How would you calculate the rate of growth for Foodie-Fi?
WITH cte AS
(	SELECT
		EXTRACT(MONTH FROM start_date) AS "month_no",
		TO_CHAR(start_date,'Month') AS "month",
		COUNT(customer_id) AS "customers"
	FROM subscriptions
 	WHERE EXTRACT(YEAR FROM start_date)=2020
	GROUP BY month_no,month
	ORDER BY month_no),
cte_1 AS
(	SELECT
 		*,
 		LAG(customers) OVER() AS "next",
 		customers - LAG(customers) OVER() AS "growth"
 	FROM cte)
SELECT *,
	CASE
		WHEN growth >= 30 THEN '↑↑'
		WHEN growth <= -30 THEN '↓↓'
		WHEN growth > 0 THEN '↑'
		WHEN growth < 0 THEN '↓'
		ELSE '-'
	END AS "(+/-)"
FROM cte_1;


-- 2 What key metrics would you recommend Foodie-Fi management to track over time to assess performance of their overall business?
--   firstly Foodie-Fi management should keep track the performance of customer cancellation through out the year in monthly basis
WITH cte AS ( 
	SELECT 
		s.customer_id, 
		p.plan_id, 
		p.plan_name, 
		start_date, 
		LEAD(p.plan_id) OVER( PARTITION BY customer_id 
							  ORDER BY p.plan_id) "next" 
	FROM subscriptions s 
	JOIN plans p 
	ON p.plan_id = s.plan_id)
SELECT EXTRACT(MONTH FROM start_date) AS "Month", 
	   COUNT(*) New_customers 
FROM cte 
WHERE plan_id = 0 AND next != 4 AND next IS NOT NULL 
	AND EXTRACT(YEAR FROM start_date) = 2020
GROUP BY EXTRACT(MONTH FROM start_date)
ORDER BY EXTRACT(MONTH FROM start_date);


WITH cte AS ( 
	SELECT 
		s.customer_id, 
		p.plan_id, 
		p.plan_name, 
		start_date, 
		LEAD(p.plan_id) OVER( PARTITION BY customer_id 
							 	ORDER BY p.plan_id) "next" 
	FROM subscriptions s 
	JOIN plans p ON p.plan_id = s.plan_id)
SELECT 
	EXTRACT(MONTH FROM start_date) AS "Month", 
	COUNT(*) New_customers 
FROM cte 
WHERE next = 4 AND next IS NOT NULL 
	AND EXTRACT(YEAR FROM start_date) = 2020
GROUP BY EXTRACT(MONTH FROM start_date)
ORDER BY EXTRACT(MONTH FROM start_date);

--3 What are some key customer journeys or experiences that you would analyse further to improve customer retention?
--firstly we should analyze the count of customer cancellation plan wise
WITH cte AS ( 
	SELECT s.customer_id, 
	p.plan_id, 
	p.plan_name, 
	start_date, 
	LEAD(p.plan_id) OVER( PARTITION BY customer_id 
						 ORDER BY p.plan_id) "next" 
	FROM subscriptions s 
	JOIN plans p 
	USING(plan_id))
SELECT plan_id, 
	   COUNT(*) churn_counts 
FROM cte WHERE next = 4
GROUP BY plan_id;



--4 If the Foodie-Fi team were to create an exit survey shown to customers who wish to cancel their subscription, 
-- what questions would you include in the survey?

-- Ans:
-- Why you have cancel our sservice, Is there any perticular raeasin?
-- What suggestions you like to add to our plan scheme?
-- Are the price rates fair as your point of view?
-- Which plans you prefered the most?
-- How did you know about our services?


--5 What business levers could the Foodie-Fi team use to reduce the customer churn rate? 
-- How would you validate the effectiveness of your ideas?

--Ans:
--Bussiness levers: 
-- 	sell price (sell high)
-- 	ourchase cost (buy low)
-- 	sales performance (sell more)
-- 	cost to serve (manage your expenses)
-- Here,
-- analyze the churn occurence
-- Engage with customer through email, websites,cha,clog,social meadia
-- Check for customer comaplaints
-- Ask for feedback
-- take risk assessments in periodic manner
-- give better services to each customers
-- we can adjust our pricing scheme according to market
--Then we can validate the company's growth in results