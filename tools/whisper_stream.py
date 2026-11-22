#!/usr/bin/python3
"""Sous-titres en direct : lit du PCM s16le stéréo 48 kHz sur stdin, écrit une ligne de texte (Whisper) par phrase sur stdout.
Usage : whisper_stream.py [modèle=small] [langue=auto] [traduction=none|es|en|fr|de|it|pt]
Sortie : « texte » ou « texte\x02traduction » (traduction via Ollama, gemma3:4b)."""
import sys, os, re, json, threading, queue, urllib.request
import numpy as np
import whisper

model_name = sys.argv[1] if len(sys.argv) > 1 else "small"
lang = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != "auto" else None
target = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] != "none" else None
NAMES = {"es": "espagnol", "en": "anglais", "fr": "français", "de": "allemand", "it": "italien", "pt": "portugais"}
OLLAMA = os.environ.get("POCKET_OLLAMA", "http://127.0.0.1:11434")
TMODEL = os.environ.get("POCKET_TRANSLATE_MODEL", "gemma3:4b")

def translate(t):
    body = {"model": TMODEL, "stream": False, "keep_alive": "30m", "options": {"num_predict": 200, "temperature": 0},
            "prompt": "Traduis ce texte en %s. Réponds uniquement par la traduction, sans commentaire.\n\n%s" % (NAMES.get(target, target), t)}
    try:
        rq = urllib.request.Request(OLLAMA + "/api/generate", json.dumps(body).encode(), {"Content-Type": "application/json"})
        out = json.load(urllib.request.urlopen(rq, timeout=20))["response"].strip()
        return out if out and out.lower() != t.lower() else None
    except Exception:
        return None
import torch
dev = "cuda" if torch.cuda.is_available() else "cpu"
model = whisper.load_model(model_name, device=dev)
print("\x01ready", flush=True)

RATE, STEP = 48000, 3          # 48 kHz -> 16 kHz
WIN = 1600                     # fenêtres d'énergie de 100 ms (à 16 kHz)
MAX_S, MIN_S, SIL_S = 6.0, 0.6, 0.35
total16 = 0  # échantillons 16 kHz lus depuis le début du flux (horloge du flux)
def chunks(t, n=5):
    """Découpe une phrase en groupes de 2 à n mots (sur la ponctuation, puis par taille)."""
    parts = [p.strip() for p in re.findall(r"[^,;:.!?…]+[,;:.!?…]*", t) if p.strip()]
    out = []
    for p in parts:
        w = p.split()
        k = -(-len(w) // n)
        per = -(-len(w) // k)
        out += [" ".join(w[i:i + per]) for i in range(0, len(w), per)]
    merged = []
    for c in out:  # un groupe d'un seul mot rejoint le précédent
        if merged and len(c.split()) == 1 and len(merged[-1].split()) < n + 1:
            merged[-1] += " " + c
        else:
            merged.append(c)
    return merged or [t]

def translate_chunks(full, chs):
    if len(chs) == 1:
        return [translate(chs[0])]
    body = {"model": TMODEL, "stream": False, "keep_alive": "30m", "options": {"num_predict": 300, "temperature": 0},
            "prompt": "Traduis en %s ce texte découpé en segments séparés par ' || '. Garde exactement le même découpage (même nombre de segments, séparés par ' || '). Réponds uniquement par la traduction.\n\n%s" % (NAMES.get(target, target), " || ".join(chs))}
    try:
        rq = urllib.request.Request(OLLAMA + "/api/generate", json.dumps(body).encode(), {"Content-Type": "application/json"})
        parts = [x.strip() for x in json.load(urllib.request.urlopen(rq, timeout=30))["response"].split("||")]
        if len(parts) == len(chs) and all(parts):
            return parts
    except Exception:
        pass
    return [translate(c) for c in chs]

BAD = re.compile(r"(sous-?titr|amara|merci d'avoir regard|thanks for watching|subscribe|abonne)", re.I)
unit = 4 * STEP * WIN  # octets par pas de 100 ms
inp = sys.stdin.buffer
qq = queue.Queue()

def reader():  # vide stdin en continu pour ne jamais bloquer l'appli pendant une transcription
    while True:
        r = inp.read(unit)
        qq.put(r)
        if not r:
            return
        while qq.qsize() > 100:  # >10 s de retard : on jette le plus ancien
            try: qq.get_nowait()
            except queue.Empty: break
buf = np.zeros(0, np.float32)
voiced = False
sil = 0

def flush(a):
    global buf, voiced, sil
    buf = np.zeros(0, np.float32); voiced = False; sil = 0
    if len(a) < MIN_S * 16000:
        return
    r = model.transcribe(a, language=lang, fp16=(dev == "cuda"), temperature=0.0,
                         condition_on_previous_text=False, word_timestamps=True, no_speech_threshold=0.5,
                         compression_ratio_threshold=2.2, logprob_threshold=-1.0)
    base = (total16 - len(a)) / 16000.0  # début du tampon dans l'horloge du flux
    for s in r["segments"]:
        t = s["text"].strip()
        if t and s["no_speech_prob"] < 0.6 and not BAD.search(t):
            chs = chunks(t)
            words = s.get("words") or []
            trs = translate_chunks(t, chs) if target else [None] * len(chs)
            idx = 0
            for c, tr in zip(chs, trs):
                st = words[min(idx, len(words) - 1)]["start"] if words else s["start"]
                idx += len(c.split())
                print("%.2f\x03%s" % (base + st, c) + ("\x02" + tr.replace("\n", " ") if tr else ""), flush=True)

threading.Thread(target=reader, daemon=True).start()
while True:
    raw = qq.get()
    if not raw:
        break
    x = np.frombuffer(raw[: len(raw) // 4 * 4], np.int16).reshape(-1, 2).astype(np.float32) / 32768.0
    m = x.mean(axis=1)
    m = m[: len(m) // STEP * STEP].reshape(-1, STEP).mean(axis=1)
    total16 += len(m)
    rms = float(np.sqrt(np.mean(m * m))) if len(m) else 0.0
    if rms > 0.008:
        voiced = True; sil = 0
    else:
        sil += 1
    if voiced or len(buf) < 16000 * 0.3:
        buf = np.concatenate([buf, m])
    if not voiced:
        buf = buf[-int(16000 * 0.3):]
    elif len(buf) >= MAX_S * 16000 or (sil * 0.1 >= SIL_S and len(buf) >= MIN_S * 16000):
        flush(buf)
