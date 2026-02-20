# SRE Agent - ngrok Session Automation

Complete automation for managing ngrok development sessions with the SRE Agent project.

## 📦 What's Included

### Automation Scripts
- `setup_ngrok_session.sh` - Start everything (backends, ngrok, specs, S3, gateway)
- `stop_ngrok_session.sh` - Stop everything cleanly
- `check_ngrok_session.sh` - Check status of all components
- `test_automation_setup.sh` - Verify prerequisites before first use
- `make_scripts_executable.sh` - Make all scripts executable

### Documentation
- `NGROK_QUICK_START.md` - One-page quick reference
- `NGROK_SESSION_GUIDE.md` - Complete detailed guide
- `AUTOMATION_SUMMARY.md` - Overview and architecture
- `README_AUTOMATION.md` - This file

---

## 🚀 Quick Start (First Time)

### 1. Test Your Setup
```bash
bash test_automation_setup.sh
```

This checks:
- ✅ All scripts are present and executable
- ✅ ngrok is installed and authenticated
- ✅ AWS CLI is installed and configured
- ✅ Python is installed
- ✅ Project structure is correct
- ✅ S3 bucket is accessible

### 2. Fix Any Issues
```bash
# Make scripts executable
bash make_scripts_executable.sh

# Install ngrok (if needed)
sudo snap install ngrok

# Authenticate ngrok (if needed)
ngrok config add-authtoken YOUR_TOKEN

# Configure AWS (if needed)
aws configure
```

### 3. Start Your First Session
```bash
./setup_ngrok_session.sh
```

Wait 10 minutes for gateway targets to become READY.

### 4. Verify Everything Works
```bash
./check_ngrok_session.sh
```

### 5. Test Your Agent
```bash
cd sre_agent
uv run sre-agent --prompt "List pods in production" --debug
```

### 6. Stop When Done
```bash
./stop_ngrok_session.sh
```

---

## 📋 Daily Usage (After First Time)

```bash
# Start session
./setup_ngrok_session.sh

# Wait 10 minutes...

# Check status
./check_ngrok_session.sh

# Test agent
cd sre_agent && uv run sre-agent --prompt "Your prompt here" --debug

# Develop and test...

# Stop session
./stop_ngrok_session.sh
```

---

## 🎯 What Gets Automated

| Manual Step | Automated? | Time Saved |
|-------------|------------|------------|
| Start 4 backend servers | ✅ Yes | 2 min |
| Start 4 ngrok tunnels | ✅ Yes | 2 min |
| Copy 4 ngrok URLs | ✅ Yes | 2 min |
| Edit 4 OpenAPI specs | ✅ Yes | 5 min |
| Upload 4 specs to S3 | ✅ Yes | 2 min |
| Generate gateway token | ✅ Yes | 1 min |
| Update gateway targets | ✅ Yes | 1 min |
| **Total** | **All automated** | **15+ min** |

---

## 🔍 How It Works

### Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│ setup_ngrok_session.sh                                       │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Cleanup old processes                                   │
│     └─ Kill old backends and ngrok tunnels                  │
│                                                              │
│  2. Start backend servers (4 FastAPI apps)                  │
│     └─ Ports: 8011, 8012, 8013, 8014                        │
│                                                              │
│  3. Start ngrok tunnels (4 tunnels)                         │
│     └─ One tunnel per backend port                          │
│                                                              │
│  4. Collect ngrok URLs                                      │
│     └─ Query ngrok API, extract HTTPS URLs                  │
│                                                              │
│  5. Regenerate OpenAPI specs                                │
│     └─ Replace {{BACKEND_DOMAIN}} with ngrok URLs           │
│                                                              │
│  6. Upload specs to S3                                      │
│     └─ Upload all 4 YAML files                              │
│                                                              │
│  7. Refresh gateway                                         │
│     └─ Generate token, update targets                       │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Data Flow

```
Local Backends (localhost:8011-8014)
         ↓
ngrok Tunnels (https://xxx.ngrok-free.app)
         ↓
OpenAPI Specs (updated with ngrok URLs)
         ↓
S3 Bucket (specs uploaded)
         ↓
AWS Gateway (reads specs, creates targets)
         ↓
SRE Agent (calls gateway → gateway calls ngrok → ngrok tunnels to backends)
```

---

## 📊 Process Tracking

The scripts track processes using temporary files:

| File | Purpose |
|------|---------|
| `/tmp/sre_agent_backend.pid` | Backend server PID |
| `/tmp/sre_agent_ngrok_pids.txt` | ngrok tunnel PIDs |
| `/tmp/sre_agent_ngrok_urls.txt` | ngrok domains |
| `/tmp/sre_agent_backend.log` | Backend server logs |
| `/tmp/ngrok_8011.log` | ngrok tunnel logs (per port) |

---

## 🛠️ Troubleshooting

### Scripts Not Executable
```bash
bash make_scripts_executable.sh
```

### ngrok Not Installed
```bash
sudo snap install ngrok
ngrok config add-authtoken YOUR_TOKEN
```

### Backend Won't Start
```bash
# Check logs
cat /tmp/sre_agent_backend.log

# Common issues:
# - Ports in use: kill old processes
# - Dependencies missing: cd backend && pip install -r requirements.txt
```

### ngrok Tunnels Fail
```bash
# Check logs
cat /tmp/ngrok_8011.log

# Common issues:
# - Not authenticated: ngrok config add-authtoken YOUR_TOKEN
# - Rate limit: wait or upgrade plan
```

### Gateway Targets Not READY
```bash
# Check status
cd gateway && python check_gateway_targets.py

# Common issues:
# - Wait 10 minutes (AWS is slow)
# - Check S3 upload: aws s3 ls s3://sre-agent-specs-1771225925/devops-multiagent-demo/
# - Check specs are valid: cat backend/openapi_specs/k8s_api.yaml
```

### Agent Can't Reach Backend
```bash
# 1. Check everything is running
./check_ngrok_session.sh

# 2. Test ngrok URL directly
curl https://YOUR_NGROK_URL.ngrok-free.app/health

# 3. Check gateway targets
cd gateway && python check_gateway_targets.py

# 4. Test with debug
cd sre_agent && uv run sre-agent --prompt "Test" --debug
```

---

## 💡 Pro Tips

### Use tmux/screen
```bash
tmux new -s sre-agent
./setup_ngrok_session.sh
# Ctrl+B, D to detach
```

### Monitor Logs
```bash
# Backend logs
tail -f /tmp/sre_agent_backend.log

# ngrok logs
tail -f /tmp/ngrok_8011.log
```

### Auto-Check Status
```bash
# Check every hour
watch -n 3600 ./check_ngrok_session.sh
```

### Test ngrok URLs Immediately
```bash
# Don't wait 10 minutes, test right away
curl https://YOUR_NGROK_URL.ngrok-free.app/health
```

---

## 🎓 Understanding the Scripts

### setup_ngrok_session.sh

**What it does:**
- Automates the entire setup process
- Runs everything in background
- Tracks all processes with PID files
- Provides colored output for easy reading

**Key functions:**
- `cleanup_old_processes()` - Kills old processes
- `start_backend_servers()` - Starts backends in background
- `start_ngrok_tunnels()` - Starts 4 ngrok tunnels
- `collect_ngrok_urls()` - Queries ngrok API for URLs
- `regenerate_openapi_specs()` - Updates specs with URLs
- `upload_specs_to_s3()` - Uploads to S3
- `refresh_gateway()` - Updates gateway

**Output:**
- Colored status messages
- Summary of ngrok URLs
- Next steps instructions

### stop_ngrok_session.sh

**What it does:**
- Stops all backend servers
- Stops all ngrok tunnels
- Cleans up temporary files

**Key features:**
- Graceful shutdown (SIGTERM)
- Force kill if needed (SIGKILL)
- Removes all tracking files

### check_ngrok_session.sh

**What it does:**
- Shows backend server status
- Shows ngrok tunnel status
- Displays current ngrok URLs
- Checks gateway targets

**Output:**
- Status of each component
- Current ngrok URLs
- Gateway targets status
- Quick action commands

---

## 📚 Documentation Guide

| Document | When to Read |
|----------|--------------|
| `NGROK_QUICK_START.md` | First time setup, quick reference |
| `NGROK_SESSION_GUIDE.md` | Detailed explanation, troubleshooting |
| `AUTOMATION_SUMMARY.md` | Architecture, how it works |
| `README_AUTOMATION.md` | This file - overview |
| `HOW_TO_FIX_CREDENTIAL_ISSUE.md` | Understanding the backend issue |

---

## 🔄 Complete Workflow Example

### Morning: Start Session
```bash
cd ~/projects/SRE-agent
./setup_ngrok_session.sh
```

**Output:**
```
========================================
SRE Agent ngrok Session Setup
========================================

========================================
Cleaning up old processes
========================================

✅ Cleanup complete

========================================
Starting Backend Servers
========================================

ℹ️  Backend servers starting (PID: 12345)
✅ Backend servers are running

========================================
Starting ngrok Tunnels
========================================

✅ ngrok tunnel started for port 8011 (PID: 12346)
✅ ngrok tunnel started for port 8012 (PID: 12347)
✅ ngrok tunnel started for port 8013 (PID: 12348)
✅ ngrok tunnel started for port 8014 (PID: 12349)

========================================
Collecting ngrok URLs
========================================

✅ Port 8011 → https://abc123.ngrok-free.app
✅ Port 8012 → https://def456.ngrok-free.app
✅ Port 8013 → https://ghi789.ngrok-free.app
✅ Port 8014 → https://jkl012.ngrok-free.app

========================================
Regenerating OpenAPI Specifications
========================================

✅ k8s_api.yaml generated
✅ logs_api.yaml generated
✅ metrics_api.yaml generated
✅ runbooks_api.yaml generated

========================================
Uploading Specs to S3
========================================

✅ k8s_api.yaml uploaded
✅ logs_api.yaml uploaded
✅ metrics_api.yaml uploaded
✅ runbooks_api.yaml uploaded

========================================
Refreshing Gateway Token and Targets
========================================

✅ Gateway token generated
✅ Gateway targets updated

========================================
Setup Complete!
========================================

Your ngrok session is ready!

📋 ngrok URLs:
  k8s_api: https://abc123.ngrok-free.app
  logs_api: https://def456.ngrok-free.app
  metrics_api: https://ghi789.ngrok-free.app
  runbooks_api: https://jkl012.ngrok-free.app

⏰ Next Steps:
  1. Wait 10 minutes for gateway targets to become READY
  2. Check status: cd gateway && python check_gateway_targets.py
  3. Test agent: cd sre_agent && uv run sre-agent --prompt "List pods" --debug
```

### Wait 10 Minutes
```bash
# Do other work...
# Or monitor logs:
tail -f /tmp/sre_agent_backend.log
```

### Check Status
```bash
./check_ngrok_session.sh
```

### Test Agent
```bash
cd sre_agent
uv run sre-agent --prompt "List pods in production" --debug
```

### Develop All Day
```bash
# Make changes to agent code
# Test repeatedly
uv run sre-agent --prompt "Different test" --debug
```

### Evening: Stop Session
```bash
./stop_ngrok_session.sh
```

---

## 🎯 Next Steps

### For Development
1. Use automation scripts daily
2. Keep logs open for monitoring
3. Check status regularly

### For Production
1. Test thoroughly with ngrok
2. Move to EC2 with stable domain
3. Deploy agent to AgentCore Runtime

See `HOW_TO_FIX_CREDENTIAL_ISSUE.md` for production deployment options.

---

## 📞 Getting Help

### Check Logs
```bash
tail -f /tmp/sre_agent_backend.log
tail -f /tmp/ngrok_8011.log
```

### Check Status
```bash
./check_ngrok_session.sh
```

### Test Prerequisites
```bash
bash test_automation_setup.sh
```

### Read Documentation
- Quick start: `NGROK_QUICK_START.md`
- Full guide: `NGROK_SESSION_GUIDE.md`
- Summary: `AUTOMATION_SUMMARY.md`

---

## ✨ Summary

You now have:

✅ Complete automation for ngrok sessions
✅ One command to start everything
✅ One command to stop everything
✅ One command to check status
✅ Comprehensive documentation
✅ Troubleshooting guides
✅ 15+ minutes saved per session

**Just run `./setup_ngrok_session.sh` and start developing!**
