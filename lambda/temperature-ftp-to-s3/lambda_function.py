"""
Temperature Monitoring FTP-to-S3 Lambda Function

This Lambda function downloads thermal images (.png) and CSV files from an FTP server
and uploads them to S3. It implements:
- Memory-safe file transfers using /tmp and s3.upload_file()
- Active Day Logic: Process today's folder continuously, only checkpoint past dates
- FTP connection retry logic with exponential backoff
- Checkpoint/resume for incremental processing
- Idempotency checks to avoid duplicate uploads
- Batch processing (2 past dates + today per run)
- FTP cleanup after successful upload
"""

import os
import json
import time
import tempfile
from ftplib import FTP, error_perm
from datetime import datetime, timezone
import boto3
from botocore.exceptions import ClientError

# Environment variables
FTP_HOST = os.environ['FTP_HOST']
FTP_USER = os.environ['FTP_USER']
FTP_PASS = os.environ['FTP_PASS']
FTP_FOLDER = os.environ['FTP_FOLDER']
S3_BUCKET = os.environ['S3_BUCKET']
SITE_IDS = os.environ['SITE_IDS'].split(',')

# Constants
CHECKPOINT_KEY = 'state/ingest_checkpoint.json'
MAX_RETRIES = 3
BATCH_SIZE = 2  # Process 2 past dates per run (+ today)

s3_client = boto3.client('s3')


def lambda_handler(event, context):
    """Main Lambda handler"""
    print(f"Starting temperature monitoring FTP-to-S3 ingestion")
    print(f"Sites to process: {SITE_IDS}")
    print(f"FTP Host: {FTP_HOST}")
    print(f"S3 Bucket: {S3_BUCKET}")
    
    # Get current UTC date for Active Day Logic
    today_str = datetime.now(timezone.utc).strftime('%Y-%m-%d')
    print(f"Today's date (UTC): {today_str}")
    
    # Connect to FTP with retry logic
    ftp = connect_ftp_with_retry()
    if not ftp:
        raise Exception("Failed to connect to FTP server after retries")
    
    try:
        # Load checkpoint
        checkpoint = load_checkpoint()
        print(f"Loaded checkpoint: {checkpoint}")
        
        # Process each site
        for site_id in SITE_IDS:
            site_id = site_id.strip()
            print(f"\n{'='*60}")
            print(f"Processing site: {site_id}")
            print(f"{'='*60}")
            
            process_site(ftp, site_id, checkpoint, today_str)
        
        # Save updated checkpoint
        save_checkpoint(checkpoint)
        print(f"\nFinal checkpoint saved: {checkpoint}")
        
    finally:
        try:
            ftp.quit()
            print("FTP connection closed")
        except:
            pass
    
    print("\n" + "="*60)
    print("Temperature monitoring ingestion completed successfully")
    print("="*60)
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Temperature monitoring ingestion completed',
            'checkpoint': checkpoint,
            'today': today_str
        })
    }


def connect_ftp_with_retry():
    """Connect to FTP server with exponential backoff retry logic"""
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            print(f"FTP connection attempt {attempt}/{MAX_RETRIES}")
            ftp = FTP()
            ftp.connect(FTP_HOST, timeout=30)
            ftp.login(FTP_USER, FTP_PASS)
            print(f"Successfully connected to FTP server: {FTP_HOST}")
            
            # Navigate to root folder
            if FTP_FOLDER and FTP_FOLDER != '/':
                ftp.cwd(FTP_FOLDER)
                print(f"Changed to FTP folder: {FTP_FOLDER}")
            
            return ftp
            
        except Exception as e:
            print(f"FTP connection attempt {attempt} failed: {str(e)}")
            if attempt < MAX_RETRIES:
                delay = 2 ** (attempt - 1)  # Exponential backoff: 1s, 2s, 4s
                print(f"Retrying in {delay} seconds...")
                time.sleep(delay)
            else:
                print("All FTP connection attempts failed")
                return None


def load_checkpoint():
    """Load checkpoint from S3"""
    try:
        response = s3_client.get_object(Bucket=S3_BUCKET, Key=CHECKPOINT_KEY)
        checkpoint = json.loads(response['Body'].read().decode('utf-8'))
        print(f"Checkpoint loaded from S3: {CHECKPOINT_KEY}")
        return checkpoint
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchKey':
            print("No existing checkpoint found, starting fresh")
            return {}
        else:
            raise


def save_checkpoint(checkpoint):
    """Save checkpoint to S3"""
    checkpoint_json = json.dumps(checkpoint, indent=2)
    s3_client.put_object(
        Bucket=S3_BUCKET,
        Key=CHECKPOINT_KEY,
        Body=checkpoint_json.encode('utf-8'),
        ContentType='application/json'
    )
    print(f"Checkpoint saved to S3: {CHECKPOINT_KEY}")


def process_site(ftp, site_id, checkpoint, today_str):
    """Process all date folders for a site"""
    try:
        # Navigate to site folder
        ftp.cwd(f"/{FTP_FOLDER}/{site_id}" if FTP_FOLDER and FTP_FOLDER != '/' else f"/{site_id}")
        print(f"Navigated to site folder: {site_id}")
    except error_perm as e:
        print(f"Site folder not found or inaccessible: {site_id} - {str(e)}")
        return
    
    # List all date folders
    try:
        items = ftp.nlst()
        print(f"Found {len(items)} items in site folder")
    except error_perm:
        print(f"No items found in site folder: {site_id}")
        return
    
    # Filter to date folders (YYYY-MM-DD format)
    date_folders = []
    for item in items:
        if len(item) == 10 and item.count('-') == 2:
            try:
                datetime.strptime(item, '%Y-%m-%d')
                date_folders.append(item)
            except ValueError:
                continue
    
    if not date_folders:
        print(f"No date folders found for site: {site_id}")
        return
    
    # Sort chronologically
    date_folders.sort()
    print(f"Found {len(date_folders)} date folders: {date_folders[:5]}{'...' if len(date_folders) > 5 else ''}")
    
    # Get last checkpoint for this site
    last_checkpoint = checkpoint.get(site_id, None)
    print(f"Last checkpoint for {site_id}: {last_checkpoint}")
    
    # Filter to dates after checkpoint
    if last_checkpoint:
        dates_to_process = [d for d in date_folders if d > last_checkpoint]
    else:
        dates_to_process = date_folders
    
    print(f"Dates to process (after checkpoint): {len(dates_to_process)}")
    
    # Separate past dates and today
    past_dates = [d for d in dates_to_process if d < today_str]
    today_exists = today_str in dates_to_process
    
    # Process next BATCH_SIZE past dates + today (Active Day Logic)
    dates_for_this_run = past_dates[:BATCH_SIZE]
    if today_exists:
        dates_for_this_run.append(today_str)
    
    if not dates_for_this_run:
        print(f"No dates to process for site {site_id} in this run")
        return
    
    print(f"Processing {len(dates_for_this_run)} dates in this run: {dates_for_this_run}")
    
    # Process each date
    for date_folder in dates_for_this_run:
        is_today = (date_folder == today_str)
        process_date_folder(ftp, site_id, date_folder, is_today)
        
        # Only update checkpoint for past dates (Active Day Logic)
        if not is_today:
            checkpoint[site_id] = date_folder
            print(f"Updated checkpoint for {site_id}: {date_folder}")
        else:
            print(f"Skipping checkpoint update for today ({today_str}) - Active Day Logic")


def process_date_folder(ftp, site_id, date_folder, is_today):
    """Process a single date folder (thermal images and CSV files)"""
    print(f"\n  Processing date folder: {date_folder} {'(TODAY)' if is_today else ''}")
    
    base_path = f"/{FTP_FOLDER}/{site_id}/{date_folder}" if FTP_FOLDER and FTP_FOLDER != '/' else f"/{site_id}/{date_folder}"
    
    # Process thermal images
    thermal_path = f"{base_path}/thermal"
    try:
        ftp.cwd(thermal_path)
        print(f"    Processing thermal images in: {thermal_path}")
        process_files(ftp, site_id, date_folder, 'thermal', '.png')
    except error_perm as e:
        print(f"    No thermal folder or inaccessible: {str(e)}")
    
    # Process CSV files in date folder root
    try:
        ftp.cwd(base_path)
        print(f"    Processing CSV files in: {base_path}")
        process_files(ftp, site_id, date_folder, '', '.csv')
    except error_perm as e:
        print(f"    Cannot access date folder: {str(e)}")
    
    # Clean up empty folders (only for past dates, not today)
    if not is_today:
        cleanup_empty_folders(ftp, site_id, date_folder)


def process_files(ftp, site_id, date_folder, subfolder, extension):
    """Process files with a specific extension in a folder"""
    try:
        files = ftp.nlst()
        matching_files = [f for f in files if f.endswith(extension)]
        
        if not matching_files:
            print(f"      No {extension} files found")
            return
        
        print(f"      Found {len(matching_files)} {extension} files")
        
        for filename in matching_files:
            process_single_file(ftp, site_id, date_folder, subfolder, filename)
            
    except error_perm as e:
        print(f"      Error listing files: {str(e)}")


def process_single_file(ftp, site_id, date_folder, subfolder, filename):
    """Process a single file: check existence, download, upload, delete"""
    # Build S3 key
    if subfolder:
        s3_key = f"{site_id}/{date_folder}/{subfolder}/{filename}"
    else:
        s3_key = f"{site_id}/{date_folder}/{filename}"
    
    # Check if file already exists in S3 (idempotency)
    if file_exists_in_s3(s3_key):
        print(f"        SKIP (exists in S3): {filename}")
        # Delete from FTP even if already in S3
        try:
            ftp.delete(filename)
            print(f"        Deleted from FTP: {filename}")
        except error_perm as e:
            print(f"        Could not delete from FTP: {str(e)}")
        return
    
    # Download to /tmp (memory-safe)
    local_path = os.path.join(tempfile.gettempdir(), filename)
    try:
        print(f"        Downloading: {filename}")
        with open(local_path, 'wb') as f:
            ftp.retrbinary(f'RETR {filename}', f.write)
        
        file_size = os.path.getsize(local_path)
        print(f"        Downloaded {file_size} bytes to /tmp")
        
        # Upload to S3 (memory-safe)
        print(f"        Uploading to S3: {s3_key}")
        s3_client.upload_file(local_path, S3_BUCKET, s3_key)
        print(f"        Uploaded to S3 successfully")
        
        # Delete from FTP
        ftp.delete(filename)
        print(f"        Deleted from FTP: {filename}")
        
    except Exception as e:
        print(f"        ERROR processing {filename}: {str(e)}")
    finally:
        # Clean up local file
        if os.path.exists(local_path):
            os.remove(local_path)


def file_exists_in_s3(s3_key):
    """Check if a file exists in S3 using head_object"""
    try:
        s3_client.head_object(Bucket=S3_BUCKET, Key=s3_key)
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            return False
        else:
            raise


def cleanup_empty_folders(ftp, site_id, date_folder):
    """Remove empty thermal and date folders from FTP"""
    base_path = f"/{FTP_FOLDER}/{site_id}/{date_folder}" if FTP_FOLDER and FTP_FOLDER != '/' else f"/{site_id}/{date_folder}"
    
    # Try to remove thermal folder
    thermal_path = f"{base_path}/thermal"
    try:
        ftp.cwd(thermal_path)
        files = ftp.nlst()
        if not files or files == ['.', '..']:
            ftp.cwd('..')  # Go back to date folder
            ftp.rmd('thermal')
            print(f"    Removed empty thermal folder: {thermal_path}")
    except error_perm:
        pass  # Folder doesn't exist or not empty
    
    # Try to remove date folder
    try:
        ftp.cwd(base_path)
        files = ftp.nlst()
        if not files or files == ['.', '..']:
            ftp.cwd('..')  # Go back to site folder
            ftp.rmd(date_folder)
            print(f"    Removed empty date folder: {date_folder}")
    except error_perm:
        pass  # Folder not empty or can't remove
