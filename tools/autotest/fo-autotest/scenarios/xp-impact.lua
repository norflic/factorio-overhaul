-- Lot EXPERIMENTAUX-PUISSANCE (5/11), design IMPACT, session AVEC images : la TRACE d'une salve de zone (cratère et sol brûlé, réponse du DC
-- du 5/11 « cratère + sol brûlé ») aux états clés, à côté de la bombe atomique VANILLA sur la même base (comparaison exigée avant série).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache --ticks 1000" --qui XP-PUISSANCE -- 1000 xp-impact <source>
-- Trois sites, la même base (une tourelle au centre, lampes tous les 3 tuiles dans 60 tuiles) : (1) la Tournesol (âge 14 : zone 75, cratère
-- 12,5), (2) le Couronné de robotsjeu (âge 15 : zone 90, cratère 15), (3) une bombe atomique vanilla qui éclate au centre.
-- Chaque site part à un tick connu S (les géants balaient toutes les 30 ticks : posés 9 ticks avant un balayage, ils tirent à ce balayage) :
-- S1 = 240, S2 = 270, S3 = 331 (bombe créée à 1 tuile du centre au tick 330). États : avant, l'onde (S + 3, 8, 15, 30), juste après (1 s),
-- 10 s après, de jour puis de nuit, et le cratère de près. Contrôles (sans juger l'image) : les deux bases des géants rasées, chaque cratère
-- posé ; la bombe vanilla, de rayon plus court, n'a pas à raser la sienne (comptée, sans contrôle).
local C = require("scenarios/xp_commun")

local CHECK = 900
local Y = 5200
local R = 60
local SITES = { { id = "tournesol", x = 13000, S = 240, pose = 231 }, { id = "crowned", x = 13400, S = 270, pose = 261 },
  { id = "vanilla", x = 13800, S = 331, pose = 330 } }
local DX = 50 -- l'unité à 50 tuiles à l'ouest du centre de la base

local PLAN = {}
local pris = {}
local function vue(tick, nom, x, y, zoom, nuit)
  while pris[tick] do tick = tick + 1 end -- une capture par tick (la session les prend l'une après l'autre)
  pris[tick] = true
  PLAN[#PLAN + 1] = { tick = tick, nom = nom, x = x, y = y, zoom = zoom, nuit = nuit }
end
for _, s in ipairs(SITES) do
  local cx, S = s.x + DX, s.S
  vue(S - 12, s.id .. "-0-avant", cx - 15, Y, 0.3)
  vue(S + 3, s.id .. "-1-onde-3", cx - 15, Y, 0.3)
  vue(S + 8, s.id .. "-2-onde-8", cx - 15, Y, 0.3)
  vue(S + 15, s.id .. "-3-onde-15", cx - 15, Y, 0.3)
  vue(S + 30, s.id .. "-4-onde-30", cx - 15, Y, 0.3)
  vue(S + 60, s.id .. "-5-apres-1s", cx - 15, Y, 0.3)
  vue(S + 600, s.id .. "-6-apres-10s", cx - 15, Y, 0.3)
  vue(S + 602, s.id .. "-7-apres-10s-nuit", cx - 15, Y, 0.3, true)
  vue(S + 604, s.id .. "-8-cratere-z1", cx, Y, 1)
end
table.sort(PLAN, function(a, b) return a.tick < b.tick end)

local function base(s, cx)
  local n = 0
  s.create_entity({ name = "gun-turret", position = { cx, Y }, force = C.CIBLE })
  for ix = -R, R, 3 do
    for iy = -R, R, 3 do
      if ix * ix + iy * iy <= R * R and not (math.abs(ix) <= 3 and math.abs(iy) <= 3) then
        if s.create_entity({ name = "small-lamp", position = { cx + ix + 0.5, Y + iy + 0.5 }, force = C.CIBLE }) then n = n + 1 end
      end
    end
  end
  return n + 1
end

local function restants(s, cx)
  return s.count_entities_filtered({ position = { cx, Y }, radius = R + 2, force = C.CIBLE })
end

return {
  description = "EXPERIMENTAUX-PUISSANCE : trace d'une salve de zone (cratere, sol brule) contre la bombe atomique vanilla",
  check_tick = CHECK,
  shots_delay = PLAN[1].tick,

  init = function(ctx)
    local st = ctx.state()
    C.forces()
    remote.call("fo-xp", "journal", true)
    ctx.call("war_setting", "fo-war-robots-cap", 400)
    local s = ctx.surface()
    s.freeze_daytime = true
    s.daytime = 0
    local cible = game.forces[C.CIBLE]
    st.n = {}
    for i, site in ipairs(SITES) do
      local cx = site.x + DX
      ctx.prepare_area(site.x - 30, Y - R - 30, cx + R + 30, Y + R + 30, "dry-dirt")
      for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { site.x - 120, Y - 200 }, { cx + 200, Y + 200 } } })) do en.destroy() end
      local fname = "fo-xp-impact-" .. i
      local f = game.forces[fname] or game.create_force(fname)
      cible.set_cease_fire(f, true)
      f.set_cease_fire(cible, false)
      game.forces.enemy.set_cease_fire(f, true)
      f.set_cease_fire(game.forces.enemy, true)
      remote.call("fo-robots", "set_age", fname, 15)
      st.n[i] = base(s, cx)
    end
    ctx.log(string.format("bases : %d, %d, %d entites", st.n[1], st.n[2], st.n[3]))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == SITES[1].pose then
      st.g = s.create_entity({ name = "fo-xp-tournesol", position = { SITES[1].x, Y }, force = "fo-xp-impact-1", raise_built = true })
      ctx.log(string.format("tick %d : tournesol %s", e.tick, tostring(st.g and st.g.valid)))
    elseif e.tick == SITES[2].pose then
      st.ro = remote.call("fo-robots", "spawn", "fo-xp-impact-2", "crowned", SITES[2].x, Y)
      ctx.log(string.format("tick %d : couronne %s", e.tick, tostring(st.ro)))
    elseif e.tick == SITES[3].pose then
      local cx3 = SITES[3].x + DX
      st.nuke = s.create_entity({ name = "atomic-rocket", position = { cx3 - 1, Y }, target = { cx3, Y }, speed = 1, force = "fo-xp-impact-3" })
      ctx.log(string.format("tick %d : bombe %s", e.tick, tostring(st.nuke ~= nil)))
    end
    if e.tick % 30 == 0 and e.tick <= CHECK then
      for i, site in ipairs(SITES) do
        local n = restants(s, site.x + DX)
        if n == 0 and not st["rasee" .. i] then st["rasee" .. i] = e.tick end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    for i, site in ipairs(SITES) do
      local cx = site.x + DX
      local n = restants(s, cx)
      if site.id == "vanilla" then
        ctx.log(string.format("vanilla : %d restantes sur %d (bombe atomique, sans controle)", n, st.n[i]))
      else
        ctx.check(n == 0, site.id .. " : base rasee", string.format("%d restantes sur %d, rasee au tick %s", n, st.n[i], tostring(st["rasee" .. i])))
      end
      local tile = s.get_tile(cx, Y)
      ctx.check(tile and tile.name == "nuclear-ground", site.id .. " : cratere au point vise", tile and tile.name or "?")
    end
  end,

  shots = function(ctx, add)
    for i, p in ipairs(PLAN) do
      local suivant = PLAN[i + 1]
      add(p.nom, p.x, p.y, p.zoom, p.nuit and 0.5 or 0, { res = { 1600, 1000 }, cadence = suivant and math.max(1, suivant.tick - p.tick) or nil, aa = true })
    end
  end,
}
