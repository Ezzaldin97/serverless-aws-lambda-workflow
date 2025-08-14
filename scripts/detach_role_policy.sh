#!/bin/bash

# --- Configuration ---
ROLE_NAME="MathSolverRole"
APIGW_POLICY_NAME=$1

# --- Get Account ID ---
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "Could not get AWS Account ID. Please configure your AWS CLI."
    exit 1
fi

# --- Construct the Policy ARN ---
APIGW_POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${APIGW_POLICY_NAME}"

echo "Detaching policy '${APIGW_POLICY_NAME}' from role '${ROLE_NAME}'..."

# --- The Detach Command ---
aws iam detach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn "${APIGW_POLICY_ARN}"

echo "Successfully detached policy."
