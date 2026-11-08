--[[
  Lot RESEAU-GRAPHE (ajout du DC, audit « n entrées, m sorties ») : test hors jeu de shared/team/blocs_audit.lua.
    §1 l'audit sur des gabarits fictifs (conforme, puis chaque défaut injecté est vu avec le bon code) ; §2 balayage des gabarits RÉELS
    (catalogue de shared/team/modules.lua, variantes d'ère) : écarts de structure, écarts de dimensionnement, liste imprimée ; §3 balayage des
    rangées générées pour chaque recette du livre réel (tests/fixtures/recipes_ia1e.lua, générateur `simple`) ; §4 hygiène du source ;
    §5 mutants : chaque règle de l'audit retirée est vue.
  Usage : lua5.2 tests/blocs_audit_test.lua   (depuis la racine du mod ; --liste imprime tous les écarts)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/blocs_audit.lua")
local M = require("shared.team.modules")
local FIX = require("tests.fixtures.recipes_ia1e")
local LISTE = false
for _, a in ipairs(arg or {}) do if a == "--liste" then LISTE = true end end

local function load_au(src)
  local fn, err = load(src, "=blocs_audit", "t")
  assert(fn, err)
  return fn()
end

local function codes_of(rep)
  local out = {}
  for _, g in ipairs(rep.gaps) do out[#out + 1] = g.code .. ":" .. tostring(g.item) end
  table.sort(out)
  return table.concat(out, " ")
end

-- gabarit fictif : deux machines en chaîne (a, b -> c ; c -> d), c reste à l'intérieur
local FAKE_R = {
  ra = { ingredients = { { name = "a", amount = 2 }, { name = "b", amount = 1 }, { name = "w", amount = 5, fluid = true } }, products = { { name = "c", amount = 1 } } },
  rb = { ingredients = { { name = "c", amount = 1 } }, products = { { name = "d", amount = 1 } } },
  rf = { ingredients = { { name = "a", amount = 1 } }, products = { { name = "e", amount = 1 } } },
}
local FAKE_SPEC = {
  asm = { kind = "assembler" }, fur = { kind = "furnace" }, brn = { kind = "furnace", burner_kw = 90 },
  drl = { kind = "drill" }, lab = { kind = "lab" }, ins = { kind = "inserter", burner_kw = 10 },
}
local CTX = { recipes = FAKE_R, spec_of = function(n) return FAKE_SPEC[n] end, fuel = "k", ores = { a = 1 }, ignore = { ["elec"] = true } }

local function fake(rate)
  rate = rate or 0.4
  local g = {
    key = "fictif", entities = { { name = "asm", recipe = "ra", rate = rate }, { name = "asm", recipe = "rb", rate = rate } },
    ports = {
      { ent = 1, io = "in", kind = "tapis", lanes = { "a", "b" } },
      { ent = 2, io = "out", kind = "tapis" },
    },
    inputs = { a = 2 * rate, b = rate }, nominal = { d = rate },
  }
  local rep = { rates = { rate, rate }, inputs = { a = 2 * rate, b = rate }, outputs = { d = rate },
    lanes = { [1] = { { "a" }, { "b" } }, [2] = { { "d" }, {} } }, errors = {} }
  return g, rep
end

local function suite(Au, quick, out)
  local ok_n, fail_n, failed = 0, 0, {}
  local function check(c, msg)
    if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 failed[#failed + 1] = msg if out then print("  ECHEC : " .. msg) end end
  end

  -- §1 gabarits fictifs
  do
    local g, rep = fake()
    local r = Au.audit(g, rep, CTX)
    check(#r.gaps == 0 and r.n_in_exp == 2 and r.n_in_real == 2 and r.n_out_exp == 1 and r.n_out_real == 1, "1.1 gabarit conforme : 2 entrées, 1 sortie, aucun écart (" .. codes_of(r) .. ")")
    check(r.in_exp[1] == "a" and r.in_exp[2] == "b" and r.out_exp[1] == "d", "1.2 le produit intermédiaire (c) n'est ni une entrée ni une sortie ; le fluide (w) n'est pas compté")
  end
  do
    local g, rep = fake()
    rep.inputs.b = nil
    local r = Au.audit(g, rep, CTX)
    check(codes_of(r):find("entree%-manquante:b") ~= nil, "1.3 un ingrédient absent des entrées de l'analyse : entree-manquante")
  end
  do
    local g, rep = fake()
    rep.inputs.z = 1
    local r = Au.audit(g, rep, CTX)
    check(codes_of(r):find("entree%-inutile:z") ~= nil, "1.4 une entrée qui n'est l'ingrédient de rien : entree-inutile")
  end
  do
    local g, rep = fake()
    rep.outputs.c = 0.4
    local r = Au.audit(g, rep, CTX)
    check(codes_of(r):find("sortie%-parasite:c") ~= nil, "1.5 un intermédiaire sorti du bloc : sortie-parasite")
    local g2, rep2 = fake()
    rep2.outputs.d = nil
    check(codes_of(Au.audit(g2, rep2, CTX)):find("sortie%-manquante:d") ~= nil, "1.6 produit net absent des sorties : sortie-manquante")
  end
  do
    local g, rep = fake()
    rep.inputs.a = 5
    local r = Au.audit(g, rep, CTX)
    check(codes_of(r):find("debit%-entree:a") ~= nil, "1.7 débit d'entrée de l'analyse différent du recalcul : debit-entree")
    local g2, rep2 = fake()
    rep2.outputs.d = 9
    check(codes_of(Au.audit(g2, rep2, CTX)):find("debit%-sortie:d") ~= nil, "1.8 débit de sortie différent : debit-sortie")
    local g3, rep3 = fake()
    g3.inputs.b = 7
    check(codes_of(Au.audit(g3, rep3, CTX)):find("declare%-entree:b") ~= nil, "1.9 entrée déclarée au gabarit fausse : declare-entree")
    local g4, rep4 = fake()
    g4.nominal.d = 7
    check(codes_of(Au.audit(g4, rep4, CTX)):find("declare%-sortie:d") ~= nil, "1.10 sortie déclarée fausse : declare-sortie")
  end
  do
    local g, rep = fake()
    rep.lanes[1] = { { "a", "b" }, { "b" } }
    check(codes_of(Au.audit(g, rep, CTX)):find("voie%-melee:a%+b") ~= nil, "1.11 deux objets sur la même voie : voie-melee")
    local g2, rep2 = fake()
    g2.ports[#g2.ports + 1] = { ent = 3, io = "in", kind = "tapis", lanes = { "z", "z" } }
    rep2.lanes[3] = { { "z" }, { "z" } }
    check(codes_of(Au.audit(g2, rep2, CTX)):find("port%-entree%-inutile:z") ~= nil, "1.12 un port qui amène un objet inutile : port-entree-inutile")
    local g3, rep3 = fake()
    g3.ports[#g3.ports + 1] = { ent = 3, io = "out", kind = "tapis" }
    rep3.lanes[3] = { { "c" }, {} }
    check(codes_of(Au.audit(g3, rep3, CTX)):find("port%-sortie%-parasite:c") ~= nil, "1.13 un port qui sort un intermédiaire : port-sortie-parasite")
    local g4, rep4 = fake()
    g4.ports = { g4.ports[2] }
    rep4.lanes = { [1] = { { "d" }, {} } }
    check(codes_of(Au.audit(g4, rep4, CTX)):find("entree%-sans%-port:a") ~= nil and codes_of(Au.audit(g4, rep4, CTX)):find("entree%-sans%-port:b") ~= nil, "1.14 sans port d'entrée : entree-sans-port pour chaque ingrédient")
    local g5, rep5 = fake()
    g5.ports = { g5.ports[1] }
    check(codes_of(Au.audit(g5, rep5, CTX)):find("sortie%-sans%-port:d") ~= nil, "1.15 sans port de sortie : sortie-sans-port")
  end
  do -- dimensionnement
    local g, rep = fake(2)
    local NOORE = { recipes = FAKE_R, spec_of = CTX.spec_of, fuel = "k", ores = {}, ignore = {} }
    local r = Au.audit(g, rep, NOORE)
    local c = codes_of(r)
    check(c:find("quai%-sous%-dimensionne:a") ~= nil and c:find("quai%-sous%-dimensionne:b") ~= nil, "1.16 débit d'entrée au-delà d'un bras par objet (0,83/s) : quai-sous-dimensionne (" .. c .. ")")
    check(c:find("tapis%-entree") == nil, "1.17 voie de 7,5/s : l'arrivée par tapis suffit pour 4/s")
    local g2, rep2 = fake(5)
    check(codes_of(Au.audit(g2, rep2, CTX)):find("tapis%-entree%-sous%-dimensionne:a") ~= nil, "1.18 10/s sur une voie de 7,5/s : tapis-entree-sous-dimensionne")
    local g3, rep3 = fake(8)
    check(codes_of(Au.audit(g3, rep3, CTX)):find("tapis%-sortie%-sous%-dimensionne:d") ~= nil, "1.19 8/s sur une voie de sortie de 7,5/s : tapis-sortie-sous-dimensionne")
    local g4, rep4 = fake(1.5)
    g4.ports[1] = { ent = 1, io = "in", kind = "tapis", lanes = { "a", "b" } }
    g4.ports[#g4.ports + 1] = { ent = 4, io = "in", kind = "tapis", lanes = { "a", "b" } }
    rep4.lanes[4] = { { "a" }, { "b" } }
    local c4 = codes_of(Au.audit(g4, rep4, NOORE))
    check(c4:find("quai%-sous%-dimensionne:b") == nil and c4:find("quai%-sous%-dimensionne:a") ~= nil, "1.20 deux ports : deux bras par objet (1,66/s) : b (1,5/s) tient, a (3/s) non (" .. c4 .. ")")
    check(codes_of(Au.audit(g, rep, CTX)):find("quai%-sous%-dimensionne:a") == nil, "1.20b un minerai de plus de 1/s n'est pas jugé sur son quai")
    local ctx_ore = { recipes = FAKE_R, spec_of = CTX.spec_of, fuel = "k", ores = { a = 1, b = 1 }, ignore = {} }
    local g5, rep5 = fake(2)
    check(codes_of(Au.audit(g5, rep5, ctx_ore)):find("quai%-sous%-dimensionne") == nil, "1.21 un minerai au-delà de 1/s est servi par foreuses et tapis : pas de quai à juger")
  end
  do -- combustible, foreuse, laboratoire, fluide, électricité
    local g = { key = "four", entities = { { name = "brn", recipe = "rf", rate = 0.5 } }, ports = { { ent = 1, io = "in", kind = "tapis", lanes = { "a", "a" } }, { ent = 2, io = "out", kind = "tapis" } },
      inputs = { a = 0.5, k = 0.1 }, nominal = { e = 0.5 }, fuel_ports = { 1 } }
    local rep = { rates = { 0.5 }, inputs = { a = 0.5, k = 0.1 }, outputs = { e = 0.5 }, lanes = { [1] = { { "a" }, { "a" } }, [2] = { { "e" }, {} } }, errors = {} }
    local r = Au.audit(g, rep, CTX)
    check(r.n_in_exp == 2 and r.n_in_real == 2 and #Au.structural(r) == 0, "1.22 une machine à combustible : le combustible compte comme entrée (ravitaillé par les porteurs : pas de port exigé)")
    local g2 = { key = "mine", resource = "a", entities = { { name = "drl", rate = 1 } }, ports = { { ent = 1, io = "out", kind = "tapis" } }, inputs = {}, nominal = { a = 1 } }
    local rep2 = { rates = { 1 }, inputs = {}, outputs = { a = 1 }, lanes = { [1] = { { "a" }, {} } }, errors = {} }
    local r2 = Au.audit(g2, rep2, CTX)
    check(r2.n_in_exp == 0 and r2.n_out_exp == 1 and #r2.gaps == 0, "1.23 des foreuses : aucune entrée, une sortie")
    local g3 = { key = "labo", labs = { packs = { "a", "b" } }, entities = { { name = "lab", rate = 0.1 } }, ports = { { ent = 1, io = "in", kind = "tapis", lanes = { "a", "b" } } }, inputs = { a = 0.1, b = 0.1 }, nominal = {} }
    local rep3 = { rates = { 0.1 }, inputs = { a = 0.1, b = 0.1 }, outputs = {}, lanes = { [1] = { { "a" }, { "b" } } }, errors = {} }
    local r3 = Au.audit(g3, rep3, CTX)
    check(r3.n_in_exp == 2 and r3.n_out_exp == 0 and #r3.gaps == 0, "1.24 des laboratoires : deux paquets en entrée, aucune sortie")
    local g4, rep4 = fake()
    rep4.outputs["elec"] = 5
    check(#Au.audit(g4, rep4, CTX).gaps == 0, "1.25 la sortie électrique n'est pas un objet")
  end

  -- §2 gabarits réels
  if not quick then
    local ctx = { recipes = M.RECIPES, spec_of = M.spec, fuel = "coal", ores = M.ORES, ignore = { ["electricity-kw"] = true } }
    local list = M.catalogue()
    for _, e in ipairs(M.era_variants()) do list[#list + 1] = e.g end
    local struct, dim, with_dim = 0, 0, 0
    local lines = {}
    for _, g in ipairs(list) do
      local rep = M.analyze(g)
      local r = Au.audit(g, rep, ctx)
      struct = struct + #Au.structural(r)
      local d = #r.gaps - #Au.structural(r)
      dim = dim + d
      if d > 0 then with_dim = with_dim + 1 end
      if #r.gaps > 0 then
        local items = {}
        for _, x in ipairs(r.gaps) do items[#items + 1] = string.format("%s %s (attendu %.2f/s, réel %.2f/s)", x.code, x.item, x.expected, x.real) end
        lines[#lines + 1] = string.format("%-26s entrées %d/%d sorties %d/%d : %s", g.key, r.n_in_exp, r.n_in_real, r.n_out_exp, r.n_out_real, table.concat(items, " ; "))
      end
      check(#rep.errors == 0, "2.0 " .. g.key .. " : l'analyse de shared/team/modules.lua ne trouve aucune erreur")
      check(r.n_in_exp == r.n_in_real and r.n_out_exp == r.n_out_real, "2.1 " .. g.key .. " : n entrées et m sorties attendues = réelles (" .. r.n_in_exp .. "/" .. r.n_in_real .. ", " .. r.n_out_exp .. "/" .. r.n_out_real .. ")")
    end
    check(#list >= 50, "2.2 le balayage couvre le catalogue et ses variantes d'ère (" .. #list .. " gabarits)")
    check(struct == 0, "2.3 aucun écart de structure (entrées, sorties, ports, voies, déclaré) sur " .. #list .. " gabarits (" .. struct .. ")")
    check(with_dim >= 1, "2.4 écart connu : le quai d'entrée n'a qu'un bras de base (0,83/s) par objet et par port (" .. with_dim .. " gabarits, " .. dim .. " écarts)")
    print(string.format("[AUDIT] gabarits réels : %d audités, %d écart(s) de structure, %d gabarit(s) en écart de dimensionnement (%d écarts)", #list, struct, with_dim, dim))
    if LISTE then for _, l in ipairs(lines) do print("  [AUDIT] " .. l) end end
    COUNTS = { total = #list, struct = struct, with_dim = with_dim, dim = dim }
  end

  -- §3 rangées générées pour chaque recette du livre réel
  if not quick then
    local ctx = { recipes = M.RECIPES, spec_of = M.spec, fuel = "coal", ores = M.ORES, ignore = { ["electricity-kw"] = true } }
    local names = {}
    for k in next, FIX do names[#names + 1] = k end
    table.sort(names)
    local built, refused, struct, with_dim, errs = 0, 0, 0, 0, 0
    for _, n in ipairs(names) do
      local r = FIX[n]
      r.name = n
      local ok, g = pcall(M.GEN.simple, r, 1, nil)
      if ok and g then
        built = built + 1
        local rep = M.analyze(g)
        if #rep.errors > 0 then errs = errs + 1 else
          local a = Au.audit(g, rep, ctx)
          struct = struct + #Au.structural(a)
          if #a.gaps > #Au.structural(a) then with_dim = with_dim + 1 end
          if #Au.structural(a) > 0 and out then print("  structure : " .. n .. " " .. codes_of(a)) end
        end
      else
        refused = refused + 1
      end
    end
    check(built >= 150 and struct == 0, "3.1 rangées d'une recette (générateur simple, une machine) : aucun écart de structure sur " .. built .. " gabarits construits (" .. struct .. ")")
    print(string.format("[AUDIT] rangées du livre de recettes : %d recettes, %d rangées construites (%d refusées par le générateur : plus de 2 ingrédients solides, fluide, catégorie), %d erreur(s) d'analyse, %d écart(s) de structure, %d en écart de dimensionnement",
      #names, built, refused, errs, struct, with_dim))
    COUNTS2 = { built = built, with_dim = with_dim, struct = struct }
  end

  return ok_n, fail_n, failed
end

local Au = load_au(SRC)
local ok_n, fail_n = suite(Au, false, true)
local function check(c, msg)
  if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end
end

-- §4 hygiène
do
  local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:find("iron%-") and not code:find("copper%-") and not code:find("coal") and not code:find("transport%-belt") and not code:find("assembling")
    and not code:find("%-plate") and not code:find("stone"), "4.1 aucun nom d'objet (le combustible et les minerais viennent du contexte)")
  check(not code:find("[^i%.]pairs%("), "4.2 aucun pairs")
  check(not code:find("math%.random") and not code:find("os%.time") and not code:find("os%.clock") and not code:find("math%.sin") and not code:find("math%.cos"),
    "4.3 ni hasard, ni horloge, ni trigonométrie")
  check(not code:find("game%.") and not code:find("global") and not code:find("script%.") and not code:find("require"), "4.4 aucune API du jeu, aucun require")
end

-- §5 mutants
local MUTANTS = {
  { "entrées attendues : intermédiaire compté", "if net < -Au.TOL and not fluid[it] and not ignore[it] then exp_in[it] = -net end", "if cons[it] > Au.TOL and not fluid[it] and not ignore[it] then exp_in[it] = cons[it] end" },
  { "sorties attendues : brutes", "if net > Au.TOL and not fluid[it] and not ignore[it] then exp_out[it] = net end", "if prod[it] > Au.TOL and not fluid[it] and not ignore[it] then exp_out[it] = prod[it] end" },
  { "entrée manquante non vue", "if real_in[it] == nil then gap(\"entree-manquante\"", "if false then gap(\"entree-manquante\"" },
  { "entrée inutile non vue", "if exp_in[it] == nil then gap(\"entree-inutile\"", "if false then gap(\"entree-inutile\"" },
  { "sortie manquante non vue", "if real_out[it] == nil then gap(\"sortie-manquante\"", "if false then gap(\"sortie-manquante\"" },
  { "sortie parasite non vue", "if exp_out[it] == nil then gap(\"sortie-parasite\"", "if false then gap(\"sortie-parasite\"" },
  { "débit d'entrée non comparé", "if real_in[it] ~= nil and exp_in[it] ~= true and rel_gap(exp_in[it], real_in[it]) then", "if false then" },
  { "débit de sortie non comparé", "if real_out[it] ~= nil and rel_gap(exp_out[it], real_out[it]) then", "if false then" },
  { "déclaré non comparé (entrée)", "if not fluid[it] and not ignore[it] and (real_in[it] == nil or rel_gap(g.inputs[it], real_in[it])) then", "if false then" },
  { "déclaré non comparé (sortie)", "if not fluid[it] and not ignore[it] and (real_out[it] == nil or rel_gap(g.nominal[it], real_out[it])) then", "if false then" },
  { "voie mêlée non vue", "if #distinct > 1 then", "if #distinct > 99 then" },
  { "port d'entrée inutile non vu", "if not fluid[it] and exp_in[it] == nil and not ignore[it] then gap(\"port-entree-inutile\"", "if false then gap(\"port-entree-inutile\"" },
  { "port de sortie parasite non vu", "if not fluid[it] and exp_out[it] == nil and not ignore[it] then gap(\"port-sortie-parasite\"", "if false then gap(\"port-sortie-parasite\"" },
  { "entrée sans port non vue", "if not in_ports[it] and not fed_other then gap(", "if false then gap(" },
  { "sortie sans port non vue", "if not out_ports[it] then gap(\"sortie-sans-port\"", "if false then gap(\"sortie-sans-port\"" },
  { "quai : un seul bras pour tous les ports", "local quai_cap = in_ports[it] * Au.QUAI_ARM_RATE", "local quai_cap = 1e9" },
  { "quai : nombre de ports ignoré", "local quai_cap = in_ports[it] * Au.QUAI_ARM_RATE", "local quai_cap = Au.QUAI_ARM_RATE" },
  { "minerai servi par tapis non reconnu", "local belt_fed = ctx.ores and ctx.ores[it] and it ~= fuel and rate >= Au.ORE_BELT_FLOW", "local belt_fed = false" },
  { "capacité des voies d'entrée ignorée", "if rate > by_lane + Au.TOL then", "if false then" },
  { "capacité des voies de sortie ignorée", "if cap and cap < math.huge and exp_out[it] > cap + Au.TOL then", "if false then" },
  { "combustible non attendu", "if burns and fuel and not exp_in[fuel]", "if false and burns and fuel and not exp_in[fuel]" },
  { "porteurs de combustible ignorés", "local fed_other = (it == fuel and fuel_by_porters) or (g.resource == it)", "local fed_other = false" },
  { "foreuse sans production", "prod[g.resource] = (prod[g.resource] or 0) + rate", "prod[g.resource] = 0" },
  { "laboratoire sans consommation", "for _, pk in ipairs(g.labs.packs or {}) do cons[pk] = (cons[pk] or 0) + rate end", "" },
  { "électricité comptée comme sortie", "for _, it in ipairs(sorted_set(rep.outputs or {})) do if not fluid[it] and not ignore[it] then", "for _, it in ipairs(sorted_set(rep.outputs or {})) do if not fluid[it] then" },
}
local refused = 0
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    check(false, "5 motif de mutant introuvable : " .. m[1])
  else
    local okl, Mu = pcall(load_au, SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    if not okl then
      refused = refused + 1
    else
      local oks, okn, failn = pcall(suite, Mu, true, false)
      if not oks or failn > 0 then refused = refused + 1 else check(false, "5 mutant SURVIVANT : " .. m[1]) end
    end
  end
end
print(string.format("[AUDIT] mutants refusés : %d sur %d", refused, #MUTANTS))
check(refused == #MUTANTS, "5.1 tous les mutants sont refusés")

print(string.format("[AUDIT] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
