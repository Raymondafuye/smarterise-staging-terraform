import json
import boto3
import logging
from datetime import datetime
from functools import lru_cache

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
BUCKET_NAME = '${bucket_name}'

@lru_cache(maxsize=1)
def load_site_config():
    """Load site configuration from S3 with caching"""
    try:
        response = s3_client.get_object(Bucket=BUCKET_NAME, Key='site-tiers.json')
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

def get_site_info(gateway_serial):
    """Get complete site information"""
    config = load_site_config()
    return config.get('sites', {}).get(gateway_serial, {
        'tier': 'CRITICAL',
        'enabled': True,
        'asset_id': f"C{gateway_serial[-3:]}"
    })

def update_site_config(updates):
    """Update site configuration"""
    try:
        # Load current config
        config = load_site_config()
        
        # Apply updates
        for gateway_serial, site_updates in updates.items():
            if gateway_serial not in config['sites']:
                config['sites'][gateway_serial] = {
                    'asset_id': f"C{gateway_serial[-3:]}",
                    'tier': 'CRITICAL',
                    'enabled': True
                }
            
            config['sites'][gateway_serial].update(site_updates)
        
        # Update metadata
        config['last_updated'] = datetime.utcnow().isoformat() + 'Z'
        config['version'] = str(float(config.get('version', '1.0')) + 0.1)
        
        # Save to S3
        s3_client.put_object(
            Bucket=BUCKET_NAME,
            Key='site-tiers.json',
            Body=json.dumps(config, indent=2),
            ContentType='application/json'
        )
        
        # Clear cache
        load_site_config.cache_clear()
        
        logger.info(f"Updated site config to version {config['version']}")
        return config
        
    except Exception as e:
        logger.error(f"Failed to update site config: {e}")
        raise

def lambda_handler(event, context):
    """
    Handle site configuration management requests
    
    Event structure:
    {
        "action": "get_config" | "get_site" | "update_sites",
        "gateway_serial": "string" (for get_site),
        "updates": {"gateway_serial": {"tier": "CRITICAL|NON_CRITICAL", "enabled": true|false}}
    }
    """
    
    try:
        action = event.get('action', 'get_config')
        
        if action == 'get_config':
            # Return full configuration
            config = load_site_config()
            return {
                'statusCode': 200,
                'body': json.dumps(config)
            }
            
        elif action == 'get_site':
            # Return specific site information
            gateway_serial = event.get('gateway_serial')
            if not gateway_serial:
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': 'gateway_serial required'})
                }
            
            site_info = get_site_info(gateway_serial)
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'gateway_serial': gateway_serial,
                    'site_info': site_info
                })
            }
            
        elif action == 'update_sites':
            # Update site configurations
            updates = event.get('updates', {})
            if not updates:
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': 'updates required'})
                }
            
            updated_config = update_site_config(updates)
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Configuration updated successfully',
                    'version': updated_config['version'],
                    'updated_sites': list(updates.keys())
                })
            }
            
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Unknown action: {action}'})
            }
            
    except Exception as e:
        logger.error(f"Error processing request: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }