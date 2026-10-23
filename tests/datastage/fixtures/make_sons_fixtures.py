r"""Fichiers témoins de la règle « sons » du harness (lot S0-suite) : trois VRAIS flux Ogg, 0,2 s d'un la (440 Hz),
encodés par PyAV (FFmpeg ; ni Blender, ni le jeu) :

    py -3.9 tests/datastage/fixtures/make_sons_fixtures.py

  s0-vorbis-pyav.ogg : Ogg VORBIS d'un autre encodeur que celui des sons du mod (libvorbis de FFmpeg) : doit PASSER ;
  s0-opus.ogg        : Ogg OPUS sous l'extension .ogg : doit être REFUSÉ (codec) ;
  s0-flac.ogg        : FLAC DANS Ogg sous l'extension .ogg : doit être REFUSÉ (codec).
Le moteur 1.1.91 lit .ogg, .wav et .voc (doc Sound.filename) ; qu'il lise Opus ou FLAC dans Ogg n'est pas prouvé : la
règle n'accepte en .ogg que du Vorbis, comme toute la vanilla (1 422 fichiers .ogg de data\, tous Vorbis).
Les fichiers sont commités (moins de 4 Ko chacun) : ce script n'est qu'une trace de leur fabrication.
"""
import os

import av
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RATE = 48000


def write(path, codec, fmt, rate):
    n = int(0.2 * rate)
    t = np.arange(n) / float(rate)
    tone = (0.3 * np.sin(2 * np.pi * 440.0 * t)).astype(np.float32)
    out = av.open(path, "w", format="ogg")
    st = out.add_stream(codec, rate=rate)
    st.layout = "mono"
    if fmt in ("s16",):
        data = (tone * 32767).astype(np.int16).reshape(1, -1)
    else:
        data = tone.reshape(1, -1)
    frame_size = st.codec_context.frame_size or 1024
    for i in range(0, n, frame_size):
        fr = av.AudioFrame.from_ndarray(np.ascontiguousarray(data[:, i:i + frame_size]), format=fmt, layout="mono")
        fr.sample_rate = rate
        fr.pts = i
        for p in st.encode(fr):
            out.mux(p)
    for p in st.encode(None):
        out.mux(p)
    out.close()
    print("%s : %d octets" % (os.path.basename(path), os.path.getsize(path)))


if __name__ == "__main__":
    write(os.path.join(HERE, "s0-vorbis-pyav.ogg"), "libvorbis", "fltp", 44100)
    write(os.path.join(HERE, "s0-opus.ogg"), "libopus", "s16", RATE)
    write(os.path.join(HERE, "s0-flac.ogg"), "flac", "s16", 44100)
