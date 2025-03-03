import asyncio
import json
import logging
import os
from typing import Dict, Any
from inference_service import InferenceService

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Get AppSync API URL from environment
APPSYNC_API_URL = os.environ.get('APPSYNC_API_URL')
if not APPSYNC_API_URL:
    raise ValueError("APPSYNC_API_URL environment variable is required")

def format_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """
    Format Lambda response
    
    Args:
        status_code: HTTP status code
        body: Response body
        
    Returns:
        Formatted response dictionary
    """
    return {
        'statusCode': status_code,
        'body': json.dumps(body)
    }

async def async_handler(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Async Lambda handler implementation
    
    Args:
        event: Lambda event data
        
    Returns:
        Lambda response
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Initialize service
        service = InferenceService(APPSYNC_API_URL)
        
        # Handle the inference job
        await service.handle_job(event)
        
        # For async invocations, we return immediately after job is initialized
        # このレスポンスは非同期実行の場合 appsync で受け取らないのであってもなくても変わらない
        return format_response(202, {
            "message": "Job accepted",
            "jobId": event.get('jobId')
        })
        
    except ValueError as e:
        # Handle validation errors
        logger.error(f"Validation error: {str(e)}")
        return format_response(400, {
            "error": "Validation Error",
            "message": str(e)
        })
        
    except Exception as e:
        # Handle unexpected errors
        logger.error(f"Unexpected error: {str(e)}")
        return format_response(500, {
            "error": "Internal Server Error",
            "message": "An unexpected error occurred"
        })

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler function
    
    This is the entry point for the Lambda function. It sets up the async
    event loop and runs the async handler.
    
    Args:
        event: Lambda event data
        context: Lambda context
        
    Returns:
        Lambda response
    """
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        return loop.run_until_complete(async_handler(event))
    except Exception as e:
        logger.error(f"Critical error in handler: {str(e)}")
        return format_response(500, {
            "error": "Critical Error",
            "message": "A critical error occurred"
        })
    finally:
        loop.close()