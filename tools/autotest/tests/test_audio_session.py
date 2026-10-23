"""Banc HORS JEU du son de la session visuelle (lot S0, E69) : visual_session.py avec FO_AUDIO.

    python -B tools/autotest/tests/test_audio_session.py

Ne lance pas Factorio. Contrôle, dans une racine JETABLE (dossier temporaire) :
  - le filtre de FO_AUDIO (absente, vide, « 1 », valeurs refusées) ;
  - prepare() : sans son, aucune section [sound] ; avec son, les 9 volumes à 0, relus par audio_silent() ;
  - audio_silent() refuse un config.ini muté (un volume à 0,5 ; une clé absente ; une valeur illisible ; section
    [sound] absente) ;
  - base_cmd() : --disable-audio sans son, absent avec son.
  - FATAL : la ligne réelle du son manquant (E69) arrête la session ; « Loading sounds » et « [Audio] » non.
Code de sortie : 0 si tous les contrôles passent.
"""
import os
import shutil
import sys
import tempfile

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
import visual_session as vs  # noqa: E402

ok = fail = 0


def check(cond, label):
    global ok, fail
    if cond:
        ok += 1
    else:
        fail += 1
    print("%s %s" % ("OK    " if cond else "ECHEC ", label))


def main():
    for env, want in (({}, (False, False)), ({"FO_AUDIO": ""}, (False, False)), ({"FO_AUDIO": "1"}, (True, False)),
                      ({"FO_AUDIO": "0"}, (False, True)), ({"FO_AUDIO": "1 "}, (False, True)),
                      ({"FO_AUDIO": "oui"}, (False, True)), ({"FO_AUDIO": "11"}, (False, True))):
        on, err = vs.audio_from_env(env)
        check((on, err is not None) == want, "FO_AUDIO %s : actif %s, refusee %s" % (env.get("FO_AUDIO", "absente"),
                                                                                  want[0], want[1]))
    base = tempfile.mkdtemp(prefix="fo audio session ")
    try:
        root = os.path.join(base, "racine")
        test = os.path.join(root, "fo-autotest")
        os.makedirs(os.path.join(test, "mods", "fo-autotest"))
        with open(os.path.join(test, "fo-autotest-map.zip"), "w") as f:
            f.write("faux zip\n")
        vis = os.path.join(root, "fo-visual")
        cfg = vs.prepare(root, vis, test, True)[0]
        check("[sound]" not in vs.read_text(cfg) and not vs.audio_silent(cfg)[0],
              "prepare sans son : aucune section [sound] (comportement inchange)")
        cfg = vs.prepare(root, vis, test, True, audio=True)[0]
        silent, detail = vs.audio_silent(cfg)
        vols = vs.audio_volumes(cfg)
        check(silent and len(vols) == 9 and all(vols[k] == "0.000000" for k in vs.AUDIO_KEYS),
              "prepare avec son : 9 volumes a 0 (%s)" % detail)
        txt = vs.read_text(cfg)
        check(txt.startswith("[path]") and "write-data=" in txt, "prepare avec son : section [path] intacte")
        for label, old, new in (("un volume a 0,5", "music-volume=0.000000", "music-volume=0.5"),
                                ("cle absente", "wind-volume=0.000000\n", ""),
                                ("valeur illisible", "master-volume=0.000000", "master-volume=zero"),
                                ("section [sound] absente", "[sound]\n", "[son]\n")):
            with open(cfg, "w", encoding="utf-8") as f:
                f.write(txt.replace(old, new))
            check(not vs.audio_silent(cfg)[0], "mutant refuse : %s (%s)" % (label, vs.audio_silent(cfg)[1]))
        # ligne réelle du journal du mutant (E69, fo-logs\2026-10-24_S0\moteur\06-gunrose-mutant-son-graphique)
        real = ("   1.875 Error SoundLibrary.cpp:56: Missing sound when loading sound library: "
                "__factorio-overhaul__/sound/levels/gun/tir-ere3-2.ogg")
        check(vs.FATAL.search(real) is not None and vs.AUDIO_LOG.search(real) is not None
              and vs.FATAL.search("   1.780 Loading sounds...") is None
              and vs.FATAL.search("   0.275 [Audio] Backend:SDL(default); Driver:wasapi") is None,
              "journal : le son manquant arrete la session (FATAL), le chargement normal non")
        c0 = vs.base_cmd("factorio.exe", "c.ini", "mods", False)
        c1 = vs.base_cmd("factorio.exe", "c.ini", "mods", True)
        check(c0.count("--disable-audio") == 1 and "--disable-audio" not in c1
              and c1 == [x for x in c0 if x != "--disable-audio"],
              "ligne de commande : --disable-audio sans son seulement")
    finally:
        shutil.rmtree(base, ignore_errors=True)
    print("BILAN : %d OK, %d ECHEC(S)" % (ok, fail))
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
