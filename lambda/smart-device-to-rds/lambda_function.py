import base64
import json
import logging
import os
import random
import string
import sys
import psycopg2
import boto3
import config
import pandas as pd
import pytz
import sqlalchemy
from config import cols_for_rds 

logger = logging.getLogger()
logger.setLevel(logging.INFO)

RUNTIME = "cloud"  # or 'local'

# RDS connection details from environment variables
rds_host = os.environ.get("DB_HOST")
rds_database = os.environ.get("DB_NAME", "smartmeters")
rds_username = os.environ.get("DB_USER")
rds_password = os.environ.get("DB_PASSWORD")
rds_port = os.environ.get("DB_PORT", "5432")
rds_table = "smart_device_readings"  # Update this if necessary


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

def insert_into_rds(df: pd.DataFrame) -> None:
    """Insert DataFrame into RDS."""
    #logger.info(f"Original columns in DataFrame: {df.columns.tolist()}")

    
    if 'timestamp' in df.columns:
        df['timestamp'] = pd.to_datetime(df['timestamp'], errors='coerce')
        # Check if timestamp is timezone-aware
        if df['timestamp'].dt.tz is None:
            # If naive, first localize to UTC then convert to Lagos
            lagos_tz = pytz.timezone("Africa/Lagos")
            df["timestamp"] = df["timestamp"].dt.tz_localize("UTC").dt.tz_convert(lagos_tz)
        elif df['timestamp'].dt.tz.zone != 'Africa/Lagos':
            # If already timezone-aware but not in Lagos time, convert to Lagos
            lagos_tz = pytz.timezone("Africa/Lagos")
            df["timestamp"] = df["timestamp"].dt.tz_convert(lagos_tz)
        # Add 1 hour to fix the time difference
        df["timestamp"] = df["timestamp"] + pd.Timedelta(hours=1)
        # Now extract month and year from Lagos time
        df['month'] = df['timestamp'].dt.month
        df['year'] = df['timestamp'].dt.year
    else:
        logger.error("Missing 'timestamp' column in DataFrame!")
        df['month'] = None
        df['year'] = None

    required_columns = list(cols_for_rds.keys())
    for col in required_columns:
        if col not in df.columns:
            logger.warning(f"Missing column: {col}, creating with default value.")
            df[col] = None  

    missing_cols = set(required_columns) - set(df.columns)
    if missing_cols:
        logger.error(f"Missing required columns before selection: {missing_cols}")
        raise KeyError(f"Missing columns: {missing_cols}")

    df = df[required_columns]
    #logger.info(f"FINAL DATA TO INSERT - Sample (first 3 rows):")
    #logger.info(df.head(3).to_dict('records'))

    logger.info(f"Preparing to insert {df.shape[0]} records into {rds_table}")
    try:
        connection = psycopg2.connect(
            host=rds_host,
            user=rds_username,
            password=rds_password,
            database=rds_database,
            port=rds_port
        )
        logger.info("SUCCESS: Connection to RDS Postgres instance succeeded")
    except psycopg2.Error as e:
        logger.error("ERROR: Could not connect to Postgres instance.")
        logger.error(e)
        return
    try:
        with connection.cursor() as cursor:
            columns = ', '.join([f'"{col}"' for col in df.columns])
            values_placeholder = ', '.join(['%s'] * len(df.columns))

            sql = f"""
                    INSERT INTO {rds_table} ({columns})
                    VALUES ({values_placeholder})
                    ON CONFLICT ("timestamp", "gateway_serial") 
                    DO UPDATE SET column_name = EXCLUDED.column_name
                    """
            for _, row in df.iterrows():
                cursor.execute(sql, tuple(row))

            connection.commit()
            logger.info(f"{df.shape[0]} records inserted successfully")

    except psycopg2.Error as e:
        logger.error("ERROR: Failed to insert data into PostgreSQL table.")
        logger.error(e)
    finally:
        if connection:
            connection.close()
            logger.info("PostgreSQL connection is closed")        

            
def lambda_handler(event, context) -> None:
    successful_records = []
    failed_records = []

    for record in event["Records"]:
        event_id = record["eventID"]
        logger.info(f"Processing event ID: {event_id}")
        try:
            payload = deserialize_record(record)
            record_df = pd.DataFrame.from_dict(payload)
            
            # Convert timestamp and create date column
            record_df["timestamp"] = pd.to_datetime(record_df["timestamp"], unit="ms")
            wat_tz = pytz.timezone('Africa/Lagos')  # WAT timezone
            record_df["timestamp"] = record_df["timestamp"].dt.tz_localize("UTC").dt.tz_convert(wat_tz)
            #print("converted")
            #print(record_df["timestamp"])
            record_df["date"] = record_df["timestamp"].dt.date

            #logger.info(f"PROCESSED DATA  timestamps:")
            #logger.info(record_df["timestamp"].head(2).to_list())
            successful_records.append(record_df)
            logger.info("Record successfully handled.")

        except Exception as e:
            failed_records.append(record)
            logger.error(e)

    if successful_records:
        successful_records_df = pd.concat(successful_records)
        
        # Log the shape and columns of the DataFrame
        #logger.info(f"DataFrame shape before processing: {successful_records_df.shape}")
        #logger.info(f"Columns before processing: {successful_records_df.columns.tolist()}")
        
        try:
            insert_into_rds(successful_records_df)
        except Exception as e:
            logger.error(f"Error inserting into RDS: {str(e)}")
            raise e

    logger.info("Lambda execution completed.")


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

