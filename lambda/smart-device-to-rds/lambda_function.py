import base64
import json
import logging
import os
import random
import string
import sys

import boto3
import config
import pandas as pd
import sqlalchemy
from flatten_json import flatten

logger = logging.getLogger()
logger.setLevel(logging.INFO)

RUNTIME = "cloud"  # or 'local'


def save_dataframe(df: pd.DataFrame, table: str, con: sqlalchemy.engine.Connection, **kwargs):
    """
    Save dataframe to the database.
    Index is saved if it has name. If it's None it will not be saved.
    It implements INSERT ON CONFLICT (timestamp, gateway_serial) DO NOTHING when inserting rows into the Postgres table.
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
        logger.info(f"Writing to temp table..., {temp_table}")
        res = df.to_sql(temp_table, con=con, **kwargs)
        logger.info(f"Response:  {res}")

        columns = _table_column_names(table=temp_table, con=con)
        insert_query = f'INSERT INTO {table}({columns}) SELECT {columns} FROM "{temp_table}" ON CONFLICT ("timestamp", "gateway_serial") DO NOTHING'
        logger.info(f"\n Inserting data from {temp_table} to {table}")
        result = con.execute(insert_query)
        logger.info(f"Result of insert query:  {result.rowcount}")

    except Exception as e:
        logger.error(f"An exception occurred: {repr(e)}")

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


def set_pandas_display_options() -> None:
    """Set pandas display options."""
    display = pd.options.display

    display.max_columns = 1000
    display.max_rows = 1000
    display.max_colwidth = 199
    display.width = 1000


def deserialize_record(record) -> dict:
    """Payload of the stream to returned flat json"""
    logger.info("Deserializing payload.")

    if RUNTIME == "cloud":
        logger.info("Base 64 decoding data...")
        try:
            payload = base64.b64decode(record["kinesis"]["data"])
            payload = payload.decode("UTF-8")
        except Exception as e:
            logger.error("Record:  %s", record)
            logger.error("Exception occurred:  %s", e)
            return e
    elif RUNTIME == "local":
        payload = record["Data"]

    payload = json.loads(payload)

    return payload


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


def create_aurora_engine() -> sqlalchemy.engine:
    """Creates SQLAlchemy engine for RDS Postgres Data API

    Returns:
        sqlalchemy.engine.Engine: SQLAlchemy engine
    """
    db_host = os.environ.get("DB_HOST")  # RDS Endpoint (e.g., 'your-db-instance.rds.amazonaws.com')
    db_name = os.environ.get("DB_NAME", "smartmeters")  # Default database name
    db_user = os.environ.get("DB_USER")  # Username
    db_password = os.environ.get("DB_PASSWORD")  # Password
    db_port = os.environ.get("DB_PORT", "5432")  # Default PostgreSQL port

    engine = sqlalchemy.create_engine(
        f"postgresql+psycopg2://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}",
        echo=True
    )
    return engine


def lambda_handler(event, context) -> None:
    logger.info("Runtime:" + str(RUNTIME))
    logger.info("Started processing event...")

    successful_records = []
    failed_records = []
    for record in event["Records"]:
        try:
            payload = deserialize_record(record)

            record_df = pd.DataFrame.from_dict(payload)
            successful_records.append(record_df)
            logger.info("Record successfully handled.")

        except Exception as e:
            failed_records.append(record)
            logger.error(e)

    successful_records_df = pd.concat(successful_records)
    successful_records_df["timestamp"] = pd.to_datetime(successful_records_df["timestamp"], unit="ms")
    successful_records_df["date"] = successful_records_df["timestamp"].dt.date

    successful_records_copy = successful_records_df.copy()

    cols_for_rds = config.cols_for_rds

    successful_records = create_col_if_not_exists(successful_records_copy, cols_for_rds)[cols_for_rds]

    engine = create_aurora_engine()

    logger.info(f"shape: {successful_records.shape}")

    with engine.connect() as conn:

        logger.info("Ingesting data... ")

        save_dataframe(
            successful_records,
            table="smart_device_readings",
            con=conn,
            if_exists="append",
            index=False,
            dtype=cols_for_rds,
        )

    engine.dispose()


if __name__ == "__main__":

    RUNTIME = "local"
    logging.basicConfig(stream=sys.stdout, level=logging.INFO)
    set_pandas_display_options()

    boto3.setup_default_session(profile_name="smarterise", region_name="eu-west-2")

    client = boto3.client("kinesis", region_name="eu-west-2")

    shard_iterator = client.get_shard_iterator(
        StreamName="parsed-device-data-stream",
        ShardId="shardId-000000000000",
        ShardIteratorType="TRIM_HORIZON",
    )["ShardIterator"]

    num_errors = 0
    while True:
        try:
            result = client.get_records(ShardIterator=shard_iterator)
            print("Number of records:", len(result["Records"]))
            if len(result["Records"]) > 0:
                try:
                    lambda_handler(event=result, context=None)

                except SystemExit as e:
                    with open(str(num_errors) + str(".err"), "w") as out_fs:
                        out_fs.write("Error:" + str(e.with_traceback(None)) + "\n")
                        out_fs.write(str(result))
                    num_errors += 1

        except Exception as e:
            logger.info(f"Failed to parse record.")
            if "ExpiredIteratorException" in str(e):
                shard_iterator = client.get_shard_iterator(
                    StreamName="parsed-device-data-stream",
                    ShardId="shardId-000000000000",
                    ShardIteratorType="TRIM_HORIZON",
                )["ShardIterator"]
            else:
                raise e
