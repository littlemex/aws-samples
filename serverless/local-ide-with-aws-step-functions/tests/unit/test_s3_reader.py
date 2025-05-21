import os
import json
import pytest
import boto3
from moto import mock_aws
from unittest.mock import patch

# テスト対象のLambda関数をインポート
import sys
sys.path.append(os.path.join(os.path.dirname(__file__), '../../functions/s3_reader'))
import app

# テスト用の定数
TEST_BUCKET_NAME = 'test-bucket'
TEST_PREFIX = 'data/'
TEST_FILE_KEY = f'{TEST_PREFIX}test-file.json'
TEST_CONTENT = {'id': 'test-id', 'value': 'test-value'}
TEST_LARGE_CONTENT = {'data': 'x' * 1000000}  # 約1MBのデータ
TEST_INVALID_JSON = 'This is not a valid JSON'

@pytest.fixture
def aws_credentials():
    """テスト用のAWS認証情報を設定"""
    os.environ['AWS_ACCESS_KEY_ID'] = 'testing'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'testing'
    os.environ['AWS_SECURITY_TOKEN'] = 'testing'
    os.environ['AWS_SESSION_TOKEN'] = 'testing'
    os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'
    os.environ['BUCKET_NAME'] = TEST_BUCKET_NAME
    os.environ['PREFIX'] = TEST_PREFIX

@pytest.fixture
def s3_client(aws_credentials):
    """モック化されたS3クライアントを作成"""
    with mock_aws():
        s3 = boto3.client('s3', region_name='us-east-1')
        # テスト用のバケットを作成
        s3.create_bucket(Bucket=TEST_BUCKET_NAME)
        yield s3

def test_empty_bucket(s3_client):
    """空のバケットの場合のテスト"""
    # Lambda関数を実行
    result = app.lambda_handler({}, None)
    
    # 結果を検証
    assert result['hasData'] == False
    assert TEST_BUCKET_NAME in result['message']

def test_single_file(s3_client):
    """1つのファイルがある場合のテスト"""
    # テストファイルをアップロード
    s3_client.put_object(
        Bucket=TEST_BUCKET_NAME,
        Key=TEST_FILE_KEY,
        Body=json.dumps(TEST_CONTENT)
    )
    
    # Lambda関数を実行
    result = app.lambda_handler({}, None)
    
    # 結果を検証
    assert result['hasData'] == True
    assert result['data']['fileInfo']['bucket'] == TEST_BUCKET_NAME
    assert result['data']['fileInfo']['key'] == TEST_FILE_KEY
    assert result['data']['content'] == TEST_CONTENT

def test_multiple_files(s3_client):
    """複数のファイルがある場合のテスト"""
    # 複数のテストファイルをアップロード
    for i in range(5):
        s3_client.put_object(
            Bucket=TEST_BUCKET_NAME,
            Key=f'{TEST_PREFIX}test-file-{i}.json',
            Body=json.dumps({'id': f'test-{i}', 'value': f'value-{i}'})
        )
    
    # 最新のファイルを追加（タイムスタンプの関係で最後に追加）
    latest_file_key = f'{TEST_PREFIX}latest-file.json'
    s3_client.put_object(
        Bucket=TEST_BUCKET_NAME,
        Key=latest_file_key,
        Body=json.dumps({'id': 'latest', 'value': 'latest-value'})
    )
    
    # Lambda関数を実行
    result = app.lambda_handler({}, None)
    
    # 結果を検証
    assert result['hasData'] == True
    assert result['data']['fileInfo']['key'] == latest_file_key
    assert result['data']['content']['id'] == 'latest'

def test_large_file(s3_client):
    """大きなファイルの場合のテスト"""
    # 大きなテストファイルをアップロード
    s3_client.put_object(
        Bucket=TEST_BUCKET_NAME,
        Key=TEST_FILE_KEY,
        Body=json.dumps(TEST_LARGE_CONTENT)
    )
    
    # Lambda関数を実行（タイムアウトを避けるためにタイムアウト時間を設定）
    with patch.object(app.s3, 'get_object', wraps=app.s3.get_object) as mock_get_object:
        result = app.lambda_handler({}, None)
        
        # get_objectが呼び出されたことを確認
        mock_get_object.assert_called_once()
    
    # 結果を検証
    assert result['hasData'] == True
    assert result['data']['fileInfo']['bucket'] == TEST_BUCKET_NAME
    assert result['data']['fileInfo']['key'] == TEST_FILE_KEY
    assert result['data']['content'] == TEST_LARGE_CONTENT

def test_invalid_json(s3_client):
    """不正なJSONファイルの場合のテスト"""
    # 不正なJSONファイルをアップロード
    s3_client.put_object(
        Bucket=TEST_BUCKET_NAME,
        Key=TEST_FILE_KEY,
        Body=TEST_INVALID_JSON
    )
    
    # Lambda関数を実行
    result = app.lambda_handler({}, None)
    
    # 結果を検証
    assert result['hasData'] == True
    assert result['data']['fileInfo']['bucket'] == TEST_BUCKET_NAME
    assert result['data']['fileInfo']['key'] == TEST_FILE_KEY
    assert 'text' in result['data']['content']
    assert result['data']['content']['text'] == TEST_INVALID_JSON

def test_missing_bucket():
    """バケットが存在しない場合のテスト"""
    # 存在しないバケット名を設定
    os.environ['BUCKET_NAME'] = 'non-existent-bucket'
    
    # Lambda関数を実行（例外が発生することを期待）
    with pytest.raises(Exception):
        app.lambda_handler({}, None)
    
    # テスト後に元の設定に戻す
    os.environ['BUCKET_NAME'] = TEST_BUCKET_NAME

def test_performance():
    """パフォーマンステスト"""
    with mock_aws():
        s3 = boto3.client('s3', region_name='us-east-1')
        s3.create_bucket(Bucket=TEST_BUCKET_NAME)
        
        # 複数の大きなファイルをアップロード
        for i in range(10):
            s3.put_object(
                Bucket=TEST_BUCKET_NAME,
                Key=f'{TEST_PREFIX}large-file-{i}.json',
                Body=json.dumps({'data': 'x' * 100000})  # 約100KBのデータ
            )
        
        # Lambda関数の実行時間を計測
        import time
        start_time = time.time()
        app.lambda_handler({}, None)
        end_time = time.time()
        
        # 実行時間が3秒未満であることを確認（Lambda関数のタイムアウトは3.01秒）
        assert (end_time - start_time) < 3.0, f"実行時間が長すぎます: {end_time - start_time}秒"
