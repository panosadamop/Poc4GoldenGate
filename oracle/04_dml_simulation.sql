-- =============================================================
-- DML simulation — run this to generate CDC events after the
-- connector is registered and consuming.
-- =============================================================

ALTER SESSION SET CONTAINER = XEPDB1;

-- INSERT: new customer
INSERT INTO app_user.CUSTOMERS (first_name, last_name, email, phone)
VALUES ('Eva', 'Johansson', 'eva.johansson@example.com', '+46-8-9876');
COMMIT;

-- UPDATE: customer email change (triggers an UPDATE event)
UPDATE app_user.CUSTOMERS
SET    email = 'alice.updated@example.com',
       updated_at = SYSTIMESTAMP
WHERE  email = 'alice.nguyen@example.com';
COMMIT;

-- UPDATE: order status progression
UPDATE app_user.ORDERS
SET    status = 'SHIPPED',
       updated_at = SYSTIMESTAMP
WHERE  order_id = 3;
COMMIT;

-- INSERT: new order for the new customer
INSERT INTO app_user.ORDERS (customer_id, total_amount, status)
VALUES (5, 120.00, 'CONFIRMED');
COMMIT;

-- DELETE: cancel an order item (soft via status, then hard delete for demo)
DELETE FROM app_user.ORDER_ITEMS WHERE item_id = 2;
COMMIT;

-- Batch update: mark all delivered orders with updated timestamp
UPDATE app_user.ORDERS
SET    updated_at = SYSTIMESTAMP
WHERE  status = 'DELIVERED';
COMMIT;
