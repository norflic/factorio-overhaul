--[[
  Lot TV-PILOTE : EXÉCUTANT des cinq points « pilotage » de docs/TODO_VIDEO.md. Les règles sont pures (shared/) ; ici, la lecture des
  réglages de carte, les relevés du monde et le journal. Aucun `require` pendant un événement (F24) : tout est requis en tête.

    V10  famille armée à parts réservées (shared/ai3/famille_armee.lua)       Pil.armee_input (pour C.think), Pil.armee_line
         réglage fo-war-armee-famille (settings/pilotage.lua), ALLUMÉ par défaut ; journal [FO-ARMEE]
    G02  plafonds de sûreté des fours, chaînes et packs (shared/ai3/plafonds.lua, Pf.HARD_OBJ)   Pil.plafonds_on
         réglage fo-war-plafonds (settings/pilotage.lua), ALLUMÉ par défaut ; refus écrit « plafond ... » au journal [FO-CAPI-CONF]
    V88  table défaut -> signal -> levier (shared/ai3/defauts.lua)            Pil.defauts, Pil.note ; journal [FO-DEFAUT]
    W04  inventaire des gardes fermées (shared/ai3/gardes.lua)                 Pil.session ; journal [FO-GARDES], une fois par session
    D02  liste minimale d'amorçage écrite (shared/team/amorce_kit.lua)         Pil.kit ; journal [FO-AMORCE] « kit minimal », toutes les 10 min
         et seulement quand il change

  Les deux réglages sont lus avec repli à « éteint » tant qu'ils ne sont pas déclarés (moteur simulé des tests) ; la suite de chaque point a
  son test allumé. État persistant : seulement des nombres et des chaînes dans l'état de la capitalisation (cs.def, cs.kit_*), jamais de
  fonction dans global ; les caches de journal propres au module (`said`) sont perdus au rechargement (le journal ne décide rien).
]]

local Fa = require("shared.ai3.famille_armee")
local Df = require("shared.ai3.defauts")
local Gd = require("shared.ai3.gardes")
local Am = require("shared.ai3.amorce")
local Kit = require("shared.team.amorce_kit")
local Config = require("script.core.config")

local Pil = {}

Pil.PLAFONDS_SETTING = "fo-war-plafonds"
Pil.ARMEE_SETTING = "fo-war-armee-famille"
Pil.KIT_EVERY = 10 * 3600 -- ticks entre deux relevés du kit d'amorçage

local function setting_on(name)
  local ok, v = pcall(function() return settings.global[name].value end)
  return ok and v == true
end

function Pil.plafonds_on() return setting_on(Pil.PLAFONDS_SETTING) end
function Pil.armee_on() return setting_on(Pil.ARMEE_SETTING) end

---------------------------------------------------------------------------------------------------
-- V10 : famille armée
---------------------------------------------------------------------------------------------------
--- Entrée ctx.armee de C.think (shared/ai3/cerveau.lua) : { parts = { delta, alpha } } lus sur la dernière décision de la capitalisation
--- (capi.res), ou nil quand le réglage est éteint (la boucle d'avant). Sans décision encore (capi nil ou sans res) : parts nil, la règle écrit
--- « part absente » et ne retient rien.
function Pil.armee_input(capi)
  if not Pil.armee_on() then return nil end
  local res = capi and capi.res
  return { parts = res and { delta = res.delta, alpha = res.alpha } or nil }
end

--- Journal [FO-ARMEE] : une ligne quand la réserve de la famille change (part, matières retenues). plan = plan du cerveau (plan.ia3.armee).
function Pil.armee_line(f, plan, mn)
  local fam = plan and plan.ia3 and plan.ia3.armee
  local st = f.team and f.team.ia3
  if not (fam and st) then return end
  local sig = Fa.signature(fam)
  if sig == st.armee_sig then return end
  st.armee_sig = sig
  -- rien retenu et rien changé depuis le départ : pas de ligne pour une réserve vide au premier passage
  if sig == "-|" and st.armee_said == nil then return end
  st.armee_said = true
  log(Fa.line(f.key or "?", fam, mn))
end

---------------------------------------------------------------------------------------------------
-- V88 : défauts -> levier
---------------------------------------------------------------------------------------------------
local function def_state(cs)
  cs.def = cs.def or { total = {}, pending = {} }
  cs.def.total = cs.def.total or {}
  cs.def.pending = cs.def.pending or {}
  return cs.def
end

--- Un défaut vu hors du relevé des machines (refus « plan directeur occupe » re-émis, par exemple) : rangé pour le prochain relevé.
function Pil.note(cs, cause, item)
  local d = def_state(cs)
  if #d.pending < 64 then d.pending[#d.pending + 1] = { cause = cause, item = item } end
end

--- Appelé par la boucle de décision (relevé de la confirmation, script/ai3/capitalisation.lua) : range les échecs, arrêts et pertes du pas
--- par défaut (Df.route) et écrit une ligne [FO-DEFAUT] « cause -> signal -> levier » par défaut ; une cause hors de la table est écrite
--- aussi (« defaut sans levier »), jamais ignorée. Rend le résultat de Df.route.
function Pil.defauts(f, cs, cfr, tick, mn)
  local d = def_state(cs)
  cfr = cfr or {} -- nil : seulement les défauts notés hors du relevé (chaque pensée, Capi.think_tail)
  local events = {}
  for _, list in ipairs({ cfr.failed_now or {}, cfr.stopped_now or {}, cfr.lost_now or {} }) do
    for _, e in ipairs(list) do events[#events + 1] = { cause = e.cause, item = e.item, id = e.id } end
  end
  for _, e in ipairs(d.pending) do events[#events + 1] = e end
  d.pending = {}
  if #events == 0 then return nil end
  local r = Df.route(events)
  local key = f.key or "?"
  for _, row in ipairs(r.rows) do
    d.total[row.cause] = (d.total[row.cause] or 0) + row.n
    log(Df.line(key, row, mn))
  end
  for _, row in ipairs(r.unrouted) do
    d.total[row.cause] = (d.total[row.cause] or 0) + row.n
    log(Df.line_unrouted(key, row, mn))
  end
  return r
end

---------------------------------------------------------------------------------------------------
-- W04 : journal des gardes ; D02 : kit d'amorçage
---------------------------------------------------------------------------------------------------
local said = false

--- Une ligne [FO-GARDES] par session (premier passage de la capitalisation) : le décompte de l'inventaire en code.
function Pil.session()
  if said then return end
  said = true
  log("[FO-GARDES] " .. Gd.summary())
end

--- Rapport du kit d'amorçage d'une équipe : toutes les Pil.KIT_EVERY ticks (et au premier passage), seulement s'il a changé. ml = état du mall
--- (f.team.ia3.mall, où vit le compteur d'amorce) ; nil : rien. Écrit « kit minimal : ... | main avant la 1re production, hors liste : ... ».
function Pil.kit(f, cs, ml, tick, mn)
  if not ml then return end
  if cs.kit_tick and tick - cs.kit_tick < Pil.KIT_EVERY then return end
  cs.kit_tick = tick
  local start = Config.get("npc_start")
  local rep, why = Am.kit_report(ml, Kit.MINIMAL, start)
  if not rep then
    log(string.format("[FO-AMORCE] %s : kit minimal non rapporte : %s a %.1f min", f.key or "?", tostring(why), mn))
    return
  end
  if rep.text == cs.kit_sig then return end
  cs.kit_sig = rep.text
  log(string.format("[FO-AMORCE] %s : %s a %.1f min", f.key or "?", rep.text, mn))
end

return Pil
