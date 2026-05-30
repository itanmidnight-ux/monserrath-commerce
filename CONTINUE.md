# CONTINUE.md — Contexto completo del proyecto

## Qué es este proyecto
Sistema completo de gestión de pedidos WhatsApp para **Concentrados Monserrath**
(empresa de alimento concentrado para cerdos, pollos, peces, gatos y perros).

Clientes escriben al WhatsApp del negocio → Bot IA detecta pedido automáticamente
→ Trabajadores gestionan desde app Android → PDF diario de entregas.

---

## Arquitectura del sistema

```
Kali Linux (servidor principal)
├── server/          → API REST Express + SQLite + Ollama LLM
├── android-app/     → App Flutter (Android + Web preview)
├── vps-bot/         → Código WhatsApp bot (se copia al VPS)
└── start-all.sh     → Arrancar todo

VPS Windows (AWS)
└── Baileys bot → escucha WhatsApp, reenvía a Kali via HTTPS

App Android (múltiples dispositivos)
└── Conecta a Kali via ngrok URL fija
```

---

## Credenciales y configuración

| Variable | Valor |
|---|---|
| ngrok authtoken | `34G7biMjp4tdGcupxvySfJvYqrQ_6BEU8VntbCjSudDRWntdB` |
| ngrok dominio | `francoise-subhumid-maire.ngrok-free.dev` |
| API Key server | `80721f27d4b9e6b1250ccf94f5356f1d9368993ffd0e51d1d9470754e85b9171` |
| JWT Secret | `a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2` |
| Worker PIN | `1234` |
| GitHub repo | `https://github.com/itanmidnight-ux/pedidos-whatsapp` |
| GitHub user | `itanmidnight-ux` |
| GitHub email | `fs22092008@gmail.com` |
| Ollama model | `llama3.2:1b` |
| Server port | `3000` |

---

## Rutas API principales

| Ruta | Método | Auth | Descripción |
|---|---|---|---|
| `/health` | GET | - | Estado servidor |
| `/app/` | GET | - | App Flutter web |
| `/api/auth/token` | POST | PIN | Login → JWT |
| `/api/products` | GET/POST/PUT/DELETE | JWT | CRUD productos |
| `/api/orders` | GET | JWT | Pedidos activos |
| `/api/orders/:id/deliver` | PUT | JWT | Marcar entregado |
| `/api/orders/:id/comment` | PUT | JWT | Agregar comentario |
| `/api/webhook/message` | POST | API Key | Bot → servidor |
| `/api/messages` | GET | JWT | Conversaciones |
| `/api/messages/:phone` | GET | JWT | Chat de cliente |
| `/api/messages/send` | POST | JWT | Enviar mensaje WA |
| `/api/messages/outbound` | GET | API Key | Bot polling mensajes |

---

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Backend | Node.js 20 + Express + better-sqlite3 |
| LLM | Ollama + llama3.2:1b |
| WhatsApp bot | Baileys v6 (pairing code, no QR) |
| Tunnel | ngrok v3 (dominio fijo) |
| App móvil | Flutter 3.44 + Dart |
| Runtime | nvm v20.20.2 |
| Cron PDF | node-cron (23:59 diario) |

---

## Cómo arrancar en nuevo dispositivo Linux

```bash
# 1. Clonar repositorio
git clone https://github.com/itanmidnight-ux/pedidos-whatsapp
cd pedidos-whatsapp

# 2. Descargar sistema
# (Ver carpeta sistema/ en el repo)
cd sistema
bash install.sh      # instala nvm, Node, Ollama, ngrok
bash run.sh          # arranca todo

# 3. Verificar
curl https://francoise-subhumid-maire.ngrok-free.dev/health
```

---

## Estado actual del proyecto (2026-05-30)

### ✅ Completado
- Servidor Node.js completo (rutas, auth, PDF, LLM parser)
- Parser híbrido LLM + reglas (funciona sin RAM suficiente)
- Bot WhatsApp Baileys con pairing code
- App Flutter: Dashboard, Productos, Login, offline cache
- Sistema de mensajería (mensajes bidireccionales con bot)
- Header estático "CONCENTRADOS MONSERRATH"
- Paleta de colores Terra & Green agropecuaria
- Script install.sh + run.sh para Linux
- Instalador .bat para VPS Windows
- Repositorio GitHub: itanmidnight-ux/pedidos-whatsapp
- Vista previa web: /app/ y /preview

### 🔧 Pendiente / Próximos pasos
- Compilar APK release en máquina x86_64 (usar compile.sh)
- Configurar número WhatsApp real en VPS (.env del bot)
- Crear cuenta OneSignal para push notifications (opcional)
- Personalizar menú de productos del bot con precios reales
- Agregar logo/icono de Concentrados Monserrath al APK

---

## Estructura de archivos del proyecto local

```
/home/kali/Jesus/
├── android-app/          ← Código Flutter (Dart)
│   ├── android/          ← Config Android nativa
│   ├── lib/              ← 11 archivos Dart
│   └── pubspec.yaml
├── server/               ← API + base de datos
│   ├── src/
│   │   ├── db/           ← SQLite schema + conexión
│   │   ├── routes/       ← 5 rutas Express
│   │   ├── services/     ← LLM, PDF, cron
│   │   ├── middleware/   ← Auth JWT + API Key
│   │   ├── webapp/       ← Flutter web compilado
│   │   └── index.js
│   ├── .env              ← Credenciales (no en git)
│   └── package.json
├── vps-bot/              ← Bot WhatsApp para VPS
│   ├── src/
│   │   ├── bot.js        ← Lógica Baileys
│   │   └── apiClient.js  ← HTTP hacia servidor
│   └── package.json
├── docs/                 ← Specs y planes
├── logs/                 ← Logs del sistema
├── start-all.sh          ← Arrancar todo
├── CONTINUE.md           ← Este archivo
└── SKILL.md              ← Skills y habilidades usadas
```

---

## Comandos útiles

```bash
# Arrancar sistema completo
bash /home/kali/Jesus/start-all.sh

# Ver logs en tiempo real
tail -f /home/kali/Jesus/logs/server.log
tail -f /home/kali/Jesus/logs/ollama.log

# Probar parser LLM
curl -X POST https://francoise-subhumid-maire.ngrok-free.dev/api/webhook/message \
  -H "X-API-Key: 80721f27d4b9e6b1250ccf94f5356f1d9368993ffd0e51d1d9470754e85b9171" \
  -H "Content-Type: application/json" \
  -d '{"phone":"573001234567","name":"Test","message":"me regala un bulto de purina para donde juanita"}'

# Crear producto de prueba
TOKEN=$(curl -s -X POST https://francoise-subhumid-maire.ngrok-free.dev/api/auth/token \
  -H "Content-Type: application/json" -d '{"pin":"1234"}' | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")
curl -X POST https://francoise-subhumid-maire.ngrok-free.dev/api/products \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"Purina Dog Chow","price":85000,"aliases":["purina","dog chow","puri"]}'
```
