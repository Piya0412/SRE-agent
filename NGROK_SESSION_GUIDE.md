# ngrok Session Automation Guide

This guide explains how to use the automated scripts for managing your ngrok development sessions.

## 🎯 Problem Solved

Every time you restart ngrok, the URLs change. This means you need to:
1. Restart backend servers
2. Restart ngrok tunnels
3. Collect new ngrok URLs
4. Update OpenAPI specs with new URLs
5. Upload specs to S3
6. Refresh gateway token
7. Update gateway targets

**These scripts automate all of this!**

---

## 📁 Scripts Overview

### 1. `setup_ngrok_session.sh` - Start Everything

**What it does:**
- Cleans up any old processes
- Starts all 4 backend servers
- Starts 4 ngrok tunnels (one per port)
- Automatically collects ngrok URLs
- Regenerates OpenAPI specs with new URLs
- Uploads specs to S3
- Refreshes gateway token and targets

**Usage:**
```bash
./setup_ngrok_session.sh
```

**Output:**
- Backend servers running in background
- ngrok tunnels running in background
- All specs uploaded to S3
- Gateway targets updated (takes ~10 min to become READY)

---

### 2. `stop_ngrok_session.sh` - Stop Everything

**What it does:**
- Stops all backend servers
- Stops all ngrok tunnels
- Cleans up temporary files and logs

**Usage:**
```bash
./stop_ngrok_session.sh
```

---

### 3. `check_ngrok_session.sh` - Check Status

**What it does:**
- Shows status of backend servers
- Shows status of ngrok tunnels
- Displays current ngrok URLs
- Checks gateway targets status

**Usage:**
```bash
./check_ngrok_session.sh
```

---

## 🚀 Quick Start Workflow

### Starting a New Session

```bash
# 1. Start everything
./setup_ngrok_session.sh

# 2. Wait 10 minutes for gateway targets to become READY
# (You can do other work during this time)

# 3. Check status
./check_ngrok_session.sh

# 4. Test your agent
cd sre_agent
uv run sre-agent --prompt "List pods in production" --debug
```

### During Development

```bash
# Check if everything is still running
./check_ngrok_session.sh

# View backend logs
tail -f /tmp/sre_agent_backend.log

# Test agent
cd sre_agent
uv run sre-agent --prompt "Your test prompt" --debug
```

### Ending Your Session

```bash
# Stop everything cleanly
./stop_ngrok_session.sh
```

---

## 📋 What Happens Behind the Scenes

### Step 1: Cleanup
- Kills any old backend processes
- Kills any old ngrok processes
- Removes stale PID files

### Step 2: Start Backends
- Runs `backend/servers/run_all_servers.py` in background
- Servers listen on ports 8011, 8012, 8013, 8014
- Logs to `/tmp/sre_agent_backend.log`

### Step 3: Start ngrok Tunnels
- Starts 4 ngrok tunnels (one per backend port)
- Each tunnel gets a unique HTTPS URL
- Logs to `/tmp/ngrok_8011.log`, etc.

### Step 4: Collect URLs
- Queries ngrok API at `http://localhost:4040/api/tunnels`
- Extracts HTTPS URLs for each port
- Saves to `/tmp/sre_agent_ngrok_urls.txt`

### Step 5: Regenerate Specs
- For each OpenAPI spec template:
  - Replaces `{{BACKEND_DOMAIN}}` with ngrok domain
  - Generates final `.yaml` file
- Specs: `k8s_api.yaml`, `logs_api.yaml`, `metrics_api.yaml`, `runbooks_api.yaml`

### Step 6: Upload to S3
- Uploads all 4 specs to S3 bucket
- Bucket: `sre-agent-specs-1771225925`
- Prefix: `devops-multiagent-demo/`

### Step 7: Refresh Gateway
- Generates new gateway token
- Updates gateway targets (forces reload of S3 specs)
- Takes ~10 minutes for targets to become READY

---

## 🔍 Troubleshooting

### Backend servers won't start

```bash
# Check logs
cat /tmp/sre_agent_backend.log

# Common issues:
# - Ports already in use: kill old processes
# - Python dependencies missing: cd backend && pip install -r requirements.txt
```

### ngrok tunnels fail

```bash
# Check if ngrok is installed
which ngrok

# Install if missing
sudo snap install ngrok

# Check ngrok logs
cat /tmp/ngrok_8011.log

# Common issues:
# - ngrok not authenticated: ngrok config add-authtoken YOUR_TOKEN
# - Rate limit hit: wait or upgrade ngrok plan
```

### Can't collect ngrok URLs

```bash
# Check if ngrok API is accessible
curl http://localhost:4040/api/tunnels

# If empty, ngrok tunnels aren't running
# Restart: ./stop_ngrok_session.sh && ./setup_ngrok_session.sh
```

### Gateway targets not READY

```bash
# Check status
cd gateway
python check_gateway_targets.py

# If stuck in CREATING:
# - Wait 10 minutes (AWS is slow)
# - Check S3 specs are uploaded: aws s3 ls s3://sre-agent-specs-1771225925/devops-multiagent-demo/

# If FAILED:
# - Check OpenAPI specs are valid
# - Check ngrok URLs are accessible from internet
```

### Agent can't reach backend

```bash
# 1. Check backend is running
./check_ngrok_session.sh

# 2. Check ngrok URLs are accessible
curl https://YOUR_NGROK_URL.ngrok-free.app/health

# 3. Check gateway targets are READY
cd gateway && python check_gateway_targets.py

# 4. Test with debug mode
cd sre_agent
uv run sre-agent --prompt "List pods" --debug
```

---

## 📊 Process Tracking

The scripts track processes using these files:

- `/tmp/sre_agent_backend.pid` - Backend server PID
- `/tmp/sre_agent_ngrok_pids.txt` - ngrok tunnel PIDs (one per line)
- `/tmp/sre_agent_ngrok_urls.txt` - ngrok domains (one per line)
- `/tmp/sre_agent_backend.log` - Backend server logs
- `/tmp/ngrok_8011.log` - ngrok tunnel logs (one per port)

---

## 🎓 Understanding the Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ YOUR LOCAL MACHINE                                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Backend Servers (localhost:8011-8014)                           │
│         ↓                                                       │
│ ngrok Tunnels (https://xxx.ngrok-free.app)                     │
│         ↓                                                       │
│ OpenAPI Specs (updated with ngrok URLs)                        │
│         ↓                                                       │
│ S3 Bucket (specs uploaded)                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ AWS CLOUD                                                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ AgentCore Gateway                                              │
│   ├── Reads specs from S3                                      │
│   ├── Creates targets for each backend                         │
│   └── Routes agent requests to ngrok URLs                      │
│                                                                 │
│ Your SRE Agent (local or in AgentCore Runtime)                 │
│   ├── Calls Gateway                                            │
│   ├── Gateway calls ngrok URLs                                 │
│   └── ngrok tunnels to your local backends                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⚡ Pro Tips

1. **Run in tmux/screen** - So you can detach and leave it running
   ```bash
   tmux new -s sre-agent
   ./setup_ngrok_session.sh
   # Ctrl+B, D to detach
   ```

2. **Check status regularly** - ngrok can disconnect
   ```bash
   watch -n 60 ./check_ngrok_session.sh
   ```

3. **Keep logs open** - Monitor for issues
   ```bash
   tail -f /tmp/sre_agent_backend.log
   ```

4. **Test immediately** - Don't wait 10 minutes
   ```bash
   # Test ngrok URLs directly
   curl https://YOUR_NGROK_URL.ngrok-free.app/health
   ```

5. **Upgrade ngrok** - Free tier has limits
   - Consider ngrok paid plan for stable URLs
   - Or move to EC2 for production

---

## 🔄 Daily Workflow

```bash
# Morning: Start session
./setup_ngrok_session.sh

# Wait 10 minutes, then test
./check_ngrok_session.sh
cd sre_agent && uv run sre-agent --prompt "Test" --debug

# During day: Develop and test
# (backends and ngrok stay running)

# Evening: Stop session
./stop_ngrok_session.sh
```

---

## 🎯 Next Steps

Once you've tested with ngrok and everything works:

1. **Consider EC2 deployment** for stable URLs
   - See `HOW_TO_FIX_CREDENTIAL_ISSUE.md` Option 1
   - One-time setup, permanent URLs

2. **Deploy agent to AgentCore Runtime**
   - See `HOW_TO_FIX_CREDENTIAL_ISSUE.md` Option 3
   - Production deployment in AWS

---

## 📞 Need Help?

- Check logs: `tail -f /tmp/sre_agent_backend.log`
- Check status: `./check_ngrok_session.sh`
- Read troubleshooting section above
- See `HOW_TO_FIX_CREDENTIAL_ISSUE.md` for detailed explanations
