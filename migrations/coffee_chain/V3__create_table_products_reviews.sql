CREATE SEQUENCE products.reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE products.reviews (
    id          bigint NOT NULL DEFAULT nextval('products.reviews_id_seq'::regclass),
    product_id  integer,
    customer_id integer,
    review      text,
    rank        smallint,
    CONSTRAINT reviews_pkey PRIMARY KEY (id)
);

ALTER SEQUENCE products.reviews_id_seq OWNED BY products.reviews.id;
