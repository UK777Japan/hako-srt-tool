@echo off
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

REM --- Docker イメージ確認・ロード ---
docker image inspect hako-srt-app >nul 2>&1
if errorlevel 1 (
    if exist "%APP_DIR%hako-srt-app.tar.gz" (
        echo Docker イメージを読み込んでいます。
        echo このウィンドウを閉じないでください。
        echo.
        docker load -i "%APP_DIR%hako-srt-app.tar.gz"
        if errorlevel 1 (
            echo.
            echo [エラー] イメージの読み込みに失敗しました。
            echo.
            pause
            exit /b 1
        )
        echo イメージの読み込みが完了しました。
        echo ディスク容量を節約したい場合は %APP_DIR%hako-srt-app.tar.gz を削除できます。
        echo.
    ) else (
        echo [エラー] hako-srt-app.tar.gz が見つかりません。
        echo 再インストールしてください。
        echo.
        pause
        exit /b 1
    )
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