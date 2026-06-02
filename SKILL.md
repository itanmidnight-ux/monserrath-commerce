# SKILL.md — Skills, habilidades y decisiones técnicas

## Superpowers Skills utilizados

| Skill | Propósito |
|---|---|
| `superpowers:brainstorming` | Diseño inicial del sistema, preguntas de clarificación |
| `superpowers:writing-plans` | Plan de implementación en 4 fases |
| `superpowers:executing-plans` | Ejecución secuencial del plan |
| `superpowers:verification-before-completion` | Auditoría de archivos antes de subir |
| `caveman` (ultra) | Compresión máxima de tokens en respuestas |
| `token-guardian` | Lecturas parciales, grep antes de read |
| `run` | Ejecución de la app Flutter web para preview |

---

## Decisiones arquitectónicas clave

### Por qué Baileys (no whatsapp-web.js)
- Sin headless Chrome → -300MB RAM en VPS
- Pairing code en lugar de QR (mejor para servidores)
- Más estable en producción

### Por qué SQLite (no PostgreSQL)
- Sin servidor de DB separado
- Suficiente para volumen de pedidos de una tienda
- WAL mode para concurrencia básica

### Por qué parser híbrido LLM + reglas
- LLM (llama3.2:1b) se usa cuando hay RAM suficiente
- Fallback automático a regex/reglas cuando RAM < 900MB
- Sistema no se rompe en ningún caso

### Por qué ngrok dominio fijo
- URL permanente para la app Android (no cambia)
- App compilada con URL hardcoded → no necesita reconfigurar

### Por qué Flutter web para preview
- Mismo código Dart que el APK → preview real
- No HTML mockup → lo que ves es exactamente lo que se compila

---

## Problemas resueltos y cómo

### ARM64 vs x86-64 (compilación APK)
- **Problema**: Android NDK, gen_snapshot, aapt2, cmake son x86-64 only
- **Solución**: Wrappers qemu-x86_64 con sysroot x86-64 extraído de paquetes .deb
- **Para producción**: Usar compile.sh en máquina x86-64

### npm roto en sistema (glob incompatible)
- **Solución**: nvm + Node.js 20.20.2 aislado del npm del sistema

### systemd no disponible sin sudo
- **Solución**: crontab @reboot + scripts de inicio manuales

### Flutter web pantalla en blanco
- **Causa 1**: base-href incorrecto (/) en lugar de (/app/)
- **Causa 2**: helmet CSP bloqueando JS de Flutter
- **Causa 3**: Interstitial de ngrok en mobile
- **Solución**: --base-href=/app/ + helmet({contentSecurityPolicy:false}) + header ngrok-skip-browser-warning

---

## Comandos de instalación por herramienta

```bash
# nvm + Node.js 20
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh"
nvm install 20

# Ollama + modelo
curl -fsSL https://ollama.ai/install.sh | sh
ollama serve &
ollama pull llama3.2:1b

# ngrok ARM64
wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz
tar xzf ngrok-v3-stable-linux-arm64.tgz -C ~/bin/
ngrok config add-authtoken TOKEN

# gh CLI ARM64
wget https://github.com/cli/cli/releases/download/v2.93.0/gh_2.93.0_linux_arm64.tar.gz
tar xzf gh_2.93.0_linux_arm64.tar.gz && cp gh_*/bin/gh ~/bin/

# Flutter (en x86-64)
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz
tar xf flutter_linux_3.24.5-stable.tar.xz
export PATH="$PATH:$HOME/flutter/bin"
flutter config --enable-web

# Flutter (en ARM64 via git clone)
git clone https://github.com/flutter/flutter.git ~/flutter -b stable --depth 1
flutter precache --android
```

---

## Paleta de colores — Concentrados Monserrath

```dart
// Terra & Green - Sector agropecuario
static const primary     = Color(0xFF2D5016);  // Verde oliva oscuro
static const accent      = Color(0xFFD4800A);  // Ámbar dorado (granos)
static const background  = Color(0xFFF8F4EE);  // Crema cálida
static const surface     = Color(0xFFFFFFFF);  // Blanco superficie
static const onPrimary   = Color(0xFFFFFFFF);  // Texto sobre primary
static const textMain    = Color(0xFF1A1A1A);  // Texto principal
static const textSub     = Color(0xFF757575);  // Texto secundario
```

---

## Estructura mensajería (implementada)

```
App → POST /api/messages/send → SQLite (direction=outbound, sent=0)
Bot → GET /api/messages/outbound (polling cada 3s)
Bot → Envía WA → PUT /api/messages/:id/sent
WA cliente → Bot → POST /api/webhook/message → SQLite (direction=inbound)
App → GET /api/messages/:phone → muestra chat
```

---

## Flujo completo de un pedido

```
1. Cliente escribe WhatsApp al negocio
2. Baileys (VPS) recibe → POST /api/webhook/message (API Key)
3. Servidor guarda mensaje en messages table (inbound)
4. Ollama analiza → extrae producto, dirección, fiado, nombre
5. Servidor crea orden en orders table
6. VPS envía confirmación al cliente
7. App Android actualiza dashboard (polling/refresh)
8. Trabajador ve tarjeta → toca → abre detalle
9. Trabador puede: marcar entregado, comentar, abrir chat
10. 23:59 → cron genera PDF + limpia órdenes entregadas
```
