# Diseño: Sistema de Pedidos WhatsApp + App Android
**Fecha:** 2026-05-30  
**Estado:** Aprobado por usuario

---

## 1. Visión General

Sistema completo para gestionar pedidos de productos alimenticios para animales vía WhatsApp. Clientes escriben al número del negocio → bot detecta pedido → LLM extrae datos → almacena en DB → app Android muestra a trabajadores.

---

## 2. Arquitectura

```
VPS Windows AWS                      Kali Linux (servidor principal)
┌────────────────────┐               ┌─────────────────────────────┐
│ WhatsApp Bot       │──HTTPS──────► │ Express REST API            │
│ Baileys v6+        │  + API Key    │ POST /api/webhook/message   │
│ Auth: pairing code │◄──────────────│ GET  /api/products          │
│ Servicio Windows   │  menu/resp    │ GET  /api/orders            │
│ RAM uso: ~250MB    │               │ PUT  /api/orders/:id        │
└────────────────────┘               │                             │
         ↑                           │ Ollama (llama3.2:1b ~900MB) │
   WhatsApp API                      │ SQLite DB                   │
   (usuarios finales)                │ ngrok → URL pública fija    │
                                     │ Cron PDF 23:59              │
                                     └─────────────────────────────┘
                                                  ↑
                                    Flutter Android App (múltiples)
                                    SQLite local (offline cache)
                                    HTTP + WebSocket (sync)
```

**RAM Kali estimada:** Ollama ~900MB + Express ~80MB + SQLite ~20MB = ~1GB (swap disponible 2GB como buffer) ✓  
**RAM VPS estimada:** Node.js + Baileys ~250MB / 800MB disponibles ✓

---

## 3. Stack Tecnológico

| Componente | Tecnología | Justificación |
|---|---|---|
| Servidor API | Node.js 20 + Express | Mismo runtime que bot, liviano |
| Base de datos | SQLite3 | Sin servidor, suficiente para volumen de pedidos |
| LLM | Ollama + llama3.2:1b | Gratuito, local, extracción estructurada |
| WhatsApp | Baileys v6 | Sin browser, ~150MB, pairing code |
| Tunnel | ngrok (URL fija de usuario) | Ya disponible, HTTPS automático |
| App móvil | Flutter 3.x | UI profesional, APK nativo, offline |
| PDF | PDFKit (Node.js) | Server-side, sin dependencias externas |
| Notificaciones | OneSignal (free tier) | No requiere Firebase project setup manual |
| Inicio automático | systemd (Kali) + node-windows (VPS) | Servicio persistente en ambos |

---

## 4. Base de Datos (SQLite)

### Tabla `products`
```sql
id INTEGER PRIMARY KEY
name TEXT NOT NULL
aliases TEXT          -- JSON array: ["purina","puri","dog chow"]
price REAL NOT NULL
available INTEGER DEFAULT 1    -- 0=no disponible
favorite INTEGER DEFAULT 0
no_fiado INTEGER DEFAULT 0
created_at TEXT
```

### Tabla `customers`
```sql
id INTEGER PRIMARY KEY
phone TEXT UNIQUE NOT NULL
name TEXT                      -- null si no tiene nombre en WA
```

### Tabla `orders`
```sql
id INTEGER PRIMARY KEY
customer_id INTEGER REFERENCES customers(id)
product_id INTEGER REFERENCES products(id)
product_name TEXT              -- snapshot al momento del pedido
product_price REAL
delivery_address TEXT
is_fiado INTEGER DEFAULT 0
status TEXT DEFAULT 'pending'  -- pending | delivered
wa_message TEXT                -- mensaje original WhatsApp
comment TEXT                   -- comentario del trabajador
requested_at TEXT              -- timestamp exacto del mensaje WA
delivered_at TEXT
pdf_exported INTEGER DEFAULT 0
```

---

## 5. Flujo Completo de un Pedido

```
1. Cliente escribe en WhatsApp del negocio
2. Baileys (VPS) recibe mensaje
3. VPS POST /api/webhook/message → Kali (HTTPS + API Key)
4. Kali guarda mensaje temporal
5. Ollama analiza con prompt estructurado:
   - ¿Qué producto? (matchea contra aliases en DB)
   - ¿Dirección de entrega?
   - ¿Es fiado? (detecta: "después pago", "mañana", "el viernes", etc.)
   - ¿Nombre del cliente? (de contacto WA o número si desconocido)
6. Kali crea registro en orders + customers
7. VPS envía confirmación al cliente + menú si aplica
8. App Android recibe notificación (OneSignal)
9. Nueva tarjeta aparece en dashboard
```

---

## 6. API REST Endpoints

```
POST /api/webhook/message          VPS → Kali (recibe mensaje WA)
GET  /api/products                 App → lista productos
POST /api/products                 App → crear producto
PUT  /api/products/:id             App → editar producto
DELETE /api/products/:id           App → eliminar producto
GET  /api/orders                   App → lista pedidos activos
PUT  /api/orders/:id/deliver       App → marcar entregado
PUT  /api/orders/:id/comment       App → agregar comentario
GET  /api/orders/pending           App → pedidos pendientes viejos
POST /api/auth/token               App → login con PIN
```

**Seguridad:**
- VPS ↔ Kali: header `X-API-Key: <secret>` (generado en setup)
- App ↔ Kali: PIN de 4 dígitos → JWT token (24h)
- ngrok HTTPS: cifrado en tránsito

---

## 7. App Flutter — Pantallas

### Dashboard (Home)
- Tarjetas pedidos activos (nombre, producto, dirección, hora, fiado badge)
- Swipe derecha/izquierda → botón ENTREGADO slide-in
- Long-press → menú rápido: Comentar, Ver mensaje WA, Marcar entregado
- Badge rojo en hora si pedido es de día anterior (pendiente)
- Offline: muestra pedidos cacheados localmente (SQLite local)
- Sync automático al recuperar conexión

### Productos
- Cards con nombre, precio, aliases, badges (favorito, no disponible, no fía)
- FAB (+) → modal crear producto: nombre, precio, aliases (chips editables)
- Long-press → selección múltiple → AppBar de acciones:
  - No disponible (toggle)
  - Favorito (toggle)  
  - No se fía (toggle)
  - Eliminar (con confirmación)

### Detalle Pedido (modal)
- Mensaje original WhatsApp completo
- Datos extraídos: producto, dirección, fiado, nombre, hora
- Campo comentario editable
- Botón ENTREGADO

---

## 8. Bot WhatsApp — Comportamiento

**Menú automático** (respuesta a "hola", "menu", "productos"):
```
📦 *Productos disponibles:*

1. Purina Dog Chow - $XX,XXX
2. Dog Chow Cachorros - $XX,XXX
3. Cat Chow - $XX,XXX
...

Escríbenos tu pedido con la dirección de envío.
```

**Confirmación de pedido detectado:**
```
✅ Pedido recibido:
📦 [Producto]
📍 [Dirección]
💰 Precio: $XX,XXX
[⚠️ Fiado registrado] (si aplica)

Pronto te confirmamos el envío.
```

---

## 9. PDF Diario (23:59)

Campos por pedido:
- Número de pedido del día
- Nombre cliente + teléfono
- Producto + precio
- Dirección entrega
- Hora pedido (exacta WA)
- Hora entrega
- Fiado: Sí/No
- Comentario trabajador (en blanco si no hay)

Archivo: `reports/pedidos-YYYY-MM-DD.pdf`  
Post-generación: elimina de DB todos los pedidos con `status=delivered` y `pdf_exported=1`.

---

## 10. Fases de Implementación

| Fase | Contenido | Entregable |
|---|---|---|
| 1 | Kali: Ollama + SQLite + API REST + ngrok + systemd | Servidor funcionando |
| 2 | VPS: .bat installer + Baileys + pairing code + servicio Windows | Bot WA activo |
| 3 | Flutter: App Android completa con offline + notificaciones | APK instalable |
| 4 | PDF cron + pendientes + pulimiento final | Sistema completo |

---

## 11. Auto-validación del Spec

- [x] Sin TBDs ni secciones incompletas
- [x] RAM Kali validada: ~1GB uso / 3.6GB total + 2GB swap ✓
- [x] RAM VPS validada: ~250MB / 800MB+ ✓
- [x] Baileys v6 soporta pairing code (no QR) ✓
- [x] OneSignal free tier: hasta 10,000 dispositivos, sin Firebase manual ✓
- [x] SQLite suficiente: pedidos de una tienda pequeña (<1000/día) ✓
- [x] Flutter compila APK en Linux (Kali) con Android SDK ✓
- [x] ngrok URL fija: usuario tiene cuenta paga ✓
- [x] Sin contradicciones entre secciones
- [x] Offline sync: SQLite local Flutter + queue de cambios pendientes ✓
