#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
ROLE_NAME="MathSolverRole"
FUNCTION_NAME="MathSolverFunction"
API_NAME="MathSolverApi"
PYTHON_FILE="solver.py"
ZIP_FILE="solver.zip"

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
    --assume-role-policy-document file://solver_trust_policy.json
  echo "Role created. Waiting for propagation before attaching policy..."
  sleep 10 # Give IAM time to propagate the new role
fi

BASIC_EXECUTION_POLICY_ARN="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
echo "--- Step 2: Checking/Attaching AWSLambdaBasicExecutionRole Policy ---"
# Check if the policy is already attached to make the script idempotent
if aws iam list-attached-role-policies --role-name ${ROLE_NAME} | grep -q "\"PolicyArn\": \"${BASIC_EXECUTION_POLICY_ARN}\""; then
  echo "Policy 'AWSLambdaBasicExecutionRole' is already attached to role '${ROLE_NAME}'."
else
  echo "Attaching policy 'AWSLambdaBasicExecutionRole' to role '${ROLE_NAME}'..."
  aws iam attach-role-policy \
      --role-name ${ROLE_NAME} \
      --policy-arn ${BASIC_EXECUTION_POLICY_ARN}
fi

echo "--- Step 3: Checking/Attaching API Gateway Invoke Policy ---"
APIGW_POLICY_NAME="ApiGatewayInvokeLambdaPolicy"
APIGW_POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${APIGW_POLICY_NAME}"

# Create the policy from the JSON file if it doesn't exist
if ! aws iam get-policy --policy-arn ${APIGW_POLICY_ARN} > /dev/null 2>&1; then
    echo "Creating policy '${APIGW_POLICY_NAME}' from api_gateway_policy.json..."
    aws iam create-policy --policy-name ${APIGW_POLICY_NAME} --policy-document file://api_gateway_policy.json > /dev/null
fi

# Attach the policy to the role if it's not already attached
if aws iam list-attached-role-policies --role-name ${ROLE_NAME} | grep -q "\"PolicyArn\": \"${APIGW_POLICY_ARN}\""; then
    echo "Policy '${APIGW_POLICY_NAME}' is already attached to role '${ROLE_NAME}'."
else
    echo "Attaching policy '${APIGW_POLICY_NAME}' to role '${ROLE_NAME}'..."
    aws iam attach-role-policy --role-name ${ROLE_NAME} --policy-arn ${APIGW_POLICY_ARN}
fi

echo "--- Step 5: Creating/Updating Lambda function ---"
LAMBDA_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
if aws lambda get-function --function-name ${FUNCTION_NAME} > /dev/null 2>&1; then
  echo "Lambda function '${FUNCTION_NAME}' already exists. Updating code..."
  aws lambda update-function-code --function-name ${FUNCTION_NAME} --zip-file fileb://${ZIP_FILE} > /dev/null
else
  echo "Lambda function '${FUNCTION_NAME}' not found. Creating it..."
  aws lambda create-function \
    --function-name ${FUNCTION_NAME} \
    --runtime python3.12 \
    --zip-file fileb://${ZIP_FILE} \
    --handler solver.lambda_handler \
    --timeout 10 \
    --role ${LAMBDA_ROLE_ARN} > /dev/null
fi

echo "--- Step 6: Creating API Gateway ---"
AWS_REGION=$(aws configure get region)

# Get or create the REST API
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='${API_NAME}'].id" --output text)
if [ -z "$API_ID" ]; then
  echo "Creating REST API '${API_NAME}'..."
  API_ID=$(aws apigateway create-rest-api --name "${API_NAME}" --description "API for Math Solver" --query 'id' --output text)
fi
echo "API ID: ${API_ID}"

# Get the root resource ID
ROOT_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id ${API_ID} --query 'items[?path==`/`].id' --output text)

# Create the /solve resource
RESOURCE_PATH="solve"
RESOURCE_ID=$(aws apigateway create-resource --rest-api-id ${API_ID} --parent-id ${ROOT_RESOURCE_ID} --path-part ${RESOURCE_PATH} --query 'id' --output text)

# Create the POST method on the /solve resource
aws apigateway put-method --rest-api-id ${API_ID} --resource-id ${RESOURCE_ID} --http-method POST --authorization-type "NONE" > /dev/null

# Create the Lambda proxy integration
LAMBDA_FUNCTION_ARN=$(aws lambda get-function --function-name ${FUNCTION_NAME} --query 'Configuration.FunctionArn' --output text)
INTEGRATION_URI="arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_FUNCTION_ARN}/invocations"

aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${RESOURCE_ID} \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri ${INTEGRATION_URI} \
    --credentials ${LAMBDA_ROLE_ARN} > /dev/null

echo "--- Step 7: Granting API Gateway permission to invoke Lambda ---"
STATEMENT_ID="apigateway-prod-invoke-${FUNCTION_NAME}"
SOURCE_ARN="arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/POST/${RESOURCE_PATH}"

aws lambda add-permission \
    --function-name ${FUNCTION_NAME} \
    --statement-id ${STATEMENT_ID} \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "${SOURCE_ARN}" 2>/dev/null || echo "Lambda permission already exists."

echo "--- Step 8: Deploying API ---"
STAGE_NAME="prod"
aws apigateway create-deployment --rest-api-id ${API_ID} --stage-name ${STAGE_NAME} > /dev/null

echo "--- Deployment Complete ---"
API_URL="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/${STAGE_NAME}/${RESOURCE_PATH}"
echo "API Gateway URL: ${API_URL}"
echo "You can test it with:"
echo "curl -X POST -H \"Content-Type: application/json\" -d '{\"expression\": \"2+2*10\"}' ${API_URL}"
