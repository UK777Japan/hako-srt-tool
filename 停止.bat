@echo off
chcp 65001 > nul
cd /d "%~dp0"
echo ハコ割り生成ツールを停止します...
docker compose down
echo 停止完了。
pause
