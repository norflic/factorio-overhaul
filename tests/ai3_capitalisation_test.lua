--[[
  Lot CAPI « la capitalisation des factions » : test hors jeu de la règle PURE shared/ai3/capitalisation.lua
  (conception : docs/IA_CAPITALISATION.md). Rien n'est branché en jeu.

    §1 débits sans table : ratios vanilla retrouvés depuis le relevé (foreuses, fours, assembleur, laboratoire, peigne,
       valeurs, combustible), conversion d'un prototype lu en jeu (rayon -> côté, J par tick -> kW, dixièmes de PNJ),
       point fixe des valeurs sur 80 niveaux, combustible filtré par l'exécutant (F332) ;
    §2 gisements : couvrir avant d'ouvrir, ouvrir quand les ouverts sont couverts ou interdits (danger), d'avance
       (épuisement, réserve de places), gisement épuisé, quantité inconnue, couverture d'avance, goulot sous une
       demi-machine, ressource inconnue, ordre ouvert (aucun doublon, reste à poser), explorer, menace, courant ;
    §3 fours : jamais plus que le minerai LIVRÉ PAR LES FOREUSES n'en nourrit (ni la main, ni le stock), aucun four sans
       débouché, fondre d'avance au plus 2 × le débouché et sur la part que les autres usages ne réclament pas, fonte
       sur place dimensionnée par gisement ;
    §4 chaînes : aucune avant l'assembleur recherché, aucune sans exécutant, dès qu'il l'est, la sorte vient de la machine,
       la main n'est pas du capital, ingrédient en manque d'abord, retour de CHAÎNE ;
    §5 recherche : laboratoires qui grandissent, jamais plus que les packs ne nourrissent, plafond Ca.LEAD, menace ;
    §6 caractère, budget : épargne d'un cycle à l'autre (départ sans stock), stock non convertible ignoré, parts de
       l'armée et de la défense, le tri par retour compte, T_max refuse (prudent, ambitieux, menace), valeur des buts ;
    §7 saturation sans débouché ;
    §8 données CHANGÉES (même code) et TOUS les noms changés : mêmes ordres au renommage près ;
    §9 modèle simulé (données jouets, ordres payés en VRAIS ingrédients) : le capital qui rapporte ;
    §10 déterminisme (entrées permutées, puits en double) ; §11 mutants ; §12 coût de calcul (4, 60 et 200 gisements) ;
    §13 cerveau : buts de FOND réémis tant que l'ordre est ouvert (vrai P.update), la recherche garde sa place ;
    §14 repli des ordres refusés (lot CAPI-REPLI, shared/ai3/repli.lua) : par (produit, gisement), remis à zéro après un
       module terminé, décroissant avec le temps, un échec de matériaux ne bloque pas (module réduit, objets en préparation),
       plafond de 5 min couverture basse et besoin non servi, le cas mesuré d'Azur (79,6 à 119,8 min sans ordre de fer) ;
       ses mutants sont dans §11.
  Usage : lua5.2 tests/ai3_capitalisation_test.lua   (depuis la racine du mod)
  Ce fichier est du TEST : il nomme les prototypes vanilla (comme le moteur) ; la règle n'en voit rien.
]]

package.path = "./?.lua;" .. package.path
local F = require("tests.iag_fixture")
local Ca = require("shared.ai3.capitalisation")
local B = require("shared.ai3.buts")
local P = require("shared.ai3.projets")
local K = require("shared.ai3.catalogue")
local Rp = require("shared.ai3.repli")
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
  check(Ca.count_for(7.8, 30, 0.79) == 1 and Ca.count_for(7.8, 30, 0.95) == 0, "§1 goulot (θ < 0,9) : une machine dès le premier objet")
  -- Prototypes lus en jeu (champs du runtime 1.1.91) : rayon -> côté, J par tick -> kW ; bras libres en dixièmes.
  local e1 = Ca.entity_of({ name = "x", type = "mining-drill", mining_speed = 0.5, resource_searching_radius = 2.49,
    tile_width = 3, energy_usage = 1500 })
  local e2 = Ca.entity_of({ name = "y", type = "mining-drill", mining_speed = 0.25, resource_searching_radius = 0.99,
    tile_width = 2, energy_usage = 2500 })
  check(e1.speed == 0.5 and e1.mining_area == 5 and e1.size == 3 and math.abs(e1.energy_kw - 90) < 1e-9
    and e2.mining_area == 2 and math.abs(e2.energy_kw - 150) < 1e-9 and Ca.idle_of(35) == 3.5,
    string.format("§1 relevé du runtime : aire %s et %s (rayons 2,49 et 0,99), %s kW et %s kW ; Br.smooth 35 -> 3,5 PNJ",
      tostring(e1.mining_area), tostring(e2.mining_area), tostring(e1.energy_kw), tostring(e2.energy_kw)))
  local per2 = Ca.comb({ size = e1.size, area = e1.mining_area })
  check(per2 == 13.5, "§1 le peigne d'un prototype converti vaut celui du relevé (13,5)")
  -- Point fixe des valeurs : 80 niveaux nommés à rebours (une passe ne monte que d'un niveau).
  local toy = { entities = { { name = "corps", type = "character", crafting_categories = { "k" }, resource_categories = { "s" } } },
    resources = { { entity = "r0", category = "s", mining_time = 1, products = { { type = "item", name = "r0", amount = 1 } } } },
    items = {}, recipes = {}, techs = {} }
  for i = 1, 80 do
    local prev = i == 1 and "r0" or string.format("c%03d", 81 - (i - 1))
    local name = string.format("c%03d", 81 - i)
    toy.recipes[name] = { category = "k", energy = 1, ingredients = { { type = "item", name = prev, amount = 1 } },
      products = { { type = "item", name = name, amount = 1 } } }
  end
  local Dt = Ca.data(toy, {})
  check(Dt.mu["c001"] ~= nil and math.abs(Dt.mu["c001"] - 9) < 1e-6,
    "§1 point fixe jusqu'à stabilité : 80 niveaux valorisés (dernier " .. tostring(Dt.mu["c001"]) .. ")")
  -- Combustible (F332, banc g1) : une ressource minable à la main plus riche que le charbon n'est pas prise quand le
  -- catalogue (K.build, filtré par l'exécutant) ou opts.fuel_ok le dit.
  local d5 = vanilla_dump(function(d)
    d.resources[#d.resources + 1] = { entity = "capi-cristal", category = "basic-solid", mining_time = 1,
      products = { { type = "item", name = "capi-cristal", amount = 1 } } }
    d.items["capi-cristal"] = { type = "item", fuel_value = 8e6 }
  end)
  local D5a = Ca.data(d5, { exec = EXEC_AUTO, exec_roles = ROLES })
  local cat5 = K.build(d5, F.opts())
  local D5b = Ca.data(d5, { exec = EXEC_AUTO, exec_roles = ROLES, cat = cat5 })
  local D5c = Ca.data(d5, { exec = EXEC_AUTO, exec_roles = ROLES, fuel_ok = F.opts().fuel_ok })
  check(D5a.fuel == "capi-cristal" and D5b.fuel == "coal" and cat5.fuel == "coal" and D5c.fuel == "coal",
    string.format("§1 combustible : sans filtre %s (le défaut F332), catalogue %s, fuel_ok %s", tostring(D5a.fuel),
      tostring(D5b.fuel), tostring(D5c.fuel)))
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
  -- b. Gros manque : d1 couvert entièrement, PUIS ouverture de s2 (dans le même cycle). Grosse réserve de pièces
  --    (3 000 circuits) : c'est la géométrie qui est vérifiée ici, pas le budget.
  local r2 = Ca.decide(iron_scene(D, 1000, { stock = pieces({ ["electronic-circuit"] = 3000 }) }), {})
  local c2, i_c = find(r2, "couvrir:d1")
  local o2, i_o = find(r2, "ouvrir:s2")
  check(c2 and c2.n == 18, "§2b d1 couvert : 18 foreuses de plus (20 places de 13,5 tuiles sur 270) (" .. tostring(c2 and c2.n) .. ")")
  check(o2 and i_c and i_o and i_o > i_c and o2.n == 13, "§2b puis s2 ouvert, après d1 (13 foreuses pour 400/min) ("
    .. tostring(o2 and o2.n) .. ")")
  local k1 = nil
  for _, c in ipairs(r2.coverage) do if c.id == "d1" then k1 = c.kappa end end
  check(k1 and k1 >= Ca.KAPPA, "§2b couverture de d1 dans le plan : " .. tostring(k1) .. " pour mille")
  check(no_dup(r2), "§2b aucun ordre en double")
  local on_s2 = 0
  for _, o in ipairs(r2.orders) do if o.deposit == "s2" then on_s2 = on_s2 + 1 end end
  check(on_s2 == 1, "§2b un seul ordre sur le site ouvert dans le cycle (" .. on_s2 .. ")")
  -- c. Épuisement proche : ouvrir d'avance, sans manque.
  local inp_c = iron_scene(D, 60)
  inp_c.deposits[1].amount = 1500
  local r3 = Ca.decide(inp_c, {})
  local o3 = find(r3, "ouvrir:s2")
  check(o3 and o3.n == Ca.OPEN_MIN and (o3.why or ""):find("epuisement", 1, true),
    "§2c d1 épuisé en 25 min : s2 ouvert d'avance (" .. tostring(o3 and o3.why) .. ")")
  -- c2. Quantité INCONNUE (nil) : jamais « épuisé » ; couvrir d1 d'abord, pas d'ouverture.
  local inp_c2 = iron_scene(D, 150)
  inp_c2.deposits[1].amount = nil
  local r3b = Ca.decide(inp_c2, {})
  check(find(r3b, "couvrir:d1") ~= nil and find(r3b, "ouvrir:s2") == nil,
    "§2c quantité inconnue : couvrir d1, aucune ouverture pour « épuisement en 0 min »")
  -- c3. Gisement ÉPUISÉ (quantité 0, 6 foreuses mortes, rien n'arrive) : aucune foreuse dessus, s2 ouvert pour TOUT le
  --     manque (les foreuses mortes ne comptent plus).
  local inp_c3 = iron_scene(D, 150, { flows = {} })
  inp_c3.deposits[1].amount = 0
  inp_c3.drills[1].n = 6
  local r3c = Ca.decide(inp_c3, {})
  local o3c = find(r3c, "ouvrir:s2")
  check(find(r3c, "couvrir:d1") == nil and o3c and o3c.n == 5,
    "§2c d1 épuisé : aucune foreuse sur d1, s2 ouvert au manque entier (5 foreuses pour 150/min) (" .. tostring(o3c and o3c.n) .. ")")
  -- d. Aucun site connu, d1 couvert : explorer.
  local inp_d = iron_scene(D, 1000)
  inp_d.deposits = { inp_d.deposits[1] }
  inp_d.drills[1].n = 20
  local r4 = Ca.decide(inp_d, {})
  check(explores(r4, "iron-ore") and count_kind(r4, "couvrir") == 0 and count_kind(r4, "ouvrir") == 0,
    "§2d gisement couvert, aucun site : exploration du fer")
  -- d2. Gisement ouvert DANGEREUX (X1 du correcteur) : il ne bloque pas l'ouverture d'un site sûr.
  local inp_x1 = iron_scene(D, 1000)
  inp_x1.deposits[1].danger = true
  local rx1 = Ca.decide(inp_x1, {})
  local ox1 = find(rx1, "ouvrir:s2")
  local rfx1 = refus_of(rx1, "couvrir:d1")
  check(find(rx1, "couvrir:d1") == nil and rfx1 and rfx1.why == "danger" and ox1 and (ox1.why or ""):find("interdits", 1, true),
    "§2d d1 dangereux : refusé (" .. tostring(rfx1 and rfx1.why) .. "), s2 ouvert (" .. tostring(ox1 and ox1.why) .. ")")
  -- d3. Site connu dangereux et aucun autre : exploration.
  local inp_x1b = iron_scene(D, 1000)
  inp_x1b.drills[1].n = 20
  inp_x1b.deposits[2].danger = true
  local rx1b = Ca.decide(inp_x1b, {})
  check(find(rx1b, "ouvrir:s2") == nil and explores(rx1b, "iron-ore"), "§2d seul site connu dangereux : non ouvert, exploration")
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
  local function shortage_cover(r)
    local o = find(r, "couvrir:d1")
    return o and o.why ~= "couverture d'avance"
  end
  local r6 = near_site(30)
  check(shortage_cover(r6) and find(r6, "ouvrir:s2") == nil and r6.lambda > 0,
    string.format("§2f site 1 %% moins cher : couvrir d1 d'abord (prix du travail %.1f)", r6.lambda))
  local r7 = near_site(1)
  local o7, i7 = find(r7, "ouvrir:s2")
  local _, ic7 = find(r7, "couvrir:d1")
  check(o7 and (o7.why or ""):find("moins cher", 1, true) and not shortage_cover(r7) and (ic7 == nil or ic7 > i7),
    string.format("§2f site 20 %% moins cher par débit : ouvert (%s ; prix du travail %.0f)", tostring(o7 and o7.why), r7.lambda))
  -- g. Courant : des foreuses électriques sans courant font d'abord poser une centrale (données de la centrale : runtime).
  local r8 = Ca.decide(iron_scene(D, 150, { power = { have_kw = 0, used_kw = 0, plant = { kw = 1800, burner_kw = 1800,
    items = { { "boiler", 1 }, { "steam-engine", 2 }, { "offshore-pump", 1 } } } } }), {})
  local e8, ie8 = find(r8, "energie")
  local c8, ic8 = find(r8, "couvrir:d1")
  check(e8 and c8 and ie8 < ic8 and c8.n * 90 <= e8.kw, string.format("§2g pas de courant : centrale (%s kW) puis 3 foreuses (%s)",
    tostring(e8 and e8.kw), tostring(c8 and c8.n)))
  -- g2. Pas de courant et AUCUNE centrale possible : d1 interdit, il ne bloque pas l'ouverture (qui est refusée de même).
  local r8b = Ca.decide(iron_scene(D, 150, { power = { have_kw = 0, used_kw = 0 } }), {})
  local rf8b = refus_of(r8b, "couvrir:d1")
  check(find(r8b, "couvrir:d1") == nil and rf8b and rf8b.why:find("aucune centrale", 1, true),
    "§2g sans centrale possible : " .. tostring(rf8b and rf8b.why))
  -- h. Réserve de places basse (κ 740 ‰ mesuré, 5 places pour 700/min demandés, aucun manque) : s2 ouvert d'avance.
  local inp_h = iron_scene(D, 700, { flows = { ["iron-ore"] = { made = 700 }, ["iron-plate"] = { made = 700 } } })
  inp_h.deposits[1].covered = 200
  inp_h.drills[1].n = 24
  local rh = Ca.decide(inp_h, {})
  local oh = find(rh, "ouvrir:s2")
  check(oh and (oh.why or ""):find("reserve", 1, true) and oh.n == Ca.OPEN_MIN,
    "§2h réserve de places basse : s2 ouvert d'avance (" .. tostring(oh and oh.why) .. ")")
  -- i. Couverture d'AVANCE : aucun manque (6 foreuses pour 150/min), du budget : d1 couvert d'avance jusqu'à Ca.KAPPA
  --    (800 ‰ des 270 tuiles : 216 tuiles, 81 couvertes, 13,5 par foreuse : 10 foreuses de plus), gain à 25 %.
  --    Lot CAPIB : décision de l'intégrateur sur Q-CAPI-1 (OBJECTIFS §4, 27/10) : SANS le plafond « 2 × le besoin »
  --    (Ca.COVER_LEAD = nil) ; avec l'ancien plafond (Ca.COVER_LEAD = 2) : 4 foreuses, comme avant.
  local inp_i = iron_scene(D, 150, { flows = { ["iron-ore"] = { made = 180 }, ["iron-plate"] = { made = 75 } } })
  inp_i.drills[1].n = 6
  local ri = Ca.decide(inp_i, {})
  local oi = find(ri, "couvrir:d1")
  check(oi and oi.why == "couverture d'avance" and oi.n == 10 and oi.useful == 0,
    "§2i couverture d'avance jusqu'à 800 pour mille (Q-CAPI-1) : " .. tostring(oi and oi.n) .. " foreuses (" .. tostring(oi and oi.why) .. ")")
  local saved_cl = Ca.COVER_LEAD
  Ca.COVER_LEAD = 2
  local oi2 = find(Ca.decide(inp_i, {}), "couvrir:d1")
  Ca.COVER_LEAD = saved_cl
  check(oi2 and oi2.n == 4, "§2i ancien plafond (Ca.COVER_LEAD = 2) : " .. tostring(oi2 and oi2.n) .. " foreuses")
  -- Lot CAPIB : pas de couverture d'avance avec une foreuse à combustible (input.drill_for : l'exécutant ne sait poser que
  -- celle-là) ; le manque, lui, reste couvert (Ca.AHEAD_BURNER = false, banc p2).
  local inp_ib = deep(inp_i)
  inp_ib.drill_for = { ["iron-ore"] = "burner-mining-drill" }
  inp_ib.drills = { { entity = "burner-mining-drill", resource = "iron-ore", n = 12, deposit = "d1" } }
  check(find(Ca.decide(inp_ib, {}), "couvrir:d1") == nil, "§2i aucune couverture d'avance a combustible (Ca.AHEAD_BURNER)")
  local inp_ib2 = deep(inp_ib)
  inp_ib2.sinks = { { item = "iron-plate", rate = 600 } }
  local oib2 = find(Ca.decide(inp_ib2, {}), "couvrir:d1")
  check(oib2 and oib2.entity == "burner-mining-drill" and (oib2.useful or 0) > 0,
    "§2i le manque reste couvert a combustible : " .. tostring(oib2 and oib2.n))
  local ri0 = Ca.decide(iron_scene(D, 0, { flows = { ["iron-ore"] = { made = 180 } } }), {})
  check(find(ri0, "couvrir:d1") == nil, "§2i aucune couverture d'avance sans débouché")
  -- j. Goulot sous une demi-machine (X8) : 37,8 charbon/min demandés, plus 5,85 pour les machines à combustion (2 foreuses,
  --    1 four) ; 13,7/min manquent (θ 0,69) : une foreuse électrique (30/min) quand même.
  local inp_j = vin(D, { stock = pieces(), sinks = { { item = "coal", rate = 37.8 } },
    deposits = { { id = "dk", resource = "coal", tiles = 200, amount = 5e5, open = true, dist = 50 } },
    drills = { { entity = "burner-mining-drill", resource = "coal", n = 2, deposit = "dk" } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 1, where = "qg" } },
    flows = { coal = { made = 30 } } })
  local rj = Ca.decide(inp_j, {})
  local oj = find(rj, "couvrir:dk")
  check(oj and oj.n == 1, "§2j goulot de 13,7/min : une foreuse (" .. tostring(oj and oj.n) .. ")")
  inp_j.sinks[1].rate = 26
  local rj2 = Ca.decide(inp_j, {})
  local rfj = refus_of(rj2, "extraire:coal")
  check(find(rj2, "couvrir:dk") == nil and rfj and rfj.why:find("demi", 1, true),
    "§2j 1,9 charbon/min manquent (θ 0,94 : pas un goulot) : refus écrit (" .. tostring(rfj and rfj.why) .. ")")
  -- k. Ressource INCONNUE (state.known sans le cuivre, rien au stock) : la foreuse électrique (circuits, donc cuivre)
  --    n'est pas disponible, la foreuse à combustion l'est.
  local inp_k = iron_scene(D, 150, { stock = {}, state = { techs = { automation = true },
    known = { ["iron-ore"] = true, stone = true, coal = true } } })
  local rk = Ca.decide(inp_k, { bank = 1000 })
  local ok_ = find(rk, "couvrir:d1")
  check(ok_ and ok_.entity == "burner-mining-drill", "§2k cuivre inconnu : foreuse à combustion (" .. tostring(ok_ and ok_.entity) .. ")")
  -- l. Ordre OUVERT sur d1 : pas de doublon ; son reste à poser (n_left) compte, pas son n d'origine.
  local inp_l = iron_scene(D, 150, { open = { { key = "couvrir:d1", kind = "couvrir", item = "iron-ore", resource = "iron-ore",
    entity = "electric-mining-drill", n = 3, n_left = 3, deposit = "d1", value = 45 } } })
  local rl = Ca.decide(inp_l, {})
  check(find(rl, "couvrir:d1") == nil and find(rl, "ouvrir:s2") == nil, "§2l ordre ouvert couvrir:d1 : aucun doublon, aucune ouverture")
  local inp_l2 = iron_scene(D, 150, { open = { { key = "couvrir:d1", kind = "couvrir", item = "iron-ore", resource = "iron-ore",
    entity = "electric-mining-drill", n = 6, n_left = 2, deposit = "d1" } } })
  inp_l2.drills[1].n = 6
  local rl2 = Ca.decide(inp_l2, {})
  local kl = nil
  for _, c in ipairs(rl2.coverage) do if c.id == "d1" then kl = c.kappa end end
  check(kl == 400, "§2l ordre à moitié posé (6 posées, 2 restantes) : couverture 8 foreuses = 400 pour mille (" .. tostring(kl) .. ")")
  say(string.format("§2 couvrir d1 : %d foreuses (T %.2f min, valeur %d) ; gros manque : %d puis ouvrir s2 %d (T %.2f)",
    c1 and c1.n or 0, c1 and c1.T or 0, c1 and c1.value or 0, c2 and c2.n or 0, o2 and o2.n or 0, o2 and o2.T or 0))
  return r1, r2
end

---------------------------------------------------------------------------------------------------
-- §3 Fours : jamais au-delà du minerai livré par les foreuses
---------------------------------------------------------------------------------------------------
local function s3()
  local D = vdata()
  local k = 18.75
  local ok, worst = true, ""
  local n_orders = 0
  -- Budget : de la pierre au coffre (elle fait les fours ; aucun puits de pierre).
  for i = 1, 50 do
    local A = 6 + (i - 1) * (1800 - 6) / 49 -- 0,1 à 30 minerais/s
    local inp = vin(D, { stock = { stone = 2000 }, flows = { ["iron-ore"] = { made = A } }, sinks = { { item = "iron-plate", rate = 1e5 } } })
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
  local r2 = Ca.decide(vin(D, { stock = { stone = 2000 }, flows = { ["iron-ore"] = { made = 300 } }, sinks = { { item = "iron-plate", rate = 1e5 } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 10, where = "qg" } } }), {})
  local o2 = find(r2, "fours:iron-plate")
  check(o2 and o2.n == 6, "§3 300/min arrivés, 10 fours posés (187,5/min) : 6 de plus (" .. tostring(o2 and o2.n) .. ")")
  -- Stock en retard, rien n'arrive : AUCUN four (un stock n'est pas une arrivée : une tâche ponctuelle le fond).
  local r3 = Ca.decide(vin(D, { flows = { ["iron-ore"] = { made = 0 } }, stock = { ["iron-ore"] = 1875, stone = 2000 },
    sinks = { { item = "iron-plate", rate = 1e5 } } }), {})
  local rf3 = refus_of(r3, "fours:iron-plate")
  check(find(r3, "fours:iron-plate") == nil and rf3 and rf3.why:find("arrivee des foreuses", 1, true),
    "§3 1 875 minerais au coffre, rien n'arrive : aucun four permanent (" .. tostring(rf3 and rf3.why) .. ")")
  -- Minerai miné À LA MAIN : il ne dimensionne aucun four (la main n'est pas du capital).
  local r3h = Ca.decide(vin(D, { stock = { stone = 2000 }, flows = { ["iron-ore"] = { made = 300, hand = 300 } },
    sinks = { { item = "iron-plate", rate = 1e5 } } }), {})
  local r3m = Ca.decide(vin(D, { stock = { stone = 2000 }, flows = { ["iron-ore"] = { made = 300, hand = 100 } },
    sinks = { { item = "iron-plate", rate = 1e5 } } }), {})
  local o3m = find(r3m, "fours:iron-plate")
  check(find(r3h, "fours:iron-plate") == nil and o3m and o3m.n == 10,
    "§3 300/min minés à la main : aucun four ; 200 livrés par les foreuses : 10 fours (" .. tostring(o3m and o3m.n) .. ")")
  -- Aucun débouché : aucun four, même avec du minerai qui s'entasse.
  local r4 = Ca.decide(vin(D, { flows = { ["iron-ore"] = { made = 300 } }, stock = { ["iron-ore"] = 5000, stone = 2000 } }), {})
  check(find(r4, "fours:iron-plate") == nil and #r4.orders == 0, "§3 minerai qui s'entasse sans demande de plaques : aucun four")
  -- Arrivée nulle : aucun four, refus écrit.
  local r5 = Ca.decide(vin(D, { stock = { stone = 2000 }, sinks = { { item = "iron-plate", rate = 100 } } }), {})
  local rf5 = refus_of(r5, "fours:iron-plate")
  check(find(r5, "fours:iron-plate") == nil and rf5 and rf5.why:find("insuffisante", 1, true),
    "§3 aucun minerai arrivé : aucun four (" .. tostring(rf5 and rf5.why) .. ")")
  -- Débouché présent : on fond d'avance, au plus 2 × le débouché (100 plaques/min : 10 fours, 187,5/min) ; avec un
  -- débouché de 200/min, TOUT le minerai arrivé (16 fours, critère (2) du DC).
  local r6 = Ca.decide(vin(D, { stock = { stone = 2000 }, flows = { ["iron-ore"] = { made = 300 } }, sinks = { { item = "iron-plate", rate = 100 } } }), {})
  local o6 = find(r6, "fours:iron-plate")
  check(o6 and o6.n == 10, "§3 300 minerais/min, 100 plaques/min demandées : 10 fours (au plus 2 × le débouché) ("
    .. tostring(o6 and o6.n) .. ")")
  local r6b = Ca.decide(vin(D, { stock = { stone = 2000 }, flows = { ["iron-ore"] = { made = 300 } }, sinks = { { item = "iron-plate", rate = 200 } } }), {})
  local o6b = find(r6b, "fours:iron-plate")
  check(o6b and o6b.n == 16, "§3 300 minerais/min, 200 plaques/min demandées : 16 fours (tout le minerai fondu) ("
    .. tostring(o6b and o6b.n) .. ")")
  -- X12 : les autres usages du minerai brut sont réservés. 300 pierres/min ; 10 briques/min et 20 fours en pierre/min
  -- (100 pierres brutes) : un four de briques (2 × le débouché), pas 8 qui mangeraient toute la pierre.
  local function stone_scene(bricks)
    return vin(D, { stock = pieces(), flows = { stone = { made = 300 } },
      sinks = { { item = "stone-brick", rate = bricks }, { item = "stone-furnace", rate = 20 } } })
  end
  local rx = Ca.decide(stone_scene(10), {})
  local ox = find(rx, "fours:stone-brick")
  check(ox and ox.n == 1 and ox.n * 37.5 <= 300 - 100 + 1e-9, "§3 X12 : 10 briques/min, 100 pierres réservées : "
    .. tostring(ox and ox.n) .. " four(s) de briques")
  local rx2 = Ca.decide(stone_scene(100), {})
  local ox2 = find(rx2, "fours:stone-brick")
  check(ox2 and ox2.n == 5, "§3 X12 : 100 briques/min et 100 pierres réservées : 5 fours de briques, pas 8 ("
    .. tostring(ox2 and ox2.n) .. ")")
  -- X2 : fonte sur place, une suite de petits ordres (une foreuse par cycle, posée aussitôt) : les fours de l'avant-poste
  -- suivent le débit TOTAL de ses foreuses (9 fours pour 180 minerais/min), sans entassement.
  local Dv = D
  local drills, furn, viol = 0, 0, 0
  for c = 1, 6 do
    local inp = vin(Dv, { stock = pieces(),
      deposits = { { id = "dc", resource = "copper-ore", tiles = 400, amount = 1e6, open = true, dist = 80,
        smelt = "copper-plate", smelter = "stone-furnace" } },
      drills = drills > 0 and { { entity = "electric-mining-drill", resource = "copper-ore", n = drills, deposit = "dc" } } or {},
      machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 1, where = "qg" },
        furn > 0 and { entity = "stone-furnace", recipe = "copper-plate", n = furn, where = "dc" } or nil },
      sinks = { { item = "copper-plate", rate = 30 * (drills + 1) } } })
    local r = Ca.decide(inp, {})
    local o = find(r, "couvrir:dc") or find(r, "ouvrir:dc")
    if o then
      drills = drills + o.n
      furn = furn + (o.smelt_n or 0)
    end
    if furn * 18.75 > drills * 30 + 1e-9 then viol = viol + 1 end
  end
  check(drills == 6 and furn == 9 and viol == 0, string.format("§3 X2 fonte sur place : %d foreuses, %d fours (9 attendus), %d entassement(s) refusé(s)",
    drills, furn, viol))
  say(string.format("§3 fours : 300/min et 10 posés -> +%d ; 100 et 200 plaques/min -> %d et %d ; briques %d puis %d",
    o2 and o2.n or 0, o6 and o6.n or 0, o6b and o6b.n or 0, ox and ox.n or 0, ox2 and ox2.n or 0))
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
  -- c2. Retour de CHAÎNE : T = (taille ÷ part utile) × capital de la chaîne (assembleur + 2 × (four + foreuse)) ÷ valeur,
  --     recalculé par le test ; la valeur au puits n'est pas comptée à chaque étage.
  local exp_g = og and (og.rate / og.useful) * cc_test(D, "iron-gear-wheel") / D.mu["iron-gear-wheel"]
  check(og and math.abs(og.T - exp_g) < 1e-6 and og.share < 0.2,
    string.format("§4c retour de chaîne des engrenages %.3f min (attendu %.3f ; part de l'étage %.3f)", og and og.T or -1,
      exp_g or -1, og and og.share or -1))
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
  local inp_e = vin(D, { stock = pieces(), open = { { key = "couvrir:dx", kind = "couvrir", item = "iron-ore", resource = "iron-ore", n = 0,
    missing = { { "pipe", 400 } } } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 8, where = "d-fe" } }, flows = { ["iron-plate"] = { made = 150 } } })
  local re = Ca.decide(inp_e, {})
  local oe = find(re, "chaine:pipe")
  check(oe and oe.n == 1, "§4e 400 tuyaux manquent à un chantier : une rangée d'assembleurs (" .. tostring(oe and oe.n) .. ")")
  -- f. Limite de l'exécutant (rangée à 2 ingrédients au plus) : écrite.
  local inp_f = vin(D, { stock = pieces(), sinks = { { item = "inserter", rate = 120 } }, limits = { max_ingredients = 2 },
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
  -- h. La SORTE vient de la machine (X4) : le moteur (catégorie que la main ne fait pas) est fait par un assembleur :
  --    une CHAÎNE, pas des fours.
  local inp_h = vin(D, { state = { techs = { automation = true, engine = true } },
    stock = pieces({ ["steel-plate"] = 100, ["iron-gear-wheel"] = 100, pipe = 200 }),
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 1, where = "qg" } },
    sinks = { { item = "engine-unit", rate = 10 } } })
  local rh = Ca.decide(inp_h, {})
  local oh = find(rh, "chaine:engine-unit")
  check(oh and oh.kind == "chaine" and find(rh, "fours:engine-unit") == nil,
    "§4h moteur fait par un assembleur : ordre « chaine » (" .. tostring(oh and oh.key) .. ")")
  -- i. La MAIN n'est pas du capital : 30 engrenages/min faits à la main, aucune machine : une chaîne est demandée.
  local inp_i = pack_scene(D, { flows = { ["iron-plate"] = { made = 150 }, ["copper-plate"] = { made = 75 },
    ["iron-gear-wheel"] = { made = 30, hand = 30 } } })
  local ri = Ca.decide(inp_i, {})
  local oi = find(ri, "chaine:iron-gear-wheel")
  check(oi and oi.n == 1, "§4i engrenages faits à la main (30/min) : une chaîne quand même (" .. tostring(oi and oi.n) .. ")")
  say(string.format("§4 engrenages %d (T %.2f), packs %d (T %.2f) ; tuyaux %d ; moteur %s", og and og.n or 0, og and og.T or 0,
    op and op.n or 0, op and op.T or 0, oe and oe.n or 0, tostring(oh and oh.n)))
  return rc
end

---------------------------------------------------------------------------------------------------
-- §5 Recherche
---------------------------------------------------------------------------------------------------
local function s5()
  local D = vdata()
  local function scene(rate, labs, machines, pack_stock, starved, threat)
    return pack_scene(D, { flows = { ["iron-plate"] = { made = 150 }, ["copper-plate"] = { made = 75 },
      ["automation-science-pack"] = { made = 6 * machines } },
      stock = pieces({ ["automation-science-pack"] = pack_stock, ["electronic-circuit"] = 3000 }),
      machines = { { entity = "assembling-machine-1", recipe = "automation-science-pack", n = machines, where = "qg" },
        { entity = "stone-furnace", recipe = "iron-plate", n = 8, where = "d-fe" } },
      labs = { { entity = "lab", n = labs } }, research = { queue = { { tech = "fast-inserter", left = 1e5, time = 15,
        packs = { { "automation-science-pack", 1 } } } }, rate = rate, starved = starved }, threat = threat })
  end
  --- `n` cycles du même état (la recherche visée grandit d'un cycle à l'autre, état persistant).
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
  -- Plafond Ca.LEAD : 30 cycles, la recherche visée ne dépasse jamais 2 × max(mesure, laboratoires posés).
  local _, u30 = cycles(function() return scene(1200, 20, 34, 2000) end, 30)
  local lead_ok = true
  for c = 1, 30 do if u30[c] > Ca.LEAD * 1200 + 1e-9 then lead_ok = false end end
  check(lead_ok and u30[30] > 1200 * 1.5, string.format("§5 plafond : recherche visée %.0f s/min après 30 cycles (≤ 2 × 1 200)", u30[30]))
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
  -- Menace : les laboratoires sont un levier du QG, ils restent ouverts.
  local r5 = cycles(function() return scene(1200, 20, 34, 2000, 0, true) end, 2)
  check(find(r5, "labos:lab") ~= nil, "§5 menace : des laboratoires quand même (levier du QG)")
  say(string.format("§5 laboratoires visés : %d (120 s/min) et %d (1 200 s/min) ; recherche visée %.0f -> %.0f ; packs : %d visés, %d nourris",
    r1.labs_target, r2.labs_target, u2[1], u2[4], r3.labs_target, cap))
end

---------------------------------------------------------------------------------------------------
-- §6 Caractère, budget, retour
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
  check(ok_budget, "§6 budget = s × production libre des parts défense et armée (aucun stock, aucune épargne)")
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
  -- X6 : un stock NON convertible ne finance rien (2 000 coffres, 300 tourelles, 3 000 chargeurs : budget inchangé) ;
  --      des circuits (convertibles) le financent ; la réserve militaire n'est jamais du budget.
  local function budget_with(stock)
    return Ca.decide(iron_scene(D, 150, { stock = stock }), {}).budget
  end
  local b0 = budget_with({})
  local bx = { budget_with({ ["iron-chest"] = 2000 }), budget_with({ ["gun-turret"] = 300 }),
    budget_with({ ["firearm-magazine"] = 3000 }), budget_with({ ["iron-chest"] = 2000, ["gun-turret"] = 300, ["firearm-magazine"] = 3000 }) }
  local same = true
  for _, b in ipairs(bx) do if math.abs(b - b0) > 1e-9 then same = false end end
  local bc = budget_with(pieces())
  check(same and bc > b0 + 100, string.format("§6 X6 stock non convertible : budget %.1f MU (coffres, tourelles, chargeurs : %.1f %.1f %.1f) ; circuits : %.1f",
    b0, bx[1], bx[2], bx[3], bc))
  -- X7 : départ SANS stock (29,7 MU par cycle, la foreuse coûte 37,1) : l'épargne fait passer le premier ordre au 2e
  --      cycle, puis la capacité croît ; l'épargne reste plafonnée.
  local st = {}
  local drills, furn, first = 2, 4, nil
  local hist = {}
  for c = 1, 20 do
    local ore = drills * 30
    local inp = iron_scene(D, 150 + 15 * c, { stock = {}, flows = { ["iron-ore"] = { made = ore },
      ["iron-plate"] = { made = math.min(ore, furn * 18.75) } } })
    inp.drills[1].n = drills
    inp.machines[1].n = furn
    local r = Ca.decide(inp, st)
    for _, x in ipairs(r.orders) do
      if x.kind == "couvrir" or x.kind == "ouvrir" then drills = drills + x.n end
      if x.kind == "fours" then furn = furn + x.n end
    end
    if #r.orders > 0 and not first then first = c end
    hist[c] = { drills = drills, bank = r.bank, budget = r.budget, Y = r.Y }
    if c == 1 then
      local rf1 = refus_of(r, "couvrir:d1")
      check(#r.orders == 0 and rf1 and rf1.why:find("budget", 1, true), "§6 X7 cycle 1 sans stock : rien, " .. tostring(rf1 and rf1.why))
    end
  end
  local cap_ok = true
  for c = 1, 20 do if hist[c].bank > Ca.BANK_H * hist[c].Y + 1e-6 then cap_ok = false end end
  check(first == 2 and hist[20].drills >= hist[2].drills + 4 and cap_ok,
    string.format("§6 X7 épargne : premier ordre au cycle %s ; foreuses %d -> %d en 20 cycles", tostring(first), hist[2].drills,
      hist[20].drills))
  -- Le TRI par retour compte : budget pour une seule foreuse ; fer proche et cuivre lointain (bras payés) : le fer.
  local inp_t = vin(D, { idle = 0, workers = 30,
    deposits = { { id = "dfe", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 30 },
      { id = "dcu", resource = "copper-ore", tiles = 270, amount = 1e6, open = true, dist = 400 } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 2, deposit = "dfe" },
      { entity = "electric-mining-drill", resource = "copper-ore", n = 2, deposit = "dcu" } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 1, where = "d-fe" },
      { entity = "stone-furnace", recipe = "copper-plate", n = 1, where = "d-cu" } },
    flows = { ["iron-ore"] = { made = 60 }, ["copper-ore"] = { made = 60 } },
    sinks = { { item = "iron-ore", rate = 90 }, { item = "copper-ore", rate = 90 } } })
  local rtri = Ca.decide(inp_t, {})
  check(#rtri.orders == 1 and rtri.orders[1].key == "couvrir:dfe" and refus_of(rtri, "couvrir:dcu") ~= nil,
    "§6 tri : une seule foreuse payable, le meilleur retour d'abord (" .. tostring(rtri.orders[1] and rtri.orders[1].key) .. ")")
  -- T_max REFUSE une option lente (assembleur 60 fois plus cher : engrenages à environ 14 min de retour). Le prudent
  -- (T_max 10) la refuse, l'ambitieux (40) la prend, l'ambitieux sous menace (10) la refuse.
  local Dx = vdata(function(d)
    for _, i in ipairs(d.recipes["assembling-machine-1"].ingredients) do i.amount = i.amount * 60 end
  end)
  local function slow(traits, threat)
    return Ca.decide(vin(Dx, { stock = { ["electronic-circuit"] = 8000 }, traits = traits, threat = threat,
      machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 20, where = "d-fe" } },
      flows = { ["iron-plate"] = { made = 375 } }, sinks = { { item = "iron-gear-wheel", rate = 60 } } }), {})
  end
  local PRU = { ambition = 600, prudence = 1500, agressivite = 1000 }
  local AMB = { ambition = 2000, prudence = 500, agressivite = 1000 }
  local rp_, ra_, rat = slow(PRU), slow(AMB), slow(AMB, true)
  local oa = find(ra_, "chaine:iron-gear-wheel")
  local rfp = refus_of(rp_, "chaine:iron-gear-wheel")
  local rft = refus_of(rat, "chaine:iron-gear-wheel")
  check(oa and oa.T > rp_.tmax and oa.T <= ra_.tmax and find(rp_, "chaine:iron-gear-wheel") == nil
    and rfp and rfp.why:find("retour", 1, true) and find(rat, "chaine:iron-gear-wheel") == nil and rft and rft.why:find("retour", 1, true),
    string.format("§6 T_max : option à %.1f min, prudent (%.0f) refuse, ambitieux (%.0f) prend, sous menace (%.0f) refuse",
      oa and oa.T or -1, rp_.tmax, ra_.tmax, rat.tmax))
  -- Valeur des buts : 50 à T = 0, 35 à T = T_max, décroissante ; dans une décision, un retour plus court vaut plus.
  local mono = Ca.value(0, 20) == Ca.V_MAX and Ca.value(20, 20) == Ca.V_MIN
  for i = 1, 40 do if Ca.value(i * 0.5, 20) > Ca.value((i - 1) * 0.5, 20) then mono = false end end
  check(mono, "§6 valeur des buts : décroissante avec le retour, de 50 (T = 0) à 35 (T = T_max)")
  local okv = true
  for _, a in ipairs(sorted_keys(res)) do for _, x in ipairs(res[a].orders) do
    if x.value < Ca.V_MIN or x.value > Ca.V_MAX then okv = false end
  end end
  check(okv, "§6 valeur de chaque ordre entre 35 et 50 (sous la recherche, 62)")
  say(string.format("§6 budget (MU) : bâtisseur %.0f, technocrate %.0f, équilibré %.0f, conquérant %.0f ; engagé %.0f, %.0f, %.0f ; X7 : %d -> %d foreuses",
    res.builder.budget, res.technocrat.budget, res.balanced.budget, res.conqueror.budget, cb, ce, cc, hist[1].drills, hist[20].drills))
end

---------------------------------------------------------------------------------------------------
-- §7 Saturation sans débouché
---------------------------------------------------------------------------------------------------
local function s7()
  local D = vdata()
  -- Aucun puits : aucune croissance, aucun ordre (saturation globale).
  local r1 = Ca.decide(vin(D, { stock = pieces(), flows = { ["iron-ore"] = { made = 300 } },
    deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 2, deposit = "d1" } } }), {})
  check(#r1.orders == 0 and r1.g == 0, "§7 aucun puits : aucun ordre, croissance nulle (" .. #r1.orders .. ", g " .. r1.g .. ")")
  -- Stock qui dort : 50 000 plaques couvrent 100/min pendant bien plus de 10 min : rien en amont.
  local inp2 = iron_scene(D, 100, { stock = pieces({ ["iron-plate"] = 50000 }) })
  local r2 = Ca.decide(inp2, {})
  check(find(r2, "couvrir:d1") == nil and find(r2, "fours:iron-plate") == nil, "§7 50 000 plaques au coffre : ni foreuse ni four")
  -- Le même sans le stock : on investit (témoin).
  local r3 = Ca.decide(iron_scene(D, 100), {})
  check(find(r3, "couvrir:d1") ~= nil, "§7 témoin sans stock de plaques : couvrir d1")
end

---------------------------------------------------------------------------------------------------
-- §8 Données changées, même code
---------------------------------------------------------------------------------------------------
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
    stock = pieces({ ["electronic-circuit"] = 2000 }),
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
  local okc = true
  for _, k in ipairs(sorted_keys(D0.convertible)) do if not D2.convertible[map[k]] then okc = false end end
  check(okc, "§8e objets convertibles retrouvés sous d'autres noms")
  -- Dans une décision, un retour plus court vaut plus au cerveau (et au moins un écart de valeur).
  local strict, order_ok = false, true
  for _, a in ipairs(r0.orders) do for _, b2 in ipairs(r0.orders) do
    if a.T < b2.T - 1 then
      if a.value < b2.value then order_ok = false end
      if a.value > b2.value then strict = true end
    end
  end end
  check(order_ok and strict, "§8e valeurs des ordres rangées comme leurs retours")
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
--- `site2` ; production minute par minute (foreuses, creusets, ateliers, savants), stocks plafonnés en aval. Un ordre se
--- PAIE EN VRAIS INGRÉDIENTS (la recette de chaque bien, un niveau : rouages, lingots, roche, fioles), pris au coffre
--- après la fonte et avant l'aval (au plus la moitié de chaque objet par minute : la matière d'un ordre est réservée,
--- comme le fera P.take), et se pose la minute qui suit son paiement complet. Ce qui reste à payer est son `missing`.
local function sim(opts)
  opts = opts or {}
  local D = Ca.data(toy_dump(), {})
  local MIN, SITE2 = opts.minutes or 150, opts.site2 or 100
  local W = { stock = { lingot = 400, rouage = 50, fiole = 30, roche = 0 },
    deposits = { { id = "g1", resource = "roche", tiles = 405, amount = 3e6, dist = 40 } },
    drills = { g1 = 2 }, furnaces = 3, asm = { rouage = 1, fiole = 1 }, labs = 1, pending = {} }
  local st, H, viol = {}, {}, 0
  local made = { roche = 0, lingot = 0, rouage = 0, fiole = 0 }
  local lab_s = 0
  local last
  local function needs_of(o)
    local need = {}
    for _, it in ipairs(o.items or {}) do
      local r = D.recipes[(D.producers[it[1]] or {})[1]]
      for _, ing in ipairs(r.ingredients) do need[ing.name] = (need[ing.name] or 0) + ing.amount * it[2] end
    end
    return need
  end
  local function install(o)
    if o.kind == "couvrir" or o.kind == "ouvrir" then
      W.drills[o.deposit] = (W.drills[o.deposit] or 0) + o.n
    elseif o.kind == "fours" then W.furnaces = W.furnaces + o.n
    elseif o.kind == "chaine" or o.kind == "packs" then W.asm[o.item] = (W.asm[o.item] or 0) + o.n
    elseif o.kind == "labos" then W.labs = W.labs + o.n end
  end
  local function left_of(o)
    local l = 0
    for _, k in ipairs(sorted_keys(o.need)) do l = l + o.need[k] end
    return l
  end
  for t = 1, MIN do
    if t == SITE2 then W.deposits[#W.deposits + 1] = { id = "g2", resource = "roche", tiles = 405, amount = 3e6, dist = 120 } end
    -- Pose de ce qui est payé.
    local keep = {}
    for _, o in ipairs(W.pending) do
      if left_of(o) <= 0 and o.ready <= t then install(o) else keep[#keep + 1] = o end
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
    -- Paiement des ordres en attente AVANT la consommation de l'aval, en vrais ingrédients, au plus la moitié du coffre
    -- de chaque objet par minute.
    local cap = {}
    for _, k in ipairs(sorted_keys(S)) do cap[k] = math.floor(S[k] / 2) end
    for _, o in ipairs(W.pending) do
      for _, k in ipairs(sorted_keys(o.need)) do
        local pay = math.max(0, math.min(o.need[k], cap[k] or 0))
        o.need[k], S[k], cap[k] = o.need[k] - pay, S[k] - pay, (cap[k] or 0) - pay
      end
      if left_of(o) <= 0 and o.ready <= t then o.ready = t + 1 end
    end
    -- Aval : les fioles d'abord (rouages du coffre), puis les rouages refont le coffre jusqu'à son plafond (des coffres
    -- à la mesure des machines qu'ils nourrissent : 2 min de consommation, plus ce que les chantiers attendent).
    local wait_r = 0
    for _, o in ipairs(W.pending) do wait_r = wait_r + (o.need.rouage or 0) end
    local lim_r, lim_f = 300 + 12 * (W.asm.fiole or 0) + wait_r, 300 + 12 * W.labs
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
      for _, k in ipairs({ "kind", "key", "item", "resource", "recipe", "entity", "n", "deposit", "where", "value",
        "smelt_n", "smelt_recipe", "smelt_entity" }) do c[k] = o[k] end
      c.n_left = o.n
      local miss = {}
      for _, k in ipairs(sorted_keys(o.need)) do if o.need[k] > 0 then miss[#miss + 1] = { k, o.need[k] } end end
      c.missing = miss
      open[#open + 1] = c
    end
    local stock = {}
    for _, k in ipairs(sorted_keys(S)) do stock[k] = S[k] end
    local input = { data = D, state = { techs = { mecanique = true } }, stock = stock,
      flows = { roche = { made = made.roche }, lingot = { made = made.lingot }, rouage = { made = made.rouage },
        fiole = { made = made.fiole } },
      machines = machines, drills = drills, labs = { { entity = "savant", n = W.labs } }, deposits = deps, open = open,
      research = { queue = { { tech = "infini", left = 1e7, time = 10, packs = { { "fiole", 1 } } } }, rate = lab_s },
      workers = 30, idle = 10, can_grow = false, traits = opts.traits or {}, weights = opts.weights or {},
      lag = 2 } -- délai de pose du jouet : payé, puis posé la minute suivante (le runtime le mesurera)
    local res = Ca.decide(input, st)
    last = res
    -- Contrôle : un ordre de fours ne dépasse jamais ce que le minerai livré par les foreuses nourrit.
    local supply = made.roche
    local planned = W.furnaces
    for _, o in ipairs(W.pending) do if o.kind == "fours" then planned = planned + o.n end end
    for _, o in ipairs(res.orders) do
      if o.kind == "fours" then
        planned = planned + o.n
        if planned * 18.75 > supply + Ca.FRAC_UP * 18.75 + 1e-6 then viol = viol + 1 end
      end
    end
    -- Ordres : payés en vrais ingrédients (la recette de chaque bien).
    for _, o in ipairs(res.orders) do
      local c = {}
      for _, k in ipairs({ "kind", "key", "item", "resource", "recipe", "entity", "n", "deposit", "where", "value", "items" }) do c[k] = o[k] end
      c.need, c.ready = needs_of(o), t + 1
      W.pending[#W.pending + 1] = c
    end
    local ore = 0
    for _, f in ipairs(W.deposits) do ore = ore + (W.drills[f.id] or 0) * 30 end
    local kinds = {}
    for _, o in ipairs(res.orders) do kinds[#kinds + 1] = o.key end
    H[t] = { K = res.K, ore = ore, labs = W.labs, furnaces = W.furnaces, keys = table.concat(kinds, ","),
      explore = explores(res, "roche") ~= nil, lab_s = lab_s, g1 = W.drills.g1 or 0, g2 = W.drills.g2 or 0, Y = res.Y,
      bank = res.bank }
    if os.getenv("CAPI_DEBUG") and not quiet and t % 10 == 0 then -- diagnostic : CAPI_DEBUG=1 lua5.2 tests/…
      print(string.format("[CAPI-SIM] t=%d creusets %d ateliers rouage %d fiole %d savants %d ; coffre lingot %.0f rouage %.0f fiole %.0f roche %.0f ; fait roche %.0f lingot %.0f rouage %.0f fiole %.0f recherche %.0f ; en attente %d",
        t, W.furnaces, W.asm.rouage, W.asm.fiole or 0, W.labs, S.lingot, S.rouage, S.fiole, S.roche, made.roche, made.lingot,
        made.rouage, made.fiole, lab_s, #W.pending))
      print("[CAPI-SIM]   " .. Ca.text(res))
    end
  end
  return H, viol, last
end

local function s9()
  local H, viol = sim()
  check(viol == 0, "§9 fours toujours sous le minerai livré (" .. viol .. " écart(s))")
  check(H[40].K >= 2 * H[10].K, string.format("§9 le capital qui rapporte croît : K %.0f (10 min) -> %.0f (40 min) MU/min", H[10].K, H[40].K))
  -- Plafond : g1 couvert, plus de capacité d'extraction jusqu'au site suivant.
  local full = nil
  for t = 1, 99 do if H[t].g1 >= 30 and not full then full = t end end
  check(full ~= nil and full < 90, "§9 g1 couvert (30 foreuses) à la minute " .. tostring(full))
  local flat, explored = full ~= nil, false
  if full then
    for t = full, 99 do
      if H[t].ore ~= H[full].ore then flat = false end
      if H[t].explore then explored = true end
    end
  end
  check(flat and explored, "§9 plafond : extraction constante de la couverture de g1 à la minute 99, exploration demandée")
  local opened = nil
  for t = 100, 140 do if not opened and H[t].keys:find("ouvrir:g2", 1, true) then opened = t end end
  check(opened ~= nil and H[140].ore > H[99].ore and H[140].K > H[99].K * 1.2,
    string.format("§9 g2 ouvert à la minute %s ; extraction %d -> %d, K %.0f -> %.0f", tostring(opened), H[99].ore, H[140].ore,
      H[99].K, H[140].K))
  check(H[90].labs >= 5 * H[1].labs and H[90].lab_s > 5 * H[5].lab_s,
    string.format("§9 laboratoires %d -> %d, recherche %.0f -> %.0f s/min", H[1].labs, H[90].labs, H[5].lab_s, H[90].lab_s))
  -- Doublement du capital : mesuré sur la montée.
  local t2 = nil
  for t = 21, 99 do if not t2 and H[t].K >= 2 * H[20].K then t2 = t end end
  check(t2 ~= nil and t2 - 20 <= 30, "§9 doublement du capital depuis 20 min en " .. tostring(t2 and (t2 - 20)) .. " min")
  -- Caractère : le bâtisseur croît plus vite que le conquérant.
  local Hb = sim({ traits = Tr.ARCHETYPES.builder, weights = B.weights(nil, Tr.ARCHETYPES.builder), minutes = 60 })
  local Hc = sim({ traits = Tr.ARCHETYPES.conqueror, weights = B.weights(nil, Tr.ARCHETYPES.conqueror), minutes = 60 })
  check(Hb[50].K > Hc[50].K * 1.1, string.format("§9 bâtisseur %.0f > conquérant %.0f MU/min à 50 min", Hb[50].K, Hc[50].K))
  say(string.format("§9 K (MU/min) : %.0f, %.0f, %.0f, %.0f, %.0f, %.0f aux minutes 1, 10, 20, 40, 99, 140 ; doublement depuis 20 min en %s min ; g1 couvert à %s, g2 ouvert à %s",
    H[1].K, H[10].K, H[20].K, H[40].K, H[99].K, H[140].K, t2 and tostring(t2 - 20) or "-", tostring(full), tostring(opened)))
  say(string.format("§9 à 140 min : %d foreuses (g1 %d, g2 %d), %d creusets, %d savants ; bâtisseur %.0f, conquérant %.0f à 50 min",
    H[140].ore / 30, H[140].g1, H[140].g2, H[140].furnaces, H[140].labs, Hb[50].K, Hc[50].K))
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
  -- Puits EN DOUBLE (même objet, élastiques ou non) dans deux ordres, sur 3 cycles : même état, mêmes décisions.
  local function dup(order)
    local st, txt = {}, {}
    for c = 1, 3 do
      local inp = rich(D)
      local s1_ = { item = "firearm-magazine", rate = 20, elastic = true }
      local s2_ = { item = "firearm-magazine", rate = 60 }
      inp.sinks = order and { s1_, s2_ } or { s2_, s1_ }
      txt[c] = Ca.text(Ca.decide(inp, st))
    end
    return table.concat(txt, "\n"), st.sink_t["firearm-magazine"]
  end
  local ta, sa = dup(true)
  local tb, sb = dup(false)
  check(ta == tb and sa == sb, string.format("§10 puits en double dans deux ordres : mêmes décisions, cible %s / %s", tostring(sa), tostring(sb)))
end

local big_scene -- scène de coût (définie plus bas)

---------------------------------------------------------------------------------------------------
-- §13 Cerveau : buts de fond, réémis tant que l'ordre est ouvert ; la recherche garde sa place
---------------------------------------------------------------------------------------------------
local function s13()
  local D = vdata()
  local r1 = Ca.decide(iron_scene(D, 150), {})
  local g1 = Ca.goals({}, r1, {})
  local okf = #g1 == #r1.orders and #g1 > 0
  for _, g in ipairs(g1) do
    if not g.fond or g.kind ~= "capi" then okf = false end
    for _, k in ipairs(sorted_keys(g.order)) do if type(g.order[k]) == "function" then okf = false end end
  end
  check(okf, "§13 un but de FOND par ordre, sans fonction (état sérialisable)")
  -- Deux pensées avec le VRAI P.update : l'ordre décidé à la pensée 1 est ouvert à la pensée 2 (la règle ne le redemande
  -- pas) ; Ca.goals le réémet, le projet reste ouvert ; il ne se ferme qu'à la fin de l'ordre.
  local stp = {}
  P.update(stp, g1, 60, 30)
  local open = {}
  for _, o in ipairs(r1.orders) do
    local c = deep(o)
    c.n_left = c.n
    open[#open + 1] = c
  end
  local r2 = Ca.decide(iron_scene(D, 150, { open = open }), {})
  local g2 = Ca.goals({}, r2, open)
  P.update(stp, g2, 120, 30)
  local still, closed = false, false
  for _, p in ipairs(stp.projects) do if p.key == "capi:couvrir:d1" then still = true end end
  for _, l in ipairs(stp.log or {}) do if l.kind == "fini" and l.key == "capi:couvrir:d1" then closed = true end end
  check(find(r2, "couvrir:d1") == nil and still and not closed,
    "§13 pensée 2 : couvrir:d1 ouvert, non redemandé, projet toujours ouvert (aucun « fini »)")
  P.update(stp, Ca.goals({}, { orders = {} }, {}), 180, 30)
  local fin = false
  for _, l in ipairs(stp.log or {}) do if l.kind == "fini" and l.key == "capi:couvrir:d1" then fin = true end end
  check(fin, "§13 ordre fini (sorti de la liste ouverte) : projet fermé")
  -- Beaucoup d'ordres capi (60 gisements, grosse réserve, forte demande) : la recherche (62) et l'extraction (70) gardent leur place
  -- parmi les K = 9 projets à 30 PNJ, même avec le P.update d'aujourd'hui (qui ne connaît pas encore g.fond).
  local big = Ca.decide(big_scene(D, 60, 60000, 4), {})
  local gl = { { key = "recherche", family = "recherche", kind = "research", value = B.RESEARCH },
    { key = "extraction:fer", family = "extraction", kind = "outpost", value = 70 } }
  Ca.goals(gl, big, {})
  local stb = {}
  local out = P.update(stb, gl, 60, 30)
  local active = {}
  for _, p in ipairs(out) do if p.state == "actif" then active[p.key] = true end end
  check(#big.orders >= 12 and active["recherche"] and active["extraction:fer"] and gl[1].key == "extraction:fer"
    and gl[2].key == "recherche",
    string.format("§13 %d ordres capi : recherche et extraction actives, en tête des buts", #big.orders))
  -- Interface : `obtainable` donné en TABLE (ev.feas d'IA-G) ; sans effectif (`workers` absent), le journal reste lisible.
  local feas = {}
  for _, k in ipairs({ "burner-mining-drill", "stone-furnace", "iron-gear-wheel", "iron-plate", "iron-ore", "stone" }) do feas[k] = true end
  local rt = Ca.decide(iron_scene(D, 150, { obtainable = feas }), {})
  local ot = find(rt, "couvrir:d1")
  local inp_nw = iron_scene(D, 150)
  inp_nw.workers = nil
  local txt = Ca.text(Ca.decide(inp_nw, {}))
  check(ot and ot.entity == "burner-mining-drill" and not txt:find("nan", 1, true) and txt:find("bras=", 1, true),
    "§13 obtainable en table (foreuse électrique absente : " .. tostring(ot and ot.entity) .. ") ; sans effectif : aucun NaN au journal")
  -- Part de l'armée et de la défense gardée à la réservation : Ca.capi_view.
  local view = Ca.capi_view({ ["iron-plate"] = 1000, ["iron-gear-wheel"] = 7 }, { delta = 100, alpha = 150 })
  check(view["iron-plate"] == 750 and view["iron-gear-wheel"] == 5, "§13 stock virtuel des projets capi : (1 − δ − α) de chaque objet")
end

---------------------------------------------------------------------------------------------------
-- Scène de coût : `n` gisements (fer, cuivre, pierre, charbon), 4 ouverts, une grosse réserve.
---------------------------------------------------------------------------------------------------
big_scene = function(D, n, circuits, mult)
  mult = mult or 1
  local res = { "iron-ore", "copper-ore", "stone", "coal" }
  local deps, drills = {}, {}
  for i = 1, n do
    local r = res[(i - 1) % 4 + 1]
    local open = i <= 4
    deps[#deps + 1] = { id = string.format("g%03d", i), resource = r, tiles = 200 + (i * 37) % 300, amount = 1e6,
      dist = 40 + (i * 53) % 900, open = open }
    if open then drills[#drills + 1] = { entity = "electric-mining-drill", resource = r, n = 2, deposit = deps[#deps].id } end
  end
  return pack_scene(D, { stock = { ["electronic-circuit"] = circuits or 3000 }, deposits = deps, drills = drills,
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 6, where = "qg" },
      { entity = "stone-furnace", recipe = "copper-plate", n = 4, where = "qg" } },
    flows = { ["iron-ore"] = { made = 60 }, ["copper-ore"] = { made = 60 }, stone = { made = 60 }, coal = { made = 60 },
      ["iron-plate"] = { made = 110 }, ["copper-plate"] = { made = 75 } },
    sinks = { { item = "iron-plate", rate = 900 * mult }, { item = "copper-plate", rate = 600 * mult },
      { item = "stone-brick", rate = 60 * mult }, { item = "firearm-magazine", rate = 20, elastic = true } } })
end

---------------------------------------------------------------------------------------------------
-- §14 Lot CAPI-REPLI : repli des ordres refusés (règle pure shared/ai3/repli.lua)
---------------------------------------------------------------------------------------------------
local function s14()
  local MIN = 3600
  local PLAN = "plan directeur : pas de lot"
  local MAT = "plan directeur : materiaux introuvables (15 min sans progres)"
  -- a. PAR GISEMENT : un refus sur un gisement ne ferme ni l'autre gisement du produit, ni un autre produit
  do
    local b = {}
    local kA, kB, kC = Rp.key("p1", "A"), Rp.key("p1", "B"), Rp.key("p2", "A")
    check(kA ~= kB and kA ~= kC, "§14a clés distinctes par produit ET par gisement")
    check(Rp.key("p1", nil) == "p1" and Rp.key("p1", "") == "p1", "§14a sans gisement : le produit seul (chaînes)")
    check(Rp.fail(b, kA, PLAN, 10 * MIN) == "plan", "§14a refus du plan : repli")
    check(Rp.held(b, kA, 11 * MIN) ~= nil, "§14a le gisement refusé est en repli")
    check(Rp.held(b, kB, 11 * MIN) == nil, "§14a l'autre gisement du même produit reste ouvert")
    check(Rp.held(b, kC, 11 * MIN) == nil, "§14a un autre produit sur le même gisement reste ouvert")
    check(Rp.held(b, kA, 10 * MIN + Rp.BASE - 1) ~= nil and Rp.held(b, kA, 10 * MIN + Rp.BASE) == nil,
      "§14a premier repli = Rp.BASE exactement")
  end
  -- b. n REMIS À ZÉRO par un module terminé
  do
    local b, k = {}, Rp.key("p1", "A")
    for i = 1, 4 do Rp.fail(b, k, PLAN, i * MIN) end
    check(b[k].n == 4, "§14b quatre refus : n = 4")
    check(b[k].until_tick - 4 * MIN == Rp.MAX, "§14b le repli plafonne à Rp.MAX")
    Rp.done(b, k)
    check(Rp.held(b, k, 5 * MIN) == nil, "§14b module terminé : plus de repli")
    Rp.fail(b, k, PLAN, 100 * MIN)
    check(b[k].n == 1 and b[k].until_tick - 100 * MIN == Rp.BASE, "§14b après un module terminé, le refus suivant repart de n = 1")
  end
  -- c. n DÉCROÎT avec le temps (un cran par Rp.DECAY sans échec)
  do
    local b, k = {}, Rp.key("p1", "A")
    Rp.fail(b, k, PLAN, 0)
    Rp.fail(b, k, PLAN, 1 * MIN)
    Rp.fail(b, k, PLAN, 2 * MIN)
    check(b[k].n == 3 and Rp.eff(b[k], 2 * MIN, "n") == 3, "§14c trois refus rapprochés : n = 3")
    check(Rp.eff(b[k], 2 * MIN + Rp.DECAY, "n") == 2, "§14c un cran de moins après Rp.DECAY")
    check(Rp.eff(b[k], 2 * MIN + 3 * Rp.DECAY, "n") == 0, "§14c retombé à zéro après 3 × Rp.DECAY")
    local t = 2 * MIN + Rp.DECAY
    Rp.fail(b, k, PLAN, t)
    check(b[k].n == 3 and b[k].until_tick - t == Rp.BASE * 4, "§14c refus après décroissance : n = 2 + 1, repli 10 × 2^2 min")
    local b2 = {}
    Rp.fail(b2, k, PLAN, 0)
    Rp.fail(b2, k, PLAN, 3 * Rp.DECAY)
    check(b2[k].n == 1 and b2[k].until_tick - 3 * Rp.DECAY == Rp.BASE, "§14c un vieux refus ne compte plus : repli de base")
  end
  -- d. UN ÉCHEC DE MATÉRIAUX NE BLOQUE PAS : module réduit, objets en préparation
  do
    local b, k = {}, Rp.key("p1", "A")
    check(Rp.is_material(MAT) and not Rp.is_material(PLAN) and not Rp.is_material(nil), "§14d classement des raisons")
    check(Rp.factor(b, k, 0) == 1, "§14d sans échec : module entier")
    local miss = { { "x", 30 }, { "y", 4 }, { "z", 0 } }
    check(Rp.fail(b, k, MAT, 80 * MIN, miss) == "materiaux", "§14d échec de matériaux reconnu")
    check(Rp.held(b, k, 80 * MIN) == nil and Rp.held(b, k, 81 * MIN) == nil, "§14d le gisement n'est PAS en repli")
    check(Rp.factor(b, k, 80 * MIN) == 0.5, "§14d module suivant réduit de moitié")
    Rp.fail(b, k, MAT, 95 * MIN, miss)
    check(Rp.factor(b, k, 95 * MIN) == 0.25, "§14d deuxième échec : un quart")
    Rp.fail(b, k, MAT, 110 * MIN, miss)
    check(Rp.factor(b, k, 110 * MIN) == 0.25, "§14d réduction bornée à 1/2^Rp.SHRINK_MAX")
    local prep = Rp.prep(b, 111 * MIN)
    check(#prep == 1 and prep[1].key == k and #prep[1].missing == 2 and prep[1].missing[1][1] == "x" and prep[1].missing[1][2] == 30,
      "§14d objets manquants gardés (quantité nulle écartée)")
    check(#Rp.prep(b, 110 * MIN + Rp.PREP_TTL) == 0, "§14d préparation expirée après Rp.PREP_TTL")
    check(Rp.factor(b, k, 110 * MIN + Rp.DECAY) == 0.5 and Rp.factor(b, k, 110 * MIN + 2 * Rp.DECAY) == 1,
      "§14d la réduction décroît avec le temps")
    Rp.done(b, k)
    check(Rp.factor(b, k, 111 * MIN) == 1 and #Rp.prep(b, 111 * MIN) == 0, "§14d module terminé : taille entière, plus de préparation")
    -- un échec de matériaux garde un repli du PLAN déjà posé, sans le prolonger
    local b2 = {}
    Rp.fail(b2, k, PLAN, 10 * MIN)
    local u = b2[k].until_tick
    Rp.fail(b2, k, MAT, 12 * MIN, miss)
    check(b2[k].until_tick == u and b2[k].n == 1, "§14d le repli du plan déjà posé n'est ni retiré ni prolongé par un échec de matériaux")
  end
  -- e. PLAFOND de 5 min : couverture sous 50 % ET besoin non servi
  do
    local b, k = {}, Rp.key("p1", "A")
    for _ = 1, 3 do Rp.fail(b, k, PLAN, 0) end
    local low = { kappa = 400, unserved = true }
    check(Rp.held(b, k, 30 * MIN) ~= nil, "§14e sans plafond : 40 min de repli après 3 refus")
    check(Rp.held(b, k, 30 * MIN, { kappa = 400, unserved = false }) ~= nil, "§14e besoin servi : pas de plafond")
    check(Rp.held(b, k, 30 * MIN, { kappa = 500, unserved = true }) ~= nil, "§14e couverture à 50 % : pas de plafond")
    check(Rp.held(b, k, 30 * MIN, { kappa = 900, unserved = true }) ~= nil, "§14e gisement couvert : pas de plafond")
    check(Rp.held(b, k, 4 * MIN, low) ~= nil, "§14e plafonné : encore en repli à 4 min")
    check(Rp.held(b, k, Rp.MAX_STARVED - 1, low) ~= nil and Rp.held(b, k, Rp.MAX_STARVED, low) == nil, "§14e plafonné : libre à 5 min exactement")
    check(Rp.held(b, k, 6 * MIN, low) == nil and Rp.held(b, k, 6 * MIN) ~= nil, "§14e le plafond ne vaut que dans les conditions")
  end
  -- f. le cas MESURÉ d'Azur (partie du DC) : refus à 3,9 min, échecs de matériaux à 78,8 et 79,6 min ; avant : fer fermé
  -- jusqu'à 119,8 min avec 281 places libres
  do
    local b = {}
    local kA, kB = Rp.key("plaque", "A"), Rp.key("plaque", "B")
    Rp.fail(b, kA, PLAN, math.floor(3.9 * MIN))
    check(Rp.held(b, kA, 79 * MIN) == nil, "§14f le refus du plan de 3,9 min est fini à 79 min")
    Rp.fail(b, kB, MAT, math.floor(78.8 * MIN), { { "x", 10 } })
    Rp.fail(b, kB, MAT, math.floor(79.6 * MIN), { { "x", 10 } })
    check(Rp.held(b, kB, math.floor(79.7 * MIN)) == nil and Rp.held(b, kA, math.floor(79.7 * MIN)) == nil,
      "§14f à 79,7 min aucun gisement de fer n'est fermé (l'ancien repli : 40 min)")
    check(Rp.held(b, kB, 100 * MIN) == nil and Rp.held(b, kA, 119 * MIN) == nil, "§14f ni à 100 min, ni à 119 min")
    check(Rp.factor(b, kB, math.floor(79.7 * MIN)) == 0.25, "§14f le prochain module de ce gisement est réduit au quart")
  end
  -- g. déterminisme : préparation triée, quel que soit l'ordre d'insertion ; élagage des entrées mortes
  do
    local function build(order)
      local b = {}
      for _, name in ipairs(order) do Rp.fail(b, Rp.key("p", name), MAT, 5 * MIN, { { name, 1 } }) end
      return b
    end
    local a = Rp.prep(build({ "c", "a", "b" }), 6 * MIN)
    local c = Rp.prep(build({ "b", "c", "a" }), 6 * MIN)
    local sa, sc = {}, {}
    for i = 1, #a do sa[i] = a[i].key end
    for i = 1, #c do sc[i] = c[i].key end
    check(table.concat(sa, ",") == "p@a,p@b,p@c" and table.concat(sa, ",") == table.concat(sc, ","), "§14g préparation triée par clé")
    local b = build({ "a", "b" })
    Rp.fail(b, "plan", PLAN, 5 * MIN)
    check(Rp.prune(b, 6 * MIN) == 0, "§14g rien à élaguer tant que tout est vivant")
    check(Rp.prune(b, 5 * MIN + 4 * Rp.DECAY) == 3 and next(b) == nil, "§14g tout est élagué quand repli, préparation et compteurs sont éteints")
    check(Rp.eff(nil, 0, "n") == 0 and Rp.factor({}, "k", 0) == 1 and Rp.held({}, "k", 0) == nil and Rp.describe({}, "k", 0) == "-",
      "§14g clé inconnue : aucune erreur, rien en repli")
  end
end

---------------------------------------------------------------------------------------------------
-- §15 Lot PREVISION (C12, arbitrage du DC « oui, compter la défense ») : la pollution qu'un ordre AJOUTE entraîne les tourelles
-- qu'elle rendra nécessaires ; leur prix (input.defense.price, MU par pollution/min, shared/ai3/prevision.lua) entre dans le
-- RETOUR (le choix), jamais dans le budget de la capitalisation.
---------------------------------------------------------------------------------------------------
local function s15()
  local function emits(d)
    for _, e in ipairs(d.entities) do
      if e.name == "electric-mining-drill" then e.emit = 10 elseif e.name == "stone-furnace" then e.emit = 2 end
    end
  end
  local D = vdata(emits)
  local em = Ca.option_emit({ D = D }, { kind = "couvrir", entity = "electric-mining-drill", n = 3, smelt_entity = "stone-furnace", smelt_n = 2 })
  check(math.abs(em - 34) < 1e-9, "§15 pollution ajoutée par un ordre (3 foreuses à 10/min, 2 fours à 2/min) : 34/min (" .. em .. ")")
  check(Ca.option_emit({ D = D }, { kind = "energie", kw = 900 }) == 0, "§15 un levier sans machine n'ajoute aucune pollution")
  local sc = function(over) return iron_scene(D, 1000, over) end
  local base = Ca.decide(sc({ stock = pieces({ ["electronic-circuit"] = 3000 }) }), {})
  local priced = Ca.decide(sc({ stock = pieces({ ["electronic-circuit"] = 3000 }), defense = { price = 2 } }), {})
  local hit, same_budget = nil, true
  for _, o in ipairs(priced.orders) do
    if (o.def_mu or 0) > 0 then
      local b = find(base, o.key)
      if b and not hit then hit = { o = o, b = b } end
    end
  end
  check(hit ~= nil, "§15 un ordre pollueur porte le prix de sa défense induite")
  if hit then
    check(math.abs(hit.o.def_mu - hit.o.emit * 2) < 1e-6 and hit.o.T > hit.b.T and math.abs(hit.o.cost_m - hit.b.cost_m) < 1e-6,
      string.format("§15 défense comptée dans le RETOUR (T %s -> %s), pas dans le budget (matières %s = %s)", tostring(hit.b.T),
        tostring(hit.o.T), tostring(hit.b.cost_m), tostring(hit.o.cost_m)))
  end
  for _, o in ipairs(base.orders) do if o.def_mu then same_budget = false end end
  check(same_budget, "§15 sans prix (aucun nid connu, prévision coupée) : aucune défense induite, décisions d'avant")
  local dear = Ca.decide(sc({ stock = pieces({ ["electronic-circuit"] = 3000 }), defense = { price = 1e6 } }), {})
  local refused = false
  for _, r in ipairs(dear.refus) do if r.why and r.why:find("retour", 1, true) then refused = true end end
  local polluting = 0
  for _, o in ipairs(dear.orders) do if (o.emit or 0) > 0 then polluting = polluting + 1 end end
  check(refused and polluting == 0, "§15 défense induite hors de prix (nids voisins en masse) : aucun agrandissement pollueur, refus « retour »")
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
  s13()
  s14()
  s15()
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
local function MV(name, field, value)
  local old = Ca[field]
  M(name, function() Ca[field] = value end, function() Ca[field] = old end)
end
local function MF(name, field, make)
  local old = Ca[field]
  M(name, function() Ca[field] = make(old) end, function() Ca[field] = old end)
end
do
  MF("fours au-delà du minerai arrivé", "fed_max", function() return function() return 999 end end)
  MV("ouvrir sans attendre la couverture", "KAPPA", 0)
  MV("stock qui dort ignoré", "H_STOCK", 1e12)
  -- Les ordres OUVERTS (entrée, sans retour T) restent appliqués ; les ordres décidés dans le cycle ne le sont plus.
  MF("plan non mis à jour (gain non marginal)", "apply", function(ap)
    return function(ctx, plan, o) if o.T == nil then return ap(ctx, plan, o) end end
  end)
  MF("budget ignoré (parts armée et défense)", "budget", function() return function() return 1e12, 1e12, 0 end end)
  MF("travail payé avec des bras libres", "labor_price", function()
    return function(Y, w) return (Y or 0) / math.max(1, w or 1) + 1 end
  end)
  MF("assembleur pris sans sa recherche", "recipe_open", function() return function() return true end end)
  MF("laboratoires au-delà des packs", "lab_cap", function() return function() return math.huge end end)
  MF("caractère ignoré", "character", function(ch) return function(_, _, th) return ch({}, {}, th) end end)
  MV("aval servi avant son ingrédient (goulot ignoré)", "THETA_MIN", 0)
  MV("menace ignorée", "THREAT_DIV", 1)
  MV("croissance coupée", "G_MAX", 0)
  MF("débouché ignoré (toute ressource demandée)", "requirements", function(rq)
    return function(ctx, plan)
      local r = rq(ctx, plan)
      for _, k in ipairs(ctx.D.res_list) do if not ctx.D.res[k].fluid and (r.R[k] or 0) <= 0 then
        r.R[k] = 100
        r.depth[k] = 0
        r.list[#r.list + 1] = k
      end end
      return r
    end
  end)
  -- Mutants survivants du correcteur (13 sur 14 survivaient) et règles nouvelles de la correction.
  MV("main comptée comme capacité", "HAND_CAPITAL", 1)
  MF("ordres ouverts ignorés (doublons)", "taken", function() return function() return false end end)
  MF("danger ignoré", "usable", function(u)
    return function(ctx, f, kind) local w = u(ctx, f, kind) if w == "danger" then return nil end return w end
  end)
  MV("réserve de places à 0", "RESERVE_PCT", 0)
  MF("gisements connus ignorés", "is_known", function() return function() return true end end)
  MF("fonte sur place coupée", "smelt_of", function() return function() return nil end end)
  MV("LEAD infini", "LEAD", 1e9)
  MF("T_max retiré", "character", function(ch)
    return function(a, b, c) local x = ch(a, b, c) x.tmax = 1e9 return x end
  end)
  MF("valeur des ordres constante", "value", function() return function() return 45 end end)
  MV("laboratoires bloqués sous menace", "HQ_LEVERS", { fours = true, chaine = true, packs = true, energie = true })
  MF("tri des options inversé", "before", function()
    return function(a, b)
      if a.Tq ~= b.Tq then return a.Tq > b.Tq end
      if a.depth ~= b.depth then return a.depth < b.depth end
      return a.key < b.key
    end
  end)
  MV("épuisement ignoré", "H_LIFE", 0)
  MV("épargne coupée (budget non cumulé)", "BANK_H", 0)
  MF("stock non convertible compté", "convertible", function() return function() return true end end)
  MF("fours sur le stock et la main", "supply_of", function()
    return function(ctx, item)
      local f = ctx.flows[item] or {}
      return (f.made or 0) + (ctx.stock[item] or 0) / Ca.H_STOCK
    end
  end)
  MF("valeur pleine à chaque étage (retour de chaîne coupé)", "share", function() return function() return 1 end end)
  MF("goulot sous une demi-machine ignoré", "count_for", function() return function(def, unit) return Ca.count(def, unit) end end)
  -- Lot CAPI-REPLI : chaque règle du repli cassée doit faire échouer un contrôle de §14.
  local function MR(name, field, make)
    local old = Rp[field]
    M(name, function() Rp[field] = make(old) end, function() Rp[field] = old end)
  end
  local function MRV(name, field, value)
    local old = Rp[field]
    M(name, function() Rp[field] = value end, function() Rp[field] = old end)
  end
  MR("repli porté par le produit (gisement ignoré)", "key", function() return function(product) return tostring(product) end end)
  MR("n jamais remis à zéro", "done", function() return function() end end)
  MR("n sans décroissance", "eff", function() return function(b, _, field) return b and b[field] or 0 end end)
  MR("échec de matériaux traité comme un refus du plan", "is_material", function() return function() return false end end)
  MR("échec de matériaux sans réduction", "factor", function() return function() return 1 end end)
  MR("préparation oubliée", "prep", function() return function() return {} end end)
  MRV("plafond de 5 min supprimé", "MAX_STARVED", 40 * 3600)
  MR("plafond de 5 min toujours appliqué", "starved", function() return function() return true end end)
  MR("plafond de 5 min sans le besoin non servi", "starved", function()
    return function(o) return o ~= nil and (o.kappa or 1000) < Rp.COVER_LOW end
  end)
  MRV("repli sans plafond de durée", "MAX", 1e12)
  MRV("réduction sans borne", "SHRINK_MAX", 6)
  MR("repli ignoré", "held", function() return function() return nil end end)
  MR("élagage qui garde tout", "prune", function() return function() return 0 end end)
  -- Lot PREVISION (C12).
  MF("défense induite ignorée", "option_emit", function() return function() return 0 end end)
end
check(n_caught == n_mut, string.format("mutants : %d refusés sur %d", n_caught, n_mut))

-- §12 Coût de calcul (ordre de grandeur, PC non épinglé) : scène riche (4 gisements), 60 et 200 gisements connus.
do
  local D = vdata()
  local function per_decision(inp, n)
    local worst = 0
    local t1 = os.clock()
    for _ = 1, n do
      local a = os.clock()
      Ca.decide(inp, {})
      local dtm = os.clock() - a
      if dtm > worst then worst = dtm end
    end
    return (os.clock() - t1) * 1000 / n, worst * 1000
  end
  -- Mesure déterministe : instructions de la machine virtuelle (en milliers) du pire appel, indépendante de la charge du PC.
  local function worst_kinstr(inp, n)
    local worst = 0
    for _ = 1, n do
      local c = 0
      debug.sethook(function() c = c + 1 end, "", 1000)
      Ca.decide(inp, {})
      debug.sethook()
      if c > worst then worst = c end
    end
    return worst
  end
  local k4 = worst_kinstr(rich(D), 20)
  local k60 = worst_kinstr(big_scene(D, 60, 20000), 10)
  local k200 = worst_kinstr(big_scene(D, 200, 20000), 5)
  local m4, w4 = per_decision(rich(D), 20)
  local m60, w60 = per_decision(big_scene(D, 60, 20000), 10)
  local m200, w200 = per_decision(big_scene(D, 200, 20000), 5)
  local t2 = os.clock()
  for _ = 1, 3 do Ca.data(vanilla_dump(), { exec = EXEC_AUTO, exec_roles = ROLES }) end
  local per_data = (os.clock() - t2) * 1000 / 3
  print(string.format("[CAPI] §12 coût (ms, PC non épinglé) : une décision : 4 gisements %.2f (pic %.2f), 60 gisements %.2f (pic %.2f), 200 gisements %.2f (pic %.2f) ; relevé %.1f ; tout le banc %.1f s",
    m4, w4, m60, w60, m200, w200, per_data, t_run))
  -- Correction du 28/10 (lot DOC) : le contrôle « pics sous 20, 40 et 80 ms » échouait dès que le PC était chargé (pics 76, 92 ms
  -- pendant des bancs moteur : le temps mesuré suit la charge, pas le code). Le garde-fou est maintenant en INSTRUCTIONS de la
  -- machine virtuelle (milliers, du pire appel) : déterministe, mesuré le 28/10 à 46, 122 et 243 ; la limite est le DOUBLE
  -- (un calcul qui double de complexité échoue). Les millisecondes restent affichées et gardent une limite large (10 fois
  -- l'ancienne : 200, 400 et 800 ms) qui ne voit que l'effondrement ; l'ancienne limite stricte est écrite en avertissement.
  check(k4 <= 92 and k60 <= 244 and k200 <= 486, string.format("§12 pires appels en milliers d'instructions : %d, %d, %d (limites 92, 244, 486 ; mesuré 46, 122, 243)", k4, k60, k200))
  check(w4 < 200 and w60 < 400 and w200 < 800, string.format("§12 pics sous 200, 400 et 800 ms (%.1f, %.1f, %.1f)", w4, w60, w200))
  if not (w4 < 20 and w60 < 40 and w200 < 80) then
    print(string.format("[CAPI] AVERTISSEMENT §12 : pics au-dessus de l'ancienne limite 20, 40 et 80 ms (%.1f, %.1f, %.1f) : PC chargé ?", w4, w60, w200))
  end
end

-- §13 Lot ELEC2 : un ordre qui étend la capacité d'une matière en manque (o.short posé par le runtime) devient un but
-- d'INVESTISSEMENT : servi après l'objectif du moment et les familles permanentes (armée, munitions), devant les projets
-- ordinaires restants et les autres buts de fond ; sans `short`, il reste servi en dernier.
do
  local goals = {
    { key = "recherche", family = "recherche", kind = "research", value = 70 },
    { key = "extraction:a", family = "extraction", kind = "outpost", value = 60 },
    { key = "armee", family = "armee", kind = "army", value = 46, permanent = true },
    { key = "armee2", family = "armee", kind = "army", value = 44, permanent = true },
    { key = "defense:munitions", family = "defense", kind = "ammo", value = 45, permanent = true },
  }
  Ca.goals(goals, nil, {
    { key = "couvrir:fer", kind = "couvrir", item = "iron-ore", value = 38, exec = "module", short = true },
    { key = "couvrir:cuivre", kind = "couvrir", item = "copper-ore", value = 39, exec = "module" },
  })
  local order = P.update({}, goals, 0, 8)
  local pos = {}
  for i, p in ipairs(order) do pos[p.key] = i end
  local by = {}
  for _, g in ipairs(goals) do by[g.key] = g end
  check(by["capi:couvrir:fer"].invest == true and by["capi:couvrir:cuivre"].invest == nil,
    "§13 seul l'ordre marqué `short` devient un investissement")
  check(pos["recherche"] == 1, "§13 l'objectif du moment reste premier")
  check(pos["capi:couvrir:fer"] > pos["armee2"] and pos["capi:couvrir:fer"] > pos["defense:munitions"],
    "§13 investissement : après les familles permanentes")
  check(pos["capi:couvrir:fer"] < pos["extraction:a"], "§13 investissement : devant les projets ordinaires restants")
  check(pos["capi:couvrir:fer"] < pos["capi:couvrir:cuivre"] and pos["capi:couvrir:cuivre"] == #order,
    "§13 sans `short` : un but de fond, servi en dernier")
end

print(string.format("[CAPI] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refusés sur %d)", pass, fail, n_caught, n_mut))
if fail > 0 then os.exit(1) end
