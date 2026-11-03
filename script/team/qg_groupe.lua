--[[
  Lot QGGROUPE, côté RUNTIME (règle pure : shared/team/qg_groupe.lua). Votre équipe seulement (f.is_player), deux interrupteurs
  (T.qg_groupe_peril_on, T.qg_groupe_pose_on). Trois services :
    1. MARQUES : une pièce de votre force tuée par une force non-équipe (biters) à moins de G.MARK_R tuiles du coffre marque le côté du
       TUEUR (sa position, sinon celle de la pièce) ; f.team.qgg.marks (nombres, la sauvegarde ; jamais lu ni écrit à on_load).
    2. APPUI (QgG.facing) : valeur armée du QG au point le plus faible, lue par script/team/survie_qg.lua à la place de la somme.
    3. REGROUPEMENT (QgG.think, à chaque pensée de l'équipe ; G.due : au plus toutes les G.PERIOD ticks, en calme) : les tourelles du QG
       (groupe « hq ») vont aux places des groupes (G.slots) par téléport sur place libre ; AUCUNE tourelle posée ni retirée. Crochet
       Outposts.hq_slots : la reconstruction du QG (Outposts.fortify) pose aux places des groupes restées vides.
  Journal [FO-QG-GROUPE] : regroupement (côtés, tourelles déplacées, appui avant/après), reconstruction aux places des groupes.
  Déterminisme : listes triées par numéro d'unité, aucune horloge mesurée, aucun hasard.
]]
local Events = require("script.core.events")
local State = require("script.faction.state")
local Outposts = require("script.faction.outposts")
local Rg = require("shared.ai3.reglages")
local Pose = require("shared.team.pose_tourelles")
local Sq = require("shared.team.survie_qg")
local T = require("shared.team.config")
local G = require("shared.team.qg_groupe")

local QgG = {}
QgG.LOGS = 60
QgG.SITE_R = 48 -- tuiles : tourelles du QG lues pour l'appui (Prev.SITE_R.qg, script/ai3/prevision.lua)

local function on(f) return f and f.is_player and f.team and f.hq_pos and T.qg_groupe_pose_on end

local function state(f)
  f.team.qgg = f.team.qgg or { marks = {}, sides = {}, logs = 0, moves = 0 }
  return f.team.qgg
end

local function say(st, fmt, ...)
  if st.logs >= QgG.LOGS then return end
  st.logs = st.logs + 1
  log("[FO-QG-GROUPE] " .. string.format(fmt, ...))
end

local TURRET_TYPE = {}
for _, ty in ipairs(Rg.TURRET_TYPES) do TURRET_TYPE[ty] = true end

--- 1. Marques des pertes près du coffre.
local function on_died(e)
  local ent = e.entity
  if not (ent and ent.valid and ent.force and ent.force.name == "player") then return end
  local killer = e.force
  if not killer or killer.name == "player" or State.by_force(killer.name) then return end
  local f = State.faction("player")
  if not (on(f) and not f.eliminated) then return end
  local ep = ent.position
  local dx, dy = ep.x - f.hq_pos.x, ep.y - f.hq_pos.y
  if dx * dx + dy * dy > G.MARK_R * G.MARK_R then return end
  local cause = e.cause and e.cause.valid and e.cause or nil
  local p = cause and cause.position or ep
  local w = TURRET_TYPE[ent.type] and G.W_TURRET or G.W_OTHER
  G.note(state(f).marks, e.tick, p.x - f.hq_pos.x, p.y - f.hq_pos.y, w)
end
Events.on(defines.events.on_entity_died, on_died)

--- Tourelles du QG (groupe « hq ») valides, triées par numéro d'unité.
local function hq_turrets(f)
  local _, by_key = Outposts.turret_groups(f)
  local g = by_key and by_key["hq"]
  local list = {}
  for _, t in ipairs(g and g.list or {}) do if t.valid then list[#list + 1] = t end end
  table.sort(list, function(a, b) return a.unit_number < b.unit_number end)
  return list
end

--- Appui des tourelles de la force à QgG.SITE_R tuiles du coffre : weakest, total (‰), nombre.
local function support_of(f, surface)
  local list = {}
  local found = surface.find_entities_filtered({ position = f.hq_pos, radius = QgG.SITE_R, force = f.force, type = Rg.TURRET_TYPES })
  table.sort(found, function(a, b) return (a.unit_number or 0) < (b.unit_number or 0) end)
  for _, e in ipairs(found) do
    if e.valid then
      local inv = e.get_inventory(defines.inventory.turret_ammo)
      local have = inv and inv.get_item_count() or nil
      list[#list + 1] = { x = e.position.x, y = e.position.y, s = have and Sq.armed_share(have, T.turret_ammo_low) or 1000 }
    end
  end
  local w, t = G.support(list, Outposts.turret_range(), f.hq_pos.x, f.hq_pos.y)
  return w, t, #list
end

--- 2. Valeur armée du QG face à une vague (au point le plus faible), ou nil (interrupteur, pas votre équipe, pas de coffre).
function QgG.facing(f, value)
  if not (f and f.is_player and f.team and T.qg_groupe_peril_on and f.hq and f.hq.valid and f.hq_pos) then return nil end
  local w, t = support_of(f, f.hq.surface)
  local st = state(f)
  st.weakest, st.total = w, t
  return G.facing(value, w, t)
end

--- Places absolues des groupes pour n tourelles (côtés retenus), ou nil sans côté.
local function targets(f, st, n)
  if #st.sides == 0 then return nil end
  local out = {}
  for _, s in ipairs(G.slots(n, st.sides, Pose.gap(Outposts.turret_range()))) do
    out[#out + 1] = { x = f.hq_pos.x + s.dx, y = f.hq_pos.y + s.dy }
  end
  return out
end

--- 3. Regroupement (pensée de l'équipe).
function QgG.think(f, tick)
  if not (on(f) and f.hq and f.hq.valid) then return end
  local st = state(f)
  local surface = f.hq.surface
  local calm = surface.count_entities_filtered({ position = f.hq_pos, radius = G.MARK_R, force = "enemy", type = "unit", limit = 1 }) == 0
  local ranked = G.rank(st.marks, tick)
  local sides = G.choose_sides(ranked, 2, st.sides)
  if not G.due({ on = true, calm = calm, tick = tick, last = st.last, sides = #sides }) then return end
  st.last = tick
  local same = #sides == #st.sides
  for i = 1, #sides do if sides[i] ~= st.sides[i] then same = false end end
  st.sides = sides
  local list = hq_turrets(f)
  local tg = targets(f, st, #list)
  if not tg or #list == 0 then return end
  local pts = {}
  for _, t in ipairs(list) do pts[#pts + 1] = { x = t.position.x, y = t.position.y, id = t.unit_number } end
  local moves = G.assign(pts, tg)
  if #moves == 0 then return end
  local w0 = support_of(f, surface)
  local moved = 0
  for _, m in ipairs(moves) do
    local t = list[m.i]
    local pos = surface.find_non_colliding_position(T.turret, { x = m.x, y = m.y }, 3, 1)
    local reserved = pos ~= nil and Outposts.reserved ~= nil and Outposts.reserved(f, T.turret, pos)
    if pos and not reserved and t.valid and t.teleport(pos) then moved = moved + 1 end
  end
  st.moves = st.moves + moved
  local w1, t1, n1 = support_of(f, surface)
  local names = {}
  for _, s in ipairs(sides) do names[#names + 1] = G.NAMES[s] end
  local wr = {}
  for _, r in ipairs(ranked) do wr[#wr + 1] = G.NAMES[r.side] .. "=" .. r.w end
  say(st, "player : regroupement a %.1f min, cotes %s (marques %s)%s : %d tourelle(s) du QG deplacee(s) sur %d a deplacer (%d au QG, aucune posee) ; appui au point le plus faible %d -> %d sur %d (%d tourelle(s) a %d tuiles)",
    tick / 3600, table.concat(names, "+"), table.concat(wr, " "), same and "" or " (nouveaux)", moved, #moves, #list,
    w0, w1, t1, n1, QgG.SITE_R)
end

--- Crochet de la reconstruction du QG (Outposts.fortify, pose_order) : places des groupes restées vides, ou nil (règle d'avant).
Outposts.hq_slots = function(f, surface, count)
  if not on(f) then return nil end
  local st = state(f)
  local list = hq_turrets(f)
  local tg = targets(f, st, #list + count)
  if not tg then return nil end
  local out = {}
  for _, p in ipairs(tg) do
    local free = true
    for _, t in ipairs(list) do
      local dx, dy = t.position.x - p.x, t.position.y - p.y
      if dx * dx + dy * dy <= G.MOVE_MIN * G.MOVE_MIN then free = false end
    end
    if free then out[#out + 1] = { x = p.x, y = p.y } end
  end
  say(st, "player : reconstruction du QG a %.1f min aux places des groupes : %d place(s) vide(s) pour %d tourelle(s)", game.tick / 3600, #out, count)
  return out
end

return QgG
