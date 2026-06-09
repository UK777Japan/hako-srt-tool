#!/bin/bash
# ハコ割り生成ツール 起動スクリプト（macOS・Docker 不要版）
RESOURCES="$(cd "$(dirname "$0")" && pwd)"
PYTHON_EXE="$RESOURCES/python/bin/python3"
FFMPEG_BIN="$RESOURCES/tools/ffmpeg/bin"
WHISPER_CACHE="$RESOURCES/models/whisper"
OUTPUT_DIR="$HOME/Desktop/ハコ割り生成ツール_output"

# すでに起動中ならブラウザを開いて終了
if curl -s --max-time 1 "http://127.0.0.1:8503/_stcore/health" >/dev/null 2>&1; then
    open "http://127.0.0.1:8503"
    exit 0
fi

# 出力フォルダ作成
mkdir -p "$OUTPUT_DIR"

# 環境変数を設定してバックグラウンドで Streamlit を起動
export PATH="$FFMPEG_BIN:$PATH"
export DYLD_LIBRARY_PATH="$FFMPEG_BIN:${DYLD_LIBRARY_PATH:-}"
export HAKO_OUTPUT_DIR="$OUTPUT_DIR"
export WHISPER_CACHE_DIR="$WHISPER_CACHE"

"$PYTHON_EXE" -m streamlit run "$RESOURCES/scripts/app.py" \
    --server.headless true \
    --server.port 8503 \
    --server.address 127.0.0.1 \
    >/dev/null 2>&1 &

# 起動を待つ（最大 3 分）
for i in $(seq 1 60); do
    sleep 3
    if curl -s --max-time 1 "http://127.0.0.1:8503/_stcore/health" >/dev/null 2>&1; then
        open "http://127.0.0.1:8503"
        exit 0
    fi
done

osascript -e 'display alert "ハコ割り生成ツール" message "起動がタイムアウトしました。再度試してください。" as critical buttons {"OK"}' 2>/dev/null
exit 1
