#!/bin/bash
cd gateway
python3 main.py sre-gateway \
  --region us-east-1 \
  --endpoint-url https://bedrock-agentcore-control.us-east-1.amazonaws.com \
  --role-arn arn:aws:iam::310485116687:role/BedrockAgentCoreGatewayRole \
  --discovery-url https://cognito-idp.us-east-1.amazonaws.com/us-east-1_CPukh9Ilm/.well-known/openid-configuration \
  --allowed-clients 7pvnt90jh7gdnhe4al23vn389d \
  --description-for-gateway "AgentCore Gateway for SRE Agent" \
  --s3-uri s3://sre-agent-specs-1771225925/devops-multiagent-demo/k8s_api.yaml \
  --s3-uri s3://sre-agent-specs-1771225925/devops-multiagent-demo/logs_api.yaml \
  --s3-uri s3://sre-agent-specs-1771225925/devops-multiagent-demo/metrics_api.yaml \
  --s3-uri s3://sre-agent-specs-1771225925/devops-multiagent-demo/runbooks_api.yaml \
  --description-for-target "Kubernetes API" \
  --description-for-target "Logs API" \
  --description-for-target "Metrics API" \
  --description-for-target "Runbooks API" \
  --create-s3-target \
  --provider-arn arn:aws:bedrock-agentcore:us-east-1:310485116687:token-vault/default/apikeycredentialprovider/sre-agent-api-key-credential-provider \
  --save-gateway-url \
  --output-json
