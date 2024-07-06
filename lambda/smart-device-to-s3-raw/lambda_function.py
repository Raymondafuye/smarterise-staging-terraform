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
    """Do some conversions on datatypes if needed."""
    logger.info("Casting datatypes in frame.")

    try:
        for col, type in schema.items():
            if col in units.keys():
                unit = units[col]

                if type == "timestamp":
                    if unit in ["D", "s", "ms", "us", "ns"]:
                        filtered_df[col] = pd.to_datetime(filtered_df[col], unit=unit, origin="unix")
                    elif unit == "ISO_OFFSET_DATE_TIME":
                        filtered_df[col] = pd.to_datetime(filtered_df[col], infer_datetime_format=True)
                    else:
                        raise LookupError("Unit: " + unit + " not recognised for " + str(col) + ".")
    except Exception as e:
        logger.error(f"\tException occurred casting datatypes: {e}")

        return e

    return filtered_df


def find_format_and_table(record: pd.DataFrame, _config=config.config) -> tuple[str, str]:
    """Look in config for matching format and it's target table."""

    logger.info("Finding if record matches any formats:")
    for table, properties in _config.items():
        for _format, details in properties["format_types"].items():

            unique_features = details["unique_features"]

            format_ok = True
            if "num_columns" in unique_features.keys():
                if len(record.keys()) != unique_features["num_columns"]:
                    format_ok = False
            if "has_columns" in unique_features.keys():
                for column in unique_features["has_columns"]:
                    if column not in record.keys():
                        format_ok = False

            if format_ok:
                logger.info("\tFormat: " + _format + " detected for table " + table + ".")
                return _format, table

    raise AttributeError("\tThis record doesn't match any formats in the config:" + str(record))


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

    return flat_json


def map_to_schema(record: dict, table: str, _format: str, _config: dict = config.config) -> dict:
    """Given a record, determine which config section to use to parse/decode it."""
    logger.info("Mapping record to schema.")

    final_record = {}
    map = _config[table]["format_types"][_format]["map"]
    schema = _config[table]["table_schema"]

    for key, value in record.items():
        if key in map.keys():
            target_column = map[key]["target_column"]
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


def put_record_in_parsed_kinesis_stream(record_df, stream_name=None) -> dict:
    """
    Puts record in kinesis stream for parsed records
    """
    client = boto3.client("kinesis", region_name="eu-west-2")
    if not stream_name:
        stream_name = os.environ.get("PARSED_DEVICE_KINESIS_DATA_STREAM_NAME")
    try:
        res = client.put_record(
            StreamName=stream_name,
            Data=record_df.to_json(),
            PartitionKey=record_df["gateway_serial"].values[0],
        )
        logger.info(res)
    except Exception as e:
        logger.error(e)


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
        ShardIteratorType="LATEST",
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
                    ShardIteratorType="LATEST",
                )["ShardIterator"]
            else:
                raise e
