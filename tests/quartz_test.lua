--[[
  Tests hors jeu du lot X3-MINERAIS (30/10) : le quartz filonien et la fonderie de puces d'X3 (chaîne A, âge 10) mis en jeu
  tels qu'X3 les décrit (shared/content/quartz.lua, shared/content/world.lua, shared/content/guarantee.lua contre
  shared/content/x3.lua), avec les objets des pistes CRAFTS (silicium, taillerie, salle blanche, four à arc), ÉTAIN (résine
  époxy, carte imprimée) et BAUXITE (aluminium).

    lua5.2 tests/quartz_test.lua
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(t) print("== " .. t) end

local Q = require("shared.content.quartz")
local W = require("shared.content.world")
local G = require("shared.content.guarantee")
local C = require("shared.content.crafts")
local Sn = require("shared.content.tin")
local B = require("shared.content.bauxite")
local X3 = require("shared.content.x3")

local function near(a, b) return a and math.abs(a - b) < 1e-9 end
local function index(list) local t = {} for _, v in ipairs(list) do t[v] = true end return t end

---------------------------------------------------------------------------------------------------
section("Quartz filonien : la ressource d'X3")
---------------------------------------------------------------------------------------------------
local qw = W.resources.quartz
local qx = Q.x3_resource("fo-vein-quartz")
check(qx and qx.epoch == 10 and qx.kind == "ore" and qx.category == "basic-solid", "fo-vein-quartz : minerai d'X3, âge 10, basic-solid")
check(qw.resource == qx.name and qw.epoch == qx.epoch and qw.item == qx.products[1] and qw.category == nil,
  "world.lua : nom, âge, produit, catégorie d'X3")
check(near(qw.mining_time, qx.mining_time) and near(qw.mining_time, Q.recipe("fo-mine-vein-quartz").time), "minage 3 s (X3)")
check(qw.biome == "fo-crystal-flats", "plaine de cristal (X3 : « veines blanches de la plaine de cristal »)")
check(qw.autoplace.none == true and qx.placement.autoplace:find("aucune", 1, true) ~= nil,
  "aucun autoplace (X3 : « posées par la SEULE garantie ») : le cristal de résonance ne bouge sur aucune graine")
check(qw.sheet and qw.sheet.effet == nil and qw.glint == nil, "feuille propre SANS couche d'effet (X3 : « sans lueur »)")
do
  local seen, dup = {}, nil
  for _, k in ipairs(W.resource_order) do
    local a = W.resources[k].autoplace
    for _, s in ipairs({ a.seed1, a.region and a.region.seed1 }) do
      if seen[s] then dup = k .. " " .. s end
      seen[s] = true
    end
  end
  for _, b in ipairs(W.biomes) do if b.region and b.region.seed1 and seen[b.region.seed1] then dup = b.name end end
  check(dup == nil, "graine des candidats de la garantie distincte de toutes les autres (" .. tostring(dup) .. ")")
end

---------------------------------------------------------------------------------------------------
section("Garantie : 2 veines de 200 000 à 400-800 tuiles, sur un disque de plaine de cristal")
---------------------------------------------------------------------------------------------------
local gs = G.spec("quartz")
local gx = qx.placement.guaranteed
check(gs and gs.count == gx.count and gs.dmin == gx.distance[1] and gs.dmax == gx.distance[2] and gs.count == 2,
  "2 veines à 400-800 tuiles (X3)")
check(gs and gs.tile == "fo-crystal-flats" and gs.kind == "ore" and gs.icon == "fo-vein-quartz",
  "site : disque de plaine de cristal (repli d'X3), étiquette : l'objet")
do
  local lo, hi = 1e18, 0
  for seed = 1, 200 do
    local L = G.layout(gs, -500, 210, seed * 7919, 1)
    if L.total < lo then lo = L.total end
    if L.total > hi then hi = L.total end
  end
  check(lo >= 190000 and hi <= 215000, string.format("veine : %d à %d (environ 200 000, X3)", lo, hi))
  check(lo >= 1.5 * gs.min_total, "une veine vaut au moins 1,5 × min_total")
end
check(W.guarantee_order[#W.guarantee_order] == "quartz" and W.resource_order[#W.resource_order] == "quartz",
  "quartz EN DERNIER (sites garantis et lettres d'ordre d'avant inchangés)")
do -- les candidats sont dans l'anneau, sur 50 graines
  local bad = 0
  for seed = 1, 50 do
    local cands = G.candidates(seed * 104729, gs, 24, 0)
    for _, c in ipairs(cands) do
      local d = math.sqrt(c.x * c.x + c.y * c.y)
      if d < gs.dmin or d > gs.dmax then bad = bad + 1 end
    end
  end
  check(bad == 0, "candidats dans l'anneau 400-800 sur 50 graines (" .. bad .. " hors)")
end

---------------------------------------------------------------------------------------------------
section("Couleur de carte")
---------------------------------------------------------------------------------------------------
local function lab(c)
  local function lin(u) if u <= 0.04045 then return u / 12.92 end return ((u + 0.055) / 1.055) ^ 2.4 end
  local r, g, b = lin(c[1]), lin(c[2]), lin(c[3])
  local x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
  local y = 0.2126 * r + 0.7152 * g + 0.0722 * b
  local z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
  local function f(t) if t > 0.008856 then return t ^ (1 / 3) end return 7.787 * t + 16 / 116 end
  return { 116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)) }
end
local function de(a, b)
  local p, q = lab(a), lab(b)
  return math.sqrt((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 + (p[3] - q[3]) ^ 2)
end
--- Rose ou violet (le DC n'en veut pas) : a* franchement positif avec b* bas, ou bleu-violet.
local function pinkish(c) local L = lab(c) return (L[2] > 12 and L[3] < 25) or (L[2] > 5 and L[3] < -15) end
local function color_report(mc)
  local REF = {
    { "fer", { 0.415, 0.525, 0.580 } }, { "cuivre", { 0.803, 0.388, 0.215 } }, { "charbon", { 0, 0, 0 } },
    { "pierre", { 0.690, 0.611, 0.427 } }, { "uranium", { 0, 0.7, 0 } }, { "pétrole", { 0.78, 0.2, 0.77 } },
    { "eau", { 51 / 255, 83 / 255, 95 / 255 } }, { "herbe", { 55 / 255, 53 / 255, 11 / 255 } },
    { "désert", { 138 / 255, 103 / 255, 58 / 255 } }, { "ennemi", { 1, 0, 0 } },
  }
  -- seuils des tests des autres ressources (zinc, bauxite, galène : 45 ; fumerolle : 35) : le quartz ne doit pas les casser
  local THR = { sphalerite = 45, bauxite = 45, galena = 45, fumarole = 35 }
  local theirs = true
  for _, k in ipairs(W.resource_order) do
    if k ~= "quartz" then
      local c = W.resources[k].map_color
      REF[#REF + 1] = { k, { c.r, c.g, c.b } }
      if THR[k] and de(mc, { c.r, c.g, c.b }) < THR[k] then theirs = false end
    end
  end
  for _, b in ipairs(W.biomes) do local c = b.map_color; REF[#REF + 1] = { b.name, { c.r / 255, c.g / 255, c.b / 255 } } end
  local worst, wn = 1e9, ""
  for _, r in ipairs(REF) do local d = de(mc, r[2]) if d < worst then worst, wn = d, r[1] end end
  return worst, wn, theirs
end
do
  local mc = { qw.map_color.r, qw.map_color.g, qw.map_color.b }
  local worst, wn, theirs = color_report(mc)
  print(string.format("  couleur de carte : ΔE76 %.1f (%s)", worst, wn))
  check(worst >= 40, string.format("couleur de carte : ΔE76 %.1f au plus proche (%s), >= 40", worst, wn))
  check(theirs, "les seuils des tests de la blende, de la bauxite, de la galène et de la fumerolle tiennent")
  check(not pinkish(mc) and lab(mc)[1] >= 55, "ni rose ni violet, claire (lisible sur la carte sombre)")
end

---------------------------------------------------------------------------------------------------
section("Objets, recettes, bâtiments : ceux d'X3, tout en jeu")
---------------------------------------------------------------------------------------------------
for _, n in ipairs(Q.ITEMS) do
  local it = Q.x3_item(n)
  local age = n == "fo-crystal-laser" and 7 or 10
  check(it and it.type == "item" and it.epoch == age and it.stack >= 50, n .. " : objet d'X3, âge " .. age)
end
for _, n in ipairs(Q.FLUIDS) do check(Q.x3_item(n) and Q.x3_item(n).type == "fluid", n .. " : fluide d'X3") end
local pu, li = Q.building("fo-crystal-puller"), Q.building("fo-crystal-lithograph")
check(pu.size[1] == 3 and pu.kw == 1500 and (pu.fluid_in or 0) == 0 and pu.categories[1] == "fo-crystal-pulling",
  "tireuse : 3 × 3, 1,5 MW, sans fluide (X3)")
check(li.size[1] == 4 and li.kw == 3000 and li.fluid_in == 2 and li.categories[1] == "fo-lithography",
  "lithographe : 4 × 4, 3 MW, 2 entrées de fluide (X3)")
local CATS = { ["fo-arc-smelting"] = true, ["fo-lapidary"] = true, chemistry = true, ["fo-cleanroom"] = true, crafting = true,
  ["advanced-crafting"] = true, ["fo-crystal-pulling"] = true, ["fo-lithography"] = true }
for _, rr in ipairs(Q.all_recipes()) do
  local r = Q.recipe(rr.name)
  check(CATS[r.category], rr.name .. " : catégorie en jeu (" .. r.category .. ")")
  for _, i in ipairs(r.ingredients) do check(Q.present(i[1]), rr.name .. " : ingrédient en jeu " .. i[1]) end
  for _, p in ipairs(r.results) do check(Q.present(p[1]), rr.name .. " : produit en jeu " .. p[1]) end
  local fl = 0
  for _, i in ipairs(r.ingredients) do
    local f = Q.is_fluid(i[1])
    if f == nil then f = (i[1] == "water" or i[1] == "sulfuric-acid" or i[1] == "light-oil" or i[1] == "heavy-oil") end
    if f then fl = fl + 1 end
  end
  if r.category == "fo-lithography" then check(fl <= li.fluid_in, rr.name .. " : " .. fl .. " fluide(s) pour 2 entrées") end
  if r.category == "fo-crystal-pulling" then check(fl == 0, rr.name .. " : aucun fluide (la tireuse n'a pas d'entrée)") end
end
check(Q.recipe("fo-wafer-sawing").variant_of == "fo-silicon-wafer" and Q.recipe("fo-etched-processor").variant_of == "processing-unit",
  "variantes : tranches sciées (tranche de la salle blanche) et processeur gravé (processeur) ; les voies d'avant restent")
for _, n in ipairs(Q.LEFT_OUT) do check(not Q.present(n), n .. " : hors jeu (débouché = centre de calcul, D-20 (4))") end
check(not Q.present("fo-data-center") and not Q.present("fo-servo-motor"), "chaînes B et C d'X3 : hors jeu")

---------------------------------------------------------------------------------------------------
section("Aucun objet sans usage ; l'étain et l'aluminium servent à l'âge 10")
---------------------------------------------------------------------------------------------------
--- Objets du lot qu'aucune recette du lot (bâtiments compris) ne consomme, hors produits des variantes (objets d'avant).
local function dead_ends(items, recipes)
  local used = {}
  for _, rr in ipairs(recipes) do
    for _, i in ipairs(Q.recipe(rr.name).ingredients) do used[i[1]] = true end
  end
  local out = {}
  for _, n in ipairs(items) do if not used[n] then out[#out + 1] = n end end
  return out
end
local own = { Q.ORE }
for _, n in ipairs(Q.ITEMS) do own[#own + 1] = n end
for _, n in ipairs(Q.FLUIDS) do own[#own + 1] = n end
local dead = dead_ends(own, Q.all_recipes())
check(#dead == 0, "chaque objet du lot sert dans le lot (" .. table.concat(dead, ", ") .. ")")
local k = Q.per_etched_processor()
check(near(k.pcb, 1) and near(k.tin, 0.5) and near(k.etched_wafer, 1),
  string.format("par processeur gravé : %.2f carte imprimée, %.2f étain, %.2f tranche gravée", k.pcb, k.tin, k.etched_wafer))
check(near(k.green, 4.5) and near(k.red, 0.5), "par processeur gravé : 4,5 circuits verts et 0,5 avancé (X0 : 10 et 2 pour 1 en salle blanche, X3)")
local laser_al = 0
for _, i in ipairs(Q.recipe("fo-crystal-laser").ingredients) do if i[1] == "fo-aluminium-plate" then laser_al = i[2] end end
local litho_laser = 0
for _, i in ipairs(Q.recipe("fo-crystal-lithograph").ingredients) do if i[1] == "fo-crystal-laser" then litho_laser = i[2] end end
check(laser_al == 1 and litho_laser == 4, "aluminium : 1 par laser, 4 lasers par lithographe (X3)")
local w = Q.per_sawn_wafer()
check(near(w.quartz, 0.15) and near(w.pure_silicon, 0.25) and near(w.powder, 0.05),
  string.format("par tranche sciée : %.3f quartz, %.2f silicium pur, %.2f poudre de cristal (X3 : 6 quartz par creuset, 40 tranches)", w.quartz, w.pure_silicon, w.powder))

---------------------------------------------------------------------------------------------------
section("Technologie")
---------------------------------------------------------------------------------------------------
local t = Q.TECHS[1]
local tx = Q.x3_tech(t.x3)
check(tx and tx.epoch == t.epoch and t.epoch == 10, "fo-chip-foundry : technologie d'X3, âge 10")
do
  local mine, theirs = index(t.unlocks), index(tx.unlocks)
  local left = index(Q.LEFT_OUT)
  local missing, extra = {}, {}
  for _, u in ipairs(tx.unlocks) do if not mine[u] and not left[u] then missing[#missing + 1] = u end end
  for _, u in ipairs(t.unlocks) do if not theirs[u] and u ~= "fo-crystal-laser" then extra[#extra + 1] = u end end
  check(#missing == 0 and #extra == 0, "déblocages = X3 moins la mémoire et la carte graphique, plus le laser à cristal (écart 1) ; manque : "
    .. table.concat(missing, ", ") .. " ; en trop : " .. table.concat(extra, ", "))
  local everything = {}
  for _, rr in ipairs(Q.all_recipes()) do everything[#everything + 1] = rr.name end
  local unl = index(t.unlocks)
  local orphan = {}
  for _, n in ipairs(everything) do if not unl[n] then orphan[#orphan + 1] = n end end
  check(#orphan == 0, "toute recette du lot est débloquée (" .. table.concat(orphan, ", ") .. ")")
end
do
  local known = {}
  for _, ct in ipairs(C.TECHS) do known[ct.name] = true end
  for _, ct in ipairs(Sn.TECHS) do known[ct.name] = true end
  for _, ct in ipairs(B.TECHS) do known[ct.name] = true end
  for _, p in ipairs(t.prerequisites) do check(known[p] or not p:find("^fo%-"), "prérequis en jeu : " .. p) end
  local servo = Q.x3_tech("fo-servo-mechanisms")
  local pre = index(t.prerequisites)
  for _, p in ipairs(servo.prereq) do check(pre[p], "prérequis des servomécanismes (absents du jeu) repris : " .. p) end
  for _, p in ipairs(tx.prereq) do check(pre[p] or p == "fo-servo-mechanisms", "prérequis d'X3 repris : " .. p) end
end
check(Q.tech_count(t) >= 10 and #Q.packs(10) >= 6, "unités (règle QX9) et packs de l'âge 10 (" .. table.concat(Q.packs(10), ", ") .. ")")

---------------------------------------------------------------------------------------------------
section("D-20 (1) : proposition seulement")
---------------------------------------------------------------------------------------------------
check(#Q.MANDATORY_STEP.hide == 2 and #Q.MANDATORY_STEP.becomes_mandatory == 3,
  "obligation du quartz : 2 recettes à cacher, 3 minerais deviendraient obligatoires (non appliqué : question au DC)")
check(#X3.retouches == 0, "aucune retouche d'X0 (des voies, jamais une porte)")

---------------------------------------------------------------------------------------------------
section("Mutants")
---------------------------------------------------------------------------------------------------
do
  local r = Q.recipe("fo-etched-processor")
  local saved = r.ingredients
  r.ingredients = { saved[1], saved[3], saved[4] }
  check(not near(Q.per_etched_processor().tin, 0.5), "M1 : processeur gravé sans carte imprimée : l'étain ne sert plus (détecté)")
  r.ingredients = saved
  local d = dead_ends({ "fo-memory-module" }, Q.all_recipes())
  check(#d == 1, "M2 : module de mémoire mis en jeu sans centre de calcul : objet sans usage (détecté)")
  check(pinkish({ 1.00, 0.60, 0.85 }), "M3 : la teinte la plus éloignée de tout (rose 1 ; 0,6 ; 0,85) est refusée")
  local _, _, theirs = color_report({ 0.0, 0.05, 0.6 })
  check(not theirs, "M4 : une couleur à ΔE < 45 de la blende casse son test (détecté)")
end

print(string.format("[QUARTZ] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
