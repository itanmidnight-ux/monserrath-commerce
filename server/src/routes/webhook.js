const express = require('express');
const router = express.Router();
const { apiKeyAuth } = require('../middleware/auth');
const { parseOrderMessage } = require('../services/llmParser');
const { getDB } = require('../db/database');

router.post('/message', apiKeyAuth, async (req, res) => {
  const { phone, name, message, timestamp } = req.body;
  if (!phone || !message) return res.status(400).json({ error: 'phone y message requeridos' });

  const db = getDB();

  db.prepare(`INSERT INTO customers (phone, name) VALUES (?, ?)
    ON CONFLICT(phone) DO UPDATE SET name = COALESCE(excluded.name, name)`)
    .run(phone, name || null);

  // Guardar mensaje en historial de conversación
  db.prepare(`INSERT INTO messages (phone, customer_name, content, direction, sent)
    VALUES (?, ?, ?, 'inbound', 1)`)
    .run(phone, name || null, message);

  const customer = db.prepare('SELECT * FROM customers WHERE phone=?').get(phone);

  const parsed = await parseOrderMessage(message, name || phone);

  let productPrice = null;
  if (parsed.product_id) {
    const prod = db.prepare('SELECT price FROM products WHERE id=?').get(parsed.product_id);
    productPrice = prod?.price;
  }

  const result = db.prepare(`INSERT INTO orders
    (customer_id, product_id, product_name, product_price, delivery_address, is_fiado, wa_message, requested_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)`)
    .run(customer.id, parsed.product_id || null, parsed.product_name || 'No detectado',
      productPrice, parsed.delivery_address || 'No especificada',
      parsed.is_fiado ? 1 : 0, message, timestamp || new Date().toISOString());

  const order = db.prepare('SELECT * FROM orders WHERE id=?').get(result.lastInsertRowid);
  res.json({ success: true, order, parsed });
});

module.exports = router;
