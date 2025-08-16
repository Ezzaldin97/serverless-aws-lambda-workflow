#!/bin/bash

# This script retrieves items from the 'Models' table by scanning for a specific ModelName.
#
# WARNING: A 'scan' operation reads every item in the table and can be slow and costly
# for large tables. For production use, consider creating a Global Secondary Index (GSI)
# on ModelName to use the more efficient 'query' operation instead.

# Check if a model name was provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <MODEL_NAME>"
  echo "Example: $0 TESLAChurn"
  exit 1
fi

TABLE_NAME="Models"
MODEL_NAME=$1

echo "Scanning table '${TABLE_NAME}' for items with ModelName: ${MODEL_NAME}..."

aws dynamodb scan \
    --table-name "${TABLE_NAME}" \
    --filter-expression "ModelName = :n" \
    --expression-attribute-values '{":n": {"S": "'"${MODEL_NAME}"'"}}' \
    --return-consumed-capacity TOTAL

echo "--- Scan Complete ---"