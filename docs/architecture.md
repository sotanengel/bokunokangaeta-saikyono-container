# アーキテクチャ

## レイヤー

- ホスト: コンテナエンジンとワークスペースを保持する
- 安全ラッパー: `scripts/run-sandbox.sh` が実行境界を作る
- ワークスペースコンテナ: 非 root ユーザーで AI エージェントを実行する
- 検証系: `make smoke` と GitHub Actions が別ラインでチェックする

## 実行フロー

```mermaid
flowchart LR
  A["Agent or IDE"] --> B["scripts/run-sandbox.sh"]
  B --> C["OCI Workspace Container"]
  C --> D["/workspace bind mount"]
  C --> E["/home/agent -> .sandbox/home"]
  C --> F["tmpfs: /tmp and /var/tmp"]
  C --> G["Toolchain: node, python, uv, mise"]
  G --> H["Generate / Build / Verify"]
  H --> I["make smoke"]
  H --> J["GitHub Actions"]
```

## 役割分担

- `Containerfile`: 最小限の共通ベース
- `bootstrap-languages`: 追加ランタイム導入
- `install-agents`: エージェント CLI 導入
- `run-sandbox`: 権限と mount の安全化

## 2つの利用モード

- オフライン既定モード: 実装、テスト、レビュー、再現確認
- オンライン明示モード: 依存取得、追加ツール導入、初期セットアップ
