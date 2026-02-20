#!/bin/bash
# Setup ngrok tunnels for local backend testing
# This script helps you expose your local backend servers to the internet via ngrok

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║          Setup ngrok for Local Backend Testing             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ ngrok is not installed"
    echo ""
    echo "Please install ngrok:"
    echo "  1. Download from: https://ngrok.com/download"
    echo "  2. Or use snap: sudo snap install ngrok"
    echo "  3. Sign up for free account: https://dashboard.ngrok.com/signup"
    echo "  4. Get your authtoken: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "  5. Configure: ngrok config add-authtoken YOUR_TOKEN"
    echo ""
    exit 1
fi

echo "✅ ngrok is installed"
echo ""

# Check if backend servers are running
echo "🔍 Checking if backend servers are running..."
SERVERS_RUNNING=0

for PORT in 8011 8012 8013 8014; do
    if curl -s -f http://127.0.0.1:$PORT/docs > /dev/null 2>&1; then
        echo "   ✅ Port $PORT is running"
        SERVERS_RUNNING=$((SERVERS_RUNNING + 1))
    else
        echo "   ❌ Port $PORT is NOT running"
    fi
done

if [ $SERVERS_RUNNING -eq 0 ]; then
    echo ""
    echo "❌ No backend servers are running!"
    echo ""
    echo "Please start the backend servers first:"
    echo "  cd backend"
    echo "  ./scripts/start_demo_backend.sh --host 127.0.0.1"
    echo ""
    exit 1
elif [ $SERVERS_RUNNING -lt 4 ]; then
    echo ""
    echo "⚠️  Warning: Only $SERVERS_RUNNING/4 backend servers are running"
    echo ""
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    INSTRUCTIONS                             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "You need to start 4 ngrok tunnels (one for each backend server)."
echo ""
echo "Option 1: Use ngrok config file (recommended)"
echo "─────────────────────────────────────────────────────────────"
echo "1. Create ~/.ngrok2/ngrok.yml with this content:"
echo ""
cat << 'EOF'
version: "2"
authtoken: YOUR_AUTHTOKEN_HERE
tunnels:
  k8s-api:
    proto: http
    addr: 8011
  logs-api:
    proto: http
    addr: 8012
  metrics-api:
    proto: http
    addr: 8013
  runbooks-api:
    proto: http
    addr: 8014
EOF
echo ""
echo "2. Start all tunnels:"
echo "   ngrok start --all"
echo ""
echo "Option 2: Start tunnels manually (4 separate terminals)"
echo "─────────────────────────────────────────────────────────────"
echo "Terminal 1: ngrok http 8011"
echo "Terminal 2: ngrok http 8012"
echo "Terminal 3: ngrok http 8013"
echo "Terminal 4: ngrok http 8014"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    NEXT STEPS                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "After starting ngrok tunnels:"
echo ""
echo "1. Note down the 4 ngrok URLs (e.g., https://abc123.ngrok.io)"
echo ""
echo "2. Update OpenAPI spec templates with ngrok URLs:"
echo "   Edit: backend/openapi_specs/*.yaml.template"
echo "   Replace server URLs with your ngrok URLs"
echo ""
echo "3. Regenerate OpenAPI specs:"
echo "   cd backend/openapi_specs"
echo "   ./generate_specs.sh"
echo ""
echo "4. Upload to S3:"
echo "   aws s3 cp k8s_api.yaml s3://sre-agent-specs-1771225925/devops-multiagent-demo/"
echo "   aws s3 cp logs_api.yaml s3://sre-agent-specs-1771225925/devops-multiagent-demo/"
echo "   aws s3 cp metrics_api.yaml s3://sre-agent-specs-1771225925/devops-multiagent-demo/"
echo "   aws s3 cp runbooks_api.yaml s3://sre-agent-specs-1771225925/devops-multiagent-demo/"
echo ""
echo "5. Update gateway targets (forces reload):"
echo "   bash fix_gateway_backend_urls.sh"
echo ""
echo "6. Wait 2-3 minutes, then test:"
echo "   cd sre_agent"
echo "   uv run sre-agent --prompt 'List pods in production'"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    IMPORTANT NOTES                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  ngrok free tier limitations:"
echo "   - URLs change every time you restart ngrok"
echo "   - Rate limits apply"
echo "   - Not suitable for production"
echo ""
echo "💡 For production, use EC2 with a real domain and SSL certificates"
echo "   See: HOW_TO_FIX_CREDENTIAL_ISSUE.md"
echo ""
