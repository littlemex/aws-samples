# モデルパッケージのグループを作成する

import time
import os
from sagemaker import get_execution_role, session
import boto3

region = boto3.Session().region_name

role = get_execution_role()

sm_client = boto3.client('sagemaker', region_name=region)

model_package_group_name = "scikit-iris-detector-" + str(round(time.time()))
model_package_group_input_dict = {
 "ModelPackageGroupName" : model_package_group_name,
 "ModelPackageGroupDescription" : "Sample model package group"
}

create_model_pacakge_group_response = sm_client.create_model_package_group(**model_package_group_input_dict)
print('ModelPackageGroup Arn : {}'.format(create_model_pacakge_group_response['ModelPackageGroupArn']))

# ListModelPackageGroups

model_package_groups = sm_client.list_model_package_groups()
print('ModelPackageGroups : {}'.format(model_package_groups))