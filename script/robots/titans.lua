--[[
  Lot TITANS (9/11, étendu le 10/11) : les titans ALLIÉS en jeu (T.ALLIES : Juggernaut, Sentinelle, Léviathan). Règles pures :
  shared/robots/titans.lua (T.allie(r, age) : palier, PV, plaques, vitesse, armes) ; prototypes : prototypes/titans.lua (un spider-vehicle
  par palier et par archétype) ; modèle : script/robots/experimentaux_geants.lua (cible G.cible, salve de zone G.salve, plafond des géants,
  télécommande, corps par `rendering`).
  - Posé : inscrit ; refusé au-delà du plafond des géants (Xp.giant_ok, titans comptés par Armee.hooks.extra_giants, chaîné au Bourdon) ;
    l'entité posée (palier 1, celui de l'objet) est REMPLACÉE par le palier de l'âge de sa force (évolution dynamique au spawn).
  - Toutes les AGE_TICKS : l'âge de la force est relu ; si le palier change, l'entité est remplacée par le prototype du nouveau palier
    (même position, même part de PV, même force), le corps redessiné : nouvelles armes, masse, plaques (règle pure T.allie).
  - Toutes les SCAN ticks, chaque titan prêt vise l'ennemi le plus proche à portée (G.cible) :
    Juggernaut : griffes (dégâts de zone courte autour de lui, K.blast, palier 1), canon annulaire (rayon fo-titan-canon, coup = salve de son
    âge, palier 2), salve de ZONE des géants (G.salve, cratère, palier 4), résonance (cadence doublée, palier 6) ;
    Sentinelle : SINGULARITÉ (zone K.blast + autocollant de ralentissement fo-titan-singularite sur ce qui bouge : l'attraction n'existe pas
    en 1.1, palier 1), canon (2), salve (4), résonance (6) ;
    Léviathan : SALVE DE DRONES (2 puis 3 drones d'escorte, `rendering` qui orbitent autour du corps sur 12 positions d'un cercle sans
    trigonométrie ; chacun tire un projectile fo-titan-drone-tir-<palier> sur la cible, palier 1), canon = le vortex frontal (3), salve (5),
    résonance (6).
  Le KAIJU (ennemi) n'a rien ici : son prototype par ère est choisi au spawn (shared/td/waves.lua, script/td/director.lua) ; l'IA est celle
  du moteur. Dégâts : script/robots/experimentaux_commun.lua (jamais sur sa force ni ses amis). Rien de mesuré en temps, rien en dur.
  Sauvegarde : `juggernauts` garde son nom (saves du 9/11) et liste TOUS les titans alliés (champ `id` = archétype, défaut juggernaut).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local T = require("shared.robots.titans")
local Xp = require("shared.robots.experimentaux")
local K = require("script.robots.experimentaux_commun")
local Armee = require("script.robots.armee")
local G = require("script.robots.experimentaux_geants")
local Rg = require("shared.tirs.regles")   -- Rg.decalage : image 0 d'une animation au tick voulu (image = floor(tick × vitesse + décalage) mod n)
local Fx = require("shared.content.effets_armes")   -- POLISSAGE-FX : pulsation de la singularité (table précalculée, couleur de la règle du titan)
require("script.robots.kaijus")   -- KAIJUS-MUTANTS : la ponte de l'Écorcheur (ennemi), abonnée ici (control.lua intact)
local Serp = require("script.robots.titans_serpent")   -- LEVIATHAN-SEG : corps articulé (segments, queue) des titans serpentins

local M = {}

Storage.declare("titans", function()
  return { juggernauts = {} }
end)

local function S() return Storage.ns("titans") end

local SCAN = 30
local AGE_TICKS = 600
local CANON = T.PREFIX .. "canon"
local GRIFFE = T.PREFIX .. "griffe"
local SINGULARITE = T.PREFIX .. "singularite"
local SINGULARITE_ECLAIR = T.PREFIX .. "singularite-eclair"
local DRONE_TIR = T.PREFIX .. "drone-tir-"
local DRONE_SPRITE = T.PREFIX .. "leviathan-drone"
local MITRAILLE = T.PREFIX .. "mitraille-"   -- KAIJUS-MUTANTS : projectiles de la rafale du Ravageur, un par palier
-- Douze positions d'un cercle unité (pas de 30°), sans trigonométrie : les drones y avancent d'un cran par balayage.
local CERCLE = {
  { 1.0, 0.0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0.0, 1.0 }, { -0.5, 0.866 }, { -0.866, 0.5 },
  { -1.0, 0.0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0.0, -1.0 }, { 0.5, -0.866 }, { 0.866, -0.5 },
}
local DRONE_HAUT = -6.0    -- les drones volent : décalage vers le haut de l'écran (tuiles)
local RALENTIS = { unit = true, character = true, car = true, ["spider-vehicle"] = true }
-- POLISSAGE-FX : vortex au sol et lumière pulsée de la singularité (recette Fx.MODES.titan.singularite, couleur r.lueur) ; la table de
-- pulsation est précalculée (onde triangulaire, sans trigonométrie) et lue tous les SCAN ticks : aucun effet par tick.
local PULSE_SPEC = Fx.MODES.titan.singularite
local PULSE = Fx.pulsation(PULSE_SPEC.pulsation.n)

local function rgba(r, g, b, a) return { r = r * a, g = g * a, b = b * a, a = a } end

local function journal(fmt, ...)
  local s = K.S()
  if s and s.journal then log(T.LOG .. " " .. string.format(fmt, ...)) end
end

local function archetype(g) return T.allie_of_id(g.id or "juggernaut") or T.JUGGERNAUT end

---------------------------------------------------------------------------------------------------
-- Registre et plafond (chaîné au compte des géants d'Armee)
---------------------------------------------------------------------------------------------------
local function mine(force_name, sauf)
  local n = 0
  local st = S()
  if not st then return 0 end
  for _, g in ipairs(st.juggernauts) do
    if g.e.valid and g.e.force.name == force_name and g.un ~= sauf then n = n + 1 end
  end
  return n
end

function M.count(force_name) return mine(force_name, nil) end

do
  local avant = Armee.hooks.extra_giants
  Armee.hooks.extra_giants = function(force_name)
    return (avant and avant(force_name) or 0) + mine(force_name, nil)
  end
end

local function detruire_drones(g)
  for _, id in ipairs(g.drones or {}) do
    if rendering.is_valid(id) then rendering.destroy(id) end
  end
  g.drones = nil
end

--- Position d'orbite du drone k (1..n) au cran `cran` : rayon d'orbite de la règle, décalage vers le haut (il vole).
local function orbite(j, k, n, cran)
  local i = (cran + math.floor(12 * (k - 1) / n)) % 12 + 1
  local c = CERCLE[i]
  return { c[1] * j.drones.orbit, c[2] * j.drones.orbit * 0.6 + DRONE_HAUT }
end

local function drones_dessiner(g, j)
  detruire_drones(g)
  if not (j.n_drones and j.armes.drones) then return end
  local e = g.e
  g.cran = g.cran or 0
  g.drones = {}
  for k = 1, j.n_drones do
    local off = orbite(j, k, j.n_drones, g.cran)
    g.drones[#g.drones + 1] = rendering.draw_sprite({ sprite = DRONE_SPRITE .. "-corps", target = e, target_offset = off, surface = e.surface, render_layer = "air-object" })
    g.drones[#g.drones + 1] = rendering.draw_sprite({ sprite = DRONE_SPRITE .. "-lueur-1", target = e, target_offset = off, surface = e.surface, render_layer = "air-object" })
  end
end

local function drones_avancer(g, j)
  if not g.drones then return end
  g.cran = ((g.cran or 0) + 1) % 12
  local n = j.n_drones or 0
  for k = 1, n do
    local off = orbite(j, k, n, g.cran)
    for q = 1, 2 do
      local id = g.drones[(k - 1) * 2 + q]
      if id and rendering.is_valid(id) then rendering.set_target(id, g.e, off) end
    end
  end
end

--- Corps ANIMÉ (FINITIONS 10/11 : Juggernaut, r.anime) : trois `rendering.draw_animation` (ombre, corps, lueur) sur l'animation de marche de
--- la direction de l'entité ; `animer` les tient à jour à chaque balayage (direction, vitesse = celle du véhicule, salve). Les rendus meurent
--- avec l'entité (remplacement de palier : `corps` les refait).
--- Direction du corps animé : le CAP de la trajectoire pour un titan articulé (LEVIATHAN-SEG : g.seg.dir, titans_serpent : la tête suit la
--- même trajectoire que ses segments), sinon celle du TORSE du spider-vehicle (F507 : `orientation` d'un spider-vehicle reste à 0 en marche ;
--- le torse tourne vers la marche, prototypes/titans.lua), parmi les directions de la règle (16 : Juggernaut, Sentinelle, Ravageur).
local function direction_corps(g, r)
  if r.segmente and g.seg and g.seg.dir then return g.seg.dir end
  return T.direction(g.e.torso_orientation, r.anime.directions)
end

local function corps_anime(g, r)
  local e = g.e
  local dir = direction_corps(g, r)
  g.anim = { dir = dir, mode = "course", v = 0, ids = {} }
  for _, c in ipairs(T.COUCHES_ANIM) do
    g.anim.ids[#g.anim.ids + 1] = rendering.draw_animation({ animation = T.anim_name(r, g.stage, "course", dir, c[1]), target = e, surface = e.surface,
      render_layer = c[2], animation_speed = 0, animation_offset = 0 })
  end
end

--- Singularité de la Sentinelle à l'écran (POLISSAGE-FX) : vortex qui tourne au sol sous le titan et lumière portée, teintés de la
--- couleur de la règle (r.lueur) ; `pulser` les fait respirer à chaque balayage. Les rendus meurent avec l'entité.
local function singularite_dessiner(g, r)
  g.sing = nil
  if not r.singularite then return end
  local e = g.e
  local v, l = PULSE_SPEC.vortex, PULSE_SPEC.lumiere
  local k = v.echelle / Fx.FEUILLE_TUILES
  g.sing = {
    k = k, taille = l.taille / Fx.LUMIERE_SPRITE_TUILES, intensite = l.intensite,
    anim = rendering.draw_animation({ animation = Fx.VORTEX, target = e, surface = e.surface, render_layer = "lower-object",
      tint = r.lueur, x_scale = k, y_scale = k * 0.7, animation_speed = 0.5 }),
    lum = rendering.draw_light({ sprite = "utility/light_medium", target = e, surface = e.surface, color = r.lueur,
      scale = l.taille / Fx.LUMIERE_SPRITE_TUILES, intensity = l.intensite, minimum_darkness = 0.15 }),
  }
end

local function singularite_pulser(g, r, tick)
  if r.singularite and not g.sing then singularite_dessiner(g, r) end
  local sg = g.sing
  if not sg then return end
  local p = PULSE[Fx.pulse_index(tick, PULSE_SPEC.pulsation.periode, PULSE_SPEC.pulsation.n)]
  if sg.lum and rendering.is_valid(sg.lum) then
    rendering.set_intensity(sg.lum, sg.intensite * p)
    rendering.set_scale(sg.lum, sg.taille * (0.8 + 0.2 * p))
  end
  if sg.anim and rendering.is_valid(sg.anim) then
    rendering.set_x_scale(sg.anim, sg.k * (0.85 + 0.15 * p))
    rendering.set_y_scale(sg.anim, sg.k * 0.7 * (0.85 + 0.15 * p))
  end
end

local function corps(g)
  local e = g.e
  local s = e.surface
  local r = archetype(g)
  singularite_dessiner(g, r)
  if r.segmente then
    Serp.dessiner(g, r)   -- LEVIATHAN-SEG : pièces et tête (crochet Serp.hooks.tete) dans l'ordre de dessin
  elseif r.anime then
    corps_anime(g, r)
  else
    local st = T.PREFIX .. r.id .. "-" .. g.stage
    rendering.draw_sprite({ sprite = st .. "-ombre", target = e, surface = s, render_layer = "lower-object" })
    rendering.draw_sprite({ sprite = st .. "-corps", target = e, surface = s, render_layer = "air-object" })
    rendering.draw_sprite({ sprite = st .. "-lueur-1", target = e, surface = s, render_layer = "air-object" })
  end
  drones_dessiner(g, T.allie(r, g.age))
end

--- LEVIATHAN-SEG : (re)dessine le corps animé de la tête d'un titan articulé à sa place dans l'ordre de dessin (titans_serpent) : neuf
--- (pose, remplacement de palier : les anciens rendus sont morts avec l'entité) ou refait avec la même animation, la même vitesse et
--- la même phase (la chaîne a changé d'ordre : rien ne se voit).
Serp.hooks.tete = function(g, r)
  local a = g.anim
  local ids = a and a.ids
  if not (ids and ids[1] and rendering.is_valid(ids[1])) then
    corps_anime(g, r)
    return
  end
  local e = g.e
  local nouveaux = {}
  for i, c in ipairs(T.COUCHES_ANIM) do
    local id = ids[i]
    local nom, v, off = T.anim_name(r, g.stage, "course", a.dir, c[1]), 0, 0
    if id and rendering.is_valid(id) then
      nom, v, off = rendering.get_animation(id), rendering.get_animation_speed(id), rendering.get_animation_offset(id)
      rendering.destroy(id)
    end
    nouveaux[i] = rendering.draw_animation({ animation = nom, target = e, surface = e.surface, render_layer = c[2], animation_speed = v,
      animation_offset = off })
  end
  a.ids = nouveaux
end

local function anim_set(g, r, anim)
  for i, c in ipairs(T.COUCHES_ANIM) do
    local id = g.anim.ids[i]
    if id and rendering.is_valid(id) then rendering.set_animation(id, T.anim_name(r, g.stage, anim, g.anim.dir, c[1])) end
  end
end

--- Salve à l'écran : l'animation d'attaque de la direction courante, image 0 à ce tick, ses images étalées sur attaque_ticks ; `animer` repasse en marche après.
local function anim_attaque(g, r, tick)
  if not (r.anime and g.anim) then return end
  local n = r.anime.images.attaque
  local v = n / r.anime.attaque_ticks
  g.anim.mode, g.anim.fin, g.anim.v = "attaque", tick + r.anime.attaque_ticks, nil
  anim_set(g, r, "attaque")
  for _, id in ipairs(g.anim.ids) do
    if rendering.is_valid(id) then
      rendering.set_animation_speed(id, v)
      rendering.set_animation_offset(id, Rg.decalage(tick, v, n))
    end
  end
end

--- À chaque balayage : direction de l'entité (r.anime.directions secteurs), marche à la vitesse du véhicule (images par tick = vitesse × images / foulée ;
--- 0 et image 0 à l'arrêt), retour en marche à la fin d'une salve.
local function animer(g, r, tick)
  if not (r.anime and g.anim) then return end
  local e = g.e
  local a = g.anim
  if a.mode == "attaque" and tick < (a.fin or 0) then return end
  local dir = direction_corps(g, r)
  if a.mode ~= "course" or dir ~= a.dir then
    a.mode, a.dir, a.v = "course", dir, nil
    anim_set(g, r, "course")
  end
  local v = T.vitesse_anim(e.speed, r.anime.foulee, r.anime.images.course)
  if v ~= a.v then
    a.v = v
    for _, id in ipairs(a.ids) do
      if rendering.is_valid(id) then
        rendering.set_animation_speed(id, v)
        if v == 0 then rendering.set_animation_offset(id, 0) end
      end
    end
  end
end

-- LEVIATHAN-SEG : la tête d'un titan articulé prend l'image de son nouveau cap dès que titans_serpent le voit changer (5 ticks), sans
-- attendre le balayage (30 ticks)
Serp.hooks.orienter = function(g, r) animer(g, r, game.tick) end

local function rendre(player, e, name)
  if player and player.valid and player.insert({ name = name, count = 1 }) == 1 then return end
  e.surface.spill_item_stack(e.position, { name = name, count = 1 }, true)
end

--- Remplace l'entité `e` par le prototype du palier `palier` de l'archétype `r` (même position, force, part de PV). Rend la nouvelle entité (ou e).
local function remplacer(e, r, palier)
  local nom = T.allie_name(r, palier)
  if e.name == nom then return e end
  local s, pos, force = e.surface, e.position, e.force
  local part = e.health / e.prototype.max_health
  local n = s.create_entity({ name = nom, position = pos, force = force, create_build_effect_smoke = false })
  if not n then return e end
  n.health = math.max(1, n.prototype.max_health * part)
  e.destroy()
  return n
end

local function inscrire(e, r, tick, player)
  local force = e.force
  local age = Armee.age(force)
  local j = T.allie(r, age)
  e = remplacer(e, r, j.palier)
  local st = S()
  local g = { un = e.unit_number, e = e, id = r.id, age = age, palier = j.palier, stage = j.stage, next = tick, next_griffes = tick, n = 0, cran = 0 }
  st.juggernauts[#st.juggernauts + 1] = g
  corps(g)
  if player and player.valid and game.item_prototypes["spidertron-remote"] then
    local stack = player.cursor_stack
    if stack and player.clear_cursor() and stack.valid and stack.set_stack({ name = "spidertron-remote", count = 1 }) then
      stack.connected_entity = e
    end
  end
  journal("%s pose #%d force %s age %d palier %d armes %s", r.id, e.unit_number, force.name, age, j.palier, table.concat(j.liste_armes, "+"))
  return g
end

local function on_built(ev)
  local e = ev.created_entity or ev.entity
  if not (e and e.valid) then return end
  local r = T.allie_palier(e.name)
  if not r then return end
  local st = S()
  for _, g in ipairs(st.juggernauts) do
    if g.e.valid and g.e == e then return end -- remplacement par ce script (script_raised_built) : déjà inscrit
  end
  local force = e.force
  local age = Armee.age(force)
  local have = Armee.giants(force.name) - mine(force.name, nil) + mine(force.name, e.unit_number)
  local player = ev.player_index and game.get_player(ev.player_index)
  if not Xp.giant_ok(age, have) then
    journal("%s refuse : plafond des geants (%d deja, age %d, plafond %d)", r.id, have, age, Xp.giant_cap(age))
    rendre(player, e, r.name)
    if player then player.print({ "fo-titan.plafond", { "entity-name." .. r.name }, Xp.giant_cap(age), age }) end
    e.destroy()
    return
  end
  inscrire(e, r, ev.tick or game.tick, player)
end

---------------------------------------------------------------------------------------------------
-- Évolution par âge : le palier suit l'âge de la force
---------------------------------------------------------------------------------------------------
local function evoluer(ev)
  local st = S()
  if not st or #st.juggernauts == 0 then return end
  for _, g in ipairs(st.juggernauts) do
    if g.e.valid then
      local age = Armee.age(g.e.force)
      if age ~= g.age then
        local r = archetype(g)
        local j = T.allie(r, age)
        g.age = age
        if j.palier ~= g.palier then
          detruire_drones(g)
          local n = remplacer(g.e, r, j.palier)
          g.e, g.un, g.palier, g.stage = n, n.unit_number, j.palier, j.stage
          corps(g)
          if g.e.force.name == "player" then
            game.print({ "fo-titan.evolue", { "entity-name." .. r.name }, j.palier, age, table.concat(j.liste_armes, ", ") })
          end
          journal("%s #%d evolue : age %d palier %d armes %s", r.id, g.un, age, j.palier, table.concat(j.liste_armes, "+"))
        end
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Armes
---------------------------------------------------------------------------------------------------
local function griffes(g, j, tick)
  local e = g.e
  local total, n = K.blast(j, e.surface, e.force, e, { x = e.position.x, y = e.position.y }, j.griffes.radius, j.salve * j.griffes.part, "physical",
    j.griffes.edge)
  if n > 0 then
    e.surface.create_entity({ name = GRIFFE, position = e.position })
    rendering.draw_circle({ color = rgba(0.3, 0.95, 1.0, 0.5), radius = j.griffes.radius, width = 8, filled = false, target = e.position,
      surface = e.surface, time_to_live = 20, draw_on_ground = true })
    journal("%s griffes #%d cibles %d degats %.0f tick %d", j.id, g.un, n, total, tick)
  end
  return n
end

--- Singularité de la Sentinelle : dégâts de zone (laser) autour d'elle + autocollant de ralentissement sur tout ennemi mobile de la zone.
local function singularite(g, j, tick)
  local e = g.e
  local sg = j.singularite
  local pos = { x = e.position.x, y = e.position.y }
  local total, n = K.blast(j, e.surface, e.force, e, pos, sg.radius, j.salve * sg.part, j.dtype, sg.edge)
  if n > 0 then
    local ralentis = 0
    for _, c in ipairs(K.candidates(e.surface, e.force, pos, sg.radius)) do
      if c.e.valid and RALENTIS[c.e.type] then
        e.surface.create_entity({ name = SINGULARITE, position = c.e.position, target = c.e })
        ralentis = ralentis + 1
      end
    end
    e.surface.create_entity({ name = SINGULARITE_ECLAIR, position = e.position })
    rendering.draw_circle({ color = rgba(0.5, 0.85, 1.0, 0.45), radius = sg.radius, width = 10, filled = false, target = e.position,
      surface = e.surface, time_to_live = 24, draw_on_ground = true })
    journal("%s singularite #%d cibles %d ralentis %d degats %.0f tick %d", j.id, g.un, n, ralentis, total, tick)
  end
  return n
end

--- Lames du Ravageur (KAIJUS-MUTANTS) : coup de zone courte des lames de cristal, même mécanique que les griffes (éclair des griffes).
local function lames(g, j, tick)
  local e = g.e
  local total, n = K.blast(j, e.surface, e.force, e, { x = e.position.x, y = e.position.y }, j.lames.radius, j.salve * j.lames.part, j.dtype,
    j.lames.edge)
  if n > 0 then
    e.surface.create_entity({ name = GRIFFE, position = e.position })
    rendering.draw_circle({ color = rgba(0.3, 0.95, 1.0, 0.5), radius = j.lames.radius, width = 8, filled = false, target = e.position,
      surface = e.surface, time_to_live = 20, draw_on_ground = true })
    journal("%s lames #%d cibles %d degats %.0f tick %d", j.id, g.un, n, total, tick)
  end
  return n
end

--- Mitraille du Ravageur : rafale de j.mitraille.n projectiles (prototype par palier, dégâts de zone sur les ennemis) depuis la bouche du
--- gatling vers la cible, étalés autour d'elle sur le cercle à 12 crans (sans trigonométrie) ; la salve à l'écran suit.
local function mitraille(g, j, target, tick)
  local e = g.e
  local n = j.mitraille.n
  local src = { e.position.x + j.bouche[1], e.position.y + j.bouche[2] }
  for k = 1, n do
    local c = CERCLE[math.floor((k - 1) * 12 / n) % 12 + 1]
    local dest = { target.position.x + c[1] * j.mitraille.spread, target.position.y + c[2] * j.mitraille.spread }
    e.surface.create_entity({ name = MITRAILLE .. j.palier, position = src, target = dest, source = e, force = e.force, speed = j.mitraille.speed })
  end
  anim_attaque(g, archetype(g), tick)
  journal("%s mitraille #%d x%d cible #%s tick %d", j.id, g.un, n, tostring(target.unit_number), tick)
end

local function canon(g, j, target, tick)
  local e = g.e
  e.surface.create_entity({ name = CANON, position = e.position, source = e, source_offset = { j.bouche[1], j.bouche[2] },
    target_position = { target.position.x, target.position.y }, duration = math.min(60, j.cooldown) })
  rendering.draw_circle({ color = rgba(0.3, 0.95, 1.0, 0.6), radius = 2.0, width = 6, filled = false, target = target.position, surface = e.surface,
    time_to_live = 30, draw_on_ground = true })
  local d = K.hit(j, target, j.salve, j.dtype, e.force, e)
  anim_attaque(g, archetype(g), tick)
  journal("%s canon #%d degats %.0f tick %d", j.id, g.un, d, tick)
end

--- Salve de drones du Léviathan : chaque drone tire un projectile (dégâts de zone sur les ennemis, prototype par palier) depuis sa position d'orbite.
local function drones_tirer(g, j, target, tick)
  local e = g.e
  local n = j.n_drones or 0
  for k = 1, n do
    local off = orbite(j, k, n, g.cran or 0)
    e.surface.create_entity({ name = DRONE_TIR .. j.palier, position = { e.position.x + off[1], e.position.y + off[2] }, target = target,
      source = e, force = e.force, speed = j.drones.speed })
  end
  anim_attaque(g, archetype(g), tick)   -- TITANS-8DIR : les anneaux s'ouvrent, les drones sortent de la gueule
  journal("%s drones #%d x%d cible #%s tick %d", j.id, g.un, n, tostring(target.unit_number), tick)
end

local function scan(ev)
  local st = S()
  if not st or #st.juggernauts == 0 then return end
  local keep = {}
  for _, g in ipairs(st.juggernauts) do
    if g.e.valid then
      keep[#keep + 1] = g
      local r = archetype(g)
      local j = T.allie(r, g.age)
      animer(g, r, ev.tick)
      singularite_pulser(g, r, ev.tick)
      if j.n_drones then
        if not g.drones then drones_dessiner(g, j) end
        drones_avancer(g, j)
      end
      -- armes de contact à leur cadence, dès qu'un ennemi est dans la zone
      if ev.tick >= g.next_griffes then
        if j.armes.griffes and griffes(g, j, ev.tick) > 0 then
          g.next_griffes = ev.tick + j.griffes.cooldown
          if not j.armes.canon then anim_attaque(g, r, ev.tick) end   -- palier 1 : les griffes sont la seule salve visible
        end
        if j.armes.singularite and singularite(g, j, ev.tick) > 0 then
          g.next_griffes = ev.tick + j.singularite.cooldown
          if not j.armes.canon then anim_attaque(g, r, ev.tick) end   -- TITANS-8DIR : palier 1, la singularité est la salve visible
        end
        if j.armes.lames and lames(g, j, ev.tick) > 0 then g.next_griffes = ev.tick + j.lames.cooldown end
      end
      if ev.tick >= g.next and not G.zone_active(g.un) then
        local t = G.cible(g.e, j, nil)
        if t then
          if j.armes.canon then canon(g, j, t, ev.tick) end
          if j.armes.mitraille then mitraille(g, j, t, ev.tick) end
          if j.armes.drones then drones_tirer(g, j, t, ev.tick) end
          if j.armes.salve then G.salve(g.e, g.un, j, { x = t.position.x, y = t.position.y }, ev.tick, nil) end
          local s = K.stat(j.id)
          s.coups = s.coups + 1
          g.n = g.n + 1
          local cadence = j.cooldown
          if j.armes.salve then cadence = j.zone_cooldown elseif j.armes.drones and not j.armes.canon then cadence = j.drones.cooldown end
          g.next = ev.tick + cadence
        end
      end
    else
      detruire_drones(g)
    end
  end
  st.juggernauts = keep
end

Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on(defines.events.script_raised_built, on_built)
Events.on(defines.events.script_raised_revive, on_built)
Events.on_nth_tick(SCAN, scan)
Events.on_nth_tick(AGE_TICKS, evoluer)

return M
