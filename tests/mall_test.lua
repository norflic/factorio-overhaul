--[[
  Lot PILE-MALL : banc HORS JEU de la règle du mall (shared/ai3/mall.lua) et de son branchement au cerveau par besoins (st.mall,
  journal [FO-MALL]). Lancement, depuis la racine du mod : lua5.2 tests/mall_test.lua
    1. relevé de la demande à la main (épisodes, volume, fenêtre par moitié, demande ré-émise à l'identique = un seul épisode) ;
    2. choix des objets (minimum d'épisodes, recette connue, plafond, ordre), usines par objet, cible ;
    3. la main n'est permise que pour l'amorçage (Ml.hand_allowed) ;
    4. lot INDUSTRIE I6 : demande d'une autre source (Ml.want, Ml.sources), péremption, journal ;
    5. cerveau par besoins : la pensée tient st.mall à jour, état sérialisable, sans effet quand le réglage est éteint ;
    6. mutants.
]]
package.path = "./?.lua;" .. package.path
local Book = require("shared.team.book")
local book = Book.new(dofile("tests/fixtures/recipes.lua"))
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end
local TURRET, MAG, GEAR = "gun-turret", "firearm-magazine", "iron-gear-wheel" -- données du banc

local function battery(Ml, verbose)
  local fails = 0
  local function ck(c, msg)
    if not c then fails = fails + 1 if verbose then print("  ECHEC : " .. msg) end end
    if verbose then check(c, msg) end
  end
  -- 1. relevé
  local st = Ml.new()
  Ml.note(st, 0, { [TURRET] = 4 })
  Ml.note(st, 10, { [TURRET] = 4 })           -- ré-émise à l'identique : rien de plus
  ck(st.use[TURRET].n == 4 and st.use[TURRET].episodes == 1, "1a. demande ré-émise à l'identique : un épisode, volume 4")
  Ml.note(st, 20, { [TURRET] = 7 })           -- augmente : le volume reçoit l'augmentation, pas un nouvel épisode
  ck(st.use[TURRET].n == 7 and st.use[TURRET].episodes == 1, "1b. la demande monte de 4 à 7 : volume 7, toujours un épisode")
  Ml.note(st, 25, { [TURRET] = 5 })           -- la demande baisse (les tourelles se fabriquent) : le volume ne baisse pas
  ck(st.use[TURRET].n == 7, "1b2. demande qui baisse : volume inchangé")
  Ml.note(st, 30, {})                          -- servie : tombe à zéro
  Ml.note(st, 40, { [TURRET] = 2 })
  ck(st.use[TURRET].n == 9 and st.use[TURRET].episodes == 2, "1c. retombée à 0 puis nouvelle demande : deuxième épisode (volume 9)")
  Ml.note(st, Ml.WINDOW_TICKS + 100, {})
  ck(st.use[TURRET].n == 4 and st.use[TURRET].episodes == 1, "1d. fenêtre : volume et épisodes divisés par deux (" .. st.use[TURRET].n .. ", " .. st.use[TURRET].episodes .. ")")
  Ml.note(st, 3 * Ml.WINDOW_TICKS, {})
  ck(st.use[TURRET] == nil, "1e. la mémoire s'éteint d'elle-même sans nouvelle demande")
  -- 2. choix
  local s2 = Ml.new()
  for i = 1, 3 do
    Ml.note(s2, i * 100, { [TURRET] = 5, [MAG] = 40, [GEAR] = 3 })
    Ml.note(s2, i * 100 + 50, {})
  end
  Ml.note(s2, 400, { ["objet-sans-recette"] = 9 }); Ml.note(s2, 410, {}); Ml.note(s2, 420, { ["objet-sans-recette"] = 9 }); Ml.note(s2, 430, {})
  Ml.note(s2, 440, { ["objet-sans-recette"] = 9 }); Ml.note(s2, 450, {})
  local out = Ml.decide(s2, book, { have = { [MAG] = 0 } })
  ck(#out == 3 and out[1].item == MAG and out[2].item == TURRET and out[3].item == GEAR, "2a. trois objets, du plus demandé au moins demandé, l'objet sans recette écarté")
  ck(out[1].machines >= 1 and out[1].machines <= Ml.MACHINES_MAX and out[1].machines >= out[3].machines, "2b. plusieurs usines selon la demande, de 1 à " .. Ml.MACHINES_MAX)
  local s3 = Ml.new()
  Ml.note(s3, 0, { [TURRET] = 5 }); Ml.note(s3, 1, {}); Ml.note(s3, 2, { [TURRET] = 5 })
  ck(#Ml.decide(s3, book, {}) == 0, "2c. moins de " .. Ml.MIN_EPISODES .. " épisodes : pas de mall pour cet objet")
  ck(Ml.machines(0, nil) == 1 and Ml.machines(1000, 6) == Ml.MACHINES_MAX and Ml.machines(6, 6) == Ml.LEAD, "2d. usines : au moins 1, au plus le plafond, 2 fois le débit voulu")
  ck(Ml.target(3) == 3 * Ml.HORIZON_MIN and Ml.target(0) == 1, "2e. cible = demande de " .. Ml.HORIZON_MIN .. " minutes")
  ck(Ml.refill == nil and Ml.layout == nil and Ml.extent == nil, "2f. lot I6 : hystérésis du coffre et gabarit en rangée retirés (la barre du coffre et les patrons les remplacent)")
  local s4 = Ml.new()
  local anybook = { recipe_for = function() return "r" end }
  for i = 1, Ml.MAX_ITEMS + 5 do
    local item = string.format("objet-%03d", i)
    for j = 1, 3 do Ml.note(s4, j * 10, { [item] = i + 1 }); Ml.note(s4, j * 10 + 5, {}) end
  end
  local out4 = Ml.decide(s4, anybook, {})
  ck(#out4 == Ml.MAX_ITEMS and Ml.MAX_ITEMS > 8, "2g. au plus " .. Ml.MAX_ITEMS .. " objets, le plafond n'est plus 8 (" .. #out4 .. ")")
  ck(out4[1].item == string.format("objet-%03d", Ml.MAX_ITEMS + 5), "2g2. les plus demandés d'abord")
  -- 3. la main
  local s5 = { running = { [TURRET] = true } }
  ck(Ml.hand_allowed(s5, TURRET, 10) == false and Ml.hand_allowed(s5, TURRET, 0) == true and Ml.hand_allowed(s5, MAG, 10) == true
    and Ml.hand_allowed(nil, TURRET, 10) == true, "3. la main : refusée si le mall tourne et que le stock existe ; permise à l'amorçage ou à sec")
  -- 3b. Relecture : le maillon vers les usines (puits de la capitalisation), « le mall tourne » mesuré, frein de la main
  local s6 = { items = { { item = TURRET, rate = 2.5 }, { item = MAG, rate = 0 } } }
  local sk = Ml.sinks(s6)
  ck(#sk == 1 and sk[1].item == TURRET and sk[1].rate == 2.5 and sk[1].want == 2.5, "3b. la demande du mall devient un puits, au débit mesuré")
  ck(#Ml.sinks(nil) == 0, "3c. sans mall : aucun puits")
  Ml.set_running(s6, { [TURRET] = { made = 10, hand = 10 } })
  ck(not s6.running[TURRET], "3d. seule la main a produit : le mall ne tourne pas")
  Ml.set_running(s6, { [TURRET] = { made = 12, hand = 10 } })
  ck(s6.running[TURRET] == true, "3e. une machine a produit : le mall tourne")
  local tk = Ml.filter_crafts(s6, { { kind = "craft", item = TURRET, prio = 30 }, { kind = "craft", item = TURRET, prio = 75 },
    { kind = "craft", item = MAG, prio = 30 }, { kind = "mine", prio = 30 } }, { [TURRET] = 5 }, 60)
  ck(#tk == 3 and tk[1].prio == 75 and tk[2].item == MAG and tk[3].kind == "mine", "3f. fabrication retirée sauf urgente, autre objet ou autre sorte")
  ck(#Ml.filter_crafts(s6, { { kind = "craft", item = TURRET, prio = 30 } }, { [TURRET] = 0 }, 60) == 1, "3g. à sec : la main reprend")
  Ml.set_running(s6, {})
  ck(#Ml.filter_crafts(s6, { { kind = "craft", item = TURRET, prio = 30 } }, { [TURRET] = 5 }, 60) == 1, "3h. machine arrêtée : la main reprend (aucun blocage)")
  -- 4. lot INDUSTRIE I6 : la demande d'une autre source
  local s7 = Ml.new()
  ck(Ml.want(s7, 100, "x", 3, "refus") == true and Ml.want(s7, 100, "y", 0, "refus") == false and Ml.want(s7, 100, 5, 1) == false,
    "4a. Ml.want : une demande positive est notée, nulle ou sans nom refusée")
  Ml.note(s7, 100, { [TURRET] = 5, [MAG] = 9 }); Ml.note(s7, 110, {}); Ml.note(s7, 120, { [TURRET] = 5, [MAG] = 9 }); Ml.note(s7, 130, {}); Ml.note(s7, 140, { [TURRET] = 5 })
  local src = Ml.sources(s7, 150)
  local by = {}
  for _, c in ipairs(src) do by[c.item] = c end
  ck(#src == 2 and by[TURRET] and by[TURRET].src == "main" and math.abs(by[TURRET].rate - 15 / Ml.WINDOW_MIN) < 1e-9
    and by.x and by.x.src == "refus" and by.x.rate == 3, "4b. Ml.sources : la main (volume ÷ fenêtre) et la demande notée")
  ck(#Ml.sources(s7, 100 + Ml.WANT_TTL + 1) == 1 and s7.want.x == nil, "4c. une demande qu'on ne renouvelle pas s'éteint après " .. Ml.WANT_TTL .. " ticks")
  Ml.want(s7, 5000, "x", 4, "refus")
  ck(Ml.sources(s7, 5000 + Ml.WANT_TTL)[2] ~= nil and Ml.sources(s7, 5000 + Ml.WANT_TTL)[2].rate == 4, "4d. renouvelée, elle dure (la dernière valeur compte)")
  local s8 = { items = {}, want = { w = { rate = 1, tick = 0, src = "refus" } } }
  Ml.set_running(s8, { w = { made = 3, hand = 0 } })
  ck(s8.running.w == true, "4e. un objet de bloc (demande notée) qui produit est dit TOURNE")
  Ml.set_running(s8, { w = { made = 3, hand = 3 } })
  ck(not s8.running.w, "4f. produit à la main seulement : ne tourne pas")
  ck(Ml.sources(nil, 0) ~= nil and #Ml.sources(nil, 0) == 0, "4g. sans état : aucune demande")
  ck(Ml.describe(s2):find("amorcage a la main", 1, true) ~= nil, "4e. journal [FO-MALL] : amorçage à la main tant que le mall ne tourne pas")
  return fails
end

print("== 1 à 4. Règle pure")
battery(require("shared.ai3.mall"), true)

print("== 5. Cerveau par besoins")
local C = require("shared.ai3.cerveau")
local R = require("shared.ai3.reglages")
do
  local T = require("shared.team.config")
  local S = require("shared.team.scale")
  local B = require("shared.ai3.buts")
  local function view(over)
    local v = {
      tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {}, outposts = {},
      pending = {}, sites = {}, smelters = 2, smelters_pending = 0, smelter_task = false, smelter_output = 0,
      smelter_fuel_low = false, smelter_coal = 0, turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 10,
      workers_max = 30, workers_idle = 2, threatened = false, open = {}, workers_wanted = 10, no_research = true,
      ladder = T.player_ladder, hq_turrets = 0, defend_first = true, is_player = true,
    }
    for k, x in pairs(over or {}) do v[k] = x end
    if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
    return v
  end
  local function op(id, kind) return { id = id, kind = kind, drills = T.outposts[kind].drills, full = false, turrets = 8, coal_needed = 0,
    fuel_low = false, output = 0, idle_ticks = 0, has_task = false, has_fortify = false } end
  local outs = { op(1, "iron"), op(2, "coal"), op(3, "copper") }
  local stock = { [T.outposts.iron.product] = 900, [T.outposts.copper.product] = 300, [T.turret_ammo] = 100, [T.fuel] = 400, stone = 300 }
  local function ctx(tick) return { tick = tick, is_player = true, weights = B.weights({}, nil),
    reach = { [T.outposts.iron.resource] = 60, [T.fuel] = 60 } } end
  local st = C.new_state(0)
  st.targets = { iron = 1, coal = 1, copper = 1, stone = 0 }
  st.iron2_set = true
  local ok, err = true, nil
  for i = 1, 4 do
    local ok2, e = pcall(C.think, view({ outposts = outs, stock = stock }), book, st, ctx(i * 600))
    if not ok2 then ok, err = false, e end
  end
  check(ok, "5a0. la pensée ne plante pas (" .. tostring(err) .. ")")
  check(ok and type(st.mall) == "table" and st.mall.items ~= nil, "5a. la pensée tient st.mall à jour (réglage allumé)")
  local function no_fn(t, seen)
    seen = seen or {}
    if seen[t] then return true end
    seen[t] = true
    for _, v in pairs(t) do
      if type(v) == "function" then return false end
      if type(v) == "table" and not no_fn(v, seen) then return false end
    end
    return true
  end
  check(ok and st.mall and no_fn(st.mall), "5b. état du mall sans fonction (sauvegarde)")
  -- la demande de fabrication à la main alimente le relevé : les tourelles du QG (fabriquées par la main) y entrent
  local any = false
  for _ in pairs((st.mall and st.mall.use) or {}) do any = true end
  check(any, "5b2. au moins un objet fabriqué à la main est relevé")
  local saved = R.PILE_MALL
  R.PILE_MALL = false
  local st2 = C.new_state(0)
  st2.targets = { iron = 1, coal = 1, copper = 1, stone = 0 }
  pcall(C.think, view({ outposts = outs, stock = stock }), book, st2, ctx(600))
  R.PILE_MALL = saved
  check(st2.mall == nil, "5c. réglage éteint : aucun état de mall")
end

print("== 6. Mutants")
local function slurp(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local killed, total = 0, 0
local M = "shared/ai3/mall.lua"
local function mut(from, to, name)
  total = total + 1
  local src = slurp(M)
  local i, j = src:find(from, 1, true)
  if not i then check(false, "mutant '" .. name .. "' : texte introuvable") return end
  local tmp = require("tests.depot").tmpname() -- lot TESTS-GIT : os.tmpname() visait la racine du disque (refusée sur C:)
  local f = assert(io.open(tmp, "wb")) f:write(src:sub(1, i - 1) .. to .. src:sub(j + 1)) f:close()
  local ok, mod = pcall(dofile, tmp)
  os.remove(tmp)
  local n = ok and select(2, pcall(battery, mod, false)) or 1
  if type(n) ~= "number" or n > 0 then killed = killed + 1 else check(false, "mutant survivant : " .. name) end
end
mut("if prev == 0 then u.episodes = u.episodes + 1 end", "u.episodes = u.episodes + 1", "tout passage compte un épisode")
mut("if n > prev then", "if n > 0 then", "le volume reçoit toute la demande à chaque pensée")
mut("u.episodes >= Ml.MIN_EPISODES", "true", "minimum d'épisodes retiré")
mut("and book:recipe_for(k) ~= nil", "", "recette inconnue acceptée")
mut("if n > Ml.MACHINES_MAX then n = Ml.MACHINES_MAX end", "", "plafond d'usines retiré")
mut("if n < 1 then n = 1 end", "", "au moins une usine retiré")
mut("return (have or 0) <= 0", "return true", "la main toujours permise")
mut("math.min(#cands, Ml.MAX_ITEMS)", "#cands", "plafond d'objets retiré")
mut("if a.n ~= b.n then return a.n > b.n end", "if a.n ~= b.n then return a.n < b.n end", "ordre inversé")
mut("u.n, u.episodes = math.floor(u.n / 2), math.floor(u.episodes / 2)", "", "fenêtre sans moitié")
mut("if it.rate > 0 and not seen[it.item] then out[#out + 1] = { item = it.item, rate = it.rate, want = it.rate } end", "", "le mall sans puits : aucune usine") -- lot BUS-INTERMEDIAIRES : les lignes d'abord, sans doublon
mut("(fl.made or 0) - (fl.hand or 0) > 0", "(fl.made or 0) > 0", "la main comptée comme le mall")
mut("if tick - (w.tick or 0) <= Ml.WANT_TTL then", "if true then", "demande notée jamais périmée")
mut("if u.episodes >= Ml.MIN_EPISODES and u.n > 0 then out[#out + 1] = { item = k, rate = u.n / Ml.WINDOW_MIN, src = \"main\" } end",
  "if u.n > 0 then out[#out + 1] = { item = k, rate = u.n / Ml.WINDOW_MIN, src = \"main\" } end", "sources : minimum d'épisodes oublié")
mut("if type(item) ~= \"string\" or type(rate) ~= \"number\" or rate <= 0 then return false end", "", "Ml.want accepte tout")
mut("-- lot INDUSTRIE I6 : un objet du bloc de mall (demande notée par Ml.want) tourne lui aussi\n  for _, k in ipairs(sorted_keys(st.want)) do\n    local fl = (flows or {})[k]\n    if fl and (fl.made or 0) - (fl.hand or 0) > 0 then run[k] = true end\n  end", "", "un objet de bloc ne tourne jamais")
mut("(t.prio or 0) >= urgent or ", "", "la défense perd la main")
print(string.format("   mutants refusés : %d / %d", killed, total))
check(killed == total, "tous les mutants refusés")
print(string.format("[PILE-MALL] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, total))
os.exit(failures == 0 and 0 or 1)
