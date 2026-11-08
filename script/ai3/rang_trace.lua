--[[
  Lot VIDEO-TRACES, partie a (G34) : journal [FO-RANG] du rang de la décision. Appelé par decide_finish (script/ai3/capitalisation.lua)
  avec le résultat de Ca.decide, qui porte le rang de Rg.chain (res.rang, shared/ai3/capitalisation.lua). Une ligne par
  (faction, signature changée) : une seule chaîne par faction, dans Storage (jamais de table neuve par pensée). Rien ne décide
  d'après ce journal. La règle (Rg.signature, Rg.text_chain) est pure : shared/ai3/rang.lua, tests/rang_trace_test.lua.
]]

local Rg = require("shared.ai3.rang")
local Storage = require("script.core.storage")

local M = {}

Storage.declare("rang_trace", function() return { sig = {} } end)

--- Un relevé de décision. R = rang de la décision (Rg.chain, J.ctx.rang), nil si la décision n'en a pas calculé.
--- Rend vrai si une ligne a été écrite.
function M.note(f, R, tick)
  if not R then return false end
  local key = tostring(f.key or "player")
  local sigs = Storage.ns("rang_trace").sig
  local sig = Rg.chain_signature(R)
  if sigs[key] == sig then return false end
  sigs[key] = sig
  log(Rg.text_chain(R, key) .. string.format(" a %.1f min", tick / 3600))
  return true
end

--- Lot CONSOLIDATION-TIERS : lignes d'attente, de consolidation et de levée d'une décision (J.ctx.cons_log, texte sans préfixe). Une ligne par
--- événement (la règle les a dédoublonnés : Pr.solid_mark, Pr.solid_step). Rend le nombre de lignes écrites.
function M.attentes(f, lines, tick)
  local n = 0
  for _, text in ipairs(lines or {}) do
    log(string.format("[FO-RANG] %s : %s a %.1f min", tostring(f.key or "player"), text, tick / 3600))
    n = n + 1
  end
  return n
end

return M
