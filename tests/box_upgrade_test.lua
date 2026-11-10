--[[
  Lot BOX-UPGRADE (directive du DC du 9/11) : rétrofit incrémental des boxes.
    §1 shared/team/box_upgrade.lua (pur) : ordre sortie -> machine -> entree dans une tranche ; tranche = 2 machines + leurs bras ;
       sorties orphelines d'abord ; can_place faux -> ajourné, la tranche continue sans lui ; kit insuffisant -> waiting, aucune tranche ;
       kit partiel -> première tranche émise, attente sur la suivante ; MAXED quand plus rien ; next avance (nouvel état) ;
       déterminisme (mêmes unités dans un autre ordre : même plan) ; ligne [FO-RETROFIT] ;
    §2 mutants (le module rechargé avec UNE retouche) : priorité inversée, ajourné bloquant, kit ignoré, tranche de taille illimitée,
       MAXED jamais atteint : chacun refusé par les MÊMES détecteurs que §1 ;
    §3 câblage textuel : boxes_rt.lua (require, appel à la fin du relevé, « lot BOX-UPGRADE »), capital.lua (replace_entity, unlocked,
       bind), box_upgrade_rt.lua (pas de `global`, pas de require dans une fonction, pas de create_entity : la primitive de capital.lua,
       can_fast_replace et build_check_type, aucun nom de type de machine en dur) ;
    §4 script/team/box_upgrade_rt.lua sur un moteur minimal (capital et stock doublés) : relevé par type, rôles des bras (cible du
       moteur, point de dépôt), tranche 1 (2 machines + bras, ordre d'émission, ajournée), tranche suivante, attente du kit, reprise,
       MAXED et état oublié, menace du QG, une seule box par impulsion, pièce du plan renommée pour la machine seulement, état en données pures.
    §5 lot RETROFIT-GABARITS (DC 10/11, emprises distinctes) : règle pure (Bu.grows, grown_successors, arm_move, fit, deferred_causes,
       ligne « (emprise) ») et ses mutants (emprise ignorée, bras non repositionné) ; moteur : unité qui grandit (2×2 → 3×3) traitée par la
       primitive partagée (swap_entity doublé) quand sa cellule l'accueille, ajournée « emprise » quand un tapis la bloque, bras déplacé
       sur la ligne d'interface, pièce du plan renommée et déplacée ; mutant du moteur « can_place ignoré » (fits court-circuité).
    §6 lot ILOTS-COLONNES (P4 du DC) : îlot à liaisons par colonne sur la règle pure : à cellules réservées (pas de 5, colonne de liaison sur
       la ligne d'interface est), chaque machine grandit de 3×3 à 4×4 sans toucher les bras de liaison (ni déplacés, ni en conflit) ; au
       pas d'avant (4, colonne de liaison dans la future emprise), la première est ajournée « emprise » (le bras de liaison de sa voisine
       est sur sa case) et la seconde aussi (son bras de liaison est poussé sur la machine suivante).
  Usage : lua5.2 tests/box_upgrade_test.lua   (depuis la racine du mod ; moins d'une seconde)
]]
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function section(name) print("== " .. name) end

local Bu = require("shared.team.box_upgrade")

---------------------------------------------------------------------------------------------------
-- Jeux d'unités et détecteurs partagés par §1 et §2
---------------------------------------------------------------------------------------------------
--- Box de `nm` machines (ids 10, 20, 30…), chacune avec un bras d'entrée (id m + 1) et un bras de sortie (id m + 2).
local function box_units(nm, opts)
  opts = opts or {}
  local u = {}
  for i = 1, nm do
    local m = i * 10
    u[#u + 1] = { id = m, role = "machine", tier_now = 1, tier_target = 2, item = "M", machine = nil }
    u[#u + 1] = { id = m + 1, role = "entree", tier_now = 1, tier_target = 2, item = "B", machine = m }
    u[#u + 1] = { id = m + 2, role = "sortie", tier_now = 1, tier_target = 2, item = "B", machine = m }
  end
  for _, o in ipairs(opts.orphans or {}) do u[#u + 1] = o end
  return u
end
local function roles(slice) local r = {} for i, x in ipairs(slice) do r[i] = x.role end return table.concat(r, ",") end
local function ids(slice) local r = {} for i, x in ipairs(slice) do r[i] = x.id end return table.concat(r, ",") end
local BOX = { kind = "fonderie", id = 7 }
local function rich() return { M = 100, B = 100 } end

--- Détecteurs : chaque entrée rend une liste de défauts (vide = conforme). Une règle (ou un mutant) passe par les MÊMES.
local DET = {}
-- (a) ordre dans la tranche : toutes les sorties, puis les machines, puis les entrées ; paire de 2 machines + 4 bras
function DET.ordre(B)
  local p = B.plan(BOX, box_units(3), rich(), { slice = 2 })
  local bad = {}
  local s = p.slices[1]
  if not s then return { "aucune tranche" } end
  if roles(s) ~= "sortie,sortie,machine,machine,entree,entree" then bad[#bad + 1] = "ordre " .. roles(s) end
  if ids(s) ~= "12,22,10,20,11,21" then bad[#bad + 1] = "ids " .. ids(s) end
  local m, b = B.counts(s)
  if m ~= 2 or b ~= 4 then bad[#bad + 1] = "paire " .. m .. "/" .. b end
  if #p.slices ~= 2 or p.total ~= 2 then bad[#bad + 1] = "nombre de tranches " .. #p.slices .. "/" .. p.total end
  if p.slices[2] and ids(p.slices[2]) ~= "32,30,31" then bad[#bad + 1] = "tranche 2 " .. ids(p.slices[2]) end
  return bad
end
-- (b) taille : jamais plus de 4 machines par tranche, même avec un cfg.slice démesuré ; 2 par défaut
function DET.taille(B)
  local bad = {}
  for _, cfg in ipairs({ { slice = 2 }, { slice = 4 }, { slice = 50 }, nil }) do
    local p = B.plan(BOX, box_units(12), rich(), cfg)
    local want = cfg and math.min(math.max(cfg.slice, 2), 4) or 2
    for i, s in ipairs(p.slices) do
      local m = B.counts(s)
      if m > 4 then bad[#bad + 1] = "tranche " .. i .. " : " .. m .. " machines" end
      if i == 1 and m ~= want then bad[#bad + 1] = "première tranche : " .. m .. " machines pour slice=" .. tostring(cfg and cfg.slice) end
    end
  end
  return bad
end
-- (c) ajournement : une unité can_place == false sort de la tranche (deferred), la tranche continue, le plan reste EN_COURS
function DET.ajourne(B)
  local u = box_units(2)
  u[3].can_place = false -- la sortie de la machine 10
  local p = B.plan(BOX, u, rich(), { slice = 2 })
  local bad = {}
  if #p.deferred ~= 1 or p.deferred[1].id ~= 12 then bad[#bad + 1] = "ajournées " .. #p.deferred end
  local s = p.slices[1]
  if not s then return { "tranche bloquée par l'ajournée" } end
  if ids(s) ~= "22,10,20,11,21" then bad[#bad + 1] = "tranche sans l'ajournée : " .. ids(s) end
  if p.status ~= "EN_COURS" then bad[#bad + 1] = "statut " .. tostring(p.status) end
  for _, x in ipairs(s) do if x.can_place == false then bad[#bad + 1] = "ajournée émise" end end
  return bad
end
-- (d) kit : insuffisant -> aucune tranche, waiting ; partiel -> première tranche émise, attente sur la suivante ; le kit n'est pas débité
function DET.kit(B)
  local bad = {}
  local p = B.plan(BOX, box_units(2), { M = 1, B = 100 }, { slice = 2 })
  if #p.slices ~= 0 then bad[#bad + 1] = "tranche émise sans kit (" .. #p.slices .. ")" end
  if not (p.waiting and p.waiting.item == "M" and p.waiting.manque == 1) then bad[#bad + 1] = "waiting " .. tostring(p.waiting and p.waiting.item) end
  if p.total ~= 1 then bad[#bad + 1] = "total " .. tostring(p.total) end
  local kit = { M = 2, B = 5 }
  p = B.plan(BOX, box_units(4), kit, { slice = 2 })
  if #p.slices ~= 1 then bad[#bad + 1] = "kit partiel : " .. #p.slices .. " tranches" end
  if not (p.waiting and p.waiting.item == "B" and p.waiting.manque == 3) then bad[#bad + 1] = "kit partiel : attente " .. tostring(p.waiting and p.waiting.item) .. " x" .. tostring(p.waiting and p.waiting.manque) end
  if kit.M ~= 2 or kit.B ~= 5 then bad[#bad + 1] = "kit de l'appelant débité" end
  if p.total ~= 2 then bad[#bad + 1] = "total partiel " .. tostring(p.total) end
  return bad
end
-- (e) MAXED : aucune unité à monter (toutes au palier, ou liste vide) ; une seule à monter : EN_COURS
function DET.maxed(B)
  local bad = {}
  local u = box_units(2)
  for _, x in ipairs(u) do x.tier_target = x.tier_now end
  local p = B.plan(BOX, u, rich(), { slice = 2 })
  if p.status ~= "MAXED" or #p.slices ~= 0 or p.total ~= 0 then bad[#bad + 1] = "au palier : " .. tostring(p.status) end
  p = B.plan(BOX, {}, {}, nil)
  if p.status ~= "MAXED" then bad[#bad + 1] = "liste vide : " .. tostring(p.status) end
  u[5].tier_target = 3
  p = B.plan(BOX, u, rich(), { slice = 2 })
  if p.status ~= "EN_COURS" or #p.slices ~= 1 or ids(p.slices[1]) ~= "21" then bad[#bad + 1] = "une seule à monter : " .. tostring(p.status) end
  return bad
end
local function run_all(B)
  local out = {}
  for _, k in ipairs({ "ordre", "taille", "ajourne", "kit", "maxed" }) do
    for _, d in ipairs(DET[k](B)) do out[#out + 1] = k .. " : " .. d end
  end
  return out
end

---------------------------------------------------------------------------------------------------
section("§1 règle pure shared/team/box_upgrade.lua")
---------------------------------------------------------------------------------------------------
local bad = run_all(Bu)
check(#bad == 0, "détecteurs (a)-(e) sur la règle : " .. table.concat(bad, " | "))

-- sorties orphelines (convoyeur d'évacuation, bras sans machine à monter) : AVANT les paires ; entrées orphelines APRÈS ; poteaux en dernier
local orphans = { { id = 1, role = "sortie", tier_now = 1, tier_target = 2, item = "B" }, { id = 2, role = "entree", tier_now = 1, tier_target = 2, item = "B" },
  { id = 3, role = "poteau", tier_now = 1, tier_target = 2, item = "P" }, { id = 4, role = "sortie", tier_now = 1, tier_target = 2, item = "B", machine = 999 } }
local p = Bu.plan(BOX, box_units(2, { orphans = orphans }), { M = 9, B = 9, P = 9 }, { slice = 2 })
check(#p.slices == 4 and ids(p.slices[1]) == "1,4" and ids(p.slices[2]) == "12,22,10,20,11,21" and ids(p.slices[3]) == "2" and ids(p.slices[4]) == "3",
  "orphelines : sorties d'abord, paires, entrées, poteaux (" .. #p.slices .. " tranches)")

-- un bras dont la machine est déjà au palier reste à monter, comme orphelin (la machine n'est pas une unité)
local u = box_units(1)
u[1].tier_target = 1
p = Bu.plan(BOX, u, rich(), nil)
check(#p.slices == 2 and ids(p.slices[1]) == "12" and ids(p.slices[2]) == "11", "machine au palier : ses bras montent seuls, sortie d'abord")

-- next : nouvel état, index et faits en nombres, l'ancien état intact
local st = { i = 2, n = 5, done = 7, t0 = 100 }
local nx = Bu.next(st, 6)
check(nx.i == 3 and nx.n == 5 and nx.done == 13 and nx.t0 == 100 and st.i == 2 and st.done == 7, "next avance d'une tranche sans toucher l'état donné")
nx = Bu.next(nil, nil)
check(nx.i == 1 and nx.n == 0 and nx.done == 0, "next depuis rien")
for k, v in pairs(nx) do check(type(v) == "number", "état de next : " .. k .. " est un nombre") end

-- déterminisme : mêmes unités, ordre d'entrée renversé, ids mélangés : même plan
local a = box_units(5)
a[#a + 1] = orphans[1]
local b = {}
for i = #a, 1, -1 do b[#b + 1] = a[i] end
local pa, pb = Bu.plan(BOX, a, rich(), { slice = 3 }), Bu.plan(BOX, b, rich(), { slice = 3 })
local same = #pa.slices == #pb.slices and pa.total == pb.total
for i = 1, #pa.slices do if ids(pa.slices[i]) ~= ids(pb.slices[i]) then same = false end end
check(same, "déterminisme : ordre d'entrée sans effet")
-- ids en chaînes et en nombres mêlés : aucune erreur de comparaison
local mixed = { { id = "b", role = "sortie", tier_now = 1, tier_target = 2, item = "B" }, { id = 5, role = "sortie", tier_now = 1, tier_target = 2, item = "B" } }
check(pcall(Bu.plan, BOX, mixed, rich(), nil), "ids de types mêlés : pas d'erreur")

-- ligne [FO-RETROFIT]
local line = Bu.line("eq1", { kind = "mall", id = 3 }, 2, 5, Bu.plan(BOX, box_units(2), rich(), nil).slices[1], 1, { item = "it", manque = 4 }, 6)
check(line == "[FO-RETROFIT] eq1 : box mall 3 : tranche 2/5 (2 machines, 4 bras, 6 remplacees), ajournees 1 (place), en attente de it x4", "ligne : " .. line)
line = Bu.line("eq1", BOX, 1, 1, nil, 0, { item = "it", manque = 2 })
check(line == "[FO-RETROFIT] eq1 : box fonderie 7 : tranche 1/1 non emise, en attente de it x2", "ligne d'attente : " .. line)
check(Bu.key(BOX) == "fonderie:7", "clé d'une box")

-- lot RETROFIT-GABARITS : détecteurs des règles d'emprise (partagés avec §5 mutants)
local S2, S3 = { w = 2, h = 2 }, { w = 3, h = 3 }
function DET.emprise(B)
  local bad = {}
  if B.grows({ fp_now = S2, fp_target = S3 }) ~= true or B.grows({ fp_now = S3, fp_target = S3 }) ~= false or B.grows({}) ~= false then
    bad[#bad + 1] = "grows"
  end
  -- cellules : 3 machines 2×2 en x = 9, 19, 29 (y = -1), espacées de 10 : la 1re grandit librement
  local cells = { { x = 9, y = -1, w = 2, h = 2 }, { x = 19, y = -1, w = 2, h = 2 }, { x = 29, y = -1, w = 2, h = 2 } }
  local ft = B.fit(cells, 1, S3, {}, {})
  if not (ft.ok and ft.rect.x == 9 and ft.rect.y == -1 and ft.rect.w == 3 and ft.rect.h == 3 and ft.cause == nil) then bad[#bad + 1] = "fit libre" end
  -- un tapis sur la colonne est (11, 0) : refus « emprise »
  local occ = { ["11,0"] = true }
  ft = B.fit(cells, 1, S3, occ, {})
  if not (ft.ok == false and ft.cause == "emprise" and ft.conflits[1] == "11,0") then bad[#bad + 1] = "fit tapis : " .. tostring(ft.cause) end
  -- cellules serrées (pas de 3) : la voisine bloque
  local tight = { { x = 9, y = -1, w = 2, h = 2 }, { x = 11, y = -1, w = 2, h = 2 } }
  ft = B.fit(tight, 1, S3, {}, {})
  if ft.ok then bad[#bad + 1] = "voisine ignorée" end
  -- bras au sud, dans le rectangle cible (y = 1), tapis en y = 3 : déplacé sur la ligne d'interface (y = 2), portée courte
  local arms = { { id = 5, x = 10, y = 1, far = { x = 10, y = 3 } } }
  ft = B.fit(cells, 1, S3, {}, arms)
  local mv = ft.moves[5]
  if not (ft.ok and mv and mv.x == 10 and mv.y == 2 and mv.long == false) then bad[#bad + 1] = "bras déplacé" end
  -- même bras, tapis collé (y = 2) : la place du bras est le tapis : refus « emprise »
  ft = B.fit(cells, 1, S3, { ["10,2"] = true }, { { id = 5, x = 10, y = 1, far = { x = 10, y = 2 } } })
  if ft.ok or ft.cause ~= "emprise" then bad[#bad + 1] = "bras sans place accepté" end
  -- même bras, tapis en y = 3 mais un poteau sur la ligne d'interface (10, 2) : la case du bras déplacé est prise : refus « emprise »
  ft = B.fit(cells, 1, S3, { ["10,2"] = true }, arms)
  if ft.ok or ft.cause ~= "emprise" then bad[#bad + 1] = "bras déplacé sur un poteau" end
  -- bras à l'est (x = 11), tapis en x = 14 : ligne d'interface est (x = 12), bras LONG (portée 2)
  local am = B.arm_move({ id = 6, x = 11, y = 0, far = { x = 14, y = 0 } }, cells[1], { x = 9, y = -1, w = 3, h = 3 })
  if not (am and am.x == 12 and am.y == 0 and am.long == true) then bad[#bad + 1] = "bras long à l'est" end
  if B.arm_move({ id = 7, x = 10, y = -2, far = { x = 10, y = -3 } }, cells[1], { x = 9, y = -1, w = 3, h = 3 }) ~= nil then bad[#bad + 1] = "bras au nord déplacé à tort" end
  if B.arm_move({ id = 8, x = 11, y = 0, far = { x = 15, y = 0 } }, cells[1], { x = 9, y = -1, w = 3, h = 3 }) ~= false then bad[#bad + 1] = "tapis hors de portée accepté" end
  -- causes comptées et dites
  local c = B.deferred_causes({ deferred = { { cause = "emprise" }, { cause = "emprise" }, {} } })
  if not (c.emprise == 2 and c.place == 1) then bad[#bad + 1] = "causes" end
  local l = B.line("eq1", { kind = "fonderie", id = 1 }, 1, 2, nil, 0, nil, nil, 2)
  if l ~= "[FO-RETROFIT] eq1 : box fonderie 1 : tranche 1/2 non emise, ajournees 2 (emprise)" then bad[#bad + 1] = "ligne : " .. l end
  return bad
end
-- successeurs à emprise plus grande : même type, vitesse >, emprise ≥ et > sur un axe, énergie identique ou électrique, niveaux > 1 exclus
function DET.grown(B)
  local bad = {}
  local P = {
    f1 = { type = "F", speed = 1, item = "i1", w = 2, h = 2, energy = "burner", cats = { s = true } },
    f2 = { type = "F", speed = 2, item = "i2", w = 2, h = 2, energy = "burner", cats = { s = true } },
    fe = { type = "F", speed = 2, item = "ie", w = 3, h = 3, energy = "electric", cats = { s = true } },
    fb = { type = "F", speed = 3, item = "ib", w = 3, h = 3, energy = "burner", cats = { s = true } },
    fx = { type = "F", speed = 3, item = "ix", w = 3, h = 3, energy = "fluid", cats = { s = true } },
    fc = { type = "F", speed = 3, item = "ic", w = 3, h = 3, energy = "burner", cats = { t = true } },
    fl = { type = "F", speed = 4, item = "il", w = 4, h = 4, energy = "electric", cats = { s = true } },
    a1 = { type = "A", speed = 9, item = "ia", w = 3, h = 3, energy = "electric", cats = { s = true } },
  }
  local ctx = { mproto = function(n) return P[n] end, machines = { "a1", "f1", "f2", "fb", "fc", "fe", "fl", "fx" },
    parse = function(n) if n == "fl" then return { key = "furnace" }, 7 end return nil end }
  local out = table.concat(B.grown_successors(ctx, "f1"), ",")
  if out ~= "fe,fb" then bad[#bad + 1] = "f1 → " .. out end -- (fe vitesse 2 puis fb vitesse 3 ; fx : énergie ; fc : catégorie ; fl : niveau 7 ; f2 : même emprise ; a1 : type)
  out = table.concat(B.grown_successors(ctx, "f2"), ",")
  if out ~= "fb" then bad[#bad + 1] = "f2 → " .. out end -- (fe : même vitesse)
  if #B.grown_successors(ctx, "zz") ~= 0 or #B.grown_successors({}, "f1") ~= 0 then bad[#bad + 1] = "inconnu" end
  if B.long_arm({ { name = "b", reach = 1, speed = 1 }, { name = "l2", reach = 2, speed = 2 }, { name = "l1", reach = 2, speed = 1 } }) ~= "l1" then bad[#bad + 1] = "bras long" end
  return bad
end
local emprise_bad = {}
for _, k in ipairs({ "emprise", "grown" }) do for _, d in ipairs(DET[k](Bu)) do emprise_bad[#emprise_bad + 1] = k .. " : " .. d end end
check(#emprise_bad == 0, "détecteurs d'emprise sur la règle : " .. table.concat(emprise_bad, " | "))

---------------------------------------------------------------------------------------------------
section("§2 mutants : chacun refusé par les mêmes détecteurs")
---------------------------------------------------------------------------------------------------
local src
do local fh = assert(io.open("shared/team/box_upgrade.lua", "rb")) src = fh:read("*a") fh:close() end
local function mutant(name, from, to)
  local s, n = src:gsub(from, function() return to end)
  check(n == 1, "mutant « " .. name .. " » : retouche appliquée une fois (" .. n .. ")")
  local chunk = assert(load(s, "=" .. name))
  local B = chunk()
  local faults = run_all(B)
  check(#faults > 0, "mutant « " .. name .. " » refusé par les détecteurs")
  return faults
end
local MUT = {
  { "priorité inversée", "Bu%.RANK = { sortie = 1, machine = 2, entree = 3, poteau = 4 }", "Bu.RANK = { sortie = 3, machine = 2, entree = 1, poteau = 4 }" },
  { "ajourné bloquant", "if u%.can_place == false then deferred%[#deferred %+ 1%] = u else keep%[#keep %+ 1%] = u end",
    "if u.can_place == false then return nil else keep[#keep + 1] = u end" },
  { "kit ignoré", "if ok then slices%[#slices %+ 1%] = kept else waiting = w end", "slices[#slices + 1] = kept" },
  { "tranche illimitée", "if n > Bu%.CFG%.slice_max then n = Bu%.CFG%.slice_max end", "n = 1000" },
  { "MAXED jamais atteint", "waiting = nil, status = Bu%.MAXED, todo = 0 }", "waiting = nil, status = Bu.EN_COURS, todo = 0 }" },
}
for _, m in ipairs(MUT) do
  local faults = mutant(m[1], m[2], m[3])
  print("  mutant « " .. m[1] .. " » : " .. (faults[1] or "(rien)"))
end
-- lot RETROFIT-GABARITS : mutants des règles d'emprise, vus par DET.emprise / DET.grown
local function mutant_emprise(name, from, to, det)
  local s, n = src:gsub(from, function() return to end)
  check(n == 1, "mutant « " .. name .. " » : retouche appliquée une fois (" .. n .. ")")
  local B = assert(load(s, "=" .. name))()
  local faults = DET[det](B)
  check(#faults > 0, "mutant « " .. name .. " » refusé par les détecteurs")
  print("  mutant « " .. name .. " » : " .. (faults[1] or "(rien)"))
end
mutant_emprise("emprise ignorée (Bl.grow sans effet)", "local ok, conflits = Bl%.grow%(cells, i, new_size, occupied%)", "local ok, conflits = true, {}", "emprise")
mutant_emprise("bras non repositionné (déplacement oublié)", "local mv = Bu%.arm_move%(a, cells%[i%], rect%)", "local mv = nil", "emprise")
mutant_emprise("bras déplacé sur une case prise", "if mv == false or %(mv and not free_for_arm%(mv, rect, cells, i, occupied%)%) then", "if mv == false then", "emprise")
mutant_emprise("successeur de même emprise accepté", "and %(%(p1%.w or 0%) > %(p0%.w or 0%) or %(p1%.h or 0%) > %(p0%.h or 0%)%)", "", "grown")
mutant_emprise("énergie ignorée", 'and %(p1%.energy == p0%.energy or p1%.energy == "electric"%)', "", "grown")

---------------------------------------------------------------------------------------------------
section("§3 câblage textuel")
---------------------------------------------------------------------------------------------------
local function slurp(path) local fh = assert(io.open(path, "rb")) local s = fh:read("*a") fh:close() return s end
local rt, bx, cap = slurp("script/team/box_upgrade_rt.lua"), slurp("script/team/boxes_rt.lua"), slurp("script/ai3/capital.lua")
check(bx:find('require("script.team.box_upgrade_rt")', 1, true) ~= nil, "boxes_rt.lua requiert le moteur du rétrofit")
check(bx:find("Bur.impulsion(f, surface, tick) -- lot BOX-UPGRADE", 1, true) ~= nil, "boxes_rt.lua : UNE ligne d'appel à la fin du relevé, « lot BOX-UPGRADE »")
local releve_body = bx:match("function Boxes%.releve%(.-\nend")
check(releve_body ~= nil and releve_body:find("Bur.impulsion", 1, true) ~= nil, "l'appel est dans Boxes.releve")
check(cap:find("function Capital.replace_entity(f, e, to) return replace_one(f, state_of(f), e, to) end", 1, true) ~= nil, "capital.lua ouvre replace_one (la primitive réutilisée)")
check(cap:find("function Capital.unlocked(f, item) return unlocked(f, item) end", 1, true) ~= nil, "capital.lua ouvre unlocked")
check(cap:find('require("script.team.box_upgrade_rt").bind(Capital, Stock)', 1, true) ~= nil, "capital.lua lie la primitive au chargement")
check(rt:find("%f[%w_]global%f[^%w_]") == nil, "box_upgrade_rt.lua ne nomme pas `global`")
local rt_code = rt:gsub("^%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "") -- le code sans l'en-tête ni les commentaires de ligne
check(rt_code:find("create_entity", 1, true) == nil, "box_upgrade_rt.lua ne pose rien lui-même (une seule primitive de remplacement)")
check(rt:find("Cap.replace_entity(", 1, true) ~= nil, "box_upgrade_rt.lua passe par Capital.replace_entity")
check(rt:find("can_fast_replace", 1, true) ~= nil and rt:find("build_check_type.manual", 1, true) ~= nil, "anti-collision : can_fast_replace puis can_place_entity{build_check_type = manual}")
local inner_req = 0
for l in rt:gmatch("[^\n]+") do if l:match("^%s+.-require%(") then inner_req = inner_req + 1 end end
check(inner_req == 0, "aucun require dans une fonction du moteur (F24) : " .. inner_req)
for _, w in ipairs({ '"furnace"', '"assembling-machine"', '"inserter"', '"stone-furnace"', '"steel-furnace"', '"fast-inserter"' }) do
  check(rt:find(w, 1, true) == nil, "aucun nom en dur " .. w .. " (types lus à Bx.TYPES et R.RANG_REACH)")
end
check(rt:find("Bx.TYPES[kind]", 1, true) ~= nil and rt:find("R.RANG_REACH.type", 1, true) ~= nil, "rôles lus aux TYPES des données")
check(rt:find("Cap.successors_of(", 1, true) ~= nil and rt:find("Cap.unlocked(", 1, true) ~= nil, "palier cible : successeurs des prototypes, recette activée")
check(rt:find("u.can_place = can_place(surface, f, u, refs[u.id])", 1, true) ~= nil, "can_place mesuré pour la tranche courante seulement")
check(rt:find("T.hq_threat_radius", 1, true) ~= nil, "garde : menace du QG")
local function longest(s)
  local max, name, cur, cname = 0, "", 0, nil
  for l in (s .. "\n"):gmatch("([^\n]*)\n") do
    local fn = l:match("^local function ([%w_]+)") or l:match("^function ([%w_%.]+)")
    if fn then cur, cname = 0, fn end
    if cname then cur = cur + 1 end
    if l == "end" and cname then if cur > max then max, name = cur, cname end cname = nil end
  end
  return max, name
end
local lm, ln = longest(rt)
check(lm < 80, "fonctions du moteur < 80 lignes (la plus longue : " .. ln .. ", " .. lm .. ")")
lm, ln = longest(src)
check(lm < 80, "fonctions de la règle < 80 lignes (la plus longue : " .. ln .. ", " .. lm .. ")")
-- lot RETROFIT-GABARITS : câblage de l'emprise distincte
check(rt:find("if Bu.grows(u) then return fits(surface, u, ref) end", 1, true) ~= nil, "can_place : une unité qui grandit passe par sa cellule (fits)")
check(rt:find("Bu.fit(cells, i, u.fp_target, occ, arms)", 1, true) ~= nil and rt:find("Bl.grown(", 1, true) ~= nil, "fits : Bu.fit sur l'occupation relevée autour de Bl.grown")
check(rt:find("Se.swap(surface, f, e, u.target,", 1, true) ~= nil and rt:find("Se.swap(surface, f, e, name,", 1, true) ~= nil, "primitive partagée Se.swap pour la machine ET le bras déplacé")
check(rt:find("Bu.grown_successors(grown_ctx(), name)", 1, true) ~= nil and cap:find("function Capital.machine_names() return machine_catalog().names end", 1, true) ~= nil, "cible à emprise plus grande : Bu.grown_successors sur le catalogue des machines (Capital.machine_names)")
check(rt:find("Bu.deferred_causes(plan)", 1, true) ~= nil, "causes d'ajournement comptées (place, emprise)")
local fs = slurp("script/team/foreuse_swap.lua")
check(fs:find("Se.swap(surface, f, d, item, { x = cx, y = cy, dir = edir, size = T.drill_electric.size })", 1, true) ~= nil and fs:find("local function place_back", 1, true) == nil,
  "foreuse_swap.lua : swap_one passe par la primitive partagée (place_back extraite)")
local se = slurp("script/team/swap_entity.lua")
check(se:find("%f[%w_]global%f[^%w_]") == nil and se:find("State.disown(unit)", 1, true) ~= nil and se:find("raise_built = true", 1, true) ~= nil, "swap_entity.lua : sans `global`, désappropriation avant le retrait, pose avec raise_built")
local lse, nse = longest(se)
check(lse < 80, "fonctions de swap_entity.lua < 80 lignes (" .. nse .. ", " .. lse .. ")")

---------------------------------------------------------------------------------------------------
section("§4 moteur script/team/box_upgrade_rt.lua sur un moteur minimal")
---------------------------------------------------------------------------------------------------
defines = { build_check_type = { manual = 1 } } -- luacheck: ignore
local logs = {}
function log(text) logs[#logs + 1] = text end -- luacheck: ignore
local function retro_logs() local out = {} for _, l in ipairs(logs) do if l:find("[FO-RETROFIT]", 1, true) then out[#out + 1] = l end end return out end

-- lot RETROFIT-GABARITS : primitive partagée doublée (le vrai script/team/swap_entity.lua tient à State et au moteur)
local swaps = {} -- { from = nom, to = nom, x, y } dans l'ordre
local world, next_id = {}, 100
local PROTO
local function ent(name, x, y)
  next_id = next_id + 1
  local p = PROTO[name]
  local e = { name = name, valid = true, unit_number = next_id, type = p.type, position = { x = x, y = y }, direction = 0, force = { name = "f1" },
    bounding_box = { left_top = { x = x - p.w / 2, y = y - p.h / 2 }, right_bottom = { x = x + p.w / 2, y = y + p.h / 2 } } }
  world[#world + 1] = e
  return e
end
local FakeSe = {
  MOVING = {},
  swap = function(surface, f, old, to, place)
    swaps[#swaps + 1] = { from = old.name, to = to, x = place.x, y = place.y, check = place.check }
    old.valid = false
    return ent(to, place.x, place.y)
  end,
  take = function() return { items = {} } end,
  give = function() return {} end,
}
package.loaded["script.team.swap_entity"] = FakeSe
local Bur = require("script.team.box_upgrade_rt")
local Bx = require("shared.team.boxes")
local R = require("shared.ai3.reglages")
local MT, AT = Bx.TYPES.fonderie[1], R.RANG_REACH.type -- types lus aux données (jamais écrits ici)

-- catalogue doublé : deux paliers de machine, deux de bras (vitesse au prototype), un bras long hors palier
PROTO = {
  m1 = { type = MT, speed = 1, item = "it-m1", w = 2, h = 2, energy = "burner" }, m2 = { type = MT, speed = 2, item = "it-m2", w = 2, h = 2, energy = "burner" },
  a1 = { type = AT, speed = 0.01, item = "it-a1", w = 1, h = 1, rang = true, reach = "0.00,-1.00>0.00,1.20" },
  a2 = { type = AT, speed = 0.02, item = "it-a2", w = 1, h = 1, rang = true, reach = "0.00,-1.00>0.00,1.20" },
  belt = { type = "B", speed = 1, item = "it-belt", w = 1, h = 1 },
}
local NAMES = { "a1", "a2", "m1", "m2" }
local SUCC = { m1 = { "m2" }, a1 = { "a2" } }
local stock = { ["it-m2"] = 2, ["it-a2"] = 10 }
local replaced = {} -- ordre d'émission (noms des entités remplacées)
local FakeCap = {
  mproto = function(n) return PROTO[n] end,
  machine_names = function() return NAMES end,
  successors_of = function(n) return SUCC[n] or {} end,
  unlocked = function(_, item) return item ~= "it-locked" end,
  replace_entity = function(f, e, to)
    if (stock[PROTO[to].item] or 0) < 1 then return nil, "objet" end
    local n = ent(to, e.position.x, e.position.y)
    n.drop_target, n.pickup_target = e.drop_target, e.pickup_target
    stock[PROTO[to].item] = stock[PROTO[to].item] - 1
    stock[PROTO[e.name].item] = (stock[PROTO[e.name].item] or 0) + 1
    e.valid = false
    replaced[#replaced + 1] = e.name .. "@" .. e.position.x
    return n
  end,
}
local FakeStock = { count = function(_, item) return stock[item] or 0 end,
  remove = function(_, item, n) stock[item] = (stock[item] or 0) - n return n end,
  insert = function(_, item, n) stock[item] = (stock[item] or 0) + n return n end }
check(not Bur.bound(), "sans liaison, le moteur est inactif")
Bur.bind(FakeCap, FakeStock)

local blocked = {} -- positions où le remplacement rapide est refusé (collision)
local threat_n = 0
local surface = {
  find_entity = function(name, pos) for _, e in ipairs(world) do if e.valid and e.name == name and e.position.x == pos[1] and e.position.y == pos[2] then return e end end return nil end,
  find_entities_filtered = function(q)
    local out = {}
    for _, e in ipairs(world) do
      if q.area then -- (relevé d'occupation autour d'une cellule qui grandit : toute entité dont le centre est dans la zone)
        local a, b = q.area[1], q.area[2]
        if e.valid and e.position.x >= a[1] and e.position.x <= b[1] and e.position.y >= a[2] and e.position.y <= b[2] then out[#out + 1] = e end
      elseif e.valid and e.type == q.type and math.abs(e.position.x - q.position[1]) <= q.radius and math.abs(e.position.y - q.position[2]) <= q.radius then out[#out + 1] = e end
    end
    return out
  end,
  find_tiles_filtered = function() return {} end,
  can_fast_replace = function(a) return not blocked[a.position.x .. "," .. a.position.y] end,
  can_place_entity = function(a) assert(a.build_check_type == 1, "build_check_type manual") return false end,
  count_entities_filtered = function() return threat_n end,
}
-- box fonderie 1 : 3 machines en x = 10, 20, 30 (y = 0) ; bras d'entrée au nord (dépose dans la machine), bras de sortie au sud (prend dans la machine)
local pieces = {}
local function piece(e) pieces[#pieces + 1] = { name = e.name, x = e.position.x, y = e.position.y, built = true } return e end
local M = {}
for i = 1, 3 do
  local m = piece(ent("m1", i * 10, 0))
  M[i] = m
  -- (le moteur réel donne toujours un point de prise et de dépôt ; la cible n'est connue qu'une fois résolue)
  local ein = piece(ent("a1", i * 10, -2))
  ein.drop_position, ein.pickup_position = { x = i * 10, y = -1 }, { x = i * 10, y = -3 }
  if i ~= 2 then ein.drop_target = m end -- cible du moteur (i = 2 : cible inconnue, point de dépôt dans l'emprise)
  local eout = piece(ent("a1", i * 10, 2))
  eout.pickup_position, eout.drop_position = { x = i * 10, y = 1 }, { x = i * 10, y = 3 }
  if i ~= 2 then eout.pickup_target = m end
end
local far = piece(ent("a1", 50, 50)) -- bras hors des machines : orphelin « entree », servi en dernier
far.drop_position, far.pickup_position = { x = 50, y = 51 }, { x = 50, y = 49 }
local f = { key = "eq1", force = "f1", hq = { valid = true }, hq_pos = { x = 0, y = 0 },
  team = { boxes = { list = { { kind = "fonderie", id = 1, status = "UPGRADE_REQUISE" }, { kind = "mall", id = 2, status = "UPGRADE_REQUISE" },
    { kind = "gisement", id = 3, status = "UPGRADE_REQUISE" } } } },
  build = { projects = { [1] = { state = "fini", ents = pieces } }, mall = { rows = { { j = 2, projects = {} } } } } }

-- menace du QG : rien ne bouge
threat_n = 1
Bur.impulsion(f, surface, 1000)
check(#replaced == 0 and #retro_logs() == 0 and next(f.team.retrofit or {}) == nil, "menace du QG : aucun remplacement, aucune ligne")
threat_n = 0

-- tranche 1 : machines 10 et 20 + 4 bras ; la sortie de la machine 10 est bloquée (ajournée) ; ordre sortie -> machine -> entree
blocked["10,2"] = true
Bur.impulsion(f, surface, 2000)
local rl = retro_logs()
check(#rl == 1, "une seule box par impulsion : une ligne [FO-RETROFIT] (" .. #rl .. ")")
-- 3 tranches à faire : la paire (10, 20), la paire (30), le bras orphelin ; le kit (2 machines) ne paie pas la 2e : attente dite tout de suite
check(rl[1] and rl[1]:find("[FO-RETROFIT] eq1 : box fonderie 1 : tranche 1/3 (2 machines, 3 bras, 5 remplacees), ajournees 1 (place), en attente de it-m2 x1 a 0.6 min", 1, true) ~= nil, "ligne de la tranche 1 : " .. tostring(rl[1]))
check(table.concat(replaced, " ") == "a1@20 m1@10 m1@20 a1@10 a1@20", "ordre d'émission sortie -> machines -> entrées : " .. table.concat(replaced, " "))
local st = f.team.retrofit["fonderie:1"]
check(st and st.i == 1 and st.n == 3 and st.done == 5 and st.deferred == 1 and st.t0 == 2000, "état { i, n, done, deferred, t0 } après la tranche 1")
check(pieces[1].name == "m2" and pieces[2].name == "a1", "pièce du plan renommée pour la machine, pas pour le bras (rang)")
check(stock["it-m2"] == 0 and stock["it-m1"] == 2 and stock["it-a1"] == 3, "kit débité, anciens objets rendus")
local function pure(v) local t = type(v) if t == "table" then for _, x in pairs(v) do if not pure(x) then return false end end return true end return t == "number" or t == "string" or t == "boolean" end
check(pure(f.team.retrofit), "f.team.retrofit : données pures (nombres, chaînes)")

-- tranche 2 : la sortie ajournée (sa machine est déjà au palier : orpheline, retrouvée par son point de prise) passe d'abord, seule
blocked = {}
Bur.impulsion(f, surface, 3000)
rl = retro_logs()
check(#rl == 2 and rl[2]:find("tranche 2/4 (0 machines, 1 bras, 1 remplacees), en attente de it-m2 x1", 1, true) ~= nil, "tranche 2 : la sortie ajournée seule : " .. tostring(rl[2]))
-- attente du kit pour la machine 30 : rien n'est émis, la machine actuelle continue
Bur.impulsion(f, surface, 4000)
rl = retro_logs()
check(#rl == 3 and rl[3]:find("tranche 3/4 non emise, en attente de it-m2 x1", 1, true) ~= nil, "kit manquant : attente, la machine actuelle continue : " .. tostring(rl[3]))
check(#replaced == 6 and M[3].valid, "rien remplacé sans kit")
st = f.team.retrofit["fonderie:1"]
check(st and st.waiting_item == "it-m2" and st.waiting_n == 1 and st.i == 2 and st.n == 4, "état d'attente en données pures")

-- reprise : le kit arrive ; puis le bras orphelin ; puis MAXED, état oublié
stock["it-m2"] = 1
Bur.impulsion(f, surface, 5000)
rl = retro_logs()
check(#rl == 4 and rl[4]:find("tranche 3/4 (1 machines, 2 bras, 3 remplacees) a 1.4 min", 1, true) ~= nil, "reprise : dernière paire : " .. tostring(rl[4]))
Bur.impulsion(f, surface, 6000)
rl = retro_logs()
check(#rl == 5 and rl[5]:find("tranche 4/4 (0 machines, 1 bras, 1 remplacees) a 1.7 min", 1, true) ~= nil, "bras orphelin d'entrée en dernier : " .. tostring(rl[5]))
Bur.impulsion(f, surface, 7000)
rl = retro_logs()
check(#rl == 6 and rl[6]:find("rien a monter (4 tranches, 10 unites remplacees)", 1, true) ~= nil, "MAXED : ligne de fin : " .. tostring(rl[6]))
check(f.team.retrofit["fonderie:1"] == nil, "état oublié au MAXED")
Bur.impulsion(f, surface, 8000)
check(#retro_logs() == 6, "box au palier : silence")
-- la box 2 (mall, sans section finie) ne donne rien : aucun remplacement, aucune ligne
check(#replaced == 10, "10 remplacements en tout")
-- unlocked faux : aucun palier cible (recette non activée)
PROTO.m3 = { type = MT, speed = 3, item = "it-locked", w = 2, h = 2 }
SUCC.m2 = { "m3" }
Bur.impulsion(f, surface, 9000)
check(#replaced == 10 and #retro_logs() == 6, "successeur à recette non activée : pas un palier cible")


---------------------------------------------------------------------------------------------------
section("§5 lot RETROFIT-GABARITS : unité qui grandit (2×2 → 3×3) sur le moteur minimal")
---------------------------------------------------------------------------------------------------
-- cible à emprise plus grande : g3 (3×3, électrique, vitesse 3) succède à m2 (2×2, à combustion) faute de successeur de même emprise
PROTO.g3 = { type = MT, speed = 3, item = "it-g3", w = 3, h = 3, energy = "electric" }
NAMES = { "a1", "a2", "belt", "g3", "m1", "m2" }
SUCC.m2 = {}
stock["it-g3"] = 3
for _, b in ipairs(f.team.boxes.list) do b.status = Bx.MAXED end
local pieces5 = {}
local function piece5(e) pieces5[#pieces5 + 1] = { name = e.name, x = e.position.x, y = e.position.y, built = true } return e end
-- 3 machines m2 en x = 110, 120, 130 (y = 0 : tuiles 109..110 × -1..0) ; bras a2 au nord (entrée) et au sud (sortie) ; pour la 130, la
-- sortie est collée au four (y = 1, dans le rectangle cible) et dépose en y = 3 : à déplacer sur la ligne d'interface (y = 2)
local M5 = {}
for i = 1, 3 do
  local x = 100 + i * 10
  local m = piece5(ent("m2", x, 0))
  M5[i] = m
  local ein = piece5(ent("a2", x, -2))
  ein.drop_target, ein.drop_position, ein.pickup_position = m, { x = x, y = -1 }, { x = x, y = -3 }
  local sy = (i == 3) and 1 or 2
  local eout = piece5(ent("a2", x, sy))
  eout.pickup_target, eout.pickup_position, eout.drop_position = m, { x = x, y = 0 }, { x = x, y = sy + 1 + ((i == 3) and 1 or 0) }
end
local belt = ent("belt", 121.5, 0.5) -- un tapis sur la colonne est de la cellule de la machine 120 (tuile 121, 0) : elle ne peut pas grandir
f.team.boxes.list[#f.team.boxes.list + 1] = { kind = "fonderie", id = 5, status = "UPGRADE_REQUISE" }
f.build.projects[5] = { state = "fini", ents = pieces5 }
local n_logs = #retro_logs()
-- impulsion 1 : la 110 grandit (3×3 posé au coin nord-ouest de sa cellule : centre (110.5, 0.5)), la 120 est ajournée « emprise »
Bur.impulsion(f, surface, 10000)
rl = retro_logs()
check(#rl == n_logs + 1 and rl[#rl]:find("box fonderie 5 : tranche 1/2 (1 machines, 0 bras, 1 remplacees), ajournees 1 (emprise)", 1, true) ~= nil, "tranche 1 : une machine grandit, une ajournée (emprise) : " .. tostring(rl[#rl]))
check(#swaps == 1 and swaps[1].from == "m2" and swaps[1].to == "g3" and swaps[1].x == 110.5 and swaps[1].y == 0.5 and swaps[1].check == 1,
  "primitive partagée : m2 → g3 au centre de Bl.grown (110.5, 0.5), build_check_type manual")
check(not M5[1].valid and stock["it-g3"] == 2 and stock["it-m2"] == 1, "ancienne retirée, kit débité, ancien objet rendu (" .. tostring(stock["it-m2"]) .. ")")
check(pieces5[1].name == "g3" and pieces5[1].x == 110.5 and pieces5[1].y == 0.5, "pièce du plan renommée ET déplacée au nouveau centre")
st = f.team.retrofit["fonderie:5"]
check(st and st.deferred == 0 and st.deferred_emprise == 1 and pure(f.team.retrofit), "état : ajournée comptée en « emprise », données pures")
-- impulsion 2 : la 130 grandit et son bras de sortie suit la ligne d'interface (y = 2) ; la 120 toujours ajournée
Bur.impulsion(f, surface, 11000)
rl = retro_logs()
check(#rl == n_logs + 2 and rl[#rl]:find("tranche 2/2 (1 machines, 0 bras, 1 remplacees), ajournees 1 (emprise)", 1, true) ~= nil, "tranche 2 : la 130 grandit : " .. tostring(rl[#rl]))
check(#swaps == 3 and swaps[2].to == "g3" and swaps[2].x == 130.5 and swaps[3].from == "a2" and swaps[3].to == "a2" and swaps[3].x == 130.5 and swaps[3].y == 2.5,
  "bras de sortie déplacé sur la ligne d'interface (130.5, 2.5), même bras (portée courte)")
check(pieces5[9].x == 130.5 and pieces5[9].y == 2.5 and pieces5[9].name == "a2", "pièce du plan du bras déplacée, nom du rang gardé")
-- impulsion 3 : le tapis retiré, la 120 grandit ; puis MAXED
belt.valid = false
Bur.impulsion(f, surface, 12000)
rl = retro_logs()
check(#rl == n_logs + 3 and rl[#rl]:find("tranche 3/3 (1 machines, 0 bras, 1 remplacees) a", 1, true) ~= nil, "tapis retiré : la 120 grandit : " .. tostring(rl[#rl]))
check(#swaps == 4 and swaps[4].x == 120.5 and stock["it-g3"] == 0, "4 remplacements à emprise différente en tout, kit épuisé")
Bur.impulsion(f, surface, 13000)
rl = retro_logs()
check(#rl == n_logs + 4 and rl[#rl]:find("rien a monter (3 tranches, 3 unites remplacees)", 1, true) ~= nil, "MAXED après les trois : " .. tostring(rl[#rl]))

-- mutant du moteur : can_place ignoré pour une unité qui grandit (la décision de fits court-circuitée, le rectangle cible gardé) : le
-- tapis n'empêche plus rien ; (court-circuiter l'appel de fits lui-même est déjà refusé par grow_one : aucun rectangle cible, « emprise »)
do
  local mut = rt:gsub("u%.cause, u%.moves, u%.rect = fit%.cause, fit%.moves, fit%.rect\n  return fit%.ok",
    function() return "u.cause, u.moves, u.rect = fit.cause, fit.moves, fit.rect\n  return true" end)
  check(mut ~= rt, "mutant du moteur : retouche appliquée")
  local BurM = assert(load(mut, "=rt_mutant"))()
  BurM.bind(FakeCap, FakeStock)
  local pieces6 = {}
  local m6 = ent("m2", 210, 0)
  pieces6[1] = { name = "m2", x = 210, y = 0, built = true }
  ent("belt", 211.5, 0.5)
  stock["it-g3"] = 1
  local f6 = { key = "eq6", force = "f1", hq = { valid = true }, hq_pos = { x = 0, y = 0 },
    team = { boxes = { list = { { kind = "fonderie", id = 6, status = "UPGRADE_REQUISE" } } } }, build = { projects = { [6] = { state = "fini", ents = pieces6 } } } }
  local n_sw = #swaps
  Bur.impulsion(f6, surface, 14000)
  check(#swaps == n_sw and m6.valid and f6.team.retrofit["fonderie:6"].deferred_emprise == 1, "règle : la machine bloquée par le tapis est ajournée (emprise)")
  f6.team.retrofit = nil
  BurM.impulsion(f6, surface, 15000)
  check(#swaps == n_sw + 1, "mutant « can_place ignoré » : la machine bloquée est remplacée quand même (vu : le vrai moteur l'ajourne)")
end

---------------------------------------------------------------------------------------------------
section("§6 lot ILOTS-COLONNES : îlot à liaisons par colonne, cellules réservées contre pas d'avant")
---------------------------------------------------------------------------------------------------
do
  local Bl = require("shared.team.box_layout")
  local S4 = { w = 4, h = 4 }
  -- îlot RÉSERVÉ : machines 3×3 en x = 0, 5, 10 (cellules de 4, colonne de liaison en x = 4 et x = 9) ; tapis d'entrée en y = -2, de
  -- sortie en y = 5 ; bras d'entrée (y = -1), de sortie LONGS (y = 4, ligne d'interface sud) ; bras de liaison longs dans les colonnes,
  -- lignes 0..2 : ceux de la colonne 4 appartiennent à la machine 2 (ils y déposent), ceux de la colonne 9 aussi (ils y prennent)
  local cells = { { x = 0, y = 0, w = 3, h = 3 }, { x = 5, y = 0, w = 3, h = 3 }, { x = 10, y = 0, w = 3, h = 3 } }
  local occ = {}
  for x = 0, 13 do occ[Bl.key(x, -2)] = true occ[Bl.key(x, 5)] = true end
  local arms_of = {}
  for i, c in ipairs(cells) do
    arms_of[i] = { { id = 100 * i + 1, x = c.x + 1, y = -1, far = { x = c.x + 1, y = -2 } }, { id = 100 * i + 2, x = c.x + 1, y = 4, far = { x = c.x + 1, y = 5 } } }
  end
  for r = 0, 2 do
    arms_of[2][#arms_of[2] + 1] = { id = 210 + r, x = 4, y = r, far = { x = 2, y = r } }   -- colonne 4 : prend dans la machine 1
    arms_of[2][#arms_of[2] + 1] = { id = 220 + r, x = 9, y = r, far = { x = 11, y = r } }  -- colonne 9 : dépose dans la machine 3
  end
  local function occupied_for(i)
    local o = {}
    for k in pairs(occ) do o[k] = true end
    for j, list in ipairs(arms_of) do
      if j ~= i then for _, a in ipairs(list) do o[Bl.key(a.x, a.y)] = true end end
    end
    return o
  end
  local all_ok, moved = true, 0
  for i = 1, 3 do
    local ft = Bu.fit(cells, i, S4, occupied_for(i), arms_of[i])
    if not ft.ok then all_ok = false end
    for _ in pairs(ft.moves) do moved = moved + 1 end
  end
  check(all_ok and moved == 0, "îlot réservé : les 3 machines grandissent vers 4×4, aucun bras de liaison déplacé ni en conflit (" .. moved .. " déplacé(s))")
  -- îlot au PAS D'AVANT (4) : machines en x = 0, 4, 8, colonne de liaison en x = 3 et x = 7 (dans la future emprise de la machine à l'ouest)
  local tight = { { x = 0, y = 0, w = 3, h = 3 }, { x = 4, y = 0, w = 3, h = 3 }, { x = 8, y = 0, w = 3, h = 3 } }
  local t_arms = { {}, {}, {} }
  for i, c in ipairs(tight) do
    t_arms[i] = { { id = 100 * i + 1, x = c.x + 1, y = -1, far = { x = c.x + 1, y = -2 } }, { id = 100 * i + 2, x = c.x + 1, y = 3, far = { x = c.x + 1, y = 5 } } }
  end
  for r = 0, 2 do
    t_arms[2][#t_arms[2] + 1] = { id = 210 + r, x = 3, y = r, far = { x = 2, y = r } }
    t_arms[2][#t_arms[2] + 1] = { id = 220 + r, x = 7, y = r, far = { x = 9, y = r } }
  end
  local function t_occupied(i)
    local o = {}
    for k in pairs(occ) do o[k] = true end
    for j, list in ipairs(t_arms) do
      if j ~= i then for _, a in ipairs(list) do o[Bl.key(a.x, a.y)] = true end end
    end
    return o
  end
  local f1 = Bu.fit(tight, 1, S4, t_occupied(1), t_arms[1])
  check(f1.ok == false and f1.cause == "emprise" and f1.conflits[1] == "3,0", "pas d'avant : la machine 1 est ajournée « emprise » (le bras de liaison de sa voisine est en (3, 0)) : " .. tostring(f1.conflits[1]))
  local f2 = Bu.fit(tight, 2, S4, t_occupied(2), t_arms[2])
  check(f2.ok == false and f2.cause == "emprise", "pas d'avant : la machine 2 est ajournée « emprise » (son bras de liaison est poussé sur la machine 3) : " .. tostring(f2.conflits[1]))
end

print(string.format("\n%d OK, %d ECHEC", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
