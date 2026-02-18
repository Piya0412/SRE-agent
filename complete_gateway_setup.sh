#!/bin/bash
# Complete Gateway Setup - Wait for ACTIVE and Add Targets

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║          Completing Gateway Setup                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

GATEWAY_URI=$(cat gateway/.gateway_uri)
GATEWAY_ID=$(echo "$GATEWAY_URI" | grep -oP '(?<=https://)[^.]+')

echo "Gateway ID: $GATEWAY_ID"
echo "Gateway URI: $GATEWAY_URI"
echo ""

# Wait for gateway to be ACTIVE
echo "Waiting for gateway to become ACTIVE..."
python3 << 'PYTHON_SCRIPT'
import boto3
import time
import sys

# Use the CONTROL PLANE client (not data plane)
client = boto3.client('bedrock-agentcore-control', region_name='us-east-1')

gateway_id = "sre-gateway-rks2qobw3q"
max_wait = 300  # 5 minutes
waited = 0

print(f"Checking gateway: {gateway_id}")
print("")

while waited < max_wait:
    try:
        response = client.get_gateway(gatewayIdentifier=gateway_id)
        status = response['status']
        print(f"  Status: {status} ({waited}s elapsed)")
        
        if status == 'ACTIVE':
            print("")
            print("✅ Gateway is ACTIVE!")
            break
        elif status in ['FAILED', 'DELETING', 'DELETED']:
            print(f"❌ Gateway in terminal state: {status}")
            if 'statusReasons' in response:
                print(f"   Reason: {response['statusReasons']}")
            sys.exit(1)
        
        time.sleep(10)
        waited += 10
    except Exception as e:
        print(f"  Error checking status: {e}")
        time.sleep(10)
        waited += 10

if waited >= max_wait:
    print("⚠️  Timeout waiting for gateway to become ACTIVE")
    sys.exit(1)

# Now add targets
print("")
print("Adding API targets...")
print("")

s3_bucket = "sre-agent-specs-1771225925"
provider_arn = "arn:aws:bedrock-agentcore:us-east-1:310485116687:token-vault/default/apikeycredentialprovider/sre-agent-api-key-credential-provider"

targets = [
    ("k8s-api", "Kubernetes Analysis API", "k8s_api.yaml"),
    ("logs-api", "Application Logs API", "logs_api.yaml"),
    ("metrics-api", "Application Metrics API", "metrics_api.yaml"),
    ("runbooks-api", "DevOps Runbooks API", "runbooks_api.yaml")
]

target_count = 0
for name, description, filename in targets:
    s3_uri = f"s3://{s3_bucket}/devops-multiagent-demo/{filename}"
    print(f"  {len(targets) - target_count}. Creating target: {name}")
    print(f"     Description: {description}")
    print(f"     S3 URI: {s3_uri}")
    
    try:
        response = client.create_gateway_target(
            gatewayIdentifier=gateway_id,
            name=name,
            description=description,
            s3TargetConfiguration={
                's3Uri': s3_uri,
                'credentialProviderArn': provider_arn
            }
        )
        target_id = response['targetId']
        print(f"     ✅ Target created: {target_id}")
        target_count += 1
    except Exception as e:
        error_msg = str(e)
        if "already exists" in error_msg.lower():
            print(f"     ℹ️  Target already exists")
            target_count += 1
        else:
            print(f"     ⚠️  Error: {e}")
    print("")

print("")
print("═══════════════════════════════════════════════════════════")
print(f"✅ Gateway Setup Complete!")
print("═══════════════════════════════════════════════════════════")
print(f"Gateway ID: {gateway_id}")
print(f"Gateway URI: https://{gateway_id}.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp")
print(f"API Targets: {target_count}/{len(targets)} configured")
print("")

PYTHON_SCRIPT

echo ""
echo "✅ Day 3 Gateway Setup Complete!"
echo ""
echo "Next: Generate access token and configure agent"
