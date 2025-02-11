import os
import boto3
import sagemaker
from sagemaker.async_inference.async_inference_config import AsyncInferenceConfig
from sagemaker.model import Model
import argparse

def deploy_async_endpoint(
    role_arn,
    image_uri,
    model_name="rembg-async",
    endpoint_name="rembg-async",
    instance_type="ml.g4dn.xlarge",
    input_bucket=None,
    output_bucket=None,
    use_gpu=True
):
    """
    Deploy SageMaker Async Inference endpoint for rembg
    """
    sagemaker_session = sagemaker.Session()
    
    # Create model
    model = Model(
        image_uri=image_uri,
        role=role_arn,
        name=model_name,
        env={
            'CUDA_ENABLED': '1' if use_gpu else '0',
            'MODEL_NAME': 'u2net',
            'MODEL_PATH': 'models/unet2.onnx'
        }
    )
    
    # Configure async inference
    async_config = AsyncInferenceConfig(
        output_path=f"s3://{output_bucket}/async-inference-output",
        max_concurrent_invocations_per_instance=4,
        notification_config={
            "SuccessTopic": "arn:aws:sns:us-east-1:067150986393:RembgAsyncInferenceStack-AsyncInferenceTopic75A74962-CLdotJUOym4Z",
            "ErrorTopic": "arn:aws:sns:us-east-1:067150986393:RembgAsyncInferenceStack-AsyncInferenceTopic75A74962-CLdotJUOym4Z"
        }
    )
    
    # Deploy endpoint
    predictor = model.deploy(
        endpoint_name=endpoint_name,
        instance_type=instance_type,
        initial_instance_count=1,
        async_inference_config=async_config,
        wait=True
    )
    
    print(f"Endpoint {endpoint_name} deployed successfully")
    return predictor

def main():
    parser = argparse.ArgumentParser(description='Deploy SageMaker Async Inference Endpoint')
    parser.add_argument('--role-arn', required=True, help='SageMaker execution role ARN')
    parser.add_argument('--image-uri', required=True, help='ECR image URI')
    parser.add_argument('--model-name', default='rembg-async', help='Model name')
    parser.add_argument('--endpoint-name', default='rembg-async', help='Endpoint name')
    parser.add_argument('--instance-type', default='ml.g4dn.xlarge', help='Instance type')
    parser.add_argument('--input-bucket', required=True, help='Input S3 bucket')
    parser.add_argument('--output-bucket', required=True, help='Output S3 bucket')
    parser.add_argument('--use-gpu', action='store_true', help='Use GPU for inference')
    
    args = parser.parse_args()
    
    deploy_async_endpoint(
        role_arn=args.role_arn,
        image_uri=args.image_uri,
        model_name=args.model_name,
        endpoint_name=args.endpoint_name,
        instance_type=args.instance_type,
        input_bucket=args.input_bucket,
        output_bucket=args.output_bucket,
        use_gpu=args.use_gpu
    )

if __name__ == '__main__':
    main()