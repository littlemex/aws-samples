# デプロイ

import time
import os
from sagemaker import get_execution_role, session, image_uris
import boto3

region = boto3.Session().region_name
print(region)

# role = get_execution_role()
role = 'arn:aws:iam::067150986393:role/service-role/AmazonSageMaker-ExecutionRole-20210318T165329'

sm_client = boto3.client('sagemaker', region_name=region)

model_package_group_name = 'scikit-iris-detector-1640068854'

model_packages = sm_client.list_model_packages(
    MaxResults=10,
    ModelPackageGroupName=model_package_group_name,
)

model_package_arn = model_packages['ModelPackageSummaryList'][0]['ModelPackageArn']

model_name = 'DEMO-modelregistry-model-' + str(round(time.time()))
print("Model name : {}".format(model_name))
container_list = [{'ModelPackageName': model_package_arn}]

create_model_response = sm_client.create_model(
    ModelName = model_name,
    ExecutionRoleArn = role,
    Containers = container_list
)
print("Model arn : {}".format(create_model_response["ModelArn"]))

endpoint_config_name = 'DEMO-modelregistry-EndpointConfig-' + str(round(time.time()))
print(endpoint_config_name)
create_endpoint_config_response = sm_client.create_endpoint_config(
    EndpointConfigName = endpoint_config_name,
    ProductionVariants=[{
        'InstanceType':'ml.m4.xlarge',
        'InitialVariantWeight':1,
        'InitialInstanceCount':1,
        'ModelName':model_name,
        'VariantName':'AllTraffic'}])

endpoint_name = 'DEMO-modelregistry-endpoint-' + str(round(time.time()))
print("EndpointName={}".format(endpoint_name))

create_endpoint_response = sm_client.create_endpoint(
    EndpointName=endpoint_name,
    EndpointConfigName=endpoint_config_name)
print(create_endpoint_response['EndpointArn'])