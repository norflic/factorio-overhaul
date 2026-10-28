--[[
  Tests hors jeu du lot PLANDIR : le poteau des gabarits est le MOINS CHER dont la recette est débloquée
  (docs/IA_CAPITALISATION.md, journal ETAPE1 du 27/10 : plan directeur allumé à 17,8 min, 4 à 5 min après l'objet « bras
  rapide », parce que les gabarits exigeaient le poteau moyen alors que le petit était ouvert dès le départ).
  Usage, depuis la racine du mod :   lua5.2 tests/plandir_test.lua

  Vérifie : table des poteaux triée (portée de fil, nom) ; choix pur (A.choose_pole) selon le livre, le coffre et le bois ;
  chaque gabarit du catalogue et chaque extension passent M.check avec le petit poteau (couverture et liaison des fils,
  un seul type de poteau) ou cèdent au poteau par défaut ; régénération (M.extend) fidèle au poteau ; le poteau est
  rétabli après une erreur ; A.cost compte le poteau choisi ; MUTANTS.
]]

package.path = "./?.lua;" .. package.path
local M = require("shared.team.modules")
local A = require("shared.ai3.automatiser")
local Book = require("shared.team.book")
local recipes = dofile("tests/fixtures/recipes.lua")
local recipes_book = nil

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end

local SMALL, MEDIUM = "small-electric-pole", "medium-electric-pole"
recipes_book = Book.new(recipes)

---------------------------------------------------------------------------------------------------
section("1. Table des poteaux")
check(#M.POLES == 2 and M.POLES[1] == SMALL and M.POLES[2] == MEDIUM, "poteaux triés par portée de fil : petit (7,5) puis moyen (9)")
check(M.DEFAULT_POLE == MEDIUM, "poteau par défaut : le moyen (catalogue inchangé)")
check(M.cheapest_pole(function() return true end) == SMALL, "tout ouvert : le moins cher est le petit")
check(M.cheapest_pole(function(n) return n == MEDIUM end) == MEDIUM, "seul le moyen ouvert : le moyen")
check(M.cheapest_pole(function() return false end) == nil, "rien d'ouvert : nil")

---------------------------------------------------------------------------------------------------
section("2. Choix pur selon le livre, le coffre et le bois")
local function book_with(allowed_names)
  local set = {}
  for _, n in ipairs(allowed_names) do set[n] = true end
  return Book.new(recipes, { allowed = function(n) return not (n == MEDIUM or n == "big-electric-pole") or set[n] end })
end
local early = book_with({})
local late = book_with({ MEDIUM })
check(A.choose_pole(early, { ["wood"] = 100 }) == SMALL, "début de partie, du bois : petit poteau (le moyen n'est pas ouvert)")
check(A.choose_pole(late, { ["wood"] = 100 }) == SMALL, "moyen ouvert, du bois : toujours le petit (le moins cher)")
check(A.choose_pole(early, {}) == nil, "début de partie, sans bois : aucun (le moyen n'est pas ouvert)")
check(A.choose_pole(late, {}) == MEDIUM, "moyen ouvert, sans bois : le moyen (aucune matière naturelle à attendre)")
check(A.choose_pole(early, { ["wood"] = 5 }) == nil, "5 bois ne font pas 20 poteaux : aucun")
check(A.choose_pole(early, { ["wood"] = 10 }) == SMALL, "10 bois = 20 petits poteaux (recette 1 bois -> 2) : petit")
check(A.choose_pole(early, { [SMALL] = 20 }) == SMALL, "20 petits poteaux au coffre : petit, sans bois")
check(A.choose_pole(early, { [MEDIUM] = 20 }) == MEDIUM, "20 poteaux moyens au coffre : moyen, même recette fermée")
check(early:natural("wood") and not early:natural("iron-plate") and not early:natural("copper-cable"),
  "bois naturel ; plaque (four) et câble (main) ne le sont pas")

---------------------------------------------------------------------------------------------------
section("3. Gabarits avec le petit poteau : catalogue et toutes les extensions (A.template contrôle et cède au besoin)")
local function poles_of(g)
  local set, n = {}, 0
  for _, e in ipairs(g.entities) do
    if M.spec(e.name).kind == "pole" then set[e.name] = (set[e.name] or 0) + 1; n = n + 1 end
  end
  return set, n
end
local cat0 = M.catalogue()
local n_small, n_fallback, n_tpl = 0, 0, 0
local fallbacks = {}
local small_n, medium_n = 0, 0
for _, g0 in ipairs(cat0) do
  local _, n_poles = poles_of(g0)
  local ex = g0.extensions and g0.extensions[1]
  local lo, hi = 1, (ex and ex.max >= 1) and ex.max or 1
  for k = lo, hi do
    local args = {}
    for i = 1, #g0.args do args[i] = g0.args[i] end
    if ex and ex.max >= 1 then args[ex.arg] = k end
    local t = A.template(g0.gen, args, SMALL)
    n_tpl = n_tpl + 1
    if check(t ~= nil, g0.key .. " n=" .. k .. " : gabarit obtenu") then
      -- le gabarit rendu passe le contrôle, quel que soit le poteau retenu
      local g = M.regenerate(g0, ex and { [ex.arg] = k } or nil, t.pole)
      local errs = M.check(g)
      check(#errs == 0, g0.key .. " n=" .. k .. " (" .. tostring(t.pole) .. ") sans erreur : " .. tostring(errs[1]))
      local set, n = poles_of(g)
      if n_poles == 0 then
        check(n == 0, g0.key .. " : un gabarit sans poteau n'en gagne pas")
      else
        check(t.pole == (g.pole_name), g0.key .. " n=" .. k .. " : résumé et gabarit au même poteau")
        local other = (t.pole == SMALL) and MEDIUM or SMALL
        check(set[other] == nil, g0.key .. " n=" .. k .. " : un seul type de poteau")
        if t.pole == SMALL then n_small = n_small + 1; small_n = small_n + n
        else n_fallback = n_fallback + 1; fallbacks[#fallbacks + 1] = g0.key .. "/" .. k end
      end
    end
  end
end
print(string.format("  %d gabarit(s)/taille(s) examinés : %d au petit poteau (%d poteaux), %d cédant au poteau par défaut",
  n_tpl, n_small, small_n, n_fallback))
if #fallbacks > 0 then print("  cèdent : " .. table.concat(fallbacks, " ")) end
check(n_small > n_fallback, "la plupart des tailles passent au petit poteau")
check(M.current_pole == nil, "poteau courant rétabli après les gabarits")

---------------------------------------------------------------------------------------------------
section("4. Le poteau est rétabli après une erreur ; le catalogue ne garde pas le petit")
local ok = pcall(M.with_pole, SMALL, function() error("boom") end)
check(not ok and M.current_pole == nil, "erreur dans with_pole : poteau rétabli")
local cat1 = M.with_pole(SMALL, function() return M.catalogue() end)
for _, g in ipairs(cat1) do
  local set = poles_of(g)
  check(set[SMALL] == nil, g.key .. " : le catalogue (mis en cache) ne porte jamais le petit poteau")
end

---------------------------------------------------------------------------------------------------
section("5. A.template, A.sized et A.cost portent le poteau choisi")
A.reset_cache()
local meth
for _, m in ipairs(A.METHODS) do if m.product == "electronic-circuit" or m.product == "automation-science-pack" then meth = meth or m end end
check(meth ~= nil, "une méthode électrique est écrite")
local t_def = A.template(meth.gen, meth.args)
local t_small = A.template(meth.gen, meth.args, SMALL)
check(t_def.pole == MEDIUM and t_small.pole == SMALL, "gabarit résumé : poteau noté (moyen par défaut, petit demandé)")
check((t_small.items[SMALL] or 0) > 0 and (t_small.items[MEDIUM] or 0) == 0, "objets du gabarit : petits poteaux, pas de moyen")
check((t_def.items[MEDIUM] or 0) > 0 and (t_def.items[SMALL] or 0) == 0, "objets du gabarit par défaut : moyens")
check(A.template(meth.gen, meth.args, SMALL) == t_small, "cache : même résumé au même poteau")
local _, items_s = A.cost(meth, t_small, {})
local _, items_d = A.cost(meth, t_def, {})
check((items_s[SMALL] or 0) >= (t_small.items[SMALL] or 0) + A.NET_POLES and items_s[MEDIUM] == nil,
  "A.cost compte les poteaux de réseau au poteau du gabarit (petit)")
check((items_d[MEDIUM] or 0) >= (t_def.items[MEDIUM] or 0) + A.NET_POLES and items_d[SMALL] == nil,
  "A.cost par défaut : poteaux moyens")
local g_s, args_s = A.sized(meth, 30, SMALL)
check(g_s and g_s.pole == SMALL, "A.sized au petit poteau")
-- un poteau inconnu du générateur cède au poteau par défaut (faux poteau : le gabarit ne couvre pas)
local t_bad = A.template(meth.gen, meth.args, "poteau-inconnu")
check(t_bad ~= nil and t_bad.pole == MEDIUM or t_bad == nil, "poteau inconnu : repli sur le poteau par défaut (ou refus net)")

---------------------------------------------------------------------------------------------------
section("6. Décision : la fonderie électrique n'attend plus le poteau moyen")
do
  local function win(n, loads, mades)
    local w = {}
    for i = 1, n do
      local b = { m = i, load = {}, made = {}, logi = {} }
      for k, v in pairs(loads) do b.load[k] = v end
      for k, v in pairs(mades) do b.made[k] = v end
      w[i] = b
    end
    return w
  end
  local hot = win(10, { ["iron-plate"] = 7200 }, { ["iron-plate"] = 60 })
  local stock = { wood = 500 }
  local function decide(pole)
    A.reset_cache()
    local r = A.decide({ window = hot, book = early, stock = stock, pole = pole,
      obtainable = function(i) return early:handcraftable(i) or (stock[i] or 0) > 0 end })
    for _, v in ipairs(r.verdicts) do if v.product == "iron-plate" then return v, r end end
  end
  local v_old, r_old = decide(nil)
  check(v_old.verdict == "recherche" and r_old.wanted[MEDIUM], "avant : verdict recherche, poteau moyen voulu (" .. tostring(v_old.why) .. ")")
  local v_new, r_new = decide(A.choose_pole(early, stock))
  print(string.format("  avant : %s (%s) ; après : %s (%s)", v_old.verdict, tostring(v_old.why), v_new.verdict, tostring(v_new.why)))
  check(not r_new.wanted[MEDIUM], "après : le poteau moyen n'est plus voulu par la recherche")
  check(not tostring(v_new.why):find("poteau", 1, true) and not tostring(v_new.why):find(MEDIUM, 1, true), "après : aucun poteau parmi les objets impossibles")
  -- le module reste impossible faute d'un AUTRE objet ? alors il n'est pas lié au poteau ; sinon une demande porte le poteau
  for _, r in ipairs(r_new.requests) do
    check(r.pole == SMALL, "la demande de " .. r.product .. " porte le poteau choisi (" .. tostring(r.pole) .. ")")
    check((r.items[SMALL] or 0) > 0 and r.items[MEDIUM] == nil, "objets de la demande : petits poteaux, aucun poteau moyen")
  end
  -- sans bois : le petit poteau n'est pas choisi, le comportement d'avant revient (le moyen est voulu)
  stock = {}
  local v_nw, r_nw = decide(A.choose_pole(early, stock))
  check(r_nw.wanted[MEDIUM], "sans bois : le poteau moyen est de nouveau voulu (" .. tostring(v_nw.why) .. ")")
end

---------------------------------------------------------------------------------------------------
section("7. Mutants")
do
  -- (a) poteaux triés à l'envers : le moyen serait choisi avant le petit
  local saved = { M.POLES[1], M.POLES[2] }
  M.POLES[1], M.POLES[2] = saved[2], saved[1]
  check(A.choose_pole(late, { wood = 100 }) ~= SMALL, "mutant tri inversé : détecté (le choix ne serait plus le petit)")
  M.POLES[1], M.POLES[2] = saved[1], saved[2]
  -- (b) le bois n'est plus compté : un petit poteau serait choisi sans bois, jamais fabricable
  local nat = Book.natural
  Book.natural = function() return false end
  check(A.choose_pole(early, {}) == SMALL, "mutant « bois ignoré » : le choix change sans bois")
  Book.natural = nat
  check(A.choose_pole(early, {}) == nil, "le vrai choix sans bois refuse le petit poteau")
  -- (c) régénération qui oublie le poteau
  local g0 = M.with_pole(SMALL, function() return M.GEN.circuits() end)
  local g_ok = M.regenerate(g0)
  local set_ok = poles_of(g_ok)
  check(set_ok[SMALL] ~= nil and set_ok[MEDIUM] == nil, "régénération fidèle au poteau")
  g0.pole_name = nil
  local set_bad = poles_of(M.regenerate(g0))
  check(set_bad[MEDIUM] ~= nil, "mutant « poteau oublié » : la régénération reprend le moyen (le contrôle 3 le verrait)")
end

---------------------------------------------------------------------------------------------------
section("8. Meilleure machine (T1) : les gabarits des machines plus rapides passent le contrôle")
do
  local all = function() return true end
  local n_checked, n_changed = 0, 0
  for _, m in ipairs(A.METHODS) do
    local m2 = A.method_for(m.product, recipes_book, all)
    local changed = false
    for i = 1, #m.args do if m2.args[i] ~= m.args[i] then changed = true end end
    if changed then
      n_changed = n_changed + 1
      local t = A.template(m2.gen, m2.args)
      if check(t ~= nil, m.product .. " : gabarit de la meilleure machine obtenu") then
        local ex = t.ext
        for k = 1, (ex and ex.max or 1) do
          local args = {}
          for i = 1, #m2.args do args[i] = m2.args[i] end
          if ex then args[ex.arg] = k end
          local g = M.GEN[m2.gen](table.unpack(args))
          if check(g ~= nil, m.product .. " n=" .. k .. " : gabarit refait") then
            local errs = M.check(g)
            check(#errs == 0, m.product .. " n=" .. k .. " (" .. tostring(m2.args[1]) .. "," .. tostring(m2.args[2]) .. ") sans erreur : " .. tostring(errs[1]))
            n_checked = n_checked + 1
          end
        end
      end
    end
  end
  print(string.format("  %d méthode(s) écrites changent de machine, %d taille(s) contrôlées", n_changed, n_checked))
  check(n_changed >= 4, "au moins quatre gabarits écrits passent à la machine 2")
  -- rangées générées depuis toutes les recettes de la main à 1 ou 2 ingrédients solides : machine 2 contrôlée aussi
  local n_gen, n_fail, n_regress = 0, 0, 0
  for _, item in ipairs({ "pipe", "iron-stick", "copper-cable", "stone-brick", "inserter", "transport-belt", "underground-belt",
    "firearm-magazine", "piercing-rounds-magazine", "engine-unit", "iron-chest", "steel-chest" }) do
    local m = A.method_for(item, recipes_book, all)
    local m1 = A.method_for(item, recipes_book)
    if m and m.generic then
      local t = A.template(m.gen, m.args)
      local t1 = A.template(m1.gen, m1.args)
      n_gen = n_gen + 1
      if not t then n_fail = n_fail + 1; if t1 then n_regress = n_regress + 1 end end
    end
  end
  print(string.format("  %d rangée(s) générée(s) examinée(s), %d refusée(s) (dont %d acceptées sur la machine 1 : repli)", n_gen, n_fail, n_regress))
  check(n_regress == 0, "une rangée acceptée sur la machine 1 l'est encore (repli sur la machine écrite)")
  check(n_gen >= 3, "au moins trois rangées générées examinées")
end

print(string.format("[PLANDIR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
