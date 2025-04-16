# AI コーディング支援エージェント時代における開発生産性とガバナンスの両立

## プレゼンテーション

2025年4月

---

## アジェンダ

- AI コーディング支援エージェントの概要と課題
- Cline の特徴と基本機能
- アーキテクチャ設計と実装
- セキュリティとアクセス制御
- コスト管理とリソース最適化
- 運用フローと実践的な導入方法

---

## AI コーディング支援エージェントの現状

**AI コーディング支援エージェント**は、開発の世界に革新的な変化をもたらしています：

- 単なるコード補完を超えた **自律的なタスク実行**
- プロジェクト全体の **コンテキスト理解**
- 複雑な開発タスクの **効率的な処理**
- チーム開発における **知識共有の促進**

*従来の開発手法では対応困難な課題に対応します*

---

## 企業が直面する主要な課題

### トークン消費と API 制限

- 複雑なコードベース理解による **大量のトークン消費**
- API Provider による **RPM/TPM 制限**
- 開発フローの中断リスク

### セキュリティとコンプライアンス

- 機密情報の保護要件
- 部門単位でのアクセス制御
- 監査対応とポリシー準拠

### コスト管理

- AI 利用コストの可視化と最適化
- 部門別予算管理と監視
- 効率的なモデル選択戦略

---

## Cline の概要

**Cline** は、開発者の意図を理解し自律的にタスクを実行できる AI コーディング支援エージェントです：

### 主要な特徴

- IDE への完全統合
- 自律的なタスク実行能力
- プロジェクト規約への適応
- オープンソースでの継続的進化

### 独自の機能

- **Pilot アプローチ**による自律的タスク遂行
- **Plan/Act モード**の分離による効率的な開発
- **Model Context Protocol** による高度な拡張性

---

## Amazon Bedrock と Claude 3.7 Sonnet の価値

### エンタープライズ環境への最適化

- AWS の「セキュリティファースト」哲学
- 包括的なコンプライアンス対応
- 豊富な実績と継続的な進化

### データ保護とプライバシー

- デフォルトでの学習無効化
- 詳細なデータ取り扱いポリシー設定
- 機密データの安全な処理

---

## 全体アーキテクチャ

```mermaid
graph TB
    subgraph Secure_AI_Coding_Environment
        subgraph "部門 A"
            UA1["開発者 A1"]
        end

        subgraph "部門 B"
            UB1["開発者 B1"]
            UB2["部門責任者"]
        end
            
        subgraph インフラ部門
            INFRA[インフラチーム]
        end
        
        subgraph "AWS"
            CA1["Cline (on Amazon EC2)"]
            
            LITELLM[LiteLLM Proxy]
            subgraph LiteLLMFunc["LiteLLM 機能"]
                BUDGET[予算管理]
                KEYS[Virtual Key 管理]
                CALLBACK[Callback 設定]
                AWSCRED[AWS クレデンシャル管理]
            end
                    
            LITELLM <--> LiteLLMFunc

            LANGFUSE[Langfuse UI]
                    
            subgraph LangfuseDashboard["Langfuse 機能"]
                USAGE[使用状況]
                COST[コスト分析]
                TAGS[自動タグ]
                LATENCY[レイテンシー分析]
                LOGS[ログトレース]
            end    
            LangfuseDashboard <--> LANGFUSE
            
            subgraph AWSAC["AWS Accounts"]
                subgraph AWS1["AWS Account 1"]
                    BEDROCK1[Amazon Bedrock]
                end
                
                subgraph AWS2["AWS Account 2"]
                    BEDROCK2[Amazon Bedrock]
                end
            end
        end
    end
    
    INFRA -->|コスト分析、ログ調査| LANGFUSE
    INFRA -->|EC2 管理| CA1
    INFRA -->|Admin 権限で設定| LITELLM
    KEYS -->|Virtual Key 発行| UA1
    UA1 -->|接続| CA1
    UB1 -->|接続| CA1
    CA1 -->|Virtual Key 使用| LITELLM
    AWSCRED <-->|クレデンシャル| BEDROCK1
    AWSCRED <-->|クレデンシャル| BEDROCK2
    CALLBACK -->|ログ転送| LangfuseDashboard
```

セキュアな AI コーディング支援環境の全体像を示しています。

---

## アクセス制御とキー管理フロー

```mermaid
sequenceDiagram
    participant IT as インフラチーム
    participant LiteLLM as LiteLLM Proxy
    participant Dev as 開発者A1
    participant Lead as 部門責任者
    participant Langfuse as Langfuse UI
    participant EC2 as Amazon EC2
    participant Bedrock as Amazon Bedrock

    Note over IT,Bedrock: 初期セットアップフェーズ
    IT->>EC2: 1. EC2インスタンス作成
    IT->>LiteLLM: 2. LiteLLM Proxy設定
    IT->>Langfuse: 3. Langfuse環境構築

    Note over IT,Lead: アクセス権限付与フェーズ
    IT->>Lead: 4. 部門別Virtual Key発行
    Lead->>Dev: 5. 開発者へVirtual Key配布

    Note over Dev,Bedrock: 開発フェーズ
    Dev->>EC2: 6. code-server/SSH接続
    Dev->>LiteLLM: 7. Virtual Keyで認証
    LiteLLM->>Bedrock: 8. API呼び出し
    Bedrock-->>LiteLLM: 9. レスポンス返却
    LiteLLM-->>Dev: 10. 結果返却
```

セキュアなアクセス制御と権限管理のフローを示しています。

---

## セキュリティ対策の実装

```mermaid
graph TB
    subgraph Security_Layers["セキュリティレイヤー"]
        subgraph Network["ネットワークセキュリティ"]
            SM[Session Manager]
            VPC[VPC Endpoint]
            SG[Security Group]
        end

        subgraph Access["アクセス制御"]
            IAM[IAM Role]
            VK[Virtual Key]
            MFA[多要素認証]
        end

        subgraph Monitoring["監視と監査"]
            CT[CloudTrail]
            CW[CloudWatch]
            LF[Langfuse]
        end

        subgraph Data["データ保護"]
            KMS[KMS暗号化]
            SEC[Secrets Manager]
            LOG[ログ制御]
        end
    end
```

多層的なセキュリティ対策の実装構造を示しています。

---

## コスト管理とリソース制御

```mermaid
graph TB
    subgraph Cost_Control["コスト管理システム"]
        subgraph Budget["予算管理"]
            MB[月次予算設定]
            DB[部門別予算]
            AB[アラート設定]
        end

        subgraph Resource["リソース制御"]
            TPM[TPM制限]
            RPM[RPM制限]
            QUE[キューイング]
        end

        subgraph Optimization["最適化"]
            MC[モデル選択]
            PC[Prompt Caching]
            BC[バッチ処理]
        end

        subgraph Analytics["分析"]
            CA[コスト分析]
            UA[利用分析]
            TA[トレンド分析]
        end
    end
```

包括的なコスト管理とリソース制御の仕組みを示しています。

---

## 実装のポイント

### LiteLLM の設定

- Virtual Key 発行時の部門情報メタデータ付与
- Langfuse へのユーザー識別情報転送
- 部門ごとのクォータ設定

### Langfuse の設定

- 部門情報のタグ記録
- 部門別ダッシュボードの作成
- 全社データアクセス権設定

---

## 導入効果と期待される価値

### 開発生産性の向上

- コード生成時間の大幅削減
- プロジェクト理解の効率化
- チーム間の知識共有促進

### ガバナンスの強化

- セキュリティリスクの最小化
- コンプライアンス要件への適合
- 詳細な監査証跡の確保

### コスト最適化

- 予算管理の自動化
- リソース使用の効率化
- モデル選択の最適化

---

## まとめ

- AI コーディング支援エージェントの **効果的な活用**
- セキュリティと生産性の **両立**
- 組織全体での **持続可能な運用体制**
- **段階的な導入**と継続的な改善

*AI 時代における開発体制の新たなスタンダードを確立します*
