# claude-upgrade-advisor

[English](./README.md) · **日本語**

Claude Code やモデルのラインナップが変わったことを検知し、公式ドキュメントを読んで
「実際に何が変わったのか」を報告した上で、あなたのプロジェクトのハーネス設計と設定が
それに対して適切かを診断する Claude Code プラグインです。

提案はしますが、勝手に書き換えることはありません。

---

## なぜ必要か

Claude Code は頻繁に更新されます。更新のたびに設定キーが増え、フックイベントが増え、
デフォルト値が変わり、新しいモデルが出ます。そして `CLAUDE.md` や `settings.json`、
`.mcp.json` には、もう存在しないバージョンの前提が静かに残り続けます。

Claude に「何が新しくなった?」と聞いても確実な答えは返りません。モデルの学習データは、
あなたが尋ねているリリースより古いからです。このプラグインは尋ねられたその時点で
公式ドキュメントを取得するので、答えが記憶ではなくドキュメントから出てきます。

## 何をするか

1. **検知** — `SessionStart` フックが、動作中の Claude Code のバージョンと使用中の
   モデルを、前回記録した内容と照合します。
2. **調査** — 依頼を受けたときに公式 CHANGELOG とリファレンスを取得し、前回の確認
   以降に何が変わったかを報告します。
3. **診断** — グローバルとプロジェクトの設定を検査します。古いモデルID、ドキュメントに
   存在しない設定キー、壊れたフック定義、広すぎる permissions、`CLAUDE.md` の陳腐化、
   MCP の設定ミスなどを見ます。
4. **提案** — 重大度順に差分を提示し、あなたの判断を待ちます。

## 何をしないか

これは願望ではなく保証です。インストールしたまま放置しても安全である理由です。

- **設定を書き換えません。** すべての変更は、あなたが承認する提案として提示されます。
- **セッション起動時にネットワークを使いません。** フックはローカル処理のみ。
  ドキュメント取得は、あなたがスキルを実行したときに行われます。
- **セッションを遅くしたり壊したりしません。** フックは常に exit 0 で終わります。
  失敗しても黙って失敗します。
- **うるさくしません。** 変化がなければ出力は一切ありません。新しいバージョンと
  新しいモデルについて、それぞれ1回だけ言及します。
- **外部に送信しません。** テレメトリなし。ネットワーク通信は Anthropic の公開
  ドキュメントの取得だけで、それも Claude が行うのであなたに見えています。
- **認証情報を保存しません。** 設定ファイルは診断のために読みますが、認証情報らしき
  値は会話に出る前にマスクします。

## 動作要件

- Claude Code（`/plugin` が使えるバージョン）
- `bash` と標準的な POSIX ツール（`sed`, `grep`, `awk`, `date`）
- `jq` はあれば使いますが、**必須ではありません**

macOS で検証済みです。GNU 限定のフラグを避け、BSD 版と GNU 版の `date` 双方に対応して
いるので Linux でも動くはずですが、動かなければ Issue を立ててください。

## インストール

デフォルトで **ユーザースコープ** に入るので、どのプロジェクトでも有効になります。

```bash
claude plugin marketplace add OzawaG/claude-upgrade-advisor
claude plugin install claude-upgrade-advisor@ozawag-plugins --scope user
```

Claude Code の中からでも構いません。

```
/plugin marketplace add OzawaG/claude-upgrade-advisor
/plugin install claude-upgrade-advisor@ozawag-plugins
```

インストール後、基準点を作るために1回実行してください。

```
/claude-upgrade-advisor:upgrade-check
```

これをやるまでは「前回いつドキュメントを確認したか」の記録がないため、比較対象が
ありません。

### インストールせずに試す

```bash
git clone https://github.com/OzawaG/claude-upgrade-advisor
claude --plugin-dir ./claude-upgrade-advisor
```

そのセッションだけ読み込まれます。後述の state ディレクトリ以外は何も残しません。

## 使い方

### 自動

セッション開始時に変化があれば、Claude が1回だけ言及します。

> claude-upgrade-advisor noticed a change in this environment. Claude Code was
> 2.1.219 at the last recorded session and is 2.1.220 now.

そこから先は、調べるかどうかはあなたの判断です。Claude には「勝手に実行するな」と
指示してあります。

### 手動

```
/claude-upgrade-advisor:upgrade-check
```

| 引数 | 動作 |
|---|---|
| *(なし)* | ドキュメント調査 → 設定診断 |
| `--docs-only` | 変更点の報告のみ。診断を飛ばす |
| `--audit-only` | 診断のみ。ドキュメント調査を飛ばす |
| `2.1.180` | そのバージョンを比較基準にする |

レポートは `<config>/claude-upgrade-advisor/reports/` に書き出されます。

## アンインストール

3段階あります。小さいものから並べてあるので、苛立ちの度合いに合わせて選んでください。

### 1. 黙らせるだけ

インストールしたまま、フックの発言だけ止めます。

```bash
touch "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/claude-upgrade-advisor/disabled"
```

シェルの設定ファイルで環境変数を設定しても同じです。

```bash
export CLAUDE_UPGRADE_ADVISOR_DISABLED=1
```

ファイルを消すか変数を外せば元に戻ります。

### 2. プラグインを外す

```
/plugin uninstall claude-upgrade-advisor
/plugin marketplace remove ozawag-plugins
```

読み込まれなくなります。state ディレクトリは残るので、後で入れ直せば続きから再開
できます。

### 3. 完全に消す

```bash
./scripts/uninstall.sh
```

何を削除するか列挙して確認を求め、削除し、残骸がないことを検証して報告します。
`--dry-run` で確認だけ、`--yes` で確認を省略できます。

書き込み先が1ディレクトリだけなので、これは「たぶん消えた」ではなく完全な削除です。
拾い忘れるファイルが原理的に存在しません。

そのあと手順2でプラグイン本体を外してください。

## 何を読み、どこに書くか

**読むもの**（診断のためだけに読みます）:

- `<config>/settings.json`, `settings.local.json`, `CLAUDE.md`
- `<config>/plugins/installed_plugins.json`, `known_marketplaces.json`
- `<config>/skills/`, `<config>/agents/` — 名前だけ
- カレントプロジェクトの `CLAUDE.md`, `.claude/settings*.json`, `.mcp.json`,
  `.claude/hooks/`, `.claude/agents/`, `.claude/skills/`, `.claude/commands/`

`<config>` は `$CLAUDE_CONFIG_DIR`、未設定なら `~/.claude` です。

**書くもの** — 1ディレクトリだけ。その外には一切書きません。

```
<config>/claude-upgrade-advisor/
├── state.json        既に見たバージョンと日付
├── seen-models       観測したモデルID（1行1件）
├── disabled          これを作るとフックが黙る
└── reports/          診断レポート。自由に消してよい
```

**認証情報のマスク。** 設定ファイルには API キーが入っていることがあります。ファイルの
内容が会話に出る前に、フィールド名が認証情報らしいもの（`token`, `key`, `secret`,
`password`, `auth`, `credential`, `passphrase` — 大文字小文字は問わない）と、値の形が
認証情報らしいもの（`sk-ant-`, `sk-`, `ghp_`, `github_pat_`, `xoxb-`, `AKIA`, `AIza`,
`glpat-`, `Bearer …`, JWT）を伏せます。

マスクは意図的に過剰です。`apiKeyHelper` のような無害なフィールドまで伏せます。
診断の細かさを少し失うことと、生きたトークンを漏らすことでは、前者を選ぶべきだと
考えています。このリポジトリ自体に認証情報は一切含まれておらず、パスはすべて環境変数
経由で解決しています。

## 設定

すべて任意で、すべて環境変数です。

| 変数 | 既定値 | 効果 |
|---|---|---|
| `CLAUDE_UPGRADE_ADVISOR_DISABLED` | 未設定 | 空でない値を入れるとフックが黙る |
| `CLAUDE_UPGRADE_ADVISOR_STALE_DAYS` | `14` | 再確認を促すまでの日数。`0` でタイマー無効 |
| `CLAUDE_UPGRADE_ADVISOR_LANG` | 未設定 | レポートの言語を固定。既定はあなたの言語に合わせる |
| `CLAUDE_CONFIG_DIR` | `~/.claude` | state の位置に反映。プラグイン固有の設定ではない |

## 検知の仕組み

フックは意図的に退屈な作りです。セッション起動のクリティカルパスに乗るからです。

- **CLI バージョン** — `claude --version` から取得。実測で約 40ms。
- **新しいモデル** — `model` フィールドを受け取れるフックイベントは `SessionStart`
  だけで、しかも任意フィールドです。そして `seen-models` に一度も現れていないモデルだけを
  「新しい」と判定します。これが `/model` での切り替えをモデルのリリースと誤認しない
  仕組みです。既に使ったことのあるモデル間を行き来しても、永久に沈黙します。
- **鮮度** — `STALE_DAYS` の間ドキュメントを確認していなければ、1期間に最大1回だけ
  指摘します。ドキュメントだけの更新はバージョン番号が動かないので、それを拾う網です。

フックが記録するものはすべて、読める・編集できる・消せる普通のファイルです。

## 開発

```bash
claude plugin validate .          # リリース前に必ず通す
claude --plugin-dir .             # インストールせず読み込む
/reload-plugins                   # 再起動せず変更を反映
```

フックには挙動テストがあります。初回実行、変化なし、バージョン更新、新モデル、
モデル切り替え、2種類のキルスイッチ、`claude` バイナリ不在、不正な stdin、`jq` なしでの
実行を網羅しています。

Pull Request を歓迎します。[何をしないか](#何をしないか) に挙げた保証は壊さないで
ください。それがこのプラグインの価値のすべてです。

## このリポジトリを消す

clone や fork したものを消したいなら、自分の複製を削除してください。所有者の場合は:

```bash
gh repo delete OzawaG/claude-upgrade-advisor
```

一度 public にしたリポジトリは、既に第三者が fork・clone・キャッシュしている可能性が
あります。オリジナルを削除しても、それらの複製は取り消せません。

## ライセンス

[MIT](./LICENSE)
