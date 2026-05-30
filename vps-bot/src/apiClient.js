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
