--[[
  Lot TV-FLUX, point G51 (docs/TODO_VIDEO.md l.228, « le fluide se juge sur ses barils ») : test hors jeu de Ca.barrels et Ca.barrel_stock
  (shared/ai3/capitalisation.lua) et de leur branchement dans la préparation d'une décision (input.barils).
    §1 les contenants sont LUS dans les recettes (couple « vider » + « remplir » identiques), jamais par un nom : relevé du jeu ET relevé
       jouet à noms inventés ; un couple à sens unique ou à quantités différentes n'est pas un contenant ;
    §2 le stock de fluide = contenants pleins × unités ; copie ; identité sans contenant ; ajout à une entrée existante ;
    §3 dans Ca.decide : réglage éteint = la décision d'avant au chiffre près (même avec des barils au coffre) ; allumé = res.barils ;
    §4 mutants (substitution dans la source de capitalisation.lua).
  Lancement, depuis la racine du mod :   lua5.2 tests/flux_barils_test.lua   -> [FLUX-BARILS] BILAN : N OK, 0 ECHEC(S)
  Ce fichier est du TEST : il nomme les prototypes vanilla (comme le moteur) ; la règle n'en voit rien.
]]
package.path = "./?.lua;" .. package.path
local F = require("tests.iag_fixture")

local pass, fail = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1 if not quiet then print("[FLUX-BARILS] ECHEC : " .. msg) end end
  return cond
end
local function say(s) if not quiet then print("[FLUX-BARILS] " .. s) end end

local function dump_with(extra)
  local d = F.dump({})
  if extra then extra(d) end
  return d
end

local function rec(ing, prod, cat)
  return { category = cat or "crafting-with-fluid", energy = 0.2, hidden = false, enabled = true, ingredients = ing, products = prod }
end

-- Relevé jouet : un fluide « zz-flu » et son contenant « zz-fut » (noms inventés), puis de faux contenants.
local function toy(d)
  d.recipes["zz-remplir"] = rec({ { amount = 40, name = "zz-flu", type = "fluid" }, { amount = 1, name = "zz-vide", type = "item" } },
    { { amount = 1, name = "zz-fut", type = "item" } })
  d.recipes["zz-vider"] = rec({ { amount = 1, name = "zz-fut", type = "item" } },
    { { amount = 40, name = "zz-flu", type = "fluid" }, { amount = 1, name = "zz-vide", type = "item" } })
  -- sens unique : on peut défaire le bloc, jamais le refaire
  d.recipes["yy-defaire"] = rec({ { amount = 1, name = "yy-bloc", type = "item" } },
    { { amount = 25, name = "yy-flu", type = "fluid" }, { amount = 1, name = "yy-reste", type = "item" } })
  -- quantités différentes : le remplissage ne reprend pas ce que le vidage rend
  d.recipes["xx-remplir"] = rec({ { amount = 50, name = "xx-flu", type = "fluid" }, { amount = 1, name = "xx-vide", type = "item" } },
    { { amount = 1, name = "xx-fut", type = "item" } })
  d.recipes["xx-vider"] = rec({ { amount = 1, name = "xx-fut", type = "item" } },
    { { amount = 25, name = "xx-flu", type = "fluid" }, { amount = 1, name = "xx-vide", type = "item" } })
end

local function suite(Ca, chk)
  local D = Ca.data(dump_with(), { exec_roles = { main = true, labo = true } })
  local bar = Ca.barrels(D)
  chk(bar["petroleum-gas"] and bar["petroleum-gas"][1].item == "petroleum-gas-barrel" and bar["petroleum-gas"][1].amount == 50,
    "§1 le gaz de pétrole a son baril de 50 unités, lu aux recettes")
  local n = 0
  for _ in pairs(bar) do n = n + 1 end
  chk(n >= 10, "§1 le relevé du jeu donne plusieurs fluides à contenant (" .. n .. ")")
  chk(Ca.barrels(D) == bar, "§1 relevé gardé (même table au second appel)")
  local T = Ca.data(dump_with(toy), { exec_roles = { main = true, labo = true } })
  local tb = Ca.barrels(T)
  chk(tb["zz-flu"] and #tb["zz-flu"] == 1 and tb["zz-flu"][1].item == "zz-fut" and tb["zz-flu"][1].amount == 40,
    "§1 relevé jouet : contenant et quantité lus sans aucun nom du jeu")
  chk(tb["yy-flu"] == nil, "§1 un vidage sans remplissage n'est pas un contenant")
  chk(tb["xx-flu"] == nil, "§1 un remplissage à d'autres quantités n'est pas un contenant")
  -- contenant double
  local T2 = Ca.data(dump_with(function(d)
    toy(d)
    d.recipes["ww-remplir"] = rec({ { amount = 40, name = "zz-flu", type = "fluid" }, { amount = 1, name = "ww-vide", type = "item" } },
      { { amount = 1, name = "ww-bidon", type = "item" } })
    d.recipes["ww-vider"] = rec({ { amount = 1, name = "ww-bidon", type = "item" } },
      { { amount = 40, name = "zz-flu", type = "fluid" }, { amount = 1, name = "ww-vide", type = "item" } })
  end), { exec_roles = { main = true, labo = true } })
  local b2 = Ca.barrels(T2)["zz-flu"]
  chk(b2 and #b2 == 2 and b2[1].item == "ww-bidon" and b2[2].item == "zz-fut", "§1 deux contenants du même fluide, triés par nom")

  -- §2
  local stock = { ["petroleum-gas-barrel"] = 3, ["crude-oil-barrel"] = 1, ["iron-plate"] = 7 }
  local cp, added = Ca.barrel_stock(D, stock)
  chk(cp ~= stock and cp["petroleum-gas"] == 150 and cp["crude-oil"] == 50, "§2 3 barils de gaz = 150 unités, 1 baril de brut = 50, copie")
  chk(cp["iron-plate"] == 7 and cp["petroleum-gas-barrel"] == 3, "§2 les objets du coffre restent")
  chk(stock["petroleum-gas"] == nil, "§2 le stock donné n'est pas modifié")
  chk(added["petroleum-gas"] == 150 and added["crude-oil"] == 50 and added["iron-plate"] == nil, "§2 ajouts rendus par fluide")
  local _, none = Ca.barrel_stock(D, { ["iron-plate"] = 5 })
  chk(next(none) == nil, "§2 aucun contenant au stock : aucun ajout")
  local s0 = { ["iron-plate"] = 5 }
  chk(select(1, Ca.barrel_stock(D, s0)) == s0, "§2 aucun contenant au stock : le stock lui-même (décision d'avant)")
  local cp3 = Ca.barrel_stock(D, { ["petroleum-gas-barrel"] = 2, ["petroleum-gas"] = 10 })
  chk(cp3["petroleum-gas"] == 110, "§2 un fluide déjà au stock reçoit l'ajout (10 + 100)")
  local cp4 = Ca.barrel_stock(D, { ["petroleum-gas-barrel"] = -4 })
  chk(cp4["petroleum-gas"] == nil, "§2 un compte négatif ne compte pas")
  chk(select(1, Ca.barrel_stock(D, nil)) ~= nil, "§2 stock absent : table vide")
  local ts = Ca.barrel_stock(T2, { ["zz-fut"] = 2, ["ww-bidon"] = 1 })
  chk(ts["zz-flu"] == 120, "§2 deux contenants additionnés (2 × 40 + 1 × 40)")
  local ts2 = Ca.barrel_stock(T2, { ["zz-fut"] = -3, ["ww-bidon"] = 2 })
  chk(ts2["zz-flu"] == 80, "§2 un compte négatif ne retranche rien aux autres contenants")
  -- un même contenant vidé par deux recettes n'est compté qu'une fois
  local T3 = Ca.data(dump_with(function(d)
    toy(d)
    d.recipes["zz-vider-bis"] = rec({ { amount = 1, name = "zz-fut", type = "item" } },
      { { amount = 40, name = "zz-flu", type = "fluid" }, { amount = 1, name = "zz-vide", type = "item" } })
  end), { exec_roles = { main = true, labo = true } })
  chk(#Ca.barrels(T3)["zz-flu"] == 1 and Ca.barrel_stock(T3, { ["zz-fut"] = 2 })["zz-flu"] == 80, "§2 un contenant vidé par deux recettes compte une fois")

  -- §3
  local function input(over)
    local inp = { data = D, state = { techs = { automation = true } }, stock = {}, flows = {}, machines = {}, drills = {}, labs = {},
      deposits = {}, open = {}, sinks = { { item = "plastic-bar", rate = 1 } }, workers = 30, idle = 10, can_grow = true, traits = {}, weights = {} }
    for k, v in pairs(over or {}) do inp[k] = v end
    return inp
  end
  local function sig(res)
    local t = {}
    for _, o in ipairs(res.orders) do t[#t + 1] = o.key .. ":" .. tostring(o.n) end
    return table.concat(t, ",")
  end
  local r_ref = Ca.decide(input(), {})
  local r_off = Ca.decide(input({ stock = { ["petroleum-gas-barrel"] = 100 } }), {})
  chk(sig(r_off) == sig(r_ref) and r_off.barils == nil, "§3 réglage éteint : la décision d'avant, même avec 100 barils au coffre")
  local r_on = Ca.decide(input({ stock = { ["petroleum-gas-barrel"] = 100 }, barils = true }), {})
  chk(r_on.barils and r_on.barils["petroleum-gas"] == 5000, "§3 allumé : 100 barils de gaz = 5 000 unités comptées")
  local r_on0 = Ca.decide(input({ barils = true }), {})
  chk(r_on0.barils == nil and sig(r_on0) == sig(r_ref), "§3 allumé sans baril : la décision d'avant, rien de compté")
  local r_on2 = Ca.decide(input({ stock = { ["petroleum-gas-barrel"] = 100 }, barils = true }), {})
  chk(sig(r_on2) == sig(r_on), "§3 déterminisme : même entrée, mêmes ordres")
end

suite(require("shared.ai3.capitalisation"), check)
say(string.format("suite principale : %d OK, %d ECHEC(S)", pass, fail))

---------------------------------------------------------------------------------------------------
-- §4 Mutants
---------------------------------------------------------------------------------------------------
local function read_all(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end
local SRC = read_all("shared/ai3/capitalisation.lua")
local function mutate(old, new)
  local i, j = SRC:find(old, 1, true)
  assert(i, "mutant : motif introuvable : " .. old)
  assert(not SRC:find(old, j + 1, true), "mutant : motif ambigu : " .. old)
  return SRC:sub(1, i - 1) .. new .. SRC:sub(j + 1)
end
local UNITS = "u = u + math.max(0, (stock or {})[c.item] or 0) * c.amount"
local SETON = "if input.barils then jstock, barils_added = Ca.barrel_stock(D, jstock) end"
local MUTANTS = {
  { "unités ignorées (un baril = 1 unité)", UNITS, "u = u + math.max(0, (stock or {})[c.item] or 0)" },
  { "remplissage non exigé (tout vidage est un contenant)",
    "if fl and it and fl.amount > 0 and fill[fl.name .. \"=\" .. fl.amount .. \"|\" .. it.name .. \"=\" .. it.amount .. \">\" .. b.name .. \"=\" .. b.amount]\n        and not seen[b.name] then",
    "if fl and it and fl.amount > 0 and not seen[b.name] then" },
  { "ajout écrase le fluide déjà au stock", "cp[fl] = (cp[fl] or 0) + u", "cp[fl] = u" },
  { "contenant compté deux fois", "        and not seen[b.name] then", "        then" },
  { "compte négatif accepté", UNITS, "u = u + ((stock or {})[c.item] or 0) * c.amount" },
  { "quantité du remplissage ignorée", "fill[fl.name .. \"=\" .. fl.amount .. \"|\" .. it.name .. \"=\" .. it.amount .. \">\" .. r.products[1].name",
    "fill[fl.name .. \"=\" .. 0 .. \"|\" .. it.name .. \"=\" .. it.amount .. \">\" .. r.products[1].name" },
  { "réglage ignoré (toujours compté)", SETON, "jstock, barils_added = Ca.barrel_stock(D, jstock)" },
  { "réglage inversé", SETON, "if not input.barils then jstock, barils_added = Ca.barrel_stock(D, jstock) end" },
  { "jamais compté", SETON, "" },
  { "copie absente (le stock du coffre est modifié)", "local cp = {}\n  for k, v in pairs(stock) do cp[k] = v end", "local cp = stock" },
}
local function killed_by(src)
  local chunk = load(src, "@capitalisation_mutant")
  if not chunk then return true end
  local saved = package.loaded["shared.ai3.capitalisation"]
  package.loaded["shared.ai3.capitalisation"] = nil
  local ok, CaM = pcall(chunk)
  local f0, p0, q0 = fail, pass, quiet
  quiet = true
  local ran = ok and pcall(suite, CaM, check)
  local dead = (not ran) or fail > f0
  fail, pass, quiet = f0, p0, q0
  package.loaded["shared.ai3.capitalisation"] = saved
  return dead
end
local survivors, killed = {}, 0
for _, m in ipairs(MUTANTS) do
  if killed_by(mutate(m[2], m[3])) then killed = killed + 1 else survivors[#survivors + 1] = m[1] end
end
check(#survivors == 0, "§4 mutants survivants : " .. table.concat(survivors, " ; "))
say(string.format("mutants refusés : %d sur %d", killed, #MUTANTS))
print(string.format("[FLUX-BARILS] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refusés sur %d)", pass, fail, killed, #MUTANTS))
os.exit(fail == 0 and 0 or 1)
