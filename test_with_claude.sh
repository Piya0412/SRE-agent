#!/bin/bash
# Quick test with Claude model instead of Nova

echo "=========================================="
echo "Testing SRE Agent with Claude Model"
echo "=========================================="
echo ""
echo "This test temporarily overrides the model to use Claude 3.5 Sonnet"
echo "to verify that the MCP tools work correctly with a different model."
echo ""

cd sre_agent

# Set environment variable to override model
export BEDROCK_MODEL_ID="anthropic.claude-3-5-sonnet-20241022-v2:0"

echo "Query: 'What pods are in CrashLoopBackOff state in the production namespace?'"
echo ""
echo "Starting investigation..."
echo ""

uv run sre-agent \
  --prompt "What pods are in CrashLoopBackOff state in the production namespace?" \
  --provider bedrock \
  2>&1 | tee ../claude_test.log

echo ""
echo "=========================================="
echo "Test Complete - Check claude_test.log for full output"
echo "=========================================="
