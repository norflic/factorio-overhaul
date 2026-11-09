--[[
  Lot SCAN-TRANCHES (directive du DC du 9/11) : scans périodiques par impulsions, fenêtres de ticks successifs, équipes désynchronisées.
    §1 shared/team/scan_tranches.lua, St.window / St.rank_at : sur une période entière et 4 rangs, jamais deux équipes actives au même
       tick ; chaque rang est actif exactement `slices` ticks successifs, à partir de T + r × (slices + gap) ; périodique ; déterministe ;
    §2 St.share / St.share_capped : les tranches couvrent une liste de n éléments sans trou ni doublon, parts de tailles égales à 1 près,
       plafond respecté et reste compté ;
    §3 St.covers, St.tile_box, St.box_cost ;
    §4 mutants : chevauchement de parts, trou entre parts, fenêtres sans décalage, tranche hors fenêtre : tous refusés par les mêmes
       détecteurs ;
    §5 script/team/hygiene.lua sur un moteur minimal (modules du dépôt doublés) : relevé, parts, compteurs (a) sur gisement et
       (b) feuille sans consommateur propre, jeton refusé puis accordé, plafond par tranche, dispatch des rangs par on_tick.
  Usage : lua5.2 tests/scan_tranches_test.lua   (depuis la racine du mod ; moins d'une seconde)
]]
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function section(name) print("== " .. name) end

local St = require("shared.team.scan_tranches")

---------------------------------------------------------------------------------------------------
-- Détecteurs partagés par §1, §2 et §4 (une règle et ses mutants passent par les MÊMES fonctions)
---------------------------------------------------------------------------------------------------
--- Sur une période : { double = ticks avec 2 équipes actives, actifs[r] = ticks actifs du rang r, contigu[r], debut[r] }.
local function scan_windows(window, cfg, ranks)
  local res = { double = 0, actifs = {}, debut = {}, contigu = {}, fin = {} }
  for r = 0, ranks - 1 do res.actifs[r], res.contigu[r] = 0, true end
  for tick = 0, cfg.period - 1 do
    local n = 0
    for r = 0, ranks - 1 do
      local on, s = window(tick, r, cfg)
      if on then
        n = n + 1
        res.actifs[r] = res.actifs[r] + 1
        if not res.debut[r] then res.debut[r] = tick end
        if res.fin[r] and tick ~= res.fin[r] + 1 then res.contigu[r] = false end
        res.fin[r] = tick
        if s ~= tick - res.debut[r] then res.contigu[r] = false end
      end
    end
    if n > 1 then res.double = res.double + 1 end
  end
  return res
end

--- Couverture d'une liste de n éléments par `slices` parts : chaque indice vu exactement une fois, parts croissantes.
local function coverage(share, n, slices)
  local seen, prev_b = {}, 0
  for s = 0, slices - 1 do
    local a, b = share(n, s, slices)
    if a ~= prev_b + 1 then return false, "part " .. s .. " commence a " .. a .. " apres " .. prev_b end
    for i = a, b do
      if seen[i] then return false, "doublon " .. i end
      seen[i] = true
    end
    if b >= a then prev_b = b end
  end
  for i = 1, n do if not seen[i] then return false, "trou " .. i end end
  if prev_b ~= n then return false, "fin " .. prev_b .. " ~= " .. n end
  return true
end

---------------------------------------------------------------------------------------------------
section("§1 fenêtres : désynchronisation, durée, contiguïté, périodicité")
---------------------------------------------------------------------------------------------------
local cfg = St.CFG
check(cfg.period == 18000 and cfg.slices == 20 and cfg.gap == 40, "réglage par défaut 18 000 / 20 / 40")
local res = scan_windows(St.window, cfg, 4)
check(res.double == 0, "jamais deux équipes actives au même tick (" .. res.double .. ")")
for r = 0, 3 do
  check(res.actifs[r] == cfg.slices, "rang " .. r .. " actif " .. cfg.slices .. " ticks (" .. tostring(res.actifs[r]) .. ")")
  check(res.debut[r] == r * (cfg.slices + cfg.gap), "rang " .. r .. " commence à T + r × 60 (" .. tostring(res.debut[r]) .. ")")
  check(res.contigu[r], "rang " .. r .. " : ticks successifs et tranche = tick - début")
end
-- périodique et déterministe
local same = true
for tick = 0, 400 do
  for r = 0, 3 do
    local a1, s1 = St.window(tick, r, cfg)
    local a2, s2 = St.window(tick + 7 * cfg.period, r, cfg)
    local a3, s3 = St.window(tick, r, cfg)
    if a1 ~= a2 or s1 ~= s2 or a1 ~= a3 or s1 ~= s3 then same = false end
  end
end
check(same, "même réponse à tick + 7 périodes et à un second appel")
-- rank_at : nil dans les repos, cohérent avec window
local ok_rank = true
for tick = 0, 3 * (cfg.slices + cfg.gap) + 5 do
  local r, s = St.rank_at(tick, cfg)
  for rr = 0, 3 do
    local on, ss = St.window(tick, rr, cfg)
    if on ~= (r == rr) or (on and ss ~= s) then ok_rank = false end
  end
  if r == nil and tick % (cfg.slices + cfg.gap) < cfg.slices then ok_rank = false end
end
check(ok_rank, "rank_at et window disent la même chose")
check(St.pulse_start(18000 * 3 + 59, cfg) == 54000 and St.pulse_start(0, cfg) == 0, "début d'impulsion = dernier multiple de la période")
-- autre réglage : 3 tranches, repos 1, période 12 : les trois rangs sont actifs sur [0,3), [4,7), [8,11)
local c2 = { period = 12, slices = 3, gap = 1 }
local r2 = scan_windows(St.window, c2, 3)
check(r2.double == 0 and r2.debut[0] == 0 and r2.debut[1] == 4 and r2.debut[2] == 8 and r2.actifs[2] == 3, "petit réglage 12 / 3 / 1")

---------------------------------------------------------------------------------------------------
section("§2 parts : couverture complète, tailles, plafond")
---------------------------------------------------------------------------------------------------
local all_ok, size_ok = true, true
for _, slices in ipairs({ 1, 2, 3, 7, 19, 20, 64 }) do
  for n = 0, 300 do
    local ok, why = coverage(St.share, n, slices)
    if not ok then all_ok = false print("  couverture n=" .. n .. " slices=" .. slices .. " : " .. why) end
    local lo, hi = math.huge, -1
    for s = 0, slices - 1 do
      local a, b = St.share(n, s, slices)
      local sz = b - a + 1
      if sz < lo then lo = sz end
      if sz > hi then hi = sz end
    end
    if hi - lo > 1 or hi > math.ceil(n / slices) then size_ok = false end
  end
end
check(all_ok, "toutes les parts couvrent 1..n sans trou ni doublon (n ≤ 300, 7 découpages)")
check(size_ok, "parts de tailles égales à 1 près, jamais plus de ceil(n / slices)")
local a, b = St.share(0, 0, 20)
check(b < a, "liste vide : part vide")
local a1, b1 = St.share(1, 19, 20)
check(a1 == 1 and b1 == 1, "un seul élément : dans la dernière part")
-- plafond
local cap_ok, done, skipped = true, 0, 0
for s = 0, 19 do
  local pa, pb, sk = St.share_capped(100, s, 20, 2)
  if pb - pa + 1 > 2 then cap_ok = false end
  done, skipped = done + math.max(0, pb - pa + 1), skipped + sk
end
check(cap_ok and done == 40 and skipped == 60, "plafond 2 par tranche sur 100 : 40 traités, 60 comptés en reste")
local pa, pb, sk = St.share_capped(30, 3, 20, 40)
local qa, qb = St.share(30, 3, 20)
check(pa == qa and pb == qb and sk == 0, "sous le plafond : la part entière, reste 0")

---------------------------------------------------------------------------------------------------
section("§3 géométrie : covers, tile_box, box_cost")
---------------------------------------------------------------------------------------------------
check(St.covers(10.5, 10.5, 2.5, 11, 9, 14, 12), "machine 3 × 3 chevauchant le carré 5 × 5 : alimentée")
check(not St.covers(10.5, 10.5, 2.5, 13, 9, 16, 12), "boîte qui touche le bord (x0 = px + d) : pas alimentée")
check(not St.covers(10.5, 10.5, 2.5, 20, 20, 21, 21), "loin : pas alimentée")
local x0, y0, x1, y1 = St.tile_box(10.35, 10.35, 10.65, 10.65)
check(x0 > 10 and x0 < 10.1 and y0 > 10 and x1 > 10.9 and x1 < 11 and y1 < 11, "poteau 1 × 1 : sa tuile, rétrécie")
x0, y0, x1, y1 = St.tile_box(9, 9, 11, 11)
check(x0 > 9 and x1 < 11 and x1 > 10.9, "poste 2 × 2 : ses quatre tuiles")
check(St.box_cost({ x0 = -3, y0 = 2, x1 = 4, y1 = 5 }) == 32 and St.box_cost(nil) == nil, "coût d'une boîte = chunks ; sans boîte : nil")

---------------------------------------------------------------------------------------------------
section("§4 mutants")
---------------------------------------------------------------------------------------------------
local function share_overlap(n, s, slices)
  local sa, sb = St.share(n, s, slices)
  if s < slices - 1 and sb >= sa then sb = sb + 1 end
  return sa, sb
end
local function share_hole(n, s, slices)
  local sa, sb = St.share(n, s, slices)
  if s < slices - 1 and sb >= sa then sb = sb - 1 end
  return sa, sb
end
check(not coverage(share_overlap, 50, 20), "mutant chevauchement (b + 1) refusé")
check(not coverage(share_hole, 50, 20), "mutant trou (b - 1) refusé")
local function window_nogap(tick, rank, c)
  local phase = tick % c.period
  return phase < c.slices, (phase < c.slices) and phase or nil -- toutes les équipes dans la même fenêtre
end
check(scan_windows(window_nogap, cfg, 3).double > 0, "mutant « même fenêtre pour toutes » refusé (doubles)")
local function window_nobound(tick, rank, c)
  local phase = tick % c.period
  local stride = c.slices + c.gap
  local r = math.floor(phase / stride)
  return r == rank, phase % stride -- tranche non bornée : l'équipe reste active pendant le repos
end
local rn = scan_windows(window_nobound, cfg, 3)
check(rn.actifs[0] ~= cfg.slices, "mutant « tranche non bornée » refusé (durée)")
local function window_norank(tick, rank, c)
  local phase = tick % c.period
  return phase % (c.slices + c.gap) < c.slices, phase % (c.slices + c.gap) -- le rang est ignoré
end
check(scan_windows(window_norank, cfg, 3).double > 0, "mutant « rang ignoré » refusé (doubles)")

---------------------------------------------------------------------------------------------------
section("§5 moteur script/team/hygiene.lua sur un moteur minimal")
---------------------------------------------------------------------------------------------------
-- Doublures des modules du dépôt (chargées AVANT le moteur ; aucune n'est le vrai module)
local tick_fn
package.loaded["script.core.events"] = { on = function(_, fn) tick_fn = fn end }
package.loaded["script.core.profiler"] = { start = function() end, stop = function() end, fstart = function() end, fstop = function() end }
package.loaded["script.team.boite_chunks"] = { get = function() return { x0 = -2, y0 = -2, x1 = 3, y1 = 3 } end }
local jeton = { refuse = 0, takes = 0, drops = 0, costs = {} }
package.loaded["script.core.lourd"] = {
  take = function(_, _, _, cost)
    jeton.takes = jeton.takes + 1
    jeton.costs[#jeton.costs + 1] = cost
    if jeton.refuse > 0 then jeton.refuse = jeton.refuse - 1 return false end
    return true
  end,
  drop = function() jeton.drops = jeton.drops + 1 end,
}
local factions = {}
package.loaded["script.faction.state"] = {
  alive = function()
    local ids = {}
    for id, f in pairs(factions) do if id ~= "player" and not f.eliminated then ids[#ids + 1] = id end end
    table.sort(ids)
    return ids
  end,
  faction = function(id) return factions[id] end,
}
defines = { events = { on_tick = 1 } } -- luacheck: ignore
local logs = {}
function log(text) logs[#logs + 1] = text end -- luacheck: ignore

local Hy = require("script.team.hygiene")
check(type(tick_fn) == "function", "le moteur s'abonne à on_tick au chargement")

-- Moteur minimal : entités { type, force, unit_number, position, bounding_box, prototype, electric_network_id, neighbours }
local ents = {}
local function overlap(bb, x0, y0, x1, y1)
  return bb.right_bottom.x > x0 and bb.left_top.x < x1 and bb.right_bottom.y > y0 and bb.left_top.y < y1
end
local function matches(e, q)
  if q.type and e.type ~= q.type then return false end
  if q.force and e.force ~= q.force then return false end
  if q.area then
    if not overlap(e.bounding_box, q.area[1][1], q.area[1][2], q.area[2][1], q.area[2][2]) then return false end
  end
  if q.position then
    local px, py = q.position[1] or q.position.x, q.position[2] or q.position.y
    local dx, dy = e.position.x - px, e.position.y - py
    if dx * dx + dy * dy > q.radius * q.radius then return false end
  end
  return true
end
local surface = {
  find_entities_filtered = function(q)
    local out = {}
    for _, e in ipairs(ents) do if matches(e, q) then out[#out + 1] = e end end
    return out
  end,
  count_entities_filtered = function(q)
    local n = 0
    for _, e in ipairs(ents) do if matches(e, q) then n = n + 1 end end
    return n
  end,
}
local next_un = 1
local function box(x, y, w, h) return { left_top = { x = x - w / 2, y = y - h / 2 }, right_bottom = { x = x + w / 2, y = y + h / 2 } } end
local function pole(x, y, force, net, d)
  local e = { type = "electric-pole", force = force, unit_number = next_un, valid = true, position = { x = x, y = y }, bounding_box = box(x, y, 0.3, 0.3),
    prototype = { supply_area_distance = d or 2.5 }, electric_network_id = net, neighbours = { copper = {}, red = {}, green = {} } }
  next_un = next_un + 1
  ents[#ents + 1] = e
  return e
end
local function wire(a, b) a.neighbours.copper[#a.neighbours.copper + 1] = b; b.neighbours.copper[#b.neighbours.copper + 1] = a end
local function machine(kind, x, y, w, h, force, net)
  local e = { type = kind, force = force, unit_number = next_un, valid = true, position = { x = x, y = y }, bounding_box = box(x, y, w, h),
    prototype = { electric_energy_source_prototype = {} }, electric_network_id = net }
  next_un = next_un + 1
  ents[#ents + 1] = e
  return e
end
local function ore(x, y) ents[#ents + 1] = { type = "resource", force = "neutral", position = { x = x + 0.5, y = y + 0.5 }, bounding_box = box(x + 0.5, y + 0.5, 0.2, 0.2), prototype = {} } end
local function team(key, force) return { key = key, force = force, team = {}, hq = { valid = true, surface = surface } } end

-- Scène (force f1) : A feuille dont la seule machine est aussi sous B ; B au milieu ; C feuille qui alimente seule une génératrice, sur
-- gisement ; D isolé ; un tapis (sans source électrique) sous A ; un poteau d'une AUTRE force sous la machine de C.
local A = pole(10.5, 10.5, "f1", 7)
local B = pole(15.5, 10.5, "f1", 7)
local C = pole(20.5, 10.5, "f1", 7)
local D = pole(40.5, 40.5, "f1", 9)
wire(A, B); wire(B, C)
machine("assembling-machine", 12.5, 10.5, 3, 3, "f1", 7)
machine("generator", 23.5, 10.5, 3, 3, "f1", 7)
ents[#ents + 1] = { type = "transport-belt", force = "f1", position = { x = 9.5, y = 10.5 }, bounding_box = box(9.5, 10.5, 1, 1), prototype = {} }
pole(24.5, 12.5, "f2", 7)
ore(20, 10)
ore(30, 30)

local f1 = team(1, "f1")
factions[1] = f1
local T0 = 18000 * 4
for s = 0, 19 do Hy.step(f1, surface, T0 + s, s) end
local h = f1.team.hygiene
check(h and h.n == 4 and h.audited == 4, "4 poteaux de la force relevés et audités (" .. tostring(h and h.n) .. ", " .. tostring(h and h.audited) .. ")")
check(h.sur == 1, "1 poteau sur gisement (C) : " .. tostring(h.sur))
check(h.red == 2, "2 redondants candidats (A : machine aussi sous B ; D : isolé) : " .. tostring(h.red))
check(h.r0 == 0 and h.cost == 5, "relevé à la tranche 0 ; coût = 1 relevé + 4 tranches non vides (" .. tostring(h.cost) .. ")")
check(jeton.costs[1] == 36, "coût déclaré au jeton = chunks de la boîte (6 × 6) : " .. tostring(jeton.costs[1]))
check(#h.poles == 0 and h.logged, "liste rendue après le journal")
check(#logs == 1 and logs[1] == "[FO-HYGIENE] 1 : impulsion a 20.0 min : 4 poteaux releves, 1 sur gisement, 2 redondants candidats (feuilles sans consommateur propre) ; cout : 5 tranches",
  "ligne [FO-HYGIENE] attendue : " .. tostring(logs[1]))
-- déterminisme : la même scène, rejouée, donne les mêmes compteurs
local h1 = { n = h.n, sur = h.sur, red = h.red, cost = h.cost }
for s = 0, 19 do Hy.step(f1, surface, T0 + 18000 + s, s) end
h = f1.team.hygiene
check(h.n == h1.n and h.sur == h1.sur and h.red == h1.red and h.cost == h1.cost, "seconde impulsion : mêmes compteurs")
-- B n'est plus une feuille, mais si l'on coupe le fil B-C, C devient feuille à génératrice propre : toujours pas candidat ; B feuille
-- dont la machine est aussi sous A : candidat
B.neighbours.copper, C.neighbours.copper = { A }, {}
for s = 0, 19 do Hy.step(f1, surface, T0 + 36000 + s, s) end
check(f1.team.hygiene.red == 3, "fil B-C coupé : A, B et D candidats, C (génératrice propre) non : " .. tostring(f1.team.hygiene.red))
-- jeton refusé 2 tranches : relevé à la tranche 2, audit entier sur les 17 restantes
jeton.refuse = 2
logs = {}
for s = 0, 19 do Hy.step(f1, surface, T0 + 54000 + s, s) end
h = f1.team.hygiene
check(h.r0 == 2 and h.audited == 4 and h.red == 3 and h.cost == 5, "jeton refusé 2 fois : relevé à la tranche 2, audit complet (" .. tostring(h.r0) .. ", " .. tostring(h.audited) .. ")")
check(#logs == 1 and logs[1]:find("4 poteaux releves", 1, true), "une ligne de journal")
-- jeton refusé toute la fenêtre : rien relevé, entrée retirée de la file, ligne de journal qui le dit
jeton.refuse = 20
logs = {}
for s = 0, 19 do Hy.step(f1, surface, T0 + 72000 + s, s) end
h = f1.team.hygiene
check(h.r0 == nil and h.n == 0 and jeton.drops == 1 and #logs == 1 and logs[1]:find("jeton des travaux lourds refuse", 1, true) ~= nil,
  "jeton refusé 20 fois : rien relevé, Lourd.drop, journal")
-- plafond par tranche : 100 poteaux isolés d'une force f3, max_per_slice 2 : 38 audités (19 tranches × 2), 62 comptés en reste
for i = 1, 100 do pole(i + 0.5, 60.5, "f3", 100 + i) end -- (dans la boîte des chunks de la doublure : −64..128)
local f3 = team(3, "f3")
local saved = Hy.CFG.max_per_slice
Hy.CFG.max_per_slice = 2
logs = {}
for s = 0, 19 do Hy.step(f3, surface, T0 + s, s) end
Hy.CFG.max_per_slice = saved
h = f3.team.hygiene
check(h.n == 100 and h.audited == 38 and h.skipped == 62 and h.audited + h.skipped == h.n, "plafond 2 : 38 audités, 62 en reste (" .. tostring(h.audited) .. ", " .. tostring(h.skipped) .. ")")
check(logs[1] and logs[1]:find("62 non audites (plafond 2 par tranche)", 1, true) ~= nil, "le journal dit le reste")
-- passe interrompue (l'équipe manque la fin de sa fenêtre) : journalisée à l'impulsion suivante
logs = {}
for s = 0, 5 do Hy.step(f3, surface, T0 + 18000 + s, s) end
Hy.step(f3, surface, T0 + 36000, 0)
check(#logs == 1 and logs[1]:find("passe interrompue", 1, true) ~= nil, "passe interrompue journalisée")
-- dispatch par on_tick : rangs 0, 1 = factions (ids triés), rang 2 = votre équipe ; chacune journalise une fois, à la fin de sa fenêtre
factions = {}
package.loaded["script.faction.state"].faction = function(id) return factions[id] end
local fa, fb, fp = team(2, "f1"), team(5, "f3"), team("player", "player")
factions[5], factions[2], factions.player = fb, fa, fp
logs = {}
local when = {}
for tick = 18000 * 7, 18000 * 8 - 1 do
  local before = #logs
  tick_fn({ tick = tick })
  if #logs > before then when[#when + 1] = { tick - 18000 * 7, logs[#logs]:match("^%[FO%-HYGIENE%] (%S+) :") } end
end
check(#logs == 3, "trois équipes, trois lignes par période (" .. #logs .. ")")
check(when[1] and when[1][1] == 19 and when[1][2] == "2", "rang 0 = faction 2 (id le plus petit), journal au tick T + 19")
check(when[2] and when[2][1] == 79 and when[2][2] == "5", "rang 1 = faction 5, journal au tick T + 79")
check(when[3] and when[3][1] == 139 and when[3][2] == "player", "rang 2 = votre équipe, journal au tick T + 139")
-- un QG détruit : son équipe ne travaille pas, les autres gardent leur rang
fa.hq.valid = false
logs = {}
for tick = 18000 * 8, 18000 * 9 - 1 do tick_fn({ tick = tick }) end
check(#logs == 2 and logs[1]:match("^%[FO%-HYGIENE%] 5 :") and logs[2]:match("^%[FO%-HYGIENE%] player :"), "QG de la faction 2 perdu : 2 lignes, rangs gardés")
-- l'état gardé ne contient que des nombres, booléens, chaînes et tables
local function pure(t)
  for k, v in pairs(t) do
    local tv = type(v)
    if tv == "table" then if not pure(v) then return false end
    elseif tv ~= "number" and tv ~= "boolean" and tv ~= "string" then return false end
    if type(k) == "function" or type(k) == "userdata" then return false end
  end
  return true
end
check(pure(fb.team.hygiene) and pure(f1.team.hygiene), "état f.team.hygiene en données pures")

print(string.format("scan_tranches_test : %d OK, %d ECHEC", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
