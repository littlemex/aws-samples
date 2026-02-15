#!/usr/bin/env python3
"""
Zero-ETL Integration ID Retrieval Script

Simple script to retrieve Zero-ETL integration ID using boto3 RDS client.
"""

import argparse
import boto3
import json
import sys
from datetime import datetime
from typing import Optional, Dict, Any


def load_config(config_file: str) -> Dict[str, Any]:
    """Load configuration from JSON file."""
    try:
        with open(config_file, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: Configuration file not found: {config_file}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in configuration file: {e}", file=sys.stderr)
        sys.exit(1)


def get_aws_region() -> str:
    """Get AWS region from configuration or default."""
    try:
        session = boto3.Session()
        return session.region_name or 'us-east-1'
    except Exception:
        return 'us-east-1'


def get_integration_id() -> str:
    """
    Retrieve integration ID using boto3 RDS client.
    
    Returns:
        Integration ID if found
        
    Raises:
        SystemExit: If integration not found or error occurs
    """
    try:
        print("Retrieving integration ID via boto3 RDS client...", file=sys.stderr)
        
        rds_client = boto3.client('rds')
        response = rds_client.describe_integrations()
        
        integrations = response.get('Integrations', [])
        if not integrations:
            print("Error: No Zero-ETL integrations found", file=sys.stderr)
            sys.exit(1)
        
        # Get the first integration
        integration = integrations[0]
        integration_arn = integration.get('IntegrationArn', '')
        
        if not integration_arn:
            print("Error: Integration ARN not found", file=sys.stderr)
            sys.exit(1)
        
        # Extract integration ID from ARN (last part after ':')
        integration_id = integration_arn.split(':')[-1]
        
        # Validate UUID format
        import re
        uuid_pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        if not re.match(uuid_pattern, integration_id):
            print(f"Error: Invalid integration ID format: {integration_id}", file=sys.stderr)
            sys.exit(1)
        
        print(f"Integration ID retrieved: {integration_id[:8]}...{integration_id[-8:]}", file=sys.stderr)
        return integration_id
        
    except Exception as e:
        print(f"Error retrieving integration ID: {e}", file=sys.stderr)
        sys.exit(1)


def update_env_file(integration_id: str, env_file: str = '.env') -> None:
    """
    Update .env file with integration ID.
    
    Args:
        integration_id: The integration ID to write
        env_file: Path to .env file
    """
    region = get_aws_region()
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    print(f"Updating {env_file} file with integration ID...", file=sys.stderr)
    
    env_content = f"""# Zero-ETL Integration Configuration
# This file is generated automatically by retrieve-integration-id.py
# Do not edit manually - will be overwritten on CDK redeploy

# Zero-ETL Integration ID (obtained from AWS RDS API)
ZERO_ETL_INTEGRATION_ID={integration_id}

# Generation timestamp
GENERATED_AT="{timestamp}"

# CDK deployment information
CDK_STACK_NAME=multitenant-analytics-aurora-postgresql-to-redshift
CDK_REGION={region}
"""
    
    try:
        with open(env_file, 'w') as f:
            f.write(env_content)
        
        print(f"{env_file} file updated successfully", file=sys.stderr)
        print(f"Integration ID: {integration_id[:8]}...{integration_id[-8:]}", file=sys.stderr)
        print(f"Generated at: {timestamp}", file=sys.stderr)
        
    except Exception as e:
        print(f"Error writing to {env_file}: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    """Main function."""
    parser = argparse.ArgumentParser(
        description='Retrieve Zero-ETL integration ID and update .env file',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  uv run retrieve-integration-id.py --config ../config.json
  uv run retrieve-integration-id.py --config ../config.json --env-file ../.env.production
        """
    )
    
    parser.add_argument(
        '--config', '-c',
        required=True,
        help='JSON configuration file path'
    )
    
    parser.add_argument(
        '--env-file',
        default='.env',
        help='Environment file path (default: .env)'
    )
    
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be done without making changes'
    )
    
    args = parser.parse_args()
    
    # Load configuration (for future use if needed)
    config = load_config(args.config)
    
    if args.dry_run:
        print("DRY RUN: Would retrieve integration ID and update .env file", file=sys.stderr)
        return
    
    # Retrieve integration ID
    integration_id = get_integration_id()
    
    # Update .env file
    update_env_file(integration_id, args.env_file)
    
    # Output integration ID to stdout for script usage
    print(integration_id)


if __name__ == '__main__':
    main()
