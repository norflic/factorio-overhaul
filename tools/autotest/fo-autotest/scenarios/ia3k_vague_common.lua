--[[
  Lot FUITE (defense groupee du QG) : une VAGUE sur le QG de votre equipe. Coffre en (2000, 0), 3 mitrailleuses de QG (munitions
  garnies) a l'est, cerveau retenu, tous les PNJ de l'equipe au repos autour du coffre (armes). Au tick 600, 16 moyens
  dechiqueteurs (force ponderee 16 : plus que les PNJ armes ne battent un par un) naissent a 75 tuiles a l'est et chargent
  le QG (attack_area). Reference int-1 (partie du guide, 55 min) : 9 PNJ tues en 18 s, un par un, a 5-25 tuiles du QG.
  Mesures : PNJ au depart et a la fin, PNJ morts, dechiqueteurs tues, reponses de l'equipe (stats ia3k hq_*, shelter_*).
  Criteres : PNJ perdus <= 2 ; au moins 12 dechiqueteurs sur 16 tues (la defense n'est pas sacrifiee). Journal : [FO-IA3K-VAGUE].
]]

local AX = 2000
local WAVE = 600
local OBS = 2400

return function(opts)
local N_BITERS, UNIT = opts.n, opts.unit
return {
  description = opts.description,
  check_tick = WAVE + OBS,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(AX - 40, -150, AX + 200, 150, "grass-1")
    ctx.check(ctx.call("war_setting", "fo-war-ia3-comportement", true) == true, "reglage fo-war-ia3-comportement allume")
    if remote.interfaces["fo-ia3f"] and remote.interfaces["fo-ia3f"].set_fog then
      ctx.remote("fo-ia3f", "set_fog", false)
    end
    ctx.call("profiler", true)
    local chest = s.create_entity({ name = "fo-team-chest", position = { AX, 0 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if chest then
      for _, it in ipairs({ { "iron-plate", 300 }, { "pistol", 8 }, { "firearm-magazine", 100 } }) do chest.insert({ name = it[1], count = it[2] }) end
    end
    st.turrets = {}
    for _, y in ipairs({ -8, 0, 8 }) do
      local tu = s.create_entity({ name = "gun-turret", position = { AX + 12, y }, force = "player", raise_built = true })
      if tu then
        tu.insert({ name = "firearm-magazine", count = 60 })
        st.turrets[#st.turrets + 1] = tu
      end
    end
    ctx.check(#st.turrets == 3, "3 mitrailleuses de QG posees")
    ctx.check(ctx.remote("fo-ia3k", "hold", "player", true) == true, "cerveau retenu")
  end,

  tick = function(ctx, e)
    local t = e.tick
    local st = ctx.state()
    local s = ctx.surface()
    if opts.scatter and t == WAVE - 400 then
      -- PNJ AU TRAVAIL (tâche « ghost », non exemptée) répartis sur le chemin de la vague, comme les bâtisseurs d'int-1.
      local k = 0
      for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do
        if not a.task and a.state ~= "walk" then
          k = k + 1
          ctx.remote("fo-ia3k", "trip", "player", a.id, AX + 22 + (k % 3) * 14, (k - 4) * 9, 1500, nil, nil, "ghost")
        end
      end
      ctx.log(string.format("%d PNJ au travail sur le chemin de la vague", k))
    elseif t == WAVE - 1 then
      -- Tous les PNJ : plein de vie, munitions (10 chargeurs).
      st.start_ids = {}
      for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do
        st.start_ids[#st.start_ids + 1] = a.id
        local best, bd = nil, nil
        for _, c in ipairs(s.find_entities_filtered({ position = { a.x, a.y }, radius = 4, type = "character", force = "player" })) do
          local d = (c.position.x - a.x) ^ 2 + (c.position.y - a.y) ^ 2
          if not bd or d < bd then best, bd = c, d end
        end
        if best then
          best.health = best.prototype.max_health
          local ammo = best.get_inventory(defines.inventory.character_ammo)
          if ammo and ammo.get_item_count("firearm-magazine") < 10 then ammo.insert({ name = "firearm-magazine", count = 10 }) end
        end
      end
      ctx.log(string.format("%d PNJ au repos autour du coffre", #st.start_ids))
    elseif t == WAVE then
      st.biters = {}
      for j = 1, N_BITERS do
        local p = s.find_non_colliding_position(UNIT, { x = AX + 75, y = (j - 4.5) * 4 }, 6, 0.5)
        local b = p and s.create_entity({ name = UNIT, position = p, force = "enemy" })
        if b then
          b.set_command({ type = defines.command.attack_area, destination = { x = AX, y = 0 }, radius = 25, distraction = defines.distraction.by_enemy })
          st.biters[#st.biters + 1] = b
        end
      end
      ctx.log(string.format("vague : %d dechiqueteurs", #st.biters))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local alive_pnj = {}
    for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do alive_pnj[a.id] = true end
    local n0, lost = #(st.start_ids or {}), 0
    for _, id in ipairs(st.start_ids or {}) do if not alive_pnj[id] then lost = lost + 1 end end
    local alive_b = 0
    for _, b in ipairs(st.biters or {}) do if b.valid then alive_b = alive_b + 1 end end
    local killed = #(st.biters or {}) - alive_b
    local stv = ctx.remote("fo-ia3k", "status", "player")
    local sx = {}
    if stv then
      for _, k in ipairs({ "hq_stand", "hq_rally", "hq_away", "shelter", "shelter_rally", "shelter_away", "refuges" }) do
        sx[#sx + 1] = k .. "=" .. tostring(stv.stats[k] or 0)
      end
      local acts = {}
      for _, k in ipairs({ "engage", "flee", "back", "detour", "stop" }) do acts[#acts + 1] = k .. "=" .. tostring(stv.stats.actions[k] or 0) end
      sx[#sx + 1] = "actions[" .. table.concat(acts, " ") .. "]"
    end
    ctx.log(string.format("FAIT PNJ au depart %d, perdus %d, dechiqueteurs tues %d / %d ; %s", n0, lost, killed, #(st.biters or {}), table.concat(sx, " ")))
    ctx.check(n0 >= 6, "au moins 6 PNJ dans l'equipe", n0)
    ctx.check(lost <= 2, "PNJ perdus a la vague <= 2", lost)
    ctx.check(killed * 4 >= #(st.biters or {}) * 3 * (opts.kills_min or 1), "au moins 3/4 des dechiqueteurs tues", string.format("%d / %d", killed, #(st.biters or {})))
  end,
}
end
