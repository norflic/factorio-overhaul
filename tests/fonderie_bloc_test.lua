--[[
  Lot FONDERIE-BLOC (8/11) : test hors jeu de la règle pure shared/team/fonderie_bloc.lua (le coffre de charbon d'une fonderie devient une entrée
  de bloc reliée par un tapis au charbon) et du branchement (lu comme texte).
    §1 décision ; §2 géométrie d'arrivée (4 directions, preuve) ; §3 pièces ; §4 journal ; §5 débit du coffre de tête dans le plan du champ
    (shared/team/champ_colonne.lua / champ.lua, règle pure) ; §6 branchement ; §7 hygiène ; §8 mutants.
  Usage : lua5.2 tests/fonderie_bloc_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/fonderie_bloc.lua")
local function load_fb(src)
  local fn, err = load(src, "=fonderie_bloc", "t")
  assert(fn, err)
  return fn()
end
local Fb = load_fb(SRC)
local Li = require("shared.team.liaison")

---------------------------------------------------------------------------------------------------
-- §1 décision
---------------------------------------------------------------------------------------------------
local function base()
  return { flow = 0.27, served = false, open = false, open_total = 0, pq_cause = "aucune_source", seen = 2, tries = 0, since_try = math.huge,
    threat = false, enemies = 0, free = 2 }
end
local function dec(over)
  local i = base()
  for k, v in pairs(over or {}) do i[k] = v end
  return Fb.decide(i)
end
check(dec() == "demander", "quai sans source, confirme, PNJ libres : demander")
check(dec({ served = true }) == "laisser", "quai deja servi : laisser")
check(dec({ flow = 0 }) == "laisser", "debit nul : laisser")
check(dec({ flow = Fb.MIN_FLOW / 2 }) == "laisser", "debit sous le minimum : laisser")
check(dec({ flow = Fb.MIN_FLOW }) == "demander", "debit au minimum : demander")
check(dec({ open = true }) == "attendre", "alimentation deja en cours : attendre")
check(dec({ pq_cause = false }) == "attendre", "piquage pas encore juge : attendre")
check(dec({ pq_cause = "a_confirmer" }) == "attendre", "piquage a confirmer : attendre")
check(dec({ pq_cause = "sortie_plus_rentable" }) == "attendre", "la liaison prend le quai : attendre")
check(dec({ pq_cause = "menace" }) == "attendre", "menace du piquage : attendre")
check(dec({ pq_cause = "ne_se_paie_pas" }) == "demander", "piquage : ne se paie pas : demander")
check(dec({ pq_cause = "essais_epuises" }) == "demander", "piquage : essais epuises : demander")
check(dec({ pq_cause = "projet_refuse" }) == "demander", "piquage : projet refuse : demander")
check(dec({ seen = 0 }) == "attendre", "jamais vu : attendre")
check(dec({ seen = Fb.CONFIRM - 1 }) == "attendre", "une confirmation manque : attendre")
check(dec({ threat = true }) == "attendre", "QG menace : attendre")
check(dec({ tries = Fb.MAX_TRIES, since_try = 60 }) == "laisser", "essais epuises recents : laisser")
check(dec({ tries = Fb.MAX_TRIES, since_try = Fb.RETRY_AFTER }) == "demander", "essais epuises, delai passe : un essai de plus")
check(dec({ tries = Fb.MAX_TRIES - 1, since_try = Fb.RETRY_GAP }) == "demander", "un essai restant : demander")
check(dec({ tries = 1, since_try = Fb.RETRY_GAP - 1 }) == "attendre", "un essai tout recent : attendre")
check(dec({ tries = 1, since_try = Fb.RETRY_GAP }) == "demander", "l'ecart entre deux essais est passe : demander")
check(dec({ open_total = Fb.MAX_OPEN }) == "attendre", "une alimentation deja ouverte : attendre")
check(dec({ free = 0 }) == "attendre", "aucun PNJ libre : attendre")
check(dec({ enemies = 1 }) == "attendre", "ennemi a portee : attendre")
do
  local _, why = dec({ pq_cause = "aucune_source" })
  check(why:find("aucune_source", 1, true) ~= nil, "la raison cite la cause du piquage")
  local _, why2 = dec({ seen = 1 })
  check(why2:find("1/" .. Fb.CONFIRM, 1, true) ~= nil, "la raison cite les releves")
end

---------------------------------------------------------------------------------------------------
-- §2 géométrie d'arrivée
---------------------------------------------------------------------------------------------------
local function free_all() return true end
do
  local ss = Fb.sites(10, 10, free_all, nil)
  check(#ss == Fb.MAX_SITES, "au plus MAX_SITES cotes proposes (" .. #ss .. ")")
  for _, c in ipairs(ss) do
    local s = c.site
    local v = Li.DV[s.dir]
    check(s.ax == 10 + v[1] and s.ay == 10 + v[2], "le bras touche le coffre (dir " .. s.dir .. ")")
    check(s.bx == s.ax + v[1] and s.by == s.ay + v[2], "le tapis est derriere le bras")
    local ents = Fb.entities({ site = s, pole = c.pole, names = { arm = "bras", pole = "poteau" } })
    check(#ents == 2, "deux entites : bras et poteau")
    local arr = Fb.arrival(s)
    local bad = Fb.verify(ents, arr, { x = 10, y = 10 })
    check(#bad == 0, "preuve juste (dir " .. s.dir .. ") : " .. table.concat(bad, ", "))
    check(not (c.pole[1] == s.ax and c.pole[2] == s.ay) and not (c.pole[1] == s.bx and c.pole[2] == s.by), "le poteau n'est ni sur le bras ni sur le tapis")
    check(not (c.pole[1] == 10 and c.pole[2] == 10), "le poteau n'est pas sur le coffre")
  end
  -- l'ordre est N, E, S, O (deterministe)
  local dirs = {}
  for _, c in ipairs(ss) do dirs[#dirs + 1] = c.site.dir end
  local sorted = true
  for i = 2, #dirs do if dirs[i] < dirs[i - 1] then sorted = false end end
  check(sorted, "cotes dans l'ordre N, E, S, O")
  -- cotes bloques
  local blocked = {}
  local function free_n(x, y) return not blocked[x .. ":" .. y] end
  blocked["10:9"] = true -- nord : bras
  local s2 = Fb.sites(10, 10, free_n, nil)
  for _, c in ipairs(s2) do check(c.site.dir ~= 0, "cote nord bloque : non propose") end
  local none = Fb.sites(10, 10, function() return false end, nil)
  check(#none == 0, "rien de libre : aucun cote")
  -- tuiles prises
  local taken = { ["11:10"] = true }
  local s3 = Fb.sites(10, 10, free_all, taken)
  for _, c in ipairs(s3) do
    check(not (c.site.ax == 11 and c.site.ay == 10), "tuile prise : jamais un bras")
    check(not (c.pole[1] == 11 and c.pole[2] == 10), "tuile prise : jamais un poteau")
  end
  -- ne modifie pas `taken`
  local n = 0
  for _ in pairs(taken) do n = n + 1 end
  check(n == 1, "la table des tuiles prises n'est pas modifiee")
end
do
  -- preuve : bras mal tourne
  local s = Li.sites(0, 0, free_all)[1]
  local ents = Fb.entities({ site = s, pole = { 5, 5 }, names = { arm = "a", pole = "p" } })
  ents[1].dir = (ents[1].dir + 4) % 8
  local bad = Fb.verify(ents, Fb.arrival(s), { x = 0, y = 0 })
  check(#bad >= 2, "bras retourne : deux ecarts au moins (" .. #bad .. ")")
  local arr = Fb.arrival(s)
  arr.dir = (arr.dir + 2) % 8
  local bad2 = Fb.verify(Fb.entities({ site = s, pole = { 5, 5 }, names = { arm = "a", pole = "p" } }), arr, { x = 0, y = 0 })
  check(#bad2 == 1, "tapis d'arrivee mal tourne : un ecart")
  local bad3 = Fb.verify(Fb.entities({ site = s, pole = { 5, 5 }, names = { arm = "a", pole = "p" } }), Fb.arrival(s), { x = 1, y = 0 })
  check(#bad3 == 1, "mauvais coffre : un ecart")
  check(#Fb.verify({}, Fb.arrival(s), { x = 0, y = 0 }) == 1, "aucun bras : un ecart")
end

---------------------------------------------------------------------------------------------------
-- §3 pièces
---------------------------------------------------------------------------------------------------
do
  local INFO = {
    ["inserter-lent"] = { reach = 1, rate = 0.8, burner = false },
    ["inserter-vif"] = { reach = 1, rate = 2.3, burner = false },
    ["inserter-brule"] = { reach = 1, rate = 0.6, burner = true },
    ["inserter-long"] = { reach = 2, rate = 1.1, burner = false },
    ["poteau-court"] = { w = 1, h = 1, wire = 7.5 },
    ["poteau-long"] = { w = 1, h = 1, wire = 9 },
    ["poteau-large"] = { w = 2, h = 2, wire = 12 },
  }
  local function info(n) return INFO[n] end
  local function is_pole(n) return n:find("poteau", 1, true) ~= nil end
  local ents = {}
  for _, n in ipairs({ "inserter-vif", "inserter-lent", "inserter-brule", "inserter-long" }) do ents[#ents + 1] = { name = n, role = "champ-bras" } end
  for _, n in ipairs({ "poteau-court", "poteau-long", "poteau-large" }) do ents[#ents + 1] = { name = n, role = "champ-poteau" } end
  local arm, pole = Fb.pick_names(ents, info, is_pole)
  check(arm == "inserter-lent", "bras : le plus lent des electriques de portee 1 (" .. tostring(arm) .. ")")
  check(pole == "poteau-long", "poteau : 1 x 1 de plus long fil (" .. tostring(pole) .. ")")
  local a2, p2 = Fb.pick_names({ { name = "inserter-lent", role = "quai-bras" } }, info, is_pole)
  check(a2 == nil and p2 == nil, "un bras d'un autre role ne compte pas")
  local a3 = Fb.pick_names({ { name = "inserter-brule", role = "champ-bras" } }, info, is_pole)
  check(a3 == nil, "un bras a combustion ne compte pas")
  -- ordre des entrees sans effet
  local rev = {}
  for i = #ents, 1, -1 do rev[#rev + 1] = ents[i] end
  local a4, p4 = Fb.pick_names(rev, info, is_pole)
  check(a4 == arm and p4 == pole, "l'ordre des entites ne change pas le choix")
end

---------------------------------------------------------------------------------------------------
-- §4 journal
---------------------------------------------------------------------------------------------------
do
  local l = Fb.line("scarlet", { key = "7:q2", item = "x", flow = 0.2704 }, "alimentation demandee", "projet 12", 31.25)
  check(l:find("^%[FO%-FONDERIE%-BLOC%] scarlet : quai 7:q2 %(x, 0%.27/s%) : alimentation demandee : projet 12 a 31%.2 min$") ~= nil, "ligne du journal : " .. l)
end

---------------------------------------------------------------------------------------------------
-- §5 le coffre de tête porte son débit dans le plan du champ
---------------------------------------------------------------------------------------------------
do
  local Co = require("shared.team.champ_colonne")
  local spec = { furnace = { size = 2, rate = 0.3125, yield = 1, fuel = "coal", fuel_rate = 0.0225 }, pole = { reach = 2.5, wire = 7.5 },
    inserter = { rate = 0.83 } }
  local ents, _, info = Co.layout(spec, 0, 1, 0, 6, "coffre")
  check(ents ~= nil, "colonne a coffre de tete posee")
  if ents then
    local chests = 0
    for _, e in ipairs(ents) do if e.kind == "coffre" and e.role == "combustible" then chests = chests + 1 end end
    check(chests == 1, "un coffre de tete par colonne")
    check(math.abs(info.need - 6 * 0.0225) < 1e-9, "besoin de la colonne = fours x charbon/s (" .. tostring(info.need) .. ")")
    check(info.need >= Fb.MIN_FLOW, "le besoin d'une colonne de 6 fours passe le minimum de debit")
  end
end

---------------------------------------------------------------------------------------------------
-- §6 branchement (lu comme texte)
---------------------------------------------------------------------------------------------------
do
  local build = read("script/team/build.lua")
  local glue = read("script/team/fonderie_bloc.lua")
  local champ_s = read("shared/team/champ.lua")
  local champ = read("script/team/champ.lua")
  local liaison = read("script/team/liaison.lua")
  local piquage = read("script/team/piquage.lua")
  check(build:find('Build.FonderieBloc = require%("script.team.fonderie_bloc"%)') ~= nil, "build.lua : Build.FonderieBloc est un champ de Build (pas une locale)")
  check(build:find("spec%.alimquai") ~= nil, "build.lua : plan_project dispatche spec.alimquai")
  check(build:find("Build%.FonderieBloc%.step") ~= nil, "build.lua : la passe appelle Build.FonderieBloc.step")
  check(build:find("(p.spec.alim or p.spec.alimquai) then mode = Cv.reach", 1, true) ~= nil, "build.lua : le tapis de l'alimentation de quai passe par le tapis long comme celui de la centrale")
  check(build:find("flow = q%.flow") ~= nil, "build.lua : les quais d'un site gardent leur debit")
  check(champ_s:find("need = g%.info%.need") ~= nil, "shared/team/champ.lua : le coffre de tete porte son besoin")
  check(champ:find("flow = e%.need") ~= nil, "script/team/champ.lua : le quai de combustible porte son debit")
  check(liaison:find("q%.flow or") ~= nil, "liaison.lua : un quai qui porte son debit le garde")
  check(piquage:find("q%.flow or") ~= nil, "piquage.lua : un quai qui porte son debit le garde")
  for _, f in ipairs({ "script/team/liaison.lua", "script/team/piquage.lua", "script/team/rapatriement.lua" }) do
    check(read(f):find('"alimquai"', 1, true) ~= nil, f .. " : un projet d'alimentation de quai n'est pas un module")
  end
  check(read("script/team/sante_centrale.lua"):find("sp%.alimquai") ~= nil, "sante_centrale.lua : l'alimentation de quai est admise sans porte des consommateurs")
  check(glue:find("%[FO%-FONDERIE%-BLOC%]") == nil, "le journal passe par Fb.line (une seule source du format)")
  check(glue:find("Fb%.decide") ~= nil and glue:find("Fb%.sites") ~= nil and glue:find("Fb%.verify") ~= nil, "la colle appelle la regle pure")
end

---------------------------------------------------------------------------------------------------
-- §7 hygiène
---------------------------------------------------------------------------------------------------
do
  check(SRC:find("[^i]pairs%(") == nil, "aucun pairs (listes triees seulement)")
  check(SRC:find("coal", 1, true) == nil and SRC:find("iron", 1, true) == nil and SRC:find("chest", 1, true) == nil, "aucun nom d'objet ni de minerai")
  check(SRC:find("os%.clock") == nil and SRC:find("math%.random") == nil, "aucun temps mesure, aucun hasard")
  check(SRC:find("math%.sin") == nil and SRC:find("math%.cos") == nil, "aucune trigonometrie")
end

---------------------------------------------------------------------------------------------------
-- §8 mutants
---------------------------------------------------------------------------------------------------
local function mutant(name, from, to, probe)
  local src, n = SRC:gsub(from, to, 1)
  if n == 0 then check(false, "mutant " .. name .. " : motif introuvable") return end
  local okl, Pm = pcall(load_fb, src)
  if not okl then check(true, "mutant " .. name .. " (ne se charge pas)") return end
  local okp, seen = pcall(probe, Pm)
  check(not okp or seen, "mutant " .. name .. " vu")
end
local function dec_m(Pm, over)
  local i = base()
  for k, v in pairs(over or {}) do i[k] = v end
  return (Pm.decide(i))
end
mutant("deja servi ignore", 'if inp%.served then return "laisser"', "if false then return \"laisser\"",
  function(Pm) return dec_m(Pm, { served = true }) ~= "laisser" end)
mutant("debit nul accepte", "if %(inp%.flow or 0%) < Fb%.MIN_FLOW then", "if false then",
  function(Pm) return dec_m(Pm, { flow = 0 }) ~= "laisser" end)
mutant("debit au minimum refuse", "if %(inp%.flow or 0%) < Fb%.MIN_FLOW then", "if (inp.flow or 0) <= Fb.MIN_FLOW then",
  function(Pm) return dec_m(Pm, { flow = Pm.MIN_FLOW }) ~= "demander" end)
mutant("alimentation en cours ignoree", 'if inp%.open then return "attendre"', 'if false then return "attendre"',
  function(Pm) return dec_m(Pm, { open = true }) ~= "attendre" end)
mutant("piquage non attendu", "if not Fb%.READY_CAUSES%[inp%.pq_cause or \"\"%] then", "if false then",
  function(Pm) return dec_m(Pm, { pq_cause = "a_confirmer" }) ~= "attendre" end)
mutant("cause ne_se_paie_pas retiree", "ne_se_paie_pas = true, ", "",
  function(Pm) return dec_m(Pm, { pq_cause = "ne_se_paie_pas" }) ~= "demander" end)
mutant("cause aucune_source retiree", "aucune_source = true, ", "",
  function(Pm) return dec_m(Pm, { pq_cause = "aucune_source" }) ~= "demander" end)
mutant("confirmation retiree", "if %(inp%.seen or 0%) < Fb%.CONFIRM then", "if false then",
  function(Pm) return dec_m(Pm, { seen = 0 }) ~= "attendre" end)
mutant("menace ignoree", 'if inp%.threat then return "attendre"', 'if false then return "attendre"',
  function(Pm) return dec_m(Pm, { threat = true }) ~= "attendre" end)
mutant("essais epuises ignores", "if %(inp%.tries or 0%) >= Fb%.MAX_TRIES and", "if false and",
  function(Pm) return dec_m(Pm, { tries = Pm.MAX_TRIES, since_try = 60 }) ~= "laisser" end)
mutant("nouvel essai jamais", "%(inp%.since_try or Fb%.RETRY_AFTER%) < Fb%.RETRY_AFTER then", "true then",
  function(Pm) return dec_m(Pm, { tries = Pm.MAX_TRIES, since_try = Pm.RETRY_AFTER }) ~= "demander" end)
mutant("ecart entre essais retire", "if %(inp%.tries or 0%) > 0 and %(inp%.since_try or Fb%.RETRY_AFTER%) < Fb%.RETRY_GAP then", "if false then",
  function(Pm) return dec_m(Pm, { tries = 1, since_try = 60 }) ~= "attendre" end)
mutant("plafond d'alimentations ouvertes retire", "if %(inp%.open_total or 0%) >= Fb%.MAX_OPEN then", "if false then",
  function(Pm) return dec_m(Pm, { open_total = Pm.MAX_OPEN }) ~= "attendre" end)
mutant("PNJ libres ignores", "if %(inp%.free or 0%) < 1 then", "if false then",
  function(Pm) return dec_m(Pm, { free = 0 }) ~= "attendre" end)
mutant("ennemi ignore", "if %(inp%.enemies or 0%) > 0 then", "if false then",
  function(Pm) return dec_m(Pm, { enemies = 1 }) ~= "attendre" end)
mutant("arrivee mal tournee", "dir = Li%.end_dir%(site%)", "dir = site.dir",
  function(Pm)
    local s = Li.sites(0, 0, free_all)[1]
    local bad = Pm.verify(Pm.entities({ site = s, pole = { 5, 5 }, names = { arm = "a", pole = "p" } }), Pm.arrival(s), { x = 0, y = 0 })
    return #bad > 0
  end)
mutant("bras retourne", "dir = s%.dir, role = \"liaison%-bras\"", "dir = (s.dir + 4) %% 8, role = \"liaison-bras\"",
  function(Pm)
    local s = Li.sites(0, 0, free_all)[1]
    local bad = Pm.verify(Pm.entities({ site = s, pole = { 5, 5 }, names = { arm = "a", pole = "p" } }), Pm.arrival(s), { x = 0, y = 0 })
    return #bad > 0
  end)
mutant("preuve de la prise retiree", "if tx %+ v%[1%] ~= arr%.x or ty %+ v%[2%] ~= arr%.y then", "if false then",
  function(Pm)
    local s = Li.sites(0, 0, free_all)[1]
    local ents = Pm.entities({ site = s, pole = { 5, 5 }, names = { arm = "a", pole = "p" } })
    ents[1].dir = (ents[1].dir + 4) % 8
    return #Pm.verify(ents, Pm.arrival(s), { x = 0, y = 0 }) < 2
  end)
mutant("preuve du depot retiree", "if tx %- v%[1%] ~= D%.x or ty %- v%[2%] ~= D%.y then", "if false then",
  function(Pm)
    local s = Li.sites(0, 0, free_all)[1]
    return #Pm.verify(Pm.entities({ site = s, pole = { 5, 5 }, names = { arm = "a", pole = "p" } }), Pm.arrival(s), { x = 1, y = 0 }) == 0
  end)
mutant("tuiles prises ignorees", "and not %(taken and taken%[x %.%. \":\" %.%. y%]%)", "",
  function(Pm)
    for _, c in ipairs(Pm.sites(10, 10, free_all, { ["11:10"] = true })) do
      if c.site.ax == 11 and c.site.ay == 10 then return true end
    end
    return false
  end)
mutant("plafond de cotes retire", "if #out >= Fb%.MAX_SITES then break end", "",
  function(Pm) return #Pm.sites(10, 10, free_all, nil) > Pm.MAX_SITES end)
mutant("bras electrique seulement", "not s%.burner and s%.reach == 1", "s.reach == 1",
  function(Pm)
    local INFO = { b = { reach = 1, rate = 0.1, burner = true }, e = { reach = 1, rate = 0.8, burner = false } }
    local arm = Pm.pick_names({ { name = "b", role = "champ-bras" }, { name = "e", role = "champ-bras" } }, function(n) return INFO[n] end, function() return false end)
    return arm ~= "e"
  end)
mutant("role du bras ignore", 'e%.role == "champ%-bras" and not s%.burner', "not s.burner",
  function(Pm)
    local INFO = { e = { reach = 1, rate = 0.8, burner = false } }
    local arm = Pm.pick_names({ { name = "e", role = "autre" } }, function(n) return INFO[n] end, function() return false end)
    return arm ~= nil
  end)
mutant("poteau le plus court", "s%.wire > wire or", "s.wire < wire or",
  function(Pm)
    local INFO = { c = { w = 1, h = 1, wire = 7.5 }, l = { w = 1, h = 1, wire = 9 } }
    local _, pole = Pm.pick_names({ { name = "c", role = "x" }, { name = "l", role = "x" } }, function(n) return INFO[n] end, function() return true end)
    return pole ~= "l"
  end)

print(string.format("[FONDERIE-BLOC] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
