#!/bin/bash
# Fix IAM Permissions for AgentCore Gateway

echo "Fixing IAM permissions for Bedrock AgentCore Gateway..."
echo ""

USER_NAME="Dev-Piyush"
POLICY_NAME="BedrockAgentCoreGatewayPolicy"

# Create IAM policy for AgentCore Gateway
cat > /tmp/agentcore_policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "bedrock-agentcore:CreateGateway",
                "bedrock-agentcore:GetGateway",
                "bedrock-agentcore:UpdateGateway",
                "bedrock-agentcore:DeleteGateway",
                "bedrock-agentcore:ListGateways",
                "bedrock-agentcore:CreateTarget",
                "bedrock-agentcore:GetTarget",
                "bedrock-agentcore:UpdateTarget",
                "bedrock-agentcore:DeleteTarget",
                "bedrock-agentcore:ListTargets",
                "bedrock-agentcore:CreateApiKeyCredentialProvider",
                "bedrock-agentcore:GetApiKeyCredentialProvider",
                "bedrock-agentcore:UpdateApiKeyCredentialProvider",
                "bedrock-agentcore:DeleteApiKeyCredentialProvider",
                "bedrock-agentcore:ListApiKeyCredentialProviders"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::sre-agent-specs-*",
                "arn:aws:s3:::sre-agent-specs-*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:CreateSecret",
                "secretsmanager:GetSecretValue",
                "secretsmanager:PutSecretValue",
                "secretsmanager:DeleteSecret"
            ],
            "Resource": "arn:aws:secretsmanager:*:*:secret:bedrock-agentcore-identity!*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:PassRole"
            ],
            "Resource": "arn:aws:iam::*:role/BedrockAgentCoreGatewayRole",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "bedrock-agentcore.amazonaws.com"
                }
            }
        }
    ]
}
EOF

echo "Creating IAM policy: $POLICY_NAME"
POLICY_ARN=$(aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document file:///tmp/agentcore_policy.json \
    --description "Permissions for Bedrock AgentCore Gateway operations" \
    --query 'Policy.Arn' \
    --output text 2>&1)

if echo "$POLICY_ARN" | grep -q "EntityAlreadyExists"; then
    echo "Policy already exists, getting ARN..."
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
    echo "Policy ARN: $POLICY_ARN"
else
    echo "✅ Policy created: $POLICY_ARN"
fi

echo ""
echo "Attaching policy to user: $USER_NAME"
aws iam attach-user-policy \
    --user-name "$USER_NAME" \
    --policy-arn "$POLICY_ARN"

if [ $? -eq 0 ]; then
    echo "✅ Policy attached successfully!"
    echo ""
    echo "Waiting 10 seconds for IAM changes to propagate..."
    sleep 10
    echo "✅ Ready to create gateway"
else
    echo "❌ Failed to attach policy"
    exit 1
fi
