--[[
  Lot RB-FLUIDE (1/11) : une recette à fluide reste OBTENABLE quand la force sait produire le fluide (shared/ai3/capitalisation.lua,
  Ca.obtainable). Avant le lot, `not r.fluid` écartait toute recette qui demande ou rend un fluide : le pack d'une recette dont l'ingrédient
  vient du gaz d'un raffinage était « non obtenable » même avec le raffinage posé (partie de 4 h du 1/11, lot C4).
  Données INVENTÉES (aucun nom du jeu : la règle est soumise à l'anti-échelle de tests/iag_test.lua) :
    brut     minerai fluide (catégorie « pomper », extracteur `pompeur`), eau = fluide d'une pompe de rive
    raffiner brut -> gaz (catégorie « raffiner », machine `raffineur`)
    chimie   gaz + eau + `fer` -> `soufre` (catégorie « chimie », machine `chimiste`)
    assembler soufre + `fer` -> `pack` (catégorie « assembler », machine `assembleur`)
  §1 la chaîne complète est obtenable ; §2 chaque maillon manquant la ferme (catégorie absente, extracteur non exécutant, ressource inconnue,
  pompe absente ou non exécutante, recette fermée, ingrédient solide absent) ; §3 le stock suffit ; §4 un cycle ne boucle pas ; §5 un objet
  sans fluide ne change pas ; §6 déterminisme (relevé renversé) ; §7 mutants : chaque règle faussée est vue.
  Usage : lua5.2 tests/ai3_fluide_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local SRC = read("shared/ai3/capitalisation.lua")

local function load_ca(src)
  local f, e = load(src, "=capitalisation", "t")
  if not f then return nil, e end
  local ok, M = pcall(f)
  if not ok then return nil, M end
  return M
end

local function ing(kind, name, n) return { type = kind, name = name, amount = n } end

--- Relevé inventé. `o` : changements (exec = { [entité] = faux }, sans = { [entité] = vrai } retire l'entité, fermees = { [recette] = vrai }).
local function dump(o)
  o = o or {}
  local ents = {
    { name = "main", type = "character", crafting_categories = { "hand" }, resource_categories = { "hand-mine" } },
    { name = "pompeur", type = "mining-drill", item = "pompeur", resource_categories = { "pomper" }, speed = 1, energy = "electric" },
    { name = "rive", type = "offshore-pump", item = "rive", fluid = "eau", energy = "none" },
    { name = "raffineur", type = "assembling-machine", item = "raffineur", crafting_categories = { "raffiner" }, speed = 1, energy = "electric" },
    { name = "chimiste", type = "assembling-machine", item = "chimiste", crafting_categories = { "chimie" }, speed = 1, energy = "electric" },
    { name = "assembleur", type = "assembling-machine", item = "assembleur", crafting_categories = { "assembler" }, speed = 1, energy = "electric" },
  }
  local keep = {}
  for _, e in ipairs(ents) do if not (o.sans or {})[e.name] then keep[#keep + 1] = e end end
  local function rec(name, cat, ins, outs)
    return { category = cat, energy = 1, ingredients = ins, products = outs, enabled = not (o.fermees or {})[name], hidden = false }
  end
  local recipes = {
    raffiner = rec("raffiner", "raffiner", { ing("fluid", "brut", 10) }, { ing("fluid", "gaz", 10) }),
    chimie = rec("chimie", "chimie", { ing("fluid", "gaz", 10), ing("fluid", "eau", 10), ing("item", "fer", 1) }, { ing("item", "soufre", 2) }),
    pack = rec("pack", "assembler", { ing("item", "soufre", 1), ing("item", "fer", 1) }, { ing("item", "pack", 1) }),
    fer = rec("fer", "hand", { ing("item", "minerai", 1) }, { ing("item", "fer", 1) }),
  }
  -- un cycle : a <-> b (aucune sortie)
  recipes.cycle_a = rec("cycle_a", "assembler", { ing("item", "cycle_b", 1) }, { ing("item", "cycle_a", 1) })
  recipes.cycle_b = rec("cycle_b", "assembler", { ing("item", "cycle_a", 1) }, { ing("item", "cycle_b", 1) })
  -- une recette fermée est débloquée par une technologie (pas faite : ctx.techs est vide)
  local techs = {}
  for name in next, o.fermees or {} do
    techs["t-" .. name] = { count = 1, time = 1, ingredients = {}, prerequisites = {}, unlocks = { name }, effects = {}, enabled = true }
  end
  return { recipes = recipes, techs = techs, entities = keep,
    resources = { { entity = "puits", category = "pomper", products = { ing("fluid", "brut", 1) }, mining_time = 1 },
      { entity = "mine", category = "hand-mine", products = { ing("item", "minerai", 1) }, mining_time = 1 } },
    items = { pack = { type = "item" }, fer = { type = "item" }, soufre = { type = "item" }, minerai = { type = "item" } } }
end

local ALL = { "hand", "raffiner", "chimie", "assembler" }

--- Contexte minimal de Ca.obtainable : relevé, catégories présentes, ressources connues, stock, techniques faites.
local function scene(Ca, o, cats, known, stock)
  o = o or {}
  local D = Ca.data(dump(o), { exec = o.exec, exec_roles = { main = true } })
  local present = {}
  for _, c in ipairs(cats or ALL) do present[c] = true end
  return { D = D, input = {}, obt = {}, stock = stock or {}, techs = {}, known = known, cats_present = present }
end

local KNOWN = { brut = true, eau = true, minerai = true }
local EXEC = { pompeur = true, rive = true, raffineur = true, chimiste = true, assembleur = true }

local function suite(Ca)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end
  local function obt(o, cats, known, stock, item)
    local s = scene(Ca, o, cats, known, stock)
    return Ca.obtainable(s, item or "pack")
  end

  -- §1 La chaîne complète.
  check(obt({ exec = EXEC }, nil, KNOWN) == true, "§1 pack obtenable : pétrole connu et extrait, eau pompée, raffinage et chimie posés")
  check(obt({ exec = EXEC }, nil, KNOWN, nil, "soufre") == true, "§1 soufre (recette à fluide) obtenable")
  check(obt({ exec = EXEC }, nil, KNOWN, nil, "gaz") == true, "§1 un fluide produit par une recette est obtenable")
  check(obt({ exec = EXEC }, nil, KNOWN, nil, "brut") == true, "§1 une ressource fluide connue et extractible est obtenable")
  check(obt({ exec = EXEC }, nil, KNOWN, nil, "eau") == true, "§1 le fluide d'une pompe exécutable et connu est obtenable")

  -- §2 Chaque maillon manquant ferme la chaîne.
  check(obt({ exec = EXEC }, { "hand", "chimie", "assembler" }, KNOWN) == false, "§2 sans raffinage posé : pas de gaz, pas de pack")
  check(obt({ exec = EXEC }, { "hand", "raffiner", "assembler" }, KNOWN) == false, "§2 sans chimie posée : pas de soufre, pas de pack")
  check(obt({ exec = EXEC }, { "hand", "raffiner", "chimie" }, KNOWN) == false, "§2 sans assembleur posé : pas de pack")
  local no_pump = {}
  for k, v in pairs(EXEC) do no_pump[k] = v end
  no_pump.pompeur = nil
  check(obt({ exec = no_pump }, nil, KNOWN) == false, "§2 extracteur non exécutant : le pétrole ne vient pas")
  local no_rive = {}
  for k, v in pairs(EXEC) do no_rive[k] = v end
  no_rive.rive = nil
  check(obt({ exec = no_rive }, nil, KNOWN) == false, "§2 pompe de rive non exécutante : pas d'eau")
  check(obt({ exec = EXEC, sans = { rive = true } }, nil, KNOWN) == false, "§2 aucune pompe : pas d'eau")
  check(obt({ exec = EXEC }, nil, { eau = true, minerai = true }) == false, "§2 pétrole inconnu : pas de gaz")
  check(obt({ exec = EXEC }, nil, { brut = true, minerai = true }) == false, "§2 eau inconnue (aucune rive à portée) : pas de soufre")
  check(obt({ exec = EXEC }, nil, { brut = true, eau = true }) == false, "§2 minerai inconnu : pas de fer, pas de pack")
  check(obt({ exec = EXEC, fermees = { raffiner = true } }, nil, KNOWN) == false, "§2 recette de raffinage fermée (technologie pas faite)")
  check(obt({ exec = EXEC, fermees = { chimie = true } }, nil, KNOWN) == false, "§2 recette de chimie fermée")
  check(obt({ exec = EXEC, fermees = { pack = true } }, nil, KNOWN) == false, "§2 recette du pack fermée")

  -- §3 Le stock suffit ; un fluide stocké n'a pas besoin de machine.
  check(obt({ exec = EXEC }, { "hand", "assembler" }, KNOWN, { soufre = 5 }) == true, "§3 du soufre au coffre : le pack se fait sans chimie")
  check(obt({ exec = EXEC, sans = { rive = true } }, nil, KNOWN, { eau = 1 }, "soufre") == true, "§3 un fluide au stock compte")

  -- §4 Un cycle de recettes ne boucle pas.
  check(obt({ exec = EXEC }, nil, KNOWN, nil, "cycle_a") == false, "§4 un cycle n'est pas obtenable et ne boucle pas")

  -- §5 Un objet sans fluide ne change pas.
  check(obt({ exec = EXEC }, { "hand" }, KNOWN, nil, "fer") == true, "§5 le fer (recette à la main) reste obtenable")
  check(obt({ exec = EXEC }, { "assembler" }, { minerai = true }, nil, "fer") == false, "§5 sans la main ni machine du fer : non obtenable (inchangé)")

  -- §6 Déterminisme : relevé renversé.
  local d = dump({})
  local rev = {}
  for i = #d.entities, 1, -1 do rev[#rev + 1] = d.entities[i] end
  d.entities = rev
  local D2 = Ca.data(d, { exec = EXEC, exec_roles = { main = true } })
  local present = {}
  for _, c in ipairs(ALL) do present[c] = true end
  check(Ca.obtainable({ D = D2, input = {}, obt = {}, stock = {}, techs = {}, known = KNOWN, cats_present = present }, "pack") == true,
    "§6 relevé renversé : même réponse")
  return pass, fail, msgs
end

local Ca = assert(load_ca(SRC))
local pass, fail, msgs = suite(Ca)
local function check_src(c, m)
  if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
end

-- Aucun nom du jeu dans la règle ajoutée : les mots de ce test (inventés) n'y sont pas non plus.
local added = SRC:match("function Ca%.obtainable.-\nend\n") or ""
check_src(not added:find("%f[%w_]fluid%-?[%w_]*%f[^%w_]") or added:find("r%.fluid") == nil, "§7 la règle n'écarte plus une recette pour son fluide (plus de `r.fluid`)")
for _, w in ipairs({ "petroleum", "crude", "water", "sulfur", "plastic", "chemical", "pumpjack", "refinery" }) do
  check_src(not added:lower():find(w), "§7 nom du jeu dans Ca.obtainable : " .. w)
end

-- §8 SOUPAPE (lot 6 FLUIDES-SOUPAPE, Fl.valve et Fl.valve_recipe, shared/ai3/fluides.lua) : règle pure, relevé inventé.
local function valve_suite(M)
  local vp, vf, vmsg = 0, 0, {}
  local function vok(c, m) if c then vp = vp + 1 else vf = vf + 1 vmsg[#vmsg + 1] = m end end
  local function run(st, rem, deb, sur) return M.valve(st, "fz", rem, deb, sur) end
  -- C6.1 : cuve à 95 % sans débouché : ouverte à la K-ième mesure, pas avant
  local st, opened_at = M.valve_new(), nil
  for k = 1, M.VALVE_K + 2 do
    if run(st, 0.95, 0, "rec-surplus").open and not opened_at then opened_at = k end
  end
  vok(opened_at == M.VALVE_K, "C6.1 cuve à 95 % sans débouché : ouverte à la mesure K (" .. tostring(opened_at) .. ")")
  -- C6.1 : à 95 % avec un débouché ouvert : rien
  st = M.valve_new()
  local any = false
  for _ = 1, 3 * M.VALVE_K do if run(st, 0.95, 1, "rec-surplus").open then any = true end end
  vok(not any, "C6.1 cuve à 95 % avec débouché ouvert : rien")
  -- seuil strict : 90 % exact et 50 % n'ouvrent jamais
  st = M.valve_new(); any = false
  for _ = 1, 3 * M.VALVE_K do
    if run(st, 0.9, 0, "rec").open or run(st, 0.5, 0, "rec").open then any = true end
  end
  vok(not any, "seuil strict : 90 % exact et 50 % n'ouvrent pas")
  -- un débouché ouvert remet le compteur à zéro
  st = M.valve_new()
  for _ = 1, M.VALVE_K - 1 do run(st, 0.95, 0, "rec") end
  run(st, 0.95, 1, "rec")
  any = false
  for _ = 1, M.VALVE_K - 1 do if run(st, 0.95, 0, "rec").open then any = true end end
  vok(not any, "débouché ouvert : compteur remis à zéro")
  -- une mesure sous le seuil remet aussi le compteur à zéro
  st = M.valve_new()
  for _ = 1, M.VALVE_K - 1 do run(st, 0.95, 0, "rec") end
  run(st, 0.5, 0, "rec")
  any = false
  for _ = 1, M.VALVE_K - 1 do if run(st, 0.95, 0, "rec").open then any = true end end
  vok(not any, "mesure sous le seuil : compteur remis à zéro")
  -- sans recette de surplus : jamais ouverte, refus écrit
  st = M.valve_new()
  local r
  for _ = 1, M.VALVE_K do r = run(st, 0.95, 0, nil) end
  vok(r.open == false and r.why:find("surplus", 1, true) ~= nil, "pas de recette de surplus : refus écrit")
  -- débouché inconnu (nil) : pas compté comme fermé
  st = M.valve_new(); any = false
  for _ = 1, M.VALVE_K + 1 do if M.valve(st, "fz", 0.95, nil, "rec").open then any = true end end
  vok(not any, "débouché inconnu : pas compté comme fermé")
  -- mesure absente : refus
  vok(M.valve(M.valve_new(), "fz", nil, 0, "rec").open == false, "mesure absente : refus")
  -- recette de surplus lue dans le relevé : visible, un seul fluide en entrée, produits solides, triée
  local rel = { recipes = {
    ["aa-cache"] = { hidden = true, ingredients = { { type = "fluid", name = "fz", amount = 1 } }, products = { { type = "item", name = "sol", amount = 1 } } },
    ["bb-deux"] = { hidden = false, ingredients = { { type = "fluid", name = "fz", amount = 1 }, { type = "fluid", name = "eau2", amount = 1 } }, products = { { type = "item", name = "sol", amount = 1 } } },
    ["cc-fluide"] = { hidden = false, ingredients = { { type = "fluid", name = "fz", amount = 1 } }, products = { { type = "fluid", name = "gaz", amount = 1 } } },
    ["dd-autre"] = { hidden = false, ingredients = { { type = "fluid", name = "autre", amount = 1 } }, products = { { type = "item", name = "sol", amount = 1 } } },
    ["zz-solide"] = { hidden = false, ingredients = { { type = "fluid", name = "fz", amount = 1 } }, products = { { type = "item", name = "sol", amount = 1 } } },
  } }
  vok(M.valve_recipe(rel, "fz") == "zz-solide", "recette de surplus : visible, un seul fluide, produits solides (la première retenue)")
  vok(M.valve_recipe({ recipes = {} }, "fz") == nil, "aucune recette : nil")
  -- recette non débloquée (enabled = false) : jamais choisie ; seule, elle donne un refus écrit
  local rel2 = { recipes = {
    ["aa-verrou"] = { hidden = false, enabled = false, ingredients = { { type = "fluid", name = "fz", amount = 1 } }, products = { { type = "item", name = "sol", amount = 1 } } },
    ["bb-ouverte"] = { hidden = false, ingredients = { { type = "fluid", name = "fz", amount = 1 } }, products = { { type = "item", name = "sol", amount = 1 } } },
  } }
  vok(M.valve_recipe(rel2, "fz") == "bb-ouverte", "recette non débloquée écartée : la débloquée est choisie")
  local rel3 = { recipes = { ["aa-verrou"] = rel2.recipes["aa-verrou"] } }
  vok(M.valve_recipe(rel3, "fz") == nil, "seule recette non débloquée : aucune")
  local rv, vst = nil, M.valve_new()
  for _ = 1, M.VALVE_K do rv = M.valve(vst, "fz", 0.95, 0, M.valve_recipe(rel3, "fz")) end
  vok(rv.open == false and rv.why:find("surplus", 1, true) ~= nil, "seule recette non débloquée : refus écrit")
  return vp, vf, vmsg
end

local VSRC = read("shared/ai3/fluides.lua")
local VM = assert(load(VSRC, "=fluides", "t"))()
local vp, vf, vmsg = valve_suite(VM)
pass, fail = pass + vp, fail + vf
for _, m in ipairs(vmsg) do msgs[#msgs + 1] = m end
-- anti-échelle : la règle ajoutée ne nomme aucun objet du jeu
local vblock = VSRC:match("Fl%.VALVE_FILL.*$") or ""
for _, w in ipairs({ "petroleum", "crude", "water", "sulfur", "plastic", "chemical", "pumpjack", "refinery", "solid%-fuel", "fuel", "gas" }) do
  check_src(not vblock:lower():find(w), "C6.2 nom du jeu dans Fl.valve : " .. w)
end
-- C6.3 : mutants refusés
local VMUT = {
  { "seuil ignoré (toute cuve pleine ouvre)", "remplissage > Fl.VALVE_FILL", "remplissage >= 0" },
  { "débouché ignoré", " and debouches == 0", "" },
  { "K ignoré (ouverture à la première mesure)", "if st.n < Fl.VALVE_K then", "if st.n < 1 then" },
  { "compteur non remis à zéro", "    st.n = 0\n    return { open = false, why = \"cuve non pleine", "    return { open = false, why = \"cuve non pleine" },
  { "recette de surplus ignorée", "  if not surplus then", "  if false then" },
  { "entrée fluide non comptée", "          fluid_in = fluid_in + 1", "          fluid_in = fluid_in + 0" },
  { "produit fluide accepté comme surplus", "if p.type ~= \"item\" then only_item_out = false end", "" },
  { "recette non débloquée choisie", " and r.enabled ~= false and", " and" },
}
local vrefused, vkept = 0, {}
for _, m in ipairs(VMUT) do
  local a, b = VSRC:find(m[2], 1, true)
  if not a then
    vkept[#vkept + 1] = m[1] .. " (motif absent)"
  else
    local mod = load(VSRC:sub(1, a - 1) .. m[3] .. VSRC:sub(b + 1), "=fluides", "t")
    local bad = 1
    if mod then
      local okm, MM = pcall(mod)
      if okm and type(MM) == "table" then
        local _, ff = valve_suite(MM)
        bad = ff
      end
    end
    if bad > 0 then vrefused = vrefused + 1 else vkept[#vkept + 1] = m[1] end
  end
end
if #vkept == 0 then pass = pass + 1 else
  fail = fail + 1
  print("[AI3-FLUIDE] ECHEC C6.3 mutants NON refusés : " .. table.concat(vkept, " ; "))
end
print(string.format("[AI3-FLUIDE] C6 soupape : mutants refusés %d sur %d", vrefused, #VMUT))

for _, m in ipairs(msgs) do print("[AI3-FLUIDE] ECHEC " .. m) end

-- §7 Mutants.
local MUT = {
  { "recette à fluide écartée (comme avant)", "if Ca.recipe_open(ctx, rn) and ctx.cats_present[r.category] then", "if Ca.recipe_open(ctx, rn) and not r.fluid and ctx.cats_present[r.category] then" },
  { "ressource fluide écartée (comme avant)", "    ok = Ca.is_known(ctx, item) and ext\n  end", "    ok = Ca.is_known(ctx, item) and ext and not rs.fluid\n  end" },
  { "ressource connue ignorée", "    ok = Ca.is_known(ctx, item) and ext\n  end", "    ok = ext\n  end" },
  { "extracteur ignoré", "    ok = Ca.is_known(ctx, item) and ext\n  end", "    ok = Ca.is_known(ctx, item)\n  end" },
  { "pompe ignorée", "  if not ok and D.pumped[item] then ok = Ca.is_known(ctx, item) end\n", "" },
  { "eau toujours connue", "if not ok and D.pumped[item] then ok = Ca.is_known(ctx, item) end", "if not ok and D.pumped[item] then ok = true end" },
  { "pompe non exécutante comptée", "if e.fluid and e.item and executable(e, role) then D.pumped[e.fluid] = true end", "if e.fluid and e.item then D.pumped[e.fluid] = true end" },
  { "catégorie absente ignorée", "if Ca.recipe_open(ctx, rn) and ctx.cats_present[r.category] then", "if Ca.recipe_open(ctx, rn) then" },
  { "recette fermée ignorée", "if Ca.recipe_open(ctx, rn) and ctx.cats_present[r.category] then", "if ctx.cats_present[r.category] then" },
  { "ingrédient fluide ignoré", "          if not Ca.obtainable(ctx, i.name) then all = false break end", "          if not i.fluid and not Ca.obtainable(ctx, i.name) then all = false break end" },
  { "ingrédient solide ignoré", "          if not Ca.obtainable(ctx, i.name) then all = false break end", "          if i.fluid and not Ca.obtainable(ctx, i.name) then all = false break end" },
  { "garde de cycle retirée", "  memo[item] = false -- garde contre un cycle de recettes\n  local D = ctx.D", "  local D = ctx.D" },
  { "stock ignoré", "local ok = (ctx.stock[item] or 0) > 0\n  if not ok and D.res[item] then", "local ok = false\n  if not ok and D.res[item] then" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif absent)"
  else
    local mod = load_ca(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    local f2 = 1
    if mod then
      local ok, _, ff = pcall(suite, mod)
      f2 = ok and ff or 1
    end
    if f2 > 0 then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
if #kept == 0 then pass = pass + 1 else
  fail = fail + 1
  print("[AI3-FLUIDE] ECHEC §7 mutants NON refusés : " .. table.concat(kept, " ; "))
end
print(string.format("[AI3-FLUIDE] mutants refusés : %d sur %d", refused, #MUT))
print(string.format("[AI3-FLUIDE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
