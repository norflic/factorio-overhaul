"""Famille FACTICE du test commun/tests/test_famille.py (lot K0, correction du défaut 1) : emprise 1×1 à tous les âges,
comme un mur, et un trou voulu reconnaissable. Le nom « epoques » est VOLONTAIREMENT celui de gun_e/epoques.py : le
test prouve que le profil de cette famille reçoit CE module, et non celui de la mitrailleuse déjà importé."""
COTE = {0: None, **{e: 1 for e in range(1, 16)}}
TROUS_VOULUS = {(5, "essai"): [(0.0, 0.0, 1.0)]}
MARQUE = "fam_essai"
