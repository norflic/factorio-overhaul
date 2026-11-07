--[[
  COFFRES DU JOUEUR dans le stock de votre équipe (lot COFFRES-JOUEUR ; règle pure : shared/team/coffres_joueur.lua).

  CJs.chests(f) : coffres posés par le joueur dans sa base, que votre équipe LIT et dans lesquels elle PREND (script/team/stock.lua :
  Stock.count, Stock.remove, Stock.contents ; jamais Stock.inventories ni le rangement). CJs.depot(f) : ceux d'entre eux où elle
  DÉPOSE aussi (coffres ordinaires sans bras : un coffre vide posé à la main, ou qui remplace une annexe par remplacement rapide ;
  branché par STOCKAGE dans Stock.insert et la capacité). Votre équipe seulement (f.is_player) : une faction n'a pas de joueur, les
  listes sont vides et Stock fait exactement ce qu'il faisait. C'est la SEULE recherche des coffres du joueur (f.annex reste le
  registre des coffres posés par l'équipe, que cette recherche saute).

  Liste refaite au plus toutes les CJ.REFRESH ticks, à la première lecture du stock qui suit (tick déterministe : la liste est dans
  global, f.coffres_joueur = { list, depot (entités), at, seen, kept }) : une recherche des coffres de la force dans la boîte de la
  base, puis, pour les CJ.SCAN coffres les plus proches du QG (vides compris), une recherche des bras alentour (un bras qui PREND
  dans le coffre en fait un tampon de chaîne ; un bras qui y DÉPOSE en fait une sortie, où l'équipe prend mais ne dépose pas). La base vient de la zone du départ (CJs.base, posé par script/faction/vision.lua : cellules, points
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
CJs.MAX_DEPOT_LOGS = 100 -- lignes « adopte en DEPOT » au plus par partie (une par coffre)

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

--- Bras de la force autour de ce coffre (3 tuiles au plus de son bord : longue portée comprise) : un bras y prend-il, un bras y
--- dépose-t-il ?
local function arms(surface, chest, force)
  local b = chest.bounding_box
  local area = { { b.left_top.x - 3, b.left_top.y - 3 }, { b.right_bottom.x + 3, b.right_bottom.y + 3 } }
  local takes, drops = false, false
  -- Moteur réel (banc coffre-acier, 7/11) : pickup_target et drop_target restent VIDES tant que le bras n'a pas tourné (bras neuf, sans
  -- courant) ; la position de prise ou de dépôt dans la boîte du coffre suffit.
  local function inside(q)
    return q ~= nil and q.x >= b.left_top.x and q.x <= b.right_bottom.x and q.y >= b.left_top.y and q.y <= b.right_bottom.y
  end
  for _, ins in ipairs(surface.find_entities_filtered({ area = area, type = "inserter", force = force })) do
    if ins.valid then
      if ins.pickup_target == chest or inside(ins.pickup_position) then takes = true end
      if ins.drop_target == chest or inside(ins.drop_position) then drops = true end
    end
  end
  return takes, drops
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
    st.list, st.depot = {}, {}
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
    if e.valid and e.unit_number and e ~= f.hq then
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
      c.kind = e.type
      c.mode = e.type == "logistic-container" and e.prototype.logistic_mode or nil
      -- Recherche des bras seulement pour un coffre qui serait retenu sans elle (coût).
      if c.by_player and c.in_base and not (c.mode and CJ.EXCLUDED_MODES[c.mode]) then c.feeds, c.drops = arms(surface, e, f.force) end
    end
    exam[#exam + 1] = c
  end
  local keep, why, dep = CJ.select(exam, CJ.MAX)
  local list, depot = {}, {}
  for i, c in ipairs(keep) do list[i] = c.e end
  for i, c in ipairs(dep) do depot[i] = c.e end
  local changed = #list ~= #st.list
  if not changed then for i, e in ipairs(list) do if st.list[i] ~= e then changed = true break end end end
  if #depot ~= #(st.depot or EMPTY) then changed = true end
  st.list, st.depot, st.seen, st.kept = list, depot, #found, #list
  -- Décision du lead (5/11, 21 h 55, mots du DC : « comme c'est un coffre que j'ai posé, ils devraient [...] pouvoir l'utiliser ») :
  -- une ligne par coffre du joueur ADOPTÉ en dépôt (première fois seulement ; st.depot_seen = numéros déjà annoncés).
  st.depot_seen = st.depot_seen or {}
  for _, e in ipairs(depot) do
    if not st.depot_seen[e.unit_number] then
      st.depot_seen[e.unit_number] = true
      f.stats = f.stats or {}
      f.stats.cj_depot = (f.stats.cj_depot or 0) + 1
      if f.stats.cj_depot <= CJs.MAX_DEPOT_LOGS then
        local p = e.position
        log(string.format("[FO-COFFRES-JOUEUR] player : coffre %s du joueur en (%d, %d) adopte en DEPOT (%d case(s)) a %.1f min", e.name or "?",
          math.floor(p.x), math.floor(p.y), #e.get_inventory(defines.inventory.chest), (tick - (f.started or 0)) / 3600))
      end
    end
  end
  if changed then
    f.stats = f.stats or {}
    f.stats.cj_logs = (f.stats.cj_logs or 0) + 1
    if f.stats.cj_logs <= CJs.MAX_LOGS then
      local parts = {}
      for _, r in ipairs(CJ.REASONS) do if why[r] then parts[#parts + 1] = r .. " " .. why[r] end end
      if why.plafond then parts[#parts + 1] = "plafond " .. why.plafond end
      log(string.format("[FO-COFFRES-JOUEUR] player : %d coffre(s) du joueur dans le stock, dont %d de depot, a %.1f min (%d coffre(s) de la force dans la boite, %d examine(s) : %s)%s",
        #list, #depot, (tick - (f.started or 0)) / 3600, #found, #exam, table.concat(parts, ", "), cells and "" or " ; sans zone du depart : rayon des points du depart"))
    end
  end
  return st
end

--- Le registre des annexes (f.annex : Stock.grow, Stock.scan, adoption) a-t-il changé depuis la liste ? Un coffre du joueur inscrit
--- comme annexe entre deux listes serait compté DEUX fois (annexe et coffre du joueur) : la liste est alors refaite aussitôt.
local function annex_changed(f, st)
  local a = f.annex or EMPTY
  return #a ~= (st.annex_n or 0) or (#a > 0 and a[#a] ~= st.annex_last)
end

--- ÉCRITURE (pensée d'équipe seulement : Stock.grow) : liste refaite quand la minute est échue ou que f.annex a changé, entités
--- disparues purgées. Régression du 7/11 (ia1i_test, « fenêtre ouverte contre fermée ») : la fenêtre lisait Stock.count, qui refaisait
--- la liste et ÉCRIVAIT dans global ; désormais aucune lecture (Stock.count, Stock.contents, fenêtre, panneau) n'écrit.
function CJs.update(f, tick)
  if not f.is_player or not (f.hq and f.hq.valid and f.hq_pos) then return nil end
  tick = tick or game.tick or 0
  local st = f.coffres_joueur
  if not st or tick - (st.at or -1e9) >= CJ.REFRESH or annex_changed(f, st) then
    st = CJs.refresh(f, tick)
    local a = f.annex or EMPTY
    st.annex_n, st.annex_last = #a, a[#a]
  end
  for _, field in ipairs({ "list", "depot" }) do
    local list = st[field] or EMPTY
    for i = 1, #list do
      if not list[i].valid then
        local out = {}
        for _, e in ipairs(list) do if e.valid then out[#out + 1] = e end end
        st[field] = out
        break
      end
    end
  end
  return st
end

--- LECTURE : entités valides de st[field], sans les coffres inscrits comme annexes depuis la liste (jamais comptés deux fois) ; rien
--- n'est écrit (copie filtrée quand il le faut).
local function read_list(f, st, field)
  local list = st[field] or EMPTY
  local clean = true
  for i = 1, #list do if not list[i].valid then clean = false break end end
  local annex = annex_changed(f, st) and f.annex or nil
  if clean and not annex then return list end
  local skip = {}
  for _, e in ipairs(annex or EMPTY) do if e.valid and e.unit_number then skip[e.unit_number] = true end end
  local out = {}
  for _, e in ipairs(list) do if e.valid and not skip[e.unit_number] then out[#out + 1] = e end end
  return out
end

--- Coffres du joueur retenus (entités valides), à lire et vider APRÈS le coffre du QG et les annexes. Vide hors de votre équipe, et
--- avant la première pensée d'équipe (CJs.update).
function CJs.chests(f)
  if not f.is_player then return EMPTY end
  local st = f.coffres_joueur
  return st and read_list(f, st, "list") or EMPTY
end

--- Coffres du joueur où votre équipe DÉPOSE aussi (sous-liste de CJs.chests : coffres ordinaires sans bras), APRÈS les annexes.
--- Vide hors de votre équipe.
function CJs.depot(f)
  if not f.is_player then return EMPTY end
  local st = f.coffres_joueur
  return st and read_list(f, st, "depot") or EMPTY
end

return CJs
