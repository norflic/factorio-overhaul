-- Arbre de décision Early / Mid / Late (directive du DC du 9/11) : règles pures de shared/team/decision_tree.lua et leurs mutants.
-- Lancer : lua5.2 tests/decision_tree_test.lua   (depuis la racine du mod)
package.path = "./?.lua;" .. package.path

local SRC_PATH = "shared/team/decision_tree.lua"

local function load_module(src)
  local chunk, err = load(src, "=decision_tree", "t")
  assert(chunk, err)
  return chunk()
end

local function read(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end

local SRC = read(SRC_PATH)
local passes, failures = 0, 0
local function check(c, msg)
  if c then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
end
local function section(t) print("== " .. t) end

-- étiquettes opaques : aucune règle ne lit un nom d'objet
local function opt(name, in_stock, craftable) return { name = name, in_stock = in_stock, craftable = craftable } end

local function suite(Dt)
  local before = failures
  local C = Dt.CFG
  -- 1. (a) phases
  do
    local full = { machines = C.machines, belts = C.belts, inserters = C.inserters }
    check(Dt.phase({ plant_ok = true, elec_drill = true, stock = full }) == "late", "1a : trois stocks aux seuils : late")
    check(Dt.phase({ plant_ok = false, elec_drill = false, stock = full }) == "late", "1a : late ne lit que le mall (stocks pleins)")
    check(Dt.phase({ plant_ok = true, elec_drill = true, stock = { machines = C.machines - 1, belts = C.belts, inserters = C.inserters } }) == "mid",
      "1b : une machine de moins : mid")
    check(Dt.phase({ plant_ok = true, elec_drill = true, stock = { machines = C.machines, belts = C.belts - 1, inserters = C.inserters } }) == "mid",
      "1b : un tapis de moins : mid")
    check(Dt.phase({ plant_ok = true, elec_drill = true, stock = { machines = C.machines, belts = C.belts, inserters = C.inserters - 1 } }) == "mid",
      "1b : un bras de moins : mid")
    check(Dt.phase({ plant_ok = true, elec_drill = true }) == "mid", "1c : centrale saine et foreuse electrique, mall non lu : mid")
    check(Dt.phase({ plant_ok = true, elec_drill = false }) == "early", "1d : centrale sans foreuse electrique : early")
    check(Dt.phase({ plant_ok = false, elec_drill = true }) == "early", "1d : foreuse electrique sans centrale : early")
    check(Dt.phase({ plant_ok = false, elec_drill = false }) == "early", "1d : rien : early")
    check(Dt.phase(nil) == "early", "1e : rien de lu : early (else)")
    check(Dt.phase({ plant_ok = 1, elec_drill = "oui" }) == "early", "1e : signaux non booleens : early (jamais devine)")
    check(Dt.phase({ stock = { machines = 0 / 0, belts = math.huge, inserters = 1e9 } }) == "early", "1e : stocks invalides : early")
    local seuils = { machines = 2, belts = 3, inserters = 1 }
    check(Dt.phase({ stock = { machines = 2, belts = 3, inserters = 1 }, seuils = seuils }) == "late", "1f : seuils de l'appelant")
    check(Dt.phase({ stock = { machines = 2, belts = 3, inserters = 1 } }) == "early", "1f : sans seuils de l'appelant : Dt.CFG")
    check(C.machines == 30 and C.belts == 200 and C.inserters == 100, "1g : nombres du DC (30 machines, 200 tapis, 100 bras)")
    local p, why = Dt.phase({ plant_ok = true, elec_drill = true })
    check(type(why) == "string" and #why > 0, "1h : la cause est ecrite (" .. tostring(why) .. ")")
    for _, s in ipairs({ nil, {}, { plant_ok = true }, { stock = full } }) do
      local ph = Dt.phase(s)
      check(ph == "early" or ph == "mid" or ph == "late", "1i : toujours une des trois valeurs")
    end
    -- déterminisme : mêmes entrées, même sortie
    check(Dt.phase({ plant_ok = true, elec_drill = true, stock = full }) == Dt.phase({ plant_ok = true, elec_drill = true, stock = full }),
      "1j : deterministe")
  end
  -- 2. (b) meilleur choix disponible
  do
    local A, B, Cc = opt("a", 0, true), opt("b", 3, true), opt("c", 10, true)
    local got, retro, why = Dt.best({ A, B, Cc })
    check(got == B and retro == true, "2a : la premiere au stock gagne (b), retrofit vrai (a existe) [" .. tostring(why) .. "]")
    got, retro = Dt.best({ opt("a", 1, false), opt("b", 50, true) })
    check(got.name == "a" and retro == false, "2a : la plus efficiente au stock : retenue, pas de retrofit")
    got, retro = Dt.best({ opt("a", 0, false), opt("b", 0, true), opt("c", 0, true) })
    check(got.name == "b" and retro == true, "2b : rien au stock : la premiere fabricable (b), retrofit vrai")
    got, retro = Dt.best({ opt("a", 0, true), opt("b", 0, false) })
    check(got.name == "a" and retro == false, "2b : la plus efficiente fabricable : pas de retrofit")
    got, retro = Dt.best({ opt("a", 0, false), opt("b", 0, false), opt("c", 0, false) })
    check(got ~= nil and got.name == "c" and retro == true, "2c : rien au stock ni fabricable : la derniere (repli), jamais nil, retrofit vrai")
    got, retro = Dt.best({ opt("seule", 0, false) })
    check(got.name == "seule" and retro == false, "2c : une seule option, indisponible : elle quand meme, pas de retrofit")
    -- anti-aberration : jamais une option moins efficiente qu'une option au stock
    got = Dt.best({ opt("a", 2, false), opt("b", 9, true), opt("c", 100, true) })
    check(got.name == "a", "2d : anti-aberration : a (2 au stock) devant b (9) et c (100)")
    got = Dt.best({ opt("a", 0, true), opt("b", 1, false), opt("c", 0, true) })
    check(got.name == "b", "2d : b dort au coffre : jamais c, et pas a (fabricable seulement : le stock passe devant)")
    -- stock par table
    got = Dt.best({ opt("a"), opt("b"), opt("c") }, { b = 4 })
    check(got.name == "b", "2e : stock lu dans la table { [nom] = n } quand in_stock manque")
    got = Dt.best({ opt("a", 0), opt("b") }, { a = 7, b = 1 })
    check(got.name == "b", "2e : in_stock de l'option prime sur la table")
    -- entrées douteuses
    got = Dt.best({ opt("a", 0 / 0, false), opt("b", -3, false), opt("c", "5", true) })
    check(got.name == "c", "2f : NaN, negatif, chaine : pas au stock ; c fabricable")
    got = Dt.best({ opt("a", 0, "oui"), opt("b", 0, false) })
    check(got.name == "b", "2f : craftable non booleen : pas fabricable (repli b)")
    local g0, r0 = Dt.best({})
    check(g0 == nil and r0 == false, "2g : liste vide : nil, retrofit faux (rien a poser)")
    local g1, r1 = Dt.best(nil)
    check(g1 == nil and r1 == false, "2g : liste absente : nil")
    -- déterminisme : deux appels, même option
    local l = { opt("a", 0, true), opt("b", 2, true), opt("c", 2, true) }
    check(Dt.best(l) == Dt.best(l) and Dt.best(l).name == "b", "2h : deterministe (b, premiere au stock)")
    check(#l == 3 and l[1].name == "a", "2h : la liste n'est pas modifiee")
  end
  -- 3. (c) thermique permise ?
  do
    check(Dt.thermal_allowed({ phase = "early", elec_drill_stock = 5, res_live = 0 }) == true, "3a : early avec 5 electriques au stock : permise (regle d'avant)")
    local ok, why = Dt.thermal_allowed({ phase = "mid", elec_drill_stock = 1, res_live = 0 })
    check(ok == false and why:find("1 foreuse(s) electrique(s) dorment au coffre : thermique interdite", 1, true) ~= nil and why:find("phase mid", 1, true) ~= nil,
      "3b : mid + 1 electrique au coffre : interdite, cause ecrite (" .. tostring(why) .. ")")
    check(Dt.thermal_allowed({ phase = "mid", elec_drill_stock = 0, res_live = 0 }) == true, "3c : mid + 0 au coffre : permise (res_live tranche ensuite)")
    check(Dt.thermal_allowed({ phase = "mid", elec_drill_stock = 0, res_live = 3 }) == true, "3c : mid + 0 au coffre, 3 sur la ressource : permise ici (E.thermal refuse sur res_live)")
    check(Dt.thermal_allowed({ phase = "late", elec_drill_stock = 12 }) == false, "3d : late + 12 : interdite")
    check(Dt.thermal_allowed({ phase = "late", elec_drill_stock = 0 }) == true, "3d : late + 0 : permise")
    -- la famine de la plaque cle (F434) ne rouvre pas la thermique quand des electriques dorment (F435 prend le relais)
    check(Dt.thermal_allowed({ phase = "mid", elec_drill_stock = 2, res_live = 0, famine = true }) == false, "3e : famine + 2 au coffre : toujours interdite")
    check(Dt.thermal_allowed({ phase = "early", elec_drill_stock = 2, famine = true }) == true, "3e : famine early : permise")
    check(Dt.thermal_allowed(nil) == true, "3f : rien de lu : permise (else)")
    check(Dt.thermal_allowed({ elec_drill_stock = 9 }) == true, "3f : phase absente (non lue) : early, permise")
    check(Dt.thermal_allowed({ phase = "mid", elec_drill_stock = 0 / 0 }) == true, "3f : stock NaN : 0, permise")
    check(Dt.thermal_allowed({ phase = "mid", elec_drill_stock = -2 }) == true, "3f : stock negatif : permise")
    check(Dt.thermal_allowed({ phase = "mid", elec_drill_stock = 0.5 }) == false, "3f : une fraction au coffre (> 0) : interdite")
    check(Dt.thermal_allowed({ phase = "autre", elec_drill_stock = 1 }) == false, "3g : phase inconnue n'est pas early : interdite (jamais permissif par erreur)")
    local a1 = Dt.thermal_allowed({ phase = "mid", elec_drill_stock = 3 })
    local a2 = Dt.thermal_allowed({ phase = "mid", elec_drill_stock = 3 })
    check(a1 == a2 and a1 == false, "3h : deterministe")
  end
  return failures - before
end

section("1 a 3. Regle pure")
local Dt = load_module(SRC)
check(suite(Dt) == 0, "la batterie passe sur la regle reelle")

section("4. Aucun nom d'objet ni de technologie dans la regle, aucun `pairs`, aucune API")
do
  local names = { "mining%-drill", "electric%-pole", "stone%-furnace", "steel%-furnace", "assembling%-machine", "transport%-belt", "\"inserter\"",
    "iron%-chest", "\"coal\"", "iron%-ore", "copper%-ore", "electronics", "automation" }
  for _, n in ipairs(names) do check(SRC:find(n) == nil, "4 : pas de « " .. n .. " » dans " .. SRC_PATH) end
  local code = SRC:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
  check(code:find("pairs%(") == nil or code:find("[^i]pairs%(") == nil, "4 : aucun `pairs` (ipairs seul)")
  check(code:find("game%.") == nil and code:find("global") == nil and code:find("os%.") == nil, "4 : aucune API du moteur, ni global, ni horloge")
  check(code:find("require") == nil, "4 : la regle ne depend de rien")
end

section("5. Mutants")
local function mutate(from, to)
  local i, j = SRC:find(from, 1, true)
  assert(i, "motif de mutant introuvable : " .. from)
  assert(not SRC:find(from, j + 1, true), "motif de mutant ambigu : " .. from)
  return SRC:sub(1, i - 1) .. to .. SRC:sub(j + 1)
end

local mutants = {
  { "best : anti-aberration retiree (la derniere au stock gagne)", "  for i = 1, n do\n    if held(options[i], stock) then pick, why = i, \"au stock\" break end\n  end",
    "  for i = n, 1, -1 do\n    if held(options[i], stock) then pick, why = i, \"au stock\" break end\n  end" },
  { "best : fabricable avant le stock", "  for i = 1, n do\n    if held(options[i], stock) then pick, why = i, \"au stock\" break end\n  end",
    "  for i = 1, n do\n    if options[i].craftable == true then pick, why = i, \"au stock\" break end\n  end" },
  { "best : fallback nil", "  if not pick then pick, why = n, \"repli : derniere option, posee tout de suite\" end",
    "  if not pick then return nil, false, \"rien\" end" },
  { "best : fallback la premiere (pas la basique)", "  if not pick then pick, why = n, \"repli : derniere option, posee tout de suite\" end",
    "  if not pick then pick, why = 1, \"repli\" end" },
  { "best : retrofit jamais", "  return options[pick], pick > 1, why", "  return options[pick], false, why" },
  { "best : retrofit toujours", "  return options[pick], pick > 1, why", "  return options[pick], true, why" },
  { "best : stock negatif compte", "  return (k or 0) > 0\n", "  return (k or 0) ~= 0\n" },
  { "best : fabricable non booleen", "      if options[i].craftable == true then", "      if options[i].craftable then" },
  { "phase : seuil late exclusif (machines)", "if machines >= (num(th.machines) or Dt.CFG.machines)", "if machines > (num(th.machines) or Dt.CFG.machines)" },
  { "phase : tapis ignores", " and belts >= (num(th.belts) or Dt.CFG.belts)\n", "\n" },
  { "phase : bras ignores", "\n    and inserters >= (num(th.inserters) or Dt.CFG.inserters) then", " then" },
  { "phase : mid sans centrale", "  if s.plant_ok == true and s.elec_drill == true then", "  if s.elec_drill == true then" },
  { "phase : mid sans foreuse electrique", "  if s.plant_ok == true and s.elec_drill == true then", "  if s.plant_ok == true then" },
  { "phase : signaux devines", "  if s.plant_ok == true and s.elec_drill == true then", "  if s.plant_ok and s.elec_drill then" },
  { "phase : seuils de l'appelant ignores", "  local th = s.seuils or cfg or Dt.CFG", "  local th = Dt.CFG" },
  { "thermal_allowed : phase ignoree", "  if phase ~= \"early\" and sleeping > 0 then", "  if sleeping > 0 then" },
  { "thermal_allowed : stock ignore", "  if phase ~= \"early\" and sleeping > 0 then", "  if phase ~= \"early\" then" },
  { "thermal_allowed : une seule ne compte pas", "  if phase ~= \"early\" and sleeping > 0 then", "  if phase ~= \"early\" and sleeping > 1 then" },
  { "thermal_allowed : mid seulement", "  if phase ~= \"early\" and sleeping > 0 then", "  if phase == \"mid\" and sleeping > 0 then" },
  { "thermal_allowed : phase absente = mid", "  local phase = i.phase or \"early\"", "  local phase = i.phase or \"mid\"" },
  { "thermal_allowed : famine rouvre", "  if phase ~= \"early\" and sleeping > 0 then", "  if phase ~= \"early\" and sleeping > 0 and not i.famine then" },
}

local survivors = 0
for _, mu in ipairs(mutants) do
  local ok, M2 = pcall(function() return load_module(mutate(mu[2], mu[3])) end)
  local killed
  if not ok then
    killed = true
  else
    local saved_pass, saved_fail = passes, failures
    local silent = print
    _G.print = function() end
    local okr, res = pcall(suite, M2)
    _G.print = silent
    killed = (not okr) or res > 0
    passes, failures = saved_pass, saved_fail -- les échecs d'un mutant ne comptent pas
  end
  check(killed, "mutant refuse : " .. mu[1])
  if not killed then survivors = survivors + 1 end
end
print(string.format("[DECISION-TREE] mutants %d refuses sur %d", #mutants - survivors, #mutants))

print(string.format("[DECISION-TREE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
