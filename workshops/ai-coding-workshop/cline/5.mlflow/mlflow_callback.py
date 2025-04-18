#!/usr/bin/env python3
from litellm.integrations.custom_logger import CustomLogger
import litellm
import mlflow
import os
import time
import logging
import boto3
import json
from datetime import datetime

# ロガーの設定
logger = logging.getLogger("mlflow_callback")
logger.setLevel(logging.DEBUG)
handler = logging.StreamHandler()
handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
logger.addHandler(handler)

# MLflow のデバッグログを有効化
logging.getLogger('mlflow').setLevel(logging.DEBUG)
logging.getLogger('botocore').setLevel(logging.DEBUG)

def get_mlflow_tracking_server_info():
    """MLflow トラッキングサーバーの情報を取得"""
    try:
        # boto3 クライアントの初期化
        sagemaker_client = boto3.client('sagemaker')
        
        # サーバー名が環境変数から利用可能な場合
        server_name = os.getenv("MLFLOW_TRACKING_SERVER_NAME")
        if server_name:
            try:
                # describe_mlflow_tracking_server API を使用
                response = sagemaker_client.describe_mlflow_tracking_server(
                    TrackingServerName=server_name
                )
                tracking_uri = response.get('TrackingServerUrl')
                tracking_arn = response.get('TrackingServerArn')
                
                if tracking_uri and tracking_arn:
                    logger.info(f"MLflow Tracking URI: {tracking_uri}")
                    logger.info(f"MLflow Tracking ARN: {tracking_arn}")
                    return tracking_uri, tracking_arn
                    
            except Exception as e:
                logger.error(f"指定されたサーバー {server_name} の情報取得に失敗: {str(e)}")
        
        # サーバー名が利用できない場合は、アクティブなサーバーを検索
        response = sagemaker_client.list_mlflow_tracking_servers(
            TrackingServerStatus='Created'
        )
        
        if not response['TrackingServerSummaries']:
            logger.warning("アクティブな MLflow サーバーが見つかりません")
            return None, None
            
        # 最初のサーバーの情報を取得
        server = response['TrackingServerSummaries'][0]
        tracking_uri = server['TrackingServerUrl']
        tracking_arn = server['TrackingServerArn']
        
        logger.info(f"MLflow Tracking URI: {tracking_uri}")
        logger.info(f"MLflow Tracking ARN: {tracking_arn}")
        
        return tracking_uri, tracking_arn
        
    except Exception as e:
        logger.error(f"MLflow サーバー情報の取得に失敗: {str(e)}")
        logger.debug("詳細なエラー情報:", exc_info=True)
        return None, None

class MLflowCallback(CustomLogger):
    def __init__(self):
        """MLflow コールバックの初期化"""
        try:
            # 1. MLflow サーバー情報の取得
            tracking_uri = os.getenv("MLFLOW_TRACKING_URI")
            tracking_arn = os.getenv("MLFLOW_TRACKING_ARN")
            experiment_name = os.getenv("MLFLOW_EXPERIMENT_NAME", "/litellm-monitoring")

            # 環境変数が設定されていない場合、API から情報を取得
            if not tracking_arn or not tracking_uri:
                logger.info("環境変数から MLflow 情報を取得できません。API を使用して取得を試みます。")
                api_uri, api_arn = get_mlflow_tracking_server_info()
                
                if api_uri and api_arn:
                    tracking_uri = api_uri
                    tracking_arn = api_arn
                    # 環境変数を更新
                    os.environ["MLFLOW_TRACKING_URI"] = tracking_uri
                    os.environ["MLFLOW_TRACKING_ARN"] = tracking_arn
                else:
                    logger.error("MLflow サーバー情報を取得できませんでした")
                    raise ValueError("MLflow Tracking ARN and URI are required")

            # 実験名の確認と修正
            if not experiment_name.startswith("/"):
                experiment_name = f"/{experiment_name}"
                logger.debug(f"実験名を修正: {experiment_name}")

            # 環境変数を明示的に設定
            os.environ["MLFLOW_EXPERIMENT_NAME"] = experiment_name

            logger.debug("MLflow 環境変数:")
            logger.debug(f"MLFLOW_TRACKING_URI: {tracking_uri}")
            logger.debug(f"MLFLOW_TRACKING_ARN: {tracking_arn}")
            logger.debug(f"MLFLOW_EXPERIMENT_NAME: {experiment_name}")

            # 2. sagemaker-mlflow の初期化
            try:
                import sagemaker_mlflow
                from sagemaker_mlflow.mlflow_sagemaker_helpers import validate_and_parse_arn
                from sagemaker_mlflow.auth import AuthBoto
                from sagemaker_mlflow.auth_provider import AuthProvider
                
                # ARN の検証と解析
                try:
                    arn = validate_and_parse_arn(tracking_arn)
                    logger.debug(f"ARN の検証と解析が成功しました: リージョン={arn.region}")
                except Exception as e:
                    logger.error(f"ARN の検証と解析に失敗: {str(e)}")
                    logger.debug("詳細なエラー情報:", exc_info=True)
                    raise
                
                logger.debug("sagemaker-mlflow ライブラリが正常にインポートされました")
            except ImportError as e:
                logger.error(f"sagemaker-mlflow のインポートに失敗: {str(e)}")
                raise

            # 3. 認証プロバイダーの登録
            try:
                from mlflow.tracking.request_auth.registry import RequestAuthProviderRegistry
                registry = RequestAuthProviderRegistry()
                registry.register(AuthProvider)
                logger.debug("認証プロバイダーを登録しました")
                
                # 環境変数 MLFLOW_TRACKING_AUTH を設定（プラグインドキュメントに基づく）
                os.environ["MLFLOW_TRACKING_AUTH"] = "arn"
                logger.debug("MLFLOW_TRACKING_AUTH=arn を設定しました")
            except Exception as e:
                logger.error(f"認証プロバイダーの登録に失敗: {str(e)}")
                logger.debug("詳細なエラー情報:", exc_info=True)
                raise

            # 4. MLflow の設定 - ARN を直接 set_tracking_uri に渡す
            mlflow.set_tracking_uri(tracking_arn)

            # 5. MLflow クライアントの初期化
            from mlflow.tracking import MlflowClient
            self._client = MlflowClient()
            logger.debug("MLflow クライアントを初期化しました")

            # 6. 実験の設定
            mlflow.set_experiment(experiment_name)
            logger.info(f"実験 '{experiment_name}' を設定しました")
            self.experiment_name = experiment_name

            # AWS認証情報の確認
            aws_access_key = os.getenv("AWS_ACCESS_KEY_ID")
            aws_secret_key = os.getenv("AWS_SECRET_ACCESS_KEY")
            aws_region = os.getenv("AWS_REGION_NAME")
            if not all([aws_access_key, aws_secret_key, aws_region]):
                logger.warning("AWS認証情報が不完全です")
            else:
                logger.info(f"AWS Region: {aws_region}")

            # 環境の検出（Local/AWS）
            self.is_aws = "sagemaker" in tracking_arn
            logger.info(f"AWS SageMaker MLflow: {self.is_aws}")

        except Exception as e:
            logger.error(f"MLflow の初期化に失敗: {str(e)}")
            logger.debug("詳細なエラー情報:", exc_info=True)
            raise

    def _get_nested_metadata(self, metadata, key, default=None):
        """ネストされたメタデータから値を取得するヘルパーメソッド"""
        try:
            # ドット記法でネストされたキーをサポート
            keys = key.split('.')
            value = metadata
            for k in keys:
                if isinstance(value, dict):
                    value = value.get(k)
                else:
                    return default
            return value
        except Exception as e:
            logger.debug(f"メタデータ '{key}' の取得に失敗: {str(e)}")
            return default

    def _prepare_tag_value(self, value):
        """タグの値を適切な形式に変換"""
        if value is None:
            return "none"  # MLflowではNoneを文字列として扱う
        if isinstance(value, (dict, list)):
            try:
                return str(value)
            except:
                return "invalid_value"
        return str(value)

    def _extract_metadata_tags(self, metadata, target_tags):
        """メタデータからタグを抽出"""
        tags = {}
        # メタデータのマッピング
        metadata_mapping = {
            "user_id": "user_api_key_user_id",
            "team_alias": "user_api_key_team_alias",
            "cache_hit": "cache_hit",
            "cache_key": "cache_key",
            "api_key_alias": "user_api_key_alias",
            "user_email": "user_api_key_user_email",
            "end_user_id": "user_api_key_end_user_id",
            "model_group": "model_group",
            "deployment": "deployment"
        }
        
        for tag_name, metadata_key in metadata_mapping.items():
            value = self._get_nested_metadata(metadata, metadata_key)
            if value is not None:  # Noneの場合はスキップ
                tag_value = self._prepare_tag_value(value)
                tags[tag_name] = tag_value
                logger.debug(f"タグを追加: {tag_name}={tag_value} (元のキー: {metadata_key})")
        return tags

    def _log_common_metrics(self, kwargs, response_obj, start_time, end_time):
        """共通メトリクスのロギング"""
        # 基本情報の取得
        model = kwargs.get("model", "unknown")
        messages = kwargs.get("messages", [])
        user = kwargs.get("user", "unknown")
        
        # リクエスト情報
        litellm_params = kwargs.get("litellm_params", {})
        metadata = litellm_params.get("metadata", {})
        
        # レスポンス情報（成功時のみ）
        # 時間差を計算してミリ秒に変換（datetime オブジェクトと float の両方に対応）
        try:
            if isinstance(start_time, datetime) and isinstance(end_time, datetime):
                # datetime オブジェクトの場合
                latency = (end_time - start_time).total_seconds() * 1000  # ミリ秒単位
            else:
                # Unix タイムスタンプ（float）の場合
                latency = (end_time - start_time) * 1000  # ミリ秒単位
            
            # 数値型に変換できることを確認
            latency = float(latency)
            logger.debug(f"計算された latency: {latency} ms")
        except Exception as e:
            logger.warning(f"latency の計算に失敗: {str(e)}、デフォルト値を使用します")
            latency = 0.0  # デフォルト値
        
        # MLflow に記録するパラメータとメトリクス
        params = {
            "model": model,
            "user": user,
            "temperature": kwargs.get("temperature", 0.7),
            "max_tokens": kwargs.get("max_tokens", 0),
            "deployment_env": "aws" if self.is_aws else "local",
        }
        
        metrics = {
            "latency_ms": latency,
        }
        
        # 使用量とコスト（成功時のみ）
        if response_obj and isinstance(response_obj, dict) and "usage" in response_obj:
            usage = response_obj["usage"]
            metrics.update({
                "prompt_tokens": usage.get("prompt_tokens", 0),
                "completion_tokens": usage.get("completion_tokens", 0),
                "total_tokens": usage.get("total_tokens", 0),
            })
            
            # コスト計算
            try:
                cost = litellm.completion_cost(completion_response=response_obj)
                metrics["cost_usd"] = cost
            except:
                pass
        
        return params, metrics, model

    async def async_log_success_event(self, kwargs, response_obj, start_time, end_time):
        """成功時の非同期ロギング"""
        try:
            logger.debug("成功イベントのログ記録を開始")
            params, metrics, model = self._log_common_metrics(kwargs, response_obj, start_time, end_time)
            
            # litellm_call_id を優先的に使用
            litellm_params = kwargs.get("litellm_params", {})
            litellm_call_id = litellm_params.get("litellm_call_id")
            logger.debug(f"litellm_call_id: {litellm_call_id}")

            # request ID の取得（フォールバック用）
            request_id = None
            if 'proxy_server_request' in litellm_params:
                headers = litellm_params['proxy_server_request'].get('headers', {})
                request_id = headers.get('x-request-id')
            
            # run_name の設定（優先順位: litellm_call_id > request_id > timestamp）
            run_name = litellm_call_id or request_id or datetime.now().strftime('%Y%m%d-%H%M%S')
            logger.info(f"MLflow run開始 (litellm_call_id: {run_name})")
            
            try:
                # 現在のアクティブな実験を取得
                experiment = mlflow.get_experiment_by_name(self.experiment_name)
                if experiment:
                    experiment_id = experiment.experiment_id
                    logger.debug(f"実験ID: {experiment_id}")
                
                #with mlflow.start_run(run_name=run_name, experiment_id=experiment_id) as run:
                with mlflow.start_run(run_name=run_name) as run:
                    run_id = run.info.run_id
                    logger.debug(f"Run ID: {run_id}")
                    
                    try:
                        # パラメータとメトリクスの記録
                        logger.debug(f"パラメータを記録: {params}")
                        mlflow.log_params(params)
                        
                        logger.debug(f"メトリクスを記録: {metrics}")
                        mlflow.log_metrics(metrics)
                        
                        # メッセージとレスポンスの記録（テキストとして）
                        messages = kwargs.get("messages", [])
                        if messages:
                            prompt_text = "\n".join([f"{m.get('role', 'unknown')}: {m.get('content', '')}" for m in messages])
                            mlflow.log_text(prompt_text, "prompt.txt")
                            logger.debug("プロンプトテキストを記録")
                        
                        if response_obj and "choices" in response_obj and response_obj["choices"]:
                            response_text = response_obj["choices"][0].get("message", {}).get("content", "")
                            mlflow.log_text(response_text, "response.txt")
                            logger.debug("レスポンステキストを記録")
                        
                        # タグの設定
                        tags = {
                            "status": "success",
                            "model_provider": model.split("-")[0] if "-" in model else model,
                            "request_id": request_id,
                            "run_id": run_id,
                            "litellm_call_id": litellm_params.get("litellm_call_id")  # litellm_call_id を追加
                        }

                        # LiteLLM のメタデータからタグを抽出
                        litellm_params = kwargs.get("litellm_params", {})
                        logger.debug(f"LiteLLM パラメータ: {litellm_params}")
                        
                        # メタデータの取得と詳細なログ
                        metadata = litellm_params.get("metadata", {})
                        logger.debug(f"メタデータの完全な構造: {json.dumps(metadata, indent=2, ensure_ascii=False)}")

                        # メタデータからタグを抽出
                        metadata_tags = self._extract_metadata_tags(metadata, {})
                        tags.update(metadata_tags)

                        # タグの最終確認とフィルタリング
                        filtered_tags = {k: v for k, v in tags.items() if v is not None and v != ""}
                        logger.debug(f"フィルタリング後のタグ: {filtered_tags}")
                        
                        # タグの設定（同期的に実行）
                        try:
                            # 現在のタグを取得
                            run = mlflow.active_run()
                            if run:
                                current_tags = run.data.tags
                                logger.debug(f"現在のタグ: {current_tags}")
                                
                                # システムタグを保持
                                system_tags = {k: v for k, v in current_tags.items() if k.startswith("mlflow.")}
                                logger.debug(f"システムタグ: {system_tags}")
                                
                                # カスタムタグを準備
                                custom_tags = {k: v for k, v in filtered_tags.items() if not k.startswith("mlflow.")}
                                logger.debug(f"カスタムタグ: {custom_tags}")
                                
                                # マージしてセット（システムタグを基本にカスタムタグで上書き）
                                final_tags = {**system_tags, **custom_tags}
                                logger.debug(f"マージ後のタグ: {final_tags}")
                                
                                # タグを設定
                                mlflow.set_tags(final_tags)
                                logger.debug("タグを設定しました")
                                
                                # 最終的なタグを確認
                                run = mlflow.active_run()
                                if run:
                                    logger.debug(f"最終的なタグ: {run.data.tags}")
                        except Exception as tag_e:
                            logger.error(f"タグの設定に失敗: {str(tag_e)}")
                            logger.debug("詳細なエラー情報:", exc_info=True)
                        
                    except Exception as inner_e:
                        logger.error(f"MLflow記録処理中にエラー発生: {str(inner_e)}")
                        logger.debug("詳細なエラー情報:", exc_info=True)
                
                logger.info(f"MLflow: モデル {model} の成功イベントを記録しました")
                
            except Exception as run_e:
                logger.error(f"MLflow run開始中にエラー発生: {str(run_e)}")
                logger.debug("詳細なエラー情報:", exc_info=True)
            
        except Exception as e:
            logger.error(f"MLflow成功イベントのログ記録中にエラー発生: {str(e)}")
            logger.debug("詳細なエラー情報:", exc_info=True)

    async def async_log_failure_event(self, kwargs, response_obj, start_time, end_time):
        """失敗時の非同期ロギング"""
        try:
            logger.debug("失敗イベントのログ記録を開始")
            # 基本メトリクスの取得
            params, metrics, model = self._log_common_metrics(kwargs, response_obj, start_time, end_time)
            
            # エラー情報の取得
            exception_event = kwargs.get("exception", None)
            traceback_event = kwargs.get("traceback_exception", None)
            
            # litellm_call_id を優先的に使用（エラー時）
            litellm_params = kwargs.get("litellm_params", {})
            litellm_call_id = litellm_params.get("litellm_call_id")
            logger.debug(f"litellm_call_id (エラー): {litellm_call_id}")

            # request ID の取得（フォールバック用）
            request_id = None
            if 'proxy_server_request' in litellm_params:
                headers = litellm_params['proxy_server_request'].get('headers', {})
                request_id = headers.get('x-request-id')
            
            # run_name の設定（優先順位: litellm_call_id > request_id > timestamp）
            run_name = litellm_call_id or request_id or datetime.now().strftime('%Y%m%d-%H%M%S')
            logger.info(f"MLflow run開始 (エラー, litellm_call_id: {run_name})")
            
            try:
                # 現在のアクティブな実験を取得
                experiment = mlflow.get_experiment_by_name(self.experiment_name)
                experiment_id = None
                if experiment:
                    experiment_id = experiment.experiment_id
                    logger.debug(f"実験ID (エラー): {experiment_id}")
                    
                
                with mlflow.start_run(run_name=run_name, experiment_id=experiment_id) as run:
                    run_id = run.info.run_id
                    logger.debug(f"Run ID (エラー): {run_id}")
                    
                    try:
                        # パラメータとメトリクスの記録
                        logger.debug(f"パラメータを記録: {params}")
                        mlflow.log_params(params)
                        
                        logger.debug(f"メトリクスを記録: {metrics}")
                        mlflow.log_metrics(metrics)
                        
                        # エラー情報の記録
                        if exception_event:
                            mlflow.log_text(str(exception_event), "error.txt")
                            logger.debug(f"エラー情報を記録: {str(exception_event)}")
                        if traceback_event:
                            mlflow.log_text(str(traceback_event), "traceback.txt")
                            logger.debug("トレースバック情報を記録")
                        
                        # タグの設定
                        tags = {
                            "status": "failure",
                            "model_provider": model.split("-")[0] if "-" in model else model,
                            "error_type": type(exception_event).__name__ if exception_event else "unknown",
                            "request_id": request_id,
                            "run_id": run_id,
                            "litellm_call_id": litellm_params.get("litellm_call_id")  # litellm_call_id を追加
                        }

                        # LiteLLM のメタデータからタグを抽出
                        litellm_params = kwargs.get("litellm_params", {})
                        logger.debug(f"LiteLLM パラメータ (エラー): {litellm_params}")
                        
                        # メタデータの取得と詳細なログ
                        metadata = litellm_params.get("metadata", {})
                        logger.debug(f"メタデータの完全な構造 (エラー): {json.dumps(metadata, indent=2, ensure_ascii=False)}")

                        # メタデータからタグを抽出
                        metadata_tags = self._extract_metadata_tags(metadata, {})
                        tags.update(metadata_tags)

                        # タグの最終確認とフィルタリング
                        filtered_tags = {k: v for k, v in tags.items() if v is not None and v != ""}
                        logger.debug(f"フィルタリング後のタグ (エラー): {filtered_tags}")
                        
                        # タグの設定（同期的に実行）
                        try:
                            # 現在のタグを取得
                            run = mlflow.active_run()
                            if run:
                                current_tags = run.data.tags
                                logger.debug(f"現在のタグ (エラー): {current_tags}")
                                
                                # システムタグを保持
                                system_tags = {k: v for k, v in current_tags.items() if k.startswith("mlflow.")}
                                logger.debug(f"システムタグ (エラー): {system_tags}")
                                
                                # カスタムタグを準備
                                custom_tags = {k: v for k, v in filtered_tags.items() if not k.startswith("mlflow.")}
                                logger.debug(f"カスタムタグ (エラー): {custom_tags}")
                                
                                # マージしてセット（システムタグを基本にカスタムタグで上書き）
                                final_tags = {**system_tags, **custom_tags}
                                logger.debug(f"マージ後のタグ (エラー): {final_tags}")
                                
                                # タグを設定
                                mlflow.set_tags(final_tags)
                                logger.debug("タグを設定しました (エラー)")
                                
                                # 最終的なタグを確認
                                run = mlflow.active_run()
                                if run:
                                    logger.debug(f"最終的なタグ (エラー): {run.data.tags}")
                        except Exception as tag_e:
                            logger.error(f"タグの設定に失敗 (エラー): {str(tag_e)}")
                            logger.debug("詳細なエラー情報:", exc_info=True)
                        
                    except Exception as inner_e:
                        logger.error(f"MLflow記録処理中にエラー発生: {str(inner_e)}")
                        logger.debug("詳細なエラー情報:", exc_info=True)
                
                logger.info(f"MLflow: モデル {model} の失敗イベントを記録しました")
                
            except Exception as run_e:
                logger.error(f"MLflow run開始中にエラー発生: {str(run_e)}")
                logger.debug("詳細なエラー情報:", exc_info=True)
            
        except Exception as e:
            logger.error(f"MLflow失敗イベントのログ記録中にエラー発生: {str(e)}")
            logger.debug("詳細なエラー情報:", exc_info=True)

# MLflow コールバックのインスタンス
mlflow_callback_instance = MLflowCallback()

__all__ = ["MLflowCallback", "mlflow_callback_instance"]
