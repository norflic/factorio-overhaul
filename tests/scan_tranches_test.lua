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
       (b) feuille sans consommateur propre, jeton refusé puis accordé, plafond par tranche, dispatch des rangs par on_tick ;
    §5 bis (lot HYGIENE-ACTIVE, DC 10/11) : le moteur AGIT : feuille rendue au coffre puis détruite, poteau sur gisement remplacé en
       deux tranches (pose, vérification au tick, retrait), relecture au tick (la seconde feuille d'une paire reste), refus par cause
       (famine, menace du QG, budget, projet non fini, pièce du plan, chaîne des foreuses, posé par un joueur, couvrant non alimenté),
       remplaçant non relié détruit et rendu, idempotence (seconde impulsion : rien à faire).
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
check(cfg.period == 10800 and cfg.slices == 20 and cfg.gap == 40, "réglage par défaut 10 800 (3 min, DC 9/11) / 20 / 40")
check(cfg.period % (cfg.slices + cfg.gap) == 0, "la période est un nombre entier de créneaux (voies de réveil alignées)")
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
local tick_fn, research_fn
-- (fusion BOXES : deux modules s'abonnent a on_research_finished (scan_reveil, boxes_rt) : la doublure les appelle TOUS, dans l'ordre d'abonnement)
local research_fns = {}
research_fn = function(e) for _, fn in ipairs(research_fns) do fn(e) end end
package.loaded["script.core.events"] = { on = function(id, fn) if id == 1 then tick_fn = fn elseif id == 2 then research_fns[#research_fns + 1] = fn end end }
-- Lot UPS : le registre des machines (script/team/registre_types.lua) et le vrai stockage s abonnent au chargement (on_init, on_load,
-- on_configuration_changed) : tout abonnement absent du bouchon est sans effet.
setmetatable(package.loaded["script.core.events"], { __index = function() return function() end end })
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
defines = { events = { on_tick = 1, on_research_finished = 2 } } -- luacheck: ignore
local logs = {}
function log(text) logs[#logs + 1] = text end -- luacheck: ignore
-- lot HYGIENE-ACTIVE : coffre (comptes par objet), famine (drapeau), réseaux alimentés (ensemble), ennemis (aucun)
local stock = { ["poteau-test"] = 2 }
local famine = true
local live = {}
package.loaded["script.team.stock"] = {
  count = function(_, item) return stock[item] or 0 end,
  insert = function(_, item, n) stock[item] = (stock[item] or 0) + n return n end,
  remove = function(_, item, n) local got = math.min(n, stock[item] or 0) stock[item] = (stock[item] or 0) - got return got end,
}
package.loaded["script.team.famine_fer"] = { team_starved = function() return famine end }
package.loaded["script.team.generateurs"] = { TYPES = { "generator" }, networks = function() return live, 0 end }
package.loaded["script.team.reseau_vivant"] = { foe_near = function() return nil end, POLE_ENEMY_R = 28 }

local Hy = require("script.team.hygiene")
local Sr = require("script.team.scan_reveil")
check(type(tick_fn) == "function", "le moteur s'abonne à on_tick au chargement")
check(type(research_fn) == "function", "les réveils s'abonnent à on_research_finished au chargement (statique)")

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
  -- lot HYGIENE-ACTIVE : une place est libre si aucune entité (hors ressource) n'y a sa boîte ; la pose crée un poteau de la doublure
  can_place_entity = function(q)
    for _, e in ipairs(ents) do
      if e.type ~= "resource" and e.bounding_box and overlap(e.bounding_box, q.position.x - 0.4, q.position.y - 0.4, q.position.x + 0.4, q.position.y + 0.4) then return false end
    end
    return true
  end,
  create_entity = function(q) return POLE(q.position.x, q.position.y, q.force, nil) end,
}
local next_un = 1
local function box(x, y, w, h) return { left_top = { x = x - w / 2, y = y - h / 2 }, right_bottom = { x = x + w / 2, y = y + h / 2 } } end
POLE = nil -- luacheck: ignore (référence tardive de la doublure : create_entity de la surface)
local connect_ok = true -- lot HYGIENE-ACTIVE : faux : le fil du remplaçant ne se pose pas (remplacement raté)
local function wire(a, b) a.neighbours.copper[#a.neighbours.copper + 1] = b; b.neighbours.copper[#b.neighbours.copper + 1] = a end
local function unwire(e)
  for _, o in ipairs(ents) do
    if o.neighbours then
      local keep = {}
      for _, n in ipairs(o.neighbours.copper) do if n ~= e then keep[#keep + 1] = n end end
      o.neighbours.copper = keep
    end
  end
end
local function pole(x, y, force, net, d)
  local e = { type = "electric-pole", name = "poteau-test", force = force, unit_number = next_un, valid = true, position = { x = x, y = y },
    bounding_box = box(x, y, 0.3, 0.3), prototype = { supply_area_distance = d or 2.5, max_wire_distance = 7.5 }, electric_network_id = net,
    neighbours = { copper = {}, red = {}, green = {} } }
  e.destroy = function()
    e.valid = false
    unwire(e)
    for i = #ents, 1, -1 do if ents[i] == e then table.remove(ents, i) end end
  end
  e.connect_neighbour = function(o)
    if not connect_ok then return false end
    wire(e, o)
    e.electric_network_id = e.electric_network_id or o.electric_network_id
    return true
  end
  next_un = next_un + 1
  ents[#ents + 1] = e
  return e
end
POLE = pole
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
check(#logs == 1 and logs[1] == "[FO-HYGIENE] 1 : impulsion a 20.0 min : 4 poteaux releves, 1 sur gisement, 2 redondants candidats (feuilles sans consommateur propre) ; cout : 5 tranches ; refus : famine 2, remplacant non alimente 1",
  -- s42 gisements : la famine ne retient plus le poteau SUR GISEMENT (C) : son remplaçant est essayé, refusé ici (réseau sans génératrice
  -- au registre), détruit et rendu au coffre ; A et D (hors gisement) restent retenus par la famine
  "ligne [FO-HYGIENE] attendue (famine : rien retiré, 2 refus famine : A, D ; C sur gisement essayé) : " .. tostring(logs[1]))
check(#ents == 10 and stock["poteau-test"] == 2, "famine : aucune entité détruite, coffre inchangé")
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
local P = cfg.period
for tick = P * 7, P * 8 - 1 do
  local before = #logs
  tick_fn({ tick = tick })
  if #logs > before then when[#when + 1] = { tick - P * 7, logs[#logs]:match("^%[FO%-HYGIENE%] (%S+) :") } end
end
check(#logs == 3, "trois équipes, trois lignes par période (" .. #logs .. ")")
check(when[1] and when[1][1] == 19 and when[1][2] == "2", "rang 0 = faction 2 (id le plus petit), journal au tick T + 19")
check(when[2] and when[2][1] == 79 and when[2][2] == "5", "rang 1 = faction 5, journal au tick T + 79")
check(when[3] and when[3][1] == 139 and when[3][2] == "player", "rang 2 = votre équipe, journal au tick T + 139")
-- un QG détruit : son équipe ne travaille pas, les autres gardent leur rang
fa.hq.valid = false
logs = {}
for tick = P * 8, P * 9 - 1 do tick_fn({ tick = tick }) end
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

---------------------------------------------------------------------------------------------------
section("§5 bis moteur : le démontage sécurisé (lot HYGIENE-ACTIVE)")
---------------------------------------------------------------------------------------------------
local P = require("shared.team.plan")
local function run_pass(f, T) logs = {} for s = 0, 19 do Hy.step(f, surface, T + s, s) end return f.team.hygiene end
local function alive(e) return e.valid and (function() for _, x in ipairs(ents) do if x == e then return true end end return false end)() end
-- scène f1 remise : fil B-C rétabli, réseau 7 alimenté, plus de famine
B.neighbours.copper, C.neighbours.copper = { A, C }, { B }
famine, live = false, { [7] = true }
package.loaded["script.team.generateurs"].networks = function() return live, 0 end
local stock0 = stock["poteau-test"]
local hb = run_pass(f1, T0 + 90000)
check(not alive(A) and not alive(D), "A (feuille couverte par B, réseau alimenté) et D (isolé) retirés")
check(alive(B), "B (deux fils) gardé")
check(not alive(C), "C (sur gisement, voisin B, génératrice propre) retiré après remplacement")
local Cn
for _, e in ipairs(ents) do if e.type == "electric-pole" and e.force == "f1" and e.position.x == 20.5 and e.position.y == 9.5 then Cn = e end end
check(Cn ~= nil, "remplaçant posé hors gisement en (20.5, 9.5) : le plus proche qui relie B et couvre la génératrice")
check(Cn and #Cn.neighbours.copper == 1 and Cn.neighbours.copper[1] == B and Cn.electric_network_id == 7, "remplaçant relié à B, réseau 7")
check(stock["poteau-test"] == stock0 + 2, "coffre : +1 (A) -1 (pose du remplacant) +1 (ancien C) +1 (D) = +2 (" .. tostring(stock["poteau-test"] - stock0) .. ")")
check(hb.retraits == 3 and #hb.acts.feuilles == 2 and #hb.acts.remplaces == 1, "3 retraits : 2 feuilles, 1 remplacement")
check(logs[1] and logs[1]:find(" ; retire poteau feuille (10.5, 10.5), (40.5, 40.5) ; remplace poteau sur gisement (20.5, 10.5) -> (20.5, 9.5)", 1, true) ~= nil
  and not logs[1]:find("refus", 1, true), "journal : " .. tostring(logs[1]))
check(f1.team.hygiene_pending == nil, "plus rien en attente")
-- idempotence : la seconde impulsion ne trouve rien à faire (B et le remplaçant ont chacun un consommateur propre)
hb = run_pass(f1, T0 + 108000)
check(hb.n == 2 and hb.red == 0 and hb.retraits == 0 and not logs[1]:find("retire", 1, true) and not logs[1]:find("refus", 1, true),
  "seconde impulsion : 2 poteaux, rien à retirer, aucun refus : " .. tostring(logs[1]))
check(pure(f1.team.hygiene), "état en données pures après les actions")

-- scène f4 : refus par cause et relecture AU TICK (paire P2-P3 : la première est retirée, la seconde garde alors un consommateur propre)
game = { entity_prototypes = { ["poteau-test"] = { type = "electric-pole" } } } -- luacheck: ignore (plan des projets : type du nom)
live[11] = true
local P1 = pole(60.5, 60.5, "f4", 21)
local P2 = pole(70.5, 60.5, "f4", 11)
local P3 = pole(75.5, 60.5, "f4", 11)
wire(P2, P3)
machine("assembling-machine", 72.5, 60.5, 3, 3, "f4", 11)
local P4 = pole(80.5, 60.5, "f4", 22); P4.last_user = {}
local P5 = pole(90.5, 60.5, "f4", 23)
local P6 = pole(100.5, 60.5, "f4", 24)
local P7 = pole(110.5, 60.5, "f4", 25)
local P8 = pole(120.5, 60.5, "f4", 12)
local P9 = pole(125.5, 60.5, "f4", 12)
wire(P8, P9)
machine("assembling-machine", 122.5, 60.5, 3, 3, "f4", 12)
local f4 = team(4, "f4")
f4.build = { order = { 2, 1, 3 }, projects = {
  [1] = { state = "chantier", ents = { { name = "poteau-test", x = 90.5, y = 60.5 }, { name = "machine-test", x = 91.5, y = 60.5 } } },
  [2] = { state = "fini", ents = { { name = "poteau-test", x = 100.5, y = 60.5 } } },
  -- lot UPS-HYGIENE : la ligne de poteaux est un projet du plan (abandonné : ses poteaux restent debout, aucune étiquette « plan ») ; le relevé
  -- ne couvre plus que la zone du plan (rectangles ± portée de fil), plus toute la carte
  [3] = { state = "fini", abandoned = true, ents = { { name = "poteau-test", x = 60.5, y = 60.5 }, { name = "poteau-test", x = 125.5, y = 60.5 } } } } }
f4.swap = { pass = {}, pole_pos = { [P.tkey(110, 60)] = true } }
stock0 = stock["poteau-test"]
hb = run_pass(f4, T0 + 90000)
check(hb.n == 9 and hb.sur == 0, "9 poteaux relevés, aucun sur gisement")
check(not alive(P1) and not alive(P2), "P1 (isolé) et P2 (feuille couverte par P3) retirés")
check(alive(P3) and #P3.neighbours.copper == 0, "P3 relu AU TICK : P2 parti, la machine n'est plus que sous P3 : gardé")
check(alive(P4) and alive(P5) and alive(P6) and alive(P7) and alive(P8) and alive(P9), "P4..P9 gardés")
check(hb.plan["90:60"] == "chantier" and hb.plan["100:60"] == "fini" and hb.plan["91:60"] == nil, "plan des poteaux des projets : chantier, fini, la machine ignorée")
check(logs[1]:find(" ; retire poteau feuille (60.5, 60.5), (70.5, 60.5) ; refus : chaine des foreuses 1, couvrant non alimente 2, piece du plan 1, pose par un joueur 1, projet non fini 1", 1, true) ~= nil,
  "journal des refus par cause (triées) : " .. tostring(logs[1]))
check(stock["poteau-test"] == stock0 + 2, "coffre : +2")
-- chaîne des foreuses hors passe, projet abandonné : P7 et P5 deviennent des feuilles ordinaires
f4.swap.pass = nil
f4.build.projects[1].abandoned = true
hb = run_pass(f4, T0 + 108000)
check(not alive(P7) and not alive(P5) and alive(P6), "chaîne finie et projet abandonné : P7 et P5 retirés ; P6 (plan fini) gardé")

-- scène f5 : budget (6 isolés, 4 retraits par impulsion)
local f5 = team(5, "f5")
local isoles = {}
for i = 1, 6 do isoles[i] = pole(60.5 + 3 * i, 80.5, "f5", 30 + i) end -- (dans la boîte des chunks de la doublure : −64..128)
hb = run_pass(f5, T0 + 90000)
local left = 0
for _, e in ipairs(isoles) do if alive(e) then left = left + 1 end end
check(hb.retraits == 4 and left == 2 and hb.acts.refus["budget"] == 2, "budget : 4 retirés, 2 refus « budget » (" .. tostring(hb.retraits) .. ", " .. left .. ")")
hb = run_pass(f5, T0 + 108000)
left = 0
for _, e in ipairs(isoles) do if alive(e) then left = left + 1 end end
check(left == 0 and hb.retraits == 2, "impulsion suivante : les 2 derniers")

-- scène f6 : menace du QG (hystérésis de votre équipe, puis menace de faction)
local f6 = team(6, "f6")
local M1 = pole(60.5, 90.5, "f6", 40)
f6.team.hq_menace = { crise = true }
hb = run_pass(f6, T0 + 90000)
check(alive(M1) and hb.acts.refus["menace du QG"] == 1, "QG menacé (hq_menace.crise) : refus")
f6.team.hq_menace.crise = false
f6.threatened_until = T0 + 200000
hb = run_pass(f6, T0 + 108000)
check(alive(M1) and hb.acts.refus["menace du QG"] == 1, "faction menacée (threatened_until) : refus")
f6.threatened_until = T0 + 108000
hb = run_pass(f6, T0 + 126000)
check(not alive(M1) and hb.retraits == 1, "menace levée : retiré")

-- scène f7 : remplacement raté (le fil du remplaçant ne se pose pas) : remplaçant détruit et rendu, l'ancien reste
live[13] = true
local Q1 = pole(100.5, 100.5, "f7", 13)
local Q2 = pole(95.5, 100.5, "f7", 13)
wire(Q1, Q2)
machine("generator", 103.5, 100.5, 3, 3, "f7", 13)
machine("assembling-machine", 92.5, 100.5, 3, 3, "f7", 13) -- consommateur propre de Q2 : Q2 n'est pas une feuille à retirer
ore(100, 100)
local f7 = team(7, "f7")
stock0 = stock["poteau-test"]
connect_ok = false
hb = run_pass(f7, T0 + 90000)
connect_ok = true
local n7 = 0
for _, e in ipairs(ents) do if e.type == "electric-pole" and e.force == "f7" then n7 = n7 + 1 end end
check(alive(Q1) and n7 == 2 and stock["poteau-test"] == stock0, "remplaçant non relié : détruit et rendu, l'ancien reste, coffre inchangé (" .. n7 .. ")")
check(hb.acts.refus["voisin non relie"] == 1 and #hb.acts.remplaces == 0 and f7.team.hygiene_pending == nil, "refus « voisin non relie », rien en attente")
-- sans poteau au coffre : rien n'est posé (cause « stock »)
stock["poteau-test"] = 0
hb = run_pass(f7, T0 + 108000)
check(alive(Q1) and hb.acts.refus["stock"] == 1, "coffre sans poteau : refus « stock », rien posé")
stock["poteau-test"] = 1
hb = run_pass(f7, T0 + 126000)
check(not alive(Q1) and #hb.acts.remplaces == 1 and stock["poteau-test"] == 1, "poteau au coffre : remplacé (payé puis l'ancien rendu : coffre inchangé)")
famine, game = true, nil -- luacheck: ignore (les sections suivantes gardent la scène d'avant : aucune action)

---------------------------------------------------------------------------------------------------
section("§6 réveils (lot SCAN-EVENEMENTS) : St.due / St.ack / St.wake, voies, prochain créneau, mutants")
---------------------------------------------------------------------------------------------------
local stride = St.stride(cfg)
local T = cfg.period * 10
-- période échue : le début de la fenêtre périodique du rang, et lui seul
local st = {}
local d, why = St.due(st, T, cfg, 0)
check(d and why == "periode", "rang 0 : passe due à T (periode)")
d, why = St.due(st, T + stride, cfg, 1)
check(d and why == "periode", "rang 1 : passe due à T + stride (periode)")
d, why = St.due(st, T + stride, cfg, 0)
check(not d and why == "rien", "rang 0 : rien de dû à T + stride sans réveil")
check(not St.due(st, T + 5, cfg, 0), "rien de dû hors d'un début de fenêtre")
-- réveil posé puis servi ; un second réveil avant service est compté, pas doublé
check(St.wake(st, T + 100, "stock") == true and st.wake.why == "stock" and st.wake.n == 1, "réveil « stock » posé")
check(St.wake(st, T + 110, "recherche") == false and st.wake.why == "stock" and st.wake.n == 2, "second réveil : compté, le premier gardé")
d, why = St.due(st, T + 120, cfg, 0)
check(d and why == "stock", "réveil posé : passe due au prochain créneau, cause « stock »")
St.ack(st, T + 120, why)
check(st.wake == nil and st.served == T + 120 and st.why == "stock", "ack : réveil consommé, départ et cause gardés")
d, why = St.due(st, T + 130, cfg, 0)
check(not d and why == "fenetre en cours", "pendant la fenêtre servie : rien de dû")
check(not St.due(st, T + 180, cfg, 0), "après la fenêtre, sans réveil : rien de dû")
-- réveil PENDANT la fenêtre en cours : il attend la fin de la fenêtre, puis UNE passe
St.wake(st, T + 125, "energie")
check(not St.due(st, T + 139, cfg, 0), "réveil pendant la fenêtre : rien avant sa fin")
d, why = St.due(st, T + 140, cfg, 0)
check(d and why == "energie", "réveil pendant la fenêtre : dû au premier créneau après la fenêtre")
St.ack(st, T + 140, why)
check(st.wake == nil, "servi une fois")
-- réveil posé juste au départ de la fenêtre périodique : servi par elle (cause « periode »)
St.wake(st, T + cfg.period, "ressource")
d, why = St.due(st, T + cfg.period, cfg, 0)
check(d and why == "periode", "réveil au départ de la fenêtre périodique : c'est la passe périodique qui le sert")
St.ack(st, T + cfg.period, why)
check(st.wake == nil, "le réveil est consommé par la passe périodique")
-- déterminisme : mêmes entrées, mêmes réponses
local s1, s2 = { wake = { tick = 5, why = "stock", n = 1 } }, { wake = { tick = 5, why = "stock", n = 1 } }
local a1, b1 = St.due(s1, T + 60, cfg, 0)
local a2, b2 = St.due(s2, T + 60, cfg, 0)
check(a1 == a2 and b1 == b2 and a1 == true, "due : même réponse pour le même état")

-- voies : pour n équipes, jamais deux rangs sur le même créneau ; la fenêtre périodique est dans la voie de son rang
local lanes_ok, lane_has_window = true, true
for _, n in ipairs({ 1, 2, 3, 4, 7 }) do
  local function lane(tick, rank, c) return St.lane(tick, rank, n, c) end
  local rl = scan_windows(lane, cfg, n)
  if rl.double > 0 then lanes_ok = false end
  for r = 0, n - 1 do
    if rl.actifs[r] ~= (cfg.period / stride / n) * cfg.slices and n ~= 7 then lanes_ok = false end
  end
  for tick = 0, n * stride * 2 do
    for r = 0, n - 1 do
      local on = St.window(tick, r, cfg)
      local ln = St.lane(tick, r, n, cfg)
      if on and not ln then lane_has_window = false end
    end
  end
end
check(lanes_ok, "voies : jamais deux rangs actifs au même tick (n = 1, 2, 3, 4, 7) ; parts égales des créneaux")
check(lane_has_window, "la fenêtre périodique d'un rang est dans sa voie")
-- prochain créneau de réveil : ≥ tick, dans la voie, tranche 0, aucun créneau de la voie sauté, à moins de n × stride
local ws_ok, ws_bound = true, true
for _, n in ipairs({ 1, 2, 3, 4, 7 }) do
  for r = 0, n - 1 do
    for tick = T - 3, T + 3 * n * stride, 7 do
      local t = St.wake_start(tick, r, n, cfg)
      local on, s = St.lane(t, r, n, cfg)
      if not (t >= tick and on and s == 0) then ws_ok = false end
      if t - tick >= n * stride then ws_bound = false end
      for t2 = tick, t - 1 do
        if t2 % stride == 0 and St.lane(t2, r, n, cfg) then ws_ok = false end
      end
    end
  end
end
check(ws_ok, "wake_start : premier créneau de la voie à partir du tick, tranche 0")
check(ws_bound, "wake_start : à moins de n × stride ticks (4 équipes : 240 ticks)")
check(St.wake_start(T + 200, 1, 3, cfg) == T + 240 and St.wake_start(T + 245, 1, 3, cfg) == T + 420, "exemples : rang 1 sur 3 : 200 → 240 (k = 4), 245 → 420 (k = 7)")

-- mutants (mêmes détecteurs)
--- Détecteur : une passe est comptée à chaque début de créneau de la voie où due dit oui ; un seul réveil posé → une seule passe attendue.
local function passes_for_one_wake(due_fn, ack_fn)
  local s = {}
  St.wake(s, T + 100, "stock")
  local n = 0
  for tick = T + 60, T + 60 + 10 * stride, stride do -- créneaux hors de la fenêtre périodique du rang 0
    local ok, w = due_fn(s, tick, cfg, 0)
    if ok then n = n + 1 ack_fn(s, tick, w) end
  end
  return n
end
check(passes_for_one_wake(St.due, St.ack) == 1, "un réveil : une passe")
local function ack_never_clears(s, tick, w) s.served, s.why = tick, w end -- mutant : le réveil n'est jamais consommé
check(passes_for_one_wake(St.due, ack_never_clears) > 1, "mutant « réveil jamais servi » refusé (passes répétées)")
--- Détecteur : départs de passe pendant une fenêtre en cours (un appelant qui interroge due à chaque tick).
local function double_passes(due_fn)
  local s, n = {}, 0
  St.wake(s, T + 100, "stock")
  for tick = T + 100, T + 100 + 2 * stride do
    local ok, w = due_fn(s, tick, cfg, 0)
    if ok then
      if s.served and tick < s.served + cfg.slices then n = n + 1 end
      St.ack(s, tick, w)
      St.wake(s, tick + 1, "energie") -- un réveil tombe aussitôt après chaque départ
    end
  end
  return n
end
check(double_passes(St.due) == 0, "jamais de départ pendant une fenêtre en cours")
local function due_noguard(s, t0, c, rank)
  if (t0 - rank * St.stride(c)) % c.period == 0 then return true, "periode" end
  if s.wake then return true, s.wake.why end
  return false, "rien"
end
check(double_passes(due_noguard) > 0, "mutant « sans garde de fenêtre en cours » refusé (double passe)")
local function lane_free_for_all(tick, rank, c) -- mutant : tout créneau libre appartient à toutes les équipes
  local k, s = St.rank_at(tick, c)
  if k == nil then return false, nil end
  if k < 3 then return k == rank, s end
  return true, s
end
check(scan_windows(lane_free_for_all, cfg, 3).double > 0, "mutant « créneau libre pour toutes » refusé (doubles)")
local function wake_start_next_aligned(tick) return tick + (stride - tick % stride) % stride end -- mutant : sans la voie
local bad = 0
for tick = T, T + 6 * stride do
  local t = wake_start_next_aligned(tick)
  if not St.lane(t, 1, 3, cfg) then bad = bad + 1 end
end
check(bad > 0, "mutant « prochain créneau sans la voie » refusé (créneau d'une autre équipe)")

---------------------------------------------------------------------------------------------------
section("§7 moteur : réveils servis par on_tick (voies), journal [FO-SCAN], jamais deux équipes au même tick")
---------------------------------------------------------------------------------------------------
factions = {}
fa, fb, fp = team(2, "f1"), team(5, "f3"), team("player", "player")
factions[5], factions[2], factions.player = fb, fa, fp
local active = {} -- [tick] = { clé } des équipes qui ont joué une tranche
local real_step = Hy.step
Hy.step = function(f, s, tick, slice)
  active[tick] = active[tick] or {}
  active[tick][#active[tick] + 1] = tostring(f.key)
  return real_step(f, s, tick, slice)
end
local function starts_of(key, from, to)
  local out = {}
  for tick = from, to do
    local a = active[tick]
    if a and a[1] == key and not (active[tick - 1] and active[tick - 1][1] == key) then out[#out + 1] = tick - from end
  end
  return out
end
logs = {}
local events = {} -- [tick] = fonction jouée AVANT on_tick de ce tick
events[T + 200] = function() research_fn({ research = { force = { valid = true, name = "f3" } }, tick = T + 200 }) end
events[T + 245] = function() Sr.wake(fb, T + 245, "energie") end                       -- pendant la fenêtre de réveil [240, 260)
events[T + 1000] = function() Sr.wake(fb, T + 1000, "stock") end
events[T + 1010] = function() Sr.wake(fb, T + 1010, "ressource") end                    -- double réveil
events[T + 2000] = function() Sr.wake(fa, T + 2000, "recherche"); Sr.wake(fp, T + 2000, "stock") end -- deux équipes en même temps
for tick = T, T + cfg.period - 1 do
  if events[tick] then events[tick]() end
  tick_fn({ tick = tick })
end
local fb_starts = starts_of("5", T, T + cfg.period - 1)
check(#fb_starts == 4 and fb_starts[1] == 60 and fb_starts[2] == 240 and fb_starts[3] == 420 and fb_starts[4] == 1140,
  "équipe 5 : passes à T + 60 (periode), 240 (recherche, k = 4), 420 (energie, posée pendant la fenêtre : après elle, k = 7), 1140 (double réveil : une passe, k = 19) : "
  .. table.concat(fb_starts, ","))
local fa_starts, fp_starts = starts_of("2", T, T + cfg.period - 1), starts_of("player", T, T + cfg.period - 1)
check(#fa_starts == 2 and fa_starts[2] == 2160 and #fp_starts == 2 and fp_starts[2] == 2100,
  "deux réveils au même tick : votre équipe à T + 2100 (k = 35 ≡ 2), équipe 2 à T + 2160 (k = 36 ≡ 0) : " .. table.concat(fa_starts, ",") .. " / " .. table.concat(fp_starts, ","))
local twice = 0
for tick = T, T + cfg.period - 1 do if active[tick] and #active[tick] > 1 then twice = twice + 1 end end
check(twice == 0, "jamais deux équipes au même tick, réveils compris")
local scan_lines = {}
for _, l in ipairs(logs) do if l:find("^%[FO%-SCAN%]") then scan_lines[#scan_lines + 1] = l end end
check(#scan_lines == 5 and scan_lines[1] == string.format("[FO-SCAN] 5 : reveil (recherche) a %.1f min", (T + 240) / 3600),
  "5 lignes [FO-SCAN] ; la première : " .. tostring(scan_lines[1]))
check(scan_lines[2] and scan_lines[2]:find("reveil (energie)", 1, true) and scan_lines[3]:find("reveil (stock)", 1, true)
  and scan_lines[4]:find("^%[FO%-SCAN%] player : reveil %(stock%)") and scan_lines[5]:find("^%[FO%-SCAN%] 2 : reveil %(recherche%)"), "causes et équipes dans l'ordre des créneaux")
local hy_reveil = 0
for _, l in ipairs(logs) do if l:find("^%[FO%-HYGIENE%]") and l:find("reveil (", 1, true) then hy_reveil = hy_reveil + 1 end end
check(hy_reveil == 5, "la ligne [FO-HYGIENE] d'une passe de réveil redit sa cause (" .. hy_reveil .. ")")
check(fb.team.scan.wake == nil and fb.team.scan.reveils == 3 and fb.team.scan.served == T + 1140, "état f.team.scan de l'équipe 5 : rien en attente, 3 réveils, dernier départ T + 1140")
-- QG perdu : le réveil attend ; QG revenu : servi au premier créneau de la voie
fa.hq.valid = false
Sr.wake(fa, T + cfg.period + 5, "recherche")
for tick = T + cfg.period, T + cfg.period + 600 do tick_fn({ tick = tick }) end
check(fa.team.scan.wake ~= nil, "QG perdu : le réveil reste posé")
fa.hq.valid = true
active = {}
for tick = T + cfg.period + 601, T + cfg.period + 900 do tick_fn({ tick = tick }) end
local back = starts_of("2", T + cfg.period + 601, T + cfg.period + 900)
check(fa.team.scan.wake == nil and back[1] == 720 - 601 and #back == 1, "QG revenu : servi au créneau T + 720 (k = 12 ≡ 0 ; k = 11 est la voie du rang 2) : " .. tostring(back[1]))
check(pure(fa.team.scan) and pure(fb.team.scan), "état f.team.scan en données pures")
Hy.step = real_step

print(string.format("scan_tranches_test : %d OK, %d ECHEC", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
