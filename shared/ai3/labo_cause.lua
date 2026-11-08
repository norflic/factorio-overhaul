--[[
  Lot BLOCAGE-LABOS (8/11) : POURQUOI une recherche d'équipe n'avance pas. Règle PURE (aucune API Factorio, AUCUN nom d'objet : anti-échelle de
  tests/iag_test.lua ; tests/labo_cause_test.lua).

  Contexte : la recherche des équipes est virtuelle (script/ai3/cerveau.lua, research_step) : une unité n'est payée que si le COFFRE
  porte tous ses packs. Quand rien n'avance, le journal ne disait pas quel pack manquait ni si on pouvait le fabriquer (mesure du 8/11 :
  labos physiques à 0 % chez les cinq forces, cause réelle = pack chimique impayable, site de pétrole refusé).

  Entrée de Lc.diagnose(input) :
    ingredients : { { pack, n } }   packs d'UNE unité de la recherche en cours
    stock       : { [pack] = n }    coffre (stock libre)
    incoming    : { [pack] = n }    packs en cours de fabrication ou de transport (facultatif)
    feasible    : function(pack) -> vrai | faux | nil   le pack est-il fabricable par cette équipe (graphe) ; nil : inconnu
    reason      : function(pack) -> texte | nil          raison connue d'un pack impayable (site refusé, ressource inconnue…)
  Sortie : liste triée par pack de { pack, kind, need, have, incoming, reason } ; kind :
    "stock"      le coffre couvre une unité : pas un blocage
    "en_cours"   le coffre ne couvre pas, mais le stock plus ce qui est en route la couvre : attendre
    "fabricable" absent, fabricable : une fabrication doit venir
    "impayable"  absent ET non fabricable : le blocage ; sa raison est jointe
    "inconnu"    absent, fabricabilité inconnue
  Lc.blocking(list) rend les entrées qui bloquent (tout sauf "stock"). Lc.signature(list) : chaîne stable, pour ne journaliser qu'AU CHANGEMENT.
  Lc.text(list) : « pack X ni en stock ni fabricable (raison) ; pack Y fabricable, attendu (0/2) ».
  Déterminisme : listes triées, aucun pairs décisionnel, aucune horloge.
]]

local Lc = {}

local function sorted_copy(list)
  local out = {}
  for i, v in ipairs(list or {}) do out[i] = v end
  table.sort(out, function(a, b) return a.pack < b.pack end)
  return out
end

function Lc.diagnose(input)
  local stock, incoming = input.stock or {}, input.incoming or {}
  local out = {}
  for _, ing in ipairs(input.ingredients or {}) do
    local pack, need = ing[1], ing[2]
    local have, coming = stock[pack] or 0, incoming[pack] or 0
    local kind
    if have >= need then
      kind = "stock"
    elseif have + coming >= need then
      kind = "en_cours"
    else
      local ok = input.feasible and input.feasible(pack)
      if ok == true then kind = "fabricable"
      elseif ok == false then kind = "impayable"
      else kind = "inconnu" end
    end
    out[#out + 1] = { pack = pack, kind = kind, need = need, have = have, incoming = coming,
      reason = kind == "impayable" and input.reason and input.reason(pack) or nil }
  end
  return sorted_copy(out)
end

function Lc.blocking(list)
  local out = {}
  for _, e in ipairs(list or {}) do if e.kind ~= "stock" then out[#out + 1] = e end end
  return out
end

function Lc.signature(list)
  local parts = {}
  for _, e in ipairs(Lc.blocking(list)) do parts[#parts + 1] = e.pack .. ":" .. e.kind .. ":" .. (e.reason or "") end
  return table.concat(parts, "|")
end

function Lc.text(list)
  local parts = {}
  for _, e in ipairs(Lc.blocking(list)) do
    local s
    if e.kind == "impayable" then
      s = string.format("pack %s ni en stock ni fabricable%s", e.pack, e.reason and (" (" .. e.reason .. ")") or "")
    elseif e.kind == "fabricable" then
      s = string.format("pack %s fabricable, attendu (%d/%d)", e.pack, e.have, e.need)
    elseif e.kind == "en_cours" then
      s = string.format("pack %s en route (%d+%d/%d)", e.pack, e.have, e.incoming, e.need)
    else
      s = string.format("pack %s absent, fabricabilite inconnue (%d/%d)", e.pack, e.have, e.need)
    end
    parts[#parts + 1] = s
  end
  return table.concat(parts, " ; ")
end

return Lc
