--[[
  Lot POTEAU-CHANTIER (0716) : côté RUNTIME du repli des poteaux d'un chantier en réserve (règle pure : shared/team/poteau_chantier.lua ; choix
  du poteau et relais : shared/team/reconstruction.lua, Rc.pick_chain). Appelé par script/team/build.lua, état « reserve » incomplet, une fois
  par relecture (une seconde) : un poteau prévu qui manque au coffre ET n'est pas fabricable avec le stock libre depuis Pc.WAIT est remplacé,
  dans le plan du chantier, par le meilleur poteau fabricable d'une tuile ; des relais rejoignent les voisins hors de son fil et des poteaux de
  compensation couvrent les machines que sa zone plus petite laisse sans courant. Les poteaux prévus déjà réservés retournent au coffre.
  Tout est lu aux prototypes (type « electric-pole », zone d'alimentation, fil, emprise, source électrique des machines) : aucun nom en dur.
  Journal [FO-POTEAU-CHANTIER] (repli fait, ou cause de l'abandon une fois par projet et par poteau). Déterminisme : listes triées, aucun pairs
  décisionnel. Global : champs numériques et chaînes du projet (p.pc_since, p.pc_said).
]]

local Rc = require("shared.team.reconstruction")
local Pc = require("shared.team.poteau_chantier")
local Book = require("shared.team.book")
local Bm = require("shared.team.book_max")
local P = require("shared.team.plan")
local Stock = require("script.team.stock")
local Board = require("script.team.board")
local Events = require("script.core.events")

local PC = {}
PC.ON = true -- tests seulement : faux = l'ancien comportement (le chantier attend son poteau)

local CANDS -- mémoire LOCALE (prototypes) : { name, item, supply, wire } des poteaux d'une tuile
local BY_ITEM
local function cands()
  if CANDS then return CANDS, BY_ITEM end
  CANDS, BY_ITEM = {}, {}
  local protos = game.get_filtered_entity_prototypes({ { filter = "type", type = "electric-pole" } })
  local names = {}
  for name in pairs(protos) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local ok, c = pcall(function()
      local p = protos[name]
      local it = p.items_to_place_this and p.items_to_place_this[1]
      if not it or (p.tile_width or 1) ~= 1 or (p.tile_height or 1) ~= 1 then return nil end
      return { name = name, item = it.name, supply = p.supply_area_distance or 0, wire = p.max_wire_distance or 0 }
    end)
    if ok and c then
      CANDS[#CANDS + 1] = c
      BY_ITEM[c.item] = BY_ITEM[c.item] or c
    end
  end
  return CANDS, BY_ITEM
end

local BOOKS = {} -- mémoire LOCALE : livre de recettes par force (effacé à chaque recherche)
local function book_of(force_name)
  local b = BOOKS[force_name]
  if b then return b end
  local force = game.forces[force_name]
  b = Book.from_game(game.recipe_prototypes, { allowed = function(name)
    local r = force and force.recipes[name]
    return r ~= nil and r.enabled
  end })
  BOOKS[force_name] = b
  return b
end
Events.on(defines.events.on_research_finished, function(e)
  local f = e.research and e.research.force
  if f then BOOKS[f.name] = nil end
end)

local function feasible(f, free, item)
  if (free[item] or 0) >= 1 or Stock.count(f, item) >= 1 then return true end
  local book = book_of(f.force)
  if not book:handcraftable(item) then return false end
  return Bm.feasible(book, item, 1, free, item)
end

local function say_once(p, key, text)
  p.pc_said = p.pc_said or {}
  if p.pc_said[key] then return end
  p.pc_said[key] = true
  log(text)
end

local SUPPLY = {} -- mémoire LOCALE : zone d'alimentation par nom de poteau
local function supply_of(name)
  local s = SUPPLY[name]
  if s == nil then
    local p = game.entity_prototypes[name]
    s = (p and p.type == "electric-pole" and p.supply_area_distance) or false
    SUPPLY[name] = s
  end
  return s or nil
end

local ELEC = {} -- mémoire LOCALE : nom -> boîte de collision (machine à source électrique) ou false
local function machine_box(e)
  local b = ELEC[e.name]
  if b == nil then
    local p = game.entity_prototypes[e.name]
    b = false
    if p and p.electric_energy_source_prototype and p.type ~= "electric-pole" then
      local cb = p.collision_box
      b = { cb.left_top.x, cb.left_top.y, cb.right_bottom.x, cb.right_bottom.y }
    end
    ELEC[e.name] = b
  end
  if not b then return nil end
  local x0, y0, x1, y1 = b[1], b[2], b[3], b[4]
  if e.dir == 2 or e.dir == 6 then x0, y0, x1, y1 = b[2], b[1], b[4], b[3] end
  return { x0 = e.x + x0, y0 = e.y + y0, x1 = e.x + x1, y1 = e.y + y1 }
end

--- Repli du poteau `item` dans le projet p ; rend vrai s'il est fait.
local function substitute(f, p, item, free, surface, tick)
  local list, by_item = cands()
  local c0 = by_item[item]
  if not c0 then return false end
  local b = f.build
  local old, others = {}, {}
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, e in ipairs(p.ents) do
    if supply_of(e.name) then
      if not e.built and e.item == item and e.name == c0.name then old[#old + 1] = e else others[#others + 1] = e end
    end
    x0, y0, x1, y1 = math.min(x0, e.x), math.min(y0, e.y), math.max(x1, e.x), math.max(y1, e.y)
  end
  if #old == 0 then
    say_once(p, item .. ":vide", string.format("[FO-POTEAU-CHANTIER] %s : projet %d : %s manque mais aucun poteau prevu non pose de ce modele dans le plan a %.1f min",
      f.key or "player", p.id, item, tick / 3600))
    return false
  end
  local world = {}
  for _, w in ipairs(surface.find_entities_filtered({ area = { { x0 - c0.wire, y0 - c0.wire }, { x1 + c0.wire, y1 + c0.wire } }, type = "electric-pole",
    force = f.force })) do
    world[#world + 1] = { x = w.position.x, y = w.position.y, supply = w.prototype.supply_area_distance or 0 }
  end
  table.sort(world, function(a, b2) if a.x ~= b2.x then return a.x < b2.x end return a.y < b2.y end)
  local alt = {}
  for _, c in ipairs(list) do if c.item ~= item then alt[#alt + 1] = c end end
  local can = function(c) return feasible(f, free, c.item) end
  local function within(a, q, r) local dx, dy = a.x - q.x, a.y - q.y return dx * dx + dy * dy <= r * r + 1e-9 end
  -- le poteau de repli : celui du premier poteau prévu (même modèle pour tout le chantier), puis contrôle des autres
  local chosen, relays, seen = nil, {}, {}
  local segs = {} -- { a, b } : segments à relayer, dans l'ordre
  for i, e in ipairs(old) do
    local nbrs = {}
    for _, w in ipairs(world) do if within(w, e, c0.wire) then nbrs[#nbrs + 1] = { x = w.x, y = w.y } end end
    for _, o in ipairs(others) do if within(o, e, c0.wire) then nbrs[#nbrs + 1] = { x = o.x, y = o.y } end end
    for j = i + 1, #old do if within(old[j], e, c0.wire) then nbrs[#nbrs + 1] = { x = old[j].x, y = old[j].y } end end
    local c = Rc.pick_chain(chosen and { chosen } or alt, { x = e.x, y = e.y }, nbrs, can)
    if not c then
      say_once(p, item .. ":chaine", string.format("[FO-POTEAU-CHANTIER] %s : projet %d : %s non fabricable, aucun poteau de repli fabricable ne rejoint les voisins (relais au plus %d) a %.1f min",
        f.key or "player", p.id, item, Rc.CHAIN_MAX, tick / 3600))
      return false
    end
    chosen = c
    for _, n in ipairs(nbrs) do segs[#segs + 1] = { a = { x = e.x, y = e.y }, b = n } end
  end
  local function free_tile(x, y)
    if b.occ[P.tkey(math.floor(x), math.floor(y))] then return false end
    if seen[x .. "," .. y] then return false end
    for _, e in ipairs(old) do if e.x == x and e.y == y then return false end end
    return surface.can_place_entity({ name = chosen.name, position = { x, y }, force = f.force })
  end
  for _, sg in ipairs(segs) do
    local pts = Rc.chain_points(sg.a, { sg.b }, chosen.wire)
    if #pts > 0 then
      local put = Pc.place_chain(sg.a, sg.b, pts, chosen.wire, free_tile)
      if not put then
        say_once(p, item .. ":relais", string.format("[FO-POTEAU-CHANTIER] %s : projet %d : aucun relais de %s ne tient entre (%.1f, %.1f) et (%.1f, %.1f) (tuiles prises a %d pres) : repli remis a plus tard a %.1f min",
          f.key or "player", p.id, chosen.name, sg.a.x, sg.a.y, sg.b.x, sg.b.y, Pc.NUDGE, tick / 3600))
        return false
      end
      for _, q in ipairs(put) do
        seen[q.x .. "," .. q.y] = true
        relays[#relays + 1] = q
      end
    end
  end
  -- compensation de la zone d'alimentation : machines électriques du chantier, réseau prévu après le repli
  local machines = {}
  for i, e in ipairs(p.ents) do
    local box = machine_box(e)
    if box then machines[#machines + 1] = { key = i, box = box } end
  end
  local net = {}
  for _, w in ipairs(world) do net[#net + 1] = w end
  for _, o in ipairs(others) do net[#net + 1] = { x = o.x, y = o.y, supply = supply_of(o.name) } end
  for _, e in ipairs(old) do net[#net + 1] = { x = e.x, y = e.y, supply = chosen.supply } end
  for _, q in ipairs(relays) do net[#net + 1] = { x = q.x, y = q.y, supply = chosen.supply } end
  local comp, lost = Pc.compensate(machines, net, chosen.supply, chosen.wire, free_tile)
  if #lost > 0 then
    say_once(p, item .. ":zone", string.format("[FO-POTEAU-CHANTIER] %s : projet %d : %d machine(s) hors de la zone de %s sans place pour un poteau : repli abandonne a %.1f min",
      f.key or "player", p.id, #lost, chosen.name, tick / 3600))
    return false
  end
  -- application : poteaux prévus remplacés, relais et compensation ajoutés au plan (tuiles réservées au projet)
  for _, e in ipairs(old) do e.name, e.item, e.repli = chosen.name, chosen.item, item end
  local part = old[1].part
  local added = 0
  for _, list2 in ipairs({ relays, comp }) do
    for _, q in ipairs(list2) do
      b.occ[P.tkey(math.floor(q.x), math.floor(q.y))] = p.id
      p.ents[#p.ents + 1] = { name = chosen.name, item = chosen.item, x = q.x, y = q.y, dir = 0, part = part, role = "poteau-repli" }
      added = added + 1
    end
  end
  local back = p.stock and p.stock[item] or 0
  if back > 0 then
    local put = Stock.insert(f, item, back)
    p.stock[item] = nil
    back = put or back
  end
  p.pc_since[item] = nil
  log(string.format("[FO-POTEAU-CHANTIER] %s : projet %d : %s non fabricable depuis %.1f min : %d poteau(x) prevu(s) remplace(s) par %s, %d relais, %d de compensation de zone, %d rendu(s) au coffre a %.1f min",
    f.key or "player", p.id, item, Pc.WAIT / 3600, #old, chosen.name, #relays, #comp, back, tick / 3600))
  return true
end

--- Relecture d'un chantier en réserve incomplète (p.missing posé par la réserve).
function PC.try(f, p, tick, surface)
  if not (PC.ON and p and p.missing and #p.missing > 0 and f.build) then return false end
  local _, by_item = cands()
  local free = nil
  local done = false
  for _, m in ipairs(p.missing) do
    local item = m[1]
    if by_item[item] then
      free = free or Board.view_stock(f, Stock.contents(f), tick)
      p.pc_since = p.pc_since or {}
      if feasible(f, free, item) then
        p.pc_since[item] = nil
      else
        if not p.pc_since[item] then
          p.pc_since[item] = tick
          say_once(p, item .. ":attente", string.format("[FO-POTEAU-CHANTIER] %s : projet %d : %s manque (%d) et n'est pas fabricable avec le stock libre : repli dans %.0f min s'il manque encore a %.1f min",
            f.key or "player", p.id, item, m[2] or 0, Pc.WAIT / 3600, tick / 3600))
        end
        p.pc_next = p.pc_next or {}
        if tick - p.pc_since[item] >= Pc.WAIT and tick >= (p.pc_next[item] or 0) then
          if substitute(f, p, item, free, surface, tick) then done = true else p.pc_next[item] = tick + Pc.RETRY end
        end
      end
    end
  end
  return done
end

return PC
