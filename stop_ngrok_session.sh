#!/bin/bash

# ============================================================================
# Stop ngrok Session for SRE Agent
# ============================================================================
# This script stops all backend servers and ngrok tunnels started by
# setup_ngrok_session.sh
# ============================================================================

set -e

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

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_header "Stopping SRE Agent ngrok Session"

# Stop backend servers
if [ -f "$BACKEND_PID_FILE" ]; then
    BACKEND_PID=$(cat "$BACKEND_PID_FILE")
    if ps -p "$BACKEND_PID" > /dev/null 2>&1; then
        print_info "Stopping backend servers (PID: $BACKEND_PID)"
        kill "$BACKEND_PID" 2>/dev/null || true
        sleep 2
        
        # Force kill if still running
        if ps -p "$BACKEND_PID" > /dev/null 2>&1; then
            print_warning "Force killing backend servers"
            kill -9 "$BACKEND_PID" 2>/dev/null || true
        fi
        
        print_success "Backend servers stopped"
    else
        print_info "Backend servers not running"
    fi
    rm -f "$BACKEND_PID_FILE"
else
    print_info "No backend PID file found"
fi

# Stop proxy server
if [ -f "/tmp/sre_agent_proxy.pid" ]; then
    PROXY_PID=$(cat "/tmp/sre_agent_proxy.pid")
    if ps -p "$PROXY_PID" > /dev/null 2>&1; then
        print_info "Stopping proxy server (PID: $PROXY_PID)"
        kill "$PROXY_PID" 2>/dev/null || true
        sleep 2
        
        # Force kill if still running
        if ps -p "$PROXY_PID" > /dev/null 2>&1; then
            print_warning "Force killing proxy server"
            kill -9 "$PROXY_PID" 2>/dev/null || true
        fi
        
        print_success "Proxy server stopped"
    else
        print_info "Proxy server not running"
    fi
    rm -f "/tmp/sre_agent_proxy.pid"
else
    print_info "No proxy PID file found"
fi

# Stop ngrok tunnels
if [ -f "$NGROK_PID_FILE" ]; then
    print_info "Stopping ngrok tunnels"
    while IFS= read -r pid; do
        if ps -p "$pid" > /dev/null 2>&1; then
            kill "$pid" 2>/dev/null || true
        fi
    done < "$NGROK_PID_FILE"
    rm -f "$NGROK_PID_FILE"
    print_success "ngrok tunnels stopped"
else
    print_info "No ngrok PID file found"
fi

# Kill any lingering ngrok processes
pkill -f "ngrok http" 2>/dev/null || true

# Clean up temporary files
rm -f "$NGROK_URLS_FILE"
rm -f /tmp/sre_agent_backend.log
rm -f /tmp/sre_agent_proxy.log
rm -f /tmp/ngrok_*.log

print_success "All processes stopped and cleaned up"

echo -e "\n${BLUE}To start a new session, run:${NC}"
echo -e "  ./setup_ngrok_session.sh\n"
