--[[
  Tests hors jeu du lot MOTIFS : base de motifs industriels (shared/team/motifs/catalogue.lua) et sélection (choix.lua).
  Usage, depuis la racine du mod :   lua5.2 tests/motifs_test.lua

  1. catalogue : au moins 25 motifs, 7 familles, identifiants uniques et triés, sources (URL) renseignées, références du DC en
     premier, aucun nom d'objet du jeu écrit dans un motif (rôles seulement), sérialisable, déterministe ;
  2. cohérence de CHAQUE motif (controle.lua) : pièces sans chevauchement, période ≥ emprise utile, bras (prise et dépôt sur la
     pièce annoncée), tapis (suite, souterrains appariés, entrées et sorties déclarées), répartiteurs, fluides sans mélange,
     poteaux (aire et fil, tuile du milieu autonome), liens, chaînes ;
  3. orientations : 8 orientations de chaque motif, mêmes cellules, bras toujours sur la bonne pièce, aller-retour identique ;
  4. débits : formules à la main (fonte 4 fours par tuile, 3 câbles pour 2 circuits limités par les bras, voie de tapis) ;
  5. équilibreurs : suivi de flux (chaque entrée se répartit en parts égales sur toutes les sorties, 4-4 compris) ;
  6. sélection sur plus de 10 terrains (rectangle libre, obstacles, carte de tuiles libres, côté d'entrée, tailles de machine,
     technologies, poteau, jetons, tapis saturé, zone trop petite, bus, équilibreurs, champ de foreuses) ;
  7. coût de la sélection en instructions (debug.sethook), au plus 300 000 ;
  8. MUTANTS : défauts injectés dans les données, dans le contrôle, dans les transformations et dans la sélection : chacun est refusé.
]]

package.path = "./?.lua;" .. package.path
local D = require("shared.team.motifs.dsl")
local Cat = require("shared.team.motifs.catalogue")
local Cp = require("shared.team.motifs.compile")
local K = require("shared.team.motifs.controle")
local Ch = require("shared.team.motifs.choix")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if quiet then
    if not cond then failures = failures + 1 end
    return cond
  end
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end
local N, E, S, W = 0, 2, 4, 6

---------------------------------------------------------------------------------------------------
section("1. Catalogue")
---------------------------------------------------------------------------------------------------
check(#Cat.erreurs == 0, "aucune erreur de compilation : " .. table.concat(Cat.erreurs, " ; "))
check(#Cat.MOTIFS >= 25, "au moins 25 motifs (" .. #Cat.MOTIFS .. ")")
local compte = Cat.compte()
for _, f in ipairs(Cat.FAMILLES) do check((compte[f] or 0) >= 1, "famille « " .. f .. " » non vide") end
do
  local prev, doubles = "", false
  for _, m in ipairs(Cat.MOTIFS) do
    if m.id <= prev then doubles = true end
    prev = m.id
  end
  check(not doubles, "catalogue trié par identifiant, sans doublon")
end
local fam_txt = {}
for _, f in ipairs(Cat.FAMILLES) do fam_txt[#fam_txt + 1] = f .. "=" .. (compte[f] or 0) end
print("  [MOTIFS] " .. #Cat.MOTIFS .. " motifs : " .. table.concat(fam_txt, ", "))

-- les 4 références du DC
local REFS = { ["Fonderie.png"] = "fonte-2x2-double-central", ["Mall1.png"] = "asm-grille-3-directe", ["Patern1.png"] = "asm-2e-1s",
  ["Patern_Mall2.png"] = "asm-cable-circuit-3-2-double" }
for ref, id in pairs(REFS) do
  local m = Cat.get(id)
  check(m and m.origine == "ref_dc" and m.ref == ref, "référence du DC " .. ref .. " transcrite par " .. id)
end

-- classification : n entrées, m sorties, modularité, machines par tuile (demande du DC)
do
  local CLASSES = {
    ["fonte-2x2-double-central"] = { 1, 2, "serie", 4 }, ["asm-2e-1s"] = { 2, 1, "serie", 1 }, ["asm-grille-3-directe"] = { 2, 1, "serie", 3 },
    ["asm-cable-circuit-3-2-double"] = { 3, 1, "serie", 10 }, ["equilibreur-4-4"] = { 4, 4, "unique", 0 },
    ["chimie-rangee-2f-1e-1s"] = { 3, 1, "serie", 1 }, ["raffinerie-rangee-base"] = { 1, 1, "serie", 1 },
    ["bus-piquage-voie-exterieure"] = { 4, 5, "unique", 0 }, ["foreuses-2xN-tapis-central"] = { 0, 1, "serie", 4 },
  }
  for id, c in pairs(CLASSES) do
    local d = Cat.get(id).derive
    check(d.n_entrees == c[1] and d.m_sorties == c[2] and d.modularite == c[3] and d.machines == c[4],
      string.format("%s classé %d entrées, %d sorties, %s, %d machines (lu : %d, %d, %s, %d)", id, c[1], c[2], c[3], c[4], d.n_entrees, d.m_sorties, d.modularite, d.machines))
  end
end

-- contraintes : place minimale et rangées qui doivent rester droites
do
  local m = Cat.get("fonte-2x2-double-central")
  check(m.derive.place_min.l == 4 and m.derive.place_min.h == 11, "place minimale de la colonne du DC : une tuile 4 × 11")
  local d = m.derive.droits
  local ok = #d == 3
  for _, x in ipairs(d) do
    if not ((x.role == "tapis_entree" and x.k == 1 and x.y == 5) or (x.role == "tapis_sortie" and x.k == 1 and x.y == 0) or (x.role == "tapis_sortie" and x.k == 2 and x.y == 10)) then ok = false end
  end
  check(ok, "rangées droites de la colonne du DC : entrée 1 (rangée 5), sorties 1 et 2 (rangées 0 et 10)")
  local c = Cat.get("chimie-rangee-2f-sortie")
  check(c.derive.place_min.l == 8 and c.derive.place_min.h == 7, "place minimale d'une rangée à 2 fluides : tête 2 + tuile 4 + queue 2 = 8 × 7")
  check(#Cat.get("equilibreur-4-4").derive.droits == 0, "l'équilibreur n'impose aucune rangée droite sur toute sa largeur")
end

for _, m in ipairs(Cat.MOTIFS) do
  check(type(m.source) == "table" and #m.source >= 1 and m.source[1]:match("^https://"), m.id .. " : source (URL) renseignée")
  check(m.nom_fr and m.nom_en, m.id .. " : noms FR et EN")
  check(m.periode >= 1 and m.h >= 1, m.id .. " : emprise")
  local n_in, n_out = #(m.entrees or {}), #(m.sorties or {})
  check(n_in >= 0 and n_out >= 0, m.id .. " : entrées et sorties comptées")
end

-- aucun nom d'objet du jeu dans les champs de structure
local Mod = require("shared.team.modules")
local INTERDITS = {}
for name in pairs(Mod.BASE) do INTERDITS[name] = true end
for _, n in ipairs({ "iron-plate", "copper-plate", "steel-plate", "stone-brick", "iron-ore", "copper-ore", "coal", "stone", "iron-gear-wheel",
  "copper-cable", "electronic-circuit", "advanced-circuit", "plastic-bar", "sulfur", "petroleum-gas", "crude-oil", "water", "steam",
  "transport-belt", "fast-transport-belt", "splitter", "underground-belt", "electric-furnace", "assembling-machine-3", "pumpjack",
  "chemical-plant", "oil-refinery", "lab", "boiler", "pipe", "pipe-to-ground", "wooden-chest" }) do INTERDITS[n] = true end
local function scan(v, path, bad)
  if type(v) == "string" then
    if INTERDITS[v] then bad[#bad + 1] = path .. " = " .. v end
  elseif type(v) == "table" then
    for k, x in pairs(v) do
      if type(k) == "string" and INTERDITS[k] then bad[#bad + 1] = path .. "." .. k .. " (clé)" end
      scan(x, path .. "." .. tostring(k), bad)
    end
  end
end
local function a_des_fonctions(v, seen)
  seen = seen or {}
  if type(v) == "function" then return true end
  if type(v) ~= "table" or seen[v] then return false end
  seen[v] = true
  for _, x in pairs(v) do if a_des_fonctions(x, seen) then return true end end
  return false
end
for _, m in ipairs(Cat.MOTIFS) do
  local bad = {}
  for _, champ in ipairs({ "pieces", "entrees", "sorties", "liens", "chaines", "fluides", "derive", "roles", "usages", "famille", "capacite", "tete", "queue" }) do
    if m[champ] ~= nil then scan(m[champ], champ, bad) end
  end
  check(#bad == 0, m.id .. " : aucun nom d'objet du jeu dans les pièces et déclarations (" .. (bad[1] or "") .. ")")
  -- le texte libre ne cite aucun nom de prototype (mots à tiret ou noms exacts)
  local texte = (m.nom_fr or "") .. " " .. (m.note_fr or "") .. " " .. m.id
  local cite
  for mot in texte:gmatch("[%a][%a%d_]*%-?[%a%d_%-]*") do
    if INTERDITS[mot] and mot ~= "lab" and mot ~= "coal" and mot ~= "water" and mot ~= "stone" and mot ~= "pipe" then cite = mot end
  end
  check(not cite, m.id .. " : texte libre sans nom de prototype (" .. tostring(cite) .. ")")
  check(not a_des_fonctions(m), m.id .. " : aucune fonction dans le motif (sérialisable)")
  for _, p in ipairs(m.pieces) do
    check(D.ROLES[p.role] ~= nil, m.id .. " : rôle connu " .. tostring(p.role))
  end
end

---------------------------------------------------------------------------------------------------
section("2. Cohérence de chaque motif (contrôle)")
---------------------------------------------------------------------------------------------------
for _, m in ipairs(Cat.MOTIFS) do
  local errs = K.verifier(m)
  check(#errs == 0, m.id .. " cohérent : " .. (errs[1] or ""))
  if #errs > 1 and not quiet then for i = 2, math.min(#errs, 4) do print("    " .. errs[i]) end end
end

---------------------------------------------------------------------------------------------------
-- 3. Orientations (batterie rejouable sur un module D modifié : mutants)
---------------------------------------------------------------------------------------------------
local function batterie_orientation(Dm)
  local ok_all = true
  local function ck(c, msg) if not c then ok_all = false; if not quiet then print("  ECHEC : " .. msg) end else if not quiet then passes = passes + 1 end end end
  for _, m in ipairs(Cat.MOTIFS) do
    local n = m.repetable and 2 or 1
    local base = Dm.instancier(m, n, { rot = 0, miroir = false })
    local cells0 = 0
    for _, p in ipairs(base.pieces) do cells0 = cells0 + p.w * p.h end
    for _, T in ipairs(Dm.ORIENTATIONS) do
      local inst = Dm.instancier(m, n, T)
      local L, H = Dm.longueur(m, n), m.h
      local el, eh = Dm.dims(L, H, T)
      ck(inst.l == el and inst.h == eh, m.id .. " " .. Dm.nom_orientation(T) .. " : dimensions")
      local occ, over = Dm.occupation(inst.pieces)
      ck(#over == 0, m.id .. " " .. Dm.nom_orientation(T) .. " : sans chevauchement")
      local cells, hors = 0, 0
      for _, p in ipairs(inst.pieces) do
        cells = cells + p.w * p.h
        if p.x < 0 or p.y < 0 or p.x + p.w > inst.l or p.y + p.h > inst.h then hors = hors + 1 end
      end
      ck(cells == cells0 and hors == 0, m.id .. " " .. Dm.nom_orientation(T) .. " : mêmes cellules, toutes dans l'emprise")
      -- bras : prise et dépôt sur la pièce annoncée, quelle que soit l'orientation
      local mauvais = 0
      for _, p in ipairs(inst.pieces) do
        local r = D.ROLES[p.role]
        if r and r.classe == "bras" then
          local prise, depot = Cp.prise_depot(p)
          local a = inst.pieces[occ[Dm.cle(prise[1], prise[2])] or 0]
          local b = inst.pieces[occ[Dm.cle(depot[1], depot[2])] or 0]
          if not (Cp.correspond(a, p.prend) and Cp.correspond(b, p.depose)) then mauvais = mauvais + 1 end
        end
      end
      ck(mauvais == 0, m.id .. " " .. Dm.nom_orientation(T) .. " : " .. mauvais .. " bras hors de leur cible")
      -- tapis : direction de chaque cellule de bord déclarée = côté transformé
      for _, port in ipairs(inst.ports) do
        local ok = port.x >= 0 and port.y >= 0 and port.x < inst.l and port.y < inst.h
        ck(ok, m.id .. " " .. Dm.nom_orientation(T) .. " : port dans l'emprise")
      end
    end
    -- aller-retour : quatre quarts de tour rendent l'instance de départ
    local a = Dm.instancier(m, n, { rot = 0, miroir = false })
    local sig = {}
    for _, p in ipairs(a.pieces) do sig[#sig + 1] = string.format("%s:%d,%d,%d,%d,%s", p.role, p.x, p.y, p.w, p.h, tostring(p.dir)) end
    table.sort(sig)
    -- r0 → r2 → r4 → r6 → r0 est l'identité par construction ; ici : r2 puis r6 sur l'emprise tournée
    local t2 = Dm.instancier(m, n, { rot = 2, miroir = false })
    local sig2 = {}
    for _, p in ipairs(t2.pieces) do
      -- on retourne par la rotation inverse (r6) appliquée à chaque pièce
      local x, y, w, h = Dm.rect_t(p.x, p.y, p.w, p.h, t2.l, t2.h, { rot = 6, miroir = false })
      sig2[#sig2 + 1] = string.format("%s:%d,%d,%d,%d,%s", p.role, x, y, w, h, tostring(p.dir and Dm.dir_t(p.dir, { rot = 6, miroir = false }) or nil))
    end
    table.sort(sig2)
    ck(table.concat(sig) == table.concat(sig2), m.id .. " : r2 puis r6 rend l'instance de départ")
    -- le miroir est une involution
    local mm = Dm.instancier(m, n, { rot = 0, miroir = true })
    local sig3 = {}
    for _, p in ipairs(mm.pieces) do
      local x, y, w, h = Dm.rect_t(p.x, p.y, p.w, p.h, mm.l, mm.h, { rot = 0, miroir = true })
      sig3[#sig3 + 1] = string.format("%s:%d,%d,%d,%d,%s", p.role, x, y, w, h, tostring(p.dir and Dm.dir_t(p.dir, { rot = 0, miroir = true }) or nil))
    end
    table.sort(sig3)
    ck(table.concat(sig) == table.concat(sig3), m.id .. " : le miroir deux fois rend l'instance de départ")
  end
  return ok_all
end
section("3. Orientations")
check(batterie_orientation(D), "toutes les orientations de tous les motifs sont cohérentes")

---------------------------------------------------------------------------------------------------
section("4. Débits (formules à la main)")
---------------------------------------------------------------------------------------------------
local function near(a, b, tol) return math.abs(a - b) <= (tol or 1e-6) end
local CTX_PIERRE = {
  vitesse = { machine_fonte = 1 }, taille = { machine_fonte = 2 },
  recettes = { principal = { temps = 3.2, entrees = { A = 1 }, sorties = { P = 1 } } },
  combustible = { machine_fonte = 90 / 4000 },
  bras = { bras = 0.83, bras_long = 1.15 }, tapis_voie = 7.5, poteau = { supply = 2.5, fil = 7.5 },
}
do
  local m = Cat.get("fonte-2x2-double-central")
  local d = Ch.debit(m, CTX_PIERRE)
  check(d and near(d.sortie.P, 4 / 3.2), "colonne de référence du DC : 4 fours de pierre par tuile = 1,25 plaque/s (" .. tostring(d and d.sortie.P) .. ")")
  check(d and d.util.principal == 1, "les bras suffisent (un bras par four)")
  -- minerai : 4 fours × 0,3125 = 1,25/s sur UNE voie de 7,5 → 6 tuiles ; sortie 2 fours par tapis, une voie : 6 tuiles
  check(d and d.n_tapis == 6, "voie de minerai de 7,5/s : 6 tuiles de 4 fours de pierre (" .. tostring(d and d.n_tapis) .. ")")
  local ctx2 = { vitesse = { machine_fonte = 2 }, taille = { machine_fonte = 2 }, recettes = CTX_PIERRE.recettes,
    combustible = CTX_PIERRE.combustible, bras = CTX_PIERRE.bras, tapis_voie = 7.5, poteau = CTX_PIERRE.poteau }
  local d2 = Ch.debit(m, ctx2)
  check(d2 and d2.n_tapis == 3, "four d'acier (vitesse 2) : 12 fours par voie de minerai = 3 tuiles (" .. tostring(d2 and d2.n_tapis) .. ")")
  check(d2 and near(d2.util.principal, 0.83 * 0.85 * 0.9 / (0.625 + 90 / 4000)), "four d'acier : le bras (0,83 × 0,85 × 0,9) limite à " .. tostring(d2 and d2.util.principal))
  local ctx3 = { vitesse = { machine_fonte = { [2] = 2, [3] = 2 } }, recettes = CTX_PIERRE.recettes, combustible = { machine_fonte = { [2] = 0.0225, [3] = 0 } },
    bras = { bras = 2.31, bras_long = 1.15 }, tapis_voie = 7.5 }
  local d3 = Ch.debit(Cat.get("fonte-3x3-double-central"), ctx3)
  check(d3 and near(d3.sortie.P, 4 * 2 / 3.2) and d3.n_tapis == 6, "four électrique 3×3 par tuile : 2 fours × 2 rangées × 0,625 = 2,5 plaques/s, 6 tuiles pour les deux voies de minerai")
end
do
  local m = Cat.get("asm-cable-circuit-3-2-double")
  local rec = { cable = { temps = 0.5, entrees = { A = 1 }, sorties = { M = 2 } }, circ = { temps = 0.5, entrees = { M = 3, B = 1 }, sorties = { P = 1 } } }
  local ctx = { vitesse = { machine_asm = 0.75 }, recettes = rec, bras = { bras = 0.83, bras_long = 1.15 }, tapis_voie = 7.5, poteau = { supply = 2.5, fil = 7.5 } }
  local d = Ch.debit(m, ctx)
  -- 6 bras de liaison par face : 6 × 0,83 × 0,9 = 4,482 contre 2 machines × 1,5 × 3 = 9 câbles/s
  check(d and near(d.util.circ, 6 * 0.83 * 0.9 / 9, 1e-6), "circuits : les bras de liaison (bras de base) limitent la machine aval à " .. tostring(d and d.util.circ))
  check(d and d.util.cable <= d.util.circ * 1.0001 + 1e-9, "circuits : la machine amont ne produit que ce que l'aval consomme")
  ctx.bras = { bras = 2.31, bras_long = 2.31 }
  local d2 = Ch.debit(m, ctx)
  check(d2 and d2.util.circ > 0.999, "avec des bras rapides le rapport 3:2 s'équilibre (" .. tostring(d2 and d2.util.circ) .. ")")
  check(d2 and near(d2.sortie.P, 4 * 1.5 * d2.util.circ), "sortie = 4 machines de circuits × 1,5 fabrication/s × utilisation")
  -- recette manquante pour un groupe : refus net, jamais de repli silencieux
  local d3, why = Ch.debit(m, { vitesse = ctx.vitesse, recettes = { principal = rec.cable }, bras = ctx.bras })
  check(d3 == nil and why == "recette_manquante:cable" or why == "recette_manquante:circ", "groupe sans recette refusé (" .. tostring(why) .. ")")
end

do
  -- ratios usuels CALCULÉS (vitesses égales ; les nombres sont ceux des recettes, jamais écrits dans le catalogue)
  local engr = { temps = 0.5, vitesse = 0.75, sorties = { M = 1 } }
  local pack = { temps = 5, vitesse = 0.75, entrees = { M = 1 } }
  check(near(Ch.rapport(engr, pack, "M"), 0.1), "ratio engrenage → pack rouge : 1 machine d'engrenages pour 10 de packs (" .. tostring(Ch.rapport(engr, pack, "M")) .. ")")
  local cab = { temps = 0.5, vitesse = 0.75, sorties = { M = 2 } }
  local cir = { temps = 0.5, vitesse = 0.75, entrees = { M = 3 } }
  check(near(Ch.rapport(cab, cir, "M"), 1.5), "ratio câble → circuit : 3 pour 2 (" .. tostring(Ch.rapport(cab, cir, "M")) .. ")")
  local m32 = Cat.get("asm-cable-circuit-3-2-double")
  check(near(Ch.rapport_motif(m32), 1.5), "le motif des circuits réalise 3:2 (6 machines de câble pour 4 de circuits)")
  local pla = { temps = 3.2, vitesse = 1, sorties = { M = 1 } }
  local aci = { temps = 16, vitesse = 1, entrees = { M = 5 } }
  check(near(Ch.rapport(pla, aci, "M"), 1), "ratio plaque → acier à vitesses égales : 1 pour 1 (" .. tostring(Ch.rapport(pla, aci, "M")) .. ")")
  check(near(Ch.rapport_motif(Cat.get("fonte-chaine-directe-3x3")), 1), "la chaîne directe de fours réalise 1:1")
  check(near(Ch.rapport_motif(Cat.get("asm-chaine-1-2")), 0.5), "la chaîne 1 → 2 réalise 1:2")
  check(Ch.rapport(pla, pack, "Z") == nil, "jeton absent : pas de rapport")
  check(Ch.bras_necessaires(1.5, 0.83, true) == 3 and Ch.bras_necessaires(0.3, 0.83, true) == 1, "bras nécessaires : 1,5/s demandent 3 bras de base sur un tapis, 0,3/s un seul")
  check(Ch.machines_par_voie(0.625, 7.5) == 12 and Ch.machines_par_voie(0.3125, 7.5) == 24, "une voie de 7,5/s nourrit 12 fours d'acier ou 24 fours de pierre")
end

local function batterie_debut(Chx)
  -- motifs du début de partie : débits calculés d'après les recettes, producteurs de tête, chaînes en série, bornes
  local function selection(extra)
    local r = { zone = { x = 0, y = 0, l = 120, h = 40 } }
    for k, v in pairs(extra) do r[k] = v end
    return Chx.choisir(r)
  end
  -- centrale : 1 chaudière pour 2 machines à vapeur, 1,8 MW par tuile, une pompe pour 20 chaudières
  local cv = { vitesse = { machine_vapeur = 1, chaudiere = 1 }, bras = { bras = 0.59 }, tapis_voie = 7.5, combustible = { chaudiere = 0.45 },
    recettes = { chaudiere = { temps = 1, entrees = {}, sorties = { S = 60 } }, vapeur = { temps = 1, entrees = { S = 30 }, sorties = { E = 900 } } } }
  local d = Chx.debit(Cat.get("centrale-vapeur-rangee"), cv)
  check(d and near(d.sortie.E, 1800), "centrale : une chaudière et deux machines à vapeur = 1 800 kW par tuile (" .. tostring(d and d.sortie.E) .. ")")
  check(near(Chx.rapport_motif(Cat.get("centrale-vapeur-rangee")), 0.5), "centrale : rapport chaudière : machine à vapeur = 1 : 2")
  local r = selection({ famille = "energie", demande = { jeton = "E", debit = 9000 }, ctx = cv })
  check(r.motif == "centrale-vapeur-rangee" and r.n == 5 and r.couvre, "centrale : 9 MW = 5 tuiles (" .. tostring(r.motif) .. " " .. tostring(r.n) .. ")")
  local r2 = selection({ famille = "energie", demande = { jeton = "E", debit = 60000 }, ctx = cv })
  check(r2.n == 20 and not r2.couvre and r2.limite == "borne", "centrale : au plus 20 chaudières par pompe (" .. tostring(r2.n) .. " " .. tostring(r2.limite) .. ")")
  -- laboratoires
  local cl = { vitesse = { machine_labo = 1 }, recettes = { principal = { temps = 30, entrees = { A = 1, B = 1 }, sorties = { R = 1 } } },
    bras = { bras = 2.31 }, tapis_voie = 7.5, poteau = { supply = 2.5, fil = 7.5 } }
  local rl = selection({ famille = "labo", demande = { jeton = "R", debit = 0.5 }, ctx = cl })
  check(rl.motif == "labo-rangee-miroir" and rl.n == 8 and rl.couvre, "labos : 0,5 unité/s = 8 tuiles de 2 laboratoires, deux faces (" .. tostring(rl.motif) .. " " .. tostring(rl.n) .. ")")
  local cl2 = { vitesse = cl.vitesse, recettes = cl.recettes, bras = { bras = 0.83 }, tapis_voie = 7.5, poteau = cl.poteau }
  local rc = selection({ famille = "labo", usage = "chaine", demande = { jeton = "R", debit = 2 }, ctx = cl2 })
  check(rc.motif == "labo-chaine-bras" and rc.n == 9 and not rc.couvre and rc.limite == "tapis", "labos en chaîne : le premier bras (0,83) ne porte que 9 laboratoires (" .. tostring(rc.n) .. " " .. tostring(rc.limite) .. ")")
  -- packs rouges : 1 assembleuse d'engrenages pour 10 de packs (calculé)
  local cr = { vitesse = { machine_asm = 0.75 }, bras = { bras = 2.31, bras_long = 1.15 }, tapis_voie = 7.5, poteau = { supply = 2.5, fil = 7.5 },
    recettes = { engrenage = { temps = 0.5, entrees = { C = 2 }, sorties = { B = 1 } }, pack = { temps = 5, entrees = { A = 1, B = 1 }, sorties = { P = 1 } } } }
  local rr = selection({ famille = "science", usage = "packs-rouges", demande = { jeton = "P", debit = 1.2 }, ctx = cr })
  check(rr.motif == "packs-rouges-rangee" and rr.n == 8 and rr.couvre, "packs rouges : 1,2 pack/s = 8 tuiles (" .. tostring(rr.motif) .. " " .. tostring(rr.n) .. ")")
  local rr2 = selection({ famille = "science", usage = "packs-rouges", demande = { jeton = "P", debit = 3 }, ctx = cr })
  check(rr2.n == 10 and not rr2.couvre and rr2.limite == "tapis" and near(rr2.debit.total, 1.5), "packs rouges : la machine d'engrenages sert 10 tuiles au plus (" .. tostring(rr2.n) .. ", " .. tostring(rr2.debit and rr2.debit.total) .. ")")
  local srv = Cat.get("packs-rouges-rangee").derive
  check(srv.groupes.engrenage.fixe == true and srv.groupes.pack.fixe == nil and srv.groupes.pack.n == 1, "packs rouges : le groupe d'engrenages est fixe (tête), celui des packs compte par tuile")
  -- packs verts : 1 machine de bras pour 12 de packs, 1 machine de convoyeurs pour 24
  local cg = { vitesse = { machine_asm = 0.75 }, bras = { bras = 2.31, bras_long = 2.31 }, tapis_voie = 7.5, poteau = { supply = 2.5, fil = 7.5 },
    recettes = { bras = { temps = 0.5, entrees = { D = 1, E = 1, F = 1 }, sorties = { B = 1 } }, tapis = { temps = 0.5, entrees = { D = 1, E = 1 }, sorties = { C = 2 } },
      pack = { temps = 6, entrees = { B = 1, C = 1 }, sorties = { P = 1 } } } }
  local rg = selection({ famille = "science", usage = "packs-verts", demande = { jeton = "P", debit = 5 }, ctx = cg })
  check(rg.motif == "packs-verts-rangee" and rg.n == 12 and not rg.couvre and rg.limite == "tapis", "packs verts : 12 tuiles au plus, bornées par les bras (" .. tostring(rg.n) .. " " .. tostring(rg.limite) .. ")")
  check(near(Chx.rapport({ temps = 0.5, vitesse = 0.75, sorties = { M = 1 } }, { temps = 6, vitesse = 0.75, entrees = { M = 1 } }, "M"), 1 / 12), "ratio bras → pack vert : 1 pour 12")
  check(near(Chx.rapport({ temps = 0.5, vitesse = 0.75, sorties = { M = 2 } }, { temps = 6, vitesse = 0.75, entrees = { M = 1 } }, "M"), 1 / 24), "ratio convoyeur → pack vert : 1 pour 24")
  -- foreuses de charbon en boucle
  local cf = { vitesse = { foreuse = 0.25 }, taille = { foreuse = 2 }, recettes = { principal = { temps = 1, sorties = { P = 1 } } }, combustible = { foreuse = 0.0375 },
    bras = { bras = 0.59 }, tapis_voie = 7.5, energie = false }
  local rf = selection({ famille = "mine", usage = "bootstrap", demande = { jeton = "P", debit = 3 }, ctx = cf })
  check(rf.motif == "foreuses-boucle-charbon" and rf.n == 6 and rf.couvre, "boucle de charbon : 3/s = 6 tuiles de 2 foreuses (" .. tostring(rf.motif) .. " " .. tostring(rf.n) .. ")")
  local cf2 = { vitesse = cf.vitesse, taille = cf.taille, recettes = cf.recettes, bras = cf.bras, tapis_voie = 7.5, energie = false }
  local rf2 = selection({ famille = "mine", usage = "bootstrap", demande = { jeton = "P", debit = 3 }, ctx = cf2 })
  check(rf2.motif == "foreuses-boucle-charbon", "boucle de charbon : sans combustible dans le contexte la tuile est acceptée aussi")
  -- usages du mall du début
  check(Chx.choisir({ zone = { x = 0, y = 0, l = 40, h = 20 }, famille = "asm", usage = "engrenage", demande = { jeton = "P", debit = 1 },
    ctx = { vitesse = { machine_asm = 0.75 }, recettes = { principal = { temps = 0.5, entrees = { A = 2 }, sorties = { P = 1 } } }, bras = { bras = 2.31 }, tapis_voie = 7.5,
      poteau = { supply = 2.5, fil = 7.5 } } }).motif == "asm-1e-1s", "mall du début : les engrenages (1 entrée) par asm-1e-1s")
end
batterie_debut(Ch)

---------------------------------------------------------------------------------------------------
section("5. Équilibreurs : suivi de flux")
---------------------------------------------------------------------------------------------------
-- flux d'une unité sur chaque sous-ensemble d'entrées ; renvoie les sorties par numéro
local function suivi(inst, entrees_actives)
  local occ = D.occupation(inst.pieces)
  local function at(x, y) return inst.pieces[occ[D.cle(x, y)] or 0] end
  local inject, cells = {}, {}
  for i, p in ipairs(inst.pieces) do
    if D.est_tapis(p.role) then
      for _, c in ipairs(D.cellules(p)) do cells[#cells + 1] = { c[1], c[2], p } end
      if p.role == "tapis_entree" and entrees_actives[p.k] then inject[D.cle(p.x, p.y)] = 1 end
    end
  end
  local function suite(p, x, y)
    if p.role == "souterrain_entree" then
      local v = D.DV[p.dir]
      for i = 1, 6 do
        local q = at(x + v[1] * i, y + v[2] * i)
        if q and q.role == "souterrain_sortie" and q.dir == p.dir then return x + v[1] * i, y + v[2] * i end
      end
      return nil
    end
    local v = D.DV[p.dir]
    return x + v[1], y + v[2]
  end
  local arrive = {}
  for _ = 1, 80 do
    local nouveau = {}
    for k, q in pairs(inject) do nouveau[k] = q end
    for _, c in ipairs(cells) do
      local x, y, p = c[1], c[2], c[3]
      local out
      if p.role == "repartiteur" then
        local tot = 0
        for _, c2 in ipairs(D.cellules(p)) do tot = tot + (arrive[D.cle(c2[1], c2[2])] or 0) end
        out = tot / 2
      else
        out = arrive[D.cle(x, y)] or 0
      end
      if out > 0 then
        local nx, ny = suite(p, x, y)
        if nx then
          local k = D.cle(nx, ny)
          nouveau[k] = (nouveau[k] or 0) + out
        end
      end
    end
    arrive = nouveau
  end
  local sorties = {}
  for _, p in ipairs(inst.pieces) do
    if p.role == "tapis_sortie" then sorties[p.k] = arrive[D.cle(p.x, p.y)] or 0 end
  end
  return sorties
end

local function equilibre(m)
  local inst = D.instancier(m, 1, { rot = 0, miroir = false })
  local ne, ns = m.capacite.entrees, m.capacite.sorties
  local ok = true
  for masque = 1, (2 ^ ne) - 1 do
    local act, total = {}, 0
    for k = 1, ne do if math.floor(masque / 2 ^ (k - 1)) % 2 == 1 then act[k] = true; total = total + 1 end end
    local s = suivi(inst, act)
    for k = 1, ns do
      if not near(s[k] or -1, total / ns, 1e-9) then ok = false end
    end
  end
  return ok
end
for _, id in ipairs({ "equilibreur-1-2", "equilibreur-2-2", "equilibreur-1-4", "equilibreur-2-4", "equilibreur-4-4" }) do
  local m = Cat.get(id)
  check(m ~= nil and equilibre(m), id .. " : chaque combinaison d'entrées se répartit en parts égales sur toutes les sorties")
end
do
  local m = Cat.get("bus-piquage-voie-exterieure")
  local inst = D.instancier(m, 1, { rot = 0, miroir = false })
  local s = suivi(inst, { [4] = true })
  check(near(s[4] or -1, 0.5, 1e-9) and near(s[5] or -1, 0.5, 1e-9), "piquage : la 4e voie se partage moitié bus, moitié branche")
  local s1 = suivi(inst, { [1] = true })
  check(near(s1[1] or -1, 1, 1e-9) and near(s1[5] or -1, 0, 1e-9), "piquage : les trois autres voies passent droit")
end

---------------------------------------------------------------------------------------------------
-- 6. Sélection sur des terrains
---------------------------------------------------------------------------------------------------
local function ctx_pierre()
  return {
    vitesse = { machine_fonte = 1 }, taille = { machine_fonte = 2 },
    recettes = { principal = { temps = 3.2, entrees = { A = 1 }, sorties = { P = 1 } } },
    combustible = { machine_fonte = 90 / 4000 },
    bras = { bras = 0.83, bras_long = 1.15 }, tapis_voie = 7.5, poteau = { supply = 2.5, fil = 7.5 },
  }
end
local function ctx_asm(extra)
  local c = {
    vitesse = { machine_asm = 0.75 }, recettes = { principal = { temps = 0.5, entrees = { A = 1, B = 1 }, sorties = { P = 1 } } },
    bras = { bras = 2.31, bras_long = 1.15 }, tapis_voie = 7.5, poteau = { supply = 2.5, fil = 7.5 },
  }
  for k, v in pairs(extra or {}) do c[k] = v end
  return c
end
local function ecarte_cause(res, id)
  for _, e in ipairs(res.ecartes) do if e.id == id then return e.cause end end
  return nil
end

local function terrains(Chx)
  local R = {}
  local function t(nom, fn) R[#R + 1] = { nom = nom, fn = fn } end

  t("T1 rectangle libre 30×12 : la colonne double du DC, 5 tuiles pour 6 plaques/s", function()
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 30, h = 12 }, famille = "fonte", demande = { jeton = "P", debit = 6 }, ctx = ctx_pierre() })
    check(r.motif == "fonte-2x2-double-central", "T1 motif : " .. tostring(r.motif))
    check(r.n == 5 and r.couvre and r.l == 20 and r.h == 11 and r.x == 0 and r.y == 0, "T1 n=5 couvre, emprise 20×11 en (0, 0) : " .. tostring(r.n) .. " " .. tostring(r.l) .. "×" .. tostring(r.h))
    check(r.debit and r.debit.total >= 6, "T1 débit total ≥ demande (" .. tostring(r.debit and r.debit.total) .. ")")
    check(r.orient.rot == 0 and not r.orient.miroir, "T1 orientation canonique")
    check(ecarte_cause(r, "asm-1e-1s") == "hors_famille" and ecarte_cause(r, "fonte-3x3-simple") == "taille:machine_fonte=3", "T1 causes d'écart : famille et taille")
    check(ecarte_cause(r, "fonte-2x2-simple") and ecarte_cause(r, "fonte-2x2-simple"):match("^moins_bon"), "T1 cause d'un motif valable mais moins bon")
  end)

  t("T2 zone trop basse pour deux rangées : la rangée simple, demande non couverte", function()
    local r = Chx.choisir({ zone = { x = 5, y = 3, l = 30, h = 7 }, famille = "fonte", demande = { jeton = "P", debit = 6 }, ctx = ctx_pierre() })
    check(r.motif == "fonte-2x2-simple", "T2 motif : " .. tostring(r.motif))
    check(r.n == 7 and not r.couvre and r.limite == "place", "T2 7 tuiles, ne couvre pas, limite = place : " .. tostring(r.n) .. " " .. tostring(r.limite))
    check(r.x == 5 and r.y == 3, "T2 ancré au coin de la zone")
    check((ecarte_cause(r, "fonte-2x2-double-central") or ""):match("^moins_bon:ne_couvre_pas"), "T2 la colonne double, tournée, ne tient qu'une tuile : " .. tostring(ecarte_cause(r, "fonte-2x2-double-central")))
  end)

  t("T3 un obstacle coupe la zone : la tuile se pose du côté qui permet le plus de tuiles", function()
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 40, h = 11 }, obstacles = { { x = 14, y = 0, l = 6, h = 11 } }, famille = "fonte",
      demande = { jeton = "P", debit = 3.75 }, ctx = ctx_pierre() })
    check(r.motif == "fonte-2x2-double-central" and r.n == 3 and r.x == 0, "T3 3 tuiles à gauche (12 de large ≤ 14) : " .. tostring(r.motif) .. " " .. tostring(r.n) .. " x=" .. tostring(r.x))
    local r2 = Chx.choisir({ zone = { x = 0, y = 0, l = 40, h = 11 }, obstacles = { { x = 14, y = 0, l = 6, h = 11 } }, famille = "fonte",
      demande = { jeton = "P", debit = 5 }, ctx = ctx_pierre() })
    check(r2.n == 4 and r2.x == 20, "T3 4 tuiles pour 5 plaques/s : seule la partie droite (20 de large) les contient : n=" .. tostring(r2.n) .. " x=" .. tostring(r2.x))
  end)

  t("T4 entrée par l'est : le motif est tourné d'un demi-tour", function()
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 30, h = 12 }, famille = "fonte", demande = { jeton = "P", debit = 6 }, ctx = ctx_pierre(),
      entrees = { { cote = "E", pos = 5, jetons = { "A", "combustible" } } } })
    check(r.motif == "fonte-2x2-double-central" and r.orient.rot == 4 and not r.orient.miroir, "T4 rot 4 sans miroir : " .. tostring(r.orient and r.orient.rot))
    check(r.x + r.l == 30, "T4 collé au bord est de la zone, côté de l'arrivée : x=" .. tostring(r.x))
    local inst = Cat.instancier(r.motif, r.n, r.orient)
    local ok = false
    for _, p in ipairs(inst.ports) do if p.io == "in" and p.cote == E then ok = true end end
    check(ok, "T4 l'entrée du motif instancié est bien du côté est")
    -- la rangée d'entrée est alignée sur la position donnée
    local py
    for _, p in ipairs(inst.ports) do if p.io == "in" then py = p.y + r.y end end
    check(py == 5, "T4 rangée de l'entrée alignée sur 5 : " .. tostring(py))
  end)

  t("T5 entrée par le nord dans une zone haute : tourné d'un quart de tour", function()
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 12, h = 30 }, famille = "fonte", demande = { jeton = "P", debit = 6 }, ctx = ctx_pierre(),
      entrees = { { cote = "N", jetons = { "A", "combustible" } } } })
    check(r.motif == "fonte-2x2-double-central" and r.orient.rot == 2, "T5 rot 2 : " .. tostring(r.orient and r.orient.rot))
    check(r.l == 11 and r.h == 20, "T5 emprise 11×20 : " .. tostring(r.l) .. "×" .. tostring(r.h))
  end)

  t("T6 fours électriques seuls (côté 3) : un motif 3×3, les 2×2 écartés", function()
    local c = ctx_pierre()
    c.taille = { machine_fonte = 3 }
    c.vitesse = { machine_fonte = 2 }
    c.combustible = { machine_fonte = 0 }
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 60, h = 14 }, famille = "fonte", demande = { jeton = "P", debit = 5 }, ctx = c })
    check(r.motif and r.motif:match("^fonte%-3x3"), "T6 motif 3×3 : " .. tostring(r.motif))
    check(ecarte_cause(r, "fonte-2x2-double-central") == "taille:machine_fonte=2", "T6 2×2 écarté pour sa taille")
    check(r.couvre, "T6 couvre la demande")
  end)

  t("T7 bras long indisponible : plus de tuile à deux entrées ; avec recherche, elle revient", function()
    local dispo = { machine_asm = "oui", bras = "oui", tapis_entree = "oui", tapis_sortie = "oui", tapis = "oui", poteau = "oui", coffre = "oui" }
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 40, h = 20 }, famille = "asm", demande = { jeton = "P", debit = 0.8 }, ctx = ctx_asm({ dispo = dispo }) })
    check(r.motif == nil, "T7 aucun motif à deux entrées sans bras long : " .. tostring(r.motif))
    check(ecarte_cause(r, "asm-2e-1s") == "role_indisponible:bras_long", "T7 cause : bras long indisponible (" .. tostring(ecarte_cause(r, "asm-2e-1s")) .. ")")
    check(ecarte_cause(r, "asm-1e-1s") == "jeton_non_servi:principal:B", "T7 la tuile à 1 entrée ne sert pas la 2e matière (" .. tostring(ecarte_cause(r, "asm-1e-1s")) .. ")")
    dispo.bras_long = "recherche"
    dispo.souterrain_entree, dispo.souterrain_sortie, dispo.repartiteur = "oui", "oui", "oui"
    local r2 = Chx.choisir({ zone = { x = 0, y = 0, l = 40, h = 20 }, famille = "asm", demande = { jeton = "P", debit = 0.8 }, ctx = ctx_asm({ dispo = dispo }) })
    check(r2.motif == "asm-2e-1s", "T7 bras long à rechercher : la tuile de référence du DC (" .. tostring(r2.motif) .. ")")
  end)

  t("T8 jeton absent des entrées disponibles", function()
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 40, h = 20 }, famille = "asm", demande = { jeton = "P", debit = 1 }, ctx = ctx_asm(),
      entrees = { { cote = "O", jetons = { "A" } } } })
    check(ecarte_cause(r, "asm-2e-1s") == "jeton_manquant:B", "T8 asm-2e-1s : jeton B manquant (" .. tostring(ecarte_cause(r, "asm-2e-1s")) .. ")")
    check(r.motif == nil, "T8 aucun motif quand B n'arrive nulle part (" .. tostring(r.motif) .. ")")
  end)

  t("T9 carte de tuiles libres : un semis de rochers interdit tout motif", function()
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 24, h = 24 }, famille = "fonte", demande = { jeton = "P", debit = 1 }, ctx = ctx_pierre(),
      libre = function(x, y) return (x + y) % 3 ~= 0 end })
    check(r.motif == nil, "T9 rien ne tient : " .. tostring(r.motif))
    check(ecarte_cause(r, "fonte-2x2-simple") == "place_insuffisante", "T9 cause : place insuffisante")
    local r2 = Chx.choisir({ zone = { x = 0, y = 0, l = 24, h = 12 }, famille = "fonte", demande = { jeton = "P", debit = 1 }, ctx = ctx_pierre(),
      libre = function(x, y) return not (x >= 8 and x < 10 and y < 12) end })
    check(r2.motif and r2.x == 0 and r2.n >= 1, "T9 carte avec un rocher : la tuile se pose du côté libre : " .. tostring(r2.motif))
  end)

  t("T10 bus : la plus petite capacité qui suffit", function()
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 30, h = 6 }, famille = "bus", demande = { voies = 4, longueur = 20 }, ctx = {} })
    check(r.motif == "bus-4-voies" and r.n == 20 and r.couvre, "T10 bus de 4 voies, 20 tuiles : " .. tostring(r.motif) .. " " .. tostring(r.n))
    local r2 = Chx.choisir({ zone = { x = 0, y = 0, l = 30, h = 10 }, famille = "bus", demande = { voies = 6, longueur = 25 }, ctx = {} })
    check(r2.motif == "bus-8-voies" and r2.n == 25 and r2.couvre, "T10 6 voies : le bus de 8 (" .. tostring(r2.motif) .. ")")
    check(ecarte_cause(r2, "bus-4-voies") == "capacite_insuffisante", "T10 cause : capacité insuffisante")
    local r3 = Chx.choisir({ zone = { x = 0, y = 0, l = 30, h = 10 }, famille = "bus", demande = { voies = 4, longueur = 40 }, ctx = {} })
    check(r3.n == 30 and not r3.couvre and r3.limite == "place", "T10 longueur 40 dans 30 : 30 tuiles, limite place")
  end)

  t("T18 bras de base : ce sont eux qui limitent, la rangée en miroir devient la plus compacte", function()
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 60, h = 20 }, famille = "asm", usage = "assemblage", demande = { jeton = "P", debit = 2 },
      ctx = ctx_asm({ bras = { bras = 0.83, bras_long = 1.15 } }) })
    local f = 0.83 * 0.85 * 0.9 / 1.5   -- bras court qui prend sur un tapis : 0,635 pour 1,5/s demandés
    check(r.motif == "asm-miroir-2e" and r.n == 2, "T18 miroir 2 tuiles : " .. tostring(r.motif) .. " " .. tostring(r.n))
    check(r.debit and math.abs(r.debit.total - 2 * 2 * 1.5 * f) < 1e-6, "T18 débit = 4 machines × 1,5 × utilisation " .. f .. " : " .. tostring(r.debit and r.debit.total))
  end)

  t("T19 rapport de chaîne : câble à une unité par fabrication, les circuits ne reçoivent que la moitié", function()
    local c = { vitesse = { machine_asm = 0.75 }, bras = { bras = 2.31, bras_long = 2.31 }, tapis_voie = 7.5, poteau = { supply = 2.5, fil = 7.5 },
      recettes = { cable = { temps = 0.5, entrees = { A = 1 }, sorties = { M = 1 } }, circ = { temps = 0.5, entrees = { M = 3, B = 1 }, sorties = { P = 1 } } } }
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 40, h = 40 }, famille = "asm", usage = "circuits", demande = { jeton = "P", debit = 3 }, ctx = c })
    check(r.motif == "asm-cable-circuit-3-2-double" and r.n == 1, "T19 double face, une tuile : " .. tostring(r.motif) .. " " .. tostring(r.n))
    check(r.debit and math.abs(r.debit.total - 3.0) < 1e-6, "T19 3 circuits/s (4 machines × 1,5 × 0,5) : " .. tostring(r.debit and r.debit.total))
  end)

  t("T20 une recette par groupe : sans elle, une chaîne est refusée au lieu de prendre la recette principale", function()
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 40, h = 40 }, famille = "asm", usage = "circuits", demande = { jeton = "P", debit = 1 }, ctx = ctx_asm() })
    check(r.motif == nil and ecarte_cause(r, "asm-cable-circuit-3-2-simple") == "recette_manquante:cable", "T20 cause : " .. tostring(ecarte_cause(r, "asm-cable-circuit-3-2-simple")))
  end)

  t("T21 voies de tapis : la demande excède les deux voies de minerai, n vaut 12", function()
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 200, h = 12 }, famille = "fonte", usage = "fonte", demande = { jeton = "P", debit = 50 }, ctx = ctx_pierre() })
    check(r.motif == "fonte-2x2-double-sortie-centrale" and r.n == 12 and not r.couvre and r.limite == "tapis", "T21 : " .. tostring(r.motif) .. " n=" .. tostring(r.n) .. " " .. tostring(r.limite))
    check(r.debit and math.abs(r.debit.total - 15) < 1e-6, "T21 15 plaques/s = 12 tuiles × 4 fours × 0,3125 : " .. tostring(r.debit and r.debit.total))
  end)

  t("T22 un obstacle hors de la bande de la tuile ne la gêne pas", function()
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 40, h = 9 }, obstacles = { { x = 10, y = 7, l = 4, h = 2 } }, famille = "fonte", usage = "fonte",
      demande = { jeton = "P", debit = 6.25 }, ctx = ctx_pierre() })
    check(r.motif == "fonte-2x2-simple" and r.n == 10 and r.x == 0 and r.y == 0 and r.couvre, "T22 rangée simple de 40 en haut : " .. tostring(r.motif) .. " n=" .. tostring(r.n) .. " (" .. tostring(r.x) .. ", " .. tostring(r.y) .. ")")
  end)

  t("T10b piquage d'une voie de bus : le motif de piquage seul, jamais le bus simple", function()
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 12, h = 12 }, famille = "bus", demande = { voies = 4, piquage = true }, ctx = {} })
    check(r.motif == "bus-piquage-voie-exterieure" and r.n == 1 and r.couvre, "T10b piquage : " .. tostring(r.motif))
    check(ecarte_cause(r, "bus-4-voies") == "demande_incompatible", "T10b le bus simple est écarté (demande incompatible)")
    local r2 = Chx.choisir({ zone = { x = 0, y = 0, l = 5, h = 12 }, famille = "bus", demande = { voies = 4, piquage = true }, ctx = {} })
    check(r2.motif == nil and ecarte_cause(r2, "bus-piquage-voie-exterieure") == "place_insuffisante", "T10b zone trop étroite")
  end)

  t("T11 équilibreurs : le plus simple qui convient", function()
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 12, h = 8 }, famille = "equilibreur", demande = { entrees = 2, sorties = 4 }, ctx = {} })
    check(r.motif == "equilibreur-2-4", "T11 2 vers 4 : l'arbre de 3 répartiteurs (" .. tostring(r.motif) .. ")")
    local r2 = Chx.choisir({ zone = { x = 0, y = 0, l = 12, h = 6 }, famille = "equilibreur", demande = { entrees = 4, sorties = 4 }, ctx = {} })
    check(r2.motif == "equilibreur-4-4" and r2.l == 10 and r2.h == 5, "T11 4 vers 4 : le papillon 10×5 (" .. tostring(r2.motif) .. ")")
    local r3 = Chx.choisir({ zone = { x = 0, y = 0, l = 8, h = 8 }, famille = "equilibreur", demande = { entrees = 4, sorties = 4 }, ctx = {} })
    check(r3.motif == nil and ecarte_cause(r3, "equilibreur-4-4") == "place_insuffisante", "T11 zone de 8 de large : le papillon ne tient pas")
    local r4 = Chx.choisir({ zone = { x = 0, y = 0, l = 5, h = 12 }, famille = "equilibreur", demande = { entrees = 1, sorties = 2 }, ctx = {} })
    check(r4.motif == "equilibreur-1-2" and r4.orient.rot == 0, "T11 1 vers 2 : un répartiteur")
  end)

  t("T12 champ de foreuses sur un gisement : le champ central, tuiles jusqu'à la demande", function()
    local c = { vitesse = { foreuse = 0.5 }, taille = { foreuse = 3 }, recettes = { principal = { temps = 1, sorties = { P = 1 } } },
      tapis_voie = 7.5, poteau = { supply = 2.5, fil = 7.5 } }
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 40, h = 10 }, famille = "mine", demande = { jeton = "P", debit = 5 }, ctx = c })
    check(r.motif == "foreuses-2xN-tapis-central" and r.n == 3 and r.couvre, "T12 champ central, 3 tuiles de 4 foreuses : " .. tostring(r.motif) .. " " .. tostring(r.n))
    check(ecarte_cause(r, "foreuses-2x2-combustion-2xN") == "taille:foreuse=2", "T12 foreuses 2×2 écartées pour leur taille")
    local c2 = { vitesse = { foreuse = 0.25 }, taille = { foreuse = 2 }, recettes = { principal = { temps = 1, sorties = { P = 1 } } }, tapis_voie = 7.5, energie = false }
    local r2 = Chx.choisir({ zone = { x = 0, y = 0, l = 40, h = 10 }, famille = "mine", demande = { jeton = "P", debit = 3 }, ctx = c2 })
    check(r2.motif == "foreuses-2x2-combustion-2xN" and r2.n == 6, "T12 foreuses à combustion : 6 tuiles de 4 (" .. tostring(r2.motif) .. " " .. tostring(r2.n) .. ")")
  end)

  t("T13 poteau trop faible : le champ de chevalets double est écarté", function()
    local c = { vitesse = { chevalet = 1 }, recettes = { principal = { temps = 1, sorties = { F1 = 10 } } }, tapis_voie = 7.5, poteau = { supply = 2.5, fil = 7.5 } }
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 40, h = 9 }, famille = "petrole", usage = "chevalets", demande = { jeton = "F1", debit = 60 }, ctx = c })
    check(ecarte_cause(r, "chevalets-double") == "poteau_insuffisant", "T13 cause : poteau insuffisant (" .. tostring(ecarte_cause(r, "chevalets-double")) .. ")")
    c.poteau = { supply = 3.5, fil = 9 }
    local r2 = Chx.choisir({ zone = { x = 0, y = 0, l = 40, h = 9 }, famille = "petrole", usage = "chevalets", demande = { jeton = "F1", debit = 60 }, ctx = c })
    check(r2.motif == "chevalets-double", "T13 avec le poteau moyen : le champ double (" .. tostring(r2.motif) .. ")")
  end)

  t("T14 demande supérieure à ce que le tapis porte : n borné, limite = tapis", function()
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 200, h = 12 }, famille = "fonte", usage = "fonte", demande = { jeton = "P", debit = 50 }, ctx = ctx_pierre() })
    check(not r.couvre and r.limite == "tapis", "T14 ne couvre pas, limite tapis : " .. tostring(r.limite) .. " " .. tostring(r.motif))
    check(r.n >= 6, "T14 au moins la capacité d'une voie de minerai (" .. tostring(r.n) .. ")")
  end)

  t("T15 déterminisme : deux appels identiques, mêmes résultats", function()
    local req = function()
      return { zone = { x = 3, y = 4, l = 33, h = 15 }, obstacles = { { x = 12, y = 6, l = 2, h = 3 }, { x = 30, y = 10, l = 3, h = 5 } },
        familles = { "fonte", "asm" }, demande = { jeton = "P", debit = 2 }, ctx = ctx_pierre() }
    end
    local a, b = Chx.choisir(req()), Chx.choisir(req())
    local function sig(r)
      local t = { tostring(r.motif), tostring(r.n), tostring(r.x), tostring(r.y), tostring(r.l), tostring(r.h) }
      for _, e in ipairs(r.ecartes) do t[#t + 1] = e.id .. "=" .. e.cause end
      return table.concat(t, "|")
    end
    check(sig(a) == sig(b), "T15 résultats identiques")
  end)

  t("T23 début de partie : centrale, laboratoires, packs rouges et verts, boucle de charbon", function() batterie_debut(Chx) end)

  t("T16b entrées invalides : erreur nette, jamais un résultat silencieux", function()
    local ok1, e1 = pcall(Chx.choisir, { famille = "fonte", demande = { jeton = "P", debit = 1 }, ctx = ctx_pierre() })
    check(not ok1 and tostring(e1):find("zone", 1, true), "T16b zone absente refusée : " .. tostring(e1))
    local ok2, e2 = pcall(Chx.choisir, { zone = { x = 0, y = 0, l = 10, h = 10 }, famille = "fonte", demande = { jeton = "P", debit = 1 }, ctx = ctx_pierre(),
      entrees = { { cote = "X", jetons = { "A" } } } })
    check(not ok2 and tostring(e2):find("côté", 1, true), "T16b côté inconnu refusé : " .. tostring(e2))
  end)

  t("T16 zone trop petite pour une seule tuile : aucun motif, cause pour chacun", function()
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 3, h = 3 }, famille = "fonte", demande = { jeton = "P", debit = 1 }, ctx = ctx_pierre() })
    check(r.motif == nil and r.n == nil, "T16 aucun motif")
    local sans_cause = 0
    for _, m in ipairs(Cat.MOTIFS) do if not ecarte_cause(r, m.id) then sans_cause = sans_cause + 1 end end
    check(sans_cause == 0, "T16 chaque motif a une cause d'écart")
  end)

  t("T17 miroir : l'entrée par le bas d'une rangée simple se garde sans retourner la répétition", function()
    local r = Chx.choisir({ zone = { x = 0, y = 0, l = 20, h = 6 }, famille = "fonte", usage = "fonte", demande = { jeton = "P", debit = 1 }, ctx = ctx_pierre(),
      entrees = { { cote = "O", pos = 5, jetons = { "A", "combustible" } } } })
    check(r.motif == "fonte-2x2-simple" and r.orient.rot == 0 and r.orient.miroir == true, "T17 miroir vertical (entrée en bas, à l'ouest) : " .. tostring(r.motif) .. " m=" .. tostring(r.orient and r.orient.miroir))
  end)
  return R
end

section("6. Sélection")
for _, tr in ipairs(terrains(Ch)) do
  if not quiet then print("  " .. tr.nom) end
  tr.fn()
end

---------------------------------------------------------------------------------------------------
section("7. Coût en instructions")
---------------------------------------------------------------------------------------------------
local function instructions(fn)
  local c = 0
  debug.sethook(function() c = c + 1 end, "", 1)
  fn()
  debug.sethook()
  return c
end
do
  local pire = 0
  local cas = {
    function() return Ch.choisir({ zone = { x = 0, y = 0, l = 60, h = 40 }, obstacles = { { x = 10, y = 5, l = 4, h = 6 }, { x = 30, y = 20, l = 5, h = 8 },
      { x = 45, y = 2, l = 6, h = 4 }, { x = 20, y = 30, l = 8, h = 3 }, { x = 5, y = 25, l = 3, h = 3 } }, demande = { jeton = "P", debit = 4 },
      ctx = ctx_pierre(), entrees = { { cote = "O", pos = 8, jetons = { "A", "combustible" } } } }) end,
    function() return Ch.choisir({ zone = { x = 0, y = 0, l = 40, h = 30 }, familles = { "asm" }, demande = { jeton = "P", debit = 3 }, ctx = ctx_asm(),
      entrees = { { cote = "N", jetons = { "A", "B" } } } }) end,
    function() return Ch.choisir({ zone = { x = 0, y = 0, l = 30, h = 30 }, demande = { jeton = "P", debit = 2 }, ctx = ctx_pierre(),
      libre = function(x, y) return not (x % 7 == 3 and y % 5 == 2) end }) end,
  }
  for i, f in ipairs(cas) do
    local n = instructions(f)
    if n > pire then pire = n end
    print(string.format("  [MOTIFS] instructions de la sélection, cas %d : %d", i, n))
  end
  check(pire <= 300000, "sélection : au plus 300 000 instructions (pire cas " .. pire .. ")")
end

---------------------------------------------------------------------------------------------------
section("8. Mutants")
---------------------------------------------------------------------------------------------------
local function lire(chemin)
  local f = assert(io.open(chemin, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local function remplacer_une(src, old, new)
  local i, j = src:find(old, 1, true)
  assert(i, "mutant : motif absent « " .. old:sub(1, 50) .. " »")
  assert(not src:find(old, j + 1, true), "mutant : motif non unique « " .. old:sub(1, 50) .. " »")
  return src:sub(1, i - 1) .. new .. src:sub(j + 1)
end
local function charger_mutant(chemin, nom, old, new)
  local src = remplacer_une(lire(chemin), old, new)
  local f, err = load(src, "@" .. nom)
  assert(f, err)
  return f()
end

-- 8a. défauts injectés dans les DONNÉES : le contrôle les refuse
local function copie_profonde(v)
  if type(v) ~= "table" then return v end
  local o = {}
  for k, x in pairs(v) do o[k] = copie_profonde(x) end
  return o
end
local function definition_de(m)
  local d = {}
  for k, v in pairs(m) do
    if k ~= "pieces" and k ~= "derive" and k ~= "roles" and k ~= "emprise" and k ~= "l" and k ~= "h" and k ~= "tete" and k ~= "queue" then d[k] = copie_profonde(v) end
  end
  if m.tete then d.tete = { art = copie_profonde(m.tete.art), legende = copie_profonde(m.tete.legende) } end
  if m.queue then d.queue = { art = copie_profonde(m.queue.art), legende = copie_profonde(m.queue.legende) } end
  d.periode = m.periode
  return d
end
local function recompile(id, fn)
  local d = definition_de(Cat.get(id))
  fn(d)
  local m, err = Cp.compiler(d)
  if not m then return nil, err end
  return m
end
local function ligne(d, i, old, new)
  local s = d.art[i]
  local a, b = s:find(old, 1, true)
  assert(a, "mutant de données : « " .. old .. " » absent de la rangée " .. i .. " (" .. s .. ")")
  d.art[i] = s:sub(1, a - 1) .. new .. s:sub(b + 1)
end

local DONNEES = {
  { "période plus courte que l'emprise utile (chevauchement entre tuiles)", "asm-1e-1s", function(d) d.periode = 3 end, "période" },
  { "bras retourné", "asm-2e-1s", function(d) d.legende.I = D.h.bras(S, "tapis_entree:1", "machine_asm", "ent_a") end, "bras" },
  { "bras de prise annoncée sur le mauvais tapis", "asm-2e-1s", function(d) d.legende.L = D.h.bras_long(N, "tapis_entree:1", "machine_asm", "ent_b") end, "prise" },
  { "poteau retiré", "asm-1e-1s", function(d) ligne(d, 4, "+", ".") end, "poteau" },
  { "poteau de la rangée des bras de sortie retiré (aire)", "fonte-2x2-simple", function(d) ligne(d, 5, "o+o.", "o.o.") end, "aire" },
  { "poteaux trop éloignés (fil)", "asm-chaine-1-2", function(d) ligne(d, 4, "qqq+ppp+qqq+", "qqq+ppp+qqq.") end, "reli" },
  { "poteau moyen requis mais non déclaré", "chevalets-double", function(d) d.exige_poteau = nil end, "poteau" },
  { "tapis de sortie à contresens (face-à-face)", "fonte-2x2-simple", function(d) d.legende.b = D.h.sortie(1, W); ligne(d, 6, "aaaa", "aabb") end, "fait face" },
  { "entrée non déclarée", "fonte-2x2-simple", function(d) d.entrees = {} end, "sans entrée déclarée" },
  { "sortie déclarée à la mauvaise rangée", "fonte-2x2-simple", function(d) d.sorties[1].pos = 3 end, "déclarée" },
  { "mélange de fluides (tuyau de l'autre fluide à côté)", "chimie-rangee-2f-sortie", function(d) ligne(d, 1, "wx.y", "wxwy") end, "mélange" },
  { "tuyau du mauvais fluide sur un raccord", "chimie-rangee-2f-sortie", function(d) d.legende.g = D.h.tuyau("F1") end, "raccord" },
  { "tuyau souterrain sans partenaire", "chimie-rangee-2f-sortie", function(d) ligne(d, 1, "wx.y", "wx..") end, "partenaire" },
  { "souterrain de tapis sans sortie", "equilibreur-4-4", function(d) ligne(d, 3, "cTgvGnttVq", "cTgv.nttVq") end, "souterrain" },
  { "tapis de tête sans origine déclarée", "packs-verts-rangee", function(d) d.tete.legende.d = { role = "tapis", k = 2, dir = E } end, "démarre au bord" },
  { "bout de tapis non déclaré", "packs-verts-rangee", function(d) d.legende.c = { role = "tapis", k = 1, dir = E } end, "quitte l'emprise" },
  { "bras de tête hors d'un poteau", "packs-verts-rangee", function(d) d.tete.art[4] = ".mmm+nnn+"; d.tete.art[7] = ".ttT+uu.." end, "poteau" },
  { "dépôt annoncé sur le mauvais tapis de sortie", "asm-1e-1s", function(d) d.legende.o = D.h.bras(N, "machine_asm", "tapis_sortie:2", "sort") end, "dépôt" },
  { "tapis de sortie en face-à-face isolé", "fonte-3x3-simple", function(d) d.legende.w = D.h.sortie(1, W); ligne(d, 7, "aaaaaa", "aaawaa") end, "fait face" },
  { "emprise utile plus large que la période sans recouvrement", "asm-1e-1s", function(d)
      for i = 1, #d.art do d.art[i] = d.art[i] .. (i == 2 and "+" or ".") end
      d.periode = 4
    end, "période" },
  { "souterrain de tapis sans sortie en bout de voie", "bus-piquage-voie-exterieure", function(d) d.legende.g = D.h.ug_entree(E); ligne(d, 1, "attttA", "atttgA") end, "souterrain" },
  { "tapis coupé au milieu", "bus-piquage-voie-exterieure", function(d) ligne(d, 1, "attttA", "att.tA") end, "vide" },
  { "machine de taille interdite", "fonte-2x2-simple", function(d) d.legende.f = D.h.machine("machine_fonte", 4) end, "incomplet" },
  { "lien déclaré sans bras", "asm-1e-1s", function(d) d.liens.fantome = { groupe = "principal", io = "in", jetons = { "A" } } end, "sans bras" },
  { "rôle inconnu", "asm-1e-1s", function(d) d.legende.m = { role = "machine_inconnue", w = 3, h = 3 } end, "inconnu" },
  { "bras sans lien déclaré", "asm-1e-1s", function(d) d.liens.ent_a = nil end, "non déclaré" },
  { "chaîne vers un groupe absent", "asm-chaine-1-1", function(d) d.chaines[1].aval = "fantome" end, "groupe inconnu" },
}
-- équilibreur 4-4 sans croisement : le contrôle de cohérence l'accepte, le suivi de flux le refuse
do
  local m = recompile("equilibreur-4-4", function(d)
    d.art = { "aSttttttUo", "bSttttttUp", "cTttttttVq", "dTttttttVs", ".........." }
  end)
  check(m ~= nil, "mutant d'équilibre : le 4-4 sans croisement se compile")
  if m then
    check(#K.verifier(m) == 0 and not equilibre(m), "mutant « 4-4 sans croisement » : cohérent mais déséquilibré, refusé par le suivi de flux")
  end
end
local verif_ok = true
for _, mu in ipairs(DONNEES) do
  local m, err = recompile(mu[2], mu[3])
  if not m then
    check(true, "mutant de données « " .. mu[1] .. " » refusé à la compilation (" .. tostring(err):sub(1, 60) .. ")")
  else
    local errs = K.verifier(m)
    local trouve = false
    for _, e in ipairs(errs) do if e:find(mu[4], 1, true) then trouve = true end end
    check(#errs > 0 and trouve, "mutant de données « " .. mu[1] .. " » refusé (" .. (errs[1] or "AUCUNE ERREUR") .. ")")
  end
end

-- 8b. défauts injectés dans le CONTRÔLE : au moins un motif fautif échappe, le mutant est tué
local function fautifs()
  local liste = {}
  for _, mu in ipairs(DONNEES) do
    local m = recompile(mu[2], mu[3])
    if m then liste[#liste + 1] = m end
  end
  return liste
end
do
  local liste = fautifs()
  local function tue(Km)
    for _, m in ipairs(liste) do
      local ok, errs = pcall(Km.verifier, m)
      if ok and #errs == 0 then return true end
    end
    return false
  end
  local CH = "shared/team/motifs/controle.lua"
  local MUT_K = {
    { "prise non contrôlée", "if not Cp.correspond(a, p.prend) then", "if false then" },
    { "dépôt non contrôlé", "if not Cp.correspond(b, p.depose) then", "if false then" },
    { "face-à-face toléré", "elseif q.dir == opposite(p.dir) then", "elseif false then" },
    { "période non contrôlée", "if m.periode < maxx then", "if false then" },
    { "aire des poteaux non contrôlée", "if not ok then e(\"%s en (%d, %d) hors de l'aire", "if false then e(\"%s en (%d, %d) hors de l'aire" },
    { "fil des poteaux non contrôlé", "if dx * dx + dy * dy <= spec.fil * spec.fil then", "if true then" },
    { "mélange non contrôlé", "q.fluide ~= p.fluide then", "false then" },
    { "entrée déclarée non exigée", "if not est_sortie_decl(p, x, y, \"in\") then", "if false then" },
    { "tuyau souterrain sans partenaire toléré", "if not trouve then e(\"tuyau souterrain", "if false then e(\"tuyau souterrain" },
    { "souterrain de tapis sans partenaire toléré", "if not paire_souterrain(p) then e(", "if false then e(" },
    { "lien sans bras toléré", "if not liens_vus[id] then e(", "if false then e(" },
    { "tapis sans origine toléré", "elseif p.role == \"tapis\" and not p.origine then", "elseif p.role == \"tapis\" and false then" },
    { "groupe de chaîne inconnu toléré", "if not der.groupes[c.amont] or not der.groupes[c.aval] then e(", "if false then e(" },
  }
  for _, mu in ipairs(MUT_K) do
    local Km = charger_mutant(CH, "controle_mutant", mu[2], mu[3])
    check(tue(Km), "mutant du contrôle « " .. mu[1] .. " » tué par un motif fautif")
  end
end

-- 8c. défauts injectés dans les TRANSFORMATIONS : la batterie d'orientation les voit
do
  local DS = "shared/team/motifs/dsl.lua"
  local MUT_D = {
    { "quart de tour remplacé par une transposition", "if r == 2 then return H - y - h, x, h, w end", "if r == 2 then return y, x, h, w end" },
    { "rotation de 270° fausse", "if r == 6 then return y, L - x - w, h, w end", "if r == 6 then return y, x, h, w end" },
    { "demi-tour sans effet sur la position", "if r == 4 then return L - x - w, H - y - h, w, h end", "if r == 4 then return x, y, w, h end" },
    { "miroir sans effet sur la position", "if T.miroir then y = H - y - h end", "if T.miroir then y = y end" },
    { "directions tournées en sens inverse", "return (d + T.rot) % 8", "return (d - T.rot) % 8" },
    { "miroir sans échange nord-sud", "if d == N then d = S elseif d == S then d = N end", "if d == N then d = N end" },
    { "dimensions non échangées après un quart de tour", "if T.rot == 2 or T.rot == 6 then return H, L end", "if T.rot == 2 or T.rot == 6 then return L, H end" },
  }
  for _, mu in ipairs(MUT_D) do
    local Dm = charger_mutant(DS, "dsl_mutant", mu[2], mu[3])
    quiet = true
    local fail0 = failures
    local ok = batterie_orientation(Dm)
    quiet = false
    failures = fail0
    check(not ok, "mutant des transformations « " .. mu[1] .. " » refusé par la batterie d'orientation")
  end
end

-- 8d. défauts injectés dans la SÉLECTION : la batterie de terrains les voit
do
  local CHP = "shared/team/motifs/choix.lua"
  local MUT_C = {
    { "nombre de tuiles arrondi par défaut", "n_besoin = max(1, ceil(dem.debit / q - EPS))", "n_besoin = max(1, floor(dem.debit / q - EPS))" },
    { "bras ignorés", "f[id] = min(1, cap / dem)", "f[id] = 1" },
    { "prise sur tapis sans pénalité", "X.BELT_PICKUP = 0.85", "X.BELT_PICKUP = 1" },
    { "voies de tapis mal comptées", "local n = floor_eps(#lanes * voie / q)", "local n = floor_eps(2 * voie / q)" },
    { "surface préférée la plus grande", "if a.surface ~= b.surface then return a.surface < b.surface end", "if a.surface ~= b.surface then return a.surface > b.surface end" },
    { "rapport de chaîne ignoré", "local u = min(util[c.aval], fourni / r.b)", "local u = util[c.aval]" },
    { "taille de machine ignorée", "if not ok then return \"taille:\" .. e.role .. \"=\" .. e.w end", "if false then return \"taille:\" .. e.role .. \"=\" .. e.w end" },
    { "poteau ignoré", "if ctx.poteau.supply + EPS < spec.supply or ctx.poteau.fil + EPS < spec.fil then return \"poteau_insuffisant\" end", "if false then return \"poteau_insuffisant\" end" },
    { "jeton manquant ignoré", "if not dispo[tok] and not manque then manque = tok end", "if false then manque = tok end" },
    { "obstacle hors bande pris en compte", "if b[2] < y + perp and b[4] > y and b[3] > x then", "if b[3] > x then" },
    { "raccord hors côté non compté", "if not ok and #supplies > 0 then faux = faux + 1 end", "if false then faux = faux + 1 end" },
    { "technologie indisponible tolérée", "elseif not ctx.dispo[role] then", "elseif false then" },
    { "couverture de la demande comptée toujours vraie", "else couvre = total + EPS >= dem.debit end", "else couvre = true end" },
    { "recette manquante remplacée par la recette principale", "local r = (ctx.recettes or {})[g]   -- un groupe a SA recette", "local r = (ctx.recettes or {})[g] or (ctx.recettes or {}).principal   -- un groupe a SA recette" },
    { "producteur de tête ignoré", "if nf < n_fixe then n_fixe = nf end", "if false then n_fixe = nf end" },
    { "chaîne en série ignorée", "if nc < n_fixe then n_fixe = nc end", "if false then n_fixe = nc end" },
    { "borne propre du motif ignorée", "if m.max_tuiles and m.max_tuiles < cap then", "if false then" },
    { "contact direct ignoré", "if c.contact and c.aval == g then serv[c.jeton] = true end", "if false then serv[c.jeton] = true end" },
    { "ingrédient non servi toléré", "if not serv[tok] then return nil, \"jeton_non_servi:\" .. g .. \":\" .. tok end", "if false then return nil, \"jeton_non_servi:\" .. g .. \":\" .. tok end" },
  }
  for _, mu in ipairs(MUT_C) do
    local Cm = charger_mutant(CHP, "choix_mutant", mu[2], mu[3])
    quiet = true
    local fail0 = failures
    for _, tr in ipairs(terrains(Cm)) do
      local ok, err = pcall(tr.fn)
      if not ok then failures = failures + 1 end
    end
    local tue = failures > fail0
    quiet = false
    failures = fail0
    check(tue, "mutant de la sélection « " .. mu[1] .. " » tué par au moins un terrain")
  end
end

print(string.format("[MOTIFS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
