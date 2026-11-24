CREATE TABLE customers.accounts (
                                    id SERIAL PRIMARY KEY,
                                    name TEXT NOT NULL,
                                    email TEXT NOT NULL,
                                    passwd_hash TEXT NOT NULL
);

ALTER TABLE customers.accounts
    ADD COLUMN deleted boolean DEFAULT false;