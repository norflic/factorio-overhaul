--[[
  Lot BOX-UPGRADE (directive du DC du 9/11) : RÉTROFIT INCRÉMENTAL des boxes. « Interdiction de déconstruire une fonderie ou un mall
  pour le refaire ; quand une box passe UPGRADE_REQUISE (nouveau four, assembleur, bras), rétrofit GLISSANT par tranches de 2 à 4
  machines, la box reste EN_COURS et produit sur les tranches non touchées ; remplacement synchronisé machine -> bras d'entrée/sortie ->
  poteau ; priorité dans une box : 1. goulot d'évacuation (bras de sortie, convoyeur d'évacuation), 2. machine, 3. alimentation ;
  zéro inactivité : si le kit d'upgrade manque, la machine actuelle continue ; anti-collision : une unité qui ne passe pas est
  ajournée sans bloquer la box. »
  Règles PURES (aucun moteur, aucun nom d'objet du jeu : tests/box_upgrade_test.lua) ; le moteur est script/team/box_upgrade_rt.lua.

  Entrées de Bu.plan(box, units, kit, cfg) :
    units = { { id, role ("sortie" | "machine" | "entree" | "poteau"), tier_now, tier_target (vitesses lues aux prototypes), item (objet
      du palier cible, 1 par unité), can_place (vrai, faux ou nil = pas encore mesuré), machine (id de la machine servie par un bras ou
      un poteau ; nil = unité « orpheline » : convoyeur d'évacuation, bras de quai…), x, y } } ;
    kit = { [item] = n } : les pièces du palier cible disponibles au stock ;
    cfg = { slice = machines par tranche (2 à 4, Bu.CFG.slice par défaut) }.
  Règles :
    1. Une unité est À MONTER si tier_target > tier_now ; sinon elle est ignorée (déjà au palier). Aucune unité à monter : MAXED.
    2. TRANCHE = `slice` machines (triées par id) AVEC leurs bras et leur poteau (« paire » : 2 machines + 4 bras = une unité de
       production complète, remplacée d'un bloc pour que l'entrée et la sortie suivent la vitesse de la machine ; le reste de la box
       produit pendant ce temps). Dans la tranche, ordre du DC : sortie -> machine -> entree -> poteau, puis id.
    3. Les unités ORPHELINES forment leurs propres tranches (2 × slice unités) : les sorties AVANT les paires (goulot d'évacuation),
       les entrées et les poteaux APRÈS.
    4. can_place == false : l'unité est AJOURNÉE (liste `deferred`) et la tranche continue sans elle ; une tranche vidée disparaît.
       Rien n'est jamais bloqué par une unité ajournée.
    5. KIT : une tranche n'est émise que si le kit la paie ENTIÈREMENT (1 objet par unité) ; la première tranche impayable arrête
       l'émission : `waiting = { item, manque }` (la machine actuelle continue). `total` compte toutes les tranches, payables ou non.
  Bu.next(state, done) : avance d'une tranche, état en nombres { i, n, done } ; rend un NOUVEL état (déterministe, sans effet de bord).
  Déterminisme : tri par rôle puis id, `pairs` seulement pour ramasser des clés ensuite triées ; aucun temps ; aucune fonction stockée.
]]

local Bu = {}

Bu.EN_COURS, Bu.MAXED = "EN_COURS", "MAXED"
Bu.ROLES = { "sortie", "machine", "entree", "poteau" } -- ordre de priorité du DC
Bu.RANK = { sortie = 1, machine = 2, entree = 3, poteau = 4 }
Bu.CFG = { slice = 2, slice_min = 2, slice_max = 4 }

--- L'unité a-t-elle un palier à monter ?
function Bu.todo(u)
  return u ~= nil and u.tier_now ~= nil and u.tier_target ~= nil and u.tier_target > u.tier_now
end

--- Clé d'une box (état f.team.retrofit[clé]).
function Bu.key(box) return tostring(box.kind) .. ":" .. tostring(box.id) end

--- Comparaison d'identifiants (nombres entre eux, sinon chaînes) : jamais une erreur de type.
local function id_lt(a, b)
  if type(a) == "number" and type(b) == "number" then return a < b end
  return tostring(a) < tostring(b)
end

--- Ordre dans une tranche : rang du rôle, puis id.
local function by_priority(a, b)
  local ra, rb = Bu.RANK[a.role] or 9, Bu.RANK[b.role] or 9
  if ra ~= rb then return ra < rb end
  return id_lt(a.id, b.id)
end

--- Machines par tranche, bornées à [slice_min, slice_max].
local function per_slice(cfg)
  local n = (cfg and cfg.slice) or Bu.CFG.slice
  if n < Bu.CFG.slice_min then n = Bu.CFG.slice_min end
  if n > Bu.CFG.slice_max then n = Bu.CFG.slice_max end
  return n
end

--- Découpe `list` (déjà ordonnée) en tranches de `size` unités, ajoutées à `out`.
local function cut(out, list, size)
  local cur = nil
  for _, u in ipairs(list) do
    if not cur or #cur >= size then cur = {} out[#out + 1] = cur end
    cur[#cur + 1] = u
  end
end

--- Tri des unités à monter : machines (par id), satellites par machine servie, orphelines par rôle.
local function split(units)
  local machines, sat, orphans = {}, {}, { sortie = {}, entree = {}, poteau = {} }
  local ids = {}
  for _, u in ipairs(units or {}) do
    if Bu.todo(u) then
      if u.role == "machine" then machines[#machines + 1] = u ids[u.id] = true end
    end
  end
  for _, u in ipairs(units or {}) do
    if Bu.todo(u) and u.role ~= "machine" then
      if u.machine ~= nil and ids[u.machine] then
        sat[u.machine] = sat[u.machine] or {}
        sat[u.machine][#sat[u.machine] + 1] = u
      elseif orphans[u.role] then
        orphans[u.role][#orphans[u.role] + 1] = u
      else
        orphans.entree[#orphans.entree + 1] = u -- rôle inconnu : traité comme une alimentation (dernier)
      end
    end
  end
  table.sort(machines, function(a, b) return id_lt(a.id, b.id) end)
  for _, k in ipairs(Bu.ROLES) do if orphans[k] then table.sort(orphans[k], by_priority) end end
  return machines, sat, orphans
end

--- Toutes les tranches dans l'ordre du DC (sans le kit ni l'ajournement) : sorties orphelines, paires, entrées et poteaux orphelins.
local function all_slices(units, cfg)
  local per = per_slice(cfg)
  local machines, sat, orphans = split(units)
  local out = {}
  cut(out, orphans.sortie, 2 * per)
  local cur = nil
  for i, m in ipairs(machines) do
    if (i - 1) % per == 0 then cur = {} out[#out + 1] = cur end
    cur[#cur + 1] = m
    for _, s in ipairs(sat[m.id] or {}) do cur[#cur + 1] = s end
  end
  for _, s in ipairs(out) do table.sort(s, by_priority) end
  cut(out, orphans.entree, 2 * per)
  cut(out, orphans.poteau, 2 * per)
  return out
end

--- Retire les unités `can_place == false` d'une tranche (ajournées) ; rend la tranche réduite (ou nil si vide).
local function defer(slice, deferred)
  local keep = {}
  for _, u in ipairs(slice) do
    if u.can_place == false then deferred[#deferred + 1] = u else keep[#keep + 1] = u end
  end
  if #keep == 0 then return nil end
  return keep
end

--- Le kit paie-t-il la tranche entière ? Rend vrai (et débite), ou faux et { item, manque } (premier objet manquant, par nom).
local function pay(slice, kit)
  local need = {}
  for _, u in ipairs(slice) do
    local it = u.item or "?"
    need[it] = (need[it] or 0) + 1
  end
  local items = {}
  for it in pairs(need) do items[#items + 1] = it end
  table.sort(items)
  for _, it in ipairs(items) do
    if (kit[it] or 0) < need[it] then return false, { item = it, manque = need[it] - (kit[it] or 0) } end
  end
  for _, it in ipairs(items) do kit[it] = kit[it] - need[it] end
  return true, nil
end

--- Plan d'un rétrofit glissant : { slices (payées, dans l'ordre), total (tranches à faire, payées ou non), deferred, waiting, status, todo }.
function Bu.plan(box, units, kit, cfg)
  local rest = {} -- copie du kit (le kit de l'appelant n'est pas débité) ; ramassage des clés sans décision sur leur ordre
  for k, n in pairs(kit or {}) do rest[k] = n end
  local deferred, slices, waiting, total, todo = {}, {}, nil, 0, 0
  for _, u in ipairs(units or {}) do if Bu.todo(u) then todo = todo + 1 end end
  if todo == 0 then return { slices = {}, total = 0, deferred = {}, waiting = nil, status = Bu.MAXED, todo = 0 } end
  for _, s in ipairs(all_slices(units, cfg)) do
    local kept = defer(s, deferred)
    if kept then
      total = total + 1
      if not waiting then
        local ok, w = pay(kept, rest)
        if ok then slices[#slices + 1] = kept else waiting = w end
      end
    end
  end
  table.sort(deferred, by_priority)
  return { slices = slices, total = total, deferred = deferred, waiting = waiting, status = Bu.EN_COURS, todo = todo }
end

--- Avance d'une tranche : rend un NOUVEL état { i = tranche courante (faites), n, done, t0 } ; `done` = unités remplacées à cette tranche.
function Bu.next(state, done)
  local s = state or { i = 0, n = 0, done = 0 }
  return { i = (s.i or 0) + 1, n = s.n or 0, done = (s.done or 0) + (done or 0), t0 = s.t0 }
end

--- Comptes d'une tranche : machines, bras (sortie + entree), poteaux.
function Bu.counts(slice)
  local m, b, p = 0, 0, 0
  for _, u in ipairs(slice or {}) do
    if u.role == "machine" then m = m + 1 elseif u.role == "poteau" then p = p + 1 else b = b + 1 end
  end
  return m, b, p
end

--- Ligne de journal [FO-RETROFIT] d'une tranche (ou d'une attente : slice nil).
function Bu.line(team, box, k, n, slice, n_deferred, waiting, done)
  local body
  if slice then
    local m, b, p = Bu.counts(slice)
    body = string.format("tranche %d/%d (%d machines, %d bras%s%s)", k, n, m, b, p > 0 and (", " .. p .. " poteaux") or "",
      done ~= nil and (", " .. done .. " remplacees") or "")
  else
    body = string.format("tranche %d/%d non emise", k, n)
  end
  local extra = ""
  if (n_deferred or 0) > 0 then extra = extra .. string.format(", ajournees %d (place)", n_deferred) end
  if waiting then extra = extra .. string.format(", en attente de %s x%d", tostring(waiting.item), waiting.manque or 0) end
  return string.format("[FO-RETROFIT] %s : box %s %s : %s%s", tostring(team), tostring(box.kind), tostring(box.id), body, extra)
end

return Bu
