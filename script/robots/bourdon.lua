--[[
  LE BOURDON en jeu (lot BOURDON, 1er/11) : cloche-cathédrale en lévitation, âge 15. Règles pures : shared/robots/bourdon.lua.

  L'entité est un `spider-vehicle` sans image ; tout ce qu'on voit passe par `rendering`, attaché à l'entité : cloche, lueurs, battant, ombre, 6 chaînes, 6 ancres.
  DÉCISION chaînes et ancres : posées à l'arrêt (6 ancres plantées au sol, griffes de terre, chaînes tendues, comme la planche), REMONTÉES au treuil pour le vol (la chaîne
  glisse dans la cloche, dessinée derrière elle ; l'ancre reste pendue sous la lèvre et se balance), retombent à l'arrivée, l'une après l'autre. Une ancre ne glisse donc jamais sur le sol.

  LE GLAS : le battant recule, les vitraux montent (70 ticks) ; il frappe : éclair à la lèvre, son ; une onde de choc court au sol, dégâts réels par tranches à mesure qu'elle
  avance, jamais sur la force de la cloche ni ses alliés, ni en cessez-le-feu ; fissures qui s'ouvrent à son passage, or qui refroidit puis cicatrice noire qui se referme par morceaux ;
  sol balayé ; poussière (`trivial-smoke`), éclats, lumière. Tous les objets de `rendering` du Glas ont un `time_to_live` : rien à nettoyer après.

  Commandes de DÉMONSTRATION : /fo-bourdon, /fo-glas ; touche Ctrl + Maj + G (Glas vers le curseur) ; interface distante « fo-bourdon ».
  FABRIQUÉ (lot ROBOTS-JEU, 3/11) : l'objet du Portique pose un relais remplacé par la descente (M.pose_fabrique), plafond de géants
  vérifié ; un Bourdon vivant compte pour un géant (Armee.hooks.extra_giants). Les commandes de démonstration ne vérifient pas le plafond.
  Déterminisme : aucun `pairs`, RNG maison, table des directions (shared), forces triées par nom. `require` en tête de fichier (F24).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local B = require("shared.robots.bourdon")
local SPR = require("graphics.robots.bourdon.sprites")
local Armee = require("script.robots.armee") -- lot ROBOTS-JEU : plafond de géants d'un Bourdon fabriqué
local Mo = require("shared.robots.modele")
local Ro = require("shared.content.robots") -- lot BOURDON-SORTIE : taille de l'usine (point de sortie)
local State = require("script.faction.state") -- lot BOURDON-MINEURS : une faction ne sort pas de Bourdon (B.sortie)
local XpG = require("script.robots.experimentaux_geants") -- règle d'échelle : cible « tout ce qui est ennemi » (lot EXPERIMENTAUX-PUISSANCE)
local Ech = require("shared.robots.echelle") -- séquelles du Glas : 10 min (QCM-7/11 : « non temporaire mais de 10 minutes »)
local SPRM = require("graphics.robots.megabourdon.sprites") -- lot MEGA-BOURDON : corps cuirassé, casemates (bouches : SPRM.canons)
local A = require("shared.content.arsenal") -- lot MEGA-BOURDON : orbe du Bastion, que les casemates tirent à l’âge 15
-- Traces du Glas : sol balayé et cicatrices des fissures durent Ech.TRACE_GLAS_TICKS ; le sol s'efface sur les 10 dernières secondes, les
-- cicatrices se referment morceau par morceau sur les 20 dernières (même étalement qu'avant, 70 s et 47 à 67 s).
local GLAS_FONDU, GLAS_REFERME = 600, 1200

local M = {}

Storage.declare("bourdon", function() return { liste = {}, prochain = 1, balayes = {} } end)

local function st() return Storage.ns("bourdon") end

local OR = { r = 1.0, g = 0.82, b = 0.46 }
local COUCHE_AIR = "air-object"
local COUCHE_DERRIERE = "smoke"   -- chaînes, battant, ancres pendues : derrière la cloche
local COUCHE_OMBRE = "lower-object"
local COUCHE_ANCRE = "object"
local CYAN = { r = 0.5, g = 0.95, b = 1.0, a = 1.0 } -- lot MEGA-BOURDON : teinte des lueurs additives (la feuille est d'un cyan presque blanc, qui sature)
local COUCHE_TOURELLE = "air-entity-info-icon" -- lot MEGA-BOURDON : les tourelles, devant la cloche (couche juste au-dessus d'« air-object »)

local function nom(k) return "fo-bourdon-" .. k end

--- Couleur d'un dessin additif d'intensité v, bornée de 0 à 1 (une valeur hors bornes lève une erreur du moteur).
local function blanc(v)
  v = v < 0 and 0 or (v > 1 and 1 or v)
  return { r = v, g = v, b = v, a = v }
end

--- Lot MEGA-BOURDON : nom et feuille d'une couche selon la variante de la cloche b ; le Méga-Bourdon a ses propres corps, vitraux, cristaux,
--- ombre et lueur cyan (graphics/robots/megabourdon), le reste (battant, chaînes, ancres, Glas) est celui du Bourdon.
local function spr_de(b, cle)
  if b and b.v == "mega" and type(SPRM[cle]) == "table" and SPRM[cle].hr then return B.MEGA.NOM .. "-" .. cle, SPRM[cle] end
  return nom(cle), SPR[cle]
end

--- Lot ART-MEGA2 : échelle de la cloche b. Le Méga-Bourdon prend celle de ses feuilles (graphics/robots/megabourdon/sprites.lua, « echelle »,
--- rendue à B.MEGA.ECHELLE) : chaînes, ancres, battant et griffes du Bourdon y sont agrandis ; des feuilles sans échelle valent 1.
local function ech(b)
  if b and b.v == "mega" then return tonumber(SPRM.echelle) or 1 end
  return 1
end

local function dessine(surface, cle, cible, decal, couche, opts)
  local t = opts or {}
  return rendering.draw_sprite({ sprite = nom(cle), surface = surface, target = cible, target_offset = decal, render_layer = couche,
    orientation = t.orientation, x_scale = t.x_scale, y_scale = t.y_scale, tint = t.tint, visible = t.visible, time_to_live = t.time_to_live })
end

-- ---------------------------------------------------------------------------------------- construction
local ORDRE_CHUTE = { 2, 1, 3, 6, 4, 5 } -- les ancres de devant d'abord

-- Lot ART-MEGA2 : une couche du corps du Méga-Bourdon peut être en TUILES (feuille de plus de 4096 px : un sprite par tuile,
-- fo-mega-bourdon-<cle>-t<i>, prototypes/bourdon.lua) ; son identifiant est alors une table d'identifiants, un par tuile, que ces aides
-- traitent comme un seul.
local function tuiles_de(f) return f and f.hr and f.hr.tuiles end
local function chaque(id, fn)
  if type(id) == "table" then
    for _, x in ipairs(id) do fn(x) end
  else
    fn(id)
  end
end

--- Pose la couche id (feuille f) au décalage (x, y) de l'entité e : chaque tuile à son propre décalage.
local function cible_couche(id, f, e, x, y)
  local tu = tuiles_de(f)
  if tu and type(id) == "table" then
    for i, x1 in ipairs(id) do rendering.set_target(x1, e, { x + tu[i].decal[1], y + tu[i].decal[2] }) end
  else
    rendering.set_target(id, e, { x, y })
  end
end

local function couleurs_intensite(id, teinte, v)
  v = v < 0 and 0 or (v > 1 and 1 or v)
  local c = { r = teinte.r * v, g = teinte.g * v, b = teinte.b * v, a = v }
  chaque(id, function(x) rendering.set_color(x, c) end)
end

local function creer_corps(b)
  local s, e = b.e.surface, b.e
  b.ids = {}
  local function retient(id)
    chaque(id, function(x) b.ids[#b.ids + 1] = x end)
    return id
  end
  local function dessine_v(cle, decal, couche, opts)
    local n, f = spr_de(b, cle)
    local t = opts or {}
    local tu = tuiles_de(f)
    if tu then
      local ids = {}
      for i, tt in ipairs(tu) do
        ids[i] = rendering.draw_sprite({ sprite = n .. "-t" .. i, surface = s, target = e, target_offset = { decal[1] + tt.decal[1], decal[2] + tt.decal[2] },
          render_layer = couche, tint = t.tint })
      end
      return ids
    end
    return rendering.draw_sprite({ sprite = n, surface = s, target = e, target_offset = decal, render_layer = couche, tint = t.tint })
  end
  local function sh(cle)
    local _, f = spr_de(b, cle)
    return f.shift
  end
  b.o_ombre = retient(dessine_v("corps-ombre", { sh("corps-ombre")[1], sh("corps-ombre")[2] }, COUCHE_OMBRE))
  b.ancres = {}
  local k = ech(b)
  for i = 1, #B.ANCRES do
    local bx, by = B.bas_chaine(i, 0, k)
    local cx, cy = B.centre_chaine(i, bx, by, k)
    local ax, ay = B.ancre_depuis_bas(bx, by, k)
    local a = B.ANCRES[i]
    local gx, gy = B.sol(i, k)
    local sc = SPR["ancre"].shift
    local sl = SPR["ancre-lueur"].shift
    local so = SPR["ancre-ombre"].shift
    b.ancres[i] = {
      e = 0.0, pose = false,
      chaine = retient(dessine(s, "chaine", e, { cx, cy }, COUCHE_DERRIERE, { orientation = a.o, x_scale = 1.25 * k, y_scale = k })),
      corps = retient(dessine(s, "ancre", e, { ax + sc[1] * k, ay + sc[2] * k }, COUCHE_DERRIERE, { x_scale = k, y_scale = k })),
      lueur = retient(dessine(s, "ancre-lueur", e, { ax + sl[1] * k, ay + sl[2] * k }, COUCHE_DERRIERE, { x_scale = k, y_scale = k })),
      ombre = retient(dessine(s, "ancre-ombre", e, { gx + so[1] * k, gy + so[2] * k }, COUCHE_OMBRE, { visible = false, x_scale = k, y_scale = k })),
      o_chaine = retient(dessine(s, "chaine-ombre", e, { gx + a.ombre_u[1] * a.ombre_long * k / 2, gy + a.ombre_u[2] * a.ombre_long * k / 2 }, COUCHE_OMBRE,
        { orientation = a.ombre_o, x_scale = k, y_scale = a.ombre_long * k / B.CHAINE_OMBRE_LONG, visible = false })),
    }
  end
  b.o_lueur_sol = retient(dessine(s, "lueur-sol", e, { 0, 0 }, "ground-patch-higher2", { tint = { r = 0, g = 0, b = 0, a = 0 } }))
  local sb, sbl = SPR["battant"].shift, SPR["battant-lueur"].shift
  b.o_battant = retient(dessine(s, "battant", e, { sb[1] * k, sb[2] * k }, COUCHE_DERRIERE, { x_scale = k, y_scale = k }))
  b.o_battant_l = retient(dessine(s, "battant-lueur", e, { sbl[1] * k, sbl[2] * k }, COUCHE_DERRIERE, { x_scale = k, y_scale = k }))
  local sc, sv, sr = sh("corps"), sh("vitrail"), sh("cristal")
  b.o_corps = retient(dessine_v("corps", { sc[1], sc[2] }, COUCHE_AIR))
  b.o_vit, b.o_cri = {}, {}
  for k = 1, 3 do
    b.o_vit[k] = retient(dessine_v("vitrail", { sv[1], sv[2] }, COUCHE_AIR, { tint = k == 1 and { r = 1, g = 1, b = 1, a = 1 } or { r = 0, g = 0, b = 0, a = 0 } }))
  end
  for k = 1, 3 do
    local c = k == 1 and b.teinte or { r = 0, g = 0, b = 0, a = 0 }
    b.o_cri[k] = retient(dessine_v("cristal", { sr[1], sr[2] }, COUCHE_AIR, { tint = c }))
  end
  -- lot MEGA-BOURDON : conduits et cœurs à vortex cyan des casemates, en lueur ; une tourelle par casemate, tournée vers l'extérieur
  if b.v == "mega" and type(SPRM.vortex) == "table" then
    local sx = sh("vortex")
    b.o_vortex = retient(dessine_v("vortex", { sx[1], sx[2] }, COUCHE_AIR, { tint = CYAN }))
  end
  if b.v == "mega" and type(SPRM.canons_sol) == "table" then
    b.tourelles = {}
    for k, cs in ipairs(SPRM.canons_sol) do
      local d = B.direction16(cs[1], cs[2] / B.COS45) or 0
      local t = { d = d, vise = d }
      local f, fl = SPRM[string.format("tourelle-%02d", d)], SPRM[string.format("tourelle-lueur-%02d", d)]
      t.main = retient(rendering.draw_sprite({ sprite = B.MEGA.NOM .. string.format("-tourelle-%02d", d), surface = s, target = e,
        target_offset = { cs[1] + f.shift[1], cs[2] + f.shift[2] }, render_layer = COUCHE_TOURELLE }))
      t.lueur = retient(rendering.draw_sprite({ sprite = B.MEGA.NOM .. string.format("-tourelle-lueur-%02d", d), surface = s, target = e,
        target_offset = { cs[1] + fl.shift[1], cs[2] + fl.shift[2] }, render_layer = COUCHE_TOURELLE, tint = CYAN }))
      b.tourelles[k] = t
    end
  end
  -- lumière de nuit : la cloche éclaire le sol sous elle
  b.o_lum = retient(rendering.draw_light({ sprite = "utility/light_medium", surface = s, target = e, target_offset = { 0, -12 * k }, scale = 28 * k, intensity = 0.7, color = OR, minimum_darkness = 0.2 }))
end

--- Lot MEGA-BOURDON : la tourelle k (feuille de sa direction t.d) sur le pied de son pivot, à la hauteur courante de la cloche (b.dh).
local function place_tourelle(b, k, t)
  local cs = SPRM.canons_sol[k]
  local nm, nl = string.format("tourelle-%02d", t.d), string.format("tourelle-lueur-%02d", t.d)
  local f, fl = SPRM[nm], SPRM[nl]
  local d = b.dh or 0
  rendering.set_sprite(t.main, B.MEGA.NOM .. "-" .. nm)
  rendering.set_sprite(t.lueur, B.MEGA.NOM .. "-" .. nl)
  rendering.set_target(t.main, b.e, { cs[1] + f.shift[1], cs[2] + f.shift[2] - d })
  rendering.set_target(t.lueur, b.e, { cs[1] + fl.shift[1], cs[2] + fl.shift[2] - d })
end

--- Place tout ce qui suit le corps, d à l'écran au-dessus de la pose (flottement + descente) ; bat_o : angle du battant.
local function place_corps(b, d, om)
  local e = b.e
  local function p(id, cle)
    local _, f = spr_de(b, cle)
    local sh = f.shift
    cible_couche(id, f, e, sh[1], sh[2] - d)
  end
  p(b.o_corps, "corps")
  for k = 1, 3 do
    p(b.o_vit[k], "vitrail")
    p(b.o_cri[k], "cristal")
  end
  if b.o_vortex then p(b.o_vortex, "vortex") end
  if b.tourelles then
    b.dh = d
    for k, t in ipairs(b.tourelles) do place_tourelle(b, k, t) end
  end
  if om then
    local _, fo = spr_de(b, "corps-ombre")
    local sh = fo.shift
    cible_couche(b.o_ombre, fo, e, sh[1] + d * B.OMBRE_PAR_Z / B.COS45, sh[2])
  end
  local o = b.bat_o or 0
  local sb, sl = SPR["battant"].shift, SPR["battant-lueur"].shift
  local k = ech(b)
  local x1, y1 = B.centre_battant(sb[1] * k, sb[2] * k, o, k)
  local x2, y2 = B.centre_battant(sl[1] * k, sl[2] * k, o, k)
  rendering.set_target(b.o_battant, e, { x1, y1 - d })
  rendering.set_target(b.o_battant_l, e, { x2, y2 - d })
  rendering.set_orientation(b.o_battant, o)
  rendering.set_orientation(b.o_battant_l, o)
end

--- Une ancre : extension ex (0 repliée, 1 posée), décalage (ox, oy) (balancement et flottement quand elle est pendue).
local function place_ancre(b, i, ex, ox, oy)
  local a = b.ancres[i]
  local e = b.e
  local k = ech(b)
  local bx, by = B.bas_chaine(i, ex, k)
  bx, by = bx + ox, by + oy
  local cx, cy = B.centre_chaine(i, bx, by, k)
  rendering.set_target(a.chaine, e, { cx, cy })
  local ax, ay = B.ancre_depuis_bas(bx, by, k)
  local sc, sl = SPR["ancre"].shift, SPR["ancre-lueur"].shift
  rendering.set_target(a.corps, e, { ax + sc[1] * k, ay + sc[2] * k })
  rendering.set_target(a.lueur, e, { ax + sl[1] * k, ay + sl[2] * k })
  a.e = ex
end

local function mets_couche_ancre(a, couche)
  rendering.set_render_layer(a.corps, couche)
  rendering.set_render_layer(a.lueur, couche)
end

-- ---------------------------------------------------------------------------------------- ancres
local function impact(b, i)
  local a = b.ancres[i]
  local e = b.e
  local k = ech(b)
  local gx, gy = B.sol(i, k)
  local x, y = e.position.x + gx, e.position.y + gy
  local s = e.surface
  mets_couche_ancre(a, COUCHE_ANCRE)
  rendering.set_visible(a.ombre, true)
  rendering.set_visible(a.o_chaine, true)
  if a.griffes then
    if rendering.is_valid(a.griffes) then rendering.destroy(a.griffes) end
    if rendering.is_valid(a.griffes_o) then rendering.destroy(a.griffes_o) end
  end
  local sg, so = SPR["griffes"].shift, SPR["griffes-ombre"].shift
  a.griffes_o = dessine(s, "griffes-ombre", { x + so[1] * k, y + so[2] * k }, nil, COUCHE_OMBRE, { x_scale = k, y_scale = k })
  a.griffes = dessine(s, "griffes", { x + sg[1] * k, y + sg[2] * k }, nil, "lower-object-above-shadow", { x_scale = k, y_scale = k })
  s.create_entity({ name = "big-explosion", position = { x, y } })
  s.play_sound({ path = "fo-bourdon-ancre", position = { x, y } })
  for k = 0, 11 do
    local c, sn = B.dir(k / 12 + i * 0.03)
    s.create_trivial_smoke({ name = "fo-bourdon-poussiere", position = { x + c * 3.2 * k, y + sn * 2.4 * k } })
  end
end

local function peut_poser(b, i)
  local e = b.e
  local gx, gy = B.sol(i, ech(b))
  local x, y = e.position.x + gx, e.position.y + gy
  local t = e.surface.get_tile(x, y)
  return t and t.valid and not t.collides_with("water-tile")
end

local function lancer_chute(b, tick)
  b.phase, b.t0 = "chute", tick
  for i = 1, #B.ANCRES do
    b.ancres[i].pose = peut_poser(b, i)
    b.ancres[i].impact = false
  end
end

local function lancer_leve(b, tick)
  b.phase, b.t0 = "leve", tick
  for i = 1, #B.ANCRES do
    local a = b.ancres[i]
    a.e0 = a.e
    rendering.set_visible(a.ombre, false)
    rendering.set_visible(a.o_chaine, false)
    mets_couche_ancre(a, COUCHE_DERRIERE)
    -- griffes : restent au sol un moment
    if a.griffes and rendering.is_valid(a.griffes) then
      rendering.set_time_to_live(a.griffes, 1800)
      rendering.set_time_to_live(a.griffes_o, 1800)
    end
    a.griffes, a.griffes_o = nil, nil
  end
end

-- ---------------------------------------------------------------------------------------- le Glas
local function ennemis(force)
  local noms = {}
  local tous = {}
  for _, f in pairs(game.forces) do tous[#tous + 1] = f.name end
  B.trie(tous)
  for _, n in ipairs(tous) do
    local f = game.forces[n]
    if f ~= force and force.is_enemy(f) then noms[#noms + 1] = n end
  end
  return noms
end

--- La liste des cibles au moment du coup, rangée par tranche de distance : l'onde les touche en passant. Ce qui bouge (unités, joueurs) est relu en route.
local function relever_cibles(b, g)
  local s, cx, cy = b.e.surface, g.cx, g.cy
  g.tranches = {}
  g.forces = ennemis(b.e.force)
  if #g.forces == 0 then return end
  local liste = s.find_entities_filtered({ position = { cx, cy }, radius = B.PORTEE, force = g.forces })
  for _, ent in ipairs(liste) do
    if ent.is_entity_with_health and ent.destructible and ent.type ~= "unit" and ent.type ~= "character" then
      local dx, dy = ent.position.x - cx, ent.position.y - cy
      local tr = B.tranche(math.sqrt(dx * dx + dy * dy))
      local l = g.tranches[tr]
      if not l then l = {}; g.tranches[tr] = l end
      l[#l + 1] = ent
    end
  end
  -- les arbres tombent près du centre : une part seulement, le coût d'un Glas reste borné
  g.arbres = s.find_entities_filtered({ position = { cx, cy }, radius = 42, type = "tree", limit = 260 })
  g.a_i = 1
end

local function toucher(b, g, ent, r)
  if not ent.valid then return end
  local d = B.degats(r)
  if d <= 0 then return end
  local x, y = ent.position.x, ent.position.y
  ent.damage(d, b.e.force, "explosion", b.e)
  g.touches = g.touches + 1
  if not ent.valid then
    g.tues = g.tues + 1
    local u = B.alea(g.rng)
    local s = b.e.surface
    if u < 0.12 then
      s.create_entity({ name = "fo-bourdon-flamme", position = { x, y } })
      s.create_trivial_smoke({ name = "fo-bourdon-fumee", position = { x, y - 1 } })
    elseif u < 0.26 then
      s.create_entity({ name = "fo-bourdon-flamme2", position = { x, y } })
    elseif u < 0.36 then
      s.create_trivial_smoke({ name = "fo-bourdon-fumee", position = { x, y - 1 } })
    elseif u < 0.48 then
      s.create_entity({ name = "big-explosion", position = { x, y } })
    end
  end
end

--- Dégâts de l'avancée : tranches passées par le rayon, et unités, tous les 4 ticks.
local function degats_avance(b, g, t, r)
  local maxtr = B.tranche(math.min(r, B.PORTEE))
  while g.tr <= maxtr do
    local l = g.tranches[g.tr]
    if l then
      for k = 1, #l do
        local ent = l[k]
        if ent.valid then
          local dx, dy = ent.position.x - g.cx, ent.position.y - g.cy
          toucher(b, g, ent, math.sqrt(dx * dx + dy * dy))
        end
      end
    end
    g.tranches[g.tr] = nil
    g.tr = g.tr + 1
  end
  if t % 4 == 0 and r <= B.PORTEE and #g.forces > 0 then
    local mob = b.e.surface.find_entities_filtered({ position = { g.cx, g.cy }, radius = r + 1, type = { "unit", "character" }, force = g.forces })
    local rin = r - 8
    for _, ent in ipairs(mob) do
      if ent.valid and ent.unit_number and not g.vus[ent.unit_number] then
        local dx, dy = ent.position.x - g.cx, ent.position.y - g.cy
        local d2 = dx * dx + dy * dy
        if d2 >= rin * rin or rin < 0 then
          g.vus[ent.unit_number] = true
          toucher(b, g, ent, math.sqrt(d2))
        end
      end
    end
  end
  -- arbres
  if g.arbres and g.a_i <= #g.arbres then
    local n = 0
    while g.a_i <= #g.arbres and n < 6 do
      local a = g.arbres[g.a_i]
      if a.valid then
        local dx, dy = a.position.x - g.cx, a.position.y - g.cy
        if dx * dx + dy * dy > r * r then break end
        a.die()
        n = n + 1
      end
      g.a_i = g.a_i + 1
    end
    if g.a_i > #g.arbres then g.arbres = nil end
  end
end

local function creer_onde(b, g)
  local s = b.e.surface
  local fin = B.fin_onde() + 2
  g.cretes, g.poussieres, g.poussieres2 = {}, {}, {}
  for k = 1, B.CRETES do
    local v = 1 + math.floor(B.alea(g.rng) * 4) % 4
    local o = (k - 1) / B.CRETES
    g.cretes[k] = rendering.draw_sprite({ sprite = nom("crete-" .. v), surface = s, target = { g.cx, g.cy }, orientation = o + 0.25, render_layer = "projectile", time_to_live = fin, x_scale = 0.18 })
  end
  for k = 1, B.POUSSIERES do
    local v = 1 + math.floor(B.alea(g.rng) * 3) % 3
    local o = (k - 1) / B.POUSSIERES
    g.poussieres2[k] = rendering.draw_sprite({ sprite = nom("poussiere-" .. (v % 3 + 1)), surface = s, target = { g.cx, g.cy }, orientation = o + 0.25, render_layer = "explosion", time_to_live = fin, x_scale = 0.18, y_scale = 0.3 })
    g.poussieres[k] = rendering.draw_sprite({ sprite = nom("poussiere-" .. v), surface = s, target = { g.cx, g.cy }, orientation = o + 0.25, render_layer = "explosion", time_to_live = fin, x_scale = 0.18, y_scale = 0.3 })
  end
  g.lumieres = {}
  for k = 1, 12 do
    g.lumieres[k] = rendering.draw_light({ sprite = "utility/light_medium", surface = s, target = { g.cx, g.cy }, scale = 7, intensity = 0.9, color = OR, minimum_darkness = 0.1, time_to_live = fin })
  end
end

local function creer_onde2(b, g)
  local s = b.e.surface
  g.cretes2 = {}
  local fin = B.fin_onde2() - B.DEBUT_ONDE2 + 2
  for k = 1, B.CRETES2 do
    local v = 1 + math.floor(B.alea(g.rng) * 2) % 2
    g.cretes2[k] = rendering.draw_sprite({ sprite = nom("crete2-" .. v), surface = s, target = { g.cx, g.cy }, orientation = (k - 1) / B.CRETES2 + 0.25, render_layer = "projectile", time_to_live = fin, x_scale = 0.18 })
  end
end

--- Le coup : position fixée, éclair à la lèvre, son, sol balayé, anneaux dans l'air, relevé des cibles.
local function frapper(b, g, tick)
  local e, s = b.e, b.e.surface
  g.cx, g.cy = e.position.x, e.position.y
  g.touches, g.tues, g.tr, g.vus = 0, 0, 1, {}
  g.rng = { v = (tick * 7919 + b.id * 104729) % 2147483647 + 1 }
  relever_cibles(b, g)
  g.segs = B.plan_fissures(tick + b.id * 31, g.cible_o)
  g.p = 1
  s.play_sound({ path = "fo-bourdon-glas", position = { g.cx, g.cy } })
  creer_onde(b, g)
  -- éclair : côté de la frappe, sur la lèvre
  local zy = -B.Z_LEVRE * B.COS45
  g.fx, g.fy = g.cx + g.sens * 11.5, g.cy + zy - 1
  g.o_flash = dessine(s, "flash", { g.fx, g.fy }, nil, "air-entity-info-icon", { time_to_live = 28 })
  g.o_flash2 = dessine(s, "flash", { g.cx, g.cy + zy + 2 }, nil, "air-object", { time_to_live = 42, x_scale = 1.8, y_scale = 1.2 })
  g.o_lum = rendering.draw_light({ sprite = "utility/light_medium", surface = s, target = { g.cx, g.cy }, scale = 50, intensity = 1.0, color = OR, minimum_darkness = 0.0, time_to_live = 92 })
  g.o_anneaux = {
    dessine(s, "anneau-air", { g.cx, g.cy + zy }, nil, "smoke", { time_to_live = 58 }),
    dessine(s, "anneau-air", { g.cx, g.cy + zy }, nil, "smoke", { time_to_live = 58 }),
  }
  g.balaye = dessine(s, "balaye", { g.cx, g.cy }, nil, "ground-patch", { time_to_live = Ech.TRACE_GLAS_TICKS, x_scale = 0.01, y_scale = 0.01 })
  local L = st().balayes
  L[#L + 1] = { id = g.balaye, t = tick }
  -- le souffle sous la cloche
  for k = 0, 31 do
    local c, sn = B.dir(k / 32)
    s.create_trivial_smoke({ name = "fo-bourdon-poussiere", position = { g.cx + c * 7, g.cy + sn * 5 } })
  end
  s.create_entity({ name = "massive-explosion", position = { g.cx, g.cy } })
end

local function ouvre_fissures(b, g, r)
  local s = b.e.surface
  local segs = g.segs
  while g.p <= #segs and segs[g.p].r <= r do
    local sg = segs[g.p]
    local xs = B.FISSURE_PAS / B.FISSURE_LONG * 1.25
    local ye = sg.e * (sg.n == 0 and 1.15 or 0.85)
    local cible = { g.cx + sg.x, g.cy + sg.y }
    rendering.draw_sprite({ sprite = nom("fissure-" .. sg.v), surface = s, target = cible, orientation = sg.o, x_scale = xs, y_scale = ye,
      render_layer = "ground-patch-higher", time_to_live = Ech.TRACE_GLAS_TICKS - GLAS_REFERME + math.floor(GLAS_REFERME * sg.vc) })
    rendering.draw_sprite({ sprite = nom("fissure-chaude-" .. sg.v), surface = s, target = cible, orientation = sg.o, x_scale = xs, y_scale = ye,
      render_layer = "ground-patch-higher2", time_to_live = 70 + math.floor(90 * sg.vh) })
    rendering.draw_sprite({ sprite = nom("fissure-chaude-" .. sg.v), surface = s, target = cible, orientation = sg.o, x_scale = xs, y_scale = ye,
      render_layer = "ground-patch-higher2", time_to_live = 200 + math.floor(280 * sg.vh), tint = { r = 0.5, g = 0.4, b = 0.3, a = 0.5 } })
    g.p = g.p + 1
  end
end

local function onde(b, g, t, r)
  local s = b.e.surface
  local f = B.force_onde(r)
  local maj = t % 3 == 0
  if maj then
    local xs = B.echelle_arc(r, B.CRETES, B.CRETE_LONG)
    local a = f
    local col = blanc(a)
    local yc = 0.95 + math.min(1.0, r / 60) * 0.85
    for k = 1, B.CRETES do
      local id = g.cretes[k]
      rendering.set_x_scale(id, xs)
      rendering.set_y_scale(id, yc)
      if f < 1 then rendering.set_color(id, col) end
    end
  end
  for k = 1, B.CRETES do
    local c, sn = B.dir((k - 1) / B.CRETES)
    rendering.set_target(g.cretes[k], { g.cx + c * r, g.cy + sn * r })
  end
  local hp = B.hauteur_poussiere(r)
  if maj then
    local xs = B.echelle_arc(r, B.POUSSIERES, B.POUSSIERE_LONG)
    local ys = 0.35 + math.min(1.0, r / 60) * 1.05
    local a = f * 0.95
    local col = blanc(a)
    local col2 = blanc(a * 0.6)
    for k = 1, B.POUSSIERES do
      local id = g.poussieres[k]
      rendering.set_x_scale(id, xs)
      rendering.set_y_scale(id, ys)
      rendering.set_color(id, col)
      local id2 = g.poussieres2[k]
      rendering.set_x_scale(id2, xs * 1.1)
      rendering.set_y_scale(id2, ys * 1.25)
      rendering.set_color(id2, col2)
    end
  end
  for k = 1, B.POUSSIERES do
    local c, sn = B.dir((k - 1) / B.POUSSIERES)
    rendering.set_target(g.poussieres[k], { g.cx + c * r, g.cy + sn * r - hp })
    rendering.set_target(g.poussieres2[k], { g.cx + c * (r - 1), g.cy + sn * (r - 1) - hp * 2.1 })
  end
  for k = 1, 12 do
    local c, sn = B.dir((k - 1) / 12)
    rendering.set_target(g.lumieres[k], { g.cx + c * r, g.cy + sn * r })
  end
  -- poussière au front, éclats projetés
  for _ = 1, 22 do
    local c, sn = B.dir(B.alea(g.rng))
    local rr = r + 1.5 * (B.alea(g.rng) - 0.5)
    s.create_trivial_smoke({ name = "fo-bourdon-poussiere", position = { g.cx + c * rr, g.cy + sn * rr } })
  end
  if t % 2 == 0 and r <= B.PORTEE then
    for _ = 1, 8 do
      local c, sn = B.dir(B.alea(g.rng))
      s.create_particle({ name = "stone-particle", position = { g.cx + c * r, g.cy + sn * r }, movement = { c * 0.18, sn * 0.18 },
        height = 0.4, vertical_speed = 0.08 + 0.12 * B.alea(g.rng), frame_speed = 1 })
    end
  end
end

local function onde2(g, t)
  local r = B.rayon2(t)
  local maj = t % 3 == 0
  if maj then
    local xs = B.echelle_arc(r, B.CRETES2, B.CRETE_LONG)
    local a = (1 - r / B.R_FIN2) * 0.7
    local col = blanc(a)
    for k = 1, B.CRETES2 do
      rendering.set_x_scale(g.cretes2[k], xs)
      rendering.set_color(g.cretes2[k], col)
    end
  end
  for k = 1, B.CRETES2 do
    local c, sn = B.dir((k - 1) / B.CRETES2)
    rendering.set_target(g.cretes2[k], { g.cx + c * r, g.cy + sn * r })
  end
end

local function eclairs(b, g, t)
  if t <= 26 then
    local v = 1 - t / 26
    rendering.set_color(g.o_flash, blanc(v))
    local e = 0.9 + t * 0.03
    rendering.set_x_scale(g.o_flash, e)
    rendering.set_y_scale(g.o_flash, e)
  end
  if t <= 40 then
    local v = (1 - t / 40) * 0.8
    rendering.set_color(g.o_flash2, blanc(v))
  end
  if t <= 90 then
    rendering.set_intensity(g.o_lum, (1 - t / 90) * 1.0)
    rendering.set_scale(g.o_lum, 50 + t * 0.7)
  end
  if t <= 56 then
    for j = 1, 2 do
      local r = 7 + (t + (j - 1) * 13) * 0.62 + (j == 1 and 9 or 0)
      local v = (1 - t / 56) * (1 - 0.3 * (j - 1)) * 0.95
      rendering.set_x_scale(g.o_anneaux[j], r / 15)
      rendering.set_y_scale(g.o_anneaux[j], r / 15 * B.COS45)
      rendering.set_color(g.o_anneaux[j], blanc(v))
    end
  end
  -- la chute de l'éclat sous la cloche
  if t <= 70 then
    local v = t <= 8 and (0.2 + t * 0.09) or (0.92 * (1 - (t - 8) / 62))
    v = v * v
    rendering.set_color(b.o_lueur_sol, blanc(v))
    rendering.set_x_scale(b.o_lueur_sol, 1.1)
    rendering.set_y_scale(b.o_lueur_sol, 0.8)
  end
  local bal = g.balaye
  if rendering.is_valid(bal) and t % 2 == 0 and t <= B.fin_onde() then
    local e = math.max(0.02, B.rayon(t) / 50)
    rendering.set_x_scale(bal, e)
    rendering.set_y_scale(bal, e)
  end
end

local function pas_glas(b, g, tick)
  local t = tick - g.frappe
  if t == 0 then frapper(b, g, tick) end
  -- charge et oscillation : battant et vitraux
  if t <= B.FIN_BALANCE then
    b.bat_o = B.balance(t, g.sens)
    local a1, a2, a3 = B.copies(B.vitraux(t))
    couleurs_intensite(b.o_vit[1], { r = 1, g = 1, b = 1 }, a1)
    couleurs_intensite(b.o_vit[2], { r = 1, g = 1, b = 1 }, a2)
    couleurs_intensite(b.o_vit[3], { r = 1, g = 1, b = 1 }, a3)
    local c1, c2, c3 = B.copies(B.cristal(t))
    couleurs_intensite(b.o_cri[1], b.teinte, c1)
    couleurs_intensite(b.o_cri[2], b.teinte, c2)
    couleurs_intensite(b.o_cri[3], b.teinte, c3)
  else
    b.bat_o = nil
  end
  if t < 0 then return end
  eclairs(b, g, t)
  local fin = B.fin_onde()
  if t <= fin then
    local r = B.rayon(t)
    onde(b, g, t, r)
    degats_avance(b, g, t, r)
    ouvre_fissures(b, g, r)
  end
  if t == B.DEBUT_ONDE2 then creer_onde2(b, g) end
  if t > B.DEBUT_ONDE2 and t <= B.fin_onde2() then onde2(g, t) end
  if t > math.max(fin, B.fin_onde2(), B.FIN_BALANCE) then
    b.dernier = { touches = g.touches, tues = g.tues, x = g.cx, y = g.cy, tick = g.frappe }
    b.glas = nil
  end
end

--- Lance un Glas. ordre : par le joueur (recharge courte). (tx, ty) : cible, ou nil. Rend vrai si le coup part.
local function sonner(b, tick, ordre, tx, ty)
  if b.glas or b.phase == "descente" or b.phase == "retire" then return false end
  if tick < b.recharge then return false end
  local sens, cible_o = 1, nil
  if tx then
    local p = b.e.position
    local dx, dy = tx - p.x, ty - p.y
    sens = dx < 0 and -1 or 1
    -- orientation vers la cible, par le table des directions : recherche directe, pas de trigonométrie
    local mieux, mo = -2, 0
    local d = math.sqrt(dx * dx + dy * dy)
    if d > 0.5 then
      for k = 0, 63 do
        local c, s = B.dir(k / 64)
        local pr = (c * dx + s * dy) / d
        if pr > mieux then mieux, mo = pr, k / 64 end
      end
      cible_o = mo
    end
  end
  b.glas = { frappe = tick + B.CHARGE, sens = sens, cible_o = cible_o, ordre = ordre }
  b.recharge = tick + (ordre and B.RECHARGE_ORDRE or B.RECHARGE_AUTO)
  b.compte = (b.compte or 0) + 1
  return true
end

-- ---------------------------------------------------------------------------------------- vie
local function pas_phase(b, tick)
  local e = b.e
  local t = tick - b.t0
  local bob = B.flottement(tick, b.id)
  if b.phase == "descente" then
    local h = B.hauteur_descente(t)
    place_corps(b, h + bob, true)
    for i = 1, #B.ANCRES do place_ancre(b, i, 0, 0, -(h + bob)) end
    if t >= B.DESCENTE then
      e.surface.play_sound({ path = "fo-bourdon-ancre", position = e.position })
      lancer_chute(b, tick)
    end
    return
  end
  if b.phase == "retire" then
    local h = (t / 240) ^ 2 * B.DESCENTE_H
    place_corps(b, h + bob, true)
    for i = 1, #B.ANCRES do place_ancre(b, i, 0, 0, -(h + bob)) end
    if t >= 240 then e.destroy() end
    return
  end
  -- ordre reçu (télécommande de vanilla, commande, interface distante) : on lève avant de partir
  if (b.phase == "pose" or b.phase == "chute") and e.autopilot_destination then
    b.route = {}
    for _, p in ipairs(e.autopilot_destinations) do b.route[#b.route + 1] = { x = p.x, y = p.y } end
    e.autopilot_destination = nil
    lancer_leve(b, tick)
    t = 0
  elseif b.phase == "leve" and e.autopilot_destination then
    b.route = {}
    for _, p in ipairs(e.autopilot_destinations) do b.route[#b.route + 1] = { x = p.x, y = p.y } end
    e.autopilot_destination = nil
  end
  if b.phase == "chute" then
    local fini = true
    for rang, i in ipairs(ORDRE_CHUTE) do
      local a = b.ancres[i]
      if a.pose then
        local u = (t - (rang - 1) * B.CHUTE_PAS) / B.CHUTE
        if u >= 1 then
          if not a.impact then
            place_ancre(b, i, 1, 0, 0)
            a.impact = true
            impact(b, i)
          end
        elseif u > 0 then
          place_ancre(b, i, B.ext_chute(u), B.oscille(tick, i) * (1 - u), bob * (1 - u))
          fini = false
        else
          place_ancre(b, i, 0, B.oscille(tick, i), bob)
          fini = false
        end
      else
        place_ancre(b, i, 0, B.oscille(tick, i), bob)
      end
    end
    if fini then
      b.phase, b.t0 = "pose", tick
      -- lot BOURDON-SORTIE : sorti du Portique, il gagne le ralliement de l'usine une fois ses ancres posées (le tick suivant, l'ordre lève les ancres)
      if b.ralliement then
        e.autopilot_destination = { b.ralliement.x, b.ralliement.y }
        b.ralliement = nil
      end
    end
  elseif b.phase == "leve" then
    local fini = true
    for rang, i in ipairs(ORDRE_CHUTE) do
      local a = b.ancres[i]
      local u = (t - (rang - 1) * B.LEVE_PAS) / B.LEVE
      if u < 1 then fini = false end
      if a.e0 > 0 then
        place_ancre(b, i, a.e0 * B.ext_leve(u), 0, 0)
      end
    end
    if fini then
      if b.route and #b.route > 0 then
        for _, p in ipairs(b.route) do e.add_autopilot_destination(p) end
        b.route = nil
        b.phase, b.t0 = "vol", tick
      else
        lancer_chute(b, tick)
      end
    end
  elseif b.phase == "vol" then
    if tick % 3 == 0 then
      for i = 1, #B.ANCRES do place_ancre(b, i, 0, B.oscille(tick, i), bob) end
    end
    if tick % 7 == 0 then
      local p = e.position
      local c, sn = B.dir(B.alea(b.rng))
      e.surface.create_trivial_smoke({ name = "fo-bourdon-poussiere", position = { p.x + c * 9, p.y + sn * 7 } })
    end
    if not e.autopilot_destination then
      b.route = nil
      lancer_chute(b, tick)
    end
  end
  if tick % 3 == 0 or b.glas then
    place_corps(b, bob, false)
  end
end

local function fin_bourdon(b)
  for _, id in ipairs(b.ids) do
    if rendering.is_valid(id) then rendering.destroy(id) end
  end
  for i = 1, #b.ancres do
    local a = b.ancres[i]
    if a.griffes and rendering.is_valid(a.griffes) then
      rendering.set_time_to_live(a.griffes, 1800)
      rendering.set_time_to_live(a.griffes_o, 1800)
    end
  end
end

-- ---------------------------------------------------------------------------------------- casemates du Méga-Bourdon (lot MEGA-BOURDON)
local ARME_MEGA -- valeurs pures (B.arme_mega), calculées une fois
local function arme_mega()
  if ARME_MEGA == nil then
    ARME_MEGA = B.arme_mega(A.age_turret(B.MEGA.ARME_AGE), Ech.salve(B.AGE, "laser"), Ech.salve(B.AGE, "explosion")) or false
  end
  return ARME_MEGA or nil
end

--- Chaque tourelle vise l'ennemi le plus proche à portée (XpG.cible : militaire d'abord), tourne d'un cran toutes les B.MEGA.TOURNE ticks par le
--- plus court chemin (B.pas_tourelle) et tire l'orbe de sa bouche (B.bouche) une fois alignée, en quinconce dans la recharge de l'orbe du Bastion,
--- jamais en deçà de la portée minimale. Sans cible, elle reste où elle est.
local function tir_canons(b, tick)
  local a = arme_mega()
  local canons, sols = SPRM.canons, SPRM.canons_sol
  if not (a and b.tourelles and type(canons) == "table" and type(sols) == "table") then return end
  b.canons_t = b.canons_t or {}
  local e = b.e
  local pos = e.position
  local cible
  if tick % B.MEGA.TOURNE == b.id % B.MEGA.TOURNE then
    cible = XpG.cible(e, { range = a.portee })
    b.cible = cible and cible.valid and cible or nil
  else
    cible = b.cible
  end
  if cible and not cible.valid then cible, b.cible = nil, nil end
  for k, t in ipairs(b.tourelles) do
    local sol = sols[k]
    if cible then
      local dx, dy = cible.position.x - (pos.x + sol[1]), cible.position.y - (pos.y + sol[2])
      t.vise = B.direction16(dx, dy / B.COS45) or t.vise
      if t.d ~= t.vise and tick % B.MEGA.TOURNE == b.id % B.MEGA.TOURNE then
        t.d = B.pas_tourelle(t.d, t.vise)
        place_tourelle(b, k, t)
      end
      if not b.canons_t[k] then b.canons_t[k] = tick + B.decalage_canon(k, b.id, a.recharge) end
      if tick >= b.canons_t[k] and t.d == t.vise then
        local c = canons[k]
        local bx, by = B.bouche(t.d)
        local ox, oy = pos.x + c[1] + bx, pos.y + c[2] + by
        local ddx, ddy = cible.position.x - ox, cible.position.y - oy
        if ddx * ddx + ddy * ddy >= a.portee_min * a.portee_min then
          e.surface.create_entity({ name = B.MEGA.ORBE, position = { ox, oy }, target = cible, source = e, force = e.force, speed = a.vitesse,
            max_range = a.portee * 2 })
          rendering.draw_light({ sprite = "utility/light_medium", surface = e.surface, target = { ox, oy }, scale = 4, intensity = 0.9,
            color = { r = 0.35, g = 0.95, b = 1.0 }, minimum_darkness = 0.0, time_to_live = 12 })
          b.tirs = (b.tirs or 0) + 1
        end
        b.canons_t[k] = tick + a.recharge
      end
    end
  end
end

local function sur_tick(ev)
  local etat = st()
  if not etat then return end
  local L = etat.liste
  if #L == 0 and #etat.balayes == 0 then return end
  local tick = ev.tick
  local i = 1
  while i <= #L do
    local b = L[i]
    if not (b.e and b.e.valid) then
      fin_bourdon(b)
      table.remove(L, i)
    else
      if b.glas then pas_glas(b, b.glas, tick) end
      pas_phase(b, tick)
      if b.v == "mega" and b.e.valid and b.phase == "pose" then tir_canons(b, tick) end
      if b.e.valid then
        -- attente : la cloche est allée sonner plus loin
        -- lot BOURDON-SORTIE : le Glas en attente part une fois posé, sans vol en attente (ordre reçu pendant la descente) et recharge finie
        -- (avant : consommé même en recharge, donc perdu)
        if b.phase == "pose" and b.attente and not b.glas and not b.e.autopilot_destination and tick >= b.recharge then
          -- lot BOURDON-MINEURS : portée revérifiée d'où elle s'est posée (B.reprise_glas) ; trop loin, elle s'approche d'abord, l'attente reste
          local o = B.reprise_glas(b.e.position, b.attente)
          if o and o.aller then
            M.aller(b, o.aller.x, o.aller.y)
          else
            local a = b.attente
            b.attente = nil
            sonner(b, tick, true, a.x, a.y)
          end
        elseif tick % 60 == b.id % 60 and b.phase == "pose" and not b.glas and tick >= b.recharge and not b.muet then
          -- règle d'échelle (réponses du DC du 5/11) : l'ennemi militaire le plus proche, sinon toute entité ennemie à portée, jusqu'à la fin
          local cible = XpG.cible(b.e, { range = B.PORTEE_AUTO })
          if cible then sonner(b, tick, false, cible.position.x, cible.position.y) end
        end
      end
      i = i + 1
    end
  end
  -- le sol balayé s'efface sur ses GLAS_FONDU derniers ticks
  if tick % 30 == 0 then
    local bal = etat.balayes
    local j = 1
    while j <= #bal do
      local x = bal[j]
      if not rendering.is_valid(x.id) then
        table.remove(bal, j)
      else
        local age = tick - x.t
        if age > Ech.TRACE_GLAS_TICKS - GLAS_FONDU then
          local v = math.max(0, 1 - (age - (Ech.TRACE_GLAS_TICKS - GLAS_FONDU)) / GLAS_FONDU)
          rendering.set_color(x.id, blanc(v))
        end
        j = j + 1
      end
    end
  end
end

Events.on(defines.events.on_tick, sur_tick)

-- ---------------------------------------------------------------------------------------- actions
--- Fait descendre un Bourdon. Rend le numéro, ou nil.
function M.descendre(surface, force, x, y, variante)
  local v = variante or "bourdon"
  local nom_e = B.nom_de(v)
  if not nom_e then return nil end
  local e = surface.create_entity({ name = nom_e, position = { x, y }, force = force, create_build_effect_smoke = false })
  if not e then return nil end
  local etat = st()
  e.color = force.color
  e.vehicle_automatic_targeting_parameters = { auto_target_with_gunner = false, auto_target_without_gunner = false }
  local id = etat.prochain
  etat.prochain = id + 1
  local c = force.color
  local b = { id = id, e = e, v = v, phase = "descente", t0 = game.tick, recharge = 0,
    teinte = { r = 0.5 * OR.r + 0.5 * c.r, g = 0.5 * OR.g + 0.5 * c.g, b = 0.5 * OR.b + 0.5 * c.b, a = 1 },
    rng = { v = (id * 48271 + game.tick) % 2147483647 + 1 } }
  creer_corps(b)
  local L = etat.liste
  L[#L + 1] = b
  place_corps(b, B.DESCENTE_H, true)
  for i = 1, #B.ANCRES do place_ancre(b, i, 0, 0, -B.DESCENTE_H) end
  return id
end

local function trouve(id)
  local etat = st()
  for _, b in ipairs(etat.liste) do
    if b.id == id and b.e.valid then return b end
  end
  return nil
end

--- Le Bourdon d'une force sur une surface : le premier de la liste (une par surface, en démonstration).
local function de_la_force(force, surface)
  local etat = st()
  for _, b in ipairs(etat.liste) do
    if b.e.valid and b.e.force == force and b.e.surface == surface then return b end
  end
  return nil
end

local function lancer_retrait(b)
  b.phase, b.t0 = "retire", game.tick
  for i = 1, #b.ancres do
    place_ancre(b, i, 0, 0, 0)
    rendering.set_visible(b.ancres[i].ombre, false)
    rendering.set_visible(b.ancres[i].o_chaine, false)
    mets_couche_ancre(b.ancres[i], COUCHE_DERRIERE)
  end
end

--- Donne un ordre d'aller : le script de phase lève les ancres puis part (les ordres de la télécommande de vanilla passent par la même voie).
function M.aller(b, x, y)
  b.e.autopilot_destination = { x, y }
end

local function donner_telecommande(player, b)
  if not game.item_prototypes["spidertron-remote"] then return end
  local stack = player.cursor_stack
  if stack and player.clear_cursor() and stack.valid and stack.set_stack({ name = "spidertron-remote", count = 1 }) then
    stack.connected_entity = b.e
  end
end

--- Glas vers (x, y) : à portée, il part ; plus loin, la cloche y va d'abord, puis sonne.
local function glas_vers(b, tick, x, y)
  if not x then return sonner(b, tick, true, nil, nil) end
  -- même règle que l'outil Armée (B.ordre) : à portée, il sonne ; plus loin, il s'arrête à B.APPROCHE de la cible puis sonne
  local o = B.ordre("attack", b.e.position, { x = x, y = y })
  if not o.aller then return sonner(b, tick, true, x, y) end
  b.attente = o.glas
  M.aller(b, o.aller.x, o.aller.y)
  return "route"
end

local function dire(player, cle, ...)
  if player then player.print({ cle, ... }) end
end

local function cmd_bourdon(cmd)
  local player = cmd.player_index and game.get_player(cmd.player_index)
  if not player then return end
  local arg = cmd.parameter
  local b = de_la_force(player.force, player.surface)
  if arg == "retirer" then
    if b then
      lancer_retrait(b)
      dire(player, "fo-bourdon.retire")
    end
    return
  end
  local p = player.position
  if b then
    -- déjà là : il vient
    M.aller(b, p.x, p.y + 14)
    dire(player, "fo-bourdon.vient")
  else
    local id = M.descendre(player.surface, player.force, p.x, p.y + 14)
    if not id then dire(player, "fo-bourdon.impossible"); return end
    b = trouve(id)
    dire(player, "fo-bourdon.demo")
  end
  donner_telecommande(player, b)
end

local function glas_du_joueur(player, cx, cy)
  local b = de_la_force(player.force, player.surface)
  if not b then dire(player, "fo-bourdon.absent"); return end
  local tick = game.tick
  local x, y = cx, cy
  if not x then
    local sel = player.selected
    if sel and sel.valid and sel.force ~= player.force then
      x, y = sel.position.x, sel.position.y
    else
      local ennemi = XpG.cible(b.e, { range = 400 }) -- règle d'échelle : militaire d'abord, sinon toute entité ennemie
      if ennemi then x, y = ennemi.position.x, ennemi.position.y end
    end
  end
  local r = glas_vers(b, tick, x, y)
  if r == "route" then
    dire(player, "fo-bourdon.route")
  elseif r then
    dire(player, x and "fo-bourdon.sonne" or "fo-bourdon.sonne-seul")
  else
    dire(player, "fo-bourdon.recharge", math.ceil(math.max(1, b.recharge - tick) / 60))
  end
end

commands.add_command("fo-bourdon", { "fo-bourdon.aide" }, cmd_bourdon)
commands.add_command("fo-glas", { "fo-bourdon.aide-glas" }, function(cmd)
  local player = cmd.player_index and game.get_player(cmd.player_index)
  if player then glas_du_joueur(player) end
end)

-- ---------------------------------------------------------------------------------------- fabriqué (lot ROBOTS-JEU, 3/11)
--- Bourdons vivants d'une force (liste dans l'ordre de création) : ils comptent pour des géants au plafond (Armee.giants).
function M.compte(force_name)
  local etat = st()
  local n = 0
  if not etat then return 0 end
  for _, b in ipairs(etat.liste) do
    if b.e and b.e.valid and b.e.force.name == force_name then n = n + B.poids(b.e.name) end -- lot MEGA-BOURDON : le Méga-Bourdon compte double
  end
  return n
end
Armee.hooks.extra_giants = M.compte

--- L'objet fabriqué au Portique a posé le relais : il est retiré et le Bourdon descend à sa place, si le plafond de géants le permet ;
--- sinon l'objet est rendu (au joueur, ou au sol). Rend le numéro du Bourdon, ou nil.
function M.pose_fabrique(relais, player)
  local surface, force, p = relais.surface, relais.force, relais.position
  local x, y = p.x, p.y
  local v = B.variante_pose(relais.name) or "bourdon"
  local objet = v == "mega" and B.MEGA.OBJET or B.OBJET
  relais.destroy()
  local id
  if B.peut_poser({ actif = Armee.enabled(), geants = Armee.giants(force.name), admis = Mo.giants_allowed(Armee.age(force)), poids = B.poids(B.nom_de(v)) }) then
    id = M.descendre(surface, force, x, y, v)
  end
  if not id then
    local rendu = (player and player.valid) and player.insert({ name = objet, count = 1 }) or 0
    if rendu < 1 then surface.spill_item_stack({ x, y }, { name = objet, count = 1 }, true) end
    dire(player and player.valid and player or nil, "fo-bourdon.refuse")
    log(string.format("[FO-BOURDON] pose refusee (plafond de geants ou robots eteints) force=%s geants=%d", force.name, Armee.giants(force.name)))
    return nil
  end
  log(string.format("[FO-BOURDON] fabrique pose %d force=%s (%.1f, %.1f) geants=%d/%d", id, force.name, x, y, Armee.giants(force.name),
    Mo.giants_allowed(Armee.age(force))))
  if player and player.valid then
    dire(player, "fo-bourdon.pose")
    donner_telecommande(player, trouve(id))
  end
  return id
end

--- Lot BOURDON-SORTIE : balayage d'une usine (script/robots/usine.lua, Armee.hooks.extra_release). Un Bourdon fini en sortie descend au point de
--- sortie de l'usine si le plafond de géants le permet, puis vole au ralliement `rally` = { x, y }. Rend le nombre de Bourdons sortis (0 ou 1).
local function sortie_une(usine, inv, rally, v, objet)
  local n = inv.get_item_count(objet)
  if n < 1 then return 0 end
  local force = usine.force
  local w = Ro.factory(usine.name)
  if not w then return 0 end
  if not B.sortie({ objets = n, faction = State.by_force(force.name) ~= nil, actif = Armee.enabled(), geants = Armee.giants(force.name),
    admis = Mo.giants_allowed(Armee.age(force)), poids = B.poids(B.nom_de(v)) }) then
    return 0
  end
  if inv.remove({ name = objet, count = 1 }) ~= 1 then return 0 end
  local o = Mo.out_point(usine.position, w.size)
  local id = M.descendre(usine.surface, force, o.x, o.y, v)
  if not id then
    inv.insert({ name = objet, count = 1 }) -- rien de perdu : l'objet revient, on réessaiera au balayage suivant
    return 0
  end
  local b = trouve(id)
  b.ralliement = B.ralliement(o.x, o.y, rally)
  log(string.format("[FO-BOURDON] sorti du portique %d : Bourdon %d force=%s descend en (%.1f, %.1f), ralliement %s, geants=%d/%d", usine.unit_number, id,
    force.name, o.x, o.y, b.ralliement and string.format("(%.1f, %.1f)", b.ralliement.x, b.ralliement.y) or "sur place", Armee.giants(force.name),
    Mo.giants_allowed(Armee.age(force))))
  return 1
end

--- Lot MEGA-BOURDON : le Bourdon d'abord, puis le Méga-Bourdon (une cloche au plus par balayage).
function M.sortie_usine(usine, inv, rally)
  local n = sortie_une(usine, inv, rally, "bourdon", B.OBJET)
  if n > 0 then return n end
  return sortie_une(usine, inv, rally, "mega", B.MEGA.OBJET)
end
Armee.hooks.extra_release = M.sortie_usine

--- Le Bourdon de ce numéro d'unité (vivant), ou nil.
local function par_numero(un)
  local etat = st()
  if not (etat and un) then return nil end
  for _, b in ipairs(etat.liste) do
    if b.e and b.e.valid and b.e.unit_number == un then return b end
  end
  return nil
end

--- Lot BOURDON-SORTIE : un ordre de l'outil Armée (« move » ou « attack ») au Bourdon b, vers pos = { x, y }. Règle : B.ordre. Pendant la descente,
--- l'ordre attend l'atterrissage (b.ralliement, b.attente) ; à portée en recharge, le Glas part dès qu'elle finit ; « aller » annule un Glas en
--- attente. Rend vrai si l'ordre est pris.
function M.commander(b, kind, pos)
  if not (b and b.e and b.e.valid) or b.phase == "retire" then return false end
  local o = B.ordre(kind, b.e.position, pos)
  if not o then return false end
  b.attente = o.glas
  if b.phase == "descente" then
    b.ralliement = o.aller
    return true
  end
  if o.aller then
    M.aller(b, o.aller.x, o.aller.y)
    return true
  end
  if sonner(b, game.tick, true, o.glas.x, o.glas.y) then b.attente = nil end
  return true
end

-- Adaptateur « robot commandable » (script/robots/armee.lua) : l'outil Armée choisit, cercle et commande le Bourdon comme un robot du registre.
M.commandable = {
  is = function(e) return B.variante(e.name) ~= nil and par_numero(e.unit_number) ~= nil end,
  entity = function(un)
    local b = par_numero(un)
    return b and b.e or nil
  end,
  send = function(e, kind, pos) return M.commander(par_numero(e.unit_number), kind, pos) end,
}
Armee.hooks.commandable = M.commandable

local function sur_pose(ev)
  local e = ev.created_entity or ev.entity
  if not (e and e.valid and B.variante_pose(e.name)) then return end
  M.pose_fabrique(e, ev.player_index and game.get_player(ev.player_index) or nil)
end
Events.on(defines.events.on_built_entity, sur_pose)
Events.on(defines.events.on_robot_built_entity, sur_pose)
Events.on(defines.events.script_raised_built, sur_pose)

Events.on("fo-bourdon-glas", function(ev)
  local player = game.get_player(ev.player_index)
  if player and ev.cursor_position and de_la_force(player.force, player.surface) then
    glas_du_joueur(player, ev.cursor_position.x, ev.cursor_position.y)
  end
end)

-- Pilotage des bancs : mêmes fonctions que les commandes.
remote.add_interface("fo-bourdon", {
  descendre = function(force_nom, x, y, surface_index, variante)
    return M.descendre(game.surfaces[surface_index or 1], game.forces[force_nom], x, y, variante)
  end,
  glas = function(id, x, y)
    local b = trouve(id)
    if not b then return false end
    return glas_vers(b, game.tick, x, y)
  end,
  aller = function(id, x, y)
    local b = trouve(id)
    if not b then return false end
    M.aller(b, x, y)
    return true
  end,
  retirer = function(id)
    local b = trouve(id)
    if not b then return false end
    lancer_retrait(b)
    return true
  end,
  -- bancs d'images : sans Glas automatique, pour photographier au tick voulu
  muet = function(id, v)
    local b = trouve(id)
    if b then b.muet = v and true or nil end
  end,
  etat = function(id)
    local b = trouve(id)
    if not b then return nil end
    local tir = b.dernier or {}
    return { phase = b.phase, x = b.e.position.x, y = b.e.position.y, glas = b.glas and true or false, compte = b.compte or 0, unite = b.e.unit_number,
      attente = b.attente and true or false, variante = b.v or "bourdon", tirs = b.tirs or 0,
      touches = tir.touches or 0, tues = tir.tues or 0, recharge = b.recharge, sante = b.e.health, ancres = (function()
        local n = 0
        for i = 1, #b.ancres do if b.ancres[i].e >= 1 then n = n + 1 end end
        return n
      end)() }
  end,
  -- bancs : un script ne tape pas une commande, mêmes fonctions que /fo-bourdon et /fo-glas ; rend le numéro du Bourdon de la force
  commande_bourdon = function(player_index, parametre)
    cmd_bourdon({ player_index = player_index, parameter = parametre })
    local p = game.get_player(player_index)
    local b = de_la_force(p.force, p.surface)
    return b and b.id or nil
  end,
  commande_glas = function(player_index) glas_du_joueur(game.get_player(player_index)) end,
  -- bancs : recharge remise à zéro, pour photographier
  recharge_zero = function(id)
    local b = trouve(id)
    if b then b.recharge = 0 end
  end,
})

return M
