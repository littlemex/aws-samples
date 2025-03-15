#!/usr/bin/env python3
import json
import argparse
import logging
import sys
import time
import boto3
import sagemaker
from sagemaker.huggingface import HuggingFaceModel, get_huggingface_llm_image_uri


def setup_logging(log_level):
    """ロギングの設定"""
    numeric_level = getattr(logging, log_level.upper(), None)
    if not isinstance(numeric_level, int):
        raise ValueError(f'無効なログレベル: {log_level}')
    
    # ルートロガーのレベルも設定
    logging.getLogger().setLevel(numeric_level)
    
    logging.basicConfig(
        level=numeric_level,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    return logging.getLogger(__name__)

def invoke_endpoint(endpoint_name, prompt, region=None, temperature=0.7, max_tokens=512):
    """SageMaker エンドポイントを呼び出す"""
    logger.info(f"エンドポイント {endpoint_name} を呼び出し中...")
    logger.debug(f"パラメータ: region={region}, temperature={temperature}, max_tokens={max_tokens}")
    
    # リージョンの設定
    if region:
        session = boto3.Session(region_name=region)
        runtime = session.client('sagemaker-runtime')
        logger.debug(f"指定されたリージョン {region} で boto3 セッションを作成")
    else:
        runtime = boto3.client('sagemaker-runtime')
        logger.debug("デフォルトリージョンで boto3 セッションを作成")
    
    # リクエストの作成
    payload = {
        "inputs": prompt,
        "parameters": {
            "max_new_tokens": max_tokens,
            "temperature": temperature,
            "top_p": 0.9,
            "do_sample": True
        }
    }
    logger.debug(f"リクエストペイロード: {json.dumps(payload, ensure_ascii=False)}")
    
    # エンドポイントの呼び出し
    start_time = time.time()
    try:
        response = runtime.invoke_endpoint(
            EndpointName=endpoint_name,
            ContentType='application/json',
            Body=json.dumps(payload)
        )
        end_time = time.time()
        logger.debug("エンドポイントの呼び出しに成功")
        
        # レスポンスの解析
        result = json.loads(response['Body'].read().decode())
        
        # 処理時間の計算
        processing_time = end_time - start_time
        logger.info(f"処理時間: {processing_time:.2f} 秒")
        
        return result, processing_time
    except Exception as e:
        logger.error(f"エンドポイントの呼び出し中にエラーが発生: {str(e)}")
        raise

def main():
    parser = argparse.ArgumentParser(description='SageMaker エンドポイントにリクエストを送信')
    parser.add_argument('--endpoint-name', type=str, required=True,
                      help='SageMaker エンドポイントの名前')
    parser.add_argument('--prompt', type=str, required=True,
                      help='モデルに送信するプロンプト')
    parser.add_argument('--temperature', type=float, default=0.7,
                      help='生成の温度パラメータ (0.0-1.0)')
    parser.add_argument('--max-tokens', type=int, default=512,
                      help='生成する最大トークン数')
    parser.add_argument('--region', type=str,
                      help='AWS リージョン（デフォルト設定を上書き）')
    parser.add_argument('--log-level', type=str, default='INFO',
                      choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
                      help='ロギングレベル')

    global logger
    args = parser.parse_args()
    
    # ロギングの設定
    logger = setup_logging(args.log_level)
    
    # デバッグメッセージの例
    logger.debug("デバッグモードで実行中")
    logger.info(f"コマンドライン引数: {vars(args)}")

    # リージョンの設定
    if args.region:
        boto3.setup_default_session(region_name=args.region)

    try:
        logger.info(f"エンドポイント {args.endpoint_name} に接続を試みます")
        result, processing_time = invoke_endpoint(
            args.endpoint_name,
            args.prompt,
            args.region,
            args.temperature,
            args.max_tokens
        )
        
        print("\n===== 応答 =====")
        if isinstance(result, list) and len(result) > 0:
            # リストの場合は最初の要素を表示
            response_text = result[0].get('generated_text', result[0])
            print(response_text)
            logger.debug(f"応答（リスト形式）: {response_text}")
        elif isinstance(result, dict):
            # 辞書の場合は generated_text を表示
            response_text = result.get('generated_text', result)
            print(response_text)
            logger.debug(f"応答（辞書形式）: {response_text}")
        else:
            # その他の場合はそのまま表示
            print(result)
            logger.debug(f"応答（その他の形式）: {result}")
        
        print(f"\n処理時間: {processing_time:.2f} 秒")
        logger.info("スクリプトが正常に完了しました")
        
    except Exception as e:
        logger.error(f"スクリプト実行中にエラーが発生: {str(e)}", exc_info=True)
        print(f"エラーが発生しました: {e}")

if __name__ == "__main__":
    main()