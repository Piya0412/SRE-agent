# ngrok Quick Start - One Page Reference

## 🚀 First Time Setup

```bash
# 1. Make scripts executable
bash make_scripts_executable.sh

# 2. Install ngrok (if not installed)
sudo snap install ngrok

# 3. Authenticate ngrok (if not done)
ngrok config add-authtoken YOUR_TOKEN_FROM_NGROK_DASHBOARD
```

---

## ⚡ Daily Usage

### Start Your Session
```bash
./setup_ngrok_session.sh
```
**Wait 10 minutes** for gateway targets to become READY.

### Check Status
```bash
./check_ngrok_session.sh
```

### Test Agent
```bash
cd sre_agent
uv run sre-agent --prompt "List pods in production" --debug
```

### Stop Session
```bash
./stop_ngrok_session.sh
```

---

## 🔍 Quick Checks

```bash
# View backend logs
tail -f /tmp/sre_agent_backend.log

# Check gateway targets
cd gateway && python check_gateway_targets.py

# Test ngrok URL directly
curl https://YOUR_NGROK_URL.ngrok-free.app/health
```

---

## ❌ Troubleshooting

| Problem | Solution |
|---------|----------|
| Scripts not executable | `bash make_scripts_executable.sh` |
| ngrok not found | `sudo snap install ngrok` |
| Backend won't start | `cat /tmp/sre_agent_backend.log` |
| Gateway targets stuck | Wait 10 min, check S3 upload |
| Agent can't reach backend | Check all 3: backends running, ngrok running, gateway READY |

---

## 📋 What Each Script Does

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `setup_ngrok_session.sh` | Start everything | Beginning of each session |
| `stop_ngrok_session.sh` | Stop everything | End of session |
| `check_ngrok_session.sh` | Check status | Anytime to verify |

---

## 🎯 Complete Workflow

```bash
# 1. Start (takes ~2 minutes)
./setup_ngrok_session.sh

# 2. Wait for gateway (takes ~10 minutes)
# Do other work...

# 3. Verify (takes ~10 seconds)
./check_ngrok_session.sh

# 4. Test (takes ~30 seconds)
cd sre_agent
uv run sre-agent --prompt "List pods" --debug

# 5. Develop and test
# (repeat step 4 as needed)

# 6. Stop when done
./stop_ngrok_session.sh
```

---

## 💡 Pro Tips

- Run in `tmux` so you can detach
- Check status every hour with `watch -n 3600 ./check_ngrok_session.sh`
- Keep backend logs open: `tail -f /tmp/sre_agent_backend.log`
- Test ngrok URLs immediately after setup
- Consider EC2 for production (stable URLs)

---

## 📚 More Info

- Full guide: `NGROK_SESSION_GUIDE.md`
- Credential issue explanation: `HOW_TO_FIX_CREDENTIAL_ISSUE.md`
- Backend details: `backend/README.md`
- Gateway details: `gateway/README.md`
