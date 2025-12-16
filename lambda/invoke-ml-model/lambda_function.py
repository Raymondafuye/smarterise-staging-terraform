import base64
import json
import logging
import pathlib
import pickle
import sys

import boto3
import pandas as pd

RUNTIME = "cloud"

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def base_path():
    return pathlib.Path(__file__).resolve().parent


def week_number_of_month(date_value):
    return date_value.isocalendar()[1] - date_value.replace(day=1).isocalendar()[1] + 1


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

    logger.info("Base 64 decoding data...")
    if RUNTIME == "cloud":
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


def lambda_handler(event, context) -> None:
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

    logger.info(successful_records)
    df = pd.concat(successful_records)
    ### ML MODEL GOES HERE ##


if __name__ == "__main__":

    RUNTIME = "local"
    logging.basicConfig(stream=sys.stdout, level=logging.INFO)
    set_pandas_display_options()

    boto3.setup_default_session(profile_name="smarterise", region_name="eu-west-2")

    client = boto3.client("kinesis", region_name="eu-west-2")

    shard_iterator = client.get_shard_iterator(
        StreamName="parsed-device-data-stream",
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
                    StreamName="parsed-device-data-stream",
                    ShardId="shardId-000000000000",
                    ShardIteratorType="LATEST",
                )["ShardIterator"]
            else:
                raise e
