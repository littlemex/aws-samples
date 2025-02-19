#!/usr/bin/env python3
import os
import time
import boto3
import logging
import mimetypes
from pathlib import Path
from typing import Any
from dotenv import load_dotenv
from abc import ABC, abstractmethod
from sagemaker_client import SageMakerClient

# ロガーの設定
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
# サードパーティライブラリのログレベルを WARNING に設定
logging.getLogger("boto3").setLevel(logging.WARNING)
logging.getLogger("botocore").setLevel(logging.WARNING)
logging.getLogger("urllib3").setLevel(logging.WARNING)
logger = logging.getLogger(__name__)

# .env ファイルから環境変数を読み込む
load_dotenv()


class BackgroundRemovalProcessor(ABC):
    """背景除去処理の基底クラス"""

    def __init__(self):
        self.logger = logging.getLogger(self.__class__.__name__)
        self.sagemaker_client = SageMakerClient()

    @abstractmethod
    def prepare_input(self, input_image_path: str) -> str:
        """入力画像の準備"""
        pass

    @abstractmethod
    def send_inference_request(self, input_location: str, output_location: str) -> Any:
        """推論リクエストの送信"""
        pass

    @abstractmethod
    def wait_for_completion(self, request_info: Any) -> bool:
        """処理完了の待機"""
        pass

    @abstractmethod
    def save_result(self, output_path: Path) -> bool:
        """結果の保存"""
        pass

    def process(self, input_image_path: str, output_path: Path) -> bool:
        """
        背景除去処理の実行

        Args:
            input_image_path: 入力画像のパス
            output_path: ローカル出力先のパス
        Returns:
            bool: 処理が成功したかどうか
        """
        try:
            self.logger.info(f"Processing input file: {input_image_path}")

            # 入力の準備
            input_location = self.prepare_input(input_image_path)
            self.logger.info(f"Input location prepared: {input_location}")
            output_location = str(output_path)
            self.logger.info(f"Local output location prepared: {output_location}")

            # 推論リクエストの送信
            request_info = self.send_inference_request(input_location, output_location)

            # 処理完了の待機
            if not self.wait_for_completion(request_info):
                return False

            # 結果の保存
            return self.save_result(output_path)

        except Exception as e:
            self.logger.exception(f"Error during processing: {str(e)}")
            return False


class LocalBackgroundRemovalProcessor(BackgroundRemovalProcessor):
    """ローカル処理用の実装"""

    def __init__(self):
        super().__init__()
        self.endpoint_name = "local-endpoint"

    def prepare_input(self, input_image_path: str) -> str:
        return f"s3://{input_image_path}"

    def send_inference_request(self, input_location: str, output_location: str) -> Any:
        custom_attributes = f"output_location=s3://{output_location}"

        self.logger.info("Sending async inference request to local endpoint")

        # 入力ファイルのMIMEタイプを取得
        mime_type, _ = mimetypes.guess_type(input_location)
        if not mime_type or not mime_type.startswith("image/"):
            mime_type = "image/jpeg"  # デフォルトのMIMEタイプ

        response = self.sagemaker_client.invoke_endpoint_async(
            EndpointName=self.endpoint_name,
            ContentType=mime_type,
            CustomAttributes=custom_attributes,
            InputLocation=input_location,
        )

        return response

    def wait_for_completion(self, request_info: Any) -> bool:
        return request_info.get("FailureLocation") is None

    def save_result(self, output_path: Path) -> bool:
        self.logger.info(f"Output will be saved to: {output_path}")
        return True


class AWSBackgroundRemovalProcessor(BackgroundRemovalProcessor):
    """AWS処理用の実装"""

    def __init__(self):
        super().__init__()
        self.s3 = boto3.client("s3")
        self.sns = boto3.client("sns")

        # 環境変数の取得
        self.input_bucket = os.environ["INPUT_BUCKET"]
        self.output_bucket = os.environ["OUTPUT_BUCKET"]
        self.success_topic_arn = os.environ["SUCCESS_TOPIC_ARN"]
        self.error_topic_arn = os.environ["ERROR_TOPIC_ARN"]
        self.endpoint_name = os.environ["SAGEMAKER_ENDPOINT_NAME"]

        self.output_key = None
        self.s3_output_location = None

    def prepare_input(self, input_image_path: str) -> str:
        input_key = f"input/{Path(input_image_path).name}"
        self.logger.info(f"Input key prepared: {input_key}")
        self.output_key = f"output/{Path(input_image_path).stem}_output.png"
        self.logger.info(f"Output key prepared: {self.output_key}")

        # S3にアップロード
        with open(input_image_path, "rb") as f:
            self.logger.info(
                f"Uploading input file to S3: {self.input_bucket}/{input_key}"
            )
            self.s3.upload_fileobj(f, self.input_bucket, input_key)

        return f"s3://{self.input_bucket}/{input_key}"

    def send_inference_request(self, input_location: str, output_location: str) -> Any:
        # input_locationからファイル名を抽出し、output_locationを構築
        input_file_name = Path(input_location.split("/")[-1]).stem
        self.s3_output_location = (
            f"{self.output_bucket}/output/{input_file_name}_output.png"
        )
        custom_attributes = f"output_location=s3://{self.s3_output_location}"

        inference_id = str(time.time())
        self.logger.info(
            f"Sending async inference request to endpoint: {self.endpoint_name}"
        )
        self.logger.info(f"Output will be saved to: s3://{self.s3_output_location}")

        # 入力ファイルのMIMEタイプを取得
        mime_type, _ = mimetypes.guess_type(input_location)
        if not mime_type or not mime_type.startswith("image/"):
            mime_type = "image/jpeg"  # デフォルトのMIMEタイプ

        response = self.sagemaker_client.invoke_endpoint_async(
            EndpointName=self.endpoint_name,
            ContentType=mime_type,
            CustomAttributes=custom_attributes,
            InferenceId=inference_id,
            InputLocation=input_location,
            Accept="image/jpeg",
            RequestTTLSeconds=60,
            InvocationTimeoutSeconds=100,
        )

        return response

    def wait_for_completion(self, request_info: Any) -> bool:
        inference_id = request_info["InferenceId"]
        self.logger.info(
            f"Waiting for processing completion. Inference ID: {inference_id}"
        )

        try:
            # S3出力ファイルの存在をポーリング
            MAX_ATTEMPTS = 30
            WAIT_TIME = 2

            for attempt in range(MAX_ATTEMPTS):
                self.logger.info(
                    f"Checking output file existence (attempt {attempt + 1}/{MAX_ATTEMPTS})"
                )

                try:
                    # S3オブジェクトのメタデータを取得してファイルの存在を確認
                    self.s3.head_object(Bucket=self.output_bucket, Key=self.output_key)
                    self.logger.info("Output file found in S3")
                    return True
                except self.s3.exceptions.ClientError as e:
                    if e.response["Error"]["Code"] == "404":
                        if attempt < MAX_ATTEMPTS - 1:
                            self.logger.info(
                                f"Output file not found yet, waiting {WAIT_TIME} seconds..."
                            )
                            time.sleep(WAIT_TIME)
                            continue
                        else:
                            self.logger.error(
                                "Output file not found after maximum attempts"
                            )
                            return False
                    else:
                        self.logger.error(f"Error checking S3 object: {str(e)}")
                        return False

            return False
        except Exception as e:
            self.logger.error(f"Error during wait_for_completion: {str(e)}")
            return False

    def save_result(self, output_path: Path) -> bool:
        try:
            output_path.parent.mkdir(parents=True, exist_ok=True)
            self.logger.info(
                f"Downloading result from S3: {self.output_bucket}/{self.output_key}"
            )
            self.s3.download_file(self.output_bucket, self.output_key, str(output_path))
            self.logger.info(f"Output image saved to: {output_path}")
            return True
        except Exception as e:
            self.logger.error(f"Error saving result: {str(e)}")
            return False


def request_background_removal(
    input_image_path: str, output_dir: str = "outputs"
) -> bool:
    """
    背景除去リクエストを送信し、結果を取得する

    Args:
        input_image_path: 入力画像のパス
        output_dir: 出力ディレクトリ（デフォルト: "outputs"）
    Returns:
        bool: 処理が成功したかどうか
    """
    use_aws = os.getenv("USE_AWS", "false").lower() == "true"
    logger.info(f"Mode: {'AWS' if use_aws else 'Local'}")

    # 処理クラスの選択
    processor = (
        AWSBackgroundRemovalProcessor()
        if use_aws
        else LocalBackgroundRemovalProcessor()
    )

    # 出力パスの準備
    local_output_path = Path(output_dir) / f"{Path(input_image_path).stem}_output.png"
    logger.info(f"Output path prepared: {local_output_path}")

    return processor.process(input_image_path, local_output_path)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="背景除去リクエストを送信")
    parser.add_argument("input_image", help="入力画像のパス")
    parser.add_argument(
        "--output-dir",
        default="local-bucket/outputs",
        help="出力ディレクトリ（デフォルト: local-bucket/outputs）",
    )

    args = parser.parse_args()
    success = request_background_removal(args.input_image, args.output_dir)

    if not success:
        exit(1)
