#!/usr/bin/env python3
"""
Setup Gateway Token - Create a workaround for MCP authentication
Since Cognito requires resource server setup, we'll document the proper approach
and create a test configuration
"""

import os
from pathlib import Path

print("╔════════════════════════════════════════════════════════════╗")
print("║          Gateway Token Setup                                ║")
print("╚════════════════════════════════════════════════════════════╝")
print()

# Read gateway URI
gateway_uri_file = Path("gateway/.gateway_uri")
if gateway_uri_file.exists():
    gateway_uri = gateway_uri_file.read_text().strip()
    print(f"✅ Gateway URI: {gateway_uri}")
else:
    print("❌ Gateway URI not found")
    exit(1)

# For now, create a placeholder token
# In production, this would be a real Cognito JWT
test_token = "test-mcp-token-placeholder"

# Update sre_agent/.env
env_file = Path("sre_agent/.env")
if env_file.exists():
    content = env_file.read_text()
    
    # Replace the token line
    lines = content.split('\n')
    new_lines = []
    token_found = False
    
    for line in lines:
        if line.startswith('GATEWAY_ACCESS_TOKEN='):
            new_lines.append(f'GATEWAY_ACCESS_TOKEN={test_token}')
            token_found = True
        else:
            new_lines.append(line)
    
    if not token_found:
        new_lines.append(f'\nGATEWAY_ACCESS_TOKEN={test_token}')
    
    env_file.write_text('\n'.join(new_lines))
    print(f"✅ Updated sre_agent/.env with token")
else:
    print("❌ sre_agent/.env not found")
    exit(1)

print()
print("⚠️  IMPORTANT NOTE:")
print("   The gateway is configured with Cognito JWT authentication.")
print("   For MCP tools to work, you need a valid JWT token.")
print()
print("   Current workaround: Using placeholder token")
print("   This may cause MCP connection to fail.")
print()
print("   Proper solution:")
print("   1. Configure Cognito Resource Server")
print("   2. Add custom scope (e.g., 'invoke:gateway')")
print("   3. Generate proper JWT token")
print()
print("   For now, the agent will work with memory and local tools only.")
print()
