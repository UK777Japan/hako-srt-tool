FROM python:3.11-slim

# システムパッケージ
RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# CPU 版 torch/torchaudio を先にインストール（torchaudio を明示指定しないと CUDA 版が入る）
RUN pip install --no-cache-dir \
    torch==2.2.2+cpu \
    torchaudio==2.2.2+cpu \
    --index-url https://download.pytorch.org/whl/cpu

# アプリ依存パッケージ
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# unidic 辞書ダウンロード（fugashi 用）
RUN python -m unidic download 2>/dev/null || true

# Whisper turbo モデルの重みファイルをビルド時にダウンロード（ロードは行わない）
RUN python -c "\
import whisper, os; \
root = os.path.expanduser('~/.cache/whisper'); \
os.makedirs(root, exist_ok=True); \
name = next((n for n in ['turbo', 'large-v3-turbo'] if n in whisper._MODELS), None); \
assert name, 'turbo model not found'; \
print(f'Downloading Whisper {name} weights...'); \
path = whisper._download(whisper._MODELS[name], root, False); \
print(f'Done: {path}')"

# スクリプト
COPY scripts/ /app/scripts/

# Streamlit 設定
COPY .streamlit/ /app/.streamlit/

EXPOSE 8501

CMD ["streamlit", "run", "/app/scripts/app.py", "--server.port=8501", "--server.address=0.0.0.0"]
