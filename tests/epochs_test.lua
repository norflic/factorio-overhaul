--[[
  Tests hors jeu du lot X0 : époques, branches avancées et arbres de fabrication (shared/content/epochs.lua).
  Usage, depuis la racine du mod (ou d'un worktree) :
    lua5.2 tests/epochs_test.lua                 contrôles (la doc 1.1.91 et technology.lua sont trouvées seules)
    lua5.2 tests/epochs_test.lua --markdown      imprime les blocs générés du scénario
    lua5.2 tests/epochs_test.lua --write-doc     réécrit ces blocs dans docs/SCENARIO_EPOQUES.md
    lua5.2 tests/epochs_test.lua <prototype-api.json>   chemin explicite de la doc

  Ce que le banc prouve (hors jeu, sur les données) :
  - fermeture du graphe : tout objet, bâtiment compris, se fabrique depuis les ressources de la carte
    (vanilla réelle : tests/fixtures/recipes.lua, recettes cachées et interdites exclues ; contenu existant ;
    barils générés ; contenu nouveau) ; aucun anachronisme ;
  - technologies : chaque recette nouvelle débloquée par exactement une technologie de son époque ; graphe
    de prérequis sans cycle ; packs disponibles ; pack de l'époque fabricable avant sa propre recherche ;
    recherche de l'époque entre 30 et 40 % du budget (vanilla re-rangée comprise, relue dans technology.lua) ;
  - Compaction : débit et énergie par machine des formes ρ8 et ρ32 face à shared/balance_model.lua ;
    foreuses de la ligne principale à chaque palier ; plafond de foreuses ;
  - limites moteur 1.1.91 relues PROPRIÉTÉ PAR PROPRIÉTÉ dans prototype-api.json (mini-analyseur JSON) ;
    types de prototype réels ; champs obligatoires ; chaîne de chaleur ;
  - garanties de placement de toute ressource dont dépend un pack ;
  - monnaies (format V2), difficulté (clés du lot IA0), calendrier des factions, course à la Porte ;
  - cohérence des données (boîtes de fluide, noms FR et EN, mots anglais dans les noms FR) ;
  - égalité entre les blocs générés du scénario et les données.
  Ce qu'il ne prouve pas : le moteur réel (aucun prototype n'existe), les fluides en conduite, l'équilibrage
  fin en partie ; les MU sont des estimations par le chemin le moins cher (fluides à 0,1 MU l'unité).
]]

package.path = "./?.lua;" .. package.path
local X = require("shared.content.epochs")
local A = require("shared.content.arsenal")
local Mo = require("shared.content.modules")
local BM = require("shared.balance_model")
local FIX = dofile("tests/fixtures/recipes.lua")

local MODE, DOC_ARG = "check", nil
for _, a in ipairs(arg or {}) do
  if a == "--markdown" then MODE = "markdown" elseif a == "--write-doc" then MODE = "write" else DOC_ARG = a end
end
local QUIET = MODE ~= "check"

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) if not QUIET then print("== " .. name) end end
local function info(msg) if not QUIET then print("   " .. msg) end end

--- Clés triées : la seule façon de parcourir une table associative dans ce banc.
local function sorted_keys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end
local INF = math.huge
local function count_pairs(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function set_of(list) local s = {} for _, v in ipairs(list or {}) do s[v] = true end return s end

---------------------------------------------------------------------------------------------------
-- Mini-analyseur JSON (Lua pur) pour doc-html/prototype-api.json.
---------------------------------------------------------------------------------------------------
local JSON_NULL = setmetatable({}, { __tostring = function() return "null" end })
local function json_decode(str)
  local pos = 1
  local function skip() pos = str:find("[^ \t\r\n]", pos) or (#str + 1) end
  local ESC = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
  local function utf8(c)
    if c < 0x80 then return string.char(c) end
    if c < 0x800 then return string.char(0xC0 + math.floor(c / 64), 0x80 + c % 64) end
    return string.char(0xE0 + math.floor(c / 4096), 0x80 + math.floor(c / 64) % 64, 0x80 + c % 64)
  end
  local parse
  local function parse_string()
    local out, i = {}, pos + 1
    while true do
      local j = str:find('["\\]', i)
      out[#out + 1] = str:sub(i, j - 1)
      if str:sub(j, j) == '"' then pos = j + 1; break end
      local e = str:sub(j + 1, j + 1)
      if e == "u" then out[#out + 1] = utf8(tonumber(str:sub(j + 2, j + 5), 16)); i = j + 6
      else out[#out + 1] = ESC[e] or e; i = j + 2 end
    end
    return table.concat(out)
  end
  function parse()
    skip()
    local c = str:sub(pos, pos)
    if c == "{" then
      local obj = {}
      pos = pos + 1; skip()
      if str:sub(pos, pos) == "}" then pos = pos + 1; return obj end
      while true do
        skip()
        local k = parse_string()
        skip(); pos = pos + 1 -- « : »
        obj[k] = parse()
        skip()
        local d = str:sub(pos, pos); pos = pos + 1
        if d == "}" then return obj end
      end
    elseif c == "[" then
      local arr = {}
      pos = pos + 1; skip()
      if str:sub(pos, pos) == "]" then pos = pos + 1; return arr end
      while true do
        arr[#arr + 1] = parse()
        skip()
        local d = str:sub(pos, pos); pos = pos + 1
        if d == "]" then return arr end
      end
    elseif c == '"' then return parse_string()
    elseif str:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
    elseif str:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
    elseif str:sub(pos, pos + 3) == "null" then pos = pos + 4; return JSON_NULL
    else
      local s, e = str:find("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
      pos = e + 1
      return tonumber(str:sub(s, e))
    end
  end
  return parse()
end
local function flatten(v, out)
  out = out or {}
  if type(v) == "table" then for _, k in ipairs(sorted_keys(v)) do flatten(v[k], out) end
  elseif v ~= nil then out[#out + 1] = tostring(v) end
  return out
end

---------------------------------------------------------------------------------------------------
section("Sources moteur 1.1.91 (doc-html/prototype-api.json, propriété par propriété)")
---------------------------------------------------------------------------------------------------
local doc_candidates = { "../../doc-html/prototype-api.json", "../../../../../doc-html/prototype-api.json" }
if DOC_ARG then table.insert(doc_candidates, 1, DOC_ARG) end
local doc_text, doc_path
for _, p in ipairs(doc_candidates) do
  if not doc_text then
    local f = io.open(p, "rb")
    if f then doc_text = f:read("*a"); f:close(); doc_path = p end
  end
end
local typenames = set_of(X.PROTO_TYPES)
if doc_text then
  info("doc relue : " .. doc_path)
  local doc = json_decode(doc_text)
  check(doc.application_version == "1.1.91", "la doc est bien celle de 1.1.91")
  local owners = {}
  for _, coll in ipairs({ doc.prototypes, doc.types }) do for _, o in ipairs(coll) do owners[o.name] = o end end
  typenames = {}
  for _, p in ipairs(doc.prototypes) do if type(p.typename) == "string" then typenames[p.typename] = true end end
  check(count_pairs(typenames) > 150, "liste des typename relue (" .. count_pairs(typenames) .. ")")
  for _, ph in ipairs(X.DOC_PHRASES) do
    local o, prop = owners[ph.owner], nil
    for _, q in ipairs(o and o.properties or {}) do if q.name == ph.prop then prop = q end end
    check(prop ~= nil, ph.key .. " : propriété " .. ph.owner .. "." .. ph.prop .. " trouvée")
    if prop then
      if ph.text then
        check(type(prop.description) == "string" and prop.description:find(ph.text, 1, true) ~= nil,
          ph.key .. " : « " .. ph.text .. " » dans la description de " .. ph.owner .. "." .. ph.prop)
      end
      if ph.default ~= nil then
        check(type(prop.default) == "table" and prop.default.value == ph.default,
          ph.key .. " : " .. ph.owner .. "." .. ph.prop .. " vaut " .. tostring(ph.default) .. " par défaut")
      end
      if ph.type_has then
        local flat = table.concat(flatten(prop.type), " ")
        for _, n in ipairs(ph.type_has) do check(flat:find(n, 1, true) ~= nil, ph.key .. " : type de " .. ph.owner .. "." .. ph.prop .. " contient " .. n) end
      end
      if ph.required then check(prop.optional == false, ph.key .. " : " .. ph.owner .. "." .. ph.prop .. " est obligatoire") end
    end
  end
  for _, absent in ipairs({ "SpoilablePrototype", "FusionReactorPrototype" }) do
    check(owners[absent] == nil, absent .. " absent de 1.1.91 (pas de péremption, pas de réacteur à fusion natif)")
  end
  for _, t in ipairs(X.PROTO_TYPES) do check(typenames[t], "type de prototype « " .. t .. " » réel en 1.1.91") end
else
  info("AVIS : prototype-api.json introuvable ; propriétés citées non relues, types contrôlés sur X.PROTO_TYPES seulement")
end
check(X.LIMITS.item_amount_max == 2 ^ 16 - 1, "quantité maximale d'objet = uint16 (65 535)")
check(X.LIMITS.wire_distance_max == 64 and X.LIMITS.supply_distance_max == 64, "portée de fil et d'alimentation : 64 au plus")

---------------------------------------------------------------------------------------------------
section("Structure, noms, traductions")
---------------------------------------------------------------------------------------------------
local idx = X.index()
for _, coll in ipairs({ { "items", X.items }, { "buildings", X.buildings }, { "recipes", X.recipes }, { "resources", X.resources },
                        { "epochs", X.epochs }, { "branches", X.branches }, { "tiles", X.tiles }, { "technologies", X.technologies },
                        { "currencies", X.currencies }, { "difficulty", X.difficulty } }) do
  check(#coll[2] > 0 and #coll[2] == count_pairs(coll[2]), coll[1] .. " : tableau pur (itération par ipairs, jamais pairs)")
end
check(#X.epochs == 15, "15 époques")
for k, e in ipairs(X.epochs) do check(e.n == k, "époque " .. k .. " à sa place") end
check(#X.branches == 4, "4 branches avancées")

-- Mots anglais connus dans un nom français (correction : « Transmutation : tungsten »…).
local EN_WORDS = { "tungsten", "ilmenite", "crystal", "copper", "iron", "plate", "ore", "slag", "sand", "steel", "wire", "dust",
  "gear", "pellet", "trap", "well", "drill", "shield", "and", "the", "of" }
local function english_in(fr)
  local low = fr:lower()
  for _, w in ipairs(EN_WORDS) do
    if low:find("%f[%a]" .. w .. "%f[%A]") then return w end
  end
  return nil
end
local function check_fr(where, fr) if fr then local w = english_in(fr); check(w == nil, where .. " : mot anglais « " .. tostring(w) .. " » dans le nom français « " .. fr .. " »") end end

local base_item = {}
local function mark_base(name) base_item[name] = true end
for _, rn in ipairs(sorted_keys(FIX)) do
  for _, i in ipairs(FIX[rn].ingredients) do mark_base(i.name) end
  for _, p in ipairs(FIX[rn].products) do mark_base(p.name) end
end
for _, p in ipairs(X.base_pseudo) do
  for _, i in ipairs(p.ingredients) do mark_base(i[1]) end
  for _, r in ipairs(p.results) do mark_base(r[1]) end
end
for _, f in ipairs(X.base_fluids) do mark_base(f) end
for _, m in ipairs(X.base_machines) do if not m.hand then mark_base(m.name) end end

local function valid_name(n) return type(n) == "string" and #n <= X.LIMITS.name_max_length and not n:find(".", 1, true) end
local seen_item, seen_recipe, seen_resource = {}, {}, {}
for _, it in ipairs(X.items) do
  check(it.name:sub(1, 3) == X.PREFIX, it.name .. " : préfixe fo-")
  check(valid_name(it.name), it.name .. " : nom valide (sans point, 200 caractères au plus)")
  check(not seen_item[it.name], it.name .. " : nom d'objet unique")
  check(not base_item[it.name], it.name .. " : ne masque aucun objet vanilla ou existant")
  check(type(it.fr) == "string" and #it.fr > 0 and type(it.en) == "string" and #it.en > 0, it.name .. " : noms FR et EN")
  check_fr(it.name, it.fr)
  check(it.epoch >= 1 and it.epoch <= 15 and it.epoch % 1 == 0, it.name .. " : époque entière de 1 à 15")
  if it.type == "item" then check(type(it.stack) == "number" and it.stack >= 1 and it.stack % 1 == 0, it.name .. " : taille de pile entière") end
  seen_item[it.name] = true
end
for _, b in ipairs(X.buildings) do
  check(b.name:sub(1, 3) == X.PREFIX and valid_name(b.name), b.name .. " : nom de bâtiment valide, préfixe fo-")
  check(not seen_item[b.name], b.name .. " : nom unique (un bâtiment est aussi un objet)")
  check(not base_item[b.name], b.name .. " : ne masque aucun bâtiment vanilla")
  check(type(b.fr) == "string" and #b.fr > 0 and type(b.en) == "string" and #b.en > 0, b.name .. " : noms FR et EN")
  check_fr(b.name, b.fr)
  seen_item[b.name] = true
end
for _, r in ipairs(X.recipes) do
  check(r.name:sub(1, 3) == X.PREFIX and valid_name(r.name), r.name .. " : nom de recette valide, préfixe fo-")
  check(not seen_recipe[r.name], r.name .. " : nom de recette unique")
  check(FIX[r.name] == nil, r.name .. " : ne remplace aucune recette vanilla (QX4 : des variantes, pas des modifications)")
  seen_recipe[r.name] = true
  local named = r.fr and r.en
  if not named and #r.results >= 1 then
    local main = idx.item[r.results[1][1]] or idx.building[r.results[1][1]]
    named = main and main.fr and main.en
  end
  check(named, r.name .. " : nom FR et EN (propre ou celui de son produit principal)")
  check_fr(r.name, r.fr)
end
for _, res in ipairs(X.resources) do
  check(res.name:sub(1, 3) == X.PREFIX and valid_name(res.name) and not seen_resource[res.name], res.name .. " : ressource nommée, unique")
  check(res.fr and res.en and res.where_fr, res.name .. " : noms FR, EN et emplacement")
  check_fr(res.name, res.fr)
  check(type(res.products) == "table" and #res.products == 1, res.name .. " : un seul produit de minage (une ressource 1.1 a un résultat fixe)")
  seen_resource[res.name] = true
end
for _, e in ipairs(X.epochs) do check(e.fr and e.en and e.reveal_fr and e.energy_fr and e.pressure_fr, "époque " .. e.n .. " : noms et récit") end
for _, br in ipairs(X.branches) do check(br.fr and br.en and br.mechanic_fr and br.yields_fr and br.cost_risk_fr, "branche " .. br.key .. " : noms, mécanique, coût et risque") end
for _, t in ipairs(X.tiles) do check(t.name:sub(1, 3) == X.PREFIX and t.fr and t.en, t.name .. " : tuile nommée") end
for _, t in ipairs(X.technologies) do
  check(t.name:sub(1, 3) == X.PREFIX and valid_name(t.name) and t.fr and t.en, t.name .. " : technologie nommée FR et EN")
  check_fr(t.name, t.fr)
end
-- Textes vus par le joueur (récit) : FR et EN partout.
check(X.story.intro_fr and X.story.intro_en and X.story.victory_fr and X.story.victory_en and X.story.defeat_fr and X.story.defeat_en
  and X.story.channel_fr, "textes d'introduction, de victoire et de défaite en FR et EN, canal fixé")
for k = 1, 14 do
  local e = X.epochs[k]
  check(e.codex_fr and #e.codex_fr > 40 and e.codex_en and #e.codex_en > 40, "Codex " .. k .. " : texte joueur FR et EN (2 phrases)")
end

---------------------------------------------------------------------------------------------------
section("Graphe complet : vanilla réelle + existant + barils + nouveau")
---------------------------------------------------------------------------------------------------
local base_recipes = {}
local function to_pairs(list)
  local out = {}
  for _, e in ipairs(list) do out[#out + 1] = { e.name or e[1], e.amount or e[2] } end
  return out
end
local never = set_of(X.base_recipe_never)
local hidden_allowed = {}
for _, h in ipairs(X.base_recipe_hidden_allowed) do hidden_allowed[h[1]] = h[2] end
local hidden_seen = {}
for _, rn in ipairs(sorted_keys(FIX)) do
  local f = FIX[rn]
  if f.hidden then hidden_seen[#hidden_seen + 1] = rn end
  if (not f.hidden or hidden_allowed[rn]) and not never[rn] then
    local r = { name = rn, category = f.category, time = f.energy, ingredients = to_pairs(f.ingredients), results = to_pairs(f.products), base = true }
    -- Vidange d'un baril : le baril vide est rendu (exclu du partage des MU).
    if rn:find("^empty%-.+%-barrel$") then for _, p in ipairs(r.results) do if p[1] == "empty-barrel" then p.back = true end end end
    base_recipes[rn] = r
  end
end
for _, rn in ipairs(hidden_seen) do
  check(never[rn] or hidden_allowed[rn], rn .. " : recette vanilla cachée exclue du graphe (ou tolérée et déclarée)")
end
for _, rn in ipairs(X.base_recipe_never) do check(FIX[rn] ~= nil, rn .. " : la liste « jamais » ne cite que des recettes réelles") end
local function from_arsenal(spec, category_is_recipe)
  local ing = {}
  for _, i in ipairs(spec.ingredients) do
    if i.type == "fluid" then ing[#ing + 1] = { i.name, i.amount } else ing[#ing + 1] = { i[1], i[2] } end
  end
  base_recipes[spec.name] = { name = spec.name, category = (category_is_recipe and spec.category) or "crafting", time = spec.energy or 10,
    ingredients = ing, results = { { spec.name, 1 } }, base = true }
end
for _, list in ipairs({ A.ammo, A.guns, A.turrets, A.walls, A.special_turrets, A.special_guns }) do
  for _, spec in ipairs(list) do from_arsenal(spec, true) end
end
for _, spec in ipairs(A.special_ammo) do from_arsenal(spec, false) end
for _, fam in ipairs(Mo.ORDER) do
  for k = Mo.VANILLA_TIERS + 1, Mo.TIERS do
    local rec = Mo.recipe(fam, k)
    base_recipes[Mo.name(fam, k)] = { name = Mo.name(fam, k), category = "crafting", time = rec.energy,
      ingredients = to_pairs(rec.ingredients), results = { { Mo.name(fam, k), 1 } }, base = true }
  end
end
-- prototypes/levels.lua:359 (recette du centre de commandement niveau 1).
base_recipes["fo-command-center"] = { name = "fo-command-center", category = "crafting", time = 5, base = true,
  ingredients = { { "iron-chest", 4 }, { "iron-gear-wheel", 20 }, { "electronic-circuit", 10 }, { "stone-brick", 20 } },
  results = { { "fo-command-center", 1 } } }
mark_base("fo-command-center")
local override_pending = {}
for _, ov in ipairs(X.existing_overrides) do
  local cur = base_recipes[ov.name]
  check(cur ~= nil, ov.name .. " : la correction vise une recette existante")
  if cur then
    local same = #cur.ingredients == #ov.ingredients
    for i, ing in ipairs(ov.ingredients) do
      if not cur.ingredients[i] or cur.ingredients[i][1] ~= ing[1] or cur.ingredients[i][2] ~= ing[2] then same = false end
    end
    if not same then override_pending[#override_pending + 1] = ov.name end
    cur.ingredients = ov.ingredients
  end
end
for _, n in ipairs(override_pending) do info("AVIS : correction à intégrer dans shared/content/arsenal.lua : " .. n) end

local base_epoch = {}
for _, row in ipairs(X.base_recipe_epochs) do
  for _, n in ipairs(row[2]) do
    check(base_epoch[n] == nil, n .. " : une seule époque dans le re-rangement")
    check(not never[n], n .. " : recette de la liste « jamais » sans époque")
    base_epoch[n] = row[1]
  end
end
for rn, e in pairs(hidden_allowed) do base_epoch[rn] = e end
for _, rn in ipairs(sorted_keys(base_recipes)) do
  check(base_epoch[rn] ~= nil, rn .. " : recette de base rangée dans une époque")
  base_recipes[rn].epoch = base_epoch[rn] or 99
end
for _, n in ipairs(sorted_keys(base_epoch)) do check(base_recipes[n] ~= nil, n .. " : le re-rangement ne cite que des recettes du graphe") end

-- Barils (FluidPrototype.auto_barrel vrai par défaut) : le data-updates de base crée un objet et deux
-- recettes par fluide nouveau qui le garde. Injectés dans le graphe à l'époque max(4, époque du fluide).
local barrel_items, barrel_recipes = {}, {}
for _, it in ipairs(X.items) do
  if it.type == "fluid" and it.barrel then
    local bn, e = it.name .. "-barrel", math.max(4, it.epoch)
    barrel_items[#barrel_items + 1] = bn
    barrel_recipes[#barrel_recipes + 1] = { name = "fill-" .. bn, epoch = e, category = "crafting-with-fluid", time = 0.2, barrel = true,
      ingredients = { { it.name, 50 }, { "empty-barrel", 1 } }, results = { { bn, 1 } }, kind = "recipe" }
    barrel_recipes[#barrel_recipes + 1] = { name = "empty-" .. bn, epoch = e, category = "crafting-with-fluid", time = 0.2, barrel = true,
      ingredients = { { bn, 1 } }, results = { { it.name, 50 }, { "empty-barrel", 1, back = true } }, kind = "recipe" }
  end
end
local all = {}
for _, rn in ipairs(sorted_keys(base_recipes)) do all[#all + 1] = base_recipes[rn] end
for _, p in ipairs(X.base_pseudo) do all[#all + 1] = p end
for _, r in ipairs(barrel_recipes) do all[#all + 1] = r end
for _, r in ipairs(X.recipes) do all[#all + 1] = r end
table.sort(all, function(a, b) return a.name < b.name end)

local is_fluid = {}
for _, f in ipairs(X.base_fluids) do is_fluid[f] = true end
for _, it in ipairs(X.items) do if it.type == "fluid" then is_fluid[it.name] = true end end
for _, rn in ipairs(sorted_keys(FIX)) do
  for _, i in ipairs(FIX[rn].ingredients) do if i.type == "fluid" then is_fluid[i.name] = true end end
  for _, p in ipairs(FIX[rn].products) do if p.type == "fluid" then is_fluid[p.name] = true end end
end

local known = {}
for _, n in ipairs(sorted_keys(base_item)) do known[n] = true end
for _, r in ipairs(all) do for _, p in ipairs(r.results) do known[p[1]] = true end end
for _, it in ipairs(X.items) do known[it.name] = true end
for _, b in ipairs(X.buildings) do known[b.name] = true end
for _, r in ipairs(X.recipes) do
  for _, i in ipairs(r.ingredients) do check(known[i[1]], r.name .. " : ingrédient connu " .. tostring(i[1])) end
  for _, p in ipairs(r.results) do check(known[p[1]], r.name .. " : produit connu " .. tostring(p[1])) end
end
for _, p in ipairs(X.base_pseudo) do
  for _, i in ipairs(p.ingredients) do check(known[i[1]], p.name .. " : ingrédient connu " .. i[1]) end
end

local machine_def = {}
for _, m in ipairs(X.base_machines) do machine_def[m.name] = m end
for _, b in ipairs(X.buildings) do machine_def[b.name] = b end
local cat_machines = {}
for _, mn in ipairs(sorted_keys(machine_def)) do
  for _, c in ipairs(machine_def[mn].categories or {}) do
    cat_machines[c] = cat_machines[c] or {}
    table.insert(cat_machines[c], mn)
  end
end
local function machines_of(r)
  if r.machines then return r.machines end
  return cat_machines[r.category] or {}
end
for _, r in ipairs(all) do
  local ms = machines_of(r)
  check(#ms > 0, r.name .. " : au moins une machine pour « " .. tostring(r.category) .. " »")
  for _, m in ipairs(ms) do check(machine_def[m] ~= nil, r.name .. " : machine déclarée " .. m) end
end

-- Point fixe : époque la plus tôt où chaque objet est disponible (filtre facultatif sur les recettes).
local avail = {}
local function av(n) return avail[n] or INF end
local function machine_avail(r)
  local best = INF
  for _, m in ipairs(machines_of(r)) do
    local e = (machine_def[m] and machine_def[m].hand) and 1 or av(m)
    if e < best then best = e end
  end
  return best
end
local function recipe_avail(r)
  local e = r.epoch or INF
  for _, i in ipairs(r.ingredients) do
    local a = av(i[1])
    if a > e then e = a end
  end
  local m = machine_avail(r)
  if m > e then e = m end
  return e
end
local function fixpoint(exclude)
  avail = {}
  local changed, n = true, 0
  while changed and n < 200 do
    changed, n = false, n + 1
    for _, r in ipairs(all) do
      if not (exclude and exclude(r)) then
        local e = recipe_avail(r)
        if e < INF then
          for _, p in ipairs(r.results) do
            if e < av(p[1]) then avail[p[1]] = e; changed = true end
          end
        end
      end
    end
  end
  return n
end
local fp_passes = fixpoint()
check(fp_passes < 200, "le point fixe converge (" .. fp_passes .. " passes)")
local function snapshot() local s = {} for _, n in ipairs(sorted_keys(avail)) do s[n] = avail[n] end return s end
local AVAIL = snapshot()

local unreachable, anachronic = 0, 0
for _, r in ipairs(all) do
  local e = recipe_avail(r)
  check(e < INF, r.name .. " : recette réalisable depuis les ressources de la carte")
  if e == INF then unreachable = unreachable + 1
  else
    check(e == r.epoch, r.name .. " : aucun anachronisme (disponible à l'époque " .. tostring(e) .. ", déclarée " .. tostring(r.epoch) .. ")")
    if e ~= r.epoch then anachronic = anachronic + 1 end
  end
end
for _, it in ipairs(X.items) do
  check(av(it.name) == it.epoch, it.name .. " : disponible à son époque " .. it.epoch .. " (calculée : " .. tostring(av(it.name)) .. ")")
end
for _, b in ipairs(X.buildings) do
  check(av(b.name) == b.epoch, b.name .. " : bâtiment disponible à son époque " .. b.epoch .. " (calculée : " .. tostring(av(b.name)) .. ")")
end
info(string.format("%d recettes dans le graphe (%d de base, %d pseudo-recettes de base, %d de barils, %d nouvelles) : %d infranchissable(s), %d anachronisme(s)",
  #all, count_pairs(base_recipes), #X.base_pseudo, #barrel_recipes, #X.recipes, unreachable, anachronic))
fixpoint()
local same = true
for _, n in ipairs(sorted_keys(AVAIL)) do if AVAIL[n] ~= avail[n] then same = false end end
check(same and count_pairs(AVAIL) == count_pairs(avail), "point fixe déterministe (deux calculs identiques)")

-- Ressources : le produit d'une pseudo-recette de minage est celui de sa ressource.
for _, r in ipairs(X.recipes) do
  if r.kind == "mining" then
    local res = idx.resource[r.resource]
    check(res ~= nil, r.name .. " : ressource déclarée " .. tostring(r.resource))
    if res then
      local prods = set_of(res.products)
      for _, p in ipairs(r.results) do
        if not p.p then check(prods[p[1]], r.name .. " : produit " .. p[1] .. " = produit de la ressource " .. res.name) end
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
section("Valeurs en MU (greffe P2) : chemin le moins cher, fluides à 0,1 MU l'unité")
---------------------------------------------------------------------------------------------------
local rho = {}
for _, it in ipairs(X.items) do if it.rho then rho[it.name] = it.rho end end
local free_fluid = set_of(X.FREE_FLUIDS)
local function unit_weight(name)
  if is_fluid[name] then return free_fluid[name] and 0 or (rho[name] or X.FLUID_MU) end
  return rho[name] or 1
end
local mu = {}
local function mu_of(n) return mu[n] or INF end
local mu_changed, mu_passes = true, 0
while mu_changed and mu_passes < 400 do
  mu_changed, mu_passes = false, mu_passes + 1
  for _, r in ipairs(all) do
    if r.kind ~= "burn" and r.kind ~= "sink" and r.unlock ~= "wonder" then
      local input, ok = 0, true
      if r.kind == "mining" or r.kind == "gather" or r.kind == "loot" or (r.kind == "launch" and r.extraction) then
        input = nil
      else
        for _, i in ipairs(r.ingredients) do
          local m = (is_fluid[i[1]] and unit_weight(i[1]) == 0) and 0 or mu_of(i[1])
          if m == INF then ok = false break end
          input = input + m * (i[2] - (i.catalyst or 0))
        end
      end
      if ok then
        local W = 0
        for _, p in ipairs(r.results) do if not p.back then W = W + (p[2] - (p.catalyst or 0)) * (p.p or 1) * unit_weight(p[1]) end end
        for _, p in ipairs(r.results) do
          if not p.back and p[2] - (p.catalyst or 0) > 0 then
            local unit
            if input == nil then unit = unit_weight(p[1])
            elseif W > 0 then unit = input * unit_weight(p[1]) / W end
            if unit and unit < mu_of(p[1]) - 1e-12 then mu[p[1]] = unit; mu_changed = true end
          end
        end
      end
    end
  end
end
check(mu_passes < 400, "calcul des MU convergent (" .. mu_passes .. " passes)")
if os.getenv("X0_DEBUG_MU") then for n in os.getenv("X0_DEBUG_MU"):gmatch("[^,]+") do print(string.format("MU %s = %.2f", n, mu_of(n))) end end
for _, it in ipairs(X.items) do
  if it.material then
    check(mu_of(it.name) >= 0.75 * it.rho - 1e-9,
      string.format("%s : MU %.2f ≥ 0,75 × ρ%g (matière dense honnête)", it.name, mu_of(it.name), it.rho))
  end
end
for _, n in ipairs({ "copper-plate", "fo-axion-condensate", "fo-antihydrogen-trap", "fo-biopolymer", "fo-methanotroph-culture" }) do
  check(mu_of(n) >= 0.5 and mu_of(n) < INF, string.format("%s : MU %.2f non effondrée (produits rendus exclus du partage)", n, mu_of(n)))
end

---------------------------------------------------------------------------------------------------
section("Époques (F1-2, F1-3, Q5, Q6), monnaies au format V2")
---------------------------------------------------------------------------------------------------
local res_by_epoch, mat_by_epoch, bld_by_epoch, main_bld_by_epoch = {}, {}, {}, {}
for k = 1, 15 do res_by_epoch[k], mat_by_epoch[k], bld_by_epoch[k], main_bld_by_epoch[k] = 0, 0, 0, 0 end
for _, r in ipairs(X.resources) do res_by_epoch[r.epoch] = res_by_epoch[r.epoch] + 1 end
for _, r in ipairs(X.base_resources) do res_by_epoch[r.epoch] = res_by_epoch[r.epoch] + 1 end
for _, it in ipairs(X.items) do if it.material or it.type == "fluid" then mat_by_epoch[it.epoch] = mat_by_epoch[it.epoch] + 1 end end
for _, b in ipairs(X.buildings) do
  bld_by_epoch[b.epoch] = bld_by_epoch[b.epoch] + 1
  if not b.branch then main_bld_by_epoch[b.epoch] = main_bld_by_epoch[b.epoch] + 1 end
end
local total_hours = 0
local pack_mu, currency_mu = {}, {}
local L_V2
for _, p in ipairs({ "shared/levels/config.lua", "../../../shared/levels/config.lua" }) do
  if not L_V2 then
    local f = io.open(p, "rb")
    if f then
      f:close()
      local ok, L = pcall(dofile, p)
      if ok and type(L) == "table" and L.epoch_materials then L_V2 = L; info("monnaies du lot V2 relues : " .. p) end
    end
  end
end
if not L_V2 then info("AVIS : shared/levels/config.lua (L.epoch_materials) introuvable ; valeurs V2 non comparées") end
for k, e in ipairs(X.epochs) do
  check(res_by_epoch[k] + mat_by_epoch[k] >= 1, "époque " .. k .. " : au moins une ressource ou un matériau (F1-2)")
  check(main_bld_by_epoch[k] >= 2, "époque " .. k .. " : au moins 2 bâtiments de ligne principale (" .. main_bld_by_epoch[k] .. ")")
  info(string.format("époque %2d %-18s ressources %d, matériaux et fluides %d, bâtiments %d (dont ligne principale %d)",
    k, e.fr, res_by_epoch[k], mat_by_epoch[k], bld_by_epoch[k], main_bld_by_epoch[k]))
  check(av(e.pack) == k, "époque " .. k .. " : son pack " .. e.pack .. " naît à l'époque " .. k)
  pack_mu[k] = mu_of(e.pack)
  local c = X.currency_of(k)
  if k == 1 then
    check(c == nil and e.currency == nil, "époque 1 : pas de monnaie (panier de base de V2)")
  else
    check(c ~= nil and c.item == e.currency, "époque " .. k .. " : une monnaie principale (format V2), la même dans X.epochs et X.currencies")
    if c then
      check(not is_fluid[c.item], "époque " .. k .. " : la monnaie " .. c.item .. " est un objet, pas un fluide (coffre du centre)")
      check(av(c.item) <= k, "époque " .. k .. " : monnaie " .. c.item .. " disponible")
      check(c.stack >= 50, "époque " .. k .. " : pile de la monnaie ≥ 50 (L.MIN_MATERIAL_STACK)")
      local it = idx.item[c.item]
      if it then check(it.stack == c.stack, c.item .. " : même pile dans X.items et X.currencies") end
      local m = mu_of(c.item)
      if c.v2_item == c.item then
        -- Monnaie inchangée : la valeur reste celle du lot V2 (une seule source), relue si possible.
        if L_V2 and L_V2.epoch_materials and L_V2.epoch_materials[k] then
          check(L_V2.epoch_materials[k].item == c.item and L_V2.epoch_materials[k].value == c.value, "époque " .. k .. " : monnaie et valeur identiques à L.epoch_materials (V2)")
          if L_V2.stack_size and L_V2.stack_size[c.item] then check(L_V2.stack_size[c.item] == c.stack, "époque " .. k .. " : pile identique à L.stack_size (V2)") end
        end
        check(c.value >= m, string.format("époque %d : valeur V2 de %s (%g) ≥ son coût calculé par le chemin le moins cher (%.1f MU)", k, c.item, c.value, m))
      elseif c.cap_per_s then
        check(c.value >= m, string.format("époque %d : valeur de %s (%g, rareté : plafond %g/s) ≥ son coût calculé (%.1f MU)", k, c.item, c.value, c.cap_per_s, m))
      else
        check(c.value > 0 and c.value >= 0.5 * m and c.value <= 3 * m,
          string.format("époque %d : valeur déclarée de %s (%g MU) entre 0,5 et 3 × son coût calculé (%.1f MU)", k, c.item, c.value, m))
      end
      currency_mu[k] = m
      if c.v2_item ~= c.item then check(c.why_fr ~= nil, "époque " .. k .. " : écart avec V2 justifié par écrit") end
      -- Le passage du centre de k à k+1 (60 % en monnaie de k) se produit en 25 % au plus de l'époque.
      if k <= 14 then
        local units = 0.6 * X.cc_upgrade_mu(k) / c.value
        local hours_needed
        if c.cap_per_s then hours_needed = units / c.cap_per_s / 3600
        else hours_needed = units * c.value / (0.5 * X.rate_avg(k)) / 3600 end
        check(hours_needed <= 0.25 * X.epoch_hours(k) + 1e-9,
          string.format("époque %d : le lot de monnaie du passage (%.0f × %s) se produit en %.2f h ≤ 25 %% de %.1f h", k, units, c.item, hours_needed, X.epoch_hours(k)))
      end
    end
  end
  if k <= 14 then
    check(idx.item["fo-codex-" .. k] and av("fo-codex-" .. k) == k, "époque " .. k .. " : Codex " .. k .. " fabricable pour passer le centre")
  else
    check(idx.item["fo-codex-15"] == nil, "pas de Codex 15 (le centre plafonne à 15)")
  end
  local ms = e.milestones
  local pitem, pcount, pval = X.milestone_production(k)
  check(av(pitem) <= k and math.abs(pcount * pval / X.budget(k) - 0.02) < 0.005, "époque " .. k .. " : jalon de production à 2 % du budget (" .. pcount .. " × " .. pitem .. ")")
  check(av(ms.construction[1]) <= k, "époque " .. k .. " : jalon de construction atteignable")
  local rn, rt = X.milestone_research(k)
  check(rt >= 1 and rn >= 1 and rn <= rt, "époque " .. k .. " : jalon de recherche " .. rn .. " sur " .. rt .. " technologies nouvelles")
  if ms.exploration.resource then
    local rr = idx.resource[ms.exploration.resource]
    local re = rr and rr.epoch
    if not re then for _, b in ipairs(X.base_resources) do if b.name == ms.exploration.resource then re = b.epoch end end end
    check(re and re <= k, "époque " .. k .. " : jalon d'exploration sur une ressource de l'époque ou d'avant")
  else
    check(ms.exploration.chart and ms.exploration.chart > 0, "époque " .. k .. " : jalon d'exploration (carte)")
  end
  for _, opts in ipairs({ {}, { military = true } }) do
    local win = X.pack_window(k, opts)
    local uniq = set_of(win)
    check(#win >= 1 and #win <= 4 and win[1] == e.pack and count_pairs(uniq) == #win,
      "époque " .. k .. " : fenêtre de packs" .. (opts.military and " militaire" or "") .. " de 1 à 4 sortes, sans doublon, pack de l'époque en tête")
    for _, pk in ipairs(win) do check(av(pk) <= k, "époque " .. k .. " : pack " .. pk .. " de la fenêtre disponible") end
  end
  total_hours = total_hours + X.epoch_hours(k)
  if k > 1 then
    check(X.epoch_hours(k) >= X.epoch_hours(k - 1), "époque " .. k .. " : durée croissante ou plafonnée")
    check(X.budget(k) > X.budget(k - 1) and X.cc_upgrade_mu(k) > X.cc_upgrade_mu(k - 1), "époque " .. k .. " : budget et passage du centre croissants")
  end
  check(X.rate_avg(k) < X.rate(k) and X.rate_avg(k) > X.rate(k - 1), "époque " .. k .. " : budget au débit MOYEN de l'époque")
end
check(X.epoch_hours(1) == 0.5, "F1-3 : époque 1 en 30 min")
check(math.abs(total_hours - 59.5) < 1e-9 and X.reach_hour(15) == 52.5, "F1-3 : 15 époques en 59,5 h ; époque 15 atteinte à 52,5 h (QX7)")
check(math.abs(X.rate(1) - 3) < 1e-9 and math.abs(X.rate(15) - 14000) < 1e-6, "débit visé de 3 à 14 000 MU/s")
local tier_start = { 1, 4, 7, 10, 13 }
local BMROWS = BM.derive(BM.PROPOSAL)
for t, ep in ipairs(tier_start) do
  check(X.logistics_tier(ep) == t and (ep == 1 or X.logistics_tier(ep - 1) == t - 1), "Q5 : palier T" .. t .. " à l'époque " .. ep .. " (un palier toutes les 3 époques)")
  check(X.compaction.tiers[t].epoch == ep and X.compaction.tiers[t].rho == BM.PROPOSAL.density[t]
        and X.compaction.tiers[t].belt == BM.PROPOSAL.belt_items[t], "constantes du palier T" .. t .. " égales à shared/balance_model.lua")
  check(X.TIER_DENSITY[t] == BM.PROPOSAL.density[t], "densité T" .. t .. " = BALANCE_SHEET §3")
end
check(X.builders(1) == 1 and X.builders(4) == 2 and X.builders(7) == 3 and X.builders(10) == 4 and X.builders(13) == 5, "ouvriers 1 à 5, un de plus toutes les 3 époques")
check(X.builders(15, true) == 6, "6e ouvrier avec l'Horloge éternelle (QX6)")
check(X.max_building_level(1) == 2 and X.max_building_level(15) == 30, "Q6 : 2 niveaux par époque, 30 niveaux à l'époque 15")
check(X.epoch_lock_tech(2) == "fo-epoch-2" and X.epoch_lock.first == 2 and X.epoch_lock.last == 15, "verrou d'époque : fo-epoch-2 à fo-epoch-15")
-- Coût des packs : croissant pour les packs NOUVEAUX (le vanilla, inchangé, est rapporté).
local is_new_pack = {}
for _, it in ipairs(X.items) do if it.use == "pack" then is_new_pack[it.name] = true end end
local mu_line = {}
for k = 1, 15 do mu_line[#mu_line + 1] = string.format("%d:%.1f", k, pack_mu[k]) end
info("MU des packs par époque : " .. table.concat(mu_line, " "))
for k = 2, 15 do
  local p = X.epochs[k].pack
  local prev_max = 0
  for j = 1, k - 1 do if pack_mu[j] > prev_max then prev_max = pack_mu[j] end end
  if is_new_pack[p] then
    check(pack_mu[k] >= pack_mu[k - 1] - 1e-9 and pack_mu[k] <= 3 * prev_max,
      string.format("époque %d : pack nouveau %s (%.1f MU) ≥ le pack de l'époque %d (%.1f MU) et ≤ 3 × le plus cher d'avant (%.1f)", k, p, pack_mu[k], k - 1, pack_mu[k - 1], prev_max))
  elseif pack_mu[k] < pack_mu[k - 1] then
    info(string.format("AVIS : pack vanilla %s (%.1f MU) moins cher que celui de l'époque %d (%.1f MU) : vanilla inchangé (QX4)", p, pack_mu[k], k - 1, pack_mu[k - 1]))
  end
end

---------------------------------------------------------------------------------------------------
section("Technologies (Q7, F1-6)")
---------------------------------------------------------------------------------------------------
local tech_by = {}
for _, t in ipairs(X.technologies) do
  check(tech_by[t.name] == nil, t.name .. " : nom de technologie unique")
  tech_by[t.name] = t
end
local unlocked_by = {}
for _, t in ipairs(X.technologies) do
  for _, rn in ipairs(t.unlocks) do
    unlocked_by[rn] = unlocked_by[rn] or {}
    table.insert(unlocked_by[rn], t)
  end
end
local start = set_of(X.start_recipes)
local PSEUDO = { mining = true, gather = true, loot = true, burn = true, launch = true, heat = true }
local n_real = 0
for _, r in ipairs(X.recipes) do
  if not PSEUDO[r.kind] then
    n_real = n_real + 1
    local by = unlocked_by[r.name] or {}
    if start[r.name] then
      check(#by == 0 and r.epoch == 1, r.name .. " : recette de départ (aucune technologie)")
    elseif r.unlock == "wonder" then
      check(#by == 0 and idx.building[r.wonder] and idx.building[r.wonder].wonder, r.name .. " : activée par la merveille " .. tostring(r.wonder))
    else
      check(#by == 1, r.name .. " : débloquée par exactement une technologie (" .. #by .. ")")
      if #by == 1 then
        check(by[1].epoch == r.epoch, r.name .. " : technologie " .. by[1].name .. " de son époque " .. r.epoch)
        check((by[1].branch or "") == (r.branch or "") and (by[1].level or 0) == (r.level or 0),
          r.name .. " : technologie de sa branche et de son niveau")
      end
    end
  end
end
for _, t in ipairs(X.technologies) do
  for _, rn in ipairs(t.unlocks) do check(idx.recipe[rn] ~= nil and not PSEUDO[idx.recipe[rn].kind], t.name .. " : débloque une recette réelle " .. rn) end
  check(#t.unlocks >= 1, t.name .. " : débloque au moins une recette")
  check(t.units >= 1 and t.units % 1 == 0, t.name .. " : nombre d'unités entier")
  check(#t.packs >= 1 and #t.packs <= 4, t.name .. " : 1 à 4 sortes de packs")
  for _, pk in ipairs(t.packs) do
    check(av(pk) <= t.epoch and (t.role ~= "pack" or pk ~= X.epochs[t.epoch].pack),
      t.name .. " : pack " .. pk .. " disponible avant la technologie (technologie de pack : fenêtre précédente)")
  end
  for _, pr in ipairs(t.prereq) do
    check(tech_by[pr] ~= nil and tech_by[pr].epoch <= t.epoch, t.name .. " : prérequis " .. pr .. " déclaré, d'une époque antérieure ou égale")
  end
  if t.branch then
    local br = idx.branch[t.branch]
    if t.level == 3 then check(t.mastery and t.epoch == X.MASTERY_CHOSEN_EPOCH, t.name .. " : maîtrise à l'époque 14 (Serment), 15 sinon")
    else check(t.epoch >= br.epochs[t.level], t.name .. " : niveau " .. t.level .. " pas avant l'époque " .. br.epochs[t.level]) end
  end
end
-- Graphe de prérequis : sans cycle (tri topologique déterministe).
do
  local indeg, order = {}, {}
  for _, t in ipairs(X.technologies) do indeg[t.name] = 0 end
  for _, t in ipairs(X.technologies) do for _, pr in ipairs(t.prereq) do if tech_by[pr] then indeg[t.name] = indeg[t.name] + 1 end end end
  local ready = {}
  for _, t in ipairs(X.technologies) do if indeg[t.name] == 0 then ready[#ready + 1] = t.name end end
  while #ready > 0 do
    table.sort(ready)
    local n = table.remove(ready, 1)
    order[#order + 1] = n
    for _, t in ipairs(X.technologies) do
      for _, pr in ipairs(t.prereq) do
        if pr == n then indeg[t.name] = indeg[t.name] - 1; if indeg[t.name] == 0 then ready[#ready + 1] = t.name end end
      end
    end
  end
  check(#order == #X.technologies, "prérequis des technologies sans cycle (" .. #order .. " / " .. #X.technologies .. ")")
end
-- Le pack nouveau de l'époque k se fabrique avec les recettes des époques < k, de la technologie de pack et
-- les recettes de départ (sinon sa recherche serait impossible).
for _, t in ipairs(X.technologies) do
  if t.role == "pack" then
    local mine = set_of(t.unlocks)
    fixpoint(function(r)
      if r.base or r.barrel or PSEUDO[r.kind] then return false end
      if start[r.name] then return false end
      return not (r.epoch < t.epoch or mine[r.name])
    end)
    local p = X.epochs[t.epoch].pack
    check(av(p) <= t.epoch, t.name .. " : le pack " .. p .. " se fabrique avec ce que la technologie de pack débloque")
  end
end
fixpoint()

-- Coût de la recherche : technologies nouvelles + vanilla re-rangée (relue dans technology.lua).
local vanilla_tech_cost, vanilla_tech_raw, vanilla_techs = {}, {}, nil
for k = 1, 15 do vanilla_tech_cost[k], vanilla_tech_raw[k] = 0, 0 end
local function window_mu(packs) local s = 0 for _, p in ipairs(packs) do s = s + (mu_of(p) < INF and mu_of(p) or 0) end return s end
-- Lot X3-MINERAIS (30/10) : FO_DATA_DIR d'abord (comme levels_test), pour une copie du mod hors de l'arborescence du jeu
-- (git archive dans un dossier jetable) ; sans lui, une telle copie ne trouvait pas technology.lua et la part de la
-- recherche tombait à 17 % (x3_test « rouge sur 0.6.21 » à l'intégration de la 0.6.22 : faux rouge).
local tech_candidates = { "../../data/base/prototypes/technology.lua", "../../../../../data/base/prototypes/technology.lua" }
if os.getenv("FO_DATA_DIR") then table.insert(tech_candidates, 1, os.getenv("FO_DATA_DIR") .. "/base/prototypes/technology.lua") end
for _, p in ipairs(tech_candidates) do
  if not vanilla_techs then
    local f = io.open(p, "rb")
    if f then
      f:close()
      local list = {}
      local env = setmetatable({ data = { extend = function(_, t) for _, x in ipairs(t) do list[#list + 1] = x end end },
        util = setmetatable({}, { __index = function() return function() return {} end end }) }, { __index = _G })
      local chunk = loadfile(p, "t", env)
      if chunk and pcall(chunk) then vanilla_techs = list; info("technologies vanilla relues : " .. p .. " (" .. #list .. ")") end
    end
  end
end
local PACK_EPOCH = {}
for k, e in ipairs(X.epochs) do PACK_EPOCH[e.pack] = k end
local vtech_epoch_fixed = {}
for _, row in ipairs(X.vanilla_tech_epochs) do vtech_epoch_fixed[row[1]] = row[2] end
local split_of = {}
for _, s in ipairs(X.vanilla_tech_splits) do split_of[s.tech] = s end
if vanilla_techs then
  section("Technologies vanilla : époques et scissions")
  local vt_names = {}
  for _, t in ipairs(vanilla_techs) do vt_names[t.name] = t end
  for _, row in ipairs(X.vanilla_tech_epochs) do check(vt_names[row[1]] ~= nil, row[1] .. " : technologie vanilla réelle (re-rangement)") end
  for _, t in ipairs(vanilla_techs) do
    local epochs, recipes_of = {}, {}
    for _, ef in ipairs(t.effects or {}) do
      if ef.type == "unlock-recipe" and not never[ef.recipe] then
        local e = base_epoch[ef.recipe]
        if e then epochs[e] = true; recipes_of[#recipes_of + 1] = ef.recipe end
      end
    end
    local ks = sorted_keys(epochs)
    if #ks > 1 then
      local sp = split_of[t.name]
      check(sp ~= nil, t.name .. " : recettes à plusieurs époques (" .. table.concat(ks, ", ") .. ") : scission déclarée dans X.vanilla_tech_splits")
      if sp then
        local declared = {}
        for _, part in ipairs(sp.parts) do for _, rn in ipairs(part[2]) do declared[rn] = part[1] end end
        for _, rn in ipairs(recipes_of) do check(declared[rn] == base_epoch[rn], t.name .. " : scission de " .. rn .. " à l'époque " .. tostring(base_epoch[rn])) end
      end
    end
    -- Coût, à l'époque de la technologie, avec la fenêtre de packs.
    if t.unit and t.unit.count and not t.max_level then
      local e = vtech_epoch_fixed[t.name]
      if not e then
        e = 0
        for _, k in ipairs(ks) do if k > e then e = k end end
        if e == 0 then
          for _, ing in ipairs(t.unit.ingredients or {}) do local pe = PACK_EPOCH[ing[1] or ing.name] or 1; if pe > e then e = pe end end
        end
      end
      local mil = false
      for _, ing in ipairs(t.unit.ingredients or {}) do if (ing[1] or ing.name) == "military-science-pack" then mil = true end end
      e = math.max(1, math.min(15, e))
      vanilla_tech_raw[e] = vanilla_tech_raw[e] + t.unit.count * window_mu(X.pack_window(e, { military = mil }))
      vanilla_tech_cost[e] = vanilla_tech_cost[e] + t.unit.count * X.VANILLA_UNIT_SCALE[e] * window_mu(X.pack_window(e, { military = mil }))
    end
  end
  for _, sp in ipairs(X.vanilla_tech_splits) do check(vt_names[sp.tech] ~= nil, sp.tech .. " : scission d'une technologie vanilla réelle") end
else
  info("AVIS : data/base/prototypes/technology.lua introuvable ; scissions et recherche vanilla non relues")
  -- Un échec NOMMÉ plutôt que des parts de recherche fausses (17 % au lieu de 30 à 40 %) sans cause visible.
  check(false, "données vanilla introuvables (technology.lua) : lancer depuis <mod> ou un worktree de .claude/worktrees, ou poser FO_DATA_DIR=<racine>/data")
end
section("Coût de la recherche par époque (30 à 40 % du budget)")
local research_share, research_mu = {}, {}
for k = 1, 15 do
  local x0, wsum = 0, 0
  for _, t in ipairs(X.technologies) do
    if t.epoch == k then
      local c = window_mu(t.packs)
      x0 = x0 + t.units * c
      wsum = wsum + (t.units / X.TECH_UNITS[k]) * c
    end
  end
  local share = (x0 + vanilla_tech_cost[k]) / X.budget(k)
  research_share[k] = share
  local need = wsum > 0 and (0.35 * X.budget(k) - vanilla_tech_cost[k]) / wsum or 0
  info(string.format("époque %2d : nouvelle %s MU + vanilla %s MU (brut %s, ×%g) = %.1f %% du budget (unités pour 35 %% : %.0f, déclarées %d ; échelle vanilla pour 17,5 %% : %.3f)",
    k, tostring(math.floor(x0)), tostring(math.floor(vanilla_tech_cost[k])), tostring(math.floor(vanilla_tech_raw[k])), X.VANILLA_UNIT_SCALE[k],
    100 * share, need, X.TECH_UNITS[k], vanilla_tech_raw[k] > 0 and math.min(1, 0.175 * X.budget(k) / vanilla_tech_raw[k]) or 1))
  if vanilla_techs then
    check(share >= 0.30 and share <= 0.40, string.format("époque %d : recherche = %.1f %% du budget (30 à 40 %%)", k, 100 * share))
  end
  research_mu = research_mu or {}
  research_mu[k] = x0 + vanilla_tech_cost[k]
end
-- BALANCE_SHEET §4.5 : le coût de la recherche d'un palier croît d'au moins ×4 (ici comme le budget).
for t = 2, 5 do
  local cur, prev = 0, 0
  for k = 1, 15 do
    if X.logistics_tier(k) == t then cur = cur + research_mu[k] elseif X.logistics_tier(k) == t - 1 then prev = prev + research_mu[k] end
  end
  check(cur >= 4 * prev, string.format("palier T%d : recherche %s MU ≥ 4 × T%d (%s MU) : ×%.1f", t, tostring(math.floor(cur)), t - 1, tostring(math.floor(prev)), cur / prev))
  info(string.format("palier T%d : recherche ×%.1f par rapport à T%d", t, cur / prev, t - 1))
end
-- Les packs exotiques de l'époque 15 tiennent dans le débit des failles garanties (la moitié au plus).
do
  local per_matter = idx.recipe["fo-exotic-pack"].results[1][2]
  local packs = 0
  for _, t in ipairs(X.technologies) do
    if t.epoch == 15 then for _, p in ipairs(t.packs) do if p == "fo-exotic-pack" then packs = packs + t.units end end end
  end
  local need = packs / per_matter + 230
  local supply = X.currency_of(15).cap_per_s * 3600 * X.epoch_hours(15)
  check(need <= 0.5 * supply, string.format("époque 15 : %.0f matières exotiques (packs et Porte) ≤ la moitié des %.0f que donnent 3 failles en 7 h", need, supply))
  info(string.format("époque 15 : %.0f matières exotiques (packs et Porte) pour %.0f possibles en 7 h avec 3 failles", need, supply))
end

---------------------------------------------------------------------------------------------------
section("Branches avancées (Q7)")
---------------------------------------------------------------------------------------------------
local branch_item = {}
for _, it in ipairs(X.items) do if it.branch then branch_item[it.name] = it.branch end end
for _, b in ipairs(X.buildings) do if b.branch then branch_item[b.name] = b.branch end end
local segment = idx.recipe["fo-ring-segment"]
local factions_seen = {}
for _, br in ipairs(X.branches) do
  check(br.epochs[1] < br.epochs[2] and br.epochs[2] <= br.epochs[3], "branche " .. br.key .. " : niveaux I < II ≤ III")
  check(br.epochs[3] == X.MASTERY_CHOSEN_EPOCH, "branche " .. br.key .. " : maîtrise à l'époque 14 si Serment")
  check(X.mastery_epoch(br.key, br.key) == 14 and X.mastery_epoch(br.key, "?") == 15, "branche " .. br.key .. " : Serment, 14 choisie, 15 sinon")
  for level = 1, 3 do
    local n, nb, use = 0, 0, false
    for _, r in ipairs(X.recipes) do
      if r.branch == br.key and r.level == level then
        n = n + 1
        if level == 3 then
          check(r.epoch == br.epochs[3], r.name .. " : maîtrise " .. br.key .. "-III à l'époque " .. br.epochs[3] .. " (Serment)")
        else
          check(r.epoch >= br.epochs[level] and r.epoch < br.epochs[3], r.name .. " : recette " .. br.key .. "-" .. level
            .. " entre l'ouverture du niveau (" .. br.epochs[level] .. ") et la maîtrise")
        end
        check(recipe_avail(r) == r.epoch, r.name .. " : recette de branche atteignable à son époque")
        -- Usage hors recherche : un produit qui n'est ni une donnée de recherche ni un intermédiaire caché.
        for _, p in ipairs(r.results) do
          local it = idx.item[p[1]]
          if (it and (it.use == "ammo" or it.use == "consumable" or it.use == "armor" or it.use == "launch")) or (r.variant_of ~= nil) then use = true end
          if idx.building[p[1]] then use = true end
        end
      end
    end
    for _, b in ipairs(X.buildings) do if b.branch == br.key and b.level == level then nb = nb + 1 end end
    check(n >= 2, "branche " .. br.key .. " niveau " .. level .. " : ses propres recettes (" .. n .. ")")
    check(nb >= 1, "branche " .. br.key .. " niveau " .. level .. " : au moins un bâtiment propre (" .. nb .. ")")
    check(use, "branche " .. br.key .. " niveau " .. level .. " : un usage hors recherche (bâtiment, munition, consommable, variante)")
  end
  local data = idx.item[br.data]
  check(data and data.use == "data" and data.branch == br.key and data.level == 1 and av(br.data) == br.epochs[1],
    "branche " .. br.key .. " : donnée de recherche produite dès le niveau I")
  local gi = idx.item[br.gate_item]
  check(gi and gi.branch == br.key and gi.level == 2, "branche " .. br.key .. " : produit de niveau II pour la Porte")
  local used = false
  for _, i in ipairs(segment.ingredients) do if i[1] == br.gate_item then used = true end end
  check(used, "branche " .. br.key .. " : chaque segment d'anneau consomme " .. br.gate_item)
  check(X.branch_params[br.mechanic] ~= nil or br.mechanic == "tide", "branche " .. br.key .. " : mécanique propre paramétrée (" .. br.mechanic .. ")")
  local w = idx.building[br.wonder]
  check(w and w.wonder and w.branch == br.key and w.proto == "simple-entity-with-owner" and w.effect_fr, "branche " .. br.key .. " : merveille " .. tostring(br.wonder) .. " (type réel, effet écrit)")
  factions_seen[br.faction] = br.key
end
check(#X.tide == 24, "marée : 24 phases")
for _, r in ipairs(X.recipes) do
  if not r.branch and r.epoch <= 14 then
    for _, i in ipairs(r.ingredients) do
      check(not branch_item[i[1]], r.name .. " : la ligne principale ne dépend pas de l'objet de branche " .. i[1])
    end
  end
end
local doc_by_faction = {}
for _, d in ipairs(X.doctrines) do doc_by_faction[d.faction] = d end
for _, d in ipairs(X.doctrines) do
  check(factions_seen[d.faction] == d.branch, d.faction .. " : doctrine " .. d.branch .. " cohérente avec la branche")
  check(doc_by_faction[d.sworn_rival] and doc_by_faction[d.sworn_rival].sworn_rival == d.faction, d.faction .. " : rivalité jurée réciproque")
end
-- Branche C bornée (correction) : la vitesse se paie, une chambre par machine, sabliers et coffres plafonnés.
do
  local dp, hp, ep = X.branch_params.dilation, X.branch_params.hourglass, X.branch_params.entangled
  check(dp.level2.consumption >= dp.level2.speed and dp.level3.consumption > dp.level3.speed,
    "dilatation : consommation ≥ vitesse (II), > vitesse (III) : jamais d'énergie par produit en baisse")
  check(dp.one_per_machine and set_of(dp.excluded_protos)["mining-drill"] and set_of(dp.excluded_protos)["lab"] and set_of(dp.excluded_flags)["confinement"],
    "dilatation : une chambre par machine ; ni foreuses, ni laboratoires, ni bâtiments à confinement")
  check(idx.recipe["fo-phase-maintenance"].time == dp.maintenance_s and dp.maintenance_s <= 120, "dilatation : un cristal stable déphasé toutes les 120 s")
  check(idx.building["fo-dilation-chamber"].dilation.speed == dp.level2.speed and idx.building["fo-dilation-chamber-2"].dilation.consumption == dp.level3.consumption,
    "dilatation : bâtiments et paramètres identiques")
  local hg = idx.recipe["fo-quantum-hourglass"]
  local has_currency = false
  for _, i in ipairs(hg.ingredients) do if X.currency_of(hg.epoch) and i[1] == X.currency_of(hg.epoch).item then has_currency = true end end
  check(hg.results[1][2] == hp.per_craft and hp.per_craft == 1 and has_currency, "sablier : 1 par fabrication, monnaie d'époque dans son coût")
  check(hp.max_per_job == 1 and hp.max_per_job_clock == 2 and hp.share * hp.max_per_job_clock <= 0.5, "sablier : 1 par chantier (2 avec l'Horloge), 50 % retirés au plus")
  check(idx.building["fo-entangled-chest"].inventory == ep.inventory and ep.inventory == 1 and ep.pairs_level2 == 2 and ep.pairs_level3 == 4 and ep.pair_kw > 0,
    "coffres intriqués : 1 case, 2 puis 4 paires, énergie par paire")
end
-- Branche B : la maîtrise rend plus par piège que la fusion catalysée (correction).
do
  local fuel_of = {}
  for _, it in ipairs(X.items) do if it.fuel then fuel_of[it.name] = it.fuel end end
  local cat = idx.recipe["fo-catalyzed-fusion-pellet"]
  local traps = 0
  for _, i in ipairs(cat.ingredients) do if i[1] == "fo-antihydrogen-trap" then traps = i[2] end end
  local gain_ii = (fuel_of["fo-catalyzed-fusion-pellet"] - fuel_of["fo-fusion-pellet"]) * cat.results[1][2] / traps
  check(fuel_of["fo-antihydrogen-trap"] > gain_ii, string.format("B-III (%g MJ par piège) rend plus que B-II (%g MJ par piège)", fuel_of["fo-antihydrogen-trap"], gain_ii))
end
-- Branche D : la transmutation coûte au plus 5 MJ par minerai (correction : 50 MJ).
do
  local r, m = idx.recipe["fo-transmutation-tungsten"], idx.building["fo-transmuter"]
  local mj = m.kw * r.time / m.speed / 1000 / r.results[2][2]
  check(mj <= 5, string.format("transmutation : %.2f MJ par minerai (5 au plus)", mj))
  local c = X.branch_params.contagion
  check(c.overflow_ticks and c.unpowered_ticks and c.crowd and c.crowd.max_vats >= 1, "contagion : débordement, coupure de courant et entassement")
end

---------------------------------------------------------------------------------------------------
section("Règles de production (P3, P5, P7)")
---------------------------------------------------------------------------------------------------
local consumers, producers = {}, {}
for _, r in ipairs(all) do
  for _, i in ipairs(r.ingredients) do consumers[i[1]] = (consumers[i[1]] or 0) + 1 end
  for _, p in ipairs(r.results) do
    producers[p[1]] = producers[p[1]] or {}
    table.insert(producers[p[1]], r)
  end
end
local SINK_USES = { pack = true, data = true, codex = true, ammo = true, armor = true, tile = true, consumable = true, launch = true }
for _, it in ipairs(X.items) do
  check(producers[it.name] ~= nil, it.name .. " : a une recette ou une source")
  local sink = (consumers[it.name] or 0) > 0 or SINK_USES[it.use or ""] or it.counter_only or false
  check(sink, it.name .. " : consommé par une recette ou par un usage (" .. tostring(it.use) .. ")")
end
for _, b in ipairs(X.buildings) do check(producers[b.name] ~= nil, b.name .. " : bâtiment fabricable") end
for _, fl in ipairs(X.flare_fluids) do check(is_fluid[fl] and idx.recipe["fo-flare-" .. fl:sub(4)], fl .. " : puits de torchère") end
local prod_count = 0
for _, r in ipairs(X.recipes) do
  local self_loop = false
  local in_names = {}
  for _, i in ipairs(r.ingredients) do in_names[i[1]] = i end
  for _, p in ipairs(r.results) do if in_names[p[1]] then self_loop = true end end
  if self_loop then
    check(r.process == "catalytic" or r.process == "conversion" or r.process == "transmutation",
      r.name .. " : un ingrédient ressort du même cycle → recette catalytique déclarée")
    for _, p in ipairs(r.results) do
      local i = in_names[p[1]]
      if i then check(i.catalyst and p.catalyst and i.catalyst == p.catalyst and i.catalyst <= i[2] and p.catalyst <= p[2],
        r.name .. " : catalyst_amount égal des deux côtés pour " .. p[1]) end
    end
  end
  if r.prod then
    prod_count = prod_count + 1
    check(not self_loop and r.process == nil and r.kind == "recipe", r.name .. " : productivité seulement sur un intermédiaire simple")
    local main = r.results[1][1]
    for _, i in ipairs(r.ingredients) do
      for _, s in ipairs(producers[i[1]] or {}) do
        local back = false
        for _, si in ipairs(s.ingredients) do if si[1] == main then back = true end end
        check(not back or s.kind == "burn", r.name .. " : pas de boucle réversible avec " .. s.name .. " (productivité + boucle = matière infinie)")
      end
    end
  end
  if r.process then check(not r.prod, r.name .. " : aucune productivité sur « " .. r.process .. " »") end
end
info(prod_count .. " recettes nouvelles admettent la productivité")
local fuel = {}
for _, f in ipairs(X.base_fuel) do fuel[f.name] = f.fuel end
for _, it in ipairs(X.items) do if it.fuel then fuel[it.name] = it.fuel end end
check(fuel["fo-hydrogen"] == nil and fuel["fo-ethylene"] == nil and fuel["fo-cryogenic-propellant"] == nil,
  "hydrogène, éthylène et ergol cryogénique sans valeur de combustion (sinon électrolyse + combustion = énergie gratuite)")
local function machine_energy_mj(r)
  local best = INF
  for _, m in ipairs(machines_of(r)) do
    local d = machine_def[m]
    local kw, speed = d.kw or 0, d.speed or 1
    local e = d.hand and 0 or kw * r.time / speed / 1000
    if e < best then best = e end
  end
  return best == INF and 0 or best
end
local whitelisted = 0
for _, r in ipairs(X.recipes) do
  if r.kind == "recipe" or r.kind == "building" then
    local out_mj, in_mj, white = 0, 0, r.whitelist_fr ~= nil
    for _, p in ipairs(r.results) do
      if fuel[p[1]] then
        out_mj = out_mj + fuel[p[1]] * (p[2] - (p.catalyst or 0)) * (p.p or 1)
        local it = idx.item[p[1]]
        if it and it.whitelist_fr then white = true end
      end
    end
    for _, i in ipairs(r.ingredients) do if fuel[i[1]] then in_mj = in_mj + fuel[i[1]] * (i[2] - (i.catalyst or 0)) end end
    in_mj = in_mj + machine_energy_mj(r)
    if out_mj > 0 then
      if white then
        whitelisted = whitelisted + 1
        check(type(r.whitelist_fr) == "string" and #r.whitelist_fr > 10 or (idx.item[r.results[1][1]] and idx.item[r.results[1][1]].whitelist_fr),
          r.name .. " : liste blanche justifiée par écrit (recette ou combustible)")
      else
        check(out_mj < in_mj, string.format("%s : combustible produit %.1f MJ < investi %.1f MJ", r.name, out_mj, in_mj))
      end
    end
  end
end
for _, it in ipairs(X.items) do
  if it.storage then
    local charge
    for _, r in ipairs(producers[it.name] or {}) do if r.category == "fo-charging" then charge = r end end
    check(charge and it.fuel <= 0.8 * machine_energy_mj(charge) + 1e-9, it.name .. " : énergie stockée rendue à 80 % au plus")
    check(it.burnt and producers[it.burnt], it.name .. " : contenant rendu vide à la décharge (burnt_result)")
  end
  if it.whitelist_fr then check(#it.whitelist_fr > 10, it.name .. " : liste blanche d'énergie justifiée par écrit") end
end
info(whitelisted .. " recette(s) en liste blanche d'énergie (fission, fusion, annihilation, butin)")

---------------------------------------------------------------------------------------------------
section("Compaction ×4 (B1) : formes denses, débit et énergie par machine (shared/balance_model.lua)")
---------------------------------------------------------------------------------------------------
local variants = 0
for _, r in ipairs(X.recipes) do
  if r.dense then
    local main = r.results[1][1]
    local it = idx.item[main]
    local born_epoch = it and it.epoch or av(main)
    local born_rho = it and it.rho or 1
    local forms = X.dense_forms(born_epoch, born_rho)
    check(forms[1] == born_rho and forms[#forms] <= 32, r.name .. " : formes denses de ρ" .. born_rho .. " à ρ32 au plus")
    for j = 2, #forms do check(forms[j] > forms[j - 1], r.name .. " : densités strictement croissantes") end
    if born_rho >= 8 then check(forms[1] >= 8, r.name .. " : matière née dense, jamais en ρ1 (P4)") end
    variants = variants + (#forms - 1)
  end
end
local f_ti = X.dense_forms(11, 8)
check(#f_ti == 2 and f_ti[1] == 8 and f_ti[2] == 32, "le titane n'existe qu'en ρ8 et ρ32")
check(#X.dense_forms(1, 1) == 5, "le fer existe en ρ1, 2, 4, 8 et 32")
local f_pl = X.dense_forms(4, 1)
check(#f_pl == 4 and f_pl[2] == 4, "le plastique (né en T2) commence à ρ4")
for _, n in ipairs(X.compaction.intermediates) do check(known[n], "intermédiaire dense " .. n .. " : objet vanilla réel") end
for _, bmat in ipairs(X.compaction.base_materials) do check(known[bmat[1]], "matière compactée " .. bmat[1] .. " : objet réel") end
info(variants .. " variantes denses de recettes à générer par le lot C (hors intermédiaires)")
local heat_mj = {}
for _, it in ipairs(X.items) do if it.heat_mj_per_unit then heat_mj[it.name] = it.heat_mj_per_unit end end
local TIER_OF_RHO = { [8] = 4, [32] = 5 }
--- Débit (MU/s) et énergie (kJ/MU, chaleur des fluides comprise) de la meilleure machine d'une recette.
local function machine_rate(r)
  local main = r.results[1]
  local best_mu, best_kj, best_m = 0, INF, nil
  for _, m in ipairs(machines_of(r)) do
    local d = machine_def[m]
    local crafts = (d.speed or 1) / r.time
    local mus = crafts * main[2] * (rho[main[1]] or 1)
    local kw = (d.kw or 0)
    for _, i in ipairs(r.ingredients) do if heat_mj[i[1]] then kw = kw + crafts * i[2] * heat_mj[i[1]] * 1000 end end
    if mus > best_mu then best_mu, best_kj, best_m = mus, kw / mus, m end
  end
  return best_mu, best_kj, best_m
end
for _, r in ipairs(X.recipes) do
  if r.kind == "recipe" and r.process ~= "decompaction" then
    local main = r.results[1][1]
    local t = TIER_OF_RHO[rho[main] or 1]
    if t and idx.item[main] and idx.item[main].material then
      local row = BMROWS[t]
      local mus, kj, m = machine_rate(r)
      check(mus >= 0.5 * row.machine_mu - 1e-6, string.format("%s : %.1f MU/s par machine (%s) ≥ 0,5 × %g (T%d)", r.name, mus, tostring(m), row.machine_mu, t))
      check(kj <= 2 * row.energy_kj_per_mu + 1e-6, string.format("%s : %.0f kJ/MU ≤ 2 × %.0f (T%d)", r.name, kj, row.energy_kj_per_mu, t))
    end
  end
end
-- Foreuses de la ligne principale : à chaque palier, la meilleure suit le modèle ; plafond de foreuses.
local function best_drill_mu(k)
  local best, name = 0, nil
  for _, mn in ipairs(sorted_keys(machine_def)) do
    local d = machine_def[mn]
    if d.mining_speed and not d.branch and not d.hand and set_of(d.resource_categories)["basic-solid"] then
      local e = d.epoch or AVAIL[mn] or 1
      if e <= k and d.mining_speed > best then best, name = d.mining_speed, mn end
    end
  end
  return best, name
end
for k = 1, 15 do
  local mus, name = best_drill_mu(k)
  local n = X.rate(k) / mus
  check(n <= X.compaction.drill_cap, string.format("époque %d : %.0f foreuses %s pour %.0f MU/s (plafond %d)", k, n, tostring(name), X.rate(k), X.compaction.drill_cap))
  local t = X.logistics_tier(k)
  if t >= 4 then check(mus >= 0.5 * BMROWS[t].machine_mu, string.format("époque %d : meilleure foreuse %s à %.0f MU/s ≥ 0,5 × %g (T%d)", k, tostring(name), mus, BMROWS[t].machine_mu, t)) end
end
-- Chaînes T4 et T5 : la foreuse alimente 1:1 sa machine accolée ; MW réels par tapis.
local chain_report = {}
for _, ch in ipairs(X.compaction.chains) do
  local drill = idx.building[ch.drill]
  local row = BMROWS[ch.tier]
  local belt_items = row.belt_items
  local first = idx.recipe[ch.steps[1]]
  local ore_in = 0
  for _, i in ipairs(first.ingredients) do if i[1] == ch.ore then ore_in = i[2] end end
  local fed = idx.building[drill.feeds]
  local fed_ore_per_s = fed.speed / first.time * ore_in
  check(drill.feeds and set_of(machines_of(first))[drill.feeds], ch.drill .. " : alimente " .. tostring(drill.feeds) .. ", machine de " .. first.name)
  check(math.abs(fed_ore_per_s / drill.mining_speed - 1) <= 0.05,
    string.format("%s : %.1f minerais/s pour %.1f consommés par %s (1:1 à 5 %% près)", ch.drill, drill.mining_speed, fed_ore_per_s, drill.feeds))
  -- Machines par tapis et puissance : chaque étape à sa cadence, pour un tapis plein du produit final.
  local items_per_s = belt_items
  local mw, heat_mw, machines = 0, 0, {}
  local need = items_per_s -- produit de l'étape courante, par seconde
  for s = #ch.steps, 1, -1 do
    local r = idx.recipe[ch.steps[s]]
    local mus, _, m = machine_rate(r)
    local d = machine_def[m]
    local crafts_needed = need / r.results[1][2]
    local nm = crafts_needed / ((d.speed or 1) / r.time)
    mw = mw + nm * (d.kw or 0) / 1000
    for _, i in ipairs(r.ingredients) do if heat_mj[i[1]] then heat_mw = heat_mw + crafts_needed * i[2] * heat_mj[i[1]] end end
    machines[#machines + 1] = string.format("%.0f %s", nm, idx.building[m] and idx.building[m].fr or m)
    -- amont : la quantité d'ingrédient principal (le premier) nécessaire
    need = crafts_needed * r.ingredients[1][2]
  end
  local ndrills = need / drill.mining_speed
  mw = mw + ndrills * drill.kw / 1000
  machines[#machines + 1] = string.format("%.0f %s", ndrills, drill.fr)
  chain_report[ch.tier] = { mw = mw, heat_mw = heat_mw, machines = machines, product = ch.product, belt_mu = belt_items * (rho[ch.product] or 1) }
  info(string.format("T%d : tapis de %s = %s ; %.0f MW électriques + %.0f MW de chaleur", ch.tier, ch.product, table.concat(machines, " + "), mw, heat_mw))
end

---------------------------------------------------------------------------------------------------
section("Limites moteur 1.1.91 par recette et par bâtiment")
---------------------------------------------------------------------------------------------------
local NO_FLUID_CATEGORIES = { crafting = true, ["advanced-crafting"] = true, ["basic-crafting"] = true }
for _, r in ipairs(X.recipes) do
  if r.kind ~= "mining" and r.kind ~= "gather" and r.kind ~= "loot" then
    check(type(r.time) == "number" and r.time > X.LIMITS.energy_required_min, r.name .. " : durée > 0,001 s")
  end
  local names, n_item_in, n_fluid_in, n_fluid_out = {}, 0, 0, 0
  for _, i in ipairs(r.ingredients) do
    check(not names[i[1]], r.name .. " : ingrédient en double " .. i[1])
    names[i[1]] = true
    if is_fluid[i[1]] then
      n_fluid_in = n_fluid_in + 1
      check(i[2] > 0, r.name .. " : quantité de fluide positive")
    else
      n_item_in = n_item_in + 1
      check(i[2] >= 1 and i[2] <= X.LIMITS.item_amount_max and i[2] % 1 == 0, r.name .. " : quantité d'objet entière de 1 à 65 535 (" .. i[1] .. ")")
    end
    if i.catalyst then check(i.catalyst <= i[2], r.name .. " : catalyseur ≤ quantité") end
  end
  for _, p in ipairs(r.results) do
    if is_fluid[p[1]] then
      n_fluid_out = n_fluid_out + 1
      check(p[2] > 0, r.name .. " : produit fluide positif")
    else
      check(p[2] >= 1 and p[2] <= X.LIMITS.item_amount_max and p[2] % 1 == 0, r.name .. " : produit entier de 1 à 65 535 (" .. p[1] .. ")")
    end
    if p.p then check(p.p > 0 and p.p <= 1, r.name .. " : probabilité dans ]0, 1]") end
  end
  check(n_item_in <= X.LIMITS.assembler_ingredients_max, r.name .. " : 255 ingrédients au plus")
  if r.category and NO_FLUID_CATEGORIES[r.category] then
    check(n_fluid_in == 0 and n_fluid_out == 0, r.name .. " : aucune recette « " .. r.category .. " » avec fluide")
  end
  if r.category == "smelting" or r.category == "fo-flaring" then
    check(n_item_in <= X.LIMITS.furnace_item_inputs_max, r.name .. " : un four n'a qu'une case d'entrée")
  end
  -- Cohérence des données (pas un contrôle du moteur) : boîtes de fluide déclarées suffisantes.
  if r.category and not r.machines then
    local fits = false
    for _, m in ipairs(machines_of(r)) do
      local d = machine_def[m]
      if (d.fluid_in or 0) >= n_fluid_in and (d.fluid_out or 0) >= n_fluid_out then fits = true end
    end
    check(fits, string.format("%s : une machine de « %s » a %d entrée(s) et %d sortie(s) de fluide (cohérence des données)", r.name, r.category, n_fluid_in, n_fluid_out))
  end
  if r.kind == "mining" then
    local res = idx.resource[r.resource]
    for _, m in ipairs(r.machines) do
      local d = machine_def[m]
      local ok = false
      for _, c in ipairs(d.resource_categories or {}) do if res and c == res.category then ok = true end end
      check(ok, r.name .. " : " .. m .. " mine la catégorie " .. tostring(res and res.category))
      if n_fluid_out > 0 then check(d.output_fluid, r.name .. " : " .. m .. " a une sortie de fluide") end
      if n_fluid_in > 0 then check(d.input_fluid, r.name .. " : " .. m .. " a une entrée de fluide") end
    end
  end
  if r.kind == "burn" then
    local it = idx.item[r.ingredients[1][1]]
    for _, m in ipairs(r.machines) do
      local d = machine_def[m]
      check(d.energy and d.energy.fuel_category == it.fuel_category, r.name .. " : " .. m .. " brûle la catégorie " .. tostring(it.fuel_category))
      if it.burnt then check(d.burnt_inventory, r.name .. " : " .. m .. " a une case de résidu (burnt_result)") end
    end
  end
  if r.kind == "launch" then
    for _, m in ipairs(r.machines) do
      local d = machine_def[m]
      local slots = 0
      for _, p in ipairs(r.results) do
        local it = idx.item[p[1]]
        slots = slots + math.ceil(p[2] / ((it and it.stack) or (p[1] == "space-science-pack" and 2000) or 1))
      end
      check(slots <= (d.result_inventory or 0), string.format("%s : %d case(s) de résultat ≤ %d de %s", r.name, slots, d.result_inventory or 0, m))
    end
    if r.extraction then
      local out, cost = 0, 0
      for _, p in ipairs(r.results) do out = out + p[2] * unit_weight(p[1]) end
      for _, i in ipairs(r.ingredients) do cost = cost + i[2] * mu_of(i[1]) end
      check(out >= 2 * cost, string.format("%s : valeur rendue %.0f MU ≥ 2 × coût %.0f MU", r.name, out, cost))
    end
    if r.power_kw then check(r.power_kw <= idx.building["fo-rectenna"].output_kw, r.name .. " : une rectenna reçoit une centrale entière") end
  end
end
-- Champs obligatoires par type, types réels, chaleur.
local heat_max = {}
for _, mn in ipairs(sorted_keys(machine_def)) do
  local d = machine_def[mn]
  if d.max_temperature then heat_max[mn] = d.max_temperature end
end
local level_protos, by_family = 0, {}
for _, b in ipairs(X.buildings) do
  check(typenames[b.proto], b.name .. " : type de prototype « " .. tostring(b.proto) .. " » réel en 1.1.91")
  check(b.size[1] <= X.LIMITS.new_building_side_max and b.size[2] <= X.LIMITS.new_building_side_max, b.name .. " : 10 × 10 au plus (Q9)")
  if b.proto == "assembling-machine" or b.proto == "furnace" or b.proto == "rocket-silo" then
    check(b.categories and #b.categories >= 1, b.name .. " : crafting_categories non vide (obligatoire)")
    check(type(b.kw) == "number" and b.kw > 0, b.name .. " : energy_usage positive (obligatoire)")
    check(type(b.speed) == "number" and b.speed > 0, b.name .. " : vitesse de fabrication positive")
  end
  if b.proto == "mining-drill" then check(b.resource_categories and #b.resource_categories >= 1 and b.mining_speed > 0, b.name .. " : catégories et vitesse de minage") end
  if b.proto == "electric-pole" then
    check(b.wire_distance <= X.LIMITS.wire_distance_max and b.supply_distance <= X.LIMITS.supply_distance_max, b.name .. " : portée de fil et d'alimentation ≤ 64")
  end
  if b.proto == "beacon" then check(b.supply_distance <= X.LIMITS.supply_distance_max, b.name .. " : portée de balise ≤ 64") end
  if b.proto == "locomotive" then check(b.energy.type == "burner", b.name .. " : locomotive à brûleur (seule source permise avec void)") end
  if b.proto == "linked-container" then check(b.inventory and b.inventory > 0, b.name .. " : inventory_size > 0") end
  if b.proto == "reactor" then
    check(b.energy.type ~= "heat", b.name .. " : un réacteur n'a pas de source de chaleur en entrée")
    check(b.neighbour_bonus ~= nil, b.name .. " : neighbour_bonus déclaré (1 par défaut en 1.1.91 : +100 % par voisin)")
    check(b.max_temperature ~= nil and b.max_transfer_kw ~= nil and b.max_transfer_kw >= b.heat_kw, b.name .. " : max_temperature et max_transfer ≥ puissance (HeatBuffer)")
    if b.injectors then
      local inj = idx.building["fo-plasma-injector"]
      check(b.injectors * inj.kw >= b.heat_kw and b.injectors <= X.LIMITS.heat_connections_max, b.name .. " : " .. b.injectors .. " injecteurs absorbent sa chaleur (32 connexions au plus)")
    end
  end
  if b.proto == "heat-pipe" then check(b.max_temperature and b.max_transfer_kw, b.name .. " : max_temperature et max_transfer") end
  if b.energy and b.energy.type == "heat" then
    check(b.energy.max_temperature and b.energy.min_temperature < b.energy.max_temperature, b.name .. " : source de chaleur min < max")
    for _, src in ipairs(b.heat_from or {}) do
      check(heat_max[src] ~= nil, b.name .. " : source de chaleur déclarée " .. src)
      if heat_max[src] then
        check(b.energy.min_temperature < heat_max[src], string.format("%s : %g °C requis < %g °C de %s", b.name, b.energy.min_temperature, heat_max[src], src))
      end
    end
    check(b.heat_from and #b.heat_from >= 1, b.name .. " : au moins une source de chaleur nommée")
  end
  if b.proto == "boiler" then check(b.mode == "output-to-separate-pipe" and b.output_fluid and b.input_fluid, b.name .. " : chaudière à sortie séparée, fluides déclarés") end
  if b.proto == "generator" then
    check(b.output_kw and b.fluid_per_s and (b.burns_fluid or b.maximum_temperature), b.name .. " : générateur complet (burns_fluid ou maximum_temperature)")
    if b.maximum_temperature then
      local fl = idx.item[b.fluid]
      local kw = (math.min(fl.max_temperature, b.maximum_temperature) - fl.default_temperature) * b.fluid_per_s * fl.heat_capacity_kj
      check(math.abs(kw / b.output_kw - 1) <= 0.01, string.format("%s : (min(T, %g) - %g) × %g × %g = %.0f kW ≈ %g kW", b.name, b.maximum_temperature, fl.default_temperature, b.fluid_per_s, fl.heat_capacity_kj, kw, b.output_kw))
    end
  end
  if b.proto == "rocket-silo" then
    check(b.rocket_parts_required >= 1 and b.rocket_parts_required <= 2 ^ 32 - 1, b.name .. " : rocket_parts_required en uint32")
    check(idx.recipe[b.fixed_recipe] ~= nil, b.name .. " : recette fixe déclarée")
    local seg = idx.item[idx.recipe[b.fixed_recipe].results[1][1]]
    check(seg and seg.counter_only, b.name .. " : le produit de sa recette fixe est un simple compteur (counter_only)")
  end
  if b.fixed_recipe then
    local fr = idx.recipe[b.fixed_recipe]
    local ok = false
    for _, c in ipairs(b.categories or {}) do if fr and fr.category == c then ok = true end end
    check(ok, b.name .. " : recette fixe dans ses catégories")
  end
  if b.proto == "lab" then for _, pk in ipairs(b.inputs) do check(known[pk], b.name .. " : pack accepté connu " .. pk) end end
  -- Niveaux (Q6) : famille et niveau de naissance, ou pièce sans niveau justifiée.
  check(b.levels and (b.levels.family or (b.levels.none_fr and #b.levels.none_fr > 5)), b.name .. " : niveaux déclarés (famille ou justification)")
  if b.levels and b.levels.family then
    check(b.levels.first == 2 * b.epoch - 1, b.name .. " : naît au niveau " .. (2 * b.epoch - 1) .. " de son époque")
    local n = 30 - b.levels.first + 1
    level_protos = level_protos + n
    by_family[b.levels.family] = (by_family[b.levels.family] or 0) + n
  end
end
local fam_known = {}
for _, f in ipairs(X.level_families) do fam_known[f.key] = f end
for _, f in ipairs(sorted_keys(by_family)) do check(fam_known[f] ~= nil, "famille de niveaux « " .. f .. " » déclarée") end
info(string.format("niveaux : %d prototypes d'entité de niveau (et autant d'objets), sur %d bâtiments à niveaux", level_protos, (function() local n = 0 for _, b in ipairs(X.buildings) do if b.levels.family then n = n + 1 end end return n end)()))
local plasma = idx.item["fo-plasma"]
check(plasma.default_temperature < plasma.max_temperature and plasma.heat_capacity_kj > 0, "plasma : default_temperature 15 < max_temperature 5 000, capacité thermique déclarée")
check(math.abs(plasma.heat_mj_per_unit - (plasma.max_temperature - plasma.default_temperature) * plasma.heat_capacity_kj / 1000) < 1e-9, "plasma : chaleur par unité = (5 000 - 15) × 1 kJ")
-- Barils : chaque fluide décide ; flux sombre et matière exotique brute restent locaux.
for _, it in ipairs(X.items) do if it.type == "fluid" then check(it.barrel == true or it.barrel == false, it.name .. " : baril décidé (auto_barrel)") end end
check(idx.item["fo-dark-flux"].barrel == false and idx.item["fo-raw-exotic-matter"].barrel == false, "flux sombre et matière exotique brute sans baril (locaux)")
check(idx.item["fo-plasma"].barrel and idx.item["fo-plasma"].barrel_fr, "plasma en baril permis, et pourquoi (sa chaleur est perdue)")

---------------------------------------------------------------------------------------------------
section("Garanties de placement (F1-1 : 15 époques sur une même carte, sans blocage)")
---------------------------------------------------------------------------------------------------
local all_resources = {}
for _, r in ipairs(X.resources) do all_resources[#all_resources + 1] = { name = r.name, epoch = r.epoch, placement = r.placement, new = true } end
for _, r in ipairs(X.base_resources) do all_resources[#all_resources + 1] = { name = r.name, epoch = r.epoch, placement = r.placement } end
local function guaranteed(pl)
  return pl and (pl.vanilla == "start" or pl.vanilla == "autoplace" or (pl.guaranteed and (pl.guaranteed.by_construction or (pl.guaranteed.count and pl.guaranteed.count >= 1))))
end
for _, r in ipairs(X.resources) do check(guaranteed(r.placement), r.name .. " : règle de placement garanti") end
local required_by = {}
for _, R in ipairs(all_resources) do
  fixpoint(function(r)
    if r.kind ~= "mining" and r.kind ~= "gather" then return false end
    if R.new then return r.resource == R.name end
    return r.results[1] and r.results[1][1] == R.name and r.resource == nil
  end)
  for k, e in ipairs(X.epochs) do
    if av(e.pack) > k then
      required_by[R.name] = required_by[R.name] or {}
      table.insert(required_by[R.name], e.pack)
    end
  end
end
fixpoint()
for _, R in ipairs(all_resources) do
  if required_by[R.name] then
    check(guaranteed(R.placement), R.name .. " : nécessaire à " .. table.concat(required_by[R.name], ", ") .. " → placement garanti")
  end
end
info("ressources nécessaires à un pack : " .. table.concat(sorted_keys(required_by), ", "))

---------------------------------------------------------------------------------------------------
section("Factions, difficulté, évolution (Q4, lot IA0)")
---------------------------------------------------------------------------------------------------
local F_PVP
for _, p in ipairs({ "shared/faction/config.lua", "../../../shared/faction/config.lua" }) do
  if not F_PVP then
    local f = io.open(p, "rb")
    if f then
      f:close()
      local ok, F = pcall(dofile, p)
      if ok and type(F) == "table" and F.pvp_order then F_PVP = F; info("difficulté du lot IA0 relue : " .. p) end
    end
  end
end
local keys = {}
for _, d in ipairs(X.difficulty) do keys[#keys + 1] = d.key end
check(table.concat(keys, ",") == table.concat(X.PVP_KEYS, ","), "clés de X.difficulty = X.PVP_KEYS, dans l'ordre")
if F_PVP then
  check(table.concat(F_PVP.pvp_order, ",") == table.concat(X.PVP_KEYS, ","), "clés de X0 = F.pvp_order du lot IA0 (une seule source)")
else
  info("AVIS : shared/faction/config.lua (F.pvp_order) introuvable ; clés comparées au miroir X.PVP_KEYS seulement")
end
for i, d in ipairs(X.difficulty) do
  check(d.fr and d.en, d.key .. " : nommé FR et EN")
  for _, owned in ipairs({ "grace_minutes", "grace_until_epoch", "attack_every_minutes", "size", "share" }) do
    check(d[owned] == nil, d.key .. " : « " .. owned .. " » appartient au lot IA0 (F.pvp), pas à X0")
  end
  check(d.evolution_offset >= -0.05 and d.evolution_offset <= 0.06, d.key .. " : décalage d'évolution de -0,05 à +0,06")
  check(type(d.epoch_offset) == "number" and d.credit > 0, d.key .. " : écart d'époque et crédit déclarés")
  if i > 1 then
    local p = X.difficulty[i - 1]
    check(d.credit > p.credit and d.epoch_offset >= p.epoch_offset and d.evolution_offset >= p.evolution_offset, d.key .. " : crédit, écart et évolution croissants")
  end
end
check(X.difficulty_of("hard").gate_build_hours and X.difficulty_of("merciless").gate_build_hours and not X.difficulty_of("normal").gate_build_hours,
  "course à la Porte en Difficile et Impitoyable seulement")
-- Calendrier des factions : seuils indexés sur le calendrier et le débit mesuré (BALANCE_SHEET §10).
check(math.abs(X.faction_threshold(2) - 4500) < 1 and math.abs(X.faction_threshold(10) - 202500) < 1 and math.abs(X.faction_threshold(15) - 472500) < 1,
  "seuils des factions : 4 500 MU (époque 2), 202 500 (10), 472 500 (15)")
do
  local d = X.difficulty_of("normal")
  local blocked, steps = 0, 0
  local reach = {}
  for step = 0, math.floor(1.25 * X.reach_hour(15) * 60) + 60 do
    local h = step / 60
    local pe = X.nominal_epoch_at(h)
    local mu_del = X.FACTION_REF_MU_S * 3600 * h
    local fe = X.faction_epoch(mu_del, pe, d)
    local free = X.faction_epoch(mu_del, 15, d)
    steps = steps + 1
    if free > fe then blocked = blocked + 1 end
    if not reach[fe] then reach[fe] = h end
  end
  for k = 2, 15 do
    local ok = reach[k] and math.abs(reach[k] - X.reach_hour(k)) <= 0.25 * X.reach_hour(k)
    check(ok, string.format("Normal : la faction atteint l'époque %d à %s h, joueur nominal à %.1f h (±25 %%)", k, reach[k] and string.format("%.1f", reach[k]) or "jamais", X.reach_hour(k)))
  end
  check(blocked / steps <= 0.20, string.format("Normal : le plafond bloque la faction %.0f %% du temps (20 %% au plus)", 100 * blocked / steps))
end
for _, d in ipairs(X.difficulty) do
  local prev = 0
  for _, mu_v in ipairs({ 0, 1000, 10000, 100000, 1000000, 10000000 }) do
    for _, pe in ipairs({ 1, 5, 10, 15 }) do
      local fe = X.faction_epoch(mu_v, pe, d)
      check(fe >= 1 and fe <= 15 and fe <= math.max(1, pe + d.epoch_offset), d.key .. " : époque de faction entre 1 et 15, plafonnée")
    end
    local fe15 = X.faction_epoch(mu_v, 15, d)
    check(fe15 >= prev, d.key .. " : l'époque de faction ne recule pas quand le minage réel croît")
    prev = fe15
  end
end
-- Course à la Porte sur le calendrier nominal.
do
  local start_h = X.reach_hour(15)
  for _, d in ipairs(X.difficulty) do
    if d.gate_build_hours then
      check(d.gate_build_hours > X.epoch_hours(15) or d.beats_nominal_fr, d.key .. " : chantier plus long que l'époque 15 du joueur, ou avance voulue et écrite")
      local done = start_h + d.gate_build_hours
      if d.beats_nominal_fr then
        info(string.format("%s : Porte de faction à %.1f h, joueur nominal à %.1f h (%s)", d.key, done, X.player_gate_hour(), d.beats_nominal_fr))
      else
        check(done > X.player_gate_hour(), string.format("%s : la faction ouvre sa Porte à %.1f h, après le joueur nominal (%.1f h)", d.key, done, X.player_gate_hour()))
      end
    end
  end
  check(X.gate_race.reset_on_destroy and X.gate_race.refund == X.branch_params.gate.faction_rebate, "chantier détruit : remis à zéro, 30 % rendus")
end
for k = 1, 15 do
  local w = X.evolution_window[k]
  check(w[1] >= 0 and w[2] <= 1 and w[1] < w[2], "évolution époque " .. k .. " : fenêtre valide")
  if k > 1 then
    local pw = X.evolution_window[k - 1]
    check(w[1] >= pw[1] and w[2] >= pw[2], "évolution époque " .. k .. " : fenêtre croissante")
    check(X.td_max_tier[k] >= X.td_max_tier[k - 1], "défense de tours époque " .. k .. " : palier maximal croissant")
  end
  check(X.clamp_evolution(0, k, 0) == w[1] and X.clamp_evolution(1, k, 0) == w[2], "évolution époque " .. k .. " : bornée par la fenêtre")
end
check(X.td_max_tier[15] == 8, "primordiaux (palier 8) à l'époque 15")
for t = 2, #X.loot.unit_probability do check(X.loot.unit_probability[t] > X.loot.unit_probability[t - 1], "butin croissant avec le palier") end
local tsum = 0
for i = 1, 24 do
  tsum = tsum + X.tide[i]
  check(X.tide[i] >= 0.5 - 1e-12 and X.tide[i] <= 1.5 + 1e-12, "marée phase " .. (i - 1) .. " dans [0,5 ; 1,5]")
end
check(X.tide[1] == 0.5 and X.tide[13] == 1.5 and math.abs(tsum / 24 - 1) < 1e-12, "marée : 0,5 à midi, 1,5 à minuit, rendement moyen 1")
check(X.power(0, 1, 0, 0) == 500 and X.power(100, 15, 3, 75) == 100 + 7500 + 6000 + 3750, "score de puissance")
local tf, cf = X.zone_upgrade_factors(10)
check(math.abs(tf - 1.9) < 1e-12 and cf == 10, "chantier de zone : 10 bâtiments, durée × 1,9, coût × 10")

---------------------------------------------------------------------------------------------------
section("La Porte : bilan de fin de partie")
---------------------------------------------------------------------------------------------------
local function amount_in(r, n) for _, i in ipairs(r.ingredients) do if i[1] == n then return i[2] end end return 0 end
local gate, key, opening = idx.recipe["fo-erebus-gate"], idx.recipe["fo-phase-key"], idx.recipe["fo-open-gate"]
local gate_b = idx.building["fo-erebus-gate"]
local nseg = amount_in(opening, "fo-ring-segment")
check(nseg == X.branch_params.gate.segments and gate_b.rocket_parts_required == nseg, "100 segments = 100 pièces du silo réhabillé")
check(gate_b.kw == X.branch_params.gate.crafting_mw * 1000 and gate_b.charge_kw == X.branch_params.gate.power_mw * 1000,
  "Porte : 50 MW pour les segments (energy_usage), 5 GW pour la charge (interface cachée)")
local exotic = nseg * amount_in(segment, "fo-stabilized-exotic-matter") + amount_in(gate, "fo-stabilized-exotic-matter") + amount_in(key, "fo-stabilized-exotic-matter")
check(exotic == 230, "230 matières exotiques stabilisées pour ouvrir la Porte (" .. exotic .. ")")
local stab = idx.recipe["fo-exotic-stabilization"]
local raw = exotic * amount_in(stab, "fo-raw-exotic-matter")
check(raw == 11500, "11 500 matières exotiques brutes")
local gate_report = {}
for _, br in ipairs(X.branches) do
  local need = nseg * amount_in(segment, br.gate_item) + amount_in(idx.recipe["fo-rift-anchor"], br.gate_item)
  gate_report[#gate_report + 1] = { br.key, need, br.gate_item }
  info(string.format("branche %s : %d × %s consommés (segments et ancre)", br.key, need, br.gate_item))
end
local superalloy = nseg * amount_in(segment, "fo-superalloy") + amount_in(gate, "fo-superalloy") + amount_in(idx.recipe["fo-rift-anchor"], "fo-superalloy")
info(string.format("superalliage ρ32 : %d (soit %d MU) ; matière exotique brute : %d", superalloy, superalloy * 32, raw))
local seg_tj = nseg * segment.time / gate_b.speed * gate_b.kw / 1e9
local charge_tj = X.branch_params.gate.power_mw * X.branch_params.gate.charge_minutes * 60 / 1e6
info(string.format("énergie de la Porte : segments %.2f TJ (50 MW × %d s) + charge %.0f TJ (5 GW × 30 min)", seg_tj, nseg * segment.time, charge_tj))
check(X.branch_params.gate.power_mw == 5000 and X.branch_params.gate.charge_minutes == 30, "charge de 30 min sous 5 GW")
check(X.fallback_recipes[1] and idx.building["fo-rift-anchor"].fallback and idx.building["fo-rift-anchor"].fallback.fixed_recipe == X.fallback_recipes[1].name,
  "ancre de faille : repli à recette fixe conçu")

---------------------------------------------------------------------------------------------------
-- Volume, blocs générés du scénario
---------------------------------------------------------------------------------------------------
local n_items, n_fluids, n_counters = 0, 0, 0
for _, it in ipairs(X.items) do
  if it.type == "fluid" then n_fluids = n_fluids + 1 elseif it.counter_only then n_counters = n_counters + 1 else n_items = n_items + 1 end
end
local kinds = {}
for _, r in ipairs(X.recipes) do kinds[r.kind] = (kinds[r.kind] or 0) + 1 end
local n_pseudo = 0
for _, k in ipairs(sorted_keys(kinds)) do if PSEUDO[k] then n_pseudo = n_pseudo + kinds[k] end end
local VOL = {
  items = n_items, counters = n_counters, fluids = n_fluids, buildings = #X.buildings, resources = #X.resources, tiles = #X.tiles,
  real = n_real, pseudo = n_pseudo, kinds = kinds, techs = #X.technologies, infinite = #X.infinite_techs,
  barrels = #barrel_items, barrel_recipes = #barrel_recipes, variants = variants, level_protos = level_protos,
}
VOL.prototypes = VOL.items + VOL.fluids + 2 * VOL.buildings + VOL.resources + VOL.tiles + VOL.real + VOL.techs + VOL.infinite + 14
  + VOL.barrels + VOL.barrel_recipes + VOL.variants + 2 * VOL.level_protos
local kind_list = {}
for _, k in ipairs(sorted_keys(kinds)) do kind_list[#kind_list + 1] = k .. " " .. kinds[k] end
info(string.format("volume : %d objets (+%d compteurs), %d fluides, %d bâtiments, %d ressources, %d tuiles, %d technologies ; recettes : %s",
  n_items, n_counters, n_fluids, #X.buildings, #X.resources, #X.tiles, #X.technologies, table.concat(kind_list, ", ")))
info(string.format("prototypes nouveaux estimés : %d (dont %d d'entités et d'objets de niveau)", VOL.prototypes, 2 * level_protos))

---------------------------------------------------------------------------------------------------
-- Générateur des blocs du scénario (docs/SCENARIO_EPOQUES.md, marqueurs <!-- GEN:nom -->)
---------------------------------------------------------------------------------------------------
local VANILLA_FR = {
  ["accumulator"] = "Accumulateur", ["advanced-circuit"] = "Circuit avancé", ["artillery-shell"] = "Obus d'artillerie",
  ["assembling-machine-1"] = "Machine d'assemblage 1", ["assembling-machine-2"] = "Machine d'assemblage 2", ["assembling-machine-3"] = "Machine d'assemblage 3",
  ["automation-science-pack"] = "Pack d'automatisation", ["battery"] = "Batterie", ["beacon"] = "Balise", ["boiler"] = "Chaudière",
  ["burner-mining-drill"] = "Foreuse à combustion", ["centrifuge"] = "Centrifugeuse", ["character"] = "main", ["chemical-plant"] = "Usine chimique",
  ["chemical-science-pack"] = "Pack chimique", ["coal"] = "Charbon", ["concrete"] = "Béton", ["copper-cable"] = "Câble de cuivre",
  ["copper-ore"] = "Minerai de cuivre", ["copper-plate"] = "Plaque de cuivre", ["electric-engine-unit"] = "Moteur électrique",
  ["electric-furnace"] = "Four électrique", ["electric-mining-drill"] = "Foreuse électrique", ["electronic-circuit"] = "Circuit électronique",
  ["engine-unit"] = "Moteur", ["fo-armored-wall"] = "Mur blindé", ["fo-methane"] = "Méthane", ["fo-methane-barrel"] = "Baril de méthane",
  ["fo-resonance-crystal"] = "Cristal de résonance", ["fo-tungsten-ore"] = "Minerai de tungstène", ["fo-tungsten-plate"] = "Plaque de tungstène",
  ["grenade"] = "Grenade", ["heat-exchanger"] = "Échangeur de chaleur", ["heat-pipe"] = "Caloduc", ["heavy-oil"] = "Huile lourde",
  ["iron-gear-wheel"] = "Engrenage", ["iron-ore"] = "Minerai de fer", ["iron-plate"] = "Plaque de fer", ["light-oil"] = "Huile légère",
  ["locomotive"] = "Locomotive", ["logistic-science-pack"] = "Pack logistique", ["low-density-structure"] = "Structure basse densité",
  ["lubricant"] = "Lubrifiant", ["military-science-pack"] = "Pack militaire", ["nuclear-reactor"] = "Réacteur nucléaire",
  ["offshore-pump"] = "Pompe côtière", ["oil-refinery"] = "Raffinerie", ["petroleum-gas"] = "Gaz de pétrole", ["pipe"] = "Tuyau",
  ["plastic-bar"] = "Plastique", ["processing-unit"] = "Processeur", ["production-science-pack"] = "Pack de production",
  ["pumpjack"] = "Chevalet de pompage", ["radar"] = "Radar", ["rocket-control-unit"] = "Unité de contrôle de fusée", ["rocket-silo"] = "Silo à fusée",
  ["solar-panel"] = "Panneau solaire", ["space-science-pack"] = "Pack espace", ["stack-inserter"] = "Bras empileur", ["steam"] = "Vapeur",
  ["steam-engine"] = "Machine à vapeur", ["steel-furnace"] = "Four en acier", ["steel-plate"] = "Plaque d'acier", ["stone"] = "Pierre",
  ["stone-brick"] = "Brique de pierre", ["stone-furnace"] = "Four en pierre", ["sulfur"] = "Soufre", ["sulfuric-acid"] = "Acide sulfurique",
  ["uranium-235"] = "Uranium 235", ["uranium-238"] = "Uranium 238", ["uranium-fuel-cell"] = "Cellule d'uranium", ["uranium-ore"] = "Minerai d'uranium",
  ["uranium-rounds-magazine"] = "Chargeur à l'uranium", ["used-up-uranium-fuel-cell"] = "Cellule d'uranium usée",
  ["utility-science-pack"] = "Pack utilitaire", ["water"] = "Eau", ["wood"] = "Bois", ["gun-turret"] = "Tourelle", ["stone-wall"] = "Mur de pierre",
  ["laser-turret"] = "Tourelle laser", ["fo-command-center"] = "Centre de commandement", ["crude-oil"] = "Pétrole brut", ["raw-fish"] = "Poisson",
  ["heat-pipe-vanilla"] = "Caloduc",
}
local function fr_name(n)
  local it = idx.item[n] or idx.building[n]
  if it then return it.fr end
  return VANILLA_FR[n] or n
end
local function fr_int(n)
  local s = tostring(math.floor(n + 0.5))
  local neg = s:sub(1, 1) == "-"
  if neg then s = s:sub(2) end
  local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
  return (neg and "-" or "") .. out
end
local function fr_num(x, dec)
  if x < 0 then return "-" .. fr_num(-x, dec) end
  if math.abs(x - math.floor(x + 0.5)) < 1e-9 and (not dec or dec == 0) then return fr_int(x) end
  local s = string.format("%." .. (dec or 2) .. "f", x)
  s = s:gsub("0+$", ""):gsub("%.$", "")
  local ip, fp = s:match("^(-?%d+)%.?(%d*)$")
  return fr_int(tonumber(ip)) .. (fp ~= "" and ("," .. fp) or "")
end
local ROMAN = { "I", "II", "III" }
local function machine_label(r)
  if r.category == "crafting" and not r.machines then return "main ou assembleur" end
  if r.category == "advanced-crafting" and not r.machines then return "assembleur" end
  local names = {}
  for _, m in ipairs(machines_of(r)) do names[#names + 1] = fr_name(m) end
  return table.concat(names, " ou ")
end
local KIND_FR = { mining = "minage", burn = "combustion", launch = "lancement", gather = "cueillette", loot = "butin", heat = "chauffe", sink = "torchère" }
local function ing_list(list)
  if #list == 0 then return "—" end
  local out = {}
  for _, i in ipairs(list) do
    local s = fr_num(i[2], 3) .. " " .. fr_name(i[1])
    if i.p then s = fr_name(i[1]) .. " (p " .. fr_num(i.p * 100, 1) .. " %)" end
    if i.catalyst then s = s .. " [cat. " .. i.catalyst .. "]" end
    if i.back then s = s .. " (rendu)" end
    out[#out + 1] = s
  end
  return table.concat(out, " + ")
end
local GEN = {}
local function lines() local t = {} return t, function(s) t[#t + 1] = s end end

do -- Fil narratif
  local t, add = lines()
  add("| Ép. | Thème | Acte | Ce que l'on découvre (Codex de l'époque) | Pression |")
  add("|---|---|---|---|---|")
  for _, e in ipairs(X.epochs) do
    add(string.format("| %d | %s | %d | %s | %s |", e.n, e.fr, e.act, e.reveal_fr, e.pressure_fr))
  end
  GEN.narrative = t
end
do -- Branches
  local t, add = lines()
  local cols = {}
  for _, br in ipairs(X.branches) do cols[#cols + 1] = br.key .. ". " .. br.fr end
  add("| | " .. table.concat(cols, " | ") .. " |")
  add("|---|---|---|---|---|")
  local function row(label, f) local c = {} for _, br in ipairs(X.branches) do c[#c + 1] = f(br) end add("| " .. label .. " | " .. table.concat(c, " | ") .. " |") end
  local FACTION_FR = { azure = "Ligue Azur", scarlet = "Ordre Écarlate", amber = "Dynastie Ambre", emerald = "Consortium Émeraude" }
  row("Doctrine de", function(br) return FACTION_FR[br.faction] end)
  row("Niveaux I, II, III (époque)", function(br) return string.format("%d, %d, %d (15 sans Serment)", br.epochs[1], br.epochs[2], br.epochs[3]) end)
  row("Mécanique propre", function(br) return br.mechanic_fr end)
  row("Ce qu'elle rapporte", function(br) return br.yields_fr end)
  row("Coût et risque (chiffrés)", function(br) return br.cost_risk_fr end)
  row("Donnée de recherche", function(br) return fr_name(br.data) end)
  row("Produit exigé par la Porte", function(br) return fr_name(br.gate_item) end)
  row("Merveille", function(br) return fr_name(br.wonder) end)
  GEN.branches = t
end
do -- Textes joueur
  local t, add = lines()
  add("| Moment | Français | English |")
  add("|---|---|---|")
  add("| Introduction | " .. X.story.intro_fr .. " | " .. X.story.intro_en .. " |")
  for k = 1, 14 do add(string.format("| Codex %s (%s) | %s | %s |", ({ "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV" })[k], X.epochs[k].fr, X.epochs[k].codex_fr, X.epochs[k].codex_en)) end
  add("| Victoire | " .. X.story.victory_fr .. " | " .. X.story.victory_en .. " |")
  add("| Défaite (QX3) | " .. X.story.defeat_fr .. " | " .. X.story.defeat_en .. " |")
  add("")
  add("Canal : " .. X.story.channel_fr .. ".")
  GEN.story = t
end
do -- Difficulté
  local t, add = lines()
  add("| Clé (F.pvp_order) | Difficulté | Évolution | Écart d'époque (plafond) | Crédit d'archive | Chantier de Porte |")
  add("|---|---|---|---|---|---|")
  for _, d in ipairs(X.difficulty) do
    add(string.format("| `%s` | %s | %s | %s | ×%s | %s |", d.key, d.fr, (d.evolution_offset > 0 and "+" or "") .. fr_num(d.evolution_offset, 2),
      (d.epoch_offset > 0 and "+" or "") .. d.epoch_offset, fr_num(d.credit, 2), d.gate_build_hours and (fr_num(d.gate_build_hours) .. " h") or "non"))
  end
  GEN.difficulty = t
end
do -- Calendrier
  local t, add = lines()
  add("| Ép. | Durée | Atteinte à | Palier | Ouvriers | Niveau max | Débit fin (MU/s) | Débit moyen | Budget (MU) | Passage du centre (MU) | Monnaie (valeur, pile) | Jalon de production | Recherche (% du budget) |")
  add("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
  for k, e in ipairs(X.epochs) do
    local c = X.currency_of(k)
    local pi, pc = X.milestone_production(k)
    add(string.format("| %d %s | %s h | %s h | T%d | %d | %d | %s | %s | %s | %s | %s | %s %s | %s %% |", k, e.fr, fr_num(X.epoch_hours(k), 1), fr_num(X.reach_hour(k), 1),
      X.logistics_tier(k), X.builders(k), X.max_building_level(k), fr_int(X.rate(k)), fr_int(X.rate_avg(k)), fr_int(X.budget(k)),
      k < 15 and fr_int(X.cc_upgrade_mu(k)) or "—", c and string.format("%s (%s MU, %d)", fr_name(c.item), fr_num(c.value), c.stack) or "panier de base",
      fr_int(pc), fr_name(pi), fr_num(100 * research_share[k], 1)))
  end
  GEN.calendar = t
end
do -- Monnaies et diff V2 (indépendant des clés de V2 : on ne change que l'objet, la valeur et la pile)
  local t, add = lines()
  add("```lua")
  add("-- À insérer dans shared/levels/config.lua juste APRÈS la table L.stack_size (L.epoch_materials, L.item_value")
  add("-- et L.stack_size existent alors). Les époques absentes gardent leur monnaie V2 (identique à X0, contrôlé par le banc).")
  add("for _, m in ipairs({")
  for _, c in ipairs(X.currencies) do
    if c.v2_item ~= c.item then add(string.format("  { %d, %q, %s, %d }, -- était %s", c.epoch, c.item, tostring(c.value), c.stack, c.v2_item)) end
  end
  add("}) do")
  add("  local e = L.epoch_materials[m[1]]")
  add("  e.item, e.value, e.want_item, e.provisional = m[2], m[3], nil, nil")
  add("  L.item_value[m[2]], L.stack_size[m[2]] = m[3], m[4]")
  add("end")
  add("-- Codex (lot X0) : le passage du centre au niveau n exige 1 Codex n-1 (valeur en MU calculée par le banc X0).")
  local cv = {}
  for k = 1, 14 do cv[#cv + 1] = string.format("%s", fr_int(mu_of("fo-codex-" .. k)):gsub(" ", "")) end
  add("L.codex_value = { " .. table.concat(cv, ", ") .. " }")
  add("for k = 1, 14 do")
  add("  L.item_value[\"fo-codex-\" .. k] = L.codex_value[k]")
  add("  L.stack_size[\"fo-codex-\" .. k] = 10")
  add("end")
  add("-- Dans raw_cost(family, n), juste après la boucle du panier de base :")
  add("--   if family.key == \"command\" then add(\"fo-codex-\" .. (n - 1), 1) end")
  add("```")
  GEN.v2diff = t
end
do -- Ressources
  local t, add = lines()
  add("| Ressource | Époque | Produit | Où | Garantie de placement |")
  add("|---|---|---|---|---|")
  for _, r in ipairs(X.resources) do
    local g = r.placement.guaranteed
    add(string.format("| %s | %d | %s | %s | %s |", r.fr .. (r.branch and string.format(" [%s-%s]", r.branch, ROMAN[r.level]) or ""), r.epoch,
      fr_name(r.products[1]), r.where_fr, g.what_fr .. (g.distance and string.format(" (%d, %s à %s tuiles)", g.count, fr_int(g.distance[1]), fr_int(g.distance[2])) or "")))
  end
  for _, r in ipairs(X.base_resources) do
    if r.placement.guaranteed then
      add(string.format("| %s (existant) | %d | %s | %s | %s |", fr_name(r.name), r.epoch, fr_name(r.name), r.placement.autoplace or "—", r.placement.guaranteed.what_fr))
    end
  end
  GEN.resources = t
end
do -- Objets par époque
  local t, add = lines()
  add("| Ép. | Objets | Fluides (baril) |")
  add("|---|---|---|")
  for k = 1, 15 do
    local its, fls = {}, {}
    for _, it in ipairs(X.items) do
      if it.epoch == k then
        if it.type == "fluid" then fls[#fls + 1] = it.fr .. (it.barrel and "" or " (sans baril)")
        else its[#its + 1] = it.fr .. (it.counter_only and " (compteur)" or "") end
      end
    end
    add(string.format("| %d | %s | %s |", k, #its > 0 and table.concat(its, ", ") or "—", #fls > 0 and table.concat(fls, ", ") or "—"))
  end
  GEN.items = t
end
do -- Bâtiments
  local t, add = lines()
  add("| Bâtiment | Ép. | Prototype 1.1 | Taille | Énergie | Rôle | Niveaux |")
  add("|---|---|---|---|---|---|---|")
  for _, b in ipairs(X.buildings) do
    local en = "—"
    if b.energy then
      if b.energy.type == "burner" then en = "brûleur (" .. b.energy.fuel_category .. ")" .. (b.kw and (", " .. fr_num(b.kw / 1000, 3) .. " MW") or "")
      elseif b.energy.type == "heat" then en = string.format("chaleur %s à %s °C, %s MW", fr_int(b.energy.min_temperature), fr_int(b.energy.max_temperature), fr_num(b.kw / 1000, 3))
      elseif b.energy.type == "fluid" then en = "vapeur, " .. fr_num(b.kw / 1000, 3) .. " MW"
      elseif b.energy.type == "void" then en = "aucune"
      else en = fr_num((b.kw or 0) / 1000, 3) .. " MW" end
    elseif b.kw then en = fr_num(b.kw / 1000, 3) .. " MW" end
    if b.heat_kw then en = en .. " → " .. fr_int(b.heat_kw / 1000) .. " MW de chaleur (voisinage 0, " .. fr_int(b.max_temperature) .. " °C)" end
    if b.output_kw then en = "produit " .. fr_num(b.output_kw / 1000, 3) .. " MW" end
    local role = {}
    if b.speed and b.categories then role[#role + 1] = "vitesse " .. fr_num(b.speed, 3) end
    if b.mining_speed then role[#role + 1] = "minage " .. fr_num(b.mining_speed, 3) .. " (" .. table.concat(b.resource_categories, ", ") .. ")" end
    if b.fixed_recipe then role[#role + 1] = "recette fixe" end
    if b.confinement then role[#role + 1] = "confinement" end
    if b.contagion then role[#role + 1] = "contagion" end
    if b.wonder then role[#role + 1] = "merveille : " .. b.effect_fr end
    if b.rule_fr then role[#role + 1] = b.rule_fr end
    if b.hp then role[#role + 1] = fr_int(b.hp) .. " PV" end
    local lv = b.levels.family and string.format("%s, niveaux %d à 30", b.levels.family, b.levels.first) or ("sans niveau : " .. b.levels.none_fr)
    add(string.format("| %s%s | %d | %s | %d×%d | %s | %s | %s |", b.fr, b.branch and string.format(" [%s-%s]", b.branch, ROMAN[b.level]) or "", b.epoch, b.proto,
      b.size[1], b.size[2], en, #role > 0 and table.concat(role, " ; ") or "—", lv))
  end
  GEN.buildings = t
end
do -- Recettes par époque
  local t, add = lines()
  for k = 1, 15 do
    add(string.format("#### Époque %d · %s", k, X.epochs[k].fr))
    add("| Recette | Entrées | Sorties | Machine | Durée | Technologie |")
    add("|---|---|---|---|---|---|")
    for _, r in ipairs(X.recipes) do
      if r.epoch == k then
        local name = r.fr
        if not name then local main = r.results[1] and (idx.item[r.results[1][1]] or idx.building[r.results[1][1]]); name = main and main.fr or r.name end
        local tags = {}
        if KIND_FR[r.kind] then tags[#tags + 1] = "*" .. KIND_FR[r.kind] .. "*" end
        if r.dense then tags[#tags + 1] = "*(dense)*" end
        if r.prod then tags[#tags + 1] = "(prod.)" end
        if r.branch then tags[#tags + 1] = string.format("[%s-%s]", r.branch, ROMAN[r.level]) end
        local tech = "—"
        if unlocked_by[r.name] and unlocked_by[r.name][1] then tech = unlocked_by[r.name][1].fr
        elseif start[r.name] then tech = "départ"
        elseif r.unlock == "wonder" then tech = "merveille : " .. fr_name(r.wonder) end
        add(string.format("| %s%s | %s | %s | %s | %s s | %s |", name, #tags > 0 and (" " .. table.concat(tags, " ")) or "", ing_list(r.ingredients),
          ing_list(r.results), machine_label(r), fr_num(r.time, 3), tech))
      end
    end
    add("")
  end
  t[#t] = nil
  GEN.recipes = t
end
do -- Technologies
  local t, add = lines()
  add("| Technologie | Ép. | Rôle | Prérequis | Packs | Unités | Recettes débloquées |")
  add("|---|---|---|---|---|---|---|")
  local ROLE_FR = { pack = "pack", normal = "—", codex = "Codex", branch1 = "branche I", branch2 = "branche II", branch3 = "maîtrise (Serment)", gate = "Porte" }
  for _, tch in ipairs(X.technologies) do
    local packs = {}
    for _, p in ipairs(tch.packs) do packs[#packs + 1] = fr_name(p) end
    local pre = {}
    for _, p in ipairs(tch.prereq) do pre[#pre + 1] = tech_by[p].fr end
    add(string.format("| %s | %d%s | %s | %s | %s | %s | %d |", tch.fr, tch.epoch, tch.mastery and " (15 sans Serment)" or "",
      (tch.branch and (tch.branch .. " ") or "") .. ROLE_FR[tch.role], #pre > 0 and table.concat(pre, ", ") or ("verrou fo-epoch-" .. tch.epoch),
      table.concat(packs, ", "), fr_int(tch.units), #tch.unlocks))
  end
  GEN.techs = t
end
do -- Énergie par palier
  local t, add = lines()
  add("| Palier | Tapis | Chaîne (sur les recettes) | MW électriques par tapis | MW de chaleur par tapis | Source de l'époque |")
  add("|---|---|---|---|---|---|")
  for tier = 1, 3 do
    local row = BMROWS[tier]
    add(string.format("| T%d (ép. %d) | %d/s ρ%d = %s MU/s | formes du lot C (modèle BALANCE_SHEET §3) | %s (modèle) | — | %s |", tier, X.compaction.tiers[tier].epoch,
      row.belt_items, row.density, fr_int(row.phi), fr_num(row.belt_mw, 1), ({ "vapeur : 1,8 MW par chaudière", "géothermie : 4,2 MW par fumerolle", "turbine à gaz 10 MW ; fission 40 MW" })[tier]))
  end
  local src = { [4] = { "fo-molten-salt-reactor", "sels fondus" }, [5] = { "fo-fusion-reactor", "fusion" } }
  for tier = 4, 5 do
    local c = chain_report[tier]
    local row = BMROWS[tier]
    local reactor = idx.building[src[tier][1]]
    local n = (c.mw + c.heat_mw) / (reactor.heat_kw / 1000)
    add(string.format("| T%d (ép. %d) | %d/s ρ%d = %s MU/s | %s | %s | %s | %s : %s réacteur(s) de %s MW par tapis |", tier, X.compaction.tiers[tier].epoch,
      row.belt_items, row.density, fr_int(row.phi), table.concat(c.machines, " + "), fr_int(c.mw), fr_int(c.heat_mw), src[tier][2], fr_num(n, 1), fr_int(reactor.heat_kw / 1000)))
  end
  GEN.energy = t
end
do -- Niveaux
  local t, add = lines()
  add("| Famille | Statut | Bâtiments à niveaux | Prototypes de niveau |")
  add("|---|---|---|---|")
  for _, f in ipairs(X.level_families) do
    local names = {}
    for _, b in ipairs(X.buildings) do if b.levels.family == f.key then names[#names + 1] = b.fr .. " (" .. b.levels.first .. ")" end end
    if #names > 0 then add(string.format("| %s | %s | %s | %d |", f.fr, f.v2 and "V2" or "proposée (E3-5)", table.concat(names, ", "), by_family[f.key] or 0)) end
  end
  add(string.format("| **Total** | | | **%d** entités de niveau + **%d** objets |", level_protos, level_protos))
  GEN.levels = t
end
do -- Volume
  local t, add = lines()
  add("| Catégorie | Nombre | Détail |")
  add("|---|---|---|")
  add(string.format("| Objets nouveaux | **%d** | plus %d compteurs de silo (segment d'anneau, pièce de lanceur léger) |", VOL.items, VOL.counters))
  add(string.format("| Fluides nouveaux | **%d** | dont %d avec baril |", VOL.fluids, VOL.barrels))
  add(string.format("| Bâtiments nouveaux | **%d** | chacun aussi un objet |", VOL.buildings))
  add(string.format("| Recettes réelles | **%d** | %d de fabrication, %d de bâtiments, %d de torchère |", VOL.real, kinds.recipe or 0, kinds.building or 0, kinds.sink or 0))
  add(string.format("| Pseudo-recettes | **%d** | minage, combustion, lancement, cueillette, butin, chauffe |", VOL.pseudo))
  add(string.format("| Barils (data-updates de base) | **%d** objets, **%d** recettes | `auto_barrel` vrai par défaut |", VOL.barrels, VOL.barrel_recipes))
  add(string.format("| Variantes denses (lot C) | **%d** | plus les intermédiaires denses |", VOL.variants))
  add(string.format("| Ressources de carte | **%d** | dont 5 remontées profondes |", VOL.resources))
  add(string.format("| Tuiles et biomes | **%d** | |", VOL.tiles))
  add(string.format("| Technologies | **%d** + %d infinies + 14 verrous | plus environ 190 vanilla re-rangées (%d scindées) |", VOL.techs, VOL.infinite, #X.vanilla_tech_splits))
  add(string.format("| Niveaux (Q6) | **%d** entités + **%d** objets | un prototype par niveau (ARCHITECTURE §7 bis), du niveau 2e-1 au niveau 30 |", level_protos, level_protos))
  add(string.format("| **Prototypes au total** | **≈ %s** | somme des lignes ci-dessus |", fr_int(VOL.prototypes)))
  add(string.format("| Graphismes | — | %d bâtiments (dont 4 merveilles 9×9 et 3 pièces 10×10) ; une pièce visuelle par niveau, soit %d variantes ; environ %d icônes ; %d jeux de gisements ; %d jeux de tuiles |",
    VOL.buildings, level_protos, VOL.items + VOL.fluids + VOL.barrels, VOL.resources, VOL.tiles))
  GEN.volume = t
end
do -- Résumé du banc
  local t, add = lines()
  add(string.format("%d recettes dans le graphe (%d de base, %d pseudo-recettes de base, %d de barils, %d nouvelles), %d technologies nouvelles.",
    #all, count_pairs(base_recipes), #X.base_pseudo, #barrel_recipes, #X.recipes, #X.technologies))
  GEN.summary = t
end
do -- Porte
  local t, add = lines()
  add(string.format("- **%d matières exotiques stabilisées**, soit **%s matières brutes**.", exotic, fr_int(raw)))
  add(string.format("- **%d superalliages ρ32** (%s MU).", superalloy, fr_int(superalloy * 32)))
  local parts = {}
  for _, g in ipairs(gate_report) do parts[#parts + 1] = string.format("%s : %d × %s", g[1], g[2], fr_name(g[3])) end
  add("- Branches consommées (segments et ancre) : " .. table.concat(parts, " ; ") .. ".")
  add(string.format("- Énergie : %s TJ pour poser les segments (50 MW), puis %s TJ pour la charge (5 GW pendant 30 min).", fr_num(seg_tj, 2), fr_int(charge_tj)))
  GEN.gate = t
end

local GEN_ORDER = { "summary", "narrative", "difficulty", "story", "branches", "calendar", "v2diff", "resources", "items", "buildings", "levels", "recipes", "techs", "energy", "gate", "volume" }
local DOC = "docs/SCENARIO_EPOQUES.md"
local function read_file(p) local f = io.open(p, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end
local function block_text(name) return table.concat(GEN[name], "\n") end
if MODE == "markdown" then
  for _, n in ipairs(GEN_ORDER) do print("<!-- GEN:" .. n .. " -->"); print(block_text(n)); print("<!-- /GEN:" .. n .. " -->"); print() end
  os.exit(0)
end
local doc_md = read_file(DOC)
if MODE == "write" then
  assert(doc_md, DOC .. " introuvable")
  for _, n in ipairs(GEN_ORDER) do
    local open, close = "<!-- GEN:" .. n .. " -->", "<!-- /GEN:" .. n .. " -->"
    local s = doc_md:find(open, 1, true)
    local e = doc_md:find(close, 1, true)
    assert(s and e and e > s, "marqueurs absents : " .. n)
    doc_md = doc_md:sub(1, s + #open - 1) .. "\n" .. block_text(n) .. "\n" .. doc_md:sub(e)
  end
  local f = assert(io.open(DOC, "wb")); f:write(doc_md); f:close()
  print("blocs réécrits dans " .. DOC)
  os.exit(0)
end
section("Scénario : blocs générés égaux aux données")
check(doc_md ~= nil, DOC .. " présent")
if doc_md then
  for _, n in ipairs(GEN_ORDER) do
    local open, close = "<!-- GEN:" .. n .. " -->", "<!-- /GEN:" .. n .. " -->"
    local s = doc_md:find(open, 1, true)
    local e = doc_md:find(close, 1, true)
    local body = s and e and doc_md:sub(s + #open + 1, e - 2)
    check(body == block_text(n), "bloc « " .. n .. " » du scénario égal aux données (lua5.2 tests/epochs_test.lua --write-doc)")
  end
end

print(string.format("Résultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
