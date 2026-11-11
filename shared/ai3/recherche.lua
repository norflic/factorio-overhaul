--[[
  IA3-a « RIEN D'IMPAYABLE » (docs/IA3_CERVEAU.md §6.2) : règle PURE de payabilité d'un niveau de recherche, lue par
  script/ai3/cerveau.lua. Un niveau dont un pack est IMPAYABLE (pack non fabricable à la main, ou matière première
  qu'aucune source ne fournit) ne fait fabriquer AUCUN pack (critère K6 : 0 fabrication jetée ; défaut C1).

  A.level_status(book, packs, obtainable) -> payable, causes.
  Aucun nom d'objet du jeu : les packs viennent de la table des niveaux de l'appelant, les matières du livre de
  recettes (shared/team/book.lua). Listes triées ; aucun hasard ; aucun pairs décisionnel.
]]

local A = {}

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Un niveau est-il PAYABLE ? Chaque pack doit être fabricable à la main (livre : recette active, catégorie de la
--- main) et chaque matière première de son coût doit avoir une source (obtainable(matière) vrai). Renvoie payable,
--- causes (liste triée des packs ou matières en défaut).
function A.level_status(book, packs, obtainable)
  local causes = {}
  for _, it in ipairs(packs) do
    if not book:handcraftable(it[1]) then causes[it[1]] = true end
  end
  if next(causes) == nil then
    local raw = book:raw_cost(packs)
    for _, r in ipairs(sorted_keys(raw)) do
      if not obtainable(r) then causes[r] = true end
    end
  end
  local list = sorted_keys(causes)
  return #list == 0, list
end

return A
