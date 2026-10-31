-- Lot GISEMENTS (retour du DC du 31/10, 0.6.27) : règles pures de shared/team/gisement.lua, leur branchement et leurs mutants.
-- Lancer : lua5.2 tests/gisement_test.lua   (depuis la racine du mod)
package.path = "./?.lua;" .. package.path
local G = require("shared.team.gisement")
local Ca = require("shared.ai3.capitalisation")
local P = require("shared.team.pose_paires")

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end
end
local function section(t) print("== " .. t) end

section("1. Pénurie par rapport au besoin (toutes les matières)")
do
  -- le cas du DC : 9 300 plaques de fer pour un besoin de 3 000, 45 de cuivre pour un besoin que personne n'a compté
  local r = G.penurie({
    { item = "a", items = { "a", "a-plaque" }, have = 9300, need = 3000 },
    { item = "b", items = { "b", "b-plaque" }, have = 45, need = 0 },
    { item = "c", items = { "c" }, have = 900, need = 600 },
  })
  check(r.starved.b and r.starved["b-plaque"], "matière oubliée (besoin nul) mais à 45 : en manque, sa plaque aussi")
  check(not r.starved.a and not r.starved.c, "matières largement servies : pas en manque (c : 900 contre un plancher de 1 500)")
  check(r.ranking[1] == "b" and r.ranking[#r.ranking] == "a", "classement : la plus en manque d'abord, la mieux servie dernière")
  -- générique : mêmes chiffres, autres noms, même verdict
  local r2 = G.penurie({ { item = "zz", have = 45, need = 0 }, { item = "yy", have = 9300, need = 3000 } })
  check(r2.starved.zz and not r2.starved.yy, "noms sans importance")
  check(next(G.penurie({}).starved) == nil and next(G.penurie(nil).starved) == nil, "rien à classer : rien en manque")
  check(next(G.penurie({ { item = "a", have = 0, need = 0 } }).starved) == nil, "aucun besoin nulle part : rien ne manque")
  -- égalité départagée par le nom
  local r3 = G.penurie({ { item = "m", have = 1, need = 10 }, { item = "k", have = 1, need = 10 } })
  check(r3.ranking[1] == "k", "égalité : nom croissant")
end

section("2. Bandes et ordre des options de matière")
do
  check(G.band(0) == 0 and G.band(0.24) == 0 and G.band(0.25) == 1 and G.band(0.99) == 3 and G.band(1) == 4 and G.band(7) == 4,
    "bandes de 0,25, couvert à 1")
  check(G.band(nil) == G.BAND_MAX and G.band(-3) == 0, "sans besoin : couvert ; négatif : rien")
  local list = { { n = "fer", th = 1.2 }, { n = "labo" }, { n = "cuivre", th = 0.1 }, { n = "pierre", th = 0.5 }, { n = "courant" } }
  local out = G.reorder(list, function(o) return o.th and G.band(o.th) or nil end)
  local names = {}
  for i, o in ipairs(out) do names[i] = o.n end
  check(table.concat(names, ",") == "cuivre,labo,pierre,fer,courant", "matières par bande, laboratoire et courant gardent leur place : " .. table.concat(names, ","))
  check(list[1].n == "fer", "liste d'origine intacte")
  -- même bande : l'ordre d'origine (meilleur retour d'abord) départage
  local o2 = G.reorder({ { n = "x", th = 0.1 }, { n = "y", th = 0.05 } }, function(o) return G.band(o.th) end)
  check(o2[1].n == "x", "même bande : retour d'origine")
  check(#G.reorder({}, function() return 0 end) == 0, "liste vide")
end

section("3. Pas d'avant-poste de trop")
do
  local opened = { { x = 0, y = 0, free = 4, id = "d1" } }
  local r, d = G.site_redundant({ x = 60, y = 0 }, opened)
  check(r and d.id == "d1", "gisement ouvert à 60 tuiles avec des places : le site est de trop")
  check(not G.site_redundant({ x = 300, y = 0 }, opened), "site lointain : utile")
  check(not G.site_redundant({ x = 60, y = 0 }, { { x = 0, y = 0, free = 0 } }), "gisement plein : le site est utile")
  check(not G.site_redundant({ x = 60, y = 0 }, { { x = 0, y = 0, free = 4, blocked = "hors du plan" } }), "gisement interdit : le site est utile")
  check(not G.site_redundant({ x = 60, y = 0 }, { { x = 0, y = 0, free = 4, danger = true } }), "gisement en danger : le site est utile")
  check(not G.site_redundant({ x = 60 }, opened) and not G.site_redundant({ x = 60, y = 0 }, { { free = 4 } }), "coordonnées absentes : rien n'est supposé")
  local _, best = G.site_redundant({ x = 50, y = 0 }, { { x = 0, y = 0, free = 1, id = "loin" }, { x = 40, y = 0, free = 1, id = "pres" } })
  check(best.id == "pres", "le plus proche est cité")
end

section("4. Foreuse à combustion : garder, rebrancher, remplacer, retirer")
do
  local I, R, H = G.IDLE, G.RETIRE, G.HARD
  check(G.verdict({ idle = 0, sink = "ok" }) == "garder" and G.verdict({ idle = I - 1, dead = true }) == "garder", "elle travaille ou l'arrêt est court : gardée")
  check(G.verdict({ idle = I, dead = true }) == "retirer", "minerai épuisé sous elle : retirée")
  check(G.verdict({ idle = I, sink = "manque", can_sink = true }) == "rebrancher", "four disparu et un réceptacle au stock : rebranchée")
  check(G.verdict({ idle = I, sink = "manque", can_sink = false }) == "garder", "four disparu, rien au stock : attendre")
  check(G.verdict({ idle = R + 1, sink = "ok", ready = true }) == "remplacer", "remplacement électrique prêt : on le laisse faire")
  check(G.verdict({ idle = H, sink = "ok", ready = true }) == "retirer", "remplacement prêt mais jamais fait : retirée")
  check(G.verdict({ idle = R, sink = "ok" }) == "retirer", "à l'arrêt sans remplacement : retirée (elle prend la place de l'électrique)")
  check(G.verdict({ idle = R - 1, sink = "ok" }) == "garder", "arrêt pas encore assez long")
  check(G.verdict({ idle = R, sink = "plein" }) == "retirer", "réceptacle plein sans fin : retirée")
end

section("5. Plus de paire foreuse + four sur le minerai quand l'électrique est possible")
do
  check(G.forbid_pairs({ sink_furnace = true, swap_done = 1 }), "foreuse déjà remplacée : plus de paire")
  check(G.forbid_pairs({ sink_furnace = true, swap_ready = 2 }), "remplacement prêt : plus de paire")
  check(G.forbid_pairs({ sink_furnace = true, retired = 1 }), "paire déjà retirée : plus de paire")
  check(not G.forbid_pairs({ sink_furnace = true }) and not G.forbid_pairs({ sink_furnace = true, swap_done = 0, swap_ready = 0 }),
    "pas d'électrique possible : les paires restent le moyen d'extraire")
  check(not G.forbid_pairs({ sink_furnace = false, swap_done = 5 }) and not G.forbid_pairs(nil), "réceptacle qui n'est pas un four, ou rien : permis")
end

section("6. Couverture du gisement en entier (plus d'arrêt à 80 %)")
do
  check(Ca.KAPPA == 1000 and P.KAPPA == 1000 and Ca.KAPPA == P.KAPPA, "seuil de couverture 1000 pour mille, identique dans la capitalisation et la pose")
  check(not P.verdict({ placed = 4, drills_after = 80, covered = 800, tiles = 1000 }).full, "80 % couvert : la pose continue")
  check(P.verdict({ placed = 4, drills_after = 80, covered = 1000, tiles = 1000 }).full, "100 % couvert : plein")
  check(Ca.SCARCE_FIRST == true, "ordre par pénurie actif")
  check(Ca.NEAR_SITE == G.NEAR, "voisinage des sites = G.NEAR")
end

section("7. Pureté : aucun nom d'objet, aucun pairs décisionnel, aucune API moteur")
do
  for _, path in ipairs({ "shared/team/gisement.lua" }) do
    local fh = io.open(path, "rb")
    local src = fh:read("*a")
    fh:close()
    local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
    check(not code:find("game%.") and not code:find("defines%.") and not code:find("global"), path .. " : aucune API Factorio")
    check(not code:find("%f[%w_]pairs%("), path .. " : aucun pairs")
    check(not code:find("iron") and not code:find("copper") and not code:find("coal") and not code:find("stone") and not code:find("plate"),
      path .. " : aucun nom d'objet")
    check(not code:find("random") and not code:find("os%.time") and not code:find("os%.clock"), path .. " : déterministe")
  end
end

section("8. MUTANTS (chacun doit faire échouer la scène de référence)")
do
  local function scene()
    local r = G.penurie({ { item = "a", items = { "a", "ap" }, have = 9300, need = 3000 }, { item = "b", items = { "b", "bp" }, have = 45, need = 0 } })
    if not (r.starved.b and r.starved.bp and not r.starved.a) then return false end
    local o = G.reorder({ { th = 1.5 }, { th = 0.1 } }, function(x) return G.band(x.th) end)
    if o[1].th ~= 0.1 then return false end
    if not G.site_redundant({ x = 60, y = 0 }, { { x = 0, y = 0, free = 4 } }) then return false end
    if G.site_redundant({ x = 60, y = 0 }, { { x = 0, y = 0, free = 0 } }) then return false end
    if G.verdict({ idle = G.IDLE, dead = true }) ~= "retirer" then return false end
    if G.verdict({ idle = G.RETIRE, sink = "ok" }) ~= "retirer" then return false end
    if G.verdict({ idle = G.IDLE, sink = "manque", can_sink = true }) ~= "rebrancher" then return false end
    if G.verdict({ idle = G.RETIRE + 1, sink = "ok", ready = true }) ~= "remplacer" then return false end
    if G.verdict({ idle = 10, dead = true }) ~= "garder" then return false end
    if not G.forbid_pairs({ sink_furnace = true, swap_done = 1 }) or G.forbid_pairs({ sink_furnace = true }) then return false end
    return true
  end
  check(scene(), "référence")
  local save = {}
  for k, v in pairs(G) do save[k] = v end
  local function kill(name, mutate)
    mutate()
    local okr, res = pcall(scene)
    for k, v in pairs(save) do G[k] = v end
    check(not (okr and res), "mutant refusé : " .. name)
  end
  kill("plancher du besoin supprimé", function() G.NEED_FLOOR_PCT = 0 end)
  kill("seuil de pénurie à 0", function() G.STARVE_THETA = 0 end)
  kill("seuil de pénurie à l'infini", function() G.STARVE_THETA = math.huge end)
  kill("plaque de la matière oubliée de la pénurie", function()
    local f = G.penurie
    G.penurie = function(rows)
      local r = f(rows)
      for k in pairs(r.starved) do if k:sub(-1) == "p" then r.starved[k] = nil end end
      return r
    end
  end)
  kill("ordre inversé (la mieux servie d'abord)", function() G.band = function(t) return G.BAND_MAX - math.floor(math.max(0, math.min(1, t or 1)) / 0.25) end end)
  kill("bande unique", function() G.band = function() return 0 end end)
  kill("voisinage nul", function() G.NEAR = 0 end)
  kill("gisement plein compté comme place", function()
    local f = G.site_redundant
    G.site_redundant = function(s, o, n)
      local o2 = {}
      for i, d in ipairs(o) do o2[i] = { x = d.x, y = d.y, free = 1 } end
      return f(s, o2, n)
    end
  end)
  kill("arrêt court déjà jugé", function() G.IDLE = 0 end)
  kill("retrait jamais", function() G.RETIRE = math.huge G.HARD = math.huge end)
  kill("remplacement prêt ignoré", function() G.HARD = 0 end)
  kill("rebranchement supprimé", function()
    local f = G.verdict
    G.verdict = function(d, c) local v, w = f(d, c) if v == "rebrancher" then return "garder", w end return v, w end
  end)
  kill("interdiction des paires jamais", function() G.forbid_pairs = function() return false end end)
  kill("interdiction des paires toujours", function() G.forbid_pairs = function() return true end end)
  check(G.NEAR == save.NEAR and G.band == save.band, "règles restaurées")
end

section("9. Exécutant script/team/gisement.lua sur des entités simulées (statuts, retrait rendu au stock, rebranchement, reprise par l'électrique)")
do
  local ES = { working = 1, normal = 2, no_minable_resources = 3, no_fuel = 4, waiting_for_space_in_destination = 5 }
  local logs, stock = {}, {}
  _G.log = function(l) logs[#logs + 1] = l end
  _G.defines = { entity_status = ES, inventory = { fuel = 6, furnace_source = 7, furnace_result = 8, furnace_modules = 10 },
    direction = { north = 0, east = 2, south = 4, west = 6 } }
  package.loaded["script.faction.state"] = { sorted_keys = function(t) local k = {} for x in pairs(t) do k[#k + 1] = x end table.sort(k) return k end,
    own = function() end, disown = function() end }
  package.loaded["script.team.stock"] = {
    count = function(_, it) return stock[it] or 0 end,
    insert = function(_, it, n) stock[it] = (stock[it] or 0) + n end,
    remove = function(_, it, n) local h = stock[it] or 0 if h < n then return 0 end stock[it] = h - n return n end }
  local created = {}
  local surface = {
    can_place_entity = function() return true end,
    find_non_colliding_position = function(_, c) return { x = math.floor(c.x), y = math.floor(c.y) } end,
    create_entity = function(a) created[#created + 1] = a.name return { valid = true, name = a.name, unit_number = 900 + #created } end }
  _G.game = { entity_prototypes = { ["stone-furnace"] = { type = "furnace", tile_width = 2, tile_height = 2 },
    ["iron-chest"] = { type = "container", tile_width = 1, tile_height = 1 } } }
  local function ent(name, unit, x, y, status)
    local e = { valid = true, name = name, unit_number = unit, position = { x = x, y = y }, direction = 0, status = status, destroyed = false,
      prototype = { tile_width = 2, tile_height = 2 } }
    e.get_inventory = function(id)
      if id == 6 then return { get_contents = function() return { coal = 5 } end, clear = function() end } end
      return nil
    end
    e.destroy = function() e.valid = false e.destroyed = true end
    return e
  end
  local function farm(status_a, status_b, with_sink)
    local a, b = ent("burner-mining-drill", 1, 10, 10, status_a), ent("burner-mining-drill", 2, 30, 10, status_b)
    local sa = ent("stone-furnace", 11, 9, 9, ES.working)
    local sb = ent("stone-furnace", 12, 29, 9, ES.working)
    local f = { key = "t", id = 1, started = 0, outposts = { [1] = { id = 1, kind = "iron", drills = 2, full = true, full_by = "pose_paires",
      drill_list = { a, b }, sinks = with_sink and { sa, sb } or { sb } } } }
    return f, a, b, sa, sb
  end
  local Gis = require("script.team.gisement")
  local function run(f, t0, t1)
    for t = t0, t1, Gis.EVERY do Gis.think(f, surface, t) end
  end
  -- a. une foreuse à l'arrêt (plus de combustible) depuis G.RETIRE sans remplacement : retirée avec son four, tout au stock
  stock = {}
  local f, a, b, sa = farm(ES.no_fuel, ES.working, true)
  run(f, 0, G.IDLE + 2 * Gis.EVERY)
  check(a.valid and not sa.destroyed, "a. arrêt de 5 min : encore là (le remplacement électrique ou le combustible peut venir)")
  run(f, G.IDLE + 3 * Gis.EVERY, G.RETIRE + 3 * Gis.EVERY)
  check(a.destroyed and sa.destroyed, "a. arrêt de 15 min sans remplacement : foreuse et four retirés")
  check(b.valid and #f.outposts[1].drill_list == 1 and f.outposts[1].drills == 1, "a. la foreuse qui travaille reste, liste et compte tenus à jour")
  check((stock["burner-mining-drill"] or 0) == 1 and (stock["stone-furnace"] or 0) == 1 and (stock.coal or 0) == 10, "a. foreuse, four et combustible rendus au stock (coal " .. tostring(stock.coal) .. ")")
  check(f.outposts[1].full == nil and f.gisement.retired == 1, "a. avant-poste rouvert (place pour les électriques), compte tenu")
  check(#logs >= 1 and logs[#logs]:find("%[FO%-GISEMENT%]") ~= nil, "a. journal [FO-GISEMENT]")
  -- b. minerai épuisé sous la foreuse : retrait dès G.IDLE
  stock = {}
  f, a, b = farm(ES.no_minable_resources, ES.working, true)
  run(f, 0, G.IDLE + 2 * Gis.EVERY)
  check(a.destroyed and b.valid, "b. gisement épuisé sous la foreuse : retirée dès 5 min d'arrêt")
  -- c. four disparu et un four au stock : rebranchement, rien n'est retiré
  stock = { ["stone-furnace"] = 1 }
  created = {}
  f, a, b = farm(ES.waiting_for_space_in_destination, ES.working, false)
  run(f, 0, G.IDLE + 2 * Gis.EVERY)
  check(a.valid and created[1] == "stone-furnace" and stock["stone-furnace"] == 0 and f.gisement.rewired == 1 and #f.outposts[1].sinks == 2,
    "c. four disparu : un four du stock est reposé au dépôt, la foreuse reste")
  -- d. remplacement électrique prêt (f.swap.ready) : on laisse faire le remplacement jusqu'à G.HARD
  stock = {}
  f, a = farm(ES.no_fuel, ES.working, true)
  f.swap = { ready = 2 }
  run(f, 0, G.RETIRE + 5 * Gis.EVERY)
  check(a.valid, "d. remplacement prêt : la foreuse n'est pas retirée avant G.HARD")
  run(f, G.RETIRE + 6 * Gis.EVERY, G.HARD + 2 * Gis.EVERY)
  check(a.destroyed, "d. remplacement jamais fait au bout de G.HARD : retirée")
  -- e. avant-poste à coffre (charbon) : l'arrêt seul ne retire rien
  stock = {}
  f, a = farm(ES.no_fuel, ES.working, true)
  f.outposts[1].kind = "coal"
  run(f, 0, G.HARD + 2 * Gis.EVERY)
  check(a.valid, "e. réceptacle à coffre : une foreuse de charbon à l'arrêt n'est pas retirée par l'arrêt seul")
  -- f. migration en cours : rien ne bouge
  f, a = farm(ES.no_fuel, ES.working, true)
  f.outposts[1].migr = "en cours"
  run(f, 0, G.HARD + 2 * Gis.EVERY)
  check(a.valid, "f. champ en migration : laissé à la migration")
  -- mutants de l'exécutant
  local function ref_a()
    stock = {}
    local ff, aa = farm(ES.no_fuel, ES.working, true)
    run(ff, 0, 15 * 3600 + 3 * Gis.EVERY) -- (borne fixe : un mutant peut rendre G.RETIRE infini)
    return aa.destroyed
  end
  check(ref_a(), "référence de l'exécutant")
  local keep = { G.RETIRE, G.IDLE, G.verdict }
  G.RETIRE = math.huge
  check(not ref_a(), "mutant refusé : retrait jamais")
  G.RETIRE = keep[1]
  G.verdict = function() return "retirer", "mutant" end
  local ff, aa = farm(ES.working, ES.working, true)
  run(ff, 0, 40 * 3600)
  check(aa.valid, "garde propre : une foreuse qui travaille n'est jamais jugée (même avec un verdict féroce)")
  G.verdict = keep[3]
  check(ref_a(), "règles restaurées")
end

print(string.format("[GISEMENT] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
