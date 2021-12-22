# モデルバージョンの登録

import time
import os
from sagemaker import get_execution_role, session, image_uris
import boto3

region = boto3.Session().region_name
print(region)

role = get_execution_role()

sm_client = boto3.client('sagemaker', region_name=region)

image = image_uris.retrieve(framework='sklearn',region='ap-northeast-1',version='0.23-1',image_scope='inference')

# モデルグループの作成時に生成された名前
model_package_group_name = 'scikit-iris-detector-1640068854'

# トレーニングジョブの実行後に推論生成を実行する方法を定義します
modelpackage_inference_specification =  {
    "InferenceSpecification": {
      "Containers": [
         {
            "Image": image,
         }
      ],
      "SupportedContentTypes": [ "text/csv" ],
      "SupportedResponseMIMETypes": [ "text/csv" ],
   }
 }
# Specify the model source
model_url = "s3://sagemaker-ap-northeast-1-067150986393/sagemaker-xgboost-2021-10-04-03-55-45-191/output/model.tar.gz"

# Specify the model data
modelpackage_inference_specification["InferenceSpecification"]["Containers"][0]["ModelDataUrl"]=model_url

create_model_package_input_dict = {
    "ModelPackageGroupName" : model_package_group_name,
    "ModelPackageDescription" : "Model to detect 3 different types of irises (Setosa, Versicolour, and Virginica)",
    "ModelApprovalStatus" : "PendingManualApproval"
}
create_model_package_input_dict.update(modelpackage_inference_specification)
print('Input Dict : {}'.format(create_model_package_input_dict))

#create_mode_package_response = sm_client.create_model_package(**create_model_package_input_dict)
#model_package_arn = create_mode_package_response["ModelPackageArn"]
#print('ModelPackage Version ARN : {}'.format(model_package_arn))

model_packages = sm_client.list_model_packages(
    # CreationTimeAfter=datetime(2015, 1, 1),
    # CreationTimeBefore=datetime(2015, 1, 1),
    MaxResults=10,
    # NameContains='string',
    # ModelApprovalStatus='Approved'|'Rejected'|'PendingManualApproval',
    ModelPackageGroupName=model_package_group_name,
    # ModelPackageType='Versioned'|'Unversioned'|'Both',
    # NextToken='string',
    # SortBy='Name'|'CreationTime',
    # SortOrder='Ascending'|'Descending'
)
print('Model Packages : {}'.format(model_packages))

model_package = sm_client.describe_model_package(
    ModelPackageName=model_packages['ModelPackageSummaryList'][0]['ModelPackageArn']
)
print('Model Package : {}'.format(model_package))