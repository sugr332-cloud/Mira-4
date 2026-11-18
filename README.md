# Mira BOX4 — Stream Dock 用ショートカット

Stream Dock のボタンから、アプリの起動／最前面化、音声デバイスの切り替えを行う `.bat` / `.ps1` 集です。

## ファイル

| ファイル | 内容 |
|---|---|
| `launch-focus.ps1` | 本体。アプリが起動中なら最前面へ、未起動なら起動してから最前面へ出し、ウィンドウ中央にマウスカーソルを移動する |
| `launch-companion.bat` | FullAIon2Companion 用 |
| `launch-aion2.bat` | AION2 (Steam `3393110`) 用 |
| `launch-orca.bat` | Orca 用。中央をクリックしてチャット欄にフォーカスも合わせる |
| `toggle-audio.bat` / `.ps1` | 出力＋マイクを スピーカー ⇔ ヘッドセット で切り替え |
| `config.json` | 切り替え対象のデバイス名（部分一致） |
| `icons/` | ボタン用アイコン (`orca-icon.png`, `aion2-icon.ico`, `companion-icon.ico`) |

## 使う前の準備

1. このフォルダ一式を、**短い固定パス**にコピーする（例: `C:\Tools\mira-box\`）。
   - 長い／ハイフンの多いパス（orca のワークスペース配下など）だと、Stream Dock が `.bat` を起動できないことがあった。
   - `.bat` と `.ps1`、`config.json` は **同じフォルダ**に置くこと。
2. アプリのパスが違う環境では `launch-focus.ps1` 冒頭の `$apps` を編集する。

## Stream Dock への登録方法

1. Stream Dock アプリで、空いているキーを選ぶ。
2. 右側の「システム」→「開く」(Open) をそのキーにドラッグする。
3. 下の設定欄に入力する。
   - **タイトル**: ボタン名
   - **App/File**: `.bat` のフルパス（`\` 区切り。例: `C:\Tools\mira-box\launch-orca.bat`）
   - **パラメータ**: 下表のとおり（不要なら空欄。`nircmd` 用の古い値が残っていないか注意）
   - **開く/表示する**: チェックなし
4. キーのアイコン画像をクリックし、`icons\` 内の画像を指定する。
5. 設定後は別のキーを選んで戻り、保存されているか確認する。実機のキーを押して動作確認する。

| ボタン | App/File | パラメータ | アイコン |
|---|---|---|---|
| Orca | `launch-orca.bat` | なし | `icons\orca-icon.png` |
| AION2 | `launch-aion2.bat` | なし | `icons\aion2-icon.ico` |
| Companion | `launch-companion.bat` | なし | `icons\companion-icon.ico` |
| ヘッドセットへ | `toggle-audio.bat` | `-To headset` | 任意 |
| スピーカーへ | `toggle-audio.bat` | `-To speaker` | 任意 |

`toggle-audio.bat` はパラメータ無しだと、押すたびに現在と反対側へ切り替わる。`-List` で認識しているデバイス一覧を表示できる。

## 新しいアプリを追加する

`launch-focus.ps1` の `$apps` に1行足し、`-ValidateSet` に名前を追加して、`launch-<名前>.bat` を作る。

```powershell
myapp = @{ Process = 'プロセス名'; Launch = 'exeのパス または steam://rungameid/ID'; Click = $true }
```

`Click = $true` は、最前面化後に中央をクリックして入力欄にフォーカスしたい場合のみ指定する（省略可）。

## 既知の注意点

- 管理者権限で動くアプリは、通常権限のスクリプトから前面化できないことがある。
- フルスクリーンのゲームでは、カーソルの中央移動が合わない場合がある。
- 前面化に Alt キーの単独押しは使わない（アプリのメニューが有効になり、Ctrl+C などが効かなくなるため）。
