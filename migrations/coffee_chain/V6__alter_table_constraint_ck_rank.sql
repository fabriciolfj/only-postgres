alter table products.reviews alter column review set not null, add constraint review_rank_check check (rank between 1 and 5);

ALTER TABLE products.reviews ADD CONSTRAINT products_review_product_id_fk FOREIGN KEY (product_id) REFERENCES products.catalog(id);


ALTER TABLE products.reviews ADD CONSTRAINT products_review_customer_id_fk FOREIGN KEY (customer_id) REFERENCES customers.accounts(id);