# Run All Services in Background (Like Old Account)

This guide shows how to run all services in the background so you don't need to keep terminals open.

---

## Quick Start (All in Background)

```bash
cd ~/projects/SRE-agent
source .venv/bin/activate
export AWS_PROFILE=friend-account

# 1. Start backend servers (already runs in background with nohup)
bash backend/scripts/start_demo_backend.sh --host 127.0.0.1

# 2. Start proxy in background
nohup python3 proxy.py > logs/proxy.log 2>&1 &
echo $! > .proxy_pid

# 3. Start ngrok in background
nohup ngrok http 8000 --log=stdout > logs/ngrok.log 2>&1 &
echo $! > .ngrok_pid

# Wait for services to start
sleep 5

# 4. Verify everything is running
bash scripts/check_all_services.sh
```

Done! All services are running in the background. You can close your terminal.

---

## Detailed Steps

### 1. Backend Servers (Already Background)

The `start_demo_backend.sh` script already uses `nohup` to run servers in the background:

```bash
cd ~/projects/SRE-agent
source .venv/bin/activate
bash backend/scripts/start_demo_backend.sh --host 127.0.0.1
```

Logs are written to `logs/k8s_server.log`, `logs/logs_server.log`, etc.

### 2. Reverse Proxy (Background)

```bash
cd ~/projects/SRE-agent
source .venv/bin/activate

# Start proxy in background
nohup python3 proxy.py > logs/proxy.log 2>&1 &

# Save PID for later stopping
echo $! > .proxy_pid

# Verify it's running
curl http://localhost:8000/health
```

### 3. ngrok Tunnel (Background)

```bash
cd ~/projects/SRE-agent

# Start ngrok in background
nohup ngrok http 8000 --log=stdout > logs/ngrok.log 2>&1 &

# Save PID for later stopping
echo $! > .ngrok_pid

# Wait for ngrok to start
sleep 3

# Get ngrok URL from log
grep -o 'https://[a-z0-9-]*\.ngrok-free\.app' logs/ngrok.log | head -1
```

**Note**: ngrok free tier URL stays the same (`lucas-unfortuitous-amara.ngrok-free.dev`) as long as you don't restart it.

---

## Check Status

```bash
# Check if all processes are running
ps aux | grep -E "k8s_server|logs_server|metrics_server|runbooks_server|proxy.py|ngrok"

# Check backend servers
curl http://localhost:8011/health
curl http://localhost:8012/health
curl http://localhost:8013/health
curl http://localhost:8014/health

# Check proxy
curl http://localhost:8000/health

# Check ngrok
curl https://lucas-unfortuitous-amara.ngrok-free.dev/health

# Check logs
tail -f logs/proxy.log
tail -f logs/ngrok.log
tail -f logs/k8s_server.log
```

---

## Stop All Services

```bash
cd ~/projects/SRE-agent

# Stop backend servers
bash backend/scripts/stop_demo_backend.sh

# Stop proxy
if [ -f .proxy_pid ]; then
    kill $(cat .proxy_pid)
    rm .proxy_pid
fi

# Stop ngrok
if [ -f .ngrok_pid ]; then
    kill $(cat .ngrok_pid)
    rm .ngrok_pid
fi

# Or kill all at once
pkill -f "k8s_server.py"
pkill -f "logs_server.py"
pkill -f "metrics_server.py"
pkill -f "runbooks_server.py"
pkill -f "proxy.py"
pkill -f "ngrok"
```

---

## Restart Services

```bash
cd ~/projects/SRE-agent
source .venv/bin/activate

# Stop everything
bash backend/scripts/stop_demo_backend.sh
pkill -f "proxy.py"
pkill -f "ngrok"

# Start everything
bash backend/scripts/start_demo_backend.sh --host 127.0.0.1
nohup python3 proxy.py > logs/proxy.log 2>&1 &
nohup ngrok http 8000 --log=stdout > logs/ngrok.log 2>&1 &

# Wait and verify
sleep 5
curl http://localhost:8000/health
```

---

## Troubleshooting

### Services not starting

```bash
# Check logs
tail -50 logs/k8s_server.log
tail -50 logs/proxy.log
tail -50 logs/ngrok.log

# Check if ports are already in use
lsof -i :8000
lsof -i :8011
lsof -i :8012
lsof -i :8013
lsof -i :8014
```

### ngrok URL changed

If ngrok restarts, the URL might change. Check the new URL:

```bash
grep -o 'https://[a-z0-9-]*\.ngrok-free\.app' logs/ngrok.log | head -1
```

If it changed, you need to update OpenAPI specs and re-upload to S3.

### Proxy not responding

```bash
# Check if proxy is running
ps aux | grep proxy.py

# Check logs
tail -50 logs/proxy.log

# Restart proxy
pkill -f "proxy.py"
nohup python3 proxy.py > logs/proxy.log 2>&1 &
```

---

## Comparison: Old vs New Setup

### Old Account (EC2)
- Backend servers: `nohup` in background ✅
- ngrok: `nohup` or `screen`/`tmux` in background ✅
- No terminals needed to stay open ✅

### New Account (This Guide)
- Backend servers: `nohup` in background ✅
- Proxy: `nohup` in background ✅
- ngrok: `nohup` in background ✅
- No terminals needed to stay open ✅

**Same experience as old account!**

---

## Auto-Start on Boot (Optional)

If you want services to start automatically when your machine boots:

### Using systemd (Linux)

Create service files in `/etc/systemd/system/`:

```bash
# /etc/systemd/system/sre-backend.service
[Unit]
Description=SRE Agent Backend Servers
After=network.target

[Service]
Type=forking
User=piyush
WorkingDirectory=/home/piyush/projects/SRE-agent
ExecStart=/home/piyush/projects/SRE-agent/backend/scripts/start_demo_backend.sh --host 127.0.0.1
ExecStop=/home/piyush/projects/SRE-agent/backend/scripts/stop_demo_backend.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl enable sre-backend
sudo systemctl start sre-backend
sudo systemctl status sre-backend
```

---

## Current Configuration

- **Backend**: localhost:8011-8014 (background with nohup)
- **Proxy**: localhost:8000 (background with nohup)
- **ngrok**: https://lucas-unfortuitous-amara.ngrok-free.dev (background with nohup)
- **Gateway**: sre-gateway-rrhmyjghhe
- **Account**: 573054851765 (friend's account)

---

## Summary

You now have the same setup as the old account:
- ✅ All services run in background
- ✅ No terminals need to stay open
- ✅ Services persist after closing terminal
- ✅ Logs are written to files
- ✅ Easy to stop/restart all services
