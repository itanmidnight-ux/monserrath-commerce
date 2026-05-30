const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');

router.post('/token', (req, res) => {
  const { pin } = req.body;
  if (pin !== process.env.WORKER_PIN) return res.status(401).json({ error: 'PIN incorrecto' });
  const token = jwt.sign({ role: 'worker' }, process.env.JWT_SECRET, { expiresIn: '24h' });
  res.json({ token });
});

module.exports = router;
