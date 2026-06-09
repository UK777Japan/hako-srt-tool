#!/bin/bash
# ハコ割り生成ツール DMG ビルドスクリプト
# 実行環境: macOS
# 実行方法: bash build/mac/build_dmg.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_MAC_DIR="$SCRIPT_DIR"
DIST_DIR="$PROJECT_ROOT/dist/mac"
APP_NAME="ハコ割り生成ツール"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_NAME="${APP_NAME}_setup.dmg"

echo "=== $APP_NAME DMG ビルド ==="
echo "プロジェクトルート: $PROJECT_ROOT"
echo "出力先: $DIST_DIR"
echo ""

# dist ディレクトリ準備
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# ---- .app バンドル作成 ----
echo "1. .app バンドルを作成中..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Info.plist
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
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# ランチャー（Terminal で start.command を開く）
cat > "$APP_BUNDLE/Contents/MacOS/launcher" << 'LAUNCHER'
#!/bin/bash
DIR="$(cd "$(dirname "$0")/../Resources" && pwd)"
open -a Terminal "$DIR/start.command"
LAUNCHER
chmod +x "$APP_BUNDLE/Contents/MacOS/launcher"

# アプリファイルをコピー
cp "$PROJECT_ROOT/Dockerfile"         "$APP_BUNDLE/Contents/Resources/"
cp "$PROJECT_ROOT/requirements.txt"   "$APP_BUNDLE/Contents/Resources/"
cp "$SCRIPT_DIR/../docker-compose.dist.yml" \
                                       "$APP_BUNDLE/Contents/Resources/docker-compose.yml"

cp -r "$PROJECT_ROOT/scripts"         "$APP_BUNDLE/Contents/Resources/"
cp -r "$PROJECT_ROOT/.streamlit"      "$APP_BUNDLE/Contents/Resources/"
cp -r "$PROJECT_ROOT/docs"            "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true

cp "$BUILD_MAC_DIR/start.command"     "$APP_BUNDLE/Contents/Resources/"
cp "$BUILD_MAC_DIR/stop.command"      "$APP_BUNDLE/Contents/Resources/"
chmod +x "$APP_BUNDLE/Contents/Resources/start.command"
chmod +x "$APP_BUNDLE/Contents/Resources/stop.command"

echo "   .app バンドル完成: $APP_BUNDLE"

# ---- 停止用 .app （AppleScript）----
echo "2. 停止用 .app を作成中..."
STOP_APP="$DIST_DIR/${APP_NAME}_停止.app"
STOP_RESOURCES="$STOP_APP/Contents/Resources"
mkdir -p "$STOP_APP/Contents/MacOS"
mkdir -p "$STOP_RESOURCES"

cat > "$STOP_APP/Contents/Info.plist" << 'STOPPLIST'
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
</dict>
</plist>
STOPPLIST

cp "$PROJECT_ROOT/build/docker-compose.dist.yml" "$STOP_RESOURCES/docker-compose.yml"
cp "$BUILD_MAC_DIR/stop.command" "$STOP_RESOURCES/"
chmod +x "$STOP_RESOURCES/stop.command"

cat > "$STOP_APP/Contents/MacOS/launcher" << 'STOPLAUNCH'
#!/bin/bash
DIR="$(cd "$(dirname "$0")/../Resources" && pwd)"
open -a Terminal "$DIR/stop.command"
STOPLAUNCH
chmod +x "$STOP_APP/Contents/MacOS/launcher"

echo "   停止 .app 完成"

# ---- DMG 作成 ----
echo "3. DMG を作成中..."

TMP_DMG_DIR="$(mktemp -d)"
cp -r "$APP_BUNDLE"  "$TMP_DMG_DIR/"
cp -r "$STOP_APP"    "$TMP_DMG_DIR/"
# Applications フォルダへのエイリアス
ln -s /Applications  "$TMP_DMG_DIR/Applications"
# docs フォルダ
if [ -d "$PROJECT_ROOT/docs" ]; then
    cp -r "$PROJECT_ROOT/docs" "$TMP_DMG_DIR/"
fi

if command -v create-dmg &>/dev/null; then
    # create-dmg (brew install create-dmg) が使える場合はきれいな DMG を作成
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 150 \
        --window-size 620 420 \
        --icon-size 100 \
        --icon "${APP_NAME}.app"         140 200 \
        --icon "${APP_NAME}_停止.app"    300 200 \
        --icon "Applications"            480 200 \
        --hide-extension "${APP_NAME}.app" \
        --hide-extension "${APP_NAME}_停止.app" \
        "$DIST_DIR/$DMG_NAME" \
        "$TMP_DMG_DIR"
else
    # hdiutil のみで作成（シンプル）
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$TMP_DMG_DIR" \
        -ov -format UDZO \
        "$DIST_DIR/$DMG_NAME"
fi

rm -rf "$TMP_DMG_DIR"

echo ""
echo "=== 完成 ==="
echo "DMG ファイル: $DIST_DIR/$DMG_NAME"
echo ""
echo "【配布方法】"
echo "1. $DMG_NAME を配布"
echo "2. ユーザーはDMGを開き、ハコ割り生成ツール.appを"
echo "   Applications フォルダにドラッグ"
echo "3. 初回は右クリック→「開く」で起動（Gatekeeper 警告を回避）"
