#!/bin/bash

# ============================================================================
# Check ngrok Session Status for SRE Agent
# ============================================================================
# This script checks the status of backend servers and ngrok tunnels
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Temporary files
BACKEND_PID_FILE="/tmp/sre_agent_backend.pid"
NGROK_PID_FILE="/tmp/sre_agent_ngrok_pids.txt"
NGROK_URLS_FILE="/tmp/sre_agent_ngrok_urls.txt"

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header "SRE Agent ngrok Session Status"

# Check backend servers
echo -e "${BLUE}Backend Servers:${NC}"
if [ -f "$BACKEND_PID_FILE" ]; then
    BACKEND_PID=$(cat "$BACKEND_PID_FILE")
    if ps -p "$BACKEND_PID" > /dev/null 2>&1; then
        print_success "Running (PID: $BACKEND_PID)"
        echo -e "  Logs: tail -f /tmp/sre_agent_backend.log"
    else
        print_error "Not running (stale PID file)"
    fi
else
    print_error "Not running (no PID file)"
fi

# Check ngrok tunnels
echo -e "\n${BLUE}ngrok Tunnels:${NC}"
if [ -f "$NGROK_PID_FILE" ]; then
    RUNNING_COUNT=0
    TOTAL_COUNT=0
    
    while IFS= read -r pid; do
        ((TOTAL_COUNT++))
        if ps -p "$pid" > /dev/null 2>&1; then
            ((RUNNING_COUNT++))
        fi
    done < "$NGROK_PID_FILE"
    
    if [ "$RUNNING_COUNT" -eq "$TOTAL_COUNT" ]; then
        print_success "All $TOTAL_COUNT tunnels running"
    else
        print_error "$RUNNING_COUNT/$TOTAL_COUNT tunnels running"
    fi
else
    print_error "Not running (no PID file)"
fi

# Show ngrok URLs if available
if [ -f "$NGROK_URLS_FILE" ]; then
    echo -e "\n${BLUE}ngrok URLs:${NC}"
    SPEC_NAMES=("k8s_api" "logs_api" "metrics_api" "runbooks_api")
    mapfile -t NGROK_DOMAINS < "$NGROK_URLS_FILE"
    
    for i in "${!SPEC_NAMES[@]}"; do
        if [ -n "${NGROK_DOMAINS[$i]}" ]; then
            echo -e "  ${SPEC_NAMES[$i]}: https://${NGROK_DOMAINS[$i]}"
        fi
    done
fi

# Check gateway targets status
echo -e "\n${BLUE}Gateway Targets:${NC}"
print_info "Checking gateway targets status..."
cd "$HOME/projects/SRE-agent/gateway" 2>/dev/null || {
    print_error "Cannot access gateway directory"
    exit 1
}

python check_gateway_targets.py 2>/dev/null || {
    print_error "Failed to check gateway targets"
    echo -e "  Run manually: cd gateway && python check_gateway_targets.py"
}

echo -e "\n${BLUE}Quick Actions:${NC}"
echo -e "  View backend logs: tail -f /tmp/sre_agent_backend.log"
echo -e "  Test agent: cd sre_agent && uv run sre-agent --prompt \"List pods\" --debug"
echo -e "  Stop session: ./stop_ngrok_session.sh"
echo -e "  Restart session: ./setup_ngrok_session.sh\n"
