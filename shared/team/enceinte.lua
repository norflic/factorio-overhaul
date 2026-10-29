--[[
  ESPACE ET ENCEINTE des équipes de PNJ (lot ESPACE, 29/10, remarque 5 du DC : « gestion de l'espace (construire vers
  l'extérieur) » et enceinte de murailles). Lua PUR : aucune API du jeu, aucun nom d'objet ; lu hors jeu
  (tests/enceinte_test.lua) et en jeu (script/team/build.lua, Build.space_step, qui fait les relevés du moteur).

  1. CROISSANCE : le carré de lots grandit d'un cran quand la place LIBRE dans le rayon actuel passe sous un seuil, que
     tout le rayon est évalué, que l'équipe n'est pas surchargée de chantiers et qu'elle a déjà fini un projet.
  2. ENCEINTE : quand la base a fini E.MIN_PROJECTS projets et que la croissance n'est plus voulue (assez de place libre,
     ou rayon maximal), un anneau de murs d'une tuile est posé à E.GAP tuiles AU-DELÀ du treillis (jamais dedans : les
     lots, rues, tapis et poteaux du plan ne croisent jamais l'anneau). Des OUVERTURES de la largeur d'une rue (4)
     sont laissées dans l'anneau en prolongement des rues principales (celles qui bordent le lot du QG) : les PNJ, les
     tapis et les poteaux passent, et l'anneau ne referme jamais l'équipe sur elle-même. Le rayon est ensuite FIGÉ
     (voir Build.grow) : un lot posé après l'anneau serait dehors, ou l'anneau couperait un lot.

  Géométrie (tuiles entières, repère du treillis de shared/team/plan.lua) : le treillis de rayon r couvre en x et en y les
  tuiles [ox - (28 r + 16), ox + 28 r + 15] (lots de 24, rues de 4, pas de 28). Le mur est sur la tuile
  ox - (28 r + 16) - GAP - 1 à l'ouest et ox + 28 r + 16 + GAP à l'est (idem en y).

  Déterminisme : listes triées, aucun `pairs`, aucune trigonométrie.
]]

local E = {}

E.PITCH = 28
E.HALF = 12
E.STREET = 4

E.GAP = 4                 -- tuiles libres entre le bord du treillis et le mur
E.MAIN_STREETS = { -1, 0 } -- rues principales : rangées/colonnes -1 et 0 (celles qui bordent le lot (0, 0) du QG)
E.GROW_FREE_MIN = 3       -- croissance quand moins de 3 lots libres (et utilisables) dans le rayon
E.BUSY_MAX = 2            -- … et au plus 2 chantiers en cours
E.MIN_PROJECTS = 5        -- projets finis avant de murer
E.CHECK_TICKS = 1800      -- période (ticks) des décisions de croissance et d'enceinte (30 s)
E.REPAIR_TICKS = 18000    -- période (ticks) du contrôle des murs détruits (5 min)
E.REPAIR_BATCH = 200      -- murs contrôlés par passe
E.RETRY_TICKS = 108000    -- après un refus du plan de l'enceinte : nouvel essai 30 min plus tard
E.RESERVE_TICKS = 18000    -- enceinte restée 5 min « en réserve » sans ses murs (briques prises ailleurs) : annulée, rayon libéré

local function sorted_keys(t)
  local out = {}
  for k in next, t do out[#out + 1] = k end
  table.sort(out)
  return out
end

--- Lots utilisables par un module (libres ou à défricher, ni pris ni écartés par des échecs), le lot du QG excepté.
function E.free_count(lots)
  local n = 0
  for _, k in ipairs(sorted_keys(lots or {})) do
    local l = lots[k]
    if not (l.i == 0 and l.j == 0) and not l.used and (l.state == "libre" or l.state == "defricher")
      and not (l.bad and l.bad >= 2) then
      n = n + 1
    end
  end
  return n
end

--- La croissance est-elle voulue ? info = { radius, rmax, pending (évaluations en file), free, busy, done, enc }.
--- Rend (vrai) ou (faux, raison).
function E.grow_due(info)
  if info.enc then return false, "enceinte" end
  if info.radius >= info.rmax then return false, "rayon maximal" end
  if (info.pending or 0) > 0 then return false, "evaluation en cours" end
  if (info.free or 0) >= E.GROW_FREE_MIN then return false, "place libre" end
  if (info.busy or 0) > E.BUSY_MAX then return false, "chantiers en cours" end
  if (info.done or 0) < 1 then return false, "rien de fini" end
  return true
end

--- L'enceinte est-elle voulue ? Même info. Elle attend que la croissance ne soit plus voulue pour de la PLACE
--- (le seul motif qui ne dépend pas de l'économie : place libre suffisante ou rayon maximal).
function E.enclosure_due(info)
  if info.enc then return false, "deja" end
  if (info.pending or 0) > 0 then return false, "evaluation en cours" end
  if (info.done or 0) < E.MIN_PROJECTS then return false, "base trop jeune" end
  if info.radius < info.rmax and (info.free or 0) < E.GROW_FREE_MIN then return false, "croissance voulue" end
  return true
end

--- Une enceinte pas encore finie reste-t-elle bloquée en réserve (matière absente) depuis assez longtemps pour être
--- annulée ? Le rayon est figé dès la demande : sans cette sortie, des briques dépensées ailleurs le figeraient pour toujours.
--- Jamais pour une enceinte déjà finie (finished non nil) : annuler sa réparation libérerait le rayon et provoquerait une
--- seconde enceinte dont l'anneau couperait les lots du nouveau rayon.
function E.reserve_stalled(state, started, finished, tick)
  return finished == nil and state == "reserve" and started ~= nil and tick - started >= E.RESERVE_TICKS
end

--- Bornes de l'anneau (tuiles du mur, incluses) pour un treillis ancré en lat = { ox, oy } et de rayon r.
function E.bounds(lat, r, gap)
  gap = gap or E.GAP
  local h = E.PITCH * r + E.HALF + E.STREET + gap
  return lat.ox - h - 1, lat.oy - h - 1, lat.ox + h, lat.oy + h
end

--- Tuile de l'axe (x ou y relatif au QG) dans l'ouverture d'une rue principale ? `o` : origine du treillis sur l'axe.
local function in_gate(v, o, mains)
  for _, m in ipairs(mains) do
    local a = o + E.PITCH * m + E.HALF
    if v >= a and v < a + E.STREET then return true end
  end
  return false
end

--- Anneau de murs : { walls = { { tx, ty, x, y, side } ... }, gates = nombre de tuiles laissées ouvertes,
--- skipped = { [raison] = nombre } }. `skip(tx, ty)` (facultatif) rend une raison (chaîne) pour une tuile à ne pas murer
--- (eau, ressource, bâtiment, tuile réservée), sinon nil. Ordre : côté nord, côté sud, ouest, est (puis x, y croissants).
function E.ring(lat, r, opts)
  opts = opts or {}
  local x0, y0, x1, y1 = E.bounds(lat, r, opts.gap)
  local mains = opts.mains or E.MAIN_STREETS
  local out = { walls = {}, gates = 0, skipped = {}, bounds = { x0, y0, x1, y1 } }
  local function add(tx, ty, side, gate)
    if gate then out.gates = out.gates + 1 return end
    local why = opts.skip and opts.skip(tx, ty) or nil
    if why then out.skipped[why] = (out.skipped[why] or 0) + 1 return end
    out.walls[#out.walls + 1] = { tx = tx, ty = ty, x = tx + 0.5, y = ty + 0.5, side = side }
  end
  for tx = x0, x1 do add(tx, y0, "n", in_gate(tx, lat.ox, mains)) end
  for tx = x0, x1 do add(tx, y1, "s", in_gate(tx, lat.ox, mains)) end
  for ty = y0 + 1, y1 - 1 do add(x0, ty, "o", in_gate(ty, lat.oy, mains)) end
  for ty = y0 + 1, y1 - 1 do add(x1, ty, "e", in_gate(ty, lat.oy, mains)) end
  return out
end

--- Murs d'un anneau sans obstacle (borne haute du coût) : périmètre moins les tuiles d'ouverture.
function E.max_walls(r, opts)
  opts = opts or {}
  local h = E.PITCH * r + E.HALF + E.STREET + (opts.gap or E.GAP)
  local side = 2 * h + 2
  return 4 * (side - 1) - 4 * #(opts.mains or E.MAIN_STREETS) * E.STREET
end

--- Nombre de fabrications d'une recette que le stock permet. ings = { { name, amount } ... }, count(name) = stock.
function E.crafts_possible(ings, count)
  if #ings == 0 then return 0 end
  local best
  for _, ing in ipairs(ings) do
    local n = math.floor(count(ing.name) / math.max(1, ing.amount))
    if not best or n < best then best = n end
  end
  return best or 0
end

--- Murs en stock, plus ceux que les ingrédients du stock permettent de fabriquer : de quoi payer `need` murs ?
function E.affordable(need, walls_in_stock, craftable)
  return walls_in_stock + craftable >= need
end

--- Fabrications à lancer pour `missing` murs d'une recette qui en rend `per_craft` : au plus `possible`.
function E.crafts_to_run(missing, per_craft, possible)
  if missing <= 0 or possible <= 0 then return 0 end
  return math.min(possible, math.ceil(missing / math.max(1, per_craft)))
end

return E
