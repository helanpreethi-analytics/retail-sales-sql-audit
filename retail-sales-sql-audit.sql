USE mystore;
ALTER TABLE store_sales ADD COLUMN product_attributes JSON;

UPDATE store_sales SET product_attributes = '{"color": "blue", "size": "M", "material": "cotton"}' WHERE sale_id = 1;
UPDATE store_sales SET product_attributes = '{"color": "black", "size": "32", "material": "denim"}' WHERE sale_id = 2;
UPDATE store_sales SET product_attributes = '{"color": "white", "size": "9", "material": "mesh"}' WHERE sale_id = 3;
UPDATE store_sales SET product_attributes = '{"color": "brown", "size": "M", "material": "plastic"}' WHERE sale_id = 4;

CREATE TABLE sales_audit_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    sale_id INT,
    action_type VARCHAR(20),
    old_price DECIMAL(10,2),
    new_price DECIMAL(10,2),
    changed_at DATETIME
);


#Stored Procedures & Functions
DELIMITER //

CREATE PROCEDURE GetEmployeePerformance(IN emp_id INT)
BEGIN
    SELECT e.employee_name,
           COUNT(s.sale_id) AS total_sales,
           SUM(s.price * s.quantity) AS total_revenue
    FROM employees e
    LEFT JOIN store_sales s ON e.employee_id = s.employee_id
    WHERE e.employee_id = emp_id
    GROUP BY e.employee_name;
END //

DELIMITER ;

CALL GetEmployeePerformance(1);   -- shows Anita's performance
CALL GetEmployeePerformance(2);   -- shows Suresh's performance

DELIMITER //

CREATE FUNCTION GetTotalRevenue(emp_id INT) RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE total DECIMAL(10,2);
    SELECT SUM(price * quantity) INTO total
    FROM store_sales WHERE employee_id = emp_id;
    RETURN total;
END //

DELIMITER ;
SELECT employee_name, GetTotalRevenue(employee_id) AS revenue FROM employees;

DELIMITER //

CREATE TRIGGER before_price_update
BEFORE UPDATE ON store_sales
FOR EACH ROW
BEGIN
    INSERT INTO sales_audit_log(sale_id, action_type, old_price, new_price, changed_at)
    VALUES (OLD.sale_id, 'PRICE_UPDATE', OLD.price, NEW.price, NOW());
END //

DELIMITER ;

UPDATE store_sales SET price = 549.00 WHERE sale_id = 1;
SELECT * FROM sales_audit_log;

















DELIMITER //

CREATE TRIGGER before_price_update
BEFORE UPDATE ON store_sales
FOR EACH ROW
BEGIN
    INSERT INTO sales_audit_log(sale_id, action_type, old_price, new_price, changed_at)
    VALUES (OLD.sale_id, 'PRICE_UPDATE', OLD.price, NEW.price, NOW());
END //

DELIMITER ;

UPDATE store_sales SET price = 549.00 WHERE sale_id = 1;
SELECT * FROM sales_audit_log;

START TRANSACTION;

UPDATE store_sales SET quantity = quantity - 1 WHERE sale_id = 3;
INSERT INTO returns (return_id, sale_id, return_reason, refund_amount)
VALUES (6, 3, 'Customer changed mind', 2499.00);

COMMIT;

START TRANSACTION;

UPDATE store_sales SET price = 0 WHERE sale_id = 1;
SELECT price FROM store_sales WHERE sale_id = 1;   -- shows 0.00, but NOT saved yet

ROLLBACK;

SELECT price FROM store_sales WHERE sale_id = 1;   -- back to original price! ROLLBACK undid it

START TRANSACTION;

UPDATE store_sales SET price = 600 WHERE sale_id = 1;
SAVEPOINT after_price_change;

UPDATE store_sales SET quantity = 100 WHERE sale_id = 1;
ROLLBACK TO after_price_change;   -- undoes ONLY the quantity change, keeps the price change

COMMIT;

SELECT sale_id, product_attributes,
    JSON_EXTRACT(product_attributes, '$.color') AS color,
    product_attributes->>'$.size' AS size
FROM store_sales
WHERE product_attributes IS NOT NULL;

SELECT * FROM store_sales
WHERE product_attributes->>'$.size' = 'M';

SELECT sale_id, JSON_CONTAINS_PATH(product_attributes, 'one', '$.color') AS has_color
FROM store_sales;


SELECT
    employee_name,
    SUM(CASE WHEN category = 'Clothing'    THEN price*quantity ELSE 0 END) AS Clothing_Revenue,
    SUM(CASE WHEN category = 'Footwear'    THEN price*quantity ELSE 0 END) AS Footwear_Revenue,
    SUM(CASE WHEN category = 'Accessories' THEN price*quantity ELSE 0 END) AS Accessories_Revenue
FROM store_sales
GROUP BY employee_name;

CREATE INDEX idx_city_category ON store_sales(city, category);
-- SLOWER: function wrapped around the column blocks index usage
SELECT * FROM store_sales WHERE YEAR(sales_date) = 2026;

-- FASTER: same result, but written as a range — index-friendly
SELECT * FROM store_sales WHERE sales_date BETWEEN '2026-01-01' AND '2026-12-31';

-- SLOWER: leading wildcard forces a full scan (MySQL can't jump ahead if it doesn't know the START of the text)
SELECT * FROM store_sales WHERE product_name LIKE '%shirt';

-- FASTER (if possible): wildcard only at the end allows index usage
SELECT * FROM store_sales WHERE product_name LIKE 'shirt%';

EXPLAIN SELECT * FROM store_sales WHERE city = 'Chennai' AND category = 'Clothing';


UPDATE store_sales SET price = 599 WHERE product_name = 'Sandals';
SET SQL_SAFE_UPDATES = 0;

UPDATE store_sales SET price = 599 WHERE sale_id = 7;
SELECT product_name FROM store_sales;   -- typo!

SHOW TABLES;              -- lists tables in the CURRENT database
SELECT DATABASE();        -- confirms which database you're currently "inside"
USE mystore;               -- switch to the correct one

SELECT s.city FROM store_sales s JOIN employees e ON s.employee_id = e.employee_id;

SELECT VERSION();

SELECT DISTINCT e.employee_name
FROM store_sales s JOIN employees e ON s.employee_id = e.employee_id
WHERE s.category = 'Clothing'
AND e.employee_name IN (
    SELECT e2.employee_name FROM store_sales s2 JOIN employees e2 ON s2.employee_id=e2.employee_id
    WHERE s2.category = 'Footwear'
);

SELECT DISTINCT e.employee_name
FROM store_sales s JOIN employees e ON s.employee_id = e.employee_id
WHERE s.category = 'Clothing'
AND e.employee_name NOT IN (
    SELECT e2.employee_name FROM store_sales s2 JOIN employees e2 ON s2.employee_id=e2.employee_id
    WHERE s2.category = 'Accessories'
);

CREATE TEMPORARY TABLE test_sales AS SELECT * FROM store_sales;
INSERT INTO test_sales (sale_id, product_name, category, price, quantity, customer_name, city, sales_date, payment_mode, employee_name)
VALUES (100, 'Test Product', 'Clothing', 999.00, 1, 'Test Customer', 'Chennai', '2026-02-01', 'Cash', 'Anita');
SET SQL_SAFE_UPDATES = 0;
UPDATE test_sales SET price = 1099.00 WHERE sale_id = 100;
DELETE FROM test_sales WHERE sale_id = 100;
select * from test_sales;
TRUNCATE TABLE test_sales;
