#!/usr/bin/env python3
"""Check Gateway Target Status"""

import boto3
import time
import sys

GATEWAY_ID = "sre-gateway-rrhmyjghhe"
REGION = "us-east-1"

def check_targets():
    client = boto3.client('bedrock-agentcore-control', region_name=REGION)
    
    print("Checking gateway target status...")
    print(f"Gateway ID: {GATEWAY_ID}\n")
    
    try:
        response = client.list_gateway_targets(gatewayIdentifier=GATEWAY_ID)
        targets = response.get('items', [])  # API returns 'items' not 'targets'
        
        if not targets:
            print("❌ No targets found!")
            return False
        
        print(f"Found {len(targets)} targets:\n")
        
        all_ready = True
        for target in targets:
            name = target.get('name', 'Unknown')
            target_id = target.get('targetId', 'Unknown')
            status = target.get('status', 'Unknown')
            
            status_icon = "✅" if status == "READY" else "⏳" if status == "CREATING" else "❌"
            print(f"{status_icon} {name}")
            print(f"   ID: {target_id}")
            print(f"   Status: {status}")
            print()
            
            if status != "READY":
                all_ready = False
        
        return all_ready
        
    except Exception as e:
        print(f"❌ Error checking targets: {e}")
        return False

if __name__ == "__main__":
    all_ready = check_targets()
    
    if all_ready:
        print("✅ All targets are READY!")
        sys.exit(0)
    else:
        print("⏳ Some targets are still being created...")
        print("   This typically takes 5-10 minutes.")
        print("   Run this script again in a few minutes.")
        sys.exit(1)
