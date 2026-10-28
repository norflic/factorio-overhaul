--[[
  Lot ENERGIE : choix de la SOURCE d'énergie d'une équipe. Règle PURE (aucune API Factorio, aucun nom d'objet : tests/iag_test.lua
  §8), déterministe, testée hors jeu par tests/generation_test.lua (avec mutants).

  Entrée : une liste de candidats lus aux PROTOTYPES (type du moteur, puissance nominale) et aux gabarits de pose :
    { name, kind (type du prototype), kw (puissance nominale d'une unité posée), cost = { { objet, n } } (tout compris : de quoi
      poser l'unité), template = vrai si un gabarit de pose existe (un exécutant), missing = { objets que l'équipe ne sait pas
      obtenir (technologie) } }
  `price(objet)` : prix d'un objet en unités de coût (MU), 1 par défaut.
  Sortie : { pick = meilleur candidat ou nil, ranked = liste triée (valeur décroissante), rejected = { { name, reason } } }.
  Valeur = kW / coût : un candidat sans gabarit de pose, sans puissance ou dont un objet manque est ÉCARTÉ avec sa raison
  (journalisée), jamais choisi en silence.
]]
local G = {}

local function cost_of(cost, price)
  local c = 0
  for _, it in ipairs(cost or {}) do c = c + (it[2] or 0) * (price and price(it[1]) or 1) end
  return c
end

function G.choose(cands, price)
  local ranked, rejected = {}, {}
  for _, c in ipairs(cands or {}) do
    local reason
    if not c.template then reason = "pas de gabarit de pose"
    elseif (c.kw or 0) <= 0 then reason = "puissance nulle"
    elseif c.missing and #c.missing > 0 then reason = "objets impossibles : " .. table.concat(c.missing, ",")
    elseif cost_of(c.cost, price) <= 0 then reason = "coût inconnu" end
    if reason then
      rejected[#rejected + 1] = { name = c.name, kind = c.kind, reason = reason, kw = c.kw }
    else
      local mu = cost_of(c.cost, price)
      ranked[#ranked + 1] = { name = c.name, kind = c.kind, kw = c.kw, cost_mu = mu, value = c.kw / mu, cand = c }
    end
  end
  table.sort(ranked, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.name < b.name
  end)
  table.sort(rejected, function(a, b) return a.name < b.name end)
  return { pick = ranked[1], ranked = ranked, rejected = rejected }
end

--- Ligne de journal d'un choix (le NOM est lu aux candidats, jamais écrit ici).
function G.describe(res)
  local parts = {}
  for _, r in ipairs(res.ranked) do parts[#parts + 1] = string.format("%s(%s %.0f kW, %.1f kW/MU)", r.name, r.kind, r.kw, r.value) end
  local rej = {}
  for _, r in ipairs(res.rejected) do rej[#rej + 1] = string.format("%s(%s : %s)", r.name, r.kind or "?", r.reason) end
  return string.format("choix %s ; candidats [%s] ; ecartes [%s]", res.pick and res.pick.name or "aucun",
    table.concat(parts, " "), table.concat(rej, " "))
end

return G
