--[[
  Lot S1 SURVIE, côté RUNTIME : le péril du QG (règle pure : shared/team/survie_qg.lua) et son journal [FO-SURVIE].
  Lit le recensement du QG et la mémoire des vagues reçues de la prévision (script/ai3/prevision.lua, Prev.qg_view), décide à chaque
  pensée de l'équipe (Team.view) et range le résultat dans f.team.s1 (nombres, chaînes et booléens : il vit dans la sauvegarde ;
  jamais une fonction). Aucune décision ne lit le journal.

  Journal, une ligne par CAUSE :
    ENTREE  QG en péril, cause « menace » (pas assez de tourelles armées pour la menace) ou « munitions » (des tourelles, mais vides) ;
    SORTIE  la défense armée couvre la menace : la production reprend ;
    RECENSEMENT toutes les 5 min tant qu'une menace est mémorisée : tourelles, armées, chargeurs, défense armée, menace.
]]

local Sq = require("shared.team.survie_qg")
local Dc = require("shared.team.defchoix")
local Prev = require("script.ai3.prevision")
local Pv = require("shared.ai3.prevision")
local State = require("script.faction.state")
local Outposts = require("script.faction.outposts")
local T = require("shared.team.config")

local SurvieQg = {}

SurvieQg.LOG_EVERY = 5 * 3600 -- recensement : une ligne par 5 min au plus
SurvieQg.FRESH = 3 * 3600     -- un recensement plus vieux que 3 min n'est plus lu (la prévision relève chaque minute)

local function state(f)
  f.team.s1 = f.team.s1 or { was = false, entries = 0, since = 0, last_log = -1000000, cause = "" }
  return f.team.s1
end

local function min_of(tick) return tick / 3600 end

--- Pensée : met à jour l'état et rend le résultat de Sq.peril (avec `tick`), ou nil (prévision éteinte, aucun relevé du QG).
function SurvieQg.update(f, tick)
  if not (f and f.team) then return nil end
  local v = Prev.qg_view(f)
  if not v or tick - (v.qg.tick or 0) > SurvieQg.FRESH then return nil end
  local s = state(f)
  local q = v.qg
  local threat = Sq.threat(v.waves, tick)
  local r = Sq.peril({ threat = threat, armed_value = q.value, turret_value = q.turret_value, turrets = q.turrets, armed = q.armed,
    cap = Dc.HQ_CAP, was = s.was })
  r.tick, r.threat = tick, threat
  local who = tostring(f.key or "?")
  if r.peril and not s.was then
    s.entries, s.since, s.cause = s.entries + 1, tick, r.cause
    log(string.format("[FO-SURVIE] %s : QG EN PERIL a %.1f min (entree n %d), cause %s : menace %d PV recue en 30 min, defense ARMEE %d PV " ..
      "(%d tourelle(s) dont %d armee(s), %d chargeur(s)), cible %d PV -> %d tourelle(s) voulue(s), %d a poser, %d a remplir%s ; defense d'abord, planchers de fer reduits",
      who, min_of(tick), s.entries, r.cause, threat, math.floor(q.value), q.turrets, q.armed, q.ammo, r.need, r.want, r.fresh, r.refill,
      r.full and " (plafond atteint)" or ""))
    s.last_log = tick
  elseif s.was and not r.peril then
    log(string.format("[FO-SURVIE] %s : QG HORS DE PERIL a %.1f min apres %.1f min (cause %s) : defense ARMEE %d PV contre une menace de %d PV " ..
      "(%d tourelle(s) dont %d armee(s), %d chargeur(s)) ; la production reprend",
      who, min_of(tick), (tick - s.since) / 3600, s.cause, math.floor(q.value), threat, q.turrets, q.armed, q.ammo))
    s.last_log = tick
  elseif (r.peril or threat > 0) and tick - s.last_log >= SurvieQg.LOG_EVERY then
    log(string.format("[FO-SURVIE] %s : QG recensement a %.1f min : %d tourelle(s) dont %d armee(s), %d chargeur(s), defense armee %d PV, " ..
      "menace %d PV, %s",
      who, min_of(tick), q.turrets, q.armed, q.ammo, math.floor(q.value), threat, r.peril and ("PERIL (" .. tostring(r.cause) .. ")") or "hors de peril"))
    s.last_log = tick
  end
  s.was = r.peril
  return r
end

---------------------------------------------------------------------------------------------------
-- Protéger avant d'agrandir ou de refaire (avant-postes touchés par des vagues), réserve de chargeurs sur la menace
---------------------------------------------------------------------------------------------------
--- PV reçus dans la fenêtre au site de l'avant-poste `oid` (clé « ap<oid> » de la prévision), 0 sans fait.
function SurvieQg.hit(f, oid, tick)
  local st = f.prevision
  if not (st and st.cal) then return 0 end
  return Pv.mem_floor(st.cal, "ap" .. tostring(oid), tick)
end

--- L'avant-poste doit-il être protégé d'abord ? (vagues reçues et tourelles manquantes ; `turrets` : tourelles posées, `wanted` : voulues.)
function SurvieQg.protect(f, oid, tick, turrets, wanted)
  return Sq.protect_first({ hit = SurvieQg.hit(f, oid, tick), turrets = turrets, wanted = wanted })
end

--- Comme SurvieQg.protect, et note le résultat dans f.team.s1.prot (tick du dernier constat, nombres seulement) : la reconstruction le lit sans
--- dépendre de ce module (script.ai3.prevision -> comportement -> ... : pas de cycle de require).
function SurvieQg.mark_protect(f, oid, tick, turrets, wanted)
  local s = state(f)
  s.prot = s.prot or {}
  local p = SurvieQg.protect(f, oid, tick, turrets, wanted)
  s.prot[oid] = p and tick or nil
  return p
end

--- Une tourelle est-elle posable (au stock ou fabricable) selon le dernier plan ? Les attentes de protection ne valent que si oui : sans
--- recette, attendre des tourelles gèlerait la production pour rien.
function SurvieQg.can_protect(f)
  return f.team ~= nil and f.team.s1 ~= nil and f.team.s1.turret_ok == true
end

--- Écrit, après le plan de la pensée, si une tourelle est posable (`plan.turret_ok`, planificateur).
function SurvieQg.note_plan(f, plan)
  if not (f and f.team and plan) then return end
  state(f).turret_ok = plan.turret_ok == true
end

--- Réserve de chargeurs voulue au coffre (Sq.ammo_reserve) : menace = la plus grosse vague reçue n'importe où en 30 min, tourelles = celles
--- de l'équipe. 0 sans fait. Lue par le cerveau (ctx.ammo_reserve -> shared/ai3/buts.lua).
function SurvieQg.ammo_reserve(f, tick)
  local st = f.prevision
  if not (st and st.cal and Prev.enabled()) then return 0 end
  local turrets = 0
  for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
    local t = f.turrets[id]
    if t.valid then turrets = turrets + 1 end
  end
  local r = Sq.ammo_reserve({ threat = Sq.threat_any(Pv.threat_waves(st.cal, "qg"), tick), turrets = turrets, per_turret = T.turret_ammo_target })
  local s = state(f)
  if r > 0 and s.reserve_said ~= r then
    log(string.format("[FO-SURVIE] %s : reserve de chargeurs au coffre voulue a %.1f min : %d (menace recue %d PV en 30 min, %d tourelle(s) de l'equipe, %d chargeurs par tourelle au plus)",
      tostring(f.key or "?"), tick / 3600, r, Sq.threat_any(Pv.threat_waves(st.cal, "qg"), tick), turrets, T.turret_ammo_target))
  end
  s.reserve_said = r
  return r
end

---------------------------------------------------------------------------------------------------
-- Interface des bancs (s1-assaut) : une vague REÇUE posée dans la mémoire de l'équipe (ce que fait la calibration, Pv.calibrate), et une
-- tourelle posée par le banc inscrite comme tourelle du QG (comme Outposts.fortify). Jamais appelée par le mod.
---------------------------------------------------------------------------------------------------
local function team_by_key(key)
  if key == "player" then return State.faction("player") end
  local war = State.war()
  for _, id in ipairs(State.sorted_keys(war and war.factions)) do
    local f = war.factions[id]
    if f.key == key then return f end
  end
  return nil
end

remote.add_interface("fo-s1", {
  --- Vague de `pv` PV reçue au site `site` ("qg", "ap1"...) à ce tick. Rend vrai si la calibration de l'équipe existe.
  note_wave = function(key, site, pv)
    local f = team_by_key(key)
    local st = f and f.prevision
    if not (st and st.cal) then return false end
    local team = st.cal[Pv.TEAM]
    if not team then
      team = { k = Pv.K0, hit = 0, fa = 0 }
      st.cal[Pv.TEAM] = team
    end
    team.waves = team.waves or {}
    team.waves[#team.waves + 1] = { t = game.tick, pv = pv, key = site, kind = "banc" }
    return true
  end,
  --- Inscrit une tourelle du banc comme tourelle du QG de l'équipe.
  own_turret = function(key, turret)
    local f = team_by_key(key)
    if not (f and turret and turret.valid) then return false end
    Outposts.add_turret(f, turret, nil, 0)
    return true
  end,
  --- État du péril (f.team.s1) : { was, entries, since, cause } ou nil.
  state = function(key)
    local f = team_by_key(key)
    return f and f.team and f.team.s1 or nil
  end,
})

return SurvieQg
