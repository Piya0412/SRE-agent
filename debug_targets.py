#!/usr/bin/env python3
"""Debug script to check gateway targets with detailed output"""

import boto3
import json

GATEWAY_ID = "sre-gateway-rks2qobw3q"
REGION = "us-east-1"

def main():
    print("=" * 70)
    print("DEBUGGING GATEWAY TARGETS")
    print("=" * 70)
    print()
    
    client = boto3.client('bedrock-agentcore-control', region_name=REGION)
    
    # First, verify the gateway exists
    print("1. Checking if gateway exists...")
    try:
        gateway_response = client.get_gateway(gatewayIdentifier=GATEWAY_ID)
        print(f"✅ Gateway found: {gateway_response['name']}")
        print(f"   Status: {gateway_response['status']}")
        print(f"   Gateway ARN: {gateway_response['gatewayArn']}")
        print()
    except Exception as e:
        print(f"❌ Error getting gateway: {e}")
        return
    
    # Now try to list targets
    print("2. Listing gateway targets...")
    try:
        response = client.list_gateway_targets(gatewayIdentifier=GATEWAY_ID)
        print(f"✅ API call successful")
        print()
        print("Full Response:")
        print(json.dumps(response, indent=2, default=str))
        print()
        
        targets = response.get('targets', [])
        print(f"Number of targets found: {len(targets)}")
        
        if targets:
            print()
            print("Target Details:")
            for i, target in enumerate(targets, 1):
                print(f"\n{i}. {target.get('name', 'Unknown')}")
                print(f"   Target ID: {target.get('targetId', 'N/A')}")
                print(f"   Status: {target.get('status', 'N/A')}")
                print(f"   Description: {target.get('description', 'N/A')}")
        else:
            print("\n⚠️  The 'targets' list is empty in the response")
            print("   This means no targets have been created for this gateway")
            
    except Exception as e:
        print(f"❌ Error listing targets: {e}")
        print(f"   Error type: {type(e).__name__}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
