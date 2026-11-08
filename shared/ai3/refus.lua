--[[
  Lot VIDEO-REFUS (C6, fo-logs/2026-11-07_VIDEO-COUVERTURE/DIAG_CONSO.md §3) : décompte des refus de la décision PAR SORTE.
  PUR : aucune API Factorio. Entrée : res.refus de Ca.decide (liste de { key, kind, item, why }, un refus par clé). Le journal
  [FO-CAPI] n'en montrait que 6 (alphabétiques) : ce décompte donne le nombre par sorte, somme exacte = nombre de refus.

  Sortes (ordre FIXE, celui de la ligne du journal) : goulot amont, budget, bras, plafond, confirmation, emplacements, rang,
  portes, autre. « autre » est là pour que la somme reste exacte : menace, danger, exécutant, courant, laboratoires, etc.
  Chaque raison tombe dans UNE sorte, par la première règle qui la reconnaît (ordre des règles ci-dessous).

  Aucune décision n'est prise ici : la fonction ne fait que lire les raisons. Aucun `pairs`, aucun hasard, aucun temps mesuré.
]]

local Rf = {}

Rf.SORTS = { "goulot amont", "budget", "bras", "plafond", "confirmation", "emplacements", "rang", "portes", "autre" }

-- Règles dans l'ordre : la première qui reconnaît la raison décide. Chaque règle : { sorte, motif Lua }.
local RULES = {
  { "confirmation", "^confirmation :" },
  { "rang", "^rang :" },
  { "rang", "^rang %d+ :" },                    -- lot CONSOLIDATION-TIERS : « rang r : chaine X de rang k non consolidee : ... »
  { "rang", "^anti%-repetition" },
  { "portes", "chantier%(s%)" },                -- porte d'extension : « bras : N chantier(s) … » (portes_extension.lua:103)
  { "portes", "^transport sature" },
  { "portes", "^repetition :" },
  { "budget", "^budget :" },
  { "budget", "^impayable" },
  { "budget", "^retour " },
  { "bras", "^bras :" },
  { "plafond", "^plafond " },
  { "plafond", "^plafond$" },                   -- raison nue de capitalisation (cap_ok sans détail)
  { "plafond", "^ordres ouverts" },
  { "emplacements", "^aucune place" },
  { "emplacements", "^gisement voisin" },
  { "emplacements", "^gisements ouverts pas couverts" },
  { "goulot amont", "^entree " },
  { "goulot amont", "^manque sous une demi%-machine" },
}

--- Sorte d'une raison (texte). Rend le nom de sorte (un élément de Rf.SORTS) ; « autre » si aucune règle ne la reconnaît.
function Rf.sort_of(why)
  local s = tostring(why or "")
  for _, r in ipairs(RULES) do
    if s:find(r[2]) then return r[1] end
  end
  return "autre"
end

--- Décompte par sorte : table { [sorte] = nombre } dont les clés sont exactement Rf.SORTS. refus = liste de { why = … }.
function Rf.count(refus)
  local out = {}
  for _, name in ipairs(Rf.SORTS) do out[name] = 0 end
  for _, r in ipairs(refus or {}) do
    local k = Rf.sort_of(r.why)
    out[k] = out[k] + 1
  end
  return out
end

--- Total des sorte d'un décompte (somme exacte, dans l'ordre fixe).
function Rf.total(counts)
  local n = 0
  for _, name in ipairs(Rf.SORTS) do n = n + (counts[name] or 0) end
  return n
end

--- Ligne du journal [FO-CAPI-REFUS] : une sorte par champ, dans l'ordre fixe, puis le total. who = clé de la faction, minute = entier.
function Rf.line(who, minute, refus)
  local c = Rf.count(refus)
  local parts = {}
  for _, name in ipairs(Rf.SORTS) do parts[#parts + 1] = name .. " " .. c[name] end
  return string.format("[FO-CAPI-REFUS] %s minute %d : %s ; total %d", tostring(who), minute, table.concat(parts, ", "), Rf.total(c))
end

return Rf
