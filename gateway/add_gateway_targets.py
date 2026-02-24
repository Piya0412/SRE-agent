#!/usr/bin/env python3
"""
Add API Targets to AgentCore Gateway
"""

import boto3
import sys
import time

# Configuration
GATEWAY_ID = "sre-gateway-rrhmyjghhe"
REGION = "us-east-1"
S3_BUCKET = "sreagent-friend-account-1771924262"
PROVIDER_ARN = "arn:aws:bedrock-agentcore:us-east-1:573054851765:token-vault/default/apikeycredentialprovider/sre-agent-api-key-credential-provider"

# API targets configuration
TARGETS = [
    {
        "name": "k8s-api",
        "description": "Kubernetes Analysis API for cluster monitoring and troubleshooting",
        "filename": "k8s_api.yaml"
    },
    {
        "name": "logs-api",
        "description": "Application Logs API for log search and analysis",
        "filename": "logs_api.yaml"
    },
    {
        "name": "metrics-api",
        "description": "Application Metrics API for performance monitoring",
        "filename": "metrics_api.yaml"
    },
    {
        "name": "runbooks-api",
        "description": "DevOps Runbooks API for incident response and troubleshooting guides",
        "filename": "runbooks_api.yaml"
    }
]

def main():
    print("╔════════════════════════════════════════════════════════════╗")
    print("║          Adding API Targets to Gateway                     ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print()
    
    # Create boto3 client - using control plane
    print(f"Connecting to bedrock-agentcore-control in {REGION}...")
    client = boto3.client('bedrock-agentcore-control', region_name=REGION)
    
    # Verify gateway exists and is ready
    print(f"Verifying gateway: {GATEWAY_ID}")
    try:
        response = client.get_gateway(gatewayIdentifier=GATEWAY_ID)
        status = response['status']
        print(f"✅ Gateway Status: {status}")
        
        if status not in ['ACTIVE', 'READY']:
            print(f"⚠️  Gateway is not ready yet. Current status: {status}")
            print("   Waiting for gateway to become ACTIVE or READY...")
            
            max_wait = 120
            waited = 0
            while waited < max_wait:
                time.sleep(10)
                waited += 10
                response = client.get_gateway(gatewayIdentifier=GATEWAY_ID)
                status = response['status']
                print(f"   Status: {status} ({waited}s)")
                
                if status in ['ACTIVE', 'READY']:
                    print(f"✅ Gateway is now {status}!")
                    break
                elif status in ['FAILED', 'DELETING']:
                    print(f"❌ Gateway in terminal state: {status}")
                    sys.exit(1)
            
            if status not in ['ACTIVE', 'READY']:
                print("❌ Timeout waiting for gateway to become ready")
                sys.exit(1)
    except Exception as e:
        print(f"❌ Error verifying gateway: {e}")
        sys.exit(1)
    
    print()
    print(f"Adding {len(TARGETS)} API targets...")
    print()
    
    # Add each target
    created_targets = []
    for i, target in enumerate(TARGETS, 1):
        name = target['name']
        description = target['description']
        filename = target['filename']
        s3_uri = f"s3://{S3_BUCKET}/devops-multiagent-demo/{filename}"
        
        print(f"{i}. Creating target: {name}")
        print(f"   Description: {description}")
        print(f"   S3 URI: {s3_uri}")
        
        try:
            response = client.create_gateway_target(
                gatewayIdentifier=GATEWAY_ID,
                name=name,
                description=description,
                targetConfiguration={
                    'mcp': {
                        'openApiSchema': {
                            's3': {
                                'uri': s3_uri
                            }
                        }
                    }
                },
                credentialProviderConfigurations=[
                    {
                        'credentialProviderType': 'API_KEY',
                        'credentialProvider': {
                            'apiKeyCredentialProvider': {
                                'providerArn': PROVIDER_ARN,
                                'credentialLocation': 'HEADER',
                                'credentialParameterName': 'X-API-KEY'
                            }
                        }
                    }
                ]
            )
            
            target_id = response['targetId']
            target_status = response.get('status', 'UNKNOWN')
            
            print(f"   ✅ Target created: {target_id}")
            print(f"   Status: {target_status}")
            
            created_targets.append({
                'name': name,
                'id': target_id,
                'status': target_status
            })
            
        except Exception as e:
            error_msg = str(e)
            if 'already exists' in error_msg.lower() or 'duplicate' in error_msg.lower():
                print(f"   ⚠️  Target already exists (skipping)")
            else:
                print(f"   ❌ Error: {e}")
        
        print()
    
    # Summary
    print("╔════════════════════════════════════════════════════════════╗")
    print("║                    SUMMARY                                  ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print()
    print(f"Gateway ID: {GATEWAY_ID}")
    print(f"Targets Created: {len(created_targets)}/{len(TARGETS)}")
    print()
    
    if created_targets:
        print("Created Targets:")
        for target in created_targets:
            print(f"  • {target['name']}: {target['id']} ({target['status']})")
    
    print()
    print("✅ Gateway targets configuration complete!")
    print()
    print("Next: Test the agent with:")
    print("  uv run sre-agent --prompt 'List your tools' --provider bedrock")

if __name__ == "__main__":
    main()
