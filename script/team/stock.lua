--[[
  STOCK d'une équipe = coffre du QG + ANNEXES (lot COFFRE, constat du DC du 27/10, 18 h 50 : coffre plein « depuis un bon
  moment », jamais vidé, jamais d'autre coffre). Règles pures : shared/team/annexe.lua ; données : T.annex.

  Toute lecture, prise et dépôt du stock passe par ici (le coffre du QG d'abord, puis les annexes) : un ouvrier, le cerveau
  ou une amélioration ne voit jamais la différence entre un objet du coffre et un objet d'une annexe. Sans annexe, chaque
  fonction est EXACTEMENT l'appel au coffre du QG d'avant (f.hq).

    Stock.count(f, item) / Stock.remove(f, item, n) / Stock.insert(f, item, n) / Stock.contents(f) / Stock.inventories(f)
    Stock.balance(f)          range l'excédent du coffre du QG aux annexes (piles entières) quand il dépasse T.annex.park_at ;
    Stock.grow(f, surface)    pose un coffre du stock (rangées T.hq_rows.annex) quand les cases se remplissent ; pose aussi les
                              fours DORMANTS de votre équipe au QG (Stock.deploy_idle, lot ADOPTE) ;
    Stock.wanted(f)           coffres à avoir en main (fabrication de fond) : pour Fond.candidates.
  f.annex = liste d'entités (le coffre détruit par un ennemi est retiré de la liste, son contenu est perdu).
]]

local T = require("shared.team.config")
local A = require("shared.team.annexe")
local Pl = require("shared.ai3.places")
local PlacesQG = require("script.ai3.places_qg")
local Br = require("shared.ai3.bras")
local Ad = require("shared.team.adopte")

local Stock = {}

--- Annexes valides (la liste est purgée des entités disparues).
function Stock.annexes(f)
  local a = f.annex
  if not a or #a == 0 then return {} end
  local out = {}
  for _, e in ipairs(a) do
    if e.valid then out[#out + 1] = e end
  end
  if #out ~= #a then f.annex = out end
  return out
end

local function chest_inv(e) return e.get_inventory(defines.inventory.chest) end

function Stock.count(f, item)
  local n = f.hq.get_item_count(item)
  for _, e in ipairs(Stock.annexes(f)) do n = n + e.get_item_count(item) end
  return n
end

--- Retire jusqu'à `n` objets (coffre du QG d'abord) ; rend le nombre retiré.
function Stock.remove(f, item, n)
  local got = f.hq.remove_item({ name = item, count = n })
  if got < n then
    for _, e in ipairs(Stock.annexes(f)) do
      got = got + e.remove_item({ name = item, count = n - got })
      if got >= n then break end
    end
  end
  return got
end

--- Dépose jusqu'à `n` objets (coffre du QG d'abord, puis les annexes) ; rend le nombre déposé.
function Stock.insert(f, item, n)
  local put = f.hq.insert({ name = item, count = n })
  if put < n then
    for _, e in ipairs(Stock.annexes(f)) do
      put = put + e.insert({ name = item, count = n - put })
      if put >= n then break end
    end
  end
  return put
end

--- Contenu du stock { [objet] = nombre } : coffre du QG et annexes.
function Stock.contents(f)
  local c = chest_inv(f.hq).get_contents()
  local annex = Stock.annexes(f)
  if #annex == 0 then return c end
  local out = {}
  for k, v in pairs(c) do out[k] = v end
  for _, e in ipairs(annex) do
    for k, v in pairs(chest_inv(e).get_contents()) do out[k] = (out[k] or 0) + v end
  end
  return out
end

--- Inventaires du stock (pour les fonctions du moteur qui prennent une liste d'inventaires).
function Stock.inventories(f)
  local list = { chest_inv(f.hq) }
  for _, e in ipairs(Stock.annexes(f)) do list[#list + 1] = chest_inv(e) end
  return list
end

-- Cases prises et cases du coffre du QG, puis du total.
local function slots_of(inv)
  local size = #inv
  return size - inv.count_empty_stacks(), size
end

local function totals(f)
  local used, size = slots_of(chest_inv(f.hq))
  local annex = Stock.annexes(f)
  for _, e in ipairs(annex) do
    local u, s = slots_of(chest_inv(e))
    used, size = used + u, size + s
  end
  return used, size, #annex
end

--- Rangement : l'excédent du coffre du QG passe aux annexes quand le coffre dépasse T.annex.park_at. Rend le nombre
--- d'objets rangés.
function Stock.balance(f)
  if not (f.hq and f.hq.valid) then return 0 end
  local annex = Stock.annexes(f)
  if #annex == 0 then return 0 end
  local inv = chest_inv(f.hq)
  local used, size = slots_of(inv)
  if size <= 0 or used < T.annex.park_at * size then return 0 end
  local room = 0
  for _, e in ipairs(annex) do room = room + chest_inv(e).count_empty_stacks() end
  local contents = inv.get_contents()
  local stack_of = {}
  for name in pairs(contents) do
    local proto = game.item_prototypes[name]
    stack_of[name] = proto and proto.stack_size or 1
  end
  local moved = 0
  for _, m in ipairs(A.park_plan(contents, stack_of, size, used, room)) do
    local left = m[2]
    for _, e in ipairs(annex) do
      if left <= 0 then break end
      local put = e.insert({ name = m[1], count = left })
      if put > 0 then
        inv.remove({ name = m[1], count = put })
        left, moved = left - put, moved + put
      end
    end
  end
  if moved > 0 then
    f.stats = f.stats or {}
    f.stats.annex_parked = (f.stats.annex_parked or 0) + moved
  end
  return moved
end

--- Coffres à avoir en main pour agrandir le stock (0 : le stock a de la place).
function Stock.wanted(f)
  if not (f.hq and f.hq.valid) then return 0 end
  local used, size, n = totals(f)
  if size <= 0 then return 0 end -- capacité inconnue (moteur simulé)
  local have = 0
  for _, k in ipairs(T.annex.kinds) do have = have + Stock.count(f, k.item) end
  return A.wanted(used, size, n, have)
end

--- Stock LIBRE (coffre et annexes moins ce que les tâches ont réservé) : posé par script/team/board.lua au chargement
--- (le tableau requiert ce fichier : pas de require retardé, F24). Absent : le stock tel quel.
Stock.free_view = nil
--- Pose de fours au QG (Outposts.place_smelters), posée par script/team/board.lua pour la même raison.
Stock.place_smelters = nil
--- Registre des fours du QG (Outposts.smelters), idem.
Stock.smelters = nil
--- Exemplaires d'un objet que le plan directeur va encore réclamer (posé par script/team/board.lua) : jamais dormants.
Stock.demand = nil

--- Lot ADOPTE (constat du DC : « les IA se mettent à poser des fours ») : les fours LIBRES au-delà de Ad.IDLE_KEEP sont posés
--- au QG (registre f.smelters, rangées T.hq_rows.smelter), jusqu'à Br.SMELT_HARD fours en tout (ils sont déjà fabriqués : un four
--- de plus, même sans minerai, ne coûte rien, contrairement à une commande d'avance) ; le combustible
--- vient du stock libre. VOTRE équipe seulement : les factions posent leurs fours par leurs vagues (Br.smelters). Une ligne
--- [FO-ADOPTE] par pose. Rend le nombre posé.
function Stock.deploy_idle(f, surface, tick)
  if not (f.is_player and f.hq and f.hq.valid and Stock.free_view and Stock.place_smelters and Stock.smelters) then return 0 end
  local ok, on = pcall(function() return settings.global["fo-war-adopte"].value end)
  if ok and on == false then return 0 end
  local free = Stock.free_view(f, tick)
  -- Dormant = resté LIBRE toute une fenêtre (A.window) : le kit de départ et les fours qu'une tâche va réclamer ne sont pas posés.
  local claimed = Stock.demand and Stock.demand(f, T.SMELTER) or 0
  local w, lo = Ad.window(f.idle_window, tick, math.max(0, (free[T.SMELTER] or 0) - claimed))
  f.idle_window = w
  if lo == nil then return 0 end
  local have = lo
  local registry = Stock.smelters(f)
  local cap = Br.SMELT_HARD
  local n = Ad.deploy(have, #registry, 0, cap, free[T.fuel] or 0, T.fuel_per_burner)
  -- Trace de la fenêtre close (au plus une ligne par fenêtre, 60 lignes par équipe) : fours au coffre, libres (minimum de la
  -- fenêtre), registre, posés : de quoi lire pourquoi des fours restent au coffre (réservés par une tâche, ou plafond atteint).
  f.stats = f.stats or {}
  f.stats.idle_logs = (f.stats.idle_logs or 0) + 1
  if f.stats.idle_logs <= 60 then
    log(string.format("[FO-ADOPTE] player : fenetre %.1f min : %d four(s) au coffre, %d libre(s) et non reclames toute la fenetre (plan : %d), registre %d/%d, a poser %d",
      (tick - (f.started or 0)) / 3600, Stock.count(f, T.SMELTER), have, claimed, #registry, cap, n))
  end
  if n <= 0 then return 0 end
  local tmp = game.create_inventory(8)
  tmp.insert({ name = T.SMELTER, count = Stock.remove(f, T.SMELTER, n) })
  tmp.insert({ name = T.fuel, count = Stock.remove(f, T.fuel, T.fuel_per_burner * n) })
  local placed = Stock.place_smelters(f, surface, n, tmp)
  for name, c in pairs(tmp.get_contents()) do Stock.insert(f, name, c) end
  tmp.destroy()
  if placed > 0 then
    f.stats = f.stats or {}
    f.stats.idle_deployed = (f.stats.idle_deployed or 0) + placed
    log(string.format("[FO-ADOPTE] player : %d four(s) dormant(s) pose(s) au QG (libres %d, registre %d -> %d, plafond %d) a %.1f min", placed,
      have, #registry - placed, #registry, cap, (tick - (f.started or 0)) / 3600))
  end
  return placed
end

--- Pose un coffre du stock (au plus un par appel) quand les cases se remplissent. Rend vrai si un coffre a été posé.
function Stock.grow(f, surface, tick)
  if not (f.hq and f.hq.valid) then return false end
  Stock.deploy_idle(f, surface, tick)
  local used, size, n = totals(f)
  if size <= 0 or not A.need_chest(used, size, n) then return false end
  for _, k in ipairs(T.annex.kinds) do
    if Stock.count(f, k.item) >= 1 then
      local placed = PlacesQG.place(surface, k.item, f.force, f.hq_pos, T.hq_rows.annex,
        Pl.need(n, 1, T.hq_rows_slack), 1, function(pos)
          local e = surface.create_entity({ name = k.item, position = pos, force = f.force })
          if not (e and e.valid) then return false end
          Stock.remove(f, k.item, 1)
          f.annex = f.annex or {}
          f.annex[#f.annex + 1] = e
          return true
        end)
      if placed > 0 then
        f.stats = f.stats or {}
        f.stats.annex_placed = (f.stats.annex_placed or 0) + 1
        log(string.format("[FO-ANNEXE] %s : coffre %d pose (%s), stock %d/%d cases a %.1f min", f.key or "player", n + 1, k.item,
          used, size, (tick - (f.started or 0)) / 3600))
        return true
      end
    end
  end
  return false
end

return Stock
