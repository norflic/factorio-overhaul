--[[
  DÉDOUBLONNAGE DES COFFRES D'UN PROJET (lot MESURE-MODULE, 8/11/2026). Règle PURE (Lua sans moteur, tests/sites_dedup_test.lua).

  Le défaut : script/team/build.lua, plan_feed, AJOUTE à p.quais (coffres d'entrée) et p.outs (coffres de sortie) à chaque plan ; quand
  un plan attend (couloir de poteaux pas encore relevé, réseau d'un autre projet, centrale lointaine) puis recommence, le chef ne
  remettait que p.ents et p.parts à zéro. Un module dont le plan a attendu trois fois portait donc quatre copies de son coffre de
  sortie (journal du DC, packs rouges, projet 3 : « essai 1, 2, 3 : le projet attend la suite », puis le plan) : quatre tâches de
  collecte du même coffre, un « dort » à 4 fois le contenu, un quota calculé pour quatre coffres.

  Ici : repérer et retirer les copies (même position ; pour un quai, même objet) en gardant la PREMIÈRE, dans l'ordre. La position
  est comparée en 1/256 de tuile (virgule fixe du moteur, F92).
]]

local D = {}

local floor = math.floor

--- Clé d'un coffre de sortie : sa position en 1/256.
function D.out_key(o)
  return floor((o.x or 0) * 256 + 0.5) .. "," .. floor((o.y or 0) * 256 + 0.5)
end

--- Clé d'un coffre d'entrée : sa position en 1/256 et son objet.
function D.quai_key(q)
  return D.out_key(q) .. "|" .. tostring(q.item)
end

--- Nombre de copies en trop dans `list` pour la clé `keyf`.
function D.count_dups(list, keyf)
  local seen, n = {}, 0
  for _, e in ipairs(list or {}) do
    local k = keyf(e)
    if seen[k] then n = n + 1 else seen[k] = true end
  end
  return n
end

--- Liste sans copies (la première de chaque clé reste), nombre retiré. Une copie qui porte un champ que la première n'a pas
--- (`at`, seuil de collecte d'une inscription ultérieure) le lui donne. Ne modifie pas `list`.
function D.dedupe(list, keyf)
  local out, at_key, removed = {}, {}, 0
  for _, e in ipairs(list or {}) do
    local k = keyf(e)
    local first = at_key[k]
    if first then
      removed = removed + 1
      for fk, fv in pairs(e) do
        if first[fk] == nil then first[fk] = fv end
      end
    else
      local c = {}
      for fk, fv in pairs(e) do c[fk] = fv end
      out[#out + 1] = c
      at_key[k] = c
    end
  end
  return out, removed
end

--- Comme D.dedupe, et rend aussi la table de passage { [ancien indice] = nouvel indice } (toutes les copies d'un coffre passent à
--- l'indice de la première gardée). Les indices servent de clé aux tâches du tableau (ia1d:<projet>:o|q:<indice>).
function D.remap(list, keyf)
  local out, at_key, map, removed = {}, {}, {}, 0
  for i, e in ipairs(list or {}) do
    local k = keyf(e)
    local first = at_key[k]
    if first then
      removed = removed + 1
      map[i] = first.idx
      for fk, fv in pairs(e) do
        if first.e[fk] == nil then first.e[fk] = fv end
      end
    else
      local c = {}
      for fk, fv in pairs(e) do c[fk] = fv end
      out[#out + 1] = c
      at_key[k] = { e = c, idx = #out }
      map[i] = #out
    end
  end
  return out, map, removed
end

--- Sort des tâches du tableau d'un projet après un dédoublonnage. entries : liste TRIÉE par clé de { key, mode ("collect" pour p.outs,
--- "fill" pour p.quais), idx, taken (vrai si un PNJ la porte) } ; map_o, map_q : tables de passage de D.remap. Rend, pour chaque
--- entrée, { key, action = "keep" | "drop", idx (nouvel indice), newkey } :
---   - par (mode, nouvel indice) UNE tâche reste : la prise de préférence, sinon la première par clé ; les autres libres sont jetées ;
---   - une tâche prise n'est jamais jetée (le PNJ la porte) : elle passe à son nouvel indice ;
---   - une tâche libre dont l'indice n'existe plus est jetée, une prise reste telle quelle.
function D.plan_tasks(entries, map_o, map_q, pid)
  local out, winner = {}, {}
  local function map_of(mode) return mode == "collect" and map_o or (mode == "fill" and map_q or nil) end
  local function letter(mode) return mode == "collect" and "o" or "q" end
  -- gagnant de chaque (mode, nouvel indice)
  for _, en in ipairs(entries) do
    local m = map_of(en.mode)
    local ni = m and m[en.idx]
    if ni then
      local gk = en.mode .. ":" .. ni
      local w = winner[gk]
      if w == nil or (en.taken and not w.taken) then winner[gk] = en end
    end
  end
  for _, en in ipairs(entries) do
    local m = map_of(en.mode)
    local ni = m and m[en.idx]
    if not ni then
      out[#out + 1] = { key = en.key, action = en.taken and "keep" or "drop", idx = en.idx, newkey = en.key }
    else
      local gk = en.mode .. ":" .. ni
      local newkey = "ia1d:" .. tostring(pid) .. ":" .. letter(en.mode) .. ":" .. ni
      if winner[gk] == en or en.taken then
        out[#out + 1] = { key = en.key, action = "keep", idx = ni, newkey = (winner[gk] == en) and newkey or en.key }
      else
        out[#out + 1] = { key = en.key, action = "drop", idx = ni, newkey = newkey }
      end
    end
  end
  return out
end

return D
