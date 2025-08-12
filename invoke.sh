FUNCTION_NAME="HelloFunction"

aws lambda invoke \
  --function-name ${FUNCTION_NAME} \
  --cli-binary-format raw-in-base64-out \
  --payload '{ "name": "Ezz" }' \
  outputs/response.json

echo "--- Done! Check response.json for the output. ---"