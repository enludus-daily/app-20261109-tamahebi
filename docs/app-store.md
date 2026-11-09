# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.006 |
| アプリ名 | （毎日のセッションが決める。本人の許可 2026-11-04） |
| サポート URL | https://github.com/enludus-daily/app-20261109-tamahebi/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261109-tamahebi/blob/main/PRIVACY.md |
| 年齢区分の答え | 暴力・ギャンブルなし（カプセルはゲーム内ポイントだけで回す。換金性なし）。本人が入力 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：自作の物理パズルゲーム。懐中電灯・壁紙などの種類ではない
- 既存のアプリとの意味のある違い：打ち出した軌跡がそのまま胴体になり、その胴体がクッションになる（スネークとビリヤードの組み合わせ）
- 長く使える価値（4.2）：日付で決まる「きょうの台」、続けた日数、15匹のなかまの収集
- 他社の名前・商標・見た目を使っていないか：使っていない（キャラクター・絵はすべて自作のコード描画）
- Apple Intelligence：使わない
- ガチャ（3.1.1 のルートボックス）：カプセルはゲーム内で遊んでためたおやつだけで回す。お金では回せない。確率は画面（出るなかまと確率）に全部出している

## 収益の道筋（本人が選ぶ）

- 買い切りの Pro（com.enludus.daily.006.pro・¥480。枠 006 に残っていた商品を使い回す）
- 理由：README の「課金」

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない、解析・広告 SDK なし、保存は端末の UserDefaults だけ）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。足りない画面は本人と相談。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
