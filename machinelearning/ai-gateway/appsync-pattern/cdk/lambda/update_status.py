import json
import logging
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Update inference status handler
    
    Parameters:
        event: UpdateStatusInput from AppSync
        context: Lambda context
    
    Returns:
        InferenceStatus object
    """
    try:
        logger.info(f"Received event: {json.dumps(event, indent=2)}")
        
        # Extract input from event
        input_data = event.get('input', {})
        job_id = input_data.get('jobId')
        status = input_data.get('status')
        result = input_data.get('result')
        error = input_data.get('error')
        
        logger.info(f"Extracted input - jobId: {job_id}, status: {status}, result: {result}, error: {error}")

        # Validate required fields
        if not job_id or not status:
            raise ValueError("jobId and status are required")

        # Create response object
        response = {
            "jobId": job_id,
            "status": status,
            "startTime": datetime.utcnow().isoformat(),
            "endTime": datetime.utcnow().isoformat() if status in ["COMPLETED", "FAILED"] else None,
            "result": result,
            "error": error
        }

        # Remove None values
        response = {k: v for k, v in response.items() if v is not None}
        
        logger.info(f"Returning response: {json.dumps(response, indent=2)}")
        return response

    except Exception as e:
        logger.error(f"Error in update_status handler: {str(e)}")
        raise e