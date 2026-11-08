--[[
  Lot STOCK-QG : lecture des prototypes pour la règle shared/team/plafond_qg.lua, plafonds de rapatriement au QG et mesure de ce qui entre.

    Pqs.category(f, item)      catégorie de l'objet pour l'équipe `f` ("brut" | "base" | "declasse" | "fini")
    Pqs.hard_set(f, counts, need)  objets au plafond du stock : { [objet] = compte } (relu au plus toutes les Pqs.EVERY ticks, f.stock_cap)
    Pqs.junk_slots(f, counts)  cases prises par du brut et du déclassé au stock
    Pqs.note_entry(f, item, n) compte ce qui ENTRE au stock hors objets finis, par objet et par appelant (journal, mesure seulement)
    Pqs.note_skip(f, item)     compte un ramassage refusé par le plafond (journal, mesure seulement)
    Pqs.flush(f, tick, counts) une ligne [FO-STOCKAGE] par fenêtre de Pqs.LOG ticks

  Les prototypes sont lus UNE fois (cache du module, jamais dans `global` ; relu à l'identique après un chargement : mêmes prototypes).
  Le déclassement d'un bâtiment dépend de ce que l'équipe sait fabriquer : relu toutes les Pqs.OBS_EVERY ticks, état DANS l'équipe.
  État par équipe, en nombres, chaînes et tables : f.stock_cap = { at, set, key, logged }, f.stock_junk = { at, n }, f.stock_obs = { at, set },
  f.stock_in = { since, by, skips, drops }.
    Pqs.room(f, item, count, wanted)  place restante au plafond pour un brut ou un déclassé (nil : aucun plafond ; 0 : au plafond)
    Pqs.note_drop(f, item, n)         compte ce qui est retiré de la poche d'un PNJ au dépôt
]]

local Pq = require("shared.team.plafond_qg")

local Pqs = {}

Pqs.EVERY = 60          -- ticks entre deux relevés du stock pour les plafonds
Pqs.OBS_EVERY = 600     -- ticks entre deux relevés du déclassement (recettes de la force)
Pqs.LOG = 5 * 3600      -- fenêtre de la ligne « entrees au stock »
Pqs.CAP_LOG = 600       -- au plus une ligne « plafond de rapatriement » par équipe sur cette durée, et quand l'ensemble change

local function get(obj, k)
  local ok, v = pcall(function() return obj[k] end)
  if ok then return v end
  return nil
end

local function sorted_keys(dict)
  local out = {}
  for k in pairs(dict or {}) do out[#out + 1] = k end
  table.sort(out)
  return out
end

---------------------------------------------------------------------------------------------------
-- Lecture des prototypes (une fois)
---------------------------------------------------------------------------------------------------
local INFO -- { raw, items, depths, buildings, recipe_of, stack }

local function build()
  local info = { raw = {}, items = {}, buildings = {}, recipe_of = {}, stack = {} }
  if not (game and game.get_filtered_entity_prototypes and game.item_prototypes) then
    info.depths = {}
    info.cats0 = {}
    return info
  end
  -- bruts : produits de minage des ressources et des arbres
  for _, ty in ipairs({ "resource", "tree" }) do
    local protos = game.get_filtered_entity_prototypes({ { filter = "type", type = ty } })
    for _, name in ipairs(sorted_keys(protos)) do
      local mp = get(protos[name], "mineable_properties")
      for _, p in ipairs((mp and mp.products) or {}) do
        if p.type == "item" or p.type == nil then info.raw[p.name] = true end
      end
    end
  end
  -- recettes : objets seulement (les fluides ne comptent pas comme ingrédient), cachées exclues
  local recipes = {}
  local rprotos = game.recipe_prototypes or {}
  for _, rn in ipairs(sorted_keys(rprotos)) do
    local r = rprotos[rn]
    if not get(r, "hidden") then
      local ins, outs = {}, {}
      for _, i in ipairs(get(r, "ingredients") or {}) do if i.type ~= "fluid" then ins[#ins + 1] = i.name end end
      for _, o in ipairs(get(r, "products") or {}) do
        if o.type ~= "fluid" then
          outs[#outs + 1] = o.name
          if info.recipe_of[o.name] == nil then info.recipe_of[o.name] = rn end
        end
      end
      recipes[#recipes + 1] = { ins = ins, outs = outs }
    end
  end
  info.depths = Pq.depths(recipes, info.raw)
  -- objets : posable (entité, tuile ou équipement) et type « item »
  local entity_protos = game.entity_prototypes or {}
  for _, name in ipairs(sorted_keys(game.item_prototypes)) do
    local p = game.item_prototypes[name]
    local pr = get(p, "place_result")
    local place = pr ~= nil or get(p, "place_as_tile_result") ~= nil or get(p, "place_as_equipment_result") ~= nil
    info.items[name] = { place = place, plain = get(p, "type") == "item" }
    info.stack[name] = get(p, "stack_size") or 50
    if pr then
      local e = entity_protos[pr.name]
      local group = e and get(e, "fast_replaceable_group")
      local rating = e and (get(e, "crafting_speed") or get(e, "mining_speed"))
      if group and rating then info.buildings[#info.buildings + 1] = { item = name, group = group, rating = rating } end
    end
  end
  return info
end

local function info()
  if not INFO then INFO = build() end
  return INFO
end

---------------------------------------------------------------------------------------------------
-- Catégories : fixes (prototypes) + déclassement relu par équipe
---------------------------------------------------------------------------------------------------
local BASE_CAT -- catégories sans déclassement, fixes pour toute la partie (cache du module : mêmes prototypes chez tous les pairs)

local function base_cats()
  if not BASE_CAT then
    local inf = info()
    BASE_CAT = Pq.classify(inf.items, inf.raw, inf.depths, nil, Pq.DEFAULT)
  end
  return BASE_CAT
end

--- Bâtiments déclassés pour l'équipe `f` : { [objet] = vrai }, relu toutes les Pqs.OBS_EVERY ticks. L'état est dans l'ÉQUIPE (f.stock_obs,
--- sauvegardé) et non dans un cache du module : un pair qui charge la partie relit au même tick que celui qui la continue (déterminisme).
local function obsolete_of(f, tick)
  local o = f.stock_obs
  if o and tick >= o.at and tick - o.at < Pqs.OBS_EVERY then return o.set end
  local inf = info()
  local force = game and game.forces and game.forces[f.force or "?"]
  local function available(item)
    if not force then return false end
    local rn = inf.recipe_of[item]
    local r = rn and force.recipes[rn]
    return r ~= nil and r.enabled == true
  end
  local set = Pq.obsolete(inf.buildings, available)
  f.stock_obs = { at = tick, set = set }
  return set
end

local function now() return (game and game.tick) or 0 end

function Pqs.category(f, item)
  local base = base_cats()[item]
  if (base == nil or base == Pq.CAT.FINI) and obsolete_of(f, now())[item] then
    local it = info().items[item]
    if it and it.place and not info().raw[item] then return Pq.CAT.DECLASSE end
  end
  return base or Pq.CAT.FINI
end

--- Table { [objet] = catégorie } de l'équipe, lue à la demande (Pq.capped et Pq.junk_slots n'indexent que par objet).
local function cat_proxy(f)
  return setmetatable({}, { __index = function(_, item) return Pqs.category(f, item) end })
end

function Pqs.stack_of(item)
  return info().stack[item]
end

--- Objets au plafond du stock (Pq.capped) pour l'équipe `f` ; `counts` = contenu du stock { [objet] = nombre }, `need` = matières demandées.
--- Relu au plus toutes les Pqs.EVERY ticks ; une ligne [FO-STOCKAGE] quand l'ensemble des objets change.
function Pqs.hard_set(f, read_counts, need)
  local tick = now()
  local c = f.stock_cap
  if c and tick >= c.at and tick - c.at < Pqs.EVERY then return c.set end
  local counts = read_counts()
  local cat = cat_proxy(f)
  local stack = info().stack
  local set = Pq.capped(cat, counts, stack, need, Pq.DEFAULT)
  local names, text = {}, {}
  for _, it in ipairs(sorted_keys(set)) do
    names[#names + 1] = it
    text[#text + 1] = string.format("%s %d/%d (%s)", it, set[it], Pq.cap_count(cat[it], stack[it], Pq.DEFAULT) or 0, cat[it])
  end
  local key = table.concat(names, " ")
  local was = c and c.key or ""
  f.stock_cap = { at = tick, set = set, key = key, logged = c and c.logged or nil }
  f.stock_junk = { at = tick, n = Pq.junk_slots(cat, counts, stack) }
  if key ~= was and (not f.stock_cap.logged or tick - f.stock_cap.logged >= Pqs.CAP_LOG) then
    f.stock_cap.logged = tick
    log(string.format("[FO-STOCKAGE] %s : plafond de rapatriement au QG : {%s} plus ramasses ni rapatries (ils restent au tampon de leur zone) (avant : {%s}) a %.1f min",
      f.key or "player", table.concat(text, ", "), was, (tick - (f.started or 0)) / 3600))
  end
  return set
end

--- Place restante du stock pour `item` (nil : pas de plafond, ou un objet qui ne se jette pas : Pq.discards) ; `count` = objets au stock,
--- `wanted` = la matière est demandée en ce moment.
function Pqs.room(f, item, count, wanted)
  local cat = Pqs.category(f, item)
  if not Pq.discards(cat) then return nil end
  return Pq.room(cat, count, info().stack[item], wanted, Pq.DEFAULT)
end

--- Un objet qui se jette au dépôt quand le stock est au plafond (brut ou déclassé) ?
function Pqs.discards(f, item) return Pq.discards(Pqs.category(f, item)) end

--- Compte ce qui est retiré de la poche d'un PNJ au dépôt (stock au plafond), pour la ligne de fenêtre.
function Pqs.note_drop(f, item, n)
  if n <= 0 then return end
  local w = f.stock_in
  if not w then
    w = { since = now(), by = {}, skips = {} }
    f.stock_in = w
  end
  w.drops = w.drops or {}
  w.drops[item] = (w.drops[item] or 0) + n
end

function Pqs.junk_slots(f, counts)
  return Pq.junk_slots(cat_proxy(f), counts, info().stack)
end

--- Cases de brut et de déclassé au stock, relues au plus toutes les 5 * Pqs.EVERY ticks (f.stock_junk = { at, n }) ; `read_counts` lit le
--- contenu du stock quand la valeur est périmée. Rend 0 sans prototypes lisibles (moteur simulé).
function Pqs.junk(f, read_counts)
  local tick = now()
  local j = f.stock_junk
  if j and tick >= j.at and tick - j.at < 5 * Pqs.EVERY then return j.n end
  local n = Pqs.junk_slots(f, read_counts())
  f.stock_junk = { at = tick, n = n }
  return n
end

---------------------------------------------------------------------------------------------------
-- Mesure : ce qui entre au stock, par objet et par appelant
---------------------------------------------------------------------------------------------------
local function caller()
  local ok, d = pcall(debug.getinfo, 5, "Sl") -- 1 pcall, 2 caller, 3 note_entry, 4 Stock.insert, 5 l'appelant de Stock.insert
  if not (ok and d) then return "?" end
  local src = tostring(d.short_src or d.source or "?"):gsub("^.*__factorio%-overhaul__[/\\]", ""):gsub("^.*[/\\]script[/\\]", "")
  return src .. ":" .. tostring(d.currentline or 0)
end

function Pqs.note_entry(f, item, n)
  if n <= 0 then return end
  local cat = Pqs.category(f, item)
  if cat == Pq.CAT.FINI then return end
  local w = f.stock_in
  if not w then
    w = { since = now(), by = {}, skips = {} }
    f.stock_in = w
  end
  local k = item .. "|" .. cat .. "|" .. caller()
  w.by[k] = (w.by[k] or 0) + n
end

function Pqs.note_skip(f, item)
  local w = f.stock_in
  if not w then
    w = { since = now(), by = {}, skips = {} }
    f.stock_in = w
  end
  w.skips[item] = (w.skips[item] or 0) + 1
end

--- Fin de fenêtre : une ligne par équipe (entrées par objet/catégorie/appelant, ramassages refusés par le plafond, cases de junk au stock).
function Pqs.flush(f, tick, junk, used, size)
  local w = f.stock_in
  if not w or tick - w.since < Pqs.LOG then return end
  local tot, rows = {}, {}
  for _, k in ipairs(sorted_keys(w.by)) do
    local item, cat, src = k:match("^([^|]+)|([^|]+)|(.*)$")
    local t = tot[item .. " (" .. cat .. ")"] or { n = 0, from = {} }
    t.n = t.n + w.by[k]
    t.from[#t.from + 1] = { src, w.by[k] }
    tot[item .. " (" .. cat .. ")"] = t
  end
  for _, name in ipairs(sorted_keys(tot)) do rows[#rows + 1] = { name, tot[name] } end
  table.sort(rows, function(a, b) if a[2].n ~= b[2].n then return a[2].n > b[2].n end return a[1] < b[1] end)
  local parts = {}
  for i = 1, math.min(6, #rows) do
    local t = rows[i][2]
    table.sort(t.from, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
    local from = {}
    for j = 1, math.min(3, #t.from) do from[j] = string.format("%s x%d", t.from[j][1], t.from[j][2]) end
    parts[i] = string.format("%s %d via %s", rows[i][1], t.n, table.concat(from, " ; "))
  end
  local sk, dr = {}, {}
  for _, it in ipairs(sorted_keys(w.skips)) do sk[#sk + 1] = it .. " " .. w.skips[it] end
  for _, it in ipairs(sorted_keys(w.drops or {})) do dr[#dr + 1] = it .. " " .. w.drops[it] end
  if #parts > 0 or #sk > 0 or #dr > 0 then
    log(string.format("[FO-STOCKAGE] %s : entrees au stock hors objets finis en %.1f min : {%s} ; ramassages refuses par plafond : {%s} ; retires de la poche au depot (stock au plafond) : {%s} ; cases de brut et de declasse au stock %d sur %d prises (%d)",
      f.key or "player", (tick - w.since) / 3600, table.concat(parts, " | "), table.concat(sk, ", "), table.concat(dr, ", "), junk or 0, used or 0, size or 0))
  end
  f.stock_in = nil
end

return Pqs
