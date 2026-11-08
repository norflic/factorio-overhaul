--[[
  Lot TV-VAPEUR, point V89 : dégradation graduée sous charge (règle pure : shared/core/charge.lua ; tests/charge_test.lua).
  Signal DÉTERMINISTE : la file du jeton des travaux lourds (script/core/lourd.lua, J.waiting), échantillonnée toutes les Ch.SAMPLE ticks.
  Niveau 0 à 3 gardé dans global (ns « pouls_jeton », champ `charge` : { ema, level, logs } ; absent d'une vieille sauvegarde = niveau 0).
  Levier : Charge.stretch(ticks) espace un travail NON URGENT. Appelé par les factions lointaines et calmes (shared/faction/cadence.lua via
  script/faction/commander.lua) et par le relevé des centrales pour leur alimentation (script/team/build.lua, charbon_step) ; JAMAIS par la
  défense, le courant (réseau, raccord) ni votre équipe. Réglage fo-war-degradation (défaut allumé) : éteint, niveau 0 (rien ne s'espace).
  Journal : [FO-CHARGE], un changement de niveau par ligne (Ch.LOGS au plus).
]]

local Storage = require("script.core.storage")
local Events = require("script.core.events")
local Lourd = require("script.core.lourd")
local Ch = require("shared.core.charge")

local Charge = {}

Charge.SETTING = "fo-war-degradation"

--- Réglage allumé ? (défaut vrai ; illisible : vrai)
function Charge.enabled()
  local ok, v = pcall(function() return settings.global[Charge.SETTING].value end)
  if ok and v == false then return false end
  return true
end

local function state(create)
  local s = Storage.ns("pouls_jeton")
  if not s then return nil end
  if create and not s.charge then s.charge = { ema = 0, level = 0, logs = 0 } end
  return s.charge
end

--- Niveau de charge courant (0 si réglage éteint ou état absent).
function Charge.level()
  local st = state(false)
  if not st or not Charge.enabled() then return 0 end
  return st.level or 0
end

--- Durée d'un travail non urgent de période `ticks` au niveau courant.
function Charge.stretch(ticks)
  return Ch.stretch(ticks, Charge.level())
end

--- Un échantillon au tick `tick` (événement toutes les Ch.SAMPLE ticks ; appelable par les bancs).
function Charge.sample(tick)
  local st = state(true)
  if not st then return end
  if not Charge.enabled() then
    if (st.level or 0) ~= 0 or (st.ema or 0) ~= 0 then st.ema, st.level = 0, 0 end
    return
  end
  local q = Lourd.waiting(tick)
  local before, after = Ch.sample(st, q)
  if before ~= after then
    st.logs = (st.logs or 0) + 1
    if st.logs <= Ch.LOGS then
      log(string.format("[FO-CHARGE] niveau %d -> %d a %.1f min : file du jeton %d, lissee %d/16 (espacement des travaux non urgents %d %%)",
        before, after, tick / 3600, q, st.ema, Ch.PERCENT[after + 1]))
    end
  end
end

Events.on_nth_tick(Ch.SAMPLE, function(e) Charge.sample(e.tick) end)

return Charge
