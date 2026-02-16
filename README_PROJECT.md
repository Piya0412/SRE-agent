# SRE Agent - Multi-Agent Infrastructure Investigation System

[![AWS](https://img.shields.io/badge/AWS-Bedrock-orange)](https://aws.amazon.com/bedrock/)
[![Python](https://img.shields.io/badge/Python-3.12-blue)](https://www.python.org/)
[![Status](https://img.shields.io/badge/Status-Day%201%20Complete-green)]()

## 🎯 Project Overview

Production-grade multi-agent SRE (Site Reliability Engineering) system built for L2 technical interview demonstration. The system uses specialized AI agents to investigate infrastructure issues, analyze logs, monitor metrics, and suggest operational procedures.

### Key Features

- **Multi-Agent Architecture:** Supervisor + 4 specialized agents (Kubernetes, Logs, Metrics, Runbooks)
- **LangGraph Orchestration:** Sophisticated agent routing and collaboration
- **AWS Bedrock Integration:** Claude/Nova models for AI reasoning
- **MCP Protocol:** Model Context Protocol for secure tool integration
- **AgentCore Gateway:** Production-ready API access management
- **Memory System:** User personalization (Alice/Carol personas)
- **Mock Backend:** Synthetic K8s, logs, metrics, runbooks data

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    SRE Agent CLI                        │
│          "Why are payment pods crash-looping?"          │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│              Supervisor Agent (LangGraph)               │
│          Routes queries to specialist agents            │
└─┬─────────┬─────────┬─────────┬─────────┬──────────────┘
  │         │         │         │         │
  ▼         ▼         ▼         ▼         ▼
┌────┐   ┌────┐   ┌────┐   ┌────┐   ┌────┐
│K8s │   │Logs│   │Metr│   │Run │   │Mem │
│Agt │   │Agt │   │Agt │   │Agt │   │Sys │
└─┬──┘   └─┬──┘   └─┬──┘   └─┬──┘   └─┬──┘
  │         │         │         │         │
  ▼         ▼         ▼         ▼         ▼
┌─────────────────────────────────────────────────────────┐
│           AgentCore Gateway (MCP Protocol)              │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│   Backend APIs: K8s(8011) Logs(8012) Metrics(8013)     │
│                 Runbooks(8014)                          │
└─────────────────────────────────────────────────────────┘
```

## 🚀 Tech Stack

- **Language:** Python 3.12
- **AI Framework:** LangGraph, Amazon Bedrock SDK
- **Backend:** FastAPI, Uvicorn
- **Storage:** AWS S3 (OpenAPI specs)
- **Identity:** AWS Cognito
- **Deployment:** Docker, AWS AgentCore Runtime
- **Package Manager:** uv (fast Python package installer)

## 📋 Current Status (Day 1 Complete)

- ✅ Backend Infrastructure: 4 servers operational
- ✅ Mock Data: Synthetic K8s pods, logs, metrics, runbooks
- ✅ API Authentication: Environment variable implementation
- ✅ Storage: S3 bucket with OpenAPI specifications
- ✅ Agent CLI: Verified and functional
- ⏳ Gateway: Configuration pending (Day 2)
- ⏳ Memory System: Initialization pending (Day 2)
- ⏳ AWS Deployment: AgentCore Runtime (Day 3-4)

## 🛠️ Setup Instructions

### Prerequisites

- Python 3.12+
- `uv` package manager
- AWS CLI configured
- Docker (for deployment)
- AWS Account with Bedrock access

### Quick Start

```bash
# Clone repository
git clone https://github.com/Piya0412/SRE-agent.git
cd SRE-agent

# Create virtual environment
uv venv --python 3.12
source .venv/bin/activate

# Install dependencies
uv pip install -e .

# Set up backend API key
export BACKEND_API_KEY="your-api-key-here"

# Start backend servers
cd backend
./scripts/start_demo_backend.sh --host 127.0.0.1

# Test agent CLI
cd ..
uv run sre-agent --help
```

## 📖 Documentation

- [Day 1 Completion Report](DAY1_COMPLETION_REPORT.md)
- [Quick Reference](docs/quick_reference.md)
- [Architecture Details](docs/architecture.md)
- [System Components](docs/components.md)
- [Memory System](docs/memory.md)
- [Deployment Guide](docs/deployment.md)

## 🎯 L2 Interview Highlights

### Technical Challenges Overcome

**AWS Bedrock Credential Provider Issue**
- Problem: Service unavailable during initial setup
- Solution: Environment variable fallback for dev mode
- Learning: Dev/prod parity with practical workflows

**Multi-Service Orchestration**
- Coordinated 4 backend APIs with agent system
- Implemented secure API key authentication
- Verified end-to-end functionality

### Skills Demonstrated

✅ AWS Service Integration (Bedrock, S3, IAM)
✅ Python Package Development
✅ API Design & Implementation
✅ Debugging & Troubleshooting
✅ System Architecture
✅ Documentation & Version Control

## 🧪 Testing

```bash
# Test backend health
curl http://127.0.0.1:8011/health  # K8s API
curl http://127.0.0.1:8012/health  # Logs API
curl http://127.0.0.1:8013/health  # Metrics API
curl http://127.0.0.1:8014/health  # Runbooks API

# Test backend functionality
API_KEY="your-api-key"
curl -H "X-API-Key: $API_KEY" http://127.0.0.1:8011/pods/status

# Test agent CLI
uv run sre-agent --prompt "list agents" --provider bedrock
```

## 📊 Project Timeline

- **Day 1 (Feb 16):** ✅ Backend infrastructure, S3 setup, Agent CLI verification
- **Day 2 (Feb 17):** ⏳ Gateway configuration, Cognito setup, First investigation
- **Day 3 (Feb 18):** ⏳ AWS deployment preparation, Container building
- **Day 4 (Feb 19):** ⏳ AgentCore Runtime deployment, Integration testing
- **Day 5 (Feb 20):** ⏳ L2 interview preparation, Demo practice

## 🔐 Security Notes

- Never commit .env files or AWS credentials
- API keys stored in environment variables
- S3 bucket permissions scoped to Bedrock service
- Backend servers use API key authentication

## 📝 License

This project is for educational and interview demonstration purposes.

## 👤 Author

**Piyush**
- L2 Technical Interview Candidate
- Focus: Cloud Architecture, AI/ML Systems, SRE Practices

---

**Note:** This is a demonstration project built for L2 technical interview. Not intended for production use without proper security hardening, monitoring, and error handling.
