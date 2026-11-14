--[[ s46 saturer2 : l'ordre du joueur (Maj+A, o.sat_req) passe la porte des chantiers EN TETE. Lua pur.
  Un avant-poste marqué sat_req (script/gui/commande.lua) nomme sa ressource (o.kind). Le PREMIER ordre « couvrir » / « ouvrir » de
  cette ressource (une bande à la fois, un seul ordre par ressource) est placé en tête de la liste, les autres gardent leur ordre :
  Pe.filter donne la place de chantier aux premiers. ]]
local St = {}

St.KINDS = { couvrir = true, ouvrir = true }

--- wanted = { [ressource] = vrai } ; rend une NOUVELLE liste (stable), et le nombre d'ordres avancés.
function St.head(orders, wanted)
  local head, rest, taken = {}, {}, {}
  for _, o in ipairs(orders or {}) do
    local r = o.resource
    if r ~= nil and St.KINDS[o.kind] and (wanted or {})[r] and not taken[r] then
      taken[r] = true
      head[#head + 1] = o
    else
      rest[#rest + 1] = o
    end
  end
  local n = #head
  for _, o in ipairs(rest) do head[#head + 1] = o end
  return head, n
end

--- Ressources demandées par les avant-postes (liste triée de clés : jamais l'ordre de pairs).
function St.wanted(outposts, keys)
  local w = {}
  for _, k in ipairs(keys or {}) do
    local o = outposts[k]
    -- borne : tant que le drapeau tient (l'avant-poste redevenu plein ne passe plus en tête)
    if o and o.sat_req and not o.full and o.kind ~= nil then w[o.kind] = true end
  end
  return w
end

return St
