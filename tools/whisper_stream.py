#!/usr/bin/python3
"""Sous-titres en direct : lit du PCM s16le stéréo 48 kHz sur stdin, écrit une ligne de texte (Whisper) par phrase sur stdout.
Usage : whisper_stream.py [modèle=small] [langue=auto]"""
import sys, os, re, threading, queue
import numpy as np
import whisper

model_name = sys.argv[1] if len(sys.argv) > 1 else "small"
lang = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != "auto" else None
import torch
dev = "cuda" if torch.cuda.is_available() else "cpu"
model = whisper.load_model(model_name, device=dev)
print("\x01ready", flush=True)

RATE, STEP = 48000, 3          # 48 kHz -> 16 kHz
WIN = 1600                     # fenêtres d'énergie de 100 ms (à 16 kHz)
MAX_S, MIN_S, SIL_S = 8.0, 0.8, 0.45
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
                         condition_on_previous_text=False, no_speech_threshold=0.5,
                         compression_ratio_threshold=2.2, logprob_threshold=-1.0)
    for s in r["segments"]:
        t = s["text"].strip()
        if t and s["no_speech_prob"] < 0.6 and not BAD.search(t):
            print(t, flush=True)

threading.Thread(target=reader, daemon=True).start()
while True:
    raw = qq.get()
    if not raw:
        break
    x = np.frombuffer(raw[: len(raw) // 4 * 4], np.int16).reshape(-1, 2).astype(np.float32) / 32768.0
    m = x.mean(axis=1)
    m = m[: len(m) // STEP * STEP].reshape(-1, STEP).mean(axis=1)
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
