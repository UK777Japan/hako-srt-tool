@echo off
title ハコ割り生成ツール - 停止

set "APP_DIR=%~dp0"

echo ============================================
echo   ハコ割り生成ツールを停止しています...
echo ============================================
echo.

docker compose -f "%APP_DIR%docker-compose.yml" -p hako-srt-tool down

echo.
echo 停止しました。
echo.
pause