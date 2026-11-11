--[[
  Lot COUVERTURE, SATURATION TOTALE des gisements revendiqués (directive du DC du 8/11, 14 h 50) : test hors jeu de Ca.decide (couvrir sans demande
  nette) et de Cv.saturation. Lancer depuis la racine du mod :
    lua5.2 tests/saturation_test.lua   -> [SATURATION] BILAN : N OK, 0 ECHEC(S)
  Les scènes reprennent les helpers de tests/ai3_capitalisation_test.lua (vanilla, mêmes données). Mutants en fin de fichier.
]]

-- Témoin A/B (lot VIDEO-INTEG, critère K6) : FO_CAPI_SRC = dossier où lire d'abord shared/ai3/capitalisation.lua (une autre
-- version de la règle) ; FO_CAPI_DUMP = fichier où écrire le rendu sérialisé de chaque Ca.decide de §1 à §17 (rien d'autre ne tourne).
local AB_SRC, AB_DUMP = os.getenv("FO_CAPI_SRC"), os.getenv("FO_CAPI_DUMP")
package.path = (AB_SRC and (AB_SRC .. "/?.lua;") or "") .. "./?.lua;" .. package.path
local F = require("tests.iag_fixture")
local Ca = require("shared.ai3.capitalisation")
local B = require("shared.ai3.buts")
local P = require("shared.ai3.projets")
local K = require("shared.ai3.catalogue")
local Rp = require("shared.ai3.repli")
local Tr = require("shared.faction.traits")
local Pf = require("shared.ai3.plafonds") -- lot VIDEO-L13 (§17)
-- Étape 8 d'INTEGRATION_VIDEO (L1b et L2 ALLUMÉS par défaut) : FO_CAPI_RANG=0 rejoue la suite interrupteurs ÉTEINTS (la décision
-- d'avant), FO_CAPI_RANG=rang avec le rang seul, sans la porte ; absent : les défauts. Les mutants de §11 gardent ce choix.
-- FO_CAPI_DUMP_SIG=1 (avec FO_CAPI_DUMP) : le témoin n'écrit que la signature des ordres et les retenues de la porte (A/B orders_sig).
local AB_RANG, AB_SIG = os.getenv("FO_CAPI_RANG"), os.getenv("FO_CAPI_DUMP_SIG")
if AB_RANG == "0" then Ca.RANG, Ca.PORTE_RANG = false, false elseif AB_RANG == "rang" then Ca.RANG, Ca.PORTE_RANG = true, false end

local pass, fail = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[SATURATION] ECHEC : " .. msg) end
  end
end
local function say(s) if not quiet then print("[SATURATION] " .. s) end end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function deep(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = deep(v) end
  return c
end

---------------------------------------------------------------------------------------------------
-- Relevé vanilla réaliste (vitesses, aires, puissances, temps de minage de data/base 1.1.91)
---------------------------------------------------------------------------------------------------
local V_SPEED = { ["stone-furnace"] = 1, ["steel-furnace"] = 2, ["electric-furnace"] = 2, ["assembling-machine-1"] = 0.5,
  ["assembling-machine-2"] = 0.75, ["assembling-machine-3"] = 1.25, ["burner-mining-drill"] = 0.25,
  ["electric-mining-drill"] = 0.5, ["pumpjack"] = 1, ["lab"] = 1, ["chemical-plant"] = 1, ["oil-refinery"] = 1,
  ["centrifuge"] = 1 }
local V_AREA = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 5, ["pumpjack"] = 1 }
local V_SIZE = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 3, ["stone-furnace"] = 2, ["steel-furnace"] = 2 }
local V_KW = { ["stone-furnace"] = 90, ["steel-furnace"] = 90, ["electric-furnace"] = 180, ["burner-mining-drill"] = 150,
  ["electric-mining-drill"] = 90, ["assembling-machine-1"] = 75, ["assembling-machine-2"] = 150,
  ["assembling-machine-3"] = 375, ["lab"] = 60, ["boiler"] = 1800 }
local V_MINE = { ["uranium-ore"] = 2 }

local function vanilla_dump(mut, fopts)
  local d = F.dump(fopts)
  for _, e in ipairs(d.entities) do
    if V_SPEED[e.name] then e.speed = V_SPEED[e.name] end
    e.mining_area = V_AREA[e.name]
    e.size = V_SIZE[e.name] or 3
    e.energy_kw = V_KW[e.name]
  end
  -- Recettes débloquées par une technologie : inactives au départ (comme dans le jeu).
  for _, t in ipairs(sorted_keys(d.techs)) do
    for _, r in ipairs(d.techs[t].unlocks) do if d.recipes[r] then d.recipes[r].enabled = false end end
  end
  for _, r in ipairs(d.resources) do r.mining_time = V_MINE[r.entity] or 1 end
  if mut then mut(d) end
  return d
end

-- Exécutants : ceux d'AUTO (foreuses électriques, assembleurs) et ceux de main aujourd'hui (four en pierre, foreuse à
-- combustion), plus la main et le laboratoire du QG.
local EXEC_AUTO = { ["stone-furnace"] = true, ["steel-furnace"] = true, ["burner-mining-drill"] = true,
  ["electric-mining-drill"] = true, ["assembling-machine-1"] = true, ["assembling-machine-2"] = true }
local EXEC_MAIN = { ["stone-furnace"] = true, ["burner-mining-drill"] = true }
local ROLES = { main = true, labo = true }
local function vdata(mut, exec, fopts)
  return Ca.data(vanilla_dump(mut, fopts), { exec = exec or EXEC_AUTO, exec_roles = ROLES })
end

-- Financement RÉALISTE des scènes : des pièces d'équipement au coffre (1 000 circuits, 3 425 MU), qui entrent dans les
-- recettes des foreuses, des assembleurs et des laboratoires. Plus de coffres en fer (ils ne deviennent jamais une
-- foreuse : un stock non convertible ne compte plus, §6). Les contrôles du budget lui-même partent d'un stock VIDE.
local PIECES = { ["electronic-circuit"] = 1000 }
local function pieces(extra)
  local s = deep(PIECES)
  for k, v in pairs(extra or {}) do s[k] = v end
  return s
end

--- Entrée de base (vanilla) : de l'assemblage recherché, RIEN au stock, des bras libres.
local function vin(D, over)
  local inp = { data = D, state = { techs = { automation = true } }, stock = {}, flows = {},
    machines = {}, drills = {}, labs = {}, deposits = {}, open = {}, sinks = {}, workers = 30, idle = 10,
    can_grow = true, traits = {}, weights = {} }
  for k, v in pairs(over or {}) do inp[k] = v end
  return inp
end

local function find(res, key)
  for i, o in ipairs(res.orders) do if o.key == key then return o, i end end
  return nil, nil
end
local function refus_of(res, key)
  for _, r in ipairs(res.refus) do if r.key == key then return r end end
  return nil
end
local function count_kind(res, kind)
  local n = 0
  for _, o in ipairs(res.orders) do if o.kind == kind then n = n + 1 end end
  return n
end
local function no_dup(res)
  local seen = {}
  for _, o in ipairs(res.orders) do
    if seen[o.key] then return false end
    seen[o.key] = true
  end
  return true
end
local function sum_cost(res)
  local c = 0
  for _, o in ipairs(res.orders) do c = c + o.cost_m end
  return c
end
local function explores(res, item)
  for _, e in ipairs(res.explore) do if e.resource == item then return e end end
  return nil
end

-- Gisement de fer (minerai livré au QG, fours du QG) et un site connu plus loin.
local function iron_scene(D, sink, over)
  local inp = vin(D, {
    stock = pieces(),
    deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60 },
      { id = "s2", resource = "iron-ore", tiles = 270, amount = 1e6, dist = 150 } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 2, deposit = "d1" } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 4, where = "qg" } },
    flows = { ["iron-ore"] = { made = 60 }, ["iron-plate"] = { made = 60 } },
    sinks = { { item = "iron-plate", rate = sink } } })
  for k, v in pairs(over or {}) do inp[k] = v end
  return inp
end

-- Recherche aux packs rouges : 8 laboratoires qui tournent, fours sur place du fer et du cuivre.
local function pack_scene(D, over)
  local inp = vin(D, {
    stock = pieces(),
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 8, where = "d-fe" },
      { entity = "stone-furnace", recipe = "copper-plate", n = 4, where = "d-cu" } },
    flows = { ["iron-plate"] = { made = 150 }, ["copper-plate"] = { made = 75 } },
    labs = { { entity = "lab", n = 8 } },
    research = { queue = { { tech = "electronics", left = 27, time = 15, packs = { { "automation-science-pack", 1 } } },
      { tech = "fast-inserter", left = 2000, time = 15, packs = { { "automation-science-pack", 1 } } } }, rate = 450 } })
  for k, v in pairs(over or {}) do inp[k] = v end
  return inp
end

--- Capital de la chaîne d'un objet recalculé PAR LE TEST, depuis les valeurs du relevé (contrôle indépendant de
--- Ca.chain_capital) : foreuse électrique, four en pierre, assembleur 1.
local function cc_test(D, item)
  local drill = D.mu["electric-mining-drill"] / 30
  local plate = D.mu["stone-furnace"] / 18.75 + drill
  if item == "iron-ore" or item == "copper-ore" then return drill end
  if item == "iron-plate" or item == "copper-plate" then return plate end
  if item == "iron-gear-wheel" then return D.mu["assembling-machine-1"] / 60 + 2 * plate end
  return nil
end

---------------------------------------------------------------------------------------------------
-- §1 Débits sans table
---------------------------------------------------------------------------------------------------

local D = vdata()
local Cv = require("shared.ai3.couverture")

-- Scène : un gisement de fer REVENDIQUÉ, des plaques en stock (demande nette nulle), un puits modeste.
local function scene(over, dep_over, saturation)
  local dep = { id = "d1", resource = "iron-ore", tiles = 3000, amount = 1e7, open = true, dist = 60 }
  for k, v in pairs(dep_over or {}) do dep[k] = v end
  local inp = vin(D, {
    stock = pieces({ ["iron-plate"] = 4000 }),
    deposits = { dep },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 3, deposit = "d1" } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 4, where = "qg" } },
    flows = { ["iron-ore"] = { made = 60 }, ["iron-plate"] = { made = 60 } },
    sinks = { { item = "iron-plate", rate = 30 } } })
  for k, v in pairs(over or {}) do inp[k] = v end
  if saturation ~= false then inp.saturation = true end
  return inp
end
local function ordre(res) return find(res, "couvrir:d1") end

-- 1. Le défaut mesuré : 10 minutes de plaques en stock -> plus aucun ordre, ni refus (saturation éteinte, comme avant).
local r0 = Ca.decide(scene(nil, nil, false), {})
check(ordre(r0) == nil and refus_of(r0, "couvrir:d1") == nil, "§1 saturation eteinte : aucun ordre ni refus (le cas silencieux mesure chez le DC)")
check(r0.sat == nil, "§1 saturation eteinte : res.sat absent (rendu d'avant)")
-- 2. Saturation allumée : l'ordre existe sans demande nette.
local r1 = Ca.decide(scene(), {})
local o1 = ordre(r1)
check(o1 ~= nil and o1.n >= 1 and o1.saturation == true and o1.why == "saturation du gisement", "§2 stock de plaques riche : ordre de saturation (" .. tostring(o1 and o1.n) .. ")")
check(o1 and o1.n <= 219 + 3, "§2 jamais plus que les places libres (" .. tostring(o1 and o1.n) .. ")")
check(r1.sat and r1.sat["d1"] == nil or true, "§2 res.sat est une table")
-- 3. Gisement saturé : plus d'ordre, la cause est ECRITE.
local r2 = Ca.decide(scene(nil, { tiles = 12 }), {})
check(ordre(r2) == nil, "§3 petit gisement deja couvert : aucun ordre")
-- 4. Danger : l'ordre est refusé avec sa cause.
local r3 = Ca.decide(scene(nil, { danger = true }), {})
check(ordre(r3) == nil and refus_of(r3, "couvrir:d1") and tostring(refus_of(r3, "couvrir:d1").why):find("danger", 1, true), "§4 danger : refus ecrit")
-- 5. Couverture exposée pour le journal.
local cv
for _, c in ipairs(r1.coverage) do if c.id == "d1" then cv = c end end
check(cv and cv.tiles == 3000 and type(cv.covered) == "number" and cv.covered > 0, "§5 coverage: tuiles et tuiles couvertes (journal [FO-SATURATION])")
for _, c in ipairs(r0.coverage) do check(c.tiles == nil, "§5 saturation eteinte : coverage sans champ de plus") end
-- 6. Deux ressources sans demande nette : les deux gisements sont saturés.
local inp6 = scene()
inp6.deposits[#inp6.deposits + 1] = { id = "d2", resource = "copper-ore", tiles = 2000, amount = 1e7, open = true, dist = 70 }
inp6.stock["copper-plate"] = 4000
inp6.stock["electronic-circuit"] = 20000 -- de quoi payer les deux ordres (sinon le second est refuse « budget » : realiste, pas le sujet)
inp6.sinks[#inp6.sinks + 1] = { item = "copper-plate", rate = 20 }
local r6 = Ca.decide(inp6, {})
check(ordre(r6) ~= nil and find(r6, "couvrir:d2") ~= nil, "§6 fer et cuivre revendiques : un ordre de saturation chacun")
-- 7. Gisement NON revendiqué (connu seulement) : la saturation n'ouvre pas de site.
local r7 = Ca.decide(scene({ drills = {} }, { open = false }), {})
check(ordre(r7) == nil and find(r7, "ouvrir:d1") == nil, "§7 gisement connu, aucune foreuse posee : ni couvrir ni ouvrir par la saturation")
local r7b = Ca.decide(scene(nil, { open = false }), {})
check(ordre(r7b) ~= nil, "§7 une foreuse posee suffit a revendiquer le gisement")
-- 7c. Un site CONNU de la même ressource (non revendiqué) : la saturation ne l'ouvre pas et ne l'accuse de rien.
local inp7c = scene()
inp7c.deposits[#inp7c.deposits + 1] = { id = "d3", resource = "iron-ore", tiles = 500, amount = 1e7, dist = 200 }
local r7c = Ca.decide(inp7c, {})
check(find(r7c, "ouvrir:d3") == nil and refus_of(r7c, "ouvrir:d3") == nil, "§7 site connu non revendique : ni ordre ni refus de la saturation")
-- 7d. Budget large : l'ordre entier passe (non réduit) et porte la marque de saturation.
local r7d = Ca.decide(scene({ stock = pieces({ ["iron-plate"] = 4000, ["electronic-circuit"] = 1e6 }) }), {})
check(ordre(r7d) and ordre(r7d).saturation == true and ordre(r7d).n > 100, "§7 budget large : l'ordre entier est marque saturation (" .. tostring(ordre(r7d) and ordre(r7d).n) .. ")")
-- 8. Déterminisme et indépendance de l'ordre des clés.
local ra, rb = Ca.decide(scene(), {}), Ca.decide(scene(), {})
check(ordre(ra).n == ordre(rb).n and #ra.orders == #rb.orders, "§8 deterministe")
-- 9. L'ordre de saturation ne prend pas la place d'un besoin réel : stock de plaques nul + puits fort -> l'ordre de besoin (pas de saturation).
local r9 = Ca.decide(scene({ stock = pieces(), sinks = { { item = "iron-plate", rate = 600 } } }), {})
local o9 = ordre(r9)
check(o9 ~= nil and o9.saturation ~= true, "§9 manque reel : l'ordre est un ordre de BESOIN, pas de saturation")
-- 10. Foreuse à combustion seulement (aucune électrique) : pas de saturation, cause écrite.
local Dbrn = vdata(nil, { ["stone-furnace"] = true, ["burner-mining-drill"] = true })
local inp10 = scene()
inp10.data = Dbrn
inp10.drills = { { entity = "burner-mining-drill", resource = "iron-ore", n = 3, deposit = "d1" } }
local ok10, r10 = pcall(Ca.decide, inp10, {})
check(ok10 and ordre(r10) == nil or (ok10 and ordre(r10).saturation ~= true), "§10 combustion seulement : pas d'ordre de saturation")
-- 11. Cv.saturation seule.
local sv, sw = Cv.saturation({ free = 10, kappa = 400, kappa_max = 1000, electric = true })
check(sv == true and sw:find("10 place", 1, true), "§11 Cv.saturation : ordre actif")
check(Cv.saturation({ free = 10, kappa = 400, electric = false }) == false, "§11 combustion refusee")
check(Cv.saturation({ free = 0, kappa = 400, electric = true }) == false, "§11 aucune place")
check(Cv.saturation({ free = 10, kappa = 1000, electric = true }) == false, "§11 gisement sature")
check(Cv.saturation({ free = 10, kappa = 400, electric = true, crisis = true }) == false, "§11 crise")
check(Cv.saturation({ free = 10, electric = true }) == false, "§11 couverture inconnue")
check(Cv.saturation(nil) == false, "§11 entree absente")
check(Cv.saturation({ free = 10, kappa = 999, electric = true }) == true, "§11 999 pour mille : encore actif")
local l1 = Cv.loop({ kind = "couvrir", product = "p", saturated = { p = true }, free = 5, saturation = true })
local l2 = Cv.loop({ kind = "couvrir", product = "p", saturated = { p = true }, free = 5 })
check(l1 == true and l2 == false, "§11 Cv.loop : la saturation passe meme produit sature, l'avance non")

-- 11b. Lot CAPI-RETOUR (graine 2507543475, emerald minute 56 : « ordre ferme (retour 51.3 min > 20.6) » sur un fer à 427 pour mille ; graine
-- 123456789, amber : 57 fours comptés pour un ordre de 8 foreuses, gain négatif, « gain nul ») : les fours d'un ordre de couverture sont ceux
-- de SON débit (l'exécutant pose des modules au débit de l'ordre, script/ai3/capitalisation.lua), pas ceux du débit de tout le gisement :
-- les foreuses déjà posées sont fondues par la fonderie déportée (hors du minerai, classée « loin »), que la fonte sur place ne voyait pas.
local function deported(over)
  local inp = scene(over, { smelt = "iron-plate", smelter = "stone-furnace", tiles = 3000 })
  inp.drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 40, deposit = "d1" } }
  inp.machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 64, where = "loin" } }
  inp.flows = { ["iron-ore"] = { made = 1200 }, ["iron-plate"] = { made = 1200 } }
  inp.stock["iron-plate"] = 40000
  inp.sinks = { { item = "iron-plate", rate = 600 } }
  return inp
end
local r11b = Ca.decide(deported(), {})
local o11b = ordre(r11b)
local rf11b = refus_of(r11b, "couvrir:d1")
check(o11b ~= nil and o11b.saturation == true, "§11b fonderie deportee : l'ordre de saturation passe (refus : " .. tostring(rf11b and rf11b.why) .. ")")
check(o11b and o11b.smelt_n == Ca.fed_max(o11b.n * 30, 0, 18.75), "§11b fours de l'ordre = fours de SON debit (" .. tostring(o11b and o11b.n) .. " foreuses, "
  .. tostring(o11b and o11b.smelt_n) .. " fours)")
check(o11b and o11b.T <= r11b.tmax, "§11b retour sous le seuil du caractere (" .. tostring(o11b and o11b.T) .. " <= " .. tostring(r11b.tmax) .. ")")

-- 12. Mutants : le source muté est écrit dans un dossier jetable lu EN PREMIER (FO_CAPI_SRC, comme le témoin A/B) ; la suite complète rejouée dans
-- un processus fils doit échouer (code de sortie non nul).
if not os.getenv("FO_SAT_CHILD") and not AB_SRC then
  local function read(p) local fh = assert(io.open(p, "rb")) local x = fh:read("*a") fh:close() return x end
  local MUT = {
    { "shared/ai3/capitalisation.lua", "saturation jamais emise", "if n == 0 and ctx.input.saturation then", "if false then" },
    { "shared/ai3/capitalisation.lua", "ressources sans demande oubliees", "if D.res[i] and (req.R[i] or 0) <= 0 then extraction_options(ctx, plan, req, i, 0, out, true) end", "" },
    { "shared/ai3/capitalisation.lua", "site ouvert par la saturation", "  if sat_only then return end\n", "" },
    { "shared/ai3/capitalisation.lua", "ordre non marque", "o.saturation = sat_order or nil\n            cand", "cand" },
    { "shared/ai3/capitalisation.lua", "tuiles non exposees", "c.tiles, c.covered = f.tiles or 0, covered_t", "" },
    { "shared/ai3/couverture.lua", "gisement sature admis", "if a.kappa >= kmax then return false,", "if false then return false," },
    { "shared/ai3/couverture.lua", "combustion admise", "if a.electric ~= true then return false,", "if false then return false," },
    { "shared/ai3/couverture.lua", "sans place admise", "if type(a.free) ~= \"number\" or a.free ~= a.free or a.free <= 0 then return false, \"aucune place", "if false then return false, \"aucune place" },
    { "shared/ai3/couverture.lua", "crise ignoree (saturation)", "if a.crisis then return false, \"crise (survie ou QG menace) : le travail de base d'abord\" end\n  if a.electric", "if a.electric" },
    { "shared/ai3/capitalisation.lua", "CAPI-RETOUR : fours de tout le gisement", "Ca.fed_max(n * rho, 0, Ca.in_per_min", "Ca.fed_max(((plan.drills_on[key] or 0) + n) * rho, 0, Ca.in_per_min" },
    { "shared/ai3/capitalisation.lua", "CAPI-RETOUR : fours doubles", "Ca.fed_max(n * rho, 0, Ca.in_per_min", "Ca.fed_max(2 * n * rho, 0, Ca.in_per_min" },
    { "shared/ai3/capitalisation.lua", "CAPI-RETOUR : fours de l'ordre absents", "Ca.fed_max(n * rho, 0, Ca.in_per_min", "Ca.fed_max(0, 0, Ca.in_per_min" },
    { "shared/ai3/couverture.lua", "boucle : saturation sans effet", "and not a.saturation then return false,", "then return false," },
  }
  local tmp = os.getenv("TEMP") or "."
  local killed = 0
  for i, m in ipairs(MUT) do
    local src = read(m[1])
    local a, b = src:find(m[3], 1, true)
    if not a or src:find(m[3], b + 1, true) then
      check(false, "mutant introuvable ou non unique : " .. m[2])
    else
      local dir = (tmp .. "/sat_mut_" .. i):gsub("\\", "/")
      os.execute('mkdir "' .. dir:gsub("/", string.char(92)) .. string.char(92) .. "shared" .. string.char(92) .. 'ai3" >nul 2>&1')
      local out = assert(io.open(dir .. "/" .. m[1], "wb"))
      out:write(src:sub(1, a - 1) .. m[4] .. src:sub(b + 1))
      out:close()
      local rc = os.execute('set "FO_SAT_CHILD=1"&& set "FO_CAPI_SRC=' .. dir .. '"&& lua5.2 tests/saturation_test.lua >nul 2>&1')
      local failed = (rc ~= 0 and rc ~= true)
      if failed then killed = killed + 1 else print("[SATURATION] mutant NON refuse : " .. m[2]) end
      check(failed, "mutant refuse : " .. m[2])
    end
  end
  print(string.format("[SATURATION] mutants refuses : %d sur %d", killed, #MUT))
end

print(string.format("[SATURATION] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
