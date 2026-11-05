--[[
  Lot FUITE (defense groupee du QG) : une VAGUE sur le QG de votre equipe. Coffre en (2000, 0), 3 mitrailleuses de QG (munitions
  garnies) a l'est, cerveau retenu, tous les PNJ de l'equipe au repos autour du coffre (armes). Au tick 600, 16 moyens
  dechiqueteurs (force ponderee 16 : plus que les PNJ armes ne battent un par un) naissent a 75 tuiles a l'est et chargent
  le QG (attack_area). Reference int-1 (partie du guide, 55 min) : 9 PNJ tues en 18 s, un par un, a 5-25 tuiles du QG.
  Mesures : PNJ au depart et a la fin, PNJ morts, dechiqueteurs tues, reponses de l'equipe (stats ia3k hq_*, shelter_*).
  Criteres : PNJ perdus <= 2 ; au moins 12 dechiqueteurs sur 16 tues (la defense n'est pas sacrifiee). Journal : [FO-IA3K-VAGUE].
  Options FACULTATIVES (lot CORR-RALLIEMENT, 5/11 ; sans elles, le scenario est celui du lot FUITE, a l'identique) :
    turrets       = { { dx, dy }, ... } : tourelles du QG autour du coffre (defaut : 3 a l'est, (12, -8), (12, 0), (12, 8)) ;
    outrange      = true | false : interrupteur remote.call("fo-ia3k", "debordement", ...) (false : temoin, regle eteinte) ;
    lost_min      = n : le controle des PNJ perdus devient « au moins n » (temoin qui doit REPRODUIRE les morts) ;
    kills_min = 0 : pas de controle des unites tuees (unites qu'on ne peut pas tuer : elles debordent tout) ;
    turret_far    = d : au moins une tourelle du QG tuee alors que l'unite de la vague la plus proche etait a plus de d tuiles ;
    hq_expect     = { [cle de stats] = "zero" | "pos" } : controles des reponses de l'equipe (stats ia3k), cles triees.
]]

local AX = 2000
local WAVE = 600
local OBS = 2400
local DEFAULT_TURRETS = { { 12, -8 }, { 12, 0 }, { 12, 8 } }

return function(opts)
local N_BITERS, UNIT = opts.n, opts.unit
local TURRETS = opts.turrets or DEFAULT_TURRETS
local EXTRA = opts.hq_expect ~= nil or opts.turret_far ~= nil
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
    st.turrets, st.tpos = {}, {}
    for _, d in ipairs(TURRETS) do
      local tu = s.create_entity({ name = "gun-turret", position = { AX + d[1], d[2] }, force = "player", raise_built = true })
      if tu then
        tu.insert({ name = "firearm-magazine", count = 60 })
        st.turrets[#st.turrets + 1] = tu
        st.tpos[#st.tpos + 1] = { x = tu.position.x, y = tu.position.y }
      end
    end
    ctx.check(#st.turrets == #TURRETS, string.format("%d mitrailleuses de QG posees", #TURRETS))
    ctx.check(ctx.remote("fo-ia3k", "hold", "player", true) == true, "cerveau retenu")
    if opts.outrange ~= nil then
      ctx.check(ctx.remote("fo-ia3k", "debordement", opts.outrange) == true,
        "regle du debordement " .. (opts.outrange and "allumee (lot)" or "eteinte (temoin)"))
    end
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
    if EXTRA and t > WAVE and st.turrets then
      -- Mort d'une tourelle du QG : distance de l'unite de la vague la plus proche (au tick du constat, une unite va a moins
      -- de 0,2 tuile par tick).
      st.tdead = st.tdead or {}
      for i, tu in ipairs(st.turrets) do
        if not st.tdead[i] and not tu.valid then
          local q, bd = st.tpos[i], nil
          for _, b in ipairs(st.biters or {}) do
            if b.valid then
              local d = math.sqrt((b.position.x - q.x) ^ 2 + (b.position.y - q.y) ^ 2)
              if not bd or d < bd then bd = d end
            end
          end
          st.tdead[i] = bd or -1
          ctx.log(string.format("tourelle du QG %d (%d, %d) morte au tick %d ; unite de la vague la plus proche a %s tuiles", i,
            math.floor(q.x - AX), math.floor(q.y), t, bd and string.format("%.1f", bd) or "?"))
        end
      end
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
    local keys = { "hq_stand", "hq_rally", "hq_away", "shelter", "shelter_rally", "shelter_away", "refuges" }
    if EXTRA then keys[#keys + 1] = "hq_outranged" keys[#keys + 1] = "outranged" end
    if stv then
      for _, k in ipairs(keys) do
        sx[#sx + 1] = k .. "=" .. tostring(stv.stats[k] or 0)
      end
      local acts = {}
      for _, k in ipairs({ "engage", "flee", "back", "detour", "stop" }) do acts[#acts + 1] = k .. "=" .. tostring(stv.stats.actions[k] or 0) end
      sx[#sx + 1] = "actions[" .. table.concat(acts, " ") .. "]"
    end
    ctx.log(string.format("FAIT PNJ au depart %d, perdus %d, dechiqueteurs tues %d / %d ; %s", n0, lost, killed, #(st.biters or {}), table.concat(sx, " ")))
    ctx.check(n0 >= 6, "au moins 6 PNJ dans l'equipe", n0)
    if opts.lost_min then
      ctx.check(lost >= opts.lost_min, string.format("PNJ perdus a la vague >= %d (le temoin reproduit)", opts.lost_min), lost)
    else
      ctx.check(lost <= 2, "PNJ perdus a la vague <= 2", lost)
    end
    if opts.kills_min ~= 0 then
      ctx.check(killed * 4 >= #(st.biters or {}) * 3 * (opts.kills_min or 1), "au moins 3/4 des dechiqueteurs tues", string.format("%d / %d", killed, #(st.biters or {})))
    end
    if opts.turret_far then
      local far, dead, ds = 0, 0, {}
      for i = 1, #(st.tpos or {}) do
        local d = st.tdead and st.tdead[i]
        if d then
          dead = dead + 1
          ds[#ds + 1] = string.format("%.1f", d)
          if d > opts.turret_far then far = far + 1 end
        end
      end
      ctx.check(far >= 1, string.format("au moins une tourelle du QG tuee depuis plus de %d tuiles", opts.turret_far),
        string.format("%d tuee(s) sur %d, unite la plus proche a {%s}", dead, #(st.tpos or {}), table.concat(ds, " ")))
    end
    if opts.hq_expect then
      local ks = {}
      for k in pairs(opts.hq_expect) do ks[#ks + 1] = k end
      table.sort(ks)
      for _, k in ipairs(ks) do
        local v = stv and stv.stats[k] or 0
        if opts.hq_expect[k] == "zero" then ctx.check(v == 0, k .. " = 0", v)
        else ctx.check(v > 0, k .. " > 0", v) end
      end
    end
  end,
}
end
