@echo off
SETLOCAL ENABLEDELAYEDEXPANSION
title Instalador Bot WhatsApp Pedidos
color 0A

echo =========================================
echo   INSTALADOR BOT WHATSAPP PEDIDOS v1.0
echo   VPS Windows - AWS
echo =========================================
echo.

net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Ejecutar como Administrador
    echo Clic derecho en el .bat -^> Ejecutar como administrador
    pause & exit /b 1
)

REM === PASO 1: Verificar/Instalar Node.js ===
echo [1/6] Verificando Node.js...
where node >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Descargando Node.js 20 LTS...
    powershell -Command "Invoke-WebRequest -Uri 'https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi' -OutFile '%TEMP%\node.msi'"
    msiexec /i "%TEMP%\node.msi" /quiet /norestart
    set "PATH=%PATH%;C:\Program Files\nodejs"
    echo Node.js instalado.
) else (
    echo Node.js OK: & node --version
)

REM Verificar node disponible
node --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Reinicia CMD como admin e intenta de nuevo.
    pause & exit /b 1
)

REM === PASO 2: Instalar dependencias ===
echo.
echo [2/6] Instalando dependencias npm...
cd /d "%~dp0"
call npm install --production 2>&1
if %ERRORLEVEL% NEQ 0 ( echo ERROR en npm install & pause & exit /b 1 )
echo Dependencias instaladas OK.

REM === PASO 3: Instalar node-windows ===
echo.
echo [3/6] Instalando node-windows...
call npm install node-windows --save 2>&1
if %ERRORLEVEL% NEQ 0 ( echo ERROR node-windows & pause & exit /b 1 )

REM === PASO 4: Crear .env ===
echo.
if not exist ".env" (
    echo [4/6] Configurando variables de entorno...
    echo.
    set /p PHONE_NUMBER="Numero WhatsApp con codigo de pais sin + (ej: 573001234567): "
    (
        echo SERVER_URL=https://francoise-subhumid-maire.ngrok-free.dev
        echo API_KEY=80721f27d4b9e6b1250ccf94f5356f1d9368993ffd0e51d1d9470754e85b9171
        echo PHONE_NUMBER=!PHONE_NUMBER!
    ) > .env
    echo .env creado.
) else (
    echo [4/6] .env ya existe, usando configuracion existente.
)

REM === PASO 5: Instalar como servicio Windows ===
echo.
echo [5/6] Registrando servicio Windows...
node install-service.js
if %ERRORLEVEL% NEQ 0 ( echo ERROR instalando servicio & pause & exit /b 1 )

REM === PASO 6: Verificar ===
echo.
echo [6/6] Verificando servicio...
timeout /t 5 /nobreak >nul
sc query PedidosWhatsAppBot 2>nul | find "RUNNING" >nul
if %ERRORLEVEL% EQU 0 (
    echo.
    echo =========================================
    echo   INSTALACION COMPLETADA EXITOSAMENTE!
    echo =========================================
    echo.
    echo El bot corre como servicio Windows automatico.
    echo.
    echo SIGUIENTE PASO:
    echo Revisa los logs para obtener el CODIGO DE VINCULACION:
    echo   %~dp0daemon\PedidosWhatsAppBot.log
    echo.
    echo Luego en WhatsApp:
    echo   Configuracion ^> Dispositivos vinculados
    echo   ^> Vincular dispositivo ^> Usar numero de telefono
    echo   ^> Ingresa el codigo de 8 digitos
    echo.
) else (
    echo Servicio instalado. Verificar con: sc query PedidosWhatsAppBot
)

pause
