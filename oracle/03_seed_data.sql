-- =============================================================
-- Seed data — run as app_user in XEPDB1
-- =============================================================

ALTER SESSION SET CONTAINER = XEPDB1;

-- Customers
INSERT INTO app_user.CUSTOMERS (first_name, last_name, email, phone)
VALUES ('Alice', 'Nguyen', 'alice.nguyen@example.com', '+1-555-0101');

INSERT INTO app_user.CUSTOMERS (first_name, last_name, email, phone)
VALUES ('Bob', 'Martínez', 'bob.martinez@example.com', '+1-555-0102');

INSERT INTO app_user.CUSTOMERS (first_name, last_name, email, phone)
VALUES ('Clara', 'Schmidt', 'clara.schmidt@example.com', '+49-30-12345');

INSERT INTO app_user.CUSTOMERS (first_name, last_name, email)
VALUES ('David', 'Lee', 'david.lee@example.com');

COMMIT;

-- Orders
INSERT INTO app_user.ORDERS (customer_id, total_amount, status)
VALUES (1, 149.99, 'CONFIRMED');

INSERT INTO app_user.ORDERS (customer_id, total_amount, status)
VALUES (1, 59.50, 'SHIPPED');

INSERT INTO app_user.ORDERS (customer_id, total_amount, status)
VALUES (2, 299.00, 'PENDING');

INSERT INTO app_user.ORDERS (customer_id, total_amount, status)
VALUES (3, 75.25, 'DELIVERED');

COMMIT;

-- Order items
INSERT INTO app_user.ORDER_ITEMS (order_id, product_sku, product_name, quantity, unit_price)
VALUES (1, 'WIDGET-001', 'Blue Widget', 3, 29.99);

INSERT INTO app_user.ORDER_ITEMS (order_id, product_sku, product_name, quantity, unit_price)
VALUES (1, 'GADGET-007', 'Smart Gadget', 1, 59.99);

INSERT INTO app_user.ORDER_ITEMS (order_id, product_sku, product_name, quantity, unit_price)
VALUES (2, 'WIDGET-002', 'Red Widget', 2, 29.75);

INSERT INTO app_user.ORDER_ITEMS (order_id, product_sku, product_name, quantity, unit_price)
VALUES (3, 'DEVICE-X1', 'Smart Device X1', 1, 299.00);

INSERT INTO app_user.ORDER_ITEMS (order_id, product_sku, product_name, quantity, unit_price)
VALUES (4, 'CABLE-USB3', 'USB-C Cable 2m', 3, 25.00);

COMMIT;
