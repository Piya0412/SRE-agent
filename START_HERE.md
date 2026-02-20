# 🚀 START HERE - ngrok Session Automation

Welcome! This guide will get you up and running in 5 minutes.

---

## ⚡ Super Quick Start

```bash
# 1. Test your setup
bash test_automation_setup.sh

# 2. Fix any issues (if needed)
bash make_scripts_executable.sh

# 3. Start your session
./setup_ngrok_session.sh

# 4. Wait 10 minutes, then test
./check_ngrok_session.sh
cd sre_agent && uv run sre-agent --prompt "List pods" --debug

# 5. Stop when done
./stop_ngrok_session.sh
```

---

## 📚 Documentation Index

### Quick Reference
- **`START_HERE.md`** ← You are here
- **`NGROK_QUICK_START.md`** - One-page command reference

### Detailed Guides
- **`README_AUTOMATION.md`** - Complete overview and usage
- **`NGROK_SESSION_GUIDE.md`** - Detailed guide with troubleshooting
- **`AUTOMATION_SUMMARY.md`** - Architecture and how it works

### Background
- **`HOW_TO_FIX_CREDENTIAL_ISSUE.md`** - Why this automation exists

---

## 🛠️ Available Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `test_automation_setup.sh` | Test prerequisites | First time, troubleshooting |
| `make_scripts_executable.sh` | Make scripts executable | First time setup |
| `setup_ngrok_session.sh` | Start everything | Beginning of each session |
| `check_ngrok_session.sh` | Check status | Anytime |
| `stop_ngrok_session.sh` | Stop everything | End of session |

---

## 🎯 What This Automation Does

### Before (Manual - 20 minutes)
1. Start 4 backend servers in separate terminals
2. Start 4 ngrok tunnels in separate terminals
3. Copy 4 ngrok URLs manually
4. Edit 4 OpenAPI YAML files with URLs
5. Upload 4 files to S3
6. Generate gateway token
7. Update gateway targets
8. Wait 10 minutes
9. Test

### After (Automated - 2 minutes)
1. Run `./setup_ngrok_session.sh`
2. Wait 10 minutes
3. Test

**Time saved: 15+ minutes per session**

---

## 🚦 First Time Setup

### Step 1: Test Prerequisites
```bash
bash test_automation_setup.sh
```

This checks:
- ✅ Scripts exist and are executable
- ✅ ngrok is installed and authenticated
- ✅ AWS CLI is configured
- ✅ Python is installed
- ✅ Project structure is correct
- ✅ S3 bucket is accessible

### Step 2: Fix Any Issues

#### Scripts not executable?
```bash
bash make_scripts_executable.sh
```

#### ngrok not installed?
```bash
sudo snap install ngrok
ngrok config add-authtoken YOUR_TOKEN
```

#### AWS not configured?
```bash
aws configure
```

### Step 3: Start Your First Session
```bash
./setup_ngrok_session.sh
```

**What happens:**
- Cleans up old processes
- Starts 4 backend servers
- Starts 4 ngrok tunnels
- Collects ngrok URLs automatically
- Regenerates OpenAPI specs
- Uploads to S3
- Refreshes gateway

**Wait 10 minutes** for gateway targets to become READY.

### Step 4: Check Status
```bash
./check_ngrok_session.sh
```

**Shows:**
- Backend server status
- ngrok tunnel status
- Current ngrok URLs
- Gateway targets status

### Step 5: Test Your Agent
```bash
cd sre_agent
uv run sre-agent --prompt "List pods in production" --debug
```

**Expected:**
- Agent loads MCP tools
- Calls gateway
- Gateway calls ngrok URLs
- Returns pod data

### Step 6: Stop When Done
```bash
./stop_ngrok_session.sh
```

---

## 📋 Daily Workflow

```bash
# Morning
./setup_ngrok_session.sh

# Wait 10 minutes...

# Verify
./check_ngrok_session.sh

# Test
cd sre_agent && uv run sre-agent --prompt "Test" --debug

# Develop all day...

# Evening
./stop_ngrok_session.sh
```

---

## 🔍 Troubleshooting

### Something not working?

1. **Check logs**
   ```bash
   tail -f /tmp/sre_agent_backend.log
   ```

2. **Check status**
   ```bash
   ./check_ngrok_session.sh
   ```

3. **Test prerequisites**
   ```bash
   bash test_automation_setup.sh
   ```

4. **Read detailed guide**
   - See `NGROK_SESSION_GUIDE.md` troubleshooting section

### Common Issues

| Problem | Solution |
|---------|----------|
| Scripts not executable | `bash make_scripts_executable.sh` |
| ngrok not found | `sudo snap install ngrok` |
| Backend won't start | `cat /tmp/sre_agent_backend.log` |
| Gateway targets stuck | Wait 10 min, check S3 |
| Agent can't reach backend | Check all 3: backends, ngrok, gateway |

---

## 💡 Pro Tips

### Use tmux
```bash
tmux new -s sre-agent
./setup_ngrok_session.sh
# Ctrl+B, D to detach
```

### Monitor logs
```bash
tail -f /tmp/sre_agent_backend.log
```

### Test immediately
```bash
# Don't wait 10 minutes, test ngrok URLs right away
curl https://YOUR_NGROK_URL.ngrok-free.app/health
```

---

## 🎓 Understanding the Flow

```
setup_ngrok_session.sh
    ↓
Starts backends (localhost:8011-8014)
    ↓
Starts ngrok tunnels (https://xxx.ngrok-free.app)
    ↓
Collects ngrok URLs automatically
    ↓
Updates OpenAPI specs with URLs
    ↓
Uploads specs to S3
    ↓
Refreshes gateway (reads specs from S3)
    ↓
Gateway creates targets (takes 10 min)
    ↓
Agent calls gateway → gateway calls ngrok → ngrok tunnels to backends
```

---

## 📞 Need More Help?

### Quick Reference
- `NGROK_QUICK_START.md` - One-page commands

### Detailed Guides
- `README_AUTOMATION.md` - Complete overview
- `NGROK_SESSION_GUIDE.md` - Detailed guide
- `AUTOMATION_SUMMARY.md` - Architecture

### Check Logs
```bash
tail -f /tmp/sre_agent_backend.log
tail -f /tmp/ngrok_8011.log
```

---

## 🎯 Next Steps

### For Development
1. Use automation daily
2. Monitor logs
3. Check status regularly

### For Production
1. Test with ngrok
2. Move to EC2 (stable URLs)
3. Deploy to AgentCore Runtime

See `HOW_TO_FIX_CREDENTIAL_ISSUE.md` for production options.

---

## ✨ You're Ready!

Run this command to get started:

```bash
bash test_automation_setup.sh
```

Then follow the instructions. You'll be testing your agent in minutes!

---

## 📊 Quick Command Reference

```bash
# Test setup
bash test_automation_setup.sh

# Make executable
bash make_scripts_executable.sh

# Start session
./setup_ngrok_session.sh

# Check status
./check_ngrok_session.sh

# Stop session
./stop_ngrok_session.sh

# View logs
tail -f /tmp/sre_agent_backend.log

# Test agent
cd sre_agent && uv run sre-agent --prompt "Test" --debug
```

---

**Happy coding! 🚀**
