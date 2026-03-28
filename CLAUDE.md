# Claude Code Notes

- 先に `AGENTS.md` を読む
- 生成、実行、検証を同じ判断に混ぜない
- 既定の作業場所はコンテナ内とし、ホスト側へ作用する mount を増やしすぎない
- 依存追加が必要なときだけ `scripts/run-sandbox.sh --online` を使う
- 検証は `make smoke` と CI の両方を前提にする
- 実装ごとに branch を分け、別件の変更を同じ branch や PR に混ぜない
- PR を作るときは `.github/pull_request_template.md` に合わせる
