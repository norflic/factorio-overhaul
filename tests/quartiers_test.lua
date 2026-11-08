--[[
  Lot TV-ARCHI (V23 de docs/TODO_VIDEO.md, l.89 ; V22 l.88 ; G38 l.215) : test HORS JEU de la règle pure des quartiers
  (shared/team/quartiers.lua). Contrôles :
    §1 quartier d'un lot ; §2 centre ; §3 lot utilisable ; §4 pôle ; §5 lots libres d'un quartier ; §6 lots libres des quartiers
       ouverts ; §7 besoin anticipé ; §8 candidats (exclusions, tri, égalités) ; §9 décision (ordre des raisons) ; §10 déterminisme ;
    §11 mutants : des motifs du source sont réécrits, le texte est rechargé, et la suite de contrôles doit ÉCHOUER sur chacun ;
    §12 dépôt du quartier (tranche 2) : depot_items, depot_serves (rejoués sur chaque mutant, car dans la suite) ;
    §13 menaces (tranche 3) : threatened, candidats écartés et 2e valeur de candidates ; dépôt périmé et collecte (depot_stale,
       collect_to_depot).
  Usage : lua5.2 tests/quartiers_test.lua   (depuis la racine du mod ; quelques secondes ; rien en jeu)
]]
package.path = "./?.lua;" .. package.path
local Q = require("shared.team.quartiers")

local MIN = 3600   -- ticks par minute de jeu (60 ticks/s)
local TICK = 20 * 3600

-- Lot : { i, j, state, used, out, bad } (les champs optionnels viennent de `extra`).
local function lot(i, j, state, extra)
  local l = { i = i, j = j, state = state }
  for k, v in pairs(extra or {}) do l[k] = v end
  return l
end

local function put(lots, i, j, state, extra)
  lots[i .. ":" .. j] = lot(i, j, state, extra)
end

-- Quartier (I, J) plein : ses 9 lots (i de 3I-1 à 3I+1, j de 3J-1 à 3J+1), dans l'état donné.
local function fill(lots, I, J, state)
  for dj = -1, 1 do
    for di = -1, 1 do
      put(lots, 3 * I + di, 3 * J + dj, state or "libre")
    end
  end
  return lots
end

local function keys_of(list)
  local ks = {}
  for _, c in ipairs(list) do ks[#ks + 1] = c.key end
  return table.concat(ks, ",")
end

-- Suite de contrôles sur une règle R (la vraie, ou un mutant rechargé). Rend (nombre de contrôles, liste des échecs).
local function suite(R)
  local n, bad = 0, {}
  local function check(cond, msg)
    n = n + 1
    if not cond then bad[#bad + 1] = msg end
  end

  -- §1 quartier d'un lot
  local OF_LOT = { {0, 0, 0, 0}, {1, 1, 0, 0}, {-1, -1, 0, 0}, {2, 0, 1, 0}, {4, 0, 1, 0},
    {5, 0, 2, 0}, {-2, 0, -1, 0}, {-4, 0, -1, 0}, {-5, 0, -2, 0} }
  for _, c in ipairs(OF_LOT) do
    local I, J = R.of_lot(c[1], c[2])
    check(I == c[3] and J == c[4], "§1 of_lot(" .. c[1] .. "," .. c[2] .. ") = (" .. tostring(I) .. "," .. tostring(J)
      .. "), attendu (" .. c[3] .. "," .. c[4] .. ")")
  end

  -- §2 centre
  local ci, cj = R.center(1, -1)
  check(ci == 3 and cj == -3, "§2 center(1,-1) = (" .. tostring(ci) .. "," .. tostring(cj) .. "), attendu (3,-3)")

  -- §3 lot utilisable
  check(R.usable(lot(0, 0, "libre")) == true, "§3 libre : utilisable")
  check(R.usable(lot(0, 0, "defricher")) == true, "§3 à défricher : utilisable")
  check(R.usable(lot(0, 0, "gisement")) == false, "§3 gisement : pas utilisable")
  check(R.usable(lot(0, 0, "libre", { used = 5 })) == false, "§3 pris (used=5) : pas utilisable")
  check(R.usable(lot(0, 0, "libre", { out = true })) == false, "§3 dehors (out) : pas utilisable")
  check(R.usable(lot(0, 0, "libre", { bad = 2 })) == false, "§3 mauvais 2 fois : pas utilisable")
  check(R.usable(lot(0, 0, "libre", { bad = 1 })) == true, "§3 mauvais une fois : utilisable")
  check(R.usable(nil) == false, "§3 lot absent : pas utilisable")

  -- §4 pôle d'un quartier
  local hl = fill({}, 1, 0)
  check(R.hub_lot(hl, 1, 0) == "3:0", "§4 quartier plein : pôle au centre (" .. tostring(R.hub_lot(hl, 1, 0)) .. ")")
  local h2 = {}
  put(h2, 3, 0, "libre", { used = 1 })
  put(h2, 3, -1, "libre"); put(h2, 2, 0, "libre"); put(h2, 4, 0, "libre"); put(h2, 3, 1, "libre")
  check(R.hub_lot(h2, 1, 0) == "3:-1", "§4 centre pris, distance 1 : départage par j puis i -> 3:-1 (" .. tostring(R.hub_lot(h2, 1, 0)) .. ")")
  local h3 = {}
  put(h3, 3, 0, "libre", { used = 1 }); put(h3, 2, 0, "libre"); put(h3, 4, 0, "libre")
  check(R.hub_lot(h3, 1, 0) == "2:0", "§4 seuls 2:0 et 4:0 libres : 2:0 (" .. tostring(R.hub_lot(h3, 1, 0)) .. ")")
  local h4 = {}
  put(h4, 3, 0, "libre", { used = 1 })
  check(R.hub_lot(h4, 1, 0) == nil, "§4 aucun lot utilisable : nil")
  put(h4, 2, 0, "gisement")
  check(R.hub_lot(h4, 1, 0) == nil, "§4 un gisement ne compte pas comme pôle : nil")

  -- §5 lots libres d'un quartier, pôle exclu
  local fl = fill({}, 1, 0)
  check(R.free_in(fl, 1, 0, "3:0") == 8, "§5 9 libres, pôle exclu : 8 (" .. tostring(R.free_in(fl, 1, 0, "3:0")) .. ")")
  check(R.free_in(fl, 1, 0, nil) == 9, "§5 sans exception : 9 (" .. tostring(R.free_in(fl, 1, 0, nil)) .. ")")

  -- §6 lots libres des quartiers ouverts (cœur compris)
  local fo = fill(fill({}, 0, 0), 1, 0)
  check(R.free_open(fo, {}) == 9, "§6 cœur seul ouvert : 9 (" .. tostring(R.free_open(fo, {})) .. ")")
  check(R.free_open(fo, { ["1:0"] = true }) == 18, "§6 quartier (1,0) ouvert : 18 (" .. tostring(R.free_open(fo, { ["1:0"] = true })) .. ")")
  check(R.free_open(fo, { ["0:1"] = true }) == 9, "§6 quartier fermé ailleurs : 9")

  -- §7 besoin anticipé (tick = 20 h de jeu)
  -- k débuts, une minute d'écart, le plus récent à `back` minutes avant TICK
  local function starts(k, back)
    local t = {}
    for m = 1, k do t[#t + 1] = TICK - (back + m - 1) * MIN end
    return t
  end
  local a, b = R.need({}, TICK)
  check(a == 2 and b == 0, "§7 aucun début : minimum 2, 0 pris (" .. tostring(a) .. "," .. tostring(b) .. ")")
  a, b = R.need(nil, TICK)
  check(a == 2 and b == 0, "§7 liste absente : minimum 2, 0 pris")
  a, b = R.need(starts(3, 0), TICK)
  check(a == 2 and b == 3, "§7 3 débuts dans 15 min : ceil(3*10/15) = 2 (" .. tostring(a) .. "," .. tostring(b) .. ")")
  a, b = R.need(starts(6, 0), TICK)
  check(a == 4 and b == 6, "§7 6 débuts : 4 (" .. tostring(a) .. "," .. tostring(b) .. ")")
  a, b = R.need(starts(9, 0), TICK)
  check(a == 4 and b == 9, "§7 9 débuts : plafond 4 (" .. tostring(a) .. "," .. tostring(b) .. ")")
  a, b = R.need(starts(6, 16), TICK)
  check(a == 2 and b == 0, "§7 6 débuts plus vieux que 15 min : ne comptent pas (" .. tostring(a) .. "," .. tostring(b) .. ")")
  local mix = starts(3, 0)
  for _, t in ipairs(starts(6, 16)) do mix[#mix + 1] = t end
  a, b = R.need(mix, TICK)
  check(a == 2 and b == 3, "§7 3 récents et 6 vieux : seuls les 3 récents (" .. tostring(a) .. "," .. tostring(b) .. ")")
  a, b = R.need({ TICK + 1, TICK + MIN, TICK + 5 * MIN }, TICK)
  check(a == 2 and b == 0, "§7 débuts dans le futur : ne comptent pas (" .. tostring(a) .. "," .. tostring(b) .. ")")
  local mix2 = starts(6, 0)
  mix2[#mix2 + 1] = TICK + 1; mix2[#mix2 + 1] = TICK + MIN; mix2[#mix2 + 1] = TICK + 5 * MIN
  a, b = R.need(mix2, TICK)
  check(a == 4 and b == 6, "§7 6 récents et 3 futurs : 4 pris 6 (" .. tostring(a) .. "," .. tostring(b) .. ")")
  a, b = R.need({ TICK }, TICK)
  check(a == 2 and b == 1, "§7 un début à l'instant même compte (" .. tostring(a) .. "," .. tostring(b) .. ")")
  a, b = R.need({ TICK - R.WINDOW }, TICK)
  check(a == 2 and b == 0, "§7 un début exactement à WINDOW ne compte pas (" .. tostring(a) .. "," .. tostring(b) .. ")")

  -- §8 candidats
  local core = fill({}, 0, 0)
  check(#R.candidates(core) == 0, "§8 le cœur n'est jamais candidat (" .. #R.candidates(core) .. " trouvé(s))")
  local gis = {}
  put(gis, 3, 0, "gisement"); put(gis, 2, 0, "gisement"); put(gis, 4, 0, "gisement")
  check(#R.candidates(gis) == 0, "§8 quartier sans pôle utilisable : pas candidat")
  local one = {}
  put(one, 3, 0, "libre")
  check(#R.candidates(one) == 0, "§8 pôle sans lot libre en plus : pas candidat")
  local full = fill({}, 1, 0)
  check(#R.candidates(full, { ["1:0"] = { pid = 7 } }) == 0, "§8 quartier connu avec pid : pas candidat")
  check(#R.candidates(full, { ["1:0"] = { refus = 2 } }) == 0, "§8 refus 2 : pas candidat")
  local c1 = R.candidates(full, { ["1:0"] = { refus = 1 } })
  check(#c1 == 1 and c1[1].key == "1:0", "§8 refus 1 : candidat")
  check(#R.candidates(full) == 1 and R.candidates(full)[1].key == "1:0", "§8 quartier inconnu, plein : candidat")
  local ord = fill({}, 0, 0)
  put(ord, 3, 0, "libre"); put(ord, 2, 0, "libre"); put(ord, 4, 0, "libre")
  put(ord, 0, 3, "libre"); put(ord, -1, 3, "libre"); put(ord, 1, 3, "libre"); put(ord, 0, 2, "libre"); put(ord, 0, 4, "libre")
  fill(ord, 2, 0)
  local lst = R.candidates(ord)
  check(keys_of(lst) == "0:1,1:0,2:0", "§8 tri : anneau, puis libres, puis hd, puis J, puis I (" .. keys_of(lst) .. ")")
  check(#lst == 3 and lst[1].free == 4 and lst[2].free == 2 and lst[3].free == 8, "§8 lots libres comptés hors pôle")
  check(#lst == 3 and lst[1].hub == "0:3" and lst[2].hub == "3:0", "§8 pôles choisis")
  local hd = {}
  put(hd, 3, 0, "libre"); put(hd, 2, 0, "libre"); put(hd, 4, 0, "libre")
  put(hd, 0, 2, "libre"); put(hd, 1, 3, "libre"); put(hd, 0, 4, "libre")
  check(keys_of(R.candidates(hd)) == "0:1,1:0", "§8 anneau et libres égaux : pôle le plus proche du QG d'abord (" .. keys_of(R.candidates(hd)) .. ")")
  local ij = {}
  put(ij, 0, -3, "libre"); put(ij, 1, -3, "libre"); put(ij, -1, -3, "libre")
  put(ij, -3, 0, "libre"); put(ij, -4, 0, "libre"); put(ij, -2, 0, "libre")
  put(ij, 3, 0, "libre"); put(ij, 2, 0, "libre"); put(ij, 4, 0, "libre")
  check(keys_of(R.candidates(ij)) == "0:-1,-1:0,1:0", "§8 égalité complète : J puis I (" .. keys_of(R.candidates(ij)) .. ")")

  -- §9 décision : raisons, dans l'ordre du code
  local C1 = { I = 1, J = 0, key = "1:0", hub = "3:0", free = 2, d = 1, hd = 3 }
  local function st(over)
    local s = { on = true, plant = true, busy = false, free = 0, need = 3, idle = 1, hold = false, survie = false, cands = { C1 } }
    for k, v in pairs(over) do s[k] = v end
    return s
  end
  local function why(over) return R.decide(st(over)).why end
  check(why({ on = false }) == "eteint", "§9 réglage éteint")
  check(why({ plant = false }) == "pas de reseau (centrale non finie)", "§9 pas de réseau")
  check(why({ busy = true }) == "quartier en chantier", "§9 quartier en chantier")
  check(why({ free = 3, need = 3 }) == "assez de lots libres", "§9 libres égaux au besoin : assez")
  local s2 = st({ free = 2 })
  s2.need = nil
  check(R.decide(s2).why == "assez de lots libres", "§9 besoin absent : défaut NEED_MIN, 2 libres suffisent")
  check(why({ idle = 0 }) == "aucun PNJ inactif", "§9 aucun PNJ inactif")
  check(why({ hold = true }) == "pile en retenue", "§9 pile en retenue")
  check(why({ survie = true }) == "mode survie", "§9 mode survie")
  check(why({ cands = {} }) == "aucun quartier ouvrable", "§9 aucun quartier ouvrable")
  local r = R.decide(st({}))
  check(r.why == nil and r.open == C1, "§9 cas ouvert : rend cands[1]")
  check(why({ on = false, plant = false, busy = true }) == "eteint", "§9 ordre : eteint d'abord")
  check(why({ plant = false, busy = true }) == "pas de reseau (centrale non finie)", "§9 ordre : réseau avant chantier")
  check(why({ busy = true, free = 5, need = 2 }) == "quartier en chantier", "§9 ordre : chantier avant les libres")
  check(why({ free = 3, need = 3, idle = 0 }) == "assez de lots libres", "§9 ordre : libres avant les PNJ")
  check(why({ idle = 0, hold = true }) == "aucun PNJ inactif", "§9 ordre : PNJ avant la pile")
  check(why({ hold = true, survie = true }) == "pile en retenue", "§9 ordre : pile avant le mode survie")
  check(why({ survie = true, cands = {} }) == "mode survie", "§9 ordre : survie avant les candidats")

  -- §10 déterminisme : deux appels, même liste, même ordre
  local d1, d2 = keys_of(R.candidates(ord)), keys_of(R.candidates(ord))
  check(d1 == d2 and d1 == "0:1,1:0,2:0", "§10 deux appels sur le même lot : même liste (" .. d1 .. " / " .. d2 .. ")")
  local e1, e2 = keys_of(R.candidates(ij)), keys_of(R.candidates(ij))
  check(e1 == e2 and e1 == "0:-1,-1:0,1:0", "§10 égalités : même liste à chaque appel")
  check(R.hub_lot(h2, 1, 0) == R.hub_lot(h2, 1, 0), "§10 pôle stable")

  -- §12 dépôt du quartier (tranche 2) : objets les plus demandés, puis service d'une tournée
  local dc = { ["iron-plate"] = 3, ["copper-plate"] = 5, ["coal"] = 0, ["gear"] = 3 }
  local dl = R.depot_items(dc, 2)
  check(table.concat(dl, ",") == "copper-plate,gear", "§12 depot_items n=2 : égalité 3/3 départagée par le nom (" .. table.concat(dl, ",") .. ")")
  local dall = R.depot_items(dc, 10)
  check(#dall == 3, "§12 depot_items n=10 : coal (à 0) exclu, 3 objets (" .. #dall .. ")")
  check(table.concat(dall, ",") == "copper-plate,gear,iron-plate", "§12 depot_items n=10 : ordre copper-plate, gear, iron-plate (" .. table.concat(dall, ",") .. ")")
  check(#R.depot_items({}, 2) == 0, "§12 depot_items sans demande : liste vide")
  check(#R.depot_items(dc, 0) == 0, "§12 depot_items n=0 : liste vide")
  check(R.depot_serves(400, 340) == true, "§12 depot_serves(400,340) : vrai")
  check(R.depot_serves(339, 340) == false, "§12 depot_serves(339,340) : faux")
  check(R.depot_serves(340, 340) == true, "§12 depot_serves(340,340) : vrai (égalité)")
  check(R.depot_serves(100, 0) == false, "§12 depot_serves(100,0) : faux (besoin nul)")
  check(R.depot_serves(nil, 10) == false, "§12 depot_serves(nil,10) : faux")

  -- §13 menaces (tranche 3) : seuil Chebyshev de Q.THREAT_R, candidats écartés, 2e valeur de candidates
  do
    local L = lot(0, -3, "libre")
    local LAT = { ox = 0, oy = 0 }   -- centre du lot (0, -84)
    check(R.threatened(L, LAT, { { x = 0, y = -20 } }) == true, "§13 menace en (0,-20), 64 pile : menacé")
    check(R.threatened(L, LAT, { { x = 0, y = -19 } }) == false, "§13 menace en (0,-19), 65 : pas menacé")
    check(R.threatened(L, LAT, { { x = 64, y = -84 } }) == true, "§13 menace en (64,-84), 64 pile à l'est : menacé")
    check(R.threatened(L, LAT, { { x = 65, y = -84 } }) == false, "§13 menace en (65,-84) : pas menacé")
    check(R.threatened(L, LAT, {}) == false, "§13 aucune menace : faux")
    check(R.threatened(L, nil, { { x = 0, y = -20 } }) == false, "§13 lat absent : faux")
    check(R.threatened(nil, LAT, { { x = 0, y = -20 } }) == false, "§13 lot absent : faux")

    local tl = fill(fill({}, 0, -1), 1, 0)   -- quartiers (0,-1) (pôle (0,-3)) et (1,0) (pôle (3,0)), tous libres
    local sans = R.candidates(tl)
    check(keys_of(sans) == "0:-1,1:0", "§13 sans menace : (0,-1) avant (1,0) (" .. keys_of(sans) .. ")")
    local _, n0 = R.candidates(tl)
    check(n0 == 0, "§13 sans menace : 2e valeur 0 (" .. tostring(n0) .. ")")
    local listed, nm = R.candidates(tl, nil, { { x = 0, y = -90 } }, LAT)
    check(keys_of(listed) == "1:0", "§13 menace près de (0,-1) : écarté, liste = 1:0 (" .. keys_of(listed) .. ")")
    check(nm >= 1, "§13 menace près de (0,-1) : 2e valeur au moins 1 (" .. tostring(nm) .. ")")
    local _, n1 = R.candidates(tl, nil, nil, LAT)
    check(n1 == 0, "§13 sans liste de menaces : 2e valeur 0 (" .. tostring(n1) .. ")")
  end

  -- §13 dépôt périmé (tranche 2) et collecte vers le dépôt
  check(R.depot_stale({ ["iron-plate"] = 10 }, { "iron-plate" }) == false, "§13 depot_stale : objet demandé seul : pas périmé")
  check(R.depot_stale({ ["iron-plate"] = 10, coal = 1 }, { "iron-plate" }) == true, "§13 depot_stale : charbon non demandé : périmé")
  check(R.depot_stale({ coal = 0 }, {}) == false, "§13 depot_stale : objet à 0 : pas périmé")
  check(R.depot_stale({}, { "x" }) == false, "§13 depot_stale : coffre vide : pas périmé")
  check(R.collect_to_depot({ "iron-gear-wheel" }, { "iron-plate", "iron-gear-wheel" }) == true, "§13 collecte : produit demandé par le dépôt : oui")
  check(R.collect_to_depot({ "copper-cable" }, { "iron-plate" }) == false, "§13 collecte : produit non demandé : non")
  check(R.collect_to_depot({}, { "a" }) == false, "§13 collecte : aucun produit : non")
  check(R.collect_to_depot({ "a" }, nil) == false, "§13 collecte : dépôt sans demande : non")

  return n, bad
end

-- ==================================================================================================================
-- Exécution sur la vraie règle
-- ==================================================================================================================
local passes, failures = 0, 0
local okS, nS, badS = pcall(suite, Q)
if not okS then nS, badS = 0, { "erreur d'exécution : " .. tostring(nS) } end
for _, m in ipairs(badS) do print("[QUARTIERS] ECHEC : " .. m) end
passes = math.max(0, nS - #badS)
failures = #badS

-- ==================================================================================================================
-- §11 mutants : le source réel est relu, un motif est réécrit, le texte est chargé et la suite doit échouer.
-- ==================================================================================================================
local fh = assert(io.open("shared/team/quartiers.lua", "rb"))
local SRC = fh:read("*a")
fh:close()

local function esc(s) return (s:gsub("%p", "%%%0")) end

-- Rend le motif du premier contrôle qui échoue sur ce texte de règle, ou nil si la suite passe.
local function refus(text)
  local chunk, err = load(text, "=quartiers-mutant", "t")
  if not chunk then return "syntaxe : " .. tostring(err) end
  local okc, M = pcall(chunk)
  if not okc or type(M) ~= "table" then return "chargement impossible" end
  local oks, _, mb = pcall(suite, M)
  if not oks then return "erreur à l'exécution" end
  if #mb > 0 then return mb[1] end
  return nil
end

-- Témoin : le texte intact doit passer (sinon le banc lui-même est faux).
local tem = refus(SRC)
if tem then
  failures = failures + 1
  print("[QUARTIERS] ECHEC : témoin, texte intact refusé : " .. tem)
else
  passes = passes + 1
end

local MUTANTS = {
  { "a", "math.floor((i + 1) / 3)", "math.floor(i / 3)" },
  { "b", "Q.NEED_MIN = 2", "Q.NEED_MIN = 1" },
  { "c", "tick - t < Q.WINDOW", "tick - t <= Q.WINDOW * 2" },
  { "d", "if a.free ~= b.free then return a.free > b.free end", "if a.free ~= b.free then return a.free < b.free end" },
  { "e", "not (I == 0 and J == 0)", "true" },
  { "f", "and not l.out", "" },
  { "g", "if s.hold then", "if false then" },
  { "h", "(kn.refus or 0) < Q.REFUS_MAX", "true" },
  { "i", "Q.NEED_MAX = 4", "Q.NEED_MAX = 5" },
  { "j", "if not best or d < bd or", "if not best or d <= bd or" },
  { "k", "Q.REFUS_MAX = 2", "Q.REFUS_MAX = 3" },
  { "l", "(s.free or 0) >= (s.need or Q.NEED_MIN)", "(s.free or 0) > (s.need or Q.NEED_MIN)" },
  { "m", "return counts[a] > counts[b]", "return counts[a] < counts[b]" },
  { "n", "return (need or 0) > 0 and (have or 0) >= need", "return (have or 0) >= (need or 0)" },
  { "o", "if (counts[k] or 0) > 0 then", "if true then" },
  { "p", "if math.max(math.abs(t.x - cx), math.abs(t.y - cy)) <= Q.THREAT_R then return true end", "if math.max(math.abs(t.x - cx), math.abs(t.y - cy)) < Q.THREAT_R then return true end" },
  { "q", "if hub and free >= 1 and Q.threatened(lots[hub], lat, threats) then", "if false then" },
  { "r", "if (contents[k] or 0) > 0 and not want[k] then return true end", "if not want[k] then return true end" },
  { "s", "for _, p in ipairs(products or {}) do if want[p] then return true end end", "for _, p in ipairs(products or {}) do if not want[p] then return true end end" },
}

local refused, total = 0, #MUTANTS
for _, m in ipairs(MUTANTS) do
  local id, old, new = m[1], m[2], m[3]
  local rep = (new:gsub("%%", "%%%%"))
  local text, cnt = SRC:gsub(esc(old), rep)
  if cnt ~= 1 then
    failures = failures + 1
    print("[QUARTIERS] ECHEC : mutant (" .. id .. ") mal écrit, motif trouvé " .. cnt .. " fois au lieu de 1")
  else
    local why = refus(text)
    if why then
      refused = refused + 1
      passes = passes + 1
      print("[QUARTIERS] mutant (" .. id .. ") refusé : " .. why)
    else
      failures = failures + 1
      print("[QUARTIERS] ECHEC : mutant (" .. id .. ") SURVIVANT")
    end
  end
end
print("[QUARTIERS] mutants refusés " .. refused .. "/" .. total)

print(string.format("[QUARTIERS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
