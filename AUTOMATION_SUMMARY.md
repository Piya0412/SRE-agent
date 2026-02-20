# ngrok Session Automation - Summary

## ✅ What Was Created

I've created a complete automation solution for your ngrok development workflow. Here's what you now have:

### 🔧 Scripts Created

1. **`setup_ngrok_session.sh`** (Main automation script)
   - Starts all 4 backend servers
   - Starts 4 ngrok tunnels
   - Collects ngrok URLs automatically
   - Regenerates OpenAPI specs with new URLs
   - Uploads specs to S3
   - Refreshes gateway token and targets
   - **Replaces all manual steps!**

2. **`stop_ngrok_session.sh`** (Cleanup script)
   - Stops all backend servers
   - Stops all ngrok tunnels
   - Cleans up temporary files

3. **`check_ngrok_session.sh`** (Status checker)
   - Shows backend server status
   - Shows ngrok tunnel status
   - Displays current ngrok URLs
   - Checks gateway targets status

4. **`make_scripts_executable.sh`** (Helper)
   - Makes all scripts executable
   - Run this first!

### 📚 Documentation Created

1. **`NGROK_SESSION_GUIDE.md`** (Complete guide)
   - Detailed explanation of each script
   - Troubleshooting section
   - Behind-the-scenes details
   - Pro tips and daily workflow

2. **`NGROK_QUICK_START.md`** (One-page reference)
   - Quick commands
   - Common troubleshooting
   - Complete workflow in one page

3. **`AUTOMATION_SUMMARY.md`** (This file)
   - Overview of what was created
   - Quick start instructions

---

## 🚀 How to Use (First Time)

### Step 1: Make Scripts Executable
```bash
cd ~/projects/SRE-agent
bash make_scripts_executable.sh
```

### Step 2: Verify Prerequisites
```bash
# Check ngrok is installed
which ngrok

# If not installed:
sudo snap install ngrok

# Authenticate ngrok (if not done)
ngrok config add-authtoken YOUR_TOKEN
```

### Step 3: Start Your First Session
```bash
./setup_ngrok_session.sh
```

This will:
- ✅ Clean up old processes
- ✅ Start backend servers
- ✅ Start ngrok tunnels
- ✅ Collect ngrok URLs
- ✅ Regenerate OpenAPI specs
- ✅ Upload to S3
- ✅ Refresh gateway

**Wait 10 minutes** for gateway targets to become READY.

### Step 4: Check Status
```bash
./check_ngrok_session.sh
```

### Step 5: Test Your Agent
```bash
cd sre_agent
uv run sre-agent --prompt "List pods in production" --debug
```

### Step 6: Stop When Done
```bash
./stop_ngrok_session.sh
```

---

## 📋 Daily Workflow (After First Time)

```bash
# Morning: Start
./setup_ngrok_session.sh

# Wait 10 minutes...

# Verify
./check_ngrok_session.sh

# Test
cd sre_agent && uv run sre-agent --prompt "Test" --debug

# Develop all day...

# Evening: Stop
./stop_ngrok_session.sh
```

---

## 🎯 What Problem This Solves

### Before (Manual Process)
```bash
# Terminal 1
cd backend/servers
python run_all_servers.py

# Terminal 2
ngrok http 8011  # Copy URL

# Terminal 3
ngrok http 8012  # Copy URL

# Terminal 4
ngrok http 8013  # Copy URL

# Terminal 5
ngrok http 8014  # Copy URL

# Terminal 6
cd backend/openapi_specs
# Manually edit 4 YAML files with ngrok URLs
./generate_specs.sh

# Upload to S3
aws s3 cp k8s_api.yaml s3://...
aws s3 cp logs_api.yaml s3://...
aws s3 cp metrics_api.yaml s3://...
aws s3 cp runbooks_api.yaml s3://...

# Refresh gateway
cd gateway
python generate_token.py
python add_gateway_targets.py

# Wait 10 minutes...
python check_gateway_targets.py

# Finally test
cd sre_agent
uv run sre-agent --prompt "Test"
```

**Time: ~20 minutes of manual work**
**Error-prone: Easy to miss a step or typo a URL**

### After (Automated)
```bash
./setup_ngrok_session.sh
# Wait 10 minutes...
./check_ngrok_session.sh
cd sre_agent && uv run sre-agent --prompt "Test"
```

**Time: ~2 minutes of actual work**
**Reliable: No manual steps, no typos**

---

## 🔍 How It Works

### The Automation Flow

```
setup_ngrok_session.sh
    │
    ├─→ 1. Cleanup old processes
    │      ├─ Kill old backend servers
    │      └─ Kill old ngrok tunnels
    │
    ├─→ 2. Start backend servers
    │      └─ Run in background, log to /tmp/sre_agent_backend.log
    │
    ├─→ 3. Start ngrok tunnels
    │      ├─ Start 4 tunnels (ports 8011-8014)
    │      └─ Run in background, log to /tmp/ngrok_*.log
    │
    ├─→ 4. Collect ngrok URLs
    │      ├─ Query ngrok API (localhost:4040)
    │      ├─ Extract HTTPS URLs
    │      └─ Save to /tmp/sre_agent_ngrok_urls.txt
    │
    ├─→ 5. Regenerate OpenAPI specs
    │      ├─ Read ngrok URLs from file
    │      ├─ Replace {{BACKEND_DOMAIN}} in templates
    │      └─ Generate 4 YAML files
    │
    ├─→ 6. Upload to S3
    │      └─ Upload all 4 specs to S3 bucket
    │
    └─→ 7. Refresh gateway
           ├─ Generate new token
           └─ Update targets (forces reload)
```

### Process Tracking

The scripts track everything using temporary files:

- `/tmp/sre_agent_backend.pid` - Backend server PID
- `/tmp/sre_agent_ngrok_pids.txt` - ngrok PIDs (one per line)
- `/tmp/sre_agent_ngrok_urls.txt` - ngrok domains (one per line)
- `/tmp/sre_agent_backend.log` - Backend logs
- `/tmp/ngrok_8011.log` - ngrok logs (one per port)

This allows:
- `check_ngrok_session.sh` to show status
- `stop_ngrok_session.sh` to clean up properly
- Easy debugging when things go wrong

---

## 🛠️ Customization

### Change Ports
Edit `setup_ngrok_session.sh`:
```bash
BACKEND_PORTS=(8011 8012 8013 8014)  # Change these
```

### Change S3 Bucket
Edit `setup_ngrok_session.sh`:
```bash
S3_BUCKET="your-bucket-name"
S3_PREFIX="your-prefix"
```

### Change Project Path
Edit all scripts:
```bash
PROJECT_ROOT="$HOME/projects/SRE-agent"  # Change this
```

---

## 📊 What Gets Automated

| Task | Before | After |
|------|--------|-------|
| Start backends | Manual in terminal | Automated |
| Start ngrok | 4 terminals, copy URLs | Automated |
| Update specs | Edit 4 files manually | Automated |
| Upload to S3 | 4 commands | Automated |
| Refresh gateway | 2 commands | Automated |
| Track processes | Manual | Automated |
| Check status | Multiple commands | One command |
| Stop everything | Kill each process | One command |

---

## 🎓 Understanding the Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ LOCAL MACHINE (WSL)                                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Backend Servers (4 FastAPI apps)                               │
│   ├─ k8s_server.py      → localhost:8011                       │
│   ├─ logs_server.py     → localhost:8012                       │
│   ├─ metrics_server.py  → localhost:8013                       │
│   └─ runbooks_server.py → localhost:8014                       │
│                                                                 │
│ ngrok Tunnels (4 tunnels)                                      │
│   ├─ https://abc123.ngrok-free.app → localhost:8011           │
│   ├─ https://def456.ngrok-free.app → localhost:8012           │
│   ├─ https://ghi789.ngrok-free.app → localhost:8013           │
│   └─ https://jkl012.ngrok-free.app → localhost:8014           │
│                                                                 │
│ OpenAPI Specs (4 YAML files)                                   │
│   ├─ k8s_api.yaml      (server: https://abc123.ngrok-free.app)│
│   ├─ logs_api.yaml     (server: https://def456.ngrok-free.app)│
│   ├─ metrics_api.yaml  (server: https://ghi789.ngrok-free.app)│
│   └─ runbooks_api.yaml (server: https://jkl012.ngrok-free.app)│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                            ↓ Upload
┌─────────────────────────────────────────────────────────────────┐
│ AWS S3 BUCKET                                                   │
├─────────────────────────────────────────────────────────────────┤
│ s3://sre-agent-specs-1771225925/devops-multiagent-demo/        │
│   ├─ k8s_api.yaml                                              │
│   ├─ logs_api.yaml                                             │
│   ├─ metrics_api.yaml                                          │
│   └─ runbooks_api.yaml                                         │
└─────────────────────────────────────────────────────────────────┘
                            ↓ Read
┌─────────────────────────────────────────────────────────────────┐
│ AWS AGENTCORE GATEWAY                                           │
├─────────────────────────────────────────────────────────────────┤
│ Gateway Targets (4 targets)                                    │
│   ├─ k8s-api      → https://abc123.ngrok-free.app             │
│   ├─ logs-api     → https://def456.ngrok-free.app             │
│   ├─ metrics-api  → https://ghi789.ngrok-free.app             │
│   └─ runbooks-api → https://jkl012.ngrok-free.app             │
└─────────────────────────────────────────────────────────────────┘
                            ↑ Call
┌─────────────────────────────────────────────────────────────────┐
│ SRE AGENT                                                       │
├─────────────────────────────────────────────────────────────────┤
│ Running locally or in AgentCore Runtime                        │
│   └─ Calls Gateway → Gateway calls ngrok → ngrok tunnels to    │
│      local backends → backends return data                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🚨 Important Notes

### ngrok URL Changes
Every time you restart ngrok, URLs change. That's why you need to run `setup_ngrok_session.sh` at the start of each session.

### Gateway Update Delay
After updating gateway targets, it takes ~10 minutes for them to become READY. This is AWS, not the script.

### Free Tier Limits
ngrok free tier has:
- Connection limits
- Bandwidth limits
- URL changes on restart

Consider upgrading or moving to EC2 for production.

### Process Management
The scripts track processes using PID files. If you manually kill processes, clean up with:
```bash
./stop_ngrok_session.sh
```

---

## 🎯 Next Steps

### For Development
1. Use these scripts daily
2. Keep backend logs open: `tail -f /tmp/sre_agent_backend.log`
3. Check status regularly: `./check_ngrok_session.sh`

### For Production
1. Test thoroughly with ngrok
2. Move to EC2 with stable domain (see `HOW_TO_FIX_CREDENTIAL_ISSUE.md` Option 1)
3. Deploy agent to AgentCore Runtime (see Option 3)

---

## 📞 Getting Help

### Check Logs
```bash
# Backend logs
tail -f /tmp/sre_agent_backend.log

# ngrok logs
tail -f /tmp/ngrok_8011.log
```

### Check Status
```bash
./check_ngrok_session.sh
```

### Read Documentation
- Quick start: `NGROK_QUICK_START.md`
- Full guide: `NGROK_SESSION_GUIDE.md`
- Credential issue: `HOW_TO_FIX_CREDENTIAL_ISSUE.md`

---

## ✨ Summary

You now have a complete automation solution that:

✅ Eliminates manual steps
✅ Prevents typos and errors
✅ Saves 15+ minutes per session
✅ Makes development workflow smooth
✅ Provides easy status checking
✅ Handles cleanup properly

**Just run `./setup_ngrok_session.sh` and you're ready to develop!**
