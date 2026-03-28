# bokunokangaeta-saikyono-container

AIエージェントに自動実装を任せるための、安全寄りなポリグロット開発コンテナ基盤です。

このリポジトリは次の前提で設計しています。

- 生成と検証を分離し、ホスト OS を実験場にしない
- Podman と Docker のどちらでも扱える OCI 互換の構成にする
- Codex CLI、Claude Code、Gemini CLI、GitHub Copilot、Cursor、Aider を中心に広く対応する
- Python と Node.js はすぐ使え、追加言語は `mise` で段階的に展開できる
- CI/CD で lint、ビルド、スモークテスト、脆弱性検査、シークレット検査を回す

## はじめ方

`make` は必須ではありません。このリポジトリの実体は `scripts/*.sh` で、`Makefile` はよく使うコマンドの省略形です。`make` が無い環境では、下の script をそのまま実行してください。

### 最初に覚える 5 つ

1. 前提確認

```bash
./scripts/check-prereqs.sh
./scripts/check-container-engines.sh
```

1. イメージを build

```bash
./scripts/build-image.sh --image ai-agent-sandbox:latest
```

1. まずはオフライン既定で入る

```bash
./scripts/run-sandbox.sh --image ai-agent-sandbox:latest
```

1. 依存取得が必要なときだけ online にする

```bash
./scripts/run-sandbox.sh --image ai-agent-sandbox:latest --online --reason "install dependencies"
```

1. 最低限の確認を回す

```bash
IMAGE=ai-agent-sandbox:latest ./scripts/smoke-test.sh
```

`make` を使うなら、対応する省略形は `make doctor`、`make doctor-host`、`make build`、`make shell`、`make shell-online`、`make smoke` です。

安全寄りのデフォルトは `./scripts/run-sandbox.sh --image ai-agent-sandbox:latest` です。ネットワークを使う依存解決やセットアップだけ `--online` を付け、通常の生成と検証はオフラインで回す想定です。

## 前提条件

- `podman` または `docker`
- `python3`
- `git`

まず `./scripts/check-prereqs.sh` で前提を確認できます。`make doctor` はこのショートカットです。

macOS で Podman と Docker CLI を未導入の状態から入れる場合は、次を使えます。

```bash
./scripts/install-host-tools-macos.sh --write-shell-profile
```

`make install-host-tools-macos` でも同じ処理を呼べます。

このターゲットは次を行います。

- `~/.local/bin` に `podman` と `docker` を導入
- Podman の helper binaries を `~/.local/lib/podman` に展開
- `podman-compose` を `python3 -m pip --user` で導入
- Docker Desktop がある場合は `docker-credential-desktop` もリンク
- `~/.zprofile` に `PATH` と動的な `DOCKER_HOST` 補助設定を追加
- Podman machine を初期化し、guest socket と host forwarding の補修を試みてから起動

自動起動が不安定な host では、次の明示起動ヘルパーを使えます。Codex などの非対話セッションで `podman machine start` がぶら下がる環境では、必要に応じて macOS のユーザーセッション側で起動を引き受けます。

```bash
./scripts/start-podman-machine-macos.sh
```

Podman machine がホスト事情で起動しない場合でも、この installer 自体は Docker 利用を継続できる状態で完了します。Podman 側だけ後から補修したいときは次を使えます。

```bash
./scripts/start-podman-machine-macos.sh
./scripts/repair-podman-machine-macos.sh
./scripts/check-container-engines.sh
```

`docker` は Docker Desktop が ready ならそのまま使い、Docker 側が unavailable な場合だけ Podman の API ソケットへ退避できる構成です。`docker compose` プラグインまでは入れないため、Compose 実行は `podman-compose` か Podman Compose を使う前提です。

## 主な構成

- `Containerfile`: 非 root ユーザー前提の OCI 互換ベースイメージ
- `scripts/run-sandbox.sh`: オフライン既定の安全な実行ラッパー
- `scripts/write-audit-log.sh`: コンテナ start/finish をホスト側監査ログへ記録
- `scripts/audit-host-security.sh`: コンテナ実行権限の棚卸し
- `scripts/polyglot-smoke-test.sh`: 多言語サンプルの実行確認
- `scripts/agent-smoke-test.sh`: エージェントごとの導線確認
- `scripts/export-image-artifacts.sh`: イメージ archive と checksum を出力
- `scripts/install-agents.sh`: エージェント CLI をユーザー領域へ導入
- `scripts/install-host-tools-macos.sh`: macOS ホストに Podman/Docker CLI を導入
- `scripts/install-host-tools-linux.sh`: Linux ホストに Podman/Docker を導入
- `scripts/start-podman-machine-macos.sh`: macOS のユーザーセッション側も使って Podman machine を起動
- `scripts/repair-podman-machine-macos.sh`: macOS 上の Podman machine 定義を補修
- `scripts/check-prereqs.sh`: ローカル前提条件の確認
- `scripts/check-container-engines.sh`: Podman/Docker のホスト実行状態を個別に診断
- `scripts/check-github-actions-pinning.sh`: workflow 内の `uses:` が full SHA かを確認
- `scripts/run-pre-commit.sh`: repo ローカル venv で `pre-commit` を実行
- `scripts/check-sandbox-runtime-config.sh`: sandbox 実行 UID/GID と compose 設定の静的検証
- `scripts/lint-local.sh`: ローカル静的チェック
- `.pre-commit-config.yaml`: commit 前に回す lint/hadolint/markdownlint/shellcheck/actionlint 設定
- `.npmrc`: npm の `min-release-age` による検疫期間
- `pyproject.toml`: `uv` の `exclude-newer` による検疫期間
- `.devcontainer/devcontainer.json`: VS Code/Cursor/Copilot 向けの開発コンテナ設定
- `compose.yaml`: Compose ベースの起動定義
- `AGENTS.md`: 共通のプロジェクト指示
- `CLAUDE.md`: Claude Code 向けメモリ
- `GEMINI.md`: Gemini CLI 向けメモリ
- `.github/copilot-instructions.md`: GitHub Copilot 向け指示
- `.cursor/rules/00-project.mdc`: Cursor ルール
- `.aider.conf.yml`: Aider 初期設定
- `docs/design-philosophy.md`: 設計思想
- `docs/security-model.md`: セキュリティモデル
- `docs/agent-compatibility.md`: 対応エージェントの整理
- `examples/`: 各言語の最小サンプル

## セキュリティ方針

- 既定で `--network none`
- `--cap-drop=ALL`
- `--security-opt=no-new-privileges`
- `--read-only` の root filesystem
- 書き込み可能なのは `workspace` とリポジトリ配下の `.sandbox/home`
- `run-sandbox` と `compose-shell` は bind mount の owner 差異を避けるため、実行時 UID/GID を呼び出し元にそろえる
- `run-sandbox` と `compose-shell` は start/finish を host 側監査ログへ残す
- `compose-shell` も repo root を workspace として固定し、`/` や `HOME` のような高リスク mount を既定で拒否する
- GitHub Actions の `uses:` は full SHA pin を前提にし、`lint-local` でも崩れないように確認する
- npm と uv は 7 日の検疫期間を置き、新規公開直後の依存をすぐには採らない
- 検証は CI とスモークテストで別系統に回す
- 依存更新と GitHub Actions 更新は Dependabot に任せる

## ドキュメント

- [設計思想](docs/design-philosophy.md)
- [アーキテクチャ](docs/architecture.md)
- [セキュリティモデル](docs/security-model.md)
- [エージェント互換性](docs/agent-compatibility.md)

## 使い分け

- 日常の自動実装ループ: `./scripts/run-sandbox.sh --image ai-agent-sandbox:latest` (`make shell`)
- 依存解決や言語追加: `./scripts/run-sandbox.sh --image ai-agent-sandbox:latest --online --reason "bootstrap"` (`make shell-online`)
- Compose で起動: `./scripts/compose-shell.sh` (`make compose-shell`)
- Compose でオンライン起動: `./scripts/compose-shell.sh --online --reason "bootstrap"` (`make compose-shell-online`)
- 前提確認: `./scripts/check-prereqs.sh` (`make doctor`)
- ホスト engine 診断: `./scripts/check-container-engines.sh` (`make doctor-host`)
- ホスト権限の棚卸し: `./scripts/audit-host-security.sh` (`make audit-host-security`)
- macOS ホストへエンジン導入: `./scripts/install-host-tools-macos.sh --write-shell-profile` (`make install-host-tools-macos`)
- Linux ホストへエンジン導入: `./scripts/install-host-tools-linux.sh` (`make install-host-tools-linux`)
- macOS Podman machine 起動: `./scripts/start-podman-machine-macos.sh` (`make start-podman-machine-macos`)
- macOS Podman machine 補修: `./scripts/repair-podman-machine-macos.sh` (`make repair-podman-machine-macos`)
- ローカル静的チェック: `./scripts/lint-local.sh` (`make lint`)
- commit 前の総合チェック: `./scripts/run-pre-commit.sh` (`make pre-commit`)
- 実行設定の静的確認: `./scripts/check-sandbox-runtime-config.sh`
- 多言語 smoke: `./scripts/polyglot-smoke-test.sh --image ai-agent-sandbox:latest --group core` (`make polyglot-smoke POLYGLOT_GROUP=core`)
- エージェント smoke: `./scripts/agent-smoke-test.sh --image ai-agent-sandbox:latest --agent codex` (`make agent-smoke AGENT_SMOKE=codex`)
- archive と checksum の出力: `./scripts/export-image-artifacts.sh --image ai-agent-sandbox:latest --output-dir dist/image-artifacts` (`make export-image-artifacts`)
- 特定エージェントを起動: `./scripts/run-sandbox.sh --image ai-agent-sandbox:latest --agent codex` (`make agent AGENT=codex`)
- CI 相当の最低確認: `IMAGE=ai-agent-sandbox:latest ./scripts/smoke-test.sh` (`make smoke`)

## 注意

- GitHub Copilot と Cursor は CLI だけでなく IDE 統合も想定しています
- Agent CLI の導入先は root filesystem ではなく `~/.local` です
- macOS の `docker` CLI は Docker Desktop を優先し、必要時のみ Podman API ソケットへ退避します
- 監査ログは `${XDG_STATE_HOME:-$HOME/.local/state}/ai-agent-sandbox/audit/container-runs.jsonl` に記録されます
- ネットワークが必要な実行は `--reason` を付けて監査しやすくしてください
- `export-image-artifacts` の checksum 生成は `sha256sum` を優先し、ない host では `shasum -a 256` を使います
- Dependabot の version update も 7 日 cooldown を入れ、リリース直後の更新を遅延させます
- commit 前チェックは `make install-pre-commit-hook` で hook 登録できます
- `Makefile` は便利コマンド集であって必須ではありません。`make` が無い環境では `scripts/*.sh` を直接使ってください
- `run-sandbox.sh --dry-run` と `compose-shell.sh --dry-run` で engine なしでも runtime 設定を確認できます
- CI は多言語 smoke、エージェント smoke、SBOM 生成、checksum 署名まで回します
- `.sandbox/` はローカル専用の作業領域として `.gitignore` しています
