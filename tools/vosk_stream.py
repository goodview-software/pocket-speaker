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
rec.SetPartialWords(True)
try:  # coupe plus vite sur les silences : des phrases courtes plutôt que des pavés
    from vosk import EndpointerMode
    rec.SetEndpointerMode(EndpointerMode.SHORT)
except Exception:
    pass

def split_words(words, text):
    """Découpe un long passage en petites phrases : à chaque pause nette entre deux mots, ou au bout de 12 mots."""
    out, cur = [], []
    for i, w in enumerate(words):
        if cur and (w["start"] - words[i - 1]["end"] >= 0.4 and len(cur) >= 3 or len(cur) >= 12):
            out.append(" ".join(x["word"] for x in cur))
            cur = []
        cur.append(w)
    if cur:
        out.append(" ".join(x["word"] for x in cur))
    return out or ([text] if text else [])
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
committed = 0  # mots du passage en cours déjà envoyés en blocs (les blocs partent pendant qu'on parle)

def block(part):
    global nblock
    nblock += 1
    print("\x07%d\x1f%s" % (nblock, part), flush=True)
    if target:
        workq.put((nblock, part))

def cut_index(words, start):
    """Premier point de coupe après `start` : une pause nette (>= 0,4 s) après 3 mots, ou 12 mots. -1 si pas encore."""
    for i in range(start + 1, len(words)):
        n = i - start
        if n >= 3 and words[i]["start"] - words[i - 1]["end"] >= 0.4:
            return i
        if n >= 12:
            return i + 1
    return -1

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
        words = (r.get("result") or [])[committed:]
        committed = 0
        t = " ".join(w["word"] for w in words) if words else (r.get("text", "").strip() if not r.get("result") else "")
        if t and not BAD.search(t):
            for part in split_words(words, t):
                block(part)
    else:
        pj = _j.loads(rec.PartialResult())
        pw = pj.get("partial_result") or []
        c = cut_index(pw, committed)
        while c != -1:  # assez de mots : on envoie une petite phrase sans attendre la fin
            part = " ".join(w["word"] for w in pw[committed:c])
            if part and not BAD.search(part):
                block(part)
            committed = c
            c = cut_index(pw, committed)
        p = " ".join(w["word"] for w in pw[committed:]) if pw else pj.get("partial", "")
        if p != last:
            last = p
            print("\x06" + p, flush=True)
