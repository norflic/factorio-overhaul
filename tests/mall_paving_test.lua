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
    §6 câblage (source de build.lua) : crochets présents, aucun `pairs` nouveau, fonctions courtes ;
    §7 MUTANTS du module (substitution du source) : gap ignoré, chevauchement non détecté, sortie manquante acceptée, offset décalé,
       poteau dans la machine, pavage sans débords.
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
check(B:find("Mp.pave_origin(", 1, true), "place_module epingle l'origine par Mp.pave_origin")
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

print(string.format("[MALL-PAVAGE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
