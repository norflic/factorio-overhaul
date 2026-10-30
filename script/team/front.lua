--[[
  Lot DEFENSE-FRONT, côté RUNTIME : la défense suit le front (shared/team/front.lua pour la règle). Trois services :
    - l'événement on_entity_died note, par équipe, OÙ ses pièces tombent sous des ennemis (mémoire sur grille de 16 tuiles, décroissance
      lente à pas fixe) ; une pièce tuée par une force non ennemie ou sans tueur n'est pas notée ;
    - Front.view(f, fortify_open) : la vue du front pour le planificateur permanent (cellule à renforcer, nombre de tourelles, emplacements) ;
      nil sans QG ;
    - Front.place(f, surface, task, carrier) : pose, depuis l'inventaire du PNJ, les tourelles de la tâche « fortify » du poste « front »
      aux emplacements de la règle ; le coût vient du stock (tâche à objets stricts, comme la garde de la centrale).
  Les tourelles posées appartiennent au poste « front<cellule> » (State.own ; groupe de ravitaillement « ofront<cellule> » de
  Outposts.turret_groups : une cellule, un groupe, donc le ravitaillement va au bon endroit). Une tourelle détruite fait baisser le compte de
  sa cellule : elle est refaite par le même mécanisme (« reconstruire les tourelles »).
  État : f.front_mem (tables simples : nombres et chaînes, dans la sauvegarde ; jamais lu ni écrit à on_load). Aucun temps mesuré.
]]
local Events = require("script.core.events")
local State = require("script.faction.state")
local R = require("shared.ai3.reglages")
local T = require("shared.team.config")
local Fr = require("shared.team.front")
local Pose = require("shared.team.pose_tourelles")
local Outposts = require("script.faction.outposts")
local Sec = require("shared.team.site_securise") -- lot INTEG-ECONOMIE (D5) : sites proches bloqués à couvrir
local Rr = require("shared.team.rebuild_rapide") -- lot REBUILD-RAPIDE (c) : cellule réattaquée chez une équipe riche
local Stock = require("script.team.stock")

local Front = {}

Front.LOGS = 60

local LAB_TYPES, ASSET_TYPES
local function types()
  if LAB_TYPES then return end
  LAB_TYPES, ASSET_TYPES = {}, {}
  for _, ty in ipairs(R.ENTITY_TYPES) do
    local role = R.ENTITY_ROLE[ty]
    if role == "labo" then LAB_TYPES[#LAB_TYPES + 1] = ty end
    if Pose.role_factor(role) > 0 then ASSET_TYPES[#ASSET_TYPES + 1] = ty end
  end
end

local function team_of(force_name)
  if force_name == "player" then return State.faction("player") end
  return State.by_force(force_name)
end

local function state(f, tick)
  local st = f.front_mem
  if not st then
    st = { mem = Fr.new(tick), rest = {}, chk = {}, chk_tick = tick, cover = {}, cover_tick = -Fr.COVER_EVERY, poses = 0, logs = 0 }
    f.front_mem = st
  end
  return st
end

local function oid_of(key) return "front" .. key end

--- Pièce de l'équipe détruite par un ennemi : la cellule reçoit son poids.
local function on_died(e)
  local ent = e.entity
  if not (ent and ent.valid and ent.force) then return end
  local role = R.ENTITY_ROLE[ent.type]
  if not role or role == "main" then return end
  local killer = e.force
  if not (killer and killer.name ~= ent.force.name and not ent.force.get_cease_fire(killer)) then return end
  local f = team_of(ent.force.name)
  if not (f and not f.eliminated and f.hq and f.hq.valid) then return end
  -- Lot INTEG-DEFENSE 6 : la force « player » est aussi celle de VOS bâtiments : pour l'équipe du joueur, seule une pièce enregistrée à elle
  -- (State.own : tourelles, foreuses, fours, QG, pièces refaites) ou adoptée compte ; une pièce posée à la main loin du QG, détruite, ne
  -- fait plus partir un PNJ y poser des tourelles. (Compromis : les murs, tapis et poteaux du plan, non enregistrés, ne comptent plus
  -- non plus ; les factions, dont la force ne porte que leurs pièces, gardent tout.)
  if f.is_player then
    local u = ent.unit_number
    local o = u and State.owner(u)
    if not ((o and o.f == f.id) or (u and f.adopt and f.adopt.units and f.adopt.units[u])) then return end
  end
  local st = state(f, e.tick)
  Fr.decay(st.mem, e.tick) -- la mémoire est à jour avant d'y ajouter : l'ancien poids décroît, le nouveau non
  local pos = ent.position
  local key = Fr.record(st.mem, pos.x, pos.y, Fr.weight(role))
  Rr.wave_note(st, key, e.tick) -- lot REBUILD-RAPIDE (c) : vagues distinctes par cellule (une mort après 30 s de calme en ouvre une nouvelle)
  -- Lot RECO-DIRECTION : la même attaque donne une DIRECTION (script/ai3/reco.lua : crochet posé au chargement, nil sans ce module).
  if Front.on_hit then Front.on_hit(f, ent, e, Fr.weight(role)) end
end
Events.on(defines.events.on_entity_died, on_died)

--- Tourelles de l'équipe { x, y } et nombre de celles du front.
local function turrets_of(f)
  local list, placed = {}, 0
  for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
    local t = f.turrets[id]
    if t.valid then
      list[#list + 1] = { x = t.position.x, y = t.position.y }
      local o = State.owner(id)
      if o and type(o.oid) == "string" and o.oid:sub(1, 5) == "front" then placed = placed + 1 end
    end
  end
  return list, placed
end

--- Laboratoires de l'équipe (bâtiments d'amélioration), regroupés par cellule, relevés toutes les Fr.COVER_EVERY ticks.
local function refresh_cover(f, st, surface, tick)
  if tick - st.cover_tick < Fr.COVER_EVERY then return end
  st.cover_tick = tick
  types()
  local pos = {}
  for _, e in ipairs(surface.find_entities_filtered({ force = f.force, type = LAB_TYPES })) do
    if e.valid then pos[#pos + 1] = { x = e.position.x, y = e.position.y } end
  end
  table.sort(pos, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
  st.cover = Fr.cover_clusters(pos)
end

local function range_near()
  local proto = game.entity_prototypes[T.turret]
  local r = proto and proto.turret_range
  if r and r > 0 then return math.min(Fr.NEAR, math.floor(r * 0.8)) end
  return nil
end

function Front.view(f, fortify_open)
  local surface = f.hq and f.hq.valid and f.hq.surface or nil
  if not surface or f.eliminated then return nil end
  local tick = game.tick
  local st = state(f, tick)
  Fr.decay(st.mem, tick)
  refresh_cover(f, st, surface, tick)
  -- Lot DEFENSE-FACTIONS D5 : Fr.SCAN cellules examinées ; la coupe à Fr.MAX_CELLS se fait dans Fr.plan, APRÈS le contrôle du moteur.
  local cells = Fr.top(st.mem, Fr.SCAN)
  -- Lot REBUILD-RAPIDE (c) (retour du DC du 29/10 : « ils se font réattaquer au même endroit […] pas de nouvelles tourelles […] ils ont 8000 de
  -- fer ») : chez une équipe riche (fer >= Rr.RICH_IRON × le plancher de la défense, cuivre au plancher), une cellule attaquée par au moins
  -- Rr.WAVES vagues veut Rr.RICH_EXTRA tourelle(s) de plus et reçoit tout son manque d'un coup (plus bas, après Fr.plan).
  Rr.wave_prune(st, tick)
  local rich = Rr.rich(Stock.count(f, T.outposts.iron.product), Stock.count(f, T.outposts.copper.product), T.defend_iron_floor, T.defend_copper_floor)
  local boosted
  cells, boosted = Rr.boost(cells, st.waves, rich, tick, Fr.want, Fr.BASE, Fr.PER_TURRET)
  -- Lot INTEG-ECONOMIE (D5) : le site proche BLOQUÉ (signal f.site_blocked de script/faction/sites.lua) est un lieu à couvrir, comme un
  -- groupe de laboratoires (règle pure : shared/team/site_securise.lua) ; vide pour votre équipe (le signal est propre aux factions).
  local cover = st.cover
  local sites = Sec.covers(f.site_blocked, tick)
  if #sites > 0 then
    cover = {}
    for _, c in ipairs(st.cover) do cover[#cover + 1] = c end
    for _, c in ipairs(sites) do cover[#cover + 1] = c end
  end
  if #cells == 0 and #cover == 0 then
    st.rows = nil
    return { busy = fortify_open and fortify_open["front"] or false }
  end
  if tick - st.chk_tick > 3600 then st.chk, st.chk_tick = {}, tick end
  local rest = {}
  for _, key in ipairs(State.sorted_keys(st.rest)) do
    if st.rest[key] > tick then rest[key] = true else st.rest[key] = nil end
  end
  types()
  local function allow(row)
    local c = st.chk[row.key]
    if c and tick - c.t < Fr.CHECK_EVERY then return c.ok end
    local pos = { x = row.x, y = row.y }
    local ok = true
    if row.kind == "attaque" then
      ok = surface.count_entities_filtered({ position = pos, radius = Fr.ASSET_R, force = f.force, type = ASSET_TYPES, limit = 1 }) > 0
    end
    if ok then ok = surface.find_nearest_enemy({ position = pos, max_distance = Fr.CALM_R, force = f.force }) == nil end
    st.chk[row.key] = { t = tick, ok = ok }
    return ok
  end
  local turrets, placed = turrets_of(f)
  -- Lot REBUILD-RAPIDE (c) : une équipe riche a Rr.RICH_CAP places de plus sous le plafond d'équipe du front (Rr.cap_placed).
  local plan = Fr.plan({ cells = cells, cover = cover, turrets = turrets, placed = Rr.cap_placed(placed, rich), near = range_near(), rest = rest,
    allow = allow, hq = f.hq_pos })
  local pick = plan.pick
  if pick and pick.kind == "attaque" and boosted[pick.key] then
    local n = Rr.rich_count(pick.want, pick.have, plan.left)
    if n > pick.count then
      pick.count = n
      local w = st.waves and st.waves[pick.key]
      local sig = pick.key .. ":" .. (w and w.n or 0) .. ":" .. pick.have
      if st.rr_sig ~= sig and (st.rr_logs or 0) < Front.LOGS then
        st.rr_sig, st.rr_logs = sig, (st.rr_logs or 0) + 1
        log(string.format("[FO-REBUILD-RAPIDE] %s : cellule %s reattaquee (%d vagues) chez une equipe riche (fer %d) : %d tourelle(s) posee(s) d'un coup " ..
          "(%d a portee, %d voulues, regle du front +%d ; front de l'equipe %d sur %d au plus) a %.1f min", f.key or "player", pick.key,
          w and w.n or 0, Stock.count(f, T.outposts.iron.product), n, pick.have, pick.want, Rr.RICH_EXTRA, placed, Fr.TEAM_CAP + Rr.RICH_CAP,
          tick / 3600))
      end
    end
  end
  -- Lot DEFENSE-FACTIONS D1 : les lignes du plan (cause de chaque cellule non servie), lues par script/team/defense_log.lua ; nombres et chaînes.
  st.rows, st.rows_tick, st.placed = plan.rows, tick, placed
  if pick and st.logs < Front.LOGS and st.last_pick ~= pick.key .. ":" .. pick.have then
    st.last_pick = pick.key .. ":" .. pick.have
    st.logs = st.logs + 1
    log(string.format("[FO-FRONT] %s : cellule %s (%s) en (%.0f, %.0f) a %.1f min : %d tourelle(s) a portee sur %d voulue(s), %d a poser ; front de l'equipe %d sur %d au plus",
      f.key or "player", pick.key, pick.kind, pick.x, pick.y, tick / 3600, pick.have, pick.want, pick.count, placed, Fr.TEAM_CAP))
  end
  return { pick = pick, busy = fortify_open and fortify_open["front"] or false }
end

--- Lot DEFENSE-FACTIONS D3 : tourelles voulues au QG d'une FACTION (votre équipe garde sa règle : T.defend_hq). `peak` : le plus grand nombre de
--- tourelles du QG déjà vu (f.team.hq_peak, créé ici à la première pensée d'après le départ) ; `f.hq_lethal_tick` : dernière occupation du QG
--- par les biters (script/team/worker.lua). Aucune tourelle voulue tant que le QG n'a perdu aucune tourelle ET n'a pas été attaqué.
function Front.hq_post(f, hq_turrets, tick)
  local team = f.team
  if not team then return 0 end
  if hq_turrets > (team.hq_peak or 0) then team.hq_peak = hq_turrets end
  local ago = f.hq_lethal_tick and tick - f.hq_lethal_tick or nil
  return Fr.hq_post({ turrets = hq_turrets, peak = team.hq_peak or 0, ago = ago })
end

--- Pose des tourelles de la tâche (emplacements de la règle, refus au-delà de Fr.ACCEPT tuiles du centre).
function Front.place(f, surface, task, carrier)
  local c = task.pos
  local key = task.cell_key
  if not (c and key) then return 0 end
  local n = Outposts.fortify_at(f, surface, oid_of(key), task.sites or {}, task.items[1][2], carrier,
    function(pos) return Fr.accepts(c.x, c.y, pos.x, pos.y) end)
  local tick = game.tick
  local st = state(f, tick)
  st.poses = st.poses + n
  -- une pose à zéro (emplacements bloqués, plus de tourelle au porteur) met la cellule au repos : elle ne monopolise pas la tâche
  st.rest[key] = n == 0 and tick + Fr.REST or nil
  if st.logs < Front.LOGS then
    st.logs = st.logs + 1
    log(string.format("[FO-FRONT] %s : pose de %d tourelle(s) sur %d demandee(s) a la cellule %s a %.1f min (cumul %d)",
      f.key or "player", n, task.items[1][2], key, tick / 3600, st.poses))
  end
  return n
end

--- Porteur tué en allant renforcer la cellule : elle se repose comme un avant-poste meurtrier (T.lethal_ticks).
function Front.on_lost(f, key, cause)
  local tick = game.tick
  local st = state(f, tick)
  if key then st.rest[key] = tick + T.lethal_ticks end
  log(string.format("[FO-FRONT] %s : PNJ tue en allant renforcer la cellule %s (%s) a %.1f min ; cellule au repos %.1f min",
    f.key or "player", tostring(key), tostring(cause), tick / 3600, T.lethal_ticks / 3600))
end

return Front
