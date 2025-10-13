#!/usr/bin/env python3
"""
Bastion Host Security Group Configuration for Redshift Serverless Access

This script configures the Bastion Host to have appropriate Security Groups
for connecting to Redshift Serverless, enabling direct psql connections.
"""

import argparse
import json
import sys
import boto3
from typing import Dict, List, Optional, Any
import logging
from datetime import datetime

class BastionRedshiftConnectivityManager:
    def __init__(self, config_file: str = 'config.json', region: str = None, dry_run: bool = False):
        """
        Initialize the Bastion-Redshift connectivity manager
        
        Args:
            config_file: Configuration file path
            region: AWS region (auto-detect if None)
            dry_run: If True, only show what would be done
        """
        self.config_file = config_file
        self.config = self._load_config(config_file)
        self.region = region or self._get_aws_region()
        self.dry_run = dry_run
        
        # AWS clients
        self.ec2 = boto3.client('ec2', region_name=self.region)
        self.cf = boto3.client('cloudformation', region_name=self.region)
        self.redshift_serverless = boto3.client('redshift-serverless', region_name=self.region)
        
        # Setup logging
        self._setup_logging()
        
        self.logger.info(f"🚀 Bastion-Redshift Connectivity Manager initialized")
        self.logger.info(f"   Region: {self.region}")
        self.logger.info(f"   Dry Run: {self.dry_run}")
        
    def _load_config(self, config_file: str) -> Dict[str, Any]:
        """Load configuration from JSON file"""
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            print(f"❌ Error loading config file {config_file}: {e}")
            sys.exit(1)
    
    def _get_aws_region(self) -> str:
        """Get AWS region from configuration or AWS CLI default"""
        try:
            session = boto3.Session()
            return session.region_name or 'us-east-1'
        except:
            return 'us-east-1'
    
    def _setup_logging(self):
        """Setup logging configuration"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        self.logger = logging.getLogger(__name__)
    
    def find_bastion_host(self) -> Dict[str, Any]:
        """
        Find Bastion host instance from CloudFormation stacks or EC2 tags
        
        Returns:
            Dictionary with bastion instance details
        """
        self.logger.info("🔍 Searching for Bastion Host...")
        
        bastion_info = {}
        
        try:
            # Method 1: Search CloudFormation stacks
            stacks = self.cf.list_stacks(StackStatusFilter=['CREATE_COMPLETE', 'UPDATE_COMPLETE'])
            
            for stack in stacks['StackSummaries']:
                stack_name = stack['StackName']
                if any(keyword in stack_name.lower() for keyword in ['bastion', 'client', 'host']):
                    self.logger.info(f"   Checking stack: {stack_name}")
                    try:
                        stack_details = self.cf.describe_stacks(StackName=stack_name)
                        outputs = stack_details['Stacks'][0].get('Outputs', [])
                        
                        for output in outputs:
                            if 'instanceid' in output['OutputKey'].lower():
                                bastion_info['instance_id'] = output['OutputValue']
                                bastion_info['stack_name'] = stack_name
                                self.logger.info(f"✅ Found Bastion Instance ID: {bastion_info['instance_id']}")
                                break
                    except Exception as e:
                        self.logger.debug(f"   Stack check failed: {e}")
                        continue
                
                if bastion_info:
                    break
            
            # Method 2: Search EC2 instances by tags if CloudFormation didn't work
            if not bastion_info:
                self.logger.info("   Searching EC2 instances by tags...")
                response = self.ec2.describe_instances(
                    Filters=[
                        {'Name': 'instance-state-name', 'Values': ['running']},
                        {'Name': 'tag:Name', 'Values': ['*bastion*', '*client*', '*jump*']}
                    ]
                )
                
                for reservation in response['Reservations']:
                    for instance in reservation['Instances']:
                        bastion_info['instance_id'] = instance['InstanceId']
                        bastion_info['instance_type'] = instance['InstanceType']
                        self.logger.info(f"✅ Found Bastion by tags: {bastion_info['instance_id']}")
                        break
                    if bastion_info:
                        break
            
            if bastion_info and 'instance_id' in bastion_info:
                # Get detailed instance information
                instance_details = self.ec2.describe_instances(
                    InstanceIds=[bastion_info['instance_id']]
                )
                
                instance = instance_details['Reservations'][0]['Instances'][0]
                bastion_info.update({
                    'vpc_id': instance['VpcId'],
                    'subnet_id': instance['SubnetId'],
                    'security_groups': [sg['GroupId'] for sg in instance['SecurityGroups']],
                    'public_ip': instance.get('PublicIpAddress', 'N/A'),
                    'private_ip': instance.get('PrivateIpAddress', 'N/A'),
                    'state': instance['State']['Name']
                })
                
                self.logger.info(f"   VPC ID: {bastion_info['vpc_id']}")
                self.logger.info(f"   Current Security Groups: {bastion_info['security_groups']}")
                
                return bastion_info
            else:
                raise Exception("No Bastion host found")
                
        except Exception as e:
            self.logger.error(f"❌ Error finding Bastion host: {e}")
            raise
    
    def get_redshift_security_groups(self) -> Dict[str, Any]:
        """
        Get Redshift Serverless security group information
        
        Returns:
            Dictionary with Redshift security group details
        """
        self.logger.info("🔍 Getting Redshift Serverless security groups...")
        
        redshift_info = {}
        workgroup_name = self.config['redshift']['workgroup']
        
        try:
            # Get workgroup details
            workgroups = self.redshift_serverless.list_workgroups()
            target_workgroup = None
            
            for wg in workgroups['workgroups']:
                if wg['workgroupName'] == workgroup_name:
                    target_workgroup = wg
                    break
            
            if not target_workgroup:
                raise Exception(f"Workgroup {workgroup_name} not found")
            
            redshift_info = {
                'workgroup_name': workgroup_name,
                'namespace_name': target_workgroup['namespaceName'],
                'security_groups': target_workgroup.get('securityGroupIds', []),
                'subnet_ids': target_workgroup.get('subnetIds', []),
                'vpc_id': None,  # Will be determined from subnets
                'endpoint': target_workgroup.get('endpoint', {})
            }
            
            # Get VPC ID from subnet information
            if redshift_info['subnet_ids']:
                subnets = self.ec2.describe_subnets(SubnetIds=redshift_info['subnet_ids'])
                if subnets['Subnets']:
                    redshift_info['vpc_id'] = subnets['Subnets'][0]['VpcId']
            
            self.logger.info(f"✅ Redshift Workgroup: {redshift_info['workgroup_name']}")
            self.logger.info(f"   Security Groups: {redshift_info['security_groups']}")
            self.logger.info(f"   VPC ID: {redshift_info['vpc_id']}")
            
            if redshift_info['endpoint']:
                endpoint_address = redshift_info['endpoint'].get('address', 'N/A')
                endpoint_port = redshift_info['endpoint'].get('port', 5439)
                self.logger.info(f"   Endpoint: {endpoint_address}:{endpoint_port}")
                redshift_info['endpoint_address'] = endpoint_address
                redshift_info['endpoint_port'] = endpoint_port
            
            return redshift_info
            
        except Exception as e:
            self.logger.error(f"❌ Error getting Redshift security groups: {e}")
            raise
    
    def check_connectivity_requirements(self, bastion_info: Dict[str, Any], 
                                      redshift_info: Dict[str, Any]) -> Dict[str, Any]:
        """
        Check if Bastion can connect to Redshift and what's needed
        
        Returns:
            Dictionary with connectivity analysis results
        """
        self.logger.info("🔍 Analyzing connectivity requirements...")
        
        analysis = {
            'same_vpc': False,
            'has_redshift_sg': False,
            'missing_sgs': [],
            'network_accessible': False,
            'required_actions': []
        }
        
        # Check if in same VPC
        if bastion_info['vpc_id'] == redshift_info['vpc_id']:
            analysis['same_vpc'] = True
            self.logger.info("✅ Bastion and Redshift are in the same VPC")
        else:
            analysis['same_vpc'] = False
            analysis['required_actions'].append("VPC peering or transit gateway required")
            self.logger.warning(f"⚠️  VPC mismatch: Bastion({bastion_info['vpc_id']}) != Redshift({redshift_info['vpc_id']})")
        
        # Check if Bastion has any of the Redshift security groups
        bastion_sgs = set(bastion_info['security_groups'])
        redshift_sgs = set(redshift_info['security_groups'])
        
        if bastion_sgs.intersection(redshift_sgs):
            analysis['has_redshift_sg'] = True
            self.logger.info("✅ Bastion already has Redshift security group access")
        else:
            analysis['has_redshift_sg'] = False
            analysis['missing_sgs'] = list(redshift_sgs)
            analysis['required_actions'].append(f"Add Redshift security groups to Bastion: {analysis['missing_sgs']}")
            self.logger.info(f"⚠️  Bastion needs Redshift security groups: {analysis['missing_sgs']}")
        
        # Check security group rules for Redshift access
        if analysis['same_vpc'] and redshift_info['security_groups']:
            try:
                # Get security group rules
                sg_rules = self.ec2.describe_security_groups(
                    GroupIds=redshift_info['security_groups']
                )
                
                port_5439_accessible = False
                for sg in sg_rules['SecurityGroups']:
                    for rule in sg['InboundRules']:
                        if rule.get('FromPort', 0) <= 5439 <= rule.get('ToPort', 65535):
                            # Check if rule allows access from Bastion SGs
                            for ref in rule.get('UserIdGroupPairs', []):
                                if ref['GroupId'] in bastion_info['security_groups']:
                                    port_5439_accessible = True
                                    break
                            if port_5439_accessible:
                                break
                    if port_5439_accessible:
                        break
                
                if port_5439_accessible:
                    analysis['network_accessible'] = True
                    self.logger.info("✅ Port 5439 is accessible from Bastion security groups")
                else:
                    analysis['network_accessible'] = False
                    analysis['required_actions'].append("Security group rules need to allow port 5439 from Bastion")
                    self.logger.info("⚠️  Port 5439 access needs to be configured")
                    
            except Exception as e:
                self.logger.warning(f"Could not analyze security group rules: {e}")
        
        return analysis
    
    def configure_bastion_security_groups(self, bastion_info: Dict[str, Any], 
                                        redshift_info: Dict[str, Any],
                                        analysis: Dict[str, Any]) -> bool:
        """
        Configure Bastion security groups for Redshift access
        
        Returns:
            True if successful, False otherwise
        """
        if analysis['has_redshift_sg'] and analysis['network_accessible']:
            self.logger.info("✅ No security group configuration needed")
            return True
        
        self.logger.info("🔧 Configuring Bastion security groups...")
        
        if self.dry_run:
            self.logger.info("DRY RUN: Would perform the following actions:")
            for action in analysis['required_actions']:
                self.logger.info(f"   - {action}")
            return True
        
        try:
            # Add missing security groups to Bastion instance
            if analysis['missing_sgs']:
                current_sgs = bastion_info['security_groups']
                new_sgs = list(set(current_sgs + analysis['missing_sgs']))
                
                self.logger.info(f"Adding security groups to Bastion instance...")
                self.logger.info(f"   Current: {current_sgs}")
                self.logger.info(f"   New: {new_sgs}")
                
                self.ec2.modify_instance_attribute(
                    InstanceId=bastion_info['instance_id'],
                    Groups=new_sgs
                )
                
                self.logger.info("✅ Security groups updated successfully")
                
                # Wait a moment for the change to propagate
                import time
                time.sleep(5)
                
                # Verify the change
                updated_instance = self.ec2.describe_instances(
                    InstanceIds=[bastion_info['instance_id']]
                )
                updated_sgs = [sg['GroupId'] for sg in updated_instance['Reservations'][0]['Instances'][0]['SecurityGroups']]
                self.logger.info(f"✅ Verified updated security groups: {updated_sgs}")
            
            return True
            
        except Exception as e:
            self.logger.error(f"❌ Error configuring security groups: {e}")
            return False
    
    def get_connection_info(self, redshift_info: Dict[str, Any]) -> Dict[str, Any]:
        """
        Get connection information for psql
        
        Returns:
            Dictionary with connection details
        """
        self.logger.info("📋 Gathering connection information...")
        
        connection_info = {
            'host': redshift_info.get('endpoint_address', 'N/A'),
            'port': redshift_info.get('endpoint_port', 5439),
            'database': 'dev',  # Default database for Redshift Serverless
            'username': 'admin',  # From Secrets Manager
            'workgroup': redshift_info['workgroup_name']
        }
        
        # Try to get admin credentials from Secrets Manager
        try:
            secrets_client = boto3.client('secretsmanager', region_name=self.region)
            secrets = secrets_client.list_secrets()
            
            for secret in secrets['SecretList']:
                if 'redshift' in secret['Name'].lower() and 'admin' in secret['Name'].lower():
                    secret_data = secrets_client.get_secret_value(SecretId=secret['Name'])
                    secret_json = json.loads(secret_data['SecretString'])
                    
                    connection_info['username'] = secret_json.get('admin_username', 'admin')
                    connection_info['password'] = secret_json.get('admin_user_password', '')
                    connection_info['secret_name'] = secret['Name']
                    
                    self.logger.info(f"✅ Found admin credentials: {connection_info['username']}")
                    break
        except Exception as e:
            self.logger.warning(f"Could not retrieve admin credentials: {e}")
        
        return connection_info
    
    def test_connectivity(self, bastion_info: Dict[str, Any], 
                         connection_info: Dict[str, Any]) -> bool:
        """
        Test network connectivity from this machine to Redshift
        Note: This is a basic network test, actual psql connection would need to be done from Bastion
        """
        self.logger.info("🧪 Testing network connectivity...")
        
        if self.dry_run:
            self.logger.info("DRY RUN: Would test connectivity")
            return True
        
        try:
            import socket
            import time
            
            host = connection_info['host']
            port = connection_info['port']
            
            if host == 'N/A':
                self.logger.warning("⚠️  No endpoint address available for testing")
                return False
            
            self.logger.info(f"Testing connection to {host}:{port}")
            
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(10)
            
            start_time = time.time()
            result = sock.connect_ex((host, port))
            end_time = time.time()
            
            sock.close()
            
            if result == 0:
                self.logger.info(f"✅ Network connectivity OK ({end_time - start_time:.2f}s)")
                return True
            else:
                self.logger.warning(f"⚠️  Network connectivity failed (error {result})")
                return False
                
        except Exception as e:
            self.logger.warning(f"⚠️  Connectivity test failed: {e}")
            return False
    
    def generate_connection_guide(self, bastion_info: Dict[str, Any], 
                                connection_info: Dict[str, Any]) -> str:
        """
        Generate connection instructions for Bastion host
        
        Returns:
            String with connection instructions
        """
        guide = f"""
🔗 Bastion Host Connection Guide
{'='*50}

📍 Bastion Instance: {bastion_info['instance_id']}
   Public IP: {bastion_info.get('public_ip', 'N/A')}
   Private IP: {bastion_info.get('private_ip', 'N/A')}

🎯 Redshift Connection Details:
   Host: {connection_info['host']}
   Port: {connection_info['port']}
   Database: {connection_info['database']}
   Username: {connection_info['username']}
   Workgroup: {connection_info['workgroup']}

📋 Connection Steps:

1. Connect to Bastion Host:
   aws ec2-instance-connect ssh --instance-id {bastion_info['instance_id']} --os-user ec2-user

2. Connect to Redshift from Bastion:
   psql -h {connection_info['host']} -p {connection_info['port']} -U {connection_info['username']} -d {connection_info['database']} -W

3. Create Zero-ETL Database:
   -- First, get integration ID
   SELECT integration_id FROM svv_integration WHERE integration_name LIKE '%multitenant%';
   
   -- Then create database (replace <integration_id> with result from above)
   CREATE DATABASE multitenant_analytics_zeroetl FROM INTEGRATION '<integration_id>' DATABASE multitenant_analytics;

💡 Tips:
   - You'll be prompted for the password from Secrets Manager: {connection_info.get('secret_name', 'RedshiftAdminUserSecret-*')}
   - Use \\l to list databases, \\c database_name to switch databases
   - Use \\dt to list tables in current database
"""
        
        return guide
    
    def run_configuration(self) -> bool:
        """
        Main configuration workflow
        
        Returns:
            True if successful, False otherwise
        """
        try:
            self.logger.info("🚀 Starting Bastion-Redshift connectivity configuration...")
            
            # Step 1: Find Bastion host
            bastion_info = self.find_bastion_host()
            
            # Step 2: Get Redshift security group info
            redshift_info = self.get_redshift_security_groups()
            
            # Step 3: Analyze connectivity requirements
            analysis = self.check_connectivity_requirements(bastion_info, redshift_info)
            
            # Step 4: Configure security groups if needed
            success = self.configure_bastion_security_groups(bastion_info, redshift_info, analysis)
            
            if not success:
                return False
            
            # Step 5: Get connection information
            connection_info = self.get_connection_info(redshift_info)
            
            # Step 6: Test connectivity
            self.test_connectivity(bastion_info, connection_info)
            
            # Step 7: Generate connection guide
            guide = self.generate_connection_guide(bastion_info, connection_info)
            print(guide)
            
            # Save connection info to file
            connection_file = 'bastion-redshift-connection.json'
            with open(connection_file, 'w') as f:
                json.dump({
                    'bastion': bastion_info,
                    'redshift': redshift_info,
                    'connection': connection_info,
                    'timestamp': datetime.now().isoformat()
                }, f, indent=2, default=str)
            
            self.logger.info(f"✅ Connection details saved to: {connection_file}")
            self.logger.info("🎉 Bastion-Redshift connectivity configuration completed!")
            
            return True
            
        except Exception as e:
            self.logger.error(f"❌ Configuration failed: {e}")
            return False


def main():
    parser = argparse.ArgumentParser(description='Configure Bastion Host for Redshift Serverless Access')
    parser.add_argument('--config', default='config.json', help='Configuration file path')
    parser.add_argument('--region', help='AWS region (auto-detect if not specified)')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be done without making changes')
    
    args = parser.parse_args()
    
    try:
        manager = BastionRedshiftConnectivityManager(
            config_file=args.config,
            region=args.region,
            dry_run=args.dry_run
        )
        
        success = manager.run_configuration()
        sys.exit(0 if success else 1)
        
    except KeyboardInterrupt:
        print("\n🛑 Operation cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
