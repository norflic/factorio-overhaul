--[[
  Lot TV-PLACE : banc HORS JEU du branchement (script/team/place_glue.lua, script/team/build.lua, script/faction/sites.lua) des points G37
  (sonde 30 x 30), G38 (défrichage préventif 50 x 50), G57 (sites en fenêtres de 10 x 10) et C07 (repli de placement simple).
  Les règles pures ont leurs bancs : tests/sonde_lot_test.lua, defrichage_prev_test.lua, place_simple_test.lua, sonde10_test.lua.
    lua5.2 tests/place_glue_test.lua   -> [PLACE-GLUE] BILAN : N OK, 0 ECHEC(S)
    1. G37  : bord de gisement (relevé de la sonde), états de la fabrique, un seul journal par lot, réglage éteint ;
    2. C07  : lots du repli en spirale, pose, échec, journal, compteurs ;
    3. G38  : ouverture d'un lot, quatre tâches « pre: », fin au quatrième quart, remise à la file, jeton des travaux lourds, abandon ;
    4. câblage (sources) : crochets de build.lua et de sites.lua, réglages et traductions, aucun `require` ni `pairs` d'événement ;
    5. mutants du branchement refusés.
]]
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("  ECHEC : " .. msg) end
  return ok
end

local store = {}
package.loaded["script.core.storage"] = {
  declare = function(name, init) store[name] = store[name] or init() end,
  ns = function(name) return store[name] end,
}
local SET = { ["fo-war-sonde-30"] = true, ["fo-war-sites-10"] = true, ["fo-war-defrichage-prev"] = true, ["fo-war-place-simple"] = true }
_G.settings = { global = setmetatable({}, { __index = function(_, k)
  if SET[k] == nil then error("parametre inconnu : " .. k, 2) end
  return { value = SET[k] }
end }) }
local LOGS = {}
_G.log = function(s) LOGS[#LOGS + 1] = s end
_G.game = { tick = 0 }
local function read(path) local fh = assert(io.open(path, "rb")) local s = fh:read("*a") fh:close() return s end
local function count_logs(tag) local n = 0 for _, l in ipairs(LOGS) do if l:find(tag, 1, true) then n = n + 1 end end return n end

local PG_PATH = "script/team/place_glue.lua"
local function load_pg(src)
  package.loaded["script.core.lourd"] = nil
  store = {}
  return assert(load(src or read(PG_PATH), "=" .. PG_PATH, "t", _ENV))()
end

-- surface fictive : tuiles de ressource { x, y, name, amount }
local function surface(res)
  local s = { counts = 0, finds = 0 }
  local function inside(r, a)
    return r.x >= a.area[1][1] and r.x < a.area[2][1] and r.y >= a.area[1][2] and r.y < a.area[2][2]
  end
  function s.count_entities_filtered(a)
    s.counts = s.counts + 1
    local n = 0
    for _, r in ipairs(res) do if inside(r, a) then n = n + 1 if a.limit and n >= a.limit then break end end end
    return n
  end
  function s.find_entities_filtered(a)
    s.finds = s.finds + 1
    local out = {}
    for _, r in ipairs(res) do if inside(r, a) then out[#out + 1] = { name = r.name, amount = r.amount or 100, position = { x = r.x, y = r.y } } end end
    return out
  end
  return s
end
local function ore(x, y, w, h, name)
  local out = {}
  for dx = 0, w - 1 do for dy = 0, h - 1 do out[#out + 1] = { x = x + dx + 0.5, y = y + dy + 0.5, name = name or "r_commun" } end end
  return out
end
local function team()
  return { key = "rouge", build = { lots = {}, order = {}, projects = {}, queue = {}, lat = { ox = 0, oy = 0 }, stats = {} } }
end
local function lot(i, j, state, extra)
  local l = { i = i, j = j, state = state or "libre", trees = 0 }
  for k, v in pairs(extra or {}) do l[k] = v end
  return l
end

local function battery(Pg, verbose)
  local bad, n = {}, 0
  local function want(ok, msg) n = n + 1 if not ok then bad[#bad + 1] = msg end end
  LOGS = {}
  SET["fo-war-sonde-30"], SET["fo-war-place-simple"], SET["fo-war-defrichage-prev"] = true, true, true
  -- 1. G37 ------------------------------------------------------------------------------------
  local f = team()
  local l = lot(5, 5, "libre")
  local amount = function(w, e) w.amount = w.amount or {} w.amount[e.name] = (w.amount[e.name] or 0) + (e.amount or 0) end
  -- lot [100,124) : la sonde va de 97 à 127 ; 24 tuiles de minerai en x 125 et 126, y 100..111
  local sf = surface(ore(125, 100, 2, 12))
  Pg.evaluated(f, sf, 600, "5:5", l, { res = {} }, 100, 100, 124, 124, "inconnu", amount, nil)
  want(l.edge == "r_commun", "24 tuiles dans la sonde, aucune dans le lot : lot en bord de gisement")
  want(count_logs("[FO-SONDE]") == 1, "une ligne [FO-SONDE]")
  want(LOGS[1] and LOGS[1]:find("rouge") and LOGS[1]:find("5:5") and LOGS[1]:find("r_commun") and LOGS[1]:find("30x30"), "la ligne dit l'equipe, le lot, le minerai et la sonde")
  Pg.evaluated(f, sf, 700, "5:5", l, { res = {} }, 100, 100, 124, 124, "libre", amount, nil)
  want(l.edge == "r_commun" and count_logs("[FO-SONDE]") == 1, "relevé refait : toujours en bord, pas de seconde ligne")
  want(f.build.place_n.edge == 1, "compteur edge = 1")
  local l2 = lot(6, 5, "defricher")
  Pg.evaluated(f, surface(ore(128, 100, 2, 12)), 800, "6:5", l2, { res = {} }, 100, 100, 124, 124, "inconnu", amount, nil)
  want(l2.edge == nil, "minerai en x 128 : hors de la sonde (127 exclu), pas un bord")
  local l3 = lot(7, 5, "libre")
  Pg.evaluated(f, surface(ore(125, 100, 2, 11)), 800, "7:5", l3, { res = {} }, 100, 100, 124, 124, "inconnu", amount, nil)
  want(l3.edge == nil, "22 tuiles : sous le seuil")
  local l4 = lot(8, 5, "occupe")
  Pg.evaluated(f, sf, 800, "8:5", l4, { res = {} }, 100, 100, 124, 124, "inconnu", amount, nil)
  want(l4.edge == nil, "lot occupe : jamais un bord")
  local l5 = lot(9, 5, "gisement")
  Pg.evaluated(f, sf, 800, "9:5", l5, { res = { r_commun = 30 } }, 100, 100, 124, 124, "inconnu", amount, nil)
  want(l5.edge == nil, "lot deja gisement : pas un bord")
  local sf0 = surface({})
  Pg.evaluated(f, sf0, 800, "x", lot(1, 1), { res = {} }, 100, 100, 124, 124, "inconnu", amount, nil)
  want(sf0.counts == 1 and sf0.finds == 0, "aucun minerai : un seul count (limit 1), aucune lecture d'entites")
  l.edge = "r_commun"
  Pg.evaluated(f, surface(ore(0, 0, 1, 1)), 900, "5:5", l, { res = {} }, 100, 100, 124, 124, "libre", amount, nil)
  want(l.edge == nil and f.build.place_n.edge_gone == 1, "le minerai a disparu : le bord s'efface (compteur edge_gone)")
  SET["fo-war-sonde-30"] = false
  local lo = lot(5, 6, "libre")
  local sfo = surface(ore(125, 100, 2, 12))
  Pg.evaluated(f, sfo, 600, "5:6", lo, { res = {} }, 100, 100, 124, 124, "inconnu", amount, nil)
  want(lo.edge == nil and sfo.counts == 0 and sfo.finds == 0, "reglage eteint : aucun appel moteur, aucune marque")
  local fab = Pg.states_for("fabrique")
  want(fab[1].no_edge == nil and fab[1].libre and not fab[1].gisement, "eteint : Lm.states_for tel quel (pas de marque)")
  SET["fo-war-sonde-30"] = true
  fab = Pg.states_for("fabrique")
  want(fab[1].no_edge == true and fab[1].libre and fab[1].defricher, "allume : la fabrique porte la marque no_edge")
  want(Pg.states_for("fonte")[2].gisement and Pg.states_for("fonte")[1].no_edge == nil, "la fonte garde ses etats sans marque")
  -- 2. C07 ------------------------------------------------------------------------------------
  LOGS = {}
  local g2 = team()
  local b = g2.build
  b.lots = {
    ["0:0"] = lot(0, 0, "occupe"), ["1:0"] = lot(1, 0, "libre", { used = 3 }), ["0:1"] = lot(0, 1, "libre", { edge = "r_commun" }),
    ["-1:0"] = lot(-1, 0, "libre", { bad = 5 }), ["0:-1"] = lot(0, -1, "defricher"), ["2:0"] = lot(2, 0, "gisement"), ["1:1"] = lot(1, 1, "libre"),
  }
  local c1 = Pg.simple_candidates(b, { libre = true, defricher = true, no_edge = true })
  local ks = {}
  for _, c in ipairs(c1) do ks[#ks + 1] = c.k end
  want(table.concat(ks, ",") == "0:-1,-1:0,1:1", "lots du repli : spirale, pris et bord ecartes, bad ignore : 0:-1,-1:0,1:1 ; recu " .. table.concat(ks, ","))
  want(c1[1].l == b.lots["0:-1"], "chaque candidat porte son lot")
  local calls = {}
  local placed = Pg.simple(g2, { id = 7 }, { gen = "patron" }, "pas de lot", { { libre = true, defricher = true, no_edge = true } }, function(states, fo)
    calls[#calls + 1] = { states = states, fo = fo }
    if #calls == 1 then return { lot = "-1:0" }, nil end
    return nil, "x"
  end, 1200)
  want(placed and placed.lot == "-1:0", "le repli rend la place trouvee")
  want(calls[1] and calls[1].fo.margin == 0 and calls[1].fo.nobad == true and #calls[1].fo.simple_lots == 3 and calls[1].fo.toward == nil, "options : marge 0, nobad, 3 lots, rien d'autre")
  want(count_logs("[FO-PLACE-SIMPLE]") == 1 and LOGS[1]:find("projet 7") and LOGS[1]:find("pas de lot") and LOGS[1]:find("lot %-1:0") and LOGS[1]:find("ne grandit pas"), "journal : projet, cause, lot pose")
  want(g2.build.place_n.simple_ok == 1, "compteur simple_ok")
  calls = {}
  local none, why = Pg.simple(g2, { id = 8 }, { gen = "patron" }, "pas de lot", { { libre = true, defricher = true, no_edge = true } }, function(states, fo)
    calls[#calls + 1] = 1
    return nil, "meme raison"
  end, 1300)
  want(none == nil and why == "pas de lot", "echec : la raison d'avant est rendue (le treillis grandit)")
  want(g2.build.place_n.simple_ko == 1 and count_logs("[FO-PLACE-SIMPLE]") == 2 and LOGS[2]:find("le treillis grandit"), "echec : compteur et journal")
  local empty = team()
  empty.build.lots = { ["0:0"] = lot(0, 0, "occupe") }
  local called = false
  Pg.simple(empty, { id = 9 }, { gen = "patron" }, "x", { { libre = true } }, function() called = true return nil end, 1)
  want(not called, "aucun lot eligible : place_module n'est pas appele")
  -- plusieurs ensembles d'etats : le second est essaye
  local seq = {}
  Pg.simple(g2, { id = 10 }, { gen = "smelter" }, "x", { { libre = true, defricher = true }, { gisement = true } }, function(states)
    seq[#seq + 1] = states.gisement and "gisement" or "libre"
    return nil
  end, 1400)
  want(seq[1] == "libre" and seq[2] == "gisement", "la fonte essaie ses lots libres puis son gisement")
  -- 3. G38 ------------------------------------------------------------------------------------
  LOGS = {}
  local h = team()
  local hb = h.build
  hb.lots = { ["1:0"] = lot(1, 0, "defricher", { trees = 40 }), ["0:1"] = lot(0, 1, "defricher", { trees = 12 }), ["3:3"] = lot(3, 3, "libre"), ["0:0"] = lot(0, 0, "occupe") }
  local out = {}
  SET["fo-war-defrichage-prev"] = false
  Pg.defprev_tasks(h, out, 10000)
  want(#out == 0 and hb.defprev == nil, "reglage eteint : aucune tache")
  SET["fo-war-defrichage-prev"] = true
  hb.projects = { [1] = { state = "defrichage" } }
  hb.order = { 1 }
  Pg.defprev_tasks(h, out, 10000)
  want(#out == 0 and hb.defprev.open == nil, "un projet defriche : on ne commence pas")
  hb.projects[1].state = "fini"
  h.threatened_until = 20000
  Pg.defprev_tasks(h, out, 10000)
  want(#out == 0, "menace en cours : rien")
  h.threatened_until = nil
  Pg.defprev_tasks(h, out, 10000)
  want(#out == 4 and hb.defprev.open == "1:0", "lot le plus proche du QG (couronne 1, d2 1, puis j : 1:0 avant 0:1) ouvert : 4 taches ; recu " .. tostring(hb.defprev.open))
  local t1 = out[1]
  want(t1 and t1.kind == "clear" and t1.prio == Pg.PRIO_PREV and Pg.PRIO_PREV < 55 and t1.domain == "logistique" and t1.ia1d.pid == 0 and t1.ia1d.mode == "clear", "tache de defrichage a la priorite la plus basse, pid 0")
  want(t1.ia1d.seg == "pre:1:0:1" and t1.key == "ia1d:pre:1:0:1", "cle de la tache : quart 1 du lot 1:0")
  local r1 = t1.ia1d.rect
  want(r1[3] - r1[1] == 25 and r1[4] - r1[2] == 25, "quart de 25 x 25")
  -- lot (1,0) : x0 = 28 - 12 = 16, y0 = -12 ; zone 50x50 = (3, -25)-(53, 25)
  want(r1[1] == 3 and r1[2] == -25, "zone 50 x 50 centree sur le lot (1,0) : coin (3, -25)")
  want(count_logs("[FO-DEFRICHAGE-PREV]") == 1 and LOGS[1]:find("lot 1:0") and LOGS[1]:find("50x50") and LOGS[1]:find("4 quarts"), "journal de l'ouverture")
  want(hb.lots["1:0"].pre_n == 1 and hb.place_n.prev_lots == 1, "tentative comptee")
  out = {}
  Pg.defprev_tasks(h, out, 10100)
  want(#out == 4 and hb.defprev.open == "1:0", "tant que le lot est ouvert, memes 4 taches et pas de second lot")
  Pg.defprev_cleared(h, "pre:1:0:2", 10200)
  Pg.defprev_cleared(h, "pre:1:0:2", 10210)
  out = {}
  Pg.defprev_tasks(h, out, 10300)
  want(#out == 3 and out[1].ia1d.seg == "pre:1:0:1" and out[2].ia1d.seg == "pre:1:0:3", "un quart coupe (deux fois : sans effet) : 3 taches restantes")
  Pg.defprev_cleared(h, "pre:9:9:1", 10300)
  want(hb.defprev.open == "1:0", "un quart d'un autre lot est ignore")
  Pg.defprev_cleared(h, "pre:1:0:1", 10400)
  Pg.defprev_cleared(h, "pre:1:0:3", 10400)
  Pg.defprev_cleared(h, "pre:1:0:4", 10500)
  want(hb.defprev.open == nil and hb.defprev.last == 10500, "4 quarts coupes : fini, repos note")
  want(#hb.queue == 1 and hb.queue[1][1] == "lot" and hb.queue[1][2] == "1:0", "le lot est remis a la file d'evaluation")
  want(hb.lots["1:0"].pre_wait == "defricher" and hb.place_n.prev_done == 1 and count_logs("4 quarts coupes") == 1, "etat d'avant garde, journal de fin")
  out = {}
  Pg.defprev_tasks(h, out, 10600)
  want(#out == 0, "repos apres un lot : aucune tache")
  -- resultat a la reevaluation
  hb.lots["1:0"].state, hb.lots["1:0"].trees = "libre", 0
  Pg.evaluated(h, surface({}), 10700, "1:0", hb.lots["1:0"], { res = {} }, 16, -12, 40, 12, "defricher", amount, nil)
  want(count_logs("releve apres le defrichage preventif : defricher -> libre") == 1 and hb.place_n.prev_libre == 1 and hb.lots["1:0"].pre_wait == nil, "resultat ecrit : defricher -> libre")
  -- lot suivant apres le repos
  out = {}
  Pg.defprev_tasks(h, out, 10500 + 3600)
  want(#out == 4 and hb.defprev.open == "0:1", "le repos passe : le lot suivant (0:1)")
  -- abandon
  out = {}
  Pg.defprev_tasks(h, out, 10500 + 3600 + 21601)
  want(hb.place_n.prev_abandon == 1, "lot qui traine : abandonne")
  want(hb.place_n.prev_abandon == 1 and count_logs("abandonne") == 1, "abandon compte et ecrit")
  -- jeton des travaux lourds
  local Lourd = require("script.core.lourd")
  local job = { seg = "pre:1:0:1" }
  want(Pg.defprev_gate(h, job, 50000) == nil, "jeton libre : on coupe")
  Lourd.take(50001, "autre", nil, 64)
  local r = Pg.defprev_gate(h, job, 50001)
  want(r == "more" and job.waits == 1, "jeton pris par un autre travail : le PNJ attend")
  local seen_done = false
  for i = 1, 45 do if Pg.defprev_gate(h, job, 50001) == "done" then seen_done = true end end
  want(seen_done, "patience epuisee (plus de Dp.WAIT_MAX refus) : la tache est rendue")
  want(Pg.defprev_gate(h, { seg = "h:0:1" }, 50002) == nil and Pg.defprev_gate(h, { seg = nil }, 50002) == nil, "une rue ordinaire ne passe pas par ce jeton")
  Pg.cut(h, "pre:1:0:1", 3); Pg.cut(h, "h:0:1", 5); Pg.cut(h, "pre:1:0:1", 0)
  want(h.build.place_n.prev_cut == 3, "obstacles coupes comptes pour les seules taches preventives")
  -- remote
  local rep = Pg.remote(h, "report")
  want(rep and rep.counters.prev_lots == 2 and rep.sonde == true and rep.simple == true and rep.defprev == true and rep.sites == true, "rapport des bancs")
  want(Pg.remote(h, "autre") == nil and Pg.remote(nil, "report") == nil, "commande inconnue ou equipe absente : nil")
  -- 4. limite de lignes
  local m = team()
  m.build.lots = {}
  for i = 1, 30 do
    m.build.lots["a" .. i] = lot(10 + i, 0, "libre")
  end
  for i = 1, 30 do
    Pg.evaluated(m, surface(ore(125 + 0, 100, 2, 12)), 600 + i, "a" .. i, m.build.lots["a" .. i], { res = {} }, 100, 100, 124, 124, "inconnu", amount, nil)
  end
  want(count_logs("[FO-SONDE]") <= 1 + Pg.LOGS and m.build.place_n.edge == 30, "journal borne a Pg.LOGS lignes, compteur exact (30)")
  return bad, n
end

local Pg0 = load_pg()
local bad, n = battery(Pg0)
for _, m in ipairs(bad) do check(false, m) end
pass = pass + (n - #bad)

-- 4. Câblage (sources) --------------------------------------------------------------------------
local BUILD = read("script/team/build.lua")
local SITES = read("script/faction/sites.lua")
local LG = read("script/team/lots_minerai_glue.lua")
local PG = read(PG_PATH)
local function has(src, text, msg) check(src:find(text, 1, true) ~= nil, msg .. " (" .. text .. ")") end
has(BUILD, 'Build.Place = require("script.team.place_glue")', "build.lua : champ Build.Place")
has(BUILD, "if states.no_edge and l.edge then ok_state = false end", "candidates : la marque no_edge ecarte un lot en bord")
has(BUILD, "(opts and opts.simple_lots) or candidates(b, kind_states, toward, res)", "place_module : lots du repli simple")
has(BUILD, "Build.Place.evaluated(f, surface, tick, item[2], l, s, x0, y0, x1, y1, old,", "eval_one : sonde large et resultat du defrichage")
has(BUILD, "if not main and Build.Place.simple_on() then", "plan_project : repli simple avant la croissance")
has(BUILD, "Build.Place.simple(f, p, g, why, Build.LotsMinerai.states(f, g.gen),", "plan_project : repli simple, memes etats")
has(BUILD, "Build.Place.defprev_tasks(f, tasks, tick)", "Build.think : taches du defrichage preventif")
has(BUILD, "local gate = Build.Place.defprev_gate(f, job, tick)", "Build.work : jeton des travaux lourds")
has(BUILD, "Build.Place.cut(f, job.seg, did)", "Build.work : compteur des obstacles coupes")
has(BUILD, 'key:sub(1, 4) == "pre:" then return Build.Place.defprev_cleared(f, key, game.tick)', "street_cleared : quart du defrichage preventif")
has(BUILD, "place = function(key, cmd) return Build.Place.remote(team_of_key(key), cmd) end", "interface distante place")
has(BUILD, "if not (opts and opts.simple_lots) then bump(b.stats.plan_refused, last) end", "le repli simple ne fausse pas plan_refused")
has(BUILD, "place_module(f, surface, g, states, qg, nil, fo)", "le repli simple passe par place_module")
has(LG, "Pg.states_for(Lg.kind(gen))", "Lots_minerai.states : etats avec la marque du bord")
has(SITES, 'local S10 = require("shared.faction.sonde10")', "sites.lua : regle pure des fenetres")
has(SITES, "local function enough(f, surface, cx, cy, area, tick)", "sites.lua : sonde en fenetres")
has(SITES, "if why then rich, area = enough(f, surface, cx, cy, area, tick) end", "sites.lua : chunk injoignable")
has(SITES, "if free then rich, area = enough(f, surface, cx, cy, area, tick) end", "sites.lua : chunk libre")
has(SITES, "[FO-SITES-10]", "sites.lua : ligne de journal")
has(SITES, "if n >= MIN_RESOURCES then return true, area end", "sites.lua : le test par chunk reste le premier")
local SETTINGS = read("settings/place.lua")
for _, name in ipairs({ "fo-war-sonde-30", "fo-war-sites-10", "fo-war-defrichage-prev", "fo-war-place-simple" }) do
  check(SETTINGS:find('name = "' .. name .. '"', 1, true) ~= nil and select(2, SETTINGS:gsub("default_value = true", "")) == 4, "settings/place.lua declare " .. name .. " allume")
  local fr, en = read("locale/fr/place.cfg"), read("locale/en/place.cfg")
  check(fr:find(name .. "=", 1, true) ~= nil and en:find(name .. "=", 1, true) ~= nil, "traductions FR et EN de " .. name)
  local esc = name:gsub("%-", "%%-")
  check(select(2, fr:gsub(esc .. "=", "")) == 2 and select(2, en:gsub(esc .. "=", "")) == 2, "nom et description de " .. name .. " en FR et EN")
end
-- regles de code : aucun require en evenement, aucun pairs non trie
local function no_require_in_function(src, name)
  local bad_lines = {}
  local ln = 0
  for line in (src .. "\n"):gmatch("(.-)\n") do
    ln = ln + 1
    if line:match("^%s+.*[^%w_]require%(") and not line:match("^%s*%-%-") then bad_lines[#bad_lines + 1] = ln end
  end
  check(#bad_lines == 0, name .. " : aucun require dans une fonction (F24) ; lignes " .. table.concat(bad_lines, ","))
end
no_require_in_function(PG, "place_glue.lua")
for _, f in ipairs({ "shared/team/sonde_lot.lua", "shared/team/defrichage_prev.lua", "shared/team/place_simple.lua", "shared/faction/sonde10.lua" }) do
  local src = read(f)
  check(not src:find("[^i]pairs%(") and not src:find("^pairs%("), f .. " : aucun pairs (listes triees)")
  check(not src:find("math%.random") and not src:find("os%.clock") and not src:find("game%."), f .. " : aucun hasard, aucun temps mesure, aucune API du jeu")
  check(not src:find("global"), f .. " : ne nomme pas global")
end
check(select(2, PG:gsub("[^i]pairs%(", "")) == 0, "place_glue.lua : aucun pairs (next seul, cles triees)")
check(not PG:find("[^%w_]global%.%a") and not PG:find("storage%."), "place_glue.lua : ne nomme pas global")

-- 4 bis. Coût en instructions Lua (debug.sethook, déterministe : jamais un temps mesuré) des chemins ajoutés ---------------------------
do
  local function cost(fn, n)
    local c = 0
    debug.sethook(function() c = c + 1 end, "", 1)
    for _ = 1, n do fn() end
    debug.sethook()
    return c / n
  end
  local Dp = require("shared.team.defrichage_prev")
  local f = team()
  for i = -9, 9 do for j = -9, 9 do f.build.lots[i .. ":" .. j] = lot(i, j, (i % 3 == 0) and "defricher" or "libre") end end
  f.build.lots["0:0"].state = "occupe"
  local out = {}
  f.build.defprev = Dp.new()
  f.build.defprev.last = 1000
  local c_idle = cost(function() out = {} Pg0.defprev_tasks(f, out, 2000) end, 50)
  f.build.defprev = Dp.new()
  local c_open = cost(function() f.build.defprev = Dp.new() out = {} Pg0.defprev_tasks(f, out, 100000) end, 5)
  local c_four = cost(function() out = {} Pg0.defprev_tasks(f, out, 100100) end, 50)
  local c_simple = cost(function() Pg0.simple_candidates(f.build, { libre = true, defricher = true, no_edge = true }) end, 20)
  local sf = { count_entities_filtered = function() return 0 end, find_entities_filtered = function() return {} end }
  local l = lot(1, 1)
  local c_eval = cost(function() Pg0.evaluated(f, sf, 1, "a", l, { res = {} }, 0, 0, 24, 24, "inconnu", nil, nil) end, 50)
  print(string.format("[PLACE-GLUE] cout (instructions Lua, sethook) : defprev au repos %.0f ; ouverture d'un lot (361 lots) %.0f ; lot ouvert (4 taches) %.0f ; lots du repli simple (361 lots) %.0f ; sonde sans minerai (1 count) %.0f",
    c_idle, c_open, c_four, c_simple, c_eval))
  check(c_idle < 500, "defrichage preventif au repos : moins de 500 instructions par pensee (" .. c_idle .. ")")
  check(c_four < 2000, "defrichage preventif, lot ouvert : moins de 2 000 instructions (" .. c_four .. ")")
  check(c_open < 100000, "ouverture d'un lot : moins de 100 000 instructions, une fois par lot (" .. c_open .. ")")
  check(c_simple < 100000, "lots du repli simple : moins de 100 000 instructions, une fois par echec de plan (" .. c_simple .. ")")
  check(c_eval < 500, "sonde large sans minerai : moins de 500 instructions par lot evalue (" .. c_eval .. ")")
end

-- 5. Mutants -------------------------------------------------------------------------------------
local MUT = {
  { "if not Pg.sonde_on() then return end\n  if l.state ~= \"libre\"", "if l.state ~= \"libre\"" },
  { "if l.state ~= \"libre\" and l.state ~= \"defricher\" then return end", "" },
  { "surface.count_entities_filtered({ area = area, type = \"resource\", limit = 1 }) == 0", "false" },
  { "local wx0, wy0, wx1, wy1 = Sl.rect(x0, y0, x1, y1)", "local wx0, wy0, wx1, wy1 = x0, y0, x1, y1" },
  { "if Pg.sonde_on() then return Sl.states_for(kind) end", "if false then return Sl.states_for(kind) end" },
  { "if not was then\n    bump(f, \"edge\")", "if true then\n    bump(f, \"edge\")" },
  { "fo.simple_lots = cands", "" },
  { "if #cands > 0 then", "if true then" },
  { "bump(f, \"simple_ok\")", "" },
  { "return nil, why\nend\n\n----", "return nil, \"autre\"\nend\n\n----" },
  -- (le garde Dp.gate de defprev_tasks est un pré-filtre de coût : Dp.pick rejoue la même porte, mutant équivalent, non listé)
  { "if state ~= \"defrichage\"", "if state ~= \"defrichage\"" }, -- (témoin : motif absent, ignoré plus bas)
  { "if p and p.state == \"defrichage\" then clearing = clearing + 1 end", "" },
  { "prio = Pg.PRIO_PREV", "prio = 99" },
  { "Pg.PRIO_PREV = 40", "Pg.PRIO_PREV = 80" },
  { "if Dp.quarter_done(st, q) then", "if true then" },
  { "b.queue[#b.queue + 1] = { \"lot\", k }", "" },
  { "l.pre_n = (l.pre_n or 0) + 1", "" },
  { "if Lourd.take(tick, \"defprev:\" .. tostring(f.key or \"player\"), nil, Dp.COST) then", "if true then" },
  { "if job.waits > Dp.WAIT_MAX then", "if false then" },
  { "if Dp.expired(st, tick) then abandon(f, st, tick, \"trop long\") end", "" },
  { "if n > 0 and type(seg) == \"string\" and seg:sub(1, 4) == \"pre:\" then", "if n > 0 then" },
  { "return a.ia1d", "return a.ia1d" }, -- (témoin : ignoré)
}
local killed, tried = 0, 0
for i, mu in ipairs(MUT) do
  local s, e = PG:find(mu[1], 1, true)
  if s and mu[1] ~= mu[2] then
    tried = tried + 1
    local src2 = PG:sub(1, s - 1) .. mu[2] .. PG:sub(e + 1)
    local ok, mod = pcall(load_pg, src2)
    local survived = false
    if ok then
      local ok2, b2 = pcall(battery, mod)
      survived = ok2 and #b2 == 0
    end
    if survived then check(false, "mutant " .. i .. " survit : " .. mu[1]:sub(1, 80)) else killed = killed + 1 end
  elseif mu[1] ~= mu[2] then
    check(false, "mutant " .. i .. " : motif introuvable : " .. mu[1]:sub(1, 80))
  end
end
pass = pass + killed
print(string.format("[PLACE-GLUE] BILAN : %d OK, %d ECHEC(S) (dont %d mutants sur %d refuses)", pass, fail, killed, tried))
os.exit(fail == 0 and 0 or 1)
