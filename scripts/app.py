# -*- coding: utf-8 -*-
import json
import shutil
import tempfile
import time
import traceback
from datetime import datetime
from pathlib import Path

import streamlit as st

OUTPUT_DIR  = Path("/app/output")
LOG_FILE    = OUTPUT_DIR / "run_log.txt"
CONFIG_FILE = OUTPUT_DIR / ".hako_config.json"

def load_config() -> dict:
    if CONFIG_FILE.exists():
        try:
            return json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}

def save_config(data: dict) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

# ---------------------------------------------------------------------------
# 言語リスト（全 99 言語 + 自動検出）
# 表示形式: "English / 日本語 [code]"
# 日本語のみ先頭固定、残りは英語名 ABC 順
# ---------------------------------------------------------------------------
LANG_LABELS: dict[str, str] = {
    "auto": "自動検出 (auto-detect)",
    # ── 先頭固定 ──
    "ja":  "Japanese / 日本語",
    # ── ABC 順（英語名基準） ──
    "af":  "Afrikaans / アフリカーンス語",
    "sq":  "Albanian / アルバニア語",
    "am":  "Amharic / アムハラ語",
    "ar":  "Arabic / アラビア語",
    "hy":  "Armenian / アルメニア語",
    "as":  "Assamese / アッサム語",
    "az":  "Azerbaijani / アゼルバイジャン語",
    "ba":  "Bashkir / バシキール語",
    "eu":  "Basque / バスク語",
    "be":  "Belarusian / ベラルーシ語",
    "bn":  "Bengali / ベンガル語",
    "bs":  "Bosnian / ボスニア語",
    "br":  "Breton / ブルトン語",
    "bg":  "Bulgarian / ブルガリア語",
    "my":  "Burmese / ビルマ語",
    "yue": "Cantonese / 広東語",
    "ca":  "Catalan / カタルーニャ語",
    "zh":  "Chinese / 中国語",
    "hr":  "Croatian / クロアチア語",
    "cs":  "Czech / チェコ語",
    "da":  "Danish / デンマーク語",
    "nl":  "Dutch / オランダ語",
    "en":  "English / 英語",
    "et":  "Estonian / エストニア語",
    "fo":  "Faroese / フェロー語",
    "fi":  "Finnish / フィンランド語",
    "fr":  "French / フランス語",
    "gl":  "Galician / ガリシア語",
    "ka":  "Georgian / ジョージア語",
    "de":  "German / ドイツ語",
    "el":  "Greek / ギリシャ語",
    "gu":  "Gujarati / グジャラート語",
    "ht":  "Haitian Creole / ハイチ・クレオール語",
    "ha":  "Hausa / ハウサ語",
    "haw": "Hawaiian / ハワイ語",
    "he":  "Hebrew / ヘブライ語",
    "hi":  "Hindi / ヒンディー語",
    "hu":  "Hungarian / ハンガリー語",
    "is":  "Icelandic / アイスランド語",
    "id":  "Indonesian / インドネシア語",
    "it":  "Italian / イタリア語",
    "jw":  "Javanese / ジャワ語",
    "kn":  "Kannada / カンナダ語",
    "kk":  "Kazakh / カザフ語",
    "km":  "Khmer / クメール語",
    "ko":  "Korean / 韓国語",
    "lo":  "Lao / ラオ語",
    "la":  "Latin / ラテン語",
    "lv":  "Latvian / ラトビア語",
    "ln":  "Lingala / リンガラ語",
    "lt":  "Lithuanian / リトアニア語",
    "lb":  "Luxembourgish / ルクセンブルク語",
    "mk":  "Macedonian / マケドニア語",
    "mg":  "Malagasy / マダガスカル語",
    "ms":  "Malay / マレー語",
    "ml":  "Malayalam / マラヤーラム語",
    "mt":  "Maltese / マルタ語",
    "mi":  "Maori / マオリ語",
    "mr":  "Marathi / マラーティー語",
    "mn":  "Mongolian / モンゴル語",
    "ne":  "Nepali / ネパール語",
    "no":  "Norwegian / ノルウェー語",
    "nn":  "Nynorsk / ニーノシュク語",
    "oc":  "Occitan / オクシタン語",
    "ps":  "Pashto / パシュトー語",
    "fa":  "Persian / ペルシャ語",
    "pl":  "Polish / ポーランド語",
    "pt":  "Portuguese / ポルトガル語",
    "pa":  "Punjabi / パンジャーブ語",
    "ro":  "Romanian / ルーマニア語",
    "ru":  "Russian / ロシア語",
    "sa":  "Sanskrit / サンスクリット語",
    "sr":  "Serbian / セルビア語",
    "sn":  "Shona / ショナ語",
    "sd":  "Sindhi / シンド語",
    "si":  "Sinhala / シンハラ語",
    "sk":  "Slovak / スロバキア語",
    "sl":  "Slovenian / スロベニア語",
    "so":  "Somali / ソマリ語",
    "es":  "Spanish / スペイン語",
    "su":  "Sundanese / スンダ語",
    "sw":  "Swahili / スワヒリ語",
    "sv":  "Swedish / スウェーデン語",
    "tl":  "Tagalog / タガログ語",
    "tg":  "Tajik / タジク語",
    "ta":  "Tamil / タミル語",
    "tt":  "Tatar / タタール語",
    "te":  "Telugu / テルグ語",
    "th":  "Thai / タイ語",
    "bo":  "Tibetan / チベット語",
    "tr":  "Turkish / トルコ語",
    "tk":  "Turkmen / トルクメン語",
    "uk":  "Ukrainian / ウクライナ語",
    "ur":  "Urdu / ウルドゥー語",
    "uz":  "Uzbek / ウズベク語",
    "vi":  "Vietnamese / ベトナム語",
    "cy":  "Welsh / ウェールズ語",
    "yi":  "Yiddish / イディッシュ語",
    "yo":  "Yoruba / ヨルバ語",
}
LANG_CODES = list(LANG_LABELS.keys())

# ステップごとの進捗定義（ログメッセージのキーワードで判定）
STEP_INFO = [
    ("[0]",              5,  "ステップ 1/6: 音声変換中 (ffmpeg)"),
    ("[1]",             10,  "ステップ 2/6: Whisper 音声認識を準備中"),
    ("モデル",          15,  "ステップ 2/6: Whisper モデルをロード中（初回は数分かかります）"),
    ("Transcribe",      20,  "ステップ 2/6: 音声認識中（しばらくお待ちください）"),
    ("キャッシュを使用", 20,  "ステップ 2/6: Whisper キャッシュを使用"),
    ("認識単語数",       70,  "ステップ 2/6: 音声認識完了"),
    ("[2]",             75,  "ステップ 3/6: DP アライメント計算中"),
    ("[3]",             85,  "ステップ 4/6: タイミング調整中"),
    ("[4]",             90,  "ステップ 5/6: タイムスタンプ調整中"),
    ("[5]",             95,  "ステップ 6/6: SRT 書き出し中"),
    ("[完了]",         100,  "完了！"),
]

# ---------------------------------------------------------------------------
# ページ設定
# ---------------------------------------------------------------------------
st.set_page_config(
    page_title="ハコ割り生成ツール",
    page_icon="📄",
    layout="centered",
)

st.title("📄 ハコ割り生成ツール")
st.markdown("音声ファイルとハコ割りテキストをアップロードして SRT を生成します。")

# ---------------------------------------------------------------------------
# セッション状態の初期化
# ---------------------------------------------------------------------------
for key in ["srt_bytes", "txt_bytes", "csv_bytes", "run_success", "run_error", "run_elapsed"]:
    if key not in st.session_state:
        st.session_state[key] = None

# ---------------------------------------------------------------------------
# サイドバー：設定
# ---------------------------------------------------------------------------
with st.sidebar:
    st.header("⚙️ 詳細設定")

    # ── 認識エンジン ──
    st.subheader("🎙️ 音声認識エンジン")
    engine_choice = st.radio(
        "処理モード",
        options=["ローカル処理（無料・APIキー不要）", "OpenAI API（高速・要APIキー）"],
        index=0,
        help="ローカル: PC 上で処理。API: OpenAI サーバーで処理（$0.006/分）。",
    )
    use_api = engine_choice.startswith("OpenAI")

    _cfg = load_config()
    _saved_key = _cfg.get("api_key", "")

    api_key = ""
    if use_api:
        api_key = st.text_input(
            "OpenAI API キー",
            type="password",
            value=_saved_key,
            placeholder="sk-...",
            help="https://platform.openai.com/api-keys で取得。入力後は自動保存されます。",
        )
        if api_key:
            if api_key != _saved_key:
                save_config({**_cfg, "api_key": api_key})
                st.success("APIキーを保存しました ✓")
            else:
                st.success("APIキーが読み込まれています ✓")
        else:
            if _saved_key:
                save_config({**_cfg, "api_key": ""})
            st.warning("APIキーを入力してください")
        st.caption("使用モデル: whisper-1（精度: large-v2 相当）")
    else:
        model_name = st.selectbox(
            "Whisperモデル",
            ["turbo", "large-v3", "large-v2", "medium", "small", "base", "tiny"],
            index=0,
            help="turbo = large-v3 と同等精度・約8倍高速（推奨）",
        )
        st.caption("GPU 未搭載の環境では CPU で動作します。")

    if use_api:
        model_name = "whisper-1"

    # ── 認識言語 ──
    st.markdown("---")
    st.subheader("🌐 認識言語")
    language_code = st.selectbox(
        "言語",
        options=LANG_CODES,
        format_func=lambda c: (
            LANG_LABELS[c] if c == "auto"
            else f"{LANG_LABELS[c]}  [{c}]"
        ),
        index=LANG_CODES.index("ja"),
        help="音声の言語を選択。「自動検出」は若干精度が落ちる場合があります。",
    )

    # ── タイミング設定 ──
    st.markdown("---")
    st.subheader("⏱️ タイミング設定")

    fps = st.number_input("フレームレート (fps)", value=30, min_value=1, max_value=120, step=1)

    global_offset = st.number_input(
        "グローバルオフセット (秒)",
        value=0.00, min_value=-2.0, max_value=2.0, step=0.01, format="%.2f",
        help="全タイムスタンプに加算するオフセット",
    )

    post_out_pad = st.number_input(
        "後端パディング (秒)",
        value=0.2, min_value=0.0, max_value=2.0, step=0.05, format="%.2f",
        help="各ブロックの終了時刻に加算する余白",
    )

    min_disp_sec = st.number_input(
        "最小表示時間 (秒)",
        value=0.8, min_value=0.1, max_value=5.0, step=0.1, format="%.1f",
    )

    silence_threshold_ms = st.number_input(
        "無音閾値 (ms)",
        value=400, min_value=0, max_value=2000, step=50,
        help="この値より短い無音区間は前ブロックを延ばして埋める",
    )

    use_cache = st.checkbox("書き起こしキャッシュを使用", value=True,
                            help="同じ音声ファイルの再処理を高速化（API の場合は再課金を防止）")

# ---------------------------------------------------------------------------
# メイン：ファイル入力
# ---------------------------------------------------------------------------
col1, col2 = st.columns(2)

with col1:
    audio_file = st.file_uploader(
        "音声・映像ファイル",
        type=["mp3", "wav", "m4a", "aac", "flac", "ogg", "mpg", "mpeg", "mp4", "ts"],
        help="音声・動画ファイル（mp4/mpg/ts は音声トラックを使用）。上限 10GB。",
    )

with col2:
    hako_file = st.file_uploader(
        "ハコ割りテキスト (.txt)",
        type=["txt"],
        help="ハコ割りテキストファイル",
    )

hako_sep_label = st.radio(
    "ハコ割りテキストの区切り方式",
    options=["空行区切り（ブロック間に空行）", "改行区切り（1行＝1ブロック）"],
    index=0,
    horizontal=True,
)
hako_separator = "blank_line" if hako_sep_label.startswith("空行") else "newline"

# ---------------------------------------------------------------------------
# 実行ボタン
# ---------------------------------------------------------------------------
run_btn = st.button(
    "▶ SRT を生成",
    type="primary",
    disabled=(audio_file is None or hako_file is None),
    use_container_width=True,
)

# ---------------------------------------------------------------------------
# 処理（run_btn が押されたとき）
# ---------------------------------------------------------------------------
if run_btn:
    # セッション状態をリセット
    for key in ["srt_bytes", "txt_bytes", "csv_bytes", "run_success", "run_error", "run_elapsed"]:
        st.session_state[key] = None

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    TMP_DIR = Path(tempfile.mkdtemp(prefix="hako_"))
    run_timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_lines: list[str] = []

    with st.status("SRT を生成中...", expanded=True) as status_box:
        prog_bar    = st.progress(0, text="準備中...")
        log_area    = st.empty()
        current_pct = [0]

        def log(msg: str):
            log_lines.append(msg)
            log_area.code("\n".join(log_lines), language=None)
            for keyword, pct, label in STEP_INFO:
                if keyword in msg:
                    current_pct[0] = pct
                    prog_bar.progress(pct, text=label)
                    break

        try:
            audio_path = TMP_DIR / audio_file.name
            audio_path.write_bytes(audio_file.read())
            hako_path  = TMP_DIR / hako_file.name
            hako_path.write_text(hako_file.read().decode("utf-8"), encoding="utf-8")

            log(f"音声ファイル: {audio_file.name}")
            log(f"ハコ割りテキスト: {hako_file.name}")

            try:
                import torch
                device = "cuda" if torch.cuda.is_available() else "cpu"
            except ImportError:
                device = "cpu"
            log(f"デバイス: {device}")

            import sys
            sys.path.insert(0, "/app/scripts")
            from sync_srt import generate_srt

            start = time.time()
            srt_path, txt_path, csv_path = generate_srt(
                audio_path=audio_path,
                hako_path=hako_path,
                output_dir=OUTPUT_DIR,
                model_name=model_name,
                fps=int(fps),
                global_offset=float(global_offset),
                post_out_pad_sec=float(post_out_pad),
                min_disp_sec=float(min_disp_sec),
                silence_threshold_ms=float(silence_threshold_ms),
                device=device,
                use_cache=use_cache,
                hako_separator=hako_separator,
                language=language_code,
                use_api=use_api,
                api_key=api_key,
                log=log,
            )
            elapsed = time.time() - start
            log(f"処理時間: {elapsed:.1f} 秒")
            log("結果: 成功")

            prog_bar.progress(100, text="完了！")
            st.session_state["srt_bytes"]   = srt_path.read_bytes()
            st.session_state["txt_bytes"]   = txt_path.read_bytes()
            st.session_state["csv_bytes"]   = csv_path.read_bytes()
            st.session_state["run_success"] = True
            st.session_state["run_elapsed"] = elapsed
            status_box.update(label=f"SRT 生成完了！（{elapsed:.1f} 秒）",
                              state="complete", expanded=False)

        except Exception as e:
            tb_str = traceback.format_exc()
            log(f"結果: エラー - {e}")
            st.session_state["run_error"] = tb_str
            prog_bar.progress(current_pct[0], text="エラーが発生しました")
            status_box.update(label="エラーが発生しました", state="error", expanded=True)

        finally:
            shutil.rmtree(TMP_DIR, ignore_errors=True)
            OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
            entry = f"=== {run_timestamp} ===\n" + "\n".join(log_lines) + "\n\n"
            with LOG_FILE.open("a", encoding="utf-8") as f:
                f.write(entry)

# ---------------------------------------------------------------------------
# 結果表示（セッション状態から）
# ---------------------------------------------------------------------------
if st.session_state.get("run_success"):
    elapsed = st.session_state["run_elapsed"]
    st.success(f"SRT 生成完了！（{elapsed:.1f} 秒）")
    dl1, dl2, dl3 = st.columns(3)
    with dl1:
        st.download_button(
            "⬇ output.srt をダウンロード",
            data=st.session_state["srt_bytes"],
            file_name="output.srt",
            mime="text/plain",
            use_container_width=True,
        )
    with dl2:
        st.download_button(
            "⬇ output.txt をダウンロード",
            data=st.session_state["txt_bytes"],
            file_name="output.txt",
            mime="text/plain",
            use_container_width=True,
        )
    with dl3:
        st.download_button(
            "⬇ output.csv をダウンロード",
            data=st.session_state["csv_bytes"],
            file_name="output.csv",
            mime="text/csv",
            use_container_width=True,
        )

if st.session_state.get("run_error"):
    st.error("エラーが発生しました")
    st.markdown("**エラー詳細**（右上のコピーボタンで全文コピーできます）")
    st.code(st.session_state["run_error"], language=None)

# ---------------------------------------------------------------------------
# ページ下部：ログ履歴
# ---------------------------------------------------------------------------
st.markdown("---")

log_col, btn_col = st.columns([5, 1])
with log_col:
    st.subheader("処理ログ")
with btn_col:
    if st.button("クリア", help="ログ履歴ファイルを削除"):
        if LOG_FILE.exists():
            LOG_FILE.unlink()
        st.session_state.pop("last_log", None)
        st.rerun()

if LOG_FILE.exists():
    log_content = LOG_FILE.read_text(encoding="utf-8").strip()
    if log_content:
        entries = [e for e in log_content.split("\n\n") if e.strip()]
        display = "\n\n".join(entries[-10:])
        st.code(display, language=None)
    else:
        st.caption("まだ処理履歴がありません。")
else:
    st.caption("まだ処理履歴がありません。")
