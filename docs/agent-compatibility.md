# エージェント互換性

2026-03-28 時点で、現在の公開エージェント群に広く合わせるための整理です。

## 主要対応

- Codex CLI: `AGENTS.md` とターミナル実行を前提に対応
- Claude Code: `CLAUDE.md` を追加し、共通方針は `AGENTS.md` に寄せる
- Gemini CLI: `GEMINI.md` を追加し、コンテナ境界を外側で固定する
- GitHub Copilot: `.github/copilot-instructions.md` と `.devcontainer` を用意する
- Cursor: `.cursor/rules/00-project.mdc` と `.devcontainer` を用意する
- Aider: `.aider.conf.yml` と共通指示読み込みを用意する

## 互換戦略

- 共通ルールは `AGENTS.md` に集約する
- エージェント固有の癖は薄いアダプターファイルで吸収する
- IDE 系は `.devcontainer` とルールファイルを使う
- CLI 系は `scripts/run-sandbox.sh` と `install-agents` を使う
- CI では `agent-smoke-test.sh` でエージェントごとの導線を確認する

## 追加言語との相性

- Python と Node.js は即時利用
- Go、Rust、Java、Ruby、Bun、Deno は `bootstrap-languages` で展開
- 多言語化しても安全境界は `run-sandbox` が維持する
