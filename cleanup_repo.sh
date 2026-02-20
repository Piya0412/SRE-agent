#!/bin/bash

# Repo cleanup script - Remove temporary and development files

echo "🧹 Starting repository cleanup..."

# Create archive directory for historical docs
mkdir -p archive/logs
mkdir -p archive/temp_scripts
mkdir -p archive/day_reports

# Move log files to archive
echo "📦 Archiving log files..."
mv *.log archive/logs/ 2>/dev/null || true

# Move temporary scripts to archive
echo "📦 Archiving temporary scripts..."
mv check_ngrok_session.sh archive/temp_scripts/ 2>/dev/null || true
mv complete_gateway_setup.sh archive/temp_scripts/ 2>/dev/null || true
mv configure_cognito_complete.sh archive/temp_scripts/ 2>/dev/null || true
mv configure_cognito_resource_server.sh archive/temp_scripts/ 2>/dev/null || true
mv create_gateway_simple.sh archive/temp_scripts/ 2>/dev/null || true
mv day3_setup.sh archive/temp_scripts/ 2>/dev/null || true
mv debug_targets.py archive/temp_scripts/ 2>/dev/null || true
mv finalize_day3_setup.sh archive/temp_scripts/ 2>/dev/null || true
mv fix_gateway_backend_urls.sh archive/temp_scripts/ 2>/dev/null || true
mv fix_iam_permissions.sh archive/temp_scripts/ 2>/dev/null || true
mv gather_support_evidence.sh archive/temp_scripts/ 2>/dev/null || true
mv generate_cognito_token.sh archive/temp_scripts/ 2>/dev/null || true
mv generate_jwt_token.sh archive/temp_scripts/ 2>/dev/null || true
mv inspect_mcp_tools.py archive/temp_scripts/ 2>/dev/null || true
mv make_scripts_executable.sh archive/temp_scripts/ 2>/dev/null || true
mv proxy.py archive/temp_scripts/ 2>/dev/null || true
mv run_gateway_creation.sh archive/temp_scripts/ 2>/dev/null || true
mv setup_gateway_token.py archive/temp_scripts/ 2>/dev/null || true
mv setup_ngrok_backend.sh archive/temp_scripts/ 2>/dev/null || true
mv setup_ngrok_session.sh archive/temp_scripts/ 2>/dev/null || true
mv setup_ngrok_session.sh.backup archive/temp_scripts/ 2>/dev/null || true
mv setup_ngrok_with_proxy.sh archive/temp_scripts/ 2>/dev/null || true
mv stop_ngrok_session.sh archive/temp_scripts/ 2>/dev/null || true
mv test_automation_setup.sh archive/temp_scripts/ 2>/dev/null || true
mv test_nova_tools.py archive/temp_scripts/ 2>/dev/null || true
mv test_simple_query.sh archive/temp_scripts/ 2>/dev/null || true
mv test_with_claude.sh archive/temp_scripts/ 2>/dev/null || true
mv verify_report.py archive/temp_scripts/ 2>/dev/null || true

# Move day reports to archive
echo "📦 Archiving day reports..."
mv DAY1_COMPLETION_REPORT.md archive/day_reports/ 2>/dev/null || true
mv DAY2_COMPLETION_REPORT.md archive/day_reports/ 2>/dev/null || true
mv DAY2_EXECUTIVE_SUMMARY.md archive/day_reports/ 2>/dev/null || true
mv DAY2_FINAL_STATUS.md archive/day_reports/ 2>/dev/null || true
mv DAY2_FINAL_VERIFICATION.md archive/day_reports/ 2>/dev/null || true
mv DAY2_QUICK_REFERENCE.md archive/day_reports/ 2>/dev/null || true
mv DAY2_STATUS_REPORT.txt archive/day_reports/ 2>/dev/null || true
mv DAY3_COMPLETE_FINAL.md archive/day_reports/ 2>/dev/null || true
mv DAY3_COMPLETION_REPORT.md archive/day_reports/ 2>/dev/null || true
mv DAY3_FINAL_STATUS.md archive/day_reports/ 2>/dev/null || true
mv DAY3_FINAL_SUMMARY.md archive/day_reports/ 2>/dev/null || true
mv DAY3_NOVA_ISSUE_ANALYSIS.md archive/day_reports/ 2>/dev/null || true
mv DAY3_QUICK_REFERENCE.md archive/day_reports/ 2>/dev/null || true

# Move temporary documentation to archive
echo "📦 Archiving temporary documentation..."
mv AUTOMATION_SUMMARY.md archive/ 2>/dev/null || true
mv DEMO_VS_PRODUCTION_EXPLAINED.md archive/ 2>/dev/null || true
mv GIT_WORKFLOW.md archive/ 2>/dev/null || true
mv HOW_TO_FIX_CREDENTIAL_ISSUE.md archive/ 2>/dev/null || true
mv NGROK_FREE_TIER_SOLUTION.md archive/ 2>/dev/null || true
mv NGROK_QUICK_START.md archive/ 2>/dev/null || true
mv NGROK_SESSION_GUIDE.md archive/ 2>/dev/null || true
mv README_AUTOMATION.md archive/ 2>/dev/null || true
mv README_PROJECT.md archive/ 2>/dev/null || true
mv SRE_AGENT_COMPLETE_AUDIT.md archive/ 2>/dev/null || true
mv START_HERE.md archive/ 2>/dev/null || true
mv WHY_BACKEND_APIS_ARE_NEEDED.md archive/ 2>/dev/null || true

# Remove Zone.Identifier files (Windows metadata)
echo "🗑️  Removing Zone.Identifier files..."
find . -name "*Zone.Identifier" -type f -delete

# Remove temporary files
echo "🗑️  Removing temporary files..."
rm -f nul
rm -f .access_token
rm -f .credentials_provider
rm -f .memory_id
rm -f .s3_bucket_name
rm -f ngrok-config.yml
rm -f deployment_run.log

# Remove temporary policy files (keep in deployment if needed)
rm -f trust-policy.json
rm -f ecr-policy.json
rm -f cloudwatch-policy.json

# Clean up support_evidence directory (move to archive)
echo "📦 Archiving support evidence..."
mv support_evidence archive/ 2>/dev/null || true

# Update .gitignore to prevent future clutter
echo "📝 Updating .gitignore..."
cat >> .gitignore << 'EOF'

# Cleanup - prevent future clutter
*.log
*Zone.Identifier
nul
.access_token
.credentials_provider
.memory_id
.s3_bucket_name
deployment_run.log
ngrok-config.yml
archive/

# Temporary scripts
setup_*.sh
test_*.sh
debug_*.py
fix_*.sh
*_temp.py

# Day reports (keep in archive only)
DAY*_*.md
EOF

echo "✅ Cleanup complete!"
echo ""
echo "📁 Repository structure:"
echo "  ├── backend/          - Backend MCP servers"
echo "  ├── deployment/       - AWS deployment scripts"
echo "  ├── docs/             - Documentation"
echo "  ├── gateway/          - SRE Gateway (MCP)"
echo "  ├── logs/             - Application logs"
echo "  ├── reports/          - Generated SRE reports"
echo "  ├── scripts/          - Utility scripts"
echo "  ├── sre_agent/        - Main agent code"
echo "  ├── tests/            - Test suite"
echo "  ├── archive/          - Historical files (not in git)"
echo "  ├── Dockerfile        - ARM64 container"
echo "  ├── Dockerfile.x86_64 - x86_64 container"
echo "  ├── docker-compose.yaml"
echo "  ├── pyproject.toml    - Python dependencies"
echo "  ├── README.md         - Main documentation"
echo "  └── CHANGELOG.md      - Version history"
