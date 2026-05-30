const Service = require('node-windows').Service;
const path = require('path');

const svc = new Service({
  name: 'PedidosWhatsAppBot',
  description: 'Bot WhatsApp para gestión de pedidos',
  script: path.join(__dirname, 'src/bot.js')
});

svc.on('install', () => { svc.start(); console.log('✅ Servicio instalado e iniciado.'); });
svc.on('alreadyinstalled', () => { svc.start(); console.log('⚡ Servicio ya existía, iniciado.'); });
svc.on('error', err => console.error('Error:', err));
svc.install();
