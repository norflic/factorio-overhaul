--[[
  Lot DANGER-ARRET : un PNJ ARME, en bonne sante et A L'ARRET regarde autour de lui (regard periodique etale par numero),
  en moteur reel. Votre equipe (coffre en (2000, 0), zone pavee, deux mitrailleuses de refuge au QG), cerveau retenu ; un
  PNJ par manche part en tournee vers (2090, 0) et y attend. Une fois arrive et immobile (etat « wait »), 2 moyens
  dechiqueteurs (force ponderee 2 : pas de combat en surnombre) naissent a 58 tuiles et chargent (vitesse 0,24 : 243 ticks
  pour couvrir la distance ; avant le lot, le PNJ ne reagissait qu'une fois blesse).
  Mesure (releve a chaque tick) : tick de la premiere reaction (etiquette detour, demi-tour, fuite, combat, ou refuge pose)
  et tick de la premiere blessure (vie sous 1 000 pour mille). Critere : reaction AVANT la premiere blessure dans >= 90 %
  des cas. Journal : [FO-IA3K-IMMOBILE].
]]

local AX = 2000
local DEST = AX + 90
local ROUND = 2200
local START = 600
local ROUNDS = 8
local CHECK = START + ROUNDS * ROUND + 60
local REACT = { detour = true, ["demi-tour"] = true, fuite = true, combat = true }

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

local function nearest_char(s, a)
  local best, bd = nil, nil
  for _, c in ipairs(s.find_entities_filtered({ position = { a.x, a.y }, radius = 4, type = "character", force = "player" })) do
    local d = d2(c.position, a)
    if not bd or d < bd then best, bd = c, d end
  end
  return best
end

return {
  description = "DANGER-ARRET : un PNJ arme a l'arret regarde autour de lui (reaction avant la premiere blessure)",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(AX - 20, -150, AX + 300, 150, "grass-1")
    ctx.check(ctx.call("war_setting", "fo-war-ia3-comportement", true) == true, "reglage fo-war-ia3-comportement allume")
    if remote.interfaces["fo-ia3f"] and remote.interfaces["fo-ia3f"].set_fog then
      ctx.log("exploration d'IA3-f coupee pour le banc : " .. tostring(ctx.remote("fo-ia3f", "set_fog", false)))
    end
    ctx.call("profiler", true)
    local chest = s.create_entity({ name = "fo-team-chest", position = { AX, 0 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if chest then
      for _, it in ipairs({ { "iron-plate", 300 }, { "pistol", 8 }, { "firearm-magazine", 100 } }) do chest.insert({ name = it[1], count = it[2] }) end
    end
    for _, y in ipairs({ -5, 5 }) do
      local tu = s.create_entity({ name = "gun-turret", position = { AX + 8, y }, force = "player", raise_built = true })
      if tu then tu.insert({ name = "firearm-magazine", count = 40 }) end
    end
    ctx.check(ctx.remote("fo-ia3k", "hold", "player", true) == true, "cerveau retenu")
    st.res = {}
    st.cur = {}
  end,

  tick = function(ctx, e)
    local t = e.tick
    local st = ctx.state()
    local s = ctx.surface()
    if t < START then return end
    local r = math.floor((t - START) / ROUND) + 1
    if r > ROUNDS then return end
    local in_round = t - START - (r - 1) * ROUND
    if in_round == 0 then
      ctx.remote("fo-ia3k", "forget", "player")
      ctx.remote("fo-ia3k", "set_character", "player", nil, nil)
      for _, b in ipairs(s.find_entities_filtered({ area = { { AX - 20, -150 }, { AX + 300, 150 } }, force = "enemy" })) do
        if b.valid then b.destroy() end
      end
      local idle = {}
      for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do
        if not a.task and a.state ~= "walk" then idle[#idle + 1] = a end
      end
      st.cur = {}
      local a = idle[1]
      if a then
        local ch = nearest_char(s, a)
        if ch then
          ch.health = ch.prototype.max_health
          local ammo = ch.get_inventory(defines.inventory.character_ammo)
          if ammo and ammo.get_item_count("firearm-magazine") < 10 then ammo.insert({ name = "firearm-magazine", count = 10 }) end
        end
        local n = ctx.remote("fo-ia3k", "trip", "player", a.id, DEST, 0, 3000)
        if n then st.cur[1] = { id = a.id, r = r } end
      end
      ctx.log(string.format("manche %d : %d PNJ part", r, #st.cur))
      return
    end
    local c = st.cur[1]
    if not c or c.done then return end
    local by = {}
    for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do by[a.id] = a end
    local a = by[c.id]
    if not a then
      c.done = true
      st.res[#st.res + 1] = { id = c.id, dead = true, spawned = c.spawned }
      ctx.log(string.format("manche %d PNJ %d : MORT", c.r, c.id))
      return
    end
    if not c.spawned then
      if a.state == "wait" and d2(a, { x = DEST, y = 0 }) <= 64 then
        c.biters = {}
        for j = 1, 2 do
          local p = s.find_non_colliding_position("medium-biter", { x = a.x + 58, y = a.y + (j - 1.5) * 4 }, 4, 0.5)
          local b = p and s.create_entity({ name = "medium-biter", position = p, force = "enemy" })
          if b then c.biters[#c.biters + 1] = b end
        end
        local ch = nearest_char(s, a)
        if ch then
          for _, b in ipairs(c.biters) do b.set_command({ type = defines.command.attack, target = ch, distraction = defines.distraction.none }) end
          c.spawned = t
          c.label_t0 = a.label_t or 0
        end
      end
      return
    end
    if not c.react_t and ((a.label and REACT[a.label] and (a.label_t or 0) > c.label_t0) or a.refuge) then c.react_t = t - c.spawned end
    if not c.hurt_t and a.hp < 1000 then c.hurt_t = t - c.spawned end
    if t - c.spawned >= 600 then
      c.done = true
      for _, b in ipairs(c.biters) do if b.valid then b.destroy() end end
      st.res[#st.res + 1] = { id = c.id, react_t = c.react_t, hurt_t = c.hurt_t, spawned = c.spawned }
      ctx.log(string.format("manche %d PNJ %d : reaction %s, premiere blessure %s", c.r, c.id,
        c.react_t and ("apres " .. c.react_t .. " ticks") or "JAMAIS", c.hurt_t and ("apres " .. c.hurt_t .. " ticks") or "aucune"))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local n, ok, dead = 0, 0, 0
    for _, x in ipairs(st.res) do
      if x.spawned then
        n = n + 1
        if x.dead then dead = dead + 1
        elseif x.react_t and (not x.hurt_t or x.react_t <= x.hurt_t) then ok = ok + 1 end
      end
    end
    ctx.log(string.format("FAIT %d mesures, reaction avant la premiere blessure %d, morts %d", n, ok, dead))
    ctx.check(n >= 6, "au moins 6 PNJ immobiles attaques", n)
    ctx.check(n > 0 and ok * 10 >= n * 9, "reaction avant la premiere blessure dans >= 90 % des cas", string.format("%d / %d", ok, n))
  end,
}
