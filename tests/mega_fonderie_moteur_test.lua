--[[
  Lot MEGA-FONDERIE (8/11) : test hors jeu du runtime script/team/mega_fonderie.lua, moteur simulé par des doublures (Champ.data,
  MigChamp.takes, Stock.count, settings, game.recipe_prototypes, log). Depuis la racine du mod :
    lua5.2 tests/mega_fonderie_moteur_test.lua   -> [MEGA-MOTEUR] BILAN : N OK, 0 ECHEC(S)
  Contrôles : décision pour une faction ET votre équipe, refus causés (minerai sans four, gisement trop petit), attentes (courant, crise),
  « garder » sans nouvelle ligne, journal à chaque changement seulement, réglage éteint (rien de lu ni d'écrit), budget de départ lu au
  coffre, rendement de la recette (brique), état f.mega sauvegardable (nombres, chaînes, tables), branchement dans la capitalisation
  (étape 11, champ Capi.Mega), mutants du runtime.
]]
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[MEGA-MOTEUR] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local PATH = "script/team/mega_fonderie.lua"
local SRC = read(PATH)

-- Doublures du moteur (vanilla : foreuse 3 × 3 à 0,5/s, four de pierre, bras, petit poteau, tapis jaune)
local LOGS = {}
_G.log = function(s) LOGS[#LOGS + 1] = s end
_G.settings = { global = { ["fo-war-mega-fonderie"] = { value = true } } }
_G.game = { entity_prototypes = { ["stone-furnace"] = { type = "furnace" }, ["iron-chest"] = { type = "container" } }, recipe_prototypes = {
  ["iron-plate"] = { ingredients = { { name = "iron-ore", amount = 1 } }, products = { { name = "iron-plate", amount = 1 } } },
  -- recette DOUBLURE (2 minerais pour 1 plaque) : le rendement est lu à la recette, jamais supposé à 1
  ["copper-plate"] = { ingredients = { { name = "copper-ore", amount = 2 } }, products = { { name = "copper-plate", amount = 1 } } },
} }
local DATA = {
  drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 }, belts = { { lane = 7.5 } },
  furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 }, inserter = { rate = 0.83 },
}
local BRICK = { drill = DATA.drill, pole = DATA.pole, belts = DATA.belts, inserter = DATA.inserter,
  furnace = { size = 2, rate = 0.625, fuel = true, fuel_rate = 0.0225 } }
local NAMES = { furnace = "stone-furnace", arm = "inserter", pole = "small-electric-pole", chest = "iron-chest", belts = { "transport-belt" } }
local calls = { data = 0 }
package.loaded["script.team.champ"] = { data = function(f, kind)
  calls.data = calls.data + 1
  if f.no_belt then return nil, "tapis" end
  if kind == "copper" then return BRICK, NAMES end
  return DATA, NAMES
end }
-- Doublure de la migration du champ (tranche 2, A2) : Mega.think ordonne le champ d'une décision par MigChamp.want(f, dep, tick, par)
local WANT = { calls = {}, fid = 77, produced = 0 }
package.loaded["script.team.migration_champ"] = { want = function(f, dep, tick, par)
  WANT.calls[#WANT.calls + 1] = { team = f.key or "player", dep = dep.id, par = par, tick = tick }
  if WANT.refuse then return nil, WANT.refuse end
  return WANT.fid, WANT.produced
end }
package.loaded["script.team.stock"] = { count = function(f, name) return (f.stock or {})[name] or 0 end }

local function load_mega(src, mf)
  package.loaded["script.team.mega_fonderie"] = nil
  local real = package.loaded["shared.team.mega_fonderie"]
  if mf then package.loaded["shared.team.mega_fonderie"] = mf end
  local ok, m = pcall(function() return assert(load(src, "=" .. PATH, "t", _ENV))() end)
  package.loaded["shared.team.mega_fonderie"] = real
  assert(ok, m)
  return m
end

-- (Lot TESTS-VERTS : centre cx, cy de chaque gisement, comme ceux du jeu, script/faction/sites.lua : la règle R3 de PAVAGE-GEANT,
-- 737d645e, lit la distance du gisement au QG)
local function deps()
  return {
    [11] = { id = 11, resource = "iron-ore", tiles = 1000, cx = 0, cy = 0 },
    [12] = { id = 12, resource = "coal", tiles = 3000, cx = 40, cy = 0 },
    [13] = { id = 13, resource = "iron-ore", tiles = 150, cx = -40, cy = 0 },
    [14] = { id = 14, resource = "copper-ore", tiles = 1200, cx = 0, cy = 40 },
  }
end

local function saveable(t, seen)
  seen = seen or {}
  if seen[t] then return true end
  seen[t] = true
  for k, v in pairs(t) do
    local tk, tv = type(k), type(v)
    if not (tk == "string" or tk == "number") then return false end
    if tv == "table" then if not saveable(v, seen) then return false end
    elseif not (tv == "string" or tv == "number" or tv == "boolean") then return false end
  end
  return true
end

local function suite(Mega, src)
  local bad, nw = {}, 0
  local function want(ok, msg) nw = nw + 1; if not ok then bad[#bad + 1] = msg end end
  local function grep(pat) local n = 0 for _, l in ipairs(LOGS) do if l:find(pat, 1, true) then n = n + 1 end end return n end
  LOGS = {}
  WANT.calls, WANT.refuse = {}, nil
  _G.settings.global["fo-war-mega-fonderie"].value = true
  -- une faction et votre équipe, mêmes gisements
  local fac = { key = "azure", stock = { ["stone-furnace"] = 60, ["inserter"] = 200, ["small-electric-pole"] = 100, ["iron-chest"] = 100, ["transport-belt"] = 400 } }
  local pl = { is_player = true, stock = {} }
  for _, f in ipairs({ fac, pl }) do
    local cs = { deps = deps() }
    for t = 1, 2 do Mega.think(f, cs, t * 3600, { power = true, crisis = false }) end -- 4 gisements, 2 par pensée
  end
  local rf, rp = fac.mega and fac.mega.deps[11], pl.mega and pl.mega.deps[11]
  want(rf and rf.state == "decide" and rf.lines == 6 and rf.furnaces == 133, "faction : gisement de 1 000 tuiles decide (6 lignes, 133 fours)")
  want(rp and rp.state == "decide" and rp.lines == 6, "votre equipe : meme decision")
  want(rf and rf.start == 2, "faction : depart au budget (60 fours = 2 colonnes de 24) (" .. tostring(rf and rf.start) .. ")")
  want(rp and rp.start == 1, "votre equipe, coffre vide : depart d'une colonne")
  want(fac.mega.deps[12].state == "refuse" and fac.mega.deps[12].cause:find("sans four", 1, true), "charbon : refus, minerai sans four de champ")
  want(fac.mega.deps[13].state == "refuse" and fac.mega.deps[13].cause:find("trop petit", 1, true), "150 tuiles : refus, trop petit pour un bus")
  local r14 = fac.mega.deps[14]
  want(r14 and r14.state == "decide" and math.abs(r14.plates - r14.ore / 2) < 1e-6, "recette a 2 minerais pour 1 plaque : decidee, plaques = minerai / 2")
  want(grep("[FO-MEGA] azure : gisement 11 (iron-ore, 1000 tuiles) : DECIDE") == 1, "journal : decision de la faction")
  want(grep("[FO-MEGA] player : gisement 11 (iron-ore, 1000 tuiles) : DECIDE") == 1, "journal : decision de votre equipe")
  want(grep("plan verifie sur 3 colonne(s)") >= 4, "journal : plan verifie (echantillon)")
  want(grep("REFUS : minerai sans four de champ") == 2 and grep("REFUS : gisement trop petit") == 2, "journal : refus causes")
  want(saveable(fac.mega) and saveable(pl.mega), "f.mega : nombres, chaines et tables seulement")
  -- tranche 2 (A2) : une décision ordonne le champ du gisement, avec le plafond de bandes en vol ; un refus n'ordonne rien
  do
    local by = {}
    for _, c in ipairs(WANT.calls) do by[c.team .. ":" .. c.dep] = (by[c.team .. ":" .. c.dep] or 0) + 1 end
    want(by["azure:11"] and by["azure:11"] >= 1 and by["player:11"] and by["player:11"] >= 1, "champ ordonne : gisement decide, faction ET votre equipe")
    want(by["azure:12"] == nil and by["azure:13"] == nil, "champ non ordonne : minerai sans four et gisement trop petit")
    local c11
    for _, c in ipairs(WANT.calls) do if c.dep == 11 then c11 = c end end
    want(c11 and c11.par == 3, "champ ordonne avec le plafond de bandes en vol (6 lignes -> 3) : " .. tostring(c11 and c11.par))
    want(fac.mega.deps[11].field == 77 and fac.mega.deps[11].pose_key == "champ", "decision : champ voulu note (field, pose_key)")
    want(grep("POSE : champ 77 voulu") == 4, "journal : POSE ecrite une fois par decision (2 gisements decides x 2 equipes) (" .. grep("POSE : champ 77") .. ")")
    want(Mega.summary(fac).fields == 2, "resume : champs voulus (2 decisions)")
  end
  -- la même taille : « garder », aucune ligne de plus
  local n0 = #LOGS
  local cs = { deps = deps() }
  local w0 = #WANT.calls
  for t = 3, 4 do Mega.think(fac, cs, t * 3600, { power = true }) end
  want(#LOGS == n0 and fac.mega.deps[11].state == "decide", "taille inchangee : garder, aucune ligne au journal")
  want(#WANT.calls > w0, "garder : le champ reste voulu (nouvel appel de want)")
  -- le minerai sans four est « statique » : lu une fois (tick 3600), jamais relu ; les gisements vivants tournent (le 13 « trop petit » est relu)
  want(fac.mega.deps[12].static == true and fac.mega.deps[12].tick == 3600, "charbon : statique, jamais relu (tick " .. tostring(fac.mega.deps[12].tick) .. ")")
  want(fac.mega.deps[13].static == nil and fac.mega.deps[13].tick > 3600, "gisement trop petit : relu (non statique)")
  want(fac.mega.deps[11].tick >= 3 * 3600, "gisement decide : relu a chaque tour")
  -- crise puis retour
  local w1 = #WANT.calls
  Mega.think(fac, cs, 5 * 3600, { power = true, crisis = true })
  Mega.think(fac, cs, 6 * 3600, { power = true, crisis = true })
  do
    local late = 0
    for i = w1 + 1, #WANT.calls do if WANT.calls[i].dep == 11 then late = late + 1 end end
    want(late == 0, "crise : decision en attente, le champ n'est plus ordonne (" .. late .. ")")
  end
  want(fac.mega.deps[11].state == "decide-attente" and grep("ATTENTE : crise") >= 2, "crise : attente ecrite, decision gardee")
  Mega.think(fac, cs, 7 * 3600, { power = true })
  Mega.think(fac, cs, 8 * 3600, { power = true })
  want(fac.mega.deps[11].state == "decide" and grep("GARDE : bloc deja decide") >= 1, "apres la crise : garde, sans redecider")
  want(Mega.block_for(fac, 11) ~= nil and Mega.block_for(fac, 12) == nil, "lecture de la decision")
  local sm = Mega.summary(fac)
  want(sm.decided == 2 and sm.refused == 2 and sm.furnaces > 133, "resume")
  -- gisements plus recensés : refus oubliés, décisions gardées
  do
    local only = { deps = { [11] = deps()[11] } }
    Mega.think(fac, only, 9 * 3600, { power = true })
    want(fac.mega.deps[12] == nil and fac.mega.deps[13] == nil and fac.mega.deps[14] ~= nil and fac.mega.deps[11] ~= nil,
      "gisements plus recenses : refus oublies, decisions gardees")
  end
  -- champ illisible (aucun tapis débloqué) : refus causé, distinct du minerai sans four
  do
    local nb = { key = "ocre", no_belt = true }
    Mega.think(nb, { deps = { [11] = deps()[11], [12] = deps()[12] } }, 3600, { power = true })
    want(nb.mega.deps[11].cause == "donnees : champ : tapis" and nb.mega.deps[12].cause == "minerai sans four de champ",
      "champ illisible (tapis) et minerai sans four : deux causes distinctes")
  end
  -- champ sans réseau alimenté à portée : la pose attend, cause écrite UNE fois, la décision reste
  do
    WANT.refuse = "aucun reseau alimente a moins de 40 tuiles"
    local g2 = { key = "jaune", stock = {} }
    for t = 1, 3 do Mega.think(g2, { deps = { [11] = deps()[11] } }, t * 3600, { power = true }) end
    local r = g2.mega and g2.mega.deps[11]
    want(r and r.state == "decide" and r.field == nil and r.pose_key:find("attente:", 1, true) == 1, "sans reseau : decision gardee, champ en attente")
    want(grep("jaune : gisement 11 (iron-ore, 1000 tuiles) : POSE : champ en attente : aucun reseau alimente") == 1, "sans reseau : cause ecrite une seule fois")
    local nj = 0
    for _, c in ipairs(WANT.calls) do if c.team == "jaune" then nj = nj + 1 end end
    want(nj == 1, "sans reseau : la recherche du reseau n'est redemandee qu'apres 3 min (" .. nj .. " appel(s) en 3 pensees d'une minute)")
    Mega.think(g2, { deps = { [11] = deps()[11] } }, 6 * 3600, { power = true })
    nj = 0
    for _, c in ipairs(WANT.calls) do if c.team == "jaune" then nj = nj + 1 end end
    want(nj == 2, "sans reseau : redemande apres 3 min (" .. nj .. ")")
    WANT.refuse = nil
  end
  -- courant lu A L'INSTANT : la capitalisation dit « pas fini » (2e centrale demandee) mais le reseau est sain -> la decision tient et le champ reste voulu ;
  -- panne reelle (ni centrale finie ni reseau sain) -> attente, le champ n'est plus ordonne
  do
    local g3 = { key = "rose", stock = {}, build = { sante = { healthy = true } } }
    Mega.think(g3, { deps = { [11] = deps()[11] } }, 3600, { power = false })
    local r = g3.mega and g3.mega.deps[11]
    want(r and r.state == "decide", "reseau sain malgre plant_state non fini : decision (healthy = true)")
    local w0 = #WANT.calls
    Mega.think(g3, { deps = { [11] = deps()[11] } }, 7200, { power = false })
    want(g3.mega.deps[11].state == "decide" and #WANT.calls > w0, "reseau sain : la decision tient et le champ reste voulu")
    g3.build.sante.healthy = false
    local w1 = #WANT.calls
    Mega.think(g3, { deps = { [11] = deps()[11] } }, 10800, { power = false })
    want(g3.mega.deps[11].state == "decide-attente" and #WANT.calls == w1, "panne reelle (reseau malsain, centrale non finie) : attente, champ non ordonne")
    g3.build = nil
    Mega.think(g3, { deps = { [11] = deps()[11] } }, 14400, { power = false })
    want(g3.mega.deps[11].state == "decide-attente", "sans suivi de sante ni centrale finie : pas de courant")
    local g4 = { key = "gris", stock = {}, build = { sante = { healthy = false } } }
    Mega.think(g4, { deps = { [11] = deps()[11] } }, 3600, { power = true })
    want(g4.mega.deps[11].state == "decide", "centrale finie (capitalisation) : courant meme si le suivi n'a pas encore relevee le reseau")
  end
  -- sans courant : attente, jamais de décision
  local nc = { key = "scarlet", stock = {} }
  Mega.think(nc, { deps = deps() }, 3600, { power = false })
  want(nc.mega.deps[11] and nc.mega.deps[11].state == "attente" and grep("scarlet : gisement 11 (iron-ore, 1000 tuiles) : ATTENTE : aucun reseau") == 1,
    "sans courant : attente causee")
  -- réglage éteint : rien de lu, rien d'écrit
  _G.settings.global["fo-war-mega-fonderie"].value = false
  local off = { key = "emerald" }
  local d0, l0 = calls.data, #LOGS
  want(Mega.think(off, { deps = deps() }, 3600, { power = true }) == 0 and off.mega == nil and calls.data == d0 and #LOGS == l0,
    "reglage eteint : rien de lu ni d'ecrit")
  _G.settings.global = {}
  want(Mega.on() == false, "reglage absent (avant le require de l'integrateur) : eteint")
  _G.settings.global = { ["fo-war-mega-fonderie"] = { value = true } }
  want(Mega.think(nil, nil, 0, {}) == 0 and Mega.think({}, { deps = {} }, 0, {}) == 0, "entrees vides")
  -- plan faux (contrôle doublé) : refus causé, jamais de décision
  do
    local Mf = require("shared.team.mega_fonderie")
    local fake = setmetatable({ verify = function() return { "tapis d'entree interrompu" } end }, { __index = Mf })
    local M2 = load_mega(src, fake)
    local g = { key = "violet", stock = {} }
    M2.think(g, { deps = { [11] = deps()[11] } }, 3600, { power = true })
    local r = g.mega and g.mega.deps[11]
    want(r and r.state == "refuse" and r.cause == "plan faux : tapis d'entree interrompu" and grep("violet : gisement 11 (iron-ore, 1000 tuiles) : REFUS : plan faux") == 1,
      "plan faux : refus cause, aucune decision")
  end
  return bad, nw
end

local Mega = load_mega(SRC)
local bad, nwant = suite(Mega, SRC)
for _, m in ipairs(bad) do check(false, m) end
pass = pass + nwant - #bad -- chaque assertion juste de la suite compte

-- Branchement dans la capitalisation : étape 11, champ (aucune locale de plus), courant et crise passés
local CAPI = read("script/ai3/capitalisation.lua")
check(CAPI:find('Capi.Mega = require("script.team.mega_fonderie")', 1, true) ~= nil, "capitalisation : champ Capi.Mega")
check(CAPI:find("elseif phase == 11 and Capi.Mega.on() then", 1, true) ~= nil, "capitalisation : etape 11 du cycle")
check(CAPI:find('Capi.Mega.think(f, cs, tick, { power = Auto.plant_state(f) == "fini", crisis = (view and (view.survie or view.hq_threat)) and true or false })', 1, true) ~= nil,
  "capitalisation : courant (centrale finie) et crise (survie, QG menace)")
do
  local n = 0
  for _ in CAPI:gmatch("\nlocal ") do n = n + 1 end
  check(n <= 114, "capitalisation : aucune locale de plus en tete de fichier (" .. n .. ")")
end

-- Mutants du runtime
local MUTANTS = {
  { "reglage ignore", "if not on then return 0 end", "" },
  { "journal a chaque pensee", 'if action == "decider" or key ~= rec.last then', "if true then" },
  { "budget ignore", "budget_cols = budget_cols(f, z, names) })", "budget_cols = nil })" },
  { "rendement ignore", "yield = yield_of(kind) }", "yield = 1 }" },
  { "plan non controle", "if #bad > 0 then", "if false then" },
  { "courant toujours la", "power = ctx.power == true", "power = true" },
  { "decisions purgees", '(rec.state == "refuse" or rec.state == "attente")', 'true' },
  { "refus jamais purges", 'if not cs.deps[id] and (rec.state', 'if false and (rec.state' },
  { "garde ecrite a chaque fois", '(action == "decider" or action == "garder") and "decide"', '(action == "decider") and "decide"' },
  { "attente redemandee a chaque pensee", "if rec.pose_next and tick < rec.pose_next then return rec.field end", "" },
  { "sante ignoree", "return sv ~= nil and sv.healthy == true", "return false" },
  { "sante toujours bonne", "return sv ~= nil and sv.healthy == true", "return sv ~= nil" },
  { "capitalisation ignoree", "if ctx and ctx.power == true then return true end", "" },
  { "statiques relus", "if not (known and known.static) then", "if true then" },
  { "champ jamais ordonne", 'if rec and rec.state == "decide" then order_field(f, st, dep, rec, tick) end', "" },
  { "plafond ignore", "MigChamp.want(f, dep, tick, Mp.par_max(rec))", "MigChamp.want(f, dep, tick, 99)" },
  { "champ ordonne meme refuse", 'if rec and rec.state == "decide" then order_field', "if rec then order_field" },
  { "pose ecrite a chaque fois", "if key ~= rec.pose_key then", "if true then" },
  { "decision oubliee a la crise", 'rec.state = rec.sig and "decide-attente" or "attente"', 'rec.state, rec.sig = "attente", nil' },
}
local refused = 0
for _, m in ipairs(MUTANTS) do
  local s2, n = SRC:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")))
  if n ~= 1 then check(false, "mutant introuvable (" .. n .. ") : " .. m[1])
  else
    local ok, Mm = pcall(load_mega, s2)
    local ran, sb = false, nil
    if ok then ran, sb = pcall(suite, Mm, s2) end
    local killed = (not ok) or (not ran) or (#sb > 0)
    if killed then refused = refused + 1 else print("[MEGA-MOTEUR] mutant NON refuse : " .. m[1]) end
    check(killed, "mutant refuse : " .. m[1])
  end
end
print(string.format("[MEGA-MOTEUR] mutants refuses : %d sur %d", refused, #MUTANTS))
print(string.format("[MEGA-MOTEUR] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
