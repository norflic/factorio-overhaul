--[[
  Suite NAV2 (3/11) : avant-poste dont le champ est passé à l'électrique (partie lot-271828182 : votre équipe, 50 refus de tournée vers
  (-11,13), 13 foreuses électriques, 25 tapis, 2 poteaux autour du but ; script/team/gisement.lua retire les foreuses à combustion
  remplacées des listes de l'avant-poste, les foreuses électriques n'y sont pas).

  Banc CIBLÉ en moteur réel : votre équipe de 8 PNJ ; disque de fer de rayon 12 à 48 tuiles du QG ; avant-poste de fer (pose réelle :
  8 paires foreuse à combustion + four, point d'accès au centre) ; puis le champ électrique du plan de shared/team/champ.lua posé par
  script sur le même gisement (les paires qui le gênent sont démontées, comme le remplacement par l'électrique) : il reste quelques
  paires à combustion dans les listes de l'avant-poste. Brûleurs à sec, 400 charbons au QG.
    1) demandes de chemin BRUTES (réglage du mod : marge 0,15, grille 0, rayon 3) depuis 8 points à 26 tuiles vers le point libre le plus
       proche du centre (le but de la tournée en 0.6.42) ;
    2) fenêtre de 5 min : brûleurs restants ravitaillés, refus « inaccessible » du service de chemins.
  Règle « accès atteignable » allumée (nav2-elec) ou coupée (nav2-elec-temoin). Journal [FO-NAV2-ELEC(-TEMOIN)].
]]
package.loaded["shared.team.champ_fonderie"] = package.loaded["shared.team.champ_fonderie"] or require("__factorio-overhaul__/shared/team/champ_fonderie")
package.loaded["shared.team.melange"] = package.loaded["shared.team.melange"] or require("__factorio-overhaul__/shared/team/melange")
package.loaded["shared.team.champ_colonne"] = package.loaded["shared.team.champ_colonne"] or require("__factorio-overhaul__/shared/team/champ_colonne")
package.loaded["shared.team.champ"] = package.loaded["shared.team.champ"] or require("__factorio-overhaul__/shared/team/champ")
local Ch = package.loaded["shared.team.champ"]

local MIN = 3600
local W0 = 60
local WINDOW = 5 * MIN
local CHECK = W0 + WINDOW + 100
local STEP = 10
local BODY = "fo-companion"
local NAMES = { foreuse = "electric-mining-drill", tapis = "transport-belt", poteau = "small-electric-pole", four = "stone-furnace",
  bras = "inserter", coffre = "iron-chest" }
local STARTS = { { 26, 0 }, { -26, 0 }, { 0, 26 }, { 0, -26 }, { 19, 19 }, { -19, 19 }, { 19, -19 }, { -19, -19 } }

local function G() global.nav2e = global.nav2e or { by_id = {} } return global.nav2e end

script.on_event(defines.events.on_script_path_request_finished, function(e)
  local g = G()
  local r = g.by_id[e.id]
  if not r then return end
  g.by_id[e.id] = nil
  if e.try_again_later then r.state = "retry" r.retries = (r.retries or 0) + 1 return end
  r.state = e.path and "ok" or "no_path"
end)

local function data(ore, plate)
  local dp = game.entity_prototypes[NAMES.foreuse]
  local rp = game.entity_prototypes[ore]
  local pp = game.entity_prototypes[NAMES.poteau]
  local bp = game.entity_prototypes[NAMES.tapis]
  local fp = game.entity_prototypes[NAMES.four]
  local ap = game.entity_prototypes[NAMES.bras]
  local rec = game.recipe_prototypes[plate]
  return {
    drill = { size = dp.tile_width, reach = math.floor((2 * dp.mining_drill_radius - dp.tile_width) / 2 + 0.5),
      rate = dp.mining_speed / rp.mineable_properties.mining_time },
    pole = { reach = math.floor(pp.supply_area_distance - 0.5 + 1e-6), wire = pp.max_wire_distance },
    belts = { { lane = bp.belt_speed * 240 } },
    furnace = { size = fp.tile_width, rate = fp.crafting_speed / rec.energy, fuel = fp.burner_prototype ~= nil },
    inserter = { rate = ap.inserter_rotation_speed * 60 },
  }
end

local function burners_near(s, c)
  local out = {}
  for _, e in ipairs(s.find_entities_filtered({ position = c, radius = 16, force = "player", name = { "burner-mining-drill", "stone-furnace" } })) do
    if e.burner then out[#out + 1] = e end
  end
  return out
end

return function(rule)
  local TAG = "[FO-NAV2-ELEC" .. (rule and "]" or "-TEMOIN]")
  return {
    description = "NAV2 : tournee vers un avant-poste dont le champ est passe a l'electrique, regle " .. (rule and "ALLUMEE" or "COUPEE (temoin)"),
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local st = ctx.state()
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local s = ctx.surface()
      local c0 = game.forces.player.get_spawn_position(s)
      local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
      local hq = { x = math.floor(p.x) + 0.5, y = math.floor(p.y) + 0.5 }
      local cc = { x = math.floor(hq.x) + 48, y = math.floor(hq.y) }
      ctx.prepare_area(cc.x - 34, cc.y - 34, cc.x + 34, cc.y + 34, "grass-1")
      local flat = {}
      for dx = -12, 12 do
        for dy = -12, 12 do
          if dx * dx + dy * dy <= 144 then
            s.create_entity({ name = "iron-ore", position = { cc.x + dx + 0.5, cc.y + dy + 0.5 }, amount = 20000 })
            flat[#flat + 1] = cc.x + dx
            flat[#flat + 1] = cc.y + dy
          end
        end
      end
      local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      chest.get_inventory(defines.inventory.chest).insert({ name = "iron-plate", count = 200 })
      local v = ctx.remote("fo-ia1", "set_regle_acces", "player", rule)
      ctx.check(v == rule, "interrupteur de la regle : " .. (rule and "allumee" or "coupee"), tostring(v))
      local o = ctx.remote("fo-ia1", "bench_outpost", "player", "iron", cc.x + 0.5, cc.y + 0.5)
      ctx.check(o ~= nil, "avant-poste de fer pose (paires a combustion)", o and (o.drills .. " foreuse(s)") or "nil")
      if not o then return end
      -- champ électrique du plan, posé par-dessus : les paires qui gênent sont démontées (remplacement par l'électrique)
      local d = data("iron-ore", "iron-plate")
      local plan, why = Ch.plan({ ore = flat, blocked = {}, drill = d.drill, pole = d.pole, belts = d.belts, furnace = d.furnace,
        inserter = d.inserter, target = { x = cc.x - 80, y = cc.y } })
      ctx.check(plan ~= nil, "plan de champ rendu", tostring(why))
      if not plan then return end
      local made, removed, failed = 0, 0, 0
      for _, e in ipairs(plan.ents) do
        local name = NAMES[e.kind]
        local ent = s.create_entity({ name = name, position = { e.x, e.y }, direction = e.dir, force = "player" })
        if not ent then
          local proto = game.entity_prototypes[name]
          local b = proto.collision_box
          local area = { { e.x + b.left_top.x - 0.5, e.y + b.left_top.y - 0.5 }, { e.x + b.right_bottom.x + 0.5, e.y + b.right_bottom.y + 0.5 } }
          for _, q in ipairs(s.find_entities_filtered({ area = area, force = "player", name = { "burner-mining-drill", "stone-furnace" } })) do
            q.destroy()
            removed = removed + 1
          end
          ent = s.create_entity({ name = name, position = { e.x, e.y }, direction = e.dir, force = "player" })
        end
        if ent then made = made + 1 else failed = failed + 1 end
      end
      local left = #burners_near(s, cc)
      st.cc, st.hq = cc, { x = chest.position.x, y = chest.position.y }
      ctx.log(string.format("%s depart : avant-poste %d au centre (%d, %d) ; plan : %d foreuses electriques, %d tapis, %d poteaux ; poses %d, refuses %d ; bruleurs demontes %d, restants %d",
        TAG, o.id, cc.x, cc.y, plan.stats.drills, plan.stats.belts, plan.stats.poles, made, failed, removed, left))
      ctx.check(left >= 1, "il reste des bruleurs dans l'avant-poste", tostring(left))
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.cc then return end
      local s = ctx.surface()
      local g = G()
      local t = e.tick
      if t == 1 then
        st.burners = {}
        for _, b in ipairs(burners_near(s, st.cc)) do
          b.get_fuel_inventory().clear()
          if b.burner.currently_burning then b.burner.remaining_burning_fuel = 0 end
          st.burners[#st.burners + 1] = { e = b, fed = false }
        end
        local chest = s.find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
        if chest then
          local ci = chest.get_inventory(defines.inventory.chest)
          ci.remove({ name = "coal", count = 100000 })
          ci.insert({ name = "coal", count = 400 })
        end
        -- demandes brutes vers le point libre le plus proche du centre (but de la tournée en 0.6.42)
        local goal = s.find_non_colliding_position(BODY, st.cc, 8, 0.5) or st.cc
        g.goal = { x = goal.x, y = goal.y }
        g.reqs = {}
        local b = game.entity_prototypes[BODY].collision_box
        for i, off in ipairs(STARTS) do
          local sp = s.find_non_colliding_position(BODY, { x = st.cc.x + off[1], y = st.cc.y + off[2] }, 4, 0.5)
          if sp then
            local id = s.request_path({
              bounding_box = { { b.left_top.x - 0.15, b.left_top.y - 0.15 }, { b.right_bottom.x + 0.15, b.right_bottom.y + 0.15 } },
              collision_mask = game.entity_prototypes[BODY].collision_mask,
              start = sp, goal = g.goal, force = "player", radius = 3,
              pathfind_flags = { cache = false, prefer_straight_paths = true }, path_resolution_modifier = 0,
            })
            local r = { i = i, state = "pending" }
            g.reqs[#g.reqs + 1] = r
            g.by_id[id] = r
          end
        end
        ctx.log(string.format("%s etat de depart : %d bruleur(s) a sec, 400 charbons au QG ; but brut (%.1f, %.1f), %d demande(s) brute(s)",
          TAG, #st.burners, g.goal.x, g.goal.y, #g.reqs))
      end
      if t == W0 then
        st.t0 = t
        local ok, pth = pcall(ctx.remote, "fo-ia1", "path")
        st.fail0 = ok and pth and pth.fail_other or 0
      end
      if not st.t0 or t > W0 + WINDOW or t % STEP ~= 0 then return end
      for _, b in ipairs(st.burners) do
        if not b.fed and b.e.valid and b.e.get_fuel_inventory().get_item_count() > 0 then b.fed = true b.at = t end
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local g = G()
      if not st.t0 then ctx.check(false, "la fenetre a commence") return end
      local okp, nop = 0, 0
      for _, r in ipairs(g.reqs or {}) do
        if r.state == "ok" then okp = okp + 1 elseif r.state == "no_path" then nop = nop + 1 end
      end
      local fed, first = 0, nil
      for _, b in ipairs(st.burners) do
        if b.fed then fed = fed + 1 if not first or b.at < first then first = b.at end end
      end
      local ok, pth = pcall(ctx.remote, "fo-ia1", "path")
      local nf = (ok and pth and pth.fail_other or 0) - (st.fail0 or 0)
      ctx.log(string.format("%s RESULTAT chemins_bruts=%d/%d no_path_bruts=%d bruleurs=%d ravitailles=%d premier_s=%.0f refus_inaccessible=%d",
        TAG, okp, #(g.reqs or {}), nop, #st.burners, fed, first and (first - W0) / 60 or -1, nf))
      ctx.check(#st.burners >= 1, "bruleurs suivis", tostring(#st.burners))
      if rule then
        ctx.check(fed >= 1, "la tournee atteint l'avant-poste (au moins un bruleur ravitaille)", string.format("%d/%d", fed, #st.burners))
      end
    end,
  }
end
