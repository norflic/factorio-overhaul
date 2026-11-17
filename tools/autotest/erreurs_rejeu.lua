--[[
  N104-ERREURS : REJEU des faits d'une partie par la règle du journal d'erreurs (shared/debug/erreurs_partie.lua), pour les journaux
  d'avant ce lot (bancs 0.9.10, partie du DC) : tools/autotest/erreurs.py reconstitue les faits minute par minute depuis les lignes
  [FO-CAPI], [FO-VAPEUR], [FO-BILAN], [FO-RESERVE], [FO-BLOQUE], [FO-CAPI-ALERTE], [FO-CHAMP-ETAT], [FO-CUL-DETAIL], [FO-RECON],
  [FO-DEFENSE]... et les écrit dans un fichier Lua ; ce rejeu écrit les MÊMES lignes que le mod ([FO-ERREUR-PARTIE], [FO-ERREUR-BILAN]).
  Lancement (racine du mod) : lua5.2 tools/autotest/erreurs_rejeu.lua <faits.lua>
  <faits.lua> rend { { team = "...", minute = M, facts = {...} }, ... } trié par équipe puis minute.
]]
package.path = "./?.lua;" .. package.path
local E = require("shared.debug.erreurs_partie")
local rows = assert(dofile(assert(arg[1], "faits.lua attendu")))
local cfg = E.seuils({ cap = 40 })
local st = {}
for _, r in ipairs(rows) do
  local s = st[r.team]
  if not s then s = E.new(); st[r.team] = s end
  for _, line in ipairs(E.step(s, r.team, r.minute, E.conds(r.facts or {}, cfg), cfg)) do print(line) end
  print(E.bilan(s, r.team, r.minute))
end
