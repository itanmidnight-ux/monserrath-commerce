require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { initDB } = require('./db/database');
const { schedulePDFJob } = require('./services/pdfScheduler');

const app = express();
// Helmet con CSP desactivado para que Flutter web funcione
app.use(helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false }));
app.use(cors());
// Servir Flutter web - sin cache para desarrollo
app.use('/app', (req, res, next) => {
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('ngrok-skip-browser-warning', 'true');
  next();
}, require('express').static(__dirname + '/webapp'));
app.use(express.json({ limit: '10mb' }));

app.use('/api/webhook', require('./routes/webhook'));
app.use('/api/products', require('./routes/products'));
app.use('/api/orders', require('./routes/orders'));
app.use('/api/auth', require('./routes/auth'));

app.get('/health', (req, res) => res.json({ status: 'ok', time: new Date().toISOString() }));
app.get('/preview', (req, res) => res.sendFile(require('path').join(__dirname, 'preview.html')));

const PORT = process.env.PORT || 3000;

initDB();
schedulePDFJob();
app.listen(PORT, () => console.log(`Servidor corriendo en puerto ${PORT}`));
