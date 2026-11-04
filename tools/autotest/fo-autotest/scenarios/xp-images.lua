-- Lot EXPERIMENTAUX (3/11), palier 1, session AVEC joueur et images (--captures) : les 5 petits au zoom 1, à côté de sprites vanilla
-- (tourelle à balles, tourelle laser, gros déchiqueteur ; force neutre), de jour et de nuit, avec leurs effets ; et le joueur qui POSE une
-- tourelle depuis son curseur (build_from_cursor) et LANCE une capsule (use_from_cursor).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache --ticks 1500" --qui EXPERIMENTAUX -- 1500 xp-images <source>
-- Les cibles (force hostile qui ne tire pas) sont soignées à chaque tick et REPOSÉES quand elles meurent (passage i1 : un coup de Veilleuse
-- les tue toutes, plus rien ne tirait pendant les rafales) ; la Demi-Vie de jour et de nuit est une seconde unité, loin de tout ennemi.
local C = require("scenarios/xp_commun")

local CHECK = 980 -- la session avec images s'arrête à la dernière capture (i1 : pas de BILAN à 1 400)
local JOUEUR_X = C.x(6)

local PLAN = {}
local function vue(tick, nom, x, y, zoom, nuit)
  PLAN[#PLAN + 1] = { tick = tick, nom = nom, x = x, y = y, zoom = zoom or 1, nuit = nuit }
end
-- chaque petit : jour, nuit, puis une rafale d'effets ; vues centrées entre l'expérimental et ses cibles
local T0 = 300
for i, id in ipairs(C.IDS) do
  local x, d = C.x(i), C.DIST[id]
  local t = T0 + (i - 1) * 120
  local vx = id == "demi-vie" and C.x(8) + 6 or x + d / 2 - 6
  vue(t, id .. "-jour", vx, C.Y - 7, 1)
  vue(t + 2, id .. "-nuit", vx, C.Y - 7, 1, true)
  local ex = id == "demi-vie" and x + d - 4 or x + d / 2 -- la fusion a lieu sur les cibles (i3 : au bord de l'image)
  for k = 0, 5 do vue(t + 10 + k * 9, string.format("%s-effet-%d", id, k), ex, C.Y - 5, 1) end
  vue(t + 70, id .. "-z05", x + d / 2, C.Y - 6, 0.5)
end
vue(990, "joueur-pose-et-lance", JOUEUR_X + 10, C.Y - 6, 0.7)
table.sort(PLAN, function(a, b) return a.tick < b.tick end)

--- Cibles soignées, et reposées à leur place quand elles meurent.
local function garnit(s, list)
  for k, c in ipairs(list or {}) do
    if c.e and c.e.valid then
      c.e.health = c.e.prototype.max_health
    else
      c.e = s.create_entity({ name = "gun-turret", position = c.p, force = C.CIBLE })
    end
  end
end

local function places(list)
  local out = {}
  for _, e in ipairs(list) do out[#out + 1] = { e = e, p = { e.position.x, e.position.y } } end
  return out
end

return {
  description = "EXPERIMENTAUX : les 5 petits en images, joueur qui pose et lance",
  check_tick = CHECK,
  shots_delay = PLAN[1].tick,

  init = function(ctx)
    local st = ctx.state()
    C.forces()
    remote.call("fo-xp", "journal", true)
    local s = ctx.surface()
    st.sites = {}
    for i, id in ipairs(C.IDS) do
      local x = C.x(i)
      C.terrain(ctx, x)
      local d = C.DIST[id]
      local site = { id = id, x = x, cibles = places(C.cibles(s, x + d, C.Y, 3, 3)) }
      -- repères vanilla, force neutre, à gauche
      s.create_entity({ name = "gun-turret", position = { x - 10, C.Y + 3 }, force = "neutral" })
      s.create_entity({ name = "laser-turret", position = { x - 13, C.Y + 3 }, force = "neutral" })
      local b = s.create_entity({ name = "big-biter", position = { x - 11.5, C.Y - 2 }, force = "neutral" })
      if b then b.active = false end
      if id ~= "geode" and id ~= "demi-vie" then
        site.robot = s.create_entity({ name = "fo-xp-" .. id, position = { x, C.Y }, force = "player", raise_built = true })
      end
      st.sites[#st.sites + 1] = site
    end
    -- le site du joueur
    C.terrain(ctx, JOUEUR_X)
    st.cibles_joueur = places(C.cibles(s, JOUEUR_X + 40, C.Y, 3, 3))
    -- la Demi-Vie montrée de jour et de nuit : loin de tout ennemi, elle attend
    C.terrain(ctx, C.x(8))
    s.create_entity({ name = "gun-turret", position = { C.x(8) - 10, C.Y + 3 }, force = "neutral" })
    s.create_entity({ name = "laser-turret", position = { C.x(8) - 13, C.Y + 3 }, force = "neutral" })
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    local s = ctx.surface()
    for _, site in ipairs(st.sites) do garnit(s, site.cibles) end
    garnit(s, st.cibles_joueur)
    if t == 5 then remote.call("fo-xp", "lancer", "demi-vie", "player", C.x(8), C.Y) end
    -- attaquants : lancés juste avant leur fenêtre d'images, assez près pour agir pendant la rafale
    for i, site in ipairs(st.sites) do
      local fen = T0 + (i - 1) * 120
      if site.id == "geode" and t == fen - 220 then
        remote.call("fo-xp", "lancer", "geode", "player", site.x + 14, C.Y)
      elseif site.id == "demi-vie" and t == fen - 30 then
        remote.call("fo-xp", "lancer", "demi-vie", "player", site.x + C.DIST["demi-vie"] - 6, C.Y)
      end
    end
    local p = game.players[1]
    if not p or not p.character then return end
    if t == 20 then
      p.teleport({ JOUEUR_X - 5, C.Y + 5 })
    elseif t == 30 then
      p.cursor_stack.set_stack({ name = "fo-xp-mat-foudre", count = 1 })
      local ok = p.can_build_from_cursor({ position = { JOUEUR_X, C.Y } })
      p.build_from_cursor({ position = { JOUEUR_X, C.Y } })
      local m = ctx.surface().find_entities_filtered({ name = "fo-xp-mat-foudre", position = { JOUEUR_X, C.Y }, radius = 2 })[1]
      ctx.check(m ~= nil and m.force == p.force, "joueur : pose le Mat-Foudre depuis son curseur",
        string.format("peut %s, entite %s", tostring(ok), m and m.force.name or "aucune"))
      ctx.power(JOUEUR_X - 12, C.Y + 6)
    elseif t == 40 then
      p.cursor_stack.set_stack({ name = "fo-xp-geode", count = 2 })
      p.use_from_cursor({ JOUEUR_X + 16, C.Y - 4 })
      st.lance = t
    elseif t == 100 and st.lance then
      local g = ctx.surface().find_entities_filtered({ name = "fo-xp-geode", position = { JOUEUR_X + 16, C.Y - 4 }, radius = 20 })[1]
      ctx.check(g ~= nil and g.force == p.force, "joueur : lance une Geode (capsule), elle apparait de sa force",
        g and string.format("%s a (%.1f, %.1f)", g.force.name, g.position.x, g.position.y) or "aucune")
      ctx.check(p.cursor_stack.valid_for_read and p.cursor_stack.count == 1, "joueur : la capsule est consommee",
        p.cursor_stack.valid_for_read and tostring(p.cursor_stack.count) or "vide")
      p.teleport({ JOUEUR_X - 6, C.Y + 30 })
    end
  end,

  finish = function(ctx)
    local all = remote.call("fo-xp", "stats")
    for _, id in ipairs(C.IDS) do
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
