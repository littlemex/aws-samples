# セルフアカウントでのローカル PC 環境セットアップ

このガイドでは ローカル PC 上で VS Code をセットアップする手順を説明します。

## ドキュメント構成

```mermaid
flowchart TD
    A[manuals/README.md] --> B{アカウント選択}
    B -->|セルフアカウント| C[manuals/selfenv.md]
    B -->|Workshop Studio| D[manuals/workshop-studio.md]
    
    C --> E{実行環境}
    D --> F{実行環境}
    
    E -->|"Amazon EC2 環境(推奨)"| G[manuals/selfenv-ec2.md]
    E -->|ローカル環境| H[manuals/selfenv-local.md]
    
    F -->|"Amazon EC2 環境(推奨)"| I[manuals/ws-ec2.md]
    F -->|ローカル環境| J[manuals/ws-local.md]
    
    G --> K[manuals/workshops/README.md]
    H --> K
    I --> K
    J --> K
    
    K -->|Cline| CL[manuals/workshops/cline.md]
    K -->|MCP| L[manuals/workshops/mcp.md]
    K -->|LiteLLM| M[manuals/workshops/litellm.md]
    K -->|Langfuse| N[manuals/workshops/langfuse.md]
    K -->|MLflow| O[manuals/workshops/mlflow.md]
    
    L --> P[1.mcp/README.md]
    M --> Q[2.litellm/README.md]
    N --> R[4.langfuse/README.md]
    O --> S[5.mlflow/README.md]

    click A href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/README.md"
    click C href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/selfenv.md"
    click D href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshop-studio.md"
    click G href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/selfenv-ec2.md"
    click I href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/ws-ec2.md"
    click J href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/ws-local.md"
    click K href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/README.md"
    click L href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/mcp.md"
    click M href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/litellm.md"
    click N href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/langfuse.md"
    click CL href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/cline.md"
    click O href "https://github.com/littlemex/aws-samples/blob/feature/issue-53/workshops/ai-coding-workshop/cline/manuals/workshops/mlflow.md"

    style H fill:#f96,stroke:#333,stroke-width:2px
```

## ツールのインストール

これらのツールはワークショップ当日までにインストールされていることが望ましいです。

### AWS CLI のインストール

[AWS CLI の最新バージョンのインストールまたは更新](https://docs.aws.amazon.com/ja_jp/cli/latest/userguide/getting-started-install.html) を行ってください。

### mise のインストール (1.mcp, 4.langfuse, 5.mlflow で使用)

[mise の Getting Started](https://mise.jdx.dev/getting-started.html) を確認して mise をインストールしてください。

```bash
mise use -g node@22 python@3.10 uv@0.6.16
mise ls
```

### Docker のインストール (2.litellm, 4.langfuse で使用)

[Docker](https://docs.docker.com/engine/install/) をインストールしてください。
Docker が利用できない場合は [finch](https://github.com/runfinch/finch) をインストールしてください。
そしてエイリアスを設定してワークショップを実施してください。

```bash
alias docker="finch"
docker run --rm public.ecr.aws/finch/hello-finch
```

## AWS CLI の設定と動作確認

Windows, Mac, Linux など OS によらず以下のコマンドを実行できます。Windows の場合は WSL2 または PowerShell で実行してください。

1. **認証情報の設定**:
   ```bash
   # default のプロファイルが既にある場合に上書きをしないために既存の ~/.aws/{credenatials,config} の profile 名と競合しない profile 名にしてください。
   # 必ず以下の環境変数を設定してください。
   export AWS_PROFILE=cline

   # IAM ユーザーの場合
   aws configure

   # IAM Identity Center (SSO) の場合
   aws configure sso
   # コマンド実行後、以下の情報の入力を求められます：
   # SSO start URL: [SSO のスタート URL を入力]
   # SSO Region: [SSO のリージョンを入力]
   # SSO registration scopes: sso:account:access
   # ブラウザが開き、AWS SSO へのログインを求められます。ログイン後、アクセスするアカウントとロールを選択します。
   ```

2. **プロファイル設定の確認**:

   プロファイルの設定内容は `~/.aws/config` または `~/.aws/credentials` に保存されます。
   
   以下は `~/.aws/credentials` のサンプルです。

   ```bash
   [cline]
   aws_access_key_id = AKIAXXXXXXXXXXXXXXXX
   aws_secret_access_key = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   region = us-east-1
   ```

   以下は `~/.aws/config` のサンプルです。

   ```
   [profile cline]
   sso_session = sso-session-name
   sso_account_id = 123456789012
   sso_role_name = RoleName
   region = us-east-1

   [sso-session sso-session-name]
   sso_start_url = https://example.awsapps.com/start
   sso_region = us-east-1
   sso_registration_scopes = sso:account:access
   ```

3. **AWS SSM コマンドの動作確認**:
   ```bash
   aws sts get-caller-identity
   ```
   
   正常に動作すると、以下のような情報が表示されます：
   ```json
   {
       "UserId": "XXXXXXXXXXXXXXXXXXXXX",
       "Account": "123456789012",
       "Arn": "arn:aws:iam::123456789012:user/username"
   }
   ```

**ここまでがうまくいけば Cline を使うための開発環境構築は完了です！**

---

**[次のステップ]**
- [ワークショップ一覧へ進む](./workshops/README.md)
- [戻る](./selfenv.md)
