#!/usr/bin/python3
"""Sous-titres en direct (Vosk, flux continu) : lit du PCM s16le stéréo 48 kHz sur stdin ; écrit « \x06mots en cours » pendant que ça parle,
puis une ligne minutée par groupe de mots à la fin de la phrase.
Usage : vosk_stream.py _ [langue=fr|en|es] [traduction=none|es|en|fr|de|it|pt]  (1er argument ignoré, compatibilité)
Sortie : « texte » ou « texte\x02traduction » (traduction via Ollama, gemma3:4b)."""
import sys, os, re, time, json, threading, queue, urllib.request
import numpy as np
import json as _j
from vosk import Model, KaldiRecognizer, SetLogLevel

model_name = sys.argv[1] if len(sys.argv) > 1 else "small"
lang = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] in ("fr", "en", "es") else "fr"
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

BAD = re.compile(r"(sous-?titr|amara|merci d'avoir regard|thanks for watching|subscribe|abonne)", re.I)

MODELS = {"fr": "vosk-model-small-fr-0.22", "en": "vosk-model-small-en-us-0.15", "es": "vosk-model-small-es-0.42"}
mdir = os.environ.get("POCKET_VOSK", os.path.expanduser("~/.local/share/pocket-speaker/models")) + "/" + MODELS[lang]
SetLogLevel(-1)
rec = KaldiRecognizer(Model(mdir), 16000)
rec.SetWords(True)
print("\x01ready", flush=True)

workq = queue.Queue()
nblock = 0
def worker():  # traduction hors de la boucle audio : les mots en direct ne sont jamais bloqués
    while True:
        n, text = workq.get()
        try:
            tr = translate(text)
            if tr:
                print("\x08%d\x1f%s" % (n, tr.replace("\n", " ")), flush=True)
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
        t = r.get("text", "").strip()
        if t and not BAD.search(t):
            nblock += 1
            print("\x07%d\x1f%s" % (nblock, t), flush=True)  # bloc de phrase, tout de suite
            if target:
                workq.put((nblock, t))
    else:
        p = _j.loads(rec.PartialResult()).get("partial", "")
        if p != last:
            last = p
            print("\x06" + p, flush=True)
