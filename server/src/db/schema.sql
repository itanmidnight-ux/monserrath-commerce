CREATE TABLE IF NOT EXISTS customers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  phone TEXT UNIQUE NOT NULL,
  name TEXT,
  created_at TEXT DEFAULT (datetime('now','localtime'))
);

CREATE TABLE IF NOT EXISTS products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  aliases TEXT DEFAULT '[]',
  price REAL NOT NULL,
  available INTEGER DEFAULT 1,
  favorite INTEGER DEFAULT 0,
  no_fiado INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now','localtime'))
);

CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  phone TEXT NOT NULL,
  customer_name TEXT,
  content TEXT NOT NULL,
  direction TEXT NOT NULL DEFAULT 'inbound',
  sent INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now','localtime'))
);
CREATE INDEX IF NOT EXISTS idx_messages_phone ON messages(phone);

CREATE TABLE IF NOT EXISTS orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER REFERENCES customers(id),
  product_id INTEGER,
  product_name TEXT NOT NULL,
  product_price REAL,
  delivery_address TEXT,
  is_fiado INTEGER DEFAULT 0,
  status TEXT DEFAULT 'pending',
  wa_message TEXT,
  comment TEXT,
  requested_at TEXT NOT NULL,
  delivered_at TEXT,
  pdf_exported INTEGER DEFAULT 0
);
