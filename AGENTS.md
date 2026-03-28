# Project Instructions

## Mission

- このリポジトリは、安全な AI 自動開発用コンテナ基盤を提供する
- 変更は OCI 互換性、エージェント互換性、セキュリティ既定を壊さないこと

## Working Rules

- まず `scripts/run-sandbox.sh` を使う
- 通常作業はオフライン既定にし、ネットワークは依存取得時だけ明示的に許可する
- ホスト OS にツールを直接増やす前提で設計しない
- root 権限前提の変更を入れない
- bind mount は最小限に保つ
- 検証を省略したまま仕様完了扱いにしない
- 実装ごとに作業ブランチを分け、別件の変更を同じブランチや PR に混ぜない
- PR を作るときは `.github/pull_request_template.md` に従い、未実施の確認があれば理由を明記する

## Change Priorities

- `Containerfile` と `scripts/` は安全性を優先する
- エージェント固有ファイルは内容をそろえ、矛盾させない
- 言語対応はベースを太らせすぎず、後から拡張できる形を優先する

## Definition Of Done

- `make smoke` が通る
- ドキュメントの更新がある
- セキュリティ既定の変更には理由がある
