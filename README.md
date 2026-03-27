# bokunokangaeta-saikyono-container

AIエージェントに自動実装を任せるための、安全寄りなポリグロット開発コンテナ基盤です。

このリポジトリは次の前提で設計しています。

- 生成と検証を分離し、ホスト OS を実験場にしない
- Podman と Docker のどちらでも扱える OCI 互換の構成にする
- Codex CLI、Claude Code、Gemini CLI、GitHub Copilot、Cursor、Aider を中心に広く対応する
- Python と Node.js はすぐ使え、追加言語は `mise` で段階的に展開できる
- CI/CD で lint、ビルド、スモークテスト、脆弱性検査、シークレット検査を回す

## クイックスタート

```bash
make install-host-tools-macos
make doctor
make lint
make build
make shell
make shell-online
make bootstrap-polyglot
make install-agents
make smoke
```

安全寄りのデフォルトは `make shell` です。ネットワークを使う依存解決やセットアップだけ `make shell-online` を使い、通常の生成と検証はオフラインで回す想定です。

## 前提条件

- `podman` または `docker`
- `python3`
- `git`

まず `make doctor` で前提を確認できます。

macOS で Podman と Docker CLI を未導入の状態から入れる場合は、次を使えます。

```bash
make install-host-tools-macos
```

このターゲットは次を行います。

- `~/.local/bin` に `podman` と `docker` を導入
- Podman の helper binaries を `~/.local/lib/podman` に展開
- `podman-compose` を `python3 -m pip --user` で導入
- Docker Desktop がある場合は `docker-credential-desktop` もリンク
- `~/.zprofile` に `PATH` と `DOCKER_HOST` の補助設定を追加
- `podman machine init --now` でローカル実行用 VM を起動

`docker` は Docker Desktop ではなく Podman の API ソケットを使う構成です。`docker compose` プラグインまでは入れないため、Compose 実行は `podman-compose` か Podman Compose を使う前提です。

## 主な構成

- `Containerfile`: 非 root ユーザー前提の OCI 互換ベースイメージ
- `scripts/run-sandbox.sh`: オフライン既定の安全な実行ラッパー
- `scripts/install-agents.sh`: エージェント CLI をユーザー領域へ導入
- `scripts/install-host-tools-macos.sh`: macOS ホストに Podman/Docker CLI を導入
- `scripts/check-prereqs.sh`: ローカル前提条件の確認
- `scripts/lint-local.sh`: ローカル静的チェック
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

## セキュリティ方針

- 既定で `--network none`
- `--cap-drop=ALL`
- `--security-opt=no-new-privileges`
- `--read-only` の root filesystem
- 書き込み可能なのは `workspace` とリポジトリ配下の `.sandbox/home`
- 検証は CI とスモークテストで別系統に回す
- 依存更新と GitHub Actions 更新は Dependabot に任せる

## ドキュメント

- [設計思想](docs/design-philosophy.md)
- [アーキテクチャ](docs/architecture.md)
- [セキュリティモデル](docs/security-model.md)
- [エージェント互換性](docs/agent-compatibility.md)

## 使い分け

- 日常の自動実装ループ: `make shell`
- 依存解決や言語追加: `make shell-online`
- Compose で起動: `make compose-shell`
- Compose でオンライン起動: `make compose-shell-online`
- 前提確認: `make doctor`
- macOS ホストへエンジン導入: `make install-host-tools-macos`
- ローカル静的チェック: `make lint`
- 特定エージェントを起動: `make agent AGENT=codex`
- CI 相当の最低確認: `make smoke`

## 注意

- GitHub Copilot と Cursor は CLI だけでなく IDE 統合も想定しています
- Agent CLI の導入先は root filesystem ではなく `~/.local` です
- macOS の `docker` CLI は Podman API ソケットへ向ける前提です
- `.sandbox/` はローカル専用の作業領域として `.gitignore` しています
