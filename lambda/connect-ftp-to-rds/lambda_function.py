import pandas as pd
import boto3
import sqlalchemy
import pytz
import logging
from io import StringIO
from config import cols_for_rds

logging.basicConfig(level=logging.INFO)

# S3 Client
s3_client = boto3.client("s3")

# RDS Connection
DATABASE_URL = "postgres://dbadmin:r!l%S4MGEBA$Ud7L@postgresql-instance.cj4m4g2kmc36.eu-west-2.rds.amazonaws.com:5432/mydb"
engine = sqlalchemy.create_engine(DATABASE_URL)

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
            insert_into_rds(df)
        else:
            logging.info("No new data to insert.")
    
    except Exception as e:
        logging.error("Error in Lambda function", exc_info=True)


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


def insert_into_rds(df):
    """Insert new records into RDS while handling conflicts on the unique timestamp."""
    try:
        df["month"] = df["timestamp"].dt.month
        df["year"] = df["timestamp"].dt.year
        
        # Ensure all required columns exist
        for col in cols_for_rds.keys():
            if col not in df.columns:
                df[col] = None
        
        df = df[cols_for_rds.keys()]

        # Prepare SQL for ON CONFLICT handling
        columns = ', '.join([f'"{col}"' for col in df.columns])
        values_placeholder = ', '.join(['%s'] * len(df.columns))
        
        update_clause = ', '.join([f'"{col}" = EXCLUDED."{col}"' for col in df.columns if col != 'timestamp'])

        sql = f"""
            INSERT INTO your-table ({columns})
            VALUES ({values_placeholder})
            ON CONFLICT ("timestamp") DO NOTHING;
        """
        
        with engine.connect() as connection:
            connection.execute(sqlalchemy.text(sql), df.to_records(index=False).tolist())
        
        logging.info(f"Inserted {df.shape[0]} new records into RDS, skipping duplicates.")
    except Exception as e:
        logging.error("Failed to insert data into RDS", exc_info=True)