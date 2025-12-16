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
from datetime import datetime, timedelta
import math
import pytz
import sqlalchemy
from config import cols_for_rds as COLS_FOR_RDS
from psycopg2.extras import execute_values
from typing import Dict, List, Any, Optional, Tuple

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# RDS connection details from environment variables
rds_host = os.environ.get("DB_HOST")
rds_database = os.environ.get("DB_NAME", "smartmeters")
rds_username = os.environ.get("DB_USER")
rds_password = os.environ.get("DB_PASSWORD")
rds_port = os.environ.get("DB_PORT", "5432")
rds_table = "smart_device_readings"

# Asset mapping
GATEWAY_TO_ASSET = {
    "AN54101354": "C025",
    "AN54101366": "C070",
    "AN54101390": "C098",
    "AN54101382": "C102",
    "AN54101385": "C119",
    "AN54101527": "C132",
    "AN54101367": "C147",
    "AN54101472": "C188",
    "AN54101510": "C229",
    "AN54101409": "C290",
    "AN54101738": "C306",
    "AN54101719": "C304",
    "AN54101528": "C358",
    "AN54101386": "C359",
    "AN54091542": "C362",
    "AN54110827": "C363",
    "AN54110835": "C407",
    "AN54112386": "C615",
    "AN54101471": "ctest"
}

# Transformer capacities (kVA)
ASSETS = {
    "C102": 630,
    "C290": 400,
    "C025": 160,
    "C098": 160,
    "C188": 630,
    "C132": 100,
    "C147": 630,
    "C119": 250,
    "C070": 160,
    "C363": 250,
    "C407": 800,
    "C359": 250,
    "C358": 250,
    "C615": 630,
    "C362": 250,
    "C229": 100,
    "C304": 630,
    "C306": 630,
    "ctest": 630
}

# We've already imported the columns from config above

def safe_float(value, default=0.0):
    """
    Convert value to float safely, returning default if conversion fails.
    
    Args:
        value: Value to convert
        default: Default value to return if conversion fails
        
    Returns:
        Float value or default
    """
    if value is None:
        return default
    try:
        return float(value)
    except (ValueError, TypeError):
        return default

def get_db_connection() -> Optional[psycopg2.extensions.connection]:
    """
    Establish a connection to the PostgreSQL database.
    Returns connection object or None if connection fails.
    """
    try:
        connection = psycopg2.connect(
            host=rds_host,
            user=rds_username,
            password=rds_password,
            database=rds_database,
            port=rds_port,
            connect_timeout=5  # Add timeout to prevent Lambda hanging
        )
        connection.autocommit = False  # For transaction control
        logger.info("Successfully connected to PostgreSQL database")
        return connection
    except psycopg2.Error as e:
        logger.error(f"Failed to connect to PostgreSQL: {e}")
        return None


def deserialize_record(record: dict) -> dict:
    """
    Deserialize a record from the Kinesis stream.
    
    Args:
        record: A record from the Kinesis stream
        
    Returns:
        The deserialized JSON payload
    """
    try:
        # Handle both cloud (base64 encoded) and local runtime
        if os.environ.get("AWS_EXECUTION_ENV", "").startswith("AWS_Lambda"):
            # We're in Lambda
            payload = base64.b64decode(record["kinesis"]["data"])
            payload = payload.decode("UTF-8")
        else:
            # Local testing
            payload = record["Data"]
            
        return json.loads(payload)
    except Exception as e:
        logger.error(f"Error deserializing record: {e}")
        logger.error(f"Record: {record}")
        raise


def calculate_metrics(metrics: Dict[str, Any], transformer_info: Dict[str, Any]) -> Dict[str, Any]:
    """
    Calculate metrics for a single reading.
    
    Args:
        metrics: Raw metrics from the device
        transformer_info: Information about the transformer
        
    Returns:
        Dictionary with calculated metrics
    """
    # Extract required values with absolute values, safely converting to float
    active_power_a = abs(safe_float(metrics.get('active_power_overall_phase_a', 0)))
    active_power_b = abs(safe_float(metrics.get('active_power_overall_phase_b', 0)))
    active_power_c = abs(safe_float(metrics.get('active_power_overall_phase_c', 0)))

    reactive_power_a = abs(safe_float(metrics.get('reactive_power_overall_phase_a', 0)))
    reactive_power_b = abs(safe_float(metrics.get('reactive_power_overall_phase_b', 0)))
    reactive_power_c = abs(safe_float(metrics.get('reactive_power_overall_phase_c', 0)))

    power_factor_a = abs(safe_float(metrics.get('power_factor_overall_phase_a', 0)))
    power_factor_b = abs(safe_float(metrics.get('power_factor_overall_phase_b', 0)))
    power_factor_c = abs(safe_float(metrics.get('power_factor_overall_phase_c', 0)))

    voltage_a = abs(safe_float(metrics.get('line_to_neutral_voltage_phase_a', 0)))
    voltage_b = abs(safe_float(metrics.get('line_to_neutral_voltage_phase_b', 0)))
    voltage_c = abs(safe_float(metrics.get('line_to_neutral_voltage_phase_c', 0)))

    current_a = abs(safe_float(metrics.get('line_current_overall_phase_a', 0)))
    current_b = abs(safe_float(metrics.get('line_current_overall_phase_b', 0)))
    current_c = abs(safe_float(metrics.get('line_current_overall_phase_c', 0)))
    
    # Calculate total active power if not provided
    #current_load = safe_float(metrics.get('active_power_overall_total'))
    #print("current_load", current_load)
    # calculate current load
    current_load = active_power_a + active_power_b + active_power_c
    
    # Calculate total reactive power if not provided
    reactive_power = reactive_power_a + reactive_power_b + reactive_power_c
    
       # reactive_power = abs(reactive_power)

    # Calculate average power factor 
    #power_factor = safe_float(metrics.get('power_factor_overall'))
    #if power_factor == 0 and (power_factor_a + power_factor_b + power_factor_c) > 0:
    power_factor = (power_factor_a + power_factor_b + power_factor_c) / 3

    # Distributed Electricity (kWh) - for 1-minute interval (60 min / hour)
    distributed_electricity = current_load / 60
    
    # Calculate voltage unbalance if not provided

    avg_voltage = (voltage_a + voltage_b + voltage_c) / 3
    max_deviation = max(voltage_a, voltage_b, voltage_c) - avg_voltage
    voltage_unbalance = max_deviation / avg_voltage * 100
    
    # Calculate current unbalance if not provided
    
    avg_current = (current_a + current_b + current_c) / 3
    max_deviation = max(current_a, current_b, current_c) - avg_current
    current_unbalance = (max_deviation / avg_current) * 100

    # Get transformer capacity
    transformer_capacity = safe_float(transformer_info.get('transformer_capacity', 0))

    # Calculate Energy
    energy = current_load * 0.166667
    
    # Calculate transformer load percentage
    loading = ((current_load / power_factor) / transformer_capacity) * 100
    
    # Return only metrics that are needed per-minute
    return {
        'line_to_neutral_voltage_phase_a': voltage_a,
        'line_to_neutral_voltage_phase_b': voltage_b,
        'line_to_neutral_voltage_phase_c': voltage_c,
        'line_current_overall_phase_a': current_a,
        'line_current_overall_phase_b': current_b,
        'line_current_overall_phase_c': current_c,
        'line_current_overall_neutral': safe_float(metrics.get('line_current_overall_neutral', 0)),
        'load': current_load,
        'energy': energy,
        'active_power_overall_phase_a': active_power_a,
        'active_power_overall_phase_b': active_power_b,
        'active_power_overall_phase_c': active_power_c,
        'power_factor_overall_phase_a': power_factor_a,
        'power_factor_overall_phase_b': power_factor_b,
        'power_factor_overall_phase_c': power_factor_c,
        'power_factor_overall': power_factor,
        'reactive_power_overall': reactive_power,
        'reactive_power_overall_phase_a': reactive_power_a,
        'reactive_power_overall_phase_b': reactive_power_b,
        'reactive_power_overall_phase_c': reactive_power_c,
        'apparent_power_overall_total': safe_float(metrics.get('apparent_power_overall_total', 0)),
        'frequency': safe_float(metrics.get('frequency', 0)),
        'voltage_unbalance_factor': voltage_unbalance,
        'current_unbalance_factor': current_unbalance,
        'Distributed_Electricity': distributed_electricity,
        'transformer_capacity': transformer_capacity,
        'transformer_load_percentage': loading
    }


def bulk_insert_to_rds(df: pd.DataFrame, connection: psycopg2.extensions.connection) -> bool:
    """
    Efficiently insert DataFrame records into RDS using execute_values for bulk insert.
    Updates only when existing line_to_neutral_voltage_phase_a is 0 or NULL.
    """
    try:
        with connection.cursor() as cursor:
            # Ensure all required columns exist
            for col in COLS_FOR_RDS:
                if col not in df.columns:
                    df[col] = None
            df = df.drop_duplicates(subset=['timestamp', 'gateway_serial'], keep='last')
            # Construct columns clause
            columns = [f'"{col}"' for col in COLS_FOR_RDS.keys()]
            columns_str = ', '.join(columns)
            
            # Create values template
            values_template = '(' + ', '.join(['%s'] * len(columns)) + ')'
            
            sql = f"""
                INSERT INTO {rds_table} ({columns_str})
                VALUES %s
                ON CONFLICT ("timestamp") 
                DO UPDATE SET 
            """
            
            # Add update conditions for all columns except timestamp
            update_columns = [
                f'"{col}" = CASE '
                f'WHEN ({rds_table}.line_to_neutral_voltage_phase_a IS NULL '
                f'OR {rds_table}.line_to_neutral_voltage_phase_a = 0) '
                f'THEN EXCLUDED."{col}" '
                f'ELSE {rds_table}."{col}" END'
                for col in COLS_FOR_RDS.keys() 
                if col != 'timestamp'
            ]
            
            sql += ', '.join(update_columns)
            
            # Create tuples of values
            values = []
            for _, row in df.iterrows():
                values.append(tuple(row[col] if col in row else None 
                                  for col in COLS_FOR_RDS.keys()))
            
            # Execute bulk insert
            execute_values(cursor, sql, values, template=None, page_size=100)
            connection.commit()
            
            logger.info(f"Successfully processed {len(values)} records into {rds_table}")
            return True
            
    except psycopg2.Error as e:
        logger.error(f"Error inserting data into RDS: {e}")
        connection.rollback()
        return False
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        connection.rollback()
        return False

def process_records(event: dict) -> Tuple[pd.DataFrame, List[dict]]:
    """
    Process records from Kinesis event.
    
    Args:
        event: Kinesis event with records
        
    Returns:
        Tuple of (processed_df, failed_records)
    """
    processed_records = []
    failed_records = []
    
    lagos_tz = pytz.timezone('Africa/Lagos')

    for record in event["Records"]:
        event_id = record["eventID"]
        logger.info(f"Processing event ID: {event_id}")
        
        try:
            # Deserialize and process record
            payload = deserialize_record(record)
            record_df = pd.DataFrame.from_dict(payload)
            lagos_tz = pytz.timezone("Africa/Lagos")
            record_df["timestamp"] = pd.to_datetime(record_df["timestamp"], unit="ms", utc=True)
            record_df["timestamp"] = record_df["timestamp"].dt.tz_convert(lagos_tz).dt.tz_localize(None)
            
            # Handle timestamp and timezone
            #record_df["timestamp"] = pd.to_datetime(record_df["timestamp"], unit="ms")
            #record_df["timestamp"] = record_df["timestamp"].dt.tz_localize("UTC").dt.tz_convert(lagos_tz)
            
            # Extract month and year for querying efficiency
            record_df['month'] = record_df["timestamp"].dt.month
            record_df['year'] = record_df["timestamp"].dt.year
            record_df['date'] = record_df["timestamp"].dt.date

            # Add asset_name based on gateway_serial
            if 'gateway_serial' in record_df.columns:
                record_df['asset_name'] = record_df['gateway_serial'].apply(
                    lambda x: GATEWAY_TO_ASSET.get(x, None)
                )
            
            # Process each row to calculate metrics
            for idx, row in record_df.iterrows():
                gateway_serial = row.get('gateway_serial', None)
                asset_name = GATEWAY_TO_ASSET.get(gateway_serial, None)
                
                # Get transformer capacity
                transformer_capacity = ASSETS.get(asset_name, 0) if asset_name else 0
                transformer_info = {'transformer_capacity': transformer_capacity, 'asset_name': asset_name}
                
                # Calculate metrics and update record
                metrics = row.to_dict()
                calculated_metrics = calculate_metrics(metrics, transformer_info)
                
                for key, value in calculated_metrics.items():
                    record_df.at[idx, key] = value
            # Deduplicate based on timestamp and gateway_serial
            if 'timestamp' in record_df.columns and 'gateway_serial' in record_df.columns:
                record_df = record_df.drop_duplicates(subset=['timestamp', 'gateway_serial'], keep='last')

            processed_records.append(record_df)

            
        except Exception as e:
            logger.error(f"Failed to process record {event_id}: {str(e)}")
            failed_records.append(record)
    
    # Combine all processed records
    if processed_records:
        return pd.concat(processed_records), failed_records
    else:
        return pd.DataFrame(), failed_records


def lambda_handler(event, context):
    """
    Main Lambda handler function.
    
    Args:
        event: Lambda event
        context: Lambda context
        
    Returns:
        Dictionary with processing results
    """
    start_time = datetime.now()
    logger.info(f"Processing {len(event.get('Records', []))} records")
    
    # Process records
    processed_df, failed_records = process_records(event)
    
    if processed_df.empty:
        logger.warning("No records were successfully processed")
        return {
            'statusCode': 200,
            'processed': 0,
            'failed': len(failed_records),
            'duration_ms': (datetime.now() - start_time).total_seconds() * 1000
        }
    
    # Get database connection
    connection = get_db_connection()
    if not connection:
        logger.error("Failed to establish database connection")
        return {
            'statusCode': 500,
            'message': 'Database connection failed',
            'duration_ms': (datetime.now() - start_time).total_seconds() * 1000
        }
    
    try:
        # Insert data into RDS
        success = bulk_insert_to_rds(processed_df, connection)
        
        if success:
            logger.info(f"Successfully processed {len(processed_df)} records")
            return {
                'statusCode': 200,
                'processed': len(processed_df),
                'failed': len(failed_records),
                'duration_ms': (datetime.now() - start_time).total_seconds() * 1000
            }
        else:
            logger.error("Failed to insert data into RDS")
            return {
                'statusCode': 500,
                'message': 'Data insertion failed',
                'duration_ms': (datetime.now() - start_time).total_seconds() * 1000
            }
    finally:
        # Always close the connection
        if connection:
            connection.close()
            logger.info("Database connection closed")