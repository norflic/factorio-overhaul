"""MATIÈRES du kit ateliers (lot DA-ATELIERS, 3/11), COPIE de calcul_o/palettes.py : palette « atelier » ajoutée (un seul
design par bâtiment, sans ère) ; recette de mat.py.
Toutes partagent les clés neutres (noir, acier, acier_clair, riv, caoutchouc, cuivre, chevron, verre…) : un organe se pose
dans n'importe quel âge. lueur() : surface lumineuse TOUJOURS en dégradé (hauteur et bruit), jamais un aplat.
"""
import bpy

import mat as MT


def lueur(S, name, col, force=4.0, main=0.45, grad=None, part=0.55, echelle=9.0, graine=3.0):
    """Lumière en dégradé. grad = (z0, z1, k0, k1) : la force passe de k0 (à z0) à k1 (à z1), position du monde."""
    force *= 0.55                               # essai 1 : les lumières sortaient blanches, sans dégradé
    m = S.mat_emissive(name, col, strength=force, base=tuple(c * 0.08 for c in col), main_scale=main, crust=(echelle, part, graine))
    if grad:
        N, L = m.node_tree.nodes, m.node_tree.links
        k = next(n for n in N if n.name == "fo_emit_strength")
        src = k.inputs[0].links[0].from_socket
        geo = N.new("ShaderNodeNewGeometry")
        sz = N.new("ShaderNodeSeparateXYZ")
        L.new(geo.outputs["Position"], sz.inputs["Vector"])
        r = MT._range(N, L, sz.outputs["Z"], grad[0], grad[1], grad[2], grad[3], True)
        L.new(MT._math(N, L, "MULTIPLY", src, r), k.inputs[0])
    return m


def verre_col(name, fond, reflet, rough=0.1):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    p = N["Principled BSDF"]
    lw = N.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.42
    c = MT._mix(N, L, lw.outputs["Facing"], fond, reflet)
    tc = N.new("ShaderNodeTexCoord")
    nz = MT._range(N, L, MT._bruit(N, L, tc.outputs["Object"], 6.0, 4.0, 0.6, (3.0, 1.0, 2.0), (1.0, 1.0, 0.35)), 0.4, 0.7, 0.6, 1.0)
    L.new(MT._scale(N, L, c, nz), p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = 0.0
    bev = N.new("ShaderNodeBevel")
    bev.inputs["Radius"].default_value = 0.02
    L.new(bev.outputs["Normal"], p.inputs["Normal"])
    m["fo_kind"] = "surface"
    return m


# Ères : couleur de carénage, secondaire, accent, usure, voyant
ERE = {
    "petrole": dict(car=(0.33, 0.25, 0.075), car2=(0.2, 0.16, 0.06), plaque=(0.17, 0.16, 0.14), voy=(1.0, 0.45, 0.06), rouille=(0.2, 0.08, 0.025), cou=0.9, ec=0.85),
    "volcan": dict(car=(0.055, 0.052, 0.058), car2=(0.09, 0.075, 0.07), plaque=(0.12, 0.08, 0.06), voy=(1.0, 0.35, 0.05), rouille=(0.2, 0.07, 0.02), cou=0.8, ec=0.7),
    "elec": dict(car=(0.13, 0.125, 0.12), car2=(0.3, 0.28, 0.23), plaque=(0.17, 0.09, 0.04), voy=(0.25, 0.7, 1.0), rouille=(0.16, 0.08, 0.03), cou=0.7, ec=0.6),
    "hitech": dict(car=(0.3, 0.295, 0.29), car2=(0.155, 0.155, 0.16), plaque=(0.38, 0.37, 0.35), voy=(0.05, 0.42, 1.0), rouille=(0.17, 0.08, 0.035), cou=0.8, ec=0.65),
    "supra": dict(car=(0.019, 0.021, 0.027), car2=(0.05, 0.055, 0.065), plaque=(0.34, 0.37, 0.41), voy=(0.08, 0.86, 1.0), rouille=(0.2, 0.26, 0.3), cou=0.5, ec=0.25),
    "atelier": dict(car=(0.115, 0.11, 0.1), car2=(0.24, 0.225, 0.19), plaque=(0.17, 0.09, 0.04), voy=(1.0, 0.5, 0.08), rouille=(0.2, 0.08, 0.03), cou=0.8, ec=0.65),
    "fusion": dict(car=(0.44, 0.42, 0.375), car2=(0.16, 0.15, 0.135), plaque=(0.42, 0.2, 0.075), voy=(1.0, 0.12, 0.72), rouille=(0.2, 0.12, 0.07), cou=0.45, ec=0.3),
}


def matieres(S, ere):
    e = ERE[ere]
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.16, ra=0.28, ec=e["ec"], nu_k=1.45, ec_col=(0.028, 0.018, 0.008), sans=("verre", "cuivre", "chrome", "noir"))
    sf = MT.surface
    cr = (0.008, 0.0065, 0.004)
    M = {}
    M["car"] = sf("c_car", e["car"], rough=0.42, met=0.25, tole=(0.62, 0.41), joint=0.45, var=0.09, coulures=e["cou"], rouille=e["rouille"],
                  usure=0.75, nu=(0.6, 0.58, 0.54), crasse=0.9, crasse_col=cr, pied=(0.0, 0.8, 0.5), grain=0.1, graine=11)
    M["car_lisse"] = sf("c_car_lisse", e["car"], rough=0.3, met=0.3, coulures=e["cou"] * 0.8, rouille=e["rouille"], usure=0.6, nu=(0.62, 0.6, 0.56),
                        crasse=0.85, crasse_col=cr, grain=0.08, graine=12)
    M["car2"] = sf("c_car2", e["car2"], rough=0.5, met=0.35, tole=(0.33, 0.27), joint=0.5, var=0.1, coulures=e["cou"], rouille=e["rouille"], usure=0.8,
                   nu=(0.5, 0.48, 0.45), crasse=0.9, crasse_col=cr, pied=(0.0, 0.7, 0.55), grain=0.11, graine=13)
    M["plaque"] = sf("c_plaque", e["plaque"], rough=0.45, met=0.5, coulures=e["cou"] * 0.8, rouille=e["rouille"], usure=0.7, crasse=0.8, crasse_col=cr, grain=0.1, graine=14)
    M["noir"] = sf("c_noir", (0.012, 0.0125, 0.014), rough=0.62, met=0.2, usure=0.45, nu=(0.16, 0.16, 0.16), crasse=0.6, crasse_col=(0.003, 0.003, 0.003), grain=0.1, graine=15)
    M["noyau"] = sf("c_noyau", (0.0045, 0.0045, 0.005), rough=0.6, met=0.5, usure=0.1, crasse=0.6, crasse_col=(0.002, 0.002, 0.002), graine=16)
    M["acier"] = sf("c_acier", (0.1, 0.082, 0.065), rough=0.48, met=0.75, usure=0.85, nu=(0.68, 0.65, 0.58), crasse=0.8, crasse_col=cr, coulures=0.5, rouille=(0.18, 0.08, 0.03), graine=17)
    M["acier_clair"] = sf("c_acier_clair", (0.24, 0.235, 0.225), rough=0.36, met=0.85, usure=0.4, crasse=0.65, crasse_col=cr, graine=18)
    M["chrome"] = sf("c_chrome", (0.5, 0.53, 0.57), rough=0.16, met=1.0, usure=0.2, nu=(0.85, 0.87, 0.9), crasse=0.55, crasse_col=(0.015, 0.016, 0.02), grain=0.03, graine=19)
    M["riv"] = sf("c_riv", (0.09, 0.075, 0.05), rough=0.55, met=0.4, usure=0.3, crasse=0.5, graine=20)
    M["caoutchouc"] = sf("c_cao", (0.02, 0.02, 0.019), rough=0.72, met=0.0, usure=0.3, nu=(0.07, 0.07, 0.065), crasse=0.5, crasse_col=cr, graine=21)
    M["cuivre"] = sf("c_cuivre", (0.42, 0.17, 0.06), rough=0.32, met=0.9, coulures=0.7, rouille=(0.05, 0.17, 0.11), usure=0.55, nu=(0.75, 0.42, 0.22), crasse=0.65, crasse_col=cr, graine=22)
    M["or"] = sf("c_or", (0.72, 0.42, 0.1), rough=0.22, met=1.0, usure=0.35, nu=(1.0, 0.75, 0.35), crasse=0.5, crasse_col=(0.05, 0.025, 0.008), grain=0.05, graine=23)
    M["chevron"] = sf("c_chevron", (0.42, 0.26, 0.015), rough=0.5, met=0.2, bandes=(0.14, (0.012, 0.011, 0.01), 0.5), usure=0.8, nu=(0.4, 0.38, 0.35), crasse=0.7, crasse_col=cr, coulures=0.5, graine=24)
    M["jaune"] = sf("c_jaune", (0.42, 0.24, 0.015), rough=0.48, met=0.2, coulures=0.7, rouille=(0.16, 0.06, 0.02), usure=0.8, nu=(0.62, 0.6, 0.56), crasse=0.85, crasse_col=cr, grain=0.1, graine=25)
    M["rouge"] = sf("c_rouge", (0.3, 0.018, 0.012), rough=0.5, met=0.1, usure=0.45, nu=(0.45, 0.25, 0.18), crasse=0.5, crasse_col=cr, graine=26)
    M["bleu"] = sf("c_bleu", (0.02, 0.095, 0.26), rough=0.45, met=0.35, coulures=0.5, rouille=(0.2, 0.26, 0.3), usure=0.65, nu=(0.5, 0.5, 0.5), crasse=0.8, crasse_col=cr, grain=0.1, graine=27)
    M["orange"] = sf("c_orange", (0.5, 0.13, 0.018), rough=0.45, met=0.3, coulures=0.6, rouille=(0.14, 0.05, 0.02), usure=0.65, nu=(0.55, 0.42, 0.3), crasse=0.8, crasse_col=cr, grain=0.1, graine=28)
    M["vert"] = sf("c_vert", (0.012, 0.15, 0.05), rough=0.42, met=0.1, usure=0.4, nu=(0.55, 0.5, 0.2), crasse=0.5, crasse_col=cr, grain=0.14, graine=29)
    M["isolant"] = sf("c_isolant", (0.38, 0.385, 0.38), rough=0.75, met=0.0, tole=(0.3, 0.22), joint=0.55, var=0.08, coulures=0.55, rouille=(0.12, 0.1, 0.08), usure=0.3, crasse=0.75, crasse_col=cr, grain=0.14, graine=30)
    M["givre"] = sf("c_givre", (0.46, 0.56, 0.64), rough=0.8, met=0.0, usure=0.0, crasse=0.5, crasse_col=(0.16, 0.22, 0.28), grain=0.22, graine=31)
    M["beton"] = sf("c_beton", (0.24, 0.225, 0.2), rough=0.9, met=0.0, tole=(1.3, 0.55), joint=0.6, var=0.07, coulures=0.85, rouille=(0.07, 0.06, 0.045), usure=0.5, nu=(0.34, 0.32, 0.29), crasse=0.8, crasse_col=cr, pied=(0.0, 1.0, 0.55), relief=0.3, grain=0.16, graine=32)
    M["ceramique"] = sf("c_ceramique", (0.36, 0.34, 0.29), rough=0.22, met=0.0, usure=0.2, crasse=0.75, crasse_col=(0.05, 0.04, 0.03), grain=0.05, graine=33)
    M["graphite"] = sf("c_graphite", (0.03, 0.03, 0.03), rough=0.65, met=0.1, usure=0.4, nu=(0.22, 0.22, 0.22), crasse=0.5, grain=0.18, graine=34)
    M["rouille"] = sf("c_rouille", (0.17, 0.065, 0.024), rough=0.8, met=0.25, usure=0.45, nu=(0.34, 0.2, 0.12), crasse=0.8, crasse_col=cr, grain=0.2, graine=35)
    M["verre"] = MT.verre("c_verre", col=(0.01, 0.02, 0.03), reflet=(0.16, 0.26, 0.34))
    M["verre_ambre"] = verre_col("c_verre_ambre", (0.05, 0.025, 0.004), (0.55, 0.33, 0.09))
    M["silicium"] = sf("c_silicium", (0.17, 0.19, 0.24), rough=0.14, met=0.9, usure=0.0, crasse=0.3, grain=0.03, graine=36)
    M["voyant"] = lueur(S, "c_voyant", e["voy"], 5.0, 0.5, part=0.3, echelle=30.0)
    M["voyant_v"] = lueur(S, "c_voyant_v", (0.12, 1.0, 0.25), 3.6, 0.5, part=0.3, echelle=30.0)
    M["voyant_r"] = lueur(S, "c_voyant_r", (1.0, 0.1, 0.04), 4.0, 0.5, part=0.3, echelle=30.0)
    M["voyant_o"] = lueur(S, "c_voyant_o", (1.0, 0.55, 0.08), 4.0, 0.5, part=0.3, echelle=30.0)
    return M
