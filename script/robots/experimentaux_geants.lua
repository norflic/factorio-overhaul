--[[
  Lot EXPERIMENTAUX (3/11), palier 3 : les 5 GÉANTS en jeu. Règles pures : shared/robots/experimentaux.lua (Xp.GEANTS, Xp.giant_cap,
  Xp.marks, Xp.circuit, Xp.fissure, Xp.foyer_fires) ; prototypes : prototypes/experimentaux_geants.lua.

  - Posé (objet, robot, script) : inscrit ; refusé au-delà du plafond des géants (Xp.giant_ok, géants de shared/content/robots.lua COMPRIS,
    lus par script/robots/armee.lua sans y écrire) : l'entité est retirée, l'objet rendu au joueur (sinon au sol).
  - Le joueur qui le pose reçoit la télécommande vanilla liée (comme le Bourdon).
  - Corps : si Xp.GIANT_BODY == "rendering", sprites `rendering` attachés à l'entité (principale, lueur, ombre), sinon le prototype.
  - Toutes les 30 ticks : chaque géant prêt cherche l'ennemi le plus proche à portée (find_nearest_enemy), sinon toute entité ennemie à
    portée (bâtiments compris : décision du DC du 5/11, « jusqu'à la fin »), et lance son effet, puis une SALVE DE ZONE (règle d'échelle,
    shared/robots/echelle.lua : coup plein par cible dans 15 × (âge − 9) tuiles, cratère, sol brûlé), au plus toutes les Ech.CADENCE_ZONE
    ticks. Effets et salves qui s'étirent dans le temps passent par la file `gjobs`, traitée à chaque tick tant qu'elle n'est pas vide ; une
    salve de zone frappe au plus Ech.TRANCHE entités par tick.
  Dégâts : script/robots/experimentaux_commun.lua (jamais sur sa force, ses amis, en cessez-le-feu).
]]

local Events = require("script.core.events")
local Xp = require("shared.robots.experimentaux")
local K = require("script.robots.experimentaux_commun")
local Armee = require("script.robots.armee")
local Ech = require("shared.robots.echelle")

local G = {}

local GEANT = {}
for _, r in ipairs(Xp.GEANTS) do GEANT[r.name] = r end

local SCAN = 30
local CAIRN_ARC = Xp.PREFIX .. "cairn-arc"
local FOYER = Xp.PREFIX .. "tournesol-foyer"
local PILIER = Xp.PREFIX .. "stylet-pilier"
local SPR_GLACE, SPR_VERRE = Xp.PREFIX .. "glace", Xp.PREFIX .. "verre"
local CRATERE = Xp.PREFIX .. "cratere-"
local CIBLES_MAX = 50 -- entités lues au plus pour trouver une cible non militaire (une recherche bornée toutes les 30 ticks par géant)
local BOUCHE = { cairn = { 0, -30 }, stylet = { 0, -2 }, trombe = { 0, -26 }, ixion = { 0, -8 }, tournesol = { -8.5, -31 } }

--- Couleur du `rendering` : le moteur la lit PRÉMULTIPLIÉE (gi1, 4/11 : { 0,85 ; 0,95 ; 1 ; a = 0,3 } donnait un disque blanc opaque).
local function rgba(r, g, b, a) return { r = r * a, g = g * a, b = b * a, a = a } end

--- Un rayon vise la POSITION de la cible : la cible tuée par le coup ne l'efface plus au tick suivant (gi1 : arcs du Cairn et foyer du
--- Tournesol invisibles, chaque coup tuant sa cible).
local function rayon(e, name, b, target, duration)
  e.surface.create_entity({ name = name, position = e.position, source = e, source_offset = { b[1], b[2] },
    target_position = { target.position.x, target.position.y }, duration = duration })
end

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

--- E3 et E4 (règle d'échelle, shared/robots/echelle.lua) : salve de ZONE au point visé `c`. Cratère et sol brûlé, puis un coup PLEIN
--- (r.salve, jamais partagé) sur chaque entité ennemie du rayon r.zone, bâtiments compris, par tranches de Ech.TRANCHE par tick, rangées
--- par anneau du centre vers le bord (l'onde se voit), au plus Ech.PLAFOND par salve. Une seule recherche d'entités par salve.
local function zone(e, un, r, c, tick)
  local s = e.surface
  s.create_entity({ name = CRATERE .. r.age, position = { c.x, c.y } })
  s.create_entity({ name = "big-scorchmark", position = { c.x, c.y } })
  local plan = Ech.plan(K.candidates(s, e.force, c, r.zone), c)
  job({ kind = "zone", e = e, un = un, id = r.id, plan = plan, k = 1, at = tick, total = 0, tues = 0, debut = tick })
end

local function zone_pas(j, tick)
  local e = j.e
  local r = Xp.robot(j.id)
  local n = #j.plan
  if not (e and e.valid) or n == 0 then return true end
  local a, b = Ech.tranche(j.k, n)
  for i = a, b do
    local t = j.plan[i].e
    if t.valid then
      j.total = j.total + K.hit(r, t, r.salve, r.dtype, e.force, e)
      if not t.valid or t.health <= 0 then j.tues = j.tues + 1 end
    end
  end
  j.k = j.k + 1
  if b >= n then
    K.journal("%s zone #%d rayon %d cibles %d tues %d degats %.0f ticks %d tick %d", r.id, j.un, r.zone, n, j.tues, j.total, tick - j.debut + 1, tick)
    return true
  end
  j.at = tick + 1
  return false
end

--- Cairn : marque les cibles, puis (après `delay`) tire un arc sur chaque marque et la salve de zone autour de la cible.
local function balayage(g, r, target, tick)
  local e = g.e
  local marks = Xp.marks(pos_of(e), K.candidates(e.surface, e.force, e.position, r.range), r.marks, r.range)
  if #marks == 0 then return false end
  local list = {}
  for _, m in ipairs(marks) do
    rendering.draw_circle({ color = rgba(0.3, 0.7, 1.0, 0.8), radius = 1.6, width = 6, filled = false, target = m.e, surface = e.surface,
      time_to_live = r.delay + 20 })
    list[#list + 1] = m.e
  end
  rendering.draw_circle({ color = rgba(0.15, 0.4, 0.8, 0.25), radius = r.zone, width = 4, filled = false, target = pos_of(target),
    surface = e.surface, time_to_live = r.delay + 10, draw_on_ground = true })
  job({ kind = "cairn", e = e, un = g.un, list = list, c = pos_of(target), at = tick + r.delay })
  return true
end

local function cairn_tire(j, tick)
  local e = j.e
  if not (e and e.valid) then return end
  local r = Xp.robot("cairn")
  local b = BOUCHE.cairn
  local n = 0
  for _, t in ipairs(j.list) do
    if t.valid then rayon(e, CAIRN_ARC, b, t, 20); n = n + 1 end
  end
  K.journal("cairn balayage #%d arcs %d tick %d", j.un, n, tick)
  zone(e, j.un, r, j.c, tick)
end

--- Stylet : le circuit à angles droits court de la pointe aux nœuds, un pilier à chaque nœud ; la salve de zone autour de la cible.
local function ecriture(g, r, target, tick)
  local e = g.e
  local cands = K.candidates(e.surface, e.force, target.position, 40)
  local first = { x = target.position.x, y = target.position.y, id = target.unit_number or 0, e = target }
  local nodes, pts = Xp.circuit(pos_of(e), first, cands, r.nodes, 12)
  job({ kind = "stylet", e = e, un = g.un, nodes = nodes, pts = pts, k = 1, at = tick + 1 })
  zone(e, g.un, r, pos_of(target), tick)
  return true
end

local function stylet_pas(j, tick)
  local e = j.e
  local r = Xp.robot("stylet")
  if not (e and e.valid) then return true end
  local a, b = j.pts[j.k], j.pts[j.k + 1]
  if not b then
    K.journal("stylet ecriture #%d noeuds %d tick %d", j.un, #j.nodes, tick)
    return true
  end
  rendering.draw_line({ color = rgba(0.6, 0.85, 1.0, 0.9), width = 12, from = { a.x, a.y }, to = { b.x, b.y }, surface = e.surface,
    time_to_live = 150, draw_on_ground = true })
  rendering.draw_line({ color = { r = 1, g = 1, b = 1, a = 1 }, width = 4, from = { a.x, a.y }, to = { b.x, b.y }, surface = e.surface,
    time_to_live = 60, draw_on_ground = true })
  for _, nd in ipairs(j.nodes) do
    if math.abs(nd.x - b.x) < 1e-6 and math.abs(nd.y - b.y) < 1e-6 then e.surface.create_entity({ name = PILIER, position = { b.x, b.y } }) end
  end
  j.k = j.k + 1
  j.at = tick + r.step_ticks
  return false
end

--- Trombe : le sol blanchit dans la zone, les unités ennemies s'arrêtent ; au dégel, pics de glace et salve de zone.
local function gel(g, r, target, tick)
  local e = g.e
  local c = pos_of(target)
  local frozen = {}
  for _, it in ipairs(Xp.in_radius(c, K.candidates(e.surface, e.force, c, r.zone + 2), r.zone)) do
    local t = it.c.e
    if t.valid and t.active then
      t.active = false
      frozen[#frozen + 1] = t
    end
  end
  rendering.draw_circle({ color = rgba(0.75, 0.9, 1.0, 0.22), radius = r.zone, filled = true, target = { c.x, c.y }, surface = e.surface,
    time_to_live = r.freeze + 40, draw_on_ground = true })
  rendering.draw_circle({ color = rgba(0.6, 0.9, 1.0, 0.7), radius = r.zone, width = 12, filled = false, target = { c.x, c.y },
    surface = e.surface, time_to_live = r.freeze + 40, draw_on_ground = true })
  job({ kind = "trombe", e = e, un = g.un, c = c, frozen = frozen, at = tick + r.freeze })
  K.journal("trombe gel #%d geles %d tick %d", g.un, #frozen, tick)
  return true
end

local function trombe_degel(j, tick)
  local r = Xp.robot("trombe")
  for _, t in ipairs(j.frozen) do
    if t.valid then t.active = true end
  end
  if not (j.e and j.e.valid) then return end
  local surface = j.e.surface
  for _, t in ipairs(j.frozen) do
    if t.valid then rendering.draw_sprite({ sprite = SPR_GLACE, target = t.position, surface = surface, time_to_live = 90, render_layer = "object" }) end
  end
  K.journal("trombe degel #%d geles %d tick %d", j.un, #j.frozen, tick)
  zone(j.e, j.un, r, j.c, tick)
end

--- Ixion : la fissure court vers la cible et au-delà, geysers le long ; la salve de zone autour de la cible.
local function tranchee(g, r, target, tick)
  local e = g.e
  local pts = Xp.fissure(pos_of(e), pos_of(target), r.step, r.beyond)
  if #pts == 0 then return false end
  job({ kind = "ixion", e = e, un = g.un, pts = pts, k = 1, at = tick + 1, prev = pos_of(e) })
  zone(e, g.un, r, pos_of(target), tick)
  return true
end

local function ixion_pas(j, tick)
  local e = j.e
  local r = Xp.robot("ixion")
  if not (e and e.valid) then return true end
  local p = j.pts[j.k]
  if not p then
    K.journal("ixion tranchee #%d points %d tick %d", j.un, #j.pts, tick)
    return true
  end
  rendering.draw_line({ color = rgba(0.12, 0.07, 0.05, 0.95), width = 32 * r.width * 0.5, from = { j.prev.x, j.prev.y }, to = { p.x, p.y },
    surface = e.surface, time_to_live = 900, draw_on_ground = true })
  rendering.draw_line({ color = { r = 1.0, g = 0.5, b = 0.12, a = 1 }, width = 32 * r.width * 0.15, from = { j.prev.x, j.prev.y }, to = { p.x, p.y },
    surface = e.surface, time_to_live = 240, draw_on_ground = true })
  e.surface.create_entity({ name = "big-explosion", position = { p.x, p.y } })
  j.prev = p
  j.k = j.k + 1
  j.at = tick + r.step_ticks
  return false
end

--- Tournesol : de jour, le foyer rend un trait sur la cible pendant toute la cadence ; verre fondu au sol ; la salve de zone autour.
local function foyer(g, r, target, tick)
  local e = g.e
  if not Xp.foyer_fires(e.surface.darkness, r.night) then return false end
  local b = BOUCHE.tournesol
  rayon(e, FOYER, b, target, r.zone_cooldown)
  g.n = g.n + 1
  if g.n % r.glass_every == 0 and target.valid then
    rendering.draw_sprite({ sprite = SPR_VERRE, target = target.position, surface = e.surface, time_to_live = 1200, render_layer = "decals",
      tint = rgba(1, 0.9, 0.6, 0.8) })
  end
  K.journal("tournesol foyer #%d tick %d", g.un, tick)
  zone(e, g.un, r, pos_of(target), tick)
  return true
end

local EFFECTS = { balayage = balayage, ecriture = ecriture, gel = gel, tranchee = tranchee, foyer = foyer }

--- Cible d'un géant : l'ennemi MILITAIRE le plus proche à portée, sinon (décision du DC, 5/11 : « tout ce qui est ennemi, jusqu'à la fin »)
--- la première entité ennemie avec des PV à portée (ordre de la recherche du moteur, le même sur toutes les machines).
local function cible(e, r)
  local t = e.surface.find_nearest_enemy({ position = e.position, max_distance = r.range, force = e.force })
  if t then return t end
  local forces = K.enemy_forces(e.force)
  if #forces == 0 then return nil end
  for _, x in ipairs(e.surface.find_entities_filtered({ position = e.position, radius = r.range, force = forces, limit = CIBLES_MAX })) do
    if x.valid and x.health and x.destructible then return x end
  end
  return nil
end

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
        local t = cible(e, r)
        if t and EFFECTS[r.effect](g, r, t, ev.tick) then
          local st = K.stat(r.id)
          st.coups = st.coups + 1
          g.next = ev.tick + r.zone_cooldown
        end
      end
    end
  end
  s.giants = keep
end

local STEP = { stylet = stylet_pas, ixion = ixion_pas, zone = zone_pas }

local function on_tick(ev)
  local s = K.S()
  if not s or #s.gjobs == 0 then return end
  local keep = {}
  local n0 = #s.gjobs
  for i = 1, n0 do
    local j = s.gjobs[i]
    local done = false
    if j.at <= ev.tick then
      if j.kind == "cairn" then cairn_tire(j, ev.tick); done = true
      elseif j.kind == "trombe" then trombe_degel(j, ev.tick); done = true
      else done = STEP[j.kind](j, ev.tick) end
    end
    if not done then keep[#keep + 1] = j end
  end
  -- les salves lancées pendant ce tick (cairn_tire, trombe_degel) ont été ajoutées en fin de liste : elles sont gardées
  for i = n0 + 1, #s.gjobs do keep[#keep + 1] = s.gjobs[i] end
  s.gjobs = keep
end

Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on(defines.events.script_raised_built, on_built)
Events.on(defines.events.script_raised_revive, on_built)
Events.on(defines.events.on_tick, on_tick)
Events.on_nth_tick(SCAN, scan)

return G
