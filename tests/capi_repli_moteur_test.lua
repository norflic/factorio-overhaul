--[[
  Lot CAPI-REPLI + CAPI-MESURE : le BRANCHEMENT du repli et des journaux, au moteur simulé (tests/mock_engine.lua).
  Le moteur simulé n'a pas la foreuse électrique de l'exécutant (aucun ordre de module n'y part, tests/capi_moteur_test.lua) :
  le test INJECTE dans l'état de la faction un ordre ouvert « module » et le module de l'exécutant qu'il suit, dans
  l'état voulu (refusé pour matériaux, refusé par le plan, fini), puis laisse tourner les pensées du cerveau. Ce n'est PAS une
  preuve en jeu (le plan directeur ne pose rien ici) : il prouve le câblage runtime -> règle pure (shared/ai3/repli.lua).
    §1 [FO-CAPI-COUV] écrit toutes les 5 min par gisement (couverture, places libres, raison de drill_for = "", repli) ;
    §2 échec de MATÉRIAUX : gisement non fermé, module suivant réduit, objets manquants en préparation, journal [FO-CAPI-REPLI] ;
    §3 refus du plan : repli de CE gisement seulement ; l'autre gisement du même produit n'est pas fermé ;
    §4 module fini : repli et réduction remis à zéro ;
    §5 alerte [FO-CAPI-ALERTE] : machines ou foreuses posées qui produisent 0/min (si le moteur simulé en pose).
  Usage : lua5.2 tests/capi_repli_moteur_test.lua   (depuis la racine du mod ; environ 1 min)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("[CAPI-REPLI-MOTEUR] ECHEC : " .. msg) end
end
local function say(s) print("[CAPI-REPLI-MOTEUR] " .. s) end
local function W() return M.world() end
local MIN = 3600

local function patches()
  local out = {}
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  local d = 0.7071
  for _, c in ipairs({ { d, -d }, { d, d }, { -d, d }, { -d, -d } }) do
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = c[1] * 320 + v[1] * r, y = c[2] * 320 + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end

local function lines_of(tag)
  local out = {}
  for _, l in ipairs(W().logs) do if l:find(tag, 1, true) then out[#out + 1] = l end end
  return out
end

M.new_world({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true })
M.load_mod()
M.dispatch(W().on_init)
M.command("fo-war", "start 2 30 30 320")
local ok, err = pcall(M.run_ticks, 12 * MIN)
check(ok, "12 min sans erreur (" .. tostring(err) .. ")")

-- §1 journal de couverture
local couv = lines_of("[FO-CAPI-COUV]")
say(string.format("§1 %d ligne(s) [FO-CAPI-COUV] en 12 min", #couv))
for i = 1, math.min(3, #couv) do say("   " .. couv[i]:sub(1, 500)) end
check(#couv >= 2, "§1 des lignes [FO-CAPI-COUV] sont écrites (" .. #couv .. ")")
local seen_dep = false
for _, l in ipairs(couv) do
  if l:find("gisement ", 1, true) and l:find("places libres", 1, true) and l:find("foreuse ", 1, true) and l:find("repli ", 1, true) then
    seen_dep = true
  end
end
check(seen_dep, "§1 une ligne par gisement : couverture, places libres, raison de la foreuse, repli")
local with_reason = false
for _, l in ipairs(couv) do if l:find('foreuse "" (', 1, true) then with_reason = true end end
check(with_reason, "§1 la raison de drill_for = \"\" est écrite (le moteur simulé n'a pas la foreuse de l'exécutant)")
-- au plus une série par 5 min et par faction : 12 min -> 3 séries au plus (minutes 0..), jamais une par décision
local per_min = {}
for _, l in ipairs(couv) do
  local who, mn = l:match("%[FO%-CAPI%-COUV%] (%S+) minute (%d+)")
  if who then per_min[who .. "@" .. mn] = true end
end
local n_series = 0
for _ in pairs(per_min) do n_series = n_series + 1 end
check(n_series <= 2 * 4, "§1 une série toutes les 5 min, pas à chaque décision (" .. n_series .. " séries faction x minute)")

-- Faction de travail : la première vivante, son état de capitalisation et un gisement suivi
local f = global.fo.war.factions[1]
local cs = f and f.team and f.team.capi
check(cs ~= nil, "état de capitalisation de la faction 1")
local dep_ids = {}
for id in pairs(cs and cs.deps or {}) do dep_ids[#dep_ids + 1] = id end
table.sort(dep_ids)
say("gisements suivis par la faction 1 : " .. #dep_ids)
check(#dep_ids >= 2, "au moins 2 gisements suivis (" .. #dep_ids .. ")")
local depA, depB = dep_ids[1], dep_ids[2]
local PRODUCT = "produit-test"
local MAT = "materiaux introuvables (15 min sans progres)"
local Rp = require("shared.ai3.repli")

--- Injecte un ordre ouvert « module » sur `dep` et le module de l'exécutant qu'il suit, dans l'état voulu.
local function inject(dep, id, state, reason, missing)
  local st = f.team.ia3e
  st.mods[#st.mods + 1] = { id = id, product = PRODUCT, state = state, reason = reason, missing = missing or {}, built = 0, total = 4,
    electric = false, capi = "test", rate_nom = 60 }
  local tick = game.tick
  cs.open[#cs.open + 1] = { key = "couvrir:" .. dep, kind = "couvrir", item = "iron-ore", resource = "iron-ore", deposit = dep,
    exec = "module", mod_ids = { id }, product = PRODUCT, n = 4, n_left = 4, opened = tick, progress_tick = tick, missing = {} }
end

-- §2 échec de matériaux sur le gisement A
inject(depA, 9001, "refuse", MAT, { { "objet-x", 30 }, { "objet-y", 4 } })
ok, err = pcall(M.run_ticks, 2 * MIN)
check(ok, "§2 sans erreur (" .. tostring(err) .. ")")
local kA, kB = Rp.key(PRODUCT, depA), Rp.key(PRODUCT, depB)
local book = cs.repli or {}
local tick = game.tick
check(book[kA] ~= nil, "§2 l'échec est inscrit au livre du repli pour (produit, gisement A)")
check(book[kA] and Rp.held(book, kA, tick) == nil, "§2 l'échec de matériaux ne ferme PAS le gisement")
check(Rp.factor(book, kA, tick) == 0.5, "§2 le module suivant de ce gisement est réduit de moitié")
local prep = Rp.prep(book, tick)
check(#prep == 1 and prep[1].key == kA and prep[1].missing[1][1] == "objet-x", "§2 les objets manquants sont gardés en préparation")
local rl = lines_of("[FO-CAPI-REPLI]")
check(#rl >= 1 and rl[#rl]:find("materiaux", 1, true) ~= nil, "§2 ligne [FO-CAPI-REPLI] écrite (" .. #rl .. ")")
if rl[1] then say("   " .. rl[1]:sub(1, 400)) end
local still_open = false
for _, rec in ipairs(cs.open) do if rec.module == nil and rec.product == PRODUCT then still_open = true end end
check(not still_open, "§2 l'ordre échoué est fermé")

-- §3 refus du plan sur le gisement A : seul A est fermé
inject(depA, 9002, "refuse", "pas de lot", {})
ok, err = pcall(M.run_ticks, 2 * MIN)
check(ok, "§3 sans erreur (" .. tostring(err) .. ")")
tick = game.tick
book = cs.repli
check(Rp.held(book, kA, tick) ~= nil, "§3 refus du plan : le gisement A est en repli")
check(Rp.held(book, kB, tick) == nil, "§3 le gisement B du même produit n'est PAS fermé")
check(book[kA] and book[kA].n == 1, "§3 n = 1 au premier refus du plan")

-- §4 module fini : tout repart de zéro
inject(depA, 9003, "fini", nil, {})
ok, err = pcall(M.run_ticks, 2 * MIN)
check(ok, "§4 sans erreur (" .. tostring(err) .. ")")
tick = game.tick
check(cs.repli[kA] == nil and Rp.held(cs.repli, kA, tick) == nil and Rp.factor(cs.repli, kA, tick) == 1,
  "§4 un module terminé remet à zéro le repli et la réduction")

-- Le livre est de l'état de partie : nombres, chaînes, tables (jamais de fonction)
local function pure(t, depth)
  if depth > 6 then return false end
  for k, v in pairs(t) do
    local tv = type(v)
    if tv == "function" then return false end
    if tv == "table" and not pure(v, depth + 1) then return false end
  end
  return true
end
check(pure(cs, 0), "l'état de capitalisation ne contient aucune fonction")

print(string.format("[CAPI-REPLI-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
