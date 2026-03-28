# Gemini CLI Notes

- 先に `AGENTS.md` を読む
- Gemini CLI の内蔵サンドボックスだけに依存せず、このリポジトリのコンテナ境界を優先する
- 通常の生成ループはオフライン既定で回す
- 追加の言語や依存が必要なら `bootstrap-languages` と `install-agents` を使う
- 検証フェーズでは独立したスモークテストを回す
- 実装ごとに branch を分け、別件の変更を同じ branch や PR に混ぜない
- PR を作るときは `.github/pull_request_template.md` に合わせる
