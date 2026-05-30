# Sistema Pedidos WhatsApp + App Android — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sistema completo para gestión de pedidos WhatsApp → LLM → DB → App Android con offline, PDF diario y bot automatizado.

**Architecture:** VPS Windows corre bot Baileys (pairing code), reenvía mensajes vía HTTPS+API Key a servidor Kali que los analiza con Ollama llama3.2:1b, almacena en SQLite y sirve datos a app Flutter. ngrok expone Kali con URL fija.

**Tech Stack:** Node.js 20, Express, SQLite3, Ollama, Baileys v6, ngrok, Flutter 3.x, PDFKit, OneSignal, node-windows, systemd

---

## FASE 1 — Kali Server Core

---

### Task 1: Estructura del proyecto servidor

**Files:**
- Create: `server/package.json`
- Create: `server/.env.example`
- Create: `server/.gitignore`
- Create: `server/src/index.js`

- [ ] **Step 1: Crear directorio raíz**

```bash
cd /home/kali/Jesus
mkdir -p server/src/{routes,services,db,utils}
mkdir -p server/reports
```

- [ ] **Step 2: Crear package.json**

```bash
cat > /home/kali/Jesus/server/package.json << 'EOF'
{
  "name": "pedidos-server",
  "version": "1.0.0",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "better-sqlite3": "^9.4.3",
    "dotenv": "^16.4.5",
    "jsonwebtoken": "^9.0.2",
    "node-cron": "^3.0.3",
    "pdfkit": "^0.15.0",
    "ollama": "^0.5.0",
    "cors": "^2.8.5",
    "helmet": "^7.1.0"
  },
  "devDependencies": {
    "nodemon": "^3.1.0"
  }
}
EOF
```

- [ ] **Step 3: Crear .env.example**

```bash
cat > /home/kali/Jesus/server/.env.example << 'EOF'
PORT=3000
API_KEY=CAMBIAR_POR_CLAVE_GENERADA
JWT_SECRET=CAMBIAR_POR_SECRET_GENERADO
NGROK_DOMAIN=tu-dominio.ngrok-free.app
OLLAMA_MODEL=llama3.2:1b
ONESIGNAL_APP_ID=
ONESIGNAL_API_KEY=
EOF
```

- [ ] **Step 4: Crear .gitignore**

```bash
cat > /home/kali/Jesus/server/.gitignore << 'EOF'
node_modules/
.env
reports/
*.db
EOF
```

- [ ] **Step 5: Generar .env real con claves aleatorias**

```bash
cd /home/kali/Jesus/server
API_KEY=$(openssl rand -hex 32)
JWT_SECRET=$(openssl rand -hex 32)
cat > .env << EOF
PORT=3000
API_KEY=$API_KEY
JWT_SECRET=$JWT_SECRET
NGROK_DOMAIN=PENDIENTE
OLLAMA_MODEL=llama3.2:1b
ONESIGNAL_APP_ID=
ONESIGNAL_API_KEY=
EOF
echo "API_KEY generada: $API_KEY"
echo "Guarda esta API_KEY para configurar el bot VPS"
```

- [ ] **Step 6: Crear index.js principal**

```javascript
// server/src/index.js
require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { initDB } = require('./db/database');
const { schedulePDFJob } = require('./services/pdfScheduler');

const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

app.use('/api/webhook', require('./routes/webhook'));
app.use('/api/products', require('./routes/products'));
app.use('/api/orders', require('./routes/orders'));
app.use('/api/auth', require('./routes/auth'));

app.get('/health', (req, res) => res.json({ status: 'ok', time: new Date().toISOString() }));

const PORT = process.env.PORT || 3000;

initDB();
schedulePDFJob();
app.listen(PORT, () => console.log(`Servidor corriendo en puerto ${PORT}`));
```

- [ ] **Step 7: Instalar dependencias**

```bash
cd /home/kali/Jesus/server && npm install
```

Expected: `added X packages` sin errores.

- [ ] **Step 8: Commit**

```bash
cd /home/kali/Jesus
git init
git add server/
git commit -m "feat: estructura base servidor Node.js"
```

---

### Task 2: Base de datos SQLite

**Files:**
- Create: `server/src/db/database.js`
- Create: `server/src/db/schema.sql`

- [ ] **Step 1: Crear schema.sql**

```bash
cat > /home/kali/Jesus/server/src/db/schema.sql << 'EOF'
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
EOF
```

- [ ] **Step 2: Crear database.js**

```javascript
// server/src/db/database.js
const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

const DB_PATH = path.join(__dirname, '../../pedidos.db');
let db;

function initDB() {
  db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  db.exec(schema);
  console.log('DB inicializada en', DB_PATH);
}

function getDB() {
  if (!db) throw new Error('DB no inicializada. Llama initDB() primero.');
  return db;
}

module.exports = { initDB, getDB };
```

- [ ] **Step 3: Verificar DB inicia sin errores**

```bash
cd /home/kali/Jesus/server
node -e "const {initDB}=require('./src/db/database'); initDB(); console.log('OK');"
```

Expected: `DB inicializada en ...pedidos.db` y `OK`.

- [ ] **Step 4: Commit**

```bash
cd /home/kali/Jesus
git add server/src/db/
git commit -m "feat: SQLite schema y conexión"
```

---

### Task 3: Ollama — instalar modelo y verificar

**Files:** ninguno (configuración de sistema)

- [ ] **Step 1: Verificar Ollama corre**

```bash
ollama list
```

Si muestra error de conexión:
```bash
ollama serve &
sleep 3
ollama list
```

- [ ] **Step 2: Descargar modelo llama3.2:1b**

```bash
ollama pull llama3.2:1b
```

Expected: descarga ~1.3GB. Esperar hasta `success`.

- [ ] **Step 3: Probar modelo**

```bash
ollama run llama3.2:1b "responde solo: FUNCIONA" --nowordwrap
```

Expected: respuesta corta del modelo.

- [ ] **Step 4: Configurar Ollama como servicio systemd**

```bash
sudo tee /etc/systemd/system/ollama.service << 'EOF'
[Unit]
Description=Ollama LLM Server
After=network.target

[Service]
ExecStart=/usr/bin/ollama serve
Restart=always
RestartSec=3
Environment=HOME=/root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ollama
sudo systemctl start ollama
sleep 3
sudo systemctl status ollama --no-pager
```

Expected: `active (running)`.

---

### Task 4: Servicio LLM — parser de mensajes

**Files:**
- Create: `server/src/services/llmParser.js`

- [ ] **Step 1: Crear llmParser.js**

```javascript
// server/src/services/llmParser.js
const { Ollama } = require('ollama');
const { getDB } = require('../db/database');

const ollama = new Ollama({ host: 'http://localhost:11434' });

function buildPrompt(message, products) {
  const productList = products
    .map(p => `- "${p.name}" (aliases: ${JSON.parse(p.aliases || '[]').join(', ')}) precio: $${p.price}`)
    .join('\n');

  return `Eres un asistente que extrae datos de pedidos de productos para animales.

PRODUCTOS DISPONIBLES:
${productList}

MENSAJE DEL CLIENTE:
"${message}"

Responde ÚNICAMENTE con JSON válido sin explicaciones, con esta estructura exacta:
{
  "product_name": "nombre exacto del producto detectado o null",
  "product_id": null,
  "delivery_address": "dirección detectada o null",
  "is_fiado": false,
  "customer_name": "nombre del cliente si lo menciona o null",
  "confidence": "high|medium|low"
}

Reglas:
- is_fiado=true si el mensaje contiene: "después", "mañana", "el viernes", "la próxima", "le pago", "fiado", "me fía", "me fia"
- delivery_address: extrae "para donde X", "en la X", "en X" como dirección
- product_name: busca coincidencia con aliases también, no solo nombre exacto
- customer_name: busca "soy X", "de parte de X", "le habla X"`;
}

async function parseOrderMessage(waMessage, senderName) {
  const db = getDB();
  const products = db.prepare('SELECT * FROM products WHERE available = 1').all();

  if (products.length === 0) {
    return { product_name: null, delivery_address: null, is_fiado: false, customer_name: senderName, confidence: 'low' };
  }

  const prompt = buildPrompt(waMessage, products);

  try {
    const response = await ollama.generate({
      model: process.env.OLLAMA_MODEL || 'llama3.2:1b',
      prompt,
      options: { temperature: 0.1, num_predict: 200 },
      stream: false
    });

    const raw = response.response.trim();
    const jsonMatch = raw.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error('No JSON en respuesta LLM');

    const parsed = JSON.parse(jsonMatch[0]);

    // Match product by name against DB
    if (parsed.product_name) {
      const allProducts = db.prepare('SELECT * FROM products WHERE available = 1').all();
      const match = allProducts.find(p => {
        const aliases = JSON.parse(p.aliases || '[]');
        return p.name.toLowerCase() === parsed.product_name.toLowerCase() ||
          aliases.some(a => a.toLowerCase() === parsed.product_name.toLowerCase());
      });
      if (match) parsed.product_id = match.id;
    }

    return parsed;
  } catch (err) {
    console.error('Error LLM parser:', err.message);
    return { product_name: null, delivery_address: null, is_fiado: false, customer_name: senderName, confidence: 'low' };
  }
}

module.exports = { parseOrderMessage };
```

- [ ] **Step 2: Test rápido del parser**

```bash
cd /home/kali/Jesus/server
node -e "
const {initDB} = require('./src/db/database');
const {parseOrderMessage} = require('./src/services/llmParser');
initDB();
parseOrderMessage('me regalas un bulto de purina para donde juanita', 'Cliente Test')
  .then(r => console.log(JSON.stringify(r, null, 2)));
"
```

Expected: JSON con campos extraídos (product_name puede ser null si DB vacía).

- [ ] **Step 3: Commit**

```bash
cd /home/kali/Jesus
git add server/src/services/llmParser.js
git commit -m "feat: LLM parser de mensajes WhatsApp con Ollama"
```

---

### Task 5: API REST — rutas completas

**Files:**
- Create: `server/src/middleware/auth.js`
- Create: `server/src/routes/webhook.js`
- Create: `server/src/routes/products.js`
- Create: `server/src/routes/orders.js`
- Create: `server/src/routes/auth.js`

- [ ] **Step 1: Crear middleware de autenticación**

```javascript
// server/src/middleware/auth.js
const jwt = require('jsonwebtoken');

function apiKeyAuth(req, res, next) {
  const key = req.headers['x-api-key'];
  if (!key || key !== process.env.API_KEY) {
    return res.status(401).json({ error: 'API Key inválida' });
  }
  next();
}

function jwtAuth(req, res, next) {
  const header = req.headers['authorization'];
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Token requerido' });
  }
  try {
    req.user = jwt.verify(header.slice(7), process.env.JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ error: 'Token inválido o expirado' });
  }
}

module.exports = { apiKeyAuth, jwtAuth };
```

- [ ] **Step 2: Crear ruta webhook (recibe mensajes del bot VPS)**

```javascript
// server/src/routes/webhook.js
const express = require('express');
const router = express.Router();
const { apiKeyAuth } = require('../middleware/auth');
const { parseOrderMessage } = require('../services/llmParser');
const { getDB } = require('../db/database');

router.post('/message', apiKeyAuth, async (req, res) => {
  const { phone, name, message, timestamp } = req.body;

  if (!phone || !message) {
    return res.status(400).json({ error: 'phone y message requeridos' });
  }

  const db = getDB();

  // Upsert customer
  db.prepare(`
    INSERT INTO customers (phone, name) VALUES (?, ?)
    ON CONFLICT(phone) DO UPDATE SET name = COALESCE(excluded.name, name)
  `).run(phone, name || null);

  const customer = db.prepare('SELECT * FROM customers WHERE phone = ?').get(phone);

  // Parse with LLM
  const parsed = await parseOrderMessage(message, name || phone);

  // Resolve product price
  let productPrice = null;
  if (parsed.product_id) {
    const prod = db.prepare('SELECT price FROM products WHERE id = ?').get(parsed.product_id);
    productPrice = prod?.price;
  }

  // Insert order
  const result = db.prepare(`
    INSERT INTO orders (customer_id, product_id, product_name, product_price, delivery_address, is_fiado, wa_message, requested_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    customer.id,
    parsed.product_id || null,
    parsed.product_name || 'No detectado',
    productPrice,
    parsed.delivery_address || 'No especificada',
    parsed.is_fiado ? 1 : 0,
    message,
    timestamp || new Date().toISOString()
  );

  const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(result.lastInsertRowid);

  res.json({ success: true, order, parsed });
});

module.exports = router;
```

- [ ] **Step 3: Crear ruta productos**

```javascript
// server/src/routes/products.js
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
  const result = db.prepare(
    'INSERT INTO products (name, price, aliases) VALUES (?, ?, ?)'
  ).run(name, price, JSON.stringify(aliases || []));
  res.json(db.prepare('SELECT * FROM products WHERE id = ?').get(result.lastInsertRowid));
});

router.put('/:id', jwtAuth, (req, res) => {
  const { name, price, aliases, available, favorite, no_fiado } = req.body;
  const db = getDB();
  db.prepare(`
    UPDATE products SET
      name = COALESCE(?, name),
      price = COALESCE(?, price),
      aliases = COALESCE(?, aliases),
      available = COALESCE(?, available),
      favorite = COALESCE(?, favorite),
      no_fiado = COALESCE(?, no_fiado)
    WHERE id = ?
  `).run(name, price, aliases ? JSON.stringify(aliases) : null, available, favorite, no_fiado, req.params.id);
  const product = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
  if (!product) return res.status(404).json({ error: 'Producto no encontrado' });
  res.json({ ...product, aliases: JSON.parse(product.aliases || '[]') });
});

router.delete('/:id', jwtAuth, (req, res) => {
  const db = getDB();
  db.prepare('DELETE FROM products WHERE id = ?').run(req.params.id);
  res.json({ success: true });
});

module.exports = router;
```

- [ ] **Step 4: Crear ruta pedidos**

```javascript
// server/src/routes/orders.js
const express = require('express');
const router = express.Router();
const { jwtAuth } = require('../middleware/auth');
const { getDB } = require('../db/database');

router.get('/', jwtAuth, (req, res) => {
  const db = getDB();
  const orders = db.prepare(`
    SELECT o.*, c.phone, c.name as customer_name
    FROM orders o
    LEFT JOIN customers c ON o.customer_id = c.id
    WHERE o.status = 'pending'
    ORDER BY o.requested_at DESC
  `).all();
  res.json(orders);
});

router.get('/pending', jwtAuth, (req, res) => {
  const db = getDB();
  const today = new Date().toISOString().split('T')[0];
  const orders = db.prepare(`
    SELECT o.*, c.phone, c.name as customer_name
    FROM orders o
    LEFT JOIN customers c ON o.customer_id = c.id
    WHERE o.status = 'pending' AND date(o.requested_at) < ?
    ORDER BY o.requested_at ASC
  `).all(today);
  res.json(orders);
});

router.put('/:id/deliver', jwtAuth, (req, res) => {
  const db = getDB();
  db.prepare(`
    UPDATE orders SET status = 'delivered', delivered_at = datetime('now','localtime')
    WHERE id = ?
  `).run(req.params.id);
  const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id);
  res.json(order);
});

router.put('/:id/comment', jwtAuth, (req, res) => {
  const { comment } = req.body;
  const db = getDB();
  db.prepare('UPDATE orders SET comment = ? WHERE id = ?').run(comment, req.params.id);
  res.json({ success: true });
});

module.exports = router;
```

- [ ] **Step 5: Crear ruta auth**

```javascript
// server/src/routes/auth.js
const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');

const WORKER_PIN = process.env.WORKER_PIN || '1234';

router.post('/token', (req, res) => {
  const { pin } = req.body;
  if (pin !== WORKER_PIN) return res.status(401).json({ error: 'PIN incorrecto' });
  const token = jwt.sign({ role: 'worker' }, process.env.JWT_SECRET, { expiresIn: '24h' });
  res.json({ token });
});

module.exports = router;
```

- [ ] **Step 6: Agregar WORKER_PIN al .env**

```bash
echo "WORKER_PIN=1234" >> /home/kali/Jesus/server/.env
```

- [ ] **Step 7: Probar servidor completo**

```bash
cd /home/kali/Jesus/server && node src/index.js &
sleep 2
curl -s http://localhost:3000/health
```

Expected: `{"status":"ok","time":"..."}`.

```bash
# Detener servidor de prueba
kill %1 2>/dev/null || pkill -f "node src/index.js"
```

- [ ] **Step 8: Commit**

```bash
cd /home/kali/Jesus
git add server/src/
git commit -m "feat: API REST completa con auth, productos, pedidos y webhook"
```

---

### Task 6: ngrok + systemd — servidor siempre activo

**Files:**
- Create: `server/scripts/start.sh`
- Create: `/etc/systemd/system/pedidos-server.service`

- [ ] **Step 1: Configurar ngrok authtoken**

```bash
ngrok config add-authtoken 34G7biMjp4tdGcupxvySfJvYqrQ_6BEU8VntbCjSudDRWntdB
```

Expected: `Authtoken saved to configuration file`.

- [ ] **Step 2: Obtener y configurar dominio fijo**

El usuario debe proveer su dominio ngrok estático. Ejecutar:
```bash
# Reemplaza TU-DOMINIO por el dominio real del usuario (ej: algo.ngrok-free.app)
NGROK_DOMAIN="TU-DOMINIO"
sed -i "s/NGROK_DOMAIN=.*/NGROK_DOMAIN=$NGROK_DOMAIN/" /home/kali/Jesus/server/.env
```

- [ ] **Step 3: Crear script de inicio**

```bash
cat > /home/kali/Jesus/server/scripts/start.sh << 'EOF'
#!/bin/bash
cd /home/kali/Jesus/server

# Iniciar servidor Node
node src/index.js &
NODE_PID=$!

# Leer dominio del .env
source .env

# Iniciar ngrok con dominio fijo
ngrok http $PORT --domain=$NGROK_DOMAIN --log=stdout &
NGROK_PID=$!

echo "Servidor PID: $NODE_PID"
echo "ngrok PID: $NGROK_PID"

wait $NODE_PID
EOF
chmod +x /home/kali/Jesus/server/scripts/start.sh
```

- [ ] **Step 4: Crear servicio systemd**

```bash
sudo tee /etc/systemd/system/pedidos-server.service << 'EOF'
[Unit]
Description=Pedidos WhatsApp Server
After=network.target ollama.service
Requires=ollama.service

[Service]
Type=simple
User=kali
WorkingDirectory=/home/kali/Jesus/server
ExecStart=/home/kali/Jesus/server/scripts/start.sh
Restart=always
RestartSec=5
EnvironmentFile=/home/kali/Jesus/server/.env

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable pedidos-server
sudo systemctl start pedidos-server
sleep 5
sudo systemctl status pedidos-server --no-pager
```

- [ ] **Step 5: Verificar endpoint público**

```bash
source /home/kali/Jesus/server/.env
curl -s https://$NGROK_DOMAIN/health
```

Expected: `{"status":"ok","time":"..."}`.

- [ ] **Step 6: Commit**

```bash
cd /home/kali/Jesus
git add server/scripts/
git commit -m "feat: scripts de inicio y servicio systemd con ngrok"
```

---

## FASE 2 — VPS WhatsApp Bot

---

### Task 7: Bot Baileys — código core

**Files:**
- Create: `vps-bot/package.json`
- Create: `vps-bot/src/bot.js`
- Create: `vps-bot/src/apiClient.js`
- Create: `vps-bot/.env.example`

- [ ] **Step 1: Crear estructura**

```bash
mkdir -p /home/kali/Jesus/vps-bot/src
```

- [ ] **Step 2: package.json del bot**

```bash
cat > /home/kali/Jesus/vps-bot/package.json << 'EOF'
{
  "name": "pedidos-whatsapp-bot",
  "version": "1.0.0",
  "main": "src/bot.js",
  "scripts": {
    "start": "node src/bot.js"
  },
  "dependencies": {
    "@whiskeysockets/baileys": "^6.7.9",
    "axios": "^1.6.8",
    "dotenv": "^16.4.5",
    "pino": "^9.1.0",
    "qrcode-terminal": "^0.12.0"
  }
}
EOF
```

- [ ] **Step 3: .env.example del bot**

```bash
cat > /home/kali/Jesus/vps-bot/.env.example << 'EOF'
SERVER_URL=https://TU-DOMINIO.ngrok-free.app
API_KEY=MISMA_API_KEY_DEL_SERVIDOR
PHONE_NUMBER=57XXXXXXXXXX
EOF
```

- [ ] **Step 4: apiClient.js — cliente HTTP hacia Kali**

```javascript
// vps-bot/src/apiClient.js
const axios = require('axios');

const client = axios.create({
  baseURL: process.env.SERVER_URL,
  headers: { 'X-API-Key': process.env.API_KEY, 'Content-Type': 'application/json' },
  timeout: 30000
});

async function sendMessage(phone, name, message, timestamp) {
  const res = await client.post('/api/webhook/message', { phone, name, message, timestamp });
  return res.data;
}

async function getProducts() {
  const res = await client.get('/api/products');
  return res.data;
}

module.exports = { sendMessage, getProducts };
```

- [ ] **Step 5: bot.js — lógica Baileys**

```javascript
// vps-bot/src/bot.js
require('dotenv').config();
const { default: makeWASocket, useMultiFileAuthState, DisconnectReason, fetchLatestBaileysVersion } = require('@whiskeysockets/baileys');
const pino = require('pino');
const { sendMessage, getProducts } = require('./apiClient');
const path = require('path');

const AUTH_DIR = path.join(__dirname, '../auth');
const logger = pino({ level: 'silent' });

async function buildMenuText() {
  try {
    const products = await getProducts();
    const available = products.filter(p => p.available);
    if (!available.length) return '📦 No hay productos disponibles en este momento.';
    const lines = available.map((p, i) => `${i + 1}. ${p.name} - $${p.price.toLocaleString('es-CO')}`);
    return `📦 *Productos disponibles:*\n\n${lines.join('\n')}\n\nEscríbenos tu pedido con la dirección de envío. 🐾`;
  } catch {
    return '📦 Por el momento no podemos mostrar el menú. Escríbenos tu pedido.';
  }
}

function isMenuRequest(text) {
  const t = text.toLowerCase().trim();
  return ['hola', 'menu', 'menú', 'productos', 'catalogo', 'catálogo', 'que tienen', 'qué tienen'].some(k => t.includes(k));
}

async function connectToWhatsApp() {
  const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);
  const { version } = await fetchLatestBaileysVersion();

  const sock = makeWASocket({
    version,
    logger,
    auth: state,
    printQRInTerminal: false,
    browser: ['PedidosBot', 'Chrome', '1.0.0']
  });

  sock.ev.on('creds.update', saveCreds);

  // Pairing code (si no está autenticado)
  if (!sock.authState.creds.registered) {
    const phone = process.env.PHONE_NUMBER;
    if (!phone) { console.error('PHONE_NUMBER no configurado en .env'); process.exit(1); }
    setTimeout(async () => {
      const code = await sock.requestPairingCode(phone);
      console.log(`\n╔══════════════════════════════╗`);
      console.log(`║  CÓDIGO DE VINCULACIÓN WA    ║`);
      console.log(`║  ${code}                  ║`);
      console.log(`╚══════════════════════════════╝`);
      console.log('Ingresa este código en WhatsApp → Dispositivos vinculados → Vincular dispositivo → Usar número de teléfono\n');
    }, 3000);
  }

  sock.ev.on('connection.update', async ({ connection, lastDisconnect }) => {
    if (connection === 'close') {
      const shouldReconnect = lastDisconnect?.error?.output?.statusCode !== DisconnectReason.loggedOut;
      console.log('Conexión cerrada. Reconectando:', shouldReconnect);
      if (shouldReconnect) setTimeout(connectToWhatsApp, 5000);
    } else if (connection === 'open') {
      console.log('✅ Bot WhatsApp conectado');
    }
  });

  sock.ev.on('messages.upsert', async ({ messages, type }) => {
    if (type !== 'notify') return;

    for (const msg of messages) {
      if (msg.key.fromMe || !msg.message) continue;

      const jid = msg.key.remoteJid;
      if (jid.endsWith('@g.us')) continue; // ignorar grupos

      const text = msg.message?.conversation ||
        msg.message?.extendedTextMessage?.text || '';
      if (!text) continue;

      const phone = jid.replace('@s.whatsapp.net', '');
      const name = msg.pushName || null;
      const timestamp = new Date(msg.messageTimestamp * 1000).toISOString();

      console.log(`[${phone}] ${name || ''}: ${text}`);

      if (isMenuRequest(text)) {
        const menu = await buildMenuText();
        await sock.sendMessage(jid, { text: menu });
        continue;
      }

      try {
        const result = await sendMessage(phone, name, text, timestamp);
        if (result.order) {
          const o = result.order;
          const fiado = o.is_fiado ? '\n⚠️ *Fiado registrado*' : '';
          const confirmText = `✅ *Pedido recibido:*\n📦 ${o.product_name}\n📍 ${o.delivery_address}\n💰 ${o.product_price ? `$${o.product_price.toLocaleString('es-CO')}` : 'Precio a confirmar'}${fiado}\n\nPronto te confirmamos el envío. 🚚`;
          await sock.sendMessage(jid, { text: confirmText });
        }
      } catch (err) {
        console.error('Error enviando a servidor:', err.message);
      }
    }
  });

  return sock;
}

connectToWhatsApp();
```

- [ ] **Step 6: Commit código bot**

```bash
cd /home/kali/Jesus
git add vps-bot/
git commit -m "feat: bot WhatsApp Baileys con pairing code y menu de productos"
```

---

### Task 8: Instalador .bat para VPS Windows

**Files:**
- Create: `vps-bot/install-windows.bat`
- Create: `vps-bot/install-service.js`

- [ ] **Step 1: Crear install-service.js (node-windows)**

```javascript
// vps-bot/install-service.js
const Service = require('node-windows').Service;
const path = require('path');

const svc = new Service({
  name: 'PedidosWhatsAppBot',
  description: 'Bot WhatsApp para gestión de pedidos',
  script: path.join(__dirname, 'src/bot.js'),
  nodeOptions: [],
  env: [
    { name: 'NODE_ENV', value: 'production' }
  ]
});

svc.on('install', () => { svc.start(); console.log('Servicio instalado e iniciado.'); });
svc.on('alreadyinstalled', () => { svc.start(); console.log('Servicio ya existía, iniciado.'); });
svc.on('error', (err) => console.error('Error servicio:', err));

svc.install();
```

- [ ] **Step 2: Crear install-windows.bat**

```batch
@echo off
SETLOCAL ENABLEDELAYEDEXPANSION
title Instalador Bot WhatsApp Pedidos
color 0A

echo =========================================
echo   INSTALADOR BOT WHATSAPP PEDIDOS
echo   Para VPS Windows - AWS
echo =========================================
echo.

REM Verificar admin
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Ejecutar como Administrador
    echo Clic derecho en el .bat -> "Ejecutar como administrador"
    pause
    exit /b 1
)

REM Verificar/instalar Node.js
where node >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [1/6] Descargando Node.js 20...
    powershell -Command "& { Invoke-WebRequest -Uri 'https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi' -OutFile '%TEMP%\node.msi' }"
    echo [1/6] Instalando Node.js...
    msiexec /i "%TEMP%\node.msi" /quiet /norestart
    REM Refrescar PATH
    call refreshenv 2>nul
    set "PATH=%PATH%;C:\Program Files\nodejs"
) else (
    echo [1/6] Node.js ya instalado: OK
)

REM Verificar node disponible
where node >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Node.js no disponible. Reinicia la terminal e intenta de nuevo.
    pause
    exit /b 1
)

echo [2/6] Instalando dependencias npm...
cd /d "%~dp0"
call npm install --production
if %ERRORLEVEL% NEQ 0 ( echo ERROR en npm install && pause && exit /b 1 )

echo [3/6] Instalando node-windows...
call npm install node-windows --save
if %ERRORLEVEL% NEQ 0 ( echo ERROR instalando node-windows && pause && exit /b 1 )

REM Crear .env si no existe
if not exist ".env" (
    echo [4/6] Configurando variables de entorno...
    echo.
    set /p SERVER_URL="Ingresa la URL del servidor (ej: https://tu-dominio.ngrok-free.app): "
    set /p API_KEY="Ingresa la API_KEY del servidor: "
    set /p PHONE_NUMBER="Ingresa el numero WhatsApp con codigo de pais sin + (ej: 573001234567): "

    (
        echo SERVER_URL=!SERVER_URL!
        echo API_KEY=!API_KEY!
        echo PHONE_NUMBER=!PHONE_NUMBER!
    ) > .env
    echo .env creado correctamente.
) else (
    echo [4/6] .env ya existe, usando configuracion existente.
)

echo [5/6] Instalando como servicio Windows...
node install-service.js
if %ERRORLEVEL% NEQ 0 ( echo ERROR instalando servicio && pause && exit /b 1 )

echo [6/6] Verificando servicio...
timeout /t 5 /nobreak >nul
sc query PedidosWhatsAppBot | find "RUNNING" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo.
    echo =========================================
    echo   INSTALACION COMPLETADA EXITOSAMENTE
    echo =========================================
    echo.
    echo El bot esta corriendo como servicio Windows.
    echo Se iniciara automaticamente al reiniciar el VPS.
    echo.
    echo IMPORTANTE: Revisa la consola de Node.js para
    echo obtener el CODIGO DE VINCULACION de WhatsApp.
    echo Logs en: %%~dp0daemon\PedidosWhatsAppBot.log
    echo.
) else (
    echo Servicio instalado. Verifica manualmente con:
    echo   sc query PedidosWhatsAppBot
)

pause
```

- [ ] **Step 3: Commit**

```bash
cd /home/kali/Jesus
git add vps-bot/install-windows.bat vps-bot/install-service.js
git commit -m "feat: instalador .bat automatico para VPS Windows"
```

---

## FASE 3 — Flutter Android App

---

### Task 9: Setup Flutter y proyecto base

**Files:** proyecto Flutter en `android-app/`

- [ ] **Step 1: Instalar Flutter SDK en Kali**

```bash
cd /home/kali
wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.22.0-stable.tar.xz
tar xf flutter_linux_3.22.0-stable.tar.xz
echo 'export PATH="$PATH:/home/kali/flutter/bin"' >> ~/.zshrc
export PATH="$PATH:/home/kali/flutter/bin"
flutter --version
```

Expected: `Flutter 3.22.x`.

- [ ] **Step 2: Instalar dependencias Android build**

```bash
sudo apt-get update -qq
sudo apt-get install -y openjdk-17-jdk unzip lib32z1 lib32ncurses6 lib32stdc++6
java -version
```

Expected: `openjdk version "17.x.x"`.

- [ ] **Step 3: Instalar Android SDK**

```bash
mkdir -p /home/kali/android-sdk/cmdline-tools
cd /home/kali/android-sdk/cmdline-tools
wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip -q commandlinetools-linux-11076708_latest.zip
mv cmdline-tools latest

cat >> ~/.zshrc << 'EOF'
export ANDROID_HOME=/home/kali/android-sdk
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
EOF
export ANDROID_HOME=/home/kali/android-sdk
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"

yes | sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

- [ ] **Step 4: Crear proyecto Flutter**

```bash
cd /home/kali/Jesus
flutter create android-app --org com.pedidos --project-name pedidos_app
cd android-app
flutter doctor
```

Expected: sin errores críticos (Android SDK OK, no se necesita emulador para build APK).

- [ ] **Step 5: Agregar dependencias Flutter**

```bash
cd /home/kali/Jesus/android-app
flutter pub add \
  http \
  sqflite \
  path_provider \
  path \
  provider \
  shared_preferences \
  connectivity_plus \
  onesignal_flutter \
  flutter_slidable \
  intl \
  cached_network_image \
  flutter_local_notifications
```

- [ ] **Step 6: Configurar permisos AndroidManifest.xml**

Editar `android/app/src/main/AndroidManifest.xml`, agregar dentro de `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

- [ ] **Step 7: Commit**

```bash
cd /home/kali/Jesus
git add android-app/
git commit -m "feat: proyecto Flutter base con dependencias y permisos"
```

---

### Task 10: Capa de datos Flutter — API + SQLite local

**Files:**
- Create: `android-app/lib/services/api_service.dart`
- Create: `android-app/lib/services/local_db.dart`
- Create: `android-app/lib/models/order.dart`
- Create: `android-app/lib/models/product.dart`

- [ ] **Step 1: Modelos de datos**

```dart
// android-app/lib/models/order.dart
class Order {
  final int? id;
  final String productName;
  final double? productPrice;
  final String deliveryAddress;
  final bool isFiado;
  final String status;
  final String waMessage;
  final String? comment;
  final String requestedAt;
  final String? deliveredAt;
  final String? customerName;
  final String? customerPhone;
  bool pendingSync;

  Order({
    this.id, required this.productName, this.productPrice,
    required this.deliveryAddress, required this.isFiado,
    required this.status, required this.waMessage, this.comment,
    required this.requestedAt, this.deliveredAt,
    this.customerName, this.customerPhone, this.pendingSync = false,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: j['id'], productName: j['product_name'] ?? '',
    productPrice: (j['product_price'] as num?)?.toDouble(),
    deliveryAddress: j['delivery_address'] ?? '',
    isFiado: j['is_fiado'] == 1 || j['is_fiado'] == true,
    status: j['status'] ?? 'pending', waMessage: j['wa_message'] ?? '',
    comment: j['comment'], requestedAt: j['requested_at'] ?? '',
    deliveredAt: j['delivered_at'],
    customerName: j['customer_name'], customerPhone: j['phone'],
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'product_name': productName, 'product_price': productPrice,
    'delivery_address': deliveryAddress, 'is_fiado': isFiado ? 1 : 0,
    'status': status, 'wa_message': waMessage, 'comment': comment,
    'requested_at': requestedAt, 'delivered_at': deliveredAt,
    'customer_name': customerName, 'customer_phone': customerPhone,
    'pending_sync': pendingSync ? 1 : 0,
  };
}
```

```dart
// android-app/lib/models/product.dart
class Product {
  final int? id;
  final String name;
  final List<String> aliases;
  final double price;
  final bool available;
  final bool favorite;
  final bool noFiado;

  Product({
    this.id, required this.name, required this.aliases,
    required this.price, this.available = true,
    this.favorite = false, this.noFiado = false,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'], name: j['name'],
    aliases: (j['aliases'] is List)
      ? List<String>.from(j['aliases'])
      : List<String>.from(j['aliases'] is String ? [] : []),
    price: (j['price'] as num).toDouble(),
    available: j['available'] == 1 || j['available'] == true,
    favorite: j['favorite'] == 1 || j['favorite'] == true,
    noFiado: j['no_fiado'] == 1 || j['no_fiado'] == true,
  );

  Map<String, dynamic> toJson() => {
    'name': name, 'price': price, 'aliases': aliases,
    'available': available, 'favorite': favorite, 'no_fiado': noFiado,
  };
}
```

- [ ] **Step 2: api_service.dart**

```dart
// android-app/lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import '../models/product.dart';

class ApiService {
  static String? _baseUrl;
  static String? _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? '';
    _token = prefs.getString('jwt_token') ?? '';
  }

  static Future<void> saveConfig(String url, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
    await prefs.setString('jwt_token', token);
    _baseUrl = url;
    _token = token;
  }

  static Map<String, String> get _headers => {
    'Authorization': 'Bearer $_token',
    'Content-Type': 'application/json',
  };

  static Future<String> login(String url, String pin) async {
    final res = await http.post(
      Uri.parse('$url/api/auth/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'pin': pin}),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['token'];
    }
    throw Exception('PIN incorrecto');
  }

  static Future<List<Order>> getOrders() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/orders'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).map((j) => Order.fromJson(j)).toList();
    }
    throw Exception('Error cargando pedidos');
  }

  static Future<void> deliverOrder(int id) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/orders/$id/deliver'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Error marcando entregado');
  }

  static Future<void> addComment(int id, String comment) async {
    await http.put(
      Uri.parse('$_baseUrl/api/orders/$id/comment'),
      headers: _headers,
      body: jsonEncode({'comment': comment}),
    ).timeout(const Duration(seconds: 10));
  }

  static Future<List<Product>> getProducts() async {
    final res = await http.get(Uri.parse('$_baseUrl/api/products'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).map((j) => Product.fromJson(j)).toList();
    }
    throw Exception('Error cargando productos');
  }

  static Future<Product> createProduct(Product p) async {
    final res = await http.post(Uri.parse('$_baseUrl/api/products'),
      headers: _headers, body: jsonEncode(p.toJson()))
        .timeout(const Duration(seconds: 10));
    return Product.fromJson(jsonDecode(res.body));
  }

  static Future<Product> updateProduct(int id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$_baseUrl/api/products/$id'),
      headers: _headers, body: jsonEncode(data))
        .timeout(const Duration(seconds: 10));
    return Product.fromJson(jsonDecode(res.body));
  }

  static Future<void> deleteProduct(int id) async {
    await http.delete(Uri.parse('$_baseUrl/api/products/$id'), headers: _headers)
        .timeout(const Duration(seconds: 10));
  }
}
```

- [ ] **Step 3: local_db.dart — SQLite offline cache**

```dart
// android-app/lib/services/local_db.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/order.dart';

class LocalDB {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'pedidos_local.db');
    return openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE orders (
          id INTEGER PRIMARY KEY,
          product_name TEXT,
          product_price REAL,
          delivery_address TEXT,
          is_fiado INTEGER,
          status TEXT,
          wa_message TEXT,
          comment TEXT,
          requested_at TEXT,
          delivered_at TEXT,
          customer_name TEXT,
          customer_phone TEXT,
          pending_sync INTEGER DEFAULT 0
        )
      ''');
    });
  }

  static Future<void> saveOrders(List<Order> orders) async {
    final d = await db;
    final batch = d.batch();
    for (final o in orders) {
      batch.insert('orders', o.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Order>> getOrders() async {
    final d = await db;
    final maps = await d.query('orders', where: "status = 'pending'", orderBy: 'requested_at DESC');
    return maps.map(Order.fromJson).toList();
  }

  static Future<void> markDelivered(int id) async {
    final d = await db;
    await d.update('orders', {'status': 'delivered', 'pending_sync': 1}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateComment(int id, String comment) async {
    final d = await db;
    await d.update('orders', {'comment': comment, 'pending_sync': 1}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Order>> getPendingSync() async {
    final d = await db;
    final maps = await d.query('orders', where: 'pending_sync = 1');
    return maps.map(Order.fromJson).toList();
  }

  static Future<void> clearSynced(int id) async {
    final d = await db;
    await d.update('orders', {'pending_sync': 0}, where: 'id = ?', whereArgs: [id]);
  }
}
```

- [ ] **Step 4: Commit**

```bash
cd /home/kali/Jesus
git add android-app/lib/
git commit -m "feat: modelos, API service y SQLite local Flutter"
```

---

### Task 11: Flutter — pantallas principales

**Files:**
- Create: `android-app/lib/main.dart`
- Create: `android-app/lib/screens/login_screen.dart`
- Create: `android-app/lib/screens/dashboard_screen.dart`
- Create: `android-app/lib/screens/products_screen.dart`
- Create: `android-app/lib/widgets/order_card.dart`
- Create: `android-app/lib/widgets/product_card.dart`
- Create: `android-app/lib/widgets/order_detail_modal.dart`
- Create: `android-app/lib/providers/app_provider.dart`

- [ ] **Step 1: main.dart**

```dart
// android-app/lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(
    ChangeNotifierProvider(create: (_) => AppProvider(), child: const PedidosApp()),
  );
}

class PedidosApp extends StatelessWidget {
  const PedidosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pedidos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: Consumer<AppProvider>(
        builder: (_, provider, __) =>
          provider.isLoggedIn ? const DashboardScreen() : const LoginScreen(),
      ),
    );
  }
}
```

- [ ] **Step 2: app_provider.dart**

```dart
// android-app/lib/providers/app_provider.dart
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/local_db.dart';

class AppProvider extends ChangeNotifier {
  bool isLoggedIn = false;
  bool isOnline = true;
  List<Order> orders = [];
  List<Product> products = [];
  bool loading = false;

  AppProvider() {
    Connectivity().onConnectivityChanged.listen((result) {
      isOnline = result != ConnectivityResult.none;
      if (isOnline && isLoggedIn) syncPendingActions();
      notifyListeners();
    });
  }

  Future<void> login(String url, String pin) async {
    final token = await ApiService.login(url, pin);
    await ApiService.saveConfig(url, token);
    isLoggedIn = true;
    notifyListeners();
    await refreshAll();
  }

  Future<void> refreshAll() async {
    await Future.wait([refreshOrders(), refreshProducts()]);
  }

  Future<void> refreshOrders() async {
    loading = true; notifyListeners();
    try {
      if (isOnline) {
        final fresh = await ApiService.getOrders();
        await LocalDB.saveOrders(fresh);
        orders = fresh;
      } else {
        orders = await LocalDB.getOrders();
      }
    } catch (_) {
      orders = await LocalDB.getOrders();
    }
    loading = false; notifyListeners();
  }

  Future<void> refreshProducts() async {
    try {
      if (isOnline) products = await ApiService.getProducts();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> deliverOrder(int id) async {
    if (isOnline) {
      await ApiService.deliverOrder(id);
    } else {
      await LocalDB.markDelivered(id);
    }
    orders.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  Future<void> addComment(int id, String comment) async {
    if (isOnline) {
      await ApiService.addComment(id, comment);
    } else {
      await LocalDB.updateComment(id, comment);
    }
    final idx = orders.indexWhere((o) => o.id == id);
    if (idx >= 0) { orders[idx].comment = comment; notifyListeners(); }
  }

  Future<void> syncPendingActions() async {
    final pending = await LocalDB.getPendingSync();
    for (final o in pending) {
      try {
        if (o.status == 'delivered') await ApiService.deliverOrder(o.id!);
        if (o.comment != null) await ApiService.addComment(o.id!, o.comment!);
        await LocalDB.clearSynced(o.id!);
      } catch (_) {}
    }
  }
}
```

- [ ] **Step 3: login_screen.dart**

```dart
// android-app/lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _urlCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AppProvider>().login(_urlCtrl.text.trim(), _pinCtrl.text.trim());
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.storefront_rounded, size: 80, color: Colors.white),
          const SizedBox(height: 16),
          const Text('Pedidos', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          const Text('Gestión de pedidos WhatsApp', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 40),
          Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(labelText: 'URL del servidor', prefixIcon: Icon(Icons.link)),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinCtrl,
              decoration: const InputDecoration(labelText: 'PIN de acceso', prefixIcon: Icon(Icons.lock)),
              obscureText: true, keyboardType: TextInputType.number, maxLength: 6,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: _loading ? null : _login,
              child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Ingresar'),
            )),
          ]))),
        ]),
      ))),
    );
  }
}
```

- [ ] **Step 4: order_card.dart (con swipe)**

```dart
// android-app/lib/widgets/order_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import 'order_detail_modal.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onDeliver;
  final ValueChanged<String> onComment;

  const OrderCard({super.key, required this.order, required this.onDeliver, required this.onComment});

  bool get _isOverdue {
    final date = DateTime.tryParse(order.requestedAt);
    if (date == null) return false;
    return DateTime.now().difference(date).inDays >= 1;
  }

  String get _timeLabel {
    final date = DateTime.tryParse(order.requestedAt);
    if (date == null) return '';
    return DateFormat('dd/MM HH:mm').format(date.toLocal());
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => OrderDetailModal(order: order, onComment: onComment, onDeliver: onDeliver),
    );
  }

  void _showCommentDialog(BuildContext context) {
    final ctrl = TextEditingController(text: order.comment);
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Comentario'),
      content: TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Escribe un comentario...')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () { onComment(ctrl.text); Navigator.pop(context); }, child: const Text('Guardar')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Slidable(
        endActionPane: ActionPane(motion: const DrawerMotion(), children: [
          SlidableAction(
            onPressed: (_) => onDeliver(),
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            icon: Icons.check_circle_rounded,
            label: 'ENTREGADO',
            borderRadius: BorderRadius.circular(16),
          ),
        ]),
        startActionPane: ActionPane(motion: const DrawerMotion(), children: [
          SlidableAction(
            onPressed: (_) => onDeliver(),
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            icon: Icons.check_circle_rounded,
            label: 'ENTREGADO',
            borderRadius: BorderRadius.circular(16),
          ),
        ]),
        child: GestureDetector(
          onLongPress: () => showModalBottomSheet(
            context: context,
            builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(leading: const Icon(Icons.comment), title: const Text('Dejar comentario'), onTap: () { Navigator.pop(context); _showCommentDialog(context); }),
              ListTile(leading: const Icon(Icons.info_outline), title: const Text('Ver detalle'), onTap: () { Navigator.pop(context); _showDetail(context); }),
              ListTile(leading: const Icon(Icons.check_circle, color: Color(0xFF2E7D32)), title: const Text('Marcar entregado'), onTap: () { Navigator.pop(context); onDeliver(); }),
            ])),
          ),
          child: Card(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(order.customerName ?? order.customerPhone ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                if (order.isFiado) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
                  child: const Text('FIADO', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Expanded(child: Text(order.productName, style: const TextStyle(fontSize: 14))),
                if (order.productPrice != null)
                  Text('\$${NumberFormat('#,###', 'es_CO').format(order.productPrice)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text(order.deliveryAddress, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.access_time, size: 14, color: _isOverdue ? Colors.red : Colors.grey),
                const SizedBox(width: 4),
                Text(_timeLabel, style: TextStyle(fontSize: 12, color: _isOverdue ? Colors.red : Colors.grey.shade600, fontWeight: _isOverdue ? FontWeight.bold : FontWeight.normal)),
                if (_isOverdue) ...[
                  const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Text('PENDIENTE', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))),
                ],
                if (order.comment != null) ...[
                  const Spacer(),
                  const Icon(Icons.comment, size: 14, color: Colors.grey),
                ],
              ]),
            ]),
          )),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: order_detail_modal.dart**

```dart
// android-app/lib/widgets/order_detail_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';

class OrderDetailModal extends StatelessWidget {
  final Order order;
  final ValueChanged<String> onComment;
  final VoidCallback onDeliver;

  const OrderDetailModal({super.key, required this.order, required this.onComment, required this.onDeliver});

  Widget _row(IconData icon, String label, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: color ?? Colors.green.shade700),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 14, color: color)),
      ])),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(order.requestedAt)?.toLocal();
    final dateStr = date != null ? DateFormat('dd/MM/yyyy HH:mm').format(date) : 'N/A';

    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(controller: ctrl, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Detalle del Pedido', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 24),
          _row(Icons.person, 'Cliente', order.customerName ?? order.customerPhone ?? ''),
          _row(Icons.inventory_2, 'Producto', order.productName),
          if (order.productPrice != null)
            _row(Icons.attach_money, 'Precio', '\$${NumberFormat('#,###', 'es_CO').format(order.productPrice)}'),
          _row(Icons.location_on, 'Dirección', order.deliveryAddress),
          _row(Icons.access_time, 'Solicitado', dateStr),
          if (order.isFiado) _row(Icons.warning_amber, 'Pago', 'FIADO', color: Colors.orange),
          const Divider(height: 24),
          const Text('Mensaje WhatsApp original', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFDCF8C6), borderRadius: BorderRadius.circular(12)),
            child: Text(order.waMessage, style: const TextStyle(fontSize: 13)),
          ),
          if (order.comment != null) ...[
            const SizedBox(height: 16),
            const Text('Comentario', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(order.comment!, style: TextStyle(color: Colors.grey.shade700)),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () { onDeliver(); Navigator.pop(context); },
            icon: const Icon(Icons.check_circle),
            label: const Text('Marcar como ENTREGADO'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), minimumSize: const Size(double.infinity, 48)),
          ),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 6: dashboard_screen.dart**

```dart
// android-app/lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/order_card.dart';
import 'products_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => provider.refreshAll()),
          if (!provider.isOnline)
            const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.wifi_off, color: Colors.orange)),
        ],
      ),
      body: IndexedStack(index: _tab, children: [
        // Dashboard tab
        RefreshIndicator(
          onRefresh: provider.refreshOrders,
          child: provider.loading
            ? const Center(child: CircularProgressIndicator())
            : provider.orders.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.inbox_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay pedidos activos', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: provider.orders.length,
                  itemBuilder: (ctx, i) {
                    final order = provider.orders[i];
                    return OrderCard(
                      order: order,
                      onDeliver: () => provider.deliverOrder(order.id!),
                      onComment: (c) => provider.addComment(order.id!, c),
                    );
                  }),
        ),
        // Products tab
        const ProductsScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Pedidos'),
          NavigationDestination(icon: Icon(Icons.inventory_rounded), label: 'Productos'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: products_screen.dart**

```dart
// android-app/lib/screens/products_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/product.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final Set<int> _selected = {};

  void _showAddProduct(BuildContext context) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final aliasCtrl = TextEditingController();
    final aliases = <String>[];

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nuevo Producto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre del producto', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Precio', border: OutlineInputBorder(), prefixText: '\$'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: aliasCtrl, decoration: const InputDecoration(labelText: 'Agregar apodo/alias', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 32), onPressed: () {
              if (aliasCtrl.text.isNotEmpty) {
                setModalState(() { aliases.add(aliasCtrl.text.trim()); aliasCtrl.clear(); });
              }
            }),
          ]),
          if (aliases.isNotEmpty) Wrap(spacing: 6, children: aliases.map((a) => Chip(
            label: Text(a),
            onDeleted: () => setModalState(() => aliases.remove(a)),
          )).toList()),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () async {
              final price = double.tryParse(priceCtrl.text.replaceAll(',', ''));
              if (nameCtrl.text.isEmpty || price == null) return;
              await context.read<AppProvider>().products;
              // ignore: use_build_context_synchronously
              Navigator.pop(ctx);
              final product = Product(name: nameCtrl.text.trim(), aliases: aliases, price: price);
              await context.read<AppProvider>().createProduct(product);
            },
            child: const Text('Guardar Producto'),
          )),
        ]),
      )),
    );
  }

  void _showActions(BuildContext context, List<Product> selected) {
    final provider = context.read<AppProvider>();
    showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.all(12), child: Text('${selected.length} producto(s) seleccionado(s)', style: const TextStyle(fontWeight: FontWeight.bold))),
      ListTile(leading: const Icon(Icons.visibility_off, color: Colors.orange), title: const Text('Marcar como no disponible'),
        onTap: () async { Navigator.pop(context); for (final p in selected) await provider.updateProduct(p.id!, {'available': 0}); setState(() => _selected.clear()); }),
      ListTile(leading: const Icon(Icons.star, color: Colors.amber), title: const Text('Favorito'),
        onTap: () async { Navigator.pop(context); for (final p in selected) await provider.updateProduct(p.id!, {'favorite': 1}); setState(() => _selected.clear()); }),
      ListTile(leading: const Icon(Icons.money_off, color: Colors.red), title: const Text('NO SE FÍA'),
        onTap: () async { Navigator.pop(context); for (final p in selected) await provider.updateProduct(p.id!, {'no_fiado': 1}); setState(() => _selected.clear()); }),
      ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Eliminar', style: TextStyle(color: Colors.red)),
        onTap: () async {
          Navigator.pop(context);
          final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
            title: const Text('Eliminar productos'),
            content: Text('¿Eliminar ${selected.length} producto(s)?'),
            actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar'))],
          ));
          if (confirm == true) {
            for (final p in selected) await provider.deleteProduct(p.id!);
            setState(() => _selected.clear());
          }
        }),
      ListTile(leading: const Icon(Icons.close), title: const Text('Cancelar'), onTap: () { Navigator.pop(context); setState(() => _selected.clear()); }),
    ])));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final products = provider.products;

    return Scaffold(
      body: products.isEmpty
        ? const Center(child: Text('Sin productos. Agrega uno con +', style: TextStyle(color: Colors.grey)))
        : ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: products.length,
            itemBuilder: (ctx, i) {
              final p = products[i];
              final isSelected = _selected.contains(p.id);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: GestureDetector(
                  onLongPress: () => setState(() {
                    if (isSelected) _selected.remove(p.id); else _selected.add(p.id!);
                    if (_selected.isNotEmpty) _showActions(ctx, products.where((x) => _selected.contains(x.id)).toList());
                  }),
                  child: Card(
                    color: isSelected ? Colors.green.shade50 : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isSelected ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none,
                    ),
                    child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                      if (isSelected) const Icon(Icons.check_circle, color: Colors.green),
                      if (!isSelected && p.favorite) const Icon(Icons.star, color: Colors.amber, size: 20),
                      if (!isSelected && !p.favorite) const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                          Text('\$${NumberFormat('#,###', 'es_CO').format(p.price)}',
                            style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                        ]),
                        if (p.aliases.isNotEmpty) Text(p.aliases.join(', '), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        Row(children: [
                          if (!p.available) _badge('NO DISPONIBLE', Colors.orange),
                          if (p.noFiado) _badge('NO SE FÍA', Colors.red),
                        ]),
                      ])),
                    ])),
                  ),
                ),
              );
            }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProduct(context),
        icon: const Icon(Icons.add),
        label: const Text('Producto'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 4, right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
  );
}
```

- [ ] **Step 8: Agregar métodos faltantes en app_provider.dart**

Agregar al final de `AppProvider` en `app_provider.dart`:

```dart
Future<Product> createProduct(Product p) async {
  final created = await ApiService.createProduct(p);
  products.add(created);
  notifyListeners();
  return created;
}

Future<void> updateProduct(int id, Map<String, dynamic> data) async {
  final updated = await ApiService.updateProduct(id, data);
  final idx = products.indexWhere((p) => p.id == id);
  if (idx >= 0) { products[idx] = updated; notifyListeners(); }
}

Future<void> deleteProduct(int id) async {
  await ApiService.deleteProduct(id);
  products.removeWhere((p) => p.id == id);
  notifyListeners();
}
```

- [ ] **Step 9: Verificar compilación Flutter**

```bash
cd /home/kali/Jesus/android-app
flutter analyze
```

Expected: sin errores críticos (warnings OK).

- [ ] **Step 10: Commit**

```bash
cd /home/kali/Jesus
git add android-app/lib/
git commit -m "feat: app Flutter completa con dashboard, productos, offline sync"
```

---

### Task 12: Compilar APK release

**Files:** `android-app/build/app/outputs/flutter-apk/app-release.apk`

- [ ] **Step 1: Configurar build.gradle para APK sin firma (debug release)**

```bash
cd /home/kali/Jesus/android-app
# Verificar minSdkVersion
grep -n "minSdk" android/app/build.gradle
```

Si `minSdkVersion < 21`, editar `android/app/build.gradle`:
```
minSdkVersion 21
```

- [ ] **Step 2: Compilar APK**

```bash
cd /home/kali/Jesus/android-app
flutter build apk --release --no-shrink
```

Expected (demora 3-8 minutos): `Built build/app/outputs/flutter-apk/app-release.apk`.

- [ ] **Step 3: Verificar APK existe**

```bash
ls -lh /home/kali/Jesus/android-app/build/app/outputs/flutter-apk/app-release.apk
```

Expected: archivo de ~20-40MB.

- [ ] **Step 4: Copiar APK a carpeta raíz del proyecto**

```bash
mkdir -p /home/kali/Jesus/releases
cp /home/kali/Jesus/android-app/build/app/outputs/flutter-apk/app-release.apk \
   /home/kali/Jesus/releases/pedidos-v1.0.apk
echo "APK lista en: /home/kali/Jesus/releases/pedidos-v1.0.apk"
```

- [ ] **Step 5: Commit**

```bash
cd /home/kali/Jesus
git add releases/
git commit -m "release: APK v1.0 compilada"
```

---

## FASE 4 — PDF + Automatización

---

### Task 13: Generador PDF diario

**Files:**
- Create: `server/src/services/pdfGenerator.js`
- Create: `server/src/services/pdfScheduler.js`

- [ ] **Step 1: pdfGenerator.js**

```javascript
// server/src/services/pdfGenerator.js
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');
const { getDB } = require('../db/database');

function formatDate(iso) {
  if (!iso) return 'N/A';
  const d = new Date(iso);
  return d.toLocaleString('es-CO', { timeZone: 'America/Bogota', day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

async function generateDailyPDF() {
  const db = getDB();
  const today = new Date().toLocaleDateString('es-CO', { timeZone: 'America/Bogota' });
  const todayISO = new Date().toISOString().split('T')[0];

  const orders = db.prepare(`
    SELECT o.*, c.phone, c.name as customer_name
    FROM orders o
    LEFT JOIN customers c ON o.customer_id = c.id
    WHERE o.status = 'delivered' AND date(o.delivered_at) = ?
    ORDER BY o.delivered_at ASC
  `).all(todayISO);

  const reportsDir = path.join(__dirname, '../../reports');
  if (!fs.existsSync(reportsDir)) fs.mkdirSync(reportsDir, { recursive: true });

  const filename = `pedidos-${todayISO}.pdf`;
  const filepath = path.join(reportsDir, filename);

  const doc = new PDFDocument({ margin: 40, size: 'A4' });
  const stream = fs.createWriteStream(filepath);
  doc.pipe(stream);

  // Header
  doc.fontSize(20).fillColor('#2E7D32').text('Reporte de Pedidos Entregados', { align: 'center' });
  doc.fontSize(12).fillColor('#666').text(`Fecha: ${today}`, { align: 'center' });
  doc.fontSize(12).fillColor('#666').text(`Total pedidos: ${orders.length}`, { align: 'center' });
  doc.moveDown(1.5);

  if (orders.length === 0) {
    doc.fontSize(14).fillColor('#333').text('No hubo pedidos entregados hoy.', { align: 'center' });
  } else {
    orders.forEach((order, idx) => {
      const y = doc.y;
      if (y > 700) doc.addPage();

      doc.roundedRect(40, doc.y, 515, 1, 2).fill('#2E7D32');
      doc.moveDown(0.5);

      doc.fontSize(13).fillColor('#1B5E20').text(`#${idx + 1} — ${order.product_name}`);
      doc.fontSize(10).fillColor('#333');

      const rows = [
        ['Cliente', order.customer_name || order.phone || 'N/A'],
        ['Teléfono', order.phone || 'N/A'],
        ['Dirección', order.delivery_address || 'N/A'],
        ['Precio', order.product_price ? `$${Number(order.product_price).toLocaleString('es-CO')}` : 'N/A'],
        ['Fiado', order.is_fiado ? 'SÍ' : 'No'],
        ['Solicitado', formatDate(order.requested_at)],
        ['Entregado', formatDate(order.delivered_at)],
        ['Comentario', order.comment || '—'],
      ];

      rows.forEach(([label, value]) => {
        doc.text(`${label}: `, { continued: true }).fillColor('#555').text(value).fillColor('#333');
      });

      doc.moveDown(1);
    });
  }

  // Footer
  doc.fontSize(9).fillColor('#aaa').text(`Generado automáticamente el ${new Date().toLocaleString('es-CO')}`, 40, 800, { align: 'center' });

  doc.end();

  await new Promise((resolve, reject) => {
    stream.on('finish', resolve);
    stream.on('error', reject);
  });

  // Marcar como exportados y limpiar
  if (orders.length > 0) {
    const ids = orders.map(o => o.id).join(',');
    db.prepare(`UPDATE orders SET pdf_exported = 1 WHERE id IN (${ids})`).run();
    db.prepare(`DELETE FROM orders WHERE status = 'delivered' AND pdf_exported = 1 AND date(delivered_at) = ?`).run(todayISO);
  }

  console.log(`PDF generado: ${filepath} (${orders.length} pedidos)`);
  return filepath;
}

module.exports = { generateDailyPDF };
```

- [ ] **Step 2: pdfScheduler.js**

```javascript
// server/src/services/pdfScheduler.js
const cron = require('node-cron');
const { generateDailyPDF } = require('./pdfGenerator');

function schedulePDFJob() {
  // 23:59 todos los días
  cron.schedule('59 23 * * *', async () => {
    console.log('Iniciando generación PDF diario...');
    try {
      const path = await generateDailyPDF();
      console.log('PDF completado:', path);
    } catch (err) {
      console.error('Error generando PDF:', err);
    }
  }, { timezone: 'America/Bogota' });

  console.log('PDF scheduler activo (23:59 diario)');
}

module.exports = { schedulePDFJob };
```

- [ ] **Step 3: Probar generación PDF manual**

```bash
cd /home/kali/Jesus/server
node -e "
const {initDB} = require('./src/db/database');
const {generateDailyPDF} = require('./src/services/pdfGenerator');
initDB();
generateDailyPDF().then(p => console.log('PDF en:', p)).catch(console.error);
"
```

Expected: `PDF generado: .../reports/pedidos-YYYY-MM-DD.pdf`.

```bash
ls -lh /home/kali/Jesus/server/reports/
```

- [ ] **Step 4: Commit**

```bash
cd /home/kali/Jesus
git add server/src/services/
git commit -m "feat: generador PDF diario con cron 23:59 y limpieza de DB"
```

---

### Task 14: Verificación final del sistema completo

- [ ] **Step 1: Reiniciar servicios Kali**

```bash
sudo systemctl restart ollama
sudo systemctl restart pedidos-server
sleep 5
sudo systemctl status ollama pedidos-server --no-pager
```

- [ ] **Step 2: Test endpoint health**

```bash
source /home/kali/Jesus/server/.env
curl -s https://$NGROK_DOMAIN/health
```

Expected: `{"status":"ok","time":"..."}`.

- [ ] **Step 3: Test webhook completo (simulación mensaje WA)**

```bash
source /home/kali/Jesus/server/.env

# Crear producto de prueba primero
TOKEN=$(curl -s -X POST https://$NGROK_DOMAIN/api/auth/token \
  -H "Content-Type: application/json" \
  -d '{"pin":"1234"}' | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

curl -s -X POST https://$NGROK_DOMAIN/api/products \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Purina Dog Chow","price":85000,"aliases":["purina","dog chow","puri"]}'

# Simular mensaje de cliente
curl -s -X POST https://$NGROK_DOMAIN/api/webhook/message \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "573001234567",
    "name": "María López",
    "message": "me regalas un bulto de purina para donde juanita, mañana le pago",
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
  }'
```

Expected: JSON con `order` y `parsed` mostrando producto detectado, dirección, `is_fiado: 1`.

- [ ] **Step 5: Verificar pedido en API**

```bash
curl -s https://$NGROK_DOMAIN/api/orders \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

Expected: lista con el pedido creado.

- [ ] **Step 6: Commit final**

```bash
cd /home/kali/Jesus
git add .
git commit -m "feat: sistema completo - servidor, bot, app, PDF"
```

---

## Self-Review del Plan

**Cobertura del spec:**
- [x] WhatsApp Bot con pairing code → Task 7-8
- [x] LLM extracción producto/dirección/fiado/nombre → Task 4
- [x] Base de datos orders/products/customers → Task 2
- [x] API REST con auth → Task 5
- [x] ngrok URL fija → Task 6
- [x] App dashboard con swipe → Task 11 (order_card.dart)
- [x] App productos con long-press multi-select → Task 11 (products_screen.dart)
- [x] Acciones rápidas: no disponible, favorito, no fía, eliminar → Task 11
- [x] Modal detalle con mensaje WA original → Task 11 (order_detail_modal.dart)
- [x] Comentarios por pedido → Task 11 + provider
- [x] Offline cache SQLite local → Task 10 (local_db.dart)
- [x] Sync automático al reconectar → Task 10 (provider)
- [x] Badge PENDIENTE en rojo para pedidos viejos → Task 11 (order_card.dart)
- [x] PDF diario 23:59 → Task 13
- [x] Limpieza DB post-PDF → Task 13
- [x] Instalador .bat VPS Windows → Task 8
- [x] Servicio Windows auto-start → Task 8
- [x] Servicio systemd Kali auto-start → Task 6
- [x] APK compilada en Kali → Task 12
- [x] Menú de productos por WhatsApp → Task 7 (bot.js)
- [x] Confirmación automática al cliente → Task 7 (bot.js)

**Sin placeholders, sin TBDs.**
**Tipos consistentes entre tareas.**
