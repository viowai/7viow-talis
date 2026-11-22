<p align="center"><img src="Resources/AppIconSource.png" width="112" height="112" alt="Talis アプリアイコン"></p>

[English](README.md) | [简体中文](README.zh-CN.md) | [Español](README.es.md) | [Português do Brasil](README.pt-BR.md) | [日本語](README.ja.md) | [Français](README.fr.md) | [हिन्दी](README.hi.md)

# Talis

考えを整理して、AIに渡しましょう。

TalisはmacOS向けのPromptワークスペースです。アイデアを書き、編集を続けられるPromptを作成して、いつも使っているAIツールにコピーできます。大切な条件が足りないときは質問で補い、繰り返し使う要件は個人用テンプレートとして保存できます。

続けて修正するときは、直近3ラウンドを文脈として使います。**修正履歴**を開くと、現在のセッションの入力と結果を確認できます。新しい作業を始めるには、エディタの**クリア**を使います。

## インストール

### DMGからインストール

[Talis v1.0.1 DMG](https://github.com/viowai/7viow-talis/releases/download/v1.0.1/talis-v1.0.1-macos-arm64-build42.dmg)をダウンロードします。ディスクイメージを開き、`Talis.app`を**アプリケーション**へドラッグして、そこから起動します。Apple Silicon搭載MacとmacOS 13以降が必要です。

アプリはad-hoc署名で、Appleによる公証は受けていません。初回起動をmacOSに止められた場合は、このリポジトリからダウンロードしたことを確認し、選択肢が表示される場合は**システム設定 → プライバシーとセキュリティ**で**このまま開く**を選びます。[Appleの初回起動手順](https://support.apple.com/en-us/102445)も参照してください。

ソースからビルドするには、macOS 26 SDK以降を含むXcode 26以降の開発ツールが必要です。Apple Siliconでのビルドを確認済みです。Intelは未確認です。有料のApple Developerメンバーシップは不要です。サードパーティ製Swift Packageへの依存はありません。

### ソースからインストール

Macのターミナルで実行します。

```bash
git clone https://github.com/viowai/7viow-talis.git
cd 7viow-talis
bash scripts/install_app.sh && open /Applications/Talis.app
```

Appleの開発ツールがない場合は、`xcode-select --install`を実行してシステムの案内を完了します。Talisが起動中なら、編集中のテキストを保存して終了してからインストールしてください。個人用テンプレートと設定はアプリ本体とは別に保持されます。

## 初めて使う

API Keyを設定しなくても、Promptの編集とコピーを試せます。

1. Talisを開き、`Option + Space`を押します。
2. 内容を入力し、`Command + Return`でコピーして、使いたいAIツールに貼り付けます。

AIで文章を調整するには、歯車ボタンから**AIサービス設定**を開きます。**API Key**または**サブスクリプション**を選び、サービスと地域を指定して保存します。エディタに戻り、**調整**、**書き換え**、**質問**を選べます。結果は編集でき、完成したら**Promptをコピー Cmd+Return**を使います。

## AIサービスとデータ

編集、テンプレート選択、コピーはオフラインで使えます。調整、書き換え、質問、AIテンプレート生成には接続可能なサービスが必要です。API Key方式の料金は各プロバイダーの規約に従います。サブスクリプション方式は、このMacでサインイン済みのAI製品の契約を使い、別のAPI Keyは不要です。

API KeyはプロバイダーごとにmacOSキーチェーンへ保存されます。サブスクリプション方式はローカルでサインイン済みの製品を利用し、そのOAuthトークンをコピーまたは保存しません。モデル、アカウント、地域、利用枠の提供状況は各サービスによって異なります。[AIサービス設定](docs/ai-services.en.md)と[プライバシーとデータ](docs/privacy.en.md)を参照してください。

Talisはテキストをクリップボードにコピーします。ユーザーに代わってAIへ依頼を送ったり、添付ファイルを転送したりしません。Prompt ServiceとTalis Codexはこのデスクトップ版に含まれません。

## フィードバックとライセンス

問題を報告するには、アプリのバージョン、macOSのバージョン、チップの種類、操作手順、エラー内容を添えて[GitHub Issue](https://github.com/viowai/7viow-talis/issues)を作成してください。API Keyや個人情報は事前に削除してください。

メンテナー：Viow。ソースコードとオリジナル文書は[Apache License 2.0](LICENSE)、Copyright 2026 Wenbin Liで提供されています。[NOTICE](NOTICE)と[第三者ライセンス表示](THIRD-PARTY-NOTICES.md)も参照してください。MontserratはSIL Open Font License 1.1で配布されています。
