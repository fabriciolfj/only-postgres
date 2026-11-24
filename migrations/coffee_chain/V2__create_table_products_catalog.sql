CREATE SEQUENCE products.catalog_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE products.catalog (
    id             integer      NOT NULL DEFAULT nextval('products.catalog_id_seq'::regclass),
    name           varchar(100) NOT NULL,
    description    text         NOT NULL,
    category       text,
    price          numeric(10,2),
    stock_quantity integer,
    CONSTRAINT catalog_pkey PRIMARY KEY (id),
    CONSTRAINT catalog_category_check CHECK (category = ANY (ARRAY['coffee'::text, 'mug'::text, 't-shirt'::text])),
    CONSTRAINT catalog_stock_quantity_check CHECK (stock_quantity >= 0)
);

ALTER SEQUENCE products.catalog_id_seq OWNED BY products.catalog.id;
