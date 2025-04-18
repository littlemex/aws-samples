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
from typing import Dict, Any, Optional, Union, Tuple, List, Protocol, Literal

# イベントログのストラテジー
class MLflowEventStrategy(Protocol):
    def prepare_tags(self, base_tags: Dict[str, str], **kwargs) -> Dict[str, str]:
        """タグの準備"""
        pass

    def prepare_artifacts(self, mlflow: Any, **kwargs) -> None:
        """アーティファクトの記録"""
        pass

class SuccessEventStrategy:
    def prepare_tags(self, base_tags: Dict[str, str], **kwargs) -> Dict[str, str]:
        tags = base_tags.copy()
        tags["status"] = "success"
        return tags

    def prepare_artifacts(self, mlflow: Any, **kwargs) -> None:
        messages = kwargs.get("messages", [])
        if messages:
            prompt_text = "\n".join([f"{m.get('role', 'unknown')}: {m.get('content', '')}" for m in messages])
            mlflow.log_text(prompt_text, "prompt.txt")

        response_obj = kwargs.get("response_obj")
        if response_obj and "choices" in response_obj and response_obj["choices"]:
            response_text = response_obj["choices"][0].get("message", {}).get("content", "")
            mlflow.log_text(response_text, "response.txt")

class FailureEventStrategy:
    def prepare_tags(self, base_tags: Dict[str, str], **kwargs) -> Dict[str, str]:
        tags = base_tags.copy()
        tags["status"] = "failure"
        exception_event = kwargs.get("exception")
        if exception_event:
            tags["error_type"] = type(exception_event).__name__
        return tags

    def prepare_artifacts(self, mlflow: Any, **kwargs) -> None:
        exception_event = kwargs.get("exception")
        if exception_event:
            mlflow.log_text(str(exception_event), "error.txt")

        traceback_event = kwargs.get("traceback_exception")
        if traceback_event:
            mlflow.log_text(str(traceback_event), "traceback.txt")

# ロガーの設定
logger = logging.getLogger("mlflow_callback")
logger.setLevel(logging.DEBUG)
handler = logging.StreamHandler()
handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
logger.addHandler(handler)

# MLflow のデバッグログを有効化
logging.getLogger('mlflow').setLevel(logging.DEBUG)
logging.getLogger('botocore').setLevel(logging.DEBUG)

def get_mlflow_tracking_server_info() -> Tuple[Optional[str], Optional[str]]:
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
    # メトリクス定義
    METRICS_CONFIG = {
        'required': ['model', 'latency_ms'],
        'optional': ['cost_usd', 'total_tokens'],
        'computed': {
            'prompt_tokens': lambda usage: usage.get('prompt_tokens', 0),
            'completion_tokens': lambda usage: usage.get('completion_tokens', 0),
            'total_tokens': lambda usage: usage.get('total_tokens', 0),
        }
    }

    # タグ定義
    TAGS_CONFIG = {
        'required': ['status', 'model_provider'],
        'optional': ['request_id', 'user_id'],
        'metadata_mapping': {
            'user_id': 'user_api_key_user_id',
            'team_alias': 'user_api_key_team_alias',
            'cache_hit': 'cache_hit',
            'cache_key': 'cache_key',
            'api_key_alias': 'user_api_key_alias',
            'user_email': 'user_api_key_user_email',
            'end_user_id': 'user_api_key_end_user_id',
            'model_group': 'model_group',
            'deployment': 'deployment'
        }
    }

    # 認証設定
    AUTH_CONFIG = {
        'providers': {
            'iam_role': lambda config: MLflowCallback._setup_iam_role_auth(config),
            'access_key': lambda config: MLflowCallback._setup_access_key_auth(config)
        },
        'default': 'access_key'
    }

    @staticmethod
    def _setup_iam_role_auth(config: Dict[str, Any]) -> Dict[str, Any]:
        """IAM Role 認証の設定"""
        role_arn = os.getenv("AWS_ROLE_ARN")
        if not role_arn:
            logger.warning("AWS_ROLE_ARN が設定されていません")
        return {
            'type': 'iam_role',
            'role_arn': role_arn,
            'region': os.getenv("AWS_REGION_NAME", "us-east-1")
        }

    @staticmethod
    def _setup_access_key_auth(config: Dict[str, Any]) -> Dict[str, Any]:
        """Access Key 認証の設定"""
        return {
            'type': 'access_key',
            'access_key': os.getenv("AWS_ACCESS_KEY_ID"),
            'secret_key': os.getenv("AWS_SECRET_ACCESS_KEY"),
            'region': os.getenv("AWS_REGION_NAME", "us-east-1")
        }

    def __init__(self):
        """MLflow コールバックの初期化"""
        # OpenTelemetry の experiment_id キャッシュ
        self._otel_experiment_id = None
        
        
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

            # 6. 実験の設定と OpenTelemetry の初期化
            mlflow.set_experiment(experiment_name)
            logger.info(f"実験 '{experiment_name}' を設定しました")
            self.experiment_name = experiment_name

            # 実験 ID を取得して OpenTelemetry の span 属性に設定
            try:
                experiment = mlflow.get_experiment_by_name(experiment_name)
                if experiment:
                    experiment_id = experiment.experiment_id
                    span = mlflow.get_current_active_span()
                    if span:
                        span.set_attribute("mlflow.experimentId", experiment_id)
                        logger.debug(f"OpenTelemetry span 属性に experiment_id を設定: {experiment_id}")
                        self._otel_experiment_id = experiment_id
            except Exception as e:
                logger.debug(f"OpenTelemetry span 属性の初期設定に失敗: {str(e)}")

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

    def _get_auth_config(self) -> Dict[str, Any]:
        """認証設定の取得"""
        auth_type = os.getenv("MLFLOW_AUTH_TYPE", self.AUTH_CONFIG['default'])
        if auth_type not in self.AUTH_CONFIG['providers']:
            raise ValueError(f"Unsupported auth type: {auth_type}")
        return self.AUTH_CONFIG['providers'][auth_type]({})

    def _get_nested_metadata(self, metadata: Dict[str, Any], key: str, default: Any = None) -> Any:
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

    def _prepare_tag_value(self, value: Any) -> str:
        """タグの値を適切な形式に変換"""
        if value is None:
            return "none"  # MLflowではNoneを文字列として扱う
        if isinstance(value, (dict, list)):
            try:
                return str(value)
            except:
                return "invalid_value"
        return str(value)

    def _extract_metadata_tags(self, metadata: Dict[str, Any], target_tags: Optional[Dict[str, str]] = None) -> Dict[str, str]:
        """メタデータからタグを抽出"""
        tags = {}
        # メタデータのマッピングを使用
        for tag_name, metadata_key in self.TAGS_CONFIG['metadata_mapping'].items():
            value = self._get_nested_metadata(metadata, metadata_key)
            if value is not None:  # Noneの場合はスキップ
                tag_value = self._prepare_tag_value(value)
                tags[tag_name] = tag_value
                logger.debug(f"タグを追加: {tag_name}={tag_value} (元のキー: {metadata_key})")
        return tags

    def _log_common_metrics(self, kwargs: Dict[str, Any], response_obj: Optional[Dict[str, Any]], 
                          start_time: Union[datetime, float], end_time: Union[datetime, float]) -> Tuple[Dict[str, Any], Dict[str, float], str]:
        """共通メトリクスのロギング"""
        # 基本情報の取得
        model = kwargs.get("model", "unknown")
        user = kwargs.get("user", "unknown")
        
        # リクエスト情報
        litellm_params = kwargs.get("litellm_params", {})
        
        # レスポンス情報（成功時のみ）
        metrics = {}
        
        # 必須メトリクス
        try:
            latency = self._calculate_latency(start_time, end_time)
            metrics["latency_ms"] = latency
        except Exception as e:
            logger.warning(f"latency の計算に失敗: {str(e)}、デフォルト値を使用します")
            metrics["latency_ms"] = 0.0
        
        # MLflow に記録するパラメータ
        params = {
            "model": model,
            "user": user,
            "temperature": kwargs.get("temperature", 0.7),
            "max_tokens": kwargs.get("max_tokens", 0),
            "deployment_env": "aws" if self.is_aws else "local",
        }
        
        # 使用量とコスト（成功時のみ）
        if response_obj and isinstance(response_obj, dict):
            usage = response_obj.get("usage", {})
            # 計算メトリクスの追加
            for metric_name, compute_fn in self.METRICS_CONFIG['computed'].items():
                try:
                    metrics[metric_name] = compute_fn(usage)
                except Exception as e:
                    logger.warning(f"メトリクス {metric_name} の計算に失敗: {str(e)}")
            
            # コスト計算
            try:
                cost = litellm.completion_cost(completion_response=response_obj)
                metrics["cost_usd"] = cost
            except Exception as e:
                logger.warning(f"コストの計算に失敗: {str(e)}")
        
        return params, metrics, model

    def _set_otel_experiment_id(self, experiment_id: str) -> None:
        """OpenTelemetry の span 属性に experiment_id を設定"""
        try:
            span = mlflow.get_current_active_span()
            if span:
                span.set_attribute("mlflow.experimentId", experiment_id)
                logger.debug(f"OpenTelemetry span 属性に experiment_id を設定: {experiment_id}")
        except Exception as e:
            logger.debug(f"OpenTelemetry span 属性の設定に失敗: {str(e)}")

    def _get_otel_experiment_id(self) -> Optional[str]:
        """OpenTelemetry の span 属性から experiment_id を取得"""
        try:
            span = mlflow.get_current_active_span()
            if span:
                experiment_id = span.attributes.get("mlflow.experimentId")
                if experiment_id:
                    logger.debug(f"OpenTelemetry span 属性から experiment_id を取得: {experiment_id}")
                    return experiment_id
                
                # experiment_id が存在しない場合、現在の実験 ID を設定
                experiment = mlflow.get_experiment_by_name(self.experiment_name)
                if experiment:
                    experiment_id = experiment.experiment_id
                    self._set_otel_experiment_id(experiment_id)
                    return experiment_id
                logger.debug("OpenTelemetry span 属性が存在しません")
        except Exception as e:
            logger.debug(f"OpenTelemetry span 属性の取得に失敗: {str(e)}")
        return None

    def _get_cached_otel_experiment_id(self) -> Optional[str]:
        """キャッシュされた experiment_id を取得"""
        if self._otel_experiment_id is None:
            self._otel_experiment_id = self._get_otel_experiment_id()
        return self._otel_experiment_id

    def _calculate_latency(self, start_time: Union[datetime, float], end_time: Union[datetime, float]) -> float:
        """レイテンシーの計算"""
        if isinstance(start_time, datetime) and isinstance(end_time, datetime):
            # datetime オブジェクトの場合
            latency = (end_time - start_time).total_seconds() * 1000
        else:
            # Unix タイムスタンプ（float）の場合
            latency = (end_time - start_time) * 1000
        
        return float(latency)

    def _prepare_run_kwargs(self, litellm_params: Dict[str, Any]) -> Tuple[Dict[str, Any], str, Optional[str]]:
        """MLflow run の設定を準備"""
        # litellm_call_id を優先的に使用
        litellm_call_id = litellm_params.get("litellm_call_id")
        logger.debug(f"litellm_call_id: {litellm_call_id}")

        # request ID の取得（フォールバック用）
        request_id = None
        if 'proxy_server_request' in litellm_params:
            headers = litellm_params['proxy_server_request'].get('headers', {})
            request_id = headers.get('x-request-id')
        
        # run_name の設定（優先順位: litellm_call_id > request_id > timestamp）
        run_name = litellm_call_id or request_id or datetime.now().strftime('%Y%m%d-%H%M%S')

        # experiment_id の取得
        experiment_id = None
        try:
            experiment = mlflow.get_experiment_by_name(self.experiment_name)
            if experiment:
                experiment_id = experiment.experiment_id
                logger.debug(f"実験ID: {experiment_id}")

            # キャッシュされた OpenTelemetry の experiment_id を使用
            otel_experiment_id = self._get_cached_otel_experiment_id()
            if otel_experiment_id:
                experiment_id = otel_experiment_id
                logger.debug(f"キャッシュされた OpenTelemetry experiment_id を使用: {experiment_id}")
        except Exception as e:
            logger.error(f"実験IDの取得に失敗: {str(e)}")

        run_kwargs = {"run_name": run_name}
        if experiment_id:
            run_kwargs["experiment_id"] = experiment_id

        return run_kwargs, run_name, request_id

    def _prepare_and_set_tags(self, event_type: Literal["success", "failure"], 
                             base_info: Dict[str, Any], strategy: Union[SuccessEventStrategy, FailureEventStrategy],
                             litellm_params: Optional[Dict[str, Any]] = None, **kwargs) -> None:
        """タグの準備と設定"""
        try:
            base_tags = {
                "model_provider": base_info["model"].split("-")[0] if "-" in base_info["model"] else base_info["model"],
                "request_id": base_info["request_id"],
                "run_id": base_info["run_id"],
                "litellm_call_id": litellm_params.get("litellm_call_id")
            }

            # タグの準備
            tags = strategy.prepare_tags(base_tags, **kwargs)
            
            # メタデータからのタグを追加
            metadata = litellm_params.get("metadata", {})
            metadata_tags = self._extract_metadata_tags(metadata, {})
            tags.update(metadata_tags)

            # タグのフィルタリング
            filtered_tags = {k: v for k, v in tags.items() if v is not None and v != ""}
            
            # 現在のタグとマージ
            run = mlflow.active_run()
            if run:
                current_tags = run.data.tags
                system_tags = {k: v for k, v in current_tags.items() if k.startswith("mlflow.")}
                custom_tags = {k: v for k, v in filtered_tags.items() if not k.startswith("mlflow.")}
                final_tags = {**system_tags, **custom_tags}
                
                mlflow.set_tags(final_tags)
                logger.debug("タグを設定しました")
        except Exception as e:
            logger.error(f"タグの設定に失敗: {str(e)}")
            logger.debug("詳細なエラー情報:", exc_info=True)

    async def _log_event_base(
        self,
        event_type: Literal["success", "failure"],
        kwargs: Dict[str, Any],
        response_obj: Optional[Dict[str, Any]],
        start_time: Union[datetime, float],
        end_time: Union[datetime, float]
    ) -> None:
        """イベントログの基底メソッド"""
        try:
            logger.debug(f"{event_type}イベントのログ記録を開始")
            
            # 基本情報の準備
            params, metrics, model = self._log_common_metrics(kwargs, response_obj, start_time, end_time)
            litellm_params = kwargs.get("litellm_params", {})
            
            # run の設定を準備
            run_kwargs, run_name, request_id = self._prepare_run_kwargs(litellm_params)
            logger.info(f"MLflow run開始 ({event_type}, litellm_call_id: {run_name})")

            # MLflow run の実行
            with mlflow.start_run(**run_kwargs) as run:
                run_id = run.info.run_id
                logger.debug(f"Run ID: {run_id}")
                
                # パラメータとメトリクスの記録
                mlflow.log_params(params)
                mlflow.log_metrics(metrics)
                
                # イベント固有のストラテジーを選択
                strategy = SuccessEventStrategy() if event_type == "success" else FailureEventStrategy()
                
                # タグの設定
                base_info = {"model": model, "request_id": request_id, "run_id": run_id}
                # litellm_params を kwargs から削除してから渡す
                kwargs_copy = kwargs.copy()
                if "litellm_params" in kwargs_copy:
                    del kwargs_copy["litellm_params"]
                self._prepare_and_set_tags(event_type, base_info, strategy, litellm_params=litellm_params, **kwargs_copy)
                
                # イベント固有のアーティファクトを記録
                strategy.prepare_artifacts(mlflow, response_obj=response_obj, **kwargs)
                
                logger.info(f"MLflow: モデル {model} の {event_type} イベントを記録しました")
                
        except Exception as e:
            logger.error(f"MLflow {event_type} イベントのログ記録中にエラー発生: {str(e)}")
            logger.debug("詳細なエラー情報:", exc_info=True)

    async def async_log_success_event(self, kwargs: Dict[str, Any], response_obj: Dict[str, Any],
                                    start_time: Union[datetime, float], end_time: Union[datetime, float]) -> None:
        """成功時の非同期ロギング"""
        await self._log_event_base("success", kwargs, response_obj, start_time, end_time)

    async def async_log_failure_event(self, kwargs: Dict[str, Any], response_obj: Optional[Dict[str, Any]],
                                    start_time: Union[datetime, float], end_time: Union[datetime, float]) -> None:
        """失敗時の非同期ロギング"""
        await self._log_event_base("failure", kwargs, response_obj, start_time, end_time)

# MLflow コールバックのインスタンス
mlflow_callback_instance = MLflowCallback()

__all__ = ["MLflowCallback", "mlflow_callback_instance"]
