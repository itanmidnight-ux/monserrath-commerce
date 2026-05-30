# Spec: .bat VPS auto-contenido + Vista previa app

**Fecha:** 2026-05-30  
**Proyecto:** Concentrados Monserrath — Sistema de pedidos WhatsApp

---

## Objetivo

Dejar el proyecto 100% funcional y listo para:
1. Instalación en VPS Windows con un solo `.bat` auto-contenido
2. Vista previa de la app Flutter web desde el servidor local
3. Proyecto listo para compilar APK en máquina x86_64

---

## 1. Archivo .bat para VPS Windows

### Nombre del archivo
`instalar-bot-whatsapp.bat` (reemplaza `whatsapp windows.bat`)

### Requisitos
- Ejecutarse como Administrador
- Sin dependencias externas (no requiere Git, no requiere repositorio)
- Todo el código del bot embebido dentro del .bat
- Funcionar en Windows 10/11 x64

### Flujo de ejecución (10 pasos, sin errores)

```
Paso 1: Verificar privilegios de administrador
        → Si no hay admin: mostrar error + pausa + exit

Paso 2: Crear estructura de carpetas
        → vps-bot\src\
        → vps-bot\auth\

Paso 3: Instalar Node.js 20 LTS
        → where node → si existe, continuar
        → Si no: descargar node-v20.11.0-x64.msi con PowerShell
        → Instalar silencioso (/quiet /norestart)
        → Refrescar PATH con variable de entorno
        → Verificar con `node --version`, error si falla

Paso 4: Escribir archivos del bot (embebidos en el .bat)
        → vps-bot\package.json
        → vps-bot\src\bot.js
        → vps-bot\src\apiClient.js
        → vps-bot\install-service.js
        → vps-bot\uninstall-service.js
        Técnica: PowerShell Set-Content con here-string para preservar
        caracteres especiales (require, {, }, etc.)

Paso 5: Configurar .env
        → Si .env existe: usar existente (no sobrescribir)
        → Si no existe: preguntar número WhatsApp con código de país
          (ej: 573001234567, sin +)
        → Escribir .env con SERVER_URL + API_KEY + PHONE_NUMBER

Paso 6: npm install
        → cd vps-bot\
        → call npm install --production
        → Verificar node_modules existe, error si falla

Paso 7: Parar servicio previo si existe
        → sc query PedidosWhatsAppBot → si existe: sc stop + uninstall

Paso 8: Lanzar bot en ventana CMD visible para vinculación
        → start "Bot WhatsApp - CODIGO DE VINCULACION" cmd /k "cd /d %BOT_DIR% && node src\bot.js"
        → Esperar 5 segundos para que el bot genere el código

Paso 9: Abrir web.whatsapp.com en navegador predeterminado
        → start https://web.whatsapp.com
        → Mostrar instrucciones en pantalla:
          "1. En WhatsApp Web: Menú (⋮) → Dispositivos vinculados → Vincular dispositivo"
          "2. Selecciona 'Usar número de teléfono'"
          "3. Ingresa el código de 8 dígitos que aparece en la otra ventana"
        → Pedir al usuario que presione Enter cuando haya vinculado

Paso 10: Instalar como servicio Windows (inicio automático)
         → node install-service.js
         → Esperar 8 segundos
         → Verificar sc query PedidosWhatsAppBot | find "RUNNING"
         → Mostrar resultado: éxito o instrucciones de diagnóstico
```

### Escritura de archivos embebidos

Los archivos del bot se escriben usando PowerShell dentro del .bat para evitar problemas con caracteres especiales de batch (`%`, `!`, `>`, `<`, `&`):

```batch
powershell -Command "$content = @'
<código JS aquí>
'@; Set-Content -Path 'ruta\archivo.js' -Value $content -Encoding UTF8"
```

Esto es más confiable que `echo` en batch para código JavaScript complejo.

---

## 2. Vista previa app Flutter web

### Comportamiento
- `start-all.sh` ya inicia ngrok + servidor + Ollama
- La app compilada está en `server/src/webapp/`
- URL de acceso: `https://francoise-subhumid-maire.ngrok-free.dev/app/`
- También local: `http://localhost:3000/app/`

### Verificaciones necesarias
- Confirmar que `server/src/webapp/` contiene el build Flutter compilado
- Confirmar que la ruta `/app/` en Express sirve correctamente los archivos estáticos
- Confirmar que helmet CSP está desactivado para Flutter JS

---

## 3. Proyecto listo para compilar APK

### Archivo compile.sh
Script `compile.sh` en raíz del proyecto para ejecutar en máquina x86_64:

```bash
#!/bin/bash
# Compilar APK release en máquina x86_64
cd android-app/
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Verificaciones en pubspec.yaml
- Versión Flutter: 3.44+
- Dependencias sin versiones conflictivas
- App name: "Concentrados Monserrath"
- Package: com.concentrados.monserrath (o similar)

### URL del servidor en Flutter
- Hardcoded en el código: `https://francoise-subhumid-maire.ngrok-free.dev`
- Verificar que es la misma URL en todos los archivos Dart que hacen llamadas API

---

## Archivos a crear/modificar

| Archivo | Acción |
|---|---|
| `instalar-bot-whatsapp.bat` | CREAR (reemplaza whatsapp windows.bat) |
| `vps-bot/uninstall-service.js` | CREAR (faltaba) |
| `compile.sh` | CREAR |
| `start-all.sh` | VERIFICAR/ACTUALIZAR si necesario |
| `server/src/index.js` | VERIFICAR rutas /app/ y /preview |

---

## Criterios de éxito

- [ ] `.bat` ejecutado en Windows limpio → bot activo como servicio en <5 min
- [ ] WhatsApp vinculado sin tocar código
- [ ] `https://<ngrok>/app/` carga la app Flutter correctamente
- [ ] APK compila en x86_64 con `flutter build apk --release`
- [ ] Cero errores en consola del servidor tras inicio
