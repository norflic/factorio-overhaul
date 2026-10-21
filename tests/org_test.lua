--[[
  Tests hors jeu du modèle d'organisation des équipes de PNJ (shared/team/org.lua, lot IA1, OBJECTIFS C5).
  Usage, depuis la racine du mod :   lua5.2 tests/org_test.lua

  Vérifie : tables (pôles, domaines, types de tâches du cerveau actuel), orientation, plafonds d'effectif,
  généralistes, cibles par pôle, déterminisme (double passage, ordre d'entrée mélangé, copie profonde),
  hystérésis et stabilité (au plus 6 changements de pôle par PNJ et par heure, même sous des ordres
  contradictoires), réaction aux priorités du joueur et à une crise, promotion, meneurs de projets, prise de
  tâche, tailles 10 / 30 / 50 / 60 et coût de calcul compté, résurrection, recrutement, progression,
  règle d'automatisation, amélioration instantanée en un trajet, compatibilité avec le cerveau actuel.
]]

package.path = "./?.lua;" .. package.path
local O = require("shared.team.org")
local T = require("shared.team.config")
local F = require("shared.faction.config")
local Book = require("shared.team.book")
local Planner = require("shared.team.planner")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

-- Sérialisation canonique (clés triées) : comparer deux résultats octet pour octet.
local function ser(v)
  local t = type(v)
  if t == "table" then
    local ks = {}
    for k in pairs(v) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b)
      local ta, tb = type(a), type(b)
      if ta ~= tb then return ta < tb end
      return a < b
    end)
    local parts = {}
    for _, k in ipairs(ks) do parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif t == "number" then
    return string.format("%.12g", v)
  elseif t == "function" then
    return "FONCTION"
  end
  return tostring(v)
end

local function deep(v)
  if type(v) ~= "table" then return v end
  local o = {}
  for k, x in pairs(v) do o[k] = deep(x) end
  return o
end

-- RNG déterministe (LCG) pour les mélanges et les tirages des tests de propriété.
local seed = 20261021
local function rnd(n)
  seed = (seed * 1103515245 + 12345) % 2147483648
  return seed % n + 1
end
local function shuffle(list)
  local l = {}
  for i = 1, #list do l[i] = list[i] end
  for i = #l, 2, -1 do
    local j = rnd(i)
    l[i], l[j] = l[j], l[i]
  end
  return l
end

local function sum3(t) return t[1] + t[2] + t[3] end

--- Équipe de n PNJ : les premiers sont généralistes (selon generalists_wanted), les autres exécutants
--- répartis selon `dist` (3 entiers, somme = exécutants) ou à tour de rôle ; tous inoccupés par défaut.
local function make_team(n, chiefs, dist)
  local g = O.generalists_wanted(n, chiefs or 5)
  local npcs = {}
  local quota = dist and { dist[1], dist[2], dist[3] } or nil
  local p = 1
  for id = 1, n do
    local rank = (id * 7) % 5 + 1
    local a = { id = id, rank = rank, xp = O.XP_THRESHOLDS[rank] + id, idle = true }
    if id <= g then
      a.role = "generalist"
      a.pole = O.POLES[(id - 1) % 3 + 1]
    else
      a.role = "executant"
      if quota then
        while quota[p] == 0 do p = p % 3 + 1 end
        quota[p] = quota[p] - 1
        a.pole = O.POLES[p]
        p = p % 3 + 1
      else
        a.pole = O.POLES[(id - 1) % 3 + 1]
      end
    end
    npcs[#npcs + 1] = a
  end
  return npcs
end

local function count_poles(npcs)
  local c = { 0, 0, 0 }
  for _, a in ipairs(npcs) do
    if a.role == "executant" and a.pole then c[O.POLE_INDEX[a.pole]] = c[O.POLE_INDEX[a.pole]] + 1 end
  end
  return c
end

local function find(npcs, id)
  for _, a in ipairs(npcs) do if a.id == id then return a end end
end

--- Applique les décisions d'une pensée à l'équipe (ce que fera le runtime).
local function apply(npcs, out, tick)
  for _, pl in ipairs(out.place) do find(npcs, pl.id).pole = pl.pole end
  for _, m in ipairs(out.moves) do
    local a = find(npcs, m.id)
    a.pole = m.to
    a.moved_tick = tick
  end
  if out.promote then find(npcs, out.promote).role = "generalist" end
  for _, gp in ipairs(out.gen_poles) do find(npcs, gp.id).pole = gp.pole end
end

local BIG = { 3000, 3000, 3000 } -- 10 PNJ équivalents de travail ouvert dans chaque pôle

---------------------------------------------------------------------------------------------------
section("Tables : pôles, domaines, types de tâches")
check(#O.POLES == 3 and #O.DOMAINS == 5, "3 pôles et 5 domaines (managers)")
local per_pole = { 0, 0, 0 }
for _, d in ipairs(O.DOMAINS) do
  check(O.POLE_INDEX[d.pole] ~= nil, "domaine " .. d.key .. " rattaché à un pôle connu")
  per_pole[O.POLE_INDEX[d.pole]] = per_pole[O.POLE_INDEX[d.pole]] + 1
end
check(per_pole[1] >= 1 and per_pole[2] >= 1 and per_pole[3] >= 1, "chaque pôle a au moins un domaine")
local kinds = {}
for k in pairs(O.TASK_DOMAIN) do kinds[#kinds + 1] = k end
table.sort(kinds)
for _, k in ipairs(kinds) do
  check(O.DOMAIN_POLE[O.TASK_DOMAIN[k]] ~= nil, "type " .. k .. " -> domaine connu")
  check(O.TASK_WORK[k] ~= nil, "type " .. k .. " : durée estimée")
end
local dk = {}
for k in pairs(O.DESIGN_KINDS) do dk[#dk + 1] = k end
table.sort(dk)
for _, k in ipairs(dk) do check(O.TASK_DOMAIN[k] ~= nil, "conception " .. k .. " a un domaine") end
for _, k in ipairs({ "mine", "carry", "service" }) do
  check(O.MANUAL_KINDS[k] ~= nil and O.TASK_DOMAIN[k] ~= nil, "travail manuel " .. k .. " connu")
end
-- Chaque type de tâche émis AUJOURD'HUI par le cerveau d'équipe a un domaine (lu dans le code source).
do
  local f = io.open("shared/team/planner.lua", "r")
  local src = f and f:read("*a") or ""
  if f then f:close() end
  local seen, n = {}, 0
  for k in src:gmatch('%f[%w_]kind = "([%w_]+)"') do
    if not seen[k] then
      seen[k] = true
      n = n + 1
      check(O.TASK_DOMAIN[k] ~= nil, "type du cerveau actuel '" .. k .. "' rattaché à un domaine")
    end
  end
  check(n >= 9, "les 9 types du cerveau actuel sont lus dans planner.lua (lus : " .. n .. ")")
end
for _, name in ipairs(O.PRESET_ORDER) do
  local p = O.PRESETS[name]
  check(p and p.extraction + p.base + p.territoire == 100, "préréglage " .. name .. " : somme 100")
end
for _, fa in ipairs(F.factions) do
  local p = O.PERSONALITY[fa.personality]
  check(p and p.extraction + p.base + p.territoire == 100, "personnalité " .. fa.personality .. " : orientation de somme 100")
end
check(ser(O.TASK_DOMAIN):find("FONCTION") == nil, "tables sans fonction (sérialisables)")

---------------------------------------------------------------------------------------------------
section("Orientation (curseurs du joueur, préréglages, menace)")
check(ser(O.normalize("ressources")) == ser({ 60, 25, 15 }), "préréglage ressources = 60/25/15")
check(ser(O.normalize({ 0, 0, 0 })) == ser({ 40, 40, 20 }), "tout à 0 -> équilibre")
check(ser(O.normalize("inconnu")) == ser({ 40, 40, 20 }), "préréglage inconnu -> équilibre")
check(ser(O.normalize({ 1, 1, 1 })) == ser({ 34, 33, 33 }), "1/1/1 -> 34/33/33 (plus fort reste, égalité par l'ordre des pôles)")
check(ser(O.normalize({ extraction = -5, base = 10 })) == ser({ 0, 100, 0 }), "négatif ramené à 0")
local thr = O.normalize("equilibre", true)
check(thr[3] > 20 and sum3(thr) == 100, "menace : le territoire monte (" .. thr[3] .. " points), somme 100")
for _ = 1, 200 do
  local o = { rnd(101) - 1, rnd(101) - 1, rnd(101) - 1 }
  local n = O.normalize(o, rnd(2) == 1)
  if sum3(n) ~= 100 or n[1] < 0 or n[2] < 0 or n[3] < 0 then check(false, "normalize " .. ser(o)) end
end
check(true, "200 orientations tirées : somme 100, aucune valeur négative")

---------------------------------------------------------------------------------------------------
section("Effectifs : plafonds par époque, départ, généralistes")
local function caps(max) return { O.headcount_cap(1, max), O.headcount_cap(2, max), O.headcount_cap(3, max), O.headcount_cap(15, max) } end
check(ser(caps(30)) == ser({ 15, 25, 30, 30 }), "30 : 15 / 25 / 30 / 30 (époques 1, 2, 3, 15) : " .. ser(caps(30)))
check(ser(caps(10)) == ser({ 5, 9, 10, 10 }), "10 : 5 / 9 / 10 / 10 : " .. ser(caps(10)))
check(ser(caps(50)) == ser({ 25, 42, 50, 50 }), "50 : 25 / 42 / 50 / 50 : " .. ser(caps(50)))
check(ser(caps(60)) == ser({ 30, 50, 60, 60 }), "60 : 30 / 50 / 60 / 60 : " .. ser(caps(60)))
local mono = true
for max = 6, 60 do
  for e = 1, 14 do if O.headcount_cap(e, max) > O.headcount_cap(e + 1, max) or O.headcount_cap(e, max) > max then mono = false end end
end
check(mono, "plafond croissant avec l'époque et jamais au-dessus du maximum (6 à 60 PNJ)")
check(O.start_headcount(30) == 8 and O.start_headcount(10) == 5 and O.start_headcount(6) == 3, "départ : 8 (30), 5 (10), 3 (6)")
local gw = {
  { 30, 5, 5 }, { 25, 5, 5 }, { 24, 5, 4 }, { 10, 5, 2 }, { 8, 5, 2 }, { 6, 5, 1 }, { 1, 5, 1 }, { 0, 5, 0 },
  { 50, 5, 5 }, { 50, 8, 8 }, { 60, 8, 8 }, { 30, 1, 1 },
}
for _, c in ipairs(gw) do
  check(O.generalists_wanted(c[1], c[2]) == c[3], string.format("généralistes pour %d PNJ (réglage %d) = %d", c[1], c[2], c[3]))
end

---------------------------------------------------------------------------------------------------
section("Répartition entière (plus fort reste)")
check(ser(O.apportion(1, { 1, 1, 1 })) == ser({ 1, 0, 0 }), "égalité départagée par l'indice")
check(ser(O.apportion(5, { 0, 0, 0 })) == ser({ 0, 0, 0 }), "poids nuls -> zéros")
local ok_sum = true
for _ = 1, 500 do
  local total = rnd(80) - 1
  local w = { rnd(10) - 1, rnd(10) - 1, rnd(10) - 1, rnd(10) - 1 }
  local a = O.apportion(total, w)
  local s = 0
  for i = 1, 4 do
    s = s + a[i]
    if a[i] < 0 then ok_sum = false end
  end
  if (w[1] + w[2] + w[3] + w[4] > 0 and s ~= total) or ser(a) ~= ser(O.apportion(total, w)) then ok_sum = false end
end
check(ok_sum, "500 tirages : somme exacte, aucune valeur négative, résultat reproductible")

---------------------------------------------------------------------------------------------------
section("Cibles par pôle (exécutants)")
local t0, s0 = O.pole_targets(25, BIG, { 40, 40, 20 }, 0)
check(ser(t0) == ser({ 10, 10, 5 }) and s0 == 0, "25 exécutants, travail partout, équilibre -> 10/10/5 : " .. ser(t0))
local tr = O.pole_targets(25, BIG, O.normalize("ressources"), 0)
check(tr[1] > tr[2] and tr[1] > tr[3] and sum3(tr) == 25, "« Ressources » : l'extraction domine " .. ser(tr))
check(tr[1] <= 13, "plafond d'utilité : 10 PNJ de travail -> 13 au plus à l'extraction (" .. tr[1] .. ")")
local tp = O.pole_targets(25, BIG, O.normalize("protection"), 0)
check(tp[3] > tp[1] and tp[3] > tp[2], "« Protection » : le territoire domine " .. ser(tp))
local tn, sn = O.pole_targets(25, { 0, 0, 0 }, { 40, 40, 20 }, 0)
check(sn == 25 and sum3(tn) == 25 and tn[1] >= tn[3], "aucun travail : 25 au fond, selon l'orientation " .. ser(tn))
local tz = O.pole_targets(25, { 3000, 3000, 0 }, { 50, 50, 0 }, 3)
check(tz[3] >= 6, "3 zones actives -> au moins 6 au territoire, même orienté à 0 (" .. tz[3] .. ")")
local tf = O.pole_targets(25, { 0, 6000, 0 }, { 0, 100, 0 }, 0)
check(tf[1] >= 2, "plancher d'extraction : 2 même orienté à 0 (" .. tf[1] .. ")")
local tsmall, ssmall = O.pole_targets(25, { 0, 300, 0 }, { 0, 100, 0 }, 0)
check(ssmall == 23, "1 PNJ de travail à la base -> 2 utiles (×5/4 arrondi), 23 au fond (surplus " .. ssmall .. ")")
local prop = true
for _ = 1, 500 do
  local n = rnd(61) - 1
  local need = { (rnd(31) - 1) * 300, (rnd(31) - 1) * 300, (rnd(31) - 1) * 300 }
  local pts = O.normalize({ rnd(101) - 1, rnd(101) - 1, rnd(101) - 1 })
  local z = rnd(4) - 1
  local t, s = O.pole_targets(n, need, pts, z)
  if sum3(t) ~= n or t[1] < 0 or t[2] < 0 or t[3] < 0 or s < 0 or s > n then prop = false end
  if n >= 2 and t[1] < 2 then prop = false end
  if n >= 2 + 2 * z and t[3] < 2 * z then prop = false end
end
check(prop, "500 tirages : somme = effectif, planchers tenus, surplus dans [0, n]")

---------------------------------------------------------------------------------------------------
section("Déterminisme")
local team30 = make_team(30, 5, { 10, 10, 5 })
local base_in = { tick = 36000, npcs = team30, need = BIG, orientation = "equilibre", zones = 0, chiefs = 5,
  projects = { { id = 1, domain = "production", prio = 80 }, { id = 2, domain = "gisements", prio = 70 } } }
local o1, o2 = O.plan(base_in), O.plan(base_in)
check(ser(o1) == ser(o2), "deux passages identiques")
local shuffled = deep(base_in)
shuffled.npcs = shuffle(shuffled.npcs)
shuffled.projects = shuffle(shuffled.projects)
check(ser(O.plan(shuffled)) == ser(o1), "ordre d'entrée mélangé (PNJ et projets) : résultat identique")
local copy = deep(base_in)
check(ser(O.plan(copy)) == ser(o1), "copie profonde (sauvegarde puis rechargement) : résultat identique")
check(ser(base_in.npcs) == ser(team30), "l'entrée n'est pas modifiée")
check(ser(o1):find("FONCTION") == nil, "résultat sans fonction (sérialisable dans global)")
check(o1.idle_rate == 1, "taux d'inactivité calculé (tous inoccupés : 1)")

---------------------------------------------------------------------------------------------------
section("Hystérésis, convergence et stabilité")
do
  -- Équipe mal répartie (tous les exécutants à la base) : elle converge, à 2 mouvements par pensée au plus.
  local npcs = make_team(30, 5, { 0, 25, 0 })
  local tick, max_moves, busy_moved, conv = 36000, 0, false, nil
  for k = 1, 200 do
    local out = O.plan({ tick = tick, npcs = npcs, need = BIG, orientation = "equilibre", chiefs = 5 })
    if #out.moves > max_moves then max_moves = #out.moves end
    for _, m in ipairs(out.moves) do if not find(npcs, m.id).idle then busy_moved = true end end
    apply(npcs, out, tick)
    local c = count_poles(npcs)
    if not conv and math.abs(c[1] - out.targets[1]) <= 1 and math.abs(c[2] - out.targets[2]) <= 1
      and math.abs(c[3] - out.targets[3]) <= 1 then conv = k end
    tick = tick + 300
  end
  check(max_moves <= O.MAX_MOVES, "au plus " .. O.MAX_MOVES .. " mouvements par pensée (vu : " .. max_moves .. ")")
  check(not busy_moved, "seuls des PNJ inoccupés changent de pôle")
  check(conv ~= nil, "convergence vers les cibles à 1 près (pensée n° " .. tostring(conv) .. ")")
  -- Une fois convergée, entrée constante : plus aucun mouvement pendant 100 pensées.
  local extra = 0
  for _ = 1, 100 do
    local out = O.plan({ tick = tick, npcs = npcs, need = BIG, orientation = "equilibre", chiefs = 5 })
    extra = extra + #out.moves
    apply(npcs, out, tick)
    tick = tick + 300
  end
  check(extra == 0, "entrée constante après convergence : 0 mouvement en 100 pensées (vu : " .. extra .. ")")
  -- Écart de 1 : pas de mouvement (pas de va-et-vient d'une unité).
  local one = make_team(30, 5, { 11, 9, 5 })
  local out1 = O.plan({ tick = 0, npcs = one, need = BIG, orientation = "equilibre", chiefs = 5 })
  check(#out1.moves == 0, "écart de 1 de chaque côté : aucun mouvement")
end
do
  -- Ordres contradictoires à CHAQUE pensée pendant 1 heure : au plus 6 changements par PNJ et par heure.
  local npcs = make_team(30, 5, { 10, 10, 5 })
  local tick, per = 0, {}
  local total = 0
  for k = 1, 720 do
    local out = O.plan({ tick = tick, npcs = npcs, need = BIG, orientation = (k % 2 == 0) and "ressources" or "protection", chiefs = 5 })
    for _, m in ipairs(out.moves) do
      per[m.id] = (per[m.id] or 0) + 1
      total = total + 1
    end
    apply(npcs, out, tick)
    tick = tick + 300
  end
  local worst = 0
  for _, a in ipairs(npcs) do worst = math.max(worst, per[a.id] or 0) end
  check(worst <= 6, "orientation inversée à chaque pensée (720 pensées) : au plus 6 changements par PNJ en 1 h (pire : " .. worst .. ")")
  check(total <= 6 * 30, "total des changements borné : " .. total .. " <= 180")
end

---------------------------------------------------------------------------------------------------
section("Réaction aux priorités du joueur et aux crises")
do
  local npcs = make_team(30, 5, { 10, 10, 5 })
  local tick = 0
  local before = count_poles(npcs)[1]
  local thinks, target = 0, nil
  for k = 1, 12 do
    local out = O.plan({ tick = tick, npcs = npcs, need = BIG, orientation = "ressources", chiefs = 5 })
    target = out.targets[1]
    apply(npcs, out, tick)
    tick = tick + 300
    if thinks == 0 and math.abs(count_poles(npcs)[1] - target) <= 1 then thinks = k end
  end
  check(target >= before + 3, "curseur « Ressources » : la cible de l'extraction monte de 3 ou plus (" .. before .. " -> " .. target .. ")")
  check(thinks > 0 and thinks <= 2, "curseur « Ressources » : extraction à sa cible à 1 près en " .. thinks .. " pensée(s) (<= 2, soit 10 s ; C5-4)")
  local c = count_poles(npcs)
  check(c[1] >= before + 2, "après 1 min : +" .. (c[1] - before) .. " à l'extraction (l'hystérésis garde le dernier écart de 1)")
end
do
  -- Crise : avant-poste de fer perdu, le travail d'extraction explose (C5-2 : +3 en 2 pensées).
  local npcs = make_team(30, 5, { 10, 10, 5 })
  local before = count_poles(npcs)[1]
  local tick = 0
  for _ = 1, 2 do
    local out = O.plan({ tick = tick, npcs = npcs, need = { 9000, 1500, 1500 }, orientation = "equilibre", chiefs = 5 })
    apply(npcs, out, tick)
    tick = tick + 300
  end
  check(count_poles(npcs)[1] >= before + 3, "crise d'extraction : +3 PNJ ou plus en 2 pensées (" .. before .. " -> " .. count_poles(npcs)[1] .. ")")
end
do
  local npcs = make_team(30, 5, { 10, 10, 5 })
  local calm = O.plan({ tick = 0, npcs = npcs, need = BIG, orientation = "equilibre", chiefs = 5 })
  local threat = O.plan({ tick = 0, npcs = npcs, need = BIG, orientation = "equilibre", threatened = true, chiefs = 5 })
  check(threat.targets[3] > calm.targets[3], "menace : la cible du territoire monte (" .. calm.targets[3] .. " -> " .. threat.targets[3] .. ")")
  -- Donneur le plus excédentaire tout occupé : on prend au suivant (pas de blocage).
  local mixed = make_team(30, 5, { 4, 14, 7 })
  for _, a in ipairs(mixed) do if a.role == "executant" and a.pole == "base" then a.idle = false end end
  local mo = O.plan({ tick = 0, npcs = mixed, need = BIG, orientation = "equilibre", chiefs = 5 })
  local from_terr = #mo.moves > 0
  for _, m in ipairs(mo.moves) do if m.from ~= "territoire" or m.to ~= "extraction" then from_terr = false end end
  check(from_terr, "base excédentaire mais toute occupée : les " .. #mo.moves .. " mouvements viennent du territoire")
  -- PNJ tous occupés : aucune réaffectation, quel que soit l'ordre.
  for _, a in ipairs(npcs) do a.idle = false end
  local busy = O.plan({ tick = 0, npcs = npcs, need = BIG, orientation = "protection", chiefs = 5 })
  check(#busy.moves == 0, "tous occupés : aucun mouvement (le travail en cours n'est jamais interrompu)")
  -- Recrues sans pôle : placées aussitôt là où il manque du monde.
  local fresh = make_team(30, 5, { 10, 10, 5 })
  for _, a in ipairs(fresh) do if a.id > 27 then a.pole = nil end end
  local pl = O.plan({ tick = 0, npcs = fresh, need = BIG, orientation = "equilibre", chiefs = 5 })
  check(#pl.place == 3, "3 recrues sans pôle placées dans la même pensée")
end

---------------------------------------------------------------------------------------------------
section("Généralistes : promotion, pôles de référence, meneurs de projets")
do
  local npcs = make_team(30, 5, { 10, 10, 5 })
  -- Un généraliste meurt : il en reste 4 pour 5 voulus.
  local alive = {}
  for _, a in ipairs(npcs) do if a.id ~= 3 then alive[#alive + 1] = a end end
  local tick = 100000
  local early = O.plan({ tick = tick, npcs = alive, need = BIG, chiefs = 5, vacancy_since = tick - 60 * 60 })
  check(early.promote == nil, "généraliste mort il y a 1 min : pas encore de promotion")
  local due = O.plan({ tick = tick, npcs = alive, need = BIG, chiefs = 5, vacancy_since = tick - 2 * 3600 })
  local best
  for _, a in ipairs(alive) do
    if a.role == "executant" and (not best or a.rank > best.rank or (a.rank == best.rank and (a.xp > best.xp or (a.xp == best.xp and a.id < best.id)))) then best = a end
  end
  check(due.promote == best.id, "après 2 min : promotion du meilleur exécutant (rang, XP, id) : " .. tostring(due.promote))
  check(#due.gen_poles == 5, "5 généralistes après promotion")
  local growth = O.plan({ tick = tick, npcs = alive, need = BIG, chiefs = 5 })
  check(growth.promote ~= nil, "croissance (pas de mort) : promotion immédiate")
  local full = O.plan({ tick = tick, npcs = npcs, need = BIG, chiefs = 5 })
  check(full.promote == nil and full.generalists_wanted == 5, "5 généralistes sur 30 : aucune promotion")
end
check(ser(O.generalist_quotas(5, { 40, 40, 20 })) == ser({ 2, 2, 1 }), "quotas 5 généralistes, équilibre : 2/2/1")
check(ser(O.generalist_quotas(5, { 47, 47, 6 })) == ser({ 3, 2, 0 }), "technocrate (territoire 6 %) : 3/2/0")
check(ser(O.generalist_quotas(2, O.normalize("protection"))) == ser({ 0, 1, 1 }), "2 généralistes, « Protection » : territoire puis base")
check(ser(O.generalist_quotas(3, { 40, 40, 20 })) == ser({ 1, 1, 1 }), "3 généralistes, 3 pôles >= 15 % : un chacun")
do
  -- Stabilité des pôles de référence : changer l'orientation déplace le minimum de généralistes.
  local npcs = make_team(30, 5, { 10, 10, 5 })
  local o1 = O.plan({ tick = 0, npcs = npcs, need = BIG, orientation = "equilibre", chiefs = 5 })
  apply(npcs, o1, 0)
  local o1b = O.plan({ tick = 0, npcs = npcs, need = BIG, orientation = "equilibre", chiefs = 5 })
  check(ser(o1b.gen_poles) == ser(o1.gen_poles), "pôles des généralistes stables à orientation constante")
  local before = {}
  for _, gp in ipairs(o1.gen_poles) do before[gp.id] = gp.pole end
  local o2 = O.plan({ tick = 0, npcs = npcs, need = BIG, orientation = "protection", chiefs = 5 })
  local changed = 0
  for _, gp in ipairs(o2.gen_poles) do if before[gp.id] ~= gp.pole then changed = changed + 1 end end
  local q1, q2 = O.generalist_quotas(5, O.normalize("equilibre")), O.generalist_quotas(5, O.normalize("protection"))
  local minimal = 0
  for p = 1, 3 do if q2[p] > q1[p] then minimal = minimal + q2[p] - q1[p] end end
  check(changed == minimal, "« Protection » : " .. changed .. " généraliste(s) change(nt) de pôle, le minimum (" .. minimal .. ")")
end
do
  local npcs = make_team(30, 5, { 10, 10, 5 })
  local o0 = O.plan({ tick = 0, npcs = npcs, need = BIG, chiefs = 5 })
  apply(npcs, o0, 0)
  local projects = {
    { id = 1, domain = "production", prio = 60 }, { id = 2, domain = "gisements", prio = 90, started = true },
    { id = 3, domain = "defense", prio = 50 }, { id = 4, domain = "logistique", prio = 85 },
    { id = 5, domain = "infrastructures", prio = 40 }, { id = 6, domain = "production", prio = 70 },
    { id = 7, domain = "gisements", prio = 30 },
  }
  local out = O.plan({ tick = 0, npcs = npcs, need = BIG, chiefs = 5, projects = projects })
  check(#out.leaders == 5 and #out.waiting == 2, "7 projets, 5 généralistes : 5 menés, 2 en attente")
  local led, uniq = {}, true
  for _, l in ipairs(out.leaders) do
    if led[l.npc] then uniq = false end
    led[l.npc] = l.project
  end
  check(uniq, "un généraliste mène un seul projet")
  local waiting = ser(out.waiting)
  check(waiting == ser({ 5, 7 }), "les 2 projets les moins prioritaires attendent : " .. waiting)
  local pole_of = {}
  for _, gp in ipairs(out.gen_poles) do pole_of[gp.id] = gp.pole end
  local first = out.leaders[1]
  check(first.project == 2 and pole_of[first.npc] == "extraction", "le projet le plus prioritaire (gisements) va à un généraliste de l'extraction")
  -- Stabilité : les priorités changent, les meneurs restent.
  for _, pr in ipairs(projects) do
    for _, l in ipairs(out.leaders) do if l.project == pr.id then pr.leader = l.npc end end
  end
  projects[5].prio = 99
  local out2 = O.plan({ tick = 300, npcs = npcs, need = BIG, chiefs = 5, projects = projects })
  local kept = 0
  for _, l in ipairs(out2.leaders) do
    for _, l1 in ipairs(out.leaders) do if l1.project == l.project and l1.npc == l.npc then kept = kept + 1 end end
  end
  check(kept == 5 and ser(out2.waiting) == ser({ 5, 7 }), "priorités changées : les 5 meneurs gardent leur projet (pas de reprise en cours de route)")
  -- Mort d'un meneur : son projet passe au premier généraliste libre à la pensée suivante… s'il y en a un.
  local dead = out.leaders[1].npc
  local alive = {}
  for _, a in ipairs(npcs) do if a.id ~= dead then alive[#alive + 1] = a end end
  local out3 = O.plan({ tick = 600, npcs = alive, need = BIG, chiefs = 5, projects = projects, vacancy_since = 600 })
  local p2_led = false
  for _, l in ipairs(out3.leaders) do if l.project == 2 then p2_led = true end end
  check(not p2_led and out3.promote == nil, "meneur mort, aucun généraliste libre : le projet attend (mode dégradé), pas de promotion avant 2 min")
  local out4 = O.plan({ tick = 600 + 2 * 3600, npcs = alive, need = BIG, chiefs = 5, projects = projects, vacancy_since = 600 })
  check(out4.promote ~= nil, "2 min plus tard : un exécutant est promu")
  local promoted = deep(alive)
  find(promoted, out4.promote).role = "generalist"
  local out5 = O.plan({ tick = 600 + 2 * 3600 + 300, npcs = promoted, need = BIG, chiefs = 5, projects = projects })
  for _, l in ipairs(out5.leaders) do if l.project == 2 then p2_led = l.npc == out4.promote end end
  check(p2_led, "le promu reprend le chantier COMMENCÉ orphelin (90 + 20) avant le nouveau projet de priorité 99")
end

---------------------------------------------------------------------------------------------------
section("Prise de tâche (un seul passage sur une liste triée une fois)")
do
  local tasks = O.sort_tasks({
    { key = "plan_module:1", kind = "plan_module", prio = 50, project = 1 },
    { key = "refill:hq", kind = "refill", prio = 95 },
    { key = "mine:iron-ore", kind = "mine", prio = 30 },
    { key = "craft:gear:1", kind = "craft", prio = 50 },
    { key = "service:3", kind = "service", prio = 70 },
    { key = "ghost:1", kind = "ghost", prio = 40, project = 2 },
    { key = "taken", kind = "craft", prio = 99, worker = 42 },
  })
  check(tasks[1].key == "taken" and tasks[2].key == "refill:hq", "tri : priorité décroissante puis clé")
  local function pick(npc, ctx)
    local i = O.pick_task(npc, tasks, ctx)
    return i and tasks[i].key or "rien"
  end
  check(pick({ id = 1, role = "executant", pole = "base" }) == "craft:gear:1", "exécutant de la base : la fabrication, jamais la conception")
  check(pick({ id = 2, role = "executant", pole = "extraction" }) == "service:3", "exécutant de l'extraction : la tournée (70) avant le minage (30)")
  local capped = { manual_busy = { portage = 5, minage = 1 }, manual_cap = { portage = 5, minage = 5 } }
  check(pick({ id = 2, role = "executant", pole = "extraction" }, capped) == "mine:iron-ore", "portage au plafond : la tournée reste au tableau, le PNJ mine")
  local both = { manual_busy = { portage = 5, minage = 5 }, manual_cap = { portage = 5, minage = 5 } }
  check(pick({ id = 2, role = "executant", pole = "extraction" }, both) == "refill:hq", "tout le manuel au plafond : l'urgence d'un autre pôle (95) est prise")
  check(pick({ id = 3, role = "generalist", pole = "territoire", project = 2 }) == "ghost:1", "généraliste : les tâches de SON projet d'abord (même peu prioritaires)")
  check(pick({ id = 4, role = "generalist", pole = "base" }) == "plan_module:1", "généraliste sans projet : la conception de son pôle")
  check(pick({ id = 5, role = "executant", pole = "territoire" }) == "refill:hq", "exécutant du territoire : le ravitaillement")
  local only_design = O.sort_tasks({ { key = "open_zone:1", kind = "open_zone", prio = 80 } })
  check(O.pick_task({ id = 6, role = "executant", pole = "territoire" }, only_design) == nil, "exécutant devant une seule tâche de conception : il n'y touche pas")
  local other = O.sort_tasks({ { key = "craft:x", kind = "craft", prio = 50 } })
  check(O.pick_task({ id = 7, role = "executant", pole = "territoire" }, other) == nil, "exécutant : pas de tâche ordinaire d'un autre pôle (hystérésis du cerveau)")
  check(O.pick_task({ id = 8, role = "generalist", pole = "territoire" }, other) == 1, "généraliste : n'importe quelle tâche faute de mieux (ouvrier à part entière)")
end

---------------------------------------------------------------------------------------------------
section("Tailles 10 / 30 / 50 / 60 et coût de calcul compté")
local ops_of = {}
for _, n in ipairs({ 10, 30, 50, 60 }) do
  local chiefs = n >= 50 and 8 or 5
  local npcs = make_team(n, chiefs)
  local projects = {}
  for i = 1, 12 do projects[i] = { id = i, domain = O.DOMAINS[(i - 1) % 5 + 1].key, prio = 100 - i } end
  local tasks = {}
  for i = 1, 3 * n do
    local kinds_list = { "craft", "service", "mine", "refill", "ghost", "upgrade", "carry", "plan_module" }
    tasks[i] = { key = "t" .. i, kind = kinds_list[(i - 1) % #kinds_list + 1], prio = (i * 13) % 100 }
  end
  local out = O.plan({ tick = 0, npcs = npcs, tasks = tasks, orientation = "equilibre", chiefs = chiefs, projects = projects, zones = 1 })
  local g = O.generalists_wanted(n, chiefs)
  check(sum3(out.targets) == n - g, string.format("%d PNJ : %d généralistes, cibles %s (somme %d)", n, g, ser(out.targets), n - g))
  check(#out.gen_poles == g and #out.leaders == math.min(g, #projects), string.format("%d PNJ : %d meneurs", n, #out.leaders))
  ops_of[n] = out.ops
  local bound = 40 * n + 20 * #projects + 25 * #tasks + 300
  check(out.ops <= bound, string.format("%d PNJ, %d tâches, %d projets : %d unités de travail <= %d", n, #tasks, #projects, out.ops, bound))
end
check(ops_of[60] <= 8 * ops_of[10], string.format("croissance presque linéaire : 60 PNJ = %.1f × 10 PNJ (<= 8)", ops_of[60] / ops_of[10]))
print(string.format("   unités de travail par pensée : 10 PNJ %d, 30 PNJ %d, 50 PNJ %d, 60 PNJ %d", ops_of[10], ops_of[30], ops_of[50], ops_of[60]))

---------------------------------------------------------------------------------------------------
section("Résurrection et recrutement")
local r1 = O.resurrection(1, 1, nil)
check(ser(r1.cost) == ser({ { "firearm-magazine", 10 }, { "iron-plate", 25 }, { "pistol", 1 } }) and r1.ticks == 600,
  "rang 1, époque 1 : kit + 25 fer, 10 s : " .. ser(r1))
local r3 = O.resurrection(3, 2, "steel-plate")
check(ser(r3.cost) == ser({ { "firearm-magazine", 10 }, { "iron-plate", 75 }, { "pistol", 1 }, { "steel-plate", 6 } }) and r3.ticks == 1800,
  "rang 3, époque 2 : kit + 75 fer + 6 acier, 30 s")
local r5 = O.resurrection(5, 6, "battery")
check(ser(r5.cost) == ser({ { "battery", 10 }, { "firearm-magazine", 10 }, { "iron-plate", 125 }, { "pistol", 1 } }) and r5.ticks == 3000,
  "rang 5, époque 6 : kit + 125 fer + 10 batteries, 50 s")
check(ser(O.resurrection(5, 6, "battery", 0).cost) == ser({ { "firearm-magazine", 10 }, { "pistol", 1 } }), "multiplicateur 0 : le kit seul")
check(O.resurrection(1, 1, nil, 2).cost[2][2] == 50, "multiplicateur 2 : 50 fer au rang 1")
check(O.resurrection(2, 1, "steel-plate").cost[3] == nil or O.resurrection(2, 1, "steel-plate").cost[3][1] == "pistol", "époque 1 : jamais de matériau d'époque")
check(ser(O.resurrection(2, 3, "iron-plate").cost) == ser({ { "firearm-magazine", 10 }, { "iron-plate", 54 }, { "pistol", 1 } }), "matériau = fer : lignes fusionnées (50 + 4)")
check(O.resurrection(9, 1).ticks == 3000 and O.resurrection(0, 1).ticks == 600, "rang hors bornes ramené à 1..5")
check(O.resurrection_slots(0) == 1 and O.resurrection_slots(4) == 1 and O.resurrection_slots(5) == 2 and O.resurrection_slots(15) == 4,
  "résurrections simultanées : 1, plus 1 tous les 5 niveaux du centre")
check(ser(O.recruit_cost(0)) == ser({ { "firearm-magazine", 10 }, { "iron-plate", 10 }, { "pistol", 1 } }), "recrue n° 1 : kit + 10 fer")
check(O.recruit_cost(30)[2][2] == 40 and O.recruit_cost(29)[2][2] == 39, "recrue à 30 PNJ : kit + 40 fer")
do
  -- Piège évité : ceil(10 × (1 + 0,1 × h)) donne 25 au lieu de 24 pour h = 14 en flottant (9 valeurs fausses
  -- entre 0 et 60). Le modèle calcule 10 + h.
  local exact = true
  for h = 0, 60 do if O.recruit_cost(h)[2][2] ~= 10 + h then exact = false end end
  check(exact, "recrue : 10 + effectif plaques, exact pour 0 à 60 PNJ (arithmétique entière)")
end
check(O.revive_policy(1, true, true) == "recruit", "rang 1 : on recrute (moins cher)")
check(O.revive_policy(2, true, true) == "resurrect", "rang 2 et plus : on ressuscite")
check(O.revive_policy(4, false, true) == "recruit", "résurrection impayable : on recrute")
check(O.revive_policy(1, true, false) == "resurrect", "recrue impayable : on ressuscite")
check(O.revive_policy(3, false, false) == "wait", "rien n'est payable : on attend")
check(ser(r5):find("FONCTION") == nil, "coût sérialisable")

---------------------------------------------------------------------------------------------------
section("Progression des PNJ et comparaison au joueur")
local ranks = { { 0, 1 }, { 29, 1 }, { 30, 2 }, { 119, 2 }, { 120, 3 }, { 359, 3 }, { 360, 4 }, { 899, 4 }, { 900, 5 }, { 1e6, 5 } }
for _, c in ipairs(ranks) do check(O.rank(c[1]) == c[2], string.format("%d XP -> rang %d", c[1], c[2])) end
local xp, carry = O.gain(0, 0, 3600, false)
check(xp == 1 and carry == 0, "1 min de travail = 1 XP")
xp, carry = O.gain(0, 0, 1800, true)
check(xp == 1 and carry == 0, "conception : 30 s comptent 1 min")
xp, carry = O.gain(0, 0, 1800, false)
xp, carry = O.gain(xp, carry, 1800, false)
check(xp == 1 and carry == 0, "le reste est conservé d'une tâche à l'autre")
local m1 = O.modifiers(1, "leger")
check(m1.character_crafting_speed_modifier == 0 and m1.character_running_speed_modifier == 0
  and m1.character_mining_speed_modifier == 0 and m1.character_inventory_slots_bonus == 0,
  "rang 1 : comme le joueur (fabrication, course, minage, inventaire)")
check(m1.character_build_distance_bonus == 6 and m1.character_reach_distance_bonus == 6, "portée +6 à tous les rangs (lots de 24 tuiles)")
local m5 = O.modifiers(5, "leger")
check(m5.character_crafting_speed_modifier == 2 and m5.character_mining_speed_modifier == 1.5
  and m5.character_running_speed_modifier == 0.15 and m5.character_inventory_slots_bonus == 40,
  "rang 5, profil léger : fabrication ×3, minage ×2,5, course +15 %, +40 cases")
local e5 = O.modifiers(5, "egal")
check(e5.character_crafting_speed_modifier == 0 and e5.character_running_speed_modifier == 0, "profil égal : aucun bonus")
local f5 = O.modifiers(5, "fort")
check(f5.character_crafting_speed_modifier == 3 and f5.character_running_speed_modifier == 0.15 and f5.character_inventory_slots_bonus == 60,
  "profil fort : ×4 en fabrication, course plafonnée à +15 %, +60 cases")
check(O.modifiers(3, "leger", "merciless").character_crafting_speed_modifier > O.modifiers(3, "leger", "easy").character_crafting_speed_modifier,
  "Impitoyable > Facile (bonus multipliés par la difficulté)")
local mono_ok, run_ok = true, true
for _, prof in ipairs({ "egal", "leger", "fort" }) do
  for _, dif in ipairs({ "peaceful", "easy", "normal", "hard", "merciless", "__nil" }) do
    local d = dif ~= "__nil" and dif or nil
    local prev
    for r = 1, 5 do
      local m = O.modifiers(r, prof, d)
      if m.character_running_speed_modifier > O.RUN_CAP then run_ok = false end
      if prev then
        for _, k in ipairs(O.MODIFIER_ORDER) do if m[k] < prev[k] then mono_ok = false end end
      end
      prev = m
    end
  end
end
check(run_ok, "course : jamais plus de +15 % (« légèrement plus vite »), tous profils, rangs et difficultés")
check(mono_ok, "chaque modificateur croît avec le rang (3 profils × 6 difficultés)")
-- Chiffres de comparaison (référence vanilla relue dans data/base/prototypes/entity/entities.lua).
print(string.format("   course joueur 0,15 tuile/tick ; PNJ rang 5 : %.4f ; minage joueur 0,5 ; PNJ rang 5 : %.2f ; inventaire 80 / %d",
  0.15 * (1 + m5.character_running_speed_modifier), 0.5 * (1 + m5.character_mining_speed_modifier), 80 + m5.character_inventory_slots_bonus))

---------------------------------------------------------------------------------------------------
section("Règle d'automatisation et plafonds de travail manuel")
check(O.needs_automation(61, 11, 64), "61/min, 11 min, 64 tuiles : tapis ou conduite")
check(not O.needs_automation(60, 11, 64), "60/min : porteurs")
check(not O.needs_automation(100, 10, 30), "besoin de 10 min seulement : porteurs")
check(not O.needs_automation(100, 30, 65), "plus de 64 tuiles : porteurs (trains et longs tapis hors IA1)")
check(O.manual_cap(25, 1) == 12 and O.manual_cap(25, 2) == 5 and O.manual_cap(25, 9) == 5, "plafond manuel : 12 à l'époque 1, puis 5 sur 25 (20 %)")
check(O.manual_cap(3, 2) == 1 and O.manual_cap(0, 2) == 1, "plafond manuel : au moins 1")

---------------------------------------------------------------------------------------------------
section("Amélioration instantanée : combien de bâtiments en un trajet")
do
  local cost = { { "steel-plate", 20 }, { "iron-gear-wheel", 10 } }
  local costs = {}
  for i = 1, 6 do costs[i] = cost end
  local stack = { ["steel-plate"] = 100, ["iron-gear-wheel"] = 100 }
  local served, take = O.trip_capacity(costs, stack, 2)
  check(served == 5 and ser(take) == ser({ { "iron-gear-wheel", 50 }, { "steel-plate", 100 } }),
    "2 cases libres : 5 fours sur 6 en un trajet (100 acier + 50 engrenages)")
  local all6 = O.trip_capacity(costs, stack, 3)
  check(all6 == 6, "3 cases : tout le module (6 fours) en un trajet")
  check(O.trip_capacity(costs, stack, 0) == 0, "inventaire plein : aucun")
end

---------------------------------------------------------------------------------------------------
section("Compatibilité avec le cerveau d'équipe actuel (planner.lua, vraies recettes)")
do
  local book = Book.new(dofile("tests/fixtures/recipes.lua"))
  local stock = {}
  for _, it in ipairs(T.start_kit) do stock[it[1]] = it[2] end
  local view = {
    tech = 0, personality = "balanced", done = { coal = true, iron = true, copper = true, stone = true }, deferred = {},
    stock = stock, incoming = {},
    outposts = {
      { id = 1, kind = "coal", drills = 4, turrets = 0, fuel_low = false, output = 60, idle_ticks = 0, has_task = false },
      { id = 2, kind = "iron", drills = 8, turrets = 0, fuel_low = true, output = 10, idle_ticks = 0, has_task = false },
      { id = 3, kind = "copper", drills = 3, turrets = 0, fuel_low = false, output = 50, idle_ticks = 0, has_task = false },
      { id = 4, kind = "stone", drills = 2, turrets = 0, fuel_low = false, output = 0, idle_ticks = 0, has_task = false },
    },
    pending = {}, sites = { coal = 1, iron = 1, copper = 1, stone = 1 },
    smelters = 2, smelters_pending = 0, smelter_task = false, smelter_output = 5, smelter_fuel_low = false, smelter_coal = 10,
    turret_groups = { { key = "hq", low = 2, has_task = false } },
    soldiers = 0, soldiers_max = 100, workers = 8, workers_max = 30, workers_idle = 4, threatened = false, open = {},
  }
  local plan = Planner.plan(view, book)
  check(#plan.tasks > 0, "le cerveau actuel produit " .. #plan.tasks .. " tâches")
  local d = O.demand_from_tasks(plan.tasks)
  local known = true
  for _, t in ipairs(plan.tasks) do if not O.TASK_DOMAIN[t.kind] then known = false end end
  check(known, "chaque tâche du cerveau actuel a un domaine et un pôle")
  local dsum = 0
  for _, dom in ipairs(O.DOMAINS) do dsum = dsum + d.domains[dom.key] end
  check(dsum == sum3(d.poles) and dsum > 0, "travail par domaine = travail par pôle (" .. dsum .. " s)")
  local npcs = make_team(30, 5, { 10, 10, 5 })
  local out = O.plan({ tick = 0, npcs = npcs, tasks = plan.tasks, orientation = O.PERSONALITY.balanced, chiefs = 5 })
  check(sum3(out.targets) == 25, "cibles calculées sur le vrai tableau : " .. ser(out.targets) .. ", surplus " .. out.surplus)
  print(string.format("   tableau actuel : %d tâches, %d s de travail (extraction %d, base %d, territoire %d) ; %d exécutants sans travail identifié",
    #plan.tasks, dsum, d.poles[1], d.poles[2], d.poles[3], out.surplus))
  -- Constat H-E1 (pourquoi l'échelle stagne avant le pack chimique) : le moteur de fabrication à la main ne
  -- sait pas faire le moteur (catégorie advanced-crafting) ni le plastique (chimie) : il faut des machines.
  check(not book:handcraftable("engine-unit") and not book:handcraftable("plastic-bar") and not book:handcraftable("sulfur"),
    "H-E1 : moteur, plastique et soufre ne se fabriquent pas à la main (il faut assembleur, usine chimique, pétrole)")
  check(book:handcraftable("electronic-circuit") and book:handcraftable("advanced-circuit"),
    "circuits verts et rouges se fabriquent à la main… si le plastique existe")
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
