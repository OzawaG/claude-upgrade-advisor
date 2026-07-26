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

## `/doctor` との違い

Claude Code には設定診断が最初から入っています（`/doctor`、別名 `/checkup`）。
インストールが壊れている、認証が通らない、バイナリが無い、MCP サーバーが起動しない、
といった問題はそちらの担当です。

このプラグインが答えるのは別の問いです。設定が**リリースに対して古くなっていないか**。
引退したモデルIDが残っている、存在しない設定キーを書いている、`CLAUDE.md` が2バージョン前の
挙動を説明している、といったものです。インストールが健全でも設定は腐りますし、
`/doctor` はそれを通してしまいます。

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

### 更新する

```bash
claude plugin marketplace update ozawag-plugins
claude plugin update claude-upgrade-advisor@ozawag-plugins
```

`update` には `plugin@marketplace` の形式が必要です。名前だけ渡すと
「Plugin not found」になります。反映には Claude Code の再起動が必要です。

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

## 情報の出どころ

このプラグインの存在意義は、答えがモデルの記憶ではなく Anthropic のドキュメントから
出てくることです。それを3つのルールで担保しています。

**公式のみ。** Anthropic が公開しているものだけを扱います。`code.claude.com`、
`platform.claude.com`、`support.claude.com`、`www.anthropic.com`、
`github.com/anthropics`、`api.anthropic.com`。第三者のブログ、フォーラム、
ニュースレター、動画は、どれだけ質が高くても使いません。

**第一情報のみ。** それを説明しているものではなく、それ自体である情報源を引きます。
「どのバージョンで変わったか」は CHANGELOG の担当。「その設定が今どう動くか」は
リファレンスページの担当。モデル一覧については `/v1/models` がどのページよりも上位です。

**根拠は必須。** すべての記述に、出典URLと、適用されるバージョンまたは日付が付きます。
両方を付けられない記述は「未検証」として、どの情報源に到達できなかったかを名指しで
報告します。記憶で埋めることはしません。

### 読む情報源

| 情報源 | 何のために |
|---|---|
| [`CHANGELOG.md`](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) | どのバージョンで何が変わったか |
| [週次ダイジェスト](https://code.claude.com/docs/en/whats-new) | その変更がなぜ効くのか。各週にバージョン範囲のタグが付いているので、自分の差分に重なる週だけ取得する |
| [モデル一覧](https://platform.claude.com/docs/en/about-claude/models/overview)と[廃止予定](https://platform.claude.com/docs/en/about-claude/model-deprecations) | モデルID、仕様、引退日 |
| モデル別の what's-new ページ | 挙動変更と破壊的変更 |
| [Platform リリースノート](https://platform.claude.com/docs/en/release-notes/overview) | API と SDK の変更 |
| Claude Code の各リファレンス | 設定・フック・permissions が今も有効かどうか |
| `GET /v1/models` | 任意。下記参照 |
| [`llms.txt`](https://code.claude.com/docs/llms.txt) 索引 | URLが移動したときに現在のパスを探す |

### API エンドポイントについて

`GET /v1/models` は存在するかぎり最も確実なモデル一覧です。ページが説明しているのでは
なく、API 自身が答えているからです。ただし API キーが必要なので、**既定では無効**です。

環境変数 `ANTHROPIC_API_KEY` が既に設定されている場合だけ実行します。プラグインは
キーを要求しません。表示しません。レポートに書き込みません。未設定なら黙って飛ばし、
「モデル一覧はドキュメントから取得した」とレポートに書きます。サブスクリプション利用者は
通常キーを持っていないので、無いことは問題として扱いません。

### 使わないもの、その理由

X は「使えそうに見える」ので、名前を挙げて理由を書いておきます。Anthropic の
[@AnthropicAI](https://x.com/AnthropicAI) は公式かつ第一情報です。ただし `x.com` は
未認証のリクエストに HTTP 402 を返すため、プログラムから読めません。投稿は告知レベルで
バージョン番号が付かず、そこに書かれた事実はすべて根拠付きでドキュメントに載ります。
「何かが出た」ことを知るために自分で読むのは有効です。「何が出たか」を根拠付きで出すのが
このプラグインの役割です。

同様に除外: YouTube、LinkedIn、Discord、第三者のブログ、Reddit、Hacker News、
そしてモデルが記憶しているだけの内容。

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
