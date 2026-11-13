--[[
  Lot TV-PILOTE : EXÉCUTANT des points V10, G02 et D02 de docs/TODO_VIDEO.md (V88 et W04 : lot TV-GARDES, script/ai3/defauts_rt.lua).
  Les règles sont pures (shared/) ; ici, la lecture des réglages de carte, les relevés du monde et le journal. Aucun `require` pendant un
  événement (F24) : tout est requis en tête.

    V10  famille armée à parts réservées (shared/ai3/famille_armee.lua)       Pil.armee_input (pour C.think), Pil.armee_line
         réglage fo-war-armee-famille (settings/pilotage.lua), ALLUMÉ par défaut ; journal [FO-ARMEE]
    G02  plafonds de sûreté des fours, chaînes et packs (shared/ai3/plafonds.lua, Pf.HARD_OBJ)   Pil.plafonds_on
         réglage fo-war-plafonds (settings/pilotage.lua), ALLUMÉ par défaut ; refus écrit « plafond ... » au journal [FO-CAPI-CONF]
    D02  liste minimale d'amorçage écrite (shared/team/amorce_kit.lua)         Pil.kit ; journal [FO-AMORCE] « kit minimal », toutes les 10 min
         et seulement quand il change

  Les deux réglages sont lus avec repli à « éteint » tant qu'ils ne sont pas déclarés (moteur simulé des tests). État persistant : seulement
  des nombres et des chaînes dans l'état de la capitalisation (cs.kit_*) et du cerveau (armee_sig), jamais de fonction dans global.
]]

local Fa = require("shared.ai3.famille_armee")
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
  -- lot S42-DEFENSE : part de la defense mesuree sur les pertes (capi.def_dyn) : la reserve suit jusqu'a 1000 pour mille
  return { parts = res and { delta = res.delta, alpha = res.alpha, max = capi.def_dyn and 1000 or nil } or nil }
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
-- D02 : kit d'amorçage
---------------------------------------------------------------------------------------------------
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
