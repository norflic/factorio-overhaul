--[[
  Lot RAPATRIEMENT (8/11) : le VRAI code de script/team/rapatriement.lua (relevé Rap.step, plan Rap.plan, suivi), exécuté hors jeu avec des
  bouchons du moteur (surface, coffres, poteaux) et le VRAI A* de shared/team/plan.lua (P.belt_route) sur une sortie à 150 tuiles du QG.
  Critères (écrits avant le code du test) :
    G1. réglage éteint ou absent : aucun état, aucune demande ;
    G2. réglage allumé : après Rp.CONFIRM relevés, UNE ligne demandée pour la sortie lointaine rentable (spec.rapatriement : objet, bras
        le plus rapide connu, tapis choisi, point du tampon, sortie), aucune pour la sortie proche ni la sortie sans objet ;
    G3. plan : tracé continu de la sortie au tampon, tuiles réservées (b.occ), coffre tampon posé sur la tuile d'arrivée, sortie p.outs du tampon
        au seuil Rp.TAMPON_AT, garde p.keep_stock, preuve géométrique juste, aucune tuile prise par un autre projet ;
    G4. plan refusé avec sa cause : coffre de sortie disparu, aucun poteau près de la sortie, aucun chemin (mur de tuiles bloquées) ;
    G5. suivi : ligne finie -> journal « ligne finie », barre du tampon posée, objets arrivés comptés ; projet refusé -> « ligne refusee » ;
        projet rouvert -> « ligne coupee » ;
    G6. un tampon fini est réutilisé par la ligne suivante du même objet (aucun coffre neuf) ;
    G7. déterminisme : deux passes identiques donnent les mêmes demandes et le même tracé.
  Usage, depuis la racine du mod :   lua5.2 tests/rapatriement_glue_test.lua
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(c, msg) if c then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end end

local logs = {}
log = function(m) logs[#logs + 1] = m end
local function logs_with(pat)
  local n = 0
  for _, m in ipairs(logs) do if m:find(pat, 1, true) then n = n + 1 end end
  return n
end
defines = { inventory = { chest = 1 } }
local remote_fn = {}
remote = { add_interface = function(name, t) remote_fn[name] = t end }
game = { tick = 0, item_prototypes = { A = { stack_size = 100 }, B = { stack_size = 50 } }, entity_prototypes = {}, get_filtered_entity_prototypes = function() return {} end, forces = {} } -- (lot BUS-LONG : aucun souterrain debloque, trace 4 voisins)
local SETTING_ON = false
settings = { global = setmetatable({}, { __index = function(_, k)
  if k == "fo-war-rapatriement" then return { value = SETTING_ON } end
  return nil
end }) }

-- Bouchons des modules de jeu requis par le runtime (le vrai code de rapatriement.lua, pas ceux-là, est sous test)
package.loaded["script.faction.state"] = { sorted_keys = function() return {} end, faction = function() return nil end, alive = function() return {} end }
package.loaded["script.companion.registry"] = { get = function() return nil end }
local SKIP = nil -- predicat « le stock du QG refuse cet objet » (Stock.skip_fn), nil : stock non plein
package.loaded["script.team.stock"] = { skip_fn = function() return SKIP end }
package.loaded["script.ai3.reserve"] = { on = function() return true end }
package.loaded["script.team.convoyeurs"] = { choose = function() return "transport-belt" end }

local P = require("shared.team.plan")
local Li = require("shared.team.liaison")
local Rp = require("shared.team.rapatriement")
local T = require("shared.team.config")
local Rap = require("script.team.rapatriement")
local CHEST = T.outposts.coal.sink

--- Rap.plan rend « tranche » tant que la recherche du tracé continue : on l'appelle jusqu'à la fin. Rend ok, raison, nombre d'appels.
local function plan_full(api, f, surface, p)
  for i = 1, 3000 do
    local ok, why, wait = Rap.plan(api, f, surface, p)
    if wait ~= "tranche" then return ok, why, i end
  end
  return false, "boucle sans fin", 3000
end
-- Monde de bouchons ---------------------------------------------------------------------------------
local function new_world()
  local W = { chests = {}, poles = {}, blocked = {} }
  function W.chest(x, y, item, n)
    local c = { valid = true, force = { name = "player" }, position = { x = x + 0.5, y = y + 0.5 }, item = item, n = n or 0, bar = 33, took = 0 }
    local inv = {}
    function inv.get_contents() if c.n > 0 and c.item then return { [c.item] = c.n } end return {} end
    function inv.supports_bar() return true end
    function inv.get_bar() return c.bar end
    function inv.set_bar(v) c.bar = v end
    c.get_inventory = function() return inv end
    c.get_item_count = function(it) if it == nil or it == c.item then return c.n end return 0 end
    W.chests[math.floor(x) .. ":" .. math.floor(y)] = c
    return c
  end
  function W.pole(x, y) W.poles[#W.poles + 1] = { position = { x = x + 0.5, y = y + 0.5 } } end
  local surface = {}
  function surface.find_entities_filtered(a)
    if a.type == "container" and a.position then
      local c = W.chests[math.floor(a.position[1] or a.position.x) .. ":" .. math.floor(a.position[2] or a.position.y)]
      return c and { c } or {}
    elseif a.type == "electric-pole" and a.position then
      local px, py, r = a.position[1] or a.position.x, a.position[2] or a.position.y, a.radius
      local out = {}
      for _, p in ipairs(W.poles) do
        if (p.position.x - px) ^ 2 + (p.position.y - py) ^ 2 <= r * r then out[#out + 1] = p end
      end
      return out
    end
    return {}
  end
  surface.index = 1
  function surface.is_chunk_generated() return true end
  function surface.find_nearest_enemy() return nil end
  function surface.count_entities_filtered() return 0 end
  W.surface = surface
  return W
end

local function new_team(W)
  local f = { key = "player", force = "player", hq_pos = { x = 0, y = 0 }, hq = { valid = true }, engineers = {}, stats = {} }
  local b = { order = {}, projects = {}, occ = {}, lat = P.lattice({ x = 0, y = 0 }), plant = 9, stats = {}, next_id = 10, opts = {} }
  f.build = b
  local function add(p) b.projects[p.id] = p; b.order[#b.order + 1] = p.id; return p end
  add({ id = 9, state = "fini", spec = { gen = "steam" }, parts = { { kind = "centrale" } }, ents = {}, quais = {}, outs = {}, obstacles = {} })
  local ents = { { name = "fast-inserter", x = 150.5, y = 21.5, role = "sortie-bras" }, { name = "small-electric-pole", x = 151.5, y = 22.5 } }
  add({ id = 1, state = "fini", spec = { site = "champ" }, parts = { { kind = "module" } }, ents = ents, quais = {}, outs = { { x = 150.5, y = 20.5, at = 200 } }, obstacles = {} })
  -- Lot TESTS-VERTS : depuis BUS-SORTIE (d40e2bcc), un quai à Rp.REUSE_R du point voulu EST l'arrivée (aucun tampon posé ; couvert par
  -- rapatriement_test 6.18 à 6.22). Les deux quais sont écartés pour que le point voulu (médianes : 20, 12, celui de la scène d'avant) soit à 11 tuiles de chacun :
  -- ce banc garde la chaîne du tampon ordinaire (coffre, sortie, barre, réutilisation).
  add({ id = 2, state = "fini", spec = { gen = "banc" }, parts = { { kind = "module" } }, ents = {}, quais = { { x = 20.5, y = 23.5, item = "A" } }, outs = {},
    obstacles = {}, inflow = { A = 1.0 } })
  add({ id = 3, state = "fini", spec = { gen = "banc" }, parts = { { kind = "module" } }, ents = {}, quais = { { x = 31.5, y = 12.5, item = "A" } }, outs = {},
    obstacles = {}, inflow = { A = 1.0 } })
  -- une sortie PROCHE (30 tuiles du QG) et une sortie sans objet lointaine
  add({ id = 4, state = "fini", spec = { gen = "banc" }, parts = { { kind = "module" } }, ents = {}, quais = {}, outs = { { x = 40.5, y = -10.5 } }, obstacles = {} })
  add({ id = 5, state = "fini", spec = { site = "champ" }, parts = { { kind = "module" } }, ents = ents, quais = {}, outs = { { x = -150.5, y = 40.5 } }, obstacles = {} })
  W.chest(150, 20, "A", 0)
  W.chest(20, 23, "A", 0)
  W.chest(31, 12, "A", 0)
  W.chest(40, -11, "A", 800)
  W.chest(-151, 40, nil, 0)
  W.pole(152, 22)
  W.pole(152, 28)
  for x = 4, 44, 4 do for y = 0, 28, 4 do W.pole(x, y) end end -- poteaux du réseau autour des quais
  return f, b
end

local function api_for(b)
  return {
    request = function(f, spec)
      local id = b.next_id
      b.next_id = id + 1
      local p = { id = id, spec = spec, state = "attente", parts = {}, ents = {}, wires = {}, stock = {}, quais = {}, outs = {}, obstacles = {}, fails = 0 }
      b.projects[id] = p
      b.order[#b.order + 1] = id
      return id
    end,
    prio = 56,
  }
end

local function plan_api(f, b, extra)
  local api = {
    read_masks = function(x0, y0, x1, y1)
      local blocked = {}
      for k in next, (extra and extra.blocked or {}) do blocked[k] = true end
      return { water = {}, blocked = blocked, clear = {}, res = {} } -- (res : tuiles de ressource, comme le vrai read_masks, lot TAMPON-MINERAI)
    end,
    reserve_tiles = function(bb, p, list)
      for _, e in ipairs(list) do
        for _, t in ipairs(P.tiles_of(e)) do
          local k = P.tkey(t[1], t[2])
          if bb.occ[k] and bb.occ[k] ~= p.id then return false end
        end
      end
      for _, e in ipairs(list) do
        for _, t in ipairs(P.tiles_of(e)) do bb.occ[P.tkey(t[1], t[2])] = p.id end
        p.ents[#p.ents + 1] = e
      end
      return true
    end,
    wood_of = function() return {} end,
    free_spot = function(bb, masks, x, y) return x, y end,
    add_obstacle = function(p, o) p.obstacles[#p.obstacles + 1] = o end,
    item_of = function(name) return name end,
    seg_passable = function() return function() return true end end,
    REACH = 10,
  }
  return api
end

--- Fait tourner Rap.step jusqu'à ce qu'un relevé complet ait eu lieu ; le contenu de la sortie monte de `gain` par relevé.
local function run_cycles(f, b, W, n, gain, from_tick)
  local api = api_for(b)
  local tick = from_tick or 0
  for _ = 1, n do
    tick = tick + Rp.PERIOD
    local c = W.chests["150:20"]
    if c then c.n = c.n + (gain or 0) end
    -- un relevé = le départ (tick >= st.next) puis les passes de Build.PULSE jusqu'à la fin
    for _ = 1, 40 do
      Rap.step(api, f, W.surface, tick)
      tick = tick + 5
      local st = b.rapatriement
      if st and not st.cyc and tick > (st.next or 0) - Rp.PERIOD + 20 then break end
    end
  end
  return tick
end

-- G1 : éteint ----------------------------------------------------------------------------------------
do
  local W = new_world()
  local f, b = new_team(W)
  SETTING_ON = false
  local api = api_for(b)
  for t = 0, 20000, 100 do Rap.step(api, f, W.surface, t) end
  check(b.rapatriement == nil, "G1.1 reglage eteint : aucun etat")
  local n0 = #b.order
  check(n0 == 6, "G1.2 reglage eteint : aucune demande")
end

-- G2 : allumé -----------------------------------------------------------------------------------------
local requested_specs, plan_logs
local snapshot
do
  logs = {}
  local W = new_world()
  local f, b = new_team(W)
  SETTING_ON = true
  run_cycles(f, b, W, 1, 400)
  check(b.rapatriement ~= nil, "G2.1 reglage allume : etat cree")
  check(#b.order == 6, "G2.2 un seul releve : pas de demande (un historique d'un point ne donne aucun debit)")
  run_cycles(f, b, W, 6, 400, 100000)
  local reqs = {}
  for _, pid in ipairs(b.order) do if b.projects[pid].spec.rapatriement then reqs[#reqs + 1] = b.projects[pid] end end
  check(#reqs == 1, "G2.3 UNE ligne demandee (" .. #reqs .. ")")
  local lc = reqs[1] and reqs[1].spec.rapatriement
  check(lc and lc.item == "A" and lc.src.pid == 1 and lc.src.x == 150 and lc.src.y == 20, "G2.4 la sortie lointaine du champ, objet A")
  check(lc and lc.arm == "fast-inserter" and lc.belt == "transport-belt" and lc.chest == CHEST, "G2.5 bras le plus rapide connu, tapis choisi, coffre des donnees")
  check(lc and lc.flow <= 2.31 + 1e-9 and lc.flow > 0, "G2.6 debit borne par le bras")
  check(lc and lc.point.x >= 18 and lc.point.x <= 32 and lc.point.y >= 10 and lc.point.y <= 18, "G2.7 le tampon vise la zone des deux quais")
  check(reqs[1] and reqs[1].spec.pile == "capital" and reqs[1].spec.domain == "infrastructures", "G2.8 projet d'investissement de la pile")
  check(logs_with("[FO-RAPATRIEMENT]") >= 1 and logs_with("ligne demandee") == 1, "G2.9 une ligne de journal : ligne demandee")
  check(logs_with("trajets de PNJ economises par heure") == 1, "G2.10 le compte des trajets economises est au journal")
  local st = b.rapatriement
  local n_lines = 0
  for _ in next, st.lines do n_lines = n_lines + 1 end
  check(n_lines == 1 and st.n.demandes == 1, "G2.11 l'etat tient une ligne demandee")
  -- ni la sortie proche (id 4), ni la sortie sans objet (id 5) n'ont de ligne
  check(st.lines["4:o1"] == nil and st.lines["5:o1"] == nil, "G2.12 ni la sortie proche ni la sortie sans objet")
  requested_specs = reqs
  snapshot = { f = f, b = b, W = W }
end

-- G3 : plan --------------------------------------------------------------------------------------------
local planned
do
  local f, b, W = snapshot.f, snapshot.b, snapshot.W
  local p = requested_specs[1]
  local t0 = os.clock()
  local ok, why = plan_full(plan_api(f, b), f, W.surface, p)
  local dt = os.clock() - t0
  check(ok == true, "G3.1 le plan reussit (" .. tostring(why) .. ")")
  if ok then
    local belts, arms, chests, poles = {}, 0, 0, 0
    for _, e in ipairs(p.ents) do
      if e.role == "liaison-tapis" then belts[#belts + 1] = e
      elseif e.role == "liaison-bras" then arms = arms + 1
      elseif e.role == "tampon" then chests = chests + 1
      elseif e.role == "liaison" then poles = poles + 1 end
    end
    check(#belts >= 100 and #belts <= Rp.MAX_LEN, "G3.2 un long tapis : " .. #belts .. " tuiles")
    check(arms == 2 and chests == 1 and poles == 2, "G3.3 deux bras, un coffre tampon, deux poteaux")
    check(#p.outs == 1 and p.outs[1].at == Rp.TAMPON_AT and p.keep_stock and p.keep_stock.A == Rp.KEEP_STOCK, "G3.4 le tampon est une sortie au seuil Rp.TAMPON_AT, garde de stock du QG")
    local ch
    for _, e in ipairs(p.ents) do if e.role == "tampon" then ch = e end end
    check(ch and math.abs(p.outs[1].x - ch.x) < 1e-9 and math.abs(p.outs[1].y - ch.y) < 1e-9, "G3.5 la sortie du projet est le coffre pose")
    local bad = Rp.verify(p.ents, { x = 150, y = 20 }, { x = math.floor(ch.x), y = math.floor(ch.y) }, function(e) return e.role == "liaison-tapis" end,
      function(e) return e.role == "liaison-bras" end, function(e) return e.role == "tampon" end, false)
    check(#bad == 0, "G3.6 preuve geometrique juste " .. tostring(bad[1]))
    local mine = 0
    for k, v in next, b.occ do if v == p.id then mine = mine + 1 end end
    check(mine == #p.ents, "G3.7 chaque piece a reserve sa tuile (" .. mine .. " / " .. #p.ents .. ")")
    check(logs_with("projet " .. p.id .. " planifie") == 1, "G3.8 journal du plan")
    check(p.parts[1] and p.parts[1].kind == "liaison" and p.counted == true, "G3.9 pas compte comme un module")
    check(p.rap and p.rap.item == "A", "G3.10 etat de la ligne : nombres et chaines")
    check(dt < 2, string.format("G3.11 plan sans lenteur (%.2f s de processeur hors jeu)", dt))
    local d = Li.manhattan(150, 20, math.floor(ch.x), math.floor(ch.y))
    check(#belts <= Rp.DETOUR * (d + 1) + Rp.DETOUR_SLACK, "G3.12 detour dans la limite")
    check(Rp.street_edge(b.lat, { pitch = P.PITCH, lot = P.LOT, half = P.HALF }, math.floor(ch.x), math.floor(ch.y)), "G3.13 le tampon est au bord d'une rue")
    check(#p.tapis_piquable > 50 and p.tapis_piquable[1].item == "A", "G3.14 marqueur tapis_piquable pour le lot piquage (" .. #p.tapis_piquable .. " tuiles droites)")
    planned = { p = p, tiles = #belts, ch = ch }
  end
end

-- G3b : un replan du même projet ne double pas la sortie du tampon (bug de build.lua signalé par team-lead) ----------
do
  local W = new_world()
  local f, b = new_team(W)
  local spec = { rapatriement = { key = "1:o1", item = "A", flow = 0.8, arm = "fast-inserter", pole = "small-electric-pole", belt = "transport-belt", chest = CHEST,
    src = { pid = 1, idx = 1, x = 150, y = 20 }, point = { x = 24, y = 14 } } }
  local p = { id = 30, spec = spec, state = "plan", parts = {}, ents = {}, wires = {}, stock = {}, quais = {}, outs = {}, obstacles = {}, fails = 0 }
  b.projects[30] = p
  b.order[#b.order + 1] = 30
  check(plan_full(plan_api(f, b), f, W.surface, p) == true and #p.outs == 1, "G3b.1 premier plan : une sortie")
  p.ents = {}
  check(plan_full(plan_api(f, b), f, W.surface, p) == true and #p.outs == 1, "G3b.2 second plan du meme projet : toujours une sortie (" .. #p.outs .. ")")
end

-- G4 : refus ---------------------------------------------------------------------------------------------
do
  local W = new_world()
  local f, b = new_team(W)
  local spec = { rapatriement = { key = "1:o1", item = "A", flow = 0.8, arm = "fast-inserter", pole = "small-electric-pole", belt = "transport-belt", chest = CHEST,
    src = { pid = 1, idx = 1, x = 150, y = 20 }, point = { x = 24, y = 14 } } }
  local function try(world_mut, extra)
    local W2 = new_world()
    local f2, b2 = new_team(W2)
    if world_mut then world_mut(W2, f2, b2) end
    local p = { id = 20, spec = spec, state = "plan", parts = {}, ents = {}, wires = {}, stock = {}, quais = {}, outs = {}, obstacles = {}, fails = 0 }
    b2.projects[20] = p
    b2.order[#b2.order + 1] = 20
    return plan_full(plan_api(f2, b2, extra), f2, W2.surface, p)
  end
  local ok, why = try(function(W2) W2.chests["150:20"] = nil end)
  check(ok == false and tostring(why):find("disparu", 1, true), "G4.1 coffre de sortie disparu : refus avec sa cause (" .. tostring(why) .. ")")
  ok, why = try(function(W2) W2.poles = {} end)
  check(ok == false and tostring(why):find("poteau", 1, true), "G4.2 aucun poteau du reseau : refus avec sa cause (" .. tostring(why) .. ")")
  local wall = {}
  for y = -400, 400 do for x = 60, 62 do wall[P.tkey(x, y)] = true end end
  ok, why = try(nil, { blocked = wall })
  check(ok == false and tostring(why):find("rapatriement", 1, true), "G4.3 un mur de tuiles bloquees : refus (" .. tostring(why) .. ")")
  -- un mur qui ne se contourne qu'au-dela de la marge d'origine : le second passage (boite elargie) le contourne
  local long_wall = {}
  for y = -16, 50 do for x = 60, 62 do long_wall[P.tkey(x, y)] = true end end
  ok, why = try(nil, { blocked = long_wall })
  check(ok == true, "G4.3b un mur qui se contourne au-dela de la marge d'origine : trace par la boite elargie (" .. tostring(why) .. ")")
  ok, why = try(function(W2, f2) W2.surface.is_chunk_generated = function(c) return c.x < 2 end end)
  check(ok == false, "G4.4 des chunks non generes sur le chemin : refus (" .. tostring(why) .. ")")
  ok, why = try(function(W2, f2, b2)
    for dx = -1, 1 do for dy = -1, 1 do
      if dx ~= 0 or dy ~= 0 then b2.occ[P.tkey(150 + dx, 20 + dy)] = 99 end -- le coffre de sortie est entouré
    end end
  end)
  check(ok == false and tostring(why):find("aucune place pour un bras", 1, true), "G4.7 coffre de sortie entoure : refus avec sa cause (" .. tostring(why) .. ")")
  local far_spec = { rapatriement = { key = "1:o1", item = "A", flow = 0.8, arm = "fast-inserter", pole = "small-electric-pole", belt = "transport-belt", chest = CHEST,
    src = { pid = 1, idx = 1, x = 150, y = 20 }, point = { x = 2000, y = 2000 } } }
  local W3 = new_world()
  local f3, b3 = new_team(W3)
  local p3 = { id = 21, spec = far_spec, state = "plan", parts = {}, ents = {}, wires = {}, stock = {}, quais = {}, outs = {}, obstacles = {}, fails = 0 }
  ok, why = plan_full(plan_api(f3, b3), f3, W3.surface, p3)
  check(ok == false and tostring(why):find("trop loin", 1, true), "G4.5 boite de plus de 420 tuiles : trop loin (" .. tostring(why) .. ")")
  local nospec = { rapatriement = { key = "1:o1", item = "A", flow = 0.8, arm = nil, pole = "small-electric-pole", belt = "transport-belt", chest = CHEST,
    src = { pid = 1, idx = 1, x = 150, y = 20 }, point = { x = 24, y = 14 } } }
  local p4 = { id = 22, spec = nospec, state = "plan", parts = {}, ents = {}, wires = {}, stock = {}, quais = {}, outs = {}, obstacles = {}, fails = 0 }
  ok, why = plan_full(plan_api(f3, b3), f3, W3.surface, p4)
  check(ok == false and tostring(why):find("pieces", 1, true), "G4.6 pieces inconnues : refus")
end

-- G5 : suivi ---------------------------------------------------------------------------------------------
do
  local f, b, W = snapshot.f, snapshot.b, snapshot.W
  local p = requested_specs[1]
  if planned then
    p.state = "fini"
    local c = W.chest(math.floor(planned.ch.x), math.floor(planned.ch.y), "A", 0)
    logs = {}
    local tick = run_cycles(f, b, W, 1, 0, 400000)
    check(logs_with("ligne finie") == 1, "G5.1 ligne finie au journal (" .. logs_with("ligne finie") .. ")")
    check(c.bar >= 2 and c.bar <= math.ceil(Rp.BUFFER_MAX_OBJ / 100) + 1, "G5.2 barre du tampon posee (" .. tostring(c.bar) .. ")")
    c.n = 500
    tick = run_cycles(f, b, W, 1, 0, tick)
    p.outs[1].collected = 120
    c.n = 800
    run_cycles(f, b, W, 1, 0, tick)
    local line = b.rapatriement.lines["1:o1"]
    check(line and line.arrived and line.arrived >= 500, "G5.3 objets arrives comptes (" .. tostring(line and line.arrived) .. ")")
    check((b.stats.rapatrie or 0) >= 500, "G5.4 compteur d'equipe b.stats.rapatrie")
    p.state = "reserve"
    logs = {}
    run_cycles(f, b, W, 1, 0, tick + 100000)
    check(logs_with("ligne coupee") == 1, "G5.5 projet rouvert : ligne coupee")
    p.state = "refuse"
    p.reason = "rapatriement: aucun chemin"
    logs = {}
    run_cycles(f, b, W, 1, 0, tick + 200000)
    check(logs_with("ligne refusee") == 1 and logs_with("aucun chemin") == 1, "G5.6 projet refuse : ligne refusee avec la cause")
    check(b.rapatriement.lines["1:o1"] == nil, "G5.7 la sortie est liberee")
  end
end

-- G6 : tampon réutilisé ------------------------------------------------------------------------------------
do
  local W = new_world()
  local f, b = new_team(W)
  SETTING_ON = true
  local c1 = W.chest(150, 20, "A", 0)
  -- une 2e sortie lointaine du même objet, au même champ
  b.projects[1].outs[2] = { x = 150.5, y = 28.5, at = 200 }
  W.chest(150, 28, "A", 0)
  run_cycles(f, b, W, 6, 400, 0)
  local first
  for _, pid in ipairs(b.order) do if b.projects[pid].spec.rapatriement then first = b.projects[pid] break end end
  check(first ~= nil, "G6.1 une premiere ligne demandee")
  if first then
    local ok = plan_full(plan_api(f, b), f, W.surface, first)
    check(ok == true, "G6.2 premiere ligne planifiee")
    first.state = "fini"
    local tx, ty = first.p_tampon_x, nil
    local ch
    for _, e in ipairs(first.ents) do if e.role == "tampon" then ch = e end end
    W.chest(math.floor(ch.x), math.floor(ch.y), "A", 0)
    -- la 2e sortie monte aussi
    for _ = 1, 8 do
      W.chests["150:28"].n = W.chests["150:28"].n + 400
      W.chests["150:20"].n = W.chests["150:20"].n + 400
      run_cycles(f, b, W, 1, 0, 500000 + _ * 5000)
    end
    local second
    for _, pid in ipairs(b.order) do
      local q = b.projects[pid]
      if q.spec.rapatriement and q ~= first then second = q end
    end
    check(second and second.spec.rapatriement.reuse ~= nil, "G6.3 la 2e ligne vise le tampon deja pose")
    if second then
      local ok2, why2 = plan_full(plan_api(f, b), f, W.surface, second)
      check(ok2 == true, "G6.4 2e ligne planifiee (" .. tostring(why2) .. ")")
      local nchest = 0
      for _, e in ipairs(second.ents) do if e.role == "tampon" then nchest = nchest + 1 end end
      check(nchest == 0 and #second.outs == 0, "G6.5 aucun coffre neuf, aucune sortie de plus")
      second.state = "fini"
      logs = {}
      run_cycles(f, b, W, 1, 0, 900000)
      local c = W.chests[math.floor(ch.x) .. ":" .. math.floor(ch.y)]
      local flows = {}
      for _, k in ipairs({ "1:o1", "1:o2" }) do if b.rapatriement.lines[k] then flows[#flows + 1] = b.rapatriement.lines[k].flow end end
      check(#flows == 2 and c.bar == Rp.bar_total(flows, 100), "G6.6 barre du tampon = debits cumules des deux lignes (" .. tostring(c.bar) .. ")")
    end
  end
end

-- G7 : déterminisme ----------------------------------------------------------------------------------------
do
  local function once()
    logs = {}
    local W = new_world()
    local f, b = new_team(W)
    SETTING_ON = true
    run_cycles(f, b, W, 7, 400, 0)
    local out = {}
    for _, pid in ipairs(b.order) do
      local p = b.projects[pid]
      if p.spec.rapatriement then
        local ok = plan_full(plan_api(f, b), f, W.surface, p)
        local sig = {}
        for _, e in ipairs(p.ents) do sig[#sig + 1] = e.role .. ":" .. e.x .. ":" .. e.y .. ":" .. (e.dir or 0) end
        out[#out + 1] = tostring(ok) .. "|" .. table.concat(sig, ",")
      end
    end
    return table.concat(out, ";"), table.concat(logs, "\n")
  end
  local a1, l1 = once()
  local a2, l2 = once()
  check(a1 ~= "" and a1 == a2, "G7.1 deux parties identiques : meme ligne, tuile pour tuile")
  check(l1 == l2, "G7.2 deux parties identiques : meme journal")
end

-- G4b : un tampon enfermé dans une poche est refusé tout de suite, avec sa cause --------------------------------------------
do
  local W = new_world()
  local f, b = new_team(W)
  local ring = {}
  for x = 17, 31 do for y = 7, 21 do if x == 17 or x == 31 or y == 7 or y == 21 then ring[P.tkey(x, y)] = true end end end
  W.poles = {}
  W.pole(152, 22) -- le départ est alimenté
  W.pole(22, 12)  -- seul poteau près du tampon : dans l'anneau
  local spec = { rapatriement = { key = "1:o1", item = "A", flow = 0.8, arm = "fast-inserter", pole = "small-electric-pole", belt = "transport-belt", chest = CHEST,
    src = { pid = 1, idx = 1, x = 150, y = 20 }, point = { x = 24, y = 14 } } }
  local p = { id = 40, spec = spec, state = "plan", parts = {}, ents = {}, wires = {}, stock = {}, quais = {}, outs = {}, obstacles = {}, fails = 0 }
  b.projects[40] = p
  b.order[#b.order + 1] = 40
  local ok, why, calls = plan_full(plan_api(f, b, { blocked = ring }), f, W.surface, p)
  check(ok == false and tostring(why):find("enfermee", 1, true), "G4b.1 tampon dans une poche fermee : refus avec la cause (" .. tostring(why) .. ")")
  local n = tonumber(tostring(why):match("%((%d+) noeuds"))
  check(n and n < 3000, "G4b.2 refus rapide : moins de 3 000 noeuds au lieu de la boite entiere (" .. tostring(n) .. ")")
end

-- G7b : un objet saturé au QG sans quai preneur n'est pas rapatrié, avec la cause écrite ----------------------------
do
  logs = {}
  local W = new_world()
  local f, b = new_team(W)
  SETTING_ON = true
  b.projects[2].quais, b.projects[3].quais = {}, {} -- aucun quai ne consomme l'objet
  SKIP = function(item) return item == "A" end
  run_cycles(f, b, W, 8, 400, 0)
  SKIP = nil
  local reqs = 0
  for _, pid in ipairs(b.order) do if b.projects[pid].spec.rapatriement then reqs = reqs + 1 end end
  check(reqs == 0, "G7b.1 objet sature, aucun quai : aucune ligne (" .. reqs .. ")")
  check(logs_with("objet sature au QG") == 1, "G7b.2 la cause est ecrite une fois (" .. logs_with("objet sature au QG") .. ")")
end

-- G8 : une sortie qui ne se paie pas est écrite une fois, pas à chaque relevé ------------------------------------
do
  logs = {}
  local W = new_world()
  local f, b = new_team(W)
  SETTING_ON = true
  b.projects[1].outs = { { x = 80.5, y = 0.5, at = 200 } } -- 80 tuiles du QG, 0,1 objet/s
  W.chests["150:20"] = nil
  W.chest(80, 0, "A", 0)
  W.pole(82, 2)
  local api = api_for(b)
  local tick = 0
  for _ = 1, 24 do
    tick = tick + Rp.PERIOD
    W.chests["80:0"].n = W.chests["80:0"].n + 3
    for _ = 1, 40 do Rap.step(api, f, W.surface, tick); tick = tick + 5 end
  end
  local reqs = 0
  for _, pid in ipairs(b.order) do if b.projects[pid].spec.rapatriement then reqs = reqs + 1 end end
  check(reqs == 0, "G8.1 petite sortie proche : aucune ligne (" .. reqs .. ")")
  check(logs_with("ne se paie pas") == 1, "G8.2 refus ecrit UNE fois en 24 releves (" .. logs_with("ne se paie pas") .. ")")
end

print(string.format("[RAPATRIEMENT-GLUE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
