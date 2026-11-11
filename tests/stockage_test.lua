--[[
  Lot STOCKAGE-VITAL : règle pure shared/team/stockage.lua (réserve des matières vitales, matières à ne plus ramasser, coffre urgent).
  Usage, depuis la racine du mod :   lua5.2 tests/stockage_test.lua
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/team/stockage.lua"
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end
local SRC = read(PATH)

local ok_n, bad = 0, 0
local function check(name, cond, detail)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[STOCKAGE] ECHEC : " .. name .. (detail and (" (" .. tostring(detail) .. ")") or "")) end
end

local function suite(Sg)
  local res = {}
  local function c(name, cond, detail) res[#res + 1] = { name, cond and true or false, detail } end
  local CFG = { reserve = 0.15, stop_at = 0.80, urgent_at = 0.85 }
  local V = { ["iron-plate"] = true, coal = true }
  -- réserve : 15 % des cases, au moins 1
  c("reserve : 200 cases -> 30 gardees", Sg.reserve_slots(200, CFG) == 30, tostring(Sg.reserve_slots(200, CFG)))
  c("reserve : 4 cases -> 1 gardee (arrondi au-dessus)", Sg.reserve_slots(4, CFG) == 1, tostring(Sg.reserve_slots(4, CFG)))
  c("reserve : aucune case -> 0", Sg.reserve_slots(0, CFG) == 0)
  -- cases vides prises : vitale toutes, non vitale au-delà de la réserve
  c("fer : toutes les cases vides (10 sur 200)", Sg.new_stacks("iron-plate", 10, 200, V, CFG) == 10)
  c("pierre : rien quand il reste moins que la reserve (10 vides, 30 gardees)", Sg.new_stacks("stone", 10, 200, V, CFG) == 0)
  c("pierre : au-dela de la reserve (50 vides -> 20)", Sg.new_stacks("stone", 50, 200, V, CFG) == 20, tostring(Sg.new_stacks("stone", 50, 200, V, CFG)))
  c("charbon : vital", Sg.new_stacks("coal", 5, 200, V, CFG) == 5)
  -- ne plus ramasser : non vitale saturée ; toutes les non vitales au-dessus de stop_at ; jamais une vitale
  local sk = Sg.skip({ stone = true, ["iron-plate"] = true }, 0.5, V, CFG)
  c("pierre saturee : plus ramassee", Sg.skipped(sk, "stone", V) == true)
  c("fer sature : toujours ramasse (vital), absent de l'ensemble", Sg.skipped(sk, "iron-plate", V) == false and sk["iron-plate"] == nil)
  c("cuivre non sature, stock a moitie : ramasse", Sg.skipped(sk, "copper-plate", V) == false)
  -- une seule règle pour « ne plus ramasser une matière saturée » : le stop_stone de la sortie de spirale (pierre saturée ET fer qui
  -- manque) s'y ramène ; rien ne manque (short = false, comme le cerveau) : la saturée reste ramassée tant que le stock a de la place
  c("pierre saturee, rien ne manque : ramassee (stock a moitie)", Sg.skipped(Sg.skip({ stone = true }, 0.5, V, CFG, false), "stone", V) == false)
  c("pierre saturee, fer qui manque (stop_stone de la spirale) : plus ramassee", Sg.skipped(Sg.skip({ stone = true }, 0.5, V, CFG, true), "stone", V) == true)
  c("pierre saturee, rien ne manque, stock a 80 % : plus ramassee", Sg.skipped(Sg.skip({ stone = true }, 0.8, V, CFG, false), "stone", V) == true)
  local sk2 = Sg.skip({}, 0.80, V, CFG)
  c("stock a 80 % : aucune non vitale ramassee (cuivre)", Sg.skipped(sk2, "copper-plate", V) == true)
  c("stock a 80 % : le charbon reste ramasse", Sg.skipped(sk2, "coal", V) == false)
  c("stock a 79 % : cuivre ramasse", Sg.skipped(Sg.skip({}, 0.79, V, CFG), "copper-plate", V) == false)
  -- relecture du 7/11 : jamais une matière DEMANDÉE en ce moment (manque mesuré du cerveau, manque de l'objectif), même stock à 90 %
  local LINKS = { { "iron-ore", "iron-plate" }, { "copper-ore", "copper-plate" }, { "stone", "stone" } }
  local need = Sg.demanded({ ["copper-plate"] = 40, stone = 0 }, { { "site:copper", 1 }, { "wood", 0 } }, LINKS)
  c("demande : cuivre manquant (40), son minerai aussi", need["copper-plate"] == 40 and need["copper-ore"] == 40)
  c("demande : un manque nul ne compte pas (pierre a 0, bois a 0), le fer non plus", need.stone == nil and need.wood == nil and need["iron-ore"] == nil)
  c("demande : le manque de l'objectif compte", Sg.demanded(nil, { { "iron-gear-wheel", 12 } }, LINKS)["iron-gear-wheel"] == 12)
  c("demande : minerai qui manque -> sa plaque aussi", Sg.demanded({ ["copper-ore"] = 5 }, nil, LINKS)["copper-plate"] == 5)
  c("demande : la plus grande des deux quantites (cerveau 40, objectif 60)", Sg.demanded({ ["copper-plate"] = 40 }, { { "copper-plate", 60 } }, LINKS)["copper-plate"] == 60)
  -- D1 (relecture revue-0659) : au depot, une matiere demandee prend la reserve jusqu'a la quantite demandee, pas au-dela
  local r1, rec1 = Sg.demand_room(nil, 200)
  c("borne : demande neuve de 200 -> 200 en reserve", r1 == 200 and rec1.q == 200 and rec1.used == 0)
  local r2 = Sg.demand_room({ q = 200, used = 200 }, 200)
  c("borne : 200 deja entres a demande inchangee -> 0 (au-dela de la quantite demandee)", r2 == 0)
  local r3, rec3 = Sg.demand_room({ q = 200, used = 200 }, 100)
  c("borne : demande recomptee a 100 -> 100, compte remis a zero", r3 == 100 and rec3.used == 0 and rec3.q == 100)
  c("borne : sans demande -> 0", Sg.demand_room({ q = 200, used = 0 }, nil) == 0 and Sg.demand_room(nil, 0) == 0)
  local A1, A2 = {}, {}
  local r4, rec4 = Sg.demand_room({ q = 200, used = 200, s = A1, m = false }, 200, A2, false)
  c("borne : meme quantite redemandee a une pensee NEUVE -> 200, compte remis a zero (B1)", r4 == 200 and rec4.used == 0 and rec4.s == A2)
  c("borne : meme pensee, meme quantite -> 0", Sg.demand_room({ q = 200, used = 200, s = A1, m = false }, 200, A1, false) == 0)
  -- C1 de DIAG_CONSO (7/11) : manques des projets en reserve (modules 94 et 95 de la partie du DC), sommes entre projets
  local rn = Sg.reserve_need({ { { "assembling-machine-2", 3 }, { "transport-belt", 23 } },
    { { "assembling-machine-2", 4 }, { "long-handed-inserter", 4 }, { "transport-belt", 47 } } })
  c("C1 reserves : manques sommes entre projets (courroies 23 + 47, assembleurs 2 3 + 4, bras longs 4)", rn["transport-belt"] == 70
    and rn["assembling-machine-2"] == 7 and rn["long-handed-inserter"] == 4, tostring(rn["transport-belt"]))
  local rz = Sg.reserve_need({ { { "steel-plate", 0 }, { 7, 5 }, { "pipe", -2 } }, {} })
  c("C1 reserves : manque nul, negatif ou nom illisible ignore", next(rz) == nil)
  c("C1 reserves : aucune reserve -> rien", next(Sg.reserve_need(nil)) == nil and next(Sg.reserve_need({})) == nil)
  local nr = Sg.demanded(nil, nil, LINKS, rn)
  c("C1 demande : un manque de reserve est demande, hors projet dominant (courroies 70)", nr["transport-belt"] == 70 and nr["assembling-machine-2"] == 7)
  c("C1 demande : la plus grande des sources (cerveau 100 courroies, reserves 70 -> 100 ; objectif 80 -> 80)",
    Sg.demanded({ ["transport-belt"] = 100 }, nil, LINKS, rn)["transport-belt"] == 100
    and Sg.demanded(nil, { { "transport-belt", 80 } }, LINKS, rn)["transport-belt"] == 80)
  c("C1 demande : plaque d'une reserve -> son minerai aussi", Sg.demanded(nil, nil, LINKS, { ["iron-plate"] = 50 })["iron-ore"] == 50)
  c("C1 demande : reserve vide ou absente -> regle d'avant", next(Sg.demanded(nil, nil, LINKS, {})) == nil and Sg.demanded(nil, nil, LINKS, nil)["transport-belt"] == nil)
  c("C1 borne : manque 127, rien au stock -> 127", Sg.resv_room(127, 0) == 127)
  c("C1 borne : manque 127, 100 deja au stock (pas encore repris) -> 27", Sg.resv_room(127, 100) == 27)
  c("C1 borne : stock au manque ou au-dela -> 0", Sg.resv_room(127, 127) == 0 and Sg.resv_room(127, 400) == 0)
  c("C1 borne : sans manque -> 0", Sg.resv_room(nil, 0) == 0 and Sg.resv_room(0, 0) == 0)
  -- C2 de DIAG_CONSO (7/11) : une matiere SATUREE au plafond (cfg.sat_cap piles au stock, 20 par defaut) n'est plus ramassee ni collectee,
  -- vitale comprise (partie du DC : charbon +5 231 et fer +8 683 par minute dans un stock plein, sature [coal copper-plate iron-plate stone])
  local STK = { coal = 50, stone = 50, ["iron-plate"] = 100, ["copper-plate"] = 100 }
  local CNT = { coal = 1000, stone = 999, ["iron-plate"] = 5000, ["copper-plate"] = 9999 }
  local ov = Sg.over_cap({ coal = true, stone = true, ["iron-plate"] = true, ["copper-plate"] = false }, function(it) return CNT[it] end,
    function(it) return STK[it] end, CFG)
  c("C2 plafond : charbon sature a 1000 = 20 piles -> au plafond (>=)", ov.coal == 1000, tostring(ov.coal))
  c("C2 plafond : fer sature a 5000 (50 piles) -> au plafond", ov["iron-plate"] == 5000)
  c("C2 plafond : pierre saturee a 999 (sous 20 piles) -> non", ov.stone == nil)
  c("C2 plafond : cuivre a 9999 NON sature (marque a faux) -> non (le plafond ne vaut que pour une saturee)", ov["copper-plate"] == nil)
  c("C2 plafond : plafond lu dans la configuration (sat_cap 10 : pierre 999 >= 500)", Sg.over_cap({ stone = true }, function(it) return CNT[it] end,
    function(it) return STK[it] end, { sat_cap = 10 }).stone == 999)
  c("C2 plafond : compte ou pile illisible -> non", next(Sg.over_cap({ coal = true }, function() return nil end, function(it) return STK[it] end, CFG)) == nil
    and next(Sg.over_cap({ coal = true }, function(it) return CNT[it] end, function() return nil end, CFG)) == nil and next(Sg.over_cap(nil, nil, nil, CFG)) == nil)
  local s2 = Sg.skip({ coal = true, ["iron-plate"] = true, stone = true }, 0.5, V, CFG, false, {}, ov)
  c("C2 ramassage : charbon vital au plafond -> plus ramasse", Sg.skipped(s2, "coal", V) == true)
  c("C2 ramassage : fer vital au plafond -> plus ramasse", Sg.skipped(s2, "iron-plate", V) == true)
  c("C2 ramassage : pierre saturee sous le plafond, rien d'autre ne manque -> ramassee (regle d'avant)", Sg.skipped(s2, "stone", V) == false)
  c("C2 ramassage : minerai de fer (vital, pas au plafond) -> ramasse", Sg.skipped(s2, "iron-ore", V) == false)
  local s3 = Sg.skip({ coal = true }, 0.5, V, CFG, false, { coal = 30 }, { coal = 1000 })
  c("C2 ramassage : charbon au plafond mais DEMANDE -> ramasse", Sg.skipped(s3, "coal", V) == false)
  local s4 = Sg.skip({ stone = true }, 0.5, V, CFG, false, {}, { stone = 2000 })
  c("C2 ramassage : pierre au plafond, rien d'autre ne manque -> plus ramassee (le plafond ne depend pas des autres manques)", Sg.skipped(s4, "stone", V) == true)
  c("C2 ramassage : charbon au plafond, une autre matiere manque -> plus ramasse non plus", Sg.skipped(Sg.skip({}, 0.5, V, CFG, true, {}, { coal = 1000 }), "coal", V) == true)
  c("C2 ramassage : sans plafond (nil) -> regle d'avant (charbon vital ramasse)", Sg.skipped(Sg.skip({ coal = true }, 0.9, V, CFG, true, {}), "coal", V) == false)
  local sk9 = Sg.skip({ stone = true }, 0.9, V, CFG, true, need)
  c("stock a 90 %, cuivre demande : cuivre ramasse et mine", Sg.skipped(sk9, "copper-plate", V) == false and Sg.skipped(sk9, "copper-ore", V) == false)
  c("stock a 90 %, cuivre demande : pierre et bois toujours ecartes", Sg.skipped(sk9, "stone", V) == true and Sg.skipped(sk9, "wood", V) == true)
  c("stock a 90 %, sans demande : cuivre ecarte (temoin)", Sg.skipped(Sg.skip({ stone = true }, 0.9, V, CFG, true), "copper-plate", V) == true)
  c("cuivre sature mais demande : ramasse", Sg.skipped(Sg.skip({ ["copper-plate"] = true }, 0.5, V, CFG, true, need), "copper-plate", V) == false)
  -- objets au sol (7/11) : un contenu tient-il au stock (piles entamees, puis cases vides) ?
  local f1, n1 = Sg.fits({ { n = 250, stack = 100, part = 30 } }, 3)
  c("tient : 250 objets, 30 de place entamee, 3 cases vides -> 3 cases neuves", f1 == true and n1 == 3, tostring(n1))
  c("ne tient pas : la meme chose dans 2 cases vides", Sg.fits({ { n = 250, stack = 100, part = 30 } }, 2) == false)
  c("tient : 120 objets, 20 de place entamee, 1 case vide", Sg.fits({ { n = 120, stack = 100, part = 20 } }, 1) == true)
  c("ne tient pas : 150 objets sans pile entamee dans 1 case (arrondi au-dessus)", Sg.fits({ { n = 150, stack = 100, part = 0 } }, 1) == false)
  c("tient : tout dans les piles entamees, aucune case vide", Sg.fits({ { n = 10, stack = 50, part = 40 } }, 0) == true)
  -- coffre urgent : au-dessus de urgent_at, aucun en main
  c("coffre urgent a 85 % sans coffre en main", Sg.urgent(0.85, false, CFG) == true)
  c("pas d'urgence a 84 %", Sg.urgent(0.84, false, CFG) == false)
  c("pas d'urgence avec un coffre en main", Sg.urgent(0.95, true, CFG) == false)
  -- valeurs par défaut quand la configuration manque
  c("defauts : reserve 15 %", Sg.reserve_slots(100) == 15)
  return res
end

local function run(text)
  local chunk, err = load(text, "=" .. PATH)
  if not chunk then return { { "module illisible : " .. tostring(err), false } } end
  local okm, Sg = pcall(chunk)
  if not okm then return { { "module : " .. tostring(Sg), false } } end
  local okr, res = pcall(suite, Sg)
  if not okr then return { { "suite : " .. tostring(res), false } } end
  return res
end
for _, r in ipairs(run(SRC)) do check(r[1], r[2], r[3]) end
-- cablage (texte) : le ramassage des avant-postes ecarte ce que Stock.skip_fn refuse ; le depot garde la reserve des vitales
do
  local op, wk, sk = read("script/faction/outposts.lua"), read("script/team/worker.lua"), read("script/team/stock.lua")
  check("cablage : collect ecarte les matieres refusees", op:find("if not (skip and skip(name)) then", 1, true) ~= nil
    and op:find("function Outposts.service(o, carrier, tick, fill, skip, info)", 1, true) ~= nil)
  check("cablage : la tournee passe Stock.skip_fn", wk:find("Stock.skip_fn and Stock.skip_fn(f),", 1, true) ~= nil)
  check("cablage : Stock.skip_fn passe les matieres demandees (manque du cerveau, manque de l'objectif)",
    sk:find("return Sg.demanded(ia3 and ia3.short, team and team.missing, LINKS, all and reserve_need(f) or nil)", 1, true) ~= nil
    and sk:find("local need = demanded(f, true)", 1, true) ~= nil
    and sk:find("T.stockage, ia3 and ia3.other_short, need, over_cap(f))", 1, true) ~= nil)
  check("cablage C1 : les manques des projets en reserve (p.missing, etat reserve) entrent au depot, bornes par le stock (Sg.resv_room)",
    -- (EXPANSION-LOINTAINE, 1552119c : une bande partie sur son plancher, p.progressif, compte aussi son manque)
    sk:find('if p and (p.state == "reserve" or p.progressif) and not p.abandoned and p.missing and #p.missing > 0 then lists[#lists + 1] = p.missing end', 1, true) ~= nil
    and sk:find("local agg = Sg.reserve_need(lists)", 1, true) ~= nil and sk:find("local resv = reserve_need(f)", 1, true) ~= nil
    and sk:find("local rroom = rq and Sg.resv_room(rq, Stock.count(f, item)) or 0", 1, true) ~= nil
    and sk:find("local k = math.min(n - put, math.max(room, rroom))", 1, true) ~= nil)
  check("cablage C2 : saturees au plafond (Sg.over_cap sur f.team.ia3.saturated, compte du stock), une ligne [FO-STOCKAGE] quand l'ensemble change",
    sk:find("local set = Sg.over_cap(ia3 and ia3.saturated, function(it) return Stock.count(f, it) end, stack_of, T.stockage)", 1, true) ~= nil
    and sk:find("plafond des saturees", 1, true) ~= nil)
  local mc, ml = read("script/team/migration_champ.lua"), read("script/team/melange.lua")
  check("cablage A : retire verifie le contenu des paires avant tout retrait, ses 3 appelants attendent sans rien compter",
    mc:find("  if not contents_fit(f, st.ids, list, ents) then return 0, {}, {}, true end", 1, true) ~= nil
    and mc:find("local removed, got, undo, full = retire(f, surface, o, st, list, ents)", 1, true) ~= nil
    and select(2, mc:gsub("local removed, got, _, full = retire%(f, surface, o, { ids = ids, frame = true }, list, ents%)", "")) == 2
    and mc:find("spill_item_stack(f.hq_pos, { name = name, count = n - put }, true, f.force, false)", 1, true) ~= nil)
  check("cablage A : melange ne releve du tapis que ce que le stock prend", ml:find("local room = Stock.room and Stock.room(f, it[1])", 1, true) ~= nil
    and ml:find("{ name = it[1], count = got - put }, true, f.force, false)", 1, true) ~= nil)
  check("cablage : compteurs des depots refuses et des poches pleines (prise de tache, worker.lua), une ligne chacun par minute",
    wk:find("Stock.note_claim(f, main_inv(agent), tick)", 1, true) ~= nil and sk:find("if opts and opts.reserve then count_refused(f, n - put, tick) end", 1, true) ~= nil
    and sk:find("flush_counts(f, tick)", 1, true) ~= nil)
  check("cablage (d) : places des annexes sur les deux faces du lot du QG, plafond moins les places tenues", sk:find("for _, o in ipairs(A.slots(-sy, w, h)) do out[#out + 1] = o end", 1, true) ~= nil
    and sk:find("return math.max(0, #annex_slots(f, w, h) - (f.annex_lost or 0))", 1, true) ~= nil)
  check("cablage (a) : coffre en main sans place libre : la raison au journal [FO-ANNEXE], bornee", sk:find("coffre en main mais aucune place libre", 1, true) ~= nil
    and sk:find("local rows = Stock.annex_blockers(f, surface, T.annex.kinds[1].item)", 1, true) ~= nil)
  check("cablage : le stock reprend les objets au sol du QG a chaque passage (Stock.grow -> Stock.pick_ground)",
    sk:find("  Stock.pick_ground(f, surface, tick) -- lot STOCKAGE-VITAL", 1, true) ~= nil
    and sk:find('find_entities_filtered({ name = "item-on-ground", position = f.hq_pos, radius = Stock.GROUND_RADIUS,', 1, true) ~= nil)
  check("cablage D1 : au depot, la matiere demandee prend la reserve, bornee (Sg.demand_room, f.stock_dem)",
    sk:find("local room, rec = Sg.demand_room(f.stock_dem and f.stock_dem[item], need[item], src_s, src_m)", 1, true) ~= nil
    and sk:find("if rec and room > 0 then rec.used = rec.used + math.min(got, room) end", 1, true) ~= nil)
  check("cablage : Stock.insert borne les non vitales (Sg.new_stacks, reserve au seul coffre du QG), pas les coffres d'annexe", sk:find("local allowed = Sg.new_stacks(item, em, #hq_inv, VITAL, T.stockage)", 1, true) ~= nil
    and sk:find("local plan = opts and opts.reserve and not VITAL[item] and not ANNEX[item] and non_vital_plan(f, item, n) or nil", 1, true) ~= nil
    and wk:find("local moved = Stock.insert(f, name, n, DEPOSIT_OPTS)", 1, true) ~= nil and wk:find("local DEPOSIT_OPTS = { reserve = true }", 1, true) ~= nil)
  check("cablage : un coffre refuse au depot est pose en annexe (place_held)", sk:find("if put < n and ANNEX[item] then put = put + place_held(f, item, n - put) end", 1, true) ~= nil
    and sk:find("place_held = function(f, item, k)", 1, true) ~= nil)
  check("cablage : depot refuse au journal, au plus une ligne par Stock.REFUSED_LOG", sk:find("tick - f.refused_log >= Stock.REFUSED_LOG", 1, true) ~= nil
    and sk:find("depot refuse", 1, true) ~= nil)
  local pl = read("script/team/poles.lua")
  check("cablage D3 : le fond recoit les coffres BRUTS voulus et la demande du plan directeur", pl:find("annex_want = Stock.wanted(f, true)", 1, true) ~= nil
    and select(2, pl:gsub("annex_demand = Stock.annex_demand%(f%)", "")) == 2 and sk:find("gross and 0 or have", 1, true) ~= nil)
  check("cablage : coffre urgent ajoute au tableau hors du fond, raison au journal", pl:find("local urgent_on = stock_urgent(f, view, free, book, keys, tick)", 1, true) ~= nil
    and pl:find("if #tasks > 0 then Board.add(f, tasks, tick) end", 1, true) ~= nil and pl:find("harvestable = from_trees", 1, true) ~= nil
    and pl:find("fin de l'urgence", 1, true) ~= nil)
  check("cablage : recolte urgente puis fabrication sur place (worker)", wk:find('if tc then steps[#steps + 1] = { "craft_now", tc.crafts, tc.ticks, tc.item } end', 1, true) ~= nil
    and wk:find('elseif kind == "craft_now" then', 1, true) ~= nil)
  check("cablage : coffre urgent demande (Stock.wanted) et journal [FO-STOCKAGE]", sk:find("if Sg.urgent(used / size, have > 0, T.stockage) and n < capacity(f) then w = math.max(w, 1) end", 1, true) ~= nil
    and sk:find("[FO-STOCKAGE]", 1, true) ~= nil)
end

-- configuration : l'urgence se déclenche AVANT le plafond des non vitales (sinon une pierre arrêtée par la réserve ne la déclencherait
-- jamais) ; le ramassage des non vitales s'arrête au plus tard à l'urgence
do
  local T = require("shared.team.config")
  local Sg = load(SRC, "=" .. PATH)()
  local cfg, bad_sizes = T.stockage, {}
  for size = 16, 784, 16 do
    if cfg.urgent_at * size > size - Sg.reserve_slots(size, cfg) + 1e-9 then bad_sizes[#bad_sizes + 1] = size end
  end
  check("configuration : urgent_at sous le plafond des non vitales (16 a 784 cases)", #bad_sizes == 0, table.concat(bad_sizes, " "))
  check("configuration : stop_at <= urgent_at (plus de ramassage des non vitales au plus tard a l'urgence)", cfg.stop_at <= cfg.urgent_at)
end

-- coffre URGENT (shared/team/fond.lua, F.annex_urgent) : sans fer (coffre en bois d'abord), récolte du bois puis fabrication sur place,
-- raison écrite (faite, déjà là, refusée et pourquoi), hors capacité du fond
local function urgent_suite(F)
  local res = {}
  local function check(name, cond, detail) res[#res + 1] = { name, cond and true or false, detail } end
  do
    local T = require("shared.team.config")
    local IRON, WOOD = T.outposts.iron.product, "wood"
    local CH, WCH = T.annex.kinds[1].item, T.annex.kinds[2].item
    check("donnees : le coffre en bois est le coffre sans plaque (cheap)", T.annex.kinds[2].cheap == true and not T.annex.kinds[1].cheap)
    local function book(ok_items)
      return {
        handcraftable = function(_, item) return ok_items[item] == true end,
        plan = function(_, list, avail)
          local item = list[1][1]
          local need = (item == CH) and { [IRON] = 8 } or { [WOOD] = 2 }
          local raw, uses = {}, {}
          for k, v in pairs(need) do
            local have = math.max(0, avail[k] or 0)
            if have < v then raw[k] = v - have end
            uses[k] = math.min(v, have)
          end
          return { raw = raw, crafts = { { recipe = item, runs = 1, energy = 0.5 } }, uses = uses }
        end,
      }
    end
    local B = book({ [CH] = true, [WCH] = true })
    local U = { book = B, annex_urgent = true }
    local function ctx(extra)
      local c = { book = B, annex_urgent = true }
      for k, v in pairs(extra or {}) do c[k] = v end
      return c
    end
    local yes = function(item) return item == WOOD end
    local no = function() return false end
    -- 1. le coffre en bois d'abord, même quand le fer est là (le coffre urgent ne dépend pas du fer)
    local t, why = F.annex_urgent({}, { [IRON] = 8, [WOOD] = 4 }, U)
    check("urgent : bois et fer au stock -> coffre en bois (pas de fer)", #t == 1 and t[1].item == WCH and t[1].kind == "craft", t[1] and t[1].item)
    check("urgent : raison ecrite (fabrication)", type(why) == "string" and why:find("fabrication de " .. WCH, 1, true) ~= nil, why)
    check("urgent : priorite vitale (celle des urgences du tableau), hors capacite du fond", t[1] ~= nil and t[1].prio == F.URGENT_PRIO and t[1].prio == require("shared.team.org").URGENT_PRIO
      and t[1].fond == nil, t[1] and tostring(t[1].fond))
    -- 2. fer à 0, bois au stock
    t = F.annex_urgent({}, { [IRON] = 0, [WOOD] = 4 }, U)
    check("urgent : fer a 0, bois au stock -> coffre en bois", #t == 1 and t[1].item == WCH, #t)
    -- 3. sans bois, fer au stock : coffre de fer en secours
    t, why = F.annex_urgent({}, { [IRON] = 8 }, ctx({ harvestable = no }))
    check("urgent : sans bois, 8 plaques -> coffre de fer en secours", #t == 1 and t[1].item == CH and t[1].kind == "craft", why)
    -- 4. ni bois ni fer, bois récoltable : récolte puis fabrication sur place
    t, why = F.annex_urgent({}, { [IRON] = 0 }, ctx({ harvestable = yes }))
    local m = t[1] or {}
    check("urgent : ni bois ni fer -> recolte du bois sur les arbres (prudente)", #t == 1 and m.kind == "mine" and m.resource == WOOD and m.trees == true
      and m.prudent == true and (m.count or 0) >= 2 and m.short == m.count and m.prio == F.URGENT_PRIO and m.fond == nil, m.kind)
    check("urgent : la recolte fabrique le coffre en bois sur place", m.then_craft ~= nil and m.then_craft.item == WCH
      and #m.then_craft.crafts == 1 and m.then_craft.ticks >= 30 + F.URGENT_CRAFT_SLACK, m.then_craft and m.then_craft.ticks)
    check("urgent : raison ecrite (recolte)", type(why) == "string" and why:find("recolte de " .. tostring(m.count) .. " " .. WOOD, 1, true) ~= nil, why)
    -- 5. ni bois ni fer, rien de récoltable : refus et pourquoi
    t, why = F.annex_urgent({}, { [IRON] = 0 }, ctx({ harvestable = no }))
    check("urgent : rien de recoltable -> aucune tache, refus ecrit avec la matiere qui manque", #t == 0 and type(why) == "string"
      and why:find("refuse", 1, true) == 1 and why:find(WCH .. " manque " .. WOOD .. " 2", 1, true) ~= nil
      and why:find(CH .. " manque " .. IRON .. " 8", 1, true) ~= nil, why)
    t, why = F.annex_urgent({}, { [IRON] = 0 }, U)
    check("urgent : sans regle de recolte -> refus (recolte inconnue)", #t == 0 and type(why) == "string" and why:find("recolte inconnue", 1, true) ~= nil, why)
    -- 6. déjà là : en main, en route, au tableau
    t, why = F.annex_urgent({}, { [IRON] = 8, [CH] = 1 }, U)
    check("urgent : coffre en main -> rien (raison)", #t == 0 and type(why) == "string" and why:find("deja en main", 1, true) ~= nil, why)
    t, why = F.annex_urgent({ incoming = { [WCH] = 1 } }, { [WOOD] = 4 }, U)
    check("urgent : coffre en route -> rien (raison)", #t == 0 and type(why) == "string" and why:find("deja en route", 1, true) ~= nil, why)
    t, why = F.annex_urgent({}, { [WOOD] = 4 }, ctx({ keys = { ["fond:craft:" .. WCH .. ":annexe-urgente"] = true } }))
    check("urgent : fabrication deja au tableau -> rien (raison)", #t == 0 and type(why) == "string" and why:find("fabrication deja au tableau", 1, true) ~= nil, why)
    t, why = F.annex_urgent({}, {}, ctx({ harvestable = yes, keys = { ["fond:mine:" .. WOOD .. ":annexe-urgente"] = true } }))
    check("urgent : recolte deja au tableau -> rien (raison)", #t == 0 and type(why) == "string" and why:find("recolte deja au tableau", 1, true) ~= nil, why)
    t, why = F.annex_urgent({}, { [IRON] = 8 }, { book = B, annex_urgent = false })
    check("urgent : rien sans urgence (ni tache ni raison)", #t == 0 and why == nil)
    -- 7. par le fond : pendant l'urgence, le fond ne fabrique pas d'autre coffre ; sans urgence, il en fabrique (annex_want)
    local stock = { [IRON] = 400, ["copper-plate"] = 0, stone = 0, [WOOD] = 0 }
    local c1 = F.candidates({ incoming = {} }, stock, { book = B, keys = {}, annex_want = 1, annex_urgent = true })
    local c2 = F.candidates({ incoming = {} }, stock, { book = B, keys = {}, annex_want = 1 })
    local function chests(c) local n = 0 for _, x in ipairs(c.base) do if x.item == CH or x.item == WCH then n = n + 1 end end return n end
    check("fond : pendant l'urgence, aucun autre coffre", chests(c1) == 0, chests(c1))
    check("temoin : sans urgence, le fond fabrique son coffre (annex_want)", chests(c2) >= 1, chests(c2))
    -- 8. point D3 de docs/IA_WORKFLOW.md : un coffre que le plan directeur réclame n'est pas « en main » (Stock.wanted le retire déjà)
    t, why = F.annex_urgent({}, { [CH] = 2, [WOOD] = 4 }, ctx({ annex_demand = { [CH] = 2 } }))
    check("D3 urgent : 2 coffres de fer reserves au plan directeur -> le coffre urgent se fabrique", #t == 1 and t[1].item == WCH, why)
    t, why = F.annex_urgent({}, { [CH] = 3, [WOOD] = 4 }, ctx({ annex_demand = { [CH] = 2 } }))
    check("temoin D3 urgent : un coffre de plus que la demande -> deja en main", #t == 0 and type(why) == "string" and why:find("deja en main", 1, true) ~= nil, why)
    local function sD3() return { [IRON] = 400, [CH] = 2, ["copper-plate"] = 0, stone = 0 } end
    local d1 = F.candidates({ incoming = {} }, sD3(), { book = B, keys = {}, annex_want = 2, annex_demand = { [CH] = 2 } })
    local d2 = F.candidates({ incoming = {} }, sD3(), { book = B, keys = {}, annex_want = 2 })
    check("D3 fond : coffres reserves au plan directeur -> le fond en fabrique", chests(d1) >= 1, chests(d1))
    check("temoin D3 fond : 2 coffres libres en main pour 2 voulus -> aucun de plus", chests(d2) == 0, chests(d2))
  end
  return res
end
package.path = "./?.lua;" .. package.path
local FOND_PATH = "shared/team/fond.lua"
local FOND_SRC = read(FOND_PATH)
local function run_fond(text)
  local chunk, err = load(text, "=" .. FOND_PATH)
  if not chunk then return { { "fond illisible : " .. tostring(err), false } } end
  local okm, F = pcall(chunk)
  if not okm then return { { "fond : " .. tostring(F), false } } end
  local okr, res = pcall(urgent_suite, F)
  if not okr then return { { "suite fond : " .. tostring(res), false } } end
  return res
end
for _, r in ipairs(run_fond(FOND_SRC)) do check(r[1], r[2], r[3]) end
local NL = string.char(10)
local FMUT = {
  { "fond : ordre de T.annex.kinds (fer d'abord)", "  local list = {}" .. NL .. "  for _, k in ipairs(T.annex.kinds) do if k.cheap then", "  do return T.annex.kinds end" .. NL .. "  local list = {}" .. NL .. "  for _, k in ipairs(T.annex.kinds) do if k.cheap then" },
  { "fond : coffre en main ignore", '    if (free[k.item] or 0) - (demand[k.item] or 0) > 0 then return out, "deja en main : " .. k.item end' .. NL, "" },
  { "fond : coffre en route ignore", '    if (incoming[k.item] or 0) > 0 then return out, "deja en route : " .. k.item end' .. NL, "" },
  { "fond : pas de recolte", "    if m.k.cheap and #raws == 1 and ctx.harvestable and ctx.harvestable(raws[1][1]) then", "    if false then" },
  { "fond : recolte d'une matiere non recoltable", "ctx.harvestable and ctx.harvestable(raws[1][1]) then", "ctx.harvestable ~= nil then" },
  { "fond : recolte sans fabrication sur place", "          then_craft = { item = m.k.item,", "          no_craft = { item = m.k.item," },
  { "fond : recolte trop petite", "      local n = math.max(raws[1][2], F.URGENT_GATHER)", "      local n = 1" },
  { "fond : recolte deja au tableau ignoree", '      if keys[key] then return out, "recolte deja au tableau', '      if false then return out, "recolte deja au tableau' },
  { "fond : coffre urgent sous la priorite des urgences", "F.URGENT_PRIO = 90", "F.URGENT_PRIO = F.PRIO.extend + 1" },
  { "fond : coffre urgent compte au fond", 'uses = sorted_uses(p.uses), domain = "production", tag = "annexe-urgente" }', 'uses = sorted_uses(p.uses), domain = "production", tag = "annexe-urgente", fond = true }' },
  { "fond : autre coffre pendant l'urgence", "  if ctx.annex_urgent then need = 0 end", "" },
  { "D3 urgent : coffres reserves comptes en main", "    if (free[k.item] or 0) - (demand[k.item] or 0) > 0 then return out", "    if (free[k.item] or 0) > 0 then return out" },
  { "D3 fond : coffres reserves comptes en main", "      need = need - math.max(0, (free[k.item] or 0) - (demand[k.item] or 0))", "      need = need - (free[k.item] or 0)" },
}
local frefused, fkept = 0, {}
for _, m in ipairs(FMUT) do
  local a1, z1 = FOND_SRC:find(m[2], 1, true)
  if not a1 then fkept[#fkept + 1] = m[1] .. " (motif introuvable)" else
    local res = run_fond(FOND_SRC:sub(1, a1 - 1) .. m[3] .. FOND_SRC:sub(z1 + 1))
    local seen = false
    for _, r in ipairs(res) do if not r[2] then seen = true break end end
    if seen then frefused = frefused + 1 else fkept[#fkept + 1] = m[1] end
  end
end
check(string.format("mutants du fond refuses %d/%d%s", frefused, #FMUT, #fkept > 0 and (" ; survivants : " .. table.concat(fkept, ", ")) or ""), frefused == #FMUT)
print(string.format("[STOCKAGE] mutants du fond refuses %d/%d", frefused, #FMUT))

local MUT = {
  { "reserve arrondie au-dessous", "  return math.ceil(cfg.reserve * size - 1e-9)", "  return math.floor(cfg.reserve * size + 1e-9)" },
  { "vitale soumise a la reserve", "  if vital and vital[item] then return empty end", "" },
  { "non vitale sans reserve", "  return math.max(0, empty - Sg.reserve_slots(size, cfg))", "  return empty" },
  { "vitale saturee plus ramassee", "if not vital[item] and not need[item] then out[item] = true end", "if not need[item] then out[item] = true end" },
  { "demande ignoree (stock presque plein)", "  if set.__keep and set.__keep[item] then return false end\n", "" },
  { "demande ignoree (saturee)", "if not vital[item] and not need[item] then out[item] = true end", "if not vital[item] then out[item] = true end" },
  { "demande ignoree (plaque sans son minerai)", "    if q > 0 then out[l[1]], out[l[2]] = q, q end", "" },
  { "quantites additionnees au lieu du maximum", "out[m[1]] = math.max(out[m[1]] or 0, n) end", "out[m[1]] = (out[m[1]] or 0) + n end" },
  { "au-dela de la quantite demandee (borne ignoree)", "  return math.max(0, q - rec.used), rec", "  return q, rec" },
  { "demande jamais recomptee (compte jamais remis a zero)", "  if not rec or rec.q ~= q or rec.s ~= s or rec.m ~= m then rec = { q = q, used = 0, s = s, m = m } end", "  if not rec then rec = { q = q, used = 0, s = s, m = m } end" },
  { "borne liee a la valeur, pas a la pensee (B1)", "  if not rec or rec.q ~= q or rec.s ~= s or rec.m ~= m then rec = { q = q, used = 0, s = s, m = m } end", "  if not rec or rec.q ~= q then rec = { q = q, used = 0, s = s, m = m } end" },
  { "C1 : manques des reserves ignores", "    if type(k) == \"number\" and k > 0 then out[it] = math.max(out[it] or 0, k) end", "" },
  { "C1 : reserves en maximum au lieu de somme", "      if type(m[1]) == \"string\" and n > 0 then out[m[1]] = (out[m[1]] or 0) + n end", "      if type(m[1]) == \"string\" and n > 0 then out[m[1]] = math.max(out[m[1]] or 0, n) end" },
  { "C1 : manque nul d'une reserve compte", "      if type(m[1]) == \"string\" and n > 0 then out[m[1]] = (out[m[1]] or 0) + n end", "      if type(m[1]) == \"string\" then out[m[1]] = (out[m[1]] or 0) + n end" },
  { "C1 : borne sans le stock", "  return math.max(0, (q or 0) - (have or 0))", "  return math.max(0, q or 0)" },
  { "C1 : borne negative", "  return math.max(0, (q or 0) - (have or 0))", "  return (q or 0) - (have or 0)" },
  { "manque nul compte comme demande", "    if type(n) == \"number\" and n > 0 then out[item] = math.max(out[item] or 0, n) end", "    if type(n) == \"number\" then out[item] = math.max(out[item] or 0, n) end" },
  { "manque de l'objectif ignore", "    if type(m[1]) == \"string\" and n > 0 then out[m[1]] = math.max(out[m[1]] or 0, n) end", "" },
  { "saturee ecartee meme quand rien ne manque", "  if short ~= false then\n", "  if true then\n" },
  { "place des piles entamees ignoree (contenu au stock)", "    local rest = (r.n or 0) - (r.part or 0)", "    local rest = (r.n or 0)" },
  { "cases neuves arrondies au-dessous", "need = need + math.ceil(rest / math.max(1, r.stack or 1))", "need = need + math.floor(rest / math.max(1, r.stack or 1))" },
  { "contenu juste a la place refuse", "  return need <= (empty or 0), need", "  return need < (empty or 0), need" },
  { "stock presque plein ignore", "  out.__all_non_vital = (fill or 0) >= cfg.stop_at or nil", "  out.__all_non_vital = nil" },
  { "seuil de plein a l'envers", "(fill or 0) >= cfg.stop_at", "(fill or 0) > cfg.stop_at" },
  { "vitale jamais protegee au ramassage", "  if vital and vital[item] then return set.__over ~= nil and set.__over[item] == true end\n", "" },
  { "C2 : plafond ignore pour une vitale", "  if vital and vital[item] then return set.__over ~= nil and set.__over[item] == true end", "  if vital and vital[item] then return false end" },
  { "C2 : plafond sans la saturation", "    if saturated[it] then names[#names + 1] = it end", "    names[#names + 1] = it" },
  { "C2 : plafond strict (>)", "    if n and st and n >= cap * st then out[it] = n end", "    if n and st and n > cap * st then out[it] = n end" },
  { "C2 : plafond qui ecarte une demande", "    if not need[item] then out[item] = true; over_set[item] = true end", "    out[item] = true; over_set[item] = true" },
  { "C2 : plafond soumis aux autres manques", "  for item in pairs(over or {}) do", "  for item in pairs(short ~= false and {} or over or {}) do" },
  { "C2 : plafond ignore", "  for item in pairs(over or {}) do", "  for item in pairs({}) do" },
  { "C2 : plafond par defaut absent", "Sg.DEFAULT = { reserve = 0.15, stop_at = 0.80, urgent_at = 0.80, sat_cap = 20 }", "Sg.DEFAULT = { reserve = 0.15, stop_at = 0.80, urgent_at = 0.80, sat_cap = 1e9 }" },
  { "urgence malgre un coffre en main", "  return (fill or 0) >= cfg.urgent_at and not have_chest", "  return (fill or 0) >= cfg.urgent_at" },
  { "urgence trop tard", "  return (fill or 0) >= cfg.urgent_at and not have_chest", "  return (fill or 0) > cfg.urgent_at and not have_chest" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local a, z = SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local res = run(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(z + 1))
    local seen = false
    for _, r in ipairs(res) do if not r[2] then seen = true break end end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(string.format("mutants refuses %d/%d%s", refused, #MUT, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUT)
print(string.format("[STOCKAGE] mutants refuses %d/%d", refused, #MUT))
print(string.format("[STOCKAGE] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
