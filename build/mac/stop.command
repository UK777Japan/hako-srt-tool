#!/bin/bash
# ハコ割り生成ツール 停止スクリプト (macOS)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "ハコ割り生成ツールを停止しています..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" -p hako-srt-tool down

echo ""
echo "停止しました。"
