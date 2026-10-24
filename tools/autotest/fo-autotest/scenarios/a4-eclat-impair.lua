-- Scénario greffé du lot A4 : a4-eclat avec les captures décalées d'UN tick (shots_delay + 1). Une capture toutes les
-- 10 ticks ne voit que 3 des 6 phases de la cadence de tir (6 ticks) ; avec a4-eclat, les 6 phases sont couvertes.
--   & "<racine>\fo-captures.bat" a4-eclat-impair "<source>"
local base = require("scenarios/a4-eclat")
local t = {}
for k, v in pairs(base) do t[k] = v end
t.description = base.description .. " (captures decalees d'un tick)"
t.shots_delay = base.shots_delay + 1
return t
