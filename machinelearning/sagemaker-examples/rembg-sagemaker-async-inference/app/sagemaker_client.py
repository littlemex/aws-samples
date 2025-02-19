#!/usr/bin/env python3
import os
import json
import time
import boto3
import requests
import logging
from typing import Dict, Any

# ロガーの設定
logging.basicConfig(
    level=logging.DEBUG, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class SageMakerClient:
    """SageMaker関連の操作を担当するクラス"""

    def __init__(self):
        """boto3クライアントの初期化"""
        self.sagemaker = boto3.client("sagemaker-runtime")
        self.logger = logging.getLogger(self.__class__.__name__)

    def invoke_endpoint_async(
        self,
        EndpointName: str,
        ContentType: str,
        Accept: str = None,
        CustomAttributes: str = None,
        InferenceId: str = None,
        InputLocation: str = None,
        RequestTTLSeconds: int = None,
        InvocationTimeoutSeconds: int = None,
    ) -> Dict[str, Any]:
        """
        invoke_endpoint_asyncのラッパーメソッド
        ローカル環境の場合はrequests.postに変換する

        Returns:
            Dict[str, Any]: {
                'InferenceId': string,
                'OutputLocation': string,
                'FailureLocation': string (optional)
            }
        """
        if os.getenv("USE_AWS", "false").lower() == "true":
            return self.sagemaker.invoke_endpoint_async(
                EndpointName=EndpointName,
                ContentType=ContentType,
                Accept=Accept,
                CustomAttributes=CustomAttributes,
                InferenceId=InferenceId,
                InputLocation=InputLocation,
                RequestTTLSeconds=RequestTTLSeconds,
                InvocationTimeoutSeconds=InvocationTimeoutSeconds,
            )
        else:
            # ローカル環境用の実装
            if not InputLocation:
                raise ValueError("InputLocation is required")
            if not ContentType:
                raise ValueError("ContentType is required")

            # Validate parameter constraints
            if len(InputLocation) > 1024 or not InputLocation.startswith(
                ("https://", "s3://")
            ):
                raise ValueError("Invalid InputLocation format")
            if InferenceId and (len(InferenceId) < 1 or len(InferenceId) > 64):
                raise ValueError("Invalid InferenceId length")

            # Get endpoint URL from environment variable or use default
            endpoint_host = os.getenv("LOCAL_ENDPOINT_HOST", "localhost:8080")
            url = f"http://{endpoint_host}/invocations"
            headers = {"Content-Type": ContentType}

            # Add optional headers
            if Accept:
                headers["X-Amzn-SageMaker-Accept"] = Accept
            if CustomAttributes:
                headers["X-Amzn-SageMaker-Custom-Attributes"] = CustomAttributes
            if InferenceId:
                headers["X-Amzn-SageMaker-Inference-Id"] = InferenceId

            self.logger.info("Local request details:")
            self.logger.info(f"URL: {url}")
            self.logger.info(f"Headers: {json.dumps(headers, indent=2)}")

            # Convert s3:// path to local path and read image as binary
            local_path = InputLocation.replace("s3://", "")
            try:
                with open(local_path, "rb") as f:
                    body = f.read()
            except FileNotFoundError:
                raise ValueError(f"Image file not found at {local_path}")
            except IOError as e:
                raise ValueError(f"Error reading image file: {str(e)}")

            try:
                response = requests.post(url, headers=headers, data=body)

                if response.status_code == 202:
                    # Extract response headers
                    output_location = response.headers.get(
                        "X-Amzn-SageMaker-OutputLocation"
                    )
                    failure_location = response.headers.get(
                        "X-Amzn-SageMaker-FailureLocation"
                    )

                    # Parse response body
                    response_data = response.json()
                    inference_id = response_data.get(
                        "InferenceId", InferenceId or str(time.time())
                    )

                    result = {"InferenceId": inference_id}

                    if output_location:
                        result["OutputLocation"] = output_location
                    if failure_location:
                        result["FailureLocation"] = failure_location

                    return result

                elif response.status_code == 400:
                    raise ValueError("ValidationError: Invalid request parameters")
                elif response.status_code == 500:
                    raise RuntimeError("InternalFailure: An internal error occurred")
                elif response.status_code == 503:
                    raise RuntimeError(
                        "ServiceUnavailable: The service is temporarily unavailable"
                    )
                else:
                    raise RuntimeError(
                        f"Unexpected status code: {response.status_code}"
                    )

            except requests.exceptions.RequestException as e:
                self.logger.error(f"Request failed: {str(e)}")
                raise RuntimeError(f"Failed to connect to endpoint: {str(e)}")
