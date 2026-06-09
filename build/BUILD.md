# ビルド手順

スクリプトを更新したあとは、EXE と DMG を再ビルドしてください。

---

## Windows EXE (Inno Setup)

### 前提条件
- [Inno Setup 6](https://jrsoftware.org/isdl.php) がインストールされていること

### ビルド手順

```powershell
# Inno Setup でコンパイル（GUI）
# build\windows\installer.iss を右クリック → 「Compile」

# またはコマンドラインで:
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" build\windows\installer.iss
```

出力先: `dist\windows\ハコ割り生成ツール_setup.exe`

### 注意事項
- `installer.iss` は **UTF-8 BOM 付き** で保存してください
  - VS Code: 右下の文字コード表示 → 「UTF-8 with BOM で再度開く」
- `dist\windows\` フォルダは自動作成されます

---

## Mac DMG

### 前提条件
- macOS 環境（GitHub Actions でも可）
- Docker Desktop for Mac がインストールされていること
- （オプション）`create-dmg`: `brew install create-dmg`

### ビルド手順

```bash
# プロジェクトルートで実行
bash build/mac/build_dmg.sh
```

出力先: `dist/mac/ハコ割り生成ツール_setup.dmg`

### GitHub Actions でビルドする場合

`.github/workflows/build_dmg.yml` を作成:

```yaml
name: Build macOS DMG

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install create-dmg
        run: brew install create-dmg
      - name: Build DMG
        run: bash build/mac/build_dmg.sh
      - name: Upload DMG
        uses: actions/upload-artifact@v4
        with:
          name: mac-dmg
          path: dist/mac/*.dmg
```

GitHub の Actions タブ → 「Build macOS DMG」→「Run workflow」で実行。  
完了後、Artifacts から DMG をダウンロードできます。

---

## 配布ファイル一覧

| ファイル | 内容 |
|---------|------|
| `dist/windows/ハコ割り生成ツール_setup.exe` | Windows インストーラー |
| `dist/mac/ハコ割り生成ツール_setup.dmg` | Mac インストーラー |

---

## バージョン更新時のチェックリスト

- [ ] `scripts/app.py` または `scripts/sync_srt.py` を修正
- [ ] `build/windows/installer.iss` の `AppVersion` を更新
- [ ] `build/mac/build_dmg.sh` 内の `1.0.0` を更新
- [ ] EXE をリビルド
- [ ] DMG をリビルド（Mac 環境または GitHub Actions）
- [ ] `docs/マニュアル.md` の末尾バージョン表記を更新
