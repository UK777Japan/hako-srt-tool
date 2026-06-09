@echo off
chcp 65001 > nul
title ハコ割り生成ツール

set "APP_DIR=%~dp0"

echo ============================================
echo   ハコ割り生成ツール
echo ============================================
echo.

REM --- 出力フォルダを Desktop に作成 ---
set "OUTPUT_DIR=%USERPROFILE%\Desktop\ハコ割り生成ツール_output"
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

REM --- Docker インストール確認 ---
where docker >nul 2>&1
if errorlevel 1 (
    echo [エラー] Docker Desktop がインストールされていません。
    echo.
    echo 下記のURLからインストールしてください：
    echo https://www.docker.com/products/docker-desktop/
    echo.
    pause
    exit /b 1
)

REM --- Docker 起動確認 ---
docker info >nul 2>&1
if errorlevel 1 (
    echo Docker Desktop を起動しています...
    start "" "%PROGRAMFILES%\Docker\Docker\Docker Desktop.exe" 2>nul
    if errorlevel 1 start "" "%PROGRAMFILES(X86)%\Docker\Docker\Docker Desktop.exe" 2>nul

    echo Docker の起動を待っています（最大 90 秒）...
    set /a COUNT=0
    :WAIT_DOCKER
    timeout /t 5 /nobreak >nul
    set /a COUNT+=1
    docker info >nul 2>&1
    if not errorlevel 1 goto DOCKER_READY
    if %COUNT% lss 18 goto WAIT_DOCKER
    echo.
    echo [エラー] Docker の起動がタイムアウトしました。
    echo Docker Desktop を手動で起動してから、再度このファイルを実行してください。
    echo.
    pause
    exit /b 1
    :DOCKER_READY
    echo Docker が起動しました。
    echo.
)

REM --- .env ファイル生成（パス区切りをスラッシュに変換）---
set "OUTPUT_FWDSLASH=%OUTPUT_DIR:\=/%"
(echo OUTPUT_DIR=%OUTPUT_FWDSLASH%) > "%APP_DIR%.env"

REM --- Docker イメージ確認・初回ビルド ---
docker image inspect hako-srt-app >nul 2>&1
if errorlevel 1 (
    echo 初回起動: Docker イメージをビルドしています。
    echo Whisper モデルのダウンロード（約 800MB）を含むため、
    echo ネットワーク速度により 5〜15 分かかる場合があります。
    echo.
    docker compose -f "%APP_DIR%docker-compose.yml" -p hako-srt-tool build
    if errorlevel 1 (
        echo.
        echo [エラー] ビルドに失敗しました。
        echo インターネット接続と Docker の状態を確認してください。
        echo.
        pause
        exit /b 1
    )
    echo.
    echo ビルド完了。
    echo.
)

REM --- コンテナ起動 ---
echo アプリを起動しています...
docker compose -f "%APP_DIR%docker-compose.yml" -p hako-srt-tool up -d
if errorlevel 1 (
    echo.
    echo [エラー] コンテナの起動に失敗しました。
    echo.
    pause
    exit /b 1
)

REM --- ブラウザを開く ---
timeout /t 3 /nobreak >nul
start http://localhost:8503

echo.
echo ============================================
echo   起動完了！
echo   ブラウザで http://localhost:8503 が開きます
echo   出力先: %OUTPUT_DIR%
echo ============================================
echo.
echo このウィンドウを閉じてもアプリは動作し続けます。
echo 停止するには「ハコ割り生成ツール 停止」を実行してください。
echo.
timeout /t 8 /nobreak >nul
