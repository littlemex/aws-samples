#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Amazon Bedrock アプリケーション推論プロファイル管理スクリプト
このスクリプトは、Amazon Bedrockの推論プロファイルを作成、管理、テストするための機能を提供します。
"""

import boto3
import json
import logging

# ロギングの設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_inference_profile(profile_name, model_arn, tags):
    """
    推論プロファイルを作成する関数
    
    Args:
        profile_name (str): 作成する推論プロファイルの名前
        model_arn (str): 基となるモデルのARN
        tags (list): プロファイルに付与するタグのリスト [{'key': 'key1', 'value': 'value1'}, ...]
    
    Returns:
        dict: 作成された推論プロファイルの情報
    """
    bedrock_client = boto3.client('bedrock')
    try:
        response = bedrock_client.create_inference_profile(
            inferenceProfileName=profile_name,
            modelSource={
                'copyFrom': model_arn
            },
            description=f"Inference profile for {profile_name}",
            tags=tags
        )
        logger.info(f"推論プロファイルを作成中: {profile_name}")
        return response
    except Exception as e:
        logger.error(f"推論プロファイルの作成中にエラーが発生: {str(e)}")
        raise

def get_inference_profile(inference_profile_arn):
    """
    ARNを指定して推論プロファイルの情報を取得する関数
    
    Args:
        inference_profile_arn (str): 推論プロファイルのARN
    
    Returns:
        dict: 推論プロファイルの詳細情報
    """
    bedrock_client = boto3.client('bedrock')
    try:
        response = bedrock_client.get_inference_profile(
            inferenceProfileIdentifier=inference_profile_arn
        )
        logger.info(f"推論プロファイルを取得: {inference_profile_arn}")
        return response
    except Exception as e:
        logger.error(f"推論プロファイルの取得中にエラーが発生: {str(e)}")
        raise

def list_inference_profiles():
    """
    アプリケーション推論プロファイルの一覧を取得する関数
    
    Returns:
        dict: 推論プロファイルのリスト
    """
    bedrock_client = boto3.client('bedrock')
    try:
        response = bedrock_client.list_inference_profiles(
            typeEquals="APPLICATION"
        )
        logger.info("推論プロファイル一覧を取得")
        return response
    except Exception as e:
        logger.error(f"推論プロファイル一覧の取得中にエラーが発生: {str(e)}")
        raise

def parse_converse_response(response):
    """
    Converse APIのレスポンスを解析する関数
    
    Args:
        response (dict): Converse APIからのレスポンス
    
    Returns:
        dict: 解析された応答データ（テキスト、画像、ドキュメント、ツール使用情報など）
    """
    output = response.get('output', {})
    message = output.get('message', {})
    role = message.get('role')
    contents = message.get('content', [])

    # テキストコンテンツの抽出
    text_content = [item.get('text') for item in contents if 'text' in item]
    
    # 画像データの抽出
    images = [
        {
            'format': item['image']['format'],
            'bytes': item['image']['source']['bytes']
        }
        for item in contents if 'image' in item
    ]
    
    # ドキュメントデータの抽出
    documents = [
        {
            'format': item['document']['format'],
            'name': item['document']['name'],
            'bytes': item['document']['source']['bytes']
        }
        for item in contents if 'document' in item
    ]
    
    # ツール関連情報の抽出
    tool_uses = [item.get('toolUse') for item in contents if 'toolUse' in item]
    tool_results = [item.get('toolResult') for item in contents if 'toolResult' in item]
    guard_content = [item['guardContent'] for item in contents if 'guardContent' in item]
    
    # メタデータの抽出
    stop_reason = response.get('stopReason')
    usage = response.get('usage', {})
    metrics = response.get('metrics', {})
    
    return {
        'role': role,
        'text_content': text_content,
        'images': images,
        'documents': documents,
        'tool_uses': tool_uses,
        'tool_results': tool_results,
        'guard_content': guard_content,
        'stop_reason': stop_reason,
        'usage': usage,
        'metrics': metrics
    }

def converse(model_id, messages):
    """
    Converse APIを使用してモデルと対話する関数
    
    Args:
        model_id (str): 使用するモデルのID
        messages (list): 対話メッセージのリスト
    
    Returns:
        dict: モデルからの応答（parse_converse_responseで解析済み）
    """
    bedrock_runtime = boto3.client('bedrock-runtime')
    try:
        response = bedrock_runtime.converse(
            modelId=model_id,
            messages=messages,
            inferenceConfig={
                'maxTokens': 300,
            }
        )
        logger.info(f"Converse API呼び出しが成功: {model_id}")
        return parse_converse_response(response)
    except Exception as e:
        logger.error(f"Converse API呼び出し中にエラーが発生: {str(e)}")
        raise

def parse_converse_stream_response(response):
    """
    ConverseStream APIのストリーミングレスポンスを解析する関数
    
    Args:
        response (dict): ConverseStream APIからのレスポンス
    
    Returns:
        list: 解析されたイベントのリスト
    """
    parsed_events = []
    stream = response.get('stream')
    
    if stream is None:
        logger.warning("ストリームデータが見つかりません")
        return parsed_events
    
    for event in stream:
        event_type = event.get('eventType')
        event_data = event.get('eventData', {})
        parsed_event = {'type': event_type}
        
        # イベントタイプに応じた処理
        if event_type == 'messageStart':
            parsed_event['role'] = event_data.get('role')
        elif event_type == 'contentBlockStart':
            parsed_event.update({
                'contentBlockIndex': event_data.get('contentBlockIndex'),
                'start': event_data.get('start', {})
            })
        elif event_type == 'contentBlockDelta':
            parsed_event.update({
                'contentBlockIndex': event_data.get('contentBlockIndex'),
                'delta': event_data.get('delta', {})
            })
        elif event_type == 'contentBlockStop':
            parsed_event['contentBlockIndex'] = event_data.get('contentBlockIndex')
        elif event_type == 'messageStop':
            parsed_event.update({
                'stopReason': event_data.get('stopReason'),
                'additionalModelResponseFields': event_data.get('additionalModelResponseFields')
            })
        elif event_type == 'metadata':
            parsed_event.update({
                'usage': event_data.get('usage', {}),
                'metrics': event_data.get('metrics', {}),
                'trace': event_data.get('trace', {})
            })
        
        parsed_events.append(parsed_event)
    
    return parsed_events

def converse_stream(model_id, messages):
    """
    ConverseStream APIを使用してストリーミング形式で対話する関数
    
    Args:
        model_id (str): 使用するモデルのID
        messages (list): 対話メッセージのリスト
    
    Returns:
        list: ストリーミングイベントのリスト（parse_converse_stream_responseで解析済み）
    """
    bedrock_runtime = boto3.client('bedrock-runtime')
    try:
        response = bedrock_runtime.converse_stream(
            modelId=model_id,
            messages=messages,
            inferenceConfig={
                'maxTokens': 300,
            }
        )
        logger.info(f"ConverseStream API呼び出しが成功: {model_id}")
        return parse_converse_stream_response(response)
    except Exception as e:
        logger.error(f"ConverseStream API呼び出し中にエラーが発生: {str(e)}")
        raise

def parse_invoke_model_response(response):
    """
    InvokeModel APIのレスポンスを解析する関数
    
    Args:
        response (dict): InvokeModel APIからのレスポンス
    
    Returns:
        dict: 解析されたレスポンスデータ
    """
    if 'body' in response:
        body_stream = response['body']
        body_content = body_stream.read()
        body_str = body_content.decode('utf-8')
        return json.loads(body_str)
    else:
        logger.warning("レスポンスボディが見つかりません")
        return None

def invoke_model(model_id, body):
    """
    InvokeModel APIを使用してモデルを直接呼び出す関数
    
    Args:
        model_id (str): 使用するモデルのID
        body (dict): モデルへの入力データ
    
    Returns:
        dict: モデルからのレスポンス（parse_invoke_model_responseで解析済み）
    """
    bedrock_runtime = boto3.client('bedrock-runtime')
    try:
        body_bytes = json.dumps(body).encode('utf-8')
        response = bedrock_runtime.invoke_model(
            modelId=model_id,
            body=body_bytes
        )
        logger.info(f"InvokeModel API呼び出しが成功: {model_id}")
        return parse_invoke_model_response(response)
    except Exception as e:
        logger.error(f"InvokeModel API呼び出し中にエラーが発生: {str(e)}")
        raise

def parse_invoke_model_with_stream(response):
    """
    InvokeModelWithResponseStream APIのストリーミングレスポンスを解析する関数
    
    Args:
        response (dict): ストリーミングレスポンス
    
    Returns:
        list: 解析されたレスポンスチャンクのリスト
    """
    output = []
    if 'body' in response:
        body_stream = response['body']
        for event in body_stream:
            if 'chunk' in event:
                event_data = event['chunk']['bytes']
                output.append(json.loads(event_data.decode('utf-8')))
        return output
    else:
        logger.warning("レスポンスボディが見つかりません")
        return None

def invoke_model_with_stream(model_id, body):
    """
    InvokeModelWithResponseStream APIを使用してストリーミング形式でモデルを呼び出す関数
    
    Args:
        model_id (str): 使用するモデルのID
        body (dict): モデルへの入力データ
    
    Returns:
        list: ストリーミングレスポンスのチャンク（parse_invoke_model_with_streamで解析済み）
    """
    bedrock_runtime = boto3.client('bedrock-runtime')
    try:
        body_bytes = json.dumps(body).encode('utf-8')
        response = bedrock_runtime.invoke_model_with_response_stream(
            modelId=model_id,
            body=body_bytes,
            contentType='application/json'
        )
        logger.info(f"InvokeModelWithResponseStream API呼び出しが成功: {model_id}")
        return parse_invoke_model_with_stream(response)
    except Exception as e:
        logger.error(f"InvokeModelWithResponseStream API呼び出し中にエラーが発生: {str(e)}")
        raise

def tag_resource(resource_arn, tags):
    """
    リソースにタグを付与する関数
    
    Args:
        resource_arn (str): タグを付与するリソースのARN
        tags (list): 付与するタグのリスト [{'key': 'key1', 'value': 'value1'}, ...]
    
    Returns:
        dict: タグ付けの結果
    """
    bedrock_client = boto3.client('bedrock')
    try:
        response = bedrock_client.tag_resource(
            resourceARN=resource_arn,
            tags=tags
        )
        logger.info(f"リソースにタグを付与: {resource_arn}")
        return response
    except Exception as e:
        logger.error(f"タグ付け中にエラーが発生: {str(e)}")
        raise

def list_tags(resource_arn):
    """
    リソースのタグ一覧を取得する関数
    
    Args:
        resource_arn (str): タグを取得するリソースのARN
    
    Returns:
        dict: タグのリスト
    """
    bedrock_client = boto3.client('bedrock')
    try:
        response = bedrock_client.list_tags_for_resource(
            resourceARN=resource_arn
        )
        logger.info(f"タグ一覧を取得: {resource_arn}")
        return response
    except Exception as e:
        logger.error(f"タグ一覧の取得中にエラーが発生: {str(e)}")
        raise

def untag_resource(resource_arn, tag_keys):
    """
    リソースからタグを削除する関数
    
    Args:
        resource_arn (str): タグを削除するリソースのARN
        tag_keys (list): 削除するタグのキーのリスト
    
    Returns:
        dict: タグ削除の結果
    """
    bedrock_client = boto3.client('bedrock')
    try:
        response = bedrock_client.untag_resource(
            resourceARN=resource_arn,
            tagKeys=tag_keys
        )
        logger.info(f"リソースからタグを削除: {resource_arn}")
        return response
    except Exception as e:
        logger.error(f"タグ削除中にエラーが発生: {str(e)}")
        raise

def delete_inference_profile(inference_profile_arn):
    """
    推論プロファイルを削除する関数
    
    Args:
        inference_profile_arn (str): 削除する推論プロファイルのARN
    
    Returns:
        dict: 削除操作の結果
    """
    bedrock_client = boto3.client('bedrock')
    try:
        response = bedrock_client.delete_inference_profile(
            inferenceProfileIdentifier=inference_profile_arn
        )
        logger.info(f"推論プロファイルを削除: {inference_profile_arn}")
        return response
    except Exception as e:
        logger.error(f"推論プロファイルの削除中にエラーが発生: {str(e)}")
        raise

def main():
    """
    メイン実行関数
    推論プロファイルの作成、モデル呼び出し、タグ管理のデモンストレーションを行います。
    """
    try:
        # 推論プロファイルの作成（部門別タグ付き）
        logger.info("\n=== 推論プロファイルの作成 ===")
        
        # Claims部門用のClaude 3 Sonnetプロファイル作成
        claude_3_sonnet_arn = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
        claims_dept_claude_profile = create_inference_profile(
            "claims_dept_claude_3_sonnet_profile",
            claude_3_sonnet_arn,
            [{'key': 'dept', 'value': 'claims'}]
        )
        claims_profile_arn = claims_dept_claude_profile['inferenceProfileArn']
        
        # Underwriting部門用のLlama 3プロファイル作成
        llama_3_arn = "arn:aws:bedrock:us-east-1::foundation-model/meta.llama3-70b-instruct-v1:0"
        underwriting_dept_llama_profile = create_inference_profile(
            "underwriting_dept_llama3_70b_profile",
            llama_3_arn,
            [{'key': 'dept', 'value': 'underwriting'}]
        )
        underwriting_profile_arn = underwriting_dept_llama_profile['inferenceProfileArn']

        # モデル呼び出しのテスト
        logger.info("\n=== モデル呼び出しのテスト ===")
        prompt = "Tell me about Amazon Bedrock"
        messages = [{"role": "user", "content": [{"text": prompt}]}]
        
        # Converse APIのテスト
        logger.info("\nConverse APIのテスト...")
        converse_response = converse(claims_profile_arn, messages)
        logger.info(json.dumps(converse_response, indent=2))
        
        # ConverseStream APIのテスト
        logger.info("\nConverseStream APIのテスト...")
        stream_response = converse_stream(claims_profile_arn, messages)
        logger.info(json.dumps(stream_response, indent=2))
        
        # InvokeModel APIのテスト
        logger.info("\nInvokeModel APIのテスト...")
        input_data = {"prompt": prompt}
        invoke_response = invoke_model(underwriting_profile_arn, input_data)
        logger.info(json.dumps(invoke_response, indent=2))
        
        # InvokeModelWithResponseStream APIのテスト
        logger.info("\nInvokeModelWithResponseStream APIのテスト...")
        stream_invoke_response = invoke_model_with_stream(underwriting_profile_arn, input_data)
        logger.info(json.dumps(stream_invoke_response, indent=2))
        
        # タグ管理のテスト
        logger.info("\n=== タグ管理のテスト ===")
        
        # タグ一覧の取得
        logger.info("\nClaims部門プロファイルのタグ一覧を取得...")
        claims_tags = list_tags(claims_profile_arn)
        logger.info(json.dumps(claims_tags, indent=2))
        
        # タグの削除
        logger.info("\nClaims部門プロファイルからタグを削除...")
        untag_resource(claims_profile_arn, ["dept"])
        
        # クリーンアップ
        logger.info("\n=== リソースのクリーンアップ ===")
        delete_inference_profile(claims_profile_arn)
        delete_inference_profile(underwriting_profile_arn)
        
    except Exception as e:
        logger.error(f"メイン処理でエラーが発生: {str(e)}")
        raise

if __name__ == "__main__":
    main()
t