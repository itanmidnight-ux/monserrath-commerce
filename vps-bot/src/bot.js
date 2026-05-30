require('dotenv').config();
const {
  default: makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  fetchLatestBaileysVersion
} = require('@whiskeysockets/baileys');
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
    const lines = available.map((p, i) =>
      `${i + 1}. ${p.name} - $${p.price.toLocaleString('es-CO')}`
    );
    return `📦 *Productos disponibles:*\n\n${lines.join('\n')}\n\nEscríbenos tu pedido con dirección de envío. 🐾`;
  } catch {
    return '📦 Escríbenos tu pedido y te atendemos.';
  }
}

function isMenuRequest(text) {
  const t = text.toLowerCase().trim();
  return ['hola', 'menu', 'menú', 'productos', 'catalogo', 'catálogo',
    'que tienen', 'qué tienen', 'buenos dias', 'buenas'].some(k => t.includes(k));
}

async function connectToWhatsApp() {
  const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);
  const { version } = await fetchLatestBaileysVersion();

  const sock = makeWASocket({
    version, logger, auth: state,
    printQRInTerminal: false,
    browser: ['PedidosBot', 'Chrome', '1.0.0']
  });

  sock.ev.on('creds.update', saveCreds);

  if (!sock.authState.creds.registered) {
    const phone = process.env.PHONE_NUMBER;
    if (!phone) { console.error('PHONE_NUMBER no configurado en .env'); process.exit(1); }
    setTimeout(async () => {
      try {
        const code = await sock.requestPairingCode(phone);
        console.log('\n╔══════════════════════════════╗');
        console.log(`║  CÓDIGO: ${code}              ║`);
        console.log('╚══════════════════════════════╝');
        console.log('WhatsApp → Dispositivos → Vincular → Usar número de teléfono\n');
      } catch (e) { console.error('Error pairing:', e.message); }
    }, 3000);
  }

  sock.ev.on('connection.update', async ({ connection, lastDisconnect }) => {
    if (connection === 'close') {
      const shouldReconnect =
        lastDisconnect?.error?.output?.statusCode !== DisconnectReason.loggedOut;
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
      if (jid.endsWith('@g.us')) continue;

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
          const precio = o.product_price
            ? `$${Number(o.product_price).toLocaleString('es-CO')}` : 'A confirmar';
          const confirm = `✅ *Pedido recibido:*\n📦 ${o.product_name}\n📍 ${o.delivery_address}\n💰 ${precio}${fiado}\n\nPronto confirmamos el envío. 🚚`;
          await sock.sendMessage(jid, { text: confirm });
        }
      } catch (err) {
        console.error('Error servidor:', err.message);
      }
    }
  });
}

connectToWhatsApp();
