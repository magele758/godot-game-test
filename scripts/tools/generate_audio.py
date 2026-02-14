"""
程序化生成游戏音效和背景音乐 (WAV)
运行: conda run -n gamefx python scripts/tools/generate_audio.py
"""
import numpy as np
from scipy.io import wavfile
import os

SR = 44100  # 采样率
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'audio')
os.makedirs(OUT, exist_ok=True)


def normalize(sig, peak=0.85):
    mx = np.max(np.abs(sig))
    if mx > 0:
        sig = sig / mx * peak
    return sig


def to_16bit(sig):
    return (normalize(sig) * 32767).astype(np.int16)


def envelope(length, attack=0.01, decay=0.05, sustain_level=0.7, release=0.1):
    """ADSR 包络"""
    n = max(1, int(length * SR))
    a = max(1, int(attack * SR))
    d = max(1, int(decay * SR))
    r = max(1, int(release * SR))
    s = max(0, n - a - d - r)
    parts = [
        np.linspace(0, 1, a),
        np.linspace(1, sustain_level, d),
        np.full(s, sustain_level),
        np.linspace(sustain_level, 0, r),
    ]
    env = np.concatenate(parts)
    if len(env) > n:
        env = env[:n]
    elif len(env) < n:
        env = np.pad(env, (0, n - len(env)))
    return env


def sine(freq, duration, phase=0):
    t = np.linspace(0, duration, int(SR * duration), endpoint=False)
    return np.sin(2 * np.pi * freq * t + phase)


def noise(duration):
    return np.random.uniform(-1, 1, int(SR * duration))


def save(name, sig):
    path = os.path.join(OUT, name)
    wavfile.write(path, SR, to_16bit(sig))
    print(f"  -> {path}")


# ──────────────────────────────────────────────
# 1. 背景音乐 (30秒循环, 可爱+轻快)
# ──────────────────────────────────────────────
def generate_bgm():
    duration = 30.0
    t = np.linspace(0, duration, int(SR * duration), endpoint=False)
    
    # 简单和弦进行: C - Am - F - G (每个4拍, BPM=110)
    bpm = 110
    beat = 60.0 / bpm
    bar = beat * 4
    
    chords = [
        [261.63, 329.63, 392.00],  # C
        [220.00, 261.63, 329.63],  # Am
        [174.61, 220.00, 261.63],  # F
        [196.00, 246.94, 293.66],  # G
    ]
    
    sig = np.zeros(len(t))
    
    # 柔和 pad 音色
    for i, chord in enumerate(chords):
        # 循环整首歌
        for repeat in range(int(duration / (bar * 4)) + 1):
            start = repeat * bar * 4 + i * bar
            end = start + bar
            if start >= duration:
                break
            s = int(start * SR)
            e = min(int(end * SR), len(t))
            seg_len = e - s
            if seg_len <= 0:
                continue
            seg_t = np.linspace(0, bar, seg_len, endpoint=False)
            for freq in chord:
                # 用三角波让音色更柔和
                wave = np.abs(2 * (seg_t * freq % 1) - 1) * 2 - 1
                env = np.ones(seg_len) * 0.15
                env[:int(0.02*SR)] = np.linspace(0, 0.15, int(0.02*SR))[:len(env[:int(0.02*SR)])]
                sig[s:e] += wave * env * 0.3

    # 简单旋律 (八音盒风格)
    melody_notes = [
        523.25, 587.33, 659.25, 523.25,
        440.00, 493.88, 523.25, 440.00,
        349.23, 392.00, 440.00, 349.23,
        392.00, 440.00, 493.88, 523.25,
    ]
    note_dur = beat * 0.8
    for repeat in range(int(duration / (beat * len(melody_notes))) + 1):
        for j, note in enumerate(melody_notes):
            start = repeat * beat * len(melody_notes) + j * beat
            if start >= duration:
                break
            s = int(start * SR)
            seg_len = int(note_dur * SR)
            e = min(s + seg_len, len(t))
            if e <= s:
                continue
            actual_len = e - s
            seg = sine(note, actual_len / SR) * 0.2
            env = envelope(actual_len / SR, attack=0.005, decay=0.05, sustain_level=0.3, release=0.15)
            env = env[:actual_len]
            sig[s:e] += seg[:actual_len] * env

    # 淡入淡出
    fade = int(0.5 * SR)
    sig[:fade] *= np.linspace(0, 1, fade)
    sig[-fade:] *= np.linspace(1, 0, fade)
    
    save("bgm_loop.wav", sig)


# ──────────────────────────────────────────────
# 2. 打击音效 (短促冲击)
# ──────────────────────────────────────────────
def generate_hit():
    dur = 0.12
    sig = sine(180, dur) * 0.6 + noise(dur) * 0.4
    env = envelope(dur, attack=0.001, decay=0.03, sustain_level=0.3, release=0.06)
    save("sfx_hit.wav", sig * env)


# ──────────────────────────────────────────────
# 3. 击杀音效 (下降音 + 爆裂)
# ──────────────────────────────────────────────
def generate_kill():
    dur = 0.35
    t = np.linspace(0, dur, int(SR * dur), endpoint=False)
    # 下降频率
    freq = np.linspace(600, 80, len(t))
    phase = np.cumsum(2 * np.pi * freq / SR)
    sig = np.sin(phase) * 0.5 + noise(dur) * 0.5
    env = envelope(dur, attack=0.001, decay=0.08, sustain_level=0.4, release=0.15)
    save("sfx_kill.wav", sig * env)


# ──────────────────────────────────────────────
# 4. 闪避音效 (嗖~ 风声)
# ──────────────────────────────────────────────
def generate_dodge():
    dur = 0.18
    t = np.linspace(0, dur, int(SR * dur), endpoint=False)
    # 带通滤波噪声模拟风声
    freq = np.linspace(800, 2000, len(t))
    phase = np.cumsum(2 * np.pi * freq / SR)
    sig = np.sin(phase) * 0.3 + noise(dur) * 0.3
    env = envelope(dur, attack=0.005, decay=0.04, sustain_level=0.5, release=0.08)
    save("sfx_dodge.wav", sig * env)


# ──────────────────────────────────────────────
# 5. 完美闪避 (叮~ 亮音)
# ──────────────────────────────────────────────
def generate_perfect_dodge():
    dur = 0.25
    sig = sine(1200, dur) * 0.4 + sine(1800, dur) * 0.25 + sine(2400, dur) * 0.15
    env = envelope(dur, attack=0.002, decay=0.06, sustain_level=0.3, release=0.12)
    save("sfx_perfect_dodge.wav", sig * env)


# ──────────────────────────────────────────────
# 6. 受伤音效
# ──────────────────────────────────────────────
def generate_player_hurt():
    dur = 0.2
    t = np.linspace(0, dur, int(SR * dur), endpoint=False)
    freq = np.linspace(400, 150, len(t))
    phase = np.cumsum(2 * np.pi * freq / SR)
    sig = np.sin(phase) * 0.5 + noise(dur) * 0.3
    env = envelope(dur, attack=0.001, decay=0.05, sustain_level=0.3, release=0.1)
    save("sfx_hurt.wav", sig * env)


# ──────────────────────────────────────────────
if __name__ == "__main__":
    print("Generating game audio...")
    generate_bgm()
    generate_hit()
    generate_kill()
    generate_dodge()
    generate_perfect_dodge()
    generate_player_hurt()
    print("Done!")
