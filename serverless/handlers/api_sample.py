def build_body():
    return {"body": "Hello!"}


def lambda_handler(event, context):
    return build_body()
