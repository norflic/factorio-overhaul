--[[
  Lot IA3-k (C3, D1) : la PEUR en moteur réel. Votre équipe (coffre en (2000, 0), zone pavée), cerveau retenu ; 4 PNJ
  par manche partent à 90 tuiles et y attendent. Une fois arrivés, chaque PNJ est mis dans la situation de la manche et
  2 petits déchiqueteurs naissent à 16 tuiles avec l'ordre de l'attaquer :
    - manches 1 et 2 : caractère neutre, vie mise à 35 % (sous le seuil de 40 %) ;
    - manches 3 et 4 : PRUDENT (prudence 1 250 : seuil 55 %), vie à 48 % ;
    - manches 5 et 6 : AUDACIEUX (prudence 600 : seuil 40 %), vie à 48 % ;
    - manche 7 : neutre, pleine vie, SANS munitions, déchiqueteurs à 26 tuiles.
  Mesures (relevé à chaque tick) : délai entre la mise en situation et la fuite engagée (refuge choisi par le mod), vie
  au moment de la fuite. Critères : neutre sous 40 % et sans munitions, fuite en <= 60 ticks dans >= 90 % des cas ;
  prudent à 48 % : fuite en <= 60 ticks dans >= 90 % ; un prudent fuit avec PLUS de vie qu'un audacieux (médianes).
  Les déchiqueteurs sont retirés 600 ticks après la mise en situation. Journal : [FO-IA3K-PEUR].
]]

local AX, AY = 2000, 0
local LANES = { -90, -30, 30, 90 }
local ROUND = 3600
local START = 600
local ROUNDS = 7
local CHECK = START + ROUNDS * ROUND + 60

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

local function kind_of(r)
  if r <= 2 then return "neutre" elseif r <= 4 then return "prudent" elseif r <= 6 then return "audacieux" end
  return "desarme"
end

local function median(t)
  if #t == 0 then return nil end
  local c = {}
  for i, v in ipairs(t) do c[i] = v end
  table.sort(c)
  local n = #c
  if n % 2 == 1 then return c[(n + 1) / 2] end
  return (c[n / 2] + c[n / 2 + 1]) / 2
end

local function find_char(s, id_pos)
  local list = s.find_entities_filtered({ position = id_pos, radius = 3, type = "character", force = "player" })
  return list[1]
end

return {
  description = "IA3-k C3 : peur (fuite blesse ou sans munitions, prudent contre audacieux)",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(AX - 20, AY - 150, AX + 160, AY + 150, "grass-1")
    ctx.check(ctx.call("war_setting", "fo-war-ia3-comportement", true) == true, "reglage fo-war-ia3-comportement allume")
    ctx.call("profiler", true)
    local chest = s.create_entity({ name = "fo-team-chest", position = { AX, AY }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if chest then
      for _, it in ipairs({ { "iron-plate", 300 }, { "pistol", 8 }, { "firearm-magazine", 100 } }) do chest.insert({ name = it[1], count = it[2] }) end
    end
    ctx.check(ctx.remote("fo-ia3k", "hold", "player", true) == true, "cerveau retenu")
    st.res = {}
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
      local k = kind_of(r)
      if k == "prudent" then ctx.remote("fo-ia3k", "set_character", "player", 1250, 1000)
      elseif k == "audacieux" then ctx.remote("fo-ia3k", "set_character", "player", 600, 1500)
      else ctx.remote("fo-ia3k", "set_character", "player", nil, nil) end
      local idle = {}
      for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do
        if not a.task and a.state ~= "walk" then idle[#idle + 1] = a end
      end
      st.cur = {}
      for i, y in ipairs(LANES) do
        local a = idle[i]
        if a then
          -- Munitions remises (la manche précédente a pu les retirer) : 10 chargeurs.
          local ch = find_char(s, { x = a.x, y = a.y })
          if ch then
            local ammo = ch.get_inventory(defines.inventory.character_ammo)
            if ammo and ammo.get_item_count("firearm-magazine") < 10 then ammo.insert({ name = "firearm-magazine", count = 10 }) end
            ch.health = ch.prototype.max_health
          end
          local n = ctx.remote("fo-ia3k", "trip", "player", a.id, AX + 90, y, 2400)
          if n then st.cur[#st.cur + 1] = { id = a.id, dest = { x = AX + 90, y = y }, kind = k, r = r } end
        end
      end
      ctx.log(string.format("manche %d (%s) : %d PNJ partent", r, k, #st.cur))
      return
    end
    local by = nil
    for _, c in ipairs(st.cur or {}) do
      if not c.done then
        by = by or (function()
          local m = {}
          for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do m[a.id] = a end
          return m
        end)()
        local a = by[c.id]
        if not a then
          c.done, c.dead = true, true
        elseif not c.t0 then
          -- Arrivé et en attente : mise en situation.
          if a.state == "wait" and d2(a, c.dest) <= 64 then
            local ch = find_char(s, { x = a.x, y = a.y })
            if ch then
              local maxh = ch.prototype.max_health
              if c.kind == "neutre" then ch.health = maxh * 0.35
              elseif c.kind == "prudent" or c.kind == "audacieux" then ch.health = maxh * 0.48
              else
                local ammo = ch.get_inventory(defines.inventory.character_ammo)
                if ammo then ammo.clear() end
                local main = ch.get_main_inventory()
                if main then main.remove({ name = "firearm-magazine", count = 1000 }) end
              end
              local dist = c.kind == "desarme" and 26 or 16
              c.biters = {}
              for j = 1, 2 do
                local p = s.find_non_colliding_position("small-biter", { x = a.x + dist, y = a.y + (j - 1.5) * 3 }, 4, 0.5)
                local b = p and s.create_entity({ name = "small-biter", position = p, force = "enemy" })
                if b then
                  b.set_command({ type = defines.command.attack, target = ch, distraction = defines.distraction.by_enemy })
                  c.biters[#c.biters + 1] = b.unit_number
                end
              end
              c.t0 = t
              c.hp0 = math.floor(ch.health / maxh * 1000 + 0.5)
            end
          end
        else
          if not c.tf and a.refuge then
            c.tf = t
            c.hpf = a.hp
          end
          if t - c.t0 >= 600 then
            for _, b in ipairs(s.find_entities_filtered({ position = { a.x, a.y }, radius = 60, name = "small-biter", force = "enemy" })) do
              if b.valid then b.destroy() end
            end
            c.done = true
            st.res[#st.res + 1] = { kind = c.kind, r = r, id = c.id, delay = c.tf and (c.tf - c.t0) or nil, hpf = c.hpf, hp0 = c.hp0 }
            ctx.log(string.format("manche %d PNJ %d (%s) : vie %d pour mille a la mise en situation, fuite %s%s", r, c.id, c.kind,
              c.hp0 or -1, c.tf and string.format("apres %d ticks", c.tf - c.t0) or "JAMAIS",
              c.hpf and string.format(" avec %d pour mille de vie", c.hpf) or ""))
          end
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local by = { neutre = {}, prudent = {}, audacieux = {}, desarme = {} }
    for _, x in ipairs(st.res) do by[x.kind][#by[x.kind] + 1] = x end
    local function fast(list)
      local n, ok = 0, 0
      for _, x in ipairs(list) do
        n = n + 1
        if x.delay and x.delay <= 60 then ok = ok + 1 end
      end
      return ok, n
    end
    local function hps(list)
      local out = {}
      for _, x in ipairs(list) do if x.hpf then out[#out + 1] = x.hpf end end
      return out
    end
    local okn, nn = fast(by.neutre)
    local okd, nd = fast(by.desarme)
    local okp, np = fast(by.prudent)
    local oka, na = fast(by.audacieux)
    local mp, ma = median(hps(by.prudent)), median(hps(by.audacieux))
    local stv = ctx.remote("fo-ia3k", "status", "player")
    ctx.log(string.format("FAIT fuite en <= 60 ticks : neutre a 35 %% %d/%d, sans munitions %d/%d, prudent a 48 %% %d/%d, audacieux a 48 %% %d/%d ; vie a la fuite (mediane) : prudent %s, audacieux %s ; refuges %s",
      okn, nn, okd, nd, okp, np, oka, na, tostring(mp), tostring(ma), stv and tostring(stv.stats.refuges) or "?"))
    ctx.check(nn + nd >= 8, "au moins 8 PNJ mis en situation (sous 40 % ou sans munitions)", nn + nd)
    ctx.check(nn + nd > 0 and (okn + okd) * 10 >= (nn + nd) * 9, "C3 : sous 40 % ou sans munitions, fuite en <= 1 s dans >= 90 % des cas",
      string.format("%d / %d", okn + okd, nn + nd))
    ctx.check(np > 0 and okp * 10 >= np * 9, "C3 : un prudent a 48 % fuit en <= 1 s", string.format("%d / %d", okp, np))
    ctx.check(mp ~= nil and (ma == nil or mp > ma), "C3 : un prudent fuit avec plus de vie qu'un audacieux (mediane)",
      string.format("prudent %s, audacieux %s", tostring(mp), tostring(ma)))
  end,
}
