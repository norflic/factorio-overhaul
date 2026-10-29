--[[
  Lot REBUILD-RAPIDE (d), côté RUNTIME : foreuse thermique de secours dans un projet du plan directeur rouvert (règles pures :
  shared/team/rebuild_rapide.lua). Appelé par Recon.craft_spares (script/team/reconstruction.lua) à chaque pensée d'équipe, avec le livre
  de recettes et le stock libre : rien à abonner ici.

  Retour du DC (29/10 vers 22 h, 0.6.18) : « le mieux, ça serait évidemment de remettre des foreuses thermiques et cetera, on refait fondre
  […] ils peuvent pas faire de foreuses électriques parce qu'ils ont plus de cuivre, donc voilà, thermiques. Ils auraient dû faire ça. »
  Mesuré dans sa partie (factorio-current.log, Scarlet, de 148 à 192 min) : les fonderies 6, 7 et 8 sont restées rouvertes plus de 40 min
  avec « manque au coffre {electric-mining-drillx3 à x6} » et « small-electric-pole non fabricable, matiere manquante : copper-plate ».

  Chaîne : une foreuse ÉLECTRIQUE d'un projet rouvert (pièce non bâtie) dont l'objet n'est ni au stock libre ni fabricable avec lui, alors
  que la foreuse à COMBUSTION l'est, devient au plan une foreuse à combustion posée dans l'ancienne emprise et qui dépose dans le même
  réceptacle (Rr.subst_center) : e.name, e.item, e.x, e.y changent, l'ancienne pièce est gardée dans e.subst. Le plan directeur la pose
  comme n'importe quelle pièce (fantôme, ravivage par un PNJ, combustible porté : script/team/build.lua, lot REBUILD-RAPIDE) et le relevé la
  surveille à sa nouvelle place. Dès que l'objet électrique est AU COFFRE, la foreuse à combustion est reprise au coffre et la pièce
  électrique est rouverte (Rr.revert_due) ; tant qu'elle attend, l'objet électrique est fabriqué s'il est fabricable (tâche « craft »).
  État écrit : e.subst (table simple : nom, objet, x, y) sur les pièces du plan ; b.sweep.rr_logs (journal borné). Journal [FO-REBUILD-RAPIDE].
]]

local R = require("shared.ai3.reglages")
local T = require("shared.team.config")
local P = require("shared.team.plan")
local Rr = require("shared.team.rebuild_rapide")
local Board = require("script.team.board")
local Stock = require("script.team.stock")
local Sweep = require("script.team.rebuild_sweep")

local RrRt = {}

RrRt.SAFE_R = 28        -- tuiles : pas de retour à l'électrique avec un ennemi à cette portée (comme Sweep.ENEMY_R)
RrRt.CRAFT_CAP = 6      -- objets fabriqués d'avance au plus par tâche
local REBUILD_STATES = { reserve = true, defrichage = true, fantomes = true, chantier = true }

local ITEM_OF = {} -- mémoire LOCALE (prototypes seulement)
local function item_of(name)
  local it = ITEM_OF[name]
  if it == nil then
    local p = game.entity_prototypes[name]
    local list = p and p.items_to_place_this
    it = (list and list[1] and list[1].name) or false
    ITEM_OF[name] = it
  end
  return it or nil
end

local function copy_sorted(t)
  local keys, out = {}, {}
  for k in next, t do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do out[k] = t[k] end
  return out
end

--- L'objet est-il au stock libre ou fabricable à la main avec lui ? (même règle que Recon : available_or_craftable)
local function obtainable(book, free, item)
  if (free[item] or 0) >= 1 then return true end
  if not book:handcraftable(item) then return false end
  local avail = copy_sorted(free)
  avail[item] = 0
  return next(book:plan({ { item, 1 } }, avail).raw) == nil
end

local function say(f, fmt, ...)
  local st = f.build and f.build.sweep
  if not st then return end
  if (st.rr_logs or 0) >= Sweep.RAPIDE_LOGS then return end
  st.rr_logs = (st.rr_logs or 0) + 1
  log(string.format("[FO-REBUILD-RAPIDE] %s : " .. fmt, f.key or "player", ...))
end

--- Retire le fantôme de `name` posé en (x, y) (sinon le fantôme de l'ancienne pièce garderait la place).
local function drop_ghost(surface, force, name, x, y)
  for _, gh in ipairs(surface.find_entities_filtered({ position = { x, y }, radius = 0.3, ghost_name = name, force = force })) do
    if gh.valid then gh.destroy() end
  end
end

local function substitute(f, surface, q, e, burner_item, tick)
  local bsize = (P.size(T.DRILL, 0))
  local bx, by = Rr.subst_center(q.ents, e, T.drill_electric.size, T.drill_electric.drop, { size = bsize, drop = T.drill_drop },
    function(name, dir) return P.size(name, dir) end)
  if not bx then
    e.subst_fail = true -- géométrie impossible (aucun réceptacle où la foreuse à combustion dépose) : la pièce attend son objet électrique
    return false
  end
  if e.ghosted then drop_ghost(surface, f.force, e.name, e.x, e.y) end
  e.subst = { name = e.name, item = e.item, x = e.x, y = e.y }
  e.name, e.item, e.x, e.y = T.DRILL, burner_item, bx, by
  e.ghosted, e.fails, e.npc_blocks, e.miss = false, 0, 0, nil
  say(f, "projet %d : foreuse electrique introuvable et non fabricable (cuivre ou circuits absents) en (%.1f, %.1f) : foreuse a combustion " ..
    "posee a sa place en (%.1f, %.1f), %d combustible(s) porte(s), retour a l'electrique des que l'objet sera au coffre, a %.1f min", q.id or 0,
    e.subst.x, e.subst.y, bx, by, Rr.SUBST_FUEL, tick / 3600)
  return true
end

local function revert(f, surface, q, e, tick)
  local s = e.subst
  if e.built then
    if surface.find_nearest_enemy({ position = { x = e.x, y = e.y }, max_distance = RrRt.SAFE_R, force = f.force }) then return false end
    local ent = surface.find_entity(e.name, { e.x, e.y })
    if ent and ent.valid then
      local taken = false
      for _, inv in ipairs(Stock.inventories(f)) do
        if inv and inv.valid and ent.mine({ inventory = inv, force = false, raise_destroyed = false }) then taken = true break end
      end
      if not taken then return false end -- coffre plein : la foreuse à combustion reste, nouvel essai à la pensée suivante
    end
  elseif e.ghosted then
    drop_ghost(surface, f.force, e.name, e.x, e.y)
  end
  e.name, e.item, e.x, e.y = s.name, s.item, s.x, s.y
  e.subst, e.subst_fail = nil, nil
  e.built, e.ghosted, e.fails, e.npc_blocks, e.miss = false, false, 0, 0, nil
  if not REBUILD_STATES[q.state] then Sweep.reopen_pieces(q, { { e = e } }, tick) end
  say(f, "projet %d : foreuse electrique de nouveau au coffre : la foreuse a combustion est reprise, la foreuse electrique est reposee en " ..
    "(%.1f, %.1f) a %.1f min", q.id or 0, e.x, e.y, tick / 3600)
  return true
end

--- Tâche de fabrication de `n` objets `item` si le stock libre le permet (comme Recon.craft_spares).
local function craft(f, book, free, item, n, tick)
  if n <= 0 or not book:handcraftable(item) then return 0 end
  local avail = copy_sorted(free)
  avail[item] = 0
  local qp = book:plan({ { item, n } }, avail)
  for m = n - 1, 1, -1 do
    if next(qp.raw) == nil then break end
    qp, n = book:plan({ { item, m } }, avail), m
  end
  if next(qp.raw) ~= nil then return 0 end
  local uses = {}
  for k in next, qp.uses do uses[#uses + 1] = k end
  table.sort(uses)
  local list = {}
  for _, k in ipairs(uses) do list[#list + 1] = { k, qp.uses[k] } end
  return Board.add(f, { { key = "craft:" .. item .. ":rebuild-rapide", kind = "craft", prio = Rr.PRIO_MAIN, item = item, count = n,
    steps = qp.crafts, uses = list, tag = "reconstruction", domain = "defense" } }, tick)
end

--- Une pensée de l'équipe `f` (livre `book`, stock libre `free`). Rend substitutions, retours.
function RrRt.drill_swap(f, book, free, tick)
  local b = f.build
  if not (R.REBUILD_SWEEP and b and b.projects and b.order and book and free) or f.eliminated then return 0, 0 end
  if not (f.hq and f.hq.valid) then return 0, 0 end
  local elec_item, burner_item = item_of(T.DRILL_ELECTRIC), item_of(T.DRILL)
  if not (elec_item and burner_item) then return 0, 0 end
  local surface = f.hq.surface
  local elec_ok, burner_ok -- lus au premier besoin (le livre coûte)
  local have_elec = math.min(free[elec_item] or 0, Stock.count(f, elec_item))
  local n_sub, n_rev, wait_elec, wait_burner = 0, 0, 0, 0
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and q.ents and not q.abandoned then
      for _, e in ipairs(q.ents) do
        if e.subst then
          if n_rev < Rr.REVERT_PER_PASS and Rr.revert_due(e, have_elec - n_rev) and revert(f, surface, q, e, tick) then
            n_rev = n_rev + 1
          else
            wait_elec = wait_elec + 1
            if not e.built then wait_burner = wait_burner + 1 end
          end
        elseif not e.built and not e.subst_fail and e.name == T.DRILL_ELECTRIC and n_sub < Rr.SUBST_PER_PASS and REBUILD_STATES[q.state]
          and Rr.partial_go(q) and (q.stock and q.stock[e.item] or 0) < 1 then
          if elec_ok == nil then elec_ok, burner_ok = obtainable(book, free, elec_item), obtainable(book, free, burner_item) end
          if Rr.subst_due(e, T.DRILL_ELECTRIC, elec_ok, burner_ok) and substitute(f, surface, q, e, burner_item, tick) then
            n_sub = n_sub + 1
            wait_burner = wait_burner + 1
          end
        end
      end
    end
  end
  -- Foreuses à combustion de secours à fabriquer (au coffre : rien), puis l'objet électrique qui les rendra à l'électrique.
  if wait_burner > 0 then craft(f, book, free, burner_item, math.min(RrRt.CRAFT_CAP, wait_burner - (free[burner_item] or 0)), tick) end
  if wait_elec > 0 and have_elec < 1 then craft(f, book, free, elec_item, math.min(RrRt.CRAFT_CAP, wait_elec), tick) end
  return n_sub, n_rev
end

return RrRt
