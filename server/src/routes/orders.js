const express = require('express');
const router = express.Router();
const { jwtAuth } = require('../middleware/auth');
const { getDB } = require('../db/database');

router.get('/', jwtAuth, (req, res) => {
  const db = getDB();
  const orders = db.prepare(`
    SELECT o.*, c.phone, c.name as customer_name
    FROM orders o LEFT JOIN customers c ON o.customer_id = c.id
    WHERE o.status = 'pending' ORDER BY o.requested_at DESC
  `).all();
  res.json(orders);
});

router.get('/pending', jwtAuth, (req, res) => {
  const db = getDB();
  const today = new Date().toISOString().split('T')[0];
  const orders = db.prepare(`
    SELECT o.*, c.phone, c.name as customer_name
    FROM orders o LEFT JOIN customers c ON o.customer_id = c.id
    WHERE o.status = 'pending' AND date(o.requested_at) < ? ORDER BY o.requested_at ASC
  `).all(today);
  res.json(orders);
});

router.put('/:id/deliver', jwtAuth, (req, res) => {
  const db = getDB();
  db.prepare(`UPDATE orders SET status='delivered', delivered_at=datetime('now','localtime') WHERE id=?`)
    .run(req.params.id);
  res.json(db.prepare('SELECT * FROM orders WHERE id=?').get(req.params.id));
});

router.put('/:id/comment', jwtAuth, (req, res) => {
  const { comment } = req.body;
  getDB().prepare('UPDATE orders SET comment=? WHERE id=?').run(comment, req.params.id);
  res.json({ success: true });
});

module.exports = router;
