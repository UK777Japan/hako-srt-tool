#!/bin/bash
# ハコ割り生成ツール DMG ビルドスクリプト（Docker 不要版）
# 実行環境: macOS（GitHub Actions macos-14 / ローカル Mac 両対応）
# 実行方法: bash build/mac/build_dmg.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist/mac"
CACHE_DIR="$SCRIPT_DIR/cache"
TMP_DIR="$SCRIPT_DIR/build_tmp"
APP_NAME="ハコ割り生成ツール"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
STOP_BUNDLE="$DIST_DIR/${APP_NAME}_停止.app"
DMG_NAME="${APP_NAME}_setup.dmg"
WHISPER_MODEL="turbo"

ARCH=$(uname -m)  # arm64 または x86_64

echo ""
echo "============================================"
echo "  $APP_NAME DMG ビルド（Docker 不要版）"
echo "  アーキテクチャ: $ARCH"
echo "============================================"

rm -rf "$DIST_DIR" "$TMP_DIR"
mkdir -p "$DIST_DIR" "$CACHE_DIR" "$TMP_DIR"

# ──────────────────────────────────────────────────────────────────────────────
# 1. Python 3.11 standalone をセットアップ
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "[1/6] Python 3.11 standalone をセットアップ..."

PY_VERSION="3.11.11"
PY_RELEASE="20250106"
if [ "$ARCH" = "arm64" ]; then
    PY_ARCH_TAG="aarch64-apple-darwin"
else
    PY_ARCH_TAG="x86_64-apple-darwin"
fi
PY_FILE="cpython-${PY_VERSION}+${PY_RELEASE}-${PY_ARCH_TAG}-install_only.tar.gz"
PY_URL="https://github.com/indygreg/python-build-standalone/releases/download/${PY_RELEASE}/${PY_FILE}"
PY_CACHE="$CACHE_DIR/python-standalone-${ARCH}.tar.gz"

if [ ! -f "$PY_CACHE" ]; then
    echo "      ダウンロード中: $PY_URL"
    curl -fL "$PY_URL" -o "$PY_CACHE"
fi
echo "      展開中..."
mkdir -p "$TMP_DIR/python_src"
tar -xzf "$PY_CACHE" -C "$TMP_DIR/python_src"
PYTHON_DIR="$TMP_DIR/python_src/python"
PYTHON_EXE="$PYTHON_DIR/bin/python3"
echo "      Python セットアップ完了"

# ──────────────────────────────────────────────────────────────────────────────
# 2. Pythonパッケージをインストール
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "[2/6] Pythonパッケージをインストール中（数分かかります）..."

"$PYTHON_EXE" -m pip install --upgrade pip --quiet

echo "      torch をインストール中..."
"$PYTHON_EXE" -m pip install torch --quiet

echo "      その他パッケージをインストール中..."
"$PYTHON_EXE" -m pip install \
    "streamlit>=1.35.0" \
    "stable-ts>=2.7.0" \
    "fugashi>=1.3.0" \
    "unidic-lite>=1.0.8" \
    "numpy<2.0" \
    "openai>=1.0.0" \
    --quiet

echo "      パッケージインストール完了"

# ──────────────────────────────────────────────────────────────────────────────
# 3. ffmpeg をセットアップ（imageio-ffmpeg の静的バイナリを使用）
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "[3/6] ffmpeg をセットアップ..."

FFMPEG_BIN_DIR="$TMP_DIR/tools/ffmpeg/bin"
mkdir -p "$FFMPEG_BIN_DIR"

# imageio-ffmpeg が提供するポータブル静的バイナリを使用（Homebrew 不要）
"$PYTHON_EXE" -m pip install imageio-ffmpeg --quiet

FFMPEG_BINARY=$("$PYTHON_EXE" -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
if [ ! -f "$FFMPEG_BINARY" ]; then
    echo "      [エラー] ffmpeg バイナリが見つかりません: $FFMPEG_BINARY"
    exit 1
fi
cp "$FFMPEG_BINARY" "$FFMPEG_BIN_DIR/ffmpeg"
chmod +x "$FFMPEG_BIN_DIR/ffmpeg"

echo "      ffmpeg セットアップ完了: $(basename "$FFMPEG_BINARY")"

# ──────────────────────────────────────────────────────────────────────────────
# 4. Whisper モデルをダウンロード（EXE に同梱してインストール後すぐ使える）
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "[4/6] Whisper モデル ($WHISPER_MODEL) をダウンロード中..."

MODEL_DIR="$TMP_DIR/models/whisper"
mkdir -p "$MODEL_DIR"

WHISPER_CACHE_DIR="$MODEL_DIR" "$PYTHON_EXE" -c "
import stable_whisper, os
model_dir = os.environ['WHISPER_CACHE_DIR']
stable_whisper.load_model('$WHISPER_MODEL', download_root=model_dir)
"

MODEL_FILE=$(ls "$MODEL_DIR"/*.pt 2>/dev/null | head -1)
if [ -z "$MODEL_FILE" ]; then
    echo "      [エラー] Whisper モデルのダウンロードに失敗しました"
    exit 1
fi
MODEL_SIZE=$(du -sh "$MODEL_FILE" | cut -f1)
echo "      完了: $(basename "$MODEL_FILE") ($MODEL_SIZE)"

# ──────────────────────────────────────────────────────────────────────────────
# 5. .app バンドルを作成
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "[5/6] .app バンドルを作成中..."

# ── 起動 .app ──
RESOURCES="$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$RESOURCES"

cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ハコ割り生成ツール</string>
    <key>CFBundleDisplayName</key>
    <string>ハコ割り生成ツール</string>
    <key>CFBundleIdentifier</key>
    <string>com.hakosrt.app</string>
    <key>CFBundleVersion</key>
    <string>1.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

cat > "$APP_BUNDLE/Contents/MacOS/launcher" << 'LAUNCHER'
#!/bin/bash
RESOURCES="$(cd "$(dirname "$0")/../Resources" && pwd)"
bash "$RESOURCES/start.command"
LAUNCHER
chmod +x "$APP_BUNDLE/Contents/MacOS/launcher"

# ファイルをコピー
cp -r "$PYTHON_DIR"               "$RESOURCES/python"
cp -r "$TMP_DIR/tools"            "$RESOURCES/"
cp -r "$TMP_DIR/models"           "$RESOURCES/"
cp -r "$PROJECT_ROOT/scripts"     "$RESOURCES/"
cp -r "$PROJECT_ROOT/.streamlit"  "$RESOURCES/"
[ -d "$PROJECT_ROOT/docs" ] && cp -r "$PROJECT_ROOT/docs" "$RESOURCES/"
cp "$SCRIPT_DIR/start.command"    "$RESOURCES/"
cp "$SCRIPT_DIR/stop.command"     "$RESOURCES/"
chmod +x "$RESOURCES/start.command"
chmod +x "$RESOURCES/stop.command"

echo "   起動 .app 完成"

# ── 停止 .app ──
mkdir -p "$STOP_BUNDLE/Contents/MacOS" "$STOP_BUNDLE/Contents/Resources"

cat > "$STOP_BUNDLE/Contents/Info.plist" << 'STOPPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ハコ割り生成ツール_停止</string>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
STOPPLIST

cp "$SCRIPT_DIR/stop.command" "$STOP_BUNDLE/Contents/Resources/"
chmod +x "$STOP_BUNDLE/Contents/Resources/stop.command"

cat > "$STOP_BUNDLE/Contents/MacOS/launcher" << 'STOPLAUNCH'
#!/bin/bash
RESOURCES="$(cd "$(dirname "$0")/../Resources" && pwd)"
bash "$RESOURCES/stop.command"
STOPLAUNCH
chmod +x "$STOP_BUNDLE/Contents/MacOS/launcher"

echo "   停止 .app 完成"

# ──────────────────────────────────────────────────────────────────────────────
# 6. DMG を作成
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "[6/6] DMG を作成中..."

TMP_DMG_DIR="$(mktemp -d)"
cp -r "$APP_BUNDLE"  "$TMP_DMG_DIR/"
cp -r "$STOP_BUNDLE" "$TMP_DMG_DIR/"
ln -s /Applications  "$TMP_DMG_DIR/Applications"
[ -d "$PROJECT_ROOT/docs" ] && cp -r "$PROJECT_ROOT/docs" "$TMP_DMG_DIR/"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$TMP_DMG_DIR" \
    -ov -format UDZO \
    "$DIST_DIR/$DMG_NAME"

rm -rf "$TMP_DMG_DIR" "$TMP_DIR"

DMG_SIZE=$(du -sh "$DIST_DIR/$DMG_NAME" | cut -f1)
echo ""
echo "============================================"
echo "  ビルド完了！ ($DMG_SIZE)"
echo "  → $DIST_DIR/$DMG_NAME"
echo "============================================"
echo ""
echo "【配布方法】"
echo "  1. $DMG_NAME を配布"
echo "  2. DMG を開き「ハコ割り生成ツール.app」をダブルクリック"
echo "  3. 初回は右クリック→「開く」で Gatekeeper 警告を回避"
