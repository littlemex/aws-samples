import os
import boto3
from sagemaker.async_inference.async_inference_config import AsyncInferenceConfig
from sagemaker.model import Model
import argparse
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

def delete_endpoint_if_exists(sagemaker_client, endpoint_name):
    """
    既存のエンドポイントが存在する場合は削除します
    """
    try:
        sagemaker_client.delete_endpoint(EndpointName=endpoint_name)
        print(f"Deleting existing endpoint: {endpoint_name}")
        waiter = sagemaker_client.get_waiter('endpoint_deleted')
        waiter.wait(EndpointName=endpoint_name)
        print(f"Existing endpoint deleted: {endpoint_name}")
    except sagemaker_client.exceptions.ClientError as e:
        if "Could not find endpoint" in str(e):
            print(f"No existing endpoint found: {endpoint_name}")
        else:
            raise e

def delete_endpoint_config_if_exists(sagemaker_client, endpoint_config_name):
    """
    既存のエンドポイント設定が存在する場合は削除します
    """
    try:
        sagemaker_client.delete_endpoint_config(EndpointConfigName=endpoint_config_name)
        print(f"Deleted existing endpoint configuration: {endpoint_config_name}")
    except sagemaker_client.exceptions.ClientError as e:
        if "Could not find endpoint configuration" in str(e):
            print(f"No existing endpoint configuration found: {endpoint_config_name}")
        else:
            raise e

# FIXME: インスタンスの最小台数を 0, 最大台数を 2 にしてもらえますか。

def deploy_async_endpoint(
    role_arn=os.getenv('SAGEMAKER_ROLE_ARN'),
    image_uri=os.getenv('ECR_REPO'),
    model_name=os.getenv('SAGEMAKER_MODEL_NAME', 'rembg-async-app'),
    endpoint_name=os.getenv('SAGEMAKER_ENDPOINT_NAME', 'rembg-async-app'),
    instance_type=os.getenv('SAGEMAKER_INSTANCE_TYPE', 'ml.g4dn.xlarge'),
    input_bucket=os.getenv('INPUT_BUCKET'),
    output_bucket=os.getenv('OUTPUT_BUCKET'),
    use_gpu=os.getenv('USE_GPU', 'true').lower() == 'true',
    model_data_url=os.getenv('MODEL_DATA_URL')  # S3 URL for model data
):
    """
    Deploy SageMaker Async Inference endpoint for rembg app
    """
    sagemaker_client = boto3.client('sagemaker')
    
    # 既存のエンドポイントとエンドポイント設定を削除
    delete_endpoint_if_exists(sagemaker_client, endpoint_name)
    delete_endpoint_config_if_exists(sagemaker_client, endpoint_name)
    
    # Create model
    model = Model(
        image_uri=image_uri,
        role=role_arn,
        name=model_name,
        model_data=model_data_url,  # S3 path to model data
        env={
            'CUDA_ENABLED': '1' if use_gpu else '0',
            'MODEL_NAME': os.getenv('MODEL_NAME', 'u2net'),
            'MODEL_PATH': '/opt/ml/model'  # SageMaker default model path
        }
    )
    
    # Configure async inference
    async_config = AsyncInferenceConfig(
        output_path=f"s3://{output_bucket}/async-inference-output",
        max_concurrent_invocations_per_instance=int(os.getenv('MAX_CONCURRENT_INVOCATIONS', '4')),
        notification_config={
            "SuccessTopic": os.getenv('SUCCESS_TOPIC_ARN'),
            "ErrorTopic": os.getenv('ERROR_TOPIC_ARN')
        }
    )
    
    # Deploy endpoint with autoscaling
    predictor = model.deploy(
        endpoint_name=endpoint_name,
        instance_type=instance_type,
        initial_instance_count=1,  # Start with 1 instance, will scale down to 0 via auto-scaling
        async_inference_config=async_config,
        wait=True
    )

    # Configure autoscaling
    client = boto3.client('application-autoscaling')
    
    # Register scalable target
    client.register_scalable_target(
        ServiceNamespace='sagemaker',
        ResourceId=f'endpoint/{endpoint_name}/variant/AllTraffic',
        ScalableDimension='sagemaker:variant:DesiredInstanceCount',
        MinCapacity=0,
        MaxCapacity=2
    )
    
    # Configure scaling policy
    client.put_scaling_policy(
        PolicyName=f'{endpoint_name}-scaling-policy',
        ServiceNamespace='sagemaker',
        ResourceId=f'endpoint/{endpoint_name}/variant/AllTraffic',
        ScalableDimension='sagemaker:variant:DesiredInstanceCount',
        PolicyType='TargetTrackingScaling',
        TargetTrackingScalingPolicyConfiguration={
            'TargetValue': 70.0,  # Target utilization of 70%
            'PredefinedMetricSpecification': {
                'PredefinedMetricType': 'SageMakerVariantInvocationsPerInstance'
            },
            'ScaleOutCooldown': 300,  # 5 minutes
            'ScaleInCooldown': 300    # 5 minutes
        }
    )
    
    print(f"Endpoint {endpoint_name} deployed successfully")
    return predictor

def main():
    parser = argparse.ArgumentParser(description='Deploy SageMaker Async Inference Endpoint')
    parser.add_argument('--role-arn', help='SageMaker execution role ARN')
    parser.add_argument('--image-uri', help='ECR image URI')
    parser.add_argument('--model-name', help='Model name')
    parser.add_argument('--endpoint-name', help='Endpoint name')
    parser.add_argument('--instance-type', help='Instance type')
    parser.add_argument('--input-bucket', help='Input S3 bucket')
    parser.add_argument('--output-bucket', help='Output S3 bucket')
    parser.add_argument('--use-gpu', action='store_true', help='Use GPU for inference')
    
    args = parser.parse_args()
    
    # Override environment variables with command line arguments if provided
    deploy_async_endpoint(
        role_arn=args.role_arn or os.getenv('SAGEMAKER_ROLE_ARN'),
        image_uri=args.image_uri or os.getenv('ECR_REPO'),
        model_name=args.model_name or os.getenv('SAGEMAKER_MODEL_NAME', 'rembg-async-app'),
        endpoint_name=args.endpoint_name or os.getenv('SAGEMAKER_ENDPOINT_NAME', 'rembg-async-app'),
        instance_type=args.instance_type or os.getenv('SAGEMAKER_INSTANCE_TYPE', 'ml.g4dn.xlarge'),
        input_bucket=args.input_bucket or os.getenv('INPUT_BUCKET'),
        output_bucket=args.output_bucket or os.getenv('OUTPUT_BUCKET'),
        use_gpu=args.use_gpu if args.use_gpu is not None else os.getenv('USE_GPU', 'true').lower() == 'true',
    )

if __name__ == '__main__':
    main()