--[[
  Lot DESIGN-ATTAQUES (5/11, nuit) : les IMAGES des grandes attaques (script/robots/attaques2.lua). Aucun dégât ici, aucune recherche
  d'entités : rendering, explosions, rayons, fumées, particules. 0 image neuve (prototypes/attaques2.lua, feuilles du Bourdon, vanilla).
  v2 après la critique sévère du 5/11 : plus de cercles ni de lignes plates en image principale (seul un trait fin de 4 px au cœur du rayon
  du Tournesol) ; le kit du Glas (fissures chaudes qui refroidissent en noir, poussière brune, étoile d'or) dans sa couleur d'origine ; le bleu
  et le cyan par la lumière ronde (couleur pure) ; anneaux par B.dir (pas de croix sur les axes) ; climax à la fin.
  Couleurs du rendering : PRÉMULTIPLIÉES (gi1, 4/11).
]]

local Xp = require("shared.robots.experimentaux")
local A = require("shared.robots.attaques2")
local B = require("shared.robots.bourdon")

local V = {}
local P = A.PREFIX

local function rgba(r, g, b, a) return { r = r * a, g = g * a, b = b * a, a = a } end
local COUL = {
  cairn = { 0.4, 0.7, 1.0 }, stylet = { 1.0, 0.85, 0.6 }, trombe = { 0.75, 0.9, 1.0 }, ixion = { 1.0, 0.45, 0.12 }, tournesol = { 1.0, 0.82, 0.4 },
}
-- point d'émission de chaque géant (décalage à l'écran depuis sa position, lu dans les feuilles : graphics/robots/experimentaux/sprites.lua)
-- (décalages en tuiles du jeu : Stylet, nez au sol (−0,3) ; Trombe, pointe au sol (−0,9) ; Ixion, cœur solaire (−15) ; Tournesol, foyer)
local BOUCHE = { cairn = { 1.8, -36 }, stylet = { 0, -0.5 }, trombe = { -0.9, -1 }, ixion = { 0, -15 }, tournesol = { -8.5, -31.3 } }

local function vis(j, k, id) j.vis[k] = id; return id end
local function ok(id) return id and rendering.is_valid(id) end
local function detruit(id) if ok(id) then rendering.destroy(id) end end

local function halo(j, pos, sx, sy, col, a, couche, ttl, petit)
  return rendering.draw_sprite({ sprite = P .. (petit and "halo-petit" or "halo"), target = pos, surface = j.surface, x_scale = sx,
    y_scale = sy or sx, tint = rgba(col[1], col[2], col[3], a), render_layer = couche or "air-object", time_to_live = ttl })
end

local function lumiere(j, pos, echelle, col, intensite, ttl)
  return rendering.draw_light({ sprite = "utility/light_medium", target = pos, surface = j.surface, scale = echelle, intensity = intensite,
    color = { r = col[1], g = col[2], b = col[3] }, minimum_darkness = 0.0, time_to_live = ttl })
end

--- Une fissure du kit du Glas : chaude (orange d'origine, additive) puis la cicatrice noire. o : orientation (fraction de tour).
local function fissure(j, pos, o, v, chaude, noire, ech)
  local s = j.surface
  ech = ech or 1
  if noire and noire > 0 then
    rendering.draw_sprite({ sprite = "fo-bourdon-fissure-" .. v, target = pos, surface = s, orientation = o, x_scale = 0.8 * ech, y_scale = 1.1 * ech,
      render_layer = "ground-patch-higher", time_to_live = noire })
  end
  if chaude and chaude > 0 then
    rendering.draw_sprite({ sprite = "fo-bourdon-fissure-chaude-" .. v, target = pos, surface = s, orientation = o, x_scale = 0.8 * ech,
      y_scale = 1.1 * ech, render_layer = "ground-patch-higher2", time_to_live = chaude })
  end
end

local function bouche(j)
  local b = BOUCHE[j.id]
  local p = j.e.valid and j.e.position or j.c
  return { x = p.x + b[1], y = p.y + b[2] }
end

local function son(j, k, pos) j.surface.play_sound({ path = P .. k, position = pos or j.c }) end

---------------------------------------------------------------------------------------------------
-- Commun : le géant s'illumine (copies additives de sa lueur), la charge, la frappe, la fin
---------------------------------------------------------------------------------------------------
local function lueurs(j, v)
  for _, id in ipairs(j.vis.lueurs or {}) do
    if ok(id) then rendering.set_color(id, rgba(1, 1, 1, math.min(1, v))) end
  end
  if ok(j.vis.lum_geant) then rendering.set_intensity(j.vis.lum_geant, math.min(1, v * 0.6)) end
end

function V.debut(j, r, a)
  local e = j.e
  j.vis.lueurs = {}
  for k = 1, 6 do
    local nom = Xp.PREFIX .. j.id .. "-lueur-" .. k
    if not game.is_valid_sprite_path(nom) then break end
    for _ = 1, 2 do
      j.vis.lueurs[#j.vis.lueurs + 1] = rendering.draw_sprite({ sprite = nom, target = e, surface = j.surface, render_layer = "air-object",
        tint = rgba(1, 1, 1, 0) })
    end
  end
  local col = COUL[j.id]
  local b = BOUCHE[j.id]
  vis(j, "lum_geant", rendering.draw_light({ sprite = "utility/light_medium", target = e, target_offset = { b[1], b[2] }, surface = j.surface,
    scale = 10, intensity = 0, color = { r = col[1], g = col[2], b = col[3] }, minimum_darkness = 0.0 }))
  j.vis.n = 0
  if j.id == "tournesol" then
    -- la couronne : 32 éclats d'or sur le cercle de départ de la spirale, allumés un à un pendant la charge
    j.vis.couronne = {}
    for k = 0, 31 do
      local cs, sn = B.dir(k / 32)
      j.vis.couronne[k + 1] = halo(j, { j.c.x + cs * j.R, j.c.y + sn * j.R }, 0.55, 0.55, col, 0, "air-object")
    end
  end
end

function V.charge(j, r, a, rt)
  local u = 1 + rt / a.charge -- 0 au début de la charge, 1 à la frappe
  if rt % 2 == 0 then lueurs(j, u * 1.6) end
  local s, c, col = j.surface, j.c, COUL[j.id]
  if j.id == "cairn" then
    -- l'orage se forme au-dessus de la cible ; des étincelles courent sur les antennes
    if rt % 4 == 0 then
      local cs, sn = B.dir(rt * 0.013)
      for k = 0, 2 do
        local c2, s2 = B.dir(k / 3 + rt * 0.013)
        s.create_trivial_smoke({ name = P .. "nuage", position = { c.x + c2 * (14 - 8 * u), c.y + s2 * (10 - 6 * u) - 8 } })
      end
      local bp = bouche(j)
      s.create_particle({ name = "spark-particle", position = { bp.x + cs * 3, bp.y + 30 }, movement = { cs * 0.05, -0.02 }, height = 30,
        vertical_speed = 0.02, frame_speed = 1 })
    end
    if rt % 15 == 0 and u > 0.4 then V.foudre(j, { x = c.x + (rt % 7) * 2 - 6, y = c.y + (rt % 5) * 2 - 4 }) end
  elseif j.id == "stylet" then
    -- le nez se charge : un éclat blanc-bleu qui grossit, des étincelles
    if not ok(j.vis.nez) then j.vis.nez = halo(j, j.o, 0.2, 0.2, { 0.8, 0.92, 1.0 }, 0.9, "air-object") end
    rendering.set_x_scale(j.vis.nez, 0.2 + 0.9 * u)
    rendering.set_y_scale(j.vis.nez, 0.2 + 0.9 * u)
    if rt % 6 == 0 then s.create_entity({ name = P .. "eclat-bleu", position = { j.o.x, j.o.y } }) end
  elseif j.id == "trombe" then
    if rt % 2 == 0 then
      for k = 0, 1 do
        local cs, sn = B.dir(rt * 0.03 + k / 2)
        local rr = 3 + 10 * (1 - u)
        s.create_trivial_smoke({ name = P .. "tornade", position = { c.x + cs * rr, c.y + sn * rr } })
      end
    end
  elseif j.id == "ixion" then
    -- les fissures chaudes rayonnent depuis la cible
    local n = math.floor(u * 48)
    while j.vis.n < n do
      local k = j.vis.n
      local ray, seg = k % 16, math.floor(k / 16)
      local cs, sn = B.dir(ray / 16 + 0.011 * ((k * 7) % 5))
      local d = 3 + seg * 5.5
      fissure(j, { c.x + cs * d, c.y + sn * d }, ray / 16, k % 6 + 1, 900, 3600 + 900, 1.2 - 0.2 * seg)
      j.vis.n = k + 1
    end
    if rt % 10 == 0 then s.create_trivial_smoke({ name = P .. "vapeur", position = { c.x, c.y } }) end
  elseif j.id == "tournesol" then
    local n = math.floor(u * 32)
    for k = 1, n do
      local id = j.vis.couronne[k]
      if ok(id) then rendering.set_color(id, rgba(col[1], col[2], col[3], 0.85)) end
    end
  end
end

function V.frappe(j, r, a)
  local s, c, col = j.surface, j.c, COUL[j.id]
  lueurs(j, 2.5)
  son(j, j.id)
  if j.id == "cairn" then
    if not (j.fusee and j.fusee[1]) then V.foudre(j, c, true) end
  elseif j.id == "stylet" then
    -- le rayon : un fût large bleu-blanc, un cœur blanc, une chaîne de halos, un point d'impact qui brûle
    local o = j.o
    local e0 = j.rayons[1]
    vis(j, "ray1", rendering.draw_line({ color = rgba(0.55, 0.8, 1.0, 0.55), width = 72, from = { o.x, o.y }, to = { e0.x, e0.y }, surface = s }))
    vis(j, "ray2", rendering.draw_line({ color = rgba(1, 1, 1, 1), width = 18, from = { o.x, o.y }, to = { e0.x, e0.y }, surface = s }))
    j.vis.rayon = {}
    for k = 0, 15 do j.vis.rayon[k + 1] = halo(j, { o.x, o.y }, 0.45, 0.45, { 0.6, 0.85, 1.0 }, 0.7, "air-object") end
    vis(j, "bout", halo(j, { e0.x, e0.y }, 1.4, 1.4, { 1.0, 0.95, 0.85 }, 1.0, "air-object"))
    vis(j, "bout_lum", lumiere(j, { e0.x, e0.y }, 8, col, 1.0))
  elseif j.id == "trombe" then
    vis(j, "trombe_lum", lumiere(j, c, 6, col, 0.8))
  elseif j.id == "ixion" then
    -- la lance : une chaîne de halos du cœur solaire à la cible
    j.vis.lance = {}
    local b = bouche(j)
    for k = 0, 23 do
      local t = k / 23
      local p = { b.x + (c.x - b.x) * t, b.y + (c.y - b.y) * t }
      j.vis.lance[#j.vis.lance + 1] = halo(j, p, 0.42, 0.42, col, 0.9, "air-object")
      j.vis.lance[#j.vis.lance + 1] = halo(j, p, 0.16, 0.16, { 1, 0.95, 0.8 }, 1.0, "air-object", nil, true)
    end
    vis(j, "cible", halo(j, c, 1.0, 1.0, col, 0.9, "air-object"))
    vis(j, "lance_lum", lumiere(j, c, 8, col, 1.0))
  elseif j.id == "tournesol" then
    for _, id in ipairs(j.vis.couronne or {}) do detruit(id) end
    j.vis.rayon = {}
    for k = 0, 19 do j.vis.rayon[k + 1] = halo(j, c, 0.38, 0.38, col, 0.75, "air-object") end
    vis(j, "coeur", rendering.draw_line({ color = rgba(1, 1, 0.92, 1), width = 4, from = j.e, from_offset = BOUCHE.tournesol, to = c, surface = s }))
    vis(j, "point1", halo(j, c, 1.3, 1.3, col, 0.9, "air-object"))
    vis(j, "point2", rendering.draw_sprite({ sprite = "fo-bourdon-flash", target = c, surface = s, x_scale = 0.18, y_scale = 0.18, render_layer = "air-object" }))
    vis(j, "point_lum", lumiere(j, c, 8, col, 1.0))
  end
end

--- Le géant redescend de l'éclat de la frappe à une lueur forte, jusqu'à la fin.
local function declin(j, rt)
  if rt % 3 == 0 and rt <= 90 then lueurs(j, 2.5 - 1.5 * rt / 90) end
end

---------------------------------------------------------------------------------------------------
-- Cairn
---------------------------------------------------------------------------------------------------
--- La foudre tombe du ciel sur `pos` (grande : le premier poteau, ou le centre sans réseau).
function V.foudre(j, pos, grande)
  local s = j.surface
  local haut = { pos.x + 3, pos.y - 42 }
  s.create_entity({ name = P .. "foudre", position = haut, source_position = haut, target_position = { pos.x, pos.y }, duration = grande and 26 or 12 })
  if grande then
    s.create_entity({ name = P .. "foudre", position = haut, source_position = { pos.x - 5, pos.y - 40 }, target_position = { pos.x, pos.y }, duration = 20 })
    s.create_entity({ name = P .. "eclat-blanc", position = { pos.x, pos.y } })
    s.create_entity({ name = P .. "eclat-bleu-grand", position = { pos.x, pos.y } })
    son(j, "cairn-fin", pos)
  end
  s.create_entity({ name = P .. "eclat-bleu", position = { pos.x, pos.y } })
end

--- Un saut de la surtension : l'arc reste tendu du parent au poteau jusqu'au climax (`reste` ticks), le poteau brille.
function V.saut(j, de, vers, premier, reste)
  local s = j.surface
  local p = vers.position
  if premier then V.foudre(j, p, true) end
  if de and de.valid then
    local q = de.position
    s.create_entity({ name = Xp.PREFIX .. "cairn-arc", position = q, source_position = q, target_position = { p.x, p.y }, duration = reste + 2 })
  end
  halo(j, vers, 0.5, 0.5, COUL.cairn, 0.75, "air-object", reste + 2)
  s.create_entity({ name = P .. "eclat-bleu", position = { p.x, p.y } })
  local cs, sn = B.dir(((vers.unit_number or 0) % 16) / 16)
  s.create_particle({ name = "spark-particle", position = { p.x, p.y }, movement = { cs * 0.08, sn * 0.08 }, height = 1.5, vertical_speed = 0.06,
    frame_speed = 1 })
end

--- Le climax : tout ce qui a été atteint saute (en quelques ticks : script/robots/attaques2.lua, A.POTEAUX par tick).
function V.climax_son(j)
  son(j, "cairn-fin")
  lumiere(j, j.c, 40, COUL.cairn, 1.0, 40)
end

--- Captures du 7/11 : un grand éclat bleu par poteau (60 à 120 en 6 à 12 ticks, additifs) faisait une nappe blanche sur toute la base. Le grand
--- éclat ne sort plus que sur un poteau sur six ; les autres prennent l'éclat sombre, qui laisse voir les explosions.
function V.climax_poteau(j, e, k)
  local p = e.position
  j.surface.create_entity({ name = "big-explosion", position = { p.x, p.y } })
  j.surface.create_entity({ name = P .. ((k or 1) % 6 == 1 and "eclat-bleu-grand" or "eclat-bleu-sombre"), position = { p.x, p.y } })
end

---------------------------------------------------------------------------------------------------
-- Stylet
---------------------------------------------------------------------------------------------------
--- Le nez laboure : fissure chaude qui refroidit en cicatrice, poussière et éclats des deux côtés, gerbes d'étincelles d'or.
function V.pointe(j, rt, x, y)
  local a = A.ATTAQUES.stylet
  local s = j.surface
  local fin = math.ceil(math.abs(j.traits[1].a - j.traits[1].de) / a.vitesse)
  if ok(j.vis.nez_lum) then rendering.set_target(j.vis.nez_lum, { x, y }) end
  if rt > fin then
    if rt == fin + 1 then
      s.create_entity({ name = P .. "eclat-blanc", position = { x, y } })
      s.create_entity({ name = "big-explosion", position = { x, y } })
      son(j, "stylet", { x = x, y = y })
      detruit(j.vis.nez_lum)
    end
    return
  end
  declin(j, rt)
  if rt % 3 == 0 then
    fissure(j, { x, y }, 0.25, (rt / 3) % 6 + 1, 240, 4800, 1.0)
    for k = -1, 1, 2 do
      s.create_trivial_smoke({ name = "fo-bourdon-poussiere", position = { x + k * 4, y } })
      s.create_particle({ name = "stone-particle", position = { x + k * 1.5, y }, movement = { k * 0.16, -0.03 }, height = 0.4,
        vertical_speed = 0.12, frame_speed = 1 })
    end
  end
  if rt % 4 == 0 then s.create_entity({ name = P .. "eclat-feu", position = { x, y } }) end
end

--- Le balayage, à chaque tick : le rayon suit son bout ; au bout, le sol explose et brûle ; le long du rayon, de la fumée.
function V.balayage(j, rt, x, y)
  declin(j, rt)
  local s, o = j.surface, j.o
  for _, k in ipairs({ "ray1", "ray2" }) do if ok(j.vis[k]) then rendering.set_to(j.vis[k], { x, y }) end end
  for k, id in ipairs(j.vis.rayon or {}) do
    if ok(id) then
      local t = k / #j.vis.rayon
      rendering.set_target(id, { o.x + (x - o.x) * t, o.y + (y - o.y) * t })
    end
  end
  for _, k in ipairs({ "bout", "bout_lum" }) do if ok(j.vis[k]) then rendering.set_target(j.vis[k], { x, y }) end end
  if rt % 3 == 0 then s.create_entity({ name = P .. "eclat-feu", position = { x, y } }) end
  if rt % 6 == 0 then
    s.create_entity({ name = "big-explosion", position = { x, y } })
    local t = ((rt / 6) % 5 + 1) / 6
    s.create_trivial_smoke({ name = "fo-bourdon-fumee", position = { o.x + (x - o.x) * t, o.y + (y - o.y) * t } })
  end
  if rt % 4 == 0 then
    s.create_particle({ name = "stone-particle", position = { x, y }, movement = { 0.1 * ((rt % 7) - 3) / 3, -0.06 }, height = 0.4,
      vertical_speed = 0.12, frame_speed = 1 })
  end
end

function V.balayage_fin(j, rt)
  if j.vis.fini then return end
  j.vis.fini = true
  for _, k in ipairs({ "ray1", "ray2", "bout", "bout_lum", "nez" }) do detruit(j.vis[k]) end
  for _, id in ipairs(j.vis.rayon or {}) do detruit(id) end
  local e = j.rayons[#j.rayons]
  j.surface.create_entity({ name = P .. "eclat-blanc", position = { e.x, e.y } })
  son(j, "stylet", e)
end

--- Une falaise se lève : explosion, poussière, éclats.
function V.falaise(j, f)
  local s = j.surface
  s.create_entity({ name = "big-explosion", position = { f.x, f.y } })
  s.create_trivial_smoke({ name = "fo-bourdon-poussiere", position = { f.x - 1.5, f.y } })
  s.create_trivial_smoke({ name = "fo-bourdon-poussiere", position = { f.x + 1.5, f.y } })
  for k = 0, 3 do
    local cs, sn = B.dir(k / 4 + 0.125)
    s.create_particle({ name = "stone-particle", position = { f.x, f.y }, movement = { cs * 0.12, sn * 0.12 }, height = 0.5,
      vertical_speed = 0.12, frame_speed = 1 })
  end
end

---------------------------------------------------------------------------------------------------
-- Trombe
---------------------------------------------------------------------------------------------------
--- La Trombe parcourt la base : mur de poussière tournant à son pied, débris projetés, sol raclé (la suie du Glas) qui reste une minute.
function V.cyclone(j, rt, x, y)
  local a = A.ATTAQUES.trombe
  local s = j.surface
  if ok(j.vis.trombe_lum) then rendering.set_target(j.vis.trombe_lum, { x, y }) end
  if rt > a.duree then
    if rt == a.duree + 1 then
      -- la Trombe se pose : la poussière retombe en anneau
      for k = 0, 23 do
        local cs, sn = B.dir(k / 24)
        s.create_trivial_smoke({ name = "fo-bourdon-poussiere", position = { x + cs * 9, y + sn * 9 } })
      end
      s.create_entity({ name = P .. "eclat-glace", position = { x, y } })
      detruit(j.vis.trombe_lum)
    end
    return
  end
  declin(j, rt)
  for k = 0, 2 do
    local cs, sn = B.dir(rt * 0.045 + k / 3)
    s.create_trivial_smoke({ name = P .. "tornade", position = { x + cs * 6.5, y + sn * 5 } })
  end
  if rt % 2 == 0 then
    local cs, sn = B.dir(rt * 0.045 + 0.17)
    s.create_particle({ name = (rt % 4 == 0) and "stone-particle" or "wooden-particle", position = { x + cs * 4, y + sn * 4 },
      movement = { -sn * 0.22 + cs * 0.05, cs * 0.22 + sn * 0.05 }, height = 1 + (rt % 5), vertical_speed = 0.14, frame_speed = 1 })
  end
  if rt % 8 == 0 then
    rendering.draw_sprite({ sprite = "fo-bourdon-balaye", target = { x, y }, surface = s, x_scale = 0.17, y_scale = 0.17,
      orientation = (rt % 64) / 64, render_layer = "ground-patch", time_to_live = 3600 })
    s.create_trivial_smoke({ name = "fo-bourdon-poussiere", position = { x, y } })
  end
end

---------------------------------------------------------------------------------------------------
-- Ixion
---------------------------------------------------------------------------------------------------
function V.lance(j, rt)
  declin(j, rt)
  local col = COUL.ixion
  local v = 0.75 + 0.25 * ((rt % 3) / 2)
  for k, id in ipairs(j.vis.lance or {}) do
    if k % 2 == 1 and ok(id) then rendering.set_color(id, rgba(col[1], col[2], col[3], v)) end
  end
  if ok(j.vis.cible) then
    rendering.set_x_scale(j.vis.cible, 1.0 + rt * 0.04)
    rendering.set_y_scale(j.vis.cible, 1.0 + rt * 0.04)
  end
  if rt % 4 == 0 then j.surface.create_entity({ name = P .. "eclat-feu", position = { j.c.x, j.c.y } }) end
end

--- L'éruption : colonne de feu, bombes de lave vers l'anneau, poussière ; plus rien de la bombe atomique vanilla.
function V.eruption(j, a)
  local s, c = j.surface, j.c
  for _, id in ipairs(j.vis.lance or {}) do detruit(id) end
  detruit(j.vis.lance_lum)
  detruit(j.vis.cible)
  son(j, "ixion-fin")
  s.create_entity({ name = P .. "eclat-blanc", position = { c.x, c.y } })
  for k = 0, 5 do s.create_entity({ name = P .. "eclat-feu", position = { c.x, c.y - k * 2.2 } }) end
  for k = 0, 5 do
    local cs, sn = B.dir(k / 6 + 0.05)
    s.create_entity({ name = "big-explosion", position = { c.x + cs * 3, c.y + sn * 3 } })
  end
  for k = 1, math.min(a.bombes, #j.feux) do
    local p = j.feux[k]
    s.create_entity({ name = P .. "bombe", position = { c.x, c.y }, source_position = { c.x, c.y - 2 }, target_position = { p.x, p.y } })
  end
  for k = 0, 11 do
    local cs, sn = B.dir(k / 12)
    s.create_trivial_smoke({ name = P .. "vapeur", position = { c.x + cs * 4, c.y + sn * 4 - 2 } })
  end
  lumiere(j, c, 50, COUL.ixion, 1.0, 120)
end

function V.anneau(j, f1)
  local s, c = j.surface, j.c
  for k = 0, 11 do
    local cs, sn = B.dir(k / 12 + 0.04 * f1)
    local r = A.bord(j.bords, A.pseudo_angle(cs, sn)) * f1
    if k % 2 == 0 then s.create_entity({ name = "fo-bourdon-flamme", position = { c.x + cs * r, c.y + sn * r } }) end
    if k % 4 == 1 then s.create_trivial_smoke({ name = P .. "vapeur", position = { c.x + cs * r, c.y + sn * r - 1 } }) end
  end
end

--- Le lac : une croûte couverte de fissures chaudes, qui s'éteignent du bord vers le centre au rythme du refroidissement ; la cicatrice
--- noire reste ensuite. Lueur au sol (visible de jour) et lumière (la nuit).
function V.lac(j, a)
  local c, col = j.c, COUL.ixion
  local etat = { v = j.graine % 2147483646 + 1 }
  local n = math.floor(j.rl * j.rl * 0.35)
  for k = 1, n do
    local cs, sn = B.dir(B.alea(etat))
    local f = math.sqrt(B.alea(etat)) * 0.95
    local r = A.bord(j.bords, A.pseudo_angle(cs, sn)) * f
    local reste = a.tenue + math.floor((1 - f) * a.refroidit)
    fissure(j, { c.x + cs * r, c.y + sn * r }, B.alea(etat), k % 6 + 1, reste, a.tenue + a.refroidit + 3600, 0.9 + 0.5 * B.alea(etat))
  end
  halo(j, c, j.rl / 5, j.rl / 5, col, 0.28, "ground-patch-higher2", a.tenue + math.floor(a.refroidit / 2))
  lumiere(j, c, j.rl / 3, col, 0.9, a.tenue + a.refroidit)
end

function V.chaleur(j, rt)
  local a = A.ATTAQUES.ixion
  declin(j, rt)
  local r = (rt - a.lance) * a.onde
  if r <= j.R and rt % 3 == 0 then
    for k = 0, 7 do
      local cs, sn = B.dir(k / 8 + rt * 0.007)
      j.surface.create_trivial_smoke({ name = P .. "vapeur", position = { j.c.x + cs * r, j.c.y + sn * r } })
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Tournesol
---------------------------------------------------------------------------------------------------
function V.zenith(j, rt, x, y, u1, u2)
  local a = A.ATTAQUES.tournesol
  declin(j, rt)
  local s = j.surface
  local p = { x, y }
  local b = bouche(j)
  for k, id in ipairs(j.vis.rayon or {}) do
    if ok(id) then
      local t = (k - 0.5) / #j.vis.rayon
      rendering.set_target(id, { b.x + (x - b.x) * t, b.y + (y - b.y) * t })
    end
  end
  if ok(j.vis.coeur) then rendering.set_to(j.vis.coeur, p) end
  for _, k in ipairs({ "point1", "point2", "point_lum" }) do if ok(j.vis[k]) then rendering.set_target(j.vis[k], p) end end
  local qx, qy = A.point_zenith(j.c, a.pas, u1)
  j.vis.trace = (j.vis.trace or 0) + math.sqrt((x - qx) ^ 2 + (y - qy) ^ 2)
  if j.vis.trace >= 2.5 then
    j.vis.trace = 0
    local o = A.pseudo_angle(x - qx, y - qy) / 4
    fissure(j, p, o, rt % 6 + 1, 300, a.tenue, 1.1)
  end
  if rt % 3 == 0 then s.create_entity({ name = "fo-bourdon-flamme", position = p }) end
  if rt % 5 == 0 then s.create_trivial_smoke({ name = "fo-bourdon-fumee", position = { x, y - 1 } }) end
end

function V.zenith_fin(j)
  local s, c = j.surface, j.c
  for _, id in ipairs(j.vis.rayon or {}) do detruit(id) end
  for _, k in ipairs({ "coeur", "point1", "point2", "point_lum" }) do detruit(j.vis[k]) end
  s.create_entity({ name = P .. "eclat-blanc", position = { c.x, c.y } })
  s.create_entity({ name = P .. "eclat-or", position = { c.x, c.y } })
  s.create_entity({ name = "massive-explosion", position = { c.x, c.y } })
  for k = 0, 11 do
    local cs, sn = B.dir(k / 12)
    s.create_entity({ name = "fo-bourdon-flamme", position = { c.x + cs * 6, c.y + sn * 6 } })
  end
  son(j, "tournesol-fin")
  lumiere(j, c, 45, COUL.tournesol, 1.0, 90)
end

---------------------------------------------------------------------------------------------------
-- Fin : tout ce qui suivait le géant ou la frappe s'éteint
---------------------------------------------------------------------------------------------------
function V.fin(j)
  for _, l in ipairs({ j.vis.lueurs, j.vis.lance, j.vis.rayon, j.vis.couronne }) do
    for _, id in ipairs(l or {}) do detruit(id) end
  end
  for _, k in ipairs({ "lum_geant", "nez_lum", "trombe_lum", "lance_lum", "cible", "coeur", "point1", "point2", "point_lum", "ray1", "ray2", "bout",
    "bout_lum", "nez" }) do
    detruit(j.vis[k])
  end
end

return V
