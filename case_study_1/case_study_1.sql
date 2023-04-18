--CREATING Schema and tables
CREATE SCHEMA case_study_1;
SET search_path = case_study_1;

CREATE TABLE sales (
	"customer_id" VARCHAR(1),
	"order_date" DATE,
	"product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
  
SELECT * FROM sales;
SELECT * FROM menu;
SELECT * FROM members;



--CASE STUDY 1

-- 1 What is the total amount each customer spent at the restaurant?
SELECT sl.customer_id,
	   SUM(m.price)
FROM sales sl
JOIN menu m
USING(product_id)
GROUP BY customer_id
ORDER BY sl.customer_id;
-- A 76
-- B 74
-- C 36

 


-- 2 How many days has each customer visited the restaurant?
SELECT customer_id,
	  COUNT(DISTINCT order_date) AS "visit_count"
FROM sales
GROUP BY customer_id;

 

-- 3 What was the first item from the menu purchased by each customer?
WITH cte AS
(	SELECT customer_id,
 		   product_name,
 		   rank()
 			OVER(PARTITION BY customer_id
				 ORDER BY order_date ASC) AS rnk
 	FROM sales
 	JOIN menu 
 	USING(product_id))
SELECT DISTINCT ON(customer_id,product_name) customer_id,product_name
FROM cte
WHERE rnk=1;

 

-- 4 What is the most purchased item on the menu and how many times was it purchased by all customers?
WITH cte AS
(	SELECT product_id,
		   COUNT(product_id) AS cnt
	FROM sales
	GROUP BY product_id
	ORDER BY cnt DESC
	LIMIT 1)
SELECT customer_id,
	   MAX(product_id) AS "product_id",
	   COUNT(sl.product_id)
FROM sales sl
JOIN cte
USING(product_id)
GROUP BY sl.customer_id;


-- 5 Which item was the most popular for each customer?
SELECT customer_id,
	   ROW_NUMBER() OVER(PARTITION BY customer_id),
	   COUNT(product_id)
FROM sales
GROUP BY customer_id;

-- 6 Which item was purchased first by the customer after they became a member?
WITH cte AS
(	SELECT customer_id,
 		   product_name,
		   RANK() OVER(PARTITION BY customer_id
							 ORDER BY order_date ASC) AS rnk
	FROM sales
	JOIN members
	USING(customer_id)
	JOIN menu
	USING(product_id)
	WHERE order_date >= join_date)
SELECT customer_id,
	   product_name
FROM cte
WHERE rnk=1;

-- 7 Which item was purchased just before the customer became a member?
WITH cte AS
(
	SELECT *,
		   RANK() OVER(PARTITION BY customer_id
					   ORDER BY order_date DESC) AS "rnk"
	FROM sales
	JOIN members
	USING(customer_id)
	JOIN menu
	USING(product_id)
	WHERE order_date<join_date
)
SELECT customer_id,
	   product_name
FROM cte
WHERE rnk=1;

-- 8 What is the total items and amount spent for each member before they became a member?

SELECT DISTINCT customer_id,
	   COUNT(product_id) OVER(PARTITION BY customer_id),
	   SUM(price) OVER(PARTITION BY customer_id)
FROM sales
JOIN members
USING(customer_id)
JOIN menu
USING(product_id)
WHERE order_date<join_date
ORDER BY customer_id;


-- 9 If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT customer_id,
	  SUM(CASE product_name
			WHEN 'sushi' THEN price*20
			ELSE price*10
		  END) AS points
FROM sales
JOIN menu
USING(product_id) 
GROUP BY customer_id
ORDER BY customer_id;

 
-- 10 In the first week after a customer joins the program (including their join date) 
--       they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
SELECT customer_id,
	   SUM(CASE 
			   WHEN join_date <= order_date  AND order_date <=join_date+6 THEN price*20
			   ELSE price*10
	   	   END) AS "points"
FROM sales
JOIN members
USING(customer_id)
JOIN menu
USING(product_id)
WHERE order_date>=join_date
      AND EXTRACT(MONTH FROM order_date)<=1
GROUP BY customer_id
ORDER BY customer_id;


--Bonus quiestion
-- Join all the things
SELECT sales.customer_id,
	   order_date,
	   product_name,
	   price,
	   CASE
	   		WHEN order_date >= join_date THEN 'Y'
			ELSE 'N'
	   END AS "member"
FROM sales
JOIN menu
USING(product_id)
LEFT JOIN members
USING(customer_id)
ORDER BY customer_id,order_date,product_name;

--rank all things
WITH cte AS
(
	SELECT sales.customer_id,
		   order_date,
		   product_name,
		   price,
		   CASE
				WHEN join_date IS NULL THEN 'N'
				WHEN order_date < join_date THEN 'N'
				ELSE 'Y'
		   END AS "member"
	FROM sales
	JOIN menu
	USING(product_id)
	LEFT JOIN members
	USING(customer_id)
	ORDER BY customer_id,order_date,product_name
)
SELECT *,
	   CASE
		   WHEN member ='Y'
		   THEN dense_rank() OVER(PARTITION BY customer_id,member
					   ORDER BY order_date)
		   ELSE NULL
		END AS "ranking"
FROM cte;
