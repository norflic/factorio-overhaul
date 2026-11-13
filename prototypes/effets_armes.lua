--[[
  Lot POLISSAGE-FX (10/11) : effets de particules et lumières dynamiques des armes avancées et des titans, à l'étape
  data-final-fixes (APRÈS l'arsenal, les armes par âge et les titans : tous les prototypes habillés existent). Règle pure :
  shared/content/effets_armes.lua (Fx) : une recette d'effets par MODE, la COULEUR lue dans la table de l'arme (A.ages[].glow,
  A.hand_weapons[].tint, A.cataclysm.tint, T.ALLIES[].lueur) : aucune couleur écrite ici.

  Par pack (Fx.armes) :
  - impact  : explosion vanilla copiée, teintée, mise à l'échelle, durée bornée, FLASH de lumière (pleine intensité, tenue,
              extinction), étincelles (optimized-particle teintées, nombre borné), onde de choc (feuille ONDE teintée) ;
  - bouche  : flash de bouche (explosion-hit teinté + lumière) posé en source_effects du tir des tourelles (faisceau, projectile) ;
  - projectile : lumière portée, traînée (trivial-smoke teintée, cadence bornée), corps VORTEX (feuille, additive) pour l'orbe de
              plasma et la roquette de singularité ; l'impact s'ajoute à l'arrivée ;
  - champ   : le nuage du lanceur de singularités (smoke-with-trigger) prend le vortex pour animation ;
  - titans  : griffes et éclair de singularité reçoivent leur onde, les tirs des drones leur lumière et leur traînée ;
  - animations « fo-fx-vortex » et « fo-fx-onde » (blanches) pour rendering.draw_animation (pulsation de la Sentinelle, script).
  Lot ART-IMPACTS (11/11, mandat de nuit du DC) : FAISCEAUX DENSES (corps « faisceau » à cœur blanc et filaments, éclat aux bouts)
  pour le laser de la lignée et la trace du fusil à rail (qui était l'arc électrique vanilla) ; ONDE DE CHOC AU SOL (feuille
  « choc », 16 images, couche lower-object-above-shadow) et BRÛLURE éphémère (scorchmark vanilla teintable, effacée en
  quelques secondes) pour le plasma, la singularité, la frappe orbitale et les titans ; DISTORSION DE SINGULARITÉ (ombre noire
  en mélange normal sous un anneau de photons additif) pour les armes de la plus haute ère : lanceur de singularités et titans.
  Feuilles : graphics/effets/sprites.lua (tools/render/pieces/effets/vortex.py, PNG hors git, D-6). Tout est porté par le
  moteur : aucun effet par tick côté script (UPS). Âge 1 (cinétique) : délégué au lot TIRS (prototypes/tirs.lua).
]]

local K = require("prototypes.tirs_kit")
local Fx = require("shared.content.effets_armes")
local A = require("shared.content.arsenal")
local T = require("shared.robots.titans")
local SPR = require("__factorio-overhaul__/graphics/effets/sprites")

local out = {}
local packs, refus = Fx.armes(A, T)
for _, r in ipairs(refus) do error("[factorio-overhaul] effets_armes : " .. tostring(r.nom) .. " : " .. tostring(r.motif)) end
for _, p in ipairs(packs) do
  local motifs = Fx.verifier(p)
  if #motifs > 0 then error("[factorio-overhaul] effets_armes : " .. table.concat(motifs, " ; ")) end
end

local function rgba(c, a) return Fx.rgba(c, a) end
local function color(c) return { r = c.r, g = c.g, b = c.b } end

--- Animation d'une feuille de graphics/effets/sprites.lua (rangée, ou grille de line_length colonnes), à l'échelle `k` de
--- la feuille, une boucle en `duree` ticks ; `ombre` : noire, mélange normal, sans teinte ni lueur (ombre de la singularité).
local function anim_feuille(cle, c, k, duree, ombre)
  local s = SPR[cle]
  assert(s, "effets_armes : feuille absente de graphics/effets/sprites.lua : " .. tostring(cle))
  local motifs = Fx.verifier_feuille(cle, s)
  if #motifs > 0 then error("[factorio-overhaul] effets_armes : " .. table.concat(motifs, " ; ")) end
  local function une(d)
    local a = { filename = d.filename, width = d.width, height = d.height, frame_count = s.images,
      line_length = s.line_length or s.images, animation_speed = s.images / duree, scale = d.scale * k,
      priority = "extra-high", flags = { "linear-minification" } }
    if not ombre then a.tint, a.blend_mode, a.draw_as_glow = rgba(c), "additive", true end
    return a
  end
  local a = une(s.lr)
  a.hr_version = une(s.hr)
  return a
end

--- Animation d'une feuille carrée à un DIAMÈTRE donné en tuiles (vortex, onde, choc, singularité, éclat).
local function feuille_anim(cle, c, echelle, duree, ombre)
  local s = SPR[cle]
  assert(s, "effets_armes : feuille absente de graphics/effets/sprites.lua : " .. tostring(cle))
  return anim_feuille(cle, c, echelle / (s.lr.width / 32), duree, ombre)
end

local function lumiere(l) return { intensity = l.intensite, size = l.taille, color = color(l.couleur) } end

--- Nom affiché d'un effet : celui de son arme (entité pour une tourelle ou un titan, objet pour une arme de poing ou une capsule) :
--- aucune clé de traduction nouvelle (F43 : un paramètre de localised_name est une chaîne).
local function nom_affiche(pack)
  for _, t in ipairs({ "gun", "capsule", "item" }) do
    if data.raw[t] and data.raw[t][pack.nom] and not (data.raw["electric-turret"][pack.nom] or data.raw["ammo-turret"][pack.nom]) then
      return { "item-name." .. pack.nom }
    end
  end
  return { "entity-name." .. pack.nom }
end

--- Éclair de lumière d'une explosion : pleine intensité tout de suite, tenue une part de la vie, puis extinction ; `onde` : la
--- lumière part plus petite et grandit.
local function flash(e, l)
  e.light = lumiere(l)
  e.light_intensity_factor_initial, e.light_intensity_factor_final = 1, 0
  e.light_intensity_peak_start_progress, e.light_intensity_peak_end_progress = 0, l.tenue or 0.35
  e.light_size_factor_initial, e.light_size_factor_final = l.onde or 1, 1
  e.light_size_peak_start_progress, e.light_size_peak_end_progress = l.onde and 0.7 or 0, 1
end

--- Particule teintée (copie d'une optimized-particle vanilla) ; rend son nom.
local function particule(nom, et, c, affiche)
  local src = data.raw["optimized-particle"][et.source]
  assert(src, "effets_armes : particule vanilla absente " .. tostring(et.source))
  local p = table.deepcopy(src)
  p.name = nom
  p.localised_name = affiche
  for _, v in ipairs(K.variations(p.pictures)) do K.teinter(v, rgba(c)) end
  out[#out + 1] = p
  return nom
end

local function etincelles(nom, et, c, affiche)
  local monte = et.montee or 0.04
  return {
    type = "create-particle", particle_name = particule(nom, et, c, affiche), repeat_count = et.nombre,
    affects_target = false, show_in_tooltip = false,
    offset_deviation = { { -0.25, -0.25 }, { 0.25, 0.25 } },
    initial_height = 0.6, initial_height_deviation = 0.3,
    initial_vertical_speed = monte, initial_vertical_speed_deviation = 0.5 * monte,
    speed_from_center = et.vitesse, speed_from_center_deviation = 0.6 * et.vitesse,
    frame_speed = 0.5, frame_speed_deviation = 0.2,
  }
end

--- Onde de choc : explosion dont l'animation est la feuille ONDE teintée ; rend son nom.
local function onde(nom, o, c, l, affiche)
  local e = {
    type = "explosion", name = nom, flags = { "not-on-map", "hidden" }, subgroup = "explosions", localised_name = affiche,
    animations = { feuille_anim("onde", c, o.echelle, o.duree) }, rotate = false,
  }
  if l then flash(e, l) end
  out[#out + 1] = e
  return nom
end

--- ART-IMPACTS : onde de choc AU SOL (feuille CHOC, 16 images, sous les entités hautes) ; rend son nom.
local function choc(nom, o, c, l, affiche)
  local e = {
    type = "explosion", name = nom, flags = { "not-on-map", "hidden" }, subgroup = "explosions", localised_name = affiche,
    animations = { feuille_anim("choc", c, o.echelle, o.duree) }, rotate = false, render_layer = "lower-object-above-shadow",
  }
  if l then flash(e, l) end
  out[#out + 1] = e
  return e
end

--- ART-IMPACTS : brûlure au sol ÉPHÉMÈRE (copie d'un scorchmark vanilla teintable : la couleur du sol la teinte), effacée
--- après `tenue` ticks ; rend son nom.
local function brulure(nom, b, affiche)
  local src = data.raw.corpse[b.source]
  assert(src, "effets_armes : marque au sol vanilla absente " .. tostring(b.source))
  local e = table.deepcopy(src)
  e.name, e.localised_name = nom, affiche
  e.ground_patch_fade_out_start = b.tenue
  e.ground_patch_fade_out_duration = math.floor(b.tenue / 2)
  e.time_before_removed = b.tenue + math.floor(b.tenue / 2) + 60
  out[#out + 1] = e
  return nom
end

--- ART-IMPACTS : distorsion de singularité = deux explosions créées ensemble : l'OMBRE (disque noir, mélange normal, couche
--- explosion) et l'anneau de photons (additif, teinte de l'arme, couche projectile : au-dessus de l'ombre) ; rend les effets.
local function distorsion(pack, d, affiche)
  local effets = {}
  for _, k in ipairs({ { "distorsion-ombre", "singularite-ombre", true, "explosion" }, { "distorsion", "singularite", false, "projectile" } }) do
    local e = {
      type = "explosion", name = Fx.nom(pack, k[1]), flags = { "not-on-map", "hidden" }, subgroup = "explosions",
      localised_name = affiche, animations = { feuille_anim(k[2], pack.couleur, d.echelle, d.duree, k[3]) }, rotate = false,
      render_layer = k[4],
    }
    out[#out + 1] = e
    effets[#effets + 1] = { type = "create-entity", entity_name = e.name }
  end
  return effets
end

--- Explosion d'impact d'un pack ; rend le nom de l'entité à créer au point d'impact. Sans explosion vanilla source, le PORTEUR
--- est l'onde de choc (sinon l'onde) : il crée à son tour les étincelles, l'onde, la brûlure et la distorsion.
local function impact(pack)
  local i = pack.impact
  if not i then return nil end
  local c = pack.couleur
  local nom = Fx.nom(pack, "impact")
  local affiche = nom_affiche(pack)
  local lum = not i.source and i.lumiere or nil
  local effets = {}
  if i.etincelles then effets[#effets + 1] = etincelles(Fx.nom(pack, "etincelle"), i.etincelles, c, affiche) end
  local porteur   -- explosion (table) qui porte l'impact quand il n'y a pas de source vanilla
  if i.choc then
    local e = choc(Fx.nom(pack, "choc"), i.choc, c, lum, affiche)
    if i.source then effets[#effets + 1] = { type = "create-entity", entity_name = e.name } else porteur = e end
  end
  if i.onde then
    local n = onde(Fx.nom(pack, "onde"), i.onde, c, (not i.source and not porteur) and lum or nil, affiche)
    if i.source or porteur then
      effets[#effets + 1] = { type = "create-entity", entity_name = n }
    else
      porteur = out[#out]
    end
  end
  if i.brulure then effets[#effets + 1] = { type = "create-entity", entity_name = brulure(Fx.nom(pack, "brulure"), i.brulure, affiche) } end
  if i.distorsion then for _, ef in ipairs(distorsion(pack, i.distorsion, affiche)) do effets[#effets + 1] = ef end end
  if not i.source then
    if #effets > 0 then porteur.created_effect = { type = "direct", action_delivery = { type = "instant", target_effects = effets } } end
    return porteur.name
  end
  local src = data.raw.explosion[i.source]
  assert(src, "effets_armes : explosion vanilla absente " .. tostring(i.source))
  local anims = K.variations(table.deepcopy(src.animations))
  for _, a in ipairs(anims) do
    K.agrandir(a, i.echelle)
    K.teinter(a, rgba(c))
    K.duree(a, i.duree)
  end
  local e = {
    type = "explosion", name = nom, flags = { "not-on-map", "hidden" }, subgroup = "explosions",
    localised_name = nom_affiche(pack), animations = anims, rotate = false, sound = src.sound,
    smoke = src.smoke, smoke_count = src.smoke_count, smoke_slow_down_factor = src.smoke_slow_down_factor,
  }
  if i.lumiere then flash(e, i.lumiere) end
  if #effets > 0 then e.created_effect = { type = "direct", action_delivery = { type = "instant", target_effects = effets } } end
  out[#out + 1] = e
  return nom
end

--- Flash de bouche d'un pack ; rend son nom (nil sans bouche).
local function bouche(pack)
  local b = pack.bouche
  if not b then return nil end
  local src = data.raw.explosion["explosion-hit"]
  local anims = K.variations(table.deepcopy(src.animations))
  for _, a in ipairs(anims) do
    K.agrandir(a, 1.2)
    K.teinter(a, rgba(pack.couleur))
    K.duree(a, b.duree)
  end
  local e = {
    type = "explosion", name = Fx.nom(pack, "bouche"), flags = { "not-on-map", "hidden" }, subgroup = "explosions",
    localised_name = nom_affiche(pack), animations = anims, rotate = false,
  }
  flash(e, { taille = b.taille, intensite = b.intensite, couleur = pack.couleur, tenue = 0.5 })
  out[#out + 1] = e
  return e.name
end

--- Traînée d'un projectile : trivial-smoke teintée (couleur de l'arme, alpha de la recette) ; rend la SmokeSource.
local function trainee(pack, t)
  local src = data.raw["trivial-smoke"][t.source]
  assert(src, "effets_armes : fumée vanilla absente " .. tostring(t.source))
  local s = table.deepcopy(src)
  s.name = Fx.nom(pack, "trainee")
  s.localised_name = nom_affiche(pack)
  s.color = rgba(pack.couleur, t.alpha)
  s.start_scale, s.end_scale = t.debut, t.fin
  s.duration = t.duree
  s.fade_away_duration = math.floor(t.duree * 0.6)
  s.affected_by_wind = false
  out[#out + 1] = s
  return { name = s.name, deviation = { 0.1, 0.1 }, frequency = t.frequence, position = { 0, 0 },
    starting_frame = 3, starting_frame_deviation = 5, starting_frame_speed = 0, starting_frame_speed_deviation = 5 }
end

--- Ajoute `effet` aux target_effects de la livraison instantanée d'une action « direct » (table ou liste).
local function ajoute_cible(action, effet)
  local items = action.type and { action } or action
  for _, it in ipairs(items) do
    local ds = it.action_delivery
    ds = ds and (ds.type and { ds } or ds) or {}
    for _, d in ipairs(ds) do
      if d.type == "instant" then
        d.target_effects = d.target_effects or {}
        local te = d.target_effects.type and { d.target_effects } or d.target_effects
        te[#te + 1] = effet
        d.target_effects = te
        return true
      end
    end
  end
  return false
end

--- Remplace les create-entity d'un nom donné dans les effets d'une action (arcs : explosion-hit -> impact de l'arme).
local function remplace_entite(t, de, vers, seen)
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if t.type == "create-entity" and t.entity_name == de then t.entity_name = vers return end
  for _, v in pairs(t) do remplace_entite(v, de, vers, seen) end
end

local function projectile(p, pack, nom_impact)
  local pr = pack.projectile
  if not (p and pr) then return end
  if pr.lumiere then p.light = lumiere(pr.lumiere) end
  if pr.trainee then p.smoke = { trainee(pack, pr.trainee) } end
  if pr.vortex then
    p.animation = feuille_anim("vortex", pack.couleur, pr.vortex.echelle, 24)
    p.shadow = nil
    p.rotatable = false
  end
  if nom_impact and p.action then ajoute_cible(p.action, { type = "create-entity", entity_name = nom_impact }) end
end

--- ART-IMPACTS : faisceau DENSE : corps (feuille FAISCEAU, raccordable, 8 images qui défilent) et éclats aux deux bouts,
--- teints de la couleur de l'arme, en lumière aussi (light_animations). Le CORPS garde l'échelle 1 (une image = UNE tuile de
--- long, comme le faisceau vanilla) : le moteur pose les maillons à ~0,93 tuile ; plus court, chaque jointure laissait un trou
--- (captures du 11/11) ; l'épaisseur `f.epaisseur` règle les éclats des bouts. Filtrage du faisceau vanilla (trilinéaire).
local function faisceau_dense(b, pack)
  local f, c = pack.faisceau, pack.couleur
  local function corps()
    local a = anim_feuille("faisceau", c, 1, 16)
    a.flags, a.hr_version.flags = { "trilinear-filtering" }, { "trilinear-filtering" }
    return a
  end
  local function bout() return feuille_anim("eclat", c, 1.6 * f.epaisseur, 16) end
  b.head, b.tail, b.body = corps(), bout(), { corps() }
  b.start, b.ending = nil, nil
  b.light_animations = { head = corps(), tail = bout(), body = { corps() } }
  return b
end

--- ART-IMPACTS : la trace du fusil à rail devient un faisceau dense à elle (visuel seul : AUCUNE action, les dégâts restent sur
--- la ligne) ; rend son nom.
local function faisceau_rail(pack)
  local b = {
    type = "beam", name = Fx.nom(pack, "faisceau"), flags = { "not-on-map" }, localised_name = nom_affiche(pack),
    width = 0.5, damage_interval = 20, random_target_offset = false, action_triggered_automatically = false,
  }
  faisceau_dense(b, pack)
  out[#out + 1] = b
  return b.name
end

local function source_bouche(t, nom_bouche)
  if not (t and nom_bouche) then return end
  local ap = t.attack_parameters
  local d = ap and ap.ammo_type and ap.ammo_type.action and ap.ammo_type.action.action_delivery
  if d then d.source_effects = { type = "create-explosion", entity_name = nom_bouche } end
end

---------------------------------------------------------------------------------------------------
-- Animations blanches pour rendering.draw_animation (teintées par le script : couleur de la règle du titan)
---------------------------------------------------------------------------------------------------
for _, cle in ipairs({ "vortex", "onde" }) do
  local a = feuille_anim(cle, { r = 1, g = 1, b = 1 }, Fx.FEUILLE_TUILES, 24)   -- blanc : le script teinte (couleur de la règle)
  a.type, a.name = "animation", Fx.PREFIXE .. cle
  out[#out + 1] = a
end

---------------------------------------------------------------------------------------------------
-- Habillage par pack
---------------------------------------------------------------------------------------------------
local nb = 0
for _, pack in ipairs(packs) do
  if not pack.delegue then
    nb = nb + 1
    local ni, nbo = impact(pack), bouche(pack)
    local nom = pack.nom
    if pack.mode == "laser" then
      local b = data.raw.beam[nom .. "-beam"]
      if b and b.action and ni then ajoute_cible(b.action, { type = "create-entity", entity_name = ni }) end
      if b and pack.faisceau then faisceau_dense(b, pack) end
      source_bouche(data.raw["electric-turret"][nom], nbo)
    elseif pack.mode == "arc" then
      for _, s in ipairs({ "-arc-1", "-arc-2" }) do
        local b = data.raw.beam[nom .. s]
        if b and ni then remplace_entite(b.action, "explosion-hit", ni, {}) end
      end
      source_bouche(data.raw["electric-turret"][nom], nbo)
    elseif pack.mode == "plasma" then
      projectile(data.raw.projectile[nom .. "-orb"], pack, ni)
      source_bouche(data.raw["electric-turret"][nom], nbo)
    elseif pack.mode == "rail" then
      local ammo = data.raw.ammo[A.hand_weapons[1].ammo] -- la balle du fusil à rail, lue dans les données de l'arme
      for _, h in ipairs(A.hand_weapons) do if h.name == nom then ammo = data.raw.ammo[h.ammo] end end
      local act = ammo and ammo.ammo_type and ammo.ammo_type.action
      if act and ni then
        ajoute_cible(act, { type = "create-entity", entity_name = ni })
        local items = act.type and { act } or act
        for _, it in ipairs(items) do if it.type == "line" and nbo then it.source_effects = { type = "create-explosion", entity_name = nbo } end end
        -- la trace : le faisceau de l'arc électrique vanilla est remplacé par le faisceau dense de l'arme
        if pack.faisceau then
          local fr = faisceau_rail(pack)
          for _, it in ipairs(items) do
            local d = it.action_delivery
            if d and d.type == "beam" then d.beam, d.duration = fr, pack.faisceau.duree or d.duration end
          end
        end
      end
    elseif pack.mode == "singularite" then
      projectile(data.raw.projectile[nom .. "-projectile"], pack, ni)
      local cloud = data.raw["smoke-with-trigger"][nom .. "-field"]
      if cloud and pack.champ and pack.champ.vortex then
        cloud.animation = feuille_anim("vortex", pack.couleur, pack.champ.vortex.echelle, 36)
        cloud.color = rgba(pack.couleur, 0.6)
        cloud.render_layer = "object"
      end
    elseif pack.mode == "champ" then
      local eq = data.raw["active-defense-equipment"][nom]
      local act = eq and eq.attack_parameters.ammo_type.action
      if act and ni then
        ajoute_cible(act, { type = "create-entity", entity_name = ni })
        local items = act.type and { act } or act
        items[#items + 1] = { type = "direct", action_delivery = { type = "instant", source_effects = { { type = "create-entity", entity_name = Fx.nom(pack, "onde") } } } }
      end
    elseif pack.mode == "orbital" then
      local marker = data.raw["combat-robot"][nom .. "-marker"]
      local d = marker and marker.destroy_action and marker.destroy_action.action_delivery
      if d and d.source_effects and ni then
        local se = d.source_effects.type and { d.source_effects } or d.source_effects
        se[#se + 1] = { type = "create-entity", entity_name = ni }   -- le porteur : onde de choc au sol, brûlure
        d.source_effects = se
      end
    elseif pack.mode == "titan" then
      for _, r in ipairs(T.ALLIES) do
        if r.name == nom then
          if r.griffes then
            local e = data.raw.explosion[T.PREFIX .. "griffe"]
            if e and ni then
              e.created_effect = { type = "direct", action_delivery = { type = "instant", target_effects = { { type = "create-entity", entity_name = ni } } } }
              flash(e, pack.impact.lumiere)
            end
          end
          if r.singularite then
            local e = data.raw.explosion[T.PREFIX .. "singularite-eclair"]
            if e and ni then
              e.created_effect = { type = "direct", action_delivery = { type = "instant", target_effects = { { type = "create-entity", entity_name = ni } } } }
              flash(e, pack.impact.lumiere)
            end
          end
          if r.drones then
            local fumee = trainee(pack, pack.projectile.trainee)   -- UNE fumée pour tous les paliers (même nom)
            for palier = 1, T.PALIERS do
              local p = data.raw.projectile[T.PREFIX .. "drone-tir-" .. palier]
              if p then
                p.light = lumiere(pack.projectile.lumiere)
                p.smoke = { table.deepcopy(fumee) }
              end
            end
          end
          if r.mitraille and pack.projectile then
            -- KAIJUS-MUTANTS : la mitraille du Ravageur prend la lumière et la traînée de son pack (couleur r.lueur), comme les drones
            local fumee = trainee(pack, pack.projectile.trainee)
            for palier = 1, T.PALIERS do
              local p = data.raw.projectile[T.PREFIX .. "mitraille-" .. palier]
              if p then
                p.light = lumiere(pack.projectile.lumiere)
                p.smoke = { table.deepcopy(fumee) }
              end
            end
          end
        end
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Lot MEGA-BALISTIQUE (11/11) : l'impact de l'orbe du Méga-Bourdon, à l'échelle de son rayon (B.MEGA.RAYON_X × celui de l'orbe
-- Bastion) : la recette d'impact du pack Bastion qu'il reprend (shared/robots/bourdon.lua, B.impact_mega), à la lueur de l'orbe
-- (prototype, light.color) ; elle remplace la big-explosion de son action. Bornes des armes, diamètres et lumière × RAYON_X.
---------------------------------------------------------------------------------------------------
do
  local Bm = require("shared.robots.bourdon")
  local orbe = data.raw.projectile[Bm.MEGA.ORBE]
  if orbe then
    local nom_bastion = A.age_turret(Bm.MEGA.ARME_AGE).name
    local base
    for _, p in ipairs(packs) do if p.nom == nom_bastion and p.mode == "plasma" then base = p end end
    assert(base and base.impact, "effets_armes : pack plasma du Bastion absent pour le Méga-Bourdon")
    local c = color(assert(orbe.light and orbe.light.color, "effets_armes : orbe du Méga-Bourdon sans lueur"))
    local pack = { nom = Bm.MEGA.NOM, mode = base.mode, age = base.age, couleur = c, impact = Bm.impact_mega(base.impact) }
    pack.impact.couleur = c
    if pack.impact.lumiere then pack.impact.lumiere.couleur = c end
    local motifs = Fx.verifier(pack, Bm.bornes_mega(Fx.BORNES))
    if #motifs > 0 then error("[factorio-overhaul] effets_armes : " .. table.concat(motifs, " ; ")) end
    local ni = impact(pack)
    remplace_entite(orbe.action, "big-explosion", ni, {})
    local function cree(t, n, vus)
      if type(t) ~= "table" or vus[t] then return false end
      vus[t] = true
      if t.type == "create-entity" and t.entity_name == n then return true end
      for _, v in pairs(t) do if cree(v, n, vus) then return true end end
      return false
    end
    assert(cree(orbe.action, ni, {}) and not cree(orbe.action, "big-explosion", {}), "effets_armes : impact du Méga-Bourdon non branché")
    -- s43 MEGA-BOURDON (ordre du DC du 13/11) : explosions EN ANNEAU sur toute la zone (B.anneaux du rayon de l'arme) : copies de la
    -- massive-explosion vanilla agrandies (B.MEGA.ANNEAU_ECHELLE), teintes de la lueur de l'orbe, durée × DUREE_X, sans particules
    -- ni son (UPS : un seul son, celui de l'impact central)
    local src = assert(data.raw.explosion["massive-explosion"], "effets_armes : massive-explosion absente")
    local an = table.deepcopy(src)
    an.name, an.localised_name = Bm.MEGA.ANNEAU, { "entity-name." .. Bm.MEGA.NOM }
    an.created_effect, an.sound = nil, nil
    an.animations = K.variations(an.animations)
    for _, a in ipairs(an.animations) do
      K.agrandir(a, Bm.MEGA.ANNEAU_ECHELLE)
      K.teinter(a, rgba(c))
      K.duree(a, base.impact.duree * Bm.MEGA.DUREE_X)
    end
    out[#out + 1] = an
    local rayon = A.age_turret(Bm.MEGA.ARME_AGE).plasma.radius * Bm.MEGA.RAYON_X
    ajoute_cible(orbe.action, { type = "create-entity", entity_name = an.name, offsets = Bm.anneaux(rayon) })
    nb = nb + 1
  end
end

data:extend(out)
log("[FO-EFFETS] " .. #out .. " prototype(s) d'effets pour " .. nb .. " arme(s) et titan(s) (couleurs lues dans leurs tables)")
