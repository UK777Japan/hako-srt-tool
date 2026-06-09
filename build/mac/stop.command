#!/bin/bash
# ハコ割り生成ツール 停止スクリプト（macOS）
PID=$(lsof -ti tcp:8503 2>/dev/null)
if [ -n "$PID" ]; then
    kill "$PID" 2>/dev/null
    echo "ハコ割り生成ツールを停止しました。"
else
    echo "ハコ割り生成ツールは起動していません。"
fi
