--[[
  Lot TV-PILOTE, point V10 : FAMILLE ARMÉE à parts réservées (shared/ai3/famille_armee.lua, branchée dans shared/ai3/cerveau.lua).
  Banc HORS JEU. Lancement, depuis la racine du mod : lua5.2 tests/famille_armee_test.lua
    1. la règle (membres, part, liste unique de besoins, réserve, prêt et retour) ;
    2. le cerveau : sans ctx.armee la pensée est celle d'avant (même plan, octet pour octet) ; avec, la réserve est calculée, journalisable,
       sérialisable, déterministe, et les buts militaires sont servis comme avant ;
    3. mutants : le texte de la règle est remplacé, le banc doit échouer.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function slurp(p) local f = assert(io.open(p, "rb")) local x = f:read("*a") f:close() return x end
local function load_fa(mutate)
  local src = slurp("shared/ai3/famille_armee.lua")
  if mutate then
    local i, j = src:find(mutate[1], 1, true)
    if not i then return nil, "texte introuvable : " .. mutate[1] end
    src = src:sub(1, i - 1) .. mutate[2] .. src:sub(j + 1)
  end
  local fn, err = load(src, "@shared/ai3/famille_armee.lua")
  if not fn then return nil, err end
  return fn()
end

local function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end

--- Batterie de la règle pure, rendue sur un module (le vrai, puis chaque mutant).
local function battery(Fa)
  -- 1. membres
  check(Fa.member({ family = "armee" }) and Fa.member({ family = "defense" }), "1 : armee et defense sont de la famille")
  check(not Fa.member({ family = "recherche" }) and not Fa.member({ family = "extraction" }) and not Fa.member({ family = "capital" }),
    "1 : recherche, extraction, capital n'en sont pas")
  check(not Fa.member({ family = "armee", late = true }), "1 : l'armee tardive de votre equipe n'en est pas (servie apres son economie)")
  check(not Fa.member(nil) and not Fa.member("x"), "1 : but absent : pas membre")
  -- 2. part
  check(Fa.share({ delta = 100, alpha = 150 }) == 250, "2 : part = delta + alpha (250 pour mille)")
  check(Fa.share({ delta = 400, alpha = 400 }) == Fa.SHARE_MAX and Fa.SHARE_MAX == 500, "2 : part plafonnee a 500 pour mille")
  local s, why = Fa.share(nil)
  check(s == nil and why and why:find("absentes", 1, true), "2 : parts absentes : aucune part, raison ecrite (" .. tostring(why) .. ")")
  s, why = Fa.share({ delta = 100 })
  check(s == nil and why and why:find("alpha", 1, true), "2 : alpha absent : aucune part inventee (" .. tostring(why) .. ")")
  s, why = Fa.share({ delta = 0 / 0, alpha = 10 })
  check(s == nil, "2 : NaN : aucune part")
  s, why = Fa.share({ delta = -5, alpha = 10 })
  check(s == nil and why:find("negatives", 1, true), "2 : part negative : aucune part")
  check(Fa.share({ delta = 0, alpha = 0 }) == 0, "2 : parts a zero : part nulle (rien ne sera retenu)")
  -- 3. besoins : UNE liste pour les deux voies
  local goals = {
    { key = "defense:munitions", family = "defense", kind = "stock", item = "m", n = 40 },
    { key = "armee", family = "armee", kind = "army", target = 6 },
    { key = "armee-tardive", family = "armee", kind = "army", target = 9, late = true },
    { key = "recherche", family = "recherche", kind = "research" },
    { key = "stock-vide", family = "defense", kind = "stock", item = "z", n = 0 },
  }
  local kit_of = function(g) if g.key == "armee" then return { { "arme", 1 }, { "m", 5 } } end return { { "ne-doit-pas-servir", 1 } } end
  local w = Fa.wants(goals, kit_of)
  check(#w == 3, "3 : trois besoins (munitions du but de stock, deux pieces du kit) : " .. #w)
  check(w[1].item == "m" and w[1].channel == "munitions" and w[2].item == "arme" and w[2].channel == "equipement" and w[3].item == "m",
    "3 : les deux voies dans UNE liste, canaux munitions et equipement")
  for _, x in ipairs(w) do check(x.item ~= "ne-doit-pas-servir" and x.item ~= "z", "3 : ni l'armee tardive ni un besoin nul : " .. x.item) end
  check(#Fa.wants(goals, nil) == 1, "3 : sans lecteur de kit, seules les munitions")
  check(#Fa.wants(nil, kit_of) == 0, "3 : buts absents : aucun besoin")
  -- 4. réserve
  local avail = { ["plaque"] = 1000, ["cuivre"] = 80, ["autre"] = 500 }
  local plan_raw = function(list)
    local raw = {}
    for _, it in ipairs(list) do raw["plaque"] = (raw["plaque"] or 0) + it[2] * 2 end -- chaque objet coute 2 plaques
    raw["cuivre"] = 500 -- un besoin en cuivre bien au-dela du stock
    return raw
  end
  local res = Fa.reserve(avail, w, plan_raw, 250)
  check(res.held["plaque"] == 92, "4 : plaques : min(stock 1000, besoin 92, part 250 de 1000 = 250) = 92 : " .. tostring(res.held["plaque"]))
  check(res.held["cuivre"] == 20, "4 : cuivre : part 250 pour mille de 80 = 20 (le stock borne) : " .. tostring(res.held["cuivre"]))
  check(res.held["autre"] == nil, "4 : une matiere que la famille ne reclame pas n'est pas retenue")
  local plan_small = function(list) return { plaque = 30 } end
  local res2 = Fa.reserve(avail, w, plan_small, 250)
  check(res2.held["plaque"] == 30, "4 : besoin 30 < part 250 : seul le besoin est retenu : " .. tostring(res2.held["plaque"]))
  local res3 = Fa.reserve(avail, {}, plan_raw, 250)
  check(next(res3.held) == nil and res3.why and res3.why:find("aucun besoin", 1, true), "4 : aucun besoin : rien retenu, raison ecrite")
  local res4 = Fa.reserve(avail, w, plan_raw, nil, "parts absentes")
  check(next(res4.held) == nil and res4.why:find("part absente", 1, true), "4 : part absente : rien retenu, raison ecrite (" .. tostring(res4.why) .. ")")
  local res5 = Fa.reserve(avail, w, plan_raw, 0)
  check(next(res5.held) == nil, "4 : part nulle : rien retenu")
  local res6 = Fa.reserve(avail, w, nil, 250)
  check(next(res6.held) == nil and res6.why:find("plan du livre absent", 1, true), "4 : plan du livre absent : rien retenu (fermé)")
  local res7 = Fa.reserve({ plaque = 0 }, w, plan_raw, 250)
  check(next(res7.held) == nil, "4 : stock vide : rien a retenir")
  local before = copy(avail)
  Fa.reserve(avail, w, plan_raw, 250)
  check(avail.plaque == before.plaque and avail.cuivre == before.cuivre, "4 : la reserve ne modifie pas le stock de l'appelant")
  -- 5. prêt et retour
  local a = { plaque = 1000, cuivre = 80 }
  local held = { plaque = 250, cuivre = 20 }
  local taken = Fa.lend(a, held, false)
  check(a.plaque == 750 and a.cuivre == 60 and taken.plaque == 250 and taken.cuivre == 20, "5 : un projet qui n'est pas de la famille voit le stock moins la reserve")
  Fa.restore(a, taken)
  check(a.plaque == 1000 and a.cuivre == 80, "5 : la reserve est rendue apres le projet")
  local t2 = Fa.lend(a, held, true)
  check(a.plaque == 1000 and next(t2) == nil, "5 : un membre voit tout le stock (rien pris)")
  local low = { plaque = 100 }
  local t3 = Fa.lend(low, { plaque = 250 }, false)
  check(low.plaque == 0 and t3.plaque == 100, "5 : jamais plus que ce qui est au stock")
  Fa.restore(low, t3)
  check(low.plaque == 100, "5 : retour exact")
  -- 5 bis. la famille consomme : ce qu'elle a pris sort de la réserve (un projet servi après elle ne la voit pas deux fois)
  local resl = Fa.reserve(avail, w, plan_raw, 250)
  check(resl.left.plaque == resl.held.plaque and resl.left ~= resl.held, "5 : left est une copie de la reserve de depart")
  local av = { plaque = 1000, cuivre = 80 }
  local snap = Fa.snapshot(av, resl.left)
  check(snap.plaque == 1000 and snap.cuivre == 80 and snap.autre == nil, "5 : releve avant le membre : les seules matieres retenues")
  av.plaque = 960 -- le membre a consomme 40 plaques
  Fa.spend(resl.left, snap, av)
  check(resl.left.plaque == resl.held.plaque - 40 and resl.held.plaque == 92, "5 : 40 plaques consommees par la famille : la reserve baisse de 40, celle de depart reste (" .. tostring(resl.left.plaque) .. ")")
  av.plaque = 0 -- consommation au-dela de la reserve
  Fa.spend(resl.left, snap, av)
  check(resl.left.plaque == nil, "5 : consommation au-dela de la reserve : plus rien de retenu, jamais negatif")
  local av2 = { plaque = 1200 } -- le stock a monte (arrivee) : rien consomme
  local l2 = { plaque = 50 }
  Fa.spend(l2, { plaque = 1000 }, av2)
  check(l2.plaque == 50, "5 : un stock qui monte ne libere rien")
  -- 6. déterminisme, signature, ligne
  local r1, r2 = Fa.reserve(avail, w, plan_raw, 250), Fa.reserve(avail, w, plan_raw, 250)
  check(Fa.signature(r1) == Fa.signature(r2) and Fa.signature(r1) == "250|cuivre,plaque", "6 : signature deterministe, sans quantites : " .. Fa.signature(r1))
  local line = Fa.line("emerald", r1, 12.5)
  check(line:find("[FO-ARMEE] emerald", 1, true) == 1 and line:find("250 pour mille", 1, true) and line:find("plaque", 1, true) and line:find("equipement", 1, true),
    "6 : ligne [FO-ARMEE] : " .. line)
  check(Fa.line("e", res4, 1):find("part absente", 1, true), "6 : ligne d'une part absente")
end

local Fa0 = assert(load_fa())
battery(Fa0)

---------------------------------------------------------------------------------------------------
-- 2. Le cerveau
---------------------------------------------------------------------------------------------------
local T = require("shared.team.config")
local Book = require("shared.team.book")
local S = require("shared.team.scale")
local B = require("shared.ai3.buts")
local C = require("shared.ai3.cerveau")
local book = Book.new(dofile("tests/fixtures/recipes.lua"))

local function view(over)
  local v = {
    tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {}, outposts = {},
    pending = {}, sites = {}, smelters = 0, smelters_pending = 0, smelter_task = false, smelter_output = 0,
    smelter_fuel_low = false, smelter_coal = 0, turret_groups = {}, soldiers = 0, soldiers_max = 12, workers = 10,
    workers_max = 30, workers_idle = 10, threatened = false, open = {}, workers_wanted = 10, no_research = true,
    ladder = T.player_ladder, hq_turrets = T.defend_hq, defend_first = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function sig(plan)
  local out = {}
  for _, t in ipairs(plan.tasks) do out[#out + 1] = t.key .. "@" .. tostring(t.prio) .. ":" .. tostring(t.count) end
  local m = {}
  for _, x in ipairs(plan.missing) do m[#m + 1] = x[1] .. "x" .. x[2] end
  return table.concat(out, ";") .. "|" .. table.concat(m, ",") .. "|" .. tostring(plan.goal)
end
local function deep_ok(t, seen)
  seen = seen or {}
  if seen[t] then return true end
  seen[t] = true
  for k, v in pairs(t) do
    local tk, tv = type(k), type(v)
    if tk ~= "string" and tk ~= "number" then return false end
    if tv == "table" then
      if getmetatable(v) ~= nil or not deep_ok(v, seen) then return false end
    elseif tv ~= "string" and tv ~= "number" and tv ~= "boolean" then return false end
  end
  return true
end

-- Une faction : fer au coffre, aucune tourelle, des soldats a faire, une reserve de munitions a bâtir.
local function think(armee)
  local st = C.new_state(0)
  local ctx = { tick = 0, is_player = false, weights = B.weights({}, nil), reach = { ["iron-ore"] = 150, stone = 40, coal = 80 },
    armee = armee, at_war = true } -- en guerre : « boot » ouvre les buts de defense et d'armee (shared/ai3/buts.lua)
  local v = view({ stock = { ["iron-plate"] = 400, ["copper-plate"] = 100, coal = 300, stone = 200 }, soldiers_max = 12, soldiers = 0 })
  local plan = C.think(v, book, st, ctx)
  return plan, st
end

local base_plan = think(nil)
check(base_plan.ia3.armee == nil, "2 : sans ctx.armee, aucune reserve (la pensee d'avant)")
local same = think(nil)
check(sig(same) == sig(base_plan), "2 : sans ctx.armee, deterministe")
local fam_plan = think({ parts = { delta = 100, alpha = 150 } })
local fam = fam_plan.ia3.armee
check(fam ~= nil and fam.share == 250, "2 : avec parts 100 + 150 : part 250 pour mille (" .. tostring(fam and fam.share) .. ")")
check(fam and #fam.wants > 0, "2 : les buts militaires donnent des besoins (" .. tostring(fam and #fam.wants) .. ")")
local any_ch = {}
for _, x in ipairs(fam and fam.wants or {}) do any_ch[x.channel] = true end
check(any_ch.munitions or any_ch.equipement, "2 : au moins une voie (munitions ou equipement) est lue")
local held_iron = fam and fam.held and fam.held["iron-plate"]
check(held_iron ~= nil and held_iron > 0 and held_iron <= 100, "2 : des plaques sont retenues, au plus 250 pour mille de 400 = 100 : " .. tostring(held_iron))
check(deep_ok(fam_plan.ia3.armee), "2 : la reserve est serialisable (nombres, chaines, tables)")
local fam_plan2 = think({ parts = { delta = 100, alpha = 150 } })
check(sig(fam_plan2) == sig(fam_plan) and Fa0.signature(fam_plan2.ia3.armee) == Fa0.signature(fam), "2 : avec ctx.armee, deterministe")
-- Les buts militaires sont servis comme avant : memes taches militaires (armee, munitions) avec et sans la reserve.
local function military_sig(plan)
  local out = {}
  for _, t in ipairs(plan.tasks) do
    local k = tostring(t.key)
    if k:find("armee", 1, true) or k:find("munition", 1, true) or k:find("magazine", 1, true) or k:find("kit", 1, true) then
      out[#out + 1] = k .. ":" .. tostring(t.count)
    end
  end
  table.sort(out)
  return table.concat(out, ";")
end
check(military_sig(fam_plan) == military_sig(base_plan), "2 : taches militaires inchangees par la reserve : [" .. military_sig(fam_plan) .. "] contre [" .. military_sig(base_plan) .. "]")
check((fam_plan.train ~= nil) == (base_plan.train ~= nil), "2 : la formation des soldats est la meme avec et sans reserve")
-- Part absente : rien retenu, raison ecrite, la pensee est celle d'avant.
local none_plan = think({ parts = nil })
check(none_plan.ia3.armee and next(none_plan.ia3.armee.held) == nil and none_plan.ia3.armee.why:find("part absente", 1, true),
  "2 : sans parts lues, rien retenu et la raison est ecrite")
check(sig(none_plan) == sig(base_plan), "2 : sans parts lues, le plan est celui d'avant")
-- Votre equipe (armee tardive) : rien retenu.
do
  local st = C.new_state(0)
  local ctx = { tick = 0, is_player = true, weights = B.weights({}, nil), reach = { ["iron-ore"] = 150 }, armee = { parts = { delta = 100, alpha = 150 } } }
  local plan = C.think(view({ is_player = true, stock = { ["iron-plate"] = 400, ["copper-plate"] = 100 }, army_cap = 6, army_target = 6, soldiers = 0 }), book, st, ctx)
  local f = plan.ia3.armee
  check(f ~= nil and next(f.held) == nil, "2 : l'armee tardive de votre equipe ne reserve rien")
end

---------------------------------------------------------------------------------------------------
-- 3. Mutants
---------------------------------------------------------------------------------------------------
local MUTANTS = {
  { "l'armee tardive reserve aussi", 'and goal.late ~= true', "" },
  { "part sans plafond", "return math.min(Fa.SHARE_MAX, math.floor(d + a + Fa.EPS))", "return math.floor(d + a + Fa.EPS)" },
  { "part absente lue comme 0 (puis retenue de tout)", 'if d == nil or a == nil then return nil, "parts illisibles : delta ou alpha absent" end', "d, a = d or 1000, a or 1000" },
  { "reserve au-dela du stock", "local h = math.min(have, math.ceil(need - Fa.EPS), cap)", "local h = math.min(math.ceil(need - Fa.EPS), cap) + 1000" },
  { "reserve sans plafond de part", "local h = math.min(have, math.ceil(need - Fa.EPS), cap)", "local h = math.min(have, math.ceil(need - Fa.EPS))" },
  { "reserve sans le besoin", "local h = math.min(have, math.ceil(need - Fa.EPS), cap)", "local h = math.min(have, cap)" },
  { "plan du livre absent : reserve quand meme", 'if type(raw) ~= "table" then res.why = "plan du livre absent" return res end', "raw = raw or {}" },
  { "un membre emprunte aussi", "if member then return taken end", "" },
  { "reserve jamais rendue", "avail[k] = (avail[k] or 0) + taken[k]", "" },
  { "consommation de la famille jamais deduite", "if used > 0 then held[k] = math.max(0, held[k] - used) end", "" },
  { "reserve epuisee gardee a zero", "if held[k] <= 0 then held[k] = nil end", "" },
  { "left partage avec la reserve de depart", "for _, k in ipairs(sorted_keys(res.held)) do res.left[k] = res.held[k] end", "res.left = res.held" },
  { "munitions ignorees", 'if g.kind == "stock" and', 'if false and' },
  { "equipement ignore", 'elseif g.kind == "army" and kit_of then', "elseif false then" },
  { "famille sans la defense", "Fa.FAMILIES = { armee = true, defense = true }", "Fa.FAMILIES = { armee = true }" },
}
local killed = 0
quiet = true
local p0, f0 = passes, failures
for _, m in ipairs(MUTANTS) do
  local mod, err = load_fa({ m[2], m[3] })
  local dead = false
  if not mod then
    quiet = false
    check(false, "3 : mutant « " .. m[1] .. " » : " .. tostring(err))
    quiet = true
  else
    local fb = failures
    local ok, e = pcall(battery, mod)
    if not ok or failures > fb then dead = true end
    failures = fb -- les ECHEC d'un mutant ne comptent pas comme des echecs du banc
  end
  if dead then killed = killed + 1 else quiet = false; check(false, "3 : mutant survivant : " .. m[1]); quiet = true end
end
quiet = false
passes = p0 + 0 -- les controles d'un mutant ne gonflent pas le compte
check(killed == #MUTANTS, string.format("3 : mutants refuses %d / %d", killed, #MUTANTS))

print(string.format("[FAMILLE-ARMEE] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refuses sur %d)", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
