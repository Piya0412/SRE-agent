#!/bin/bash
# Simplified Gateway Creation Script

set -e

cd gateway

echo "╔════════════════════════════════════════════════════════════╗"
echo "║          Creating AgentCore Gateway                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Load environment
source .env

echo "Configuration:"
echo "  User Pool: $COGNITO_USER_POOL_ID"
echo "  Client ID: $COGNITO_CLIENT_ID"
echo "  Region: $AWS_REGION"
echo ""

# Step 1: Create gateway without token first
echo "Step 1: Creating gateway infrastructure..."
echo "----------------------------------------"

export COGNITO_USER_POOL_ID
export COGNITO_CLIENT_ID
export AWS_REGION
export AWS_ACCOUNT_ID

python3 << 'PYTHON_SCRIPT'
import boto3
import json
import sys
import os

# Load config
user_pool_id = os.environ.get('COGNITO_USER_POOL_ID', 'us-east-1_CPukh9Ilm')
client_id = os.environ.get('COGNITO_CLIENT_ID', '7pvnt90jh7gdnhe4al23vn389d')
region = os.environ.get('AWS_REGION', 'us-east-1')
account_id = os.environ.get('AWS_ACCOUNT_ID', '310485116687')
s3_bucket = "sre-agent-specs-1771225925"

# Extract Cognito region from pool ID
cognito_region = user_pool_id.split('_')[0]
discovery_url = f"https://cognito-idp.{cognito_region}.amazonaws.com/{user_pool_id}/.well-known/openid-configuration"

# Create client
client = boto3.client('bedrock-agentcore', region_name=region)

# Gateway configuration
gateway_name = "sre-gateway"
role_arn = f"arn:aws:iam::{account_id}:role/BedrockAgentCoreGatewayRole"
provider_arn = f"arn:aws:bedrock-agentcore:{region}:{account_id}:token-vault/default/apikeycredentialprovider/sre-agent-api-key-credential-provider"

# S3 URIs for OpenAPI specs
s3_uris = [
    f"s3://{s3_bucket}/devops-multiagent-demo/k8s_api.yaml",
    f"s3://{s3_bucket}/devops-multiagent-demo/logs_api.yaml",
    f"s3://{s3_bucket}/devops-multiagent-demo/metrics_api.yaml",
    f"s3://{s3_bucket}/devops-multiagent-demo/runbooks_api.yaml"
]

descriptions = [
    "Kubernetes Analysis API for cluster monitoring",
    "Application Logs API for log search and analysis",
    "Application Metrics API for performance monitoring",
    "DevOps Runbooks API for incident response"
]

print(f"Creating gateway: {gateway_name}")
print(f"Discovery URL: {discovery_url}")
print(f"Allowed Clients: {client_id}")
print("")

try:
    # Check if gateway exists
    try:
        list_response = client.list_gateways()
        existing_gateway = None
        for gw in list_response.get('gateways', []):
            if gw.get('name') == gateway_name:
                existing_gateway = gw
                break
        
        if existing_gateway:
            gateway_id = existing_gateway['gatewayIdentifier']
            print(f"⚠️  Gateway already exists: {gateway_id}")
            print(f"   Status: {existing_gateway.get('status', 'UNKNOWN')}")
            
            # Get full gateway details
            get_response = client.get_gateway(gatewayIdentifier=gateway_id)
            gateway_uri = get_response['uri']
            
            print(f"✅ Using existing gateway")
            print(f"   URI: {gateway_uri}")
            
            # Save URI
            with open('.gateway_uri', 'w') as f:
                f.write(gateway_uri)
            
            sys.exit(0)
    except Exception as e:
        print(f"No existing gateway found, creating new one...")
    
    # Create new gateway
    create_params = {
        'name': gateway_name,
        'description': 'AgentCore Gateway for SRE Agent Demo',
        'roleArn': role_arn,
        'authenticationConfiguration': {
            'oidc': {
                'discoveryUrl': discovery_url,
                'allowedClients': [client_id]
            }
        }
    }
    
    response = client.create_gateway(**create_params)
    
    gateway_id = response['gatewayIdentifier']
    gateway_uri = response['uri']
    status = response['status']
    
    print(f"✅ Gateway created successfully!")
    print(f"   Gateway ID: {gateway_id}")
    print(f"   URI: {gateway_uri}")
    print(f"   Status: {status}")
    
    # Save gateway URI
    with open('.gateway_uri', 'w') as f:
        f.write(gateway_uri)
    
    print("")
    print("Waiting for gateway to become ACTIVE...")
    
    # Wait for gateway to be active
    import time
    max_wait = 60
    waited = 0
    while waited < max_wait:
        get_response = client.get_gateway(gatewayIdentifier=gateway_id)
        current_status = get_response['status']
        print(f"   Status: {current_status} ({waited}s)")
        
        if current_status == 'ACTIVE':
            print("✅ Gateway is ACTIVE")
            break
        elif current_status in ['FAILED', 'DELETING']:
            print(f"❌ Gateway creation failed with status: {current_status}")
            sys.exit(1)
        
        time.sleep(5)
        waited += 5
    
    # Now create targets
    print("")
    print("Creating API targets...")
    
    for i, (s3_uri, description) in enumerate(zip(s3_uris, descriptions)):
        api_name = s3_uri.split('/')[-1].replace('_api.yaml', '').upper()
        print(f"  {i+1}. {api_name} API: {s3_uri}")
        
        try:
            target_response = client.create_target(
                gatewayIdentifier=gateway_id,
                name=f"{api_name.lower()}-api-target",
                description=description,
                s3TargetConfiguration={
                    's3Uri': s3_uri,
                    'credentialProviderArn': provider_arn
                }
            )
            print(f"     ✅ Target created: {target_response['targetIdentifier']}")
        except Exception as e:
            print(f"     ⚠️  Target creation error: {e}")
    
    print("")
    print("✅ Gateway setup complete!")
    
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

PYTHON_SCRIPT

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Gateway created successfully!"
    echo ""
    echo "Gateway URI saved to: gateway/.gateway_uri"
    cat .gateway_uri
else
    echo "❌ Gateway creation failed"
    exit 1
fi
