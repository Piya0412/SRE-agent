#!/bin/bash

# ============================================================================
# Automated ngrok Session Setup for SRE Agent
# ============================================================================
# This script automates the entire process of:
# 1. Starting backend servers
# 2. Starting ngrok tunnels
# 3. Collecting ngrok URLs
# 4. Regenerating OpenAPI specs with ngrok URLs
# 5. Uploading specs to S3
# 6. Refreshing gateway token and targets
#
# Run this script at the start of each development session.
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
    
    # Kill old backend processes
    if [ -f "$BACKEND_PID_FILE" ]; then
        OLD_PID=$(cat "$BACKEND_PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            print_info "Stopping old backend process (PID: $OLD_PID)"
            kill "$OLD_PID" 2>/dev/null || true
            sleep 2
        fi
        rm -f "$BACKEND_PID_FILE"
    fi
    
    # Kill old proxy processes
    if [ -f "$PROXY_PID_FILE" ]; then
        OLD_PID=$(cat "$PROXY_PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            print_info "Stopping old proxy process (PID: $OLD_PID)"
            kill "$OLD_PID" 2>/dev/null || true
            sleep 2
        fi
        rm -f "$PROXY_PID_FILE"
    fi
    
    # Kill old ngrok processes
    if [ -f "$NGROK_PID_FILE" ]; then
        OLD_PID=$(cat "$NGROK_PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            print_info "Stopping old ngrok process (PID: $OLD_PID)"
            kill "$OLD_PID" 2>/dev/null || true
        fi
        rm -f "$NGROK_PID_FILE"
    fi
    
    # Also kill any lingering ngrok processes
    pkill -f "ngrok http" 2>/dev/null || true
    
    print_success "Cleanup complete"
}

start_backend_servers() {
    print_header "Starting Backend Servers"
    
    # Get API key from gateway directory
    API_KEY_FILE="$PROJECT_ROOT/gateway/.api_key_local"
    if [ -f "$API_KEY_FILE" ]; then
        export BACKEND_API_KEY=$(cat "$API_KEY_FILE")
        print_info "Loaded API key from $API_KEY_FILE"
    else
        print_error "API key file not found: $API_KEY_FILE"
        print_info "Backend servers may fail to start without API key"
    fi
    
    cd "$PROJECT_ROOT/backend/servers"
    
    # Set PYTHONPATH to include backend directory
    export PYTHONPATH="$PROJECT_ROOT/backend:$PYTHONPATH"
    
    # Start backend servers in background
    nohup python run_all_servers.py > /tmp/sre_agent_backend.log 2>&1 &
    BACKEND_PID=$!
    echo "$BACKEND_PID" > "$BACKEND_PID_FILE"
    
    print_info "Backend servers starting (PID: $BACKEND_PID)"
    print_info "Waiting 10 seconds for servers to initialize..."
    sleep 10
    
    # Verify servers are running
    if ps -p "$BACKEND_PID" > /dev/null; then
        print_success "Backend servers are running"
        print_info "Logs: tail -f /tmp/sre_agent_backend.log"
    else
        print_error "Backend servers failed to start"
        print_error "Check logs: cat /tmp/sre_agent_backend.log"
        exit 1
    fi
}

start_proxy_server() {
    print_header "Starting Reverse Proxy"
    
    cd "$PROJECT_ROOT"
    
    # Check if dependencies are installed
    print_info "Checking proxy dependencies..."
    python -c "import fastapi, httpx, uvicorn" 2>/dev/null || {
        print_warning "Installing proxy dependencies..."
        pip install -q fastapi httpx uvicorn
    }
    
    # Start proxy server in background
    nohup python proxy.py > /tmp/sre_agent_proxy.log 2>&1 &
    PROXY_PID=$!
    echo "$PROXY_PID" > /tmp/sre_agent_proxy.pid
    
    print_info "Proxy server starting (PID: $PROXY_PID)"
    print_info "Waiting 5 seconds for proxy to initialize..."
    sleep 5
    
    # Verify proxy is running
    if ps -p "$PROXY_PID" > /dev/null; then
        print_success "Proxy server is running on port 8000"
        print_info "Logs: tail -f /tmp/sre_agent_proxy.log"
    else
        print_error "Proxy server failed to start"
        print_error "Check logs: cat /tmp/sre_agent_proxy.log"
        exit 1
    fi
}

start_ngrok_tunnels() {
    print_header "Starting ngrok Tunnel"
    
    rm -f "$NGROK_PID_FILE"
    
    print_info "Starting single ngrok tunnel for proxy (port 8000)..."
    
    # Start single ngrok tunnel for the proxy
    nohup ngrok http 8000 --log=stdout > /tmp/ngrok_proxy.log 2>&1 &
    NGROK_PID=$!
    echo "$NGROK_PID" >> "$NGROK_PID_FILE"
    
    print_success "ngrok tunnel started (PID: $NGROK_PID)"
    print_info "Waiting 10 seconds for tunnel to establish..."
    sleep 10
    
    # Verify ngrok is still running
    if ! ps -p "$NGROK_PID" > /dev/null 2>&1; then
        print_error "ngrok process exited unexpectedly"
        print_info "Log contents:"
        cat /tmp/ngrok_proxy.log
        exit 1
    fi
    
    print_success "ngrok tunnel established"
}

collect_ngrok_urls() {
    print_header "Collecting ngrok URL"
    
    rm -f "$NGROK_URLS_FILE"
    
    print_info "Parsing ngrok log file for tunnel URL..."
    
    # Wait a bit more to ensure URL is in the log
    sleep 3
    
    # Extract HTTPS URL from the log file
    TUNNEL_URL=$(grep -oP 'url=https://[^\s]+' /tmp/ngrok_proxy.log | head -1 | cut -d'=' -f2)
    
    if [ -z "$TUNNEL_URL" ]; then
        print_error "Failed to get ngrok URL"
        print_info "Log file contents:"
        cat /tmp/ngrok_proxy.log
        exit 1
    fi
    
    # Remove https:// prefix and store just the domain
    DOMAIN=$(echo "$TUNNEL_URL" | sed 's|https://||')
    
    print_success "ngrok URL: $TUNNEL_URL"
    
    # Create URLs for each service with path prefixes
    echo "${DOMAIN}/k8s" >> "$NGROK_URLS_FILE"
    echo "${DOMAIN}/logs" >> "$NGROK_URLS_FILE"
    echo "${DOMAIN}/metrics" >> "$NGROK_URLS_FILE"
    echo "${DOMAIN}/runbooks" >> "$NGROK_URLS_FILE"
    
    echo ""
    print_success "Service URLs created:"
    print_info "  k8s-api:      https://${DOMAIN}/k8s"
    print_info "  logs-api:     https://${DOMAIN}/logs"
    print_info "  metrics-api:  https://${DOMAIN}/metrics"
    print_info "  runbooks-api: https://${DOMAIN}/runbooks"
}

regenerate_openapi_specs() {
    print_header "Regenerating OpenAPI Specifications"
    
    cd "$PROJECT_ROOT/backend/openapi_specs"
    
    # Read the collected URLs
    mapfile -t NGROK_DOMAINS < "$NGROK_URLS_FILE"
    
    # Generate each spec with its corresponding ngrok domain
    for i in "${!SPEC_NAMES[@]}"; do
        SPEC_NAME="${SPEC_NAMES[$i]}"
        NGROK_DOMAIN="${NGROK_DOMAINS[$i]}"
        PORT="${BACKEND_PORTS[$i]}"
        
        print_info "Generating ${SPEC_NAME}.yaml with domain: $NGROK_DOMAIN"
        
        # Use sed to replace the domain in the template
        sed "s|{{BACKEND_DOMAIN}}|$NGROK_DOMAIN|g" \
            "${SPEC_NAME}.yaml.template" > "${SPEC_NAME}.yaml"
        
        print_success "${SPEC_NAME}.yaml generated"
    done
    
    echo ""
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
    
    echo ""
    print_success "All specs uploaded to S3"
}

refresh_gateway() {
    print_header "Refreshing Gateway Token and Targets"
    
    cd "$PROJECT_ROOT/gateway"
    
    # Generate new token
    print_info "Generating new gateway token..."
    python generate_token.py
    print_success "Gateway token generated"
    
    # Update gateway targets (forces reload of S3 specs)
    print_info "Updating gateway targets..."
    python add_gateway_targets.py
    print_success "Gateway targets updated"
    
    print_warning "Gateway targets are being updated in AWS..."
    print_warning "This takes about 10 minutes to complete"
    print_info "You can check status with: cd gateway && python check_gateway_targets.py"
}

print_summary() {
    print_header "Setup Complete!"
    
    echo -e "${GREEN}Your ngrok session is ready!${NC}\n"
    
    echo -e "${BLUE}📋 ngrok URLs:${NC}"
    mapfile -t NGROK_DOMAINS < "$NGROK_URLS_FILE"
    for i in "${!SPEC_NAMES[@]}"; do
        echo -e "  ${SPEC_NAMES[$i]}: https://${NGROK_DOMAINS[$i]}"
    done
    
    echo -e "\n${BLUE}📁 Process Info:${NC}"
    echo -e "  Backend PID: $(cat $BACKEND_PID_FILE)"
    echo -e "  Backend logs: tail -f /tmp/sre_agent_backend.log"
    echo -e "  ngrok PIDs: $(cat $NGROK_PID_FILE | tr '\n' ' ')"
    
    echo -e "\n${BLUE}⏰ Next Steps:${NC}"
    echo -e "  1. Wait 10 minutes for gateway targets to become READY"
    echo -e "  2. Check status: cd gateway && python check_gateway_targets.py"
    echo -e "  3. Test agent: cd sre_agent && uv run sre-agent --prompt \"List pods\" --debug"
    
    echo -e "\n${BLUE}🛑 To stop everything:${NC}"
    echo -e "  Run: ./stop_ngrok_session.sh"
    
    echo -e "\n${YELLOW}⚠️  Remember: ngrok URLs change every time you restart!${NC}"
    echo -e "${YELLOW}   Run this script again at the start of each session.${NC}\n"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    print_header "SRE Agent ngrok Session Setup"
    
    # Check prerequisites
    if ! command -v ngrok &> /dev/null; then
        print_error "ngrok is not installed"
        print_info "Install with: sudo snap install ngrok"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Execute setup steps
    cleanup_old_processes
    start_backend_servers
    start_proxy_server
    start_ngrok_tunnels
    collect_ngrok_urls
    regenerate_openapi_specs
    upload_specs_to_s3
    refresh_gateway
    print_summary
}

# Run main function
main
