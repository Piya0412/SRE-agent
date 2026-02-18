#!/bin/bash
# Test the agent with a simple query that doesn't require tool usage

echo "=========================================="
echo "Testing SRE Agent with Simple Query"
echo "=========================================="
echo ""

cd sre_agent

echo "Query: 'Hello, can you introduce yourself?'"
echo ""

uv run sre-agent --prompt "Hello, can you introduce yourself? Do not use any tools, just respond directly." --provider bedrock 2>&1 | tail -50
