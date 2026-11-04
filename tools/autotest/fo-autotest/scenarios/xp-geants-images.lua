-- Lot EXPERIMENTAUX (4/11), palier 3, session AVEC images (--captures) : les 5 géants à leur échelle de design (40 à 75 tuiles), à côté
-- d'un silo à fusée et d'une tourelle vanilla, de jour et de nuit, avec leur effet ; cibles soignées et reposées (l'effet continue).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache --ticks 1400" --qui EXPERIMENTAUX -- 1400 xp-geants-images <source>
local C = require("scenarios/xp_commun")

local IDS = { "cairn", "stylet", "trombe", "ixion", "tournesol" }
local Y = 3600
local CHECK = 1150 -- avant la dernière capture (la session avec images s'arrête à la dernière)
local function gx(i) return 9000 + (i - 1) * 200 end

local PLAN = {}
local function vue(tick, nom, x, y, zoom, nuit)
  PLAN[#PLAN + 1] = { tick = tick, nom = nom, x = x, y = y, zoom = zoom, nuit = nuit }
end
local T0 = 200
for i, id in ipairs(IDS) do
  local x = gx(i)
  local t = T0 + (i - 1) * 210
  vue(t, id .. "-jour", x + 6, Y - 24, 0.5)
  vue(t + 2, id .. "-nuit", x + 6, Y - 24, 0.5, true)
  vue(t + 4, id .. "-z1-pied", x - 8, Y - 6, 1)
  -- E-XP1 pour le corps `rendering` : la POSITION du géant 26 tuiles sous le bord bas de l'image (le corps, 40 tuiles et plus de haut,
  -- la couvre) ; un torse porté par le prototype y disparaît (essai e1, 4/11) : le sprite attaché reste-t-il dessiné ?
  vue(t + 6, id .. "-hors-ecran-sud", x, Y - 40, 1)
  for k = 0, 7 do vue(t + 20 + k * 14, string.format("%s-effet-%d", id, k), x + 14, Y - 14, 0.5) end
end
table.sort(PLAN, function(a, b) return a.tick < b.tick end)

local function garnit(s, list)
  for _, c in ipairs(list or {}) do
    if c.e and c.e.valid then
      c.e.health = c.e.prototype.max_health
    else
      c.e = s.create_entity({ name = "gun-turret", position = c.p, force = C.CIBLE })
    end
  end
end

return {
  description = "EXPERIMENTAUX : les 5 geants en images, effets, jour et nuit",
  check_tick = CHECK,
  shots_delay = PLAN[1].tick,

  init = function(ctx)
    local st = ctx.state()
    C.forces()
    remote.call("fo-xp", "journal", true)
    local s = ctx.surface()
    st.sites = {}
    local cible = game.forces[C.CIBLE]
    for i, id in ipairs(IDS) do
      local x = gx(i)
      ctx.prepare_area(x - 60, Y - 80, x + 80, Y + 40, "dry-dirt")
      for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { x - 120, Y - 140 }, { x + 160, Y + 120 } } })) do en.destroy() end
      local fname = "fo-xp-g-" .. id
      local f = game.forces[fname] or game.create_force(fname)
      cible.set_cease_fire(f, true)
      f.set_cease_fire(cible, false)
      game.forces.enemy.set_cease_fire(f, true)
      f.set_cease_fire(game.forces.enemy, true)
      remote.call("fo-robots", "set_age", fname, 15)
      -- repères vanilla : silo à fusée (9 × 9) et tourelle à balles, force neutre, à gauche
      s.create_entity({ name = "rocket-silo", position = { x - 30, Y - 2 }, force = "neutral" })
      s.create_entity({ name = "gun-turret", position = { x - 20, Y + 4 }, force = "neutral" })
      local site = { id = id, cibles = {} }
      for gy = 0, 3 do
        for g2 = 0, 2 do
          site.cibles[#site.cibles + 1] = { p = { x + 22 + g2 * 4, Y - 6 + gy * 4 } }
        end
      end
      garnit(s, site.cibles)
      site.g = s.create_entity({ name = "fo-xp-" .. id, position = { x, Y }, force = f, raise_built = true })
      ctx.check(site.g ~= nil and site.g.valid, id .. " : pose")
      st.sites[#st.sites + 1] = site
    end
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick % 10 == 0 then
      for _, site in ipairs(st.sites) do garnit(s, site.cibles) end
    end
  end,

  finish = function(ctx)
    local all = remote.call("fo-xp", "stats")
    for _, id in ipairs(IDS) do
      ctx.check(all[id].coups >= 1, id .. " : a agi pendant la session avec images", string.format("coups %d, degats %.0f", all[id].coups, all[id].degats))
    end
  end,

  shots = function(ctx, add)
    for i, p in ipairs(PLAN) do
      local suivant = PLAN[i + 1]
      add(p.nom, p.x, p.y, p.zoom, p.nuit and 0.5 or 0, { res = { 1600, 1000 }, cadence = suivant and math.max(1, suivant.tick - p.tick) or nil, aa = true })
    end
  end,
}
