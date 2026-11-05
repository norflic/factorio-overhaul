--[[
  Lot ÉTAGE 5 (5/11, accord du lead) : COULOIR D'ACCÈS réservé d'un avant-poste. PUR : aucune API du moteur, aucun nom d'objet.

  Défaut mesuré (fo-logs/2026-11-04_ETAGE4/RAPPORT.md §4) : un PNJ muré par sa propre équipe près de l'accès d'un avant-poste. Émeraude
  (123456789) : coincé en (−179, 488) de 25 à 60 min, cerné par le champ vapeur, l'avant-poste et ses tourelles. Écarlate (20261020) :
  coincé en (187, −499) de 25 à 50 min, cerné par les agrandissements de l'avant-poste. Les avant-postes et leurs tourelles évitaient les
  tuiles du plan (crochet Outposts.reserved) ; le plan, les agrandissements et les tourelles n'évitaient pas l'accès (o.access, l'endroit
  où se tenait le bâtisseur) : rien ne le réservait. La règle NAV2 (shared/team/acces_champ.lua) déplace le but APRÈS la fermeture, elle
  ne la prévient pas.

  Règles :
    Co.tiles(ax, ay, hx, hy, len, width) -> tuiles { x, y } du couloir : de la tuile de l'accès vers le QG, chemin de Manhattan (axe
                                    dominant d'abord), Co.WIDTH tuiles de large (la seconde rangée du côté du QG sur l'autre axe), Co.LEN
                                    tuiles de chemin au plus, arrêté à Co.HQ_GAP (Manhattan) du QG. Triées (y, puis x), sans doublon. Calculé
                                    depuis l'accès et le QG seuls : aucun état écrit (les sauvegardes existantes ont leur couloir).
    Co.closer(boxes, tiles, access, rect, order) -> indice, dans `order` (du plus récent au plus ancien), du premier obstacle dont le retrait
                                    rend l'accès atteignable depuis le bord du rectangle (Acc.reach) : le bâtiment qui ferme la DERNIÈRE issue
                                    (journal [FO-NAV-ACCES]). nil si aucun retrait seul ne suffit.
]]
local Acc = require("shared.team.acces_champ")

local Co = {}

Co.LEN = Acc.FIELD_RADIUS + Acc.MARGIN -- 35 tuiles de chemin : de l'accès jusqu'au-delà du champ (rayon d'agrandissement + marge)
Co.WIDTH = 2                           -- tuiles de large (un PNJ passe, une paire posée de travers ne le ferme pas)
Co.HQ_GAP = 8                          -- tuiles (Manhattan) avant le QG où le couloir s'arrête (la base du QG garde sa place)
Co.CLOSER_TRIES = 12                   -- obstacles essayés au plus pour nommer celui qui ferme la dernière issue

local function sgn(v)
  if v < 0 then return -1 end
  return 1
end

function Co.tiles(ax, ay, hx, hy, len, width)
  len, width = len or Co.LEN, width or Co.WIDTH
  local x, y = math.floor(ax), math.floor(ay)
  local tx, ty = math.floor(hx), math.floor(hy)
  local dx, dy = tx - x, ty - y
  local budget = math.min(len, math.max(0, math.abs(dx) + math.abs(dy) - Co.HQ_GAP))
  local sx, sy = sgn(dx), sgn(dy)
  local seen, out = {}, {}
  local function add(px, py)
    local k = px .. "," .. py
    if seen[k] then return end
    seen[k] = true
    out[#out + 1] = { x = px, y = py }
  end
  local x_first = math.abs(dx) >= math.abs(dy)
  -- tuile de chemin (px, py) le long de l'axe x (along_x) ou y : la rangée de largeur part du côté du QG sur l'autre axe
  local function cell(px, py, along_x)
    for k = 0, width - 1 do
      if along_x then add(px, py + k * sy) else add(px + k * sx, py) end
    end
  end
  cell(x, y, x_first)
  local n1 = math.min(budget, x_first and math.abs(dx) or math.abs(dy))
  for _ = 1, n1 do
    if x_first then x = x + sx else y = y + sy end
    cell(x, y, x_first)
  end
  local n2 = math.min(budget - n1, x_first and math.abs(dy) or math.abs(dx))
  for _ = 1, n2 do
    if x_first then y = y + sy else x = x + sx end
    cell(x, y, not x_first)
  end
  table.sort(out, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
  return out
end

--- Couloirs de tous les avant-postes d'une équipe : outposts = { [id] = { access = { x, y } } } (un avant-poste sans accès n'en a pas),
--- hq = { x, y }. Rend la liste { x, y, id } dans l'ordre des ids triés puis des tuiles (une tuile de deux couloirs garde le premier id).
function Co.team_tiles(outposts, hq)
  local out = {}
  if not (outposts and hq) then return out end
  local ids = {}
  for id in pairs(outposts) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
  local seen = {}
  for _, id in ipairs(ids) do
    local a = outposts[id].access
    if a then
      for _, t in ipairs(Co.tiles(a.x, a.y, hq.x, hq.y)) do
        local k = t.x .. "," .. t.y
        if not seen[k] then
          seen[k] = true
          out[#out + 1] = { x = t.x, y = t.y, id = id }
        end
      end
    end
  end
  return out
end

function Co.closer(boxes, tiles, access, rect, order)
  local n = 0
  for _, i in ipairs(order or {}) do
    n = n + 1
    if n > Co.CLOSER_TRIES then return nil end
    local rest = {}
    for j, b in ipairs(boxes) do if j ~= i then rest[#rest + 1] = b end end
    local r = Acc.reach(rest, tiles, access, rect)
    if not r.moved and not r.enclosed then return i end
  end
  return nil
end

return Co
