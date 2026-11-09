--[[
  Lot DEFAUTS-DC (9/11, QCM du DC de 12 h 10 : « coffre d'équipe garni automatiquement au départ ») : le STOCK DE DÉPART du coffre d'équipe
  posé d'office (script/team/player_team.lua, PlayerTeam.found_default). DONNÉES + règle pure (aucune API Factorio) : les noms d'objets
  vivent ICI, dans une table de données, jamais dans une décision (shared/ai3, script/ai3 : tests/iag_test.lua).

  Le contenu est EXACTEMENT celui que le banc de la partie du guide posait à la main (tools/autotest/fo-autotest/scenarios/
  verif_guide_common.lua, version 8d1d4ba3, lignes 76-83) : c'est ce stock que toutes les preuves du guide supposaient. Le DC ne garnit plus
  le coffre à la main.

  Une seule fois par partie, sans double garniture : la garniture suit la pose d'office (D.chest_due : aucune équipe, départ pas encore offert)
  et le départ est marqué offert à la fondation de l'équipe (ns.depart_offert) ; si le joueur fonde lui-même l'équipe, le coffre d'office
  n'est jamais posé, donc jamais garni. D.stock_due() est la règle : garnir seulement un coffre posé d'office et pas déjà garni.
]]

local C = {}

--- Stock de départ : { { objet, nombre }, ... }, dans l'ordre de pose. Ne pas l'éditer en jeu : c'est la référence du guide.
C.CONTENTS = {
  { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
  { "pistol", 3 }, { "firearm-magazine", 60 }, { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 },
}

--- Copie du contenu (l'appelant ne modifie jamais la table de référence).
function C.items()
  local out = {}
  for i, it in ipairs(C.CONTENTS) do out[i] = { it[1], it[2] } end
  return out
end

--- Faut-il garnir le coffre ? c = { founded_by_default = le coffre vient d'être posé d'office, garni = déjà garni dans cette partie (ns.depart_garni) }.
--- Rend (vrai/faux, motif).
function C.stock_due(c)
  if not c.founded_by_default then return false, "pas-d-office" end -- coffre fondé par le joueur : il met ce qu'il veut
  if c.garni then return false, "deja-garni" end
  return true, "depart"
end

return C
