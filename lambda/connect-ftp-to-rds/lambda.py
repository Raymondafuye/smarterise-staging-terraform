import pandas as pd
import boto3
import os
import sqlalchemy
import pytz
import logging
import re
from io import StringIO
from config import cols_for_rds

logging.basicConfig(level=logging.INFO)

# S3 Client
s3_client = boto3.client("s3")

# RDS Connection
# RDS connection details from environment variables
rds_host = os.environ.get("DB_HOST")
rds_database = os.environ.get("DB_NAME", "smartmeters")
rds_username = os.environ.get("DB_USER")
rds_password = os.environ.get("DB_PASSWORD")
rds_port = os.environ.get("DB_PORT", "5432")
rds_table = "smart_device_readings" 

# Create SQLAlchemy engine for database connection
try:
    connection_string = f"postgresql://{rds_username}:{rds_password}@{rds_host}:{rds_port}/{rds_database}"
    engine = sqlalchemy.create_engine(connection_string)
    logging.info("Successfully created database engine")
except Exception as e:
    logging.error("Failed to create database engine", exc_info=True)
    raise e

# Column Mapping
mapping_dict = {
    "timestamp": "time",
    "line_to_neutral_voltage_phase_a": "V1",
    "line_to_neutral_voltage_phase_b": "V2",
    "line_to_neutral_voltage_phase_c": "V3",
    "line_current_overall_phase_a": "I1",
    "line_current_overall_phase_b": "I2",
    "line_current_overall_phase_c": "I3",
    "line_current_overall_neutral": "Iavg_A",
    "active_power_overall_total": "Psum_kW",
    "import_active_energy_overall_total": "EP_IMP_kWh",
    "analog_input_channel_1": "AI1",
    "analog_input_channel_2": "AI2",
    "power_factor_overall_phase_a": "PF1",
    "power_factor_overall_phase_b": "PF2",
    "power_factor_overall_phase_c": "PF3",
    "active_power_overall_phase_a": "P1",
    "active_power_overall_phase_b": "P2",
    "active_power_overall_phase_c": "P3",
    "device_online": "LoadType",
    "voltage_unbalance_factor": "Unbl_V",
    "current_unbalance_factor": "Unbl_I",
    "frequency": "Freq_Hz",
    "power_factor_overall": "PF",
    "reactive_power_overall_total": "Qsum_kvar",
    "reactive_power_overall_phase_a": "Q1",
    "reactive_power_overall_phase_b": "Q2",
    "reactive_power_overall_phase_c": "Q3",
    "apparent_power_overall_total": "Ssum_kVA",
    "total_harmonic_distortion_current_phase_a": "THD_Ia",
    "total_harmonic_distortion_current_phase_b": "THD_Ib",
    "total_harmonic_distortion_current_phase_c": "THD_Ic",
    "3rd_harmonic_phase_a": "Har3_Va",
    "3rd_harmonic_phase_b": "Har3_Vb",
    "3rd_harmonic_phase_c": "Har3_Vc",
    "5th_harmonic_phase_a": "Har5_Va",
    "5th_harmonic_phase_b": "Har5_Vb",
    "5th_harmonic_phase_c": "Har5_Vc",
}


def extract_gateway_serial(filename):
    # Extract gateway serial from filename pattern: AN54101471-logger1-2025-03-20T08-00-00-0400-1min.csv
    match = re.match(r'([A-Z]{2}\d+)', filename)
    if match:
        return match.group(1)
    return None

def lambda_handler(event, context):
    """AWS Lambda function triggered by S3 when a CSV file is uploaded."""
    try:
        # Get S3 bucket and object key from the event
        s3_bucket = event['Records'][0]['s3']['bucket']['name']
        s3_key = event['Records'][0]['s3']['object']['key']
        file_key = event['Records'][0]['s3']['object']['key']
        # Extract gateway serial from filename
        gateway_serial = extract_gateway_serial(os.path.basename(file_key))
        if not gateway_serial:
            raise ValueError(f"Could not extract gateway serial from filename: {file_key}")

        # Fetch and process CSV file
        df = fetch_csv_from_s3(s3_bucket, s3_key)
        
        if not df.empty:
            insert_into_rds(df, gateway_serial)
        else:
            logging.info("No new data to insert.")
    
    except Exception as e:
        logging.error("Error in Lambda function", exc_info=True)
        raise e


def fetch_csv_from_s3(bucket_name, file_key):
    """Read CSV file from S3, process, and return a DataFrame."""
    try:
        response = s3_client.get_object(Bucket=bucket_name, Key=file_key)
        csv_content = response["Body"].read().decode("utf-8")

        # Read CSV into Pandas DataFrame
        df = pd.read_csv(StringIO(csv_content))
        df.rename(columns=mapping_dict, inplace=True)
        df["timestamp"] = pd.to_datetime(df["timestamp"], errors="coerce")
        df.dropna(subset=["timestamp"], inplace=True)

        # Convert timezone from US Eastern Time to Africa/Lagos
        us_tz = pytz.timezone("America/New_York")  # Adjust if different
        lagos_tz = pytz.timezone("Africa/Lagos")
        df["timestamp"] = df["timestamp"].dt.tz_localize(us_tz).dt.tz_convert(lagos_tz)

        return df
    except Exception as e:
        logging.error("Failed to read/process CSV from S3", exc_info=True)
        return pd.DataFrame()


def insert_into_rds(df, gateway_serial):
    """Insert new records into RDS while handling conflicts on the unique timestamp."""
    try:
        df["month"] = df["timestamp"].dt.month
        df["year"] = df["timestamp"].dt.year
        df["gateway_serial"] = gateway_serial  # Add gateway serial to dataframe
        
        # Ensure all required columns exist
        for col in cols_for_rds.keys():
            if col not in df.columns:
                df[col] = None
        
        # Select only columns defined in cols_for_rds
        df = df[list(cols_for_rds.keys())]

        # Use SQLAlchemy to insert data
        with engine.begin() as conn:
            # Insert data into the specified table
            df.to_sql(
                rds_table, 
                conn, 
                if_exists='append', 
                index=False,
                method='multi',
                chunksize=1000  # Process in chunks to handle large datasets
            )
        
        logging.info(f"Successfully inserted {len(df)} rows into {rds_table}")
    except Exception as e:
        logging.error(f"Failed to insert data into RDS table {rds_table}", exc_info=True)
        raise e