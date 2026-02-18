#!/bin/bash

# AWS Support Evidence Gathering Script
# Purpose: Collect evidence for Bedrock rate limit increase request
# Date: February 18, 2026

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     AWS Support Evidence Gathering for Bedrock            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Create evidence directory
mkdir -p support_evidence
cd support_evidence

echo "📁 Created support_evidence directory"
echo ""

# ============================================================================
# 1. Analyze Application Logs
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "1. Analyzing Application Logs"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ -f "../claude_sonnet_test1.log" ]; then
    echo "✅ Found claude_sonnet_test1.log"
    
    # Count throttling events
    THROTTLE_COUNT=$(grep -c "ThrottlingException" ../claude_sonnet_test1.log)
    echo "   Throttling events: $THROTTLE_COUNT"
    
    # Extract throttling errors
    echo "   Extracting throttling errors..."
    grep -A 5 "ThrottlingException" ../claude_sonnet_test1.log > throttling_errors.txt
    echo "   ✅ Saved to: throttling_errors.txt"
    
    # Get time period
    START_TIME=$(head -1 ../claude_sonnet_test1.log | awk '{print $1, $2}')
    END_TIME=$(tail -1 ../claude_sonnet_test1.log | awk '{print $1, $2}')
    echo "   Log period: $START_TIME to $END_TIME"
    
    # Count InvokeModel calls
    INVOKE_COUNT=$(grep -c "InvokeModel" ../claude_sonnet_test1.log)
    echo "   InvokeModel calls: $INVOKE_COUNT"
    
else
    echo "⚠️  claude_sonnet_test1.log not found"
fi

echo ""

if [ -f "../nova_test_final.log" ]; then
    echo "✅ Found nova_test_final.log (successful test)"
    
    # Count successful responses
    SUCCESS_COUNT=$(grep -c "response captured\|SUCCESS" ../nova_test_final.log)
    echo "   Successful responses: $SUCCESS_COUNT"
    
    # Extract success evidence
    echo "   Extracting success evidence..."
    grep -B 2 -A 2 "response captured" ../nova_test_final.log | head -20 > nova_success_evidence.txt
    echo "   ✅ Saved to: nova_success_evidence.txt"
else
    echo "⚠️  nova_test_final.log not found"
fi

echo ""

# ============================================================================
# 2. CloudWatch Metrics
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "2. Gathering CloudWatch Metrics"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if AWS CLI is available
if command -v aws &> /dev/null; then
    echo "✅ AWS CLI found"
    echo ""
    
    # Get Bedrock invocations
    echo "📊 Fetching Bedrock Invocations (past 7 days)..."
    aws cloudwatch get-metric-statistics \
        --namespace AWS/Bedrock \
        --metric-name Invocations \
        --start-time $(date -d '7 days ago' -u +%Y-%m-%dT%H:%M:%S) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
        --period 3600 \
        --statistics Sum \
        --region us-east-1 \
        --output json > cloudwatch_invocations.json 2>&1
    
    if [ $? -eq 0 ]; then
        echo "   ✅ Saved to: cloudwatch_invocations.json"
    else
        echo "   ⚠️  Error fetching invocations (check AWS credentials)"
    fi
    
    echo ""
    
    # Get throttling errors
    echo "📊 Fetching Bedrock UserErrors (throttling, past 7 days)..."
    aws cloudwatch get-metric-statistics \
        --namespace AWS/Bedrock \
        --metric-name UserErrors \
        --start-time $(date -d '7 days ago' -u +%Y-%m-%dT%H:%M:%S) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
        --period 3600 \
        --statistics Sum \
        --region us-east-1 \
        --output json > cloudwatch_user_errors.json 2>&1
    
    if [ $? -eq 0 ]; then
        echo "   ✅ Saved to: cloudwatch_user_errors.json"
    else
        echo "   ⚠️  Error fetching user errors (check AWS credentials)"
    fi
    
    echo ""
    
    # Get model invocations by model
    echo "📊 Fetching Model-Specific Metrics..."
    aws cloudwatch get-metric-statistics \
        --namespace AWS/Bedrock \
        --metric-name Invocations \
        --dimensions Name=ModelId,Value=us.anthropic.claude-3-5-sonnet-20241022-v2:0 \
        --start-time $(date -d '7 days ago' -u +%Y-%m-%dT%H:%M:%S) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
        --period 3600 \
        --statistics Sum \
        --region us-east-1 \
        --output json > cloudwatch_claude_sonnet_invocations.json 2>&1
    
    if [ $? -eq 0 ]; then
        echo "   ✅ Saved to: cloudwatch_claude_sonnet_invocations.json"
    else
        echo "   ⚠️  Error fetching Claude Sonnet metrics"
    fi
    
else
    echo "❌ AWS CLI not found"
    echo "   Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
fi

echo ""

# ============================================================================
# 3. Service Quotas
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "3. Checking Service Quotas"
echo "═══════════════════════════════════════════════════════════"
echo ""

if command -v aws &> /dev/null; then
    echo "📋 Fetching Bedrock Service Quotas..."
    aws service-quotas list-service-quotas \
        --service-code bedrock \
        --region us-east-1 \
        --output json > service_quotas_bedrock.json 2>&1
    
    if [ $? -eq 0 ]; then
        echo "   ✅ Saved to: service_quotas_bedrock.json"
        
        # Try to extract relevant quotas
        echo ""
        echo "   📊 Relevant Quotas:"
        cat service_quotas_bedrock.json | grep -A 5 -i "claude\|sonnet\|rate\|request" | head -20
    else
        echo "   ⚠️  Error fetching service quotas"
    fi
else
    echo "❌ AWS CLI not found"
fi

echo ""

# ============================================================================
# 4. Generate Summary Report
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "4. Generating Summary Report"
echo "═══════════════════════════════════════════════════════════"
echo ""

cat > evidence_summary.txt << EOF
AWS BEDROCK SUPPORT REQUEST - EVIDENCE SUMMARY
Generated: $(date)
Account: 310485116687
Region: us-east-1

═══════════════════════════════════════════════════════════

1. APPLICATION LOG ANALYSIS

Throttling Events: $THROTTLE_COUNT
InvokeModel Calls: $INVOKE_COUNT
Log Time Period: $START_TIME to $END_TIME

Model Tested: us.anthropic.claude-3-5-sonnet-20241022-v2:0
Result: ThrottlingException - "Too many requests, please wait before trying again"

Workaround Model: amazon.nova-pro-v1:0
Result: SUCCESS - No throttling

═══════════════════════════════════════════════════════════

2. CLOUDWATCH METRICS

Files Generated:
- cloudwatch_invocations.json (Bedrock invocations, 7 days)
- cloudwatch_user_errors.json (Throttling errors, 7 days)
- cloudwatch_claude_sonnet_invocations.json (Model-specific)

═══════════════════════════════════════════════════════════

3. SERVICE QUOTAS

File Generated:
- service_quotas_bedrock.json (Current Bedrock quotas)

═══════════════════════════════════════════════════════════

4. SUPPORTING FILES

- throttling_errors.txt (Extracted error logs)
- nova_success_evidence.txt (Proof of concept with Nova)

═══════════════════════════════════════════════════════════

5. REQUEST SUMMARY

Current Model: us.anthropic.claude-3-5-sonnet-20241022-v2:0
Current Limit: [To be verified from Service Quotas]
Requested Limit: 50 requests per minute

Justification:
- Multi-agent SRE system with 5 concurrent agents
- Typical investigation: 8-12 requests
- Peak scenarios: 30-45 requests
- Buffer for retries: +5-10 requests
- Total: 50 requests per minute

═══════════════════════════════════════════════════════════

6. NEXT STEPS

Manual Actions Required:
1. Go to AWS Console → Service Quotas → Amazon Bedrock
2. Take screenshot of current Claude Sonnet v2 limits
3. Take screenshot of usage percentage (if available)
4. Go to CloudWatch Console → Metrics → AWS/Bedrock
5. Take screenshots of Invocations and UserErrors graphs
6. Review generated JSON files for accuracy
7. Submit support case with all evidence

═══════════════════════════════════════════════════════════

EVIDENCE FILES LOCATION:
$(pwd)

Total Files: $(ls -1 | wc -l)
EOF

echo "✅ Summary report generated: evidence_summary.txt"
echo ""

# ============================================================================
# 5. Final Instructions
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "5. Next Steps"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "📋 Manual Actions Required:"
echo ""
echo "1. AWS Console → Service Quotas → Amazon Bedrock"
echo "   - Screenshot current limits for Claude models"
echo "   - Screenshot usage percentage"
echo ""
echo "2. AWS Console → CloudWatch → Metrics → AWS/Bedrock"
echo "   - Screenshot Invocations graph (past 7 days)"
echo "   - Screenshot UserErrors graph (past 7 days)"
echo ""
echo "3. Review Generated Files:"
echo "   - evidence_summary.txt"
echo "   - throttling_errors.txt"
echo "   - cloudwatch_*.json files"
echo ""
echo "4. Submit Support Case:"
echo "   - Use template from AWS_SUPPORT_REQUEST.md"
echo "   - Attach all evidence files"
echo "   - Attach screenshots from console"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "✅ Evidence Gathering Complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📁 All evidence saved to: $(pwd)"
echo ""
echo "📄 Files generated:"
ls -lh
echo ""
echo "📋 Next: Review AWS_SUPPORT_REQUEST.md for submission template"
