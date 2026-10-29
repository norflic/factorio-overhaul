--[[
  Lot PD-REPARATION (D79) : réparation des bâtiments ENDOMMAGÉS de toutes les équipes (laboratoires, fours, assembleurs,
  foreuses, centrale des factions, murs, logistique). Règles pures : shared/team/reparation.lua (Rp).

  Chaîne (journal [FO-REPARE], une ligne par étape) :
    1. RELEVÉ : on_entity_damaged, FILTRÉ AU MOTEUR par type (Rp.filter_types, script.set_event_filter à on_init et on_load :
       les unités ennemies touchées par les tourelles n'appellent pas le script). O(1) par coup : la classe, l'équipe, le
       rapport de santé, une entrée de f.repare.ents. Une entité qui meurt du coup (final_health 0) est laissée à la
       reconstruction.
    2. PENSÉE (Rep.think, appelée par Team.think toutes les 5 s, juste après Recon.repair_think) : une tâche « repair » de ce
       lot à la fois par équipe ; lot choisi par Rp.pick (importance, puis la plus abîmée ; pas sous attaque locale) ; les
       pièces du lot sont relues au moteur (au plus Rp.BATCH_MAX lectures, détruites ou déjà réparées retirées) ; unités
       ennemies à moins de Recon.SAFE_RADIUS de la pièce : report (attaque locale).
    3. EXÉCUTION : la tâche a le kind « repair » des lots RECONSTRUIRE et COMPAGNONS-ACTIFS : même programme
       (Recon.repair_program) et même acte (Recon.repair_act : santé remise au maximum, GRATUIT, Q12) ; rien n'est dupliqué.
    4. FIN : la tâche prise a quitté le tableau : ses pièces sont relues, réparées comptées, journal.

  ATTENTION (bus d'événements) : le filtre de on_entity_damaged vaut pour TOUT le mod. Un autre module qui s'abonne à cet
  événement ne recevra que ces types : élargir Rp.filter_types (ou retirer le filtre) dans ce cas.
  État : f.repare (créé à la première note, en événement), dans la table de l'équipe (global par storage.lua). Une sauvegarde
  0.6.18 n'a pas ce champ : il naît au premier coup reçu.
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local Board = require("script.team.board")
local Recon = require("script.team.reconstruction")
local Rp = require("shared.team.reparation")

local Rep = {}

local function team_of(force_name)
  if force_name == "player" then return State.faction("player") end
  return State.by_force(force_name)
end

local function key_of(f) return tostring(f.key or (f.is_player and "player") or f.id) end

local function minutes(f, tick) return (tick - (f.started or 0)) / 3600 end

-- Classe par type, calculée une fois au chargement du fichier (même valeur sur tous les clients) : [is_player][type].
local CLASS = { [true] = {}, [false] = {} }
for _, t in ipairs(Rp.filter_types()) do
  CLASS[false][t] = Rp.class_of(t, false)
  CLASS[true][t] = Rp.class_of(t, true)
end

local function on_damaged(e)
  if not Rp.ENABLED then return end
  local ent = e.entity
  if not (ent and ent.valid) or e.final_health <= 0 then return end
  local etype = ent.type
  if not CLASS[false][etype] then return end -- hors filtre (filtre absent : sauvegarde chargée avant le filtre, autre abonné)
  local f = team_of(ent.force.name)
  if not (f and not f.eliminated and f.hq and f.hq.valid) then return end
  local cls = CLASS[f.is_player == true][etype]
  if not cls then return end
  local unit = ent.unit_number
  local ratio = unit and ent.get_health_ratio()
  if not ratio then return end
  local st = f.repare
  if not st then
    st = Rp.new_state()
    f.repare = st
  end
  -- Entrée déjà notée (coups répétés d'une même attaque) : ni nom ni position relus.
  local known = st.ents[unit]
  if known then
    Rp.note(st, unit, known.n, known.x, known.y, ratio, cls, e.tick)
    return
  end
  local p = ent.position
  Rp.note(st, unit, ent.name, p.x, p.y, ratio, cls, e.tick)
end
Events.on(defines.events.on_entity_damaged, on_damaged)

local function set_filter()
  local filters = {}
  for _, t in ipairs(Rp.filter_types()) do filters[#filters + 1] = { filter = "type", type = t } end
  script.set_event_filter(defines.events.on_entity_damaged, filters)
end
Events.on_init(set_filter)
Events.on_load(set_filter)

local function say(f, st, text)
  if st.logs >= Rp.LOGS then return end
  st.logs = st.logs + 1
  log(text)
end

--- Fin d'une réparation de ce lot : vrai si la pensée doit s'arrêter (tâche encore en cours).
local function follow(f, st, surface, tick)
  local open = st.open
  if not open then return false end
  local t = Board.get(f).tasks[open.key]
  if t and t.worker then
    open.taken = open.taken or tick
    return true
  end
  if t then return true end -- ajoutée à cette pensée, pas encore prise
  st.open = nil
  -- Pièces relues (au plus Rp.BATCH_MAX lectures) : une tâche prise et finie entre deux pensées n'a pas été vue prise.
  local fixed = 0
  for _, c in ipairs(open.targets) do
    local e = surface.find_entity(c.name, { c.x, c.y })
    if e and e.valid and e.get_health_ratio() >= 1 then
      fixed = fixed + 1
      Rp.drop(st, c.unit)
    end
  end
  if not open.taken and fixed == 0 then return false end -- retirée sans preneur par Board.sync : rouverte plus bas
  open.taken = open.taken or tick
  st.last_key = nil
  st.stats.done = st.stats.done + 1
  st.stats.repaired = st.stats.repaired + fixed
  say(f, st, string.format("[FO-REPARE] %s : reparation %s terminee a %.1f min : %d piece(s) sur %d remise(s) a neuf, %.0f s apres l'ouverture, " ..
    "%.0f s apres la prise", key_of(f), open.key, minutes(f, tick), fixed, #open.targets, (tick - open.t) / 60, (tick - open.taken) / 60))
  return false
end

--- Pensée de réparation d'une équipe (Team.think). Rend le nombre de tâches ajoutées (0 ou 1).
function Rep.think(f, surface, tick)
  local st = f.repare
  if not (Rp.ENABLED and st) then return 0 end
  if not st.report_t then
    st.report_t = tick
  elseif st.report_t + Rp.REPORT_EVERY <= tick then
    log(Rp.report_line(key_of(f), tick, st))
    st.report_t = tick
  end
  if follow(f, st, surface, tick) then return 0 end
  if st.count == 0 then return 0 end
  -- Pièces du lot relues au moteur ; une pièce détruite ou réparée par ailleurs (joueur, paquet de réparation) est retirée et le
  -- lot est recalculé (au plus 3 fois : Rp.BATCH_MAX lectures chacune).
  local batch
  for _ = 1, 3 do
    local cand, skipped = Rp.pick(st, tick)
    if #cand == 0 then
      if skipped > 0 then st.stats.deferred = st.stats.deferred + 1 end
      return 0
    end
    local ok, changed = {}, false
    for _, c in ipairs(cand) do
      local e = surface.find_entity(c.name, { c.x, c.y })
      local r = e and e.valid and e.get_health_ratio() or nil
      if r and r * 100 < (Rp.BELOW[c.cls] or 0) then
        c.ratio = r
        ok[#ok + 1] = c
      else
        Rp.drop(st, c.unit)
        st.stats.dropped = st.stats.dropped + 1
        if c == cand[1] then changed = true end
      end
    end
    if not changed then
      batch = ok
      break
    end
  end
  if not batch or #batch == 0 then return 0 end
  local seed = batch[1]
  if #surface.find_enemy_units({ x = seed.x, y = seed.y }, Recon.SAFE_RADIUS, f.force) > 0 then
    -- Attaque locale : les pièces du lot repartent pour Rp.CALM ticks (pas de nouvel appel au moteur avant).
    for _, c in ipairs(batch) do
      local e = st.ents[c.unit]
      if e then e.t = tick end
    end
    st.stats.deferred = st.stats.deferred + 1
    say(f, st, string.format("[FO-REPARE] %s : reparation de %s en (%.1f, %.1f) reportee a %.1f min : unites ennemies a moins de %d tuiles",
      key_of(f), seed.name, seed.x, seed.y, minutes(f, tick), Recon.SAFE_RADIUS))
    return 0
  end
  local task = Rp.task(batch)
  local n = Board.add(f, { task }, tick)
  if n > 0 then
    -- Une tâche libre est retirée par Board.sync à la pensée suivante puis rouverte ici : même clé, ni compte ni ligne de plus.
    local again = st.last_key == task.key
    st.open = { key = task.key, targets = task.targets, t = again and st.last_t or tick }
    st.last_key, st.last_t = task.key, st.open.t
    if again then return n end
    st.stats.opened = st.stats.opened + 1
    say(f, st, string.format("[FO-REPARE] %s : reparation ouverte a %.1f min : %d piece(s) autour de %s en (%.1f, %.1f), classe %s, la plus abimee " ..
      "a %d %%, priorite %d, cout %s", key_of(f), minutes(f, tick), #batch, seed.name, seed.x, seed.y, seed.cls, math.floor(seed.ratio * 100),
      task.prio, Rp.COST))
  end
  return n
end

return Rep
