const express = require('express');
const router = express.Router();
const { jwtAuth } = require('../middleware/auth');
const { getDB } = require('../db/database');

router.get('/', jwtAuth, (req, res) => {
  const db = getDB();
  const products = db.prepare('SELECT * FROM products ORDER BY favorite DESC, name ASC').all();
  res.json(products.map(p => ({ ...p, aliases: JSON.parse(p.aliases || '[]') })));
});

router.post('/', jwtAuth, (req, res) => {
  const { name, price, aliases } = req.body;
  if (!name || price == null) return res.status(400).json({ error: 'name y price requeridos' });
  const db = getDB();
  const result = db.prepare('INSERT INTO products (name, price, aliases) VALUES (?, ?, ?)')
    .run(name, price, JSON.stringify(aliases || []));
  const product = db.prepare('SELECT * FROM products WHERE id = ?').get(result.lastInsertRowid);
  res.json({ ...product, aliases: JSON.parse(product.aliases || '[]') });
});

router.put('/:id', jwtAuth, (req, res) => {
  const { name, price, aliases, available, favorite, no_fiado } = req.body;
  const db = getDB();
  db.prepare(`UPDATE products SET
    name = COALESCE(?, name), price = COALESCE(?, price),
    aliases = COALESCE(?, aliases), available = COALESCE(?, available),
    favorite = COALESCE(?, favorite), no_fiado = COALESCE(?, no_fiado)
    WHERE id = ?`)
    .run(name, price, aliases ? JSON.stringify(aliases) : null, available, favorite, no_fiado, req.params.id);
  const product = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
  if (!product) return res.status(404).json({ error: 'No encontrado' });
  res.json({ ...product, aliases: JSON.parse(product.aliases || '[]') });
});

router.delete('/:id', jwtAuth, (req, res) => {
  getDB().prepare('DELETE FROM products WHERE id = ?').run(req.params.id);
  res.json({ success: true });
});

module.exports = router;
