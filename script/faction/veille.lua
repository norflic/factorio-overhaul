--[[
  Lot VEILLE (28/10) : EXÉCUTION de la reconnaissance régulière des factions (règles pures : shared/faction/veille.lua).

  Demande du Directeur Créatif (D-24) : « elles doivent aussi faire de la reconnaissance comme un joueur ». Un VIVIER réservé : un
  soldat marqué (s.scout, script/faction/military.lua), payé en plus de l'armée et jamais compté dans la garnison. La visée des
  attaques n'est PAS touchée (la règle « ne viser que ce qu'on a reconnu » est sur la branche `recon`, parquée).

  Ce module, appelé par le commandant après le chef :
  - fabrique le vivier (Veille.think) quand l'armée de départ et les tourelles du QG sont en place, et le REMPLACE après une perte ;
  - envoie le soldat du vivier vers un secteur de la bande R ± 96 (R = 300 + 150 par trajet réussi, 1 600 au plus) jamais vu ou vu depuis
    plus de 20 min, le plus ancien d'abord (crochets de script/ai3/exploration.lua : mêmes exclusions que les éclaireurs ouvriers) ;
  - compte chaque refus par raison (f.stats.veille_refus) et publie une ligne `[FO-VEILLE]` toutes les 10 min par faction ;
  - enveloppe les crochets Military.on_scout_done / on_scout_lost (posés par script/faction/vision.lua pour les éclaireurs du joueur)
    pour les éclaireurs de tag « veille » ; les autres vont à Vision, inchangés.

  Crochets posés ailleurs : Veille.fog_on, known, pick_goal, watch, mark_bad, note_nopath (script/ai3/exploration.lua) et
  Veille.pay_kit (script/faction/commander.lua : l'équipe seule connaît le stock libre).
]]

local V = require("shared.faction.veille")
local F = require("shared.faction.config")
local T = require("shared.team.config")
local Planner = require("shared.team.planner")
local State = require("script.faction.state")
local Military = require("script.faction.military")
local Character = require("script.faction.character")
local Outposts = require("script.faction.outposts")

local Veille = {}

Veille.TAG = "veille"
local GEN_TRIES = 4        -- demandes de génération du but avant de l'écarter
local GEN_WAIT = 180       -- attente entre deux contrôles de génération (3 s)
local NO_DEST_WAIT = 1800  -- aucun but sûr : nouvel essai dans 30 s
local BUSY_WAIT = 600      -- l'éclaireur n'a pas pu partir : nouvel essai dans 10 s
local ENEMY_NEAR = 100     -- tuiles du QG : unité ou nid ennemi => pas de départ
local REPORT_EVERY = 10 * 3600

-- Crochets posés ailleurs.
Veille.fog_on = function() return true end
Veille.known = nil
Veille.pick_goal = nil
Veille.watch = nil
Veille.mark_bad = nil
Veille.note_nopath = nil
Veille.pay_kit = nil

local function state_of(f)
  if not f.veille then
    f.veille = { next_at = 0, next_train = 0, trips = 0, losses = 0, last_oct = -1, sent = 0, lost = 0, arrived = 0, trained = 0,
      gen_tries = 0, refus = {}, last_report = 0, quiet_until = 0 }
  end
  return f.veille
end

local function refuse(vs, reason)
  vs.refus[reason] = (vs.refus[reason] or 0) + 1
end

--- Tourelles du QG complètes (T.defend_hq, la défense du début de shared/team) ?
local function hq_defended(f)
  for _, g in ipairs(Outposts.turret_groups(f)) do
    if g.key == "hq" then return #g.list >= T.defend_hq end
  end
  return false
end

local function enemies_near_hq(surface, f)
  return surface.count_entities_filtered({ position = f.hq_pos, radius = ENEMY_NEAR, force = "enemy", type = { "unit", "unit-spawner" },
    limit = 1 }) > 0
end

local function scout_busy(f)
  if f.scout_pending then return true end
  for _, gid in ipairs(State.sorted_keys(f.groups or {})) do
    if f.groups[gid].state == "scout" then return true end
  end
  return false
end

local function chunk_ready(surface, p)
  return surface.is_chunk_generated({ x = math.floor(p.x / 32), y = math.floor(p.y / 32) })
end

--- Un éclaireur du vivier vient d'être fabriqué (`how` : "fournee" de l'armée ou "stock" payé directement).
function Veille.vivier_made(f, tick, how)
  local vs = state_of(f)
  local ch = Character.of(f)
  vs.trained = vs.trained + 1
  vs.want_vivier, vs.want_since = false, nil
  vs.next_train = tick + V.interval(ch.traits and ch.traits.curiosite, (f.chef and f.chef.last_threat) or 0, vs.losses)
  f.stats.veille_vivier = (f.stats.veille_vivier or 0) + 1
  log(string.format("[FO-VEILLE] vivier tick %d %s : eclaireur fabrique (%s), soldats %d", tick, f.key, how, f.soldiers_count or 0))
end

--- Une mort de soldat de la faction (appelée par le commandant) : aucun départ pendant V.QUIET.
function Veille.on_soldier_died(f, tick, unit_number)
  local s = unit_number and f.soldiers and f.soldiers[unit_number]
  if s and s.scout then return end -- la mort d'un éclaireur loin du QG n'est pas une menace sur la garnison
  local vs = state_of(f)
  vs.quiet_until = tick + V.QUIET
end

---------------------------------------------------------------------------------------------------
-- Pensée
---------------------------------------------------------------------------------------------------
function Veille.think(f, surface, tick)
  if not Veille.fog_on() then return end
  local st = f.chef
  if not st or not f.hq_pos then return end
  local vs = state_of(f)
  local ch = Character.of(f)
  local curiosity = ch.traits and ch.traits.curiosite
  local threat = st.last_threat or 0
  local alert = tick < (f.threatened_until or 0)
  local hq_ok = hq_defended(f)
  local ready, alive = Military.scouts_ready(f)

  -- 1. Le vivier : fabriqué quand l'armée de départ (hors vivier) et les tourelles du QG sont en place, remplacé après une perte.
  local unit = Planner.best_unit(f.tech or 0)
  local kit = unit and T.kits[unit]
  local due, why = V.train_due({ have = alive, soldiers = f.soldiers_count or 0, tick = tick, next_train = vs.next_train, hq_ok = hq_ok,
    stock_ok = true, survive = st.survival, alert = alert, threat = threat })
  if due then
    -- Voie normale : le soldat de plus est ajouté à la prochaine fournée de l'armée (script/team/team.lua, Team.think, vs.want_vivier).
    vs.want_vivier = true
    vs.want_since = vs.want_since or tick
    -- Repli : aucune fournée en V.PLANNER_WAIT (armée à son effectif visé) : le kit est payé sur le stock LIBRE de l'équipe.
    if tick - vs.want_since >= V.PLANNER_WAIT then
      if not (kit and Veille.pay_kit and Veille.pay_kit(f, kit, tick, false)) then
        refuse(vs, "fer insuffisant")
      else
        local made = Military.train(f, surface, unit, 1, true)
        if made > 0 then Veille.vivier_made(f, tick, "stock") end
      end
    end
  else
    vs.want_vivier, vs.want_since = false, nil
    if why ~= "vivier plein" then refuse(vs, why) end
  end

  -- 2. Le départ.
  ready, alive = Military.scouts_ready(f)
  local enemies = ready > 0 and enemies_near_hq(surface, f) or false
  local go, reason = V.want({ ready = ready, busy = scout_busy(f), tick = tick, next_at = vs.next_at, threat = threat,
    survive = st.survival, alert = alert, hq_ok = hq_ok, enemies = enemies, quiet_until = vs.quiet_until })
  if not go then
    if reason ~= "pas d'eclaireur" and reason ~= "eclaireur en cours" then refuse(vs, reason) end
    return
  end
  local radius = V.radius(vs.trips)
  local goal = Veille.pick_goal and Veille.pick_goal(f, tick, radius, vs.last_oct) or nil
  if not goal then
    -- Aucun secteur à voir dans cette bande : on l'élargit pour le prochain essai (la bande est connue ou fermée).
    refuse(vs, "aucun secteur")
    vs.trips = vs.trips + 1
    vs.next_at = tick + NO_DEST_WAIT
    return
  end
  local dest = { x = goal.x, y = goal.y }
  -- Le but doit être généré (le chemin d'un soldat ne traverse pas une zone non générée) : pick_goal ne rend que des secteurs
  -- générés ; le point exact doit l'être aussi.
  if not chunk_ready(surface, dest) then
    surface.request_to_generate_chunks(dest, 3)
    vs.gen_tries = vs.gen_tries + 1
    if vs.gen_tries >= GEN_TRIES then
      vs.gen_tries = 0
      if Veille.mark_bad then Veille.mark_bad(f, dest.x, dest.y, tick, false) end
      vs.next_at = tick + NO_DEST_WAIT
    else
      vs.next_at = tick + GEN_WAIT
    end
    return
  end
  vs.gen_tries = 0
  local name = F.unit_name(f.key, F.best_soldier(f.tech))
  local q = surface.find_non_colliding_position(name, dest, 24, 2)
  if q then dest = { x = q.x, y = q.y } end
  if Military.scout(f, surface, dest, tick, Veille.TAG, 1, true) then
    vs.sent = vs.sent + 1
    vs.next_at = tick + V.interval(curiosity, threat, vs.losses)
    vs.last_oct = goal.octant
    vs.dest = { x = dest.x, y = dest.y }
    f.stats.veille_scouts = (f.stats.veille_scouts or 0) + 1
    log(string.format("[FO-VEILLE] depart tick %d %s : vers (%d, %d), octant %d, rayon %d (%d tuiles du QG), %d candidat(s), trajet %d",
      tick, f.key, math.floor(dest.x), math.floor(dest.y), goal.octant, radius, math.floor(goal.dh), goal.n or 0, vs.sent))
  else
    vs.next_at = tick + BUSY_WAIT
    refuse(vs, "pas d'eclaireur")
  end
end

--- Bilan toutes les 10 min par faction (appelé par le commandant à chaque pensée ; une ligne par période).
function Veille.report(f, tick)
  local vs = f.veille
  if not vs or tick - vs.last_report < REPORT_EVERY then return end
  vs.last_report = tick
  local keys = {}
  for r in pairs(vs.refus) do keys[#keys + 1] = r end
  table.sort(keys)
  local parts = {}
  for _, r in ipairs(keys) do parts[#parts + 1] = r:gsub(" ", "_") .. "=" .. vs.refus[r] end
  local ready, alive = Military.scouts_ready(f)
  log(string.format("[FO-VEILLE] bilan tick %d %s minute %d : partis %d, arrives %d, perdus %d, fabriques %d, vivier %d (prets %d), rayon %d, "
    .. "secteurs reconnus %s, refus {%s}", tick, f.key, math.floor(tick / 3600), vs.sent, vs.arrived, vs.lost, vs.trained, alive, ready,
    V.radius(vs.trips), tostring(Veille.known and Veille.known(f) or "?"), table.concat(parts, " ")))
end

---------------------------------------------------------------------------------------------------
-- Crochets de Military.scout : les éclaireurs du vivier sont traités ici, les autres vont à Vision
---------------------------------------------------------------------------------------------------
local installed = false

--- Appelé une fois par le commandant, APRÈS le chargement de script/faction/vision.lua (qui pose les crochets de base).
function Veille.install()
  if installed then return end
  installed = true
  local prev_done, prev_lost = Military.on_scout_done, Military.on_scout_lost
  Military.on_scout_done = function(f, g, tick, arrived)
    if g.tag ~= Veille.TAG then
      if prev_done then return prev_done(f, g, tick, arrived) end
      return
    end
    local vs = state_of(f)
    local at = g.dest
    if g.group and g.group.valid and not arrived then at = g.group.position end
    if g.nopath then
      -- Aucun chemin : la région autour du but et le cône derrière elle sont écartés (mécanisme du lot EXPLO).
      f.stats.veille_nopath = (f.stats.veille_nopath or 0) + 1
      if at and Veille.note_nopath then
        Veille.note_nopath(f, f.hq_pos.x, f.hq_pos.y, at.x, at.y, tick)
      elseif at and Veille.mark_bad then
        Veille.mark_bad(f, at.x, at.y, tick, false)
      end
      vs.next_at = tick + NO_DEST_WAIT
    else
      if at and Veille.watch then Veille.watch(f, at.x, at.y, tick) end
      if arrived then
        vs.trips = vs.trips + 1
        vs.arrived = vs.arrived + 1
        if vs.losses > 0 then vs.losses = vs.losses - 1 end
      end
    end
    log(string.format("[FO-VEILLE] fin tick %d %s : %s (%d, %d), rayon suivant %d", tick, f.key,
      g.nopath and "sans itineraire" or (arrived and "arrive" or "arrete"), math.floor(at and at.x or 0), math.floor(at and at.y or 0),
      V.radius(vs.trips)))
  end
  Military.on_scout_lost = function(f, g, tick, alive)
    if g.tag ~= Veille.TAG then
      if prev_lost then return prev_lost(f, g, tick, alive) end
      return
    end
    local vs = state_of(f)
    -- Groupe vidé sans mort (le moteur retire des membres, F174) : l'éclaireur est rentré à pied, ce n'est pas une perte.
    if alive >= (g.size or 1) then
      log(string.format("[FO-VEILLE] fin tick %d %s : groupe vide, eclaireur vivant (F174)", tick, f.key))
      return
    end
    vs.lost = vs.lost + 1
    vs.losses = math.min(vs.losses + 1, V.LOSS_CAP)
    if g.dest and Veille.mark_bad then Veille.mark_bad(f, g.dest.x, g.dest.y, tick, true) end
    local ch = Character.of(f)
    local interval = V.interval(ch.traits and ch.traits.curiosite, (f.chef and f.chef.last_threat) or 0, vs.losses)
    vs.next_at = math.max(vs.next_at or 0, tick + interval)
    vs.next_train = math.max(vs.next_train or 0, tick + interval)
    log(string.format("[FO-VEILLE] perdu tick %d %s : eclaireur du vivier, delai %d min (x2^%d)", tick, f.key, math.floor(interval / 3600),
      vs.losses))
  end
end

return Veille
