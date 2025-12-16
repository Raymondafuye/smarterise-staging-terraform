import os

import boto3
from disable import create_aurora_engine, get_latest_timestamp


def run():
    boto3.setup_default_session(
        region_name="eu-west-2",
        aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID"),
        aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY"),
    )

    lambda_function_name = "smart-device-to-rds"
    cluster_name = "rds-postgresql-cluster"

    print("\ntesting secrets connectivity...")
    secrets = boto3.client("secretsmanager")
    res = secrets.list_secrets(Filters=[{"Key": "description", "Values": [cluster_name]}])
    print(res["SecretList"][0]["ARN"])

    print("\ntesting RDS connectivity... ")
    engine = create_aurora_engine(cluster_name)
    df = get_latest_timestamp(engine)
    print(df)
    engine.dispose()
    rds = boto3.client("rds")
    response = rds.describe_db_clusters(DBClusterIdentifier=cluster_name)
    print(response["DBClusters"][0])

    print("\ntesting lambda connectivity...")
    lambda_client = boto3.client("lambda")
    uuid = lambda_client.list_event_source_mappings(FunctionName=lambda_function_name,)["EventSourceMappings"][
        0
    ]["UUID"]

    response = lambda_client.get_event_source_mapping(UUID=uuid)
    print(response)

    print("\ntesting ECS connectivity...")
    ecs = boto3.client("ecs")
    res = ecs.describe_services(cluster="main_dev", services=["api_service"])
    print(res["services"][0])


if __name__ == "__main__":
    run()
