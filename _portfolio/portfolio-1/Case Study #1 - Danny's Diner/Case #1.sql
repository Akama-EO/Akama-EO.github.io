---------------------------------------
--   CASE STUDY #1: DANNY'S DINER    --
---------------------------------------

-- Author: Emmanuel Akama
-- Date: 10/01/2025 
-- Tool used: Microsoft SQL Server 2019

---------------------------------------
--        CASE STUDY QUESTIONS       --
---------------------------------------

-- 1. What is the total amount each customer spent at the restaurant?
SELECT 
  customer_id,
  CONCAT('$', sum(price)) AS total_sales
FROM menu m
  INNER JOIN sales s
  ON m.product_id = s.product_id
GROUP BY customer_id
ORDER BY customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT 
  customer_id,
  count(DISTINCT order_date) AS visit_count
FROM sales
GROUP BY customer_id
ORDER BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
/*
  This request was a bit ambigious as it could be interpreted as follows
  (a) first item(s) from the menu purchased by each customer
  (b) first item in the first menu purchased by each customer

  Asssumption: Since the timestamp is missing, all items bought on the 
  first day is considered as the first item (provided multiple items were
  purchased on the first day) -- dense_rank() is used to rank all orders 
  purchased on the same day 
*/
-- 3(a) all item(s) from the first menu 
WITH order_info AS
  (SELECT customer_id,
          order_date,
          product_name,
          DENSE_RANK() OVER(PARTITION BY s.customer_id
                            ORDER BY s.order_date) AS ranking
   FROM sales AS s
	  INNER JOIN menu AS m 
	  ON s.product_id = m.product_id)
SELECT customer_id,
       product_name
FROM order_info
WHERE ranking = 1
GROUP BY customer_id,
         product_name;

---------------------------------------------------

-- 3(b) first item from first menu 
WITH order_info AS
  (SELECT
	   customer_id,
       order_date,
       product_name,
       DENSE_RANK() OVER(PARTITION BY s.customer_id
                         ORDER BY s.order_date) AS order_ranking,
	   DENSE_RANK() OVER(PARTITION BY s.customer_id
					     ORDER BY m.product_name) AS product_ranking
   FROM sales AS s
	  INNER JOIN menu AS m 
	  ON s.product_id = m.product_id)
SELECT customer_id,
       product_name
FROM order_info
WHERE order_ranking = 1 AND product_ranking = 1 
GROUP BY customer_id,
         product_name;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT Top (1) 
	product_name,
    count(s.product_id) AS order_count
FROM menu AS m
	INNER JOIN sales AS s 
		ON m.product_id = s.product_id
GROUP BY product_name
ORDER BY order_count DESC;

-- 5. Which item was the most popular for each customer?

-- Asssumption: Products with the highest purchase counts are all considered 
-- to be popular for each customer
WITH order_info AS
  (SELECT 
	  product_name,
      customer_id,
      count(product_name) AS order_count,
      rank() over(PARTITION BY customer_id
                  ORDER BY count(product_name) DESC) AS ranking
   FROM menu AS m
	  INNER JOIN sales AS s
	  ON m.product_id = s.product_id
   GROUP BY customer_id,
            product_name)
SELECT customer_id,
       product_name, 
       order_count
FROM order_info
WHERE ranking = 1

-- 6. Which item was purchased first by the customer after they became a member?

-- Asssumption: Since timestamp of purchase is not available, purchase made when 
-- order_date is the same or after the join date is used to find the first item

WITH diner_info AS
  (SELECT 
	  product_name,
      s.customer_id,
      order_date,
      join_date,
      m.product_id,
      DENSE_RANK() OVER(PARTITION BY s.customer_id
                        ORDER BY s.order_date) AS first_item
   FROM menu AS m
	  INNER JOIN sales AS s 
		 ON m.product_id = s.product_id
      INNER JOIN members AS mb 
		 ON mb.customer_id = s.customer_id
   WHERE order_date >= join_date)
SELECT 
	customer_id,
    product_name,
    order_date
FROM diner_info
WHERE first_item=1;

-- 7. Which item was purchased just before the customer became a member?

-- Asssumption: Since timestamp of purchase is not available, purchase made when 
-- order_dateis before the join date is used to find the last item purchased just 
-- before the customer became a member

WITH diner_info AS
  (SELECT 
	  product_name,
      s.customer_id,
      order_date,
      join_date,
      m.product_id,
      DENSE_RANK() OVER(PARTITION BY s.customer_id
                        ORDER BY s.order_date DESC) AS ranking
   FROM menu AS m
	  INNER JOIN sales AS s 
		 ON m.product_id = s.product_id
      INNER JOIN members AS mb 
		 ON mb.customer_id = s.customer_id
   WHERE order_date < join_date)
SELECT 
    product_name,
	customer_id,
    order_date,
    join_date
FROM diner_info
WHERE ranking = 1;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT 
  s.customer_id,
  count(product_name) AS total_items,
  CONCAT('$', SUM(price)) AS amount_spent
FROM menu AS m
  INNER JOIN sales AS s 
    ON m.product_id = s.product_id
  INNER JOIN members AS mb 
    ON mb.customer_id = s.customer_id
WHERE order_date < join_date
GROUP BY s.customer_id
ORDER BY customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
/*
  Again, this request is ambigious as it could be interpreted as follows
  (a) total points accured by each customer (even before joining the membership program)
  (b) total points accured by each customer after joining the membersip program
*/
-- 9(a) total points accrued BEFORE membership program
SELECT 
	customer_id,
    SUM(CASE
           WHEN product_name = 'sushi' THEN price*20 ELSE price*10
        END) AS customer_points
FROM menu AS m
	INNER JOIN sales AS s 
		ON m.product_id = s.product_id
GROUP BY customer_id
ORDER BY customer_id;

-- 9(b) total points accrued AFTER membership program
SELECT 
	s.customer_id,
    SUM(CASE
           WHEN product_name = 'sushi' THEN price*20 ELSE price*10
        END) AS customer_points
FROM menu AS m
	INNER JOIN sales AS s 
		ON m.product_id = s.product_id
	INNER JOIN members AS mb 
		ON mb.customer_id = s.customer_id
WHERE order_date >= join_date
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
-- not just sushi - how many points do customer A and B have at the end of January

-- Asssumption: Points is rewarded only after the customer joins in the membership program

-- Steps
-- 1. Find the program_last_date which is 7 days after a customer joins the program (including their join date)
-- 2. Determine the customer points for each transaction and for members with a membership
-- 		a. During the first week of the membership -> points = price*20 irrespective of the purchase item
-- 		b. Product = Sushi -> and order_date is not within a week of membership -> points = price*20
-- 		c. Product = Not Sushi -> and order_date is not within a week of membership -> points = price*10
-- 3. Conditions in JOIN clause
-- 		a. order_date <= '2021-01-31' -> Order must be placed before 31st January 2021
-- 		b. order_date >= join_date -> Points awarded to only customers with a membership

WITH program_last_day AS
   (SELECT 
	   customer_id,
	   join_date,
	   DATEADD(DAY, 6, join_date) AS program_last_date
	FROM members)
SELECT
	s.customer_id,
    SUM(CASE
		   WHEN order_date BETWEEN join_date AND program_last_date THEN price*10*2
		   WHEN order_date NOT BETWEEN join_date AND program_last_date
			  AND product_name = 'sushi' THEN price*10*2
		   WHEN order_date NOT BETWEEN join_date AND program_last_date
			  AND product_name != 'sushi' THEN price*10
        END) AS customer_points
FROM menu AS m
	INNER JOIN sales AS s 
		ON m.product_id = s.product_id
	INNER JOIN program_last_day AS mb 
		ON mb.customer_id = s.customer_id AND order_date <='2021-01-31' AND order_date >= join_date
GROUP BY s.customer_id
ORDER BY s.customer_id;

/*
   ##################               Bonus Questions - 01               ###############
	
   Create basic data tables that Danny and his team can use to quickly derive insights
   without needing to join the underlying tables using SQL. Fill Member column as 'N' 
   if the purchase was made before becoming a member and 'Y' if the after is made after
   joining the membership.
   ===================================================================================
*/

SELECT 
	s.customer_id,
    product_name,
	order_date,
    price,
	(CASE
	    WHEN s.order_date >= mb.join_date THEN 'Y' ELSE 'N'
	 END) AS [is_member?]
FROM members AS mb
	RIGHT JOIN sales AS s 
		ON mb.customer_id = s.customer_id
	INNER JOIN menu AS m
		ON m.product_id = s.product_id
ORDER BY s.customer_id,
         order_date;

/*
   ####################               Bonus Questions - 02               #################
   Danny also requires further information about the ranking of customer products, but he 
   purposely does not need the ranking for non-member purchases so he expects null ranking 
   values for the records when customers are not yet part of the loyalty program.
   =======================================================================================
*/
WITH data_table AS
	(SELECT 
		s.customer_id,
		product_name,
		order_date,
		price,
		(CASE
			WHEN s.order_date >= mb.join_date THEN 'Y' ELSE 'N'
		 END) AS [is_member?]
FROM members AS mb
	RIGHT JOIN sales AS s 
		ON mb.customer_id = s.customer_id
	INNER JOIN menu AS m
		ON m.product_id = s.product_id)
SELECT *,
	(CASE
	    WHEN [is_member?] = 'Y' THEN DENSE_RANK() OVER (PARTITION BY customer_id, [is_member?]
                                                        ORDER BY order_date) ELSE Null
	 END) AS ranking
FROM data_table;