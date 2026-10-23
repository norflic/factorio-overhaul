"""Entrées et sorties audio par le module `aud` de Blender (Audaspace, FFmpeg embarqué) : lot S0.

Lancé UNIQUEMENT par sons.py, à travers le verrou de rendu (CLAUDE.md §4, interdit 6) :

    python tools/render/with_render_lock.py -- <blender.exe> -b --factory-startup --python-exit-code 1
        --python tools/sound/blender_audio.py -- <travaux.json>

<travaux.json> : {"jobs": [{"op": ..., "src": ..., "dst": ...}, ...], "report": <chemin du rapport JSON>}
  - op "decode"  : src (.ogg, .wav...) -> dst .wav PCM 16 bits, même fréquence et mêmes canaux (lecture FFmpeg) ;
  - op "ogg"     : src .wav -> dst .ogg (Vorbis), « quality » ignorée par aud : débit `bitrate` (bits/s, défaut 96000) ;
  - op "mp3"     : src .wav -> dst .mp3 (lame par FFmpeg, si Blender l'embarque), débit `bitrate` (défaut 128000) ;
  - op "probe"   : src -> rapport (fréquence, canaux, durée, crête) sans rien écrire.
Le rapport dit, pour chaque travail, « ok » ou l'erreur, et les specs lues (aud.Sound(...).specs). Aucun fichier hors
des chemins dst n'est écrit. Les sons ne sont jamais joués (aucun périphérique audio ouvert : seules les écritures
de fichier d'Audaspace sont appelées).
"""
import json
import os
import sys
import traceback

import aud  # module de Blender
import numpy as np

CONTAINERS = {
    "wav": (aud.CONTAINER_WAV, aud.CODEC_PCM, aud.FORMAT_S16),
    "ogg": (aud.CONTAINER_OGG, aud.CODEC_VORBIS, aud.FORMAT_FLOAT32),
    "mp3": (aud.CONTAINER_MP3, aud.CODEC_MP3, aud.FORMAT_FLOAT32),
}


def specs(snd):
    rate, channels = snd.specs
    return {"rate": int(rate), "channels": int(channels)}


def stats(snd):
    data = snd.data()  # numpy float32, (échantillons, canaux)
    peak = float(np.max(np.abs(data))) if data.size else 0.0
    return {"frames": int(data.shape[0]), "peak": peak}


def write(snd, dst, kind, bitrate):
    container, codec, fmt = CONTAINERS[kind]
    rate, channels = snd.specs
    os.makedirs(os.path.dirname(os.path.abspath(dst)), exist_ok=True)
    if os.path.exists(dst):
        os.remove(dst)
    # aud.Sound.write(filename, rate, channels, format, container, codec, bitrate, buffersize)
    snd.write(dst, int(rate), int(channels), fmt, container, codec, int(bitrate))
    if not os.path.exists(dst) or os.path.getsize(dst) == 0:
        raise RuntimeError("fichier non écrit : %s" % dst)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) != 1:
        print("[fo-son] usage : blender -b --python blender_audio.py -- <travaux.json>")
        return 1
    with open(argv[0], encoding="utf-8") as f:
        work = json.load(f)
    results = []
    fail = 0
    for job in work["jobs"]:
        r = dict(job)
        try:
            snd = aud.Sound(job["src"])
            r["src_specs"] = specs(snd)
            r["src_stats"] = stats(snd)
            op = job["op"]
            if op == "decode":
                write(snd, job["dst"], "wav", 0)
            elif op == "ogg":
                write(snd, job["dst"], "ogg", job.get("bitrate", 96000))
            elif op == "mp3":
                write(snd, job["dst"], "mp3", job.get("bitrate", 128000))
            elif op != "probe":
                raise ValueError("op inconnue : %s" % op)
            if op != "probe":
                back = aud.Sound(job["dst"])
                r["dst_specs"] = specs(back)
                r["dst_stats"] = stats(back)
                r["dst_bytes"] = os.path.getsize(job["dst"])
            r["ok"] = True
        except Exception as exc:  # noqa: BLE001 - rapporté tel quel
            fail += 1
            r["ok"] = False
            r["error"] = "%s: %s" % (type(exc).__name__, exc)
            r["trace"] = traceback.format_exc()
        results.append(r)
        print("[fo-son] %s %s %s -> %s" % ("OK    " if r["ok"] else "ECHEC ", job["op"], job["src"],
                                            job.get("dst", "-")), flush=True)
    with open(work["report"], "w", encoding="utf-8") as f:
        json.dump({"aud_version": getattr(aud, "version", "?"), "results": results}, f, indent=1)
    print("[fo-son] BILAN : %d OK, %d ECHEC(S)" % (len(results) - fail, fail), flush=True)
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
