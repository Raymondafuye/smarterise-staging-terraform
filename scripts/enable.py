import datetime
import io
import json
import os
import random
import string
import time

import awswrangler as wr
import boto3
import config
import pandas as pd
import sqlalchemy


def save_dataframe(df: pd.DataFrame, table: str, con: sqlalchemy.engine.Connection, **kwargs):
    """
    Save dataframe to the database.
    Index is saved if it has name. If it's None it will not be saved.
    It implements INSERT ON CONFLICT ("timestamp", "gateway_serial") DO NOTHING' when inserting rows into the Postgres table.
    Table needs to exist before.

    Args:
        df (pd.DataFrame): dataframe to save
        table (str): name of db table
        con (sqlalchemy.engine.Connection): connection
    """

    _insert_conflict_ignore(df=df, table=table, con=con, **kwargs)


def _insert_conflict_ignore(df: pd.DataFrame, table: str, con: sqlalchemy.engine.Connection, **kwargs):
    """
    Saves dataframe to the MySQL database with 'INSERT IGNORE' query.

    First it uses pandas.to_sql to save to temporary table.
    After that it uses SQL to transfer the data to destination table, matching the columns.
    Destination table needs to exist already.
    Final step is deleting the temporary table.

    Args:
        df (pd.DataFrame): dataframe to save
        table (str): table name
        con (sqlalchemy.engine.Connection): connection

    """
    # generate random table name for concurrent writing
    temp_table = "".join(random.choice(string.ascii_letters) for i in range(10))

    try:
        print("Writing to temp table...", temp_table)
        res = df.to_sql(temp_table, con=con, **kwargs)
        print("Response: ", res)

        columns = _table_column_names(table=temp_table, con=con)
        insert_query = f'INSERT INTO {table}({columns}) SELECT {columns} FROM "{temp_table}" ON CONFLICT ("timestamp", "gateway_serial") DO NOTHING'
        print(f"\n Inserting data from {temp_table} to {table}")
        result = con.execute(insert_query)
        print("Result of insert query: ", result.rowcount)

    except Exception as e:
        print("Error", e)
        res = repr(e)

    # drop temp table
    drop_query = f"DROP TABLE IF EXISTS {temp_table}"
    con.execute(drop_query)


def _table_column_names(table: str, con: sqlalchemy.engine.Connection) -> str:
    """Get column names from database table

    Args:
        table (str): name of the table
        con (sqlalchemy.engine.Connection): connection

    Returns:
        str: names of columns as a string so we can interpolate into the SQL queries
    """
    query = f"SELECT column_name FROM information_schema.columns WHERE table_name = '{table}'"
    rows = con.execute(query)
    dirty_names = [i[0] for i in rows]
    clean_names = '"' + '", "'.join(map(str, dirty_names)) + '"'
    return clean_names


def scale_up_ecs():
    """
    Scales up ECS service from to 1 replica.
    """

    print("Scaling up ECS... ")
    ecs = boto3.client("ecs")
    ecs_count = 0
    response = ecs.update_service(cluster="main_dev", service="api_service", desiredCount=1)
    print("Status Code: ", response["ResponseMetadata"]["HTTPStatusCode"])

    while not ecs_count:
        res = ecs.describe_services(cluster="main_dev", services=["api_service"])

        ecs_count = res["services"][0]["runningCount"]
        print("Current count: ", ecs_count)

        if not ecs_count:
            print("Waiting 30 seconds before checking again... ")
            time.sleep(30)

    print("ECS successfully scaled up to 1 \n")


def turn_on_lambda_trigger(lambda_function_name: str):
    """Turns on the event source mapping that invokes the lambda function

    Args:
        lambda_function_name (str): Name of the lambda function who's event source mapping needs turning on
    """
    trigger_status = "Disabled"

    lambda_client = boto3.client("lambda")

    print("Turning on lambda trigger... ")
    print(lambda_function_name)

    uuid = lambda_client.list_event_source_mappings(FunctionName=lambda_function_name,)["EventSourceMappings"][
        0
    ]["UUID"]
    response = lambda_client.update_event_source_mapping(
        Enabled=True,
        UUID=uuid,
    )

    print("Status Code: ", response["ResponseMetadata"]["HTTPStatusCode"])

    while trigger_status != "Enabled":
        trigger_status = lambda_client.get_event_source_mapping(
            UUID=uuid,
        )["State"]
        print("Trigger Status: ", trigger_status)

    print("Lambda Trigger successfully enabled... \n")


def wait_for_rds_scale_up(cluster_name: str):
    rds = boto3.client("rds")

    cluster_capacity = 0

    print("Checking RDS Capacity...")
    time_elapsed = 0
    # check database has stopped
    while cluster_capacity == 0:

        print(cluster_name)
        response = rds.describe_db_clusters(DBClusterIdentifier=cluster_name)

        cluster_capacity = response["DBClusters"][0]["Capacity"]

        print("Cluster capacity at: ", cluster_capacity)

        if not cluster_capacity:
            print("Waiting 30 seconds before checking again... ")
            time.sleep(30)
            time_elapsed = time_elapsed + 30
            print("Total time waiting: ", time_elapsed)

    print("RDS Scaled up successfully... \n")


def get_timestamp_from_s3() -> int:
    """Gets the timestamp from S3 in the RDS State bucket

    Returns:
        int: Timestamp in epoch
    """
    s3_resource = boto3.resource("s3")

    print("\n Getting timestamp from S3 RDS State... ")
    content_obj = s3_resource.Object("smarterise-rds-state", "state.json")
    file_content = content_obj.get()["Body"].read().decode("utf-8")
    json_content = json.loads(file_content)

    timestamp = json_content["min"]["0"]

    # epoch is in ms so dividing by 1000
    timestamp = int(timestamp / 1000)

    print("Timestamp successfully retrieved... \n ")

    return timestamp


def query_athena_for_records(last_rds_timestamp: int, now: int) -> pd.DataFrame:
    """Queries Athena for records between last_rds_timestamp and now

    Args:
        last_rds_timestamp (int): the timestamp from the state file in s3 in epoch
        now (int): the timestamp now in epoch

    Returns:
        pd.DataFrame: DataFrame containing records between last_rds_timestamp and now
    """

    utc_rds = datetime.datetime.utcfromtimestamp(last_rds_timestamp)
    utc_now = datetime.datetime.utcfromtimestamp(now)
    print(
        f"Querying Athena for data between {utc_rds.strftime('%Y-%m-%d %H:%M:%S')} and {utc_now.strftime('%Y-%m-%d %H:%M:%S')}"
    )

    sql = f"""SELECT
    *
    FROM smart_device_readings
    WHERE to_unixtime(timestamp) >= {last_rds_timestamp}
    AND to_unixtime(timestamp) <= {now}
    """

    data = wr.athena.read_sql_query(sql, database="datalake_raw", workgroup="datalake_raw_workgroup")

    print("Records retrieved: ", data.shape[0])
    return data


def save_records_to_s3(data: pd.DataFrame, now: int):
    """Saves records to S3 in the RDS State container under a subdirectory called data_for_rehydration

    Args:
        data (pd.DataFrame): data with records between now and last timestamp
        now (int): time now in epoch
    """
    print("Saving records to s3... ")
    csv_buffer = io.StringIO()
    data.to_csv(csv_buffer)

    now_utc = datetime.datetime.utcfromtimestamp(now)
    date = now_utc.strftime("%Y%m%d")
    time = now_utc.strftime("%H%M%S")

    path = os.path.join("data_for_rehydration", date, time)
    s3_resource = boto3.resource("s3")
    s3_resource.Object("smarterise-rds-state", path).put(Body=csv_buffer.getvalue())

    print(f"Data successfully uploaded to S3: smarterise-rds-state/{path} \n")


def create_aurora_engine(cluster_name: str) -> sqlalchemy.engine:
    """Creates SQLAlchemy engine for Aurora Data API

    Returns:
        sqlalchemy.engine: SQLAlchemy engine
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


def create_col_if_not_exists(record_df: pd.DataFrame, cols: list[str]) -> pd.DataFrame:
    """Checks if a column exists in the dataframe and if it doesn't, creates it with None values

    Args:
        record_df (pd.DataFrame): DataFrame with Records
        cols (list[str]): Columns to check existence

    Returns:
        pd.DataFrame: DataFrame with columns created (with None values)
    """

    cols_not_in_df = [col for col in cols if col not in record_df.columns]
    record_df[cols_not_in_df] = None

    return record_df


def split_dataframe(df, chunk_size=10000):
    print("Splitting data into chunks of size: ", chunk_size)
    chunks = list()
    num_chunks = len(df) // chunk_size + 1
    for i in range(num_chunks):
        chunks.append(df[i * chunk_size : (i + 1) * chunk_size])
    return chunks


def run():
    boto3.setup_default_session(
        region_name="eu-west-2",
        aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID"),
        aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY"),
    )

    lambda_function_name = "smart-device-to-rds"
    # lambda_function_name = "invoke-ml-model"
    # cluster_name = "dev-smarterise-cluster"
    cluster_name = "rds-postgresql-cluster"

    last_rds_stamp = get_timestamp_from_s3()

    turn_on_lambda_trigger(lambda_function_name)
    scale_up_ecs()
    # wait for RDS to scale up
    wait_for_rds_scale_up(cluster_name)

    # waiting for 3 minutes, 60 seconds for iot to hit kinesis, 60 seconds for kinesis to hit lambda and 60s for lambda to run
    print("Waiting for 3 minutes for records to go through IoT, Kinesis and Lambda")
    time.sleep(180)

    now = int(datetime.datetime.now().timestamp())

    data = query_athena_for_records(last_rds_stamp, now)

    save_records_to_s3(data, now)

    data["timestamp"] = pd.to_datetime(data["timestamp"], unit="ms")
    data["date"] = data["timestamp"].dt.date

    cols_for_rds = config.cols_for_rds

    data = create_col_if_not_exists(data, cols_for_rds)[cols_for_rds]

    for chunk in split_dataframe(data):
        engine = create_aurora_engine(cluster_name)
        print("\n Chunk shape: ", chunk.shape)
        with engine.connect() as conn:

            print("\n Ingesting data... ")

            save_dataframe(
                chunk, "smart_device_readings", con=conn, if_exists="append", index=False, dtype=config.cols_for_rds
            )

        engine.dispose()


if __name__ == "__main__":
    run()
