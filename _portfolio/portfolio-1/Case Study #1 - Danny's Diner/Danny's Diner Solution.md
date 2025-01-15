# :ramen: :curry: :sushi: Case Study #1: Danny's Diner

## Case Study Questions

1. What is the total amount each customer spent at the restaurant?
2. How many days has each customer visited the restaurant?
3. What was the first item from the menu purchased by each customer?
4. What is the most purchased item on the menu and how many times was it purchased by all customers?
5. Which item was the most popular for each customer?
6. Which item was purchased first by the customer after they became a member?
7. Which item was purchased just before the customer became a member?
10. What is the total items and amount spent for each member before they became a member?
11. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
12. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
***

###  1. What is the total amount each customer spent at the restaurant?

```sql
SELECT 
  customer_id,
  CONCAT('$', sum(price)) AS total_sales
FROM menu
  INNER JOIN sales ON menu.product_id = sales.product_id
GROUP BY customer_id
ORDER BY customer_id;
``` 
	
#### Result set:
| customer_id | total_sales |
| ----------- | ----------- |
| A           | $76         |
| B           | $74         |
| C           | $36         |

***

###  2. How many days has each customer visited the restaurant?

```sql
SELECT 
  customer_id,
  count(DISTINCT order_date) AS visit_count
FROM dannys_diner.sales
GROUP BY customer_id
ORDER BY customer_id;
``` 
	
#### Result set:
| customer_id | visit_count |
| ----------- | ----------- |
| A           | 4           |
| B           | 6           |
| C           | 2           |

***

###  3. What was the first item(s) from the menu purchased by each customer?
#### This request was a bit ambigious as it could be interpreted as follows;
####  (a) first item(s) from the menu purchased by each customer
####  (b) first item from the first menu  purchased by each customer

```sql
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
``` 
	
#### Result set: All item(s) from first menu 
| customer_id | product_name |
| ----------- | ------------ |
| A           | curry        |
| A           | sushi        |
| B           | curry        |
| C           | ramen        |

```sql
WITH order_info AS
  (SELECT customer_id,
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
``` 
	
#### Result set: First item from first menu 
| customer_id | product_name |
| ----------- | ------------ |
| A           | curry        |
| B           | curry        |
| C           | ramen        |

***

###  4. What is the most purchased item on the menu and how many times was it purchased by all customers?

```sql
SELECT Top (1) 
	product_name AS most_purchased_item,
  count(s.product_id) AS order_count
FROM menu AS m
	INNER JOIN sales AS s 
		ON m.product_id = s.product_id
GROUP BY product_name
ORDER BY order_count DESC
``` 
	
#### Result set:
| most_purchased_item | order_count |
| ------------------- | ----------- |
| ramen               | 8           |

***

###  5. Which item was the most popular for each customer?

```sql
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
WHERE ranking = 1;
``` 
	
#### Result set:
| customer_id | product_name | order_count |
| ----------- | ------------ | ----------- |
| A           | ramen        | 3           |
| B           | ramen        | 2           |
| B           | curry        | 2           |
| B           | sushi        | 2           |
| C           | ramen        | 3           |

***

###  6. Which item was purchased first by the customer after they became a member?

```sql
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
``` 
	
#### Result set:
| customer_id | product_name | order_date |
| ----------- | ------------ | ---------- | |
| A           | curry        | 2021-01-07 |
| B           | sushi        | 2021-01-07 |

***

###  7. Which item was purchased just before the customer became a member?

```sql
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
``` 
	
#### Result set:
| customer_id | product_name | order_date | join_date  |
| ----------- | ------------ | ---------- | ---------- |
| A           | sushi        | 2021-01-01 | 2021-01-07 |
| A           | curry        | 2021-01-01 | 2021-01-07 |
| B           | sushi        | 2021-01-04 | 2021-01-09 |

***

###  8. What is the total items and amount spent for each member before they became a member?

```sql
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
``` 
	
#### Result set:
| customer_id | total_items | amount_spent |
| ----------- | ----------- | ------------ |
| A           | 2           | $25          |
| B           | 3           | $40          |

***

###  9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

#### Had the customer joined the loyalty program before making the purchases, total points that each customer would have accrued
```sql
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
``` 
	
#### Result set:
| customer_id | customer_points |
| ----------- | --------------- |
| A           | 860             |
| B           | 940             |
| C           | 360             |

#### Total points that each customer has accrued after taking a membership
```sql
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
``` 
	
#### Result set:
| customer_id | customer_points |
| ----------- | --------------- |
| A           | 510             |
| B           | 440             |

***

###  10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January

#### Steps
1. Find the program_last_date which is 7 days after a customer joins the program (including their join date)
2. Determine the customer points for each transaction and for members with a membership
- During the first week of the membership -> points = price*20 irrespective of the purchase item
- Product = Sushi -> and order_date is not within a week of membership -> points = price*20
- Product = Not Sushi -> and order_date is not within a week of membership -> points = price*10
3. Conditions in JOIN clause
- order_date <= '2021-01-31' -> Order must be placed before 31st January 2021
- order_date >= join_date -> Points awarded to only customers with a membership

```sql
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
``` 

#### Result set:
| customer_id | customer_points |
| ----------- | --------------- |
| A           | 1020            |
| B           | 320             |

***

###  Bonus Questions

#### Join All The Things
Create basic data tables that Danny and his team can use to quickly derive insights without needing to join the underlying tables using SQL. Fill Member column as 'N' if the purchase was made before becoming a member and 'Y' if the after is amde after joining the membership.

```sql
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
``` 
	
#### Result set:
| customer_id	| product_name | order_date | price | is_member? | 
| ----------- | ------------ | ---------- | ----- | ---------- |
| A           | sushi        | 2021-01-01 | 10    | N          |
| A           | curry        | 2021-01-01 | 15    | N          |
| A           | curry        | 2021-01-07 | 15    | Y          |
| A           | ramen        | 2021-01-10 | 12    | Y          |
| A           | ramen        | 2021-01-11 | 12    | Y          |
| A           | ramen        | 2021-01-11 | 12    | Y          |
| B           | curry        | 2021-01-01 | 15    | N          |
| B           | curry        | 2021-01-02 | 15    | N          |
| B           | sushi        | 2021-01-04 | 10    | N          |
| B           | sushi        | 2021-01-11 | 10    | Y          |
| B           | ramen        | 2021-01-16 | 12    | Y          |
| B           | ramen        | 2021-02-01 | 12    | Y          |
| C           | ramen        | 2021-01-01 | 12    | N          |
| C           | ramen        | 2021-01-01 | 12    | N          |
| C           | ramen        | 2021-01-07 | 12    | N          |

***

#### Rank All The Things
Danny also requires further information about the ranking of customer products, but he purposely does not need the ranking for non-member purchases so he expects null ranking values for the records when customers are not yet part of the loyalty program.

```sql
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
```

#### Result set:
| customer_id	| product_name | order_date | price | is_member? | ranking |
| ----------- | ------------ | ---------- | ----- | ---------- | ------- |
| A           | sushi        | 2021-01-01 | 10    | N          | NULL    |
| A           | curry        | 2021-01-01 | 15    | N          | NULL    |
| A           | curry        | 2021-01-07 | 15    | Y          | 1       |
| A           | ramen        | 2021-01-10 | 12    | Y          | 2       |
| A           | ramen        | 2021-01-11 | 12    | Y          | 3       |
| A           | ramen        | 2021-01-11 | 12    | Y          | 3       |
| B           | curry        | 2021-01-01 | 15    | N          | NULL    |
| B           | curry        | 2021-01-02 | 15    | N          | NULL    |
| B           | sushi        | 2021-01-04 | 10    | N          | NULL    |
| B           | sushi        | 2021-01-11 | 10    | Y          | 1       |
| B           | ramen        | 2021-01-16 | 12    | Y          | 2       |
| B           | ramen        | 2021-02-01 | 12    | Y          | 3       |
| C           | ramen        | 2021-01-01 | 12    | N          | NULL    |
| C           | ramen        | 2021-01-01 | 12    | N          | NULL    |
| C           | ramen        | 2021-01-07 | 12    | N          | NULL    |

***


Click [here](https://github.com/Akama-EO/8-Week-SQL-Challenge) to move back to the 8-Week-SQL-Challenge repository!


