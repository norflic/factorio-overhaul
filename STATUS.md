# STATUS COUVERTURE (8/11, avant redemarrage du PC) - branche couverture-boucle
SHA code : 6e6d0d31 (base a0064584 = essai-0666 ; contient f9e07783 deja integre). Ce fichier est commite apres.
MARCHE (hors jeu, verts) : L6 passee en boucle (Cv.loop), chantiers finis cumules + emplacements qui grandissent, plancher Pe.site_room, pose prevue -> mall (Cv.reserve_wants),
  SATURATION totale (Cv.saturation, Ca.decide sans demande nette, electrique seulement, ordre o.saturation, plusieurs modules Cv.sat_modules), journaux [FO-COUVERTURE] et [FO-SATURATION].
  Tests : saturation 36, couverture 32, couverture_runtime 50, portes_extension 29, portes_runtime 24, ai3_capitalisation 319, iag 480, demande 123, rang 94, reserve 88, leviers 86, recharge 60, video_ab 40 + ~25 autres verts.
  Moteur reel : micro-banc 10k ticks (fo-logs/2026-11-08_COUVERTURE/sat-10k-genereux) : lignes [FO-SATURATION] sortent, code 0, aucune erreur.
MANQUE : (1) AUCUNE mesure de couverture a 30/60 min (couverture_mesures.py pret : PYTHONUTF8=1 py -3.9 -B tools/autotest/couverture_mesures.py <benchmark.log.gz> --minutes 30,60) ;
  (2) capi_conf et capi_decide non rendus (capi_decide joue par l'integrateur) ; (3) fer/cuivre electriques passent par le CHAMP (une bande a la fois par minerai) : vitesse de saturation limitee, non levee ;
  (4) lots electrique (centrale en avance, elec_kw) et fonte-dyn (ligne_split, plafond 7 paires/lot) non verifies ensemble.
PROCHAINE ETAPE EXACTE : integrer le SHA, puis UN banc etape1-guide 216000 ticks (graine 20261020) par la file --qui COUVERTURE et lire la couverture des gisements a 30 et 60 min avec couverture_mesures.py
  contre un temoin sans saturation (fo-war-saturation=false). Si la couverture des grands gisements reste < 20 %, regarder le champ (une bande a la fois : migration_champ.lua SLOTS) puis MODULES_PER_ORDER.
