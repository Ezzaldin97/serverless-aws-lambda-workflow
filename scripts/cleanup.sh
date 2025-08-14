#!/bin/bash

# This script cleans up the AWS Lambda function and API Gateway created by solver.sh

# --- Configuration ---
FUNCTION_NAME="MathSolverFunction"
API_NAME="MathSolverApi"

echo "--- Step 1: Deleting API Gateway Deployment ---"
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='${API_NAME}'].id" --output text)
if [ ! -z "$API_ID" ]; then
  echo "Deleting API Gateway '${API_NAME}'..."

  # Delete all deployments
  DEPLOYMENTS=$(aws apigateway get-deployments --rest-api-id ${API_ID} --query "items[*].id" --output text)
  for DEPLOYMENT_ID in $DEPLOYMENTS; do
    aws apigateway delete-deployment --rest-api-id ${API_ID} --deployment-id $DEPLOYMENT_ID > /dev/null
  done

  # Delete all stages
  STAGES=$(aws apigateway get-stages --rest-api-id ${API_ID} --query "item.stageName" --output text)
  for STAGE_NAME in $STAGES; do
    aws apigateway delete-stage --rest-api-id ${API_ID} --stage-name $STAGE_NAME
  done

  # Delete the API Gateway
  aws apigateway delete-rest-api --rest-api-id ${API_ID} > /dev/null
  echo "API Gateway '${API_NAME}' deleted."
else
  echo "API Gateway '${API_NAME}' not found, skipping deletion."
fi

echo "--- Step 2: Deleting Lambda Function ---"
if aws lambda get-function --function-name ${FUNCTION_NAME} > /dev/null 2>&1; then
  echo "Deleting Lambda function '${FUNCTION_NAME}'..."

  # Remove API Gateway permission from Lambda function
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  AWS_REGION=$(aws configure get region)
  API_ID=$(aws apigateway get-rest-apis --query "items[?name=='${API_NAME}'].id" --output text)
  SOURCE_ARN="arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*"
  STATEMENT_ID="apigateway-prod-invoke-${FUNCTION_NAME}"

  aws lambda remove-permission \
    --function-name ${FUNCTION_NAME} \
    --statement-id ${STATEMENT_ID} 2>/dev/null || echo "Lambda permission does not exist, skipping removal."

  # Delete the Lambda function
  aws lambda delete-function --function-name ${FUNCTION_NAME} > /dev/null
  echo "Lambda function '${FUNCTION_NAME}' deleted."
else
  echo "Lambda function '${FUNCTION_NAME}' not found, skipping deletion."
fi

echo "--- Cleanup Complete ---"