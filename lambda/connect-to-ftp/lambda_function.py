import logging
import ftplib
import boto3
import os
import json
import tempfile
from botocore.exceptions import ClientError

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
FTP_HOST = os.getenv("FTP_HOST")
FTP_USER = os.getenv("FTP_USER")
FTP_PASS = os.getenv("FTP_PASS")
FTP_FOLDER = os.getenv("FTP_FOLDER")
S3_BUCKET = os.getenv("S3_BUCKET")
S3_FOLDER = os.getenv("S3_FOLDER")
SITE_CONFIG_BUCKET = os.getenv("SITE_CONFIG_BUCKET", "smarterise-site-config")

# AWS clients
s3 = boto3.client("s3")

def load_site_config():
    """Load site configuration from S3"""
    try:
        response = s3.get_object(Bucket=SITE_CONFIG_BUCKET, Key='site-tiers.json')
        config = json.loads(response['Body'].read())
        logger.info(f"Loaded site config version: {config.get('version', 'unknown')}")
        return config
    except Exception as e:
        logger.error(f"Failed to load site config: {e}")
        return {"sites": {}}

def get_sites_by_tier(tier):
    """Get list of sites for a specific tier"""
    config = load_site_config()
    sites = []
    for device_name, site_info in config.get('sites', {}).items():
        if site_info.get('tier') == tier and site_info.get('enabled', True):
            sites.append(device_name)
    return sites

def file_exists_in_s3(bucket, key):
    """Check if a file exists in S3."""
    try:
        s3.head_object(Bucket=bucket, Key=key)
        return True
    except ClientError as e:
        if e.response["Error"]["Code"] == "404":
            return False
        else:
            raise

def process_ftp_for_sites(sites):
    """Process FTP files for specific sites"""
    processed_files = []
    
    try:
        with ftplib.FTP(FTP_HOST) as ftp:
            ftp.login(FTP_USER, FTP_PASS)
            ftp.cwd(FTP_FOLDER)

            files = ftp.nlst()
            logger.info(f"Found {len(files)} files in FTP")

            for file_name in files:
                # Check if file belongs to any of the target sites
                site_match = None
                for site in sites:
                    if site in file_name:
                        site_match = site
                        break
                
                if not site_match:
                    continue
                
                s3_key = f"{S3_FOLDER}{file_name}"

                if file_exists_in_s3(S3_BUCKET, s3_key):
                    logger.info(f"Skipping {file_name}, already exists in S3")
                    continue

                try:
                    logger.info(f"Downloading {file_name} for site {site_match}")
                    with tempfile.NamedTemporaryFile(delete=False) as temp_file:
                        try:
                            ftp.retrbinary(f"RETR {file_name}", temp_file.write)
                            temp_file_path = temp_file.name
                        except ftplib.error_perm as ftp_error:
                            logger.error(f"Error downloading {file_name}: {ftp_error}")
                            continue

                    logger.info(f"Uploading {file_name} to S3: s3://{S3_BUCKET}/{s3_key}")
                    s3.upload_file(temp_file_path, S3_BUCKET, s3_key)
                    os.remove(temp_file_path)

                    ftp.delete(file_name)
                    logger.info(f"Deleted {file_name} from FTP")
                    processed_files.append(file_name)

                except Exception as file_error:
                    logger.error(f"Error processing {file_name}: {str(file_error)}")

    except Exception as e:
        logger.error(f"FTP connection error: {str(e)}")
        raise
    
    return processed_files

def lambda_handler(event, context):
    logger.info("Lambda function started")
    logger.info(f"Event: {json.dumps(event)}")

    try:
        # Check if this is a site-tier specific invocation
        site_tier = event.get('site_tier')
        
        if site_tier:
            logger.info(f"Processing {site_tier} sites")
            sites = get_sites_by_tier(site_tier)
            logger.info(f"Found {len(sites)} {site_tier} sites: {sites}")
            
            if not sites:
                return {
                    "status": "no_sites",
                    "message": f"No {site_tier} sites found"
                }
            
            processed_files = process_ftp_for_sites(sites)
            
            return {
                "status": "success",
                "site_tier": site_tier,
                "sites_processed": len(sites),
                "files_processed": len(processed_files),
                "files": processed_files
            }
        else:
            # Legacy mode - process all files
            logger.info("Processing all sites (legacy mode)")
            processed_files = process_ftp_for_sites([])
            
            return {
                "status": "success",
                "files_processed": len(processed_files)
            }

    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {"status": "error", "message": str(e)}
