SELECT category, COUNT(*) AS number_of_orders,
       SUM(total_eur)::numeric AS total_revenue
FROM customer
WHERE status = 'Delivered'
GROUP BY category
ORDER BY total_revenue DESC;

WITH revenue_ranking AS (
  SELECT category, product, SUM(total_eur) :: numeric AS total_revenue,
           ROW_NUMBER() OVER (
               PARTITION BY category
               ORDER BY SUM(total_eur) DESC
           ) AS rank_revenue
    FROM customer
    WHERE status = 'Delivered'
    GROUP BY category, product
)
SELECT category, product, total_revenue, rank_revenue
FROM revenue_ranking
WHERE rank_revenue <= 3
ORDER BY category, rank_revenue;


SELECT customer_id,
       ROUND(SUM(total_eur::numeric), 2) AS total_spending,
       RANK() OVER (ORDER BY SUM(total_eur) DESC) AS spending_rank
FROM customer
WHERE status = 'Delivered'
GROUP BY customer_id
ORDER BY total_spending DESC, customer_id;

SELECT category,
       ROUND(100.0 * SUM(CASE WHEN status = 'Returned' THEN 1 ELSE 0 END)
             / COUNT(*), 2) AS returned_percentage
FROM customer
GROUP BY category
ORDER BY returned_percentage DESC;

SELECT product, AVG(rating) AS avg_rating,
       COUNT(rating) AS number_of_ratings
FROM customer
GROUP BY product
HAVING AVG(rating) < 3 AND COUNT(rating) >= 3
ORDER BY avg_rating ASC;

WITH delivery_gaps AS (
    SELECT city, delivery_date::date - order_date::date AS delivery_days
    FROM customer
    WHERE status = 'Delivered'
      AND order_date IS NOT NULL AND delivery_date IS NOT NULL
      AND city IS NOT NULL
)
SELECT city, AVG(delivery_days) AS avg_delivery_days
FROM delivery_gaps
GROUP BY city
ORDER BY avg_delivery_days DESC;

WITH spending_by_category AS (
    SELECT category, SUM(total_eur::numeric) AS category_revenue
    FROM customer
    WHERE status = 'Delivered'
    GROUP BY category
)
SELECT category, category_revenue,
       ROUND(100.0 * category_revenue
             / NULLIF(SUM(category_revenue) OVER (), 0), 2) AS revenue_percentage
FROM spending_by_category
ORDER BY revenue_percentage DESC;

WITH spending_by_month AS (
    SELECT DATE_TRUNC('month', order_date) AS month,
           SUM(total_eur::numeric) AS revenue_by_month
    FROM customer
    WHERE status = 'Delivered' AND order_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_date)
), monthly_comparison AS (
    SELECT month, revenue_by_month,
           LAG(revenue_by_month) OVER (ORDER BY month) AS previous_revenue
    FROM spending_by_month
)
SELECT month, TO_CHAR(month, 'FMMonth YYYY') AS month_name,
       ROUND(revenue_by_month, 2) AS monthly_revenue,
       ROUND(previous_revenue, 2) AS previous_revenue,
       ROUND(revenue_by_month - previous_revenue, 2) AS revenue_change,
       ROUND(100.0 * (revenue_by_month - previous_revenue)
             / NULLIF(previous_revenue, 0), 2) AS revenue_change_pct
FROM monthly_comparison
ORDER BY month;


WITH order_date_comparison AS (
    SELECT customer_id, order_id, order_date,
           LAG(order_date) OVER (
               PARTITION BY customer_id ORDER BY order_date, order_id
           ) AS previous_order
    FROM customer
    WHERE order_date IS NOT NULL
), comparison AS (
    SELECT customer_id, order_date::date - previous_order::date AS gap_days
    FROM order_date_comparison
)
SELECT customer_id, COUNT(*) AS number_of_orders,
       COUNT(gap_days) AS number_of_gaps,
       ROUND(AVG(gap_days)::numeric, 2) AS average_gap_in_days 
FROM comparison
GROUP BY customer_id
HAVING COUNT(gap_days) >= 1
ORDER BY average_gap_in_days;



WITH revenue_by_month_product AS (
    SELECT DATE_TRUNC('month', order_date) AS month,
           product, SUM(total_eur) AS total_revenue
    FROM customer
    WHERE status = 'Delivered' AND order_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_date), product
), monthly_maximum AS (
    SELECT month, product, total_revenue,
           MAX(total_revenue) OVER (PARTITION BY month) AS max_by_month
    FROM revenue_by_month_product
)
SELECT month, TO_CHAR(month, 'FMMonth YYYY') AS month_name,
       product, total_revenue, max_by_month
FROM monthly_maximum
WHERE total_revenue = max_by_month
ORDER BY month, product;

WITH revenue_by_month_category AS (
    SELECT DATE_TRUNC('month', order_date) AS month, category,
           SUM(total_eur::numeric) AS monthly_revenue
    FROM customer
    WHERE status = 'Delivered' AND order_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_date), category
)
SELECT month, category, ROUND(monthly_revenue, 2) AS monthly_revenue,
       ROUND(SUM(monthly_revenue) OVER (
           PARTITION BY category, EXTRACT(YEAR FROM month)
           ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ), 2) AS cumulative_revenue
FROM revenue_by_month_category
ORDER BY category, month;

