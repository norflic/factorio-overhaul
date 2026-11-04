--[[
  Lot EXPERIMENTAUX (3/11), palier 3 : les 5 GÉANTS en jeu. Règles pures : shared/robots/experimentaux.lua (Xp.GEANTS, Xp.giant_cap,
  Xp.marks, Xp.circuit, Xp.fissure, Xp.foyer_fires) ; prototypes : prototypes/experimentaux_geants.lua.

  - Posé (objet, robot, script) : inscrit ; refusé au-delà du plafond des géants (Xp.giant_ok, géants de shared/content/robots.lua COMPRIS,
    lus par script/robots/armee.lua sans y écrire) : l'entité est retirée, l'objet rendu au joueur (sinon au sol).
  - Le joueur qui le pose reçoit la télécommande vanilla liée (comme le Bourdon).
  - Corps : si Xp.GIANT_BODY == "rendering", sprites `rendering` attachés à l'entité (principale, lueur, ombre), sinon le prototype.
  - Toutes les 30 ticks : chaque géant prêt cherche l'ennemi le plus proche à portée (find_nearest_enemy) et lance son effet ; les effets
    qui s'étirent dans le temps (Cairn, Stylet, Trombe, Ixion) passent par la file `gjobs`, traitée à chaque tick tant qu'elle n'est pas vide.
  Dégâts : script/robots/experimentaux_commun.lua (jamais sur sa force, ses amis, en cessez-le-feu).
]]

local Events = require("script.core.events")
local Xp = require("shared.robots.experimentaux")
local K = require("script.robots.experimentaux_commun")
local Armee = require("script.robots.armee")

local G = {}

local GEANT = {}
for _, r in ipairs(Xp.GEANTS) do GEANT[r.name] = r end

local SCAN = 30
local CAIRN_ARC = Xp.PREFIX .. "cairn-arc"
local FOYER = Xp.PREFIX .. "tournesol-foyer"
local PILIER = Xp.PREFIX .. "stylet-pilier"
local SPR_GLACE, SPR_VERRE = Xp.PREFIX .. "glace", Xp.PREFIX .. "verre"
local BOUCHE = { cairn = { 0, -30 }, stylet = { 0, -2 }, trombe = { 0, -26 }, ixion = { 0, -8 }, tournesol = { -8.5, -31 } }

---------------------------------------------------------------------------------------------------
-- Registre et plafond
---------------------------------------------------------------------------------------------------
--- Géants de cette famille, vivants, pour une force (sans compter `sauf`).
local function mine(force_name, sauf)
  local n = 0
  for _, g in ipairs(K.S().giants) do
    if g.e.valid and g.e.force.name == force_name and g.un ~= sauf then n = n + 1 end
  end
  return n
end

--- Géants de cette famille pour une force : son NOM (chaîne, ce qu'envoie script/robots/armee.lua de robotsjeu) ; un LuaForce est aussi lu.
local appels = 0 -- appels de G.count pendant UN calcul (jamais gardé d'un tick à l'autre : rien en storage)
function G.count(force)
  appels = appels + 1
  local name = type(force) == "string" and force or (force and force.valid and force.name)
  if not name then return 0 end
  return mine(name, nil)
end

local function corps(g, r)
  if Xp.GIANT_BODY ~= "rendering" then return end
  local e = g.e
  local s = e.surface
  rendering.draw_sprite({ sprite = Xp.PREFIX .. r.id .. "-ombre", target = e, surface = s, render_layer = "lower-object" })
  rendering.draw_sprite({ sprite = Xp.PREFIX .. r.id .. "-corps", target = e, surface = s, render_layer = "air-object" })
  rendering.draw_sprite({ sprite = Xp.PREFIX .. r.id .. "-lueur-1", target = e, surface = s, render_layer = "air-object" })
end

local function rendre(player, e, name)
  if player and player.valid and player.insert({ name = name, count = 1 }) == 1 then return end
  e.surface.spill_item_stack(e.position, { name = name, count = 1 }, true)
end

local function on_built(ev)
  local e = ev.created_entity or ev.entity
  if not (e and e.valid) then return end
  local r = GEANT[e.name]
  if not r then return end
  local force = e.force
  local age = Armee.age(force)
  -- Armee.giants (robotsjeu) compte déjà les miens s'il appelle l'interface « fo-xp » (integ-0647, armee.lua) : sinon, on les ajoute ici.
  -- Le nouveau venu n'est pas encore inscrit : il n'est compté ni par l'un ni par l'autre.
  local avant = appels
  local have = Armee.giants(force.name)
  if appels == avant then have = have + mine(force.name, e.unit_number) end
  local player = ev.player_index and game.get_player(ev.player_index)
  if not Xp.giant_ok(age, have) then
    K.journal("%s refuse : plafond des geants (%d deja, age %d, plafond %d)", r.id, have, age, Xp.giant_cap(age))
    local name = e.name
    rendre(player, e, name)
    if player then player.print({ "fo-xp.plafond", { "entity-name." .. name }, Xp.giant_cap(age), age }) end
    e.destroy()
    return
  end
  local s = K.S()
  local g = { un = e.unit_number, e = e, id = r.id, next = ev.tick or game.tick, n = 0 }
  s.giants[#s.giants + 1] = g
  corps(g, r)
  if player and game.item_prototypes["spidertron-remote"] then
    local stack = player.cursor_stack
    if stack and player.clear_cursor() and stack.valid and stack.set_stack({ name = "spidertron-remote", count = 1 }) then
      stack.connected_entity = e
    end
  end
  K.journal("%s pose #%d force %s (age %d, geants %d / %d)", r.id, e.unit_number, force.name, age, have + 1, Xp.giant_cap(age))
end

---------------------------------------------------------------------------------------------------
-- Effets
---------------------------------------------------------------------------------------------------
local function pos_of(e) return { x = e.position.x, y = e.position.y } end
local function bouche(g)
  local b = BOUCHE[g.id]
  return { x = g.e.position.x + b[1], y = g.e.position.y + b[2] }
end

local function job(j)
  local s = K.S()
  s.gjobs[#s.gjobs + 1] = j
end

--- Cairn : marque, puis tire (après `delay`) un arc sur chaque marque ; le coup est partagé.
local function balayage(g, r, target, tick)
  local e = g.e
  local marks = Xp.marks(pos_of(e), K.candidates(e.surface, e.force, e.position, r.range), r.marks, r.range)
  if #marks == 0 then return false end
  local list = {}
  for _, m in ipairs(marks) do
    rendering.draw_circle({ color = { r = 0.3, g = 0.7, b = 1.0, a = 0.8 }, radius = 1.6, width = 3, filled = false, target = m.e, surface = e.surface,
      time_to_live = r.delay + 20 })
    list[#list + 1] = m.e
  end
  rendering.draw_circle({ color = { r = 0.15, g = 0.4, b = 0.8, a = 0.25 }, radius = r.range, width = 4, filled = false, target = e, surface = e.surface,
    time_to_live = r.delay })
  job({ kind = "cairn", e = e, un = g.un, list = list, at = tick + r.delay })
  return true
end

local function cairn_tire(j)
  local e = j.e
  if not (e and e.valid) then return end
  local r = Xp.robot("cairn")
  local alive = {}
  for _, t in ipairs(j.list) do if t.valid then alive[#alive + 1] = t end end
  local part = Xp.split(r.shot, #alive)
  local total = 0
  local b = BOUCHE.cairn
  for _, t in ipairs(alive) do
    e.surface.create_entity({ name = CAIRN_ARC, position = e.position, source = e, source_offset = { b[1], b[2] }, target = t, duration = 20 })
    total = total + K.hit(r, t, part, r.dtype, e.force, e)
  end
  K.journal("cairn balayage #%d degats %.1f cibles %d tick %d", j.un, total, #alive, game.tick)
end

--- Stylet : le circuit à angles droits court de la pointe aux nœuds ; chaque nœud tire un pilier.
local function ecriture(g, r, target, tick)
  local e = g.e
  local cands = K.candidates(e.surface, e.force, target.position, 40)
  local first = { x = target.position.x, y = target.position.y, id = target.unit_number or 0, e = target }
  local nodes, pts = Xp.circuit(pos_of(e), first, cands, r.nodes, 12)
  job({ kind = "stylet", e = e, un = g.un, nodes = nodes, pts = pts, k = 1, at = tick + 1, part = Xp.split(r.shot, #nodes), total = 0 })
  return true
end

local function stylet_pas(j, tick)
  local e = j.e
  local r = Xp.robot("stylet")
  if not (e and e.valid) then return true end
  local a, b = j.pts[j.k], j.pts[j.k + 1]
  if not b then
    K.journal("stylet ecriture #%d degats %.1f noeuds %d tick %d", j.un, j.total, #j.nodes, tick)
    return true
  end
  rendering.draw_line({ color = { r = 0.6, g = 0.85, b = 1.0, a = 0.9 }, width = 5, from = { a.x, a.y }, to = { b.x, b.y }, surface = e.surface,
    time_to_live = 150, draw_on_ground = true })
  rendering.draw_line({ color = { r = 1, g = 1, b = 1, a = 1 }, width = 2, from = { a.x, a.y }, to = { b.x, b.y }, surface = e.surface,
    time_to_live = 60, draw_on_ground = true })
  for _, nd in ipairs(j.nodes) do
    if math.abs(nd.x - b.x) < 1e-6 and math.abs(nd.y - b.y) < 1e-6 then
      e.surface.create_entity({ name = PILIER, position = { b.x, b.y } })
      j.total = j.total + K.blast(r, e.surface, e.force, e, b, r.node_radius, j.part, r.dtype, 1)
    end
  end
  j.k = j.k + 1
  j.at = tick + r.step_ticks
  return false
end

--- Trombe : le sol blanchit, les ennemis s'arrêtent ; au dégel, les pics de glace les font éclater.
local function gel(g, r, target, tick)
  local e = g.e
  local c = pos_of(target)
  local frozen = {}
  for _, it in ipairs(Xp.in_radius(c, K.candidates(e.surface, e.force, c, r.radius + 2), r.radius)) do
    local t = it.c.e
    if t.valid and t.active then
      t.active = false
      frozen[#frozen + 1] = t
    end
  end
  rendering.draw_circle({ color = { r = 0.85, g = 0.95, b = 1.0, a = 0.3 }, radius = r.radius, filled = true, target = { c.x, c.y }, surface = e.surface,
    time_to_live = r.freeze + 40, draw_on_ground = true })
  rendering.draw_circle({ color = { r = 0.6, g = 0.9, b = 1.0, a = 0.7 }, radius = r.radius, width = 6, filled = false, target = { c.x, c.y },
    surface = e.surface, time_to_live = r.freeze + 40, draw_on_ground = true })
  job({ kind = "trombe", e = e, un = g.un, c = c, frozen = frozen, at = tick + r.freeze })
  K.journal("trombe gel #%d geles %d tick %d", g.un, #frozen, tick)
  return true
end

local function trombe_degel(j)
  local r = Xp.robot("trombe")
  local surface, force = nil, nil
  if j.e and j.e.valid then surface, force = j.e.surface, j.e.force end
  for _, t in ipairs(j.frozen) do
    if t.valid then t.active = true end
  end
  if not surface then return end
  local total, n = 0, 0
  local part = Xp.split(r.shot, #j.frozen)
  for _, t in ipairs(j.frozen) do
    if t.valid then
      rendering.draw_sprite({ sprite = SPR_GLACE, target = t.position, surface = surface, time_to_live = 90, render_layer = "object" })
      local d = K.hit(r, t, part, r.dtype, force, j.e)
      if d > 0 then total, n = total + d, n + 1 end
    end
  end
  K.journal("trombe degel #%d degats %.1f cibles %d tick %d", j.un, total, n, game.tick)
end

--- Ixion : la fissure court vers la cible et au-delà ; geysers le long ; le coup est partagé entre les points.
local function tranchee(g, r, target, tick)
  local e = g.e
  local pts = Xp.fissure(pos_of(e), pos_of(target), r.step, r.beyond)
  if #pts == 0 then return false end
  job({ kind = "ixion", e = e, un = g.un, pts = pts, k = 1, at = tick + 1, part = Xp.split(r.shot, #pts), total = 0, prev = pos_of(e) })
  return true
end

local function ixion_pas(j, tick)
  local e = j.e
  local r = Xp.robot("ixion")
  if not (e and e.valid) then return true end
  local p = j.pts[j.k]
  if not p then
    K.journal("ixion tranchee #%d degats %.1f points %d tick %d", j.un, j.total, #j.pts, tick)
    return true
  end
  rendering.draw_line({ color = { r = 0.12, g = 0.07, b = 0.05, a = 0.95 }, width = 9, from = { j.prev.x, j.prev.y }, to = { p.x, p.y },
    surface = e.surface, time_to_live = 900, draw_on_ground = true })
  rendering.draw_line({ color = { r = 1.0, g = 0.5, b = 0.12, a = 1 }, width = 3, from = { j.prev.x, j.prev.y }, to = { p.x, p.y },
    surface = e.surface, time_to_live = 240, draw_on_ground = true })
  e.surface.create_entity({ name = "big-explosion", position = { p.x, p.y } })
  j.total = j.total + K.blast(r, e.surface, e.force, e, p, r.width, j.part, r.dtype, 1)
  j.prev = p
  j.k = j.k + 1
  j.at = tick + r.step_ticks
  return false
end

--- Tournesol : de jour, le foyer rend un trait sur la cible ; verre fondu au sol.
local function foyer(g, r, target, tick)
  local e = g.e
  if not Xp.foyer_fires(e.surface.darkness, r.night) then return false end
  local b = BOUCHE.tournesol
  e.surface.create_entity({ name = FOYER, position = e.position, source = e, source_offset = { b[1], b[2] }, target = target, duration = r.cooldown })
  local d = K.hit(r, target, r.shot, r.dtype, e.force, e)
  g.n = g.n + 1
  if g.n % r.glass_every == 0 and target.valid then
    rendering.draw_sprite({ sprite = SPR_VERRE, target = target.position, surface = e.surface, time_to_live = 1200, render_layer = "decals",
      tint = { r = 1, g = 0.9, b = 0.6, a = 0.8 } })
  end
  K.journal("tournesol foyer #%d degats %.1f tick %d", g.un, d, tick)
  return true
end

local EFFECTS = { balayage = balayage, ecriture = ecriture, gel = gel, tranchee = tranchee, foyer = foyer }

local function scan(ev)
  local s = K.S()
  if not s or #s.giants == 0 then return end
  local keep = {}
  for _, g in ipairs(s.giants) do
    if g.e.valid then
      keep[#keep + 1] = g
      if ev.tick >= g.next then
        local r = Xp.robot(g.id)
        local e = g.e
        local t = e.surface.find_nearest_enemy({ position = e.position, max_distance = r.range, force = e.force })
        if t and EFFECTS[r.effect](g, r, t, ev.tick) then
          local st = K.stat(r.id)
          st.coups = st.coups + 1
          g.next = ev.tick + r.cooldown
        end
      end
    end
  end
  s.giants = keep
end

local STEP = { stylet = stylet_pas, ixion = ixion_pas }

local function on_tick(ev)
  local s = K.S()
  if not s or #s.gjobs == 0 then return end
  local keep = {}
  for _, j in ipairs(s.gjobs) do
    local done = false
    if j.at <= ev.tick then
      if j.kind == "cairn" then cairn_tire(j); done = true
      elseif j.kind == "trombe" then trombe_degel(j); done = true
      else done = STEP[j.kind](j, ev.tick) end
    end
    if not done then keep[#keep + 1] = j end
  end
  s.gjobs = keep
end

Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on(defines.events.script_raised_built, on_built)
Events.on(defines.events.script_raised_revive, on_built)
Events.on(defines.events.on_tick, on_tick)
Events.on_nth_tick(SCAN, scan)

return G
