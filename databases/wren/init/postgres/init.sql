-- サンプルテーブル作成
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    amount DECIMAL(10, 2),
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(10, 2),
    stock INTEGER
);

CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id),
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER,
    unit_price DECIMAL(10, 2)
);

-- ダミーデータ挿入
INSERT INTO customers (name, email)
SELECT 
    'Customer ' || i,
    'customer' || i || '@example.com'
FROM generate_series(1, 500) AS i;

INSERT INTO products (name, category, price, stock)
SELECT
    'Product ' || i,
    (ARRAY['Electronics', 'Clothing', 'Food', 'Books', 'Home'])[1 + floor(random() * 5)],
    (random() * 500 + 10)::decimal(10,2),
    floor(random() * 1000)::int
FROM generate_series(1, 100) AS i;

INSERT INTO orders (customer_id, amount, order_date)
SELECT 
    floor(random() * 500) + 1,
    (random() * 1000)::decimal(10,2),
    CURRENT_TIMESTAMP - (random() * interval '365 days')
FROM generate_series(1, 1000) AS i;

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT
    floor(random() * 1000) + 1,
    floor(random() * 100) + 1,
    floor(random() * 5) + 1,
    (random() * 500 + 10)::decimal(10,2)
FROM generate_series(1, 2000) AS i;

-- インデックス作成
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
