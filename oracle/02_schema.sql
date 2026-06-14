-- =============================================================
-- Application schema — run as app_user in XEPDB1
-- =============================================================

ALTER SESSION SET CONTAINER = XEPDB1;

-- Enable table-level supplemental logging so Debezium captures
-- full before/after images for UPDATE and DELETE events.
-- (Must be run as a DBA after tables are created.)

-- -------------------------------------------------------------
-- CUSTOMERS
-- -------------------------------------------------------------
CREATE TABLE app_user.CUSTOMERS (
  customer_id   NUMBER(10)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  first_name    VARCHAR2(50)  NOT NULL,
  last_name     VARCHAR2(50)  NOT NULL,
  email         VARCHAR2(100) NOT NULL UNIQUE,
  phone         VARCHAR2(20),
  created_at    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  status        VARCHAR2(10)  DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE'))
);

ALTER TABLE app_user.CUSTOMERS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- -------------------------------------------------------------
-- ORDERS
-- -------------------------------------------------------------
CREATE TABLE app_user.ORDERS (
  order_id      NUMBER(10)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id   NUMBER(10)    NOT NULL REFERENCES app_user.CUSTOMERS(customer_id),
  order_date    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  total_amount  NUMBER(12, 2) NOT NULL,
  status        VARCHAR2(20)  DEFAULT 'PENDING'
                              CHECK (status IN ('PENDING','CONFIRMED','SHIPPED','DELIVERED','CANCELLED')),
  updated_at    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL
);

ALTER TABLE app_user.ORDERS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- -------------------------------------------------------------
-- ORDER_ITEMS
-- -------------------------------------------------------------
CREATE TABLE app_user.ORDER_ITEMS (
  item_id       NUMBER(10)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id      NUMBER(10)    NOT NULL REFERENCES app_user.ORDERS(order_id),
  product_sku   VARCHAR2(50)  NOT NULL,
  product_name  VARCHAR2(200) NOT NULL,
  quantity      NUMBER(6)     NOT NULL CHECK (quantity > 0),
  unit_price    NUMBER(10, 2) NOT NULL CHECK (unit_price >= 0),
  line_total    NUMBER(12, 2) GENERATED ALWAYS AS (quantity * unit_price) VIRTUAL
);

ALTER TABLE app_user.ORDER_ITEMS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

COMMIT;
