# モデルバージョンの登録

import time
import os
from sagemaker import get_execution_role, session, image_uris
import boto3

region = boto3.Session().region_name
print(region)

role = get_execution_role()

sm_client = boto3.client('sagemaker', region_name=region)

# モデルグループの作成時に生成された名前
model_package_group_name = 'scikit-iris-detector-1640068854'

model_packages = sm_client.list_model_packages(
    MaxResults=10,
    ModelPackageGroupName=model_package_group_name,
)

model_package_arn = model_packages['ModelPackageSummaryList'][0]['ModelPackageArn']

model_package_update_input_dict = {
    "ModelPackageArn" : model_package_arn,
    "ModelApprovalStatus" : "Approved"
}
model_package_update_response = sm_client.update_model_package(**model_package_update_input_dict)

model_package = sm_client.describe_model_package(
    ModelPackageName=model_package_arn
)
print('Model Package : {}'.format(model_package))