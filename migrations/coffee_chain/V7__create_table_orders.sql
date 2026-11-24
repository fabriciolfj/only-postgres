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
                                   PRIMARY KEY (order_id, product_id