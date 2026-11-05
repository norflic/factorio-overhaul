--[[
  COFFRES DU JOUEUR dans le stock de votre équipe (lot COFFRES-JOUEUR ; règle pure : shared/team/coffres_joueur.lua).

  CJs.chests(f) : coffres posés par le joueur dans sa base, que votre équipe LIT et dans lesquels elle PREND (script/team/stock.lua :
  Stock.count, Stock.remove, Stock.contents ; jamais Stock.insert, Stock.inventories ni le rangement). Votre équipe seulement
  (f.is_player) : une faction n'a pas de joueur, la liste est vide et Stock fait exactement ce qu'il faisait.

  Liste refaite au plus toutes les CJ.REFRESH ticks, à la première lecture du stock qui suit (tick déterministe : la liste est dans
  global, f.coffres_joueur = { list (entités), at, seen, kept }) : une recherche des coffres de la force dans la boîte de la base,
  puis, pour les CJ.SCAN coffres non vides les plus proches du QG, une recherche des bras alentour (un bras qui PREND dans le coffre
  en fait un tampon de chaîne). La base vient de la zone du départ (CJs.base, posé par script/faction/vision.lua : cellules, points
  du départ et boîte) ; sans zone, les HOME_RADIUS tuiles autour des points du départ.
  Journal : [FO-COFFRES-JOUEUR] quand la liste change (40 lignes au plus par partie).
]]

local CJ = require("shared.team.coffres_joueur")
local A = require("shared.faction.adversaire")

local CJs = {}

--- Posé par script/faction/vision.lua (vision requiert ce fichier, pas l'inverse) : function(surface) -> cells (zone du départ, ou
--- nil), homes ({ { x, y } }), box ({ x0, y0, x1, y1 } : boîte de la zone, ou nil).
CJs.base = nil

local EMPTY = {}
local TYPES = { "container", "logistic-container" }
CJs.MAX_LOGS = 40

local function in_base(cells, homes, x, y)
  if cells and A.in_zone(cells, x, y) then return true end
  local r2 = A.HOME_RADIUS * A.HOME_RADIUS
  for _, h in ipairs(homes) do
    local dx, dy = x - h.x, y - h.y
    if dx * dx + dy * dy <= r2 then return true end
  end
  return false
end

--- Boîte de recherche : celle de la zone, agrandie aux disques des points du départ.
local function search_box(box, homes)
  local R = A.HOME_RADIUS
  local x0, y0, x1, y1
  if box then x0, y0, x1, y1 = box[1], box[2], box[3], box[4] end
  for _, h in ipairs(homes) do
    x0 = math.min(x0 or h.x - R, h.x - R)
    y0 = math.min(y0 or h.y - R, h.y - R)
    x1 = math.max(x1 or h.x + R, h.x + R)
    y1 = math.max(y1 or h.y + R, h.y + R)
  end
  if not x0 then return nil end
  return { { x0, y0 }, { x1, y1 } }
end

--- Un bras de la force prend-il dans ce coffre ? (bras à 3 tuiles au plus de son bord : longue portée comprise.)
local function feeds(surface, chest, force)
  local b = chest.bounding_box
  local area = { { b.left_top.x - 3, b.left_top.y - 3 }, { b.right_bottom.x + 3, b.right_bottom.y + 3 } }
  for _, ins in ipairs(surface.find_entities_filtered({ area = area, type = "inserter", force = force })) do
    if ins.valid and ins.pickup_target == chest then return true end
  end
  return false
end

--- Refait la liste des coffres du joueur retenus (f.coffres_joueur).
function CJs.refresh(f, tick)
  local surface = f.hq.surface
  local cells, homes, box
  if CJs.base then cells, homes, box = CJs.base(surface) end
  homes = homes or { { x = f.hq_pos.x, y = f.hq_pos.y } }
  local st = f.coffres_joueur or { list = {}, at = tick, seen = 0, kept = 0 }
  f.coffres_joueur = st
  st.at = tick
  local area = surface and search_box(box, homes)
  if not area then
    st.list = {}
    return st
  end
  -- Coffres de l'équipe : QG, annexes, réceptions des foreuses adoptées (registre f.adopt.drills, ensemble lu sans ordre).
  local skip = {}
  if f.hq.unit_number then skip[f.hq.unit_number] = true end
  for _, e in ipairs(f.annex or EMPTY) do if e.valid and e.unit_number then skip[e.unit_number] = true end end
  local drills = f.adopt and f.adopt.drills
  if drills then for _, d in pairs(drills) do if d.sink then skip[d.sink] = true end end end
  local found = surface.find_entities_filtered({ area = area, force = f.force, type = TYPES })
  local cands = {}
  for _, e in ipairs(found) do
    if e.valid and e.unit_number and e ~= f.hq and not e.get_inventory(defines.inventory.chest).is_empty() then
      local p = e.position
      local dx, dy = p.x - f.hq_pos.x, p.y - f.hq_pos.y
      cands[#cands + 1] = { e = e, id = e.unit_number, d2 = dx * dx + dy * dy, x = p.x, y = p.y, adopted = skip[e.unit_number] or false }
    end
  end
  CJ.order(cands)
  local exam = {}
  for i = 1, math.min(#cands, CJ.SCAN) do
    local c = cands[i]
    local e = c.e
    if not c.adopted then
      c.by_player = e.last_user ~= nil
      c.in_base = in_base(cells, homes, c.x, c.y)
      c.mode = e.type == "logistic-container" and e.prototype.logistic_mode or nil
      -- Recherche des bras seulement pour un coffre qui serait retenu sans elle (coût).
      c.feeds = c.by_player and c.in_base and not (c.mode and CJ.EXCLUDED_MODES[c.mode]) and feeds(surface, e, f.force) or false
    end
    exam[#exam + 1] = c
  end
  local keep, why = CJ.select(exam, CJ.MAX)
  local list = {}
  for i, c in ipairs(keep) do list[i] = c.e end
  local changed = #list ~= #st.list
  if not changed then for i, e in ipairs(list) do if st.list[i] ~= e then changed = true break end end end
  st.list, st.seen, st.kept = list, #found, #list
  if changed then
    f.stats = f.stats or {}
    f.stats.cj_logs = (f.stats.cj_logs or 0) + 1
    if f.stats.cj_logs <= CJs.MAX_LOGS then
      local parts = {}
      for _, r in ipairs(CJ.REASONS) do if why[r] then parts[#parts + 1] = r .. " " .. why[r] end end
      if why.plafond then parts[#parts + 1] = "plafond " .. why.plafond end
      log(string.format("[FO-COFFRES-JOUEUR] player : %d coffre(s) du joueur dans le stock a %.1f min (%d coffre(s) de la force dans la boite, %d non vide(s), %d examine(s) : %s)%s",
        #list, (tick - (f.started or 0)) / 3600, #found, #cands, #exam, table.concat(parts, ", "), cells and "" or " ; sans zone du depart : rayon des points du depart"))
    end
  end
  return st
end

--- Coffres du joueur retenus (entités valides), à lire et vider APRÈS le coffre du QG et les annexes. Vide hors de votre équipe.
function CJs.chests(f)
  if not f.is_player or not (f.hq and f.hq.valid and f.hq_pos) then return EMPTY end
  local tick = game.tick or 0
  local st = f.coffres_joueur
  if not st or tick - (st.at or -1e9) >= CJ.REFRESH then st = CJs.refresh(f, tick) end
  local list = st.list
  for i = 1, #list do
    if not list[i].valid then
      local out = {}
      for _, e in ipairs(list) do if e.valid then out[#out + 1] = e end end
      st.list = out
      return out
    end
  end
  return list
end

return CJs
