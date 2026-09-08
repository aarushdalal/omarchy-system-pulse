#!/usr/bin/env python3
"""
Hyper-Reactive 60 FPS Audio Spectrum Analyzer with Perfect Buffer Accumulation.
Accumulates full 368-sample frames continuously without pipe slice dropouts.
"""

import sys
import os
import time
import math
import struct
import subprocess
import signal

CHUNK_SIZE = 368
SAMPLE_RATE = 22050
NUM_BANDS = 18

# 18 log-spaced frequency filters from 45 Hz to 11.5 kHz
filters = []
for b in range(NUM_BANDS):
    freq = 45.0 * (1.36 ** b)
    k = int(0.5 + (CHUNK_SIZE * freq / SAMPLE_RATE))
    omega = (2.0 * math.pi * k) / CHUNK_SIZE
    coeff = 2.0 * math.cos(omega)
    eq_boost = 1.0 + (b * 0.08)
    if b < 4:
        eq_boost += 0.35 # punchy bass
    filters.append((coeff, math.cos(omega), math.sin(omega), eq_boost))

smooth = [0.0] * NUM_BANDS
rolling_max = 50.0

def get_active_monitor_target():
    """Detect the best audio stream monitor target."""
    try:
        sinks_out = subprocess.check_output(["pactl", "list", "short", "sinks"], stderr=subprocess.DEVNULL, timeout=1.0).decode()
        # If EasyEffects is active, it receives all application audio
        if "easyeffects_sink" in sinks_out:
            return "easyeffects_sink.monitor"
        
        sink = subprocess.check_output(["pactl", "get-default-sink"], stderr=subprocess.DEVNULL, timeout=1.0).decode().strip()
        if sink:
            return f"{sink}.monitor"
    except Exception:
        pass
    return "@DEFAULT_MONITOR@"

def spawn_parec(target):
    try:
        proc = subprocess.Popen(
            [
                "parec",
                "-d", target,
                "--rate", str(SAMPLE_RATE),
                "--channels", "1",
                "--format", "s16le",
                "--latency-msec=16"
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            bufsize=0
        )
        return proc
    except Exception:
        return None

def read_exact(stream, n):
    """Accumulate exactly n bytes from the pipe stream without partial-read drops."""
    buf = bytearray()
    while len(buf) < n:
        chunk = stream.read(n - len(buf))
        if not chunk:
            return None
        buf.extend(chunk)
    return bytes(buf)

def main():
    global rolling_max
    current_target = get_active_monitor_target()
    current_proc = spawn_parec(current_target)
    last_sink_check = time.time()

    def cleanup(signum=None, frame=None):
        nonlocal current_proc
        if current_proc:
            try:
                current_proc.terminate()
                current_proc.kill()
            except Exception:
                pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    frame_bytes = CHUNK_SIZE * 2

    while True:
        now = time.time()
        # Periodically check if audio routing changed
        if now - last_sink_check > 4.0:
            last_sink_check = now
            new_target = get_active_monitor_target()
            if new_target != current_target:
                current_target = new_target
                if current_proc:
                    try:
                        current_proc.terminate()
                        current_proc.kill()
                    except Exception:
                        pass
                current_proc = spawn_parec(current_target)

        if not current_proc or current_proc.poll() is not None:
            time.sleep(0.3)
            current_target = get_active_monitor_target()
            current_proc = spawn_parec(current_target)
            if not current_proc:
                sys.stdout.buffer.write((",".join(["0"] * NUM_BANDS) + "\n").encode("ascii"))
                sys.stdout.buffer.flush()
                time.sleep(0.016)
                continue

        try:
            raw = read_exact(current_proc.stdout, frame_bytes)
            if not raw:
                # Smooth decay on stream close
                out = []
                for i in range(NUM_BANDS):
                    smooth[i] = max(0.0, smooth[i] * 0.65)
                    out.append(int(smooth[i]))
                sys.stdout.buffer.write((",".join(map(str, out)) + "\n").encode("ascii"))
                sys.stdout.buffer.flush()
                time.sleep(0.016)
                continue

            samples = struct.unpack(f"<{CHUNK_SIZE}h", raw)

            # Check peak sample amplitude
            max_amp = max(abs(s) for s in samples)
            if max_amp < 5:
                # Silence decay with low CPU idle sleep
                out = []
                for i in range(NUM_BANDS):
                    smooth[i] = max(0.0, smooth[i] * 0.65)
                    out.append(int(smooth[i]))
                sys.stdout.buffer.write((",".join(map(str, out)) + "\n").encode("ascii"))
                sys.stdout.buffer.flush()
                time.sleep(0.035)
                continue


            # Calculate raw magnitudes for each band
            mags = []
            for i, (coeff, cos_w, sin_w, eq_boost) in enumerate(filters):
                q0, q1, q2 = 0.0, 0.0, 0.0
                for x in samples:
                    q0 = coeff * q1 - q2 + x
                    q2 = q1
                    q1 = q0
                real = q1 - q2 * cos_w
                imag = q2 * sin_w
                mag = (math.sqrt(real * real + imag * imag) / CHUNK_SIZE) * eq_boost
                mags.append(mag)

            # Track peak energy for adaptive AGC
            frame_max = max(mags) if mags else 1.0
            if frame_max > rolling_max:
                rolling_max = rolling_max * 0.6 + frame_max * 0.4
            else:
                rolling_max = max(15.0, rolling_max * 0.985)

            # Adaptive dynamic scaling: maps energy cleanly from 15% to 100%
            out = []
            for i, mag in enumerate(mags):
                ratio = min(1.0, max(0.0, mag / max(10.0, rolling_max)))
                val = min(100.0, max(0.0, math.pow(ratio, 0.65) * 100.0))

                # Snappy attack, smooth decay
                if val > smooth[i]:
                    smooth[i] = val
                else:
                    smooth[i] = max(0.0, smooth[i] * 0.68 + val * 0.32)

                out.append(int(smooth[i]))

            sys.stdout.buffer.write((",".join(map(str, out)) + "\n").encode("ascii"))
            sys.stdout.buffer.flush()
            time.sleep(0.016)


        except (BrokenPipeError, KeyboardInterrupt):
            break
        except Exception:
            time.sleep(0.016)

    cleanup()

if __name__ == "__main__":
    main()
