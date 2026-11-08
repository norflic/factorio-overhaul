--[[
  Lot TV-PILOTE, point D02 de docs/TODO_VIDEO.md (« Pour transplanter la racine : le livre, une pile de barils d'huile lourde, au moins un
  robot logistique » : la liste MINIMALE d'amorçage est explicite). La liste de départ d'une équipe de PNJ, ÉCRITE en code, à côté du
  compteur d'amorce (shared/ai3/amorce.lua, Am.supplied, Am.kit_report). PUR (aucune API Factorio). Les NOMS d'objets sont ici, dans
  shared/team (donnée du mod), jamais dans shared/ai3 (test anti-échelle, tests/iag_test.lua §8) : la règle de comparaison (Am.kit_report)
  reçoit cette liste en paramètre.

  Pourquoi si petite : décision du lot KIT (28/10, réponse du DC : « idéalement il faudrait vraiment pas leur donner de ressources : ils ne
  doivent pas avoir plus que le joueur principal, ils doivent eux-mêmes récolter les ressources nécessaires au début »). Le départ réel
  d'une équipe (shared/team/fondation.lua, F.grant) est donc : l'équipement des ouvriers de départ (T.kits.worker, fo-npc-start) et, pour
  les deux équipes (lot PARITE), les tourelles de QG de T.start_hq_turrets. Aucun objet au coffre (T.start_kit est vide), aucun four posé
  (T.start_smelters = 0). Tout le reste est CALCULÉ à l'exécution et non écrit ici : la liste de matériel des Am.K premiers projets du plan
  directeur (Am.bom) et l'amorce de chaque cycle de recettes (Am.seed, Rg.chain) ; ces deux listes sont dans K.COMPUTED, pour que le
  rapport dise ce qui n'est PAS dans la liste explicite.

  Le compteur d'amorce (Am.supplied) dimensionne le vrai kit (C11) : ce que la main a fourni avant la première production d'une machine et
  qui n'est PAS dans cette liste est un candidat au kit ou un défaut de la graine ; Am.kit_report le liste, le journal [FO-AMORCE] l'écrit.
]]

local T = require("shared.team.config")

local K = {}

-- Un élément = { item, n, per, why } : `per` = "ouvrier" (n par ouvrier de départ) ou "equipe" (n pour l'équipe).
K.MINIMAL = {}
for _, it in ipairs(T.kits.worker) do
  K.MINIMAL[#K.MINIMAL + 1] = { item = it[1], n = it[2], per = "ouvrier", why = "equipement de l'ouvrier de depart (T.kits.worker, fo-npc-start)" }
end
K.MINIMAL[#K.MINIMAL + 1] = { item = T.turret, n = T.start_hq_turrets, per = "equipe", why = "tourelles de QG offertes une fois a chaque equipe (lot PARITE, T.start_hq_turrets)" }

-- Ce qui n'est pas écrit mais calculé à l'exécution (dit par le rapport).
K.COMPUTED = {
  "materiel des " .. 3 .. " premiers projets du plan directeur (Am.bom, graine du mall)",
  "amorce de chaque cycle de recettes (Am.seed, rang.lua)",
}

-- Le kit GÉNÉREUX d'avant le lot KIT : bancs seulement (réglage fo-war-kit-genereux), jamais le départ d'une partie.
K.BENCH = T.start_kit_generous

--- Total d'un élément pour une équipe de `workers` ouvriers de départ.
function K.total(el, workers)
  if el.per == "ouvrier" then return el.n * math.max(0, math.floor(workers or 0)) end
  return el.n
end

--- Total par objet de la liste minimale ({ [objet] = n }), pour `workers` ouvriers de départ.
function K.totals(workers)
  local out = {}
  for _, el in ipairs(K.MINIMAL) do out[el.item] = (out[el.item] or 0) + K.total(el, workers) end
  return out
end

return K
