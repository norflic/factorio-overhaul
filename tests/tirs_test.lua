-- Banc hors jeu du lot TIRS (27/10) : table des âges, règles pures, garde « aucun effet de jeu » (mutants).
--   lua5.2 tests/tirs_test.lua      -> [TIRS] BILAN : N OK, 0 ECHEC(S)
package.path = "./?.lua;" .. package.path

local T = require("shared.tirs.ages")
local R = require("shared.tirs.regles")

local ok, ko = 0, 0
local function check(c, quoi, detail)
  if c then ok = ok + 1 else ko = ko + 1; print("ECHEC  " .. quoi .. (detail and (" : " .. tostring(detail)) or "")) end
end

local function copie(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = copie(v) end
  return c
end

-- 1. table des âges bien formée, âges témoins
local m = R.verifier_ages(T)
check(#m == 0, "table des ages bien formee", table.concat(m, " ; "))
check(#T.temoins == 4 and T.temoins[1] == 1 and T.temoins[2] == 5 and T.temoins[3] == 10 and T.temoins[4] == 15,
  "ages temoins 1, 5, 10, 15")
for e = 1, 15 do
  local temoin = e == 1 or e == 5 or e == 10 or e == 15
  check((T.ages[e] ~= nil) == temoin, "age " .. e .. (temoin and " habille" or " garde l'effet d'avant"))
end
-- part croissante avec l'âge (plus spectaculaire en montant), plafond positif
local prev = 0
for _, e in ipairs(T.temoins) do
  local p = T.probabilite * T.ages[e].part[1] / T.ages[e].part[2]
  check(p > prev, "part des tirs habilles croissante (age " .. e .. ")", p)
  prev = p
end
-- grandeurs croissantes avec l'âge : lumière de bouche, échelle de bouche, traçante
local lum, ech, tr = 0, 0, 0
for _, e in ipairs(T.temoins) do
  local b = T.ages[e].bouche[1]
  check(b.lumiere.taille > lum, "lumiere de bouche croissante (age " .. e .. ")", b.lumiere.taille)
  check(b.echelle * (T.IMAGES[b.image or ""] and 1 or 1) > 0, "echelle de bouche positive (age " .. e .. ")")
  lum = b.lumiere.taille
  local t = T.ages[e].trace
  check(t and t.echelle > tr, "traçante plus grosse a chaque age (age " .. e .. ")", t and t.echelle)
  tr = t and t.echelle or tr
  ech = b.echelle
end
-- sons : couches ajoutées aux âges 5, 10, 15 ; volumes plafonnés ; aggregation
for _, e in ipairs({ 5, 10, 15 }) do
  local c = T.ages[e].son and T.ages[e].son.couches
  check(c and #c >= 1, "age " .. e .. " : couches de son ajoutees")
  for _, x in ipairs(c or {}) do
    check(x.volume <= 0.5 and x.max <= 2, "age " .. e .. " : couche plafonnee (volume <= 0,5, max <= 2)", x.volume)
    for _, f in ipairs(R.fichiers(x.fichiers)) do
      check(f:match("^__base__/sound/fight/[%w%-]+%.ogg$") ~= nil, "son vanilla reference " .. f)
    end
  end
end
check(T.ages[1].son == nil, "age 1 : son S0 inchange")

-- 2. accumulateur : a sur b exactement, sans ordre ni hasard
for _, p in ipairs({ { 2, 5 }, { 1, 2 }, { 2, 3 }, { 1, 1 }, { 1, 7 } }) do
  local c, n, gaps, last, maxgap = 0, 0, 0, 0, 0
  for i = 1, 1000 * p[2] do
    local g
    g, c = R.garder(c, p)
    if g then
      n = n + 1
      maxgap = math.max(maxgap, i - last)
      last = i
    end
  end
  check(n == 1000 * p[1], "garder " .. p[1] .. "/" .. p[2] .. " : exact", n)
  check(maxgap <= math.ceil(p[2] / p[1]), "garder " .. p[1] .. "/" .. p[2] .. " : regulier (ecart max)", maxgap)
end
-- 3. plafond par tick
local etat = { tick = -1, n = 0 }
local passes = 0
for _ = 1, 10 do if R.plafond(etat, 100, 6) then passes = passes + 1 end end
check(passes == 6, "plafond : 6 tirs par tick", passes)
check(R.plafond(etat, 101, 6), "plafond : remis a zero au tick suivant")

-- 4. garde : prototypes sans jeu (témoins acceptés, mutants refusés)
local permis = { ["fo-tir-15-impact-1"] = true, ["fo-tir-15-impact-1-etincelle"] = true }
local trace = { type = "projectile", name = "fo-tir-15-trace", acceleration = 0,
  action = { type = "direct", action_delivery = { type = "instant", target_effects = {
    { type = "create-explosion", entity_name = "fo-tir-15-impact-1" } } } } }
local expl = { type = "explosion", name = "fo-tir-15-impact-1", created_effect = { type = "direct",
  action_delivery = { type = "instant", target_effects = { { type = "create-particle",
    particle_name = "fo-tir-15-impact-1-etincelle", initial_height = 1 } } } } }
local trait = { type = "beam", name = "fo-tir-15-trait" }
check(R.verifier_prototype(trace, permis) == nil, "temoin : traçante sans degats acceptee")
check(R.verifier_prototype(expl, permis) == nil, "temoin : explosion a etincelles acceptee")
check(R.verifier_prototype(trait, permis) == nil, "temoin : trait sans action accepte")
check(R.verifier_prototype({ type = "trivial-smoke", name = "f" }, permis) == nil, "temoin : fumee acceptee")

local mutants = {
  { "traçante qui blesse", function(p) table.insert(p.action.action_delivery.target_effects,
      { type = "damage", damage = { amount = 5, type = "physical" } }) end, trace },
  { "traçante a nested-result", function(p) p.action.action_delivery.target_effects[1] = { type = "nested-result",
      action = {} } end, trace },
  { "traçante qui cree une entite de jeu", function(p) p.action.action_delivery.target_effects[1] = {
      type = "create-entity", entity_name = "fire-flame" } end, trace },
  { "traçante qui cree une explosion hors liste", function(p)
      p.action.action_delivery.target_effects[1].entity_name = "explosion" end, trace },
  { "traçante a zone", function(p) p.action.type = "area" end, trace },
  { "traçante a livraison projectile", function(p) p.action.action_delivery.type = "projectile" end, trace },
  { "traçante a final_action", function(p) p.final_action = { type = "direct" } end, trace },
  { "traçante perforante", function(p) p.piercing_damage = 100 end, trace },
  { "traçante qui touche (collision_box)", function(p) p.collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } } end, trace },
  { "traçante qui pousse (push-back)", function(p) p.action.action_delivery.target_effects[1] = { type = "push-back",
      distance = 2 } end, trace },
  { "traçante qui colle (sticker)", function(p) p.action.action_delivery.target_effects[1] = {
      type = "create-sticker", sticker = "slowdown-sticker" } end, trace },
  { "traçante a effet script", function(p) p.action.action_delivery.target_effects[1] = { type = "script",
      effect_id = "x" } end, trace },
  { "explosion qui blesse", function(p) p.created_effect.action_delivery.target_effects[1] = { type = "damage",
      damage = { amount = 5, type = "fire" } } end, expl },
  { "explosion a feu", function(p) p.created_effect.action_delivery.target_effects[1] = { type = "create-fire",
      entity_name = "fire-flame" } end, expl },
  { "trait avec action", function(p) p.action = { type = "direct" } end, trait },
  { "type hors lot", function(p) p.type = "sticker" end, trait },
  { "particule a effet au sol", function(p) p.type = "optimized-particle"; p.ended_on_ground_trigger_effect = {
      type = "damage" } end, trait },
}
for _, mu in ipairs(mutants) do
  local p = copie(mu[3])
  mu[2](p)
  check(R.verifier_prototype(p, permis) ~= nil, "mutant refuse : " .. mu[1])
end

local mutants_ages = {
  { "part a > b", function(t) t.ages[5].part = { 3, 2 } end },
  { "part non entiere", function(t) t.ages[5].part = { 0.5, 1 } end },
  { "bouche vide", function(t) t.ages[10].bouche = {} end },
  { "impact vide", function(t) t.ages[10].impact = {} end },
  { "image inconnue", function(t) t.ages[15].impact[2].image = "rien" end },
  { "source et image", function(t) t.ages[15].impact[2].source = "explosion" end },
  { "traçante trop lente", function(t) t.ages[1].trace.vitesse = 0.3 end },
  { "trait trop long", function(t) t.ages[15].trait.duree = 90 end },
  { "teinte hors [0, 1]", function(t) t.ages[5].bouche[1].teinte = { 2, 0, 0 } end },
  { "son trop fort", function(t) t.ages[15].son.couches[1].volume = 1.5 end },
  { "son sans aggregation", function(t) t.ages[15].son.couches[1].max = nil end },
  { "age hors liste des temoins", function(t) t.ages[7] = copie(t.ages[5]) end },
  { "probabilite nulle", function(t) t.probabilite = 0 end },
}
for _, mu in ipairs(mutants_ages) do
  local t = copie(T)
  mu[2](t)
  check(#R.verifier_ages(t) > 0, "mutant de la table refuse : " .. mu[1])
end

-- 5. noms
check(R.nom(T, 5, "bouche", 1) == "fo-tir-05-bouche-1" and R.nom(T, 15, "trace") == "fo-tir-15-trace", "noms du lot")

print(string.format("[TIRS] BILAN : %d OK, %d ECHEC(S)", ok, ko))
os.exit(ko == 0 and 0 or 1)
