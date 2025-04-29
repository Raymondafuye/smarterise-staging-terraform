import pandas as pd
import boto3
import os
import pytz
import logging
import re
import psycopg2
from io import StringIO
from config import cols_for_rds

logging.basicConfig(level=logging.INFO)

# S3 Client
s3_client = boto3.client("s3")

# RDS Connection details from environment variables
rds_host = os.environ.get("DB_HOST")
rds_database = os.environ.get("DB_NAME", "smartmeters")
rds_username = os.environ.get("DB_USER")
rds_password = os.environ.get("DB_PASSWORD")
rds_port = os.environ.get("DB_PORT", "5432")
rds_table = "smart_device_readings" 

# Column Mapping - Using exact CSV column names (case sensitive)
mapping_dict = {
    "Time": "timestamp",  # Note the capital 'T' in "Time"
    "V1": "line_to_neutral_voltage_phase_a",
    "V2": "line_to_neutral_voltage_phase_b",
    "V3": "line_to_neutral_voltage_phase_c",
    "I1": "line_current_overall_phase_a",
    "I2": "line_current_overall_phase_b",
    "I3": "line_current_overall_phase_c",
    "AI1":"analog_input_channel_1",
    "AI2":"analog_input_channel_2",
    "Iavg_A": "line_current_overall_neutral",
    "Psum_kW": "active_power_overall_total",
    "EP_IMP_kWh": "import_active_energy_overall_total",
    "PF1": "power_factor_overall_phase_a",
    "PF2": "power_factor_overall_phase_b",
    "PF3": "power_factor_overall_phase_c",
    "P1": "active_power_overall_phase_a",
    "P2": "active_power_overall_phase_b",
    "P3": "active_power_overall_phase_c",
    "Unbl_U": "voltage_unbalance_factor",
    "Unbl_I": "current_unbalance_factor",
    "Freq_Hz": "frequency",
    "PF": "power_factor_overall",
    "Qsum_kvar": "reactive_power_overall_total",
    "Q1": "reactive_power_overall_phase_a",
    "Q2": "reactive_power_overall_phase_b",
    "Q3": "reactive_power_overall_phase_c",
    "Ssum_kVA": "apparent_power_overall_total",
    "THD_Ia": "total_harmonic_distortion_current_phase_a",
    "THD_Ib": "total_harmonic_distortion_current_phase_b",
    "THD_Ic": "total_harmonic_distortion_current_phase_c",
    "Har3_Va": "3rd_harmonic_phase_a",
    "Har3_Vb": "3rd_harmonic_phase_b",
    "Har3_Vc": "3rd_harmonic_phase_c",
    "Har5_Va": "5th_harmonic_phase_a",
    "Har5_Vb": "5th_harmonic_phase_b",
    "Har5_Vc": "5th_harmonic_phase_c",
}

def get_db_connection():
    """Create a connection to the PostgreSQL database"""
    try:
        conn = psycopg2.connect(
            host=rds_host,
            database=rds_database,
            user=rds_username,
            password=rds_password,
            port=rds_port
        )
        return conn
    except Exception as e:
        logging.error("Failed to connect to the database", exc_info=True)
        raise e

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
        
        # Log column names for debugging
        logging.info(f"CSV columns: {list(df.columns)}")
        
        # Case-insensitive column detection for timestamp
        time_column_candidates = ['Time', 'time', 'TIMESTAMP', 'Timestamp', 'timestamp', 'DATE', 'Date', 'date', 'DATETIME', 'Datetime', 'datetime']
        found_time_column = None
        
        for col in time_column_candidates:
            if col in df.columns:
                found_time_column = col
                break
        
        if found_time_column:
            logging.info(f"Found timestamp column: {found_time_column}")
            
            # First rename the time column to 'timestamp' if needed
            if found_time_column != 'timestamp':
                df.rename(columns={found_time_column: 'timestamp'}, inplace=True)
                
            # Then process the rest of the CSV columns
            # Create a new map with only available columns
            available_mapping = {}
            for csv_col, db_col in mapping_dict.items():
                if csv_col in df.columns and csv_col != found_time_column:
                    available_mapping[csv_col] = db_col
            
            # Apply the filtered mapping
            df.rename(columns=available_mapping, inplace=True)
            
            # Process the timestamp
            df["timestamp"] = pd.to_datetime(df["timestamp"], errors="coerce")
            df.dropna(subset=["timestamp"], inplace=True)
            
            # Convert timezone from US Eastern Time to Africa/Lagos
            us_tz = pytz.timezone("America/New_York")
            lagos_tz = pytz.timezone("Africa/Lagos")
            df["timestamp"] = df["timestamp"].dt.tz_localize(us_tz).dt.tz_convert(lagos_tz)
        else:
            raise ValueError("No timestamp column found in the CSV")
        
        return df
    except Exception as e:
        logging.error("Failed to read/process CSV from S3", exc_info=True)
        logging.error(str(e))
        return pd.DataFrame()


def insert_into_rds(df, gateway_serial):
    """Insert new records into RDS while handling conflicts on the unique timestamp."""
    try:
        # Extract month, year, and date from timestamp
        df["month"] = df["timestamp"].dt.month
        df["year"] = df["timestamp"].dt.year
        df["date"] = df["timestamp"].dt.date  # Extract date from timestamp
        df["gateway_serial"] = gateway_serial  # Add gateway serial to dataframe
        
        # Assign company_id if gateway_serial matches AN54101471
        df["company_id"] = "7f00de00-a116" if gateway_serial == "AN54101471" else None
        
        # Debug the dataframe content
        logging.info(f"Preparing to insert data. DataFrame shape: {df.shape}")
        logging.info(f"Columns available: {list(df.columns)}")

        # Get the available columns from cols_for_rds that exist in the DataFrame
        cols_to_use = [col for col in cols_for_rds.keys() if col in df.columns]
        missing_cols = [col for col in cols_for_rds.keys() if col not in df.columns]
        
        # Log missing columns for awareness
        if missing_cols:
            logging.warning(f"Missing columns in DataFrame: {missing_cols}")

        # Ensure essential columns are included
        essential_cols = ['timestamp', 'date', 'gateway_serial', 'month', 'year', 'company_id']
        for col in essential_cols:
            if col not in cols_to_use:
                cols_to_use.append(col)

        # Select only required columns
        df = df[cols_to_use]

        # Log final structure before insert
        logging.info(f"Final columns being inserted: {list(df.columns)}")

        # Connect to database
        conn = get_db_connection()
        cursor = conn.cursor()

        # Build the INSERT statement
        columns = ', '.join([f'"{col}"' for col in df.columns])
        placeholders = ', '.join(['%s'] * len(df.columns))

        # Create SQL statement with ON CONFLICT handling
        sql = f"""
                INSERT INTO {rds_table} ({columns})
                VALUES ({placeholders})
                ON CONFLICT (timestamp) 
                DO UPDATE SET
                {', '.join([f'"{col}" = EXCLUDED."{col}"' for col in df.columns if col not in ['timestamp']])}
                WHERE
                {rds_table}."line_to_neutral_voltage_phase_a" = 0 AND
                {rds_table}."line_to_neutral_voltage_phase_b" = 0 AND
                {rds_table}."line_to_neutral_voltage_phase_c" = 0;
                """
        logging.info("Executing batch insert...")

        # Convert DataFrame to list of tuples for batch insert
        batch_size = 1000
        records = [tuple(row) for row in df.values]

        # Execute in batches
        for i in range(0, len(records), batch_size):
            batch = records[i:i+batch_size]
            cursor.executemany(sql, batch)

        # Commit the transaction
        conn.commit()
        logging.info(f"Successfully inserted {len(df)} rows into {rds_table}")

    except Exception as e:
        logging.error(f"Error inserting into {rds_table}: {e}", exc_info=True)
        logging.error(f"DataFrame before failure: {df.shape}")
        logging.error(f"Sample data before failure: {df.head().to_dict(orient='records')}")
        raise e
    finally:
        try:
            if cursor:
                cursor.close()
            if conn:
                conn.close()
        except NameError:
            logging.warning("Database connection or cursor was not initialized.")
