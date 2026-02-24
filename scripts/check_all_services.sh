#!/bin/bash
# Check status of all SRE Agent services

set -e

echo "🔍 Checking SRE Agent Services..."
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a process is running
check_process() {
    local name=$1
    local pattern=$2
    
    if pgrep -f "$pattern" > /dev/null; then
        echo -e "${GREEN}✅ $name is running${NC}"
        return 0
    else
        echo -e "${RED}❌ $name is NOT running${NC}"
        return 1
    fi
}

# Function to check HTTP endpoint
check_endpoint() {
    local name=$1
    local url=$2
    local endpoint=$3
    
    # Load API key if available
    if [ -f gateway/.api_key_local ]; then
        local api_key=$(cat gateway/.api_key_local)
        if curl -s -f -H "x-api-key: $api_key" "$url$endpoint" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $name is responding${NC}"
            return 0
        fi
    fi
    
    # Try without API key (for proxy health endpoint)
    if curl -s -f "$url$endpoint" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $name is responding${NC}"
        return 0
    fi
    
    echo -e "${RED}❌ $name is NOT responding${NC}"
    return 1
}

echo "📊 Process Status:"
echo "-------------------"
check_process "K8s Server" "k8s_server.py"
check_process "Logs Server" "logs_server.py"
check_process "Metrics Server" "metrics_server.py"
check_process "Runbooks Server" "runbooks_server.py"
check_process "Proxy" "proxy.py"
check_process "ngrok" "ngrok"

echo ""
echo "🌐 Basic Connectivity Checks:"
echo "-------------------"

# Just check if servers are listening on their ports
if nc -z localhost 8011 2>/dev/null; then
    echo -e "${GREEN}✅ K8s API (8011) is listening${NC}"
else
    echo -e "${RED}❌ K8s API (8011) is NOT listening${NC}"
fi

if nc -z localhost 8012 2>/dev/null; then
    echo -e "${GREEN}✅ Logs API (8012) is listening${NC}"
else
    echo -e "${RED}❌ Logs API (8012) is NOT listening${NC}"
fi

if nc -z localhost 8013 2>/dev/null; then
    echo -e "${GREEN}✅ Metrics API (8013) is listening${NC}"
else
    echo -e "${RED}❌ Metrics API (8013) is NOT listening${NC}"
fi

if nc -z localhost 8014 2>/dev/null; then
    echo -e "${GREEN}✅ Runbooks API (8014) is listening${NC}"
else
    echo -e "${RED}❌ Runbooks API (8014) is NOT listening${NC}"
fi

if nc -z localhost 8000 2>/dev/null; then
    echo -e "${GREEN}✅ Proxy (8000) is listening${NC}"
else
    echo -e "${RED}❌ Proxy (8000) is NOT listening${NC}"
fi

echo ""
echo "🔗 ngrok Status:"
echo "-------------------"
if [ -f logs/ngrok.log ]; then
    NGROK_URL=$(grep -o 'https://[a-z0-9-]*\.ngrok-free\.app' logs/ngrok.log 2>/dev/null | head -1)
    if [ -n "$NGROK_URL" ]; then
        echo -e "${GREEN}✅ ngrok URL: $NGROK_URL${NC}"
        if curl -s -f "$NGROK_URL/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ ngrok tunnel is accessible${NC}"
        else
            echo -e "${YELLOW}⚠️  ngrok tunnel exists but not responding${NC}"
        fi
    else
        echo -e "${RED}❌ ngrok URL not found in logs${NC}"
    fi
else
    echo -e "${RED}❌ ngrok log file not found${NC}"
fi

echo ""
echo "📝 Log Files:"
echo "-------------------"
for log in logs/k8s_server.log logs/logs_server.log logs/metrics_server.log logs/runbooks_server.log logs/proxy.log logs/ngrok.log; do
    if [ -f "$log" ]; then
        SIZE=$(du -h "$log" | cut -f1)
        echo -e "${GREEN}✅ $log ($SIZE)${NC}"
    else
        echo -e "${YELLOW}⚠️  $log (not found)${NC}"
    fi
done

echo ""
echo "🎯 Summary:"
echo "-------------------"

# Count running services
RUNNING=0
TOTAL=6

pgrep -f "k8s_server.py" > /dev/null && ((RUNNING++)) || true
pgrep -f "logs_server.py" > /dev/null && ((RUNNING++)) || true
pgrep -f "metrics_server.py" > /dev/null && ((RUNNING++)) || true
pgrep -f "runbooks_server.py" > /dev/null && ((RUNNING++)) || true
pgrep -f "proxy.py" > /dev/null && ((RUNNING++)) || true
pgrep -f "ngrok" > /dev/null && ((RUNNING++)) || true

if [ $RUNNING -eq $TOTAL ]; then
    echo -e "${GREEN}✅ All services are running ($RUNNING/$TOTAL)${NC}"
    exit 0
else
    echo -e "${RED}❌ Some services are not running ($RUNNING/$TOTAL)${NC}"
    echo ""
    echo "To start missing services:"
    echo "  cd ~/projects/SRE-agent"
    echo "  bash backend/scripts/start_demo_backend.sh --host 127.0.0.1"
    echo "  nohup python3 proxy.py > logs/proxy.log 2>&1 &"
    echo "  nohup ngrok http 8000 --log=stdout > logs/ngrok.log 2>&1 &"
    exit 1
fi
