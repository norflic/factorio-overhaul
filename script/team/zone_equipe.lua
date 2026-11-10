--[[
  Lot UPS-HYGIENE (Mode Démon du DC, 10/11) : la ZONE d'une équipe en jeu (règle pure : shared/team/zone_equipe.lua) : les rectangles
  de tuiles où ses entités peuvent être, lus dans l'état de l'équipe (plan directeur, QG, avant-postes, chaîne des foreuses, remplaçant
  de l'hygiène en attente), élargis de la portée de fil la plus longue des poteaux (prototypes : identique sur tous les pairs), fusionnés,
  rognés à la boîte des chunks générés. Lecteurs : le relevé des poteaux (hygiene.lua) et celui des balises (balises_teinte.lua), au lieu
  d'une recherche sur toute la carte (≈ 12 ms par recherche, quel que soit le nombre de résultats : banc UPS-MESURE).

  Mémo d'UN tick (table locale du module : { key, tick, rects }) : les deux relevés du même tick partagent le calcul. Rien dans le stockage persistant ;
  après un chargement, le premier appel recalcule. Sans plan ni QG : nil (l'appelant garde la boîte entière, comme avant).
]]

local Ze = require("shared.team.zone_equipe")
local T = require("shared.team.config")
local BoiteChunks = require("script.team.boite_chunks")

local Zone = {}

Zone.MARGE_DEFAUT = 9      -- tuiles : sans prototypes lisibles (bancs hors jeu) ; en jeu : la portée de fil la plus longue des poteaux
Zone.HQ_RAYON = 16         -- tuiles autour du coffre du QG (le lot du QG fait 32 de côté)

local marge_memo = nil
--- Portée de fil la plus longue parmi les poteaux électriques du jeu (prototypes), +1 tuile ; lue une fois par chargement.
function Zone.marge()
  if marge_memo then return marge_memo end
  local m = 0
  local protos = game and game.get_filtered_entity_prototypes and game.get_filtered_entity_prototypes({ { filter = "type", type = "electric-pole" } })
  if protos then
    for _, pr in pairs(protos) do -- max : l'ordre de parcours n'a aucun effet
      local w = pr.max_wire_distance or 0
      if w > m then m = w end
    end
  end
  marge_memo = (m > 0) and (math.ceil(m) + 1) or Zone.MARGE_DEFAUT
  return marge_memo
end

local TK_OFF, TK_MUL = 1048576, 2097152 -- inverse de P.tkey (shared/team/plan.lua) : k = (x + OFF) * MUL + (y + OFF)
--- Coordonnées de tuile d'une clé P.tkey.
function Zone.tkey_xy(k)
  local x = math.floor(k / TK_MUL) - TK_OFF
  local y = k - (x + TK_OFF) * TK_MUL - TK_OFF
  return x, y
end

--- Rectangles bruts (avant fusion) de l'équipe `f`, élargis de `marge` ; nil si l'équipe n'a ni plan ni QG.
function Zone.raw(f, marge)
  local rects, any = {}, false
  local b = f.build
  if b and b.projects then
    local order = b.order or {}
    for i = 1, #order do
      local q = b.projects[order[i]]
      if q and q.ents and #q.ents > 0 then
        local r = Ze.rect_of_points(q.ents, marge)
        if r then rects[#rects + 1] = r any = true end
      end
    end
  end
  if f.hq_pos then
    rects[#rects + 1] = Ze.rect_around(f.hq_pos.x, f.hq_pos.y, Zone.HQ_RAYON, marge)
    any = true
  end
  if f.outposts then
    local ids = {}
    for oid in pairs(f.outposts) do ids[#ids + 1] = oid end
    table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
    for _, oid in ipairs(ids) do
      local o = f.outposts[oid]
      if o and o.pos then
        local r = (T.seed_radius and T.seed_radius[o.kind]) or 8
        rects[#rects + 1] = Ze.rect_around(o.pos.x, o.pos.y, r, marge)
      end
    end
  end
  local sw = f.swap
  if sw and sw.pole_pos then
    local pts = {}
    for k in pairs(sw.pole_pos) do
      local x, y = Zone.tkey_xy(k)
      pts[#pts + 1] = { x = x + 0.5, y = y + 0.5 }
    end
    local r = Ze.rect_of_points(pts, marge) -- boîte de tous les points : l'ordre de pairs n'a aucun effet
    if r then rects[#rects + 1] = r end
  end
  local pd = f.team and f.team.hygiene_pending
  if pd and pd.new then rects[#rects + 1] = Ze.rect_around(pd.new[2], pd.new[3], 0, marge) end
  if not any then return nil end
  return rects
end

local memo = { key = nil, tick = nil, rects = nil, has = false }

--- Rectangles fusionnés et rognés de l'équipe `f` au tick `tick` (mémo d'un tick) ; nil sans plan ni QG.
function Zone.rects(f, surface, tick)
  local key = tostring(f.key or "player")
  if memo.has and memo.key == key and memo.tick == tick then return memo.rects end
  local raw = Zone.raw(f, Zone.marge())
  local rects = nil
  if raw then
    rects = Ze.clip(Ze.merge(raw), Ze.box_tiles(BoiteChunks.get(surface)))
  end
  memo.key, memo.tick, memo.rects, memo.has = key, tick, rects, true
  return rects
end

--- Coût (chunks) à déclarer au jeton des travaux lourds pour une recherche dans `rects` (nil : la boîte entière `box`).
function Zone.cost(rects, box)
  if rects then return Ze.cost(rects) end
  return box and ((box.x1 - box.x0 + 1) * (box.y1 - box.y0 + 1)) or nil
end

--- Toutes les entités d'un filtre `q` (type, force...) dans les rectangles `rects` : une recherche par rectangle, dédoublonnée par
--- unit_number (un rectangle fusionné n'en chevauche aucun autre, mais la boîte d'une entité peut en toucher deux). Sans zone (nil) :
--- la boîte des chunks générés `box` (comme avant ; nil : toute la surface).
function Zone.find(surface, q, rects, box)
  local out, seen = {}, {}
  if not rects then
    local bt = Ze.box_tiles(box)
    if bt then q.area = Ze.area(bt) else q.area = nil end
    for _, e in ipairs(surface.find_entities_filtered(q)) do out[#out + 1] = e end
    return out
  end
  for _, r in ipairs(rects) do
    q.area = Ze.area(r)
    for _, e in ipairs(surface.find_entities_filtered(q)) do
      local u = e.unit_number
      if u then
        if not seen[u] then seen[u] = true out[#out + 1] = e end
      else
        out[#out + 1] = e
      end
    end
  end
  return out
end

return Zone
