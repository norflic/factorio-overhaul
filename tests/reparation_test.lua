--[[
  Lot PD-REPARATION (D79) : règles pures (shared/team/reparation.lua) et exécutant (script/team/reparation.lua) hors jeu, avec
  l'acte de réparation RÉEL du lot RECONSTRUIRE (script/team/reconstruction.lua, Recon.repair_program / Recon.repair_act) pour la
  chaîne de bout en bout : coup reçu -> relevé -> tâche -> programme du PNJ -> santé remise au maximum -> fin journalisée.
  Usage : lua5.2 tests/reparation_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

-- Doublures (mêmes que tests/reconstruction_exec_test.lua, plus on_init / on_load / set_event_filter) ----------------------
local handlers, inits, loads = {}, {}, {}
package.loaded["script.core.events"] = {
  on = function(id, fn) handlers[id] = fn end,
  on_init = function(fn) inits[#inits + 1] = fn end,
  on_load = function(fn) loads[#loads + 1] = fn end,
}
defines = { events = { on_entity_died = 1, on_player_mined_entity = 2, on_robot_mined_entity = 3, on_entity_damaged = 4 },
  entity_status = { no_power = 7, working = 1 }, direction = { north = 0, east = 2, south = 4, west = 6 } }
local ns = { ia3k = { teams = {} } }
package.loaded["script.core.storage"] = { ns = function(n) ns[n] = ns[n] or {}; return ns[n] end }
local teams = {}
package.loaded["script.faction.state"] = {
  sorted_keys = function(t) local k = {} for key in next, t do k[#k + 1] = key end table.sort(k) return k end,
  owner = function() return nil end,
  own = function() end,
  faction = function(id) return teams[id] end,
  by_force = function(fn) return teams[fn] end,
  alive = function() return {} end,
  war = function() return { claims = {} } end,
  site_key = function(pos) return math.floor(pos.x / 32) .. ":" .. math.floor(pos.y / 32) end,
}
package.loaded["script.faction.sites"] = { claim = function() end, release = function() end }
package.loaded["script.team.board"] = {
  get = function(f) return f.team.board end,
  add = function(f, tasks)
    local n = 0
    for _, t in ipairs(tasks) do if not f.team.board.tasks[t.key] then f.team.board.tasks[t.key] = t; n = n + 1 end end
    return n
  end,
}
package.loaded["script.team.stock"] = { count = function() return 0 end }
package.loaded["script.team.harvest"] = { names = function(item) return { item } end }
remote = { add_interface = function() end }
local filters_set = {}
script = { set_event_filter = function(id, flt) filters_set[#filters_set + 1] = { id = id, filters = flt } end }
local logs = {}
function log(s) logs[#logs + 1] = s end
game = { tick = 0, entity_prototypes = {} }
function game.get_filtered_entity_prototypes() return {} end

local R = require("shared.ai3.reglages")
local Rp = require("shared.team.reparation")
local Recon = require("script.team.reconstruction")
local Rep = require("script.team.reparation")
local damaged = handlers[defines.events.on_entity_damaged]

local function grep(pat)
  local n = 0
  for _, l in ipairs(logs) do if l:find(pat, 1, true) then n = n + 1 end end
  return n
end

-- §1 Classes : types du moteur seulement, rien de dupliqué ------------------------------------------------------------------
do
  for _, t in ipairs({ "lab", "furnace", "assembling-machine", "mining-drill" }) do
    check(Rp.class_of(t, true) == "production" and Rp.class_of(t, false) == "production", "classe production : " .. t .. " (toutes les équipes)")
  end
  for _, t in ipairs(R.TURRET_TYPES) do
    check(Rp.class_of(t, true) == nil and Rp.class_of(t, false) == nil, "tourelle " .. t .. " exclue (réparée par COMPAGNONS-ACTIFS)")
  end
  check(Rp.class_of("electric-pole", true) == nil and Rp.class_of("boiler", true) == nil,
    "infrastructure électrique de VOTRE équipe exclue (réparée par RECONSTRUIRE)")
  check(Rp.class_of("electric-pole", false) == "energie" and Rp.class_of("generator", false) == "energie",
    "infrastructure électrique des FACTIONS réparée ici (personne ne la réparait)")
  check(Rp.class_of("wall", true) == "defense" and Rp.class_of("inserter", true) == "logistique", "mur : défense ; bras : logistique")
  check(Rp.class_of("character", false) == nil and Rp.class_of("unit", false) == nil and Rp.class_of("unit-spawner", false) == nil,
    "personnage, unités et nids exclus")
  local ft = Rp.filter_types()
  local sorted, has = true, {}
  for i, t in ipairs(ft) do has[t] = true if i > 1 and ft[i - 1] >= t then sorted = false end end
  check(sorted and has.lab and has["electric-pole"] and not has["ammo-turret"] and not has.unit, "types du filtre triés, sans tourelle ni unité")
end

-- §2 Note : seuil, mise à jour, retrait, plafond par classe ----------------------------------------------------------------
do
  local st = Rp.new_state()
  check(Rp.note(st, 1, "a", 0, 0, 0.9, "production", 10) == nil and st.count == 0, "au-dessus du seuil (80 %) : rien de noté")
  check(Rp.note(st, 1, "a", 0, 0, 0.5, "production", 10) == "add" and st.count == 1, "sous le seuil : noté")
  check(Rp.note(st, 1, "a", 0, 0, 0.4, "production", 20) == "upd" and st.ents[1].r == 0.4 and st.ents[1].t == 20, "coup suivant : mis à jour")
  check(Rp.note(st, 1, "a", 0, 0, 0.95, "production", 30) == "del" and st.count == 0 and st.ents[1] == nil, "réparé ailleurs : retiré")
  for u = 1, Rp.PENDING_MAX.defense + 5 do Rp.note(st, 100 + u, "w", u, 0, 0.1, "defense", 40) end
  check(st.count == Rp.PENDING_MAX.defense and st.over == 5, "plafond de la classe défense : " .. st.count .. " gardés, 5 hors place")
  check(Rp.note(st, 9, "l", 0, 0, 0.1, "production", 40) == "add", "des murs criblés ne prennent pas la place d'un laboratoire")
  Rp.drop(st, 9)
  check(st.per.production == 0 and st.count == Rp.PENDING_MAX.defense, "retrait : compteurs justes")
end

-- §3 Choix : importance, la plus abîmée, attaque locale, lot de voisines ----------------------------------------------------
do
  local T0 = 100000
  local st = Rp.new_state()
  Rp.note(st, 1, "convoyeur", 0, 0, 0.05, "logistique", T0 - 5000)
  Rp.note(st, 2, "four", 100, 0, 0.7, "production", T0 - 5000)
  Rp.note(st, 3, "labo", 200, 0, 0.3, "production", T0 - 5000)
  local b = Rp.pick(st, T0)
  check(b[1] and b[1].unit == 3, "production avant logistique, puis la plus abîmée (labo à 30 % avant four à 70 %)")
  -- Attaque locale : le labo vient d'être touché ; son voisin à 10 tuiles aussi écarté
  Rp.note(st, 3, "labo", 200, 0, 0.25, "production", T0 - 10)
  Rp.note(st, 4, "assembleur", 210, 0, 0.1, "production", T0 - 5000)
  b = Rp.pick(st, T0)
  check(b[1] and b[1].unit == 2, "attaque locale : pièce touchée et sa voisine (10 tuiles) écartées, le four loin d'elles est choisi")
  b = Rp.pick(st, T0 + Rp.CALM)
  check(b[1] and b[1].unit == 4 and #b == 2, "attaque finie (Rp.CALM) : l'assembleur à 10 % et le labo voisin en un voyage")
  -- Lot borné
  local s2 = Rp.new_state()
  for u = 1, 10 do Rp.note(s2, u, "f", u, 0, 0.5, "production", 0) end
  Rp.note(s2, 50, "f", 50, 0, 0.5, "production", 0)
  b = Rp.pick(s2, T0)
  check(#b == Rp.BATCH_MAX, "lot : au plus Rp.BATCH_MAX pièces")
  local far = false
  for _, c in ipairs(b) do if c.unit == 50 then far = true end end
  check(not far, "lot : pas de pièce hors de Rp.BATCH_RADIUS")
  -- Déterminisme : ordre d'insertion différent, même choix
  local s3 = Rp.new_state()
  Rp.note(s3, 50, "f", 50, 0, 0.5, "production", 0)
  for u = 10, 1, -1 do Rp.note(s3, u, "f", u, 0, 0.5, "production", 0) end
  local b3 = Rp.pick(s3, T0)
  local same = #b3 == #b
  for i = 1, #b do if not b3[i] or b3[i].unit ~= b[i].unit then same = false end end
  check(same, "déterministe : même lot quel que soit l'ordre des coups")
  -- Tout est sous attaque : rien, compté
  local s4 = Rp.new_state()
  Rp.note(s4, 1, "f", 0, 0, 0.5, "production", T0)
  local b4, skipped = Rp.pick(s4, T0)
  check(#b4 == 0 and skipped == 1, "pendant l'attaque : aucune réparation")
  local t = Rp.task(b)
  check(t.kind == "repare" and t.prio == Rp.PRIO.production and t.domain == "production" and #t.targets == #b and t.targets[1].unit == b[1].unit,
    "tâche : kind repare (programme et acte de RECONSTRUIRE ; ne bloque pas la réparation des tourelles), priorité et domaine de la classe")
  check(Rp.PRIO.production < Rp.PRIO.energie + 2 and Rp.PRIO.production < 66 and Rp.PRIO.logistique < Rp.PRIO.defense,
    "priorités : sous la reconstruction (70) et la réparation des tourelles (66) ; production > énergie > défense passive > logistique")
end

-- §4 Exécutant : relevé à l'événement --------------------------------------------------------------------------------------
local surface
local ents = {}
local function new_ent(name, ty, x, y, force, health, max)
  local e = { valid = true, name = name, type = ty, position = { x = x, y = y }, force = { name = force }, health = health,
    prototype = { max_health = max } }
  e.unit_number = #ents + 1000
  e.get_health_ratio = function() return e.health / max end
  ents[#ents + 1] = e
  return e
end
local function new_team(id, is_player)
  local f = { id = id, key = id, force = id, is_player = is_player, started = 0, stats = {}, hq = { valid = true },
    team = { board = { tasks = {} } } }
  teams[id] = f
  return f
end
surface = {
  enemies = 0,
  find_enemy_units = function() local n = {} for i = 1, surface.enemies do n[i] = {} end return n end,
  find_entity = function(name, pos)
    for _, e in ipairs(ents) do
      if e.valid and e.name == name and e.position.x == pos[1] and e.position.y == pos[2] then return e end
    end
  end,
}
local lab
local function hit(e, tick)
  damaged({ entity = e, final_health = e.health, tick = tick })
end

do
  check(damaged ~= nil, "l'exécutant s'abonne à on_entity_damaged")
  check(#inits == 1 and #loads == 1, "filtre posé à on_init et à on_load (le filtre n'est pas sauvegardé)")
  inits[1]()
  loads[1]()
  local fl = filters_set[1]
  check(fl and fl.id == defines.events.on_entity_damaged and #fl.filters == #Rp.filter_types() and fl.filters[1].filter == "type",
    "filtre du moteur : un filtre « type » par type réparable (les unités touchées n'appellent pas le script)")

  local fa = new_team("scarlet", false)
  local pl = new_team("player", true)
  lab = new_ent("labo-x", "lab", 10, 10, "scarlet", 50, 100)
  hit(lab, 1000)
  check(fa.repare and fa.repare.count == 1, "faction : labo à 50 % relevé (état créé à l'événement)")
  local biter = new_ent("ver-x", "unit", 0, 0, "enemy", 10, 100)
  hit(biter, 1000)
  local dead = new_ent("four-x", "furnace", 12, 10, "scarlet", 0, 100)
  hit(dead, 1000)
  check(fa.repare.count == 1, "unité ennemie et pièce tuée par le coup (laissée à la reconstruction) ignorées")
  local pole = new_ent("poteau-x", "electric-pole", 5, 5, "player", 10, 100)
  hit(pole, 1000)
  check(pl.repare == nil, "votre poteau n'est pas relevé ici (RECONSTRUIRE le répare)")
  local plab = new_ent("labo-x", "lab", -10, -10, "player", 60, 100)
  hit(plab, 1000)
  check(pl.repare and pl.repare.count == 1, "votre labo (posé par vous ou par les PNJ) est relevé")
  -- Borne par tick : 1000 coups sur la même pièce = une entrée
  for i = 1, 1000 do hit(lab, 1000 + i) end
  check(fa.repare.count == 1 and fa.repare.ents[lab.unit_number].t == 2000, "1000 coups sur une pièce : une entrée, O(1) par coup")
end

-- §5 Pensée : ouverture, attaque locale, reprise après Board.sync, fin et chaîne réelle -------------------------------------
do
  local fa = teams.scarlet
  local st = fa.repare
  local T = 2000
  check(Rep.think(fa, surface, T + 10) == 0 and st.stats.deferred >= 1, "pensée pendant l'attaque (touché il y a 10 ticks) : rien")
  surface.enemies = 2
  check(Rep.think(fa, surface, T + Rp.CALM) == 0 and grep("reportee") == 1, "unités ennemies près de la pièce : report journalisé")
  surface.enemies = 0
  check(Rep.think(fa, surface, T + Rp.CALM + 10) == 0, "report : la pièce attend de nouveau Rp.CALM ticks")
  local T2 = T + 2 * Rp.CALM + 20
  check(Rep.think(fa, surface, T2) == 1 and grep("[FO-REPARE] scarlet : reparation ouverte") == 1, "calme revenu : tâche ouverte, journal [FO-REPARE]")
  local key = st.open.key
  local task = fa.team.board.tasks[key]
  check(task and task.kind == "repare" and task.targets[1].name == "labo-x", "tâche au tableau : réparer le labo")
  -- Board.sync retire une tâche libre ; la pensée suivante la rouvre sans compter une ouverture de plus
  fa.team.board.tasks = {}
  check(Rep.think(fa, surface, T2 + 300) == 1 and st.stats.opened == 1 and grep("reparation ouverte") == 1, "rouverte après Board.sync : ni compte ni ligne de plus")
  task = fa.team.board.tasks[key]
  task.worker = 7
  check(Rep.think(fa, surface, T2 + 600) == 0, "tâche prise : aucune autre ouverte")
  -- Chaîne réelle : programme et acte de RECONSTRUIRE
  local prog = Recon.repair_program(fa, task)
  local acts = false
  for _, step in ipairs(prog or {}) do if step[1] == "act" and step[2] == "repair" then acts = true end end
  check(acts, "programme du PNJ : aller à la pièce et l'acte « repair »")
  check(Recon.repair_act({}, fa, task, surface) == true and lab.health == 100, "acte réel : santé du labo remise au maximum, sans objet consommé (Q12 : gratuit)")
  fa.team.board.tasks = {}
  Rep.think(fa, surface, T2 + 900)
  check(grep("[FO-REPARE] scarlet : reparation " .. key .. " terminee") == 1 and st.stats.repaired == 1 and st.count == 0,
    "fin : journal [FO-REPARE] terminee, pièce comptée et retirée du relevé")
  -- Pièce détruite entre le coup et la pensée : retirée à la relecture
  local four = new_ent("four-y", "furnace", 40, 40, "scarlet", 30, 100)
  hit(four, T2 + 1000)
  four.valid = false
  check(Rep.think(fa, surface, T2 + 1000 + Rp.CALM) == 0 and st.count == 0 and st.stats.dropped == 1, "pièce détruite avant la réparation : retirée, rien d'ouvert")
  -- Bilan périodique
  Rep.think(fa, surface, T2 + 1000 + Rp.CALM + Rp.REPORT_EVERY + 1)
  check(grep("[FO-REPARE] scarlet : bilan") >= 1 and grep("cout : gratuit") >= 1, "bilan [FO-REPARE] toutes les 5 min, coût affiché")
end

-- §5 bis Exécutant du PNJ : le kind « repare » est branché sur le programme et l'acte de « repair » (script/team/worker.lua)
do
  local fh = io.open("script/team/worker.lua", "r")
  local src = fh and fh:read("*a") or ""
  if fh then fh:close() end
  check(src:find('k == "repare" then%s+return Recon%.repair_program%(f, task%)') ~= nil, "worker : programme du kind repare = Recon.repair_program")
  check(src:find("ACTS.repare = ACTS.repair", 1, true) ~= nil, "worker : ACTS.repare = ACTS.repair (même acte, gratuit)")
end

-- §6 Équipe sans relevé, ou réglage éteint : rien -------------------------------------------------------------------------
do
  local f = new_team("vide", false)
  check(Rep.think(f, surface, 99999) == 0 and f.repare == nil, "équipe jamais touchée : aucun état, aucun appel")
  Rp.ENABLED = false
  local e = new_ent("labo-x", "lab", 3, 3, "vide", 10, 100)
  hit(e, 100)
  check(f.repare == nil, "Rp.ENABLED éteint : aucun relevé")
  Rp.ENABLED = true
end

for _, l in ipairs(logs) do if os.getenv("FO_VERBOSE") then print(l) end end -- FO_VERBOSE=1 : journal simulé
print(string.format("[PD-REPARATION] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
