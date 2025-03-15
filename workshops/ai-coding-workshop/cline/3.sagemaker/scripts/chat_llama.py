#!/usr/bin/env python3
import json
import boto3
import argparse
import time
import os

def clear_screen():
    """画面をクリアする"""
    os.system('cls' if os.name == 'nt' else 'clear')

def invoke_endpoint(endpoint_name, prompt, conversation_history=None, region=None, temperature=0.7, max_tokens=512):
    """SageMaker エンドポイントを呼び出す"""
    # リージョンの設定
    if region:
        session = boto3.Session(region_name=region)
        runtime = session.client('sagemaker-runtime')
    else:
        runtime = boto3.client('sagemaker-runtime')
    
    # 会話履歴がある場合は、それを含めたプロンプトを作成
    full_prompt = prompt
    if conversation_history:
        full_prompt = conversation_history + "\n\nユーザー: " + prompt + "\n\nアシスタント: "
    
    # リクエストの作成
    payload = {
        "inputs": full_prompt,
        "parameters": {
            "max_new_tokens": max_tokens,
            "temperature": temperature,
            "top_p": 0.9,
            "do_sample": True
        }
    }
    
    # エンドポイントの呼び出し
    start_time = time.time()
    response = runtime.invoke_endpoint(
        EndpointName=endpoint_name,
        ContentType='application/json',
        Body=json.dumps(payload)
    )
    end_time = time.time()
    
    # レスポンスの解析
    result = json.loads(response['Body'].read().decode())
    
    # 処理時間の計算
    processing_time = end_time - start_time
    
    return result, processing_time

def main():
    parser = argparse.ArgumentParser(description='SageMaker エンドポイントとチャット')
    parser.add_argument('--endpoint-name', type=str, required=True,
                      help='SageMaker エンドポイントの名前')
    parser.add_argument('--temperature', type=float, default=0.7,
                      help='生成の温度パラメータ (0.0-1.0)')
    parser.add_argument('--max-tokens', type=int, default=512,
                      help='生成する最大トークン数')
    parser.add_argument('--region', type=str,
                      help='AWS リージョン（デフォルト設定を上書き）')

    args = parser.parse_args()
    
    # 会話履歴の初期化
    conversation_history = "以下は、ユーザーとAIアシスタントの会話です。AIアシスタントは親切で、丁寧で、誠実です。"
    
    clear_screen()
    print("===== Llama 3.3 Swallow チャット =====")
    print("終了するには 'exit' または 'quit' と入力してください。")
    print("会話をリセットするには 'reset' と入力してください。")
    print("======================================")
    
    while True:
        try:
            # ユーザー入力の取得
            user_input = input("\nユーザー: ")
            
            # 終了コマンドのチェック
            if user_input.lower() in ['exit', 'quit']:
                print("チャットを終了します。")
                break
            
            # リセットコマンドのチェック
            if user_input.lower() == 'reset':
                conversation_history = "以下は、ユーザーとAIアシスタントの会話です。AIアシスタントは親切で、丁寧で、誠実です。"
                print("会話履歴をリセットしました。")
                continue
            
            # エンドポイントの呼び出し
            result, processing_time = invoke_endpoint(
                args.endpoint_name, 
                user_input, 
                conversation_history,
                args.region, 
                args.temperature, 
                args.max_tokens
            )
            
            # 応答の表示
            if isinstance(result, list) and len(result) > 0:
                response_text = result[0].get('generated_text', str(result[0]))
            elif isinstance(result, dict):
                response_text = result.get('generated_text', str(result))
            else:
                response_text = str(result)
            
            # プロンプトの一部が応答に含まれている場合は削除
            if conversation_history in response_text:
                response_text = response_text.replace(conversation_history, "").strip()
            if user_input in response_text:
                response_text = response_text.split(user_input, 1)[-1].strip()
            if "ユーザー: " in response_text:
                response_text = response_text.split("ユーザー: ", 1)[0].strip()
            if "アシスタント: " in response_text:
                response_text = response_text.split("アシスタント: ", 1)[-1].strip()
            
            print(f"\nアシスタント: {response_text}")
            print(f"\n(処理時間: {processing_time:.2f} 秒)")
            
            # 会話履歴の更新
            conversation_history += f"\n\nユーザー: {user_input}\n\nアシスタント: {response_text}"
            
        except Exception as e:
            print(f"エラーが発生しました: {e}")

if __name__ == "__main__":
    main()