import json

def lambda_handler(event, context):
    """
    A simple Lambda function that greets a name passed in the event.

    :param event: The event dict that contains the request parameters.
                  Expected to have a 'name' key.
    :param context: The context in which the function is called.
    :return: A response dict with a status code and a message in the body.
    """
    print(f"Received event: {event}")
    print(f"Remaining Time: {context.get_remaining_time_in_millis()} ms")
    print(f"Function Name: {context.function_name}")
    print(f"Memory Limit: {context.memory_limit_in_mb} MB")
    # Safely get the 'name' from the event, providing 'World' as a default.
    name = event.get('name', 'World')

    message = f"Hello, {name}!"
    print(message)

    return {
        'statusCode': 200,
        'body': json.dumps(message)
    }