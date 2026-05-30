const { Ollama } = require('ollama');
const { getDB } = require('../db/database');

const ollama = new Ollama({ host: 'http://localhost:11434' });

function buildPrompt(message, products) {
  const productList = products
    .map(p => `- "${p.name}" (aliases: ${JSON.parse(p.aliases || '[]').join(', ')}) precio: $${p.price}`)
    .join('\n');

  return `Eres un asistente que extrae datos de pedidos de productos para animales.

PRODUCTOS DISPONIBLES:
${productList || '(sin productos aun)'}

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
- is_fiado=true si el mensaje contiene: "después", "despues", "mañana", "el viernes", "la próxima", "le pago", "fiado", "me fía", "me fia", "luego pago", "cuando pueda"
- delivery_address: extrae "para donde X", "en la X", "a donde X", dirección completa
- product_name: busca coincidencia con aliases también, no solo nombre exacto
- customer_name: busca "soy X", "de parte de X", "le habla X", "habla X"`;
}

async function parseOrderMessage(waMessage, senderName) {
  const db = getDB();
  const products = db.prepare('SELECT * FROM products WHERE available = 1').all();

  const prompt = buildPrompt(waMessage, products);

  try {
    const response = await ollama.generate({
      model: process.env.OLLAMA_MODEL || 'llama3.2:1b',
      prompt,
      options: { temperature: 0.1, num_predict: 300 },
      stream: false
    });

    const raw = response.response.trim();
    const jsonMatch = raw.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error('No JSON en respuesta LLM');

    const parsed = JSON.parse(jsonMatch[0]);

    if (parsed.product_name) {
      const allProducts = db.prepare('SELECT * FROM products WHERE available = 1').all();
      const match = allProducts.find(p => {
        const aliases = JSON.parse(p.aliases || '[]');
        const nameMatch = p.name.toLowerCase().includes(parsed.product_name.toLowerCase()) ||
          parsed.product_name.toLowerCase().includes(p.name.toLowerCase());
        const aliasMatch = aliases.some(a =>
          a.toLowerCase().includes(parsed.product_name.toLowerCase()) ||
          parsed.product_name.toLowerCase().includes(a.toLowerCase())
        );
        return nameMatch || aliasMatch;
      });
      if (match) {
        parsed.product_id = match.id;
        parsed.product_name = match.name;
      }
    }

    return parsed;
  } catch (err) {
    console.error('Error LLM parser:', err.message);
    return {
      product_name: null,
      product_id: null,
      delivery_address: null,
      is_fiado: false,
      customer_name: senderName,
      confidence: 'low'
    };
  }
}

module.exports = { parseOrderMessage };
