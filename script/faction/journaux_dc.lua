--[[
  Lot JOURNAUX-DC (30/10 ; rapport fo-logs/2026-10-30_AMELIO/CINQ-POINTS.md, points 1 et 2) : journaux qui rendent une
  partie du Directeur Créatif lisible après coup. Aucune décision de jeu : on écrit, on ne décide rien.

    [FO-ANEANTI]  chute du QG d'une faction : cause (biters, rival, joueur), PNJ restants, stock perdu avec le QG, ce qui
                  reste aux annexes ; refondation : non (Q19 en attente du DC).
    [FO-REGLAGES] valeurs des réglages de carte du mod (fo-*) et de la guerre en cours : au lancement du jeu (premier
                  passage après le chargement), au lancement de la guerre, et à chaque changement d'un réglage.

  Règles pures : shared/team/journaux_dc.lua. État écrit (dans un événement seulement) : f.hq_chute (faction).
  Le journal du lancement est écrit par une variable LOCALE (`logged`) : chaque client écrit son propre journal, aucune
  donnée de partie n'est touchée par cette branche (aucune écriture de l'état persistant : pas de désynchronisation).
]]

local Events = require("script.core.events")
local Config = require("script.core.config")
local State = require("script.faction.state")
local Stock = require("script.team.stock")
local J = require("shared.team.journaux_dc")

local JDC = {}

local PREFIX = "fo-"

local function minutes(tick)
  local war = State.war()
  return ((tick or 0) - ((war and war.started) or 0)) / 3600
end

local function faction_key_of(force_name)
  local f = State.by_force(force_name)
  return f and f.key or nil
end

---------------------------------------------------------------------------------------------------
-- Point 1 : chute d'un QG
---------------------------------------------------------------------------------------------------
--- Contenu d'un coffre { [objet] = n } (protégé : moteur simulé ou entité sans inventaire).
local function contents_of(ent)
  local out = {}
  pcall(function()
    local inv = ent.get_inventory(defines.inventory.chest)
    if inv then out = inv.get_contents() end
  end)
  return out
end

-- L'entité est encore valide ici (on_entity_died), son coffre aussi : on garde la cause et ce qui part avec elle.
-- L'élimination elle-même vient ensuite par on_entity_destroyed (script/faction/commander.lua).
Events.on(defines.events.on_entity_died, function(e)
  local ent = e.entity
  if not (ent and ent.valid and ent.unit_number) then return end
  local war = State.war()
  if not (war and war.active) then return end
  local f = State.by_force(ent.force.name)
  if not (f and not f.eliminated and f.hq and f.hq.valid and f.hq.unit_number == ent.unit_number) then return end
  local total, txt = J.resume_objets(contents_of(ent), 6)
  f.hq_chute = {
    tick = e.tick, force = e.force and e.force.name or nil,
    tueur = e.cause and e.cause.valid and e.cause.name or nil,
    perdu = total, perdu_txt = txt,
  }
end)

--- Appelé par war.lua (Commander.on_eliminated) quand une faction perd son QG. Écrit [FO-ANEANTI] et rend la cause
--- (genre, clé du rival) pour le message de fin de guerre.
function JDC.aneanti(f, tick, n_vivantes)
  local ch = f.hq_chute or {}
  local genre, tueur = J.cause(ch.force, f.force, faction_key_of)
  local reste = 0
  pcall(function()
    for _, e in ipairs(Stock.annexes(f)) do
      local c = contents_of(e)
      local n = J.resume_objets(c, 0)
      reste = reste + n
    end
  end)
  log(string.format("[FO-ANEANTI] tick %d (%.1f min) %s : QG detruit | cause %s%s (force %s, tueur %s) | PNJ restants : "
    .. "ouvriers %d, soldats %d | perdu avec le QG : %d objets {%s} | reste aux annexes : %d objets | factions vivantes %d | "
    .. "refondation : non (Q19 en attente du DC)",
    tick, minutes(tick), f.key or "?", genre, tueur and (" " .. tueur) or "", ch.force or "?", ch.tueur or "?",
    f.engineers_count or 0, f.soldiers_count or 0, ch.perdu or 0, ch.perdu_txt or "", reste, n_vivantes or 0))
  return genre, tueur
end

---------------------------------------------------------------------------------------------------
-- Point 2 : réglages
---------------------------------------------------------------------------------------------------
--- Valeurs des réglages de carte du mod (runtime-global, préfixe « fo- »), triées par J.ligne_reglages.
local function mod_settings()
  local out = {}
  local g = settings and settings.global
  if not g then return out end
  for name, s in pairs(g) do
    if type(name) == "string" and name:sub(1, #PREFIX) == PREFIX then out[name] = s.value end
  end
  return out
end

--- Ligne de la guerre : active ou non, factions vivantes, plafond d'ouvriers EFFECTIF des factions et sa source (le
--- nombre écrit au lancement d'une guerre lancée avec un nombre l'emporte sur le réglage : script/team/team.lua, npc_max).
local function war_text()
  local war = State.war()
  if not (war and war.active) then return "guerre inactive" end
  local s = war.settings or {}
  local cap, src
  if s.npc_from_setting or not s.engineers_max then
    cap, src = Config.get("npc_max"), "reglage fo-war-workers"
  else
    cap, src = s.engineers_max, "nombre ecrit au lancement de la guerre"
  end
  return string.format("guerre active depuis %.1f min, factions vivantes %d, soldats max %s, plafond d'ouvriers des factions %s (%s), "
    .. "plafond de votre equipe %s", minutes(game.tick), #State.alive(), tostring(s.soldiers_max), tostring(cap), src,
    tostring(Config.get("player_npc_max")))
end

--- Votre équipe (lecture seule de l'état : State.faction ne crée rien).
local function pteam_text()
  local p = State.faction("player")
  if not (p and p.hq and p.hq.valid) then return "votre equipe : aucune (pas de coffre d'equipe)" end
  return string.format("votre equipe : %d PNJ, coffre en (%d, %d)", p.engineers_count or 0, math.floor(p.hq.position.x),
    math.floor(p.hq.position.y))
end

--- Écrit la ligne [FO-REGLAGES] (raison : « lancement », « guerre lancee », « changement de <nom> »).
function JDC.reglages(raison)
  log(string.format("[FO-REGLAGES] tick %d %s | %s | %s | %s", game.tick, raison, J.ligne_reglages(mod_settings()),
    war_text(), pteam_text()))
end

local logged = false
Events.on_nth_tick(60, function()
  if logged then return end
  logged = true
  JDC.reglages("lancement")
end)

Events.on(defines.events.on_runtime_mod_setting_changed, function(e)
  local name = e.setting or "?"
  if name:sub(1, #PREFIX) ~= PREFIX then return end
  Config.invalidate() -- le cache est aussi vidé par script/core/config.lua ; l'ordre des abonnements n'importe pas ici
  JDC.reglages(string.format("changement de %s (%s)", name, e.player_index and ("joueur " .. e.player_index) or "script"))
end)

return JDC
