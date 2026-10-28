--[[
  Lot FUITE (preuve) : la VAGUE d'une faction sur votre equipe, comme int-1 a 55 min (9 PNJ tues en 18 s). Votre equipe
  (coffre en (2000, 0), 4 mitrailleuses de QG), cerveau retenu, ses PNJ repartis comme dans int-1 :
    - 4 « ghost » (batisseurs) en chantier a 55-110 tuiles a l'est, SUR le chemin de l'armee (ils la voient venir et rentrent) ;
    - 1 « smelt » et 1 « craft » a 15-20 tuiles du coffre ; les autres au repos autour du coffre (dont 2 « garrison » si assez de PNJ).
  L'armee : de VRAIES unites de la faction fo-azure (prototypes du mod : rifleman, gunner, rocketeer, vue 30, vitesse 0,11-0,12)
  nees a 230 tuiles a l'est, attack_area sur le QG (distraction par ennemis). Mesures : PNJ perdus (par role de depart),
  unites tuees, premiers morts. Critere : PNJ perdus <= 2 (9 dans int-1). Journal : [FO-IA3K-FACTION]. Le « temoin » est le meme
  banc lance sur une autre source (main), pas un reglage.
]]

local AX = 2000
local WAVE = 700
local OBS = 4600
local ARMY = { { "rifleman", 4 }, { "gunner", 3 }, { "rocketeer", 3 } }
local GHOSTS = { { 55, -10 }, { 75, 10 }, { 95, -5 }, { 110, 8 } }
local NEAR = { { "smelt", -15, 12 }, { "craft", 18, -12 } }

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

return {
  description = "FUITE : vague d'une faction (vraies unites fo-azure) sur des PNJ au travail et au QG",
  check_tick = WAVE + OBS,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(AX - 40, -150, AX + 330, 150, "grass-1")
    ctx.check(ctx.call("war_setting", "fo-war-ia3-comportement", true) == true, "reglage fo-war-ia3-comportement allume")
    if remote.interfaces["fo-ia3f"] and remote.interfaces["fo-ia3f"].set_fog then ctx.remote("fo-ia3f", "set_fog", false) end
    ctx.call("profiler", true)
    if not game.forces["fo-azure"] then game.create_force("fo-azure") end
    game.forces["fo-azure"].set_cease_fire("player", false)
    game.forces.player.set_cease_fire("fo-azure", false)
    local chest = s.create_entity({ name = "fo-team-chest", position = { AX, 0 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if chest then
      for _, it in ipairs({ { "iron-plate", 300 }, { "pistol", 8 }, { "firearm-magazine", 100 } }) do chest.insert({ name = it[1], count = it[2] }) end
    end
    st.turrets = 0
    for _, y in ipairs({ -12, -4, 4, 12 }) do
      local tu = s.create_entity({ name = "gun-turret", position = { AX + 12, y }, force = "player", raise_built = true })
      if tu then tu.insert({ name = "firearm-magazine", count = 60 }) st.turrets = st.turrets + 1 end
    end
    ctx.check(st.turrets == 4, "4 mitrailleuses de QG posees")
    ctx.check(ctx.remote("fo-ia3k", "hold", "player", true) == true, "cerveau retenu")
    st.role = {}
  end,

  tick = function(ctx, e)
    local t = e.tick
    local st = ctx.state()
    local s = ctx.surface()
    if t == WAVE - 500 then
      local list = {}
      for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do
        if not a.task then list[#list + 1] = a end
      end
      local k = 0
      for i, g in ipairs(GHOSTS) do
        local a = list[i]
        if a then
          k = k + 1
          st.role[a.id] = "ghost"
          ctx.remote("fo-ia3k", "trip", "player", a.id, AX + g[1], g[2], 4500, nil, nil, "ghost")
        end
      end
      for i, nr in ipairs(NEAR) do
        local a = list[#GHOSTS + i]
        if a then
          st.role[a.id] = nr[1]
          ctx.remote("fo-ia3k", "trip", "player", a.id, AX + nr[2], nr[3], 4500, nil, nil, nr[1])
        end
      end
      for i = #GHOSTS + #NEAR + 1, #list do
        local a = list[i]
        local garrison = i <= #GHOSTS + #NEAR + 2
        st.role[a.id] = garrison and "garrison" or "repos"
        if garrison then ctx.remote("fo-ia3k", "trip", "player", a.id, AX + 6, (i % 2 == 0) and 6 or -6, 4500, nil, nil, "garrison") end
      end
      ctx.log(string.format("%d PNJ en place (%d ghost)", #list, k))
    elseif t == WAVE - 1 then
      st.start_ids = {}
      for id in pairs(st.role) do st.start_ids[#st.start_ids + 1] = id end
      table.sort(st.start_ids)
      -- Pleine vie et munitions pour tous (10 chargeurs).
      for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do
        local best, bd = nil, nil
        for _, c in ipairs(s.find_entities_filtered({ position = { a.x, a.y }, radius = 4, type = "character", force = "player" })) do
          local d = d2(c.position, a)
          if not bd or d < bd then best, bd = c, d end
        end
        if best then
          best.health = best.prototype.max_health
          local ammo = best.get_inventory(defines.inventory.character_ammo)
          if ammo and ammo.get_item_count("firearm-magazine") < 10 then ammo.insert({ name = "firearm-magazine", count = 10 }) end
        end
      end
    elseif t == WAVE then
      st.army = {}
      local j = 0
      for _, row in ipairs(ARMY) do
        for _ = 1, row[2] do
          j = j + 1
          local name = "fo-azure-" .. row[1]
          local p = s.find_non_colliding_position(name, { x = AX + 230 + (j % 3) * 3, y = (j - 5.5) * 3 }, 8, 0.5)
          local u = p and s.create_entity({ name = name, position = p, force = "fo-azure" })
          if u then
            u.set_command({ type = defines.command.attack_area, destination = { x = AX, y = 0 }, radius = 25,
              distraction = defines.distraction.by_enemy })
            st.army[#st.army + 1] = u
          end
        end
      end
      ctx.log(string.format("armee fo-azure : %d unites a 230 tuiles", #st.army))
    elseif st.start_ids and t > WAVE and (t - WAVE) % 600 == 0 then
      local alive = 0
      for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do if st.role[a.id] then alive = alive + 1 end end
      local ua = 0
      for _, u in ipairs(st.army or {}) do if u.valid then ua = ua + 1 end end
      ctx.log(string.format("t+%d : PNJ vivants %d / %d, unites vivantes %d", t - WAVE, alive, #st.start_ids, ua))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local alive = {}
    for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do alive[a.id] = true end
    local lost, by = 0, {}
    for _, id in ipairs(st.start_ids or {}) do
      if not alive[id] then lost = lost + 1 by[st.role[id]] = (by[st.role[id]] or 0) + 1 end
    end
    local ua = 0
    for _, u in ipairs(st.army or {}) do if u.valid then ua = ua + 1 end end
    local killed = #(st.army or {}) - ua
    local roles = {}
    for _, k in ipairs({ "ghost", "smelt", "craft", "garrison", "repos" }) do roles[#roles + 1] = k .. "=" .. (by[k] or 0) end
    local stv = ctx.remote("fo-ia3k", "status", "player")
    local sx = {}
    if stv then
      for _, k in ipairs({ "hq_stand", "hq_rally", "hq_away", "shelter", "shelter_rally", "refuges", "flee_recalls" }) do
        sx[#sx + 1] = k .. "=" .. tostring(stv.stats[k] or 0)
      end
    end
    ctx.log(string.format("FAIT PNJ au depart %d, perdus %d [%s], unites tuees %d / %d ; %s", #(st.start_ids or {}), lost,
      table.concat(roles, " "), killed, #(st.army or {}), table.concat(sx, " ")))
    ctx.check(#(st.start_ids or {}) >= 8, "au moins 8 PNJ en place", #(st.start_ids or {}))
    ctx.check(#(st.army or {}) == 10, "10 unites fo-azure posees", #(st.army or {}))
    ctx.check(lost <= 2, "PNJ perdus a la vague <= 2 (9 dans int-1)", lost)
  end,
}
