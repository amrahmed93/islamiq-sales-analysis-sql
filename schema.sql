-- database creation
CREATE DATABASE islamiq_analytics;

-- switching to correct database 
USE islamiq_analytics;

/*
Create core tables for IslamIQ analytics.
Includes products, customers, orders, and order items.
*/

CREATE TABLE products (
	product_id INT AUTO_INCREMENT PRIMARY KEY,
	product_name VARCHAR(100) NOT NULL,
	category VARCHAR(100) NOT NULL,
	price DECIMAL(10, 2) NOT NULL,
	cost DECIMAL(10, 2) NOT NULL
);

CREATE TABLE customers (
	customer_id INT AUTO_INCREMENT PRIMARY KEY,
	first_name VARCHAR(50) NOT NULL,
	last_name VARCHAR(50) NOT NULL,
	email VARCHAR(100) NOT NULL UNIQUE,
	city VARCHAR(50),
	country VARCHAR(50),
	signup_date DATE NOT NULL,
	signup_source VARCHAR(50) DEFAULT 'unknown'
);

CREATE TABLE orders (
	order_id INT AUTO_INCREMENT PRIMARY KEY,
	customer_id INT,
	order_date DATETIME NOT NULL,
	order_status VARCHAR(20) NOT NULL,
	payment_method VARCHAR(30) NOT NULL,
	subtotal DECIMAL(10, 2) NOT NULL,
	discount_amount DECIMAL(10, 2),
    discount_code VARCHAR(50),
	tax_amount DECIMAL(10, 2), 
	shipping_amount DECIMAL(10, 2),
	order_total DECIMAL(10, 2) NOT NULL,

	FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
	order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);