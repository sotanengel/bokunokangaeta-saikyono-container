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

## 書き込み先

- `/workspace`: 実際のプロジェクト
- `/home/agent`: リポジトリ配下の `.sandbox/home` に限定

## 検証ライン

- スモークテストでコンテナ境界と基本ツールを確認する
- CI で lint と build を回す
- Security workflow で秘密情報、Dockerfile 品質、脆弱性を検査する

## 運用ルール

- オンライン実行は依存取得など必要なときだけ
- セキュリティ既定を緩める変更には文書更新を必須にする
- エージェント固有の設定差分は薄く保つ
