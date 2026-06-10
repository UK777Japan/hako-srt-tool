# DP アライメントによる超高精度タイムスタンプ同期システム
# -*- coding: utf-8 -*-

import csv
import io
import os
import re
import json
import subprocess
from pathlib import Path
from typing import List, Dict, Tuple, Optional, Callable

# ---------------------------------------------------------------------------
# 日本語処理
# ---------------------------------------------------------------------------
try:
    from fugashi import Tagger
    _tagger = Tagger()
    HAS_FUGASHI = True
except Exception:
    HAS_FUGASHI = False
    _tagger = None

def get_kana_reading(text: str) -> str:
    if not HAS_FUGASHI or not _tagger:
        return text.translate(str.maketrans(
            "ぁあぃいぅうぇえぉおかがきぎくぐけげこごさざしじすずせぜそぞただちぢっつづてでとどなにぬねのはばぱひびぴふぶぷへべぺほぼぽまみむめもゃやゅゆょよらりるれろわをんゔ",
            "ァアィイゥウェエォオカガキギクグケゲコゴサザシジスズセゼソゾタダチヂッツヅテデトドナニヌネノハバパヒビピフブプヘベペホボポマミムメモャヤュユョヨラリルレロワヲンヴ"
        ))
    readings = []
    for w in _tagger(text):
        f = w.feature
        kana = getattr(f, "kana", None) or getattr(f, "pron", None)
        readings.append(kana if kana else w.surface)
    return "".join(readings)

# ---------------------------------------------------------------------------
# ユーティリティ
# ---------------------------------------------------------------------------
_SKIP_PAT = re.compile(r'[\s　ぁぃぅぇぉっゃゅょゎ、。！？「」…‥\-~～]')

def fmt_ts(t: float) -> str:
    t = max(0.0, float(t))
    total_ms = int(t * 1000)
    ms = total_ms % 1000
    ts = total_ms // 1000
    return f"{ts // 3600:02}:{(ts % 3600) // 60:02}:{ts % 60:02},{ms:03}"

def snap(t: float, fps: int) -> float:
    return round(t * fps) / fps

def load_hako(path: Path, separator: str = "blank_line") -> List[str]:
    raw = path.read_text(encoding="utf-8").replace("\r\n", "\n")
    if separator == "newline":
        return [line.strip() for line in raw.splitlines() if line.strip()]
    # blank_line: 空行区切り
    blocks = re.split(r'\n[ \t]*\n', raw)
    return [b.strip("\n") for b in blocks if b.strip()]

# ---------------------------------------------------------------------------
# Whisper 書き起こし
# ---------------------------------------------------------------------------
def run_whisper_transcribe(
    wav: Path,
    prompt: str,
    model_name: str,
    device: str,
    cache_path: Optional[Path],
    log: Callable[[str], None],
    language: str = "ja",
) -> List[Dict]:
    if cache_path and cache_path.exists():
        log("  キャッシュを使用します")
        return json.loads(cache_path.read_text(encoding="utf-8"))

    import stable_whisper
    log(f"  モデル {model_name} をロード中...")
    _whisper_cache = os.environ.get("WHISPER_CACHE_DIR") or None
    model = stable_whisper.load_model(model_name, device=device, download_root=_whisper_cache)

    lang_arg = None if language == "auto" else language
    log("  Transcribe（音声認識）実行中...")
    result = model.transcribe(
        str(wav),
        language=lang_arg,
        word_timestamps=True,
        initial_prompt=prompt[:1000].replace("\n", " "),
        vad=True,
    )

    words = []
    for seg in result.to_dict().get("segments", []):
        for w in seg.get("words", []):
            surf = w.get("word", "").strip()
            if surf:
                words.append({
                    "word":  surf,
                    "start": float(w["start"]),
                    "end":   float(w["end"]),
                })

    if cache_path:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(json.dumps(words, ensure_ascii=False, indent=2), encoding="utf-8")
    return words

# ---------------------------------------------------------------------------
# DP アライメント（Needleman-Wunsch）
# ---------------------------------------------------------------------------
def dp_align_chars(
    seq_a: List[Dict],
    seq_b: List[Dict],
) -> List[Tuple[int, int]]:
    n, m = len(seq_a), len(seq_b)
    dp = [[0.0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        dp[i][0] = i * 1.2
    for j in range(m + 1):
        dp[0][j] = j * 1.2

    for i in range(1, n + 1):
        ka = seq_a[i - 1]["kana"]
        for j in range(1, m + 1):
            kb = seq_b[j - 1]["kana"]
            cost = 0.0 if (ka == kb and ka != "") else 2.0
            dp[i][j] = min(
                dp[i - 1][j - 1] + cost,
                dp[i - 1][j] + 1.2,
                dp[i][j - 1] + 1.2,
            )

    alignment = []
    i, j = n, m
    while i > 0 or j > 0:
        if i > 0 and j > 0:
            ka = seq_a[i - 1]["kana"]
            kb = seq_b[j - 1]["kana"]
            cost = 0.0 if (ka == kb and ka != "") else 2.0
            if abs(dp[i][j] - (dp[i - 1][j - 1] + cost)) < 1e-5:
                if cost == 0.0:
                    alignment.append((i - 1, j - 1))
                i -= 1
                j -= 1
                continue
        if i > 0 and (j == 0 or abs(dp[i][j] - (dp[i - 1][j] + 1.2)) < 1e-5):
            i -= 1
        else:
            j -= 1
    alignment.reverse()
    return alignment

def align_robust(
    hako_blocks: List[str],
    whisper_words: List[Dict],
    min_disp_sec: float,
    log: Callable[[str], None],
) -> List[Dict]:
    # 1. Whisper 結果の文字展開
    seq_a = []
    for w in whisper_words:
        dur = w["end"] - w["start"]
        chars = [c for c in w["word"] if not _SKIP_PAT.match(c)]
        if not chars:
            continue
        for idx, ch in enumerate(chars):
            seq_a.append({
                "char":  ch,
                "kana":  get_kana_reading(ch),
                "start": w["start"] + dur * idx / len(chars),
                "end":   w["start"] + dur * (idx + 1) / len(chars),
            })

    # 2. ハコテキストの文字展開
    seq_b = []
    for bi, block in enumerate(hako_blocks):
        for ch in block:
            if not _SKIP_PAT.match(ch):
                seq_b.append({"char": ch, "kana": get_kana_reading(ch), "block_idx": bi})

    # 3. DP アライメント
    log("  DP による文字アライメントを計算中...")
    matched_pairs = dp_align_chars(seq_a, seq_b)

    # 4. ハコごとに時間を集約
    hako_times: Dict[int, List[Tuple[float, float]]] = {i: [] for i in range(len(hako_blocks))}
    for idx_a, idx_b in matched_pairs:
        hako_times[seq_b[idx_b]["block_idx"]].append((seq_a[idx_a]["start"], seq_a[idx_a]["end"]))

    # 5. ブロック単位で最終決定
    result = []
    prev_end = 0.0
    for bi, block in enumerate(hako_blocks):
        times = hako_times[bi]
        if times:
            start = min(t[0] for t in times)
            end   = max(t[1] for t in times)
        else:
            start = prev_end
            end   = prev_end + max(len(block) * 0.1, min_disp_sec)

        if end - start < min_disp_sec:
            end = start + min_disp_sec
        start    = max(start, prev_end)
        end      = max(end, start + min_disp_sec)
        prev_end = end
        result.append({"text": block, "start": start, "end": end})

    return result

# ---------------------------------------------------------------------------
# ポスト調整
# ---------------------------------------------------------------------------
def apply_adjustments(
    blocks: List[Dict],
    global_offset: float,
    post_out_pad: float,
    min_disp_sec: float,
    min_gap: float,
    frame_gap_ms: float,
    silence_threshold_ms: float,
) -> List[Dict]:
    for b in blocks:
        b["end"]   += post_out_pad + global_offset
        b["start"] += global_offset

    for i in range(len(blocks) - 1):
        cur, nxt = blocks[i], blocks[i + 1]
        if cur["end"] > nxt["start"] - min_gap:
            cur["end"] = max(cur["start"] + min_disp_sec, nxt["start"] - frame_gap_ms / 1000.0)
        if 0 < (nxt["start"] - cur["end"]) * 1000 < silence_threshold_ms:
            cur["end"] = nxt["start"] - frame_gap_ms / 1000.0

    return blocks

def resolve_overlaps(blocks: List[Dict], gap: float, min_disp_sec: float) -> List[Dict]:
    if not blocks:
        return blocks
    out = [blocks[0].copy()]
    for curr in blocks[1:]:
        curr = curr.copy()
        prev = out[-1]
        if curr["start"] < prev["end"] + gap:
            curr["start"] = prev["end"] + gap
        if curr["end"] < curr["start"] + min_disp_sec:
            curr["end"] = curr["start"] + min_disp_sec
        out.append(curr)
    return out

# ---------------------------------------------------------------------------
# OpenAI API 書き起こし
# ---------------------------------------------------------------------------
def run_whisper_transcribe_api(
    wav: Path,
    language: str,
    api_key: str,
    cache_path: Optional[Path],
    log: Callable[[str], None],
) -> List[Dict]:
    if cache_path and cache_path.exists():
        log("  キャッシュを使用します")
        return json.loads(cache_path.read_text(encoding="utf-8"))

    from openai import OpenAI

    # WAV → MP3 に変換して送信サイズを削減（API 上限 25 MB）
    mp3_path = wav.parent / "api_input.mp3"
    log("  API 用に音声を MP3 変換中...")
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-i", str(wav), "-q:a", "5", str(mp3_path)],
        check=True,
    )
    size_mb = mp3_path.stat().st_size / (1024 ** 2)
    log(f"  送信サイズ: {size_mb:.1f} MB (上限 25 MB)")
    if size_mb > 24.5:
        raise ValueError(
            f"音声ファイルが OpenAI API の上限 25 MB を超えています（{size_mb:.1f} MB）。"
            "より短い音声を使用するか、ローカルモードをお使いください。"
        )

    client = OpenAI(api_key=api_key)
    log("  OpenAI Whisper API (whisper-1) に送信中...")
    lang_arg = None if language == "auto" else language
    with mp3_path.open("rb") as f:
        response = client.audio.transcriptions.create(
            model="whisper-1",
            file=f,
            language=lang_arg,
            response_format="verbose_json",
            timestamp_granularities=["word"],
        )

    words = []
    for w in getattr(response, "words", []) or []:
        surf = getattr(w, "word", "").strip()
        if surf:
            words.append({
                "word":  surf,
                "start": float(w.start),
                "end":   float(w.end),
            })

    if cache_path:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(json.dumps(words, ensure_ascii=False, indent=2), encoding="utf-8")

    return words

# ---------------------------------------------------------------------------
# メイン API
# ---------------------------------------------------------------------------
def generate_srt(
    audio_path: Path,
    hako_path: Path,
    output_dir: Path,
    model_name: str = "turbo",
    fps: int = 30,
    global_offset: float = 0.00,
    post_out_pad_sec: float = 0.2,
    min_disp_sec: float = 0.8,
    frame_gap_ms: float = 33,
    silence_threshold_ms: float = 400,
    device: str = "cpu",
    use_cache: bool = True,
    hako_separator: str = "blank_line",
    language: str = "ja",
    use_api: bool = False,
    api_key: str = "",
    log: Optional[Callable[[str], None]] = None,
) -> Tuple[Path, Path, Path]:
    """
    音声ファイルとハコ割りテキストから SRT ファイルを生成する。
    Returns: (srt_path, txt_path)
    """
    if log is None:
        log = print

    min_gap = 1.0 / fps
    output_dir.mkdir(parents=True, exist_ok=True)
    tmp_dir = output_dir / "_tmp"
    tmp_dir.mkdir(exist_ok=True)

    # 音声を 16kHz モノラル WAV に変換（毎回再生成）
    wav = tmp_dir / "norm.wav"
    log("[0] 音声変換中 (ffmpeg)...")
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-i", str(audio_path),
         "-ac", "1", "-ar", "16000", str(wav)],
        check=True,
    )

    hako_blocks = load_hako(hako_path, separator=hako_separator)
    log(f"    ハコ数: {len(hako_blocks)}")

    # Whisper 書き起こし
    cache_path = (tmp_dir / "whisper_cache.json") if use_cache else None
    if use_api:
        log("[1] OpenAI API 音声認識実行中...")
        whisper_words = run_whisper_transcribe_api(wav, language, api_key, cache_path, log)
    else:
        log("[1] Whisper 音声認識実行中...")
        whisper_words = run_whisper_transcribe(
            wav, "".join(hako_blocks), model_name, device, cache_path, log, language=language
        )
    log(f"    認識単語数: {len(whisper_words)}")

    # DP アライメント
    log("[2] DP アライメント実行中...")
    blocks = align_robust(hako_blocks, whisper_words, min_disp_sec, log)

    # ポスト調整
    log("[3] タイミング調整中...")
    blocks = apply_adjustments(
        blocks, global_offset, post_out_pad_sec,
        min_disp_sec, min_gap, frame_gap_ms, silence_threshold_ms,
    )
    blocks = resolve_overlaps(blocks, min_gap, min_disp_sec)

    # fps スナップ
    log(f"[4] タイムスタンプを {fps}fps にスナップ中...")
    for b in blocks:
        b["start"] = snap(b["start"], fps)
        b["end"]   = snap(b["end"],   fps)
    blocks = resolve_overlaps(blocks, min_gap, min_disp_sec)

    # SRT / TXT / CSV 書き出し
    log("[5] SRT/TXT/CSV 書き出し中...")
    srt_path = output_dir / "output.srt"
    txt_path = output_dir / "output.txt"
    csv_path = output_dir / "output.csv"

    # SRT & TXT（同フォーマット）
    for out_path in (srt_path, txt_path):
        with out_path.open("w", encoding="utf-8-sig") as f:
            for i, b in enumerate(blocks, 1):
                f.write(f"{i}\n{fmt_ts(b['start'])} --> {fmt_ts(b['end'])}\n{b['text']}\n\n")

    # CSV（Excel で開きやすいよう . 区切りのタイムコード）
    def fmt_tc(t: float) -> str:
        t = max(0.0, float(t))
        total_ms = int(t * 1000)
        ms = total_ms % 1000
        ts = total_ms // 1000
        return f"{ts // 3600:02}:{(ts % 3600) // 60:02}:{ts % 60:02}.{ms:03}"

    buf = io.StringIO()
    writer = csv.writer(buf, lineterminator="\n")
    writer.writerow(["No", "Start", "End", "Duration", "Text"])
    for i, b in enumerate(blocks, 1):
        duration = round(b["end"] - b["start"], 3)
        writer.writerow([i, fmt_tc(b["start"]), fmt_tc(b["end"]), duration, b["text"]])
    csv_path.write_text("﻿" + buf.getvalue(), encoding="utf-8")

    log(f"[完了] ブロック数: {len(blocks)}")
    return srt_path, txt_path, csv_path

# ---------------------------------------------------------------------------
# 原稿なし文字起こし（ヘルパー）
# ---------------------------------------------------------------------------
def _transcribe_segments_local(
    wav: Path,
    model_name: str,
    device: str,
    language: str,
    cache_path: Optional[Path],
    log: Callable[[str], None],
) -> List[Dict]:
    if cache_path and cache_path.exists():
        log("  キャッシュを使用します")
        return json.loads(cache_path.read_text(encoding="utf-8"))

    import stable_whisper
    log(f"  モデル {model_name} をロード中...")
    _whisper_cache = os.environ.get("WHISPER_CACHE_DIR") or None
    model = stable_whisper.load_model(model_name, device=device, download_root=_whisper_cache)

    lang_arg = None if language == "auto" else language
    log("  Transcribe（音声認識）実行中...")
    result = model.transcribe(str(wav), language=lang_arg, vad=True)

    segments = []
    for seg in result.to_dict().get("segments", []):
        text = seg.get("text", "").strip()
        if text:
            segments.append({
                "text":  text,
                "start": float(seg["start"]),
                "end":   float(seg["end"]),
            })

    if cache_path:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(json.dumps(segments, ensure_ascii=False, indent=2), encoding="utf-8")
    return segments


def _transcribe_segments_api(
    wav: Path,
    language: str,
    api_key: str,
    cache_path: Optional[Path],
    log: Callable[[str], None],
) -> List[Dict]:
    if cache_path and cache_path.exists():
        log("  キャッシュを使用します")
        return json.loads(cache_path.read_text(encoding="utf-8"))

    from openai import OpenAI

    mp3_path = wav.parent / "api_tr_input.mp3"
    log("  API 用に音声を MP3 変換中...")
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-i", str(wav), "-q:a", "5", str(mp3_path)],
        check=True,
    )
    size_mb = mp3_path.stat().st_size / (1024 ** 2)
    log(f"  送信サイズ: {size_mb:.1f} MB (上限 25 MB)")
    if size_mb > 24.5:
        raise ValueError(
            f"音声ファイルが OpenAI API の上限 25 MB を超えています（{size_mb:.1f} MB）。"
            "より短い音声を使用するか、ローカルモードをお使いください。"
        )

    client = OpenAI(api_key=api_key)
    log("  OpenAI Whisper API (whisper-1) に送信中...")
    lang_arg = None if language == "auto" else language
    with mp3_path.open("rb") as f:
        response = client.audio.transcriptions.create(
            model="whisper-1",
            file=f,
            language=lang_arg,
            response_format="verbose_json",
            timestamp_granularities=["segment"],
        )

    segments = []
    for seg in getattr(response, "segments", []) or []:
        text = getattr(seg, "text", "").strip()
        if text:
            segments.append({
                "text":  text,
                "start": float(seg.start),
                "end":   float(seg.end),
            })

    if cache_path:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(json.dumps(segments, ensure_ascii=False, indent=2), encoding="utf-8")
    return segments


# ---------------------------------------------------------------------------
# 原稿なし文字起こし（メイン API）
# ---------------------------------------------------------------------------
def transcribe_only(
    audio_path: Path,
    output_dir: Path,
    model_name: str = "turbo",
    fps: int = 30,
    global_offset: float = 0.00,
    post_out_pad_sec: float = 0.2,
    min_disp_sec: float = 0.8,
    silence_threshold_ms: float = 400,
    device: str = "cpu",
    use_cache: bool = True,
    language: str = "ja",
    use_api: bool = False,
    api_key: str = "",
    log: Optional[Callable[[str], None]] = None,
) -> Tuple[Path, Path, Path]:
    """音声ファイルのみから SRT を生成（原稿なし・Whisper セグメントを直接変換）。"""
    if log is None:
        log = print

    min_gap = 1.0 / fps
    output_dir.mkdir(parents=True, exist_ok=True)
    tmp_dir = output_dir / "_tmp"
    tmp_dir.mkdir(exist_ok=True)

    wav = tmp_dir / "norm_tr.wav"
    log("[0] 音声変換中 (ffmpeg)...")
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-i", str(audio_path),
         "-ac", "1", "-ar", "16000", str(wav)],
        check=True,
    )

    cache_path = (tmp_dir / "whisper_tr_cache.json") if use_cache else None

    if use_api:
        log("[1] OpenAI API 音声認識実行中...")
        segments = _transcribe_segments_api(wav, language, api_key, cache_path, log)
    else:
        log("[1] Whisper 音声認識実行中...")
        segments = _transcribe_segments_local(wav, model_name, device, language, cache_path, log)

    log(f"  認識セグメント数: {len(segments)}")

    blocks = apply_adjustments(
        segments, global_offset, post_out_pad_sec,
        min_disp_sec, min_gap, 33, silence_threshold_ms,
    )
    blocks = resolve_overlaps(blocks, min_gap, min_disp_sec)

    for b in blocks:
        b["start"] = snap(b["start"], fps)
        b["end"]   = snap(b["end"],   fps)
    blocks = resolve_overlaps(blocks, min_gap, min_disp_sec)

    log("[完了] SRT/TXT/CSV 書き出し中...")
    srt_path = output_dir / "transcribe.srt"
    txt_path = output_dir / "transcribe.txt"
    csv_path = output_dir / "transcribe.csv"

    with srt_path.open("w", encoding="utf-8-sig") as f:
        for i, b in enumerate(blocks, 1):
            f.write(f"{i}\n{fmt_ts(b['start'])} --> {fmt_ts(b['end'])}\n{b['text']}\n\n")

    txt_path.write_text(
        "".join(f"{b['text']}\n" for b in blocks),
        encoding="utf-8-sig",
    )

    def fmt_tc(t: float) -> str:
        t = max(0.0, float(t))
        total_ms = int(t * 1000)
        ms = total_ms % 1000
        ts = total_ms // 1000
        return f"{ts // 3600:02}:{(ts % 3600) // 60:02}:{ts % 60:02}.{ms:03}"

    buf = io.StringIO()
    writer = csv.writer(buf, lineterminator="\n")
    writer.writerow(["No", "Start", "End", "Duration", "Text"])
    for i, b in enumerate(blocks, 1):
        duration = round(b["end"] - b["start"], 3)
        writer.writerow([i, fmt_tc(b["start"]), fmt_tc(b["end"]), duration, b["text"]])
    csv_path.write_text("﻿" + buf.getvalue(), encoding="utf-8")

    log(f"[完了] セグメント数: {len(blocks)}")
    return srt_path, txt_path, csv_path


# ---------------------------------------------------------------------------
# CLI エントリポイント（後方互換）
# ---------------------------------------------------------------------------
def main():
    BASE  = Path(r"D:\AIWorks")
    generate_srt(
        audio_path  = BASE / "audio.mp3",
        hako_path   = BASE / "hako.txt",
        output_dir  = BASE,
    )

if __name__ == "__main__":
    main()
