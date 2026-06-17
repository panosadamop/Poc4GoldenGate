-- =============================================================
-- Target schema — run as app_user in XEPDB1
-- Differences from source:
--   - No GENERATED ALWAYS AS IDENTITY (PKs populated by replication)
--   - No VIRTUAL columns (line_total stored as plain NUMBER)
--   - No FK constraints (rows may arrive out of order)
--   - No CHECK constraints (data already validated at source)
-- =============================================================

CREATE TABLE app_user.CUSTOMERS (
  customer_id   NUMBER(10)     PRIMARY KEY,
  first_name    VARCHAR2(50),
  last_name     VARCHAR2(50),
  email         VARCHAR2(100),
  phone         VARCHAR2(20),
  created_at    TIMESTAMP,
  updated_at    TIMESTAMP,
  status        VARCHAR2(10)
);

CREATE TABLE app_user.ORDERS (
  order_id      NUMBER(10)    PRIMARY KEY,
  customer_id   NUMBER(10),
  order_date    TIMESTAMP,
  total_amount  NUMBER(12, 2),
  status        VARCHAR2(20),
  updated_at    TIMESTAMP
);

CREATE TABLE app_user.ORDER_ITEMS (
  item_id       NUMBER(10)    PRIMARY KEY,
  order_id      NUMBER(10),
  product_sku   VARCHAR2(50),
  product_name  VARCHAR2(200),
  quantity      NUMBER(6),
  unit_price    NUMBER(10, 2),
  line_total    NUMBER(12, 2)
);

COMMIT;
