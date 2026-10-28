--[[
  Lot FUITE : l'ARRÊT (alerte) garde les yeux ouverts, en moteur réel. Votre équipe (coffre en (2000, 0), zone pavée), cerveau
  retenu ; UN PNJ par manche (les autres PNJ ne voient pas
  la scène : pas de menace partagée) part en tournée vers (2260, 0). Quand le PNJ marche à plus de 40 tuiles du coffre, 2 moyens
  déchiqueteurs (force pesée 2 : pas de combat en surnombre) naissent 54 tuiles devant lui, IMMOBILES : hors de portée + marge (38), sur sa route, le PNJ s'arrête (alerte,
  180 ticks). Dès que l'arrêt est engagé, les déchiqueteurs reçoivent l'ordre d'attaquer le PNJ (vitesse 0,24 : ils franchissent
  la marge en une trentaine de ticks). Avant le lot, le PNJ restait aveugle jusqu'à la fin de l'arrêt (ou jusqu'à sa première
  blessure) ; maintenant son arrêt est rompu à la pensée suivante.
  Mesure (relevé à chaque tick) : distance du déchiqueteur le plus proche à la première réaction (étiquette alerte exceptée)
  posée après l'ordre d'attaque ; PNJ mort ou non. Critères : réaction à >= 14 tuiles dans >= 90 % des cas, 0 mort.
  Journal : [FO-IA3K-ARRET].
]]

local AX = 2000
local ROUND = 1800
local START = 600
local ROUNDS = 8
local CHECK = START + ROUNDS * ROUND + 60
local REACT = { detour = true, ["demi-tour"] = true, fuite = true, combat = true }

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

-- Le personnage le plus proche de la position du PNJ (les PNJ au repos sont tous serrés autour du coffre).
local function nearest_char(s, a)
  local best, bd = nil, nil
  for _, c in ipairs(s.find_entities_filtered({ position = { a.x, a.y }, radius = 4, type = "character", force = "player" })) do
    local d = d2(c.position, a)
    if not bd or d < bd then best, bd = c, d end
  end
  return best
end

return {
  description = "FUITE : l'arret (alerte) est rompu par des unites qui arrivent",
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
    -- Le refuge : deux mitrailleuses de votre équipe au QG (sinon des déchiqueteurs de 0,24 tuile/tick rattrapent tout PNJ à pied).
    for _, y in ipairs({ -5, 5 }) do
      local tu = s.create_entity({ name = "gun-turret", position = { AX + 8, y }, force = "player", raise_built = true })
      ctx.check(tu ~= nil, "mitrailleuse de refuge posee")
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
      for _, c in ipairs(st.cur) do
        if not c.done then
          c.done = true
          st.res[#st.res + 1] = { id = c.id, spawned = c.spawned, react_d = c.react_d, dead = c.dead, unset = not c.go }
        end
      end
      ctx.remote("fo-ia3k", "forget", "player")
      ctx.remote("fo-ia3k", "set_character", "player", nil, nil)
      local idle = {}
      for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do
        if not a.task and a.state ~= "walk" then idle[#idle + 1] = a end
      end
      st.cur = {}
      for _, b in ipairs(s.find_entities_filtered({ area = { { AX - 20, -150 }, { AX + 300, 150 } }, force = "enemy" })) do
        if b.valid then b.destroy() end
      end
      local a = idle[1]
      if a then
        -- Manches indépendantes : pleine vie et munitions remises (la manche précédente a pu blesser ce PNJ).
        local ch = nearest_char(s, a)
        if ch then
          ch.health = ch.prototype.max_health
          local ammo = ch.get_inventory(defines.inventory.character_ammo)
          if ammo and ammo.get_item_count("firearm-magazine") < 10 then ammo.insert({ name = "firearm-magazine", count = 10 }) end
        end
        local n = ctx.remote("fo-ia3k", "trip", "player", a.id, AX + 260, 0, 2400)
        if n then st.cur[#st.cur + 1] = { id = a.id, lane = 0, r = r } end
      end
      ctx.log(string.format("manche %d : %d PNJ part%s", r, #st.cur, a and string.format(" (PNJ %d, vie %d pour mille avant remise)", a.id, a.hp or -1) or ""))
      return
    end
    local by = nil
    for _, c in ipairs(st.cur) do
      if not c.done then
        by = by or (function()
          local m = {}
          for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do m[a.id] = a end
          return m
        end)()
        local a = by[c.id]
        if not a then
          c.done, c.dead = true, true
          st.res[#st.res + 1] = { id = c.id, spawned = c.spawned, react_d = c.react_d, dead = true, unset = not c.go }
          ctx.log(string.format("manche %d PNJ %d : MORT", c.r, c.id))
        elseif not c.spawned then
          if a.state == "walk" and a.x >= AX + 40 and a.x <= AX + 200 then
            c.biters = {}
            for j = 1, 2 do
              local p = s.find_non_colliding_position("medium-biter", { x = a.x + 54, y = a.y + (j - 1.5) * 4 }, 4, 0.5)
              local b = p and s.create_entity({ name = "medium-biter", position = p, force = "enemy" })
              if b then
                b.set_command({ type = defines.command.stop, ticks_to_wait = 1000000, distraction = defines.distraction.none })
                c.biters[#c.biters + 1] = b
              end
            end
            c.spawned = t
          end
        elseif not c.go then
          if t - c.spawned > 400 then
            c.done = true
            for _, b in ipairs(c.biters) do if b.valid then b.destroy() end end
            st.res[#st.res + 1] = { id = c.id, spawned = c.spawned, unset = true }
            ctx.log(string.format("manche %d PNJ %d : jamais arrete (pas d'alerte en 400 ticks)", c.r, c.id))
          elseif a.hold then
            local ch = nearest_char(s, a)
            if ch then
              for _, b in ipairs(c.biters) do
                if b.valid then b.set_command({ type = defines.command.attack, target = ch, distraction = defines.distraction.none }) end
              end
              c.go = t
              c.label_t0 = a.label_t or 0
            end
          end
        else
          local near = 1e9
          for _, b in ipairs(c.biters) do
            if b.valid then
              local d = math.sqrt(d2(b.position, a))
              if d < near then near = d end
            end
          end
          if not c.react_d and a.label and REACT[a.label] and (a.label_t or 0) > c.label_t0 or (not c.react_d and a.refuge) then
            c.react_d, c.react_t = near, t - c.go
          end
          if t - c.go >= 600 or near > 1e8 then
            c.done = true
            for _, b in ipairs(c.biters) do if b.valid then b.destroy() end end
            st.res[#st.res + 1] = { id = c.id, spawned = c.spawned, react_d = c.react_d, react_t = c.react_t }
            ctx.log(string.format("manche %d PNJ %d : reaction %s", c.r, c.id,
              c.react_d and string.format("apres %d ticks, dechiqueteur a %.1f tuiles", c.react_t, c.react_d) or "JAMAIS"))
          end
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    for _, c in ipairs(st.cur) do
      if not c.done then
        st.res[#st.res + 1] = { id = c.id, spawned = c.spawned, react_d = c.react_d, dead = c.dead, unset = not c.go }
      end
    end
    local n, ok, dead, unset = 0, 0, 0, 0
    for _, x in ipairs(st.res) do
      if x.unset then unset = unset + 1
      else
        n = n + 1
        if x.react_d and x.react_d >= 14 then ok = ok + 1 end
        if x.dead then dead = dead + 1 end
      end
    end
    ctx.log(string.format("FAIT %d mesures, reaction a >= 14 tuiles %d, morts %d, jamais arretes %d", n, ok, dead, unset))
    ctx.check(n >= 6, "au moins 6 PNJ arretes puis attaques", n)
    ctx.check(n > 0 and ok * 10 >= n * 9, "arret rompu : reaction a >= 14 tuiles dans >= 90 % des cas", string.format("%d / %d", ok, n))
    ctx.check(dead == 0, "aucun PNJ mort", dead)
  end,
}
