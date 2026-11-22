#!/usr/bin/python3
"""Sous-titres en direct (Vosk, flux continu) : lit du PCM s16le stéréo 48 kHz sur stdin ; écrit « \x06mots en cours » pendant que ça parle,
puis une ligne minutée par groupe de mots à la fin de la phrase.
Usage : vosk_stream.py _ [langue=fr|en|es] [traduction=none|es|en|fr|de|it|pt] [kid|0]  (1er argument ignoré, compatibilité)
Sortie : « texte » ou « texte\x02traduction » (traduction via Ollama, gemma3:4b)."""
import sys, os, re, time, json, threading, queue, urllib.request
import numpy as np
import json as _j
from vosk import Model, KaldiRecognizer, SetLogLevel

model_name = sys.argv[1] if len(sys.argv) > 1 else "small"
lang = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] in ("fr", "en", "es") else "fr"
kid = len(sys.argv) > 4 and sys.argv[4] == "kid"
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

def simplify(t):
    """Mode enfant : reformule avec des mots très simples (même sens, même langue)."""
    body = {"model": TMODEL, "stream": False, "keep_alive": "30m", "options": {"num_predict": 120, "temperature": 0},
            "prompt": "Réécris cette phrase avec des mots très simples, pour un enfant de 8 ans. Garde le même sens et la même langue. Phrase courte. Réponds uniquement par la phrase.\n\n" + t}
    try:
        rq = urllib.request.Request(OLLAMA + "/api/generate", json.dumps(body).encode(), {"Content-Type": "application/json"})
        out = json.load(urllib.request.urlopen(rq, timeout=20))["response"].strip().split("\n")[0]
        return out or t
    except Exception:
        return t

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

MODELS = {"fr": "vosk-model-small-fr-0.22", "en": "vosk-model-small-en-us-0.15", "es": "vosk-model-small-es-0.42"}
mdir = os.environ.get("POCKET_VOSK", os.path.expanduser("~/.local/share/pocket-speaker/models")) + "/" + MODELS[lang]
SetLogLevel(-1)
rec = KaldiRecognizer(Model(mdir), 16000)
rec.SetWords(True)
print("\x01ready", flush=True)

workq = queue.Queue()
def emit(words, text):
    t = text.strip()
    if not t or BAD.search(t):
        return
    if kid:
        t = simplify(t)
        words = []
    chs = chunks(t, 4 if kid else 5)
    trs = translate_chunks(t, chs) if target else [None] * len(chs)
    idx = 0
    n_all = max(1, sum(len(c.split()) for c in chs))
    seg_s = words[0]["start"] if words else 0.0
    seg_e = words[-1]["end"] if words else 2.0
    for c, tr in zip(chs, trs):
        k = len(c.split())
        if words:
            st = words[min(idx, len(words) - 1)]["start"]
            en = words[min(idx + k, len(words)) - 1]["end"]
        else:
            st = seg_s + (seg_e - seg_s) * idx / n_all
            en = seg_s + (seg_e - seg_s) * (idx + k) / n_all
        idx += k
        print("%.2f,%.2f\x03%s" % (st, en, c) + ("\x02" + tr.replace("\n", " ") if tr else ""), flush=True)

def worker():  # traduction / simplification hors de la boucle audio
    while True:
        words, text = workq.get()
        try:
            emit(words, text)
        except Exception:
            pass
threading.Thread(target=worker, daemon=True).start()

RATE, STEP = 48000, 3
inp = sys.stdin.buffer
last = ""
while True:
    raw = inp.read(4 * STEP * 480)  # ~30 ms
    if not raw:
        break
    x = np.frombuffer(raw[: len(raw) // 4 * 4], np.int16).reshape(-1, 2).astype(np.float32)
    m = x.mean(axis=1)
    m = m[: len(m) // STEP * STEP].reshape(-1, STEP).mean(axis=1).astype(np.int16)
    if rec.AcceptWaveform(m.tobytes()):
        r = _j.loads(rec.Result())
        print("\x06", flush=True)
        last = ""
        if r.get("text"):
            workq.put((r.get("result") or [], r["text"]))
    else:
        p = _j.loads(rec.PartialResult()).get("partial", "")
        if p != last:
            last = p
            print("\x06" + p, flush=True)
