# セキュリティモデル

## 守りたい対象

- ホスト OS
- ユーザーのホーム配下にある無関係なファイル
- シークレット
- CI での supply chain

## 想定する失敗

- AI が危険なコマンドを提案する
- 依存を無制限に追加する
- 不要なファイルを広く mount してしまう
- 信頼された container runtime が持ち込み・持ち出しの踏み台になる
- テストをすり抜けるための見かけだけの修正を入れる

## ランタイム制御

- コンテナ内ユーザーは `agent`
- root filesystem は read-only
- `--cap-drop=ALL`
- `--security-opt=no-new-privileges`
- `--pids-limit=512`
- `/tmp` と `/var/tmp` は tmpfs
- ワークスペース以外の bind mount は増やさない
- ネットワークは既定で無効
- `/` やユーザー home のような高リスクな workspace mount は拒否する
- すべての実行に監査用の container name と label を付与する

## 書き込み先

- `/workspace`: 実際のプロジェクト
- `/home/agent`: リポジトリ配下の `.sandbox/home` に限定
- 監査ログ: `${XDG_STATE_HOME:-$HOME/.local/state}/ai-agent-sandbox/audit/container-runs.jsonl`

## BYOC 対策

- `run-sandbox.sh` と `compose-shell.sh` は start/finish をホスト側監査ログへ残す
- 監査ログはコンテナに mount しないホスト領域へ出力し、`--rm` でも消えない
- `compose-shell.sh` は `--service-ports` を使わず、不要なポート露出を避ける
- オンライン実行は明示フラグでのみ許可し、理由も記録する
- ホスト側の実行権限は `audit-host-security.sh` で棚卸しする
- CI では SBOM と checksum 署名を成果物として残す

## 検証ライン

- スモークテストでコンテナ境界、監査ログ、高リスク mount 拒否を確認する
- CI で lint と build を回す
- Security workflow で秘密情報、Dockerfile 品質、脆弱性を検査する

## 運用ルール

- オンライン実行は依存取得など必要なときだけ
- オンライン実行には用途を説明する `--reason` を付ける
- セキュリティ既定を緩める変更には文書更新を必須にする
- エージェント固有の設定差分は薄く保つ
