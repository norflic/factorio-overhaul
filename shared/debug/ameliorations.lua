--[[
  Lot DEBUG-CERVEAU : catalogue des améliorations qu'une zone pourrait recevoir, et ce que le cerveau en fait. Règle PURE
  (tests/debug_cerveau_test.lua). Demande du DC (8/11) : « comment l'améliorer si la zone est à améliorer, si finalement il y a une tâche
  prévue par exemple pour refill en charbon cette zone, pour remplacer ce coffre de charbon par un input directement avec des convoyeurs,
  pour remplacer ce bras mécanique par un splitter par exemple ».
  RÈGLE D'HONNÊTETÉ : une amélioration que le cerveau n'a pas (exists = false) est écrite « n'existe pas dans le cerveau », quels que soient
  les faits donnés ; la vue ne l'invente jamais. Les absences listées ici sont celles que l'inventaire du 8/11 n'a retrouvées dans aucun
  fichier de script/ ni de shared/ (recherche de « splitter » et « repartiteur » : seulement des pièces posées à la construction du champ,
  champ.lua et shared/team/champ*.lua, jamais un remplacement) ; elles deviennent des lots, et passent à exists = true quand le code existe.
  États : prevue (une décision ou un projet l'envisage) | en_cours | refusee (avec sa raison) | aucune (le mécanisme existe, rien d'envisagé
  maintenant) | inactive (mécanisme éteint par un réglage) | absente (n'existe pas dans le cerveau).
  Sortie de Am.evaluate : liste dans l'ordre du catalogue { key, exists, state, why, owner }.
]]

local Am = {}

-- owner : où vit le mécanisme (lecture de l'inventaire du 8/11, à revoir avec le code) ; note : ce qu'il fait et sa limite.
Am.CATALOGUE = {
  { key = "niveau", exists = true, owner = "script/ai3/capital.lua (Capital.goal, REMPLACER sur place)",
    note = "machine ou bâtiment de niveau supérieur ; choisi par FAMILLE de bâtiments, pas par zone" },
  { key = "tapis", exists = true, owner = "script/team/convoyeurs.lua (Conv.step)",
    note = "tapis de meilleure vitesse sur un tracé de foreuses fini qui sature (fast_replace)" },
  { key = "machine", exists = true, owner = "script/ai3/automatisation.lua (Auto.think, A.decide)",
    note = "passage de la main à la machine pour ce qui revient, par PRODUIT" },
  { key = "liaison", exists = true, owner = "script/team/liaison.lua (Liaison.step)",
    note = "quai d'entrée d'un module relié par tapis au coffre de SORTIE d'un autre module (module à module seulement)" },
  { key = "charbon_tapis", exists = false, owner = nil,
    note = "remplacer un coffre de charbon ravitaillé par les PNJ par une entrée à tapis depuis la foreuse" },
  { key = "bras_repartiteur", exists = false, owner = nil,
    note = "remplacer un bras par un répartiteur (splitter) quand le débit le demande" },
}

local STATES = { prevue = true, en_cours = true, refusee = true, aucune = true, inactive = true }
Am.STATES = { "prevue", "en_cours", "refusee", "aucune", "inactive", "absente" }

--- facts : { [clé du catalogue] = { state = ..., why = ... } } ; une clé sans fait vaut « aucune ».
function Am.evaluate(facts)
  facts = type(facts) == "table" and facts or {}
  local out = {}
  for _, c in ipairs(Am.CATALOGUE) do
    local row = { key = c.key, exists = c.exists, owner = c.owner, note = c.note }
    if not c.exists then
      row.state = "absente"
    else
      local f = facts[c.key]
      if type(f) == "table" and STATES[f.state] then
        row.state, row.why = f.state, f.why
      else
        row.state = "aucune"
      end
    end
    out[#out + 1] = row
  end
  return out
end

--- Les clés du catalogue qui n'existent pas (liste pour l'intégrateur : elle devient des lots).
function Am.absentes()
  local out = {}
  for _, c in ipairs(Am.CATALOGUE) do if not c.exists then out[#out + 1] = c.key end end
  return out
end

return Am
