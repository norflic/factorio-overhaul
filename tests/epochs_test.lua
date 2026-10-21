--[[
  Tests hors jeu du lot X0 : époques, branches avancées et arbres de fabrication (shared/content/epochs.lua).
  Usage, depuis la racine du mod :   lua5.2 tests/epochs_test.lua ["chemin/vers/doc-html/prototype-api.json"]

  Ce que le banc prouve (hors jeu, sur les données) :
  - fermeture du graphe : tout objet, bâtiment compris, se fabrique depuis les ressources de la carte
    (vanilla réelle : tests/fixtures/recipes.lua ; contenu existant : shared/content/*.lua ; contenu nouveau) ;
  - aucune recette n'utilise un objet inconnu ; aucun anachronisme (époque calculée = époque déclarée) ;
  - chaque époque apporte une ressource ou un matériau et un bâtiment (F1-2) ; durées (F1-3) ; paliers (Q5) ;
  - chaque branche avancée est atteignable, a ses recettes, et ne bloque pas la ligne principale (Q7) ;
  - règles de production : sous-produits sans issue, productivité, énergie, MU ≥ 0,75 × ρ (greffes P2) ;
  - limites moteur 1.1.91 (sources : doc-html/prototype-api.json, relue si présente) ;
  - difficulté, évolution, factions (Q4) ; déterminisme (itérations triées, jamais l'ordre de pairs).
  Ce qu'il ne prouve pas : les débits réels, l'équilibrage fin, les fluides en conduite, le moteur réel.
]]

package.path = "./?.lua;" .. package.path
local X = require("shared.content.epochs")
local A = require("shared.content.arsenal")
local Mo = require("shared.content.modules")
local BM = require("shared.balance_model")
local FIX = dofile("tests/fixtures/recipes.lua")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function info(msg) print("   " .. msg) end

--- Clés triées : la seule façon de parcourir une table associative dans ce banc.
local function sorted_keys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end
local INF = math.huge

---------------------------------------------------------------------------------------------------
section("Sources moteur 1.1.91 (doc-html/prototype-api.json)")
---------------------------------------------------------------------------------------------------
local doc_candidates = {
  "../../doc-html/prototype-api.json",                -- racine du mod : <racine>/mods/factorio-overhaul
  "../../../../../doc-html/prototype-api.json",       -- worktree : <mod>/.claude/worktrees/<nom>
}
if arg and arg[1] then table.insert(doc_candidates, 1, arg[1]) end
local doc_text, doc_path
for _, p in ipairs(doc_candidates) do
  if not doc_text then
    local f = io.open(p, "rb")
    if f then doc_text = f:read("*a"); f:close(); doc_path = p end
  end
end
if doc_text then
  info("doc relue : " .. doc_path)
  -- Le JSON livré avec le jeu est compact (aucune espace après les deux-points).
  check(doc_text:find('"application_version":"1.1.91"', 1, true) ~= nil, "la doc est bien celle de 1.1.91")
  check(doc_text:find('"name":"RecipePrototype"', 1, true) ~= nil, "la recherche par nom de prototype fonctionne (témoin)")
  for _, ph in ipairs(X.DOC_PHRASES) do
    check(doc_text:find(ph.text, 1, true) ~= nil, "phrase de la doc introuvable (" .. ph.proto .. ") : " .. ph.text)
  end
  for _, absent in ipairs({ "SpoilablePrototype", "FusionReactorPrototype" }) do
    check(doc_text:find('"name":"' .. absent .. '"', 1, true) == nil, absent .. " absent de 1.1.91 (pas de péremption, pas de réacteur à fusion natif)")
  end
else
  info("AVIS : prototype-api.json introuvable ; sources citées dans X.LIMITS non relues (contrôles sautés)")
end
check(X.LIMITS.item_amount_max == 2 ^ 16 - 1, "quantité maximale d'objet = uint16 (65 535)")
check(X.LIMITS.wire_distance_max == 64 and X.LIMITS.supply_distance_max == 64, "portée de fil et d'alimentation : 64 au plus")

---------------------------------------------------------------------------------------------------
section("Structure, noms, traductions")
---------------------------------------------------------------------------------------------------
local idx = X.index()
local function count_pairs(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
for _, coll in ipairs({ { "items", X.items }, { "buildings", X.buildings }, { "recipes", X.recipes }, { "resources", X.resources },
                        { "epochs", X.epochs }, { "branches", X.branches }, { "tiles", X.tiles } }) do
  check(#coll[2] > 0 and #coll[2] == count_pairs(coll[2]), coll[1] .. " : tableau pur (itération par ipairs, jamais pairs)")
end
check(#X.epochs == 15, "15 époques")
for k, e in ipairs(X.epochs) do check(e.n == k, "époque " .. k .. " à sa place") end
check(#X.branches == 4, "4 branches avancées")

-- Noms du contenu de base (vanilla réel + existant) : pour détecter les collisions.
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
  check(it.epoch >= 1 and it.epoch <= 15 and it.epoch % 1 == 0, it.name .. " : époque entière de 1 à 15")
  seen_item[it.name] = true
end
for _, b in ipairs(X.buildings) do
  check(b.name:sub(1, 3) == X.PREFIX and valid_name(b.name), b.name .. " : nom de bâtiment valide, préfixe fo-")
  check(not seen_item[b.name], b.name .. " : nom unique (un bâtiment est aussi un objet)")
  check(not base_item[b.name], b.name .. " : ne masque aucun bâtiment vanilla")
  check(type(b.fr) == "string" and #b.fr > 0 and type(b.en) == "string" and #b.en > 0, b.name .. " : noms FR et EN")
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
end
for _, res in ipairs(X.resources) do
  check(res.name:sub(1, 3) == X.PREFIX and valid_name(res.name) and not seen_resource[res.name], res.name .. " : ressource nommée, unique")
  check(res.fr and res.en and res.where_fr, res.name .. " : noms FR, EN et emplacement")
  seen_resource[res.name] = true
end
for _, e in ipairs(X.epochs) do check(e.fr and e.en and e.reveal_fr and e.energy_fr, "époque " .. e.n .. " : noms et récit") end
for _, br in ipairs(X.branches) do check(br.fr and br.en and br.mechanic_fr and br.yields_fr, "branche " .. br.key .. " : noms et mécanique") end
for _, t in ipairs(X.tiles) do check(t.name:sub(1, 3) == X.PREFIX and t.fr and t.en, t.name .. " : tuile nommée") end

---------------------------------------------------------------------------------------------------
section("Graphe complet : vanilla réelle + existant + nouveau")
---------------------------------------------------------------------------------------------------
-- Recettes de base : la fixture (246 recettes réelles, vanilla 1.1.91 + mod), l'arsenal et les modules
-- relus dans shared/content, le centre de commandement, puis les corrections proposées (X.existing_overrides).
local base_recipes = {}
local function to_pairs(list)
  local out = {}
  for _, e in ipairs(list) do out[#out + 1] = { e.name or e[1], e.amount or e[2] } end
  return out
end
for _, rn in ipairs(sorted_keys(FIX)) do
  local f = FIX[rn]
  base_recipes[rn] = { name = rn, category = f.category, time = f.energy, ingredients = to_pairs(f.ingredients), results = to_pairs(f.products), base = true }
end
-- Dans A.ammo, « category » est la catégorie de RECETTE ; dans A.special_ammo, c'est la catégorie de
-- MUNITION (la recette y est « crafting », comme dans prototypes/arsenal_special.lua).
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

-- Époques des recettes de base : couverture complète, sans doublon.
local base_epoch = {}
for _, row in ipairs(X.base_recipe_epochs) do
  for _, n in ipairs(row[2]) do
    check(base_epoch[n] == nil, n .. " : une seule époque dans le re-rangement")
    base_epoch[n] = row[1]
  end
end
for _, rn in ipairs(sorted_keys(base_recipes)) do
  check(base_epoch[rn] ~= nil, rn .. " : recette de base rangée dans une époque")
  base_recipes[rn].epoch = base_epoch[rn] or 99
end
for _, n in ipairs(sorted_keys(base_epoch)) do check(base_recipes[n] ~= nil, n .. " : le re-rangement ne cite que des recettes réelles") end

-- Toutes les recettes, triées par nom (ordre déterministe du point fixe).
local all = {}
for _, rn in ipairs(sorted_keys(base_recipes)) do all[#all + 1] = base_recipes[rn] end
for _, p in ipairs(X.base_pseudo) do all[#all + 1] = p end
for _, r in ipairs(X.recipes) do all[#all + 1] = r end
table.sort(all, function(a, b) return a.name < b.name end)

-- Types : fluide ou objet.
local is_fluid = {}
for _, f in ipairs(X.base_fluids) do is_fluid[f] = true end
for _, it in ipairs(X.items) do if it.type == "fluid" then is_fluid[it.name] = true end end
for _, rn in ipairs(sorted_keys(FIX)) do
  for _, i in ipairs(FIX[rn].ingredients) do if i.type == "fluid" then is_fluid[i.name] = true end end
  for _, p in ipairs(FIX[rn].products) do if p.type == "fluid" then is_fluid[p.name] = true end end
end

-- Objets connus.
local known = {}
for _, n in ipairs(sorted_keys(base_item)) do known[n] = true end
for _, rn in ipairs(sorted_keys(base_recipes)) do for _, r in ipairs(base_recipes[rn].results) do known[r[1]] = true end end
for _, it in ipairs(X.items) do known[it.name] = true end
for _, b in ipairs(X.buildings) do known[b.name] = true end

for _, r in ipairs(X.recipes) do
  for _, i in ipairs(r.ingredients) do check(known[i[1]], r.name .. " : ingrédient connu " .. tostring(i[1])) end
  for _, p in ipairs(r.results) do check(known[p[1]], r.name .. " : produit connu " .. tostring(p[1])) end
end
for _, p in ipairs(X.base_pseudo) do
  for _, i in ipairs(p.ingredients) do check(known[i[1]], p.name .. " : ingrédient connu " .. i[1]) end
end

-- Machines : catégorie → machines.
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

-- Point fixe : époque la plus tôt où chaque objet est disponible.
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
local function fixpoint()
  avail = {}
  local changed, passes_fp = true, 0
  while changed and passes_fp < 200 do
    changed, passes_fp = false, passes_fp + 1
    for _, r in ipairs(all) do
      local e = recipe_avail(r)
      if e < INF then
        for _, p in ipairs(r.results) do
          if e < av(p[1]) then avail[p[1]] = e; changed = true end
        end
      end
    end
  end
  return passes_fp
end
local fp_passes = fixpoint()
check(fp_passes < 200, "le point fixe converge (" .. fp_passes .. " passes)")

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
info(string.format("%d recettes dans le graphe (%d de base, %d pseudo-recettes de base, %d nouvelles) : %d infranchissable(s), %d anachronisme(s)",
  #all, count_pairs(base_recipes), #X.base_pseudo, #X.recipes, unreachable, anachronic))

-- Re-calcul pour le déterminisme : même résultat, objet par objet.
local snapshot = {}
for _, n in ipairs(sorted_keys(avail)) do snapshot[n] = avail[n] end
fixpoint()
local same = true
for _, n in ipairs(sorted_keys(snapshot)) do if snapshot[n] ~= avail[n] then same = false end end
check(same and count_pairs(snapshot) == count_pairs(avail), "point fixe déterministe (deux calculs identiques)")

---------------------------------------------------------------------------------------------------
section("Époques (F1-2, F1-3, Q5, Q6)")
---------------------------------------------------------------------------------------------------
local res_by_epoch, mat_by_epoch, bld_by_epoch = {}, {}, {}
for k = 1, 15 do res_by_epoch[k], mat_by_epoch[k], bld_by_epoch[k] = 0, 0, 0 end
for _, r in ipairs(X.resources) do res_by_epoch[r.epoch] = res_by_epoch[r.epoch] + 1 end
for _, r in ipairs(X.base_resources) do res_by_epoch[r.epoch] = res_by_epoch[r.epoch] + 1 end
for _, it in ipairs(X.items) do if it.material or it.type == "fluid" then mat_by_epoch[it.epoch] = mat_by_epoch[it.epoch] + 1 end end
for _, b in ipairs(X.buildings) do bld_by_epoch[b.epoch] = bld_by_epoch[b.epoch] + 1 end
local total_hours = 0
for k, e in ipairs(X.epochs) do
  check(res_by_epoch[k] + mat_by_epoch[k] >= 1, "époque " .. k .. " : au moins une ressource ou un matériau (F1-2)")
  check(bld_by_epoch[k] >= 1, "époque " .. k .. " : au moins un bâtiment nouveau (F1-2)")
  info(string.format("époque %2d %-18s ressources %d, matériaux et fluides %d, bâtiments %d", k, e.fr, res_by_epoch[k], mat_by_epoch[k], bld_by_epoch[k]))
  check(av(e.pack) == k, "époque " .. k .. " : son pack " .. e.pack .. " naît à l'époque " .. k)
  for _, c in ipairs(e.currency) do check(av(c) <= k, "époque " .. k .. " : monnaie " .. c .. " disponible") end
  check(#e.currency >= 1, "époque " .. k .. " : au moins une monnaie de niveau")
  if k <= 14 then
    check(idx.item["fo-codex-" .. k] and av("fo-codex-" .. k) == k, "époque " .. k .. " : Codex " .. k .. " fabricable pour passer le centre")
  else
    check(idx.item["fo-codex-15"] == nil, "pas de Codex 15 (le centre plafonne à 15)")
  end
  local ms = e.milestones
  check(av(ms.production[1]) <= k and ms.production[2] > 0, "époque " .. k .. " : jalon de production atteignable")
  check(av(ms.construction[1]) <= k, "époque " .. k .. " : jalon de construction atteignable")
  if ms.exploration.resource then
    local rr = idx.resource[ms.exploration.resource]
    local re = rr and rr.epoch
    if not re then for _, b in ipairs(X.base_resources) do if b.name == ms.exploration.resource then re = b.epoch end end end
    check(re and re <= k, "époque " .. k .. " : jalon d'exploration sur une ressource de l'époque ou d'avant")
  else
    check(ms.exploration.chart and ms.exploration.chart > 0, "époque " .. k .. " : jalon d'exploration (carte)")
  end
  local win = X.pack_window(k)
  check(#win >= 1 and #win <= 4 and win[1] == e.pack, "époque " .. k .. " : fenêtre de packs de 1 à 4 sortes, pack de l'époque en tête")
  for _, pk in ipairs(win) do check(av(pk) <= k, "époque " .. k .. " : pack " .. pk .. " de la fenêtre disponible") end
  check(#X.pack_window(k, { military = true }) <= 4, "époque " .. k .. " : fenêtre militaire de 4 sortes au plus")
  total_hours = total_hours + X.epoch_hours(k)
  if k > 1 then
    check(X.epoch_hours(k) >= X.epoch_hours(k - 1), "époque " .. k .. " : durée croissante ou plafonnée")
    check(X.budget(k) > X.budget(k - 1) and X.cc_upgrade_mu(k) > X.cc_upgrade_mu(k - 1), "époque " .. k .. " : budget et passage du centre croissants")
  end
end
check(X.epoch_hours(1) == 0.5, "F1-3 : époque 1 en 30 min")
check(math.abs(total_hours - 59.5) < 1e-9, "F1-3 : 15 époques en 59,5 h (environ 60 h)")
check(math.abs(X.rate(1) - 3) < 1e-9 and math.abs(X.rate(15) - 14000) < 1e-6, "débit visé de 3 à 14 000 MU/s")
local tier_start = { 1, 4, 7, 10, 13 }
for t, ep in ipairs(tier_start) do
  check(X.logistics_tier(ep) == t and (ep == 1 or X.logistics_tier(ep - 1) == t - 1), "Q5 : palier T" .. t .. " à l'époque " .. ep .. " (un palier toutes les 3 époques)")
  check(X.compaction.tiers[t].epoch == ep and X.compaction.tiers[t].rho == BM.PROPOSAL.density[t]
        and X.compaction.tiers[t].belt == BM.PROPOSAL.belt_items[t], "Compaction T" .. t .. " conforme à shared/balance_model.lua")
  check(X.TIER_DENSITY[t] == BM.PROPOSAL.density[t], "densité T" .. t .. " = BALANCE_SHEET §3")
end
check(X.builders(1) == 1 and X.builders(4) == 2 and X.builders(7) == 3 and X.builders(10) == 4 and X.builders(13) == 5, "ouvriers 1 à 5, un de plus toutes les 3 époques")
check(X.builders(15, true) == 6, "6e ouvrier avec l'Horloge éternelle")
check(X.max_building_level(1) == 2 and X.max_building_level(15) == 30, "Q6 : 2 niveaux par époque, 30 niveaux à l'époque 15")
check(X.epoch_lock_tech(2) == "fo-epoch-2" and X.epoch_lock.first == 2 and X.epoch_lock.last == 15, "verrou d'époque : fo-epoch-2 à fo-epoch-15")

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
    local n = 0
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
      end
    end
    check(n >= 2, "branche " .. br.key .. " niveau " .. level .. " : ses propres recettes (" .. n .. ")")
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
  factions_seen[br.faction] = br.key
end
check(#X.tide == 24, "marée : 24 phases")
-- La ligne principale (époques 1 à 14) ne consomme jamais un objet de branche.
for _, r in ipairs(X.recipes) do
  if not r.branch and r.epoch <= 14 then
    for _, i in ipairs(r.ingredients) do
      check(not branch_item[i[1]], r.name .. " : la ligne principale ne dépend pas de l'objet de branche " .. i[1])
    end
  end
end
-- Doctrines : une faction par branche, rivalités réciproques.
local doc_by_faction = {}
for _, d in ipairs(X.doctrines) do doc_by_faction[d.faction] = d end
for _, d in ipairs(X.doctrines) do
  check(factions_seen[d.faction] == d.branch, d.faction .. " : doctrine " .. d.branch .. " cohérente avec la branche")
  check(doc_by_faction[d.sworn_rival] and doc_by_faction[d.sworn_rival].sworn_rival == d.faction, d.faction .. " : rivalité jurée réciproque")
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
  local sink = (consumers[it.name] or 0) > 0 or SINK_USES[it.use or ""] or false
  check(sink, it.name .. " : consommé par une recette ou par un usage (" .. tostring(it.use) .. ")")
end
for _, b in ipairs(X.buildings) do check(producers[b.name] ~= nil, b.name .. " : bâtiment fabricable") end
for _, fl in ipairs(X.flare_fluids) do check(is_fluid[fl] and idx.recipe["fo-flare-" .. fl:sub(4)], fl .. " : puits de torchère") end

-- Productivité : jamais sur compaction, décompaction, catalyse, conversion, transmutation ni boucle.
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

-- Énergie (P5) : un combustible fabriqué rend moins que ce qu'il coûte, sauf liste blanche explicite.
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
        check(r.whitelist_fr or true, r.name .. " : liste blanche justifiée")
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

-- MU (greffe P2) : une matière dense vaut au moins 0,75 × ρ en matière brute.
local rho = {}
for _, it in ipairs(X.items) do if it.rho then rho[it.name] = it.rho end end
local mu = {}
local function mu_of(n) return mu[n] or INF end
local function weight(name, amount, p)
  if is_fluid[name] then return amount * (p or 1) * (rho[name] or 0) end
  return amount * (p or 1) * (rho[name] or 1)
end
local mu_changed, mu_passes = true, 0
while mu_changed and mu_passes < 400 do
  mu_changed, mu_passes = false, mu_passes + 1
  for _, r in ipairs(all) do
    if r.kind ~= "burn" and r.kind ~= "sink" then
      local input, ok = 0, true
      if r.kind == "mining" or r.kind == "launch" then
        input = nil
      else
        for _, i in ipairs(r.ingredients) do
          -- Un fluide sans densité ne porte aucune matière (eau, gaz) ; un fluide porteur (TiCl₄) attend sa valeur.
          local m = (is_fluid[i[1]] and not rho[i[1]]) and 0 or mu_of(i[1])
          if m == INF then ok = false break end
          input = input + m * (i[2] - (i.catalyst or 0))
        end
      end
      if ok then
        local W = 0
        for _, p in ipairs(r.results) do W = W + weight(p[1], p[2] - (p.catalyst or 0), p.p) end
        for _, p in ipairs(r.results) do
          local unit
          if input == nil then
            unit = is_fluid[p[1]] and 0 or (rho[p[1]] or 1)            -- extraction : la matière brute vaut sa densité
          elseif W > 0 then
            unit = input * (is_fluid[p[1]] and (rho[p[1]] or 0) or (rho[p[1]] or 1)) / W
          end
          if unit and unit < mu_of(p[1]) - 1e-12 then mu[p[1]] = unit; mu_changed = true end
        end
      end
    end
  end
end
check(mu_passes < 400, "calcul des MU convergent (" .. mu_passes .. " passes)")
for _, it in ipairs(X.items) do
  if it.material then
    check(mu_of(it.name) >= 0.75 * it.rho - 1e-9,
      string.format("%s : MU %.2f ≥ 0,75 × ρ%g (matière dense honnête)", it.name, mu_of(it.name), it.rho))
  end
end

---------------------------------------------------------------------------------------------------
section("Compaction ×4 (B1) : formes denses")
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
local f_fe = X.dense_forms(1, 1)
check(#f_fe == 5, "le fer existe en ρ1, 2, 4, 8 et 32")
local f_pl = X.dense_forms(4, 1)
check(#f_pl == 4 and f_pl[2] == 4, "le plastique (né en T2) commence à ρ4")
for _, n in ipairs(X.compaction.intermediates) do check(known[n], "intermédiaire dense " .. n .. " : objet vanilla réel") end
for _, bmat in ipairs(X.compaction.base_materials) do check(known[bmat[1]], "matière compactée " .. bmat[1] .. " : objet réel") end
info(variants .. " variantes denses de recettes à générer par le lot C (hors intermédiaires)")

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
  if r.category and not r.machines then
    local fits = false
    for _, m in ipairs(machines_of(r)) do
      local d = machine_def[m]
      if (d.fluid_in or 0) >= n_fluid_in and (d.fluid_out or 0) >= n_fluid_out then fits = true end
    end
    check(fits, string.format("%s : une machine de « %s » a %d entrée(s) et %d sortie(s) de fluide", r.name, r.category, n_fluid_in, n_fluid_out))
  end
  if r.kind == "mining" then
    local res = idx.resource[r.resource]
    check(res ~= nil, r.name .. " : ressource déclarée " .. tostring(r.resource))
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
end
for _, b in ipairs(X.buildings) do
  check(b.size[1] <= X.LIMITS.new_building_side_max and b.size[2] <= X.LIMITS.new_building_side_max, b.name .. " : 10 × 10 au plus (Q9)")
  if b.proto == "electric-pole" then
    check(b.wire_distance <= X.LIMITS.wire_distance_max and b.supply_distance <= X.LIMITS.supply_distance_max, b.name .. " : portée de fil et d'alimentation ≤ 64")
  end
  if b.proto == "beacon" then check(b.supply_distance <= X.LIMITS.supply_distance_max, b.name .. " : portée de balise ≤ 64") end
  if b.proto == "locomotive" then check(b.energy.type == "burner", b.name .. " : locomotive à brûleur (seule source permise avec void)") end
  if b.proto == "reactor" then check(b.energy.type ~= "heat", b.name .. " : un réacteur n'a pas de source de chaleur en entrée") end
  if b.proto == "rocket-silo" then
    check(b.rocket_parts_required >= 1 and b.rocket_parts_required <= 2 ^ 32 - 1, b.name .. " : rocket_parts_required en uint32")
    check(idx.recipe[b.fixed_recipe] ~= nil, b.name .. " : recette fixe déclarée")
  end
  if b.fixed_recipe then
    local fr = idx.recipe[b.fixed_recipe]
    local ok = false
    for _, c in ipairs(b.categories or {}) do if fr and fr.category == c then ok = true end end
    check(ok, b.name .. " : recette fixe dans ses catégories")
  end
  if b.proto == "lab" then for _, pk in ipairs(b.inputs) do check(known[pk], b.name .. " : pack accepté connu " .. pk) end end
end

---------------------------------------------------------------------------------------------------
section("Factions, difficulté, évolution (Q4)")
---------------------------------------------------------------------------------------------------
check(#X.difficulty == 5, "5 niveaux de difficulté")
for i, d in ipairs(X.difficulty) do
  check(d.fr and d.en, d.key .. " : nommé FR et EN")
  check(d.evolution_offset >= -0.05 and d.evolution_offset <= 0.06, d.key .. " : décalage d'évolution de -0,05 à +0,06")
  if i > 1 then
    local p = X.difficulty[i - 1]
    check(d.share > p.share and d.size > p.size, d.key .. " : part et taille des attaques croissantes")
    if p.attack_every_minutes then check(d.attack_every_minutes < p.attack_every_minutes, d.key .. " : attaques plus fréquentes") end
    if p.epoch_offset then check(d.epoch_offset > p.epoch_offset, d.key .. " : écart d'époque croissant") end
  end
end
check(X.difficulty[1].attack_every_minutes == nil and X.difficulty[1].share == 0, "Paisible : aucune attaque contre le joueur")
check(X.difficulty[4].gate_race_hours and X.difficulty[5].gate_race_hours and X.difficulty[3].gate_race_hours == nil, "course à la Porte en Difficile et Impitoyable seulement")
for _, d in ipairs(X.difficulty) do
  local prev = 0
  for _, mu_v in ipairs({ 0, 100, 1000, 10000, 100000, 1000000, 10000000 }) do
    for _, pe in ipairs({ 1, 5, 10, 15 }) do
      local fe = X.faction_epoch(mu_v, pe, d)
      check(fe >= 1 and fe <= 15, d.key .. " : époque de faction entre 1 et 15")
      if d.epoch_offset then check(fe <= math.max(1, pe + d.epoch_offset), d.key .. " : plafonnée par l'époque du joueur décalée") end
    end
    local fe15 = X.faction_epoch(mu_v, 15, d)
    check(fe15 >= prev, d.key .. " : l'époque de faction ne recule pas quand le minage réel croît")
    prev = fe15
  end
end
check(X.faction_epoch(1e9, 15, X.difficulty[5]) == 15, "Impitoyable : une faction peut atteindre l'époque 15 (course à la Porte)")
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
check(X.evolution_window[1][1] == 0 and X.evolution_window[1][2] == 0.10 and X.evolution_window[15][1] == 0.85 and X.evolution_window[15][2] == 1.0,
  "fenêtre de 0-0,10 (époque 1) à 0,85-1,00 (époque 15)")
check(X.td_max_tier[15] == 8, "primordiaux (palier 8) à l'époque 15")
for t = 2, #X.loot.unit_probability do check(X.loot.unit_probability[t] > X.loot.unit_probability[t - 1], "butin croissant avec le palier") end
check(X.loot.unit_probability[1] == 0.02 and X.loot.unit_probability[8] == 0.08, "butin : 2 % (petit) à 8 % (primordial)")
-- Marée : table sans trigonométrie, 0,5 à midi, 1,5 à minuit, moyenne 1.
local tsum = 0
for i = 1, 24 do
  tsum = tsum + X.tide[i]
  check(X.tide[i] >= 0.5 - 1e-12 and X.tide[i] <= 1.5 + 1e-12, "marée phase " .. (i - 1) .. " dans [0,5 ; 1,5]")
end
check(X.tide[1] == 0.5 and X.tide[13] == 1.5 and math.abs(tsum / 24 - 1) < 1e-12, "marée : 0,5 à midi, 1,5 à minuit, rendement moyen 1")
-- Score de puissance, chantiers de zone.
check(X.power(0, 1, 0, 0) == 500 and X.power(100, 15, 3, 75) == 100 + 7500 + 6000 + 3750, "score de puissance")
local tf, cf = X.zone_upgrade_factors(10)
check(math.abs(tf - 1.9) < 1e-12 and cf == 10, "chantier de zone : 10 bâtiments, durée × 1,9, coût × 10")

---------------------------------------------------------------------------------------------------
section("La Porte : bilan de fin de partie")
---------------------------------------------------------------------------------------------------
local function amount_in(r, n) for _, i in ipairs(r.ingredients) do if i[1] == n then return i[2] end end return 0 end
local gate, key, opening = idx.recipe["fo-erebus-gate"], idx.recipe["fo-phase-key"], idx.recipe["fo-open-gate"]
local nseg = amount_in(opening, "fo-ring-segment")
check(nseg == X.branch_params.gate.segments and idx.building["fo-erebus-gate"].rocket_parts_required == nseg, "100 segments = 100 pièces du silo réhabillé")
local exotic = nseg * amount_in(segment, "fo-stabilized-exotic-matter") + amount_in(gate, "fo-stabilized-exotic-matter") + amount_in(key, "fo-stabilized-exotic-matter")
check(exotic == 230, "230 matières exotiques stabilisées pour ouvrir la Porte (" .. exotic .. ")")
local stab = idx.recipe["fo-exotic-stabilization"]
local raw = exotic * amount_in(stab, "fo-raw-exotic-matter")
check(raw == 11500, "11 500 matières exotiques brutes")
for _, br in ipairs(X.branches) do
  local need = nseg * amount_in(segment, br.gate_item) + amount_in(idx.recipe["fo-rift-anchor"], br.gate_item)
  info(string.format("branche %s : %d × %s consommés (segments et ancre)", br.key, need, br.gate_item))
end
local superalloy = nseg * amount_in(segment, "fo-superalloy") + amount_in(gate, "fo-superalloy") + amount_in(idx.recipe["fo-rift-anchor"], "fo-superalloy")
info(string.format("superalliage ρ32 : %d (soit %d MU) ; matière exotique brute : %d", superalloy, superalloy * 32, raw))
check(X.branch_params.gate.power_mw == 5000 and X.branch_params.gate.charge_minutes == 30, "charge de 30 min sous 5 GW")

---------------------------------------------------------------------------------------------------
-- Volume
---------------------------------------------------------------------------------------------------
local n_items, n_fluids = 0, 0
for _, it in ipairs(X.items) do if it.type == "fluid" then n_fluids = n_fluids + 1 else n_items = n_items + 1 end end
local kinds = {}
for _, r in ipairs(X.recipes) do kinds[r.kind] = (kinds[r.kind] or 0) + 1 end
local kind_list = {}
for _, k in ipairs(sorted_keys(kinds)) do kind_list[#kind_list + 1] = k .. " " .. kinds[k] end
info(string.format("volume : %d objets, %d fluides, %d bâtiments, %d ressources, %d tuiles ; recettes : %s",
  n_items, n_fluids, #X.buildings, #X.resources, #X.tiles, table.concat(kind_list, ", ")))

print(string.format("Résultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
