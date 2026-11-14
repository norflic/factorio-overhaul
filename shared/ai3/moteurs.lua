--[[
  s44 moteurs : les intermédiaires que la MAIN ne sait pas fabriquer (recette hors catégorie de la main, lue dans le relevé
  shared/ai3/lecture.lua : e.main faux) n'ont jamais de charge à la main ; la règle d'automatisation (A.decide : « charge <= 0.25 PNJ »)
  ne les automatise donc jamais, et le mall ne les demande que si un projet du plan directeur les porte. Partie du DC 0.7.102 :
  verdict « non*(d3, charge 0.00 PNJ <= 0.25) » de 74 à 162 min, aucune ligne [FO-CUMUL] de l'objet en 2 h 30, améliorations
  de foreuses « decide mais non paye » faute de 2 pièces au coffre (74 min), kit de robot du mall « manque 1 » de 111 à 127 min.
  Règle : un intermédiaire (au moins une AUTRE recette du relevé le consomme : bâtiments et technologies à venir) dont la recette est
  débloquée, hors main, posable en patron, sans fluide, à un seul produit, et dont tous les ingrédients sont utilisables, est demandé
  au mall dès le déblocage, borné par un stock tampon Mo.STOCK (la demande s'éteint au tampon atteint). Aucun nom en dur.
  Lua pur, déterministe (recettes triées).
]]

local Mo = {}

Mo.SRC = "moteur" -- source de la demande du mall (Ml.want)
Mo.STOCK = 20 -- stock tampon visé (pièces au coffre)
Mo.HORIZON_MIN = 10 -- minutes pour faire le tampon (débit demandé = manque / horizon)
Mo.MAX = 3 -- objets demandés au plus par passe

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- fab : relevé (L.read) ; enabled(recette) -> bool ; usable(objet) -> bool ; have(objet) -> nombre au coffre.
--- Rend la liste triée { { item, recipe, need, rate, users } }.
function Mo.wants(fab, enabled, usable, have)
  local out = {}
  if type(fab) ~= "table" then return out end
  local names = sorted_keys(fab)
  -- consommateurs de chaque objet (toutes les recettes du relevé, débloquées ou non : les âges suivants comptent)
  local users = {}
  for _, rn in ipairs(names) do
    for _, i in ipairs(fab[rn].solides or {}) do
      users[i.name] = users[i.name] or {}
      users[i.name][rn] = true
    end
  end
  local seen = {}
  for _, rn in ipairs(names) do
    local e = fab[rn]
    local item = e.produits and #e.produits == 1 and e.produits[1] or nil
    if item and not seen[item] and not e.main and e.patronnable and #(e.fluides_in or {}) == 0 and #(e.solides or {}) > 0
      and enabled and enabled(rn) then
      local ok = true
      for _, i in ipairs(e.solides) do
        if i.name == item or not (usable and usable(i.name)) then ok = false break end
      end
      local n_users = 0
      for u in pairs(users[item] or {}) do if u ~= rn then n_users = n_users + 1 end end
      if ok and n_users > 0 then
        seen[item] = true
        local need = Mo.STOCK - math.floor((have and have(item)) or 0)
        if need > 0 then
          out[#out + 1] = { item = item, recipe = rn, need = need, rate = need / Mo.HORIZON_MIN, users = n_users }
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.users ~= b.users then return a.users > b.users end
    return a.item < b.item
  end)
  while #out > Mo.MAX do out[#out] = nil end
  return out
end

--- Pose la demande au mall (Ml injecté) : une demande fraîche d'une autre source à débit au moins égal est gardée.
--- s45 freeze : mémo d'une fonction à un argument pour UNE passe (Stock.count lit le QG et chaque annexe au moteur ; Mo.wants
--- l'appelait pour chaque ingrédient de chaque recette du relevé, plusieurs fois le même objet). Valeur nil gardée aussi.
function Mo.memo(fn)
  local cache, done = {}, {}
  return function(k)
    if done[k] then return cache[k] end
    local v = fn(k)
    done[k], cache[k] = true, v
    return v
  end
end

function Mo.seed(st, tick, list, Ml)
  local n = 0
  for _, w in ipairs(list or {}) do
    local cur = st.want and st.want[w.item]
    local fresh = cur and (tick - (cur.tick or 0) <= (Ml.WANT_TTL or 0))
    if not (fresh and cur.src ~= Mo.SRC and (cur.rate or 0) >= w.rate) then
      if Ml.want(st, tick, w.item, w.rate, Mo.SRC) then n = n + 1 end
    end
  end
  return n
end

return Mo
