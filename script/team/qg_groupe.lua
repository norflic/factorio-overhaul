--[[
  Lot QG-GROUPE2, côté RUNTIME (règle pure : shared/team/qg_groupe.lua). Votre équipe seulement (f.is_player) ; les factions gardent la règle
  d'avant. Interrupteurs : T.qg_groupe_pose_on (places), T.qg_groupe_peril_on (péril au point le plus faible).
    1. MARQUES : une pièce de votre force tuée par une force non-équipe (biters) à moins de G.MARK_R tuiles du coffre marque le côté du TUEUR
       (sa position, sinon celle de la pièce) ; f.team.qgg (nombres et listes simples : la sauvegarde ; jamais lu ni écrit à on_load).
    2. POSE : QgG.line (tourelles offertes au départ, Team.place_hq_turrets) et le crochet Outposts.hq_slots (reconstruction et péril :
       Outposts.fortify -> pose_order) rendent les places des LIGNES (G.slots) ; une tourelle déjà posée ne bouge jamais (aucun téléport) :
       seules les places libres (G.free) sont rendues. Côté : marques ; sans marque, côtés retenus avant ; au départ, nids connus (G.prior).
    3. APPUI (QgG.facing) : PV armés au point le plus faible, lus par script/team/survie_qg.lua (Sq.peril, champ facing).
  Journal [FO-QG-GROUPE] (pose de départ, places de reconstruction).
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
QgG.SITE_R = 48   -- tuiles : tourelles lues pour l'appui (Prev.SITE_R.qg, script/ai3/prevision.lua : le même recensement)
QgG.NEST_R = 320  -- tuiles : nids lus au départ pour choisir le côté de la ligne (au plus QgG.NEST_MAX, les plus proches comptent le plus)
QgG.NEST_MAX = 64

local function mine(f) return f and f.is_player and f.team and f.hq_pos and true or false end

local function state(f)
  f.team.qgg = f.team.qgg or { marks = {}, sides = {}, logs = 0 }
  return f.team.qgg
end

local function say(st, fmt, ...)
  if st.logs >= QgG.LOGS then return end
  st.logs = st.logs + 1
  log("[FO-QG-GROUPE] " .. string.format(fmt, ...))
end

local function names(sides)
  local out = {}
  for _, s in ipairs(sides) do out[#out + 1] = G.NAMES[s] end
  return table.concat(out, "+")
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
  if not (mine(f) and T.qg_groupe_pose_on and not f.eliminated) then return end
  local ep = ent.position
  local dx, dy = ep.x - f.hq_pos.x, ep.y - f.hq_pos.y
  if dx * dx + dy * dy > G.MARK_R * G.MARK_R then return end
  local cause = e.cause and e.cause.valid and e.cause or nil
  local p = cause and cause.position or ep
  G.note(state(f).marks, e.tick, p.x - f.hq_pos.x, p.y - f.hq_pos.y, TURRET_TYPE[ent.type] and G.W_TURRET or G.W_OTHER)
end
Events.on(defines.events.on_entity_died, on_died)

--- Tourelles du groupe « hq » valides, triées par numéro d'unité.
local function hq_turrets(f)
  local _, by_key = Outposts.turret_groups(f)
  local g = by_key and by_key["hq"]
  local list = {}
  for _, t in ipairs(g and g.list or {}) do if t.valid then list[#list + 1] = t end end
  table.sort(list, function(a, b) return a.unit_number < b.unit_number end)
  return list
end

local function gap() return Pose.gap(Outposts.turret_range()) end

--- 2a. Tourelles offertes au départ (Team.place_hq_turrets) : décalages { {dx, dy} } en ligne, ou nil (autre équipe, interrupteur, portée
--- inconnue). Côté : les nids à QgG.NEST_R tuiles (les plus proches pèsent le plus) ; sans nid, G.DEFAULT_SIDE.
function QgG.line(f, surface, center, n)
  if not (f and f.is_player and f.team and T.qg_groupe_pose_on and Outposts.turret_range() > 0) then return nil end
  local st = state(f)
  local found = surface.find_entities_filtered({ position = center, radius = QgG.NEST_R, force = "enemy", type = "unit-spawner" })
  table.sort(found, function(a, b) return (a.unit_number or 0) < (b.unit_number or 0) end)
  local pts = {}
  for i, e in ipairs(found) do
    if i > QgG.NEST_MAX then break end
    pts[#pts + 1] = { dx = e.position.x - center.x, dy = e.position.y - center.y }
  end
  local prior = G.prior(pts)
  st.sides = G.choose_sides(prior, 2, nil)
  local out = {}
  for _, s in ipairs(G.slots(n, st.sides, gap())) do out[#out + 1] = { s.dx, s.dy } end
  say(st, "player : depart, %d tourelle(s) du QG en ligne cote %s (%d nid(s) a %d tuiles%s), ecart %d", n, names(st.sides), #found,
    QgG.NEST_R, #found == 0 and " : cote par defaut" or "", gap())
  return out
end

--- 2b. Crochet de la reconstruction et du péril (Outposts.fortify, pose_order) : places libres des lignes, ou nil (règle d'avant).
Outposts.hq_slots = function(f, surface, count)
  if not (mine(f) and T.qg_groupe_pose_on and Outposts.turret_range() > 0) then return nil end
  local st = state(f)
  local tick = game.tick
  local before = names(st.sides)
  st.sides = G.choose_sides(G.rank(st.marks, tick), 2, st.sides)
  local list = hq_turrets(f)
  local pts, abs = {}, {}
  for _, t in ipairs(list) do pts[#pts + 1] = { x = t.position.x, y = t.position.y } end
  for _, s in ipairs(G.slots(#list + count, st.sides, gap())) do abs[#abs + 1] = { x = f.hq_pos.x + s.dx, y = f.hq_pos.y + s.dy } end
  local out = G.free(abs, pts)
  say(st, "player : reconstruction du QG a %.1f min, cote %s%s : %d place(s) libre(s) pour %d tourelle(s) (%d deja au QG, aucune deplacee)",
    tick / 3600, names(st.sides), before ~= names(st.sides) and (" (avant " .. (before ~= "" and before or "aucun") .. ")") or "", #out, count, #list)
  return out
end

--- Appui des tourelles de la force à QgG.SITE_R tuiles du coffre : weakest, total (‰), points d'entrée (tourelles qui couvrent le coffre).
local function support_of(f, surface)
  local list = {}
  local range = Outposts.turret_range()
  local found = surface.find_entities_filtered({ position = f.hq_pos, radius = QgG.SITE_R, force = f.force, type = Rg.TURRET_TYPES })
  table.sort(found, function(a, b) return (a.unit_number or 0) < (b.unit_number or 0) end)
  for _, e in ipairs(found) do
    if e.valid then
      local inv = e.get_inventory(defines.inventory.turret_ammo)
      local have = inv and inv.get_item_count() or nil
      list[#list + 1] = { x = e.position.x, y = e.position.y, s = have and Sq.armed_share(have, T.turret_ammo_low) or 1000,
        p = G.covers(e.position.x, e.position.y, f.hq_pos.x, f.hq_pos.y, range) }
    end
  end
  local w, t, _, entries = G.support(list, range, f.hq_pos.x, f.hq_pos.y)
  return w, t, entries
end

--- 3. PV armés au point le plus faible et tourelles du groupe « hq », ou nil, nil (autre équipe, interrupteur, pas de coffre).
function QgG.facing(f, value)
  if not (mine(f) and T.qg_groupe_peril_on and f.hq and f.hq.valid) then return nil, nil end
  local w, t, entries = support_of(f, f.hq.surface)
  local st = state(f)
  st.weakest, st.total, st.entries = w, t, entries
  return G.facing(value, w, t), #hq_turrets(f)
end

--- Texte de journal : « appui w sur t, e point(s) d'entree » (dernier calcul), ou « - ».
function QgG.support_text(f)
  local st = f and f.team and f.team.qgg
  if not (st and st.total) then return "-" end
  return string.format("%d sur %d, %d point(s) d'entree", st.weakest or 0, st.total or 0, st.entries or 0)
end

return QgG
