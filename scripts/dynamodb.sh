#!/bin/bash

TABLE_NAME="Models"

echo "--- Checking/Creating DynamoDB table: ${TABLE_NAME} ---"

if aws dynamodb describe-table --table-name ${TABLE_NAME} > /dev/null 2>&1; then
    echo "Table '${TABLE_NAME}' already exists. Skipping creation."
else
    echo "Creating table '${TABLE_NAME}'..."
    aws dynamodb create-table --table-name ${TABLE_NAME} \
        --attribute-definitions \
            AttributeName=ModelID,AttributeType=S \
            AttributeName=ModelName,AttributeType=S \
        --key-schema \
            AttributeName=ModelID,KeyType=HASH \
            AttributeName=ModelName,KeyType=RANGE \
        --provisioned-throughput \
            ReadCapacityUnits=5,WriteCapacityUnits=5
    echo "Table '${TABLE_NAME}' created."
fi

# Get current date in ISO 8601 format
CREATION_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "Putting item into ${TABLE_NAME}..."

aws dynamodb put-item \
    --table-name "${TABLE_NAME}" \
    --item '{
        "ModelID": {"S": "model-001"},
        "ModelName": {"S": "TESLAChurn"},
        "ModelAccuracy": {"N": "0.92"},
        "ModelCreationDate": {"S": "'"${CREATION_DATE}"'"}
    }'

aws dynamodb put-item \
    --table-name "${TABLE_NAME}" \
    --item '{
        "ModelID": {"S": "model-002"},
        "ModelName": {"S": "TESLAForcasting"},
        "ModelAccuracy": {"N": "0.62"},
        "ModelCreationDate": {"S": "'"${CREATION_DATE}"'"}
    }'

echo "Item successfully added."

