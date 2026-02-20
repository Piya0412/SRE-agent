#!/bin/bash

# ============================================================================
# Automated ngrok Session Setup for SRE Agent (Proxy-Based for Free Tier)
# ============================================================================
# This script uses a SINGLE ngrok tunnel with path-based routing via a proxy
# This works with ngrok FREE tier!
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$HOME/projects/SRE-agent"
S3_BUCKET="sre-agent-specs-1771225925"
S3_PREFIX="devops-multiagent-demo"
BACKEND_PORTS=(8011 8012 8013 8014)
SPEC_NAMES=("k8s_api" "logs_api" "metrics_api" "runbooks_api")
PATH_PREFIXES=("k8s" "logs" "metrics" "runbooks")
PROXY_PORT=8000

# Temporary files for tracking processes
BACKEND_PID_FILE="/tmp/sre_agent_backend.pid"
PROXY_PID_FILE="/tmp/sre_agent_proxy.pid"
NGROK_PID_FILE="/tmp/sre_agent_ngrok.pid"
NGROK_URL_FILE="/tmp/sre_agent_ngrok_url.txt"

# ============================================================================
# Helper Functions
# ============================================================================

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

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

cleanup_old_processes() {
    print_header "Cleaning up old processes"
    
    # Kill old backend
    if [ -f "$BACKEND_PID_FILE" ]; then
        OLD_PID=$(cat "$BACKEND_PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            print_info "Stopping old backend (PID: $OLD_PID)"
            kill "$OLD_PID" 2>/dev/null || true
            sleep 2
        fi
        rm -f "$BACKEND_PID_FILE"
    fi
    
    # Kill old proxy
    if [ -f "$PROXY_PID_FILE" ]; then
        OLD_PID=$(cat "$PROXY_PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            print_info "Stopping old proxy (PID: $OLD_PID)"
            kill "$OLD_PID" 2>/dev/null || true
            sleep 2
        fi
        rm -f "$PROXY_PID_FILE"
    fi
    
    # Kill old ngrok
    if [ -f "$NGROK_PID_FILE" ]; then
        OLD_PID=$(cat "$NGROK_PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            print_info "Stopping old ngrok (PID: $OLD_PID)"
            kill "$OLD_PID" 2>/dev/null || true
        fi
        rm -f "$NGROK_PID_FILE"
    fi
    
    pkill -f "ngrok http" 2>/dev/null || true
    
    print_success "Cleanup complete"
}

start_backend_servers() {
    print_header "Starting Backend Servers"
    
    # Get API key
    API_KEY_FILE="$PROJECT_ROOT/gateway/.api_key_local"
    if [ -f "$API_KEY_FILE" ]; then
        export BACKEND_API_KEY=$(cat "$API_KEY_FILE")
        print_info "Loaded API key"
    else
        print_error "API key file not found: $API_KEY_FILE"
        exit 1
    fi
    
    cd "$PROJECT_ROOT/backend/servers"
    export PYTHONPATH="$PROJECT_ROOT/backend:$PYTHONPATH"
    
    nohup python run_all_servers.py > /tmp/sre_agent_backend.log 2>&1 &
    BACKEND_PID=$!
    echo "$BACKEND_PID" > "$BACKEND_PID_FILE"
    
    print_info "Backend servers starting (PID: $BACKEND_PID)"
    sleep 10
    
    if ps -p "$BACKEND_PID" > /dev/null; then
        print_success "Backend servers running"
    else
        print_error "Backend failed to start"
        cat /tmp/sre_agent_backend.log
        exit 1
    fi
}

start_proxy_server() {
    print_header "Starting Reverse Proxy"
    
    cd "$PROJECT_ROOT"
    
    # Install dependencies if needed
    python3 -c "import fastapi, httpx, uvicorn" 2>/dev/null || {
        print_info "Installing proxy dependencies..."
        pip install -q fastapi httpx uvicorn
    }
    
    nohup python3 proxy.py > /tmp/sre_agent_proxy.log 2>&1 &
    PROXY_PID=$!
    echo "$PROXY_PID" > "$PROXY_PID_FILE"
    
    print_info "Proxy starting (PID: $PROXY_PID) on port $PROXY_PORT"
    sleep 5
    
    if ps -p "$PROXY_PID" > /dev/null; then
        print_success "Proxy server running"
    else
        print_error "Proxy failed to start"
        cat /tmp/sre_agent_proxy.log
        exit 1
    fi
}

start_ngrok_tunnel() {
    print_header "Starting ngrok Tunnel"
    
    print_info "Starting single ngrok tunnel on port $PROXY_PORT..."
    
    nohup ngrok http "$PROXY_PORT" --log=stdout > /tmp/ngrok.log 2>&1 &
    NGROK_PID=$!
    echo "$NGROK_PID" > "$NGROK_PID_FILE"
    
    print_info "ngrok starting (PID: $NGROK_PID)"
    sleep 10
    
    if ! ps -p "$NGROK_PID" > /dev/null 2>&1; then
        print_error "ngrok failed to start"
        cat /tmp/ngrok.log
        exit 1
    fi
    
    print_success "ngrok tunnel established"
}

collect_ngrok_url() {
    print_header "Collecting ngrok URL"
    
    sleep 3
    
    # Parse log for URL
    NGROK_URL=$(grep -oP 'url=https://[^\s]+' /tmp/ngrok.log | head -1 | cut -d'=' -f2)
    
    if [ -z "$NGROK_URL" ]; then
        print_error "Failed to get ngrok URL"
        cat /tmp/ngrok.log
        exit 1
    fi
    
    # Remove https:// and save
    NGROK_DOMAIN=$(echo "$NGROK_URL" | sed 's|https://||')
    echo "$NGROK_DOMAIN" > "$NGROK_URL_FILE"
    
    print_success "ngrok URL: $NGROK_URL"
}

regenerate_openapi_specs() {
    print_header "Regenerating OpenAPI Specifications"
    
    cd "$PROJECT_ROOT/backend/openapi_specs"
    
    NGROK_DOMAIN=$(cat "$NGROK_URL_FILE")
    
    # Generate each spec with path prefix
    for i in "${!SPEC_NAMES[@]}"; do
        SPEC_NAME="${SPEC_NAMES[$i]}"
        PATH_PREFIX="${PATH_PREFIXES[$i]}"
        
        # The domain includes the path prefix
        FULL_DOMAIN="${NGROK_DOMAIN}/${PATH_PREFIX}"
        
        print_info "Generating ${SPEC_NAME}.yaml with: $FULL_DOMAIN"
        
        sed "s|{{BACKEND_DOMAIN}}|$FULL_DOMAIN|g" \
            "${SPEC_NAME}.yaml.template" > "${SPEC_NAME}.yaml"
        
        print_success "${SPEC_NAME}.yaml generated"
    done
    
    print_success "All OpenAPI specs regenerated"
}

upload_specs_to_s3() {
    print_header "Uploading Specs to S3"
    
    cd "$PROJECT_ROOT/backend/openapi_specs"
    
    for spec_name in "${SPEC_NAMES[@]}"; do
        print_info "Uploading ${spec_name}.yaml..."
        
        aws s3 cp "${spec_name}.yaml" \
            "s3://${S3_BUCKET}/${S3_PREFIX}/${spec_name}.yaml" \
            --quiet
        
        print_success "${spec_name}.yaml uploaded"
    done
    
    print_success "All specs uploaded to S3"
}

refresh_gateway() {
    print_header "Refreshing Gateway"
    
    cd "$PROJECT_ROOT/gateway"
    
    print_info "Generating new gateway token..."
    python generate_token.py
    print_success "Gateway token generated"
    
    print_info "Updating gateway targets..."
    python add_gateway_targets.py
    print_success "Gateway targets updated"
    
    print_warning "Gateway targets are being updated in AWS (takes ~10 minutes)"
}

print_summary() {
    print_header "Setup Complete!"
    
    NGROK_URL="https://$(cat $NGROK_URL_FILE)"
    
    echo -e "${GREEN}Your ngrok session is ready!${NC}\n"
    
    echo -e "${BLUE}📋 ngrok URL:${NC} $NGROK_URL"
    echo -e "${BLUE}📋 Proxy Port:${NC} $PROXY_PORT"
    echo ""
    echo -e "${BLUE}📋 API Endpoints:${NC}"
    for i in "${!PATH_PREFIXES[@]}"; do
        echo -e "  ${SPEC_NAMES[$i]}: $NGROK_URL/${PATH_PREFIXES[$i]}"
    done
    
    echo -e "\n${BLUE}📁 Process Info:${NC}"
    echo -e "  Backend PID: $(cat $BACKEND_PID_FILE)"
    echo -e "  Proxy PID: $(cat $PROXY_PID_FILE)"
    echo -e "  ngrok PID: $(cat $NGROK_PID_FILE)"
    
    echo -e "\n${BLUE}📁 Logs:${NC}"
    echo -e "  Backend: tail -f /tmp/sre_agent_backend.log"
    echo -e "  Proxy: tail -f /tmp/sre_agent_proxy.log"
    echo -e "  ngrok: tail -f /tmp/ngrok.log"
    
    echo -e "\n${BLUE}⏰ Next Steps:${NC}"
    echo -e "  1. Wait 10 minutes for gateway targets to become READY"
    echo -e "  2. Check: cd gateway && python check_gateway_targets.py"
    echo -e "  3. Test: cd sre_agent && uv run sre-agent --prompt \"List pods\""
    
    echo -e "\n${BLUE}🛑 To stop:${NC} ./stop_ngrok_session.sh\n"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    print_header "SRE Agent ngrok Session Setup (Proxy Mode)"
    
    cleanup_old_processes
    start_backend_servers
    start_proxy_server
    start_ngrok_tunnel
    collect_ngrok_url
    regenerate_openapi_specs
    upload_specs_to_s3
    refresh_gateway
    print_summary
}

main
