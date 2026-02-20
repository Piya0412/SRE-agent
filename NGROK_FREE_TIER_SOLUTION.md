# ngrok Free Tier Solution - Single Tunnel + Reverse Proxy

## 🎯 The Problem

ngrok free tier only allows 1 online endpoint at a time. We need 4 backend APIs accessible.

## ✅ The Solution

Use a single ngrok tunnel pointing to a local reverse proxy that routes requests to the 4 backend servers based on URL path.

## 🏗️ Architecture

```
Internet
    ↓
ngrok (single tunnel)
https://xxx.ngrok-free.app
    ↓
Local Reverse Proxy (port 8000)
    ├── /k8s/*      → Backend Server (port 8011)
    ├── /logs/*     → Backend Server (port 8012)
    ├── /metrics/*  → Backend Server (port 8013)
    └── /runbooks/* → Backend Server (port 8014)
```

## 📁 Files Created

1. **proxy.py** - FastAPI reverse proxy server
   - Routes requests based on path prefix
   - Forwards to appropriate backend server
   - Handles all HTTP methods

2. **Updated setup_ngrok_session.sh**
   - Starts 4 backend servers
   - Starts reverse proxy
   - Starts single ngrok tunnel
   - Generates OpenAPI specs with path prefixes
   - Uploads to S3
   - Refreshes gateway

## 🚀 How It Works

### Step 1: Start Backend Servers
```bash
# 4 FastAPI servers on ports 8011-8014
python backend/servers/run_all_servers.py
```

### Step 2: Start Reverse Proxy
```bash
# Proxy on port 8000
python proxy.py
```

### Step 3: Start ngrok
```bash
# Single tunnel to proxy
ngrok http 8000
# Gets URL like: https://abc123.ngrok-free.app
```

### Step 4: Generate OpenAPI Specs
Each spec gets the same base URL with different path prefix:
- k8s_api.yaml: `https://abc123.ngrok-free.app/k8s`
- logs_api.yaml: `https://abc123.ngrok-free.app/logs`
- metrics_api.yaml: `https://abc123.ngrok-free.app/metrics`
- runbooks_api.yaml: `https://abc123.ngrok-free.app/runbooks`

### Step 5: Upload & Refresh
- Upload specs to S3
- Refresh gateway token
- Update gateway targets

## 🎮 Usage

### Start Everything
```bash
./setup_ngrok_session.sh
```

This automatically:
1. ✅ Starts 4 backend servers
2. ✅ Starts reverse proxy
3. ✅ Starts ngrok tunnel
4. ✅ Collects ngrok URL
5. ✅ Generates OpenAPI specs with path prefixes
6. ✅ Uploads to S3
7. ✅ Refreshes gateway

### Check Status
```bash
./check_ngrok_session.sh
```

### Stop Everything
```bash
./stop_ngrok_session.sh
```

## 🔍 Testing

### Test Proxy Locally
```bash
# Health check
curl http://localhost:8000/health

# Test k8s API through proxy
curl http://localhost:8000/k8s/pods/status?namespace=production \
  -H "X-API-Key: YOUR_KEY"
```

### Test Through ngrok
```bash
# Get your ngrok URL from the setup output
NGROK_URL="https://abc123.ngrok-free.app"

# Test k8s API
curl $NGROK_URL/k8s/pods/status?namespace=production \
  -H "X-API-Key: YOUR_KEY"
```

## 📊 Request Flow Example

```
User Request:
GET https://abc123.ngrok-free.app/k8s/pods/status?namespace=production

    ↓ ngrok forwards to
    
GET http://localhost:8000/k8s/pods/status?namespace=production

    ↓ proxy.py routes to
    
GET http://localhost:8011/pods/status?namespace=production

    ↓ k8s_server.py responds
    
{"status": "ok", "pods": [...]}
```

## 💡 Benefits

1. **Works with ngrok free tier** - Only 1 tunnel needed
2. **No URL conflicts** - Single domain, different paths
3. **Fully automated** - One command to start everything
4. **Easy to debug** - All logs in /tmp/
5. **Clean shutdown** - One command to stop everything

## 🛠️ Troubleshooting

### Proxy won't start
```bash
# Check if port 8000 is in use
lsof -i :8000

# Check proxy logs
tail -f /tmp/sre_agent_proxy.log
```

### Backend servers won't start
```bash
# Check backend logs
tail -f /tmp/sre_agent_backend.log

# Verify API key is set
echo $BACKEND_API_KEY
```

### ngrok tunnel fails
```bash
# Check ngrok logs
cat /tmp/ngrok_proxy.log

# Verify authentication
ngrok config check
```

### Gateway targets not working
```bash
# Check OpenAPI specs have correct URLs
cat backend/openapi_specs/k8s_api.yaml | grep url

# Verify specs uploaded to S3
aws s3 ls s3://sre-agent-specs-1771225925/devops-multiagent-demo/

# Check gateway targets status
cd gateway && python check_gateway_targets.py
```

## 📝 Notes

- The proxy adds minimal latency (~1-5ms)
- All HTTP methods are supported (GET, POST, PUT, DELETE, etc.)
- Headers and query parameters are forwarded correctly
- The proxy handles errors gracefully with 502 responses

## 🎯 Next Steps

Once everything is working:
1. Test your agent: `cd sre_agent && uv run sre-agent --prompt "List pods" --debug`
2. For production, consider moving to EC2 with a real domain
3. Or upgrade ngrok to paid plan for multiple simultaneous tunnels

## ✨ Summary

This solution elegantly works around ngrok free tier limitations by using a reverse proxy to multiplex 4 backend services through a single ngrok tunnel. The automation script handles everything, making it a one-command solution!
