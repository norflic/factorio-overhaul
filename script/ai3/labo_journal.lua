--[[
  Lot BLOCAGE-LABOS (8/11) : la ligne [FO-LABO]. Quand la recherche virtuelle d'une équipe attend des packs au coffre (script/ai3/cerveau.lua,
  research_step : `lab.paid < need_paid`), dit POURQUOI, pack par pack (règle pure shared/ai3/labo_cause.lua) : en stock, en route,
  fabricable, impayable avec la raison du site de pétrole. Une ligne par force, AU CHANGEMENT de signature, au plus une par minute.
  Lecture seule : ne change aucune décision.
]]
local Lc = require("shared.ai3.labo_cause")
local Stock = require("script.team.stock")
local General = require("script.ai3.general")
local Pet = require("script.ai3.petrole")

local Lj = {}

Lj.EVERY = 3600 -- au plus une ligne par force et par minute

--- `spec.ing` = { { pack, n } } de l'unité ; `view` = vue de la pensée (view.incoming) ; `minutes` = minute de jeu (affichage).
--- Rend la liste de diagnostic (utile aux bancs) ; `blocked` faux : rien n'attend, une éventuelle alerte précédente est levée au journal.
function Lj.note(f, st, tech, spec, view, tick, minutes, blocked)
  st.labo_log = st.labo_log or { sig = "", tick = -Lj.EVERY }
  local lg = st.labo_log
  if not blocked then
    if lg.sig ~= "" and tick - lg.tick >= Lj.EVERY then
      log(string.format("[FO-LABO] %s : recherche '%s' repart (packs payes) a %.1f min", f.key or "?", tostring(tech), minutes))
      lg.sig, lg.tick = "", tick
    end
    return nil
  end
  local stock = {}
  for _, ing in ipairs(spec.ing or {}) do stock[ing[1]] = Stock.count(f, ing[1]) end
  local list = Lc.diagnose({
    ingredients = spec.ing, stock = stock, incoming = (view and view.incoming) or {},
    feasible = function(pack) return General.feasible(f, pack) end,
    reason = function(pack) return Pet.reason_for(f, pack) end,
  })
  local sig = tech .. "|" .. Lc.signature(list)
  if sig ~= lg.sig and tick - lg.tick >= Lj.EVERY then
    lg.sig, lg.tick = sig, tick
    log(string.format("[FO-LABO] %s : recherche '%s' attend les packs a %.1f min : %s", f.key or "?", tostring(tech), minutes,
      Lc.text(list)))
  end
  return list
end

return Lj
