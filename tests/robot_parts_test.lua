--[[
  Lot RB-4 GAMME (1/11) : banc hors jeu du sous-ensemble d'X3 mis en jeu pour les robots (shared/content/robot_parts.lua).
    §1 les 7 pièces viennent d'X3 (âges 7, 10, 12) ; leurs recettes sont celles d'X3 sauf les 2 écarts déclarés ;
    §2 le noyau de pilotage ne demande ni calcul (D-20 (4)) ni carte graphique (âge 11) ;
    §3 chaque ingrédient est une matière en jeu (vanilla, X0 mis en jeu, ou pièce de ce lot), jamais un fluide « fo-compute » ;
    §4 les technologies : âges 7, 10, 12, prérequis déclarés, chaque pièce débloquée une fois ;
    §5 X3 n'est pas modifié (aucun écart n'écrit dans x3.lua) ; §6 mutants.
  Usage : lua5.2 tests/robot_parts_test.lua
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local SRC = read("shared/content/robot_parts.lua")
local X3 = require("shared.content.x3")
local Ro = require("shared.content.robots")

local function load_parts(src)
  local f = load(src, "=parts", "t")
  if not f then return nil end
  local ok, P = pcall(f)
  return ok and P or nil
end

local function suite(P)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end end
  check(#P.ITEMS == 7, "§1 sept pièces")
  local epochs = { ["fo-servo-motor"] = 7, ["fo-optical-sensor"] = 7, ["fo-controller"] = 7, ["fo-guidance-core"] = 10,
    ["fo-magnetic-actuator"] = 12, ["fo-ndyag-rod"] = 12, ["fo-laser-module"] = 12 }
  for _, n in ipairs(P.ITEMS) do
    check(P.item(n).epoch == epochs[n], "§1 âge de " .. n)
    local r = P.recipe(n)
    check(#r.results == 1 and r.results[1][1] == n and r.time > 0 and #r.ingredients >= 3, "§1 recette de " .. n)
    check(r.epoch == epochs[n], "§1 âge de la recette de " .. n)
  end
  -- écarts : seuls le noyau et le barreau
  check(P.OVERRIDES["fo-guidance-core"] ~= nil and P.OVERRIDES["fo-ndyag-rod"] ~= nil and #P.DEVIATIONS == 2, "§1 deux écarts déclarés à X3")
  for _, n in ipairs({ "fo-servo-motor", "fo-optical-sensor", "fo-controller", "fo-magnetic-actuator", "fo-laser-module" }) do
    local x = nil
    for _, rr in ipairs(X3.recipes) do if rr.name == n then x = rr break end end
    local r = P.recipe(n)
    local same = x and x.category == r.category and x.time == r.time and #x.ingredients == #r.ingredients
    if same then
      for i, g in ipairs(x.ingredients) do if g[1] ~= r.ingredients[i][1] or g[2] ~= r.ingredients[i][2] then same = false end end
    end
    check(same, "§1 " .. n .. " : exactement la recette d'X3")
  end
  -- §2 noyau
  local core = P.recipe("fo-guidance-core")
  local has = {}
  for _, g in ipairs(core.ingredients) do has[g[1]] = g[2] end
  check(has["fo-compute"] == nil and has["fo-graphics-card"] == nil and has["fo-controller"] == 1 and has["fo-motherboard"] == 1 and has["fo-optical-sensor"] == 2,
    "§2 noyau : contrôleur, carte mère, deux capteurs ; ni calcul ni carte graphique")
  -- §3 matières
  local ok_ings = true
  for _, n in ipairs(P.ITEMS) do
    for _, g in ipairs(P.recipe(n).ingredients) do
      if g[1] == "fo-compute" or g[1] == "fo-crystal-puller" then ok_ings = false end
    end
  end
  check(ok_ings, "§3 aucun fluide de calcul ni machine non posée en ingrédient")
  local cats_ok = true
  for _, n in ipairs(P.ITEMS) do
    local c = P.recipe(n).category
    if c ~= "crafting" and c ~= "advanced-crafting" then cats_ok = false end
  end
  check(cats_ok, "§3 chaque pièce se fabrique dans un assembleur vanilla (crafting ou advanced-crafting)")
  -- §4 technologies
  local seen, tech_ok = {}, true
  local expect = { ["fo-servo-mechanisms"] = 7, ["fo-robot-guidance"] = 10, ["fo-magnetic-drive"] = 12 }
  for _, t in ipairs(P.TECHS) do
    if expect[t.name] ~= t.epoch then tech_ok = false end
    for _, u in ipairs(t.unlocks) do seen[u] = (seen[u] or 0) + 1 end
  end
  local every = true
  for _, n in ipairs(P.ITEMS) do if seen[n] ~= 1 then every = false end end
  check(tech_ok and #P.TECHS == 3 and every, "§4 trois technologies (âges 7, 10, 12), chaque pièce débloquée une fois")
  check(P.of_epoch(7)[1] == "fo-servo-motor" and #P.of_epoch(12) == 3 and #P.of_epoch(10) == 1 and P.present("fo-laser-module") and not P.present("fo-combat-robot"),
    "§4 pièces par âge ; le robot de combat d'X3 reste parqué")
  -- les robots ne citent que des pièces de ce lot parmi les objets d'X3
  local parked = { ["fo-combat-robot"] = true, ["fo-laser-drone-capsule"] = true, ["fo-guard-drone-capsule"] = true, ["fo-crystal-laser"] = true }
  local cited_ok = true
  for _, r in ipairs(Ro.ROBOTS) do
    local lists = { r.ingredients, r.segment and r.segment.ingredients or {} }
    for _, l in ipairs(lists) do for _, g in ipairs(l) do if parked[g[1]] then cited_ok = false end end end
  end
  check(cited_ok, "§4 aucun robot ne demande un objet d'X3 resté parqué")
  return pass, fail, msgs
end

local P0 = assert(load_parts(SRC))
local pass, fail, msgs = suite(P0)

-- §5 X3 intact : le module n'écrit rien dans X3
check_src = SRC:gsub("%-%-%[%[.-%]%]", "")
if check_src:find("X3%.[%w_]+%s*=") or check_src:find("table%.insert%(X3") then
  fail = fail + 1
  msgs[#msgs + 1] = "§5 le module écrit dans X3"
else
  pass = pass + 1
end

-- §6 Mutants.
local MUTANTS = {
  { "noyau avec calcul", '{ "fo-controller", 1 }, { "fo-motherboard", 1 }, { "fo-optical-sensor", 2 }', '{ "fo-controller", 1 }, { "fo-compute", 20 }, { "fo-optical-sensor", 2 }' },
  { "noyau avec carte graphique", '{ "fo-controller", 1 }, { "fo-motherboard", 1 }, { "fo-optical-sensor", 2 }', '{ "fo-controller", 1 }, { "fo-graphics-card", 1 }, { "fo-optical-sensor", 2 }' },
  { "noyau à un capteur", '{ "fo-optical-sensor", 2 } }, category', '{ "fo-optical-sensor", 1 } }, category' },
  { "robot de combat en jeu", '"fo-ndyag-rod", "fo-laser-module" }', '"fo-ndyag-rod", "fo-laser-module", "fo-combat-robot" }' },
  { "technologie des actionneurs à l'âge 11", 'name = "fo-magnetic-drive", epoch = 12', 'name = "fo-magnetic-drive", epoch = 11' },
  { "servomoteur oublié des technologies", 'unlocks = { "fo-servo-motor", "fo-optical-sensor", "fo-controller" }', 'unlocks = { "fo-optical-sensor", "fo-controller" }' },
  { "pièce en double dans les technologies", 'unlocks = { "fo-guidance-core" }', 'unlocks = { "fo-guidance-core", "fo-servo-motor" }' },
  { "écart du barreau retiré", 'category = "advanced-crafting",\n    why_fr = "catégorie « fo-crystal-pulling »', 'why_fr = "catégorie « fo-crystal-pulling »' },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif absent)" else
    local P = load_parts(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    local f2 = 1
    if P then
      local ok, _, ff = pcall(suite, P)
      f2 = ok and ff or 1
    end
    if f2 > 0 then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
if #kept == 0 then pass = pass + 1 else
  fail = fail + 1
  msgs[#msgs + 1] = "§6 mutants NON refusés : " .. table.concat(kept, " ; ")
end

for _, m in ipairs(msgs) do print("[ROBOT-PARTS] ECHEC " .. m) end
print(string.format("[ROBOT-PARTS] mutants refusés : %d sur %d", refused, #MUTANTS))
print(string.format("[ROBOT-PARTS] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
