import boto3
import json
import os


def lambda_handler(event, context):
    dynamodb = boto3.client("dynamodb")
    event["User"] = "Visitor"

    # Read Data from the Table and Increment the Visitor Count

    data_response = dynamodb.get_item(
        TableName=os.environ["TableName"], Key={"user": {"S": event["User"]}}
    )

    if "Item" in data_response:
        visited_count = int(data_response["Item"]["count"]["N"])
        print(f"Current Visited Count From Database : {visited_count}")
    else:
        visited_count = 0

    visited_count += 1

    # Update The Dynamo DB Table
    update_response = dynamodb.put_item(
        TableName=os.environ["TableName"],
        Item={"user": {"S": event["User"]}, "count": {"N": f"{visited_count}"}},
    )

    if update_response["ResponseMetadata"]["HTTPStatusCode"] != 200:
        return {
            "statusCode": update_response["ResponseMetadata"]["HTTPStatusCode"],
            "body": json.dumps(update_response),
        }

    # Return the Visitor Count To The API
    visitor_response = dynamodb.get_item(
        TableName=os.environ["TableName"], Key={"user": {"S": event["User"]}}
    )

    return {
        "status_code": 200,
        "count": json.dumps(int(visitor_response["Item"]["count"]["N"])),
    }
