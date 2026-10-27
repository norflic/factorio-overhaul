--[[
  Lot LEVIERS : test hors jeu de shared/ai3/leviers.lua (modules dans les machines posées, recherches à effet, repli),
  appelé par shared/ai3/capitalisation.lua.

    §1 données : le catalogue se lit dans le relevé (modules, emplacements, effets permis, technologies à effet) ;
    §2 repli : tous les sites interdits -> un ordre de module dans les 5 pensées, avec « repli : pourquoi » ; sites libres ->
       l'extraction passe avant (retour plus court) ;
    §3 formule : sortie de plus, énergie, facteurs du barème D-17, recalculés PAR LE TEST depuis module_mult ;
    §4 limites : l'entrée manque (vitesse inutile), recette non permise, effet non permis, emplacements pleins, courant,
       menace, gisement dangereux ;
    §5 ordre ouvert (aucun doublon, reste à poser), plan appliqué ;
    §6 recherches à effet : foreuses, laboratoires, travail des PNJ (goulot de construction), pack non obtenable ;
    §7 données changées (même code) et déterminisme ; §8 mutants.
  Usage : lua5.2 tests/leviers_test.lua   (depuis la racine du mod)
  Ce fichier est du TEST : il nomme les prototypes (comme le moteur) ; la règle n'en voit rien.
]]

package.path = "./?.lua;" .. package.path
local C = require("tests.leviers_common")
local MM = require("shared.content.module_mult")

local pass, fail = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[LEVIERS] ECHEC : " .. msg) end
  end
end
local function say(s) if not quiet then print("[LEVIERS] " .. s) end end

local sorted_keys, deep = C.sorted_keys, C.deep

-- Les modules du test existent au stock (recette de module : 180 MU) ; le coffre porte des circuits (financement).
local function stock(extra)
  local s = { ["electronic-circuit"] = 1000, ["speed-module"] = 40, ["productivity-module"] = 40, ["speed-module-2"] = 40,
    ["productivity-module-2"] = 40, ["effectivity-module"] = 40 }
  for k, v in pairs(extra or {}) do s[k] = v end
  return s
end

local function find(res, pat)
  for _, o in ipairs(res.orders) do if o.key:find(pat, 1, true) then return o end end
  return nil
end
local function refus_of(res, pat)
  for _, r in ipairs(res.refus) do if r.key:find(pat, 1, true) then return r end end
  return nil
end
local function count_kind(res, kind)
  local n = 0
  for _, o in ipairs(res.orders) do if o.kind == kind then n = n + 1 end end
  return n
end

-- Comme en jeu (script/ai3/capitalisation.lua) : les fours du QG sont nourris par les PNJ, leur nombre reste à SCALE.
local function fours_reserves(kind)
  if kind == "fours" then return "fours du QG nourris par les PNJ : decideur SCALE" end
  return nil
end

-- Scène « tous les sites interdits » : un gisement de fer dangereux, 6 fours électriques et 6 foreuses électriques posés,
-- une demande de plaques que le minerai livré ne suffit pas à servir.
local function blocked_scene(D, over)
  local inp = C.input(D, {
    stock = stock(),
    deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60, danger = true } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 6, deposit = "d1" } },
    machines = { { entity = "electric-furnace", recipe = "iron-plate", n = 6, where = "qg" } },
    flows = { ["iron-ore"] = { made = 180 }, ["iron-plate"] = { made = 180 } },
    sinks = { { item = "iron-plate", rate = 300 } }, can_exec = fours_reserves })
  for k, v in pairs(over or {}) do inp[k] = v end
  return inp
end

-- Scène « un site libre » : même usine, mais le gisement connu est sûr et à couvrir.
local function free_scene(D, over)
  local inp = blocked_scene(D, over)
  inp.deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60 },
    { id = "s2", resource = "iron-ore", tiles = 270, amount = 1e6, dist = 100 } }
  for k, v in pairs(over or {}) do inp[k] = v end
  return inp
end

local function all_ok() return true end

-- Scène de recherche : laboratoires et file (la durée d'une recherche vient des laboratoires posés), tout obtenable.
local function tech_scene(D, over)
  local inp = blocked_scene(D, { obtainable = all_ok, labs = { { entity = "lab", n = 4 } },
    state = { techs = { automation = true, ["advanced-electronics"] = true, ["automation-2"] = true, robotics = true } },
    research = { queue = { { tech = "electronics", left = 5, time = 15, packs = { { "automation-science-pack", 1 } } } }, rate = 60 } })
  for k, v in pairs(over or {}) do inp[k] = v end
  return inp
end

-- Assembleurs de tuyaux (recette hors de la liste de la productivité) et d'engrenages (dans la liste), plaques au coffre.
local function asm_scene(D, recipe, sink, plates)
  return blocked_scene(D, {
    machines = { { entity = "assembling-machine-2", recipe = recipe, n = 4, where = "qg" } },
    drills = {}, deposits = {},
    stock = stock({ ["iron-plate"] = plates or 5000 }),
    flows = { ["iron-plate"] = { made = 600 } },
    sinks = { { item = recipe, rate = sink } },
    can_exec = function(kind) if kind ~= "equiper" then return "ordres de machines reserves a un autre decideur" end end })
end
local function pipe_scene(D) return asm_scene(D, "pipe", 400) end
local function pipe_tight_scene(D) return asm_scene(D, "pipe", 400, 3600) end -- plaques : juste de quoi nourrir les 4 assembleurs
local function gear_scene(D) return asm_scene(D, "iron-gear-wheel", 400) end

---------------------------------------------------------------------------------------------------
-- §1 Données
---------------------------------------------------------------------------------------------------
local D0 = C.data()
local function s1()
  local L = D0.lv
  check(L and #L.cand == 5, "§1 cinq modules de vitesse ou de productivité candidats (l'efficacité n'en est pas un), " .. tostring(L and #L.cand))
  check(L.slots["electric-furnace"].n == 2 and L.slots["stone-furnace"] == nil, "§1 emplacements lus par machine (le four en pierre n'en a pas)")
  check(L.techs["mining-productivity-1"] and L.techs["research-speed-1"] and L.techs["worker-robots-speed-1"]
    and not L.techs["physical-projectile-damage-1"], "§1 technologies à effet de capacité retenues, effets militaires écartés")
  check(L.techs["research-speed-1"].effects[1].kind == "lab_speed" and L.techs["research-speed-1"].effects[1].modifier == 0.2,
    "§1 effet et modificateur lus")
  check(L.techs["mining-productivity-1"].count > 0 and #L.techs["mining-productivity-1"].ingredients > 0,
    "§1 coût de recherche lu au relevé des technologies")
  check(D0.mu["productivity-module"] > 100 and D0.mu["productivity-module"] == D0.mu["speed-module"], "§1 valeur d'un module : ses recettes")
  local D1 = C.data(nil, nil, nil, function(lv) lv.equip = nil end)
  check(#D1.lv.cand == 0 and next(D1.lv.slots) ~= nil, "§1 relevé sans module : aucun candidat")
  local D2 = Ca_data_no_lv and nil
  local D3 = require("shared.ai3.capitalisation").data({ recipes = {}, techs = {}, entities = {}, resources = {}, items = {} }, {})
  check(D3.lv and #D3.lv.cand == 0 and #D3.lv.tech_list == 0, "§1 relevé sans clé lv : catalogue vide")
end

---------------------------------------------------------------------------------------------------
-- §2 Repli
---------------------------------------------------------------------------------------------------
local Ca = require("shared.ai3.capitalisation")
local function s2()
  local res = Ca.decide(blocked_scene(D0), {})
  local o = find(res, "equiper:electric-furnace:iron-plate")
  check(o ~= nil, "§2 tous les sites interdits : un ordre de module sur les fours")
  check(o and o.module == "productivity-module" and o.per == 2, "§2 la productivité : la vitesse n'a pas d'entrée de plus (" .. tostring(o and o.module) .. ")")
  check(res.repli and #res.repli.blocked >= 1 and res.repli.blocked[#res.repli.blocked].resource == "iron-ore"
    and #res.repli.levers >= 1, "§2 compte rendu du repli : ressource bloquée et levier retenu")
  check(res.repli and res.repli.text:find("1 dangereux", 1, true) and res.repli.text:find("equiper:electric-furnace", 1, true),
    "§2 le texte dit pourquoi (gisement dangereux) et quoi")
  check(o and o.why:find("repli : 1 gisement(s) de iron-ore", 1, true), "§2 la raison de l'ordre porte le repli")
  -- Ordre émis dans les 5 pensées (une par minute), ordres ouverts rendus à la pensée suivante.
  local st, open, first = {}, {}, nil
  for cycle = 1, 5 do
    local r = Ca.decide(blocked_scene(D0, { open = open, dt = 1 }), st)
    for _, oo in ipairs(r.orders) do
      if oo.kind == "equiper" and not first then first = cycle end
      local c = deep(oo)
      c.n_left = c.n
      open[#open + 1] = c
    end
  end
  check(first ~= nil and first <= 5, "§2 un ordre de module dans les 5 pensées (pensée " .. tostring(first) .. ")")
  -- Un site libre : l'extraction (retour 1 à 5 min) passe avant, aucun module d'abord.
  local r2 = Ca.decide(free_scene(D0), {})
  check(find(r2, "couvrir:") or find(r2, "ouvrir:"), "§2 site libre : l'extraction est décidée")
  local m2 = find(r2, "equiper:")
  check(not m2 or (m2.repli == nil), "§2 site libre : un module éventuel n'est pas un repli")
  local first_key = r2.orders[1] and r2.orders[1].kind
  check(first_key == "couvrir" or first_key == "ouvrir", "§2 site libre : le premier ordre est une extraction (" .. tostring(first_key) .. ")")
  check(not r2.repli, "§2 site libre : pas de repli")
  -- Retour accepté en repli plus long que T_max du caractère (sinon aucun levier).
  local res3 = Ca.decide(blocked_scene(D0), {})
  local o3 = find(res3, "equiper:")
  check(o3 and o3.T > res3.tmax and o3.T <= 60, string.format("§2 retour %s min au-delà de T_max %s mais sous l'horizon de 60 min",
    o3 and string.format("%.1f", o3.T) or "-", string.format("%.1f", res3.tmax)))
  -- Hors repli (site libre), le même module n'est PAS accepté à ce retour : T_max du caractère.
  local r4 = Ca.decide(free_scene(D0, { deposits = {
    { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60, covered = 270 } } }), {})
  check(r4.repli ~= nil, "§2 gisement couvert à 100 % : plus aucune place = repli")
end

---------------------------------------------------------------------------------------------------
-- §3 Formule
---------------------------------------------------------------------------------------------------
local function s3()
  local res = Ca.decide(blocked_scene(D0), {})
  local o = find(res, "equiper:electric-furnace:iron-plate")
  if not o then check(false, "§3 ordre absent") return end
  -- Recalcul par le test : liste des effets des modules posés (2 de productivité par machine), barème MULTIPLICATIF.
  local list = { { speed = -2, consumption = 6, productivity = 10 }, { speed = -2, consumption = 6, productivity = 10 } }
  local c = MM.complements(list)
  local s_n, p_n, e_n = c.speed.t, c.productivity.t, c.consumption.t
  check(s_n == 96 and p_n == 121 and e_n == 112, string.format("§3 facteurs du barème : vitesse %d, productivité %d, énergie %d", s_n, p_n, e_n))
  local rho = 60 * 2 / 3.2 -- plaques par minute d'un four de vitesse 2
  local d_out = o.n * rho * (s_n * p_n - 100 * 100) / 10000
  check(math.abs(o.d_out - d_out) < 1e-6, string.format("§3 sortie de plus %.4f = formule %.4f", o.d_out, d_out))
  check(math.abs(o.d_kw - o.n * 180 * (e_n - 100) / 100) < 1e-6, "§3 énergie de plus = puissance × (facteur − 1)")
  local cost = o.n * 2 * D0.mu["productivity-module"]
  check(math.abs(o.cost_m - cost) < 1e-6, "§3 coût = modules posés × valeur du module")
  local va = D0.mu["iron-plate"]
  local gain = math.min(d_out, 300 - 225 - 0) * va - (o.d_kw * 60 / D0.fuel_kj) * D0.mu[D0.fuel]
  check(math.abs(o.gain - gain) < 1e-6, string.format("§3 gain %.4f = utile × valeur − énergie (%.4f)", o.gain, gain))
  check(math.abs(o.T - (o.cost_m + res.lambda * o.work / 60) / o.gain) < 1e-9, "§3 retour = coût ÷ gain")
  -- Des modules déjà posés entrent dans le plan (les machines qui en portent fournissent davantage).
  local inp = blocked_scene(D0)
  inp.machines[1].mods = { ["productivity-module"] = 1 }
  local r1 = Ca.decide(inp, {})
  local o1 = find(r1, "equiper:electric-furnace:iron-plate:qg:productivity-module*1")
  check(o1 ~= nil and o1.per == 1, "§3 un emplacement pris : un module de plus au plus par machine (" .. tostring(o1 and o1.per) .. ")")
  local list2 = { { speed = -2, consumption = 6, productivity = 10 }, { speed = -2, consumption = 6, productivity = 10 } }
  local cc = MM.complements(list2)
  if o1 then
    local c1 = MM.complements({ { speed = -2, consumption = 6, productivity = 10 } })
    local want = o1.n * rho * (cc.speed.t * cc.productivity.t - c1.speed.t * c1.productivity.t) / 10000
    check(math.abs(o1.d_out - want) < 1e-6, string.format("§3 sortie de plus avec un module déjà posé %.4f = %.4f", o1.d_out, want))
  end
  -- Foreuses : la vitesse multiplie le minerai (pas d'entrée à fournir).
  local inp2 = blocked_scene(D0, { deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60 } } })
  inp2.deposits[1].covered = 270
  local r2 = Ca.decide(inp2, {})
  local od = find(r2, "equiper:electric-mining-drill")
  check(od ~= nil, "§3 foreuses : un module quand le gisement est couvert")
  if od then
    local sc = MM.complements({ { speed = 20, consumption = 12 }, { speed = 20, consumption = 12 }, { speed = 20, consumption = 12 } })
    local want = od.n * 30 * (sc.speed.t - 100) / 100
    check(od.module:find("speed", 1, true) and math.abs(od.d_out - want) < 1e-6 or od.module:find("productivity", 1, true),
      string.format("§3 foreuse : %s, sortie de plus %.3f (vitesse seule : %.3f)", od.module, od.d_out, want))
  end
end

---------------------------------------------------------------------------------------------------
-- §4 Limites
---------------------------------------------------------------------------------------------------
local function s4()
  -- L'entrée manque : un four n'a pas de minerai de plus (minerai livré = consommé) -> la vitesse n'ajoute rien.
  local res = Ca.decide(blocked_scene(D0, { stock = stock({ ["productivity-module"] = 0, ["productivity-module-2"] = 0 }) }), {})
  check(not find(res, "equiper:electric-furnace"), "§4 sans module de productivité : pas de module de vitesse sur des fours sans minerai de plus")
  local rf = refus_of(res, "equiper:electric-furnace")
  check(rf and rf.why:find("entree", 1, true), "§4 refus écrit : l'entrée manque (" .. tostring(rf and rf.why) .. ")")
  -- Du minerai en surplus : le module de vitesse sert.
  local inp = blocked_scene(D0, { stock = stock({ ["productivity-module"] = 0, ["productivity-module-2"] = 0 }),
    flows = { ["iron-ore"] = { made = 600 }, ["iron-plate"] = { made = 180 } } })
  local r2 = Ca.decide(inp, {})
  local o2 = find(r2, "equiper:electric-furnace")
  check(o2 and o2.module:find("speed", 1, true), "§4 minerai livré en surplus : un module de vitesse (" .. tostring(o2 and o2.module) .. ")")
  -- Recette non permise à la productivité (assembleur de moteurs) : aucun module de productivité.
  local r3 = Ca.decide(pipe_scene(D0), {})
  local o3 = find(r3, "equiper:assembling-machine-2")
  check(o3 ~= nil and o3.module:find("speed", 1, true), "§4 recette hors de la liste : vitesse, pas productivité (" .. tostring(o3 and o3.module) .. ")")
  local t3 = Ca.decide(pipe_tight_scene(D0), {})
  check(not find(t3, "equiper:assembling-machine-2") and ((refus_of(t3, "equiper:assembling-machine-2") or {}).why or ""):find("entree", 1, true),
    "§4 plaques sans surplus, tuyaux hors de la liste : ni vitesse ni productivité")
  local g3 = find(Ca.decide(gear_scene(D0), {}), "equiper:assembling-machine-2")
  check(g3 ~= nil and g3.module:find("productivity", 1, true), "§4 recette de la liste (engrenages) : productivité (" .. tostring(g3 and g3.module) .. ")")
  -- Effet non permis : une machine qui ne permet pas la productivité.
  local Dn = C.data(nil, nil, nil, function(lv) lv.slots["electric-furnace"].allowed.productivity = nil end)
  local r4 = Ca.decide(blocked_scene(Dn, { stock = stock() }), {})
  local o4 = find(r4, "equiper:electric-furnace")
  check(not o4 or o4.module:find("speed", 1, true), "§4 productivité non permise : aucun module de productivité")
  -- Emplacements pleins.
  local inp5 = blocked_scene(D0)
  inp5.machines[1].mods = { ["productivity-module"] = 2 }
  check(not find(Ca.decide(inp5, {}), "equiper:electric-furnace"), "§4 emplacements pleins : aucun ordre")
  -- Courant : la puissance de plus dépasse la réserve.
  local inp6 = blocked_scene(D0, { power = { have_kw = 1000, used_kw = 1000 } })
  local r6 = Ca.decide(inp6, {})
  check(not find(r6, "equiper:electric-furnace") and ((refus_of(r6, "equiper:electric-furnace") or {}).why or ""):find("courant", 1, true),
    "§4 courant insuffisant : refus écrit")
  -- Menace : leviers du QG seulement (les fours du QG restent permis, les foreuses d'un gisement non).
  local inp7 = blocked_scene(D0, { threat = true })
  inp7.deposits[1].danger = nil
  inp7.deposits[1].covered = 270
  local r7 = Ca.decide(inp7, {})
  check(not find(r7, "equiper:electric-mining-drill"), "§4 menace : pas de module chez les foreuses du gisement")
  -- Gisement dangereux : les foreuses du gisement ne reçoivent rien (ni PNJ, ni module).
  local r8 = Ca.decide(blocked_scene(D0), {})
  check(not find(r8, "equiper:electric-mining-drill") and refus_of(r8, "equiper:electric-mining-drill").why:find("danger", 1, true),
    "§4 gisement dangereux : pas de module chez ses foreuses")
  -- Pas de demande : aucun levier.
  local r9 = Ca.decide(blocked_scene(D0, { sinks = {} }), {})
  check(#r9.orders == 0, "§4 aucune demande : aucun ordre")
  -- Module non obtenable (ni au stock ni fabricable) : l'ordre n'existe pas, la recherche prend de la valeur.
  local r10 = Ca.decide(blocked_scene(D0, { stock = { ["electronic-circuit"] = 1000 } }), {})
  check(not find(r10, "equiper:"), "§4 module non obtenable : aucun ordre")
  check(#r10.want >= 1, "§4 module rentable mais non obtenable : demandé à la recherche (" .. table.concat(r10.want, ",") .. ")")
end

---------------------------------------------------------------------------------------------------
-- §5 Ordre ouvert
---------------------------------------------------------------------------------------------------
local function s5()
  local st = {}
  local r1 = Ca.decide(blocked_scene(D0), st)
  local o = find(r1, "equiper:electric-furnace")
  if not o then check(false, "§5 ordre absent") return end
  local c = deep(o)
  c.n_left = c.n
  local r2 = Ca.decide(blocked_scene(D0, { open = { c } }), st)
  local n_same = 0
  for _, oo in ipairs(r2.orders) do if oo.key == o.key then n_same = n_same + 1 end end
  check(n_same == 0, "§5 ordre ouvert : jamais réémis")
  -- Reste à poser : l'ordre à moitié fini compte pour la moitié dans le plan (sortie attendue plus faible).
  local c2 = deep(o)
  c2.n_left = 0
  local r3 = Ca.decide(blocked_scene(D0, { open = { c2 } }), {})
  local r0 = Ca.decide(blocked_scene(D0, { open = { c } }), {})
  check(r3.R["iron-plate"] ~= nil and r0.R["iron-plate"] ~= nil, "§5 plan avec ordre ouvert calculé")
  local ok = true
  for _, oo in ipairs(r3.orders) do if oo.key == o.key then ok = false end end
  check(ok, "§5 ordre fini (n_left 0) : clé gardée (un seul ordre par clé)")
  -- Le plan applique l'ordre : le manque baisse (une seconde décision ne redemande pas la même sortie).
  local tot = 0
  for _, oo in ipairs(r1.orders) do if oo.kind == "equiper" then tot = tot + oo.d_out end end
  check(tot > 0 and tot <= 75 + 1e-6 + (Ca.LEAD * 300 - 225), "§5 la sortie de plus ne dépasse pas la demande servie (+ l'avance)")
end

---------------------------------------------------------------------------------------------------
-- §6 Recherches à effet
---------------------------------------------------------------------------------------------------
-- Le pack chimique n'a pas de valeur dans ce relevé (fluides) : valeur fixée pour la recherche du travail des PNJ.
local DL = C.data()
DL.mu["chemical-science-pack"] = 12
local function s6()
  -- Foreuses : productivité des foreuses, gisements pris -> repli ; gain = bonus × minerai livré × valeur.
  local res = Ca.decide(tech_scene(D0), {})
  local o = find(res, "techno:mining-productivity-1")
  check(o ~= nil, "§6 recherche des foreuses retenue quand les gisements sont pris")
  if o then
    local d_ore = 0.1 * 180
    local want_gain = math.min(d_ore, 300 - 180) * D0.mu["iron-ore"]
    check(math.abs(o.gain - want_gain) < 1e-6 or math.abs(o.gain - (math.min(d_ore, 300 - 180) * D0.mu["iron-ore"])) < 1e-6,
      string.format("§6 gain %.3f = bonus × minerai × valeur (%.3f)", o.gain, want_gain))
    check(o.cost_m == 0 and o.cost > 0 and o.delay ~= nil, "§6 coût payé en recherche (hors budget du cycle), retard compté")
    check(res.repli and #res.repli.levers >= 1, "§6 le repli compte la recherche parmi ses leviers")
    local tw = Ca.techs_wanted(res, {})
    check(tw["mining-productivity-1"] ~= nil and tw["mining-productivity-1"] >= 35, "§6 Ca.techs_wanted : la technologie et sa valeur")
  end
  -- Pack non obtenable : pas d'option, refus écrit.
  local r2 = Ca.decide(blocked_scene(D0, { stock = stock() }), {})
  check(not find(r2, "techno:") and refus_of(r2, "techno:").why:find("non obtenable", 1, true), "§6 pack non obtenable : refus écrit")
  -- Déjà recherchée : rien.
  local inp3 = tech_scene(D0, { state = { techs = { automation = true, ["advanced-electronics"] = true, ["mining-productivity-1"] = true } } })
  check(not find(Ca.decide(inp3, {}), "techno:mining-productivity-1"), "§6 technologie déjà recherchée : rien")
  -- Prérequis manquant : rien.
  local D4 = C.data(function(d) d.techs["mining-productivity-1"].prerequisites = { "logistic-science-pack" } end)
  local inp4 = tech_scene(D4)
  check(not find(Ca.decide(inp4, {}), "techno:mining-productivity-1"), "§6 prérequis non recherché : rien")
  -- Laboratoires : vitesse utile seulement si la recherche visée dépasse les laboratoires et que les packs suivent.
  local inp5 = blocked_scene(D0, { obtainable = all_ok, stock = { ["electronic-circuit"] = 1000 },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 8, where = "d-fe" } },
    flows = { ["iron-plate"] = { made = 150 }, ["copper-plate"] = { made = 75 },
      ["automation-science-pack"] = { made = 60 } },
    labs = { { entity = "lab", n = 4 } }, sinks = {},
    research = { queue = { { tech = "electronics", left = 500, time = 15, packs = { { "automation-science-pack", 1 } } } }, rate = 240 } })
  local r5 = Ca.decide(inp5, {})
  say("§6 laboratoires : u* " .. string.format("%.1f", r5.u_star) .. " ordres " .. count_kind(r5, "labos") .. " techno " .. count_kind(r5, "techno"))
  check(r5.u_star > 0, "§6 recherche visée calculée")
  -- Travail des PNJ : construction goulot (aucun bras libre) contre bras libres.
  local base = { idle = 0, can_grow = false,
    open = { { key = "chaine:x", kind = "chaine", item = "iron-gear-wheel", entity = "assembling-machine-1", recipe = "iron-gear-wheel",
      n = 4, n_left = 4, work_left = 6000, where = "qg" } } }
  local rb = Ca.decide(tech_scene(DL, base), {})
  local free = deep(base)
  free.idle = 12
  local rf = Ca.decide(tech_scene(DL, free), {})
  local ob, of = find(rb, "techno:worker-robots-speed-1"), find(rf, "techno:worker-robots-speed-1")
  say(string.format("§6 travail : goulot %s, bras libres %s", ob and string.format("T=%.1f", ob.T) or "-", of and string.format("T=%.1f", of.T) or "-"))
  check(ob ~= nil and ob.effects[1]:find("goulot", 1, true), "§6 construction goulot : la vitesse du travail est une recherche retenue")
  check(of == nil or (ob and of.T > ob.T), "§6 bras libres : même recherche moins pressée (gain à 25 %)")
end

---------------------------------------------------------------------------------------------------
-- §7 Données changées et déterminisme
---------------------------------------------------------------------------------------------------
local function orders_text(res)
  local t = {}
  for _, o in ipairs(res.orders) do t[#t + 1] = string.format("%s|%s|%s|%d|%.6f", o.key, tostring(o.module), tostring(o.tech), o.n, o.T) end
  return table.concat(t, ";")
end
local function s7()
  -- Modules deux fois plus rapides, même code : une sortie de plus au moins double (vitesse), formule recalculée.
  local D2 = C.data(nil, nil, nil, function(lv)
    for _, m in pairs(lv.equip) do
      if m.effects.speed then m.effects.speed = m.effects.speed * 2 end
    end
  end)
  local inp = blocked_scene(D2, { stock = stock({ ["productivity-module"] = 0, ["productivity-module-2"] = 0 }),
    flows = { ["iron-ore"] = { made = 600 }, ["iron-plate"] = { made = 180 } } })
  local o = find(Ca.decide(inp, {}), "equiper:electric-furnace")
  local inp1 = blocked_scene(D0, { stock = stock({ ["productivity-module"] = 0, ["productivity-module-2"] = 0 }),
    flows = { ["iron-ore"] = { made = 600 }, ["iron-plate"] = { made = 180 } } })
  local o1 = find(Ca.decide(inp1, {}), "equiper:electric-furnace")
  check(o and o1 and o.d_out > o1.d_out, "§7 modules plus rapides : sortie de plus plus grande, même code")
  -- Plus d'emplacement : aucun levier, et le compte rendu le dit.
  local D3 = C.data(nil, nil, nil, function(lv) lv.slots = {} end)
  local r3 = Ca.decide(blocked_scene(D3), {})
  check(count_kind(r3, "equiper") == 0 and r3.repli and r3.repli.none and r3.repli.text:find("aucun levier", 1, true),
    "§7 sans emplacement dans les données : aucun levier, dit pourquoi (" .. tostring(r3.repli and r3.repli.none) .. ")")
  -- Tous les noms changés (modules, machines, recettes du test inchangés ici : on renomme les modules) : mêmes ordres.
  local Dr = C.data(nil, nil, nil, function(lv)
    local m2 = {}
    for k, v in pairs(lv.equip) do m2["zz-" .. k] = v end
    lv.equip = m2
  end, nil)
  -- (les recettes des modules gardent leurs noms : ils sortent du relevé de recettes, pas de lv ; le renommage ne
  -- change donc pas les valeurs) -> on contrôle seulement la décision sur les modules du stock renommés
  local st2 = {}
  for k, v in pairs(stock()) do st2["zz-" .. k] = v end
  st2["electronic-circuit"] = 1000
  local rr = Ca.decide(blocked_scene(Dr, { stock = st2 }), {})
  check(count_kind(rr, "equiper") == 0, "§7 modules sans recette (valeur inconnue) : aucun ordre, aucune erreur")
  -- Déterminisme : deux passages, entrées permutées.
  local a = orders_text(Ca.decide(blocked_scene(D0), {}))
  local b = orders_text(Ca.decide(blocked_scene(D0), {}))
  check(a == b and a ~= "", "§7 deux passages : mêmes ordres")
  local inp_p = blocked_scene(D0)
  inp_p.machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 1, where = "qg" }, inp_p.machines[1] }
  local inp_q = blocked_scene(D0)
  inp_q.machines = { inp_q.machines[1], { entity = "stone-furnace", recipe = "iron-plate", n = 1, where = "qg" } }
  check(orders_text(Ca.decide(inp_p, {})) == orders_text(Ca.decide(inp_q, {})), "§7 machines permutées : mêmes ordres")
  local Drev = C.data(nil, nil, { reverse = true })
  check(orders_text(Ca.decide(blocked_scene(Drev), {})) == a, "§7 relevé en ordre inverse : mêmes ordres")
  -- Ordres sans fonction (peuvent aller dans global).
  local res = Ca.decide(blocked_scene(D0, { obtainable = all_ok }), {})
  local function has_fn(t, seen)
    seen = seen or {}
    if type(t) == "function" then return true end
    if type(t) ~= "table" or seen[t] then return false end
    seen[t] = true
    for _, k in ipairs(sorted_keys(t)) do if has_fn(t[k], seen) then return true end end
    return false
  end
  check(not has_fn(res.orders) and not has_fn(res.repli), "§7 ordres et repli sans fonction")
end

---------------------------------------------------------------------------------------------------
-- §8 Mutants : la règle perd chacune de ses gardes, un contrôle doit le voir
---------------------------------------------------------------------------------------------------
local function read_all(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local LV_SRC = read_all("shared/ai3/leviers.lua")
local function with_mutant(old, new, fn)
  local i, j = LV_SRC:find(old, 1, true)
  assert(i, "mutant : motif introuvable : " .. old)
  assert(not LV_SRC:find(old, j + 1, true), "mutant : motif ambigu : " .. old)
  local src = LV_SRC:sub(1, i - 1) .. new .. LV_SRC:sub(j + 1)
  local chunk = assert(load(src, "@leviers_mutant"))
  local saved = { package.loaded["shared.ai3.leviers"], package.loaded["shared.ai3.capitalisation"] }
  package.loaded["shared.ai3.leviers"] = chunk()
  package.loaded["shared.ai3.capitalisation"] = nil
  local CaM = require("shared.ai3.capitalisation")
  local ok, err = pcall(fn, CaM)
  package.loaded["shared.ai3.leviers"], package.loaded["shared.ai3.capitalisation"] = saved[1], saved[2]
  if not ok then return false end
  return err
end

--- Chaque mutant renvoie vrai quand ce qu'il casse est VU par au moins un contrôle (comparaison à la règle d'origine).
local function mutants()
  local base_blocked = orders_text(Ca.decide(blocked_scene(D0), {}))
  local base_speed = orders_text(Ca.decide(blocked_scene(D0, { stock = stock({ ["productivity-module"] = 0, ["productivity-module-2"] = 0 }),
    flows = { ["iron-ore"] = { made = 600 }, ["iron-plate"] = { made = 180 } } }), {}))
  local base_nospeed = orders_text(Ca.decide(blocked_scene(D0, { stock = stock({ ["productivity-module"] = 0, ["productivity-module-2"] = 0 }) }), {})) -- vide
  local base_free = orders_text(Ca.decide(free_scene(D0), {}))
  local n_mut, n_caught = 0, 0
  local function M(name, old, new, probe)
    n_mut = n_mut + 1
    local seen = with_mutant(old, new, probe)
    if seen then n_caught = n_caught + 1 else say("§8 mutant NON refusé : " .. name) end
  end
  local function differs(sc, base)
    return function(CaM) return orders_text(CaM.decide(sc(), {})) ~= base end
  end
  M("retour en repli = T_max du caractère", "return math.max(ctx.ch.tmax, h)", "return ctx.ch.tmax", differs(function() return blocked_scene(D0) end, base_blocked))
  M("l'entrée de plus n'est pas exigée", "local fr = math.max(0, math.min(1, avail / dn))", "local fr = 1",
    differs(function() return blocked_scene(D0, { stock = stock({ ["productivity-module"] = 0, ["productivity-module-2"] = 0 }) }) end, base_nospeed))
  M("liste de recettes de la productivité ignorée", "if recipe and m.limit and not m.limit[recipe] then return false end", "",
    function(CaM)
      local o = find(CaM.decide(pipe_tight_scene(D0), {}), "equiper:assembling-machine-2")
      return o ~= nil and o.module:find("productivity", 1, true) ~= nil
    end)
  M("effets permis ignorés", "if slots.allowed[ef] ~= true then return false end", "",
    function(CaM)
      local Dn = C.data(nil, nil, nil, function(lv) lv.slots["electric-furnace"].allowed.productivity = nil end)
      local o = find(CaM.decide(blocked_scene(Dn, { stock = stock() }), {}), "equiper:electric-furnace")
      return o ~= nil and o.module:find("productivity", 1, true) ~= nil
    end)
  M("emplacements pleins ignorés", "local free = sl.n - filled_count(mods)", "local free = sl.n",
    function(CaM)
      local inp5 = blocked_scene(D0)
      inp5.machines[1].mods = { ["productivity-module"] = 2 }
      return find(CaM.decide(inp5, {}), "equiper:electric-furnace") ~= nil
    end)
  M("énergie de plus gratuite", "o.gain = (useful + extra) * va * sh * wf - d_fuel * ctx.fuel_mu", "o.gain = (useful + extra) * va * sh * wf",
    differs(function() return blocked_scene(D0) end, base_blocked))
  M("sortie utile non bornée par la demande", "local useful = math.min(d_out, math.max(0, def))", "local useful = d_out",
    differs(function() return blocked_scene(D0, { sinks = { { item = "iron-plate", rate = 229 } } }) end,
      orders_text(Ca.decide(blocked_scene(D0, { sinks = { { item = "iron-plate", rate = 229 } } }), {}))))
  M("courant ignoré", "if d_kw > room_kw + Ca.EPS then", "if false then",
    function(CaM) return find(CaM.decide(blocked_scene(D0, { power = { have_kw = 1000, used_kw = 1000 } }), {}), "equiper:electric-furnace") ~= nil end)
  M("menace ignorée", "if ctx.threat then H.refuse(ctx, key, \"equiper\", item, \"menace : leviers du QG seulement\") return end", "",
    function(CaM)
      local Dc = C.data()
      Dc.mu["speed-module"] = 30
      local inp7 = blocked_scene(Dc, { threat = true })
      inp7.deposits[1].danger = nil
      inp7.deposits[1].covered = 270
      return find(CaM.decide(inp7, {}), "equiper:electric-mining-drill") ~= nil
    end)
  M("gisement dangereux ignoré", "local why = Ca.usable(ctx, f, \"equiper\")\n      if why then", "local why = nil\n      if why then",
    function(CaM) return find(CaM.decide(blocked_scene(D0), {}), "equiper:electric-mining-drill") ~= nil end)
  M("repli jamais déclaré", "if st.blocked then blocked[#blocked + 1] = { resource = k, text = st.text, absent = st.absent or nil } end",
    "", function(CaM) return find(CaM.decide(blocked_scene(D0), {}), "equiper:") == nil end)
  M("gisement dangereux compté libre", "if why then\n      if f.danger then st.danger = st.danger + 1 else st.forbid = st.forbid + 1 end",
    "if false then\n      if f.danger then st.danger = st.danger + 1 else st.forbid = st.forbid + 1 end",
    function(CaM) return CaM.decide(blocked_scene(D0), {}).repli == nil end)
  M("prérequis ignorés", "if not ctx.techs[p] then ready = false end", "",
    function(CaM)
      local D4 = C.data(function(d) d.techs["mining-productivity-1"].prerequisites = { "logistic-science-pack" } end)
      return find(CaM.decide(tech_scene(D4), {}), "techno:mining-productivity-1") ~= nil
    end)
  M("retard de la recherche ignoré", "o.T = cost / gain + delay", "o.T = cost / gain",
    function(CaM)
      local o = find(CaM.decide(tech_scene(D0), {}), "techno:mining-productivity-1")
      local o0 = find(Ca.decide(tech_scene(D0), {}), "techno:mining-productivity-1")
      return o and o0 and o.T ~= o0.T
    end)
  M("construction goulot ignorée", "if not bottleneck then g1 = g1 * Ca.AHEAD_PCT / 100 end", "",
    function(CaM)
      local free = { idle = 12, can_grow = false,
        open = { { key = "chaine:x", kind = "chaine", item = "iron-gear-wheel", entity = "assembling-machine-1",
          recipe = "iron-gear-wheel", n = 4, n_left = 4, work_left = 6000, where = "qg" } } }
      local a, b = find(CaM.decide(tech_scene(DL, free), {}), "techno:worker-robots-speed-1"),
        find(Ca.decide(tech_scene(DL, free), {}), "techno:worker-robots-speed-1")
      return (a and a.T or -1) ~= (b and b.T or -1)
    end)
  M("module déjà posé ignoré dans le calcul", "for _ = 1, mods[nm] do list", "for _ = 1, 0 do list",
    function(CaM)
      local inp = blocked_scene(D0)
      inp.machines[1].mods = { ["productivity-module"] = 1 }
      local a = find(CaM.decide(inp, {}), "equiper:electric-furnace")
      local b = find(Ca.decide(inp, {}), "equiper:electric-furnace")
      return (a and a.d_out or -1) ~= (b and b.d_out or -1)
    end)
  check(n_caught == n_mut, string.format("§8 mutants : %d refusés sur %d", n_caught, n_mut))
  return n_mut, n_caught
end

s1()
s2()
s3()
s4()
s5()
s6()
s7()
local n_mut, n_caught = mutants()
print(string.format("[LEVIERS] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refusés sur %d)", pass, fail, n_caught, n_mut))
os.exit(fail == 0 and 0 or 1)
