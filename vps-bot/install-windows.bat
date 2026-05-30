@echo off
SETLOCAL ENABLEDELAYEDEXPANSION
title Concentrados Monserrath - Bot WhatsApp
color 0A

echo =========================================
echo   CONCENTRADOS MONSERRATH
echo   Bot WhatsApp - Instalador VPS Windows
echo =========================================
echo.

net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Ejecutar como Administrador
    echo Clic derecho ^> Ejecutar como administrador
    pause
    exit /b 1
)

if not exist "src\bot.js" (
    echo ERROR: Ejecuta desde la carpeta sistema\vps-bot\
    echo Pasos:
    echo   1. Descarga el repositorio de GitHub
    echo   2. Entra a sistema\vps-bot\
    echo   3. Copia este .bat ahi
    echo   4. Ejecuta como Administrador
    pause
    exit /b 1
)

REM === PASO 1: Node.js ===
echo [1/6] Verificando Node.js...
where node >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Descargando Node.js 20 LTS...
    powershell -Command "Invoke-WebRequest -Uri 'https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi' -OutFile '%TEMP%\node.msi'"
    msiexec /i "%TEMP%\node.msi" /quiet /norestart
    set "PATH=%PATH%;C:\Program Files\nodejs"
)
node --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Reinicia CMD como Admin e intenta de nuevo
    pause
    exit /b 1
)
echo Node.js OK: & node --version

REM === PASO 2: Dependencias ===
echo.
echo [2/6] Instalando dependencias npm...
cd /d "%~dp0"
call npm install --production >nul 2>&1
call npm install node-windows --save >nul 2>&1
echo Dependencias OK

REM === PASO 3: .env ===
echo.
echo [3/6] Configurando conexion...
if not exist ".env" (
    set /p PHONE="Numero WhatsApp con codigo pais sin + (ej: 573001234567): "
    (
        echo SERVER_URL=https://francoise-subhumid-maire.ngrok-free.dev
        echo API_KEY=80721f27d4b9e6b1250ccf94f5356f1d9368993ffd0e51d1d9470754e85b9171
        echo PHONE_NUMBER=!PHONE!
    ) > .env
    echo .env creado.
) else (
    echo .env ya existe - usando configuracion existente.
)
echo Servidor: https://francoise-subhumid-maire.ngrok-free.dev

REM === PASO 4: Desinstalar servicio previo (si existe) ===
echo.
echo [4/6] Preparando servicio...
sc query PedidosWhatsAppBot >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Deteniendo servicio previo...
    sc stop PedidosWhatsAppBot >nul 2>&1
    timeout /t 3 /nobreak >nul
    node uninstall-service.js >nul 2>&1
    timeout /t 2 /nobreak >nul
)

REM === PASO 5: Instalar servicio Windows (inicio automatico) ===
echo [5/6] Instalando servicio Windows permanente...
node install-service.js
if %ERRORLEVEL% NEQ 0 (
    echo ERROR instalando servicio
    pause
    exit /b 1
)

REM === PASO 6: Verificar y mostrar resultado ===
echo.
echo [6/6] Verificando...
timeout /t 8 /nobreak >nul

sc query PedidosWhatsAppBot 2>nul | find "RUNNING" >nul
if %ERRORLEVEL% EQU 0 (
    echo.
    echo =========================================
    echo   CONCENTRADOS MONSERRATH
    echo   BOT INSTALADO Y ACTIVO
    echo =========================================
    echo.
    echo El bot inicia automaticamente con Windows.
    echo Conexion lista: https://francoise-subhumid-maire.ngrok-free.dev
    echo.
    echo *** VINCULA WHATSAPP AHORA ***
    echo.
    echo 1. Abre este archivo de log:
    echo    %~dp0daemon\PedidosWhatsAppBot.log
    echo.
    echo 2. Busca el CODIGO DE 8 DIGITOS
    echo.
    echo 3. En tu celular:
    echo    WhatsApp ^> Dispositivos vinculados
    echo    ^> Vincular dispositivo
    echo    ^> Usar numero de telefono
    echo    ^> Ingresa el codigo
    echo.
    echo El bot empezara a funcionar automaticamente.
    echo =========================================
) else (
    echo Servicio instalado. Estado:
    sc query PedidosWhatsAppBot
    echo.
    echo Revisa logs en: %~dp0daemon\PedidosWhatsAppBot.log
)

echo.
pause
