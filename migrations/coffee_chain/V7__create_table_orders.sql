CREATE SCHEMA IF NOT EXISTS sales;

CREATE TABLE sales.orders (
                              id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                              customer_id INT REFERENCES customers.accounts(id),
                              order_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                              total_amount DECIMAL(10, 2)
);

CREATE TABLE sales.order_items (
                                   order_id UUID REFERENCES sales.orders(id),
                                   product_id INT REFERENCES products.catalog(id),
                                   quantity INT CHECK (quantity > 0),
                                   price DECIMAL (10, 2),
                                   PRIMARY KEY (order_id, product_id));


ALTER TABLE sales.orders ADD COLUMN status TEXT DEFAULT 'pending' CHECK (status in ('pending','ordered'));

UPDATE sales.orders SET status = 'ordered';

ALTER TABLE sales.orders  ADD CONSTRAINT one_pending_order_per_customerEXCLUDE USING btree (customer_id WITH =)
WHERE (status = 'pending');



CREATE OR REPLACE FUNCTION sales.order_add_item(customer_id_param INT,
  product_id_param INT, quantity_param INT)
RETURNS TABLE (order_id UUID, prod_id INT,
  quantity INT, prod_price DECIMAL) AS $$
DECLARE
pending_order_id UUID;
BEGIN
SELECT id INTO pending_order_id
FROM sales.orders
WHERE customer_id = customer_id_param
  AND status = 'pending'
    LIMIT 1;

IF pending_order_id IS NULL THEN
        INSERT INTO sales.orders (customer_id, status)
        VALUES (customer_id_param, 'pending')
        RETURNING id INTO pending_order_id;
END IF;

MERGE INTO sales.order_items AS oi
    USING (SELECT id, price FROM products.catalog
           WHERE id = product_id_param) AS prod
    ON oi.product_id = prod.id AND oi.order_id = pending_order_id
    WHEN MATCHED THEN
        UPDATE SET quantity = quantity_param
    WHEN NOT MATCHED THEN
        INSERT (order_id, product_id, quantity, price)
            VALUES (pending_order_id, prod.id, quantity_param, prod.price);

RETURN QUERY
SELECT oi.order_id, oi.product_id, oi.quantity, oi.price as prod_price
FROM sales.order_items as oi
WHERE oi.order_id = pending_order_id;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION sales.order_checkout(customer_id_param INT)
RETURNS TABLE (order_id UUID, customer_id INT, total_amount DECIMAL) AS $$
DECLARE
pending_order_id UUID;
    final_total_amount DECIMAL := 0;
BEGIN
SELECT id INTO pending_order_id
FROM sales.orders as o
WHERE o.customer_id = customer_id_param
  AND status = 'pending'
    LIMIT 1;

IF pending_order_id IS NULL THEN
        RAISE EXCEPTION 'No pending order found for customer %',
          customer_id_param;
END IF;

SELECT SUM(oi.quantity * oi.price) INTO final_total_amount
FROM sales.order_items oi
WHERE oi.order_id = pending_order_id;

UPDATE sales.orders
SET status = 'ordered',
    total_amount = final_total_amount,
    order_date = CURRENT_TIMESTAMP
WHERE id = pending_order_id;

UPDATE products.catalog
SET stock_quantity = stock_quantity - oi.quantity
    FROM sales.order_items oi
WHERE products.catalog.id = oi.product_id
  AND oi.order_id = pending_order_id;

RETURN QUERY
SELECT o.id, o.customer_id, o.total_amount
FROM sales.orders as o
WHERE o.id = pending_order_id;
END;
$$ LANGUAGE plpgsql;



   CREATE OR REPLACE FUNCTION sales.update_order_total()
RETURNS TRIGGER AS $$
BEGIN
UPDATE sales.orders
SET total_amount = (
    SELECT COALESCE(SUM(oi.quantity * oi.price), 0)
    FROM sales.order_items oi
    WHERE oi.order_id = COALESCE(NEW.order_id, OLD.order_id)
)
WHERE id = COALESCE(NEW.order_id, OLD.order_id) AND status = 'pending';

RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trigger_update_order_total
    AFTER INSERT OR UPDATE OR DELETE ON sales.order_items
    FOR EACH ROW
    EXECUTE FUNCTION sales.update_order_total();

CREATE VIEW sales.product_sales_summary AS
SELECT
    c.name AS product_name,
    c.category,
    SUM(oi.quantity) AS total_quantity_sold,
    SUM(oi.quantity * oi.price) AS total_revenue
FROM products.catalog c
         LEFT JOIN sales.order_items oi ON c.id = oi.product_id
GROUP BY c.id
ORDER BY total_quantity_sold DESC, total_revenue DESC;



CREATE MATERIALIZED VIEW sales.monthly_sales_summary AS
SELECT
    date_trunc('month', o.order_date) AS sales_month,
    SUM(oi.quantity * oi.price) AS total_revenue,
    COUNT(DISTINCT(o.id)) AS total_orders
FROM sales.orders o
         JOIN sales.order_items oi ON o.id = oi.order_id
GROUP BY sales_month
ORDER BY sales_month;

REFRESH MATERIALIZED VIEW sales.monthly_sales_summary;


CREATE ROLE coffee_chain_admin WITH LOGIN PASSWORD 'password';

GRANT CONNECT ON DATABASE coffee_chain TO coffee_chain_admin;

REVOKE CONNECT ON DATABASE coffee_chain FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO coffee_chain_admin;
GRANT USAGE ON SCHEMA products TO coffee_chain_admin;
GRANT USAGE ON SCHEMA customers TO coffee_chain_admin;
GRANT USAGE ON SCHEMA sales TO coffee_chain_admin;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES
    IN SCHEMA public TO coffee_chain_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES
    IN SCHEMA products TO coffee_chain_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES
    IN SCHEMA customers TO coffee_chain_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES
    IN SCHEMA sales TO coffee_chain_admin;

GRANT USAGE, SELECT ON ALL SEQUENCES
    IN SCHEMA products TO coffee_chain_admin;
GRANT USAGE, SELECT ON ALL SEQUENCES
    IN SCHEMA customers TO coffee_chain_admin;
GRANT USAGE, SELECT ON ALL SEQUENCES
    IN SCHEMA sales TO coffee_chain_admin;
