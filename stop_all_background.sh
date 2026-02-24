#!/bin/bash
# Stop all SRE Agent services running in background

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🛑 Stopping SRE Agent Services..."
echo ""

# 1. Stop backend servers
echo "📊 Stopping backend servers..."
if [ -f backend/scripts/stop_demo_backend.sh ]; then
    bash backend/scripts/stop_demo_backend.sh
else
    pkill -f "k8s_server.py" || true
    pkill -f "logs_server.py" || true
    pkill -f "metrics_server.py" || true
    pkill -f "runbooks_server.py" || true
fi

# 2. Stop proxy
echo "🔀 Stopping reverse proxy..."
if [ -f .proxy_pid ]; then
    kill $(cat .proxy_pid) 2>/dev/null || true
    rm .proxy_pid
fi
pkill -f "proxy.py" || true

# 3. Stop ngrok
echo "🌐 Stopping ngrok tunnel..."
if [ -f .ngrok_pid ]; then
    kill $(cat .ngrok_pid) 2>/dev/null || true
    rm .ngrok_pid
fi
pkill -f "ngrok" || true

# Wait a moment
sleep 2

# Verify all stopped
echo ""
echo "🔍 Verifying services stopped..."

STILL_RUNNING=0

if pgrep -f "k8s_server.py" > /dev/null; then
    echo "⚠️  K8s server still running"
    ((STILL_RUNNING++))
fi

if pgrep -f "logs_server.py" > /dev/null; then
    echo "⚠️  Logs server still running"
    ((STILL_RUNNING++))
fi

if pgrep -f "metrics_server.py" > /dev/null; then
    echo "⚠️  Metrics server still running"
    ((STILL_RUNNING++))
fi

if pgrep -f "runbooks_server.py" > /dev/null; then
    echo "⚠️  Runbooks server still running"
    ((STILL_RUNNING++))
fi

if pgrep -f "proxy.py" > /dev/null; then
    echo "⚠️  Proxy still running"
    ((STILL_RUNNING++))
fi

if pgrep -f "ngrok" > /dev/null; then
    echo "⚠️  ngrok still running"
    ((STILL_RUNNING++))
fi

if [ $STILL_RUNNING -eq 0 ]; then
    echo "✅ All services stopped successfully!"
else
    echo ""
    echo "⚠️  $STILL_RUNNING service(s) still running"
    echo "   Try: pkill -9 -f 'k8s_server|logs_server|metrics_server|runbooks_server|proxy.py|ngrok'"
fi

echo ""
echo "📝 Logs preserved in: $SCRIPT_DIR/logs/"
