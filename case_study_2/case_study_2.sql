--Case study 2
SET search_path = case_study_2;


SELECT * FROM runners;
--unnest the toppings and created a new table
SELECT * FROM pizza_recipes;

DROP TABLE IF EXISTS new_pizza_recipes;
CREATE TABLE new_pizza_recipes
AS
SELECT pizza_id,UNNEST(string_to_array(toppings,','))::int AS "topping_id" FROM pizza_recipes;
SELECT * FROM new_pizza_recipes;



-- A. Pizza Metrics
-- 1.How many pizzas were ordered?
SELECT COUNT(order_id) AS total_pizza_ordered
FROM customer_orders;

-- 2.How many unique customer orders were made?
SELECT COUNT(DISTINCT customer_id) AS unique_customer,
	   COUNT(DISTINCT pizza_id) AS unique_orders
FROM customer_orders;

-- 3.How many successful orders were delivered by each runner?
SELECT runner_id,COUNT(duration)
FROM runner_orders
WHERE cancellation IS NULL
GROUP BY runner_id;

-- 4.How many of each type of pizza was delivered?
SELECT pizza_name,
	   COUNT(order_id)
FROM customer_orders
JOIN pizza_names
USING(pizza_id)
JOIN runner_orders
USING(order_id)
WHERE cancellation IS NULL
GROUP BY pizza_name;

-- 5.How many Vegetarian and Meatlovers were ordered by each customer?
SELECT customer_id,
	   pizza_name,
	   COUNT(order_id)
FROM customer_orders
JOIN pizza_names
USING(pizza_id)
GROUP BY customer_id,pizza_id,pizza_name
ORDER BY customer_id;

	   
-- 6.What was the maximum number of pizzas delivered in a single order?
SELECT order_id,
	   COUNT(pizza_id) AS cnt
FROM customer_orders
JOIN runner_orders
USING(order_id)
WHERE cancellation IS NULL
GROUP BY order_id
ORDER BY cnt DESC
LIMIT 1;

-- 7.For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT COUNT(CASE 
			WHEN exclusions IS NOT NULL THEN 1
			ELSE NULL
	   END) AS "pizza_with change",
	   COUNT(CASE
	   		WHEN exclusions IS NULL THEN 1
			ELSE NULL
	   END )AS "pizza_with_no_change"
FROM customer_orders
JOIN runner_orders
USING(order_id)
WHERE cancellation IS NULL;

-- 8.How many pizzas were delivered that had both exclusions and extras?
SELECT COUNT(pizza_id) AS "both exclusion and extra"
FROM customer_orders
JOIN runner_orders
USING(order_id)
WHERE exclusions IS NOT NULL 
	  AND extras IS NOT NULL
	  AND cancellation IS NULL;

-- 9.What was the total volume of pizzas ordered for each hour of the day?
SELECT EXTRACT(HOUR FROM order_time) AS "hours",
	   COUNT(pizza_id) AS "pizzas per hour"
FROM customer_orders
GROUP BY hours
ORDER BY hours;

-- 10.What was the volume of orders for each day of the week?
SELECT to_char(order_time,'day') AS "day",
	   COUNT(pizza_id) AS "pizzas per week day"
FROM customer_orders
GROUP BY day
ORDER BY day;



-- B. Runner and Customer Experience
-- 1.How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT EXTRACT(WEEK FROM registration_date) AS "week",
	   COUNT(runner_id) AS "runners_per_week"
FROM runners
GROUP BY week
ORDER BY week;

-- 2.What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
SELECT runner_id,
	   ROUND(AVG(EXTRACT(EPOCH FROM(pickup_time - order_time))/60))||' minutes' AS "difference"
FROM customer_orders
JOIN runner_orders
USING(order_id)
GROUP BY runner_id
ORDER BY runner_id;

-- 3.Is there any relationship between the number of pizzas and how long the order takes to prepare?
WITH cte AS
(	SELECT order_id,
		   pickup_time-order_time AS "preparation_time",
		   COUNT(pizza_id) OVER(PARTITION BY order_id) AS "pizza_count"
	FROM customer_orders
	JOIN runner_orders
	USING(order_id)
	WHERE cancellation IS NULL)
SELECT pizza_count,
	   AVG(preparation_time) AS "average_preparation_time"
FROM cte
GROUP BY pizza_count
ORDER BY pizza_count;

-- 4.What was the average distance travelled for each customer?
SELECT customer_id,
	   ROUND(AVG(distance),2)
FROM customer_orders
JOIN runner_orders
USING(order_id)
WHERE cancellation IS NULL
GROUP BY customer_id
ORDER BY customer_id;

-- 5.What was the difference between the longest and shortest delivery times for all orders?
SELECT MAX(duration)-MIN(duration)||' minutes' AS "difference"
FROM runner_orders;

-- 6.What was the average speed for each runner for each delivery and do you notice any trend for these values?
WITH cte AS
(	SELECT order_id,
		   runner_id,
		   (distance/(duration::numeric/60)) AS "speed(kn/h)"
	FROM runner_orders
	WHERE cancellation IS NULL)
SELECT order_id,
	   runner_id,
	   AVG(speed) OVER(PARTITION BY runner_id)
FROM cte;

-- 7.What is the successful delivery percentage for each runner?
SELECT runner_id,
	   (COUNT(duration)*100)/COUNT(order_id)||' %' AS successfull_deleivery
FROM runner_orders
GROUP BY runner_id
ORDER BY runner_id;



-- C. Ingredient Optimisation
-- 1.What are the standard ingredients for each pizza?
SELECT * FROM new_pizza_recipes;
SELECT pizza_name,STRING_AGG(topping_name,', ')
FROM pizza_names
JOIN new_pizza_recipes
USING(pizza_id)
JOIN pizza_toppings
USING(topping_id)
GROUP BY pizza_name;

-- 2.What was the most commonly added extra?
WITH cte AS
(
	SELECT UNNEST(extras) AS "extra",
		   COUNT(order_id) AS "cnt"
	FROM customer_orders
	GROUP BY extra
	ORDER BY cnt DESC LIMIT 1
)
SELECT topping_name
FROM pizza_toppings
WHERE topping_id = (SELECT extra FROM cte);

-- 3.What was the most common exclusion?
 WITH cte AS
(
	SELECT UNNEST(exclusions) AS "exclusion",
		   COUNT(order_id) AS "cnt"
	FROM customer_orders
	GROUP BY exclusion
	ORDER BY cnt DESC LIMIT 1
)
SELECT topping_name
FROM pizza_toppings
WHERE topping_id = (SELECT exclusion FROM cte);

-- 4.Generate an order item for each record in the customers_orders table in the format of one of the following:
--   Meat Lovers
--   Meat Lovers - Exclude Beef
--   Meat Lovers - Extra Bacon
--   Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
DROP TABLE IF EXISTS temp_customer_orders;
CREATE TABLE temp_customer_orders
AS
SELECT ROW_NUMBER() OVER(ORDER BY order_id) AS "row",*
FROM customer_orders;

SELECT * FROM temp_customer_orders;

WITH cte AS
(	SELECT order_id,
		   pizza_id,
 		   row,
		   UNNEST(extras) AS "extra",
		   UNNEST(exclusions) AS "exclusion"
	FROM temp_customer_orders co
	UNION
	SELECT order_id,
		   pizza_id,
 		   row,
		   NULL,
 		   NULL
 	FROM temp_customer_orders
 	WHERE extras IS NULL AND exclusions IS NULL
),
cte_1 AS
(	SELECT order_id,
		   pizza_id,
		   STRING_AGG(pt1.topping_name,', ') AS "extra_topping",
		   STRING_AGG(pt2.topping_name,', ') AS "exclude_topping"
	FROM cte
	LEFT JOIN pizza_toppings pt1
	ON cte.extra = pt1.topping_id
	LEFT JOIN pizza_toppings pt2
	ON cte.exclusion = pt2.topping_id
	GROUP BY row,order_id,pizza_id)
SELECT order_id,
	   pizza_name,
	   CASE
	   		WHEN exclude_topping IS NOT NULL AND extra_topping IS NOT NULL
				THEN pizza_name||' - Exclude '||exclude_topping ||' - Extra '||extra_topping
			WHEN exclude_topping IS NOT NULL AND extra_topping IS NULL
				THEN pizza_name||' - Exclude '||exclude_topping
			WHEN exclude_topping IS NULL AND extra_topping IS NOT NULL
				THEN pizza_name||' - Extra '||extra_topping
			ELSE
				pizza_name
	   END AS "orders"
FROM cte_1
JOIN pizza_names
USING(pizza_id);



-- 5.Generate an alphabetically ordered comma separated ingredient list 
-- for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
-- For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

WITH cte AS
(	SELECT row,
		   order_id,
		   pizza_id,
		   UNNEST(extras) AS "extra",
		   UNNEST(exclusions) AS "exclusion",
		   STRING_TO_ARRAY(toppings,', ')::INT[] AS "toppings"	   
	FROM temp_customer_orders
	JOIN pizza_recipes
	USING(pizza_id)
 	UNION
 	SELECT row,
 		   order_id,
 		   pizza_id,
 		   NULL,NULL,
 		   STRING_TO_ARRAY(toppings,', ')::INT[] AS "toppings"
 	FROM temp_customer_orders
	JOIN pizza_recipes
	USING(pizza_id)
),
cte_1 AS
(	SELECT *,
		   ARRAY_REMOVE(toppings,exclusion)
	FROM cte),
cte_2 AS
(	SELECT *,
		   CASE 
				WHEN extra IS NOT NULL 
					THEN ARRAY_APPEND(toppings,extra)
				ELSE toppings
			END AS "final_list"
	FROM cte_1),
cte_3 AS
(	SELECT row,
		   order_id,
		   pizza_id,
		   extra,
		   exclusion,
		   UNNEST(final_list) AS "tp"
	FROM cte_2),
cte_4 AS
(	SELECT row,
			   order_id,
			   pizza_id,
			   extra,
			   exclusion,
			   tp,
			   topping_name
	FROM cte_3
	JOIN pizza_toppings pt
	ON pt.topping_id=cte_3.tp)
SELECT row,
	   order_id,
	   pizza_id,
	   STRING_AGG(topping_name,', ')
FROM cte_4
GROUP BY row,order_id,pizza_id;




CREATE TABLE pizza_topping_map
AS
WITH cte AS
(	SELECT 
		pizza_id,
		UNNEST(STRING_TO_ARRAY(toppings,', ')::INT[]) AS "topping_id"
	FROM pizza_recipes pr)
SELECT 
	pizza_id,
	pt.topping_id,
	topping_name
FROM cte
JOIN pizza_toppings pt
ON cte.topping_id = pt.topping_id
ORDER BY pizza_id;

SELECT * FROM pizza_topping_map;
WITH cte AS
(	SELECT
		row,
		order_id,
		pizza_id,
		UNNEST(exclusions) AS "extra",
		UNNEST(extras) AS "exclusion"
	FROM temp_customer_orders
	UNION
	SELECT
		row,
		order_id,
		pizza_id,
		NULL,NULL
	FROM temp_customer_orders),
cte_1 AS
(	SELECT
		row,
		order_id,
		pizza_id,
		extra,
		exclusion,
		topping_id,
		topping_name
	FROM cte
	JOIN pizza_topping_map
	USING(pizza_id)
	ORDER BY row)
SELECT
	row,
	order_id,
	pizza_id,
	STRING_AGG(topping_name,', ')
FROM cte_1
GROUP BY row,order_id,pizza_id
;





WITH cte AS (
	SELECT id, 
	order_id, 
	a.pizza_id, 
	pizza_name, 
	topping_id, 
	topping_name, 
	count(*), 
	CASE 
		WHEN count(*) = 1 
			THEN topping_name 
		ELSE concat(count(*)::VARCHAR, 'x ', topping_name) 
	END AS "ingredients" 
FROM (SELECT * 
	  FROM (SELECT 
				row, 
				order_id, 
				coc.pizza_id, 
				UNNEST(toppings) as toppings 
			FROM temp_customer_orders coc 
			JOIN pizza_names pn 
			on pn.pizza_id =coc.pizza_id 
			JOIN pizza_recipes pr 
			ON pr.pizza_id =pn.pizza_id 
			
			EXCEPT 
			
			SELECT 
				row, 
				order_id, 
				pizza_id, 
				UNNEST(exclusions) as exclusions 
			FROM temp_customer_orders coc) k 
	  		
	  		UNION ALL 
	  		SELECT 
	  			row, 
	  			order_id, 
	  			pizza_id, 
	  			UNNEST(extras) as extras 
	  		FROM customer_orders coc) a 
			JOIN pizza_toppings pt 
			on pt.topping_id = a.toppings :: numeric 
			JOIN pizza_names pn 
			on pn.pizza_id =a.pizza_id 
			group by row, order_id, a.pizza_id, pizza_name, topping_id, topping_name 
			ORDER BY row, order_id, a.pizza_id, topping_id, topping_name) 
select 
	id,
	concat(pizza_name, ': ', STRING_AGG(ingredients,', ')) as string 
from cte 
GROUP BY row, pizza_name 
ORDER BY row;












-- 6.What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
WITH cte AS
(	SELECT order_id,
		   pizza_id,
		   extras,
		   exclusions,
		   STRING_TO_ARRAY(toppings,', ')::INT[] AS "toppings"
	FROM customer_orders
	JOIN pizza_recipes
	USING(pizza_id)),
WI
(	SELECT *,
		   ARRAY_CAT(toppings,extras),
		   (select array(select unnest(toppings) except select unnest(exclusions)))
	-- 	   ARRAY_SUBTRACT(toppings,exclusions)
	FROM cte)
;











-- D. Pricing and Ratings
-- 1.If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes 
-- - how much money has Pizza Runner made so far if there are no delivery fees?
SELECT SUM(CASE pizza_id
	   		WHEN 1 THEN 12
			WHEN 2 THEN 10
	   END) AS "total_price"
FROM customer_orders
JOIN runner_orders
USING(order_id)
WHERE cancellation IS NULL;

-- 2.What if there was an additional $1 charge for any pizza extras?
-- Ex: Add cheese is $1 extra
SELECT SUM(CASE pizza_id
	   		WHEN 1 THEN 12+COALESCE(ARRAY_LENGTH(extras,1),0)
			WHEN 2 THEN 10+COALESCE(ARRAY_LENGTH(extras,1),0)
	   END) AS "total_price"
FROM customer_orders
JOIN runner_orders
USING(order_id)
WHERE cancellation IS NULL;

-- 3.The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, 
-- how would you design an additional table for this new dataset - generate a schema for this new table 
-- and insert your own data for ratings for each successful customer order between 1 to 5.
CREATE SCHEMA IF NOT EXISTS runner_rating_schema
AUTHORIZATION postgres;
SET search_path = runner_rating_schema;

SELECT * FROM case_study_2.runner_orders
JOIN case_study_2.customer_orders
USING(order_id);

DROP TABLE IF EXISTS runner_rating;
DROP TABLE IF EXISTS runner_order;
CREATE TABLE runner_order
AS
SELECT DISTINCT order_id,
	   runner_id,
	   customer_id
FROM case_study_2.runner_orders
JOIN case_study_2.customer_orders
USING(order_id)
WHERE cancellation IS NULL
ORDER BY order_id;

ALTER TABLE runner_order
ADD CONSTRAINT unique_row
	UNIQUE(order_id,runner_id,customer_id);
SELECT * FROM runner_order;

CREATE TABLE runner_rating
(
	order_id INTEGER PRIMARY KEY,
	runner_id INTEGER,
	customer_id INTEGER,
	rating INTEGER,
	CHECK(rating>=1 AND rating<=5),
	FOREIGN KEY(order_id,runner_id,customer_id)
		REFERENCES runner_order(order_id,runner_id,customer_id)
);

INSERT INTO runner_rating(order_id,runner_id,customer_id,rating)
VALUES (1,1,101,5),
	   (2,1,101,3),
	   (4,2,103,4),
	   (5,3,104,5),
	   (7,2,105,4),
	   (8,2,102,5),
	   (10,1,104,2);
--wrong entry
INSERT INTO runner_rating(order_id,runner_id,customer_id,rating)
VALUES (1,1,111,5);
INSERT INTO runner_rating(order_id,runner_id,customer_id,rating)
VALUES (1,1,101,78);

SELECT * FROM runner_rating;

-- 4.Using your newly generated table - can you join all of the information together 
-- to form a table which has the following information for successful deliveries?
-- customer_id
-- order_id
-- runner_id
-- rating
-- order_time
-- pickup_time
-- Time between order and pickup
-- Delivery duration
-- Average speed
-- Total number of pizzas
SELECT rr.customer_id,
	   rr.order_id,
	   rr.runner_id,
	   rating,
	   order_time::TIME,
	   pickup_time::TIME,
	   pickup_time-order_time AS "preparation_time",
	   duration,
	   ROUND(distance/(duration::numeric/60),2) AS "average_speed(km/h)",
	   COUNT(pizza_id) OVER(PARTITION BY order_id) AS "number_of_pizza"
FROM runner_rating_schema.runner_rating rr
JOIN case_study_2.runner_orders ro
USING(order_id)
JOIN case_study_2.customer_orders co
USING(order_id);

-- 5.If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras 
--   and each runner is paid $0.30 per kilometre traveled 
--   how much money does Pizza Runner have left over after these deliveries?
WITH cte AS
(	SELECT
		    SUM(CASE
					WHEN co.pizza_id = 1 THEN 12
					WHEN co.pizza_id = 2 THEN 10
				END) -
			ROUND(AVG(distance:: NUMERIC)*0.30, 2) AS "profit"
	FROM runner_orders AS ro 
	JOIN customer_orders AS co 
	USING(order_id)
	WHERE ro.cancellation IS NULL
	GROUP BY ro.order_id
	ORDER BY ro.order_id)
SELECT sum(profit) 
FROM cte;

--2 app
WITH cte AS
(	SELECT SUM(distance)*0.30 AS "dis"
			FROM runner_orders)
SELECT SUM(
			CASE pizza_id
				WHEN 1 THEN 12
				WHEN 2 THEN 10
			END) - SUM(dis)
FROM customer_orders
JOIN runner_orders
USING(order_id)
WHERE cancellation IS NULL
;

-- E. Bonus Questions
-- If Danny wants to expand his range of pizzas - how would this impact the existing data design? 
-- Write an INSERT statement to demonstrate what would happen 
-- if a new Supreme pizza with all the toppings was added to the Pizza Runner menu?
SELECT * 
FROM pizza_names;
INSERT INTO pizza_names
VALUES(3,'Supreme');

SELECT * 
FROM pizza_recipes;
INSERT INTO pizza_recipes
VALUES(3,'1,2,3,4,5,6,7,8,9,10,11,12');


--new menu
SELECT * 
FROM pizza_names
JOIN pizza_recipes
USING(pizza_id);

SELECT * FROM pizza_toppings;

