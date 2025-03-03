import json
import logging
import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import aiohttp
from gql import Client, gql
from gql.transport.aiohttp import AIOHTTPTransport
from typing import Dict, Any, Optional
from yarl import URL

logger = logging.getLogger()
logger.setLevel(logging.INFO)

class SigV4Transport(AIOHTTPTransport):
    def __init__(self, client, **kwargs):
        super().__init__(**kwargs)
        self.client = client
        self.session = None

    async def connect(self):
        if self.session is None:
            self.session = aiohttp.ClientSession()
        return self

    async def execute(self, document, variable_values=None, operation_name=None):
        query = document.loc.source.body
        payload = {
            'query': query,
            'variables': variable_values or {}
        }
        if operation_name:
            payload['operationName'] = operation_name

        payload_str = json.dumps(payload)
        headers = self.client._get_request_headers('POST', self.url, payload_str)

        try:
            async with self.session.post(
                self.url,
                data=payload_str,
                headers=headers
            ) as response:
                response.raise_for_status()
                result = await response.json()
                logger.info(f"SigV4Transport execute response: {json.dumps(result, indent=2)}")
                
                if 'errors' in result:
                    logger.error(f"GraphQL errors: {json.dumps(result['errors'])}")
                    raise Exception(f"GraphQL errors: {json.dumps(result['errors'])}")
                    
                return result
        except Exception as e:
            logger.error(f"Error executing GraphQL request: {str(e)}")
            raise

    async def disconnect(self):
        if self.session:
            await self.session.close()
            self.session = None

class AppSyncClient:
    """Generic AppSync GraphQL client with SigV4 authentication"""
    
    def __init__(self, api_url: str, api_key: Optional[str] = None, region: Optional[str] = None):
        """
        Initialize AppSync client with either API Key or SigV4 authentication
        
        Args:
            api_url: AppSync API endpoint URL
            api_key: AppSync API Key (optional, if not provided will use SigV4)
            region: AWS region (optional, defaults to session region)
        """
        if not api_url:
            raise ValueError("AppSync API URL is required")
            
        self.api_url = api_url
        self.api_key = api_key
        
        # API Keyが提供されない場合はSigV4認証を使用
        if not self.api_key:
            self.session = boto3.Session()
            self.credentials = self.session.get_credentials()
            self.region = region or self.session.region_name or 'us-east-1'
            self.service = 'appsync'
        
        self.transport = None
        self.client = None

    def _get_request_headers(self, method: str, url: str, data: str = None) -> Dict[str, str]:
        """
        Get request headers with appropriate authentication
        
        Args:
            method: HTTP method
            url: Request URL
            data: Request body
            
        Returns:
            Dict of headers with authentication
        """
        headers = {'Content-Type': 'application/json'}
        
        if self.api_key:
            # API Key認証を使用
            headers['x-api-key'] = self.api_key
        else:
            # SigV4認証を使用
            request = AWSRequest(
                method=method,
                url=url,
                data=data
            )
            
            # Add host header required for SigV4
            url_parts = URL(url)
            request.headers.add_header('host', url_parts.host)
            
            SigV4Auth(self.credentials, self.service, self.region).add_auth(request)
            headers.update(dict(request.headers))
            
        return headers

    async def connect(self):
        """Establish connection to AppSync"""
        if self.api_key:
            # API Key認証の場合は標準のAIOHTTPTransportを使用
            headers = {
                'Content-Type': 'application/json',
                'x-api-key': self.api_key
            }
            self.transport = AIOHTTPTransport(
                url=self.api_url,
                headers=headers
            )
        else:
            # SigV4認証の場合はカスタムトランスポートを使用
            self.transport = SigV4Transport(
                client=self,
                url=self.api_url,
                headers={'Content-Type': 'application/json'}
            )
        
        self.client = Client(
            transport=self.transport,
            fetch_schema_from_transport=False
        )
        
        return self

    async def disconnect(self):
        """Close connection"""
        if isinstance(self.transport, SigV4Transport):
            await self.transport.disconnect()
        elif hasattr(self.transport, 'session') and self.transport.session:
            await self.transport.session.close()

    async def execute_mutation(self, mutation_str: str, variables: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Execute GraphQL mutation
        
        Args:
            mutation_str: GraphQL mutation string
            variables: Mutation variables
            
        Returns:
            Mutation response data
        """
        try:
            mutation = gql(mutation_str)
            async with self.client as session:
                result = await session.execute(mutation, variable_values=variables or {})
                logger.info(f"Execute mutation result: {json.dumps(result, indent=2)}")
                logger.info(f"Result type: {type(result)}")
                if not isinstance(result, dict):
                    raise Exception(f"Unexpected response format: {result}")
                if 'errors' in result:
                    logger.error(f"GraphQL errors: {json.dumps(result['errors'])}")
                    raise Exception(f"GraphQL errors: {json.dumps(result['errors'])}")
                return result.get('data', {})
        except Exception as e:
            logger.error(f"Error executing mutation: {str(e)}")
            raise

    async def execute_query(self, query_str: str, variables: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Execute GraphQL query
        
        Args:
            query_str: GraphQL query string
            variables: Query variables
            
        Returns:
            Query response data
        """
        try:
            query = gql(query_str)
            async with self.client as session:
                result = await session.execute(query, variable_values=variables or {})
                if not isinstance(result, dict):
                    raise Exception(f"Unexpected response format: {result}")
                if 'errors' in result:
                    logger.error(f"GraphQL errors: {json.dumps(result['errors'])}")
                    raise Exception(f"GraphQL errors: {json.dumps(result['errors'])}")
                return result.get('data', {})
        except Exception as e:
            logger.error(f"Error executing query: {str(e)}")
            raise

    @staticmethod
    def format_error(error: Exception) -> Dict[str, str]:
        """
        Format error response
        
        Args:
            error: Exception object
            
        Returns:
            Formatted error dict
        """
        return {
            "message": str(error),
            "type": error.__class__.__name__
        }