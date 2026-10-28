--[[
  Lot IA1-b (pôles, managers, généralistes) : bancs HORS JEU des parties pures.
    - O.pole_targets avec la CAPACITÉ DE FOND (`room`) : le surplus ne va qu'aux pôles qui ont de la place, selon
      l'orientation ; sans `room`, résultat d'avant IA1-b (tirages) ; toutes places prises : orientation seule ;
    - shared/team/fond.lua : candidats de fond (agrandir dans le stock, construire sur un site connu, fondre le
      minerai du QG, minage à la main dans le plafond, réserve de biens d'équipement au-dessus des planchers, garde) ;
      stock libre ; tâches marquées fond et domaine ; clés déjà au tableau ignorées ; déterminisme.
  Lancement : lua5.2 tests/ia1b_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local O = require("shared.team.org")
local T = require("shared.team.config")
local Book = require("shared.team.book")
local Fond = require("shared.team.fond")
local F_PAIRS = Fond.PAIRS

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local function ser(v)
  local t = type(v)
  if t == "table" then
    local ks = {}
    for k in pairs(v) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(ks) do out[#out + 1] = tostring(k) .. "=" .. ser(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
  end
  return tostring(v)
end

-- RNG maison (LCG), aucun math.random.
local seed = 12345
local function rnd(n)
  seed = (seed * 1103515245 + 12345) % 2147483648
  return seed % n
end

---------------------------------------------------------------------------------------------------
section("O.pole_targets : capacité de fond (room)")
do
  local pts = O.normalize("equilibre")
  -- Aucun travail du cerveau : 25 exécutants au-delà du carnet.
  local t0, s0 = O.pole_targets(25, { 0, 0, 0 }, pts, 0)
  local t1, s1 = O.pole_targets(25, { 0, 0, 0 }, pts, 0, nil, nil)
  check(ser(t0) == ser(t1) and s0 == s1, "sans room : identique à l'appel d'avant IA1-b")
  local t2 = O.pole_targets(25, { 0, 0, 0 }, pts, 0, nil, { 12, 0, 6 })
  check(t2[1] >= 12 and t2[3] >= 6,
    "room 12/0/6 : extraction et territoire remplis à leur place (" .. ser(t2) .. ")")
  check(t2[1] + t2[2] + t2[3] == 25, "room : la somme des cibles reste l'effectif")
  -- La Base n'a aucune place : elle ne reçoit que la part « orientation seule » du reste (25 - 18 = 7 PNJ).
  check(t2[2] <= 3, "room 12/0/6 : la Base sans place ne reçoit que sa part du reste (" .. t2[2] .. " <= 3)")
  local t3 = O.pole_targets(25, { 0, 0, 0 }, pts, 0, nil, { 30, 30, 30 })
  check(ser(t3) == ser(t0), "places illimitées : l'orientation seule (" .. ser(t3) .. " = " .. ser(t0) .. ")")
  local t4 = O.pole_targets(25, { 0, 0, 0 }, pts, 0, nil, { 0, 0, 0 })
  check(ser(t4) == ser(t0), "aucune place : l'orientation seule (inactivité inévitable)")
  -- Orientation « ressources » : avec de la place partout, l'extraction prend la plus grosse part.
  local tr = O.pole_targets(25, { 0, 0, 0 }, O.normalize("ressources"), 0, nil, { 20, 20, 20 })
  check(tr[1] > tr[2] and tr[1] > tr[3], "ressources, places partout : l'extraction devant (" .. ser(tr) .. ")")
  -- Le travail du cerveau passe d'abord (part pondérée), la place ne joue que pour le surplus.
  local tw = O.pole_targets(25, { 0, 3000, 0 }, pts, 0, nil, { 0, 0, 0 })
  check(tw[2] >= 12, "besoin de la Base (3 000 s) : servi avant la capacité de fond (" .. ser(tw) .. ")")
  -- 500 tirages : somme, bornes, déterminisme.
  local ok_sum, ok_det = true, true
  for _ = 1, 500 do
    local n = rnd(40)
    local need = { rnd(4000), rnd(4000), rnd(4000) }
    local room = { rnd(20), rnd(20), rnd(20) }
    local p = O.normalize({ rnd(100), rnd(100), rnd(100) })
    local a = O.pole_targets(n, need, p, rnd(3), nil, room)
    local b = O.pole_targets(n, need, p, rnd(0) + 0, nil, room)
    if a[1] + a[2] + a[3] ~= n then ok_sum = false end
    local c = O.pole_targets(n, need, p, 0, nil, room)
    if ser(b) ~= ser(c) then ok_det = false end
  end
  check(ok_sum, "500 tirages : la somme des cibles vaut l'effectif")
  check(ok_det, "500 tirages : même entrée, même résultat")
  -- O.plan transmet room.
  local npcs = {}
  for i = 1, 25 do npcs[i] = { id = i, role = "executant", idle = true, rank = 1, xp = 0 } end
  local out = O.plan({ tick = 0, npcs = npcs, need = { 0, 0, 0 }, orientation = "equilibre", room = { 12, 0, 6 } })
  local pl = { 0, 0, 0 }
  for _, p in ipairs(out.place) do pl[O.POLE_INDEX[p.pole]] = pl[O.POLE_INDEX[p.pole]] + 1 end
  check(out.targets[1] >= 12 and out.targets[3] >= 6, "O.plan : room transmise (cibles " .. ser(out.targets) .. ")")
end

---------------------------------------------------------------------------------------------------
section("Fond : candidats des managers")
local book = Book.new(dofile("tests/fixtures/recipes.lua"))
local function view(opts)
  return {
    outposts = opts.outposts or {}, sites = opts.sites or {}, smelters = opts.smelters or 0,
    stock = opts.stock or {}, incoming = opts.incoming or {},
  }
end
do
  local v = view({
    outposts = { { id = 1, kind = "iron", drills = 8 }, { id = 2, kind = "coal", drills = 12 }, { id = 3, kind = "copper", drills = 3, full = true } },
    sites = { stone = 1 }, smelters = 2,
    stock = { ["burner-mining-drill"] = 4, ["stone-furnace"] = 10, ["iron-chest"] = 4, coal = 300, stone = 300,
      ["iron-plate"] = 1000, ["copper-plate"] = 200, ["iron-ore"] = 40 },
  })
  local free = Fond.free_stock(v.stock, {})
  local c = Fond.candidates(v, free, { book = book, keys = {}, mine_left = 3 })
  local ext, build, smelt, mine = {}, {}, 0, 0
  for _, t in ipairs(c.extraction) do
    check(t.fond == true and t.domain == "gisements", "extraction : tâche de fond du domaine Gisements (" .. t.key .. ")")
    if t.kind == "extend" then ext[#ext + 1] = t.outpost end
    if t.kind == "build" then build[#build + 1] = t.outpost_kind end
    if t.kind == "smelt" then smelt = smelt + 1 end
    if t.kind == "mine" then mine = mine + 1 end
  end
  check(ser(ext) == ser({ 1 }), "agrandir : l'avant-poste de fer seulement (charbon au maximum, cuivre plein) : " .. ser(ext))
  check(ser(build) == ser({ "copper" }) or ser(build) == ser({ "copper", "stone" }) or ser(build) == ser({ "stone" }),
    "construire : un type sans avant-poste agrandissable et avec un site connu : " .. ser(build))
  check(smelt == 1, "fondre : 40 minerais de fer au QG, une tournée de fonderie")
  check(mine == 3, "miner à la main : exactement le reste du plafond (3)")
  local crafts = 0
  for _, t in ipairs(c.base) do
    check(t.fond == true and t.domain == "production" and t.kind == "craft", "base : fabrication de fond (" .. t.key .. ")")
    crafts = crafts + 1
  end
  check(crafts > 0, "base : réserve de foreuses à refaire (" .. crafts .. " fabrication(s))")
  check((free["iron-plate"] or 0) >= Fond.FLOOR["iron-plate"], "réserve : le plancher de fer du cerveau reste (" .. tostring(free["iron-plate"]) .. ")")
  local garde = 0
  for _, t in ipairs(c.territoire) do
    check(t.kind == "garrison" and t.fond and t.domain == "defense", "territoire : garde (" .. t.key .. ")")
    garde = garde + 1
  end
  check(garde == 4, "garde : le QG et les 3 avant-postes (" .. garde .. ")")
  -- Déterminisme.
  local c2 = Fond.candidates(v, Fond.free_stock(v.stock, {}), { book = book, keys = {}, mine_left = 3 })
  local k1, k2 = {}, {}
  for _, name in ipairs({ "extraction", "base", "territoire" }) do
    for _, t in ipairs(c[name]) do k1[#k1 + 1] = t.key end
    for _, t in ipairs(c2[name]) do k2[#k2 + 1] = t.key end
  end
  check(table.concat(k1, ",") == table.concat(k2, ","), "même entrée : mêmes candidats, même ordre")
end
do
  -- Stock vide : ni agrandissement, ni fabrication ; le minage reste (matière) ; clés déjà au tableau ignorées.
  local v = view({ outposts = { { id = 1, kind = "iron", drills = 8 } }, smelters = 1, stock = { ["iron-plate"] = 150 } })
  local c = Fond.candidates(v, Fond.free_stock(v.stock, {}), { book = book, keys = { ["fond:mine:coal:1"] = true }, mine_left = 2 })
  local kinds = {}
  for _, t in ipairs(c.extraction) do kinds[#kinds + 1] = t.kind .. ":" .. (t.resource or "") end
  check(#c.base == 0, "stock sous les planchers : aucune fabrication de fond")
  check(#c.extraction == 2 and c.extraction[1].kind == "mine", "stock vide : deux minages à la main (" .. table.concat(kinds, " ") .. ")")
  for _, t in ipairs(c.extraction) do check(t.key ~= "fond:mine:coal:1", "clé déjà au tableau ignorée") end
  -- Ressource écartée (programme en échec) : jamais proposée.
  local c3 = Fond.candidates(v, Fond.free_stock(v.stock, {}), { book = book, keys = {}, mine_left = 8, mine_skip = { coal = true } })
  local bad = 0
  for _, t in ipairs(c3.extraction) do if t.resource == "coal" then bad = bad + 1 end end
  check(bad == 0, "ressource écartée : aucun minage de charbon proposé")
end
do
  -- Stock libre : les objets des tâches qui ne les ont pas encore pris sont réservés.
  local free = Fond.free_stock({ ["burner-mining-drill"] = 10, coal = 50 }, {
    { key = "a", items = { { "burner-mining-drill", 4 } } },
    { key = "b", worker = 3, items = { { "burner-mining-drill", 2 } } },
    { key = "c", worker = 4, took = true, items = { { "burner-mining-drill", 3 } } },
    { key = "d", uses = { { "coal", 20 } } },
  })
  check(free["burner-mining-drill"] == 4, "stock libre : 10 - 4 (libre) - 2 (prise, pas encore prise au QG) = 4 (" .. tostring(free["burner-mining-drill"]) .. ")")
  check(free.coal == 30, "stock libre : `uses` réservé aussi")
  -- Potentiel : places restantes des avant-postes non pleins + sites connus.
  local p = Fond.potential({ outposts = { { id = 1, kind = "iron", drills = 8 }, { id = 2, kind = "coal", drills = 4, full = true } },
    sites = { copper = 1 } })
  -- Lot COFFRE (K-D) : ce qui se POSE à brève échéance, un lot de F.PAIRS paires par avant-poste agrandissable et par site
  -- constructible, au plus F.AHEAD (plus « toutes les places de la carte » : 37 foreuses dormantes au constat du DC).
  check(p == F_PAIRS + math.min(F_PAIRS, T.outposts.copper.drills), "potentiel : un lot par avant-poste agrandissable et par site (" .. p .. ")")
  local big = { outposts = {}, sites = { coal = 1, copper = 1, stone = 1 } }
  for i = 1, 6 do big.outposts[#big.outposts + 1] = { id = i, kind = "iron", drills = 2 } end
  check(Fond.potential(big) == Fond.AHEAD, "potentiel : plafonné à F.AHEAD (" .. Fond.potential(big) .. ")")
  check(Fond.potential(big, { reserve = Fond.PLAYER_RESERVE }) == Fond.PLAYER_AHEAD and Fond.PLAYER_AHEAD < Fond.AHEAD,
    "potentiel de VOTRE équipe : plafonné à F.PLAYER_AHEAD (" .. Fond.potential(big, { reserve = Fond.PLAYER_RESERVE }) .. "), les factions gardent F.AHEAD (lot ADOPTE)")
  local df = { defend_first = true }
  check(Fond.potential({ outposts = {}, sites = { copper = 1 } }, df) == 0, "sous « défendre d'abord », sans tourelles au stock : un site connu ne compte pas")
  check(Fond.potential({ outposts = {}, sites = { copper = 1 } }, df, { ["gun-turret"] = 1, [T.turret_ammo] = T.defend_ammo }) > 0,
    "sous « défendre d'abord », avec tourelles et chargeurs au stock : le site compte")
  check(Fond.potential({ outposts = { { id = 1, kind = "iron", drills = 8 } }, sites = { copper = 1 } }, { safe_only = true }) == 0
    and Fond.potential({ outposts = { { id = 1, kind = "iron", drills = 8 } } }, { prudent = true }) == 0,
    "fond sûr ou prudence : rien ne se pose, rien d'avance")
  check(Fond.potential({ outposts = { { id = 1, kind = "iron", drills = 8 } } }, { undefended = { [1] = true } }) == 0
    and Fond.potential({ outposts = { { id = 1, kind = "iron", drills = 8 } } }, { danger = { [1] = true } }) == 0,
    "avant-poste non défendu ou dangereux : rien d'avance")
end
do
  -- Danger (nid ou ver près d'un avant-poste) et prudence (pertes récentes) : le fond ne sort plus du QG.
  local v = view({ outposts = { { id = 1, kind = "iron", drills = 8 }, { id = 2, kind = "coal", drills = 4 } }, sites = { stone = 1 },
    smelters = 1, stock = { ["burner-mining-drill"] = 20, ["stone-furnace"] = 20, ["iron-chest"] = 10, coal = 500, ["iron-ore"] = 50 } })
  local cd = Fond.candidates(v, Fond.free_stock(v.stock, {}), { book = book, keys = {}, mine_left = 2, danger = { [1] = true } })
  local ext1, garde1 = false, false
  for _, t in ipairs(cd.extraction) do if t.kind == "extend" and t.outpost == 1 then ext1 = true end end
  for _, t in ipairs(cd.territoire) do if t.post == 1 then garde1 = true end end
  check(not ext1 and not garde1, "avant-poste dangereux : ni agrandissement ni garde de fond")
  local cp = Fond.candidates(v, Fond.free_stock(v.stock, {}), { book = book, keys = {}, mine_left = 5, prudent = true })
  local out_of_hq = 0
  for _, t in ipairs(cp.extraction) do if t.kind ~= "smelt" then out_of_hq = out_of_hq + 1 end end
  check(out_of_hq == 0, "prudence : le fond d'extraction ne garde que la fonderie du QG")
  check(#cp.territoire == 1 and cp.territoire[1].post == "hq", "prudence : seule la garde du QG")
  local v2 = view({ outposts = { { id = 1, kind = "iron", drills = 8 } }, sites = { copper = 2 },
    stock = { ["iron-plate"] = 2000, ["copper-plate"] = 500, stone = 500 } })
  local cn = Fond.candidates(v2, Fond.free_stock(v2.stock, {}), { book = book, keys = {}, mine_left = 0 })
  local cs = Fond.candidates(v2, Fond.free_stock(v2.stock, {}), { book = book, keys = {}, mine_left = 0, brain_short = true })
  check(#cn.base > 0 and #cs.base == 0, "cerveau en manque d'objets : aucune fabrication de fond (" .. #cn.base .. " sinon)")
end

do
  -- Lot COFFRE (K-D) : la réserve de biens d'équipement ne dépasse jamais ce qui se pose ; rien à poser : rien d'avance.
  local rich = { ["iron-plate"] = 3000, ["copper-plate"] = 1000, stone = 1000, coal = 500, wood = 500 }
  local v0 = view({ outposts = { { id = 1, kind = "iron", drills = 20, full = true } }, sites = {}, stock = rich })
  local c0 = Fond.candidates(v0, Fond.free_stock(v0.stock, {}), { book = book, keys = {}, mine_left = 0 })
  local eq = 0
  for _, t in ipairs(c0.base) do if Fond.EQUIPMENT[t.item] then eq = eq + t.count end end
  check(eq == 0, "rien à poser : aucun bien d'équipement d'avance (" .. eq .. ")")
  local v1 = view({ outposts = { { id = 1, kind = "iron", drills = 8 } }, sites = { copper = 2, coal = 1 }, stock = rich })
  local c1 = Fond.candidates(v1, Fond.free_stock(v1.stock, {}), { book = book, keys = {}, mine_left = 0 })
  local drills = 0
  for _, t in ipairs(c1.base) do if t.item == T.DRILL then drills = drills + t.count end end
  check(drills > 0 and drills <= Fond.AHEAD, "à poser : foreuses d'avance dans la limite de F.AHEAD (" .. drills .. ")")
  -- Annexes : coffres à fabriquer quand le stock se remplit (ctx.annex_want), même cerveau en manque s'ils ne coûtent aucune plaque.
  local v2 = view({ outposts = { { id = 1, kind = "iron", drills = 20, full = true } }, sites = {}, stock = { wood = 200, ["iron-plate"] = 1000 } })
  local c2 = Fond.candidates(v2, Fond.free_stock(v2.stock, {}), { book = book, keys = {}, mine_left = 0, annex_want = 2, brain_short = true })
  local items = {}
  for _, t in ipairs(c2.base) do items[#items + 1] = t.item end
  check(#items == 1 and items[1] == "wooden-chest", "cerveau en manque : seul le coffre sans plaque est fabriqué pour les annexes (" .. table.concat(items, ",") .. ")")
  local c3 = Fond.candidates(v2, Fond.free_stock(v2.stock, {}), { book = book, keys = {}, mine_left = 0, annex_want = 2 })
  local chests = 0
  for _, t in ipairs(c3.base) do if t.item == "iron-chest" or t.item == "wooden-chest" then chests = chests + t.count end end
  check(chests == 2, "annex_want 2 : deux coffres demandés (" .. chests .. ")")
  local c4 = Fond.candidates(v2, Fond.free_stock({ wood = 200, ["iron-plate"] = 1000, ["iron-chest"] = 3 }, {}), { book = book, keys = {}, mine_left = 0, annex_want = 2 })
  local more = 0
  for _, t in ipairs(c4.base) do if t.item == "iron-chest" or t.item == "wooden-chest" then more = more + 1 end end
  check(more == 0, "coffres déjà en main : aucun de plus")
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
