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
-- PIQUAGE (lot PIQUAGE, champ d'état f.build.piquage) : mots fixes de ses verdicts et causes (source : Pq.VERDICT_CODES et Pq.CAUSE_CODES,
-- shared/team/piquage.lua de la branche piquage). Un mot que cette liste ne connaît pas s'affiche « inconnu » (jamais un texte brut).
Am.PQ_VERDICTS = { "attente", "demande", "branche_finie", "repartiteur_pose", "actif", "inerte", "coupe", "refuse", "laisser" }
Am.PQ_CAUSES = { "ok", "releves_insuffisants", "tapis_mixte", "surplus_non_observe", "tuile_impropre", "aucune_place", "trop_loin", "bras_lent",
  "ne_se_paie_pas", "aucune_source", "sortie_plus_rentable", "a_confirmer", "menace", "ennemi", "essais_epuises", "pieces_inconnues",
  "repartiteur_manquant", "repartiteur_a_fabriquer", "remplacement_refuse", "projet_refuse", "projet_rouvert", "livre", "ne_livre_pas" }
local PQV, PQC = {}, {}
for _, v in ipairs(Am.PQ_VERDICTS) do PQV[v] = true end
for _, v in ipairs(Am.PQ_CAUSES) do PQC[v] = true end
-- verdicts qui sont un travail en cours ou prévu
local PQ_BUSY = { demande = true, branche_finie = true, repartiteur_pose = true }

local function pq_word(w, known) return (type(w) == "string" and known[w]) and w or "inconnu" end

--- Quais du piquage d'un projet `pid` : liste { key, i, verdict, cause, tick } triée par numéro de quai. quais : { ["<pid>:q<i>"] = { verdict, cause, tick } }.
function Am.piquage_rows(quais, pid)
  local out = {}
  if type(quais) ~= "table" or pid == nil then return out end
  local prefix = tostring(pid) .. ":q"
  for key, q in pairs(quais) do -- liste triée juste après : l'ordre de pairs ne compte pas
    if type(key) == "string" and key:sub(1, #prefix) == prefix and type(q) == "table" then
      out[#out + 1] = { key = key, i = tonumber(key:sub(#prefix + 1)) or 0, verdict = pq_word(q.verdict, PQV), cause = pq_word(q.cause, PQC), tick = q.tick }
    end
  end
  table.sort(out, function(a, b) if a.i ~= b.i then return a.i < b.i end return a.key < b.key end)
  return out
end

--- Résumé de tous les quais : { state, why = { verdict, cause, n } | nil }. state : en_cours (un quai a un piquage demandé, une branche finie ou un
--- répartiteur posé), refusee (un quai refusé, aucun travail en cours), aucune sinon. why : le quai le plus récent de l'état retenu.
function Am.piquage_summary(quais)
  local best, best_state, cnt = nil, "aucune", { aucune = 0, refusee = 0, en_cours = 0 }
  if type(quais) ~= "table" then return { state = "aucune" } end
  local keys = {}
  for key in pairs(quais) do keys[#keys + 1] = tostring(key) end -- tri juste après
  table.sort(keys)
  for _, key in ipairs(keys) do
    local q = quais[key]
    if type(q) == "table" then
      local v = pq_word(q.verdict, PQV)
      local st = PQ_BUSY[v] and "en_cours" or (v == "refuse" and "refusee" or "aucune")
      local rank = { aucune = 0, refusee = 1, en_cours = 2 }
      if rank[st] > rank[best_state] or (rank[st] == rank[best_state] and st ~= "aucune" and (q.tick or 0) >= ((best and best.tick) or 0)) then
        best_state, best = st, { verdict = v, cause = pq_word(q.cause, PQC), tick = q.tick }
      end
      cnt[st] = cnt[st] + 1
    end
  end
  if best_state == "aucune" then return { state = "aucune" } end
  return { state = best_state, why = { verdict = best.verdict, cause = best.cause, n = cnt[best_state] } }
end

--- Un fait peut déclarer { present = true } : le mécanisme est alors lu dans l'état du jeu (un champ que seul son code écrit) et compte comme
--- existant, quelle que soit la liste ci-dessus. Un fait sans `present` ne fait JAMAIS exister une amélioration absente.
function Am.evaluate(facts)
  facts = type(facts) == "table" and facts or {}
  local out = {}
  for _, c in ipairs(Am.CATALOGUE) do
    local fact = facts[c.key]
    local present = c.exists or (type(fact) == "table" and fact.present == true)
    local row = { key = c.key, exists = present, owner = c.owner, note = c.note, present = (not c.exists) and present or nil }
    if not present then
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
