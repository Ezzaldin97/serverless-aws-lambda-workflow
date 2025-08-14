#!/bin/bash

# This script lists all managed and inline policies for a given IAM role.

# Check if a role name was provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <IAM_ROLE_NAME>"
  echo "Example: $0 MathSolverRole"
  exit 1
fi

ROLE_NAME=$1

echo "--- Checking policies for role: ${ROLE_NAME} ---"

# Check if the role exists first
if ! aws iam get-role --role-name "${ROLE_NAME}" > /dev/null 2>&1; then
  echo "Error: IAM role '${ROLE_NAME}' not found."
  exit 1
fi

echo ""
echo "1. Attached Managed Policies (AWS-managed and Customer-managed):"
ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "${ROLE_NAME}" --query 'AttachedPolicies' --output text)

if [ -z "$ATTACHED_POLICIES" ]; then
  echo "   No attached managed policies found."
else
  aws iam list-attached-role-policies --role-name "${ROLE_NAME}" --query 'AttachedPolicies[].[PolicyName, PolicyArn]' --output table
fi

echo ""
echo "2. Inline Policies (Embedded directly in the role):"
INLINE_POLICIES=$(aws iam list-role-policies --role-name "${ROLE_NAME}" --query 'PolicyNames' --output text)

if [ -z "$INLINE_POLICIES" ]; then
  echo "   No inline policies found."
else
  echo "   Found inline policy names: ${INLINE_POLICIES}"
  echo "   (To view the content of an inline policy, use 'aws iam get-role-policy --role-name ${ROLE_NAME} --policy-name <POLICY_NAME>')"
fi

echo "--- Done ---"