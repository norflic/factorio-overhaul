--[[
  Lot L2 « la porte de rang ciblée » (docs/VIDEO_AUTOMATISATION.md §6 L2, docs/TODO_VIDEO.md §H). PUR (aucune API Factorio),
  testé hors jeu (tests/porte_rang_test.lua). RIEN N'EST BRANCHÉ : la capitalisation garde ses règles d'emplacement.

  Règle : un ordre de production dont la chaîne DÉPEND (même indirectement, par les recettes choisies) d'un objet EN MANQUE
  d'un rang strictement INFÉRIEUR ne prend pas d'emplacement : il attend que ce manque soit servi. Un ordre sans cette
  dépendance passe (la porte n'est pas globale : la vidéo bloque tout rang supérieur, nous connaissons le graphe).
    - un manque SANS ISSUE (aucune option : ni recette, ni machine, ni gisement) ne bloque rien ;
    - les ordres des étages R0 et R1 de la pile (survivre, réparer et protéger) ne sont jamais retenus ;
    - même rang (cycle contracté compris) : pas de blocage.
  Cas mesuré visé (EFFONDREMENT, partie du DC 717152950 en 0.6.51, Ca.blocked_items) : deux modules qui attendaient du fer
  tenaient les deux emplacements du plan directeur ; la foreuse de fer était refusée « plan directeur occupe ». La porte
  retient les modules (ils dépendent du minerai de fer en manque, rang 0) : la foreuse passe.
  ANTI-RÉPÉTITION (gist de l'auteur, l.181-204) : parmi les ordres permis d'un même rang, l'objet posé au tour précédent
  (`last`) est retenu s'il y en a un autre à ce rang ; seul de son rang, il passe quand même.

  Pr.deps(R) : fermeture des dépendances par objet, depuis un rang de décision (Rg.chain : rec, list). deps[i] = { [amont] =
  vrai } le long des recettes choisies (sans l'objet lui-même).
  Pr.decide(input) -> { allowed = { ordres }, held = { { order, cause } }, rstar } avec input = {
    orders = { { key, item, rank, pile } } (dans l'ordre de priorité ; pile = étage de la pile, 0 à 3, nil : 2),
    short = { { item, rank, option } } (manques ; option = vrai : une option existe pour le servir),
    deps = { [objet] = { [amont] = vrai } }, last = objet posé au tour précédent (ou nil) }.
  Aucun nom du jeu ; listes triées, causes départagées par (rang, nom) ; aucun pairs qui décide sans tri.
]]

local Pr = {}

Pr.KEEP_PILE = 1 -- étages de la pile jamais retenus : R0 et R1

--- Fermeture des dépendances, objets dans l'ordre du rang croissant (les ingrédients d'abord, hors cycle).
function Pr.deps(R)
  local deps = {}
  for _, i in ipairs(R.list) do
    local d = {}
    local r = R.rec[i]
    for _, ing in ipairs((r and r.ingredients) or {}) do
      local j = ing.name
      if j ~= i then
        d[j] = true
        for k in pairs(deps[j] or {}) do if k ~= i then d[k] = true end end
      end
    end
    deps[i] = d
  end
  return deps
end

function Pr.decide(input)
  -- Manques qui bloquent : ceux qui ont une option, triés par (rang, nom).
  local def = {}
  for _, s in ipairs(input.short or {}) do
    if s.option and s.item ~= nil and s.rank ~= nil then def[#def + 1] = s end
  end
  table.sort(def, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.item < b.item
  end)
  local rstar = def[1] and def[1].rank or nil
  local deps = input.deps or {}
  local allowed, held = {}, {}
  for _, o in ipairs(input.orders or {}) do
    local cause = nil
    if (o.pile or 2) > Pr.KEEP_PILE and o.rank ~= nil then
      local up = deps[o.item] or {}
      for _, s in ipairs(def) do
        if cause == nil and s.rank < o.rank and up[s.item] then
          cause = string.format("rang : %s (rang %d) d'abord", s.item, s.rank)
        end
      end
    end
    if cause then held[#held + 1] = { order = o, cause = cause } else allowed[#allowed + 1] = o end
  end
  -- Anti-répétition : l'objet du tour précédent cède sa place à un autre objet du même rang.
  local last = input.last
  if last ~= nil then
    local others = {}
    for _, o in ipairs(allowed) do
      if o.item ~= last and o.rank ~= nil then others[o.rank] = true end
    end
    local kept = {}
    for _, o in ipairs(allowed) do
      if o.item == last and o.rank ~= nil and others[o.rank] and (o.pile or 2) > Pr.KEEP_PILE then
        held[#held + 1] = { order = o, cause = "anti-repetition : " .. tostring(last) .. " pose au tour precedent" }
      else
        kept[#kept + 1] = o
      end
    end
    allowed = kept
  end
  return { allowed = allowed, held = held, rstar = rstar }
end

return Pr
