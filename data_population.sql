/*
Data population pipeline:

1. Load customer data from Mockaroo CSV.
2. Insert orders with random dates, statuses, and payment methods.
3. Insert order_items using real product IDs.
4. Compute subtotal from order_items.
5. Assign discount codes.
6. Compute discount amounts, tax, and final totals.
*/

-- import customer data generated with Mockaroo
LOAD DATA LOCAL INFILE 'data/customer_data.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(first_name, last_name, email, city, country, signup_date, signup_source);

-- generate initial orders
INSERT INTO orders
(customer_id, order_date, order_status, payment_method, subtotal, discount_amount, discount_code, tax_amount, shipping_amount, order_total)
SELECT
    c.customer_id,
    TIMESTAMP(
        DATE_ADD('2025-03-11', INTERVAL FLOOR(RAND() * 365) DAY),
        SEC_TO_TIME(FLOOR(RAND() * 86400))
    ) AS order_date,
    ELT(
        FLOOR(1 + RAND() * 10),
        'completed','completed','completed','completed','completed',
        'completed','completed','completed',
        'cancelled','refunded'
    ) AS order_status,
    CASE
        WHEN c.signup_source = 'manual' AND RAND() < 0.35 THEN 'cash'
        ELSE ELT(FLOOR(1 + RAND() * 3), 'credit_card', 'paypal', 'apple_pay')
    END AS payment_method,
    0.00 AS subtotal,
    0.00 AS discount_amount,
    NULL AS discount_code,
    0.00 AS tax_amount,
    0.00 AS shipping_amount,
    0.00 AS order_total
FROM customers c
ORDER BY RAND();

-- assign basket sizes: 50% of orders get 1 item, 35% get 2, 15% get 3
DROP TEMPORARY TABLE IF EXISTS order_basket_sizes;

CREATE TEMPORARY TABLE order_basket_sizes AS
SELECT
    order_id,
    CASE
        WHEN r < 0.50 THEN 1
        WHEN r < 0.85 THEN 2
        ELSE 3
    END AS basket_size
FROM (
    SELECT order_id, RAND() AS r
    FROM orders
) x;

-- insert first item for every order
INSERT INTO order_items
(order_id, product_id, quantity, price)
SELECT
    o.order_id,
    FLOOR(71 + RAND() * 70) AS product_id,
    1 AS quantity,
    0.00 AS price
FROM orders o;
-- note: product_id values currently range from 71 to 140

-- insert second item for orders with basket size 2 or 3
INSERT INTO order_items
(order_id, product_id, quantity, price)
SELECT
    b.order_id,
    FLOOR(71 + RAND() * 70) AS product_id,
    1 AS quantity,
    0.00 AS price
FROM order_basket_sizes b
WHERE b.basket_size >= 2;

-- insert third item for orders with basket size 3
INSERT INTO order_items
(order_id, product_id, quantity, price)
SELECT
    b.order_id,
    FLOOR(71 + RAND() * 70) AS product_id,
    1 AS quantity,
    0.00 AS price
FROM order_basket_sizes b
WHERE b.basket_size = 3;

UPDATE order_items oi
JOIN products p
ON oi.product_id = p.product_id
SET oi.price = p.price;

-- compute subtotal from basket contents
UPDATE orders o
JOIN (
    SELECT
        order_id,
        SUM(quantity * price) AS subtotal_calc
    FROM order_items
    GROUP BY order_id
) x
ON o.order_id = x.order_id
SET o.subtotal = x.subtotal_calc;

-- assign in-person discount codes based on subtotal
UPDATE orders
SET discount_code =
    CASE
        WHEN payment_method = 'cash' AND subtotal >= 80.00 THEN 'IN_PERSON_15'
        WHEN payment_method = 'cash' AND subtotal >= 60.00 AND subtotal < 80.00 THEN 'IN_PERSON_10'
        WHEN payment_method = 'cash' AND subtotal >= 50.00 AND subtotal < 60.00 THEN 'IN_PERSON_5'
        ELSE NULL
    END;
    
-- randomly assign website discounts
UPDATE orders
JOIN (
    SELECT order_id, RAND() AS r
    FROM orders
) x
ON orders.order_id = x.order_id
SET discount_code =
    CASE
        WHEN payment_method = 'cash' THEN discount_code
        WHEN payment_method <> 'cash' AND r < 0.15 THEN 'WEB15'
        WHEN payment_method <> 'cash' AND r < 0.35 THEN 'WEB10'
        ELSE NULL
    END;

-- convert discount codes into actual discount amounts
UPDATE orders
SET discount_amount =
    CASE
        WHEN discount_code = 'IN_PERSON_5' THEN 5.00
        WHEN discount_code = 'IN_PERSON_10' THEN 10.00
        WHEN discount_code = 'IN_PERSON_15' THEN 15.00
        WHEN discount_code = 'WEB10' THEN ROUND(subtotal * 0.10, 2)
        WHEN discount_code = 'WEB15' THEN ROUND(subtotal * 0.15, 2)
        ELSE 0.00
    END;
    
-- calculate tax after discount
UPDATE orders
SET tax_amount = ROUND((subtotal - discount_amount) * 0.05, 2);

-- compute final order total
UPDATE orders
SET order_total = ROUND(subtotal - discount_amount + tax_amount + shipping_amount, 2);

-- zero out cancelled orders
UPDATE orders
SET
    subtotal = 0.00,
    discount_amount = 0.00,
    discount_code = NULL,
    tax_amount = 0.00,
    shipping_amount = 0.00,
    order_total = 0.00
WHERE order_status = 'cancelled';