-- Scénario greffé du lot ART-GEANTS (mandat de 10 h du DC, 11/11) : les géants EXPÉRIMENTAUX s'orientent-ils quand ils marchent ?
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui GEANTS-MARCHE -- 8200 geants-marche <source>          (journal, contrôles)
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui GEANTS-MARCHE --captures -- 0 geants-marche <source> (captures en marche)
-- Repris de titans-marche (F507). Cairn, Stylet, Trombe, Ixion et Tournesol, chacun dans sa force (âge 15 par « set_age »), chacun sur sa
-- piste de 120 tuiles, 8 jambes de 36 tuiles (E, S, O, N et diagonales) par son pilote automatique. Tous les 30 ticks : orientation, torse,
-- position, et le SPRITE du corps dessiné par le mod (rendering de factorio-overhaul ciblé sur l'entité, nom en « -corps » ou « -corps-dNN »).
-- Contrôles (Ixion, la roue qui roule : seul géant dont la silhouette dépend du sens de marche) : le corps est dessiné ; en marche, la pose
-- du corps (dNN, NN × 360/16 degrés, une roue est la même à 180° près) suit le déplacement (écart d'au plus 22,5°) dans au moins 80 % des
-- relevés ; au moins 4 poses vues. Les quatre autres (symétriques par dessin : pile de galets, lance verticale à 3 pans, entonnoir,
-- miroir tourné vers le soleil) sont journalisés seulement, comme le Bourdon et le Méga-Bourdon (cloches de révolution, posés par
-- « descendre » de fo-bourdon, menés par « aller » sur les mêmes 8 jambes à partir du tick T0_CLOCHE, après la descente). Journal : [FO-GEANTS-MARCHE].

local C = require("scenarios/rb0_common")

local X0, Y0 = 9000, 9000
local PISTE = 120
local JAMBE = 36
local T0 = 180
local JAMBE_MAX = 900          -- ticks au plus par jambe (le titan le plus lent : vitesse lue au banc)
local RELEVE = 30
local CHECK = 8000             -- avant la fin du banc (8 200 ticks : le dernier tick joué est 8 199)
local IDS = { "cairn", "stylet", "trombe", "ixion", "tournesol" }
-- les cloches (F517) : id du site -> variante de « descendre » (nil : le Bourdon)
local CLOCHES = { { id = "bourdon" }, { id = "mega-bourdon", variante = "mega" } }
local T0_CLOCHE = 720          -- la cloche est posée vers le tick 430 (megabourdon-vitrine)
local NSITES = #IDS + #CLOCHES
-- 8 jambes : (dx, dy) unitaires ; y croît vers le sud
local JAMBES = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 }, { 0.7071, -0.7071 }, { 0.7071, 0.7071 }, { -0.7071, 0.7071 }, { -0.7071, -0.7071 } }

--- Orientation (0 = nord, sens horaire, en tours) d'un déplacement (dx, dy) ; nil si immobile. (Mod de test : la trigonométrie est permise.)
local function cap(dx, dy)
  if math.abs(dx) + math.abs(dy) < 0.05 then return nil end
  local o = math.atan2(dx, -dy) / (2 * math.pi)
  if o < 0 then o = o + 1 end
  return o
end

--- Écart circulaire (en tours) entre deux orientations.
local function ecart(a, b)
  local d = math.abs(a - b) % 1
  return math.min(d, 1 - d)
end
-- poses du corps d'Ixion : 16 directions de marche, 8 poses (la roue est la même à 180° près : pose = direction mod 8)
local NDIRS, NPOSES = 16, 8
local CONTROLE = { ixion = true }

--- Sprite du corps dessiné par le mod principal sur l'entité : nom.
local function corps_de(e)
  for _, id in ipairs(rendering.get_all_ids("factorio-overhaul")) do
    if rendering.is_valid(id) and rendering.get_type(id) == "sprite" then
      local t = rendering.get_target(id)
      if t and t.entity == e then
        local a = rendering.get_sprite(id)
        if a and (a:find("%-corps$") or a:find("%-corps%-d%d+$")) then return a end
      end
    end
  end
  return nil
end

local function trouver(s, site)
  local l = s.find_entities_filtered({ force = site.force, type = "spider-vehicle" })
  return l[1]
end

return {
  description = "ART-GEANTS : les geants experimentaux s'orientent quand ils marchent (8 jambes, 5 geants)",
  base = nil,
  check_tick = CHECK,
  shots_delay = T0 + 240,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    st.sites, st.pret = {}, false
    game.map_settings.enemy_expansion.enabled = false
    game.map_settings.pollution.enabled = false
    ctx.prepare_area(X0 - 60, Y0 - 70, X0 + PISTE * (NSITES - 1) + 120, Y0 + 70, "lab-dark-1")   -- les vues débordent de 47 tuiles autour du centre de piste
    C.sans_ennemis(s, X0 - 200, Y0 - 200, X0 + PISTE * NSITES + 200, Y0 + 200)
    for k, id in ipairs(IDS) do
      local nom = "fo-xp-" .. id
      local site = { id = id, force = "gm-" .. id, x = X0 + PISTE * (k - 1), y = Y0, jambe = 0, releves = {}, dirs = {}, n = 0, ok = 0, anim_v0 = 0 }
      if not game.entity_prototypes[nom] then
        ctx.fail("(" .. id .. ") prototype present", nom)
      else
        C.force(site.force)
        ctx.remote("fo-robots", "set_age", site.force, 15)
        s.create_entity({ name = nom, position = { site.x, site.y }, force = site.force, raise_built = true })
        local e = trouver(s, site)
        site.nom = e and e.name
        local a = e and corps_de(e)
        ctx.check(e ~= nil and a ~= nil, "(" .. id .. ") geant pose, inscrit et dessine (corps)",
          string.format("entite %s, corps %s", tostring(site.nom), tostring(a)))
      end
      st.sites[#st.sites + 1] = site
    end
    for j, c in ipairs(CLOCHES) do
      local site = { id = c.id, force = "gm-" .. c.id, x = X0 + PISTE * (#IDS + j - 1), y = Y0, jambe = 0, releves = {}, dirs = {}, n = 0, ok = 0,
        t0 = T0_CLOCHE }
      C.force(site.force)
      site.cloche = remote.call("fo-bourdon", "descendre", site.force, site.x, site.y, 1, c.variante)
      local e = trouver(s, site)
      site.nom = e and e.name
      ctx.check(site.cloche ~= nil and e ~= nil, "(" .. c.id .. ") cloche descendue", string.format("id %s, entite %s", tostring(site.cloche), tostring(site.nom)))
      st.sites[#st.sites + 1] = site
    end
    st.pret = true
  end,

  tick = function(ctx, ev)
    local st = ctx.state()
    if not st.pret or ev.tick < T0 then return end
    local s = ctx.surface()
    if ev.tick == T0 then
      for _, site in ipairs(st.sites) do
        if site.cloche then remote.call("fo-bourdon", "muet", site.cloche, true) end
      end
    end
    for _, site in ipairs(st.sites) do
      local e = (ev.tick >= (site.t0 or T0)) and trouver(s, site)
      if e then
        -- jambe suivante : à l'arrivée (à 2 tuiles) ou après JAMBE_MAX ticks
        local arrive = site.cible and ((e.position.x - site.cible.x) ^ 2 + (e.position.y - site.cible.y) ^ 2 <= 4)
        if site.jambe == 0 or arrive or ev.tick - site.t_jambe >= JAMBE_MAX then
          if site.jambe < #JAMBES then
            site.jambe = site.jambe + 1
            local j = JAMBES[site.jambe]
            site.cible = { x = e.position.x + j[1] * JAMBE, y = e.position.y + j[2] * JAMBE }   -- depuis là où il est
            site.t_jambe = ev.tick
            if site.cloche then remote.call("fo-bourdon", "aller", site.cloche, site.cible.x, site.cible.y) else e.autopilot_destination = site.cible end
            ctx.log(string.format("%s jambe %d vers (%.1f, %.1f) au tick %d", site.id, site.jambe, site.cible.x, site.cible.y, ev.tick))
          elseif arrive or ev.tick - site.t_jambe >= JAMBE_MAX then
            site.fini = site.fini or ev.tick
          end
        end
        if ev.tick % RELEVE == 15 then
          local p = { x = e.position.x, y = e.position.y }
          local a = corps_de(e)
          local pose = a and tonumber(a:match("%-corps%-d(%d+)$"))
          local dep = site.prec and cap(p.x - site.prec.x, p.y - site.prec.y)
          if dep and not site.fini then
            site.n = site.n + 1
            -- une roue : pose p = direction p ou p + 8 (même silhouette à 180° près)
            if pose and math.min(ecart(pose / NDIRS, dep), ecart(pose / NDIRS + 0.5, dep)) <= 1 / NDIRS + 1e-6 then site.ok = site.ok + 1 end
          end
          if pose then site.dirs[pose] = true end
          if #site.releves < 300 then   -- chaque relevé (8 200 ticks : 273 au plus) : les planches recadrent les vues sur la position
            ctx.log(string.format("%s t=%d pos=(%.1f,%.1f) orientation=%.3f torse=%s vitesse=%.4f deplacement=%s corps=%s", site.id,
              ev.tick, p.x, p.y, e.orientation, tostring(e.torso_orientation), e.speed or -1, dep and string.format("%.3f", dep) or "nil", tostring(a)))
            site.releves[#site.releves + 1] = true
          end
          site.prec = p
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    for _, site in ipairs(st.sites) do
      local nd = 0
      for _ in pairs(site.dirs) do nd = nd + 1 end
      local part = site.n > 0 and site.ok / site.n or 0
      if CONTROLE[site.id] then
        ctx.check(site.n >= 20, "(" .. site.id .. ") le geant a marche (releves en mouvement)", site.n .. " releves")
        ctx.check(part >= 0.8, "(" .. site.id .. ") la pose du corps suit la marche (>= 80 % des releves, a 22,5 degres et 180 degres pres)",
          string.format("%d / %d = %.0f %%", site.ok, site.n, part * 100))
        ctx.check(nd >= 4, "(" .. site.id .. ") au moins 4 poses du corps vues", nd .. " pose(s)")
      end
      ctx.log(string.format("[FO-GEANTS-MARCHE] %s : releves %d, corps dans la direction %d (%.0f %%), poses vues %d, fin jambes %s",
        site.id, site.n, site.ok, part * 100, nd, tostring(site.fini)))
    end
  end,

  --- Captures (session avec images) : la piste entière de chaque titan (jambes E, S, O, N puis diagonales : x de 0 à 51, y de -25 à 36
  --- autour du départ ; le corps monte jusqu'à 36 tuiles au-dessus du pied), une vue par titan toutes les ~150 ticks pendant les jambes
  --- (attentes de 10 ticks entre deux tours de vues) : le titan est toujours dans le cadre, quelle que soit l'heure exacte de la vue.
  shots = function(ctx, add)
    local st = ctx.state()
    for k = 1, 12 do
      for _, site in ipairs(st.sites or {}) do
        add(string.format("tour%02d-%s", k, site.id), site.x + 25, site.y - 14, 0.3, 0, { res = { 1200, 1200 }, info = false, aa = true })
      end
      for w = 1, 11 do add(string.format("attente-%02d-%02d", k, w), X0, Y0 - 300, 1, 0, { res = { 16, 16 }, info = false }) end
    end
  end,
}
