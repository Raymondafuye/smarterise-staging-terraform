import io
import os
import time
from datetime import datetime

import boto3
import pandas as pd
import sqlalchemy


def create_aurora_engine(cluster_name) -> sqlalchemy.engine.Engine:
    """Creates SQLAlchemy engine for Aurora Data API by retrieving secrets and the cluster arn

    Returns:
        sqlalchemy.engine.Engine: SQLAlchemy engine
    """
    secrets = boto3.client("secretsmanager")
    res = secrets.list_secrets(Filters=[{"Key": "description", "Values": [cluster_name]}])
    secret_arn = res["SecretList"][0]["ARN"]

    rds = boto3.client("rds")
    cluster_arn = rds.describe_db_clusters(DBClusterIdentifier=cluster_name)["DBClusters"][0]["DBClusterArn"]

    cluster_arn = os.environ.get("CLUSTER_ARN", cluster_arn)
    secret_arn = os.environ.get("SECRET_ARN", secret_arn)

    engine = sqlalchemy.create_engine(
        "postgresql+auroradataapi://:@/smartmeters",
        echo=True,
        connect_args=dict(aurora_cluster_arn=cluster_arn, secret_arn=secret_arn),
    )

    return engine


def write_timestamp_to_s3(df: pd.DataFrame):
    """Writes latest timestamp from rds to RDS State bucket

    Args:
        df (pd.DataFrame): DataFrame containing latest timestamp
    """

    dt = datetime.utcnow()
    date = dt.strftime("%Y%m%d")
    time = dt.strftime("%H%M%S")

    buffer = io.StringIO()
    df.to_json(buffer)
    s3_resource = boto3.resource("s3")

    print("\n writing RDS state to S3... ")
    # write to state.json
    res = s3_resource.Object("smarterise-rds-state", "state.json").put(
        Body=buffer.getvalue(), ServerSideEncryption="AES256"
    )
    print(res)
    print("Success... ")

    print("Adding to archive... ")
    # write to archive state.json
    path = os.path.join("archive", date, time, "state.json")
    res = s3_resource.Object("smarterise-rds-state", path).put(Body=buffer.getvalue(), ServerSideEncryption="AES256")
    print(res)
    print("Success... ")


def get_latest_timestamp(engine: sqlalchemy.engine.Engine) -> pd.DataFrame:
    """Gets the latest timestamp from Aurora

    Args:
        engine (sqlalchemy.engine.Engine): SqlAlchemy Aurora Engine

    Returns:
        pd.DataFrame: DataFrame containing the latest timestamp from Aurora
    """

    print("Getting latest timestamp from Aurora... ")
    with engine.connect() as conn:
        df = pd.read_sql(
            "SELECT MIN(timestamp) from (SELECT DISTINCT timestamp FROM smart_device_readings ORDER BY timestamp DESC LIMIT 100) t",
            con=conn,
        )

    return df


def turn_off_lambda_trigger(lambda_function_name: str):
    """Turns off the event source mapping for the given lambda function

    Args:
        lambda_function_name (str): Name of the lambda function who's event source mapping will be turned off
    """
    trigger_status = "Enabled"

    lambda_client = boto3.client("lambda")

    print("\n Turning off lambda trigger... ")
    print(lambda_function_name)
    uuid = lambda_client.list_event_source_mappings(FunctionName=lambda_function_name,)["EventSourceMappings"][
        0
    ]["UUID"]

    response = lambda_client.update_event_source_mapping(
        Enabled=False,
        UUID=uuid,
    )

    print("Status Code: ", response["ResponseMetadata"]["HTTPStatusCode"])

    while trigger_status != "Disabled":
        trigger_status = lambda_client.get_event_source_mapping(
            UUID=uuid,
        )["State"]
        print("Trigger Status: ", trigger_status)

    print("Lambda Trigger successfully disabled...")


def scale_down_ecs():
    """Scales down ECS by reducing the replicas to 0"""

    print("\n Scaling down ECS... ")
    ecs = boto3.client("ecs")
    ecs_count = 1
    response = ecs.update_service(cluster="main_dev", service="api_service", desiredCount=0)
    print("Status Code: ", response["ResponseMetadata"]["HTTPStatusCode"])
    while ecs_count:
        res = ecs.describe_services(cluster="main_dev", services=["api_service"])

        ecs_count = res["services"][0]["runningCount"]
        print("Current count: ", ecs_count)

        if ecs_count:
            print("Waiting 30 seconds before checking again... ")
            time.sleep(30)

    print("ECS successfully scaled down to 0")


def wait_for_rds_scale_down(cluster_name: str):
    """Waits for the Aurora RDS DB Cluster to scale down to 0 ACUs

    Args:
        cluster_name (str): Name of the cluster to wait to turn off
    """
    rds = boto3.client("rds")

    cluster_capacity = 4

    print("\n Checking RDS Capacity...")
    time_elapsed = 0
    # check database has stopped
    while cluster_capacity != 0:
        print(cluster_name)
        response = rds.describe_db_clusters(DBClusterIdentifier=cluster_name)

        cluster_capacity = response["DBClusters"][0]["Capacity"]

        print("Cluster capacity at: ", cluster_capacity)

        if cluster_capacity:
            print("Waiting 30 seconds before checking again... ")
            time.sleep(30)
            time_elapsed = time_elapsed + 30
            print(f"Total time waiting: {time_elapsed} \n")

    print("RDS Scaled down successfully... ")


def run():
    boto3.setup_default_session(
        region_name="eu-west-2",
        aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID"),
        aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY"),
    )

    lambda_function_name = "smart-device-to-rds"
    rds_cluster_name = "rds-postgresql-cluster"
    # lambda_function_name = "invoke-ml-model"
    # rds_cluster_name = "dev-smarterise-cluster"

    engine = create_aurora_engine(rds_cluster_name)
    df = get_latest_timestamp(engine)
    engine.dispose()

    write_timestamp_to_s3(df)

    turn_off_lambda_trigger(lambda_function_name)

    scale_down_ecs()

    wait_for_rds_scale_down(rds_cluster_name)


if __name__ == "__main__":
    run()
