--[[
  Lot DEFENSE, côté RUNTIME : la CEINTURE (règle pure : shared/team/ceinture.lua ; tests : tests/ceinture_test.lua). Lit le moteur (bâtiments de
  l'équipe, mémoire des attaques du front, nids connus), appelle la règle et rend des emplacements de tourelles rangés dans l'ordre de pose.
  Aucune décision n'en dépend en dehors du CHOIX des emplacements : ni le nombre de tourelles, ni leur coût, ni la tâche ne changent.

  Appelé par :
    - script/faction/outposts.lua, pose_order : tourelles d'un avant-poste ou du QG (avant : 8 emplacements fixes autour du centre) ;
    - script/team/front.lua : tourelles d'une cellule attaquée ou d'un groupe de machines à couvrir (avant : l'anneau de 6 tuiles autour du
      centre de la cellule).
  Sans bâtiment de production à entourer, ou sans emplacement de contour assez proche, `Ceinture.sites` rend nil : l'appelant garde SA pose d'avant.
  Pas d'état : rien n'est écrit dans `global`.
]]
local State = require("script.faction.state")
local R = require("shared.ai3.reglages")
local Pose = require("shared.team.pose_tourelles")
local Ce = require("shared.team.ceinture")
local K = require("shared.ai3.carte")

local M = {}

M.THREAT_R = 120   -- tuiles : les attaques et nids plus loin du centre du site ne disent rien de SON côté exposé
M.NEST_R = 160     -- tuiles : nids connus lus autour du centre

--- Bâtiments de l'équipe autour du centre : { { x, y, w, x0, y0, x1, y1, core } } (w = aire de l'emprise × facteur du rôle, comme
--- Pose.cells ; `core` : machine, foreuse, laboratoire, chaudière, générateur, pompe ou le QG, c'est-à-dire ce qu'une ceinture doit entourer,
--- pas les tapis ni les poteaux).
function M.assets(f, surface, center, radius)
  local types = {}
  for _, ty in ipairs(R.ENTITY_TYPES) do
    if Pose.role_factor(R.ENTITY_ROLE[ty]) > 0 then types[#types + 1] = ty end
  end
  local out = {}
  local hq = f.hq and f.hq.valid and f.hq or nil
  for _, e in ipairs(surface.find_entities_filtered({ position = center, radius = radius, force = f.force, type = types })) do
    local bb = e.bounding_box
    local lt, rb = bb.left_top, bb.right_bottom
    local area = math.max(1, math.floor((rb.x - lt.x) * (rb.y - lt.y) + 0.5))
    local factor = Pose.role_factor(R.ENTITY_ROLE[e.type])
    local w = area * factor
    local is_hq = hq and e.unit_number and e.unit_number == hq.unit_number
    if is_hq then w = Pose.HQ_WEIGHT end
    out[#out + 1] = { x = e.position.x, y = e.position.y, w = w, x0 = lt.x, y0 = lt.y, x1 = rb.x, y1 = rb.y,
      core = (factor >= 2 or is_hq) and true or false }
  end
  return out
end

--- Points de menace vus du site : cellules attaquées de la mémoire du front (poids = score), nids connus (poids Ce.NEST_W). { { x, y, w } }
--- triés (déterminisme), au plus M.THREAT_R tuiles du centre.
function M.threats(f, center)
  local out = {}
  local st = f.front_mem
  local mem = st and st.mem
  local r2 = M.THREAT_R * M.THREAT_R
  for _, key in ipairs(State.sorted_keys(mem and mem.cells or {})) do
    local c = mem.cells[key]
    if c.sw and c.sw > 0 and c.n and c.n > 0 then
      local x, y = c.sx / c.sw, c.sy / c.sw
      if (x - center.x) ^ 2 + (y - center.y) ^ 2 <= r2 then out[#out + 1] = { x = x, y = y, w = c.n } end
    end
  end
  local km = f.ai3f and f.ai3f.m
  if km then
    local pts = {}
    for _, p in ipairs(K.enemy_points(km, center.x, center.y, M.NEST_R)) do
      if p.kind == "spawner" then pts[#pts + 1] = p end
    end
    table.sort(pts, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
    for _, p in ipairs(pts) do out[#out + 1] = { x = p.x, y = p.y, w = Ce.NEST_W } end
  end
  return out
end

--- Emplacements de ceinture pour `count` tourelles autour de `center`. o = { radius (tuiles où l'on lit les bâtiments), range (portée de la
--- tourelle), existing = { { x, y } } (tourelles déjà là), max_d (facultatif : seuls les emplacements à moins de max_d tuiles du centre),
--- min (facultatif, défaut 2 : sous ce nombre d'emplacements, nil) }. Rend { sites = { { x, y } } (choisis d'abord, puis le repli),
--- info = { cands, chosen, covered, total, assets, threats } } ou nil.
function M.sites(f, surface, center, count, o)
  if not (count and count > 0 and o and o.range and o.range > 0) then return nil end
  local assets = M.assets(f, surface, center, o.radius)
  local boxes = {}
  for _, a in ipairs(assets) do
    if a.core then boxes[#boxes + 1] = { x0 = a.x0, y0 = a.y0, x1 = a.x1, y1 = a.y1 } end
  end
  if #boxes == 0 then return nil end
  local cands = Ce.contour(boxes, { center = center })
  if o.max_d then
    local keep, lim = {}, o.max_d * o.max_d
    for _, c in ipairs(cands) do
      if (c.x - center.x) ^ 2 + (c.y - center.y) ^ 2 <= lim then keep[#keep + 1] = c end
    end
    cands = keep
  end
  if #cands < (o.min or 2) then return nil end
  local threats = M.threats(f, center)
  local ch = Ce.choose({ cands = cands, assets = assets, range = o.range, existing = o.existing or {}, count = count,
    gap = Pose.gap(o.range), center = center, threats = threats })
  return { sites = ch.order, info = { cands = #cands, chosen = ch.chosen, covered = ch.covered, total = ch.total, assets = #assets,
    threats = #threats } }
end

return M
