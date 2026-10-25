--[[
  Tests hors jeu de l'expansion des factions guidée par la carte (lot IA2-b).
  Usage, depuis la racine du mod :   lua5.2 tests/valeur_test.lua

  Vérifie :
    1. valeur d'un site (shared/faction/valeur.lua, pur) : richesse croissante et saturante, accès depuis le
       TERRITOIRE (avant-postes) et non depuis le seul QG, danger et contestation vus, × prudence ; portée × ambition ×
       appétit du chef ; site perdu récemment évité puis oublié ;
    2. choix : déterministe, hasard borné (jamais hors de la marge de la meilleure valeur), rangs par valeur et par
       distance ;
    3. front de prospection : un tour sur deux au QG, fronts asséchés sautés, danger évité ;
    4. éventail de départ : 64 axes × 16 emplacements, écarts ≥ 41 tuiles, tous à 40 tuiles ou plus du QG, les 5
       premiers d'un même côté (demi-plan de l'axe) ;
    5. moteur simulé : axe tiré du flux 100 + id, gisements de départ d'un même côté, sites choisis par valeur
       (lignes « [FO-STRAT] site » avec valeur et rang), même graine = mêmes choix, orphelins d'un avant-poste perdu
       repris à la reconstruction et démontés par un ouvrier.
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local V = require("shared.faction.valeur")
local Tr = require("shared.faction.traits")

local function ctx(o)
  o = o or {}
  return { hq = o.hq or { x = 0, y = 0 }, anchors = o.anchors or { { x = 0, y = 0 } }, rivals = o.rivals or {},
    lost = o.lost or {}, tick = o.tick or 0, ambition = o.ambition or 1000, prudence = o.prudence or 1000,
    appetite = o.appetite or 1000 }
end

---------------------------------------------------------------------------------------------------
section("Valeur d'un site (pur)")
do
  local c = ctx()
  local poor = V.value({ x = 100, y = 0, rich = 10000 }, c)
  local rich = V.value({ x = 100, y = 0, rich = 100000 }, c)
  local richer = V.value({ x = 100, y = 0, rich = 1000000 }, c)
  check(rich > poor and richer > rich, "richesse croissante (" .. poor .. " < " .. rich .. " < " .. richer .. ")")
  check(richer - rich < rich - poor, "richesse saturante")
  check(V.components({ x = 100, y = 0 }, c).rich == V.RICH_UNKNOWN, "richesse inconnue (partie existante) : neutre")
  -- Accès depuis le territoire : un site à 400 tuiles du QG mais à 60 d'un avant-poste bat un site à 300 tuiles
  -- du QG loin de tout.
  local t = ctx({ anchors = { { x = 0, y = 0 }, { x = 340, y = 0 } } })
  local near_outpost = V.components({ x = 400, y = 0, rich = 60000 }, t)
  local lone = V.components({ x = 0, y = 300, rich = 60000 }, t)
  check(near_outpost.d_terr == 60 and near_outpost.d_hq == 400, "distance au territoire 60, au QG 400")
  check(near_outpost.value > lone.value, "un site près de nos avant-postes bat un site plus proche du QG mais isolé ("
    .. near_outpost.value .. " > " .. lone.value .. ")")
  -- Danger vu : QG rival et avant-poste rival ; contestation à moins de 64 tuiles ; × prudence.
  local safe = V.components({ x = 100, y = 0, rich = 60000 }, c)
  local hot = V.components({ x = 100, y = 0, rich = 60000 }, ctx({ rivals = { { x = 300, y = 0, hq = true }, { x = 140, y = 0 } } }))
  check(hot.danger > 0 and hot.contest == V.CONTEST and hot.value < safe.value, "danger et contestation vus (" .. hot.danger .. ", " .. hot.contest .. ")")
  local bold = V.components({ x = 100, y = 0, rich = 60000 }, ctx({ prudence = 500, rivals = { { x = 300, y = 0, hq = true }, { x = 140, y = 0 } } }))
  check(bold.danger < hot.danger and bold.value > hot.value, "la prudence pèse sur le danger (" .. bold.danger .. " < " .. hot.danger .. ")")
  check(V.components({ x = 100, y = 0 }, ctx({ rivals = { { x = 700, y = 0, hq = true }, { x = 400, y = 0 } } })).danger == 0,
    "rivales lointaines : aucun danger")
  -- Site perdu récemment : danger dégressif, oublié après 30 min.
  local lost = { { x = 100, y = 10, tick = 0 } }
  local d0 = V.components({ x = 100, y = 0 }, ctx({ lost = lost, tick = 60 })).danger
  local d1 = V.components({ x = 100, y = 0 }, ctx({ lost = lost, tick = 15 * 3600 })).danger
  local d2 = V.components({ x = 100, y = 0 }, ctx({ lost = lost, tick = 31 * 3600 })).danger
  check(d0 > d1 and d1 > 0 and d2 == 0, "site perdu : danger " .. d0 .. " puis " .. d1 .. " puis " .. d2)
  -- Terrain et eau.
  local rough = V.components({ x = 100, y = 0, rich = 60000, rough = 50, cliffs = 2 }, c)
  check(rough.terrain == math.min(V.TERRAIN_MAX, 50 * V.ROUGH + 2 * V.CLIFF), "terrain : arbres, rochers, falaises")
  check(V.components({ x = 100, y = 0, water = true }, c).water == V.WATER, "eau proche")
  -- Portée : ambition et appétit du chef.
  check(V.reach(1500, 1000) > V.reach(1000, 1000) and V.reach(500, 1000) < V.reach(1000, 1000), "portée × ambition")
  check(V.appetite({ { key = "expansion", w = 1000 } }) > V.appetite({ { key = "fortification", w = 1000 } }),
    "appétit : expansion > fortification")
  check(V.appetite(nil) == 1000 and V.appetite({ { key = "expansion", w = 1000 } }, true) == 700, "appétit : sans chef 1 000, survie 700")
  local far = { x = 500, y = 0, rich = 60000 }
  check(V.value(far, ctx({ ambition = 1500, appetite = 1300 })) > V.value(far, ctx({ ambition = 600, appetite = 800 })),
    "l'ambitieux en expansion accepte mieux un site lointain")
  check(V.reach(100, 100) == 80 and V.reach(5000, 5000) == 600, "portée bornée à [80 ; 600]")
  -- Plancher d'expansion : le fer d'Écarlate à 526 tuiles (moteur réel, essai 1) est refusé pour un 2e avant-poste,
  -- jamais pour le premier ; un ambitieux en expansion va plus loin.
  local iron = { x = 526, y = 0, rich = 70000 }
  check(not V.acceptable(V.value(iron, c), false) and V.acceptable(V.value(iron, c), true),
    "plancher : site à 526 tuiles refusé pour s'étendre (" .. V.value(iron, c) .. "), accepté pour un premier avant-poste")
  local at = function(d, amb, app) return V.value({ x = d, y = 0, rich = 70000 }, ctx({ ambition = amb, appetite = app })) end
  local lim1, lim2 = 0, 0
  for d = 50, 800, 10 do
    if V.acceptable(at(d, 1000, 1000), false) then lim1 = d end
    if V.acceptable(at(d, 1500, 1300), false) then lim2 = d end
  end
  check(lim1 >= 250 and lim1 <= 400 and lim2 > lim1, "plancher : jusqu'à " .. lim1 .. " tuiles (ambition 1 000), " .. lim2 .. " (1 500, expansion)")
end

---------------------------------------------------------------------------------------------------
section("Choix par valeur, hasard borné (pur)")
do
  local c = ctx()
  local cands = {
    { x = 60, y = 0, rich = 20000 }, { x = 0, y = 70, rich = 200000 }, { x = -300, y = 0, rich = 300000 },
    { x = 0, y = -65, rich = 190000 },
  }
  local e1, k1 = V.choose(cands, c, nil)
  check(e1 and k1 == 1, "sans tirage : la meilleure valeur")
  local list = V.rank(cands, c)
  local best = list[1].value
  local m = V.margin(best)
  local bad = 0
  local seen = {}
  local st = Tr.new_stream(20261020, 101)
  for _ = 1, 500 do
    local e = V.choose(cands, c, function(n) return Tr.range(st, 1, n) end)
    if e.value < best - m then bad = bad + 1 end
    seen[e.site] = true
  end
  local nseen = 0
  for _ in pairs(seen) do nseen = nseen + 1 end
  check(bad == 0, "jamais un site hors de la marge de la meilleure valeur (500 tirages)")
  check(nseen >= 2, "hasard borné : plusieurs sites quasi égaux tirés (" .. nseen .. ")")
  check(not seen[cands[3]] and not seen[cands[1]], "le site lointain et le site pauvre ne sont jamais tirés")
  local ch, _, nr = V.choose({ { x = 150, y = 0, rich = 9e6 }, { x = 50, y = 0, rich = 1000 } }, c, nil)
  check(ch.site.x == 150 and nr == 2, "un gisement riche à 150 tuiles bat un pauvre à 50 : rang par distance du choix 2")
  local ch2 = V.choose({ { x = 300, y = 0, rich = 9e6 }, { x = 50, y = 0, rich = 1000 } }, c, nil)
  check(ch2.site.x == 50, "mais pas à 300 tuiles hors du territoire (ambition 1 000)")
  local a = V.rank(cands, c)
  local b = V.rank({ cands[4], cands[3], cands[2], cands[1] }, c)
  local same = true
  for i = 1, #a do if a[i].site ~= b[i].site then same = false end end
  check(same, "classement indépendant de l'ordre de la réserve")
  check(V.choose({}, c, nil) == nil, "aucun candidat : nil")
end

---------------------------------------------------------------------------------------------------
section("Front de prospection (pur)")
do
  local fronts = { { key = "o5", x = 300, y = 0 }, { key = "o7", x = 0, y = 300 } }
  local c = ctx({ rivals = { { x = 560, y = 0, hq = true } } })
  check(V.pick_front(fronts, c, {}, 2, nil) == nil, "tour pair : QG")
  check(V.pick_front(fronts, c, {}, 3, nil) == "o7", "tour impair : le front loin du QG rival")
  check(V.pick_front(fronts, c, { o7 = 100 }, 3, nil) == "o5", "front asséché sauté")
  check(V.pick_front(fronts, ctx({ tick = 200, rivals = c.rivals }), { o7 = 100 }, 3, nil) == "o7", "front de nouveau permis après son délai")
  check(V.pick_front({}, c, {}, 3, nil) == nil, "aucun front : QG")
end

---------------------------------------------------------------------------------------------------
section("Éventail de départ (pur, sans trigonométrie en jeu)")
do
  local min_pair, min_hq, same_side = math.huge, math.huge, true
  for axis = 0, 63 do
    local s = V.start_slots(axis)
    local ax = V.DIRS64[axis + 1]
    for i = 1, #s do
      local dh = math.sqrt(s[i][1] ^ 2 + s[i][2] ^ 2)
      if dh < min_hq then min_hq = dh end
      if i <= 5 and s[i][1] * ax[1] + s[i][2] * ax[2] <= 0 then same_side = false end
      for j = i + 1, #s do
        local d = math.sqrt((s[i][1] - s[j][1]) ^ 2 + (s[i][2] - s[j][2]) ^ 2)
        if d < min_pair then min_pair = d end
      end
    end
  end
  check(min_pair >= 41, string.format("écart minimal entre emplacements %.1f tuiles (≥ 41)", min_pair))
  check(min_hq >= 40, string.format("distance minimale au QG %.1f tuiles (≥ 40)", min_hq))
  check(same_side, "les 5 premiers emplacements d'un même côté de l'axe (éventail, pas de couronne)")
  local okn = true
  for k = 1, 64 do
    local d = V.DIRS64[k]
    if math.abs(d[1] * d[1] + d[2] * d[2] - 1) > 1e-12 then okn = false end
  end
  check(okn and #V.DIRS64 == 64, "table des 64 directions : vecteurs unitaires")
end

---------------------------------------------------------------------------------------------------
-- Moteur simulé
---------------------------------------------------------------------------------------------------
local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for ri, r in ipairs({ 40, 64, 88, 150, 220 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1],
          amount = 10000 * ((ri + di) % 5 + 1) }
      end
    end
  end
  return out
end
local function W() return M.world() end
local function logs(pattern)
  local out = {}
  for _, l in ipairs(W().logs) do if l:find(pattern, 1, true) then out[#out + 1] = l end end
  return out
end
local function start(seed)
  M.new_game({ seed = seed, patches = patches(), p_busy = 0.02, p_nopath = 0.02, p_lost = 0.005 })
  M.command("fo-war", "start 4 100 10 320")
  return global.fo.war
end

section("Moteur simulé : éventail tiré, sites par valeur")
local seed = 777
local war = start(seed)
do
  local ok_axis, ok_side = true, true
  for _, f in ipairs(war.factions) do
    local expect = Tr.range(Tr.new_stream(seed, 100 + f.id), 0, 63)
    if f.seed_axis ~= expect then ok_axis = false end
    local ax = V.DIRS64[f.seed_axis + 1]
    for _, s in ipairs(f.prospects or {}) do
      if s.seeded and ((s.x - f.hq_pos.x) * ax[1] + (s.y - f.hq_pos.y) * ax[2]) <= 0 then ok_side = false end
    end
  end
  check(ok_axis, "axe de départ = 1er tirage du flux 100 + id")
  check(ok_side, "les 4 gisements de départ du même côté de l'axe")
  local axes = {}
  for _, f in ipairs(war.factions) do axes[#axes + 1] = f.seed_axis end
  check(not (axes[1] == axes[2] and axes[2] == axes[3] and axes[3] == axes[4]), "axes différents entre factions (" .. table.concat(axes, ", ") .. ")")
end
check(pcall(M.run_ticks, 15 * 3600), "15 min de guerre sans erreur")
local sitesA = logs("[FO-STRAT] site")
do
  local valued, real, maxn = 0, 0, 0
  for _, l in ipairs(sitesA) do
    local v, k, n = l:match("valeur (%-?%d+), rang valeur (%d+) sur (%d+)")
    if v then
      valued = valued + 1
      n = tonumber(n)
      if n >= 2 then real = real + 1 end
      if n > maxn then maxn = n end
    end
  end
  check(#sitesA > 0 and valued == #sitesA, "lignes de site avec valeur et rang (" .. valued .. " sur " .. #sitesA .. ")")
  check(real >= 1, "au moins un choix réel entre plusieurs sites (" .. real .. ", jusqu'à " .. maxn .. " candidats)")
  -- Fronts : sites trouvés depuis un de nos avant-postes (choisis, ou encore en réserve), et réserve renouvelée.
  local fronts, in_reserve, dropped, turns = 0, 0, 0, 0
  for _, l in ipairs(sitesA) do if l:find("front o", 1, true) then fronts = fronts + 1 end end
  for _, f in ipairs(war.factions) do
    for _, s in ipairs(f.prospects or {}) do if s.front then in_reserve = in_reserve + 1 end end
    dropped = dropped + (f.stats.reserve_dropped or 0)
    turns = turns + (f.scan_turn or 0)
  end
  check(fronts + in_reserve >= 1, "des sites trouvés depuis un front (choisis " .. fronts .. ", en réserve " .. in_reserve .. ")")
  check(dropped >= 4 and turns >= 8, "réserve renouvelée (" .. dropped .. " sites oubliés) et origines alternées (" .. turns .. " tours)")
  local over = false
  for _, f in ipairs(war.factions) do
    local per = {}
    for _, s in ipairs(f.prospects or {}) do per[s.resource] = (per[s.resource] or 0) + 1 end
    for _, n in pairs(per) do if n > 3 then over = true end end
    if #(f.prospects or {}) > 12 then over = true end
  end
  check(not over, "réserve : au plus 3 sites par ressource, 12 en tout")
end

section("Moteur simulé : même graine, mêmes choix")
do
  start(seed)
  check(pcall(M.run_ticks, 15 * 3600), "2e partie sans erreur")
  local sitesB = logs("[FO-STRAT] site")
  local same = #sitesA == #sitesB
  for i = 1, math.min(#sitesA, #sitesB) do if sitesA[i] ~= sitesB[i] then same = false end end
  check(same, "lignes de site identiques (" .. #sitesA .. " et " .. #sitesB .. ")")
end

section("Moteur simulé : orphelins d'un avant-poste perdu (F209)")
do
  local Outposts = require("script.faction.outposts")
  war = global.fo.war
  -- Deux avant-postes perdus : l'un repris à la reconstruction, l'autre démonté par un ouvrier.
  local f, victims = nil, {}
  for _, ff in ipairs(war.factions) do
    local ids = require("script.faction.state").sorted_keys(ff.outposts)
    if #ids >= 2 and not f then
      f = ff
      victims = { ids[1], ids[2] }
    end
  end
  check(f ~= nil, "une faction avec deux avant-postes")
  if f then
    local pos = {}
    for i, oid in ipairs(victims) do
      local o = f.outposts[oid]
      pos[i] = { x = o.pos.x, y = o.pos.y, oid = oid }
      for _, d in ipairs(o.drill_list) do if d.valid then d.die() end end
    end
    M.run_ticks(2)
    local n0 = #Outposts.orphans(f)
    check(n0 >= 2 and f.outposts[victims[1]] == nil and f.outposts[victims[2]] == nil,
      "avant-postes perdus, réceptacles orphelins retenus (" .. n0 .. ")")
    local J = require("script.faction.journal")
    local before = #W().logs
    J.shape(f, W().surface, game.tick)
    local line = W().logs[before + 1] or ""
    check(line:find("orphelins " .. n0, 1, true) ~= nil, "orphelins comptés dans la ligne de forme")
    -- Reprise : l'ouvrier qui reconstruit sur place démonte d'abord les orphelins de ce site.
    local inv = game.create_inventory(40)
    local r = Outposts.reclaim(f, pos[1], inv, 24)
    local items = 0
    for _, n in pairs(inv.get_contents()) do items = items + n end
    check(r >= 1 and items >= r, "reprise à la reconstruction : " .. r .. " orphelin(s), " .. items .. " objet(s) rendus")
    inv.destroy()
    -- Démontage : orphelins du 2e site vieillis de 30 min ; un ouvrier part les démonter.
    local left = 0
    for _, o in ipairs(Outposts.orphans(f)) do
      if o.oid == pos[2].oid then
        o.tick = game.tick - Outposts.ORPHAN_WAIT
        left = left + 1
      end
    end
    check(left >= 1 and #Outposts.orphan_groups(f, game.tick) >= 1, "groupe d'orphelins prêt au démontage")
    for _, it in ipairs({ { "iron-plate", 400 }, { "coal", 200 } }) do f.hq.insert({ name = it[1], count = it[2] }) end
    check(pcall(M.run_ticks, 8 * 3600), "8 min sans erreur après les pertes")
    local still = 0
    for _, o in ipairs(Outposts.orphans(f)) do if o.oid == pos[2].oid then still = still + 1 end end
    check(still == 0 and (f.stats.orphans_salvaged or 0) >= 1 or (f.stats.orphans_reclaimed or 0) > r,
      "orphelins du 2e site démontés (démontés " .. tostring(f.stats.orphans_salvaged or 0) .. ", repris "
      .. tostring(f.stats.orphans_reclaimed or 0) .. ", restants " .. still .. ")")
  end
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
