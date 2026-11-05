"""スタンプの「ポン」の音を合成する。 python3 tool/make_pon_sound.py"""
import math
import random
import struct
import wave

RATE = 44100
DURATION = 0.28
random.seed(7)
samples = []
phase = 0.0
for i in range(int(RATE * DURATION)):
    t = i / RATE
    freq = 190 + 430 * math.exp(-t / 0.035)
    phase += 2 * math.pi * freq / RATE
    body = math.sin(phase) * math.exp(-t / 0.065)
    overtone = 0.25 * math.sin(phase * 2.02) * math.exp(-t / 0.025)
    click = 0.35 * random.uniform(-1, 1) * math.exp(-t / 0.0015)
    samples.append(body + overtone + click)
peak = max(abs(s) for s in samples)
fade = int(RATE * 0.03)
frames = bytearray()
for i, s in enumerate(samples):
    gain = min(1.0, (len(samples) - i) / fade)
    frames += struct.pack("<h", int(s / peak * 0.8 * gain * 32767))
with wave.open("assets/sounds/pon.wav", "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(bytes(frames))
