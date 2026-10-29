--[[
  Lot PILE-PRIORITE : banc HORS JEU de la pile de priorité (shared/ai3/pile.lua) et de son branchement au cerveau par besoins
  (shared/ai3/cerveau.lua, shared/ai3/buts.lua, shared/team/planner.lua out.raw_need). Lancement, depuis la racine du mod :
    lua5.2 tests/pile_test.lua

  Sections :
    1. règle pure : pile vide ; R1 suspend R3 (capital, capitalisation, recherche, foreuses, migration) sauf ce qui sert un
       cadre (focus) ; perte SANS objet -> fabrication R1 ; objet au stock -> gardé ; infrastructure -> pas de doublon ;
       manque de fer d'une tourelle (prio 90) -> sous-cadres produire plaque -> minerai (-> explorer sans source) ; place
       tenue par l'ennemi -> cadre « place » qui ne gèle rien, puis dépilé à l'abandon ; dépilement à la satisfaction ;
       AUCUNE horloge ; blocage (aucune voie) ; front exclu ; ordre interne « production d'abord » ; survivre ; pénurie ;
       déterminisme et état persistant ;
    2. moteur simulé (pensées successives du cerveau par besoins, stock qui évolue) : QG à 0 tourelle, 60 fer -> aucune
       amélioration, le fer de la protection hérite de sa priorité, l'extraction de fer GRANDIT (« usine, nouveau gisement »),
       puis les tourelles, puis l'amélioration ; une pièce perdue sans objet est fabriquée ;
    3. anti-échelle : shared/ai3/pile.lua ne nomme aucun objet du jeu ;
    4. mutants : chaque règle retirée (par substitution du texte de la règle) fait échouer au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local S = require("shared.team.scale")

local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)

local quiet = false
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end

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

local IRON, ORE, COPPER = T.outposts.iron.product, T.outposts.iron.resource, T.outposts.copper.product
local REPAIR_ITEM = "assembling-machine-1" -- fabricable à la main (fixture)

local function has_frame(st, key)
  for _, fr in ipairs(st.frames) do if fr.key == key then return fr end end
  return nil
end

---------------------------------------------------------------------------------------------------
-- La batterie (rejouée sous chaque mutant).
---------------------------------------------------------------------------------------------------
local function battery(Pi, C, B)
  local SRC = { [ORE] = true, [IRON] = true, [COPPER] = true, [T.outposts.copper.resource] = true }
  local INP = { [IRON] = ORE }
  local function sig(over)
    local s = { sources = SRC, inputs = INP, raw_need = {}, posts = {}, repair = {} }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
  end
  local hq_fer = { id = "hq", have = 0, want = 4, why = "fer", raw = { [IRON] = 40 } }

  section("1. Règle pure")
  -- a. Pile vide.
  local st = Pi.update(Pi.new(), sig(), 0)
  check(st.top == Pi.AMELIORER and not st.hold and #st.frames == 0, "pile vide : sommet améliorer, rien de retenu")
  check(Pi.allows(st, "capital") and Pi.allows(st, "foreuses"), "pile vide : améliorer permis")
  -- b. R1 suspend R3, sauf ce qui sert un cadre.
  st = Pi.update(Pi.new(), sig({ posts = { hq_fer }, raw_need = { [IRON] = { n = 40, prio = 90 } } }), 0)
  check(st.top == Pi.ADAPTER and st.hold, "QG sous son minimum : sommet s'adapter, améliorer retenu")
  local susp = true
  for _, fam in ipairs({ "capital", "capi", "recherche", "foreuses", "migration", "upgrade" }) do
    if Pi.allows(st, fam) then susp = false end
  end
  check(susp, "R1 suspend capital, capitalisation, recherche, foreuses, migration, upgrade")
  check(Pi.allows(st, "proteger") and Pi.allows(st, "reparer") and Pi.allows(st, "survivre"), "R1 laisse protéger et réparer")
  check(Pi.allows(st, "foreuses", IRON) and not Pi.allows(st, "foreuses", "x-autre"),
    "une amélioration qui SERT un cadre (son produit est dans focus) reste permise, pas les autres")
  -- c. Manque de fer d'une tourelle : la priorité 90 est gardée, sous-cadres produire plaque -> minerai.
  check(st.short[IRON] and st.short[IRON].prio == 90 and st.short[IRON].n == 40, "le manque garde la priorité 90 de la tourelle")
  check(has_frame(st, "produire:" .. IRON) ~= nil and has_frame(st, "produire:" .. ORE) ~= nil,
    "sous-cadres : produire la plaque, puis son minerai")
  local f_ore, f_plate = has_frame(st, "produire:" .. ORE), has_frame(st, "produire:" .. IRON)
  check(f_ore ~= nil and f_plate ~= nil and f_ore.parent == "produire:" .. IRON and f_plate.parent == "proteger:hq",
    "chaîne de parents : protéger le QG > plaque > minerai")
  check(f_plate ~= nil and f_plate.rank == Pi.ADAPTER, "un sous-cadre garde le rang de son parent (il n'est pas suspendu)")
  st = Pi.update(Pi.new(), sig({ posts = { hq_fer }, raw_need = { [IRON] = { n = 40, prio = 40 } } }), 0)
  check(st.short[IRON] == nil, "un manque de rang ordinaire (prio 40 < Pi.INJECT_PRIO) n'est pas repris")
  -- d. Sans source : exploration ; sans aucune voie : bloqué, rien n'est gelé.
  st = Pi.update(Pi.new(), sig({ sources = {}, posts = { hq_fer }, raw_need = { [IRON] = { n = 40, prio = 90 } } }), 0)
  check(has_frame(st, "explorer:" .. ORE) ~= nil, "aucune source connue : sous-cadre explorer le minerai")
  check(st.blocked and not st.hold, "aucune voie (matière sans source) : cadre BLOQUÉ, l'amélioration n'est pas gelée")
  st = Pi.update(Pi.new(), sig({ posts = { { id = "hq", have = 0, want = 4, why = "recette" } } }), 0)
  check(st.blocked and not st.hold, "tourelle sans recette : bloqué, rien n'est gelé")
  -- e. Perte sans objet -> fabrication R1 ; objet au stock -> gardé ; infrastructure -> pas de doublon.
  local lost = { key = "k1", item = REPAIR_ITEM, value = 5, prio = 75, have = 0, craftable = true }
  st = Pi.update(Pi.new(), sig({ repair = { lost } }), 0)
  check(st.hold and has_frame(st, "reparer:" .. REPAIR_ITEM) ~= nil, "perte SANS objet au stock : cadre réparer, amélioration retenue")
  check(#st.crafts == 1 and st.crafts[1][1] == REPAIR_ITEM and st.crafts[1][2] == 1 and st.crafts[1][3] == 75,
    "perte sans objet : l'objet devient une fabrication de rang R1 (priorité de la pièce)")
  st = Pi.update(Pi.new(), sig({ repair = { { key = "k1", item = REPAIR_ITEM, value = 5, prio = 75, have = 2, craftable = true } } }), 0)
  check(#st.crafts == 0 and #st.reserve == 1 and st.reserve[1][2] == 1, "objet au stock : gardé pour la pièce, pas fabriqué")
  st = Pi.update(Pi.new(), sig({ repair = { { key = "k1", item = REPAIR_ITEM, value = 14, prio = 84, have = 0, craftable = true, infra = true } } }), 0)
  check(#st.crafts == 0 and st.hold, "infrastructure électrique : retenue, mais pas de 2e fabrication (Rc.demand la fait)")
  st = Pi.update(Pi.new(), sig({ repair = { { key = "k1", item = REPAIR_ITEM, value = 5, prio = 75, have = 0, craftable = false } } }), 0)
  check(st.blocked and not st.hold, "pièce ni au stock ni fabricable : bloqué, rien n'est gelé")
  -- e bis. Projet du plan directeur rouvert (relecture) : retient s'il a une voie, bloqué sinon.
  st = Pi.update(Pi.new(), sig({ plan_reopened = true }), 0)
  check(st.hold and has_frame(st, "reparer:plan") ~= nil, "projet rouvert qui doit encore prendre des objets : réparer retient")
  st = Pi.update(Pi.new(), sig({ plan_reopened = true, plan_path = false }), 0)
  check(st.blocked and not st.hold, "projet rouvert dont un objet n'est ni au coffre ni fabricable : bloqué, rien n'est gelé")
  -- f. Place tenue par l'ennemi : sous-but « protéger ou nettoyer », pas de gel ; dépilée à l'abandon.
  local pst = Pi.new()
  Pi.update(pst, sig({ repair = { { key = "k9", item = REPAIR_ITEM, value = 5, prio = 75, have = 0, craftable = true, enemy = true } } }), 0)
  check(has_frame(pst, "place:k9") ~= nil and not pst.hold and pst.top == Pi.AMELIORER,
    "place tenue par l'ennemi : cadre « place », l'amélioration n'est PAS gelée")
  Pi.update(pst, sig(), 600) -- la pièce est abandonnée (compteur de reports) : le runtime ne la donne plus
  check(has_frame(pst, "place:k9") == nil and (pst.closed_n or 0) >= 1, "pièce abandonnée : la place est dépilée")
  st = Pi.update(Pi.new(), sig({ repair = { { key = "k9", item = REPAIR_ITEM, value = 5, prio = 75, have = 0, craftable = true, enemy = true, claimed = true } } }), 0)
  check(st.hold, "pièce prise par un PNJ (même près de l'ennemi) : on la refait, l'amélioration attend")
  -- g. Dépilement à la satisfaction ; aucune horloge.
  local dst = Pi.new()
  Pi.update(dst, sig({ posts = { hq_fer }, raw_need = { [IRON] = { n = 40, prio = 90 } } }), 0)
  Pi.update(dst, sig({ posts = { hq_fer }, raw_need = { [IRON] = { n = 40, prio = 90 } } }), 10 * 60 * 3600)
  check(dst.hold and dst.top == Pi.ADAPTER, "AUCUNE horloge : 10 h plus tard, le cadre non satisfait retient toujours")
  Pi.update(dst, sig({ posts = { { id = "hq", have = 4, want = 4, why = nil } } }), 10 * 60 * 3600 + 300)
  check(not dst.hold and dst.top == Pi.AMELIORER and dst.closed_n >= 3 and dst.changed,
    "QG pourvu : cadres dépilés (protéger, plaque, minerai), sommet améliorer, changement noté")
  -- h. Front exclu ; R0 ; pénurie.
  st = Pi.update(Pi.new(), sig({ posts = { { id = "front", have = 0, want = 6, why = "fer", raw = { [IRON] = 80 } } } }), 0)
  check(not st.hold and #st.frames == 0, "la croissance du front n'ouvre pas de cadre (sinon la pile ne se viderait jamais)")
  -- Intégration 0.6.19 : le poste facultatif de l'îlot (ILOTS-MURS, « ressources d'abord ») n'ouvre pas de cadre non plus.
  st = Pi.update(Pi.new(), sig({ posts = { { id = "ilot", have = 0, want = 2, why = "ressources" } } }), 0)
  check(not st.hold and #st.frames == 0, "l'îlot isolé sans tourelles (poste facultatif) ne retient pas l'amélioration")
  st = Pi.update(Pi.new(), sig({ survive = "effectif" }), 0)
  check(st.top == Pi.SURVIVRE and st.hold, "sous l'effectif de départ : sommet survivre")
  -- Relecture : R0 n'est jamais « bloqué » ; sans recrue possible (plafond global d'agents), il gelait l'amélioration à vie.
  local sg = Pi.signals({ workers = 3, recover_floor = 8 }, {}, nil, { cap = {} }, nil)
  check(sg.survive == "effectif", "signaux : sous l'effectif de départ, recrue possible : R0 survivre")
  sg = Pi.signals({ workers = 3, recover_floor = 8, recruit_blocked = true }, {}, nil, { cap = {} }, nil)
  st = Pi.update(Pi.new(), sg, 0)
  check(sg.survive == nil and not st.hold and st.top == Pi.AMELIORER,
    "signaux : plafond global d'agents atteint (aucune recrue possible) : pas de R0, l'amélioration n'est pas gelée à vie")
  sg = Pi.signals({ workers = 3, emergency = { floor = 8 }, recruit_blocked = true, hq_threat = true }, {}, nil, { cap = {} }, nil)
  check(sg.survive == "qg", "signaux : QG menacé retient même sans recrue possible")
  st = Pi.update(Pi.new(), sig({ penurie = true }), 0)
  check(st.top == Pi.PRODUIRE and st.hold and Pi.allows(st, "extraction") and not Pi.allows(st, "capital"),
    "mode pénurie : sommet produire, extraction permise, capital suspendu")
  -- i. Ordre interne de R1 (Pr.decide) : production d'abord -> pièces et matières devant la protection.
  local both = sig({ posts = { hq_fer }, repair = { lost }, raw_need = { [IRON] = { n = 40, prio = 90 } } })
  st = Pi.update(Pi.new(), both, 0)
  check(st.frames[1].key == "proteger:hq", "défense et production payées : la protection d'abord")
  both.production_first = true
  st = Pi.update(Pi.new(), both, 0)
  check(st.frames[1].kind ~= "proteger" and has_frame(st, "proteger:hq") ~= nil,
    "production d'abord : la pièce et la matière passent devant la protection (« la défense viendra tout juste après »)")
  -- j. Déterminisme et état.
  local a = Pi.update(Pi.new(), both, 7)
  local b2 = Pi.update(Pi.new(), both, 7)
  check(Pi.describe(a) == Pi.describe(b2), "déterminisme : mêmes entrées, même pile")
  check(deep_ok(a), "état persistant : nombres, chaînes, booléens et tables seulement (global)")

  section("2. Moteur simulé : le cerveau par besoins sous la pile")
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
  local function op(id, kind, over)
    local o = { id = id, kind = kind, drills = T.outposts[kind].drills, full = false, turrets = 8, coal_needed = 0, fuel_low = false,
      output = 0, idle_ticks = 0, has_task = false, has_fortify = false }
    for k, x in pairs(over or {}) do o[k] = x end
    return o
  end
  local outs = { op(1, "iron"), op(2, "coal"), op(3, "copper") }
  local stock = { [IRON] = 60, [COPPER] = 200, [T.turret_ammo] = 100, [T.fuel] = 400, stone = 300 }
  local upgrade = { key = "upgrade:essai", family = "capital", kind = "stock", item = T.turret_ammo, n = 1, value = 95 }
  local function ctx(tick, extra)
    local c = { tick = tick, is_player = true, weights = B.weights({}, nil), reach = { [ORE] = 60, [T.fuel] = 60 },
      capital = upgrade }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
  end
  local function has_project(stc, key)
    for _, p in ipairs(stc.projects or {}) do if p.key == key then return true end end
    return false
  end
  local sst = C.new_state(0)
  sst.targets = { iron = 1, coal = 1, copper = 1, stone = 0 }
  sst.iron2_set = true
  local v = view({ outposts = outs, stock = stock })
  local plan = C.think(v, book, sst, ctx(0))
  check(plan.ia3.pile and plan.ia3.pile.hold and sst.pile.top == Pi.ADAPTER, "QG à 0 tourelle, 60 fer : la pile retient (sommet s'adapter)")
  check(not has_project(sst, "upgrade:essai"), "aucune amélioration : le but capital n'ouvre pas de projet (ne réserve pas sa matière)")
  check((sst.short[IRON] or 0) > 0, "le fer des tourelles entre dans les manques du cerveau (" .. tostring(sst.short[IRON]) .. ")")
  local base_mine, ia3_mine = 0, 0
  for _, t in ipairs(plan.tasks) do
    if t.kind == "mine" and t.resource == ORE then
      if t.key == "mine:" .. ORE then base_mine = base_mine + 1 else ia3_mine = ia3_mine + 1 end
    end
  end
  check(ia3_mine >= 1 and base_mine == 0, "minage du minerai par le cerveau (prio héritée), plus le minage d'appoint à 25 en double ("
    .. ia3_mine .. " / " .. base_mine .. ")")
  local tg0 = sst.targets.iron
  for i = 1, B.GROW_THINKS + 1 do plan = C.think(v, book, sst, ctx(i * 300)) end
  check(sst.targets.iron > tg0, "le manque durable de la protection fait GRANDIR l'extraction de fer (" .. tg0 .. " -> " .. sst.targets.iron .. ")")
  check(has_project(sst, "extraction:iron"), "projet d'extraction de fer ouvert (usine, puis nouveau gisement)")
  check(not has_project(sst, "upgrade:essai"), "toujours aucune amélioration pendant que le QG manque de tourelles")
  -- Le fer arrive : les tourelles d'abord, puis l'amélioration.
  local rich = {}
  for k, n in pairs(stock) do rich[k] = n end
  rich[IRON] = 900
  local v2 = view({ outposts = outs, stock = rich })
  plan = C.think(v2, book, sst, ctx(3000))
  local fort = false
  for _, t in ipairs(plan.tasks) do
    if (t.kind == "fortify" and t.outpost == "hq") or (t.kind == "craft" and t.item == "gun-turret" and t.tag == "defense") then fort = true end
  end
  check(fort and sst.pile.hold and not has_project(sst, "upgrade:essai"),
    "le fer suit : les tourelles du QG d'abord (fabriquées ou posées), amélioration encore retenue")
  plan = C.think(view({ outposts = outs, stock = rich, hq_turrets = T.defend_hq }), book, sst, ctx(3300))
  check(not sst.pile.hold and has_project(sst, "upgrade:essai"), "QG pourvu : la pile se vide, l'amélioration passe")
  -- Réparer : une pièce perdue SANS objet au stock est fabriquée avant les projets.
  local rst = C.new_state(0)
  rst.targets = { iron = 1, coal = 1, copper = 1, stone = 0 }
  rst.iron2_set = true
  plan = C.think(view({ outposts = outs, stock = rich, hq_turrets = T.defend_hq }), book, rst,
    ctx(0, { pile = { repair = { { key = "k1", item = REPAIR_ITEM, value = 5, prio = 75, have = 0, craftable = true } } } }))
  local craft = nil
  for _, t in ipairs(plan.tasks) do if t.kind == "craft" and t.item == REPAIR_ITEM then craft = t end end
  check(craft ~= nil and craft.prio == 75, "perte sans objet : fabriquée par le cerveau à la priorité de la pièce")
  check(rst.pile.hold and not has_project(rst, "upgrade:essai"), "perte sans objet : l'amélioration attend (audit A5)")
end

---------------------------------------------------------------------------------------------------
-- Chargement (normal ou muté).
---------------------------------------------------------------------------------------------------
local MODS = { "shared.ai3.pile", "shared.ai3.buts", "shared.ai3.cerveau" }
local function fresh(mut)
  for _, m in ipairs(MODS) do package.loaded[m] = nil end
  if mut then
    local fh = assert(io.open(mut.file, "rb"))
    local src = fh:read("*a")
    fh:close()
    local i, j = src:find(mut.from, 1, true)
    assert(i, "mutant introuvable : " .. mut.name)
    assert(not src:find(mut.from, j + 1, true), "mutant ambigu : " .. mut.name)
    src = src:sub(1, i - 1) .. mut.to .. src:sub(j + 1)
    package.loaded[mut.mod] = assert(load(src, "@" .. mut.file))()
  end
  return require("shared.ai3.pile"), require("shared.ai3.cerveau"), require("shared.ai3.buts")
end

battery(fresh(nil))

section("3. Anti-échelle : shared/ai3/pile.lua ne nomme aucun objet du jeu")
do
  local fh = assert(io.open("shared/ai3/pile.lua", "rb"))
  local src = fh:read("*a")
  fh:close()
  local code = src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
  local names = {}
  for name, r in pairs(recipes) do
    names[name] = true
    for _, p in ipairs(r.products) do names[p.name] = true end
    for _, ing in ipairs(r.ingredients) do names[ing.name] = true end
  end
  local hits = {}
  for s in code:gmatch('"([^"\n]*)"') do if names[s] then hits[#hits + 1] = s end end
  local bare = code:gsub('"[^"\n]*"', '""')
  for w in bare:gmatch("[%a_][%w_]*") do if names[w] then hits[#hits + 1] = w end end
  table.sort(hits)
  check(#hits == 0, "aucun nom d'objet dans pile.lua (" .. table.concat(hits, ", ") .. ")")
end

local base_pass, base_fail = passes, failures

section("4. Mutants")
local MUTANTS = {
  { name = "la pile ne retient jamais", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "local hold = top < Pi.AMELIORER and not blocked", to = "local hold = false" },
  { name = "R3 jamais suspendu (allows toujours vrai)", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "if rank <= (st.top or Pi.AMELIORER) then return true end", to = "if true then return true end" },
  { name = "pas d'exception focus", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "if item and st.focus and st.focus[item] then return true end", to = "" },
  { name = "perte sans objet non fabriquée", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "crafts[#crafts + 1] = { item, open_n - keep, a.prio }", to = "" },
  { name = "objet au stock non gardé", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "if keep > 0 then reserve[#reserve + 1] = { item, keep } end", to = "" },
  { name = "manques R0/R1 non repris", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "Pi.INJECT_PRIO = 60", to = "Pi.INJECT_PRIO = 999" },
  { name = "place ennemie qui gèle", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "exec = false,\n      nohold = true,", to = "exec = false," },
  { name = "pas de blocage (siège sans issue qui gèle)", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "    blocked = true\n", to = "    blocked = false\n" },
  { name = "front qui ouvre un cadre", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "Pi.GROWTH_POSTS = { front = true }", to = "Pi.GROWTH_POSTS = {}" },
  { name = "îlot facultatif qui ouvre un cadre", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "Pi.OPTIONAL_POSTS = { ilot = true }", to = "Pi.OPTIONAL_POSTS = {}" },
  { name = "ordre interne ignoré", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "local pf = sig.production_first and true or false", to = "local pf = false" },
  { name = "pas de sous-cadre minerai", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "produce(ore, n, depth + 1, \"produire:\" .. item)", to = "" },
  { name = "pas d'exploration", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "elseif not src and depth + 1 <= Pi.DEPTH_MAX then", to = "elseif false then" },
  { name = "une horloge ferme la pile", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "local hold = top < Pi.AMELIORER and not blocked", to = "local hold = top < Pi.AMELIORER and not blocked and tick < 20 * 3600" },
  { name = "R0 sans recrue possible (gel à vie)", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "(view.workers or 0) < floor and not view.recruit_blocked then", to = "(view.workers or 0) < floor then" },
  { name = "projet rouvert sans voie qui gèle", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "exec = sig.plan_path ~= false,", to = "exec = true," },
  { name = "croissance sans le seuil de la pile", mod = "shared.ai3.buts", file = "shared/ai3/buts.lua",
    from = "local grow_short = (s.focus and s.focus[product]) and 1 or B.GROW_SHORT", to = "local grow_short = B.GROW_SHORT" },
  { name = "capital non suspendu au cerveau", mod = "shared.ai3.cerveau", file = "shared/ai3/cerveau.lua",
    from = "if ctx.capital and Pi.allows(pile, \"capital\") then", to = "if ctx.capital then" },
  { name = "manques non injectés au cerveau", mod = "shared.ai3.cerveau", file = "shared/ai3/cerveau.lua",
    from = "for _, k in ipairs(sorted_keys(pile.short)) do P.short_raw(E, pile_proj, k, pile.short[k].n, pile.short[k].prio) end", to = "" },
  { name = "fabrications de la pile non émises", mod = "shared.ai3.cerveau", file = "shared/ai3/cerveau.lua",
    from = "for _, it in ipairs(pile.crafts or {}) do P.want(E, repair_proj, { { it[1], it[2] } }, it[3], false, \"pile\") end", to = "" },
  { name = "minage d'appoint en double", mod = "shared.ai3.cerveau", file = "shared/ai3/cerveau.lua",
    from = "and t.key == \"mine:\" .. t.resource) or false", to = "and false) or false" },
}
local killed = 0
quiet = true
for _, m in ipairs(MUTANTS) do
  local f0 = failures
  local ok, err = pcall(function() battery(fresh(m)) end)
  local dead = (not ok) or failures > f0
  if dead then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. m.name) end
  if not ok then print("  (mutant « " .. m.name .. " » : erreur " .. tostring(err) .. ")") end
end
quiet = false
fresh(nil)
passes, failures = base_pass, base_fail
check(killed == #MUTANTS, "mutants refusés : " .. killed .. " sur " .. #MUTANTS)
print(string.format("[PILE] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
