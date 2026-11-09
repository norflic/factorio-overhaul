--[[
  Lot RECHERCHE-BRAS (A) : OBJETS VOULUS par un module quelconque (mall, amélioration, pétrole, robots…), un seul point d'entrée.

  Le cerveau général (shared/ai3/general.lua) donne de la valeur à la technologie qui débloque un OBJET voulu (V_WANTED, chaîne vers
  l'objet), et depuis la décision du DC du 8/11 (« Oui, voulue proche devant ») une voulue PROCHE (elle ouvre l'objet, ou une chaîne
  de Gen.K1_FRONT technologies au plus) passe devant les paliers qui ne sont pas la première consommation d'un pack. Un module qui veut
  une recherche déclare donc l'OBJET que cette recherche ouvre (jamais le nom d'une technologie : la même règle vaut pour tous les
  jeux de données et pour l'anti-échelle d'iag_test) :

    Voulues.set(f, source, items, tick)   déclare (remplace) la liste d'objets de `source` (nom du module, libre) ; items = liste de noms
                                          d'objets ou table { [objet] = vrai } ; une liste vide retire la source
    Voulues.clear(f, source)              retire la source
    Voulues.wanted(f)                     { [objet] = vrai } de toutes les sources, ou nil s'il n'y en a aucune (lu par
                                          script/ai3/cerveau.lua, research_step, avec Auto.wanted / Capital.wanted / Pet.wanted)

  Exemple (mall, D5) : les objets des types « logistique » du jeu (répartiteur, souterrain), trouvés par le TYPE de prototype ; dès que
  la centrale produit et que le fer et le cuivre sont automatisés, `Voulues.set(f, "mall", items, tick)`.
  État : f.team.ia3.voulues = { [source] = { tick, items = liste triée } } (données seules, sérialisable, jamais de fonction).
  Déterminisme : sources et objets parcourus triés.
]]
local Voulues = {}

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function ia3(f)
  return f and f.team and f.team.ia3 or nil
end

--- Liste triée et sans doublon des noms d'objets de `items` (liste ou table { [objet] = vrai }).
function Voulues.normalize(items)
  local set = {}
  if type(items) == "table" then
    for k, v in pairs(items) do
      if type(k) == "number" and type(v) == "string" then set[v] = true
      elseif type(k) == "string" and v == true then set[k] = true end
    end
  end
  return sorted_keys(set)
end

--- Déclare (remplace) les objets voulus de `source`. Rend vrai si l'état a changé.
function Voulues.set(f, source, items, tick)
  local st = ia3(f)
  if not st or type(source) ~= "string" then return false end
  local list = Voulues.normalize(items)
  if #list == 0 then return Voulues.clear(f, source) end
  st.voulues = st.voulues or {}
  local cur = st.voulues[source]
  if cur and table.concat(cur.items, ",") == table.concat(list, ",") then return false end
  st.voulues[source] = { tick = tick or 0, items = list }
  return true
end

--- Retire `source`. Rend vrai si elle existait.
function Voulues.clear(f, source)
  local st = ia3(f)
  if not (st and st.voulues and st.voulues[source]) then return false end
  st.voulues[source] = nil
  if next(st.voulues) == nil then st.voulues = nil end
  return true
end

--- Objets voulus de toutes les sources : { [objet] = vrai }, ou nil.
function Voulues.wanted(f)
  local st = ia3(f)
  if not (st and st.voulues) then return nil end
  local out, any = {}, false
  for _, src in ipairs(sorted_keys(st.voulues)) do
    for _, it in ipairs(st.voulues[src].items) do out[it] = true; any = true end
  end
  return any and out or nil
end

return Voulues
