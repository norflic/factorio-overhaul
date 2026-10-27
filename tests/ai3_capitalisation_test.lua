--[[
  Lot CAPI « la capitalisation des factions » : test hors jeu de la règle PURE shared/ai3/capitalisation.lua
  (conception : docs/IA_CAPITALISATION.md). Rien n'est branché en jeu.

    §1 débits sans table : ratios vanilla retrouvés depuis le relevé (foreuses, fours, assembleur, laboratoire, peigne,
       valeurs, combustible) ;
    §2 gisements : couvrir avant d'ouvrir, ouvrir quand les ouverts sont couverts, d'avance (épuisement), explorer sans
       site connu, menace ;
    §3 fours : jamais plus que le minerai arrivé n'en nourrit (50 arrivées de 0,1 à 30 minerais/s), stock résorbé,
       aucun four sans débouché ;
    §4 chaînes : aucune avant l'assembleur recherché, aucune sans exécutant, dès qu'il l'est (packs, engrenages, biens
       d'équipement), ingrédient en manque d'abord (goulot amont) ;
    §5 recherche : les laboratoires grandissent avec la recherche mesurée, jamais plus que les packs ne nourrissent ;
       laboratoires affamés : les packs d'abord ;
    §6 caractère, parts de l'armée et de la défense : s, budget exact, ordres rangés bâtisseur > équilibré > conquérant,
       menace, prix du travail nul avec des bras libres ;
    §7 saturation sans débouché : aucun puits, stock qui dort, minerai sans demande de plaques ;
    §8 données CHANGÉES (même code) : four plus rapide, minerai plus dur, engrenage au cuivre, laboratoire plus rapide,
       et TOUS les noms changés (l'ordre des noms gardé) : mêmes ordres au renommage près ;
    §9 modèle simulé (données jouets, noms inventés) : le capital qui rapporte croît, plafonne quand le gisement est
       couvert, repart à l'ouverture du suivant ; laboratoires qui grandissent ; fours toujours sous l'arrivée ; le
       bâtisseur croît plus vite que le conquérant ;
    §10 déterminisme : deux passages, entrées permutées, relevé dans l'ordre inverse ;
    §11 mutants : chaque règle cassée est vue ; §12 coût de calcul.
  Usage : lua5.2 tests/ai3_capitalisation_test.lua   (depuis la racine du mod)
  Ce fichier est du TEST : il nomme les prototypes vanilla (comme le moteur) ; la règle n'en voit rien.
]]

package.path = "./?.lua;" .. package.path
local F = require("tests.iag_fixture")
local Ca = require("shared.ai3.capitalisation")
local B = require("shared.ai3.buts")
local Tr = require("shared.faction.traits")

local pass, fail = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[CAPI] ECHEC : " .. msg) end
  end
end
local function say(s) if not quiet then print("[CAPI] " .. s) end end

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

--- Entrée de base (vanilla) : de l'assemblage recherché, un capital qui dort au stock (coffres), des bras libres.
local function vin(D, over)
  local inp = { data = D, state = { techs = { automation = true } }, stock = { ["iron-chest"] = 2000 }, flows = {},
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

-- Gisement de fer (minerai livré au QG, fours du QG) et un site connu plus loin.
local function iron_scene(D, sink, over)
  local inp = vin(D, {
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
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 8, where = "d-fe" },
      { entity = "stone-furnace", recipe = "copper-plate", n = 4, where = "d-cu" } },
    flows = { ["iron-plate"] = { made = 150 }, ["copper-plate"] = { made = 75 } },
    labs = { { entity = "lab", n = 8 } },
    research = { queue = { { tech = "electronics", left = 27, time = 15, packs = { { "automation-science-pack", 1 } } },
      { tech = "fast-inserter", left = 2000, time = 15, packs = { { "automation-science-pack", 1 } } } }, rate = 450 } })
  for k, v in pairs(over or {}) do inp[k] = v end
  return inp
end

---------------------------------------------------------------------------------------------------
-- §1 Débits sans table
---------------------------------------------------------------------------------------------------
local function s1()
  local D = vdata()
  local ed, bd = D.drill_by["electric-mining-drill"], D.drill_by["burner-mining-drill"]
  local sf, stf = D.maker_by["stone-furnace"], D.maker_by["steel-furnace"]
  local a1 = D.maker_by["assembling-machine-1"]
  local rp = D.recipes["iron-plate"]
  check(Ca.drill_per_min(D, ed, "iron-ore") == 30 and Ca.drill_per_min(D, bd, "iron-ore") == 15,
    "§1 foreuses : 0,5 et 0,25 minerai/s lus aux vitesses")
  local k_stone, k_steel = Ca.in_per_min(sf, rp, "iron-ore"), Ca.in_per_min(stf, rp, "iron-ore")
  check(math.abs(30 / k_stone - 1.6) < 1e-9, "§1 1,6 four en pierre par foreuse électrique (" .. 30 / k_stone .. ")")
  check(Ca.fed_max(900, 0, k_stone) == 48 and Ca.fed_max(900, 0, k_steel) == 24,
    "§1 30 foreuses (15 minerais/s) : 48 fours en pierre ou 24 en acier")
  check(Ca.out_per_min(a1, D.recipes["automation-science-pack"], "automation-science-pack") == 6,
    "§1 pack rouge : 6/min à l'assembleur de vitesse 0,5")
  check(Ca.lab_per_min(D, D.lab_by["lab"]) / 10 == 6, "§1 laboratoire : 6 unités/min d'une technologie de 10 s")
  local per, cov = Ca.comb(ed)
  local per_b, cov_b = Ca.comb(bd)
  check(per == 13.5 and cov == 13.5 and per_b == 5 and cov_b == 4,
    "§1 peigne : 13,5 tuiles par foreuse électrique, 5 (4 couvertes) à combustion")
  check(math.abs(D.mu["iron-plate"] - 1.32) < 1e-9 and math.abs(D.mu["iron-gear-wheel"] - 2.69) < 1e-9
    and math.abs(Ca.va(D, "iron-plate") - 0.32) < 1e-9,
    string.format("§1 valeurs : plaque %.3f, engrenage %.3f, valeur ajoutée de la fonte %.3f", D.mu["iron-plate"],
      D.mu["iron-gear-wheel"], Ca.va(D, "iron-plate")))
  check(D.fuel == "coal" and math.abs(Ca.fuel_per_min(D, sf) - 1.35) < 1e-9,
    "§1 combustible déduit (" .. tostring(D.fuel) .. "), four en pierre 1,35/min")
  check(a1.assembler and not sf.assembler, "§1 assembleur = fabrique d'une catégorie de la main ; four : non")
  -- Arrondi des machines nourries : famine ≤ 10 % d'une machine, entassement < une machine.
  local ok = true
  for i = 1, 300 do
    local x = i * 0.37
    local n = Ca.fed_max(x, 0, 1)
    if n > x + Ca.FRAC_UP + 1e-9 or x - n >= 1 then ok = false end
  end
  check(ok, "§1 Ca.fed_max : n ≤ x + 0,1 et x − n < 1")
  check(Ca.count(29, 60) == 0 and Ca.count(30, 60) == 1 and Ca.count(95, 60) == 2, "§1 une machine dès une demi-machine")
  say(string.format("§1 vanilla : foreuse électrique 30/min, four 18,75/min, pack rouge 6/min ; MU plaque %.2f engrenage %.2f pack %.2f laboratoire %.2f",
    D.mu["iron-plate"], D.mu["iron-gear-wheel"], D.mu["automation-science-pack"], D.mu["lab"]))
end

---------------------------------------------------------------------------------------------------
-- §2 Gisements
---------------------------------------------------------------------------------------------------
local function s2()
  local D = vdata()
  -- a. Petit manque : couvrir le gisement ouvert, pas ouvrir le suivant.
  local r1 = Ca.decide(iron_scene(D, 150), {})
  local c1 = find(r1, "couvrir:d1")
  check(c1 and c1.n == 3 and c1.entity == "electric-mining-drill", "§2a manque de 90 minerais/min : 3 foreuses sur d1 ("
    .. tostring(c1 and c1.n) .. ")")
  check(find(r1, "ouvrir:s2") == nil, "§2a pas d'ouverture tant que d1 a des places")
  local rf = refus_of(r1, "ouvrir:s2")
  check(rf and rf.why:find("pas couverts", 1, true) ~= nil, "§2a refus écrit : " .. tostring(rf and rf.why))
  check(find(r1, "fours:iron-plate") == nil and (refus_of(r1, "fours:iron-plate") or {}).why ~= nil,
    "§2a fours du QG refusés : le minerai arrivé (60/min) est déjà fondu par 4 fours (75/min)")
  -- b. Gros manque : d1 couvert entièrement, PUIS ouverture de s2 (dans le même cycle).
  local r2 = Ca.decide(iron_scene(D, 1000), {})
  local c2, i_c = find(r2, "couvrir:d1")
  local o2, i_o = find(r2, "ouvrir:s2")
  check(c2 and c2.n == 18, "§2b d1 couvert : 18 foreuses de plus (20 places de 13,5 tuiles sur 270) (" .. tostring(c2 and c2.n) .. ")")
  check(o2 and i_c and i_o and i_o > i_c and o2.n == 13, "§2b puis s2 ouvert, après d1 (13 foreuses pour 400/min) ("
    .. tostring(o2 and o2.n) .. ")")
  local k1 = nil
  for _, c in ipairs(r2.coverage) do if c.id == "d1" then k1 = c.kappa end end
  check(k1 and k1 >= Ca.KAPPA, "§2b couverture de d1 dans le plan : " .. tostring(k1) .. " pour mille")
  check(no_dup(r2), "§2b aucun ordre en double")
  -- c. Épuisement proche : ouvrir d'avance, sans manque.
  local inp_c = iron_scene(D, 60)
  inp_c.deposits[1].amount = 1500
  local r3 = Ca.decide(inp_c, {})
  local o3 = find(r3, "ouvrir:s2")
  check(o3 and o3.n == Ca.OPEN_MIN and (o3.why or ""):find("epuisement", 1, true),
    "§2c d1 épuisé en 25 min : s2 ouvert d'avance (" .. tostring(o3 and o3.why) .. ")")
  -- d. Aucun site connu, d1 couvert : explorer.
  local inp_d = iron_scene(D, 1000)
  inp_d.deposits = { inp_d.deposits[1] }
  inp_d.drills[1].n = 20
  local r4 = Ca.decide(inp_d, {})
  local ex = false
  for _, e in ipairs(r4.explore) do if e.resource == "iron-ore" then ex = true end end
  check(ex and count_kind(r4, "couvrir") == 0 and count_kind(r4, "ouvrir") == 0, "§2d gisement couvert, aucun site : exploration du fer")
  -- e. Menace : leviers hors du QG refusés, retour accepté ÷ 4.
  local inp_e = iron_scene(D, 150)
  inp_e.threat = true
  local r5 = Ca.decide(inp_e, {})
  local rf5 = refus_of(r5, "couvrir:d1")
  check(find(r5, "couvrir:d1") == nil and rf5 and rf5.why:find("menace", 1, true), "§2e menace : couvrir refusé (" .. tostring(rf5 and rf5.why) .. ")")
  check(math.abs(r5.tmax * 4 - r1.tmax) < 1e-9, string.format("§2e menace : retour accepté %.1f -> %.1f min (÷ 4)", r1.tmax, r5.tmax))
  -- f. Un site un peu moins cher (plus proche, bras payés) ne passe pas devant un gisement qui a des places ; 20 % moins
  --    cher par débit, il s'ouvre (le travail d'un chantier lointain coûte cher quand aucun bras n'est libre).
  local function near_site(workers)
    local inp = iron_scene(D, 150, { idle = 0, workers = workers })
    inp.deposits[1].dist, inp.deposits[2].dist = 150, 30
    return Ca.decide(inp, {})
  end
  local r6 = near_site(30)
  check(find(r6, "couvrir:d1") ~= nil and find(r6, "ouvrir:s2") == nil and r6.lambda > 0,
    string.format("§2f site 1 %% moins cher : couvrir d1 d'abord (prix du travail %.1f)", r6.lambda))
  local r7 = near_site(1)
  local o7 = find(r7, "ouvrir:s2")
  check(o7 and (o7.why or ""):find("moins cher", 1, true) and find(r7, "couvrir:d1") == nil,
    string.format("§2f site 20 %% moins cher par débit : ouvert (%s ; prix du travail %.0f)", tostring(o7 and o7.why), r7.lambda))
  -- g. Courant : des foreuses électriques sans courant font d'abord poser une centrale (données de la centrale : runtime).
  local r8 = Ca.decide(iron_scene(D, 150, { power = { have_kw = 0, used_kw = 0, plant = { kw = 1800, burner_kw = 1800,
    items = { { "boiler", 1 }, { "steam-engine", 2 }, { "offshore-pump", 1 } } } } }), {})
  local e8, ie8 = find(r8, "energie")
  local c8, ic8 = find(r8, "couvrir:d1")
  check(e8 and c8 and ie8 < ic8 and c8.n * 90 <= e8.kw, string.format("§2g pas de courant : centrale (%s kW) puis 3 foreuses (%s)",
    tostring(e8 and e8.kw), tostring(c8 and c8.n)))
  say(string.format("§2 couvrir d1 : %d foreuses (T %.2f min, valeur %d) ; gros manque : %d puis ouvrir s2 %d (T %.2f)",
    c1 and c1.n or 0, c1 and c1.T or 0, c1 and c1.value or 0, c2 and c2.n or 0, o2 and o2.n or 0, o2 and o2.T or 0))
  return r1, r2
end

---------------------------------------------------------------------------------------------------
-- §3 Fours : jamais au-delà du minerai arrivé
---------------------------------------------------------------------------------------------------
local function s3()
  local D = vdata()
  local k = 18.75
  local ok, worst = true, ""
  local n_orders = 0
  for i = 1, 50 do
    local A = 6 + (i - 1) * (1800 - 6) / 49 -- 0,1 à 30 minerais/s
    local inp = vin(D, { flows = { ["iron-ore"] = { made = A } }, sinks = { { item = "iron-plate", rate = 1e5 } } })
    local r = Ca.decide(inp, {})
    local o = find(r, "fours:iron-plate")
    local n = o and o.n or 0
    if o then n_orders = n_orders + 1 end
    if n * k > A + Ca.FRAC_UP * k + 1e-9 or A - n * k >= k then
      ok = false
      worst = string.format("arrivée %.1f : %d fours", A, n)
    end
  end
  check(ok and n_orders >= 45, "§3 50 arrivées de 0,1 à 30/s : fours × 18,75 ≤ arrivée + 0,1 four et arrivée − fours < un four (" .. n_orders .. " ordres) " .. worst)
  -- Fours déjà posés : seule l'arrivée restante compte.
  local r2 = Ca.decide(vin(D, { flows = { ["iron-ore"] = { made = 300 } }, sinks = { { item = "iron-plate", rate = 1e5 } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 10, where = "qg" } } }), {})
  local o2 = find(r2, "fours:iron-plate")
  check(o2 and o2.n == 6, "§3 300/min arrivés, 10 fours posés (187,5/min) : 6 de plus (" .. tostring(o2 and o2.n) .. ")")
  -- Stock en retard : résorbé en Ca.H_STOCK minutes, pas plus vite.
  local r3 = Ca.decide(vin(D, { flows = { ["iron-ore"] = { made = 0 } }, stock = { ["iron-ore"] = 1875, ["iron-chest"] = 2000 },
    sinks = { { item = "iron-plate", rate = 1e5 } } }), {})
  local o3 = find(r3, "fours:iron-plate")
  check(o3 and o3.n == 10, "§3 1 875 minerais au coffre, rien n'arrive : 10 fours (le stock fondu en 10 min) (" .. tostring(o3 and o3.n) .. ")")
  -- Aucun débouché : aucun four, même avec du minerai qui s'entasse.
  local r4 = Ca.decide(vin(D, { flows = { ["iron-ore"] = { made = 300 } }, stock = { ["iron-ore"] = 5000, ["iron-chest"] = 2000 } }), {})
  check(find(r4, "fours:iron-plate") == nil and #r4.orders == 0, "§3 minerai qui s'entasse sans demande de plaques : aucun four")
  -- Arrivée nulle : aucun four, refus écrit.
  local r5 = Ca.decide(vin(D, { sinks = { { item = "iron-plate", rate = 100 } } }), {})
  local rf5 = refus_of(r5, "fours:iron-plate")
  check(find(r5, "fours:iron-plate") == nil and rf5 and rf5.why:find("insuffisante", 1, true),
    "§3 aucun minerai arrivé : aucun four (" .. tostring(rf5 and rf5.why) .. ")")
  -- Débouché présent : TOUT le minerai arrivé est fondu (critère (2) du DC : fours au débit du minerai, à 10 % près).
  local r6 = Ca.decide(vin(D, { flows = { ["iron-ore"] = { made = 300 } }, sinks = { { item = "iron-plate", rate = 100 } } }), {})
  local o6 = find(r6, "fours:iron-plate")
  check(o6 and o6.n == 16, "§3 300 minerais/min arrivés, 100 plaques/min demandées : 16 fours (tout le minerai fondu) ("
    .. tostring(o6 and o6.n) .. ")")
  say(string.format("§3 fours : 300/min et 10 posés -> +%d ; 1 875 au coffre -> %d", o2 and o2.n or 0, o3 and o3.n or 0))
end

---------------------------------------------------------------------------------------------------
-- §4 Chaînes d'assemblage
---------------------------------------------------------------------------------------------------
local function s4()
  local D = vdata()
  -- a. Assembleur non recherché : aucune chaîne.
  local inp_a = pack_scene(D, { state = { techs = {} }, flows = { ["iron-plate"] = { made = 150 }, ["copper-plate"] = { made = 75 },
    ["iron-gear-wheel"] = { made = 30, hand = 30 } } })
  local ra = Ca.decide(inp_a, {})
  check(count_kind(ra, "chaine") + count_kind(ra, "packs") == 0, "§4a assembleur non recherché : aucune chaîne")
  local rfa = refus_of(ra, "packs:automation-science-pack")
  check(rfa and rfa.why:find("aucune machine", 1, true), "§4a refus écrit : " .. tostring(rfa and rfa.why))
  -- b. Recherché mais sans exécutant (les exécutants de main aujourd'hui) : aucune chaîne.
  local Dm = vdata(nil, EXEC_MAIN)
  local rb = Ca.decide(pack_scene(Dm), {})
  check(count_kind(rb, "chaine") + count_kind(rb, "packs") == 0, "§4b sans exécutant d'assembleur : aucune chaîne")
  -- c. Recherché et exécutable : engrenages (ingrédient en manque) d'abord, puis les packs.
  local rc = Ca.decide(pack_scene(D), {})
  local og, ig = find(rc, "chaine:iron-gear-wheel")
  local op, ip = find(rc, "packs:automation-science-pack")
  check(og and op and ig < ip, string.format("§4c engrenages (%s) avant packs (%s)", tostring(ig), tostring(ip)))
  check(op and op.n == 5 and op.entity == "assembling-machine-1", "§4c packs : 30/min, 5 assembleurs (" .. tostring(op and op.n) .. ")")
  check(op and op.value >= Ca.V_MIN and og and og.value >= Ca.V_MIN, "§4c valeur des ordres ≥ 35 (travail qui fait recruter)")
  -- d. Plaques en manque : ni engrenages ni packs, l'amont d'abord.
  local inp_d = pack_scene(D, { machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 1, where = "d-fe" },
    { entity = "stone-furnace", recipe = "copper-plate", n = 4, where = "d-cu" } },
    flows = { ["iron-plate"] = { made = 18.75 }, ["copper-plate"] = { made = 75 } } })
  local rd = Ca.decide(inp_d, {})
  local rfg = refus_of(rd, "chaine:iron-gear-wheel")
  check(find(rd, "chaine:iron-gear-wheel") == nil and find(rd, "packs:automation-science-pack") == nil
    and rfg and rfg.why:find("iron-plate d'abord", 1, true),
    "§4d plaques de fer à 18,75/min : aucune chaîne en aval (" .. tostring(rfg and rfg.why) .. ")")
  -- e. Biens d'équipement : les matières d'un ordre ouvert font monter leur chaîne.
  local inp_e = vin(D, { open = { { key = "couvrir:dx", kind = "couvrir", item = "iron-ore", resource = "iron-ore", n = 0,
    missing = { { "pipe", 400 } } } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 8, where = "d-fe" } }, flows = { ["iron-plate"] = { made = 150 } } })
  local re = Ca.decide(inp_e, {})
  local oe = find(re, "chaine:pipe")
  check(oe and oe.n == 1, "§4e 400 tuyaux manquent à un chantier : une rangée d'assembleurs (" .. tostring(oe and oe.n) .. ")")
  -- f. Limite de l'exécutant (rangée à 2 ingrédients au plus) : écrite.
  local inp_f = vin(D, { sinks = { { item = "inserter", rate = 120 } }, limits = { max_ingredients = 2 },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 20, where = "d-fe" } }, flows = { ["iron-plate"] = { made = 375 } } })
  local rf = Ca.decide(inp_f, {})
  local rff = refus_of(rf, "chaine:inserter")
  check(find(rf, "chaine:inserter") == nil and rff and rff.why:find("ingredients", 1, true), "§4f limite de l'exécutant : " .. tostring(rff and rff.why))
  -- g. Courant : 100 kW pour 6 assembleurs de 75 kW : les engrenages passent, la centrale avant les packs.
  local rg = Ca.decide(pack_scene(D, { power = { have_kw = 100, used_kw = 0, plant = { kw = 1800, burner_kw = 1800,
    items = { { "boiler", 1 }, { "steam-engine", 2 }, { "offshore-pump", 1 } } } } }), {})
  local eg, ieg = find(rg, "energie")
  local pg, ipg = find(rg, "packs:automation-science-pack")
  local kw = 0
  for _, o in ipairs(rg.orders) do if o.kind == "chaine" or o.kind == "packs" then kw = kw + o.n * 75 end end
  check(eg and pg and ieg < ipg and kw <= 100 + eg.kw, string.format("§4g courant : centrale (%s kW) avant les packs, %d kW posés",
    tostring(eg and eg.kw), kw))
  say(string.format("§4 engrenages %d (T %.2f), packs %d (T %.2f) ; tuyaux %d", og and og.n or 0, og and og.T or 0,
    op and op.n or 0, op and op.T or 0, oe and oe.n or 0))
  return rc
end

---------------------------------------------------------------------------------------------------
-- §5 Recherche
---------------------------------------------------------------------------------------------------
local function s5()
  local D = vdata()
  local function scene(rate, labs, machines, pack_stock, starved)
    return pack_scene(D, { flows = { ["iron-plate"] = { made = 150 }, ["copper-plate"] = { made = 75 },
      ["automation-science-pack"] = { made = 6 * machines } },
      stock = { ["automation-science-pack"] = pack_stock, ["iron-chest"] = 2000 },
      machines = { { entity = "assembling-machine-1", recipe = "automation-science-pack", n = machines, where = "qg" },
        { entity = "stone-furnace", recipe = "iron-plate", n = 8, where = "d-fe" } },
      labs = { { entity = "lab", n = labs } }, research = { queue = { { tech = "fast-inserter", left = 1e5, time = 15,
        packs = { { "automation-science-pack", 1 } } } }, rate = rate, starved = starved } })
  end
  --- `n` cycles du même état (la recherche visée grandit d'un cycle à l'autre, état persistant) : le dernier résultat
  --- et la recherche visée de chaque cycle.
  local function cycles(make, n)
    local st, r, u = {}, nil, {}
    for c = 1, n do
      r = Ca.decide(make(), st)
      u[c] = r.u_star
    end
    return r, u
  end
  local r1, u1 = cycles(function() return scene(120, 2, 34, 2000) end, 4)
  local r2, u2 = cycles(function() return scene(1200, 20, 34, 2000) end, 4)
  local l1, l2 = find(r1, "labos:lab"), find(r2, "labos:lab")
  check(r2.labs_target > r1.labs_target and l1 and l2 and l2.n > l1.n,
    string.format("§5 recherche mesurée 120 -> 1 200 s/min : laboratoires visés %d -> %d, ordres %s -> %s", r1.labs_target,
      r2.labs_target, tostring(l1 and l1.n), tostring(l2 and l2.n)))
  check(u2[4] > u2[1] and u2[1] >= 1200, string.format("§5 recherche visée qui grandit : %.0f -> %.0f s/min en 4 cycles", u2[1], u2[4]))
  -- Jamais plus que les packs ne nourrissent : 11 assembleurs (66 packs/min) pour 15 laboratoires qui en mangent 60.
  local r3 = cycles(function() return scene(900, 15, 11, 0) end, 4)
  local l3 = find(r3, "labos:lab")
  local packs_new = 0
  for _, o in ipairs(r3.orders) do if o.key == "packs:automation-science-pack" then packs_new = packs_new + o.n end end
  local cap = math.floor((11 + packs_new) * 6 / 4 + Ca.FRAC_UP) -- 4 packs/min par laboratoire (technologie de 15 s)
  check(r3.labs_target > cap and (15 + (l3 and l3.n or 0)) <= cap,
    string.format("§5 laboratoires (15 + %d) ≤ ce que les packs nourrissent (%d), %d visés", l3 and l3.n or 0, cap, r3.labs_target))
  -- Laboratoires affamés : les packs d'abord.
  local r4 = cycles(function() return scene(1200, 20, 34, 2000, 300) end, 4)
  local rf4 = refus_of(r4, "labos:lab")
  check(find(r4, "labos:lab") == nil and rf4 and rf4.why:find("affames", 1, true),
    "§5 laboratoires affamés : aucun de plus (" .. tostring(rf4 and rf4.why) .. ")")
  say(string.format("§5 laboratoires visés : %d (120 s/min) et %d (1 200 s/min) ; recherche visée %.0f -> %.0f ; packs : %d visés, %d nourris",
    r1.labs_target, r2.labs_target, u2[1], u2[4], r3.labs_target, cap))
end

---------------------------------------------------------------------------------------------------
-- §6 Caractère, parts de l'armée et de la défense
---------------------------------------------------------------------------------------------------
local function s6()
  local D = vdata()
  local function scene(arch, threat)
    local tr = Tr.ARCHETYPES[arch]
    local inp = iron_scene(D, 1000, { stock = {}, flows = { ["iron-ore"] = { made = 600 } }, traits = tr,
      weights = B.weights(nil, tr), threat = threat })
    return inp
  end
  local res = {}
  for _, a in ipairs({ "builder", "technocrat", "balanced", "conqueror" }) do res[a] = Ca.decide(scene(a), {}) end
  check(res.builder.s > res.technocrat.s and res.technocrat.s > res.balanced.s and res.balanced.s > res.conqueror.s,
    string.format("§6 part réinvestie : bâtisseur %d > technocrate %d > équilibré %d > conquérant %d", res.builder.s,
      res.technocrat.s, res.balanced.s, res.conqueror.s))
  check(res.conqueror.alpha > res.balanced.alpha and res.balanced.alpha > res.builder.alpha,
    string.format("§6 part de l'armée : conquérant %d > équilibré %d > bâtisseur %d", res.conqueror.alpha, res.balanced.alpha, res.builder.alpha))
  local ok_budget, ok_spent = true, true
  for _, a in ipairs({ "builder", "technocrat", "balanced", "conqueror" }) do
    local r = res[a]
    local expect = r.s / 1000 * (600 * (1000 - r.delta - r.alpha) / 1000)
    if math.abs(r.budget - expect) > 1e-6 then ok_budget = false end
    if sum_cost(r) > r.budget + 1e-6 then ok_spent = false end
  end
  check(ok_budget, "§6 budget = s × production libre des parts défense et armée (aucun stock)")
  check(ok_spent, "§6 matières engagées ≤ budget (les 4 caractères)")
  local cb, ce, cc = sum_cost(res.builder), sum_cost(res.balanced), sum_cost(res.conqueror)
  check(cb > ce and ce > cc and cc > 0, string.format("§6 engagé : bâtisseur %.0f > équilibré %.0f > conquérant %.0f MU", cb, ce, cc))
  local o = find(res.balanced, "couvrir:d1")
  check(o and o.n < 18, "§6 le budget règle la taille : " .. tostring(o and o.n) .. " foreuses sur 18 places")
  -- Menace : défense doublée, retour ÷ 4.
  local rt = Ca.decide(scene("balanced", true), {})
  check(rt.delta >= 2 * res.balanced.delta and math.abs(rt.tmax * 4 - res.balanced.tmax) < 1e-9 and rt.budget < res.balanced.budget,
    string.format("§6 menace : défense %d -> %d, retour %.1f -> %.1f min, budget %.0f -> %.0f", res.balanced.delta, rt.delta,
      res.balanced.tmax, rt.tmax, res.balanced.budget, rt.budget))
  -- Prix du travail : nul avec des bras libres, positif sans.
  local inp_l = scene("balanced")
  local rl0 = Ca.decide(inp_l, {})
  inp_l.idle = 0
  local rl1 = Ca.decide(inp_l, {})
  check(rl0.lambda == 0 and rl1.lambda > 0, string.format("§6 prix du travail : %.2f avec des bras libres, %.2f sans", rl0.lambda, rl1.lambda))
  -- Valeur des ordres : 35 à 90.
  local okv = true
  for _, a in ipairs(sorted_keys(res)) do for _, x in ipairs(res[a].orders) do
    if x.value < Ca.V_MIN or x.value > Ca.V_MAX then okv = false end
  end end
  check(okv, "§6 valeur de chaque ordre entre 35 et 90")
  -- Buts du cerveau : un par ordre, sans fonction (état sérialisable).
  local goals = Ca.goals({}, res.builder)
  local okg = #goals == #res.builder.orders
  for _, g in ipairs(goals) do for _, k in ipairs(sorted_keys(g.order)) do if type(g.order[k]) == "function" then okg = false end end end
  check(okg and goals[1] and goals[1].family == "capital", "§6 buts du cerveau : un par ordre, famille capital, sans fonction")
  say(string.format("§6 budget (MU) : bâtisseur %.0f, technocrate %.0f, équilibré %.0f, conquérant %.0f ; engagé %.0f, %.0f, %.0f",
    res.builder.budget, res.technocrat.budget, res.balanced.budget, res.conqueror.budget, cb, ce, cc))
end

---------------------------------------------------------------------------------------------------
-- §7 Saturation sans débouché
---------------------------------------------------------------------------------------------------
local function s7()
  local D = vdata()
  -- Aucun puits : aucune croissance, aucun ordre (saturation globale).
  local r1 = Ca.decide(vin(D, { flows = { ["iron-ore"] = { made = 300 } },
    deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 2, deposit = "d1" } } }), {})
  check(#r1.orders == 0 and r1.g == 0, "§7 aucun puits : aucun ordre, croissance nulle (" .. #r1.orders .. ", g " .. r1.g .. ")")
  -- Stock qui dort : 50 000 plaques couvrent 100/min pendant bien plus de 10 min : rien en amont.
  local inp2 = iron_scene(D, 100, { stock = { ["iron-plate"] = 50000, ["iron-chest"] = 2000 } })
  local r2 = Ca.decide(inp2, {})
  check(find(r2, "couvrir:d1") == nil and find(r2, "fours:iron-plate") == nil, "§7 50 000 plaques au coffre : ni foreuse ni four")
  -- Le même sans le stock : on investit (témoin).
  local r3 = Ca.decide(iron_scene(D, 100), {})
  check(find(r3, "couvrir:d1") ~= nil, "§7 témoin sans stock : couvrir d1")
end

---------------------------------------------------------------------------------------------------
-- §8 Données changées, même code
---------------------------------------------------------------------------------------------------
local RENAME_FIELDS = nil
local function rename_all(d, map)
  local function m(x) return (type(x) == "string" and map[x]) or x end
  local nd = { recipes = {}, techs = {}, entities = {}, resources = {}, items = {} }
  for _, rn in ipairs(sorted_keys(d.recipes)) do
    local r = deep(d.recipes[rn])
    r.category = m(r.category)
    for _, i in ipairs(r.ingredients or {}) do i.name = m(i.name) end
    for _, p in ipairs(r.products or {}) do p.name = m(p.name) end
    nd.recipes[m(rn)] = r
  end
  for _, tn in ipairs(sorted_keys(d.techs)) do
    local t = deep(d.techs[tn])
    for i, x in ipairs(t.prerequisites or {}) do t.prerequisites[i] = m(x) end
    for i, x in ipairs(t.unlocks or {}) do t.unlocks[i] = m(x) end
    for _, x in ipairs(t.ingredients or {}) do x[1] = m(x[1]) end
    nd.techs[m(tn)] = t
  end
  for _, e0 in ipairs(d.entities) do
    local e = deep(e0)
    e.name, e.item = m(e.name), m(e.item)
    for i, c in ipairs(e.crafting_categories or {}) do e.crafting_categories[i] = m(c) end
    for i, c in ipairs(e.resource_categories or {}) do e.resource_categories[i] = m(c) end
    for i, c in ipairs(e.lab_inputs or {}) do e.lab_inputs[i] = m(c) end
    nd.entities[#nd.entities + 1] = e
  end
  for _, r0 in ipairs(d.resources) do
    local r = deep(r0)
    r.entity, r.category = m(r.entity), m(r.category)
    for _, p in ipairs(r.products or {}) do p.name = m(p.name) end
    nd.resources[#nd.resources + 1] = r
  end
  for _, k in ipairs(sorted_keys(d.items)) do nd.items[m(k)] = deep(d.items[k]) end
  return nd
end
local function name_map(d)
  local names = {}
  local function n(x) if type(x) == "string" then names[x] = true end end
  for rn, r in pairs(d.recipes) do
    n(rn) n(r.category)
    for _, i in ipairs(r.ingredients or {}) do n(i.name) end
    for _, p in ipairs(r.products or {}) do n(p.name) end
  end
  for tn, t in pairs(d.techs) do
    n(tn)
    for _, x in ipairs(t.prerequisites or {}) do n(x) end
    for _, x in ipairs(t.unlocks or {}) do n(x) end
    for _, x in ipairs(t.ingredients or {}) do n(x[1]) end
  end
  for _, e in ipairs(d.entities) do
    n(e.name) n(e.item)
    for _, c in ipairs(e.crafting_categories or {}) do n(c) end
    for _, c in ipairs(e.resource_categories or {}) do n(c) end
    for _, c in ipairs(e.lab_inputs or {}) do n(c) end
  end
  for _, r in ipairs(d.resources) do
    n(r.entity) n(r.category)
    for _, p in ipairs(r.products or {}) do n(p.name) end
  end
  for k in pairs(d.items) do n(k) end
  local list = sorted_keys(names)
  local map = {}
  for i, x in ipairs(list) do map[x] = string.format("z%05d", i) end -- l'ordre des noms est gardé
  return map
end
local function rename_input(inp, map, D2)
  local function m(x) return (type(x) == "string" and map[x]) or x end
  local function keys(t) local o = {} for _, k in ipairs(sorted_keys(t)) do o[m(k)] = deep(t[k]) end return o end
  local o = deep(inp)
  o.data = D2
  o.state = { techs = keys(inp.state.techs) }
  o.stock, o.flows = keys(inp.stock), keys(inp.flows)
  for _, x in ipairs(o.machines or {}) do x.entity, x.recipe = m(x.entity), m(x.recipe) end
  for _, x in ipairs(o.drills or {}) do x.entity, x.resource = m(x.entity), m(x.resource) end
  for _, x in ipairs(o.labs or {}) do x.entity = m(x.entity) end
  for _, x in ipairs(o.deposits or {}) do x.resource, x.smelt, x.smelter = m(x.resource), m(x.smelt), m(x.smelter) end
  for _, x in ipairs(o.sinks or {}) do x.item = m(x.item) end
  if o.research then
    for _, q in ipairs(o.research.queue or {}) do
      q.tech = m(q.tech)
      for _, p in ipairs(q.packs or {}) do p[1] = m(p[1]) end
    end
  end
  return o
end

--- Scène riche : fer (gisement + site), cuivre avec fonte sur place, charbon, recherche aux packs rouges.
local function rich(D, over)
  local inp = pack_scene(D, {
    deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60 },
      { id = "s2", resource = "iron-ore", tiles = 270, amount = 1e6, dist = 150 },
      { id = "dc", resource = "copper-ore", tiles = 200, amount = 5e5, open = true, dist = 80, smelt = "copper-plate",
        smelter = "stone-furnace" },
      { id = "dk", resource = "coal", tiles = 200, amount = 5e5, open = true, dist = 50 } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 4, deposit = "d1" },
      { entity = "burner-mining-drill", resource = "copper-ore", n = 4, deposit = "dc" },
      { entity = "burner-mining-drill", resource = "coal", n = 2, deposit = "dk" } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 6, where = "qg" },
      { entity = "stone-furnace", recipe = "iron-plate", n = 8, where = "d1" },
      { entity = "stone-furnace", recipe = "copper-plate", n = 4, where = "dc" } },
    flows = { ["iron-ore"] = { made = 120 }, ["iron-plate"] = { made = 110 }, ["copper-plate"] = { made = 60 },
      ["coal"] = { made = 30 }, ["iron-gear-wheel"] = { made = 20, hand = 20 } },
    sinks = { { item = "firearm-magazine", rate = 20, elastic = true } } })
  for k, v in pairs(over or {}) do inp[k] = v end
  return inp
end

local function orders_sig(res, unmap)
  local t = {}
  for _, o in ipairs(res.orders) do
    local item = o.item
    if unmap and item then item = unmap[item] or item end
    t[#t + 1] = string.format("%s|%s|%d|%.6f", o.kind, tostring(item), o.n or 0, o.T)
  end
  return table.concat(t, ";")
end

local function s8()
  -- a. Four en acier deux fois plus rapide : deux fois moins de fours pour la même arrivée.
  local Df = vdata(function(d) for _, e in ipairs(d.entities) do if e.name == "steel-furnace" then e.speed = 4 end end end)
  local k4 = Ca.in_per_min(Df.maker_by["steel-furnace"], Df.recipes["iron-plate"], "iron-ore")
  check(Ca.fed_max(900, 0, k4) == 12, "§8a four en acier à vitesse 4 : 12 fours pour 900/min (24 en vanilla)")
  -- b. Minerai deux fois plus dur : deux fois plus de foreuses pour le même manque.
  local Dm = vdata(function(d) for _, r in ipairs(d.resources) do if r.entity == "iron-ore" then r.mining_time = 2 end end end)
  local inp_b = iron_scene(Dm, 150)
  inp_b.flows["iron-ore"].made = 30
  local rb = Ca.decide(inp_b, {})
  local ob = find(rb, "couvrir:d1")
  check(ob and ob.n == 8, "§8b fer deux fois plus dur (temps 2) : 8 foreuses pour 120/min manquants (vanilla 3 pour 90) (" .. tostring(ob and ob.n) .. ")")
  -- c. L'engrenage demande du cuivre : le besoin de plaques de cuivre monte (graphe des recettes).
  local Dv = vdata()
  local Dc = vdata(function(d)
    local g = d.recipes["iron-gear-wheel"]
    g.ingredients[#g.ingredients + 1] = { type = "item", name = "copper-plate", amount = 1 }
  end)
  local rv, rc = Ca.decide(pack_scene(Dv), {}), Ca.decide(pack_scene(Dc), {})
  check((rc.R["copper-plate"] or 0) > (rv.R["copper-plate"] or 0) + 1,
    string.format("§8c engrenage au cuivre : besoin de cuivre %.0f -> %.0f /min", rv.R["copper-plate"] or 0, rc.R["copper-plate"] or 0))
  -- d. Laboratoire deux fois plus rapide : deux fois moins de laboratoires visés.
  local Dl = vdata(function(d) for _, e in ipairs(d.entities) do if e.name == "lab" then e.speed = 2 end end end)
  local rl = Ca.decide(pack_scene(Dl), {})
  local rl0 = Ca.decide(pack_scene(Dv), {})
  check(rl.labs_target * 2 <= rl0.labs_target + 1 and rl.labs_target < rl0.labs_target,
    string.format("§8d laboratoire à vitesse 2 : %d laboratoires visés (vanilla %d)", rl.labs_target, rl0.labs_target))
  -- e. TOUS les noms changés (l'ordre des noms gardé) : mêmes ordres au renommage près.
  local d0 = vanilla_dump()
  local map = name_map(d0)
  local unmap = {}
  for _, k in ipairs(sorted_keys(map)) do unmap[map[k]] = k end
  local d2 = rename_all(d0, map)
  local exec2 = {}
  for _, k in ipairs(sorted_keys(EXEC_AUTO)) do exec2[map[k]] = true end
  local D0 = Ca.data(d0, { exec = EXEC_AUTO, exec_roles = ROLES })
  local D2 = Ca.data(d2, { exec = exec2, exec_roles = ROLES })
  local inp0 = rich(D0)
  local r0 = Ca.decide(inp0, {})
  local r2 = Ca.decide(rename_input(inp0, map, D2), {})
  local s0, s2 = orders_sig(r0), orders_sig(r2, unmap)
  check(#r0.orders >= 3 and s0 == s2, "§8e noms changés : mêmes ordres (" .. #r0.orders .. " ordres)" .. (s0 == s2 and "" or (" : " .. s0 .. " / " .. s2)))
  local renamed_fuel = D2.fuel and unmap[D2.fuel]
  check(renamed_fuel == D0.fuel, "§8e combustible retrouvé sous un autre nom (" .. tostring(D2.fuel) .. ")")
  say("§8e scène riche (vanilla) : " .. Ca.text(r0))
end

---------------------------------------------------------------------------------------------------
-- §9 Modèle simulé : le capital qui rapporte (données jouets, noms inventés)
---------------------------------------------------------------------------------------------------
local function I(name, n) return { type = "item", name = name, amount = n } end
local function toy_dump()
  local function it() return { type = "item" } end
  return {
    entities = {
      { name = "corps", type = "character", crafting_categories = { "etabli" }, resource_categories = { "sol" } },
      { name = "excavatrice", type = "mining-drill", item = "excavatrice", resource_categories = { "sol" }, speed = 0.5,
        mining_area = 5, size = 3, energy = "none" },
      { name = "creuset", type = "furnace", item = "creuset", crafting_categories = { "chauffe" }, speed = 1, size = 2,
        energy = "none" },
      { name = "atelier", type = "assembling-machine", item = "atelier", crafting_categories = { "etabli" }, speed = 0.5,
        size = 3, energy = "none" },
      { name = "savant", type = "lab", item = "savant", lab_inputs = { "fiole" }, speed = 1, size = 3, energy = "none" },
    },
    resources = { { entity = "filon", category = "sol", mining_time = 1, products = { I("roche", 1) } } },
    items = { roche = it(), lingot = it(), rouage = it(), fiole = it(), excavatrice = it(), creuset = it(), atelier = it(),
      savant = it() },
    recipes = {
      lingot = { category = "chauffe", energy = 3.2, ingredients = { I("roche", 1) }, products = { I("lingot", 1) } },
      rouage = { category = "etabli", energy = 0.5, ingredients = { I("lingot", 2) }, products = { I("rouage", 1) } },
      fiole = { category = "etabli", energy = 5, ingredients = { I("lingot", 1), I("rouage", 1) }, products = { I("fiole", 1) } },
      excavatrice = { category = "etabli", energy = 2, ingredients = { I("rouage", 5), I("lingot", 10) }, products = { I("excavatrice", 1) } },
      creuset = { category = "etabli", energy = 0.5, ingredients = { I("roche", 5) }, products = { I("creuset", 1) } },
      atelier = { category = "etabli", energy = 0.5, ingredients = { I("rouage", 5), I("lingot", 9) }, products = { I("atelier", 1) },
        enabled = false },
      savant = { category = "etabli", energy = 2, ingredients = { I("rouage", 10), I("fiole", 5) }, products = { I("savant", 1) } },
    },
    techs = { mecanique = { count = 10, time = 10, ingredients = { { "fiole", 1 } }, prerequisites = {}, unlocks = { "atelier" } } },
  }
end

--- Une partie jouet de `minutes` minutes. Monde : gisement g1 (405 tuiles : 30 excavatrices), g2 connu à la minute
--- `site2` ; production minute par minute (foreuses, creusets, ateliers, savants), stocks plafonnés en aval ; les
--- ordres se paient en lingots (MU ÷ MU du lingot), pris au coffre au-dessus d'une réserve, et se posent la minute
--- suivante (payés après la fonte, avant l'aval). Rend l'historique { K, ore, labs, furnaces, orders }, les écarts au plafond des fours et le dernier
--- résultat.
local function sim(opts)
  opts = opts or {}
  local D = Ca.data(toy_dump(), {})
  local MIN, SITE2 = opts.minutes or 150, opts.site2 or 100
  local W = { stock = { lingot = 400, rouage = 50, fiole = 30, roche = 0 },
    deposits = { { id = "g1", resource = "roche", tiles = 405, amount = 3e6, dist = 40 } },
    drills = { g1 = 2 }, furnaces = 3, asm = { rouage = 1, fiole = 1 }, labs = 1, pending = {} }
  local st, H, viol = {}, {}, 0
  local mu_l = D.mu.lingot
  local made = { roche = 0, lingot = 0, rouage = 0, fiole = 0 }
  local lab_s = 0
  local last
  local function install(o)
    if o.kind == "couvrir" or o.kind == "ouvrir" then
      W.drills[o.deposit] = (W.drills[o.deposit] or 0) + o.n
    elseif o.kind == "fours" then W.furnaces = W.furnaces + o.n
    elseif o.kind == "chaine" or o.kind == "packs" then W.asm[o.item] = (W.asm[o.item] or 0) + o.n
    elseif o.kind == "labos" then W.labs = W.labs + o.n end
  end
  for t = 1, MIN do
    if t == SITE2 then W.deposits[#W.deposits + 1] = { id = "g2", resource = "roche", tiles = 405, amount = 3e6, dist = 120 } end
    -- Pose de ce qui est payé.
    local keep = {}
    for _, o in ipairs(W.pending) do
      if o.paid >= o.need and o.ready <= t then install(o) else keep[#keep + 1] = o end
    end
    W.pending = keep
    -- Une minute de production, de l'amont vers l'aval.
    made = { roche = 0, lingot = 0, rouage = 0, fiole = 0 }
    for _, f in ipairs(W.deposits) do
      local x = math.min((W.drills[f.id] or 0) * 30, f.amount)
      f.amount = f.amount - x
      made.roche = made.roche + x
    end
    local S = W.stock
    S.roche = S.roche + made.roche
    local x = math.min(W.furnaces * 18.75, S.roche)
    S.roche, S.lingot, made.lingot = S.roche - x, S.lingot + x, x
    -- Paiement des ordres en attente AVANT la consommation de l'aval (la matière de l'investissement est réservée,
    -- comme le fait le cerveau : P.take), au plus la moitié des lingots du coffre.
    local budget_l = math.floor(S.lingot / 2)
    for _, o in ipairs(W.pending) do
      local pay = math.max(0, math.min(o.need - o.paid, budget_l))
      o.paid, S.lingot, budget_l = o.paid + pay, S.lingot - pay, budget_l - pay
    end
    -- Aval : les fioles d'abord (rouages du coffre), puis les rouages refont le coffre jusqu'à son plafond (des coffres
    -- à la mesure des machines qu'ils nourrissent : 2 min de consommation).
    local lim_r, lim_f = 300 + 12 * (W.asm.fiole or 0), 300 + 12 * W.labs
    x = math.min((W.asm.fiole or 0) * 6, S.lingot, S.rouage, math.max(0, lim_f - S.fiole))
    S.lingot, S.rouage, S.fiole, made.fiole = S.lingot - x, S.rouage - x, S.fiole + x, x
    x = math.min(W.asm.rouage * 60, math.floor(S.lingot / 2), math.max(0, lim_r - S.rouage))
    S.lingot, S.rouage, made.rouage = S.lingot - 2 * x, S.rouage + x, x
    lab_s = math.min(W.labs * 60, S.fiole * 10)
    S.fiole = S.fiole - lab_s / 10
    -- Décision.
    local machines = { { entity = "creuset", recipe = "lingot", n = W.furnaces, where = "qg" },
      { entity = "atelier", recipe = "rouage", n = W.asm.rouage, where = "qg" },
      { entity = "atelier", recipe = "fiole", n = W.asm.fiole or 0, where = "qg" } }
    local drills, deps = {}, {}
    for _, f in ipairs(W.deposits) do
      local n = W.drills[f.id] or 0
      if n > 0 then drills[#drills + 1] = { entity = "excavatrice", resource = "roche", n = n, deposit = f.id } end
      deps[#deps + 1] = { id = f.id, resource = f.resource, tiles = f.tiles, amount = f.amount, dist = f.dist, open = n > 0 }
    end
    local open = {}
    for _, o in ipairs(W.pending) do
      local c = {}
      for _, k in ipairs({ "kind", "key", "item", "resource", "recipe", "entity", "n", "deposit", "where" }) do c[k] = o[k] end
      c.missing = o.need > o.paid and { { "lingot", o.need - o.paid } } or nil
      open[#open + 1] = c
    end
    local stock = {}
    for _, k in ipairs(sorted_keys(S)) do stock[k] = S[k] end
    local input = { data = D, state = { techs = { mecanique = true } }, stock = stock,
      flows = { roche = { made = made.roche }, lingot = { made = made.lingot }, rouage = { made = made.rouage },
        fiole = { made = made.fiole } },
      machines = machines, drills = drills, labs = { { entity = "savant", n = W.labs } }, deposits = deps, open = open,
      research = { queue = { { tech = "infini", left = 1e7, time = 10, packs = { { "fiole", 1 } } } }, rate = lab_s },
      workers = 30, idle = 10, can_grow = false, traits = opts.traits or {}, weights = opts.weights or {} }
    local res = Ca.decide(input, st)
    last = res
    -- Contrôle : un ordre de fours ne dépasse jamais ce que le minerai arrivé nourrit.
    local supply = made.roche + S.roche / Ca.H_STOCK
    local planned = W.furnaces
    for _, o in ipairs(W.pending) do if o.kind == "fours" then planned = planned + o.n end end
    for _, o in ipairs(res.orders) do
      if o.kind == "fours" then
        planned = planned + o.n
        if planned * 18.75 > supply + Ca.FRAC_UP * 18.75 + 1e-6 then viol = viol + 1 end
      end
    end
    -- Paiement en lingots, dans l'ordre.
    for _, o in ipairs(res.orders) do
      local c = {}
      for _, k in ipairs({ "kind", "key", "item", "resource", "recipe", "entity", "n", "deposit", "where" }) do c[k] = o[k] end
      c.need, c.paid, c.ready = math.ceil(o.cost_m / mu_l), 0, t + 1
      W.pending[#W.pending + 1] = c
    end
    local ore = 0
    for _, f in ipairs(W.deposits) do ore = ore + (W.drills[f.id] or 0) * 30 end
    local ex = false
    for _, e in ipairs(res.explore) do if e.resource == "roche" then ex = true end end
    local kinds = {}
    for _, o in ipairs(res.orders) do kinds[#kinds + 1] = o.key end
    H[t] = { K = res.K, ore = ore, labs = W.labs, furnaces = W.furnaces, keys = table.concat(kinds, ","), explore = ex,
      lab_s = lab_s, g1 = W.drills.g1 or 0, g2 = W.drills.g2 or 0, Y = res.Y }
    if os.getenv("CAPI_DEBUG") and not quiet and t % 10 == 0 then -- diagnostic : CAPI_DEBUG=1 lua5.2 tests/…
      print(string.format("[CAPI-SIM] t=%d creusets %d ateliers rouage %d fiole %d savants %d ; coffre lingot %.0f rouage %.0f fiole %.0f roche %.0f ; fait roche %.0f lingot %.0f rouage %.0f fiole %.0f recherche %.0f",
        t, W.furnaces, W.asm.rouage, W.asm.fiole or 0, W.labs, S.lingot, S.rouage, S.fiole, S.roche, made.roche, made.lingot,
        made.rouage, made.fiole, lab_s))
      print("[CAPI-SIM]   " .. Ca.text(res))
    end
  end
  return H, viol, last
end

local function s9()
  local H, viol = sim()
  check(viol == 0, "§9 fours toujours sous le minerai arrivé (" .. viol .. " écart(s))")
  check(H[40].K >= 2 * H[10].K, string.format("§9 le capital qui rapporte croît : K %.0f (10 min) -> %.0f (40 min) MU/min", H[10].K, H[40].K))
  -- Plafond : g1 couvert, plus de capacité d'extraction jusqu'au site suivant.
  local full = nil
  for t = 1, 79 do if H[t].g1 >= 30 and not full then full = t end end
  check(full ~= nil and full < 70, "§9 g1 couvert (30 foreuses) à la minute " .. tostring(full))
  local flat, explored = full ~= nil, false
  if full then
    for t = full, 79 do
      if H[t].ore ~= H[full].ore then flat = false end
      if H[t].explore then explored = true end
    end
  end
  check(flat and explored, "§9 plafond : extraction constante de la couverture de g1 à la minute 79, exploration demandée")
  local opened = nil
  for t = 80, 120 do if not opened and H[t].keys:find("ouvrir:g2", 1, true) then opened = t end end
  check(opened ~= nil and H[120].ore > H[79].ore and H[120].K > H[79].K * 1.2,
    string.format("§9 g2 ouvert à la minute %s ; extraction %d -> %d, K %.0f -> %.0f", tostring(opened), H[79].ore, H[120].ore,
      H[79].K, H[120].K))
  check(H[60].labs >= 5 * H[1].labs and H[60].lab_s > 5 * H[5].lab_s,
    string.format("§9 laboratoires %d -> %d, recherche %.0f -> %.0f s/min", H[1].labs, H[60].labs, H[5].lab_s, H[60].lab_s))
  -- Doublement mesuré du capital sur la montée (après l'amorçage de la recherche) : le capital rapporte, il se double
  -- en moins de 15 min (la règle vise g = s ÷ T̄ par minute, soit 100 pour mille à s = 500 : 7,3 min sans retard de pose).
  local t2 = nil
  for t = 41, 79 do if not t2 and H[t].K >= 2 * H[40].K then t2 = t end end
  check(t2 ~= nil and t2 - 40 <= 15, "§9 doublement du capital depuis 40 min en " .. tostring(t2 and (t2 - 40)) .. " min")
  -- Caractère : le bâtisseur croît plus vite que le conquérant.
  local Hb = sim({ traits = Tr.ARCHETYPES.builder, weights = B.weights(nil, Tr.ARCHETYPES.builder), minutes = 50 })
  local Hc = sim({ traits = Tr.ARCHETYPES.conqueror, weights = B.weights(nil, Tr.ARCHETYPES.conqueror), minutes = 50 })
  check(Hb[40].K > Hc[40].K * 1.1, string.format("§9 bâtisseur %.0f > conquérant %.0f MU/min à 40 min", Hb[40].K, Hc[40].K))
  say(string.format("§9 K (MU/min) : %.0f, %.0f, %.0f, %.0f, %.0f, %.0f aux minutes 1, 10, 20, 40, 79, 120 ; doublement depuis 40 min en %s min ; g1 couvert à %s, g2 ouvert à %s",
    H[1].K, H[10].K, H[20].K, H[40].K, H[79].K, H[120].K, t2 and tostring(t2 - 40) or "-", tostring(full), tostring(opened)))
  say(string.format("§9 à 120 min : %d foreuses (g1 %d, g2 %d), %d creusets, %d savants ; bâtisseur %.0f, conquérant %.0f à 40 min",
    H[120].ore / 30, H[120].g1, H[120].g2, H[120].furnaces, H[120].labs, Hb[40].K, Hc[40].K))
  return H
end

---------------------------------------------------------------------------------------------------
-- §10 Déterminisme
---------------------------------------------------------------------------------------------------
local function rev(l) local o = {} for i = #l, 1, -1 do o[#o + 1] = l[i] end return o end
local function s10()
  local D = vdata()
  local a = Ca.text(Ca.decide(rich(D), {}))
  local b = Ca.text(Ca.decide(rich(D), {}))
  check(a == b, "§10 deux passages identiques")
  local p = rich(D)
  p.machines, p.drills, p.deposits, p.labs, p.sinks = rev(p.machines), rev(p.drills), rev(p.deposits), rev(p.labs), rev(p.sinks)
  check(Ca.text(Ca.decide(p, {})) == a, "§10 entrées dans un autre ordre : même plan")
  local Dr = Ca.data(vanilla_dump(nil, { reverse = true }), { exec = EXEC_AUTO, exec_roles = ROLES })
  check(Ca.text(Ca.decide(rich(Dr), {})) == a, "§10 relevé dans l'ordre inverse : même plan")
end

---------------------------------------------------------------------------------------------------
-- Exécution
---------------------------------------------------------------------------------------------------
local function run_all()
  s1()
  s2()
  s3()
  s4()
  s5()
  s6()
  s7()
  s8()
  s9()
  s10()
end

local t0 = os.clock()
run_all()
local t_run = os.clock() - t0

-- §11 Mutants : chaque règle cassée doit faire échouer au moins un contrôle.
local n_mut, n_caught = 0, 0
local function M(name, apply, restore)
  n_mut = n_mut + 1
  local p0, f0 = pass, fail
  quiet = true
  local ok, err = pcall(function() apply() run_all() end)
  restore()
  quiet = false
  local caught = (fail - f0) > 0 or not ok
  pass, fail = p0, f0
  if caught then n_caught = n_caught + 1 end
  check(caught, "mutant refusé : " .. name .. (ok and "" or (" (plantage : " .. tostring(err) .. ")")))
end
do
  local fm = Ca.fed_max
  M("fours au-delà du minerai arrivé", function() Ca.fed_max = function() return 999 end end, function() Ca.fed_max = fm end)
  local kp = Ca.KAPPA
  M("ouvrir sans attendre la couverture", function() Ca.KAPPA = 0 end, function() Ca.KAPPA = kp end)
  local hs = Ca.H_STOCK
  M("stock qui dort ignoré", function() Ca.H_STOCK = 1e12 end, function() Ca.H_STOCK = hs end)
  local ap = Ca.apply
  -- Les ordres OUVERTS (entrée, sans retour T) restent appliqués ; les ordres décidés dans le cycle ne le sont plus.
  M("plan non mis à jour (gain non marginal)", function()
    Ca.apply = function(ctx, plan, o) if o.T == nil then return ap(ctx, plan, o) end end
  end, function() Ca.apply = ap end)
  local bu = Ca.budget
  M("budget ignoré (parts armée et défense)", function() Ca.budget = function() return 1e12 end end, function() Ca.budget = bu end)
  local lp = Ca.labor_price
  M("travail payé avec des bras libres", function() Ca.labor_price = function(Y, w) return (Y or 0) / math.max(1, w or 1) + 1 end end,
    function() Ca.labor_price = lp end)
  local ro = Ca.recipe_open
  M("assembleur pris sans sa recherche", function() Ca.recipe_open = function() return true end end, function() Ca.recipe_open = ro end)
  local lc = Ca.lab_cap
  M("laboratoires au-delà des packs", function() Ca.lab_cap = function() return math.huge end end, function() Ca.lab_cap = lc end)
  local ch = Ca.character
  M("caractère ignoré", function() Ca.character = function(_, _, th) return ch({}, {}, th) end end, function() Ca.character = ch end)
  local tm = Ca.THETA_MIN
  M("aval servi avant son ingrédient (goulot ignoré)", function() Ca.THETA_MIN = 0 end, function() Ca.THETA_MIN = tm end)
  local td = Ca.THREAT_DIV
  M("menace ignorée", function() Ca.THREAT_DIV = 1 end, function() Ca.THREAT_DIV = td end)
  local gm = Ca.G_MAX
  M("croissance coupée", function() Ca.G_MAX = 0 end, function() Ca.G_MAX = gm end)
  local rq = Ca.requirements
  M("débouché ignoré (toute ressource demandée)", function()
    Ca.requirements = function(ctx, plan)
      local r = rq(ctx, plan)
      for _, k in ipairs(ctx.D.res_list) do if not ctx.D.res[k].fluid and (r.R[k] or 0) <= 0 then
        r.R[k] = 100
        r.depth[k] = 0
        r.list[#r.list + 1] = k
      end end
      return r
    end
  end, function() Ca.requirements = rq end)
end
check(n_caught == n_mut, string.format("mutants : %d refusés sur %d", n_caught, n_mut))

-- §12 Coût de calcul (ordre de grandeur, PC non épinglé).
do
  local D = vdata()
  local inp = rich(D)
  local t1 = os.clock()
  for _ = 1, 20 do Ca.decide(inp, {}) end
  local per = (os.clock() - t1) * 1000 / 20
  local t2 = os.clock()
  local Ddata
  for _ = 1, 3 do Ddata = Ca.data(vanilla_dump(), { exec = EXEC_AUTO, exec_roles = ROLES }) end
  local per_data = (os.clock() - t2) * 1000 / 3
  print(string.format("[CAPI] §12 coût (ms, PC non épinglé) : une décision (scène riche, vanilla) %.2f ; relevé %.1f ; tout le banc %.1f s",
    per, per_data, t_run))
  check(per < 50, "§12 une décision sous 50 ms hors jeu (" .. string.format("%.2f", per) .. ")")
end

print(string.format("[CAPI] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refusés sur %d)", pass, fail, n_caught, n_mut))
if fail > 0 then os.exit(1) end
