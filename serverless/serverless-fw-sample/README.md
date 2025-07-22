# serverless framework sample

シンプルなサーバレス構成を立ち上げます。  

- [x] REST API Gateway
- [x] Lambda (python)

# 構築手順

前提として以下を実施してください。

- serverless frameworkのインストール(バージョンに気をつけてください)  
  - frameworkVersion: "=2.57.0"でサンプルは作成しています。  
- credentialの設定  
  - 適切なProfile設定、assume-role等を行ってください。  

## 1. S3バケットを作成する  

- 任意の名前でS3バケットを作成します。  
- conf/env_dev.ymlに記載のS3_CONFIG_BUCKET_NAME、S3_CONFIG_BUCKET_PREFIXを作成したバケット名に変更します。  

```yml
# deployment bucket
S3_CONFIG_BUCKET_NAME: akazawt-serverless-deployment-bucket
S3_CONFIG_BUCKET_PREFIX: sample
```

## 設定ファイルの修正

- conf/env_dev.ymlに記載のACCOUNT_IDをご自身が利用しているアカウントIDに変更します。  

## 2. デプロイ実施

./deploy.shはserverless deployコマンドをwrapしているだけなので使わなくても良いです。  

```bash
./deploy.sh dev
```

## ファイル説明

### 1. serverless_環境.yml

serverless実行時に指定するトップのファイルです。
このファイルから別のファイルを呼び出すような作りになっています。
詳細はファイルにコメントを書いていますのでそちらをご覧ください。

#### functions

appディレクトリ配下に、apiというディレクトリがあります。
その中にfunctionの設定を書いたymlが配置されます。
functionのymlについては用意されたサンプルベースで書き換えればすぐに使えると思います。  

### 2. conf/env_環境.ymlの編集

serverless実行時とlambdaの環境変数で利用する環境ごとの変数を設定します。
必要に応じて編集してください。

```yml
custom:
  otherfile:
    environment:
      env: ${file(./conf/env_dev.yml)}
```

### 3. conf/apigw.yml

API gatewayを固定化する際に利用します。  
手動で作成したAPI gatewayのIdを指定しますが、
変数として管理しているので操作は基本必要ありません。
APIGW_REST_API_ID, APIGW_REST_API_ROOT_RESOURCE_IDを設定します。  
事前にAPIのエンドポイントURLのみ外部に共有する必要があるようなケースで利用します。  

### 4. conf/iam.yml

lambdaに与える権限設定を行います。
lambda設定側(app以下)でも既存のroleを上書きして設定することができます。

### 5. conf/provide_env.yml

lambdaの環境変数を指定します。
環境ごとの差異をconf/end_環境.yml内のみにするため、
以下の例のようにconf/end_環境.ymlの設定を呼び出します。

例

```bash
REGION: ${self:custom.otherfile.environment.env.REGION}
```

### 6. conf/provider_logs.yml

API gatewayの取得するログフォーマットを指定しています。

### 7. handlers/

app内の個々の設定ファイル内のhandlersで指定したハンドラを配置します。