#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
ROLE_NAME="MyLambdaExecutionRole"
FUNCTION_NAME="HelloFunction"
PYTHON_FILE="lambda_function.py"
ZIP_FILE="function.zip"

# Replace with your 12-digit AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "Could not get AWS Account ID. Please configure your AWS CLI or set it manually."
    exit 1
fi

echo "--- Step 1: Checking/Creating IAM Role for Lambda ---"
# Check if the role already exists to make the script idempotent
if aws iam get-role --role-name ${ROLE_NAME} > /dev/null 2>&1; then
  echo "IAM role '${ROLE_NAME}' already exists. Skipping creation."
else
  echo "IAM role '${ROLE_NAME}' not found. Creating it..."
  aws iam create-role \
    --role-name ${ROLE_NAME} \
    --assume-role-policy-document file://trust_policy.json
  echo "Role created. Waiting for propagation before attaching policy..."
  sleep 10 # Give IAM time to propagate the new role
fi

POLICY_ARN="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
POLICY_NAME="AWSLambdaBasicExecutionRole"
echo "--- Step 2: Checking/Attaching Execution Policy ---"
# Check if the policy is already attached to make the script idempotent
if aws iam list-attached-role-policies --role-name ${ROLE_NAME} | grep -q "\"PolicyArn\": \"${POLICY_ARN}\""; then
  echo "Policy '${POLICY_NAME}' is already attached to role '${ROLE_NAME}'."
else
  echo "Attaching policy '${POLICY_NAME}' to role '${ROLE_NAME}'..."
  aws iam attach-role-policy \
      --role-name ${ROLE_NAME} \
      --policy-arn ${POLICY_ARN}
fi

echo "--- Step 4: Creating Lambda function ---"
aws lambda create-function \
  --function-name ${FUNCTION_NAME} \
  --runtime python3.12 \
  --zip-file fileb://${ZIP_FILE} \
  --handler lambda_function.lambda_handler \
  --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}
