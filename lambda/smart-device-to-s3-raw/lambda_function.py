import base64
import io
import json
import logging
import os
import pickle
import sys
from datetime import date, datetime

import awswrangler as wr
import boto3
import config
import pandas as pd
from flatten_json import flatten

logger = logging.getLogger()
logger.setLevel(logging.INFO)

RUNTIME = "cloud"  # or 'local'


def set_pandas_display_options() -> None:
    """Set pandas display options."""
    display = pd.options.display

    display.max_columns = 1000
    display.max_rows = 1000
    display.max_colwidth = 199
    display.width = 1000


def handle_failed_records(records):
    s3_client = boto3.client("s3", region_name="eu-west-2")

    try:
        for record in records:
            try:
                payload = deserialize_record(record)
                last_data = pd.DataFrame([payload], index=None)
                fallback_write_to_s3(last_data, athena_table="", s3_bucket="fallback")

            except Exception as e:
                s3_client.upload_fileobj(
                    pickle.dumps(record["kinesis"]["data"]), "fallback", record["SequenceNumber"] + "_kinesis.dump"
                )
                logger.error(e)

    except Exception as e:
        logger.critical("Dataloss:" + str(records))
        logger.error(e)


def fallback_write_to_s3(tempdf: pd.DataFrame, athena_table: str, s3_bucket: str) -> None:
    """
    Fallback Boto3 writing to S3.
    :param tempdf: Pandas DF to write to S3
    :type tempdf: pd.DataFrame
    :param athena_table: Table to write to (it will be suffixed with _fallback)
    :type athena_table: str
    :param s3_bucket: The S3 Bucket to write to
    :type s3_bucket: str
    """

    dt = datetime.utcnow()
    date = dt.strftime("%Y%m%d")
    time = dt.strftime("%H%M%S")

    csv_buffer = io.StringIO()
    tempdf.to_csv(csv_buffer)
    s3_resource = boto3.resource("s3")

    fallback_path = f"{athena_table}_fallback/{date}/{time}.csv"
    logger.info(f"Error occurred so uploading to S3 location: {fallback_path} as CSV...")

    s3_resource.Object(s3_bucket, fallback_path).put(
        Body=csv_buffer.getvalue(), SSEKMSKeyId=os.environ["S3_RAW_BUCKET_KMS_KEY_ARN"], ServerSideEncryption="AES256"
    )


def write_to_s3(
    output_df: pd.DataFrame,
    athena_table: str,
    database_name: str,
    partition_cols: list,
    schema: dict,
    col_comments: dict,
    s3_bucket: str = None,
) -> dict:
    """
    Writes the DataFrame to S3 and Athena using AWS Wrangler
    :param output_df: The Dataframe to write out to S3
    :type output_df: pd.DataFrame
    :param athena_table: The table in Athena to write to
    :type athena_table: str
    :param database_name: The database in Athena to write to
    :type database_name: str
    :param partition_cols: Partition columns
    :type partition_cols: list
    :param schema: The schema for the table
    :type schema: dict
    :param col_comments: The comments for the columns
    :type col_comments: dict
    :param s3_bucket: The name of the bucket in S3, defaults to None
    :type s3_bucket: str, optional
    :return: The response
    :rtype: dict
    """
    logger.info("Uploading to AWS using Wrangler:")

    if s3_bucket is None:
        s3_bucket = os.environ["S3_RAW_BUCKET_NAME"]

    logger.info(f"\tUploading to S3 bucket: {s3_bucket}")
    logger.info(f"\tPandas DataFrame Shape: {output_df.shape}")
    path = f"s3://{s3_bucket}/{athena_table}/"
    logger.info("\tUploading to S3 location:  %s", path)

    try:
        res = wr.s3.to_parquet(
            df=output_df,
            path=path,
            index=False,
            dataset=True,
            database=database_name,
            table=athena_table,
            mode="append",
            schema_evolution="true",
            compression="snappy",
            partition_cols=partition_cols,
            dtype=schema,
            columns_comments=col_comments,
            s3_additional_kwargs={
                "ServerSideEncryption": "AES256",
            },
        )

        return res

    except Exception as e:
        logger.error("Failed uploading to S3 location:  %s", path)
        logger.error("Exception occurred:  %s", e)

        try:
            logger.info("Writing to fallback...COMMENTED OUT")
            fallback_write_to_s3(output_df, athena_table, s3_bucket)
        except Exception as e2:
            logger.error(f"Failed fallback with Exception: {e2}")

        raise e


def cast_datatypes(filtered_df: pd.DataFrame, schema: dict, units: dict) -> pd.DataFrame:
    """Convert datatypes in the dataframe based on schema and units."""
    logger.info("Casting datatypes in frame.")

    try:
        for col, dtype in schema.items():
            if col in units.keys():
                unit = units[col]

                # Log incoming timestamp value
                logger.info(f"Processing column: {col}, Unit: {unit}, Current value: {filtered_df[col]}")

                if dtype == "timestamp":
                    try:
                        # Ensure the column contains valid numeric values
                        if pd.api.types.is_numeric_dtype(filtered_df[col]):
                            max_value = filtered_df[col].max()
                            if max_value > 1e12:  # If the largest value is greater than 10^12, it's in milliseconds
                                unit = "ms"
                            else:
                                unit = "s"

                        filtered_df[col] = pd.to_datetime(filtered_df[col], unit=unit, origin='unix', errors='coerce')
                        logger.info(f"Converted timestamp ({unit}): {filtered_df[col]}")
                    
                    except Exception as e:
                        logger.error(f"Error occurred while converting {col}: {e}")
                        filtered_df[col] = pd.NaT  # Handle the error by setting it to NaT
                    
    except Exception as e:
        logger.error(f"Exception occurred casting datatypes: {e}")
        return e

    logger.info(f"After casting, final timestamp values: {filtered_df['timestamp']}")
    return filtered_df

def find_format_and_table(record: pd.DataFrame, _config=config.config) -> tuple[str, str]:
    """
    Validates an incoming record against the configuration to determine its format and target table.
    """
    import logging
    logger = logging.getLogger(__name__)
    
    logger.info("Finding if record matches any formats:")
    logger.info(f"Validating record with device model: {record.get('device_model')}")
    logger.debug(f"Incoming record: {record}")  # Be careful with sensitive data

    # Iterate through tables and their format types in the config
    for table, properties in _config.items():
        for _format, details in properties.get("format_types", {}).items():
            unique_features = details.get("unique_features", {})
            format_ok = True

            # Validate the number of columns
            if "num_columns" in unique_features:
                num_columns = len(record.keys())
                expected_columns = unique_features["num_columns"]
                logger.info(f"Validating column count: Found {num_columns}, Expected {expected_columns}")
                if num_columns != expected_columns:
                    format_ok = False
                    logger.warning(f"Column count mismatch for format {_format}: Expected {expected_columns}, Found {num_columns}")

            # Validate required columns
            if "has_columns" in unique_features:
                required_columns = unique_features["has_columns"]
                missing_columns = [col for col in required_columns if col not in record.keys()]
                if missing_columns:
                    format_ok = False
                    logger.warning(f"Missing required columns for format {_format}: {missing_columns}")

            if format_ok:
                logger.info(f"Format {_format} detected for table {table}.")
                return _format, table

    raise AttributeError(f"This record doesn't match any formats in the config: {record}")

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
    flat_json = flatten(payload)

    # Remove '_0' from the keys
    cleaned_flat_json = {key.replace('_0', ''): value for key, value in flat_json.items()}

    # Add these debug lines
    logger.info(f"Number of columns: {len(cleaned_flat_json.keys())}")
    logger.info(f"Device model: {cleaned_flat_json.get('device_model')}")

    return cleaned_flat_json



def map_to_schema(record: dict, table: str, _format: str, _config: dict = config.config) -> dict:
    """Given a record, determine which config section to use to parse/decode it."""
    logger.info("Mapping record to schema.")

    final_record = {}
    map = _config[table]["format_types"][_format]["map"]
    schema = _config[table]["table_schema"]
    logger.info(f"Using map: {map}")
    logger.info(f"Using schema: {schema}")

    for key, value in record.items():
        if key in map.keys():
            target_column = map[key]["target_column"] # Debug log
            if target_column in schema.keys():
                final_record[target_column] = value
            else:
                raise Exception(target_column, "not in schema: ", schema.keys())
        else:
            pass  # Not in keys

    return final_record


def set_defaults(record: dict, defaults: dict) -> dict:
    """
    Go through a record and if it is missing a column defined in default's keys - add the key: value from default.
    """
    logger.info("Setting default values.")
    for col, default in defaults.items():
        if col not in record.keys():
            logger.info("Default: " + str(default) + " was set for " + str("col"))
            record[col] = default

    return record


def reorder_columns(df: pd.DataFrame, first_columns: list[str]) -> pd.DataFrame:
    """
    Reorder dataframe. Specified 'first_columns' are indexed first,
    then remaining columns are added in their existing order.
    """
    existing_order = df.columns
    left_overs = [column for column in existing_order if column not in first_columns]
    first_columns.extend(left_overs)
    df = df.reindex(columns=first_columns)

    return df

import boto3
import os
import logging

# Assuming logging has been configured
logger = logging.getLogger(__name__)


def put_record_in_parsed_kinesis_stream(record_df, stream_name=None) -> dict:
    """
    Puts record in kinesis stream for parsed records
    """
    client = boto3.client("kinesis", region_name="eu-west-2")
    
    if not stream_name:
        stream_name = os.environ.get("PARSED_DEVICE_KINESIS_DATA_STREAM_NAME")
    
    # Log the data before sending
    logger.info(f"Attempting to send data to Kinesis: {record_df}")
    
    # Ensure the DataFrame has the necessary values and isn't empty
    if record_df.empty:
        logger.error(f"The DataFrame is empty, no data to send. DataFrame details: {record_df}")
        return {"error": "Empty DataFrame"}

    try:
        # Convert DataFrame to JSON
        data_to_send = record_df.to_json()

        # Log the final data that will go to Kinesis
        logger.info(f"Sending the following data to Kinesis: {data_to_send}")

        # Put the record in Kinesis
        res = client.put_record(
            StreamName=stream_name,
            Data=data_to_send,
            PartitionKey=record_df["gateway_serial"].values[0],
        )

        # Log the response from Kinesis
        logger.info(f"Kinesis response: {res}")

    except Exception as e:
        logger.error(f"Exception occurred while sending data to Kinesis: {e}")
        return {"error": str(e)}

    return res

def lambda_handler(event, context, _config: dict = config.config) -> None:
    """
    Accepts a Kinesis Data Stream Event
    :param event: The event dict that contains the parameters sent when the function is invoked.
    :param context: The context in which the function is called.
    :param _config: The nested configuration dictionary.
    :return: The result of the specified action.
    """

    set_pandas_display_options()

    logger.info("Runtime:" + str(RUNTIME))
    logger.info("Started processing event...")

    successful_records = []
    failed_records = []
    for record in event["Records"]:
        try:
            payload = deserialize_record(record)
            _format, table = find_format_and_table(payload)

            schema = {k: v["type"] for (k, v) in _config[table]["table_schema"].items()}
            col_comments = {k: v["comment"] for (k, v) in _config[table]["table_schema"].items()}
            partition_cols = _config[table]["partition_cols"]
            col_units = {
                v["target_column"]: v["unit"]
                for (k, v) in _config[table]["format_types"][_format]["map"].items()
                if "unit" in v.keys()
            }
            col_defaults = {
                v["target_column"]: v["default"]
                for (k, v) in _config[table]["format_types"][_format]["map"].items()
                if "default" in v.keys()
            }

            schema_dict = map_to_schema(payload, table, _format)
            final_dict = set_defaults(schema_dict, col_defaults)
            record_df = pd.DataFrame([final_dict], index=None)
            record_df = cast_datatypes(record_df, schema=schema, units=col_units)

            logger.info("Putting Record in Kinesis... ")
            put_record_in_parsed_kinesis_stream(record_df)

            successful_records.append(record_df)
            logger.info("Record successfully handled.")

        except Exception as e:
            failed_records.append(record)
            logger.error(e)

    # write to s3 table
    successful_records_df = pd.concat(successful_records)
    successful_records_df["date_extracted"] = date.today().strftime("%Y%m%d")
    successful_records_df["timestamp_extracted"] = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    successful_records_df["date"] = successful_records_df["timestamp"].dt.date

    successful_records_df = reorder_columns(successful_records_df, ["timestamp_extracted", "date_extracted", "date"])

    write_output = write_to_s3(
        output_df=successful_records_df,
        athena_table=table,
        database_name=os.environ["DATABASE_RAW"],
        partition_cols=partition_cols,
        schema=schema,
        col_comments=col_comments,
    )

    logger.info(f"Writing Result: {write_output}")
    if len(failed_records) > 0:
        logger.error("Failed Records Could Not Be Written " + str(failed_records))
        handle_failed_records(records=failed_records)
    logger.info("Exiting function...\n")


if __name__ == "__main__":
    RUNTIME = "local"
    logging.basicConfig(stream=sys.stdout, level=logging.INFO)
    set_pandas_display_options()

    boto3.setup_default_session(profile_name="smarterise", region_name="eu-west-2")

    client = boto3.client("kinesis", region_name="eu-west-2")

    shard_iterator = client.get_shard_iterator(
        StreamName="device-data-stream",
        ShardId="shardId-000000000000",
        ShardIteratorType="AT_TIMESTAMP",
    )["ShardIterator"]

    num_errors = 0
    while True:
        try:
            result = client.get_records(ShardIterator=shard_iterator)
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
                    StreamName="device-data-stream",
                    ShardId="shardId-000000000000",
                    ShardIteratorType="AT_TIMESTAMP",
                )["ShardIterator"]
            else:
                raise e
