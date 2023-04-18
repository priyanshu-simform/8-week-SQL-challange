--case study 8
SET search_path = case_study_8;


SELECT * FROM interest_map;
SELECT DISTINCT interest_name FROM interest_map;
SELECT DISTINCT interest_summary FROM interest_map;

SELECT * FROM interest_metrics;
SELECT * FROM json_data;

-- 1.Data Exploration and Cleansing
-- 1 Update the fresh_segments.interest_metrics table by modifying the month_year column to be a date data type with the start of the month
SELECT * FROM interest_metrics;
SELECT ('01-'||_month||'-'||_year)::DATE AS "month_year" FROM interest_metrics;


DROP TABLE IF EXISTS temp_interest_metics;
CREATE TEMP TABLE temp_interest_metrics
AS
SELECT * FROM interest_metrics;


ALTER TABLE temp_interest_metrics
ALTER COLUMN month_year TYPE DATE
USING ('01-'||month_year)::DATE;
SELECT * FROM temp_interest_metrics;
ALTER TABLE temp_interest_metrics
ALTER COLUMN interest_id TYPE INTEGER
USING interest_id::INT;
ALTER TABLE temp_interest_metrics
ALTER COLUMN _month TYPE INT
USING _month::INT;
ALTER TABLE temp_interest_metrics
ALTER COLUMN _year TYPE INT
USING _year::INT;
-- 2 What is count of records in the fresh_segments.interest_metrics for each month_year value sorted in chronological order (earliest to latest) 
--   with the null values appearing first?
SELECT
	month_year,
	COUNT(*)
FROM temp_interest_metrics
GROUP BY month_year
ORDER BY month_year NULLS FIRST;

-- 3 What do you think we should do with these null values in the fresh_segments.interest_metrics
-- we can delete these NULL entries
DELETE FROM temp_interest_metrics
WHERE month_year IS NULL;

SELECT COUNT(*)
FROM temp_interest_metrics
WHERE month_year IS NULL;

-- 4 How many interest_id values exist in the fresh_segments.interest_metrics table but not in the fresh_segments.interest_map table? 
--   What about the other way around?
SELECT interest_id::INT
FROM interest_metrics
EXCEPT
SELECT id
FROM interest_map;

SELECT
	id,
	interest_id,
	*
FROM interest_metrics a
RIGHT JOIN interest_map b
ON a.interest_id::INT=b.id
WHERE a.interest_id IS NULL;


WITH cte
AS (
	SELECT 
		DISTINCT
		id,
		interest_id
	FROM interest_map a
	FULL JOIN interest_metrics b
	ON b.interest_id::INT = a.id
	WHERE interest_id IS NULL OR 
	id IS NULL)
SELECT 
	SUM(CASE
			WHEN id IS NULL THEN 1
			ELSE 0
		END) total_not_in_map,
	SUM(CASE
			WHEN interest_id IS NULL THEN 1
			ELSE 0
		END) total_not_in_metric
FROM cte;

-- 5 Summarise the id values in the fresh_segments.interest_map by its total record count in this table
SELECT
	COUNT(id) AS "total_id"
FROM interest_map;

-- 6 What sort of table join should we perform for our analysis and why? 
-- ans: we should join these two table using inner join on the interest_id column of interest_metrics to the id column of interest_map
--      because this is the valid common column for joining in these both table for our analysis purpose
--  Check your logic by checking the rows xwhere interest_id = 21246 in your joined output and include all columns from fresh_segments.interest_metrics 
--  and all columns from fresh_segments.interest_map except from the id column.
SELECT
	a.*,
	interest_name,
	interest_summary,
	created_at,
	last_modified
FROM temp_interest_metrics a
JOIN interest_map b
ON a.interest_id=b.id
WHERE interest_id=21246;

-- 7 Are there any records in your joined table where the month_year value is before the created_at value from the fresh_segments.interest_map table? 

SELECT
	*
FROM temp_interest_metrics a 
LEFT JOIN interest_map b
ON a.interest_id = b.id
WHERE month_year<created_at;
--   Do you think these values are valid and why?
-- ans: Yes these values could be valid because initially we have taken the date in month_year as 01-month-year


-- 2.Interest Analysis
-- 1 Which interests have been present in all month_year dates in our dataset?
WITH cte AS
(	SELECT
		interest_id,
		COUNT(DISTINCT month_year) AS "mon_cnt"
	FROM temp_interest_metrics
	GROUP BY interest_id)
SELECT
	interest_id,
	interest_name
FROM cte
JOIN interest_map im
ON cte.interest_id=im.id
WHERE mon_cnt = (SELECT COUNT(DISTINCT month_year) FROM temp_interest_metrics);

-- 2 Using this same total_months measure - calculate the cumulative percentage of all records starting at 14 months 
--   - which total_months value passes the 90% cumulative percentage value?
WITH cte AS
(	SELECT
		interest_id,
		COUNT(DISTINCT month_year) AS "mon_cnt"
	FROM temp_interest_metrics
	GROUP BY interest_id),
cte_1 AS
(	SELECT
		mon_cnt,
		COUNT(interest_id) AS "total_ids",
--  		SUM(COUNT(interest_id)) OVER(ORDER BY mon_cnt DESC),
--  		SUM(COUNT(interest_id)) OVER(),
 		ROUND(SUM(COUNT(interest_id)) OVER(ORDER BY mon_cnt DESC)*100.0
 		/ SUM(COUNT(interest_id)) OVER(),2) AS "cum_percnt"
	FROM cte
	GROUP BY mon_cnt)
SELECT 
	*
FROM cte_1
WHERE cum_percnt>=90;




-- 3 If we were to remove all interest_id values which are lower than the total_months value we found in the previous question 
--   - how many total data points would we be removing?
WITH cte AS
(	SELECT
		interest_id,
		COUNT(DISTINCT month_year) AS "mon_cnt"
	FROM temp_interest_metrics
	GROUP BY interest_id)
SELECT
	COUNT(*)
FROM cte
WHERE mon_cnt<6;
--there are total 110 interest_id present having value lower than total_months value in the previous question

-- how many total data points would we be removing?
WITH cte AS
(	SELECT
		interest_id,
		COUNT(DISTINCT month_year) AS "mon_cnt"
	FROM temp_interest_metrics
	GROUP BY interest_id
	HAVING COUNT(DISTINCT month_year)<6)
SELECT
	COUNT(interest_id) AS "rmv_data_point"
FROM temp_interest_metrics
WHERE interest_id IN (SELECT interest_id FROM cte);

--400 data points will be removed


-- 4 Does this decision make sense to remove these data points from a business perspective? 
-- ans: Yes removing this value does make some sense as they have lower value in business perspective


-- 5 After removing these interests - how many unique interests are there for each month?
DROP TABLE IF EXISTS new_interest_metrics;
CREATE TEMP TABLE new_interest_metrics
AS
SELECT * FROM temp_interest_metrics;
--deleted those data points
DELETE FROM new_interest_metrics
WHERE interest_id IN (SELECT
						interest_id
-- 						COUNT(DISTINCT month_year) AS "mon_cnt"
					FROM temp_interest_metrics
					GROUP BY interest_id
					HAVING COUNT(DISTINCT month_year)<6)

-- how many unique interests are there for each month
SELECT
	_month,
	COUNT(DISTINCT interest_id)
FROM new_interest_metrics
GROUP BY _month
ORDER BY _month;

--original values (without removal of data points)
SELECT
	_month,
	COUNT(DISTINCT interest_id)
FROM temp_interest_metrics
GROUP BY _month
ORDER BY _month;





-- 3.Segment Analysis
-- 1 Using our filtered dataset by removing the interests with less than 6 months worth of data, 
--   which are the top 10 and bottom 10 interests 
--   which have the largest composition values in any month_year? Only use the maximum composition value for each interest 
--   but you must keep the corresponding month_year
DROP TABLE IF EXISTS interest_id_comp;

CREATE TEMP TABLE interest_id_comp
AS
SELECT
	DISTINCT ON(interest_id)
	interest_id,
	interest_name,
	month_year,
	MAX(composition) OVER(PARTITION BY interest_id) AS "max_comp"
FROM new_interest_metrics a
JOIN interest_map b
ON a.interest_id=b.id
ORDER BY interest_id;

-- top 10 interests 
SELECT
	interest_id,
	interest_name
FROM interest_id_comp
ORDER BY max_comp DESC
LIMIT 10;
-- bottom 10 interests
SELECT
	interest_id,
	interest_name
FROM interest_id_comp
ORDER BY max_comp
LIMIT 10;

--   which have the largest composition values in any month_year
SELECT
	DISTINCT
	month_year,
-- 	MAX(composition) OVER(PARTITION BY month_year),
	FIRST_VALUE(interest_name) OVER(PARTITION BY month_year
								  ORDER BY composition DESC) AS "max_comp_interest"
FROM temp_interest_metrics a
JOIN interest_map b
ON a.interest_id=b.id;






-- 2 Which 5 interests had the lowest average ranking value?
WITH cte AS
(	SELECT
		interest_id,
		ROUND(AVG(ranking),1) AS "avg_rank",
 		DENSE_RANK() OVER(ORDER BY AVG(ranking)) AS "rnk"
	FROM new_interest_metrics
	GROUP BY interest_id)
SELECT
	interest_id,
	interest_name,
	avg_rank
FROM cte
JOIN interest_map im
ON cte.interest_id=im.id
WHERE rnk<=5
ORDER BY rnk;


-- 3 Which 5 interests had the largest standard deviation in their percentile_ranking value?
WITH cte AS
(	SELECT
		interest_id,
		ROUND(STDDEV(percentile_ranking)::NUMERIC,2) AS "std_dev",
		DENSE_RANK() OVER(ORDER BY STDDEV(percentile_ranking) DESC) AS "rnk"
	FROM new_interest_metrics
	GROUP BY interest_id)
SELECT
	interest_id,
	interest_name,
	std_dev
FROM cte
JOIN interest_map im
ON cte.interest_id=im.id
WHERE rnk<=5
ORDER BY rnk;

-- 4 For the 5 interests found in the previous question - what was minimum and maximum percentile_ranking values for each interest 
--   and its corresponding year_month value? Can you describe what is happening for these 5 interests?
WITH cte AS
(	SELECT
		interest_id,
		ROUND(STDDEV(percentile_ranking)::NUMERIC,2) AS "std_dev",
		DENSE_RANK() OVER(ORDER BY STDDEV(percentile_ranking) DESC) AS "rnk"
	FROM new_interest_metrics
	GROUP BY interest_id)
SELECT DISTINCT
	interest_id,
	interest_name,
	std_dev,
	MIN(percentile_ranking) OVER(PARTITION BY interest_id) AS "min_per_rnk",
	MAX(percentile_ranking) OVER(PARTITION BY interest_id) AS "max_per_rnk"
FROM cte
JOIN new_interest_metrics
USING(interest_id)
JOIN interest_map im
ON cte.interest_id=im.id
WHERE rnk<=5;



-- 5 How would you describe our customers in this segment based off their composition and ranking values? 
--   What sort of products or services should we show to these customers and what should we avoid?
--  ans: Customers in this market category enjoy travelling, some may be business travellers, they seek a luxurious lifestyle, and they participate in sports. 
--  Instead of focusing on the budget category or any products or services connected to unrelated hobbies like computer games or astrology, 
--  we should highlight those that are relevant to luxury travel or a luxurious lifestyle. Hence, in general, we must concentrate on the interests with high composition values, 
--  but we also must monitor this metric to determine when clients become disinterested in a particular subject.



-- 4.Index Analysis
-- The index_value is a measure which can be used to reverse calculate the average composition for Fresh Segments’ clients.
-- Average composition can be calculated by dividing the composition column by the index_value column rounded to 2 decimal places.
DROP TABLE IF EXISTS avg_comp_table;
CREATE TEMP TABLE avg_comp_table
AS
SELECT
	_month,
	_year,
	month_year,
	interest_id,
	interest_name,
	composition,
	index_value,
	ranking,
	percentile_ranking,
	ROUND((composition/index_value)::NUMERIC,2) AS "avg_comp"
FROM new_interest_metrics a
JOIN interest_map b
ON a.interest_id=b.id;
SELECT * FROM avg_comp_table;

-- 1 What is the top 10 interests by the average composition for each month?
WITH cte AS
(	SELECT
		_month,
		_year,
		interest_id,
		interest_name,
		avg_comp,
		DENSE_RANK() OVER(PARTITION BY _month,_year
						  ORDER BY avg_comp DESC) AS "rnk"
	FROM avg_comp_table)
SELECT
	*
FROM cte
WHERE rnk<=10;

-- 2 For all of these top 10 interests - which interest appears the most often?
WITH cte AS
(	SELECT
		_month,
		_year,
		interest_id,
		interest_name,
		avg_comp,
		DENSE_RANK() OVER(PARTITION BY _month,_year
						  ORDER BY avg_comp DESC) AS "rnk"
	FROM avg_comp_table),
cte_1 AS
(	SELECT
		interest_name,
		COUNT(*) AS "cnt",
 	DENSE_RANK() OVER(ORDER BY COUNT(*) DESC) AS "new_rnk"
	FROM cte
	WHERE rnk<=10
	GROUP BY interest_name)
SELECT
	interest_name,
	cnt
FROM cte_1
WHERE new_rnk=1; 



-- 3 What is the average of the average composition for the top 10 interests for each month?
WITH cte AS
(	SELECT
		_month,
		_year,
		interest_id,
		interest_name,
		avg_comp,
		DENSE_RANK() OVER(PARTITION BY _month,_year
						  ORDER BY avg_comp DESC) AS "rnk"
	FROM avg_comp_table)
SELECT
	_month,
	_year,
	ROUND(AVG(avg_comp),2)
FROM cte
WHERE rnk<=10
GROUP BY _month,_year;

-- 4 What is the 3 month rolling average of the max average composition value from September 2018 to August 2019 
--   and include the previous top ranking interests in the same output shown below.


WITH cte AS
(	SELECT
 		*,
 		DENSE_RANK() OVER(PARTITION BY month_year
								  ORDER BY avg_comp DESC) AS "avg_rank"
 	FROM avg_comp_table
	WHERE month_year IS NOT NULL),
CTE_1 AS
(	SELECT
	   month_year,
	   interest_name,
	   avg_comp,
	   LAG(interest_name) OVER(ORDER BY month_year) AS "int_1_mon_ago",
	   LAG(avg_comp) OVER(ORDER BY month_year) AS "comp_1_mon_ago",
	   LAG(interest_name,2) OVER(ORDER BY month_year) AS "int_2_mon_ago",
	   LAG(avg_comp,2) OVER(ORDER BY month_year) AS "comp_2_mon_ago"
	FROM cte
	WHERE avg_rank=1)
SELECT 
	month_year,
	interest_name,
	avg_comp AS "max_index_composition",
	ROUND((avg_comp+comp_1_mon_ago+comp_2_mon_ago)/3,2) AS "3_month_moving_avg",
	int_1_mon_ago||': '||comp_1_mon_ago AS	"1_month_ago",
	int_2_mon_ago||': '||comp_2_mon_ago AS	"2_months_ago"
FROM cte_1
WHERE comp_2_mon_ago IS NOT NULL
ORDER BY month_year;




-- 5 Provide a possible reason why the max average composition might change from month to month? 
--   Could it signal something is not quite right with the overall business model for Fresh Segments?
-- ANS.I believe that the user's interests have shifted, and that they are now less interested in certain topics, if at all. 
-- Users "burned out," and the index composition value fell. Some usersmay need to be moved to a different segment. 
-- Although some interests have a high index composition value, which could indicate that these topics are always of interest to the users.








--ignore this
-- SELECT 
-- 	table_name AS TableName,
-- 	*
-- FROM information_schema.TABLES
-- WHERE table_schema = 'case_study_7'
-- AND table_name = 'sales'
-- SELECT 'a fat cat sat on a mat and ate a fat rat'::tsvector @@ 'a'::tsquery;
-- SELECT 
-- 	pl.id 'PROCESS ID'
-- 	,trx.trx_started
-- 	,esh.event_name 'EVENT NAME'
-- 	,esh.sql_text 'SQL'
-- FROM information_schema.innodb_trx AS trx
-- INNER JOIN information_schema.processlist pl 
-- 	ON trx.trx_mysql_thread_id = pl.id
-- INNER JOIN performance_schema.threads th 
-- 	ON th.processlist_id = trx.trx_mysql_thread_id
-- INNER JOIN performance_schema.events_statements_history esh 
-- 	ON esh.thread_id = th.thread_id
-- WHERE trx.trx_started < CURRENT_TIME - INTERVAL '59 SECOND'
--   AND pl.user <> 'system_user'
-- ORDER BY esh.EVENT_ID ;
