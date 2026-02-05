import json
import boto3
import pandas as pd
import logging
from datetime import datetime
from functools import lru_cache
import ftplib
import io
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
cloudwatch = boto3.client('cloudwatch')
rds_client = boto3.client('rds-data')

SITE_CONFIG_BUCKET = os.environ.get('SITE_CONFIG_BUCKET', 'smarterise-site-config')

@lru_cache(maxsize=1)
def load_site_config():
    """Load site configuration from S3 with caching"""
    try:
        response = s3_client.get_object(Bucket=SITE_CONFIG_BUCKET, Key='site-tiers.json')
        config = json.loads(response['Body'].read())
        logger.info(f"Loaded site config version: {config.get('version', 'unknown')}")
        return config
    except Exception as e:
        logger.error(f"Failed to load site config: {e}")
        return {"sites": {}}

def get_site_tier(gateway_serial):
    """Get site tier for a specific gateway"""
    config = load_site_config()
    site_info = config.get('sites', {}).get(gateway_serial, {})
    return site_info.get('tier', 'CRITICAL')

def evaluate_and_publish_with_timestamp(data_row, gateway_serial, measurement_timestamp=None):
    """Publishes metrics with actual measurement timestamp"""
    timestamp = measurement_timestamp if measurement_timestamp else datetime.utcnow()
    
    try:
        # Extract metrics from data row
        voltage_a = float(data_row.get('voltage_phase_a', 0))
        voltage_b = float(data_row.get('voltage_phase_b', 0))
        voltage_c = float(data_row.get('voltage_phase_c', 0))
        
        # Calculate voltage unbalance factor
        avg_voltage = (voltage_a + voltage_b + voltage_c) / 3
        max_deviation = max(abs(voltage_a - avg_voltage), 
                           abs(voltage_b - avg_voltage), 
                           abs(voltage_c - avg_voltage))
        voltage_unbalance_factor = (max_deviation / avg_voltage) * 100 if avg_voltage > 0 else 0
        
        # Publish metrics to CloudWatch
        metrics = [
            {
                "MetricName": "VoltagePhase_A",
                "Value": voltage_a,
                "Unit": "None",
                "Timestamp": timestamp,
                "Dimensions": [{"Name": "GatewaySerial", "Value": gateway_serial}]
            },
            {
                "MetricName": "VoltagePhase_B", 
                "Value": voltage_b,
                "Unit": "None",
                "Timestamp": timestamp,
                "Dimensions": [{"Name": "GatewaySerial", "Value": gateway_serial}]
            },
            {
                "MetricName": "VoltagePhase_C",
                "Value": voltage_c,
                "Unit": "None", 
                "Timestamp": timestamp,
                "Dimensions": [{"Name": "GatewaySerial", "Value": gateway_serial}]
            },
            {
                "MetricName": "VoltageUnbalanceCalculated",
                "Value": voltage_unbalance_factor,
                "Unit": "Percent",
                "Timestamp": timestamp,
                "Dimensions": [{"Name": "GatewaySerial", "Value": gateway_serial}]
            }
        ]
        
        cloudwatch.put_metric_data(
            Namespace="SmartMeterMetrics",
            MetricData=metrics
        )
        
        logger.info(f"Published {len(metrics)} metrics for {gateway_serial} with timestamp {timestamp}")
        
    except Exception as e:
        logger.error(f"Error publishing metrics for {gateway_serial}: {e}")

def lambda_handler(event, context):
    """Enhanced FTP Lambda handler with site-aware processing"""
    
    try:
        # Check if this is an EventBridge scheduled event
        if 'site_tier' in event:
            site_tier = event['site_tier']
            logger.info(f"Processing scheduled event for {site_tier} sites")
            
            # Load site configuration
            config = load_site_config()
            
            # Process sites of the specified tier
            processed_sites = []
            for gateway_serial, site_info in config.get('sites', {}).items():
                if site_info.get('tier') == site_tier and site_info.get('enabled', True):
                    logger.info(f"Processing FTP for {gateway_serial} (tier: {site_tier})")
                    processed_sites.append(gateway_serial)
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Processed {len(processed_sites)} {site_tier} sites',
                    'sites': processed_sites
                })
            }
        
        # Handle S3 trigger events
        elif 'Records' in event:
            results = []
            
            for record in event['Records']:
                bucket = record['s3']['bucket']['name']
                key = record['s3']['object']['key']
                
                # Extract gateway serial from file path/name
                gateway_serial = extract_gateway_serial(key)
                if not gateway_serial:
                    logger.warning(f"Could not extract gateway serial from {key}")
                    continue
                
                # Get site tier for this gateway
                site_tier = get_site_tier(gateway_serial)
                
                # Process the data
                logger.info(f"Processing {key} for {gateway_serial} (tier: {site_tier})")
                results.append({
                    'gateway_serial': gateway_serial,
                    'file': key,
                    'site_tier': site_tier
                })
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Processed {len(results)} files',
                    'results': results
                })
            }
        
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Unknown event type'})
            }
            
    except Exception as e:
        logger.error(f"Error in lambda handler: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def extract_gateway_serial(file_path):
    """Extract gateway serial from file path"""
    parts = file_path.split('/')
    for part in parts:
        if part.startswith('AN') or part.startswith('ehm'):
            return part.split('_')[0]
    return None