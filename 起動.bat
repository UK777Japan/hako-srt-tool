@echo off
chcp 65001 > nul
cd /d "%~dp0"
echo ハコ割り生成ツールを起動します...
docker compose up -d --build
echo.
echo 起動完了！ブラウザで以下のURLを開いてください：
echo http://localhost:8503
echo.
pause
