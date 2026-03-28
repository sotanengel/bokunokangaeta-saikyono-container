# bokunokangaeta-saikyono-container

AI エージェント用の安全寄り開発コンテナ基盤です。Podman/Docker で動かし、通常作業はオフライン、依存取得時だけオンラインを想定しています。

## このリポジトリに入っているもの

- `Containerfile`: 共通ベースイメージ
- `scripts/run-sandbox.sh`: オフライン既定の実行ラッパー
- `scripts/build-image.sh`: ローカルイメージを build
- `scripts/smoke-test.sh`: 最低限の動作確認
- `scripts/polyglot-smoke-test.sh`: 言語サンプル確認
- `scripts/agent-smoke-test.sh`: エージェント導線確認
- `scripts/install-host-tools-macos.sh` / `scripts/install-host-tools-linux.sh`: ホスト側ツール導入補助
- `compose.yaml`: Compose 起動定義
- `docs/`: 設計、セキュリティ、互換性の説明

## 最短手順

`make` は必須ではありません。必要なら `Makefile` をショートカットとして使えます。

1. 前提確認

```bash
./scripts/check-prereqs.sh
./scripts/check-container-engines.sh
```

1. イメージを build

```bash
./scripts/build-image.sh --image ai-agent-sandbox:latest
```

1. まずはオフラインで入る

```bash
./scripts/run-sandbox.sh --image ai-agent-sandbox:latest
```

1. 依存取得が必要なときだけ online

```bash
./scripts/run-sandbox.sh --image ai-agent-sandbox:latest --online --reason "install dependencies"
```

1. 最低限の確認

```bash
IMAGE=ai-agent-sandbox:latest ./scripts/smoke-test.sh
```

## エンジンが無い場合

- macOS: `./scripts/install-host-tools-macos.sh --write-shell-profile`
- Linux: `./scripts/install-host-tools-linux.sh`
- macOS で Podman machine を明示起動: `./scripts/start-podman-machine-macos.sh`

## よく使うコマンド

- Compose で起動: `./scripts/compose-shell.sh`
- 静的チェック: `./scripts/lint-local.sh`
- commit 前チェック: `./scripts/run-pre-commit.sh`
- 多言語 smoke: `./scripts/polyglot-smoke-test.sh --image ai-agent-sandbox:latest --group core`
- エージェント smoke: `./scripts/agent-smoke-test.sh --image ai-agent-sandbox:latest --agent codex`
- archive と checksum の出力: `./scripts/export-image-artifacts.sh --image ai-agent-sandbox:latest --output-dir dist/image-artifacts`

## 既定

- root filesystem は read-only
- 既定で `--network none`
- 書き込み先は `workspace` と `.sandbox/home`
- 実行ログは host 側に監査ログとして残す

## ドキュメント

- [設計思想](docs/design-philosophy.md)
- [アーキテクチャ](docs/architecture.md)
- [セキュリティモデル](docs/security-model.md)
- [エージェント互換性](docs/agent-compatibility.md)
