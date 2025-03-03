import json
import logging
import asyncio
import os
from datetime import datetime
from typing import Dict, Any, Optional
from appsync_client import AppSyncClient

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# 環境変数からAPI Keyを取得
APPSYNC_API_KEY = os.environ.get('APPSYNC_API_KEY')

class JobStatus:
    """Job status constants"""
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"

class InferenceService:
    """Service for handling inference jobs"""

    UPDATE_STATUS_MUTATION = """
    mutation UpdateInferenceStatus($input: UpdateStatusInput!) {
        updateInferenceStatus(input: $input) {
            jobId
            status
            startTime
            endTime
            result
            error
        }
    }
    """

    def __init__(self, appsync_url: str):
        """
        Initialize inference service
        
        Args:
            appsync_url: AppSync API endpoint URL
        """
        self.client = AppSyncClient(appsync_url, api_key=APPSYNC_API_KEY)
        self.valid_models = ['anthropic.claude-v2', 'anthropic.claude-instant-v1']

    async def update_job_status(
        self,
        job_id: str,
        status: str,
        result: Optional[str] = None,
        error: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Update job status in AppSync
        
        Args:
            job_id: Unique job identifier
            status: New job status
            result: Optional result data
            error: Optional error message
            
        Returns:
            Updated job data
        """
        variables = {
            "input": {
                "jobId": job_id,
                "status": status,
                "result": result,
                "error": error
            }
        }

        try:
            logger.info(f"Updating status for job {job_id} to {status}")
            await self.client.connect()
            logger.info(f"Executing mutation with variables: {json.dumps(variables, indent=2)}")
            response = await self.client.execute_mutation(
                self.UPDATE_STATUS_MUTATION,
                variables
            )
            logger.info(f"Raw mutation response: {json.dumps(response, indent=2)}")
            
            result = response.get('updateInferenceStatus', {})
            logger.info(f"Processed response for job {job_id}: {json.dumps(result, indent=2)}")
            
            return result
        except Exception as e:
            logger.error(f"Failed to update status for job {job_id}: {str(e)}")
            raise
        finally:
            await self.client.disconnect()

    def validate_input(self, event: Dict[str, Any]) -> None:
        """
        Validate inference input parameters
        
        Args:
            event: Input event data
            
        Raises:
            ValueError: If validation fails
        """
        prompt = event.get('prompt')
        model = event.get('model')
        
        if not prompt or not model:
            raise ValueError("Missing required fields: prompt and model")
            
        if model not in self.valid_models:
            raise ValueError(f"Invalid model: {model}. Must be one of {self.valid_models}")

    async def process_inference(
        self,
        job_id: str,
        event: Dict[str, Any]
    ) -> None:
        """
        Process inference request
        
        Args:
            job_id: Unique job identifier
            event: Input event data containing inference parameters
        """
        try:
            # Validate input
            self.validate_input(event)
            
            process_time = event.get('processTime', 0)
            model = event.get('model')
            
            logger.info(f"Processing inference request - jobId: {job_id}, model: {model}")
            
            # Update to PROCESSING status
            await self.update_job_status(job_id, JobStatus.PROCESSING)
            
            # Simulate processing time if specified
            # FIXME: 今は実装しないが今後の実装として Bedrock へのアクセスを行う
            if process_time > 0:
                logger.info(f"Simulating processing time of {process_time} seconds")
                await asyncio.sleep(process_time)
            
            # Generate result
            result = {
                "message": "Inference completed successfully",
                "timestamp": datetime.utcnow().isoformat()
            }
            
            # Update to COMPLETED status with result
            await self.update_job_status(
                job_id,
                JobStatus.COMPLETED,
                result=json.dumps(result)
            )
            
        except Exception as e:
            logger.error(f"Error in process_inference: {str(e)}")
            # Update to FAILED status with error
            await self.update_job_status(
                job_id,
                JobStatus.FAILED,
                error=str(e)
            )
            raise

    async def initialize_job(self, job_id: str) -> None:
        """
        Initialize job with PENDING status
        
        Args:
            job_id: Unique job identifier
        """
        try:
            await self.update_job_status(job_id, JobStatus.PENDING)
            logger.info(f"Initialized job {job_id} with PENDING status")
        except Exception as e:
            logger.error(f"Failed to initialize job {job_id}: {str(e)}")
            raise

    async def handle_job(self, event: Dict[str, Any]) -> None:
        """
        Handle inference job from start to finish
        
        Args:
            event: Input event data
        """
        job_id = event.get('jobId')
        if not job_id:
            raise ValueError("jobId is required but not provided")
            
        try:
            # Initialize job with PENDING status
            await self.initialize_job(job_id)
            
            # Process the inference request
            await self.process_inference(job_id, event)
            
        except Exception as e:
            logger.error(f"Error handling job {job_id}: {str(e)}")
            # Ensure job is marked as failed
            await self.update_job_status(job_id, JobStatus.FAILED, error=str(e))
            raise