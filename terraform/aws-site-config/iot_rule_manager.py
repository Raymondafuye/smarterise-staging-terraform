import json
import boto3
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
iot_client = boto3.client('iot')

SITE_CONFIG_BUCKET = os.environ.get('SITE_CONFIG_BUCKET')
DEVICE_DATA_STREAM_NAME = os.environ.get('DEVICE_DATA_STREAM_NAME')
IOT_ROLE_ARN = os.environ.get('IOT_ROLE_ARN')

def load_site_config():
    """Load site configuration from S3"""
    try:
        response = s3_client.get_object(Bucket=SITE_CONFIG_BUCKET, Key='site-tiers.json')
        config = json.loads(response['Body'].read())
        logger.info(f"Loaded site config version: {config.get('version', 'unknown')}")
        return config
    except Exception as e:
        logger.error(f"Failed to load site config: {e}")
        raise

def get_existing_iot_rules():
    """Get all existing IoT topic rules for devices"""
    try:
        rules = []
        paginator = iot_client.get_paginator('list_topic_rules')
        for page in paginator.paginate():
            rules.extend(page.get('rules', []))
        
        device_rules = {}
        for rule in rules:
            rule_name = rule['ruleName']
            if rule_name.startswith('write_to_kinesis_data_stream_'):
                device_name = rule_name.replace('write_to_kinesis_data_stream_', '')
                device_rules[device_name] = rule_name
        
        logger.info(f"Found {len(device_rules)} existing IoT rules")
        return device_rules
    except Exception as e:
        logger.error(f"Failed to list IoT rules: {e}")
        raise

def create_iot_rule(device_name):
    """Create IoT topic rule for a device"""
    try:
        rule_name = f"write_to_kinesis_data_stream_{device_name}"
        
        iot_client.create_topic_rule(
            ruleName=rule_name,
            topicRulePayload={
                'sql': f"SELECT * FROM 'accuenergy/{device_name}'",
                'description': f'Route {device_name} data to Kinesis',
                'actions': [
                    {
                        'kinesis': {
                            'roleArn': IOT_ROLE_ARN,
                            'streamName': DEVICE_DATA_STREAM_NAME,
                            'partitionKey': device_name
                        }
                    }
                ],
                'ruleDisabled': False
            }
        )
        logger.info(f"Created IoT rule for {device_name}")
        return True
    except iot_client.exceptions.ResourceAlreadyExistsException:
        logger.info(f"IoT rule already exists for {device_name}")
        return True
    except Exception as e:
        logger.error(f"Failed to create IoT rule for {device_name}: {e}")
        return False

def delete_iot_rule(rule_name):
    """Delete IoT topic rule"""
    try:
        iot_client.delete_topic_rule(ruleName=rule_name)
        logger.info(f"Deleted IoT rule: {rule_name}")
        return True
    except Exception as e:
        logger.error(f"Failed to delete IoT rule {rule_name}: {e}")
        return False

def sync_iot_rules():
    """Sync IoT rules with site configuration"""
    config = load_site_config()
    existing_rules = get_existing_iot_rules()
    
    critical_sites = []
    non_critical_sites = []
    
    for device_name, site_info in config.get('sites', {}).items():
        if site_info.get('tier') == 'CRITICAL' and site_info.get('enabled', True):
            critical_sites.append(device_name)
        else:
            non_critical_sites.append(device_name)
    
    created = []
    deleted = []
    
    # Create rules for CRITICAL sites
    for device_name in critical_sites:
        if device_name not in existing_rules:
            if create_iot_rule(device_name):
                created.append(device_name)
    
    # Delete rules for NON_CRITICAL sites
    for device_name in non_critical_sites:
        if device_name in existing_rules:
            if delete_iot_rule(existing_rules[device_name]):
                deleted.append(device_name)
    
    return {
        'critical_sites': critical_sites,
        'non_critical_sites': non_critical_sites,
        'created_rules': created,
        'deleted_rules': deleted
    }

def lambda_handler(event, context):
    """Handle IoT rule synchronization"""
    try:
        logger.info(f"Event: {json.dumps(event)}")
        
        result = sync_iot_rules()
        
        logger.info(f"Sync complete: {json.dumps(result)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'IoT rules synchronized successfully',
                'result': result
            })
        }
    except Exception as e:
        logger.error(f"Error syncing IoT rules: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
