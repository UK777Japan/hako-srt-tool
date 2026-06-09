#Requires -Version 5.1
<#
.SYNOPSIS
    ハコ割り生成ツール スタンドアロンインストーラービルドスクリプト

.DESCRIPTION
    以下を自動で行い、Inno Setup で配布用EXEを生成します。
      1. Python 3.11 embeddable をダウンロード・展開・pip 有効化
      2. 必要パッケージ (torch CPU版 + その他) を pip install
      3. ffmpeg をダウンロード・配置
      4. Whisper turbo モデルをダウンロード
      5. アプリファイルを dist/ にまとめる
      6. Inno Setup (ISCC.exe) でインストーラーEXEを生成

.NOTES
    前提条件:
      - インターネット接続
      - Inno Setup 6 がインストール済み
        (未インストールの場合は https://jrsoftware.org/isdl.php から取得)

    実行方法 (PowerShell):
      Set-ExecutionPolicy -Scope Process Bypass
      .\build.ps1

    Whisper モデルを変更する場合:
      $whisperModel = "turbo"  # small / medium / large-v3 等も指定可能
#>

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir     = Split-Path -Parent (Split-Path -Parent $scriptDir)  # プロジェクトルート
$distDir     = Join-Path $scriptDir "dist"
$cacheDir    = Join-Path $scriptDir "cache"

# ビルドするWhisperモデル（turbo = large-v3-turbo 推奨）
$whisperModel = "turbo"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ハコ割り生成ツール インストーラービルド" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# ──────────────────────────────────────────────────────────────────────────────
# 1. dist フォルダを初期化
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n[1/7] dist フォルダを初期化..." -ForegroundColor Yellow
if (Test-Path $distDir) { Remove-Item $distDir -Recurse -Force }
New-Item -ItemType Directory -Path $distDir | Out-Null
New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
Write-Host "      $distDir"

# ──────────────────────────────────────────────────────────────────────────────
# 2. Python 3.11 embeddable をダウンロード・展開・pip 有効化
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n[2/7] Python 3.11 embeddable をセットアップ..." -ForegroundColor Yellow

$pyVersion = "3.11.9"
$pyZipUrl  = "https://www.python.org/ftp/python/$pyVersion/python-$pyVersion-embed-amd64.zip"
$pyZip     = Join-Path $cacheDir "python-embed.zip"
$pythonDir = Join-Path $distDir "python"

if (-not (Test-Path $pyZip)) {
    Write-Host "      ダウンロード中: $pyZipUrl"
    Invoke-WebRequest -Uri $pyZipUrl -OutFile $pyZip
}
Write-Host "      展開中..."
Expand-Archive -Path $pyZip -DestinationPath $pythonDir -Force

# python311._pth の "#import site" を有効化（pip のために必要）
$pthFile = Get-ChildItem -Path $pythonDir -Filter "*._pth" | Select-Object -First 1
if ($pthFile) {
    (Get-Content $pthFile.FullName) -replace "^#import site", "import site" |
        Set-Content $pthFile.FullName
    Write-Host "      $($pthFile.Name): import site を有効化"
}

# get-pip.py をダウンロードして pip をインストール
$getPipCache = Join-Path $cacheDir "get-pip.py"
if (-not (Test-Path $getPipCache)) {
    Write-Host "      get-pip.py をダウンロード中..."
    Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile $getPipCache
}
Write-Host "      pip をインストール中..."
& (Join-Path $pythonDir "python.exe") $getPipCache --quiet
Write-Host "      Python セットアップ完了"

$pythonExe = Join-Path $pythonDir "python.exe"

# ──────────────────────────────────────────────────────────────────────────────
# 3. Pythonパッケージをインストール
#    torch は CPU 専用の軽量版を先にインストールしてサイズを削減
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n[3/7] Pythonパッケージをインストール中（数分かかります）..." -ForegroundColor Yellow

# torch CPU 専用（CUDA を含まない軽量版、約 200-300MB）
Write-Host "      torch (CPU only) をインストール中..."
& $pythonExe -m pip install torch --index-url https://download.pytorch.org/whl/cpu --quiet

# その他のパッケージ
$packages = @(
    "streamlit>=1.35.0",
    "stable-ts>=2.7.0",
    "fugashi>=1.3.0",
    "unidic-lite>=1.0.8",
    "numpy<2.0",
    "openai>=1.0.0"
)
Write-Host "      その他パッケージをインストール中..."
& $pythonExe -m pip install @packages --quiet

Write-Host "      パッケージインストール完了"

# ──────────────────────────────────────────────────────────────────────────────
# 4. ffmpeg をダウンロード・配置
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n[4/7] ffmpeg をセットアップ..." -ForegroundColor Yellow

$ffmpegZipUrl  = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
$ffmpegZip     = Join-Path $cacheDir "ffmpeg.zip"
$ffmpegDestDir = Join-Path $distDir "tools\ffmpeg\bin"
New-Item -ItemType Directory -Path $ffmpegDestDir -Force | Out-Null

if (-not (Test-Path $ffmpegZip)) {
    Write-Host "      ダウンロード中: $ffmpegZipUrl"
    Invoke-WebRequest -Uri $ffmpegZipUrl -OutFile $ffmpegZip
}
Write-Host "      展開中..."
$ffmpegTemp = Join-Path $cacheDir "ffmpeg_temp"
if (Test-Path $ffmpegTemp) { Remove-Item $ffmpegTemp -Recurse -Force }
Expand-Archive -Path $ffmpegZip -DestinationPath $ffmpegTemp -Force

$ffmpegExe  = Get-ChildItem -Path $ffmpegTemp -Filter "ffmpeg.exe"  -Recurse | Select-Object -First 1
$ffprobeExe = Get-ChildItem -Path $ffmpegTemp -Filter "ffprobe.exe" -Recurse | Select-Object -First 1
if (-not $ffmpegExe) { throw "ffmpeg.exe が展開先に見つかりませんでした" }
Copy-Item $ffmpegExe.FullName  -Destination $ffmpegDestDir
if ($ffprobeExe) { Copy-Item $ffprobeExe.FullName -Destination $ffmpegDestDir }
Remove-Item $ffmpegTemp -Recurse -Force
Write-Host "      配置完了: tools\ffmpeg\bin\"

# ──────────────────────────────────────────────────────────────────────────────
# 5. Whisper モデルをダウンロード（EXE に同梱することでインストール後すぐ使える）
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n[5/7] Whisper モデル ($whisperModel) をダウンロード中..." -ForegroundColor Yellow

$modelDir = Join-Path $distDir "models\whisper"
New-Item -ItemType Directory -Path $modelDir -Force | Out-Null

$tempPy = Join-Path $cacheDir "download_model.py"
@"
import stable_whisper, sys
print("  モデル '$whisperModel' をダウンロード中（しばらくお待ちください）...", flush=True)
stable_whisper.load_model('$whisperModel', download_root=r'$modelDir')
print("  ダウンロード完了", flush=True)
"@ | Set-Content -Path $tempPy -Encoding UTF8
& $pythonExe $tempPy
Remove-Item $tempPy -ErrorAction SilentlyContinue

if (-not (Get-ChildItem -Path $modelDir -Filter "*.pt" -ErrorAction SilentlyContinue)) {
    throw "Whisper モデルのダウンロードに失敗しました"
}
$modelFile = Get-ChildItem -Path $modelDir -Filter "*.pt" | Select-Object -First 1
$modelSizeMB = [math]::Round($modelFile.Length / 1MB, 0)
Write-Host "      完了: $($modelFile.Name) ($modelSizeMB MB)"

# ──────────────────────────────────────────────────────────────────────────────
# 6. アプリファイルをコピー
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n[6/7] アプリファイルをコピー..." -ForegroundColor Yellow

# scripts/
Copy-Item -Path (Join-Path $rootDir "scripts") `
          -Destination (Join-Path $distDir "scripts") -Recurse -Force
Write-Host "      scripts/ をコピー"

# .streamlit/
Copy-Item -Path (Join-Path $rootDir ".streamlit") `
          -Destination (Join-Path $distDir ".streamlit") -Recurse -Force
Write-Host "      .streamlit/ をコピー"

# ランチャー・停止スクリプト（VBS は UTF-8 でも問題ないが念のため CP932 で保存）
$cp932 = [System.Text.Encoding]::GetEncoding(932)
foreach ($pair in @(
    @{ src = "launcher.vbs"; dst = "起動.vbs" },
    @{ src = "stop.vbs";     dst = "停止.vbs" }
)) {
    $srcPath = Join-Path $scriptDir $pair.src
    $dstPath = Join-Path $distDir   $pair.dst
    $text = [System.IO.File]::ReadAllText($srcPath, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($dstPath, $text, $cp932)
}
Write-Host "      ランチャー・停止スクリプトをコピー"

# docs/
Copy-Item -Path (Join-Path $rootDir "docs") `
          -Destination (Join-Path $distDir "docs") -Recurse -Force
Write-Host "      docs/ をコピー"

# ──────────────────────────────────────────────────────────────────────────────
# 7. Inno Setup でインストーラーEXEを生成
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n[7/7] Inno Setup でインストーラーを生成..." -ForegroundColor Yellow

$isccCandidates = @(
    "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
)
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $iscc) {
    Write-Host ""
    Write-Host "  ⚠ Inno Setup 6 が見つかりません。" -ForegroundColor Red
    Write-Host "    https://jrsoftware.org/isdl.php からインストール後に再実行してください。" -ForegroundColor Red
    Write-Host ""
    Write-Host "  dist/ フォルダは準備済みです。" -ForegroundColor Yellow
} else {
    Write-Host "      ISCC: $iscc"
    $issFile = Join-Path $scriptDir "installer.iss"
    & $iscc $issFile

    $outputExe = Join-Path $rootDir "dist\windows\ハコ割り生成ツール_setup.exe"
    if (Test-Path $outputExe) {
        $sizeMB = [math]::Round((Get-Item $outputExe).Length / 1MB, 0)
        Write-Host ""
        Write-Host "  インストーラー生成完了！ ($sizeMB MB)" -ForegroundColor Green
        Write-Host "  → $outputExe" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ビルド完了" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
