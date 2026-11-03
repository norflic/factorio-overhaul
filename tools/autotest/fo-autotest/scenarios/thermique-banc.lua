--[[
  Lot CHAMP (retour du DC du 2/11) : le plan de shared/team/champ.lua posé TEL QUEL en moteur réel, par script, sur deux gisements :
    - « normal » : disque de fer de rayon 12, site de fonderie à l'ouest (sortie vers l'ouest) ;
    - « long »   : ellipse de cuivre de 121 × 21, tapis jaune seul (15 foreuses par côté au plus : la bande sort par ses deux bouts).
  Caractéristiques lues aux prototypes (foreuse électrique, petit poteau, tapis jaune, four de pierre, bras, coffre de fer), courant de
  l'alimentation invisible du mod de test, charbon dans les fours et les coffres de combustible. Contrôles au tick 7 000 (le minerai a parcouru les fonderies les plus longues) :
  tout posé, un seul réseau, foreuses qui extraient, minerai qui ne reste pas figé, fours qui produisent, plaques dans les coffres de
  sortie, contrôle pur du plan sans défaut. Lancement : banc.py --qui CHAMP -- 7200 champ-banc <source>. Journal : [FO-CHAMP-BANC].
]]
-- (les require internes de la règle sont relatifs à la racine du mod : leurs modules sont chargés d'abord sous leur nom)
package.loaded["shared.team.champ_fonderie"] = package.loaded["shared.team.champ_fonderie"] or require("__factorio-overhaul__/shared/team/champ_fonderie")
package.loaded["shared.team.melange"] = package.loaded["shared.team.melange"] or require("__factorio-overhaul__/shared/team/melange")
package.loaded["shared.team.champ_colonne"] = package.loaded["shared.team.champ_colonne"] or require("__factorio-overhaul__/shared/team/champ_colonne")
package.loaded["shared.team.champ"] = package.loaded["shared.team.champ"] or require("__factorio-overhaul__/shared/team/champ")
local Ch = package.loaded["shared.team.champ"]
local Cv = require("__factorio-overhaul__/shared/team/champ_verif")

local X0, Y0 = 4200, 3000
local NAMES = { foreuse = "electric-mining-drill", tapis = "transport-belt", poteau = "small-electric-pole", four = "stone-furnace",
  bras = "inserter", coffre = "iron-chest" }

local function data(ore, plate)
  local dp = game.entity_prototypes[NAMES.foreuse]
  local rp = game.entity_prototypes[ore]
  local pp = game.entity_prototypes[NAMES.poteau]
  local bp = game.entity_prototypes[NAMES.tapis]
  local ap = game.entity_prototypes[NAMES.bras]
  return {
    drill = { size = dp.tile_width, reach = math.floor((2 * dp.mining_drill_radius - dp.tile_width) / 2 + 0.5),
      rate = dp.mining_speed / rp.mineable_properties.mining_time },
    pole = { reach = math.floor(pp.supply_area_distance - 0.5 + 1e-6), wire = pp.max_wire_distance },
    belts = { { lane = bp.belt_speed * 240 } },
    furnace = nil, -- lot THERMIQUE : mode COFFRES (charbon, pierre)
    inserter = { rate = ap.inserter_rotation_speed * 60 },
  }
end

local function field(s, ore, shape)
  local flat = {}
  for _, t in ipairs(shape) do
    s.create_entity({ name = ore, position = { t[1] + 0.5, t[2] + 0.5 }, amount = 20000 })
    flat[#flat + 1] = t[1]; flat[#flat + 1] = t[2]
  end
  return flat
end

local function place(ctx, key, ore, plate, shape, target, min_cov)
  local s = ctx.surface()
  local st = ctx.state()
  local flat = field(s, ore, shape)
  local d = data(ore, plate)
  local spec = { ore = flat, blocked = {}, drill = d.drill, pole = d.pole, belts = d.belts, furnace = d.furnace, inserter = d.inserter,
    target = target }
  local plan, why = Ch.plan(spec)
  ctx.check(plan ~= nil, key .. " : plan rendu", tostring(why))
  if not plan then return end
  local rep = Cv.verify(plan, spec)
  ctx.log(string.format("[FO-CHAMP-BANC] %s : axe %s sortie %d, %d foreuses, %d fours, %d bras, %d coffres, %d poteaux, %d tapis, coupees %d ; %s",
    key, plan.axis, plan.exit, plan.stats.drills, plan.stats.furnaces, plan.stats.inserters, plan.stats.chests, plan.stats.poles,
    plan.stats.belts, plan.stats.capped, Cv.line(rep)))
  ctx.check(rep.ok and rep.elec >= min_cov, string.format("%s : plan sans defaut, couverture >= %d %%", key, math.floor(100 * min_cov + 0.5)), Cv.line(rep))
  if min_cov < 0.85 then
    ctx.check(plan.stats.capped > 0, key .. " : tapis jaune seul, des foreuses attendent un tapis plus rapide (ecart ecrit)", tostring(plan.stats.capped))
  end
  local made, failed = {}, 0
  for _, e in ipairs(plan.ents) do
    local ent = s.create_entity({ name = NAMES[e.kind], position = { e.x, e.y }, direction = e.dir, force = "player" })
    if ent then
      made[#made + 1] = ent
      if e.kind == "four" then ent.insert({ name = "coal", count = 5 }) end
      if e.kind == "coffre" and e.role == "combustible" then ent.insert({ name = "coal", count = 50 }) end
    else
      failed = failed + 1
    end
  end
  ctx.check(failed == 0, key .. " : toutes les entites du plan posees", failed .. " refusee(s) sur " .. #plan.ents)
  -- fils : chaque poteau relié à ses voisins à portée (comme le chantier, wire_project)
  local poles = {}
  for _, e in ipairs(made) do if e.valid and e.type == "electric-pole" then poles[#poles + 1] = e end end
  for _, p in ipairs(poles) do
    for _, q in ipairs(s.find_entities_filtered({ position = p.position, radius = d.pole.wire, type = "electric-pole", force = "player" })) do
      if q ~= p then p.connect_neighbour(q) end
    end
  end
  -- alimentation : au bord du champ, reliée au poteau le plus à l'ouest
  local west
  for _, p in ipairs(poles) do if not west or p.position.x < west.position.x then west = p end end
  if west then
    local src = ctx.power(west.position.x - 3, west.position.y)
    ctx.check(src ~= nil, key .. " : alimentation invisible du mod de test", src and "posee" or "prototypes absents")
    for _, q in ipairs(s.find_entities_filtered({ position = { west.position.x - 3, west.position.y }, radius = 1, type = "electric-pole" })) do
      q.connect_neighbour(west)
    end
  end
  st[key] = { made = made, plan_drills = plan.stats.drills, cov = rep.elec }
end

local function disc(cx, cy, r)
  local out = {}
  for x = cx - r, cx + r do for y = cy - r, cy + r do if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r then out[#out + 1] = { x, y } end end end
  return out
end
local function ellipse(cx, cy, a, b)
  local out = {}
  for x = cx - a, cx + a do
    for y = cy - b, cy + b do if ((x - cx) / a) ^ 2 + ((y - cy) / b) ^ 2 <= 1 then out[#out + 1] = { x, y } end end
  end
  return out
end

return {
  description = "THERMIQUE : champ en mode COFFRES pose en moteur reel (charbon normal, pierre longue au tapis jaune)",
  base = nil,
  check_tick = 7000,

  init = function(ctx)
    local s = ctx.surface()
    ctx.prepare_area(X0 - 240, Y0 - 40, X0 + 240, Y0 + 100, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 300, Y0 - 150 }, { X0 + 300, Y0 + 220 } } })) do en.destroy() end
    place(ctx, "normal", "coal", "coal", disc(X0, Y0, 12), { x = X0 - 500, y = Y0 }, 0.85)
    place(ctx, "long", "stone", "stone", ellipse(X0, Y0 + 60, 60, 10), { x = X0 + 500, y = Y0 + 60 }, 0.75)
  end,

  finish = function(ctx)
    local st = ctx.state()
    for _, key in ipairs({ "normal", "long" }) do
      local r = st[key]
      if r then
        local drills, working, stuck, nopower, furnaces, produced, plates, nets = 0, 0, 0, 0, 0, 0, 0, {}
        for _, e in ipairs(r.made) do
          if e.valid then
            if e.type == "mining-drill" then
              drills = drills + 1
              if e.status == defines.entity_status.working then working = working + 1 end
              if e.status == defines.entity_status.waiting_for_space_in_destination then stuck = stuck + 1 end
              if e.status == defines.entity_status.no_power or e.status == defines.entity_status.low_power then nopower = nopower + 1 end
            elseif e.type == "furnace" then
              furnaces = furnaces + 1
              if e.products_finished > 0 then produced = produced + 1 end
            elseif e.type == "container" then
              plates = plates + e.get_item_count("coal") + e.get_item_count("stone")
            elseif e.type == "electric-pole" and e.electric_network_id then
              nets[e.electric_network_id] = true
            end
          end
        end
        local n_nets = 0
        for _ in pairs(nets) do n_nets = n_nets + 1 end
        ctx.log(string.format("[FO-CHAMP-BANC] %s : foreuses %d (en marche %d, figees %d, sans courant %d), fours %d (ont produit %d), plaques dans les coffres %d, reseaux %d, couverture %.0f %%",
          key, drills, working, stuck, nopower, furnaces, produced, plates, n_nets, 100 * r.cov))
        ctx.check(n_nets == 1 and nopower == 0, key .. " : un seul reseau, aucune foreuse sans courant", n_nets .. " reseau(x), " .. nopower .. " sans courant")
        ctx.check(drills == r.plan_drills and working >= 0.9 * drills, key .. " : foreuses qui extraient (>= 90 %)", working .. " / " .. drills)
        ctx.check(stuck <= 0.1 * drills, key .. " : minerai pas fige (foreuses bloquees en sortie <= 10 %)", stuck .. " / " .. drills)
        ctx.check(furnaces == 0, key .. " : aucun four en mode coffres", tostring(furnaces))
        ctx.check(plates > 0, key .. " : minerai dans les coffres de sortie", tostring(plates))
      end
    end
  end,
}
