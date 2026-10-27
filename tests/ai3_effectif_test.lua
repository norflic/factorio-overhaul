--[[
  IA3-d « ils ne scalent pas » : test hors jeu de la règle d'effectif des factions (shared/ai3/effectif.lua ;
  docs/IA_ATTENDUS.md ligne A7 ; docs/IA3_CERVEAU.md §3.6).

  Ce qu'il prouve :
    1. une faction RECRUTE quand du travail utile attend depuis au moins 2 min au-delà de ses bras libres et que la recrue
       se paie ; elle ne recrute PAS quand ses PNJ sont inactifs (bras libres ≥ travail qui attend) ;
    2. ce qui n'est pas du « travail qui attend » : fond, garde, conception, équipement d'une recrue, appoint (valeur < 35),
       travail de moins de 2 min, travail sans matière libre ;
    3. le coût : stock libre moins ce que le travail en attente et l'objectif réservent, plus une marge (un prudent garde
       plus) ; le rythme (une ambitieuse grandit plus vite) ;
    4. l'ordre des raisons (plafond, garde, plancher, sans frein, menace…) et la tolérance de fo-recruit-idle-max ;
    5. une équipe SIMULÉE (8 PNJ au départ, travail qui arrive) grandit sous la charge, reste à 8 sans charge, ne dépasse
       jamais le plafond, ne recrute jamais avec un PNJ libre ; la même suite de pensées donne la même suite de décisions ;
    6. MUTANTS : chaque mutant du module (une règle retirée ou faussée) est refusé par la suite (au moins un ECHEC).

  Usage : lua5.2 tests/ai3_effectif_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path

local SRC_PATH = "shared/ai3/effectif.lua"

local function read_src()
  local fh = assert(io.open(SRC_PATH, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end

local function load_module(src)
  local chunk, err = load(src, "=effectif", "t")
  if not chunk then return nil, err end
  local ok, mod = pcall(chunk)
  if not ok then return nil, mod end
  return mod
end

local MIN = 3600

--- Situation de base : 8 PNJ, plafond 30, départ 8, tous occupés, du fer en masse.
local function base(over)
  local s = { n = 8, cap = 30, floor = 8, blocked = false, limit = 0, threatened = false, idle = 0, fond = 0, tasks = {},
    cost = { ["iron-plate"] = 63, ["copper-plate"] = 5 }, left = { ["iron-plate"] = 500, ["copper-plate"] = 200 },
    traits = { ambition = 1000, prudence = 1000 } }
  for k, v in pairs(over or {}) do s[k] = v end
  return s
end

local function task(kind, prio, age, extra)
  local t = { kind = kind, prio = prio, created = 100000 - age, prenable = true }
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end

local NOW = 100000

---------------------------------------------------------------------------------------------------
-- Suite (rend pass, fail, messages) : jouée sur le vrai module, puis sur chaque mutant.
---------------------------------------------------------------------------------------------------
local function suite(E)
  local pass, fail, msgs = 0, 0, {}
  local function check(cond, msg)
    if cond then pass = pass + 1 else fail = fail + 1; msgs[#msgs + 1] = msg end
  end
  local function decide(s, st, tick) return E.decide(s, st or {}, tick or NOW) end
  local ok, err = pcall(function()
    local W2 = 2 * MIN
    -- 1. Recrue et inactifs.
    local d = decide(base({ tasks = { task("craft", 50, W2 + 60), task("build", 80, W2 + 600) } }))
    check(d.recruit == true and d.reason == "recrue", "2 tâches en attente depuis plus de 2 min, personne de libre : recrue (" .. tostring(d.reason) .. ")")
    check(d.waiting == 2 and d.short == 2, "travail en attente compté : 2, manque de bras 2 (" .. d.waiting .. ", " .. d.short .. ")")
    check(d.value == 80 and d.oldest == W2 + 600, "prix fictif = meilleure valeur en attente (80), plus ancienne attente (" .. d.value .. ")")
    d = decide(base({ idle = 2, tasks = { task("craft", 50, W2 + 60), task("build", 80, W2 + 600) } }))
    check(d.recruit == false and d.reason == "inactifs", "2 PNJ inactifs pour 2 tâches : aucune recrue (" .. tostring(d.reason) .. ")")
    d = decide(base({ idle = 1, tasks = { task("craft", 50, W2 + 60), task("build", 80, W2 + 600) } }))
    check(d.recruit == true and d.short == 1, "1 PNJ inactif pour 2 tâches qui attendent : 1 bras manque, recrue")
    d = decide(base({ fond = 2, tasks = { task("craft", 50, W2 + 60), task("build", 80, W2 + 600) } }))
    check(d.recruit == false and d.reason == "inactifs", "2 PNJ au travail de fond : disponibles, aucune recrue")
    d = decide(base({ idle = 3, tasks = {} }))
    check(d.recruit == false and d.reason == "inactifs", "PNJ inactifs sans travail : raison inactifs")
    d = decide(base({ tasks = {} }))
    check(d.recruit == false and d.reason == "pas_de_travail", "tout le monde occupé, rien n'attend : aucune recrue")
    -- 2. Ce qui ne compte pas.
    d = decide(base({ tasks = { task("craft", 50, W2 - 1) } }))
    check(d.recruit == false and d.reason == "travail_recent", "travail de moins de 2 min : aucune recrue (" .. tostring(d.reason) .. ")")
    d = decide(base({ tasks = { task("craft", 50, W2) } }))
    check(d.recruit == true, "travail d'exactement 2 min : compté")
    d = decide(base({ tasks = { task("craft", 50, W2 + 10, { prenable = false }) } }))
    check(d.recruit == false and d.reason == "matiere", "travail sans matière libre : la matière manque, pas les bras")
    d = decide(base({ tasks = { task("mine", 50, W2 + 10, { fond = true }) } }))
    check(d.recruit == false and d.waiting == 0, "travail de fond : jamais une raison de recruter")
    d = decide(base({ tasks = { task("garrison", 96, W2 + 10) } }))
    check(d.recruit == false and d.waiting == 0, "garde : pas du travail qui attend une recrue")
    d = decide(base({ tasks = { task("claim_site", 80, W2 + 10), task("route", 80, W2 + 10) } }))
    check(d.recruit == false and d.waiting == 0, "conception (généraliste) : pas pour une recrue")
    d = decide(base({ tasks = { task("craft", 55, W2 + 10, { tag = "ouvrier" }) } }))
    check(d.recruit == false and d.waiting == 0, "équipement d'une recrue : ne justifie pas une autre recrue")
    d = decide(base({ tasks = { task("mine", 30, W2 + 10) } }))
    check(d.recruit == false and d.waiting == 0 and d.low == 1, "appoint (valeur 30) : trop peu utile pour une recrue")
    d = decide(base({ tasks = { task("mine", 35, W2 + 10) } }))
    check(d.recruit == true, "valeur 35 : assez utile")
    d = decide(base({ tasks = { task("craft", 50, W2 + 10, { worker = 7 }) } }))
    check(d.recruit == false and d.waiting == 0, "tâche prise : pas en attente")
    -- 3. Coût, marge, rythme.
    d = decide(base({ tasks = { task("craft", 50, W2 + 10) }, left = { ["iron-plate"] = 112, ["copper-plate"] = 10 } }))
    check(d.recruit == false and d.reason == "cout", "fer libre 112 < coût 63 + marge 50 : aucune recrue (" .. tostring(d.reason) .. ")")
    d = decide(base({ tasks = { task("craft", 50, W2 + 10) }, left = { ["iron-plate"] = 113, ["copper-plate"] = 10 } }))
    check(d.recruit == true, "fer libre 113 = coût + marge : recrue")
    d = decide(base({ tasks = { task("craft", 50, W2 + 10) }, left = { ["iron-plate"] = 500, ["copper-plate"] = 4 } }))
    check(d.recruit == false and d.reason == "cout", "cuivre libre 4 < 5 : aucune recrue")
    d = decide(base({ tasks = { task("craft", 50, W2 + 10) }, left = { ["iron-plate"] = -40, ["copper-plate"] = 10 } }))
    check(d.recruit == false and d.reason == "cout", "objectif en manque de fer (libre négatif) : aucune recrue")
    local prudent = { ambition = 1000, prudence = 1500 }
    local hardy = { ambition = 1000, prudence = 600 }
    check(E.margin(prudent) > E.margin({}) and E.margin(hardy) < E.margin({}), "marge : prudent > neutre > audacieux")
    d = decide(base({ tasks = { task("craft", 50, W2 + 10) }, left = { ["iron-plate"] = 120, ["copper-plate"] = 10 }, traits = prudent }))
    check(d.recruit == false and d.reason == "cout", "prudent : même fer (120), il garde sa marge et ne recrute pas")
    d = decide(base({ tasks = { task("craft", 50, W2 + 10) }, left = { ["iron-plate"] = 120, ["copper-plate"] = 10 }, traits = hardy }))
    check(d.recruit == true, "audacieux : même fer (120), recrue")
    local amb = { ambition = 1875, prudence = 1000 }
    local slow = { ambition = 750, prudence = 1000 }
    check(E.period(amb) < E.period({}) and E.period(slow) > E.period({}), "période : ambitieuse < neutre < peu ambitieuse")
    check(E.period({ ambition = 100000 }) == E.PERIOD_MIN and E.period({ ambition = 1 }) == E.PERIOD_MAX, "période bornée")
    local st = {}
    E.grown(st, NOW - E.period({}) + 1)
    d = decide(base({ tasks = { task("craft", 50, W2 + 10) } }), st)
    check(d.recruit == false and d.reason == "rythme" and d.wait_left == 1, "recrue de croissance il y a moins d'une période : attendre (" .. tostring(d.reason) .. ")")
    d = decide(base({ tasks = { task("craft", 50, W2 + 10) }, traits = amb }), st)
    check(d.recruit == true, "même attente, faction ambitieuse : sa période est passée, recrue")
    E.grown(st, NOW - E.period({}))
    d = decide(base({ tasks = { task("craft", 50, W2 + 10) } }), st)
    check(d.recruit == true and st.grown == 2, "une période après : recrue ; recrues de croissance comptées")
    -- 4. Ordre des raisons, tolérance.
    local busy = { task("craft", 50, W2 + 10), task("craft", 50, W2 + 20) }
    d = decide(base({ n = 30, tasks = busy }))
    check(d.reason == "plafond" and not d.recruit, "plafond atteint : aucune recrue")
    d = decide(base({ blocked = true, tasks = busy }))
    check(d.reason == "garde" and not d.recruit, "garde de performance : aucune recrue")
    d = decide(base({ n = 5, idle = 4, tasks = {} }))
    check(d.reason == "plancher" and d.recruit, "sous l'effectif de départ : pas de frein (la survie décide)")
    d = decide(base({ limit = 60, idle = 6, tasks = {} }))
    check(d.reason == "sans_frein" and d.recruit, "fo-recruit-idle-max = 60 : aucun frein (sens d'IA1-a, protocole 30 contre 10)")
    d = decide(base({ threatened = true, tasks = busy }))
    check(d.reason == "menace" and not d.recruit, "QG menacé : pas de croissance")
    d = decide(base({ n = 30, blocked = true, tasks = busy }))
    check(d.reason == "plafond", "plafond examiné avant la garde")
    d = decide(base({ limit = 1, idle = 1, tasks = { task("craft", 50, W2 + 10) } }))
    check(d.recruit == true, "fo-recruit-idle-max = 1 : 1 PNJ inactif toléré")
    d = decide(base({ limit = 1, idle = 2, tasks = { task("craft", 50, W2 + 10) } }))
    check(d.recruit == false and d.reason == "inactifs", "fo-recruit-idle-max = 1 : 2 inactifs, 1 libre pour 1 tâche : aucune recrue")
    -- Indépendance de l'ordre des tâches et déterminisme.
    local a = { task("craft", 50, W2 + 10), task("build", 80, W2 + 600), task("mine", 30, W2), task("craft", 50, 10) }
    local b = { a[4], a[3], a[2], a[1] }
    local da, db = decide(base({ tasks = a })), decide(base({ tasks = b }))
    check(da.reason == db.reason and da.waiting == db.waiting and da.value == db.value and da.oldest == db.oldest
      and da.young == db.young and da.low == db.low, "ordre des tâches sans effet sur la décision")
    -- Comptes de la minute (ordre fixe des raisons).
    local cst = {}
    E.count(cst, { reason = "rythme" })
    E.count(cst, { reason = "inactifs" })
    E.count(cst, { reason = "inactifs" })
    local sum = E.minute_summary(cst)
    check(sum.reasons == "inactifs:2 rythme:1" and sum.top == "inactifs" and sum.thinks == 3, "résumé de la minute : " .. sum.reasons)
    check(cst.thinks == 0 and next(cst.why) == nil, "résumé : comptes remis à zéro")
    check(cst.last_d and cst.last_d.reason == "inactifs", "dernière décision gardée (fenêtre)")
    -- 5. Équipe simulée (pensée toutes les 300 ticks ; une tâche dure 2 min de PNJ ; recrue disponible à la pensée
    -- suivante ; fer : revenu de 40 par minute et par PNJ, coût 55 + effectif).
    local function simulate(rate_per_min, minutes, traits)
      local s_st, team = {}, { n = 8, busy = {}, queue = {}, iron = 400, next_id = 1 }
      local hist, idle_recruits, over_cap, decisions = {}, 0, false, {}
      for tick = 300, minutes * MIN, 300 do
        -- Fin des tâches.
        local still = {}
        for _, b in ipairs(team.busy) do if b > tick then still[#still + 1] = b end end
        team.busy = still
        -- Arrivées de travail (déterministes : rate tâches par minute, réparties).
        team.acc = (team.acc or 0) + rate_per_min * 300
        while team.acc >= MIN do
          team.acc = team.acc - MIN
          team.queue[#team.queue + 1] = task("craft", 60, 0, { created = tick })
        end
        -- Prises : un PNJ libre prend la plus ancienne tâche.
        while #team.busy < team.n and #team.queue > 0 do
          table.remove(team.queue, 1)
          team.busy[#team.busy + 1] = tick + 2 * MIN
        end
        team.iron = team.iron + 40 * team.n * 300 / MIN
        local idle = team.n - #team.busy
        local d = E.decide({ n = team.n, cap = 30, floor = 8, limit = 0, idle = idle, fond = 0, tasks = team.queue,
          cost = { ["iron-plate"] = 55 + team.n }, left = { ["iron-plate"] = team.iron, ["copper-plate"] = 100 },
          traits = traits or {} }, s_st, tick)
        decisions[#decisions + 1] = d.reason
        if d.recruit and d.reason == "recrue" then
          if idle > 0 then idle_recruits = idle_recruits + 1 end
          team.iron = team.iron - (55 + team.n)
          team.n = team.n + 1
          E.grown(s_st, tick)
        end
        if team.n > 30 then over_cap = true end
        if tick % MIN == 0 then hist[#hist + 1] = team.n end
      end
      return team.n, hist, idle_recruits, over_cap, table.concat(decisions, ",")
    end
    -- Charge : 6 tâches de 2 min par minute = 12 PNJ de travail ; l'équipe de 8 doit grandir.
    local n_hi, hist_hi, idle_hi, over_hi, seq1 = simulate(6, 30)
    check(n_hi >= 12 and n_hi <= 16, "sous une charge de 12 PNJ, l'équipe de 8 grandit à 12 à 16 (" .. n_hi .. ")")
    local mono = true
    for i = 2, #hist_hi do if hist_hi[i] < hist_hi[i - 1] then mono = false end end
    check(mono and hist_hi[#hist_hi] > hist_hi[1], "effectif qui monte, minute par minute")
    check(idle_hi == 0 and not over_hi, "jamais de recrue avec un PNJ libre, jamais au-delà du plafond")
    local _, _, _, _, seq2 = simulate(6, 30)
    check(seq1 == seq2, "même suite de pensées : même suite de décisions")
    -- Sans charge (2 tâches par minute = 4 PNJ de travail) : l'équipe reste à 8.
    local n_lo = simulate(2, 30)
    check(n_lo == 8, "charge de 4 PNJ : aucune recrue (" .. n_lo .. ")")
    -- Charge énorme : plafonnée à 30.
    local n_max, _, _, over_max = simulate(30, 120, { ambition = 2000 })
    check(n_max <= 30 and not over_max and n_max >= 25, "charge de 60 PNJ : l'équipe monte vers son plafond sans le dépasser (" .. n_max .. ")")
    -- Ambitieuse plus rapide que peu ambitieuse sous la même charge, à 10 min.
    local _, h_amb = simulate(6, 10, { ambition = 1875 })
    local _, h_slow = simulate(6, 10, { ambition = 750 })
    check(h_amb[#h_amb] > h_slow[#h_slow], "à 10 min, l'ambitieuse a plus de PNJ que la peu ambitieuse ("
      .. h_amb[#h_amb] .. " contre " .. h_slow[#h_slow] .. ")")
  end)
  if not ok then fail = fail + 1; msgs[#msgs + 1] = "erreur : " .. tostring(err) end
  return pass, fail, msgs
end

---------------------------------------------------------------------------------------------------
-- Vrai module
---------------------------------------------------------------------------------------------------
local src = read_src()
local E = assert(load_module(src))
local pass, fail, msgs = suite(E)
for _, m in ipairs(msgs) do print("[AI3-EFFECTIF] ECHEC : " .. m) end

-- Généricité : le module ne nomme aucune recette ni aucun objet hors des plaques (le coût lui arrive en plaques).
local named = {}
for _, w in ipairs({ "pistol", "firearm", "burner", "furnace", "turret", "magazine" }) do
  if src:find(w, 1, true) then named[#named + 1] = w end
end
if #named == 0 then pass = pass + 1 else
  fail = fail + 1
  print("[AI3-EFFECTIF] ECHEC : objets nommés dans le module : " .. table.concat(named, ", "))
end
-- Aucun `pairs` dans le module (ordre de décision).
if not src:find("[^i]pairs%(") then pass = pass + 1 else
  fail = fail + 1
  print("[AI3-EFFECTIF] ECHEC : pairs() dans le module")
end

---------------------------------------------------------------------------------------------------
-- Mutants : chacun doit être refusé (au moins un ECHEC de la suite).
---------------------------------------------------------------------------------------------------
local MUTANTS = {
  { "attente ignorée (0 min)", "E.WAIT_TICKS = 2 * 3600", "E.WAIT_TICKS = 0" },
  { "inactifs ignorés", "local hands = (s.idle or 0) + (s.fond or 0)", "local hands = 0" },
  { "fond non compté comme bras libres", "local hands = (s.idle or 0) + (s.fond or 0)", "local hands = (s.idle or 0)" },
  { "fond compté comme travail", "not t.worker and not t.fond and", "not t.worker and" },
  { "coût ignoré", "if not E.affordable(s.cost, s.left, d.margin) then", "if false then" },
  { "marge ignorée", "need = need + (margin or 0)", "need = need" },
  { "rythme ignoré", "if last and tick - last < d.period then", "if false then" },
  { "plafond ignoré", "if n >= (s.cap or 0) then", "if false then" },
  { "plancher ignoré", "if n < (s.floor or 0) then", "if false then" },
  { "sans frein ignoré", "if (s.limit or 0) >= E.NO_BRAKE then", "if false then" },
  { "menace ignorée", "if s.threatened then", "if false then" },
  { "matière ignorée", "elseif t.prenable == false then", "elseif false then" },
  { "valeur minimale ignorée", "if v < E.VALUE_MIN * 2 then", "if false then" },
  { "garde ignorée", "if s.blocked then", "if false then" },
  { "équipement de recrue compté", "and t.tag ~= E.RECRUIT_TAG then", "then" },
  { "caractère ignoré (période)", "local a = (traits and traits.ambition) or 1000", "local a = 1000" },
  { "caractère ignoré (marge)", "local p = (traits and traits.prudence) or 1000", "local p = 1000" },
  { "tolérance ignorée", "local free = hands - (s.limit or 0)", "local free = hands" },
  { "recrue dès 1 tâche même avec des libres", "if d.short <= 0 then", "if w == 0 then" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = src:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif absent)"
  else
    local msrc = src:sub(1, a - 1) .. m[3] .. src:sub(b + 1)
    local mod, err = load_module(msrc)
    local mf = 1
    if mod then
      local _, f2 = suite(mod)
      mf = f2
    end
    if mf > 0 then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
if #kept == 0 then pass = pass + 1 else
  fail = fail + 1
  print("[AI3-EFFECTIF] ECHEC : mutants NON refusés : " .. table.concat(kept, " ; "))
end
print(string.format("[AI3-EFFECTIF] mutants refusés : %d sur %d", refused, #MUTANTS))

---------------------------------------------------------------------------------------------------
-- 7. Branchement (moteur simulé) : une guerre à 4 factions, plafond 30, départ 8 ; Team.view rend la décision de la
-- règle (raison connue, frein levé seulement quand elle dit « recrue ») ; ligne minute « [FO-EFFECTIF] » ; fenêtre.
---------------------------------------------------------------------------------------------------
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[AI3-EFFECTIF] ECHEC : " .. msg) end
end
local okm, errm = pcall(function()
  local M = require("tests.mock_engine")
  local function patches()
    local out = {}
    local d = 0.7071
    local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
    local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
      { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
    for _, c in ipairs(corners) do
      local hx, hy = c[1] * 320, c[2] * 320
      local names = { "coal", "iron-ore", "copper-ore", "stone" }
      for ri, r in ipairs({ 40, 64, 88 }) do
        for di, v in ipairs(dirs) do out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] } end
      end
    end
    return out
  end
  M.new_game({ patches = patches(), p_busy = 0.02, p_nopath = 0.02, p_lost = 0.005 })
  M.command("fo-war", "start 4 100 30 320")
  M.run_ticks(5 * 3600 + 30)
  local Team = require("script.team.team")
  local Registry = require("script.companion.registry")
  local known = {}
  for _, r in ipairs(E.REASONS) do known[r] = true end
  local all_known, lines = true, {}
  for _, f in ipairs(global.fo.war.factions) do
    local d = f.team and f.team.effectif and f.team.effectif.last_d
    if not (d and known[d.reason]) then all_known = false end
  end
  check(all_known, "moteur simulé : chaque faction a une décision d'effectif de raison connue")
  for _, l in ipairs(M.world().logs) do
    local key = l:match("%[FO%-EFFECTIF%] (%a+) minute")
    if key then lines[key] = (lines[key] or 0) + 1 end
  end
  local n_keys = 0
  for _, k in ipairs({ "scarlet", "azure", "emerald", "amber" }) do if (lines[k] or 0) >= 3 then n_keys = n_keys + 1 end end
  check(n_keys == 4, "ligne minute [FO-EFFECTIF] écrite pour les 4 factions (" .. n_keys .. ")")
  -- Branchement de la décision : Écarlate, tous ses PNJ occupés, 3 tâches libres qui attendent depuis 3 min, du fer.
  local f = global.fo.war.factions[1]
  local b = f.team.board
  local saved_list, saved_tasks = b.list, {}
  local ids = {}
  for id in pairs(f.engineers) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local a = Registry.get(id)
    saved_tasks[id] = a and a.task
    if a then a.task = a.task or { kind = "mine", key = "test:occupe:" .. id } end
  end
  local tick = game.tick
  local list = {}
  for i = 1, 3 do list[i] = { key = "test:attente:" .. i, kind = "craft", prio = 60, created = tick - 3 * 3600 } end
  b.list = list
  f.hq.insert({ name = "iron-plate", count = 2000 })
  f.hq.insert({ name = "copper-plate", count = 200 })
  local view = Team.view(f, tick + 1)
  local de = view.effectif
  check(de ~= nil and de.reason == "recrue" and view.recruit_held == false and de.waiting == 3,
    "Team.view : 3 tâches en attente, personne de libre, fer : recrue, frein levé (" .. tostring(de and de.reason) .. ", "
      .. tostring(de and de.waiting) .. ")")
  -- Un PNJ libre pour une seule tâche : inactifs, frein tenu.
  b.list = { list[1] }
  local a1 = Registry.get(ids[1])
  if a1 then a1.task = nil end
  view = Team.view(f, tick + 2)
  check(view.effectif and view.effectif.reason == "inactifs" and view.recruit_held == true,
    "Team.view : un PNJ libre pour la seule tâche en attente : aucune recrue (" .. tostring(view.effectif and view.effectif.reason) .. ")")
  -- Fenêtre : texte localisé de la raison.
  require("shared.ai3.effectif").count(f.team.effectif, view.effectif)
  local txt = Team.effectif_text(f)
  check(type(txt) == "table" and txt[1] == "fo-ia3d.recruit-line" and type(txt[2]) == "table" and txt[2][1] == "fo-ia3d.why-inactifs",
    "fenêtre : ligne « Recrutement : … » de la raison")
  b.list = saved_list
  for _, id in ipairs(ids) do local a = Registry.get(id); if a then a.task = saved_tasks[id] end end
end)
check(okm, "branchement au moteur simulé sans erreur (" .. tostring(errm) .. ")")

-- Traductions : une clé why-<raison> par raison, en français et en anglais.
for _, lang in ipairs({ "fr", "en" }) do
  local fh = io.open("locale/" .. lang .. "/ia3d.cfg", "rb")
  local txt = fh and fh:read("*a") or ""
  if fh then fh:close() end
  local missing = {}
  for _, r in ipairs(E.REASONS) do
    if not txt:find("\nwhy%-" .. r:gsub("_", "%%_") .. "=") then missing[#missing + 1] = r end
  end
  if not txt:find("\nrecruit%-line=") then missing[#missing + 1] = "recruit-line" end
  check(#missing == 0, "locale/" .. lang .. "/ia3d.cfg : toutes les raisons traduites (" .. table.concat(missing, ", ") .. ")")
end
print(string.format("[AI3-EFFECTIF] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
