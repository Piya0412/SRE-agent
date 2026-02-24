#!/bin/bash
# Start all SRE Agent services in background (like old account setup)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Starting SRE Agent Services in Background..."
echo ""

# Create logs directory
mkdir -p logs

# Export BACKEND_API_KEY if available
if [ -f gateway/.api_key_local ]; then
    export BACKEND_API_KEY=$(cat gateway/.api_key_local)
    echo "🔑 Loaded API key from gateway/.api_key_local"
else
    echo "⚠️  Warning: gateway/.api_key_local not found"
    echo "   Backend servers may fail to start"
fi

# 1. Start backend servers (already uses nohup internally)
echo "📊 Starting backend servers..."
bash backend/scripts/start_demo_backend.sh --host 127.0.0.1

# 2. Start proxy in background
echo "🔀 Starting reverse proxy..."
if pgrep -f "proxy.py" > /dev/null; then
    echo "⚠️  Proxy already running, skipping..."
else
    nohup python3 proxy.py > logs/proxy.log 2>&1 &
    echo $! > .proxy_pid
    echo "✅ Proxy started (PID: $(cat .proxy_pid))"
fi

# 3. Start ngrok in background
echo "🌐 Starting ngrok tunnel..."
if pgrep -f "ngrok" > /dev/null; then
    echo "⚠️  ngrok already running, skipping..."
else
    nohup ngrok http 8000 --log=stdout > logs/ngrok.log 2>&1 &
    echo $! > .ngrok_pid
    echo "✅ ngrok started (PID: $(cat .ngrok_pid))"
fi

# Wait for services to initialize
echo ""
echo "⏳ Waiting for services to initialize..."
sleep 5

# Check status
echo ""
echo "🔍 Checking service status..."
bash scripts/check_all_services.sh

echo ""
echo "✅ All services started in background!"
echo ""
echo "📝 Logs are in: $SCRIPT_DIR/logs/"
echo "🛑 To stop all services: bash stop_all_background.sh"
echo "🔍 To check status: bash scripts/check_all_services.sh"
echo ""
echo "🌐 ngrok URL:"
if [ -f logs/ngrok.log ]; then
    sleep 2  # Give ngrok a moment to write URL
    NGROK_URL=$(grep -o 'https://[a-z0-9-]*\.ngrok-free\.app' logs/ngrok.log 2>/dev/null | head -1)
    if [ -n "$NGROK_URL" ]; then
        echo "   $NGROK_URL"
    else
        echo "   Check logs/ngrok.log in a few seconds"
    fi
fi
