import os
import random
import string

import awswrangler as wr
import boto3
import config
import pandas as pd
import sqlalchemy
from lambda_function import create_col_if_not_exists


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


def split_dataframe(df, chunk_size=1000):
    print("Splitting data into chunks of size: ", chunk_size)
    chunks = list()
    num_chunks = len(df) // chunk_size + 1
    for i in range(num_chunks):
        chunks.append(df[i * chunk_size : (i + 1) * chunk_size])
    return chunks


def save_dataframe(df: pd.DataFrame, table: str, con: sqlalchemy.engine.Connection, **kwargs):
    """
    Save dataframe to the database.
    Index is saved if it has name. If it's None it will not be saved.
    It implements INSERT ON CONFLICT (hash_id) DO NOTHING when inserting rows into the Postgres table.
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
        insert_query = (
            f'INSERT INTO {table}({columns}) SELECT {columns} FROM "{temp_table}" ON CONFLICT ("hash_id") DO NOTHING'
        )
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


def query_athena_for_records(sql: None):

    # sql = f"""
    # SELECT
    # *
    # FROM smart_device_readings
    # WHERE date = date'{date}'

    # """

    data = wr.athena.read_sql_query(sql, database="datalake_raw", workgroup="datalake_raw_workgroup")

    print("Records retrieved: ", data.shape[0])
    return data


def run():
    boto3.setup_default_session(
        region_name="eu-west-2",
        aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID"),
        aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY"),
    )
    cluster_name = "rds-postgresql-cluster"

    data = query_athena_for_records()

    data["timestamp"] = pd.to_datetime(data["timestamp"], unit="ms")
    data["date"] = data["timestamp"].dt.date

    data[config.cols_for_rds]
    data = create_col_if_not_exists(data, config.cols_for_rds)[config.cols_for_rds]

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
