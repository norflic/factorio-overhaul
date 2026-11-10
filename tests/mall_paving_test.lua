--[[
  Lot MALL-PAVAGE : banc HORS JEU de shared/team/mall_paving.lua (géométrie du ruban, duplication en série, pavage d'un lot) et du
  câblage minimal dans script/team/build.lua (candidates / place_module : plusieurs blocs de mall par lot, collés).
    lua5.2 tests/mall_paving_test.lua   -> [MALL-PAVAGE] BILAN : N OK, 0 ECHEC(S)
    §1 pattern : dimensions (14 de haut pour 3 × 3 et 2 convoyeurs, comme P.bloc), gap, aucun chevauchement, entrées au bout amont,
       une sortie (coffre) par machine, poteaux dans les passages, tailles de machine et corridors variés, refus écrits ;
    §2 next_offset : contiguïté en x et en y, gap par défaut, gap > 2 refusé (erreur de contrat), les deux formes de boîte ;
    §3 compact : largeur totale = somme + gaps, emprise en travers, déterminisme (deux appels, même liste permutée ≠), axe y ;
    §4 check : refus d'un chevauchement, d'une cellule hors emprise, d'une machine sans bras d'entrée ou de sortie ;
    §5 pave_origin : collé à l'est, puis au sud, débords des têtes, lot plein (le bloc 11 × 14 à têtes 17 ne se double pas dans 24) ;
    §6 câblage (source de build.lua) : crochets présents, aucun `pairs` nouveau, fonctions courtes ; §6 bis (lot MALL-RUE) : sources du
       câblage de la série (build.lua, plan.lua, industrie.lua, modules.lua), puis les crochets Build.Pave.serie / try_serie / cross extraits
       de build.lua et joués hors jeu sur un gabarit ruban réel (lot suivant, souterrain, port servi sans tête, arrêt « lot occupe », journal) ;
    §7 MUTANTS du module (substitution du source) : gap ignoré, chevauchement non détecté, sortie manquante acceptée, offset décalé,
       poteau dans la machine, pavage sans débords ;
    §8 serie (lot MALL-RUE) : section suivante de l'autre côté de la rue, souterrain d'un bord de lot à l'autre (écart = rue + 1 dans la
       portée), rallonge et raccords, axe y, refus (portée insuffisante ou inconnue, section 1 sur la rue), déterminisme ;
    §9 check_serie : section sur la rue, chevauchement, corridor coupé, souterrain hors des bords, portée ; mutants : section posée sur
       la rue, portée ignorée, corridor coupé, vérification aveugle.
]]
package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("  ECHEC : " .. label) end
  return cond
end
local function read(path) local fh = assert(io.open(path, "rb")) local s = fh:read("*a") fh:close() return s end

local MP_PATH = "shared/team/mall_paving.lua"
local SRC = read(MP_PATH)
local function load_mp(src) return assert(load(src or SRC, "=" .. MP_PATH, "t", _ENV))() end
local Mp = load_mp()

local function count(pat, kind) local n = 0 for _, c in ipairs(pat.cells) do if c.kind == kind then n = n + 1 end end return n end
local function cell_at(pat, dx, dy, kind)
  for _, c in ipairs(pat.cells) do
    if (not kind or c.kind == kind) and dx >= c.dx and dx < c.dx + (c.w or 1) and dy >= c.dy and dy < c.dy + (c.h or 1) then return c end
  end
  return nil
end

---------------------------------------------------------------------------------------------------
print("== §1 pattern : le ruban")
---------------------------------------------------------------------------------------------------
local p = assert(Mp.pattern({ asm = { w = 3, h = 3 }, belts = 2, n = 2 }))
check(p.w == 7 and p.h == 14, "3 x 3, 2 convoyeurs, 2 machines par rangee : 7 x 14 (hauteur du bloc de patrons.lua)")
check(p.gap == 1 and p.belts == 2 and p.n == 2, "gap par defaut 1, 2 convoyeurs, n = 2")
local okp, whyp = Mp.check(p)
check(okp, "le ruban passe sa propre validation : " .. tostring(whyp))
check(count(p, "asm") == 4 and count(p, "chest") == 4 and count(p, "arm_out") == 4, "4 machines, 4 coffres, 4 bras de sortie")
check(count(p, "belt") == 14, "2 convoyeurs de 7 tuiles")
check(#p.inputs == 2 and p.inputs[1].dx == 0 and p.inputs[1].dy == 6 and p.inputs[2].dy == 7, "entrees au bout ouest des convoyeurs (y = 6 et 7)")
check(#p.outputs == 4 and p.outputs[1].dy == 0 and p.outputs[2].dy == 13, "sorties : coffres nord (y = 0) et sud (y = 13)")
check(cell_at(p, 1, 6, "belt") and cell_at(p, 1, 7, "belt") and cell_at(p, 1, 5, "arm_in") and cell_at(p, 1, 8, "arm_in"), "corridor central entre les deux bras d'entree")
check(cell_at(p, 1, 5).dir == Mp.S and cell_at(p, 1, 8).dir == Mp.N, "bras d'entree : le nord prend au sud, le sud prend au nord")
check(cell_at(p, 1, 1).kind == "arm_out" and cell_at(p, 1, 1).dir == Mp.S and cell_at(p, 1, 12).dir == Mp.N, "bras de sortie vers les coffres exterieurs")
check(cell_at(p, 2, 5, "arm_in") and cell_at(p, 2, 5).reach == 2, "bras long vers le second convoyeur")
check(cell_at(p, 3, 3, "pole") and cell_at(p, 3, 10, "pole") and cell_at(p, 7, 3, "pole"), "poteaux dans le passage entre machines et dans le gap de section")
check(cell_at(p, 3, 6, "belt") and not cell_at(p, 3, 2), "le passage ne porte que le poteau et le corridor")
-- machines seules, grandes, 3 convoyeurs
local p1 = assert(Mp.pattern({ asm = { w = 3, h = 3 } }))
check(p1.w == 3 and p1.h == 14 and Mp.check(p1) and count(p1, "pole") == 2, "n = 1 : 3 x 14, poteaux dans le gap de section")
local p5 = assert(Mp.pattern({ asm = { w = 5, h = 5 }, belts = 3, n = 3 }))
check(p5.w == 17 and p5.h == 19 and Mp.check(p5), "5 x 5, 3 convoyeurs, 3 par rangee : 17 x 19, valide")
check(#p5.inputs == 3 and count(p5, "belt") == 51, "3 convoyeurs de 17")
local p0 = assert(Mp.pattern({ asm = { w = 3, h = 3 }, gap = 0 }))
check(p0.gap == 0 and count(p0, "pole") == 0 and Mp.check(p0), "gap 0 : aucun poteau dans un gap qui n'existe pas")
local p2 = assert(Mp.pattern({ asm = { w = 2, h = 2 }, n = 4 }))
check(p2.w == 11 and p2.h == 12 and Mp.check(p2), "machine 2 x 2 : 11 x 12 valide")
local p11 = assert(Mp.pattern({ asm = { w = 1, h = 1 }, n = 2 }))
check(Mp.check(p11) and count(p11, "arm_in") == 4, "machine 1 x 1 : pas de bras long (il poserait hors de la machine), valide")
-- refus
check(select(2, Mp.pattern({})) and select(2, Mp.pattern({})):find("asm"), "sans asm : refus ecrit")
check(select(2, Mp.pattern({ asm = { w = 3, h = 3 }, belts = 4 })):find("2 ou 3"), "4 convoyeurs : refus")
check(select(2, Mp.pattern({ asm = { w = 3, h = 3 }, n = 0 })):find("n ="), "n = 0 : refus")
check(not pcall(Mp.pattern, { asm = { w = 3, h = 3 }, gap = 3 }), "gap 3 dans le gabarit : erreur de contrat")
-- determinisme : deux generations identiques
local pa, pb = Mp.pattern({ asm = { w = 3, h = 3 }, n = 3 }), Mp.pattern({ asm = { w = 3, h = 3 }, n = 3 })
local same = #pa.cells == #pb.cells
for i = 1, #pa.cells do
  local a, b = pa.cells[i], pb.cells[i]
  if a.kind ~= b.kind or a.dx ~= b.dx or a.dy ~= b.dy or a.dir ~= b.dir then same = false end
end
check(same, "pattern deterministe (memes cellules dans le meme ordre)")

---------------------------------------------------------------------------------------------------
print("== §2 next_offset : la section suivante collee a la precedente")
---------------------------------------------------------------------------------------------------
local prev = { x0 = 10, y0 = 20, x1 = 17, y1 = 34 }
local o = Mp.next_offset(prev, "x", 1)
check(o.x == 18 and o.y == 20, "axe x, gap 1 : origine en (18, 20)")
o = Mp.next_offset(prev, "y", 2)
check(o.x == 10 and o.y == 36, "axe y, gap 2 : origine en (10, 36)")
o = Mp.next_offset(prev, "x")
check(o.x == 17 + Mp.GAP, "gap par defaut = Mp.GAP")
o = Mp.next_offset({ x = 10, y = 20, w = 7, h = 14 }, "x", 0)
check(o.x == 17 and o.y == 20, "forme { x, y, w, h } acceptee, gap 0 : contigu")
check(not pcall(Mp.next_offset, prev, "x", 3), "gap 3 refuse (erreur de contrat)")
check(not pcall(Mp.next_offset, prev, "x", 20), "gap 20 (l'espacement mort) refuse")
check(not pcall(Mp.next_offset, prev, "x", -1), "gap negatif refuse")
check(not pcall(Mp.next_offset, prev, "x", 1.5), "gap non entier refuse")
check(not pcall(Mp.next_offset, prev, "z", 1), "axe inconnu refuse")
check(not pcall(Mp.next_offset, { x0 = 1 }, "x", 1), "boite incomplete refusee")
-- en serie : trois sections de 7
local a = { x = 0, y = 0, w = 7, h = 14 }
local b = Mp.next_offset(a, "x"); b.w, b.h = 7, 14
local c = Mp.next_offset(b, "x")
check(b.x == 8 and c.x == 16, "trois sections en serie : 0, 8, 16")

---------------------------------------------------------------------------------------------------
print("== §3 compact : largeur totale = somme + gaps")
---------------------------------------------------------------------------------------------------
local blocks = { { w = 11, h = 14 }, { w = 7, h = 14 }, { w = 3, h = 12 } }
local cp = Mp.compact(blocks, 1)
check(cp.n == 3 and cp.w == 11 + 7 + 3 + 2 and cp.h == 14, "largeur 23 = 21 + 2 gaps, hauteur 14")
check(cp.origins[1].x == 0 and cp.origins[2].x == 12 and cp.origins[3].x == 20, "origines 0, 12, 20")
check(cp.origins[1].y == 0 and cp.origins[3].y == 0, "meme ligne")
local cp2 = Mp.compact(blocks, 1)
check(cp2.w == cp.w and cp2.origins[3].x == cp.origins[3].x, "deterministe : deux appels, memes origines")
local cpy = Mp.compact(blocks, 2, "y")
check(cpy.h == 14 + 14 + 12 + 4 and cpy.w == 11 and cpy.origins[2].y == 16 and cpy.origins[3].y == 32, "axe y, gap 2 : 44 de haut, origines 0, 16, 32")
check(Mp.compact({}, 1).w == 0 and Mp.compact({}, 1).n == 0, "liste vide : 0")
check(Mp.compact({ { w = 5, h = 5 } }, 2).w == 5, "un seul bloc : pas de gap")
local perm = Mp.compact({ blocks[3], blocks[1], blocks[2] }, 1)
check(perm.origins[2].x == 4 and perm.w == 23, "l'ordre de la liste est l'ordre des origines")
check(not pcall(Mp.compact, blocks, 3), "compact : gap 3 refuse")
check(not pcall(Mp.compact, { { w = 0, h = 1 } }, 1), "compact : bloc de largeur 0 refuse")
check(not pcall(Mp.compact, blocks, 1, "diag"), "compact : axe inconnu refuse")

---------------------------------------------------------------------------------------------------
print("== §4 check : validation pure")
---------------------------------------------------------------------------------------------------
local function clone(pat)
  local out = { w = pat.w, h = pat.h, gap = pat.gap, cells = {} }
  for i, c in ipairs(pat.cells) do local d = {} for k, v in pairs(c) do d[k] = v end out.cells[i] = d end -- (copie : l'ordre est sans effet)
  return out
end
local bad = clone(p)
bad.cells[#bad.cells + 1] = { kind = "chest", dx = 0, dy = 2, w = 1, h = 1 }
check(not Mp.check(bad) and select(2, Mp.check(bad)):find("chevauchement"), "chevauchement detecte : " .. tostring(select(2, Mp.check(bad))))
bad = clone(p)
bad.cells[#bad.cells + 1] = { kind = "chest", dx = 7, dy = 0, w = 1, h = 1 }
check(not Mp.check(bad) and select(2, Mp.check(bad)):find("hors emprise"), "coffre dans le gap : hors emprise")
bad = clone(p)
for i = #bad.cells, 1, -1 do if bad.cells[i].kind == "arm_out" and bad.cells[i].dy == 1 and bad.cells[i].dx == 1 then table.remove(bad.cells, i) end end
check(not Mp.check(bad) and select(2, Mp.check(bad)):find("sans bras de sortie"), "machine sans bras de sortie refusee")
bad = clone(p)
for i = #bad.cells, 1, -1 do if bad.cells[i].kind == "arm_in" and bad.cells[i].dy == 8 and bad.cells[i].dx < 3 then table.remove(bad.cells, i) end end -- (les deux bras, court et long)
check(not Mp.check(bad) and select(2, Mp.check(bad)):find("sans bras d'entr"), "machine sans bras d'entree depuis le corridor refusee")
bad = clone(p)
for _, cl in ipairs(bad.cells) do if cl.kind == "arm_in" and cl.dy == 5 and cl.dx == 1 then cl.dir = Mp.N end end
check(not Mp.check(bad) and select(2, Mp.check(bad)):find("aucun convoyeur"), "bras d'entree retourne : ne prend sur aucun convoyeur")
bad = clone(p)
for _, cl in ipairs(bad.cells) do if cl.kind == "chest" and cl.dy == 0 and cl.dx == 1 then cl.kind = "pole" end end
check(not Mp.check(bad) and select(2, Mp.check(bad)):find("aucun coffre"), "sortie sans coffre refusee")
check(not Mp.check({ w = 3, h = 3, cells = {} }), "aucune machine : refus")
check(not Mp.check(nil) and not Mp.check({}), "rien : refus")

---------------------------------------------------------------------------------------------------
print("== §5 pave_origin : plusieurs blocs par lot, colles")
---------------------------------------------------------------------------------------------------
local lot = { x0 = 100, y0 = 200, x1 = 124, y1 = 224 } -- un lot de 24 (P.LOT)
-- un petit bloc de 3 x 14 avec deux tetes de 3 (emprise 9) deja pose a l'ouest : emprise 100..109
local prev1 = { x0 = 100, y0 = 201, x1 = 109, y1 = 215 }
local need = { w = 3, h = 14, lead = { x0 = -3, y0 = 0, x1 = 6, y1 = 14 } }
o = assert(Mp.pave_origin(prev1, need, lot, 1, 1))
check(o.axis == "x" and o.x == 113 and o.y == 201, "second bloc colle a l'est : emprise 110..118, corps en 113 (" .. tostring(o.x) .. ")")
check(o.x + need.lead.x0 == prev1.x1 + 1, "gap exactement 1 entre les deux emprises")
-- un troisieme ne tient plus a l'est (119 + 9 = 128 > 124) : au sud, si la hauteur le permet
local prev2 = { x0 = 100, y0 = 201, x1 = 119, y1 = 215 }
local o3, why3 = Mp.pave_origin(prev2, need, lot, 1, 1)
check(not o3 and why3:find("lot plein"), "troisieme bloc : ni a l'est ni au sud (14 + 1 + 14 > 24) : " .. tostring(why3))
local short = { w = 3, h = 6, lead = { x0 = -3, y0 = 0, x1 = 6, y1 = 6 } }
o = assert(Mp.pave_origin(prev2, short, lot, 1, 1))
check(o.axis == "y" and o.y == 216 and o.x == 103, "bloc bas : au sud, colle (y = 216), corps a 3 de l'emprise")
-- le bloc de la mesure : 11 x 14, tetes de 3 de chaque cote (17) : jamais deux dans un lot de 24
local big = { w = 11, h = 14, lead = { x0 = -3, y0 = 0, x1 = 14, y1 = 14 } }
local prev_big = { x0 = 104, y0 = 201, x1 = 121, y1 = 215 }
local ob, whyb = Mp.pave_origin(prev_big, big, lot, 1, 1)
check(not ob and whyb:find("lot plein"), "bloc 11 x 14 a tetes : un seul par lot de 24 (" .. tostring(whyb) .. ")")
check(not pcall(Mp.pave_origin, prev1, need, lot, 3, 1), "pavage : gap 3 refuse")
check(not pcall(Mp.pave_origin, prev1, { w = 3 }, lot, 1, 1), "pavage : need sans h refuse")
-- marge : le corps respecte la marge, les tetes peuvent toucher le bord
local edge = { x0 = 100, y0 = 200, x1 = 112, y1 = 224 }
o = assert(Mp.pave_origin({ x0 = 100, y0 = 201, x1 = 101, y1 = 215 }, { w = 3, h = 14, lead = { x0 = -3, y0 = 0, x1 = 6, y1 = 14 } }, edge, 1, 1))
check(o.x == 105 and o.x + 6 == 111, "tetes jusqu'au bord, corps a plus d'une tuile")
local oo = Mp.pave_origin({ x0 = 100, y0 = 201, x1 = 103, y1 = 215 }, { w = 3, h = 14, lead = { x0 = -3, y0 = 0, x1 = 6, y1 = 14 } }, edge, 1, 1)
check(not oo, "une tuile de trop : refus")

---------------------------------------------------------------------------------------------------
print("== §6 cablage : script/team/build.lua")
---------------------------------------------------------------------------------------------------
local B = read("script/team/build.lua")
check(B:find('require("shared.team.mall_paving")', 1, true), "build.lua charge le module")
check(B:find("Mp.pave_origin_dir(", 1, true), "place_module epingle l'origine par Mp.pave_origin_dir (lot MALL-DIRECTIONS : du cote ou la serie avance, Mp.pave_origin vers l'est)")
check(B:find("function Build.Pave.owner(", 1, true) and B:find("Build.Pave.owner(b, l.used)", 1, true), "candidates : un lot pris par un bloc de mall reste candidat")
check(B:find("Build.Pave.GEN[g.gen]", 1, true), "seul un bloc ou une cellule de mall pave un lot")
check(B:find("fopts.within = {", 1, true), "P.fit n'essaie que la place collee (within)")
check(B:find("main.pave", 1, true) and B:find("b.lots[main.lot].used = main.pave", 1, true), "le lot reste au nom de son premier bloc")
check(B:find("c.l.bad = (c.l.bad or 0) + (c.pave and 0 or 1)", 1, true), "un lot plein pour le pavage n'est pas un mauvais lot")
check(B:find("Build.Pave.want = Build.Pave.GEN[g.gen]", 1, true) and B:find("local pave = Build.Pave.want\n  Build.Pave.want = nil", 1, true), "candidates consomme le signal du pavage (aucun autre appelant ne le voit)")
-- fonctions courtes : chaque fonction ajoutee tient en moins de 80 lignes
for _, fn in ipairs({ "function Build.Pave.owner(", "function Build.Pave.box(", "function Build.Pave.pin(", "local function candidates(", "local function place_module(" }) do
  local s = B:find(fn, 1, true)
  local e = s and B:find("\nend\n", s, true)
  local n = 0
  if s and e then for _ in B:sub(s, e):gmatch("\n") do n = n + 1 end end
  check(s and e and n < 80, fn .. " : " .. tostring(n) .. " lignes (< 80)")
end
-- aucun pairs nouveau dans les crochets du pavage
for _, fn in ipairs({ "function Build.Pave.owner(", "function Build.Pave.box(", "function Build.Pave.pin(" }) do
  local s = B:find(fn, 1, true)
  local e = s and B:find("\nend\n", s, true)
  check(s and e and not B:sub(s, e):find("[^i]pairs%("), fn .. " : aucun pairs")
end
check(not SRC:find("game%."), "le module est pur (aucune API du jeu)")
check(not SRC:find('"assembling%-machine') and not SRC:find('"small%-electric%-pole') and not SRC:find('"iron%-chest') and not SRC:find('"transport%-belt'), "aucun nom d'objet en dur")

---------------------------------------------------------------------------------------------------
print("== §6 bis cablage de la serie (lot MALL-RUE) : sources, puis les crochets de build.lua joues hors jeu")
---------------------------------------------------------------------------------------------------
check(B:find("GEN = { bloc = true, patron = true, ruban = true }", 1, true), "build.lua : le ruban pave un lot comme un bloc")
check(B:find("Build.Pave.try_serie(f, surface, g, c, fopts, kind_states,", 1, true), "place_module : la serie est essayee quand le lot est plein")
check(B:find("if place.fed and place.fed[port.ent] then", 1, true), "plan_feed : aucune tete sur le port servi par le souterrain")
check(B:find("Build.Pave.cross(f, p, main, reserve_tiles)", 1, true), "plan_project : les pieces du franchissement entrent dans le projet")
check(B:find("part = part, type = e.type }", 1, true), "inst_entities : le type (entree/sortie) d'un souterrain suit l'entite")
check(B:find('type = "input", role = "serie-souterrain"', 1, true) and B:find('type = "output", role = "serie-souterrain"', 1, true), "cross : entree et sortie du souterrain typees")
do
  local ps, pe = B:find("Build.Pave = {", 1, true), B:find("\nlocal function candidates(", 1, true)
  check(B:find("Build.Trav.underground(f, belt)", 1, true) and ps and pe and not B:sub(ps, pe):find("underground%-belt") and not B:sub(ps, pe):find("transport%-belt"),
    "serie : souterrain du palier debloque (portee lue aux donnees), aucun nom de tapis ni de souterrain en dur dans Build.Pave")
end
check(B:find('"serie arretee : lot occupe (', 1, true), "serie : arret propre quand le lot suivant est pris")
local PL = read("shared/team/plan.lua")
check(PL:find("function P.port_room(inst, fan, skip)", 1, true) and PL:find("P.port_room(inst0, opts.fan, opts.fed)", 1, true), "plan.lua : P.fit ne reserve pas de tete pour un port servi (opts.fed)")
local IND = read("script/ai3/industrie.lua")
check(IND:find("function Ind.ruban_wanted(st, cands, width)", 1, true) and IND:find("Mp.compact(blocks, Mp.GAP).w > Pt.LOT", 1, true), "industrie.lua : le ruban quand la demande (Mp.compact) depasse le lot")
check(IND:find('(ruban and "ruban" or "bloc")', 1, true) and IND:find('if not g and gen == "ruban" then gen = "bloc"', 1, true), "industrie.lua : gabarit ruban, repli sur le bloc")
check(IND:find("local BLOC_GEN = { bloc = true, ruban = true }", 1, true), "industrie.lua : le ruban est un bloc pour la collecte et les barres")
local MOD = read("shared/team/modules.lua")
check(MOD:find('"patron", "bloc", "ruban" }', 1, true) and MOD:find("function G.ruban(machine, recettes, kit, barre)", 1, true), "modules.lua : generateur ruban")
for _, fn in ipairs({ "function Build.Pave.serie(", "function Build.Pave.try_serie(", "function Build.Pave.cross(", "function Build.Pave.last(", "function Build.Pave.rank(", "local function place_module(" }) do
  local s = B:find(fn, 1, true)
  local e = s and B:find("\nend\n", s, true)
  local n = 0
  if s and e then for _ in B:sub(s, e):gmatch("\n") do n = n + 1 end end
  check(s and e and n < 80, fn .. " : " .. tostring(n) .. " lignes (< 80)")
end
for _, fn in ipairs({ "function Build.Pave.serie(", "function Build.Pave.cross(", "function Build.Pave.last(", "function Build.Pave.rank(", "function Build.Pave.say(", "function Build.Pave.belt_of(" }) do
  local s = B:find(fn, 1, true)
  local e = s and B:find("\nend\n", s, true)
  check(s and e and not B:sub(s, e):find("[^i]pairs%("), fn .. " : aucun pairs")
end
-- les crochets de build.lua, extraits et joues sur un gabarit ruban reel : la section suivante de l'autre cote de la rue
do
  local s0 = B:find("Build.Pave = {", 1, true)
  local e0 = B:find("\nlocal function candidates(", s0, true)
  local M = require("shared.team.modules")
  local P = require("shared.team.plan")
  local Pm = require("shared.team.patrons")
  local LOGS = {}
  local env = setmetatable({ log = function(t) LOGS[#LOGS + 1] = t end }, { __index = _G })
  local Build = { Trav = { underground = function() return { name = "souterrain-t", maxd = 5 } end } }
  local function sorted_keys(t) local ks = {} for k in pairs(t) do ks[#ks + 1] = k end table.sort(ks) return ks end
  local chunk = assert(load("local M, P, sorted_keys, Build = ...\n" .. B:sub(s0, e0), "=build.lua(Pave)", "t", env))
  chunk(M, P, sorted_keys, Build)
  check(Build.Pave and Build.Pave.serie and Build.Pave.try_serie and Build.Pave.cross, "crochets Build.Pave charges hors jeu")
  local cat = "cat-serie"
  Pm.declare(M, "machine-serie", { kind = "assembler", w = 3, h = 3, speed = 1, categories = { cat } })
  local function rec(name, ins) local l = {} for i, v in ipairs(ins) do l[i] = { name = v, amount = 1 } end return { name = name, category = cat, energy = 20, ingredients = l, products = { { name = name .. "-o", amount = 1 } } } end
  local KIT = { bras = "inserter", bras_long = "long-handed-inserter", tapis = "transport-belt", coffre = "wooden-chest" }
  local g = assert(Pm.ruban(M, "machine-serie", { rec("s1", { "a", "b", "c" }), rec("s2", { "a", "c" }), rec("s3", { "b" }), rec("s4", { "c" }), rec("s5", { "a" }) }, KIT, 4))
  -- treillis : lat = (12, 12) -> lot 0:0 en x = 0..23, rue 24..27, lot 1:0 en 28..51 ; section 1 (projet 1) posee en (4, 3), corps 4..14
  local function world()
    local b = { lat = { ox = 12, oy = 12 }, occ = {}, projects = {}, lots = {
      ["0:0"] = { i = 0, j = 0, state = "libre", used = 1 }, ["1:0"] = { i = 1, j = 0, state = "libre" }, ["2:0"] = { i = 2, j = 0, state = "gisement", used = 7 } } }
    b.projects[1] = { id = 1, spec = { gen = "ruban" }, parts = { { kind = "module", lot = "0:0", key = g.key, ox = 4, oy = 3, w = g.w, h = g.h, k = 0 } },
      ents = { { name = "transport-belt", x = 4.5, y = 10.5, dir = 2 } } }
    return { key = "equipe-t", build = b }, b
  end
  local f, b = world()
  local c = { k = "0:0", l = b.lots["0:0"] }
  local sr, why = Build.Pave.serie(f, b, c, g, { libre = true })
  check(sr ~= nil, "serie : rendue (" .. tostring(why) .. ")")
  check(sr and sr.k2 == "1:0" and sr.within.x0 == 29 and sr.within.y0 == 3 and sr.within.x1 == 40, "serie : lot suivant 1:0, corps epingle en x = 29 (a 1 de la rue), meme ligne")
  local t1 = sr and sr.trav.res.traversees[1]
  check(t1 and t1.entree.x == 23 and t1.sortie.x == 28 and t1.entree.y == 3 + g.ruban.belts[1] and #t1.rallonge == 8 and t1.rallonge[1].x == 15, "serie : entree au bord du lot (23), sortie au bord du suivant (28), sur la ligne du convoyeur A, rallonge 15..22")
  check(sr and sr.trav.ug.name == "souterrain-t" and sr.trav.belt == "transport-belt" and sr.owner == 1, "serie : souterrain du palier, tapis du gabarit, lot au nom du ruban 1")
  -- lot suivant occupe par autre chose : arret propre
  local f2, b2 = world(); b2.lots["1:0"].used = 42
  local sn, nwhy = Build.Pave.serie(f2, b2, { k = "0:0", l = b2.lots["0:0"] }, g, { libre = true })
  check(sn == nil and nwhy:find("serie arretee : lot occupe", 1, true) and nwhy:find("projet 42", 1, true), "lot suivant pris par un autre projet : « serie arretee : lot occupe » (" .. tostring(nwhy) .. ")")
  local f3, b3 = world(); b3.lots["1:0"].state = "gisement"
  check(select(2, Build.Pave.serie(f3, b3, { k = "0:0", l = b3.lots["0:0"] }, g, { libre = true })):find("lot occupe", 1, true), "lot suivant gisement : arret propre")
  -- portee insuffisante, aucun souterrain
  Build.Trav.underground = function() return { name = "court", maxd = 4 } end
  check(select(2, Build.Pave.serie(f, b, c, g, { libre = true })):find("portee insuffisante", 1, true), "souterrain trop court pour la rue : refus ecrit")
  Build.Trav.underground = function() return nil end
  check(select(2, Build.Pave.serie(f, b, c, g, { libre = true })):find("aucun souterrain", 1, true), "aucun souterrain debloque : refus ecrit")
  Build.Trav.underground = function() return { name = "souterrain-t", maxd = 5 } end
  -- un bloc ordinaire ne fait pas de serie
  check(select(2, Build.Pave.serie(f, b, c, { gen = "bloc" }, { libre = true })):find("sans corridor", 1, true), "un bloc sans corridor : pas de serie")
  -- try_serie : placement dans le lot suivant, port servi sans tete, passage controle
  local free = function() return true end
  local fopts = { free = free, margin = 1, toward = { x = 0, y = 0 } }
  local scan = function() return { free = free } end
  local pl, pwhy = Build.Pave.try_serie(f, nil, g, c, fopts, { libre = true }, scan)
  check(pl ~= nil, "try_serie : placement rendu (" .. tostring(pwhy) .. ")")
  check(pl and pl.ox == 29 and pl.oy == 3 and pl.lot == "1:0" and pl.k == 0 and pl.pave == 1 and pl.lot_from == "0:0", "try_serie : section en (29, 3) dans le lot 1:0, au nom du ruban 1")
  check(pl and pl.fed and pl.fed[g.ruban.port] == true and pl.serie and pl.serie.res, "try_serie : le port du convoyeur A est servi (aucune tete), la traversee suit le placement")
  -- sans `fed`, la tete du port ouest tomberait sur la rue : P.fit refuse ; avec, il accepte
  local inst0 = M.instantiate(g, 0, 0, 0)
  check(#P.port_room(inst0, nil, { [g.ruban.port] = true }) < #P.port_room(inst0, nil), "P.port_room : aucune tuile de tete pour le port servi")
  check(P.fit(g, sr.rect2, { free = free, margin = 1, within = sr.within }) == nil, "P.fit sans fed : la tete ouest (sur la rue) fait refuser la place epinglee")
  local fit = P.fit(g, sr.rect2, { free = free, margin = 1, within = sr.within, fed = { [g.ruban.port] = true } })
  check(fit and fit.ox == 29 and fit.oy == 3, "P.fit avec fed : la place epinglee est acceptee")
  local f4, b4 = world(); b4.occ[P.tkey(23, 10)] = 9
  local po, owhy = Build.Pave.try_serie(f4, nil, g, { k = "0:0", l = b4.lots["0:0"] }, fopts, { libre = true }, scan)
  check(po == nil and owhy:find("passage du corridor occupe en (23, 10)", 1, true), "try_serie : l'entree du souterrain deja reservee : refus ecrit")
  -- cross : les pieces du franchissement dans le projet de la section 2, journal
  local p2 = { id = 2, spec = { gen = "ruban" }, parts = { { kind = "module", lot = "1:0", key = g.key, ox = 29, oy = 3, w = g.w, h = g.h, k = 0 } },
    ents = { { name = "transport-belt", x = 29.5, y = 10.5, dir = 2 } } }
  b.projects[2] = p2
  b.lots["1:0"].used = 1
  local got
  local okc, cwhy = Build.Pave.cross(f, p2, pl, function(_, _, list) got = list return true end)
  check(okc == true and got and #got == 10, "cross : 8 tapis de rallonge + entree + sortie (" .. tostring(cwhy) .. ", " .. tostring(got and #got) .. ")")
  local ins, outs, belts_n = nil, nil, 0
  for _, e in ipairs(got or {}) do
    if e.type == "input" then ins = e elseif e.type == "output" then outs = e elseif e.name == "transport-belt" then belts_n = belts_n + 1 end
  end
  check(ins and ins.name == "souterrain-t" and ins.x == 23.5 and ins.y == 10.5 and ins.dir == 2 and ins.part == 1, "cross : entree du souterrain en (23, 10), vers l'est, partie 1")
  check(outs and outs.x == 28.5 and outs.y == 10.5 and outs.dir == 2, "cross : sortie du souterrain en (28, 10), vers l'est")
  check(belts_n == 8 and got[1].x == 15.5 and got[1].dir == 2, "cross : la rallonge part de la fin du corridor (15) vers l'est")
  check(p2.parts[1].serie and p2.parts[1].serie.voies == 1 and p2.parts[1].serie.lot_from == "0:0", "cross : la partie garde la traversee (1 voie, depuis le lot 0:0)")
  check(LOGS[#LOGS] and LOGS[#LOGS]:find("[FO-MALL] equipe-t : serie : section 2 posee de l'autre cote de la rue (lot 1:0), corridor en souterrain (1 voies)", 1, true),
    "journal : « serie : section 2 posee de l'autre cote de la rue (lot 1:0), corridor en souterrain (1 voies) » (" .. tostring(LOGS[#LOGS]) .. ")")
  check(Build.Pave.cross(f, p2, pl, function() return false end) == false, "cross : place prise : refus")
  -- la section 3 : le lot 1:0 (au nom du ruban) est candidat, plein : serie depuis 1:0 vers 2:0, qui est un gisement : arret
  local s3, w3 = Build.Pave.serie(f, b, { k = "1:0", l = b.lots["1:0"] }, g, { libre = true })
  check(s3 == nil and w3:find("serie arretee : lot occupe (2:0 : gisement, projet 7)", 1, true), "section 3 : le lot 2:0 est un gisement : « serie arretee : lot occupe » (" .. tostring(w3) .. ")")
  -- depuis le lot 0:0, le lot 1:0 est deja pave par la section 2 : pas de doublon
  check(select(2, Build.Pave.serie(f, b, c, g, { libre = true })):find("deja pave", 1, true), "depuis le lot 0:0 : le lot 1:0 est deja pave, aucune seconde section")
end

---------------------------------------------------------------------------------------------------
print("== §7 mutants du module")
---------------------------------------------------------------------------------------------------
local function mutant(label, from, to, probe)
  local i, j = SRC:find(from, 1, true) -- (substitution LITTÉRALE : les crochets et parenthèses du source ne sont pas des motifs)
  if not check(i and not SRC:find(from, j + 1, true), "mutant « " .. label .. " » : source trouvee une fois") then return end
  local s = SRC:sub(1, i - 1) .. to .. SRC:sub(j + 1)
  local ok, M2 = pcall(load_mp, s)
  if not ok then pass = pass + 1 return end -- un mutant qui ne charge plus est refuse
  local caught = not pcall(probe, M2) or probe(M2) == false
  check(caught, "mutant « " .. label .. " » refuse par la batterie")
end
-- 1. gap ignore : next_offset colle toujours a 0
mutant("gap ignoré", "if axis == \"x\" then return { x = b.x1 + gap, y = b.y0 } end", "if axis == \"x\" then return { x = b.x1, y = b.y0 } end",
  function(M2) return M2.next_offset({ x0 = 0, y0 = 0, x1 = 7, y1 = 14 }, "x", 1).x == 8 end)
-- 2. gap > 2 accepte (l'espacement mort revient)
mutant("gap > 2 accepté", "gap < 0 or gap > Mp.GAP_MAX", "gap < 0", function(M2) return not pcall(M2.next_offset, { x0 = 0, y0 = 0, x1 = 7, y1 = 14 }, "x", 20) end)
-- 3. chevauchement non detecte
mutant("chevauchement non détecté", "if occ[k] then return nil, string.format(\"chevauchement", "if false then return nil, string.format(\"chevauchement",
  function(M2) local q = M2.pattern({ asm = { w = 3, h = 3 }, n = 2 }); q.cells[#q.cells + 1] = { kind = "chest", dx = 0, dy = 2, w = 1, h = 1 }; return M2.check(q) == false end)
-- 4. sortie manquante acceptee
mutant("sortie manquante acceptée", "if not out[m] then return false", "if false then return false",
  function(M2) local q = M2.pattern({ asm = { w = 3, h = 3 }, n = 2 }); for i = #q.cells, 1, -1 do if q.cells[i].kind == "arm_out" then table.remove(q.cells, i) end end; return M2.check(q) == false end)
-- 5. offset decale : compact oublie le gap
mutant("offset décalé", "if i > 1 then along = along + gap end", "", function(M2) return M2.compact({ { w = 11, h = 14 }, { w = 7, h = 14 } }, 1).w == 19 end)
-- 6. poteau dans la machine : le pattern ne passe plus check
mutant("poteau dans la machine", 'add("pole", x0 + mw, r.asm_n + floor(mh / 2))', 'add("pole", x0, r.asm_n + floor(mh / 2))',
  function(M2) return M2.check(M2.pattern({ asm = { w = 3, h = 3 }, n = 2 })) == true end)
-- 7. pavage sans debords : la tete ouest mord sur le bloc precedent
mutant("pavage sans débords", "local o = { x = fo.x - lead.x0, y = fo.y - lead.y0, axis = axis }", "local o = { x = fo.x, y = fo.y - lead.y0, axis = axis }",
  function(M2) return M2.pave_origin(prev1, need, lot, 1, 1).x == 113 end)
-- 8. entree manquante acceptee
mutant("entrée manquante acceptée", "if not fed[m] then return false", "if false then return false",
  function(M2) local q = M2.pattern({ asm = { w = 3, h = 3 }, n = 2 }); for i = #q.cells, 1, -1 do if q.cells[i].kind == "arm_in" then table.remove(q.cells, i) end end; return M2.check(q) == false end)

---------------------------------------------------------------------------------------------------
print("== §8 serie : la section suivante de l'autre cote de la rue, corridor en souterrain")
---------------------------------------------------------------------------------------------------
-- grille du treillis : lots de 24 à pas 28 (rue de 4), lot 0 en x = 0..23, rue 24..27, lot 1 en 28..51
local LOTS = { pitch = 28, lot = 24, ox = 0, oy = 0 }
local RUE = { w = 4, underground_reach = 5 } -- souterrain de base : écart 5 au plus
-- une section de 11 x 14 (le bloc de la mesure), corridor sur la ligne 7 (le second convoyeur) ; corps en x = 4..14 (têtes à l'ouest)
local s1 = { x = 4, y = 3, w = 11, h = 14, belts = { 7 } }
local sr, swhy = Mp.serie(s1, 2, "x", LOTS, 1, RUE)
check(sr ~= nil, "serie de 2 : rendue (" .. tostring(swhy) .. ")")
check(sr and #sr.sections == 2 and sr.sections[1].x == 4 and sr.sections[1].lot.i == 0 and sr.sections[1].lot.j == 0, "section 1 a l'origine, lot 0:0")
check(sr and sr.sections[2].x == 29 and sr.sections[2].y == 3 and sr.sections[2].lot.i == 1, "section 2 de l'autre cote de la rue : corps en x = 29 (lot 1, a 1 de la rue), meme ligne")
check(sr and #sr.traversees == 1 and sr.traversees[1].voie == 7 and sr.traversees[1].section == 2, "une traversee par voie du corridor, vers la section 2")
local tv = sr and sr.traversees[1]
check(tv and tv.entree.x == 23 and tv.entree.y == 10 and tv.sortie.x == 28 and tv.sortie.y == 10, "entree sur la derniere tuile du lot (23), sortie sur la premiere du suivant (28), sur la ligne du convoyeur")
check(tv and tv.ecart == 5 and tv.dir == Mp.E, "ecart 5 = rue + 1, vers l'est")
check(tv and #tv.rallonge == 8 and tv.rallonge[1].x == 15 and tv.rallonge[8].x == 22, "rallonge de la fin du corridor (15) a l'entree exclue (22)")
check(sr and #sr.raccords == 0, "aucun raccord : les deux sections sont dans deux lots")
check(sr and Mp.check_serie(sr, LOTS, RUE) == true, "la serie passe sa verification : " .. tostring((select(2, Mp.check_serie(sr, LOTS, RUE)))))
-- portee insuffisante : refus ecrit, rien n'est pose sur la rue
local sn, nwhy = Mp.serie(s1, 2, "x", LOTS, 1, { w = 4, underground_reach = 4 })
check(sn == nil and nwhy:find("portee insuffisante"), "portee 4 pour une rue de 4 (ecart 5) : refus ecrit (" .. tostring(nwhy) .. ")")
local su, uwhy = Mp.serie(s1, 2, "x", LOTS, 1, 4)
check(su == nil and uwhy:find("portee inconnue"), "rue sans portee : refus ecrit")
check(Mp.serie(s1, 2, "x", LOTS, 1, { w = 4, underground_reach = 7 }) ~= nil, "souterrain rapide (7) : passe")
-- petites sections : trois dans le meme lot, collees, raccords sur le gap ; la quatrieme franchit
local sp = assert(Mp.serie({ x = 1, y = 3, w = 5, h = 14, belts = { 6, 7 } }, 4, "x", LOTS, 1, RUE))
check(sp.sections[2].x == 7 and sp.sections[3].x == 13 and sp.sections[3].lot.i == 0, "sections 2 et 3 collees dans le lot 0 (7, 13)")
check(sp.sections[4].x == 29 and sp.sections[4].lot.i == 1, "section 4 (19..23 ne tient pas a 1 de la rue) de l'autre cote")
check(#sp.raccords == 4 and sp.raccords[1].x == 6 and sp.raccords[1].y == 9 and sp.raccords[1].voie == 6, "raccords : 2 gaps x 2 voies, le premier en (6, 9)")
check(#sp.traversees == 2 and sp.traversees[2].voie == 7 and sp.traversees[2].entree.y == 10, "deux souterrains (2 voies), le second sur la ligne 10")
check(Mp.check_serie(sp, LOTS, RUE) == true, "serie de 4 valide : " .. tostring((select(2, Mp.check_serie(sp, LOTS, RUE)))))
-- sections de tailles differentes (liste), axe y, grille decalee
local LY = { pitch = 28, lot = 24, ox = -12, oy = -12 }
local sy = assert(Mp.serie({ x = -5, y = -11, w = 14, h = 11, belts = { 6 } }, { { w = 14, h = 11 }, { w = 14, h = 12 } }, "y", LY, 1, RUE))
check(sy.sections[2].y == 17 and sy.sections[2].x == -5 and sy.sections[2].lot.j == 1 and sy.sections[2].lot.i == 0, "axe y : section 2 (12 de haut : 1..12 mordrait la marge) en y = 17 (lot 0:1), meme colonne")
check(sy.traversees[1].entree.y == 11 and sy.traversees[1].sortie.y == 16 and sy.traversees[1].entree.x == 1 and sy.traversees[1].dir == Mp.S, "axe y : entree en y = 11, sortie en 16, colonne du convoyeur (x = 1), vers le sud")
check(Mp.check_serie(sy, LY, RUE) == true, "axe y valide : " .. tostring((select(2, Mp.check_serie(sy, LY, RUE)))))
-- refus et contrats
check(select(2, Mp.serie({ x = 20, y = 3, w = 11, h = 14 }, 2, "x", LOTS, 1, RUE)):find("section 1"), "section 1 a cheval sur la rue : refus")
check(not pcall(Mp.serie, s1, 2, "x", { pitch = 24, lot = 24 }, 1, RUE), "grille sans rue : erreur de contrat")
check(not pcall(Mp.serie, s1, 2, "x", LOTS, 1, { w = 9, underground_reach = 20 }), "rue plus large que le pas moins le lot : erreur de contrat")
check(not pcall(Mp.serie, s1, 2, "z", LOTS, 1, RUE), "axe inconnu : erreur de contrat")
check(not pcall(Mp.serie, s1, 0, "x", LOTS, 1, RUE), "n = 0 : erreur de contrat")
check(not pcall(Mp.serie, s1, 2, "x", LOTS, 3, RUE), "gap 3 : erreur de contrat")
-- determinisme
local sa, sb = Mp.serie(s1, 3, "x", LOTS, 1, RUE), Mp.serie(s1, 3, "x", LOTS, 1, RUE)
check(sa and sb and sa.sections[3].x == sb.sections[3].x and sa.sections[3].x == 57, "deterministe : section 3 en 57 (lot 2) les deux fois")

---------------------------------------------------------------------------------------------------
print("== §9 check_serie : rien sur la rue, aucun chevauchement, corridor continu")
---------------------------------------------------------------------------------------------------
local function cs(res) local out = {} for k, v in pairs(res) do out[k] = v end return out end -- (copie superficielle : l'ordre est sans effet)
local bad_s = cs(sr); bad_s.sections = { sr.sections[1], { x = 24, y = 3, w = 11, h = 14, lot = { i = 1, j = 0 } } }
check(not Mp.check_serie(bad_s, LOTS, RUE) and select(2, Mp.check_serie(bad_s, LOTS, RUE)):find("sur la rue"), "section posee sur la rue : refus")
bad_s = cs(sr); bad_s.sections = { sr.sections[1], { x = 10, y = 3, w = 11, h = 14, lot = { i = 0, j = 0 } } }
check(select(2, Mp.check_serie(bad_s, LOTS, RUE)):find("chevauchent"), "sections qui se chevauchent : refus")
bad_s = cs(sr); bad_s.traversees = {}
check(select(2, Mp.check_serie(bad_s, LOTS, RUE)):find("corridor coupe"), "sans souterrain : corridor coupe")
bad_s = cs(sr); bad_s.traversees = { { entree = { x = 23, y = 10 }, sortie = { x = 28, y = 10 }, voie = 7, dir = Mp.E, ecart = 5, rallonge = {} } }
check(select(2, Mp.check_serie(bad_s, LOTS, RUE)):find("corridor coupe en %(15, 10%)"), "sans rallonge : corridor coupe juste apres la section 1")
bad_s = cs(sr); bad_s.traversees = { { entree = { x = 22, y = 10 }, sortie = { x = 28, y = 10 }, voie = 7, rallonge = tv.rallonge } }
check(select(2, Mp.check_serie(bad_s, LOTS, RUE)):find("entree hors du bord"), "entree avant le bord du lot : refus")
bad_s = cs(sr); bad_s.traversees = { { entree = { x = 23, y = 10 }, sortie = { x = 29, y = 10 }, voie = 7, rallonge = tv.rallonge } }
check(select(2, Mp.check_serie(bad_s, LOTS, RUE)):find("sortie hors du bord"), "sortie au-dela du bord du lot suivant : refus")
check(select(2, Mp.check_serie(sr, LOTS, { w = 4, underground_reach = 4 })):find("hors de la portee"), "portee trop courte pour la traversee rendue : refus")
bad_s = cs(sr); bad_s.raccords = { { x = 25, y = 10, voie = 7 } }
check(select(2, Mp.check_serie(bad_s, LOTS, RUE)):find("raccord sur la rue"), "raccord sur la rue : refus")
check(not Mp.check_serie(nil, LOTS, RUE) and not Mp.check_serie({ sections = {} }, LOTS, RUE), "serie vide : refus")

-- mutants de la serie
-- 9. section posee sur la rue : le test de place dans le lot oublie le bord
mutant("section posée sur la rue", "if start + sz[A.w] <= lot_end - Mp.MARGE then", "if true then",
  function(M2) local r = M2.serie(s1, 2, "x", LOTS, 1, RUE); return r ~= nil and r.sections[2].x == 29 and M2.check_serie(r, LOTS, RUE) == true end)
-- 10. portee ignoree : la rue est franchie quelle que soit la portee
mutant("portée ignorée", "if ecart > S.reach or ecart < 2 then return nil", "if false then return nil",
  function(M2) return M2.serie(s1, 2, "x", LOTS, 1, { w = 4, underground_reach = 4 }) == nil end)
-- 11. corridor coupe : plus de rallonge jusqu'a l'entree
mutant("corridor coupé", "for a = prev_end, a_in - 1 do t.rallonge[#t.rallonge + 1] = pt(A, a, c0 + bk) end", "",
  function(M2) local r = M2.serie(s1, 2, "x", LOTS, 1, RUE); return r ~= nil and #r.traversees[1].rallonge == 8 and M2.check_serie(r, LOTS, RUE) == true end)
-- 12. la verification laisse passer un corridor coupe
mutant("vérification sans continuité", "if not section_at(res, A, a, c) and not (cover[bk] and cover[bk][a]) then", "if false then",
  function(M2) local r = cs(M2.serie(s1, 2, "x", LOTS, 1, RUE)); r.traversees = {}; return M2.check_serie(r, LOTS, RUE) == false end)
-- 13. la verification laisse une section sur la rue
mutant("vérification sans la rue", "return false, string.format(\"section %d sur la rue en (%d, %d)\", idx, s.x, s.y)", "",
  function(M2) local r = cs(M2.serie(s1, 2, "x", LOTS, 1, RUE)); r.sections = { r.sections[1], { x = 24, y = 3, w = 11, h = 14, lot = { i = 1, j = 0 } } }; return M2.check_serie(r, LOTS, RUE) == false end)

print(string.format("[MALL-PAVAGE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
