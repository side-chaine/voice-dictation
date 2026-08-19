#!/usr/bin/env python3
"""Нормализация + шумовой гейт: переписывает WAV с пиком ~0.95,
тихие фреймы (ниже порога от шумового пола файла) обнуляет."""
import sys, wave, array, math

IN, OUT = sys.argv[1], sys.argv[2]
w = wave.open(IN, 'rb')
rate = w.getframerate()
data = array.array('h', w.readframes(w.getnframes()))
w.close()
if not data:
    sys.exit(1)

FR = int(rate * 0.03)
frames = [data[i:i+FR] for i in range(0, len(data)-FR, FR)]
frms = sorted(math.sqrt(sum(x*x for x in f)/len(f)) for f in frames if len(f) == FR)
floor = frms[max(0, len(frms)//10 - 1)]
gate = max(floor * 1.8, 60)
peak = max(abs(x) for x in data)
gain = min(0.95 * 32767 / max(peak, 1), 20.0)

out = array.array('h')
for f in frames:
    r = math.sqrt(sum(x*x for x in f)/len(f)) if f else 0
    g = gain if r >= gate else 0.0
    out.extend(array.array('h', (int(x*g) for x in f)))

res = wave.open(OUT, 'wb')
res.setnchannels(1); res.setsampwidth(2); res.setframerate(rate)
res.writeframes(out.tobytes())
res.close()
sys.stderr.write("floor=%d gate=%d gain=%.1f peak=%d\n" % (floor, gate, gain, peak))