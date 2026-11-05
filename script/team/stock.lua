--[[
  STOCK d'une équipe = coffre du QG + ANNEXES (lot COFFRE, constat du DC du 27/10, 18 h 50 : coffre plein « depuis un bon
  moment », jamais vidé, jamais d'autre coffre). Règles pures : shared/team/annexe.lua ; données : T.annex.

  Toute lecture, prise et dépôt du stock passe par ici (le coffre du QG d'abord, puis les annexes) : un ouvrier, le cerveau
  ou une amélioration ne voit jamais la différence entre un objet du coffre et un objet d'une annexe. Sans annexe, chaque
  fonction est EXACTEMENT l'appel au coffre du QG d'avant (f.hq).

    Stock.count(f, item) / Stock.remove(f, item, n) / Stock.insert(f, item, n) / Stock.contents(f) / Stock.inventories(f)
    Stock.balance(f)          range l'excédent du coffre du QG aux annexes (piles entières) quand il dépasse T.annex.park_at ;
    Stock.grow(f, surface)    pose un coffre du stock (bloc T.annex.block, côté extérieur) quand les cases se remplissent, ou
                              PAR ANTICIPATION (lot STOCKAGE : stock à 60 % pendant 5 min, ou dépôt refusé) ; pose aussi les
                              fours DORMANTS de votre équipe au QG (Stock.deploy_idle, lot ADOPTE) ;
    Stock.wanted(f)           coffres à avoir en main (fabrication de fond) : pour Fond.candidates.
  f.annex = liste d'entités (le coffre détruit par un ennemi est retiré de la liste, son contenu est perdu).
  f.stock_watch = { since, retry } et f.refused_at (nombres seuls) : fenêtre d'agrandissement régulier (shared/team/annexe.lua) ;
  f.annex_sy = face du bloc (+1 sud, -1 nord), fixée à la première pose : une partie d'avant (annexes au sud) garde le sud.
]]

local T = require("shared.team.config")
local A = require("shared.team.annexe")
local Pl = require("shared.ai3.places")
local PlacesQG = require("script.ai3.places_qg")
local Br = require("shared.ai3.bras")
local Ad = require("shared.team.adopte")
local Sg = require("shared.team.stockage") -- lot STOCKAGE (essai 2) : poser le plus grand, améliorer, anneaux (règle pure)
local FQ = require("shared.ai3.fonderie_qg") -- lot PD-FONDERIEQG (D77) : fonderie du QG bornée par l'automatisation

-- Entrées de la fonderie du QG, triées (données de shared/team/config.lua), pour FQ.automated.
local SMELT_INPUTS = {}
do
  local ps = {}
  for p in pairs(T.smelter_inputs) do ps[#ps + 1] = p end
  table.sort(ps)
  for _, p in ipairs(ps) do SMELT_INPUTS[#SMELT_INPUTS + 1] = { p, T.smelter_inputs[p][1], T.smelter_inputs[p][2] } end
end

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
  -- Lot STOCKAGE : un dépôt refusé = plus de place pour cet objet (quel qu'il soit) ; déclenche la pose anticipée d'un coffre.
  if put < n then
    f.refused_at = game.tick or 0
    -- Lot STOCKAGE (essai 2, « les ressources se posent par terre ») : le reste n'est JAMAIS perdu ni posé au sol : il attend (f.stock_pending,
    -- nombres seuls) et entre au stock dès qu'un coffre a de la place (Stock.flush, à chaque pensée de l'équipe, après la pose d'un coffre).
    -- Avant : 19 appels ignoraient le refus (objets perdus), 3 chemins les posaient au sol, le dépôt les laissait dans le sac du PNJ.
    f.stock_pending = f.stock_pending or {}
    f.stock_pending[item] = (f.stock_pending[item] or 0) + (n - put)
    f.stats = f.stats or {}
    f.stats.stock_pending_in = (f.stats.stock_pending_in or 0) + (n - put)
    return n
  end
  return put
end

--- Lot STOCKAGE (essai 2) : objets EN ATTENTE (refusés par un stock plein) remis au coffre du QG puis aux annexes, dans l'ordre des noms.
--- Rend le nombre d'objets encore en attente.
function Stock.flush(f)
  local p = f.stock_pending
  if not p or not (f.hq and f.hq.valid) then return 0 end
  local names = {}
  for name in pairs(p) do names[#names + 1] = name end
  table.sort(names)
  local left = 0
  for _, name in ipairs(names) do
    local n = p[name]
    local put = f.hq.insert({ name = name, count = n })
    if put < n then
      for _, e in ipairs(Stock.annexes(f)) do
        put = put + e.insert({ name = name, count = n - put })
        if put >= n then break end
      end
    end
    if put >= n then p[name] = nil else p[name] = n - put; left = left + n - put end
  end
  if left == 0 then f.stock_pending = nil end
  return left
end

--- Seuil d'alerte du journal [FO-STOCKAGE] pour les objets en attente (demande du lead, 5/11).
Stock.PENDING_ALERT = 1000

--- Objets en attente (0 sans attente).
function Stock.pending(f)
  local n = 0
  for _, v in pairs(f.stock_pending or {}) do n = n + v end
  return n
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
--- Coffres du stock EN MAIN : ceux du coffre et des annexes, moins ce que le plan directeur va encore réclamer (un coffre
--- réservé à un avant-poste n'est pas posé en annexe).
local function chests_in_hand(f, item)
  return math.max(0, Stock.count(f, item) - (Stock.demand and Stock.demand(f, item) or 0))
end

--- Emprise (largeur, hauteur en tuiles) d'un coffre du stock, lue au prototype (1 × 1 sans prototype : moteur simulé).
local function footprint(item)
  local protos = game and game.entity_prototypes
  local proto = protos and protos[item]
  return Pl.tiles(proto and proto.collision_box)
end

--- Face du bloc des annexes : la première pose la fixe (face de l'EXTÉRIEUR de la carte, A.outward) ; une partie d'avant
--- (annexes déjà posées au sud) garde le sud.
local function side(f)
  if f.annex_sy then return f.annex_sy end
  if f.annex and #f.annex > 0 then
    f.annex_sy = 1
  elseif f.hq_pos then
    f.annex_sy = A.outward(f.hq_pos.y)
  else
    return 1 -- position du QG pas encore connue : rien n'est figé (la face se fixe à la première lecture avec position)
  end
  return f.annex_sy
end

--- Lot STOCKAGE (essai 2) : anneaux ouverts (f.annex_rings, 1 au départ : le bloc d'avant) et places de tous les anneaux ouverts.
local function rings(f) return math.max(1, math.min(Sg.MAX_RINGS, f.annex_rings or 1)) end

--- Plafond d'annexes : les places des anneaux OUVERTS pour l'emprise du premier coffre de l'échelle (avant le lot STOCKAGE, essai 2 : le seul
--- bloc de 48 places).
local function capacity(f)
  local k = T.annex.kinds[1]
  local w, h = footprint(k.item)
  return Sg.capacity(side(f), w, h, rings(f))
end

--- Échelle des coffres (Sg) : { { slots }, ... } du plus grand au plus petit (T.annex.kinds) ; rang d'un nom d'entité dans l'échelle (un coffre
--- hors échelle compte comme le plus petit).
local LADDER = {}
for i, k in ipairs(T.annex.kinds) do LADDER[i] = { slots = k.slots } end
local function rank_of(name)
  for i, k in ipairs(T.annex.kinds) do if k.item == name then return i end end
  return nil -- coffre hors échelle : ni compté ni amélioré
end

--- Coffres en main par rang, annexes posées par rang.
local function hand_of(f)
  local out = {}
  for i, k in ipairs(T.annex.kinds) do out[i] = chests_in_hand(f, k.item) end
  return out
end
local function posed_of(f)
  local out = {}
  for _, e in ipairs(Stock.annexes(f)) do
    local r = rank_of(e.name)
    if r then out[r] = (out[r] or 0) + 1 end
  end
  return out
end

function Stock.wanted(f)
  if not (f.hq and f.hq.valid) then return 0 end
  local used, size, n = totals(f)
  if size <= 0 then return 0 end -- capacité inconnue (moteur simulé)
  local tick = game.tick or 0
  local early = A.early_due(f.stock_watch, tick, f.refused_at)
  local hand = hand_of(f)
  local have = 0
  -- Lot STOCKAGE (essai 2) : anneaux pleins (f.annex_full) : seuls comptent les coffres PLUS GRANDS que le plus petit posé (ceux qui
  -- améliorent) ; le fond fabrique alors le premier coffre fabricable de l'échelle (l'acier d'abord, shared/team/fond.lua).
  local smallest = 0
  if f.annex_full then for r, c in pairs(posed_of(f)) do if c > 0 and r > smallest then smallest = r end end end
  for i = 1, #hand do if not f.annex_full or i < smallest then have = have + hand[i] end end
  return A.wanted(used, size, n, have, early, Sg.capacity(side(f), 1, 1, Sg.MAX_RINGS))
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
--- Crochet de pensée (balayage des fantômes d'aperçu), idem.
Stock.on_think = nil
--- Une entité `name` en `pos` toucherait-elle une tuile réservée par le plan directeur ? Posé par script/team/build.lua
--- (Build.reserved_entity ; build.lua requiert ce fichier, pas l'inverse). Absent : rien n'est réservé.
Stock.reserved = nil

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
  -- Lot PD-FONDERIEQG (D77) : dès qu'une ligne à tapis fond une plaque (module fini, débit mesuré : f.team.ia3.covered), les
  -- fours dormants ne sont plus posés au QG au-delà de FQ.KEEP : ils restent au coffre, où la ligne les prend pour grandir.
  local covered = f.team and f.team.ia3 and f.team.ia3.covered
  local n_auto = #FQ.automated(SMELT_INPUTS, covered)
  local why
  cap, why = FQ.limit(cap, FQ.KEEP, n_auto, 0, 0)
  local n = Ad.deploy(have, #registry, 0, cap)
  -- Trace de la fenêtre close (au plus une ligne par fenêtre, 60 lignes par équipe) : fours au coffre, libres (minimum de la
  -- fenêtre), registre, posés : de quoi lire pourquoi des fours restent au coffre (réservés par une tâche, ou plafond atteint).
  f.stats = f.stats or {}
  f.stats.idle_logs = (f.stats.idle_logs or 0) + 1
  if f.stats.idle_logs <= 60 then
    log(string.format("[FO-ADOPTE] player : fenetre %.1f min : %d four(s) au coffre, %d libre(s) et non reclames toute la fenetre (plan : %d), registre %d/%d, a poser %d%s",
      (tick - (f.started or 0)) / 3600, Stock.count(f, T.SMELTER), have, claimed, #registry, cap, n,
      why and string.format(" ([FO-FONDERIE-QG] %d plaque(s) fondue(s) par ligne a tapis : plafond %d au lieu de %d)", n_auto, cap, Br.SMELT_HARD) or ""))
  end
  if n <= 0 then return 0 end
  local tmp = game.create_inventory(8)
  tmp.insert({ name = T.SMELTER, count = Stock.remove(f, T.SMELTER, n) })
  -- le combustible libre accompagne les fours (jusqu'à T.fuel_per_burner chacun) ; sans charbon libre, ils sont posés à sec
  local fuel = math.min(math.max(0, free[T.fuel] or 0), T.fuel_per_burner * n)
  if fuel > 0 then tmp.insert({ name = T.fuel, count = Stock.remove(f, T.fuel, fuel) }) end
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

--- Pose un coffre du stock (au plus un par appel) quand les cases se remplissent (70 %) ou par ANTICIPATION (lot STOCKAGE :
--- stock à 60 % depuis 5 min, ou dépôt refusé). Les places viennent du bloc de T.annex.block, du plus proche du QG au plus
--- lointain, côté extérieur ; une place réservée par le plan directeur (Stock.reserved) est sautée, sans passe de secours.
--- Rend vrai si un coffre a été posé.
--- Lot STOCKAGE (essai 2) : places de tous les anneaux ouverts, pour un coffre w × h, face sy.
local function ring_places(f, sy, w, h)
  local out = {}
  for r = 1, rings(f) do
    for _, p in ipairs(Sg.ring_slots(sy, w, h, r)) do out[#out + 1] = p end
  end
  return out
end

--- Lot STOCKAGE (essai 2) : pose du coffre de rang k sur la première place libre des anneaux ouverts ; rend vrai si posé.
local function place_kind(f, surface, k, tick, n, used, size, st)
  local item = T.annex.kinds[k].item
  local w, h = footprint(item)
  local placed = PlacesQG.place_list(surface, item, f.force, f.hq_pos, ring_places(f, side(f), w, h), 0, 1, function(pos)
    if Stock.reserved and Stock.reserved(f, item, pos) then return false end
    local e = surface.create_entity({ name = item, position = pos, force = f.force })
    if not (e and e.valid) then return false end
    Stock.remove(f, item, 1)
    f.annex = f.annex or {}
    f.annex[#f.annex + 1] = e
    return true
  end)
  if placed <= 0 then return false end
  f.stats = f.stats or {}
  f.stats.annex_placed = (f.stats.annex_placed or 0) + 1
  st.since, st.retry, st.placed_at, f.refused_at = tick, nil, tick, nil -- la fenêtre repart : au plus un coffre toutes les 5 min par anticipation
  log(string.format("[FO-ANNEXE] %s : coffre %d pose (%s), stock %d/%d cases a %.1f min", f.key or "player", n + 1, item,
    used, size, (tick - (f.started or 0)) / 3600))
  Stock.flush(f) -- les objets en attente entrent dans le coffre neuf
  return true
end

--- Lot STOCKAGE (essai 2) : AMÉLIORATION du plus petit coffre posé en coffre de rang k, À LA MÊME PLACE, contenu gardé : remplacement rapide
--- (create_entity fast_replace, F39 : contenu, recette et munitions conservés) ; si le moteur n'a pas remplacé l'ancien (encore valide),
--- le contenu est transféré à la main et l'ancien retiré seulement VIDE. Le coffre retiré revient au stock. Rend vrai si fait.
local function upgrade(f, surface, k, tick)
  local list = Stock.annexes(f)
  local idx, worst = nil, 0
  for i, e in ipairs(list) do
    local r = rank_of(e.name)
    if r and r > k and r > worst then idx, worst = i, r end
  end
  if not idx then return false end
  local old = list[idx]
  local old_name, pos = old.name, old.position
  local before = old.get_inventory(defines.inventory.chest).get_contents()
  local item = T.annex.kinds[k].item
  local e = surface.create_entity({ name = item, position = pos, force = f.force, fast_replace = true, spill = false })
  if not (e and e.valid) then return false end
  if old.valid then
    local names = {}
    for name in pairs(before) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
      local moved = e.insert({ name = name, count = before[name] })
      if moved > 0 then old.remove_item({ name = name, count = moved }) end
    end
    if next(old.get_inventory(defines.inventory.chest).get_contents()) == nil then old.destroy() end
  end
  Stock.remove(f, item, 1)
  if not old.valid then
    f.annex[idx] = e
    Stock.insert(f, old_name, 1)
  else
    f.annex[#f.annex + 1] = e -- l'ancien garde ce qui n'a pas tenu (jamais perdu) : il reste annexe
  end
  f.stats = f.stats or {}
  f.stats.annex_upgraded = (f.stats.annex_upgraded or 0) + 1
  log(string.format("[FO-STOCKAGE] %s : coffre %s ameliore en %s a la meme place (contenu garde) a %.1f min", f.key or "player", old_name, item,
    (tick - (f.started or 0)) / 3600))
  return true
end

--- Pose un coffre du stock (au plus une action par appel) quand les cases se remplissent (70 %) ou par ANTICIPATION (lot STOCKAGE :
--- stock à 60 % depuis 5 min, ou dépôt refusé). Lot STOCKAGE (essai 2, shared/team/stockage.lua) : le PLUS GRAND coffre en main est posé
--- sur une place libre des anneaux ouverts ; sans place libre, le plus petit coffre posé est AMÉLIORÉ (bois -> fer -> acier) ; sinon un
--- ANNEAU de plus s'ouvre (le même bloc 8 tuiles plus loin, Sg.MAX_RINGS au plus : journal [FO-STOCKAGE] quand la borne est atteinte).
--- Une place réservée par le plan directeur (Stock.reserved) est sautée. Les objets en attente (refusés) entrent d'abord (Stock.flush).
--- Rend vrai si un coffre a été posé ou amélioré.
function Stock.grow(f, surface, tick)
  if not (f.hq and f.hq.valid) then return false end
  if Stock.on_think then Stock.on_think(f, tick) end -- lot FANTOMES : balayage des aperçus (posé par script/team/board.lua)
  Stock.deploy_idle(f, surface, tick)
  local waiting = Stock.flush(f)
  local used, size, n = totals(f)
  if size <= 0 then return false end
  f.stock_watch = f.stock_watch or {}
  local st = A.watch(f.stock_watch, used, size, tick)
  if waiting > 0 then
    f.refused_at = f.refused_at or tick -- des objets attendent : il faut de la place
    if tick - (f.pending_said or -1000000) >= 5 * 3600 then
      f.pending_said = tick
      log(string.format("[FO-STOCKAGE] %s : %d objet(s) en attente d'une place au stock (refuses, ni perdus ni au sol), %d annexe(s), " ..
        "anneaux %d/%d, a %.1f min", f.key or "player", waiting, n, rings(f), Sg.MAX_RINGS, (tick - (f.started or 0)) / 3600))
    end
  end
  -- Demande du lead (5/11) : l'attente est hors de la lecture du stock ; à la borne des anneaux elle grossit sans se voir : une ALERTE au
  -- journal quand elle dépasse Stock.PENDING_ALERT objets (une fois par dépassement ; réarmée quand elle repasse dessous).
  if waiting > Stock.PENDING_ALERT and not f.pending_alert then
    f.pending_alert = tick
    log(string.format("[FO-STOCKAGE] %s : ALERTE : %d objet(s) en attente (plus de %d), invisibles du stock ; %d annexe(s), anneaux %d/%d, a %.1f min",
      f.key or "player", waiting, Stock.PENDING_ALERT, n, rings(f), Sg.MAX_RINGS, (tick - (f.started or 0)) / 3600))
  elseif waiting <= Stock.PENDING_ALERT then
    f.pending_alert = nil
  end
  local early = A.early_due(st, tick, f.refused_at)
  side(f) -- la face du bloc se fixe à la première pensée où la position du QG est connue (comme avant)
  if not (early or A.fill(used, size) >= T.annex.grow_at) then -- (plus de plafond fixe : les anneaux et leur borne décident plus bas)
    f.annex_full = nil
    return false
  end
  if st.retry and tick < st.retry then return false end
  local hand, posed = hand_of(f), posed_of(f)
  local c = { used = used, size = size, n = n, early = true, hand = hand, annexes = posed, rings = rings(f),
    free_places = n < capacity(f) and 1 or 0 }
  local action, k = Sg.decide(c, LADDER)
  if action == "poser" then
    if place_kind(f, surface, k, tick, n, used, size, st) then f.annex_full = nil return true end
    c.free_places = 0 -- toutes les places des anneaux ouverts sont prises ou réservées
    action, k = Sg.decide(c, LADDER)
  end
  if action == "ameliorer" then
    f.annex_full = true
    if upgrade(f, surface, k, tick) then st.retry = nil return true end
  elseif action == "anneau" then
    f.annex_full = true
    f.annex_rings = rings(f) + 1
    log(string.format("[FO-STOCKAGE] %s : anneau %d/%d ouvert (bloc plein : %d annexe(s), stock %d/%d cases) a %.1f min", f.key or "player",
      f.annex_rings, Sg.MAX_RINGS, n, used, size, (tick - (f.started or 0)) / 3600))
    local kh = nil
    for i = 1, #hand do if hand[i] > 0 then kh = i break end end
    if kh and place_kind(f, surface, kh, tick, n, used, size, st) then return true end
  elseif k == nil and action == "rien" and rings(f) >= Sg.MAX_RINGS and n >= capacity(f) then
    f.annex_full = true
    if not f.annex_cap_said then
      f.annex_cap_said = tick
      log(string.format("[FO-STOCKAGE] %s : BORNE atteinte : %d anneaux, %d annexe(s), stock %d/%d cases, %d objet(s) en attente, a %.1f min",
        f.key or "player", Sg.MAX_RINGS, n, used, size, Stock.pending(f), (tick - (f.started or 0)) / 3600))
    end
  elseif action == "fabriquer" then
    f.annex_full = n >= capacity(f) or nil
  end
  -- Rien posé : on ne refait pas la recherche à chaque pensée.
  st.retry = tick + T.annex.retry
  return false
end

return Stock
