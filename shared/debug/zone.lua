--[[
  Lot DEBUG-CERVEAU (demande du DC, 8/11) : état RÉEL d'une zone, règle PURE (testée hors jeu : tests/debug_cerveau_test.lua).
  Une zone est un projet du plan directeur (module, fonderie, laboratoires, centrale, bande du champ...) ou un avant-poste. Le
  runtime (script/debug/lecture.lua) compte les statuts des machines de la zone ; ce fichier en tire la couleur et la cause :
    vert    en marche (au moins Zn.OK_RATIO des machines travaillent, aucune pièce manquante) ;
    orange  dégradé (une partie seulement travaille, une pièce manque) ou chantier bloqué qui reprendra ;
  Cause « courant » : SEULEMENT des machines du module sans alimentation (règle du DC, 11/11, lot DBG-COURANT) ; un bras sans courant n'en est pas une.
    rouge   arrêté (aucune machine ne travaille) ;
    gris    prévu, en construction, refusé, ou fini mais sans machine à mesurer. JAMAIS vert sans mesure.
  Entrée z : { state = état du projet (attente, plan, reserve, defrichage, fantomes, chantier, raccordement, fini, refuse, bloque),
    machines = { [cause] = n } ou nil (cause « marche » pour les machines qui travaillent ; sinon une clé de Zn.CAUSES),
    lost = pièces posées qui ont disparu }.
  Sortie : { color, cause (clé de Zn.CAUSES ou d'un état), ratio (0..1 ou nil), n (machines mesurées), top = { { cause, n }... } triées }.
  Fermé par défaut : un état inconnu ou une entrée absente rend gris. Aucun nom du jeu ici. Aucun hasard, aucun temps.
]]

local Zn = {}

Zn.OK_RATIO = 0.8
Zn.RUN = "marche"
-- Causes d'arrêt d'une machine, dans l'ordre de départage à égalité (la première gagne).
Zn.CAUSES = { "courant", "combustible", "entree", "sortie", "gisement", "pieces", "autre" }
Zn.BUILD = { attente = true, plan = true, reserve = true, defrichage = true, fantomes = true, chantier = true, raccordement = true }
Zn.COLORS = { "vert", "orange", "rouge", "gris" }

local ORDER = {}
for i, c in ipairs(Zn.CAUSES) do ORDER[c] = i end

local function num(v) return type(v) == "number" and v == v and v >= 0 and v or 0 end

--- Causes triées par effectif décroissant, puis par ordre de Zn.CAUSES (déterminisme).
local function ranked(machines, lost)
  local list = {}
  for _, c in ipairs(Zn.CAUSES) do
    local n = num(machines and machines[c])
    if c == "pieces" then n = n + num(lost) end
    if n > 0 then list[#list + 1] = { cause = c, n = n } end
  end
  table.sort(list, function(a, b)
    if a.n ~= b.n then return a.n > b.n end
    return ORDER[a.cause] < ORDER[b.cause]
  end)
  return list
end

function Zn.classify(z)
  if type(z) ~= "table" or type(z.state) ~= "string" then return { color = "gris", cause = "inconnu", n = 0, top = {} } end
  local st = z.state
  if Zn.BUILD[st] then return { color = "gris", cause = st, n = 0, top = {} } end
  if st == "refuse" then return { color = "gris", cause = "refuse", n = 0, top = {} } end
  if st == "bloque" then return { color = "orange", cause = "bloque", n = 0, top = {} } end
  if st ~= "fini" then return { color = "gris", cause = "inconnu", n = 0, top = {} } end
  local m = z.machines
  local run, total = num(m and m[Zn.RUN]), 0
  for _, c in ipairs(Zn.CAUSES) do total = total + num(m and m[c]) end
  total = total + run
  local top = ranked(m, z.lost)
  if total == 0 then
    -- aucune machine mesurée : des pièces manquantes se voient quand même, jamais un vert
    if #top > 0 then return { color = "orange", cause = top[1].cause, n = 0, top = top } end
    return { color = "gris", cause = "non_mesure", n = 0, top = {} }
  end
  local ratio = run / total
  local degraded = num(z.lost) > 0 -- une pièce manquante dégrade même si les machines tournent
  if ratio == 0 then return { color = "rouge", cause = top[1] and top[1].cause or "autre", ratio = 0, n = total, top = top } end
  if ratio >= Zn.OK_RATIO and not degraded then return { color = "vert", ratio = ratio, n = total, top = {} } end
  return { color = "orange", cause = top[1] and top[1].cause or "autre", ratio = ratio, n = total, top = top }
end

--- Correspondance d'un statut du moteur (nom de defines.entity_status) vers la cause de Zn.CAUSES, ou Zn.RUN. Les noms sont ceux de l'API
--- 1.1.91 (doc-html/runtime-api.json, defines.entity_status) ; tout statut non listé est « autre » (jamais « marche » par défaut).
Zn.STATUS = {
  working = Zn.RUN, normal = Zn.RUN,
  no_power = "courant", low_power = "courant",
  no_fuel = "combustible",
  no_ingredients = "entree", fluid_ingredient_shortage = "entree", item_ingredient_shortage = "entree", missing_required_fluid = "entree",
  missing_science_packs = "entree", waiting_for_source_items = "entree",
  full_output = "sortie", waiting_for_space_in_destination = "sortie",
  no_minable_resources = "gisement",
}

function Zn.cause_of_status(name)
  if type(name) ~= "string" then return "autre" end
  return Zn.STATUS[name] or "autre"
end

return Zn
