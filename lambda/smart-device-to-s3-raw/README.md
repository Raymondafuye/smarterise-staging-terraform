# Kinesis Streamer Developer Docs

## Setup (Local)
AWS
- Download and install the CLI.
- Configure a profile with the --profile arg.

Python
- Pip install missing libraries (boto3, wrangler, flatten_json, etc.).

Set Environment Variables
- AWS_PROFILE="[Name of the profile config'd in AWS CLI]"
- DATABASE_RAW="[DB Name]"
- S3_RAW_BUCKET_NAME="[S3 Bucket Name]"

## Running tests
Pass for now

## A quick walk around
All functional code is packed into the lambda_function.py library.

The configuration for the program is packed away in config.py

## The Config

Take a moment to look at the config down below.

```
config = {
    "smart_device_readings": {
        "partition_cols": ["date_extracted"],
        "table_schema": {...},
        "format_types": {
            "acuvim-ii": {
                "unique_features": {"num_columns": 209, 
                                    "has_columns": ["gateway_name", "device_name"]},
                "map": {...},
            },
            "acurev": {
                "unique_features": {"num_columns": 1446, 
                                    "has_columns": ["deviceId", "metrics_1_value"]},
                "map": {...}
            }
        }
    },
}
```

Config - the dictionary - has key value pairs of TABLE_NAME : TABLE_PROPERTIES type mapping, 
where TABLE_NAME is the string name of a target database table and TABLE_PROPERTIES contains 
information about the table such as corresponding formats, it's schema and some partitioning 
information.

TABLE PROPERTIES (Described above) contains:
    - partition columns to be supplied to wrangler and used in S3.
    - table schema, a dict of COLUMN_NAME : PROPERTIES type mapping.
    - format types, a dict of FORMAT : FORMAT_PROPERTIES.

FORMAT_PROPERTIES (Described above) contains:
    - unique features, dictionary to describe how this format can be identified by it's metadata.
    - map, a dictionary of RECORD_COLUMN : RECORD_PROPERTIES.

The RECORD_PROPERTIES (Described above) are dictionaries which contain: 
    - "target_column": SCHEMA_COLUMN
    - "default" : Some default value to set if it's not in the supplied record (Optional)
    - "unit" : A unit to use when casting datatypes (Optional, just timestamp formats for now)

### Adding a new data format to a table
It's likely more formats will need be added to tables.

1. Add the name of the format as a key : {} pair under config[table]["format_types"]
2. Add the "unique_features": dict pair under config[table]["format_types"][format] and specify at least one of the following:
   - "num_columns": The number of keys in a flattened record (Int).
   - "has_columns": ["Key (string) In record.keys()", "Key (String) In Record.keys()"]}
3. Add the "map": dict pair under config[table]["format_types"][format]
   - Fill in the key value pairs with at least {"record.key": {"target_column"="schema.column_name"}
