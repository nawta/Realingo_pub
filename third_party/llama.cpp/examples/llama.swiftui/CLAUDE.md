# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.




このファイルは本プロジェクトのコーディング規約および設定を記載 した「ルール」または「ルールファイル」です。


## 最も重要なルール

ユーザーから今回限りではなく常に対応が必要だと思われる指示を受けた場合：

1.  「これを標準のルールにしますか？」と質問する
2.  YESの回答を得た場合、CLAUDE.mdに追加ルールとして記載する
3.  以降は標準ルールとして常に適用する

このプロセスにより、プロジェクトのルールを継続的に改善していきます。

## 標準ルール（常に適用）

### 作業とコミットの原則
- 作業で変更・追加したファイルは随時コミットする
- Git設定: user.name="nawta", user.email="nawta1998@gmail.com"
- コミットメッセージは変更内容を明確に記載
- 作業内容は随時logs/Log_{日付}.mdファイルに書き込んでいく。同じ日付であれば同じmdファイルに追記していく
- 指示に従って段階的に作業を進める（先走らない）. TODO.mdにTODOを随時更新していき，それに従って実装を行う．TODO.mdには実装中のもの，実装完了したもの，実装予定のものを書き込む
- 長時間の実行に失敗したり，必要なライブラリを入れたり，sudo権限を使う必要があるなどユーザの介入が必要な場合は素直に申し出て指示を待つ
- 簡略化した実装など行った場合は報告する
- 主要クラスの冒頭に、設計ドキュメントへの参照と、関連クラスのメモを、コメントとしてつけてください。

### View実装の原則
- 各Viewは必ずExtendedQuizを受け取れる構造にする
- 問題データの受け渡しができるよう、適切なイニシャライザを実装する
- NavigationDestinationで遷移する際は、必要なデータを渡せるようにする

## タスク実行ガイドライン - Ultrathink Mode

### 目的
与えられたタスクに対して、ultrathink （拡張思考）を用いて徹底的な調査と分析を行い、高品質な提案と実装を提供する。

### 実行プロセス

1. **初期分析**（Ultrathink Phase）
   - タスクの要件を完全に理解
   - 関連する全ての側面を検討
   - 必要な情報と調査範囲を特定
   - **重要**：不明な点は推測せず、確認を優先

2. **情報収集**（Research Phase）
   - コードベースの関連部分を徹底的に確認
   - 周辺コードとの依存関係を把握
   - 必要に応じてドキュメントやWeb情報を参照
   - 既存の実装パターンを理解

3. **解決策の検討**（Solution Design Phase）
   - 複数のアプローチを比較検討
   - 各案の実現可能性とトレードオフを評価
   - プロジェクトのベストプラクティスとの整合性を確認
   - 将来の拡張性を考慮

4. **実装計画**（Implementation Planning Phase）
   - 推奨する解決策を根拠と共に説明
   - 実装の具体的な手順を段階的に提示
   - 影響を受けるファイルと変更内容を明確化
   - テスト方針を含める

5. **リスク評価**（Risk Assessment Phase）
   - 潜在的な問題点を特定
   - 副作用や破壊的変更の可能性を評価
   - 必要な確認事項を列挙
  

### 品質保証基準
- 事実とコードに基づいた分析
- 現在の実行環境の確認を怠らない
- 推測や仮定を行う場合は明示的に述べる
- 不確実な点は質問として提示
- 実装前に確認が必要な事項を明確化
- 実装後は一時的に生成したファイルなどは消去し，コードベースを綺麗に保つこと
- 実装後は変更したファイルに対しコミットを行う．その際は`git condig user.name`が`nawta`, `git config user.email`が`nawta1998@gmail.com`にすること．

### 禁止事項
- コンテキストを確認せずに実装を進める
- 周辺コードへの影響を考慮しない変更
- 推測に基づいた破壊的変更
- 確認なしでの大規模リファクタリング


## Gemini CLI 連携ガイド

### 目的
ユーザーが **「Geminiと相談しながら進めて」** （または同義語）と指示した場合、Claude は以降のタスクを **Gemini CLI** と協調しながら進める。
Gemini から得た回答はそのまま提示し、Claude 自身の解説・統合も付け加えることで、両エージェントの知見を融合する。なお，Geminiは検索能力とコンテクスト長に長けているモデルであるが，コーディング能力自体はClaudeの方が長けていることが多い．

---

### トリガー
- 正規表現: `/Gemini.*相談しながら/`
- 例:
- 「Geminiと相談しながら進めて」
- 「この件、Geminiと話しつつやりましょう」

---

### 基本フロー
1. **PROMPT 生成**
Claude はユーザーの要件を 1 つのテキストにまとめ、環境変数 `$PROMPT` に格納する。

2. **Gemini CLI 呼び出し**
```bash
gemini <<EOF
$PROMPT
EOF

## o3 連携ガイド
ユーザーが **「o3と相談しながら進めて」** （または同義語）と指示した場合、Claude は以降のタスクを **ChatGPT o3** と協調しながら進める。
この際，実装でエラーが解消できなくて困ったらo3に聞いてみるとネット検索結果をうまくまとめて返してくれることが多い．


上記のガイドラインに従ってください！
