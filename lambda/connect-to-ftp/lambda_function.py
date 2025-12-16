import logging
import ftplib
import boto3
import os
import tempfile
from botocore.exceptions import ClientError

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)  # Change to DEBUG for more details

# Environment variables
FTP_HOST = os.getenv("FTP_HOST")
FTP_USER = os.getenv("FTP_USER")
FTP_PASS = os.getenv("FTP_PASS")
FTP_FOLDER = os.getenv("FTP_FOLDER")
S3_BUCKET = os.getenv("S3_BUCKET")
S3_FOLDER = os.getenv("S3_FOLDER")

# AWS S3 client
s3 = boto3.client("s3")

def file_exists_in_s3(bucket, key):
    """Check if a file exists in S3."""
    try:
        s3.head_object(Bucket=bucket, Key=key)
        return True  # File exists
    except ClientError as e:
        if e.response["Error"]["Code"] == "404":
            return False  # File does not exist
        else:
            raise  # Other errors (e.g., permissions issues)

def lambda_handler(event, context):
    logger.info("🚀 Lambda function started!")

    try:
        with ftplib.FTP(FTP_HOST) as ftp:
            ftp.login(FTP_USER, FTP_PASS)
            ftp.cwd(FTP_FOLDER)

            files = ftp.nlst()
            logger.info(f"Found files: {files}")

            if not files:
                logger.warning("⚠️ No files found in the FTP folder.")
                return {"status": "no_files", "message": "No files found"}

            for file_name in files:
                s3_key = f"{S3_FOLDER}{file_name}"

                # Skip file if it already exists in S3
                if file_exists_in_s3(S3_BUCKET, s3_key):
                    logger.info(f"⚠️ Skipping {file_name}, already exists in S3.")
                    continue

                try:
                    logger.info(f"📥 Downloading {file_name} from FTP...")
                    with tempfile.NamedTemporaryFile(delete=False) as temp_file:
                        try:
                            ftp.retrbinary(f"RETR {file_name}", temp_file.write)
                            temp_file_path = temp_file.name
                        except ftplib.error_perm as ftp_error:
                            logger.error(f"❌ Error processing {file_name}: {ftp_error}")
                            continue  # Skip the file and move to the next one

                    logger.info(f"📤 Uploading {file_name} to S3: s3://{S3_BUCKET}/{s3_key}")
                    s3.upload_file(temp_file_path, S3_BUCKET, s3_key)

                    # Remove temp file after successful upload
                    os.remove(temp_file_path)

                    # Delete the file from FTP after successful upload
                    ftp.delete(file_name)
                    logger.info(f"🗑️ Deleted {file_name} from FTP.")

                except Exception as file_error:
                    logger.error(f"❌ Error processing {file_name}: {str(file_error)}", exc_info=True)

        logger.info("🎉 Lambda execution completed!")
        return {"status": "success", "message": "Files processed"}

    except Exception as e:
        logger.error(f"❌ General error: {str(e)}", exc_info=True)
        return {"status": "error", "message": str(e)}
