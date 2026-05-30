const express = require('express');
const router = express.Router();
const { jwtAuth, apiKeyAuth } = require('../middleware/auth');
const { getDB } = require('../db/database');

// GET /api/messages — lista de conversaciones únicas
router.get('/', jwtAuth, (req, res) => {
  const db = getDB();
  const convs = db.prepare(`
    SELECT m.phone, m.customer_name,
      (SELECT content FROM messages WHERE phone=m.phone ORDER BY created_at DESC LIMIT 1) as last_msg,
      (SELECT created_at FROM messages WHERE phone=m.phone ORDER BY created_at DESC LIMIT 1) as last_at,
      (SELECT COUNT(*) FROM messages WHERE phone=m.phone AND direction='inbound' AND sent=0) as unread
    FROM messages m
    GROUP BY m.phone
    ORDER BY last_at DESC
  `).all();
  res.json(convs);
});

// GET /api/messages/:phone — mensajes de un cliente
router.get('/:phone', jwtAuth, (req, res) => {
  const db = getDB();
  const msgs = db.prepare(`
    SELECT * FROM messages WHERE phone=? ORDER BY created_at ASC
  `).all(req.params.phone);
  res.json(msgs);
});

// POST /api/messages/send — app envía mensaje (bot lo enviará)
router.post('/send', jwtAuth, (req, res) => {
  const { phone, content } = req.body;
  if (!phone || !content) return res.status(400).json({ error: 'phone y content requeridos' });
  const db = getDB();
  const customer = db.prepare('SELECT name FROM customers WHERE phone=?').get(phone);
  const result = db.prepare(`
    INSERT INTO messages (phone, customer_name, content, direction, sent)
    VALUES (?, ?, ?, 'outbound', 0)
  `).run(phone, customer?.name || null, content);
  res.json({ success: true, id: result.lastInsertRowid });
});

// GET /api/messages/outbound/pending — bot polling (API Key)
router.get('/outbound/pending', apiKeyAuth, (req, res) => {
  const db = getDB();
  const pending = db.prepare(`
    SELECT * FROM messages WHERE direction='outbound' AND sent=0 ORDER BY created_at ASC
  `).all();
  res.json(pending);
});

// PUT /api/messages/:id/sent — bot marca como enviado
router.put('/:id/sent', apiKeyAuth, (req, res) => {
  getDB().prepare('UPDATE messages SET sent=1 WHERE id=?').run(req.params.id);
  res.json({ success: true });
});

module.exports = router;
