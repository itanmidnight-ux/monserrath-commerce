#!/bin/bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
nvm use v20.20.2 --silent 2>/dev/null

# Iniciar Ollama
if ! pgrep -x ollama > /dev/null; then
    ollama serve >> /home/kali/Jesus/logs/ollama.log 2>&1 &
    sleep 3
fi

# Iniciar servidor Node
cd /home/kali/Jesus/server
node src/index.js >> /home/kali/Jesus/logs/server.log 2>&1 &
NODE_PID=$!

# Iniciar ngrok
source .env
ngrok http $PORT --domain=$NGROK_DOMAIN --log=stdout >> /home/kali/Jesus/logs/ngrok.log 2>&1 &

echo "Servicios iniciados. Logs en /home/kali/Jesus/logs/"
