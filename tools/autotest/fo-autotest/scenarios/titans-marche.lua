-- Scénario greffé du lot ART-16DIR (mandat de 10 h du DC, 10/11) : les titans ALLIÉS s'orientent-ils quand ils marchent ?
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui TITANS-MARCHE -- 8200 titans-marche <source>          (journal, contrôles)
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui TITANS-MARCHE --captures -- 0 titans-marche <source> (captures en marche)
-- Juggernaut, Sentinelle, Ravageur et Léviathan, chacun dans sa force (âge 15 par l'aide des bancs « set_age » : palier 6, plafond des
-- géants de 3 par force), chacun sur sa piste de 120 tuiles. Chacun parcourt 8 jambes de 36 tuiles (E, S, O, N, NE, SE, SO, NO) par son
-- pilote automatique (autopilot_destination, comme la télécommande du joueur). Tous les 30 ticks (décalés de 15 sur le balayage du mod) :
-- orientation, orientation du torse, vitesse, position, et l'animation du CORPS dessinée par le mod (rendering de factorio-overhaul ciblé
-- sur l'entité, couche « corps ») avec sa vitesse d'images. Contrôles : chaque titan est dessiné ; en marche, la direction du corps suit
-- celle du déplacement (écart d'au plus 45°, la direction du corps lue sur ses N directions) dans au moins 80 % des relevés ; au moins
-- 4 directions vues ;
-- la vitesse d'images est non nulle en marche. Journal : [FO-TITANS-MARCHE].

local C = require("scenarios/rb0_common")

local X0, Y0 = 9000, 9000
local PISTE = 120
local JAMBE = 36
local T0 = 180
local JAMBE_MAX = 900          -- ticks au plus par jambe (le titan le plus lent : vitesse lue au banc)
local RELEVE = 30
local CHECK = 8000             -- avant la fin du banc (8 200 ticks : le dernier tick joué est 8 199)
local IDS = { "juggernaut", "sentinelle", "ravageur", "leviathan" }
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
-- directions des feuilles de chaque titan (ART-16DIR : 16 pour Juggernaut, Sentinelle, Ravageur ; LEVIATHAN-SEG : 16 pour la tête ; 8 pour tous avant
-- ce lot : la table est mise à 8 partout quand on mesure une source à 8 directions)
local NDIRS = { juggernaut = 16, sentinelle = 16, ravageur = 16, leviathan = 16 }   -- LEVIATHAN-SEG : tête en 16 directions

--- Animation du corps dessinée par le mod principal sur l'entité : nom, vitesse d'images.
local function corps_de(e)
  for _, id in ipairs(rendering.get_all_ids("factorio-overhaul")) do
    if rendering.is_valid(id) and rendering.get_type(id) == "animation" then
      local t = rendering.get_target(id)
      if t and t.entity == e then
        local a = rendering.get_animation(id)
        if a and a:find("%-corps$") then return a, rendering.get_animation_speed(id) end
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
  description = "ART-16DIR : les titans allies s'orientent et s'animent quand ils marchent (8 jambes, 4 titans)",
  base = nil,
  check_tick = CHECK,
  shots_delay = T0 + 240,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    st.sites, st.pret = {}, false
    game.map_settings.enemy_expansion.enabled = false
    game.map_settings.pollution.enabled = false
    ctx.prepare_area(X0 - 60, Y0 - 70, X0 + PISTE * (#IDS - 1) + 120, Y0 + 70, "lab-dark-1")   -- les vues débordent de 47 tuiles autour du centre de piste
    C.sans_ennemis(s, X0 - 200, Y0 - 200, X0 + PISTE * #IDS + 200, Y0 + 200)
    for k, id in ipairs(IDS) do
      local nom = "fo-titan-" .. id .. "-1"
      local site = { id = id, force = "tm-" .. id, x = X0 + PISTE * (k - 1), y = Y0, jambe = 0, releves = {}, dirs = {}, n = 0, ok = 0, anim_v0 = 0 }
      if not game.entity_prototypes[nom] then
        ctx.fail("(" .. id .. ") prototype present", nom)
      else
        C.force(site.force)
        ctx.remote("fo-robots", "set_age", site.force, 15)
        s.create_entity({ name = nom, position = { site.x, site.y }, force = site.force, raise_built = true })
        local e = trouver(s, site)
        site.nom = e and e.name
        local a = e and corps_de(e)
        ctx.check(e ~= nil and a ~= nil, "(" .. id .. ") titan pose, inscrit et dessine (corps anime)",
          string.format("entite %s, corps %s", tostring(site.nom), tostring(a)))
      end
      st.sites[#st.sites + 1] = site
    end
    st.pret = true
  end,

  tick = function(ctx, ev)
    local st = ctx.state()
    if not st.pret or ev.tick < T0 then return end
    local s = ctx.surface()
    for _, site in ipairs(st.sites) do
      local e = trouver(s, site)
      if e then
        -- jambe suivante : à l'arrivée (à 2 tuiles) ou après JAMBE_MAX ticks
        local arrive = site.cible and ((e.position.x - site.cible.x) ^ 2 + (e.position.y - site.cible.y) ^ 2 <= 4)
        if site.jambe == 0 or arrive or ev.tick - site.t_jambe >= JAMBE_MAX then
          if site.jambe < #JAMBES then
            site.jambe = site.jambe + 1
            local j = JAMBES[site.jambe]
            site.cible = { x = e.position.x + j[1] * JAMBE, y = e.position.y + j[2] * JAMBE }   -- depuis là où il est
            site.t_jambe = ev.tick
            e.autopilot_destination = site.cible
            ctx.log(string.format("%s jambe %d vers (%.1f, %.1f) au tick %d", site.id, site.jambe, site.cible.x, site.cible.y, ev.tick))
          elseif arrive or ev.tick - site.t_jambe >= JAMBE_MAX then
            site.fini = site.fini or ev.tick
          end
        end
        if ev.tick % RELEVE == 15 then
          local p = { x = e.position.x, y = e.position.y }
          local a, v = corps_de(e)
          local dir_anim = a and tonumber(a:match("%-(%d+)%-corps$"))
          local dep = site.prec and cap(p.x - site.prec.x, p.y - site.prec.y)
          local nd = NDIRS[site.id] or 8
          if dep and not site.fini then
            site.n = site.n + 1
            if dir_anim and ecart(dir_anim / nd, dep) <= 0.125 + 1e-6 then site.ok = site.ok + 1 end
            if v and v > 0 then site.anim_v0 = site.anim_v0 + 1 end
          end
          if dir_anim then site.dirs[dir_anim] = true end
          if #site.releves < 40 or ev.tick % 300 == 15 then
            ctx.log(string.format("%s t=%d pos=(%.1f,%.1f) orientation=%.3f torse=%s vitesse=%.4f deplacement=%s corps=%s v_images=%s", site.id,
              ev.tick, p.x, p.y, e.orientation, tostring(e.torso_orientation), e.speed or -1, dep and string.format("%.3f", dep) or "nil", tostring(a), tostring(v)))
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
      ctx.check(site.n >= 20, "(" .. site.id .. ") le titan a marche (releves en mouvement)", site.n .. " releves")
      ctx.check(part >= 0.8, "(" .. site.id .. ") le corps suit la direction de marche (>= 80 % des releves, a un secteur pres)",
        string.format("%d / %d = %.0f %%", site.ok, site.n, part * 100))
      ctx.check(nd >= 4, "(" .. site.id .. ") au moins 4 directions du corps vues", nd .. " direction(s)")
      ctx.check(site.n > 0 and site.anim_v0 >= 0.8 * site.n, "(" .. site.id .. ") le corps s'anime en marche (vitesse d'images > 0)",
        site.anim_v0 .. " / " .. site.n)
      ctx.log(string.format("[FO-TITANS-MARCHE] %s : releves %d, corps dans la direction %d (%.0f %%), directions vues %d, anime %d, fin jambes %s",
        site.id, site.n, site.ok, part * 100, nd, site.anim_v0, tostring(site.fini)))
    end
  end,

  --- Captures (session avec images) : la piste entière de chaque titan (jambes E, S, O, N puis diagonales : x de 0 à 51, y de -25 à 36
  --- autour du départ ; le corps monte jusqu'à 36 tuiles au-dessus du pied), une vue par titan toutes les ~150 ticks pendant les jambes
  --- (attentes de 10 ticks entre deux tours de vues) : le titan est toujours dans le cadre, quelle que soit l'heure exacte de la vue.
  shots = function(ctx, add)
    local st = ctx.state()
    for k = 1, 12 do
      for _, site in ipairs(st.sites or {}) do
        add(string.format("tour%02d-%s", k, site.id), site.x + 25, site.y - 4, 0.36, 0, { res = { 1200, 1200 }, info = false, aa = true })
      end
      for w = 1, 11 do add(string.format("attente-%02d-%02d", k, w), X0, Y0 - 300, 1, 0, { res = { 16, 16 }, info = false }) end
    end
  end,
}
