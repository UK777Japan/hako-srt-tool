#!/bin/bash
# ハコ割り生成ツール 起動スクリプト (macOS)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$HOME/Desktop/ハコ割り生成ツール_output"

echo "============================================"
echo "  ハコ割り生成ツール"
echo "============================================"
echo ""

# 出力フォルダ作成
mkdir -p "$OUTPUT_DIR"

# Docker インストール確認
if ! command -v docker &>/dev/null; then
    echo "[エラー] Docker Desktop がインストールされていません。"
    echo ""
    echo "下記の URL からインストールしてください："
    echo "https://www.docker.com/products/docker-desktop/"
    echo ""
    read -rp "Enter キーを押して終了..."
    exit 1
fi

# Docker 起動確認
if ! docker info &>/dev/null 2>&1; then
    echo "Docker Desktop を起動しています..."
    open -a Docker

    echo "Docker の起動を待っています（最大 90 秒）..."
    COUNT=0
    while ! docker info &>/dev/null 2>&1; do
        sleep 5
        COUNT=$((COUNT + 1))
        if [ "$COUNT" -ge 18 ]; then
            echo ""
            echo "[エラー] Docker の起動がタイムアウトしました。"
            echo "Docker Desktop を手動で起動してから再試行してください。"
            echo ""
            read -rp "Enter キーを押して終了..."
            exit 1
        fi
    done
    echo "Docker が起動しました。"
    echo ""
fi

# .env ファイル生成
echo "OUTPUT_DIR=$OUTPUT_DIR" > "$SCRIPT_DIR/.env"

# イメージ確認・初回ビルド
if ! docker image inspect hako-srt-app &>/dev/null 2>&1; then
    echo "初回起動: Docker イメージをビルドしています。"
    echo "Whisper モデルのダウンロード（約 800MB）を含むため、"
    echo "ネットワーク速度により 5〜15 分かかる場合があります。"
    echo ""
    docker compose -f "$SCRIPT_DIR/docker-compose.yml" -p hako-srt-tool build
    if [ $? -ne 0 ]; then
        echo ""
        echo "[エラー] ビルドに失敗しました。"
        echo "インターネット接続と Docker の状態を確認してください。"
        echo ""
        read -rp "Enter キーを押して終了..."
        exit 1
    fi
    echo ""
    echo "ビルド完了。"
    echo ""
fi

# コンテナ起動
echo "アプリを起動しています..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" -p hako-srt-tool up -d
if [ $? -ne 0 ]; then
    echo ""
    echo "[エラー] コンテナの起動に失敗しました。"
    echo ""
    read -rp "Enter キーを押して終了..."
    exit 1
fi

sleep 3
open http://localhost:8503

echo ""
echo "============================================"
echo "  起動完了！"
echo "  ブラウザで http://localhost:8503 が開きます"
echo "  出力先: $OUTPUT_DIR"
echo "============================================"
echo ""
echo "このターミナルを閉じてもアプリは動作し続けます。"
echo "停止するには stop.command を実行してください。"
