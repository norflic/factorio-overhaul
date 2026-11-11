-- Lot LEVIATHAN-SEG (mandat du DC, 11/11), session AVEC images (--captures) : un Léviathan ARTICULÉ (tête = entité, segments et queue =
-- `rendering` qui suivent sa trajectoire) fait le tour d'un carré de 44 tuiles (quatre virages à 90°) puis coupe en diagonale.
-- Contrôles (moteur réel) : la tête pose ses pièces (4 segments et la queue, trois couches chacune, ciblées sur elle) ; en ligne droite
-- les pièces sont alignées derrière la tête aux distances de la règle ; dans un virage, les pièces de devant ont déjà tourné et celles de
-- derrière gardent l'ancienne direction (images de directions différentes) ; au moins 6 directions prises sur le parcours.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache --ticks 2400" --qui LEVIATHAN-SEG -- 2400 leviathan-seg <source>
-- Journal : [FO-AUTOTEST] (ctx.log), captures leviathan-<k>.png.
local X0, Y0 = 9600, -4200
local COTE = 44
local CHECK = 2300
local NOM = "fo-titan-leviathan-1"
local DIST = { 6, 11, 16, 21, 26 }          -- T.LEVIATHAN.segmente : premier 6, espacement 5, queue 5 (contrôlé hors jeu, tests/serpent_test.lua)

local PLAN = {}
for k, t in ipairs({ 240, 420, 600, 780, 960, 1140, 1320, 1500, 1680, 1860, 2040, 2220 }) do
  PLAN[#PLAN + 1] = { tick = t, nom = string.format("leviathan-%02d", k), x = X0 + COTE / 2, y = Y0 + COTE / 2 - 8, zoom = 0.34 }
end

local function pieces(e)
  local l = {}
  for _, id in ipairs(rendering.get_all_ids("factorio-overhaul")) do
    if rendering.is_valid(id) and rendering.get_type(id) == "sprite" then
      local tg = rendering.get_target(id)
      local sp = rendering.get_sprite(id)
      if tg and tg.entity == e and sp and (sp:find("%-segment%-") or sp:find("%-queue%-")) then
        l[#l + 1] = { id = id, sprite = sp, dx = tg.entity_offset and (tg.entity_offset.x or tg.entity_offset[1]) or 0,
          dy = tg.entity_offset and (tg.entity_offset.y or tg.entity_offset[2]) or 0 }
      end
    end
  end
  return l
end

local function corps(l)
  local out = {}
  for _, p in ipairs(l) do
    if p.sprite:find("%-corps$") then out[#out + 1] = p end
  end
  table.sort(out, function(a, b) return (a.dx * a.dx + a.dy * a.dy) < (b.dx * b.dx + b.dy * b.dy) end)
  return out
end

local function direction_de(sprite) return tonumber(sprite:match("%-(%d+)%-corps$")) end

--- Direction de l'image du corps animé de la TÊTE (animation <préfixe>leviathan-<stade>-<anim>-<dir>-corps ciblée sur l'entité).
local function direction_tete(e)
  for _, id in ipairs(rendering.get_all_ids("factorio-overhaul")) do
    if rendering.is_valid(id) and rendering.get_type(id) == "animation" then
      local tg = rendering.get_target(id)
      local a = rendering.get_animation(id)
      if tg and tg.entity == e and a and a:find("%-corps$") then return tonumber(a:match("%-(%d+)%-corps$")) end
    end
  end
end

-- 16 directions (0 = nord, sens horaire, y vers le sud) : direction d'un déplacement par produit scalaire maximal
local DIRS16 = {
  { 0.0, -1.0 }, { 0.38268, -0.92388 }, { 0.70711, -0.70711 }, { 0.92388, -0.38268 }, { 1.0, 0.0 }, { 0.92388, 0.38268 },
  { 0.70711, 0.70711 }, { 0.38268, 0.92388 }, { 0.0, 1.0 }, { -0.38268, 0.92388 }, { -0.70711, 0.70711 }, { -0.92388, 0.38268 },
  { -1.0, 0.0 }, { -0.92388, -0.38268 }, { -0.70711, -0.70711 }, { -0.38268, -0.92388 },
}
local function direction16(dx, dy)
  local best, bi = nil, nil
  for i, v in ipairs(DIRS16) do
    local d = dx * v[1] + dy * v[2]
    if best == nil or d > best then best, bi = d, i - 1 end
  end
  return bi
end

local function ecart16(a, b)
  local d = math.abs(a - b) % 16
  return math.min(d, 16 - d)
end

return {
  description = "LEVIATHAN-SEG : le Leviathan articule (tete, segments, queue) suit sa trajectoire dans quatre virages",
  check_tick = CHECK,
  shots_delay = PLAN[1].tick,

  init = function(ctx)
    local st = ctx.state()
    game.map_settings.enemy_expansion.enabled = false
    local s = ctx.surface()
    ctx.prepare_area(X0 - 50, Y0 - 50, X0 + COTE + 50, Y0 + COTE + 50, "dry-dirt")
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 250, Y0 - 250 }, { X0 + 300, Y0 + 300 } } })) do en.destroy() end
    if not game.entity_prototypes[NOM] then
      ctx.fail("prototype du Leviathan present", NOM)
      return
    end
    remote.call("fo-robots", "set_age", "player", 15)   -- sinon le plafond des géants (âge 1 : 0 géant) retire le titan
    st.g = s.create_entity({ name = NOM, position = { X0, Y0 }, force = "player", raise_built = true })
    st.tours = 0
    st.vus = {}
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    if not (st.g and st.g.valid) then
      -- remplacement de palier par le script (âge 15) : la nouvelle tête est le titan du joueur le plus proche du départ
      local s = ctx.surface()
      local l = s.find_entities_filtered({ type = "spider-vehicle", force = "player", area = { { X0 - 80, Y0 - 80 }, { X0 + COTE + 80, Y0 + COTE + 80 } } })
      for _, c in ipairs(l) do
        if c.name:find("^fo%-titan%-leviathan%-") then st.g = c end
      end
      if not (st.g and st.g.valid) then return end
    end
    local g = st.g
    if t == 60 then
      st.palier = g.name
      local p = pieces(g)
      ctx.check(#p == 15, "a la pose : 4 segments et la queue, trois couches chacun, cibles sur la tete", tostring(#p) .. " objets de rendu (" .. g.name .. ")")
      local c = corps(p)
      local ok = #c == 5
      for k, q in ipairs(c) do
        local d = math.sqrt(q.dx * q.dx + q.dy * q.dy)
        if math.abs(d - DIST[k]) > 0.6 then ok = false end
      end
      ctx.check(ok, "a la pose : pieces en ligne droite derriere la tete aux distances de la regle (6, 11, 16, 21, 26 tuiles)")
      g.autopilot_destination = { X0 + COTE, Y0 }
      g.add_autopilot_destination({ X0 + COTE, Y0 + COTE })
      g.add_autopilot_destination({ X0, Y0 + COTE })
      g.add_autopilot_destination({ X0, Y0 })
      g.add_autopilot_destination({ X0 + COTE, Y0 + COTE })
    end
    if t > 60 and t % 30 == 0 then
      local c = corps(pieces(g))
      local dirs = {}
      for _, q in ipairs(c) do
        local d = direction_de(q.sprite)
        if d then dirs[#dirs + 1] = d end
      end
      local distinctes = {}
      local n = 0
      for _, d in ipairs(dirs) do
        if not distinctes[d] then distinctes[d] = true; n = n + 1 end
      end
      if n >= 2 then st.virage = (st.virage or 0) + 1 end
      for _, d in ipairs(dirs) do st.vus[d] = true end
      -- la tête regarde où elle va : image de la tête contre direction du déplacement sur 30 ticks, en ligne droite (même direction de
      -- déplacement deux relevés de suite), à un cran près
      local dt = direction_tete(g)
      local p0 = st.p0
      st.p0 = { x = g.position.x, y = g.position.y }
      if p0 then
        local dx, dy = g.position.x - p0.x, g.position.y - p0.y
        local dm = (dx * dx + dy * dy > 1.0) and direction16(dx, dy) or nil
        if dm and dm == st.dm and dt then
          if ecart16(dt, dm) <= 1 then st.tete_ok = (st.tete_ok or 0) + 1 else
            st.tete_ko = (st.tete_ko or 0) + 1
            ctx.log(string.format("t%d tete : image %d, deplacement %d", t, dt, dm))
          end
        end
        st.dm = dm
      end
      if t % 150 == 0 then
        ctx.log(string.format("t%d tete (%.1f, %.1f) %s vitesse %.3f orientation %.3f direction de la tete %s, des pieces [%s]", t, g.position.x - X0,
          g.position.y - Y0, g.name, g.speed, g.orientation, tostring(dt), table.concat(dirs, " ")))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local n = 0
    for d = 0, 15 do if st.vus[d] then n = n + 1 end end
    ctx.check(st.g and st.g.valid, "le Leviathan vit jusqu'au controle")
    ctx.check((st.virage or 0) >= 3, "dans les virages, les pieces de devant ont tourne et celles de derriere pas encore (directions differentes)",
      tostring(st.virage or 0) .. " releves")
    ctx.check(n >= 6, "les pieces prennent au moins 6 directions differentes sur le parcours", tostring(n) .. " directions vues")
    ctx.check((st.tete_ok or 0) >= 10 and (st.tete_ko or 0) == 0, "en ligne droite, la tete regarde ou elle va (direction de son deplacement, a un cran pres)",
      string.format("%d releves justes, %d faux", st.tete_ok or 0, st.tete_ko or 0))
    ctx.check(game.tick >= CHECK, "la partie joue jusqu'au controle", "tick " .. game.tick)
  end,

  shots = function(ctx, add)
    for i, p in ipairs(PLAN) do
      local suivant = PLAN[i + 1]
      add(p.nom, p.x, p.y, p.zoom, 0, { res = { 1800, 1200 }, cadence = suivant and math.max(1, suivant.tick - p.tick) or nil, aa = true })
    end
  end,
}
