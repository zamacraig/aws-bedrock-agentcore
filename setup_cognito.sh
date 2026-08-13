#!/bin/bash

set -e

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo ".env file not found"
    exit 1
fi

echo "Creating Cognito User Pool..."

# Create User Pool
POOL_ID=$(aws cognito-idp create-user-pool \
  --pool-name "$POOL_NAME" \
  --policies '{"PasswordPolicy":{"MinimumLength":8}}' \
  --region "$REGION" \
  --query 'UserPool.Id' \
  --output text)

echo "User Pool created: $POOL_ID"

# Create App Client
CLIENT_ID=$(aws cognito-idp create-user-pool-client \
  --user-pool-id "$POOL_ID" \
  --client-name "$CLIENT_NAME" \
  --no-generate-secret \
  --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
  --region "$REGION" \
  --query 'UserPoolClient.ClientId' \
  --output text)

echo "App Client created: $CLIENT_ID"

# Store configuration in SSM Parameter Store
echo "Storing Cognito configuration in SSM Parameter Store..."

aws ssm put-parameter \
  --name "/app/customersupport/agentcore/pool_id" \
  --value "$POOL_ID" \
  --type String \
  --overwrite > /dev/null

aws ssm put-parameter \
  --name "/app/customersupport/agentcore/client_id" \
  --value "$CLIENT_ID" \
  --type String \
  --overwrite > /dev/null

  aws ssm put-parameter \
  --name "/app/customersupport/agentcore/web_client_id " \
  --value "$CLIENT_ID" \
  --type String \
  --overwrite > /dev/null

aws ssm put-parameter \
  --name "/app/customersupport/agentcore/cognito_discovery_url" \
  --value "https://cognito-idp.${REGION}.amazonaws.com/${POOL_ID}/.well-known/openid-configuration" \
  --type String \
  --overwrite > /dev/null

aws cognito-idp admin-create-user \
  --user-pool-id "$POOL_ID" \
  --username "$USERNAME" \
  --temporary-password "$TEMP_PASSWORD" \
  --user-attributes Name=email,Value="$EMAIL" Name=email_verified,Value=true \
  --message-action SUPPRESS \
  --no-cli-pager

# Set a permanent password so the user is confirmed and ready to use
aws cognito-idp admin-set-user-password \
  --user-pool-id "$POOL_ID" \
  --username "$USERNAME" \
  --password "$PERMANENT_PASSWORD" \
  --permanent \
  --no-cli-pager

echo "User ${USERNAME} created and confirmed"