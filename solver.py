import json

def lambda_handler(event, context):
    print(f"Received event: {event}")

    headers = {
        "Content-Type": "application/json"
    }

    try:
        # The request body from API Gateway is a string that needs to be parsed
        body = json.loads(event.get('body', '{}'))
        expression = body.get("expression", "")

        if not expression:
            return {"statusCode": 400, "headers": headers, "body": json.dumps({"error": "No expression provided"})}

        print(f"Evaluating expression: {expression}")
        result = eval(expression)
        print(f"Result: {result}")
        
        return {"statusCode": 200, "headers": headers, "body": json.dumps({"result": result})}

    except Exception as e:
        print(f"Error: {e}")
        return {"statusCode": 400, "headers": headers, "body": json.dumps({"error": f"Invalid expression: {e}"})}
