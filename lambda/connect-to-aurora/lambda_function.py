import boto3
from botocore.exceptions import ClientError
import os


def lambda_handler(event, context):
    session = boto3.session.Session()
    rdsData = session.client('rds-data')
    try:
        response = rdsData.execute_statement(
            resourceArn=os.environ['CLUSTER_ARN'],
            secretArn=os.environ['SECRET_ARN'],
            database='smartmeters',
            sql='select count(*) as number_of_readings from smart_device_readings')
        number_of_readings = response['records'][0][0]["longValue"]
    except ClientError as e:
        raise e

    return {
        'statusCode': 200,
        'body': number_of_readings
    }
