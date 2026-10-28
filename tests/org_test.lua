--[[
  Tests hors jeu du modèle d'organisation des équipes de PNJ (shared/team/org.lua, lot IA1, OBJECTIFS C5).
  Usage, depuis la racine du mod :   lua5.2 tests/org_test.lua

  Vérifie : tables (pôles, domaines, types de tâches du cerveau actuel), orientation (menace : +20 points
  entiers), plafonds d'effectif et options de montée (Q-IA1-2), durées de partie des options de recalibrage
  (Q-IA1-1, deux hypothèses de débit), généralistes, cibles par pôle, déterminisme (double passage, ordre d'entrée
  mélangé, copie profonde), hystérésis et stabilité (au plus 6 changements de pôle par PNJ, généralistes
  compris, par heure glissante, même sous des ordres contradictoires, équipe inoccupée OU au travail),
  réaction aux priorités du joueur, à une crise, à une menace et à une zone nouvelle avec une équipe occupée à
  85 % ou plus (mouvements DIFFÉRÉS appliqués en fin de tâche), équipes de zone nommées, promotion, meneurs,
  prise de tâche (urgence avant le pôle, zone, domaine hérité du projet), besoin compté avec le travail en
  cours, jetons de travail partagés entre équipes, tailles 10 / 30 / 50 / 60 et coût de calcul compté,
  résurrection, recrutement (option la moins chère), coût d'une mort par époque, progression, règle
  d'automatisation, amélioration instantanée en un trajet, chiffres des maquettes du §8, compatibilité avec
  le cerveau actuel.
]]

package.path = "./?.lua;" .. package.path
local O = require("shared.team.org")
local T = require("shared.team.config")
local F = require("shared.faction.config")
local X = require("shared.content.epochs")
local Book = require("shared.team.book")
local Planner = require("shared.team.planner")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

-- Sérialisation canonique (clés triées) : comparer deux résultats octet pour octet.
local function ser(v)
  local t = type(v)
  if t == "table" then
    local ks = {}
    for k in pairs(v) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b)
      local ta, tb = type(a), type(b)
      if ta ~= tb then return ta < tb end
      return a < b
    end)
    local parts = {}
    for _, k in ipairs(ks) do parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif t == "number" then
    return string.format("%.12g", v)
  elseif t == "function" then
    return "FONCTION"
  end
  return tostring(v)
end

local function deep(v)
  if type(v) ~= "table" then return v end
  local o = {}
  for k, x in pairs(v) do o[k] = deep(x) end
  return o
end

-- RNG déterministe (LCG) pour les mélanges et les tirages des tests de propriété.
local seed = 20261021
local function rnd(n)
  seed = (seed * 1103515245 + 12345) % 2147483648
  return seed % n + 1
end
local function shuffle(list)
  local l = {}
  for i = 1, #list do l[i] = list[i] end
  for i = #l, 2, -1 do
    local j = rnd(i)
    l[i], l[j] = l[j], l[i]
  end
  return l
end

local function sum3(t) return t[1] + t[2] + t[3] end

--- Équipe de n PNJ : les premiers sont généralistes (selon generalists_wanted), les autres exécutants
--- répartis selon `dist` (3 entiers, somme = exécutants) ou à tour de rôle ; tous inoccupés par défaut.
local function make_team(n, chiefs, dist)
  local g = O.generalists_wanted(n, chiefs or 5)
  local npcs = {}
  local quota = dist and { dist[1], dist[2], dist[3] } or nil
  local p = 1
  for id = 1, n do
    local rank = (id * 7) % 5 + 1
    local a = { id = id, rank = rank, xp = O.XP_THRESHOLDS[rank] + id, idle = true }
    if id <= g then
      a.role = "generalist"
      a.pole = O.POLES[(id - 1) % 3 + 1]
    else
      a.role = "executant"
      if quota then
        while quota[p] == 0 do p = p % 3 + 1 end
        quota[p] = quota[p] - 1
        a.pole = O.POLES[p]
        p = p % 3 + 1
      else
        a.pole = O.POLES[(id - 1) % 3 + 1]
      end
    end
    npcs[#npcs + 1] = a
  end
  return npcs
end

--- Exécutants par pôle RÉEL (là où ils travaillent).
local function count_poles(npcs)
  local c = { 0, 0, 0 }
  for _, a in ipairs(npcs) do
    if a.role == "executant" and a.pole then c[O.POLE_INDEX[a.pole]] = c[O.POLE_INDEX[a.pole]] + 1 end
  end
  return c
end

local function find(npcs, id)
  for _, a in ipairs(npcs) do if a.id == id then return a end end
end

--- Applique les décisions d'une pensée à l'équipe (ce que fera le runtime). Renvoie la liste des ids dont le
--- pôle a changé TOUT DE SUITE (mouvements immédiats et généralistes).
local function apply(npcs, out, tick)
  local changed = {}
  for _, pl in ipairs(out.place) do find(npcs, pl.id).pole = pl.pole end
  for _, m in ipairs(out.moves) do
    local a = find(npcs, m.id)
    if m.deferred then
      a.dest = m.to
    else
      a.pole, a.dest, a.moved_tick = m.to, nil, tick
      changed[#changed + 1] = a.id
    end
  end
  if out.promote then find(npcs, out.promote).role = "generalist" end
  for _, gm in ipairs(out.gen_moves) do
    find(npcs, gm.id).moved_tick = tick
    changed[#changed + 1] = gm.id
  end
  for _, gp in ipairs(out.gen_poles) do
    local a = find(npcs, gp.id)
    a.pole, a.dest = gp.pole, nil
  end
  for _, a in ipairs(npcs) do if a.role == "executant" then a.zone = nil end end
  for _, z in ipairs(out.zone_of) do find(npcs, z.id).zone = z.zone end
  return changed
end

--- Pire nombre de changements d'un PNJ dans une heure glissante semi-ouverte [t, t + 1 h).
local function worst_window(npcs, changes)
  local worst = 0
  for _, a in ipairs(npcs) do
    local list = changes[a.id] or {}
    for i = 1, #list do
      local c = 0
      for j = i, #list do if list[j] < list[i] + 216000 then c = c + 1 end end
      if c > worst then worst = c end
    end
  end
  return worst
end

--[[
  Simulation d'une équipe AU TRAVAIL (une pensée toutes les 300 ticks, soit 5 s). Chaque exécutant enchaîne des
  tâches de `dur` pensées ; celui d'id i finit sa tâche aux pensées k où (k + i) % dur == 0 (fins échelonnées).
  À sa fin de tâche, O.settle applique sa destination différée, puis il reprend aussitôt une tâche (comme
  script/team/worker.lua, état idle). Les exécutants de `idle_ids` sont inoccupés à chaque pensée (aucun
  travail dans leur pôle). opts = { thoughts, dur, idle_ids, input = function(k) -> entrée sans tick ni npcs,
  after = function(k, out, npcs), tick }. Contrôle à chaque pensée qu'aucun PNJ occupé ne change de pôle hors
  de sa fin de tâche. Renvoie changes = { [id] = { ticks } } (changements de pôle EFFECTIFS) et le drapeau
  `interrupted` (vrai si un PNJ occupé a été déplacé en cours de tâche).
]]
local function simulate(npcs, opts)
  local tick = opts.tick or 0
  local changes, interrupted = {}, false
  local function note(id)
    changes[id] = changes[id] or {}
    changes[id][#changes[id] + 1] = tick
  end
  for k = 1, opts.thoughts do
    for _, a in ipairs(npcs) do
      if a.role == "executant" then
        local phase = (k + a.id) % opts.dur
        if phase == 0 and O.settle(a, tick) then note(a.id) end
        a.idle = opts.idle_ids[a.id] or false
        a.work_left = a.idle and 0 or (opts.dur - phase) * 5
      end
    end
    local inp = opts.input(k)
    inp.tick, inp.npcs = tick, npcs
    local busy_pole = {}
    for _, a in ipairs(npcs) do
      if a.role == "executant" and not a.idle then busy_pole[a.id] = a.pole end
    end
    local out = O.plan(inp)
    for _, m in ipairs(out.moves) do
      if m.deferred == (find(npcs, m.id).idle and true or false) then interrupted = true end
    end
    for _, id in ipairs(apply(npcs, out, tick)) do note(id) end
    for _, a in ipairs(npcs) do
      if a.role == "executant" and busy_pole[a.id] and a.pole ~= busy_pole[a.id] then interrupted = true end
    end
    if opts.after then opts.after(k, out, npcs) end
    tick = tick + 300
  end
  return changes, interrupted
end

--- Ensemble des `m` exécutants inoccupés : les ids les plus grands parmi les pôles donneurs `poles`.
local function pick_idle(npcs, m, poles)
  local set, n = {}, 0
  for i = #npcs, 1, -1 do
    local a = npcs[i]
    if n >= m then break end
    if a.role == "executant" and poles[a.pole] then set[a.id] = true; n = n + 1 end
  end
  return set
end

local BIG = { 3000, 3000, 3000 } -- 10 PNJ équivalents de travail dans chaque pôle
local DUR = 12                   -- tâches de 12 pensées (60 s), fins échelonnées

---------------------------------------------------------------------------------------------------
section("Tables : pôles, domaines, types de tâches")
check(#O.POLES == 3 and #O.DOMAINS == 5, "3 pôles et 5 domaines (managers)")
local per_pole = { 0, 0, 0 }
for _, d in ipairs(O.DOMAINS) do
  check(O.POLE_INDEX[d.pole] ~= nil, "domaine " .. d.key .. " rattaché à un pôle connu")
  per_pole[O.POLE_INDEX[d.pole]] = per_pole[O.POLE_INDEX[d.pole]] + 1
end
check(per_pole[1] >= 1 and per_pole[2] >= 1 and per_pole[3] >= 1, "chaque pôle a au moins un domaine")
local kinds = {}
for k in pairs(O.TASK_DOMAIN) do kinds[#kinds + 1] = k end
table.sort(kinds)
for _, k in ipairs(kinds) do
  check(O.DOMAIN_POLE[O.TASK_DOMAIN[k]] ~= nil, "type " .. k .. " -> domaine connu")
  check(O.TASK_WORK[k] ~= nil, "type " .. k .. " : durée estimée")
end
local dk = {}
for k in pairs(O.DESIGN_KINDS) do dk[#dk + 1] = k end
table.sort(dk)
for _, k in ipairs(dk) do check(O.TASK_DOMAIN[k] ~= nil, "conception " .. k .. " a un domaine") end
for _, k in ipairs({ "mine", "carry", "service" }) do
  check(O.MANUAL_KINDS[k] ~= nil and O.TASK_DOMAIN[k] ~= nil, "travail manuel " .. k .. " connu")
end
-- Chaque type de tâche émis AUJOURD'HUI par le cerveau d'équipe a un domaine (lu dans le code source).
do
  local f = io.open("shared/team/planner.lua", "r")
  local src = f and f:read("*a") or ""
  if f then f:close() end
  local seen, n = {}, 0
  for k in src:gmatch('%f[%w_]kind = "([%w_]+)"') do
    if not seen[k] then
      seen[k] = true
      n = n + 1
      check(O.TASK_DOMAIN[k] ~= nil, "type du cerveau actuel '" .. k .. "' rattaché à un domaine")
    end
  end
  check(n >= 9, "les 9 types du cerveau actuel sont lus dans planner.lua (lus : " .. n .. ")")
end
for _, name in ipairs(O.PRESET_ORDER) do
  local p = O.PRESETS[name]
  check(p and p.extraction + p.base + p.territoire == 100, "préréglage " .. name .. " : somme 100")
end
for _, fa in ipairs(F.factions) do
  local p = O.PERSONALITY[fa.personality]
  check(p and p.extraction + p.base + p.territoire == 100, "personnalité " .. fa.personality .. " : orientation de somme 100")
end
check(ser(O.TASK_DOMAIN):find("FONCTION") == nil, "tables sans fonction (sérialisables)")

---------------------------------------------------------------------------------------------------
section("Orientation (curseurs du joueur, préréglages, menace : +20 points entiers)")
check(ser(O.normalize("ressources")) == ser({ 60, 25, 15 }), "préréglage ressources = 60/25/15")
check(ser(O.normalize({ 0, 0, 0 })) == ser({ 40, 40, 20 }), "tout à 0 -> équilibre")
check(ser(O.normalize("inconnu")) == ser({ 40, 40, 20 }), "préréglage inconnu -> équilibre")
check(ser(O.normalize({ 1, 1, 1 })) == ser({ 34, 33, 33 }), "1/1/1 -> 34/33/33 (plus fort reste entier, égalité par l'ordre des pôles)")
check(ser(O.normalize({ extraction = -5, base = 10 })) == ser({ 0, 100, 0 }), "négatif ramené à 0")
check(ser(O.normalize("equilibre", true)) == ser({ 30, 30, 40 }), "menace en équilibre : 30/30/40 (+20 points exacts au territoire)")
check(ser(O.normalize("ressources", true)) == ser({ 46, 19, 35 }), "menace en « Ressources » : 46/19/35 (20 points pris au prorata 60:25)")
check(ser(O.normalize("protection", true)) == ser({ 11, 14, 75 }), "menace en « Protection » : 11/14/75")
check(ser(O.normalize({ 0, 0, 90 }, true)) == ser({ 0, 0, 100 }), "menace plafonnée à 100 points")
do
  local exact = true
  local names = {}
  for _, n in ipairs(O.PRESET_ORDER) do names[#names + 1] = O.PRESETS[n] end
  for _, k in ipairs({ "conqueror", "technocrat", "builder", "balanced" }) do names[#names + 1] = O.PERSONALITY[k] end
  for _, o in ipairs(names) do
    local a, b = O.normalize(o), O.normalize(o, true)
    if b[3] ~= math.min(100, a[3] + 20) or sum3(b) ~= 100 or b[1] > a[1] or b[2] > a[2] then exact = false end
  end
  check(exact, "menace : territoire = calme + 20 exactement (5 préréglages, 4 personnalités), pris aux deux autres")
end
-- Égalité sous menace : le territoire n'est jamais derrière un pôle à égalité (quotas des généralistes).
check(ser(O.normalize({ 70, 0, 30 }, true)) == ser({ 50, 0, 50 }), "70/0/30 sous menace -> 50/0/50 (égalité)")
check(ser(O.generalist_quotas(1, { 50, 0, 50 }, nil, O.THREAT_ORDER)) == ser({ 0, 0, 1 }), "égalité 50/50 sous menace : le seul généraliste va au territoire")
check(ser(O.generalist_quotas(1, { 50, 0, 50 })) == ser({ 1, 0, 0 }), "même égalité sans menace : l'extraction (ordre des pôles)")
for _ = 1, 200 do
  local o = { rnd(101) - 1, rnd(101) - 1, rnd(101) - 1 }
  local th = rnd(2) == 1
  local n = O.normalize(o, th)
  if sum3(n) ~= 100 or n[1] < 0 or n[2] < 0 or n[3] < 0 then check(false, "normalize " .. ser(o)) end
  if th then
    local c = O.normalize(o)
    if n[3] ~= math.min(100, c[3] + 20) then check(false, "menace +20 " .. ser(o)) end
  end
end
check(true, "200 orientations tirées : somme 100, aucune valeur négative, menace = +20 exacts")

---------------------------------------------------------------------------------------------------
section("Effectifs : plafonds par époque, départ, généralistes")
local function caps(max, fr) return { O.headcount_cap(1, max, fr), O.headcount_cap(2, max, fr), O.headcount_cap(3, max, fr), O.headcount_cap(15, max, fr) } end
check(ser(caps(30)) == ser({ 15, 25, 30, 30 }), "30 : 15 / 25 / 30 / 30 (époques 1, 2, 3, 15) : " .. ser(caps(30)))
check(ser(caps(10)) == ser({ 5, 9, 10, 10 }), "10 : 5 / 9 / 10 / 10 : " .. ser(caps(10)))
check(ser(caps(50)) == ser({ 25, 42, 50, 50 }), "50 : 25 / 42 / 50 / 50 : " .. ser(caps(50)))
check(ser(caps(60)) == ser({ 30, 50, 60, 60 }), "60 : 30 / 50 / 60 / 60 : " .. ser(caps(60)))
check(ser(caps(30, {})) == ser({ 30, 30, 30, 30 }), "option « 30 dès l'époque 1 » (Q-IA1-2) : 30 / 30 / 30 / 30")
local mono = true
for max = 6, 60 do
  for e = 1, 14 do if O.headcount_cap(e, max) > O.headcount_cap(e + 1, max) or O.headcount_cap(e, max) > max then mono = false end end
end
check(mono, "plafond croissant avec l'époque et jamais au-dessus du maximum (6 à 60 PNJ)")
check(O.start_headcount(30) == 8 and O.start_headcount(10) == 5 and O.start_headcount(6) == 3, "départ : 8 (30), 5 (10), 3 (6)")
local gw = {
  { 30, 5, 5 }, { 25, 5, 5 }, { 24, 5, 4 }, { 10, 5, 2 }, { 8, 5, 2 }, { 6, 5, 1 }, { 1, 5, 1 }, { 0, 5, 0 },
  { 50, 5, 5 }, { 50, 8, 8 }, { 60, 8, 8 }, { 30, 1, 1 },
}
for _, c in ipairs(gw) do
  check(O.generalists_wanted(c[1], c[2]) == c[3], string.format("généralistes pour %d PNJ (réglage %d) = %d", c[1], c[2], c[3]))
end
do
  -- Q-IA1-2 : coût de la montée de 8 à 30 PNJ (recrues + kits), en MU (plaque = 1 MU ; pistolet 10, chargeur 4 :
  -- recettes vanilla 5 fer + 5 cuivre et 4 fer).
  local MU = { pistol = 10, ["firearm-magazine"] = 4 }
  local total = 0
  for h = 8, 29 do total = total + O.cost_value(O.recruit_cost(h), MU) end
  check(total == 627 + 22 * 50, "22 recrues de 8 à 30 PNJ : 627 fer + 22 kits = " .. total .. " MU")
  print(string.format("   montée 8 -> 30 : %d MU, soit %.1f min du débit nominal de l'époque 1 (%.2f MU/s) et %.0f %% de son budget",
    total, total / X.rate_avg(1) / 60, X.rate_avg(1), 100 * total / X.budget(1)))
end

---------------------------------------------------------------------------------------------------
section("Q-IA1-1 : durée de la partie selon le recalibrage des coûts (estimations ; m NON MESURÉ)")
do
  -- Durée de l'époque k = coût × budget X0 ÷ débit de l'équipe. Deux hypothèses de débit, faute de mesure :
  --   H1 « travail manuel seul » : débit nominal X0 + A(k), A = mineurs au plafond manuel (O.manual_cap sur 25
  --      exécutants : 12 à l'époque 1, 5 ensuite) × 0,5 minerai/s × 1 MU (estimé) ;
  --   H2 « l'équipe multiplie l'usine par m » : débit nominal × m (m = 1,5, 2 ou 3).
  -- Options de coût : (a) X0 inchangé ; (b) X0 aux époques 1 à 3, × gain à partir de l'époque 4 ; (b') variante
  -- de la revue, × gain aux époques 1 à 3 seulement ; (c) × gain partout (gain = débit équipe ÷ débit nominal).
  local function A(k) return O.manual_cap(25, k) * 0.5 end
  local function zero() return 0 end
  local function run(mult, add, cost)
    local h, reach = 0, {}
    for k = 1, X.EPOCHS do
      reach[k] = h
      h = h + cost(k) * X.budget(k) / (X.rate_avg(k) * mult + add(k)) / 3600
    end
    return reach, h
  end
  local function gain(mult, add) return function(k) return (X.rate_avg(k) * mult + add(k)) / X.rate_avg(k) end end
  local function from4(g) return function(k) return k >= 4 and g(k) or 1 end end
  local function upto3(g) return function(k) return k <= 3 and g(k) or 1 end end
  local one = function() return 1 end
  local rn, tn = run(1, zero, one)
  check(math.abs(tn - 59.5) < 1e-9 and rn[3] == 1.5 and rn[4] == 3, "calendrier X0 nominal : époque 3 à 1,5 h, époque 4 à 3 h, 59,5 h en tout")
  local rows = {}
  local function row(label, reach, total)
    rows[#rows + 1] = string.format("%-34s ép. 3 %5.2f h ; ép. 4 %5.2f h ; ép. 6 %5.2f h ; ép. 10 %5.1f h ; total %5.1f h",
      label, reach[3], reach[4], reach[6], reach[10], total)
  end
  row("X0 nominal (joueur seul)", rn, tn)
  local ra, ta = run(1, A, one)
  row("H1 (a) coûts X0", ra, ta)
  check(ra[4] < 2 and ta > 55 and ta < 59.5, string.format("H1 (a) : le pétrole vers %.1f h au lieu de 3 h, partie de %.1f h (le manuel ne compte qu'au début)", ra[4], ta))
  local rb1, tb1 = run(1, A, from4(gain(1, A)))
  row("H1 (b) X0 ép. 1-3, x gain ensuite", rb1, tb1)
  local rc1, tc1 = run(1, A, gain(1, A))
  row("H1 (c) recalibrage complet", rc1, tc1)
  check(math.abs(tc1 - 59.5) < 1e-6 and math.abs(rc1[4] - 3) < 1e-6, "H1 (c) : le recalibrage complet rend exactement le calendrier X0 (l'accélération disparaît)")
  for _, m in ipairs({ 1.5, 2, 3 }) do
    local r, t = run(m, zero, one)
    row(string.format("H2 m = %.1f (a) coûts X0", m), r, t)
    check(math.abs(t - 59.5 / m) < 1e-6, string.format("H2 m = %.1f (a) : partie de 59,5 / m = %.1f h", m, t))
    local rb, tb = run(m, zero, from4(gain(m, zero)))
    row(string.format("H2 m = %.1f (b) X0 ép. 1-3, x m ensuite", m), rb, tb)
    check(math.abs(rb[4] - 3 / m) < 1e-6 and math.abs(tb - (59.5 - 3 + 3 / m)) < 1e-6,
      string.format("H2 m = %.1f (b) : pétrole à %.2f h, partie de %.1f h (seul le début accélère)", m, rb[4], tb))
    local rb2, tb2 = run(m, zero, upto3(gain(m, zero)))
    row(string.format("H2 m = %.1f (b') x m ép. 1-3 seulement", m), rb2, tb2)
    check(math.abs(rb2[4] - 3) < 1e-6 and tb2 < 59.5, string.format("H2 m = %.1f (b') : début au rythme X0, fin accélérée (%.1f h) : l'inverse de la demande", m, tb2))
    local rc, tc = run(m, zero, gain(m, zero))
    row(string.format("H2 m = %.1f (c) recalibrage complet", m), rc, tc)
    check(math.abs(tc - 59.5) < 1e-6, string.format("H2 m = %.1f (c) : 59,5 h, calendrier X0", m))
  end
  for _, line in ipairs(rows) do print("   " .. line) end
end

---------------------------------------------------------------------------------------------------
section("Répartition entière (plus fort reste, restes entiers)")
check(ser(O.apportion(1, { 1, 1, 1 })) == ser({ 1, 0, 0 }), "égalité départagée par l'indice")
check(ser(O.apportion(1, { 1, 1, 1 }, nil, { 3, 1, 2 })) == ser({ 0, 0, 1 }), "égalité départagée par l'ordre donné (territoire d'abord)")
check(ser(O.apportion(5, { 0, 0, 0 })) == ser({ 0, 0, 0 }), "poids nuls -> zéros")
check(ser(O.apportion(100, { 1, 1, 1 })) == ser({ 34, 33, 33 }), "100 sur 1/1/1 : 34/33/33")
check(ser(O.apportion(7, { 2.9, 1.2 })) == ser(O.apportion(7, { 2, 1 })), "poids fractionnaires tronqués en entiers")
local ok_sum = true
for _ = 1, 500 do
  local total = rnd(80) - 1
  local w = { rnd(10) - 1, rnd(10) - 1, rnd(10) - 1, rnd(10) - 1 }
  local a = O.apportion(total, w)
  local s = 0
  for i = 1, 4 do
    s = s + a[i]
    if a[i] < 0 then ok_sum = false end
    -- plus fort reste : chaque part est le quotient exact, arrondi en dessous ou au-dessus
    local sw = w[1] + w[2] + w[3] + w[4]
    if sw > 0 then
      local lo = math.floor(total * w[i] / sw)
      if a[i] < lo or a[i] > lo + 1 then ok_sum = false end
    end
  end
  if (w[1] + w[2] + w[3] + w[4] > 0 and s ~= total) or ser(a) ~= ser(O.apportion(total, w)) then ok_sum = false end
end
check(ok_sum, "500 tirages : somme exacte, parts au quotient près, aucune valeur négative, reproductible")

---------------------------------------------------------------------------------------------------
section("Cibles par pôle (exécutants)")
local t0, s0 = O.pole_targets(25, BIG, { 40, 40, 20 }, 0)
check(ser(t0) == ser({ 10, 10, 5 }) and s0 == 0, "25 exécutants, travail partout, équilibre -> 10/10/5 : " .. ser(t0))
local tr = O.pole_targets(25, BIG, O.normalize("ressources"), 0)
check(tr[1] > tr[2] and tr[1] > tr[3] and sum3(tr) == 25, "« Ressources » : l'extraction domine " .. ser(tr))
check(tr[1] <= 13, "plafond d'utilité : 10 PNJ de travail -> 13 au plus à l'extraction (" .. tr[1] .. ")")
local tp = O.pole_targets(25, BIG, O.normalize("protection"), 0)
check(tp[3] > tp[1] and tp[3] > tp[2], "« Protection » : le territoire domine " .. ser(tp))
local tn, sn = O.pole_targets(25, { 0, 0, 0 }, { 40, 40, 20 }, 0)
check(sn == 25 and sum3(tn) == 25 and tn[1] >= tn[3], "aucun travail : 25 au-delà du carnet, au fond selon l'orientation " .. ser(tn))
local tz = O.pole_targets(25, { 3000, 3000, 0 }, { 50, 50, 0 }, 3)
check(tz[3] >= 6, "3 zones actives -> au moins 6 au territoire, même orienté à 0 (" .. tz[3] .. ")")
local tf = O.pole_targets(25, { 0, 6000, 0 }, { 0, 100, 0 }, 0)
check(tf[1] >= 2, "plancher d'extraction : 2 même orienté à 0 (" .. tf[1] .. ")")
local tsmall, ssmall = O.pole_targets(25, { 0, 300, 0 }, { 0, 100, 0 }, 0)
check(ssmall == 23, "1 PNJ de travail à la base -> 2 utiles (×5/4 arrondi), 23 au-delà du carnet (surplus " .. ssmall .. ")")
do
  -- Plancher des zones borné (sonde du correcteur : 25 exécutants et 12 zones donnaient 2/0/23).
  local t12, _, info = O.pole_targets(25, BIG, { 40, 40, 20 }, 12)
  check(t12[3] == 12 and t12[2] > 0 and info.capped and info.zone_wanted == 24 and info.zone_floor == 12,
    "12 zones pour 25 exécutants : territoire borné à 12 (50 %), la base garde " .. t12[2] .. ", avertissement : " .. ser(t12))
end
local prop = true
for _ = 1, 500 do
  local n = rnd(61) - 1
  local need = { (rnd(31) - 1) * 300, (rnd(31) - 1) * 300, (rnd(31) - 1) * 300 }
  local pts = O.normalize({ rnd(101) - 1, rnd(101) - 1, rnd(101) - 1 })
  local z = rnd(8) - 1
  local t, s = O.pole_targets(n, need, pts, z)
  if sum3(t) ~= n or t[1] < 0 or t[2] < 0 or t[3] < 0 or s < 0 or s > n then prop = false end
  if n >= 2 and t[1] < 2 then prop = false end
  local zf = math.min(2 * z, math.floor(n * 50 / 100), math.max(0, n - 2))
  if t[3] < zf then prop = false end
end
check(prop, "500 tirages : somme = effectif, planchers tenus, zones bornées à 50 %, surplus dans [0, n]")

---------------------------------------------------------------------------------------------------
section("Besoin : travail ouvert ET restant des tâches en cours ; domaine hérité du projet")
do
  local tasks = {}
  for i = 1, 25 do tasks[i] = { key = "m" .. i, kind = "mine", prio = 30, worker = 100 + i, work_left = 30 } end
  local d = O.demand_from_tasks(tasks)
  check(d.open[1] == 0 and d.taken[1] == 750 and d.poles[1] == 750, "25 tâches prises (30 s restantes) : 750 s comptées à l'extraction, 0 ouverte")
  local d2 = O.demand_from_tasks({ { key = "c", kind = "craft", prio = 50, worker = 1 } })
  check(d2.taken[2] == 15, "tâche prise sans reste connu : la moitié de l'estimation (30 s -> 15 s)")
  -- Équipe toute au travail, tableau sans tâche libre : la base n'est pas vue vide, aucun PNJ inactif.
  local npcs = make_team(30, 5, { 10, 10, 5 })
  local all_taken = {}
  local i = 0
  for _, a in ipairs(npcs) do
    a.idle = false
    if a.role == "executant" then
      i = i + 1
      local kind = ({ extraction = "mine", base = "craft", territoire = "refill" })[a.pole]
      all_taken[i] = { key = "t" .. i, kind = kind, prio = 50, worker = a.id, work_left = 200 }
    end
  end
  local out = O.plan({ tick = 0, npcs = npcs, tasks = all_taken, orientation = "equilibre", chiefs = 5 })
  check(out.idle_rate == 0 and out.need[2] == 2000, "équipe au travail, 0 tâche libre : besoin de la base 2 000 s (travail en cours), inactivité 0")
  check(#out.moves == 0, "un pôle dont tout le travail est pris n'est pas vidé : aucun mouvement (" .. ser(out.targets) .. ")")
  print(string.format("   équipe au travail, 0 tâche libre : surplus (au-delà du carnet à 5 min) %d, inactivité réelle %d %%", out.surplus, out.idle_rate * 100))
  -- Domaine hérité : un fantôme du projet Pétrole (gisements) va à l'extraction, pas à la base.
  local projects = { { id = 7, domain = "gisements", prio = 80 } }
  local tk = O.sort_tasks({ { key = "ghost:oil:1", kind = "ghost", prio = 40, project = 7 }, { key = "craft:x", kind = "craft", prio = 30 } }, projects)
  check(tk[1].pole == "extraction" and tk[2].pole == "base", "fantôme d'un projet Pétrole : pôle Extraction (domaine du projet)")
  local pe = O.pick_task({ id = 1, role = "executant", pole = "extraction" }, tk)
  local pb = O.pick_task({ id = 2, role = "executant", pole = "base" }, tk)
  check(pe == 1 and pb == 2, "l'exécutant de l'extraction prend le fantôme du projet ; celui de la base, sa fabrication")
  local dp = O.demand_from_tasks({ { key = "g", kind = "ghost", prio = 40, project = 7 } }, nil, O.project_domains(projects))
  check(dp.poles[1] == 60 and dp.poles[2] == 0, "besoin : le fantôme du projet compte à l'extraction")
end

---------------------------------------------------------------------------------------------------
section("Déterminisme")
local team30 = make_team(30, 5, { 10, 10, 5 })
local base_in = { tick = 36000, npcs = team30, need = BIG, orientation = "equilibre", chiefs = 5,
  zones = { { id = 1, prio = 50 }, { id = 2, prio = 10 } },
  projects = { { id = 1, domain = "production", prio = 80 }, { id = 2, domain = "gisements", prio = 70 } } }
local o1, o2 = O.plan(base_in), O.plan(base_in)
check(ser(o1) == ser(o2), "deux passages identiques")
local shuffled = deep(base_in)
shuffled.npcs = shuffle(shuffled.npcs)
shuffled.projects = shuffle(shuffled.projects)
shuffled.zones = shuffle(shuffled.zones)
check(ser(O.plan(shuffled)) == ser(o1), "ordre d'entrée mélangé (PNJ, projets, zones) : résultat identique")
local copy = deep(base_in)
check(ser(O.plan(copy)) == ser(o1), "copie profonde (sauvegarde puis rechargement) : résultat identique")
check(ser(base_in.npcs) == ser(team30), "l'entrée n'est pas modifiée")
check(ser(o1):find("FONCTION") == nil, "résultat sans fonction (sérialisable dans global)")
check(o1.idle_rate == 1, "taux d'inactivité calculé (tous inoccupés : 1)")
do
  local a = { id = 1, pole = "base", dest = "extraction" }
  check(O.effective_pole(a) == "extraction", "pôle effectif = destination différée")
  check(O.settle(a, 500) and a.pole == "extraction" and a.dest == nil and a.moved_tick == 500, "fin de tâche : la destination devient le pôle, délai de garde daté")
  check(not O.settle(a, 600) and a.moved_tick == 500, "fin de tâche sans destination : rien ne change")
end

---------------------------------------------------------------------------------------------------
section("Hystérésis, convergence et stabilité")
do
  -- Équipe mal répartie (tous les exécutants à la base) : elle converge, à 2 mouvements par pensée au plus.
  local npcs = make_team(30, 5, { 0, 25, 0 })
  local tick, max_moves, conv = 36000, 0, nil
  for k = 1, 200 do
    local out = O.plan({ tick = tick, npcs = npcs, need = BIG, orientation = "equilibre", chiefs = 5 })
    if #out.moves > max_moves then max_moves = #out.moves end
    apply(npcs, out, tick)
    local c = count_poles(npcs)
    if not conv and math.abs(c[1] - out.targets[1]) <= 1 and math.abs(c[2] - out.targets[2]) <= 1
      and math.abs(c[3] - out.targets[3]) <= 1 then conv = k end
    tick = tick + 300
  end
  check(max_moves <= O.MAX_MOVES, "au plus " .. O.MAX_MOVES .. " mouvements par pensée (vu : " .. max_moves .. ")")
  check(conv ~= nil, "convergence vers les cibles à 1 près (pensée n° " .. tostring(conv) .. ")")
  -- Une fois convergée, entrée constante : plus aucun mouvement pendant 100 pensées.
  local extra = 0
  for _ = 1, 100 do
    local out = O.plan({ tick = tick, npcs = npcs, need = BIG, orientation = "equilibre", chiefs = 5 })
    extra = extra + #out.moves + #out.gen_moves
    apply(npcs, out, tick)
    tick = tick + 300
  end
  check(extra == 0, "entrée constante après convergence : 0 mouvement en 100 pensées (vu : " .. extra .. ")")
  -- Écart de 1 : pas de mouvement (pas de va-et-vient d'une unité).
  local one = make_team(30, 5, { 11, 9, 5 })
  local out1 = O.plan({ tick = 0, npcs = one, need = BIG, orientation = "equilibre", chiefs = 5 })
  check(#out1.moves == 0, "écart de 1 de chaque côté : aucun mouvement")
end
do
  -- Ordres contradictoires à CHAQUE pensée pendant 1 h, équipe inoccupée : au plus 6 changements par PNJ
  -- (exécutants ET généralistes) par heure glissante.
  local npcs = make_team(30, 5, { 10, 10, 5 })
  local tick, changes, total = 0, {}, 0
  for k = 1, 720 do
    local out = O.plan({ tick = tick, npcs = npcs, need = BIG, orientation = (k % 2 == 0) and "ressources" or "protection", chiefs = 5 })
    for _, id in ipairs(apply(npcs, out, tick)) do
      changes[id] = changes[id] or {}
      changes[id][#changes[id] + 1] = tick
      total = total + 1
    end
    tick = tick + 300
  end
  local worst = worst_window(npcs, changes)
  check(worst <= 6, "orientation inversée à chaque pensée (720 pensées, équipe inoccupée) : au plus 6 changements par PNJ et par heure glissante, généralistes compris (pire : " .. worst .. ")")
  check(total <= 6 * 30, "total des changements borné : " .. total .. " <= 180")
end
do
  -- Bascule de la menace à chaque pensée (« Ressources » : quotas 2/2/1 <-> 2/1/2) : les généralistes aussi
  -- sont tenus par le délai de garde.
  local npcs = make_team(30, 5, { 10, 10, 5 })
  local tick, changes, gen_changes = 0, {}, 0
  for k = 1, 720 do
    local out = O.plan({ tick = tick, npcs = npcs, need = BIG, orientation = "ressources", threatened = (k % 2 == 0), chiefs = 5 })
    gen_changes = gen_changes + #out.gen_moves
    for _, id in ipairs(apply(npcs, out, tick)) do
      changes[id] = changes[id] or {}
      changes[id][#changes[id] + 1] = tick
    end
    tick = tick + 300
  end
  local worst = worst_window(npcs, changes)
  check(worst <= 6, "menace basculée à chaque pensée pendant 1 h : au plus 6 changements par PNJ et par heure glissante (pire : " .. worst .. ", généralistes : " .. gen_changes .. " changements en tout)")
end
do
  -- Même épreuve avec une équipe AU TRAVAIL (0 inactif, tâches de 60 s) : changements différés appliqués en fin
  -- de tâche, délai de garde compté depuis le changement effectif.
  local npcs = make_team(30, 5, { 10, 10, 5 })
  local changes, interrupted = simulate(npcs, { thoughts = 720, dur = DUR, idle_ids = {},
    input = function(k) return { need = BIG, orientation = (k % 2 == 0) and "ressources" or "protection", chiefs = 5 } end })
  local worst = worst_window(npcs, changes)
  check(not interrupted, "équipe au travail : aucun PNJ occupé déplacé en cours de tâche (720 pensées)")
  check(worst <= 6, "équipe au travail, orientation inversée à chaque pensée : au plus 6 changements par PNJ et par heure glissante (pire : " .. worst .. ")")
end

---------------------------------------------------------------------------------------------------
section("Réaction avec une équipe OCCUPÉE à 85 % ou plus (mouvements différés, fins de tâche échelonnées)")
local react = {}
for _, idle_n in ipairs({ 0, 3, 4 }) do
  -- 0, 3 et 4 inactifs sur 30 : 0 %, 10 % et 13 % (le critère C5-2 vise 15 % au plus).
  local label = idle_n .. " inactif(s) sur 30"
  local donors_be = { base = true, territoire = true }
  -- 1. Curseur « Ressources » (le levier « concentrer nos efforts »).
  do
    local npcs = make_team(30, 5, { 10, 10, 5 })
    local before = count_poles(npcs)[1]
    local target, dec_at, act_at
    local changes, interrupted = simulate(npcs, { thoughts = 30, dur = DUR, idle_ids = pick_idle(npcs, idle_n, donors_be),
      input = function() return { need = BIG, orientation = "ressources", chiefs = 5 } end,
      after = function(k, out, team)
        target = out.targets[1]
        if not dec_at and math.abs(out.assigned[1] - target) <= 1 then dec_at = k end
        if not act_at and math.abs(count_poles(team)[1] - target) <= 1 then act_at = k end
      end })
    check(target >= before + 3, label .. " : curseur « Ressources », cible de l'extraction " .. before .. " -> " .. target)
    check(dec_at and dec_at <= 2, label .. " : curseur, affectations à la cible à 1 près en " .. tostring(dec_at) .. " pensée(s) (<= 2)")
    check(act_at and act_at <= 2 + DUR, label .. " : curseur, effectifs AU TRAVAIL à la cible à 1 près en " .. tostring(act_at) .. " pensées (<= 2 + une tâche de 12)")
    check(not interrupted, label .. " : curseur, aucun travail interrompu")
    react[#react + 1] = string.format("curseur %s : décisions %d pensée(s), au travail %d pensées", label, dec_at or -1, act_at or -1)
  end
  -- 2. Crise : avant-poste de fer perdu, le travail d'extraction explose (C5-2 : +3 en 2 pensées).
  do
    local npcs = make_team(30, 5, { 10, 10, 5 })
    local before = count_poles(npcs)[1]
    local dec2, act_at
    local _, interrupted = simulate(npcs, { thoughts = 30, dur = DUR, idle_ids = pick_idle(npcs, idle_n, donors_be),
      input = function() return { need = { 9000, 1500, 1500 }, orientation = "equilibre", chiefs = 5 } end,
      after = function(k, out, team)
        if k == 2 then dec2 = out.assigned[1] end
        if not act_at and count_poles(team)[1] >= before + 3 then act_at = k end
      end })
    check(dec2 >= before + 3, label .. " : crise, +3 affectés à l'extraction en 2 pensées (" .. before .. " -> " .. dec2 .. ")")
    check(act_at and act_at <= 2 + DUR, label .. " : crise, +3 AU TRAVAIL à l'extraction en " .. tostring(act_at) .. " pensées (<= 14)")
    check(not interrupted, label .. " : crise, aucun travail interrompu")
    react[#react + 1] = string.format("crise %s : +%d affectés en 2 pensées, +3 au travail en %d pensées", label, dec2 - before, act_at or -1)
  end
  -- 3. Menace : la cible du territoire monte, les affectations suivent.
  do
    local npcs = make_team(30, 5, { 10, 10, 5 })
    local before = count_poles(npcs)[3]
    local target, dec_at
    simulate(npcs, { thoughts = 20, dur = DUR, idle_ids = pick_idle(npcs, idle_n, { extraction = true, base = true }),
      input = function() return { need = BIG, orientation = "equilibre", threatened = true, chiefs = 5 } end,
      after = function(k, out)
        target = out.targets[3]
        if not dec_at and math.abs(out.assigned[3] - target) <= 1 then dec_at = k end
      end })
    check(target > before and dec_at and dec_at <= 2, label .. " : menace, territoire " .. before .. " -> " .. target .. " affectés en " .. tostring(dec_at) .. " pensée(s)")
  end
  -- 4. Zone nouvelle : 4 zones de 2 PNJ, plancher 8 au territoire (5 aujourd'hui).
  do
    local npcs = make_team(30, 5, { 10, 10, 5 })
    local zones = { { id = 1, prio = 40 }, { id = 2, prio = 30 }, { id = 3, prio = 20 }, { id = 4, prio = 10 } }
    local dec_at, crews_full
    simulate(npcs, { thoughts = 30, dur = DUR, idle_ids = pick_idle(npcs, idle_n, { extraction = true, base = true }),
      input = function() return { need = BIG, orientation = "equilibre", zones = zones, chiefs = 5 } end,
      after = function(k, out)
        if not dec_at and out.assigned[3] >= 7 then dec_at = k end
        if not crews_full and #out.zone_short == 0 then crews_full = k end
      end })
    check(dec_at and dec_at <= 2, label .. " : zones nouvelles, territoire affecté à 8 à 1 près en " .. tostring(dec_at) .. " pensée(s)")
    check(crews_full and crews_full <= 3, label .. " : les 4 équipes de zone nommées au complet en " .. tostring(crews_full) .. " pensée(s)")
  end
end
for _, line in ipairs(react) do print("   " .. line) end
do
  -- Donneur le plus excédentaire tout occupé : les inoccupés d'un autre donneur passent d'abord (effet immédiat).
  local mixed = make_team(30, 5, { 4, 14, 7 })
  for _, a in ipairs(mixed) do if a.role == "executant" and a.pole == "base" then a.idle = false end end
  local mo = O.plan({ tick = 0, npcs = mixed, need = BIG, orientation = "equilibre", chiefs = 5 })
  local from_terr = #mo.moves > 0
  for _, m in ipairs(mo.moves) do if m.from ~= "territoire" or m.to ~= "extraction" or m.deferred then from_terr = false end end
  check(from_terr, "base excédentaire mais toute occupée : les " .. #mo.moves .. " mouvements immédiats viennent des inoccupés du territoire")
  -- Tous occupés : des mouvements DIFFÉRÉS (aucun travail interrompu), au plus 2.
  local npcs = make_team(30, 5, { 10, 10, 5 })
  for _, a in ipairs(npcs) do a.idle = false end
  local busy = O.plan({ tick = 0, npcs = npcs, need = BIG, orientation = "protection", chiefs = 5 })
  local all_def = #busy.moves == 2
  for _, m in ipairs(busy.moves) do if not m.deferred then all_def = false end end
  check(all_def, "tous occupés : 2 mouvements différés (appliqués en fin de tâche), aucun immédiat")
  -- Un PNJ déjà en partance n'est pas redésigné, et il compte déjà dans son pôle de destination.
  for _, m in ipairs(busy.moves) do find(npcs, m.id).dest = m.to end
  local again = O.plan({ tick = 300, npcs = npcs, need = BIG, orientation = "protection", chiefs = 5 })
  local twice = false
  for _, m in ipairs(again.moves) do for _, m0 in ipairs(busy.moves) do if m.id == m0.id then twice = true end end end
  check(not twice and again.assigned[3] >= busy.assigned[3], "un PNJ en partance n'est pas redésigné ; il compte dans son pôle de destination")
  -- Recrues sans pôle : placées aussitôt là où il manque du monde.
  local fresh = make_team(30, 5, { 10, 10, 5 })
  for _, a in ipairs(fresh) do if a.id > 27 then a.pole = nil end end
  local pl = O.plan({ tick = 0, npcs = fresh, need = BIG, orientation = "equilibre", chiefs = 5 })
  check(#pl.place == 3, "3 recrues sans pôle placées dans la même pensée")
end

---------------------------------------------------------------------------------------------------
section("Zones : équipes nommées, plancher borné, priorité")
do
  local npcs = make_team(30, 5, { 10, 10, 5 })
  local zones = {}
  for i = 1, 12 do zones[i] = { id = i, prio = 100 - i } end
  local out = O.plan({ tick = 0, npcs = npcs, need = BIG, orientation = "equilibre", zones = zones, chiefs = 5 })
  check(out.targets[3] == 12 and out.targets[2] > 0, "12 zones, 25 exécutants : territoire 12 (50 %), la base n'est pas vidée " .. ser(out.targets))
  check(out.warnings[1] == "trop_de_zones", "avertissement « trop de zones pour l'effectif »")
  -- Convergence (équipe inoccupée) : les 6 zones les plus prioritaires ont 2 PNJ nommés, les 6 autres aucun.
  local tick = 0
  for _ = 1, 20 do
    out = O.plan({ tick = tick, npcs = npcs, need = BIG, orientation = "equilibre", zones = zones, chiefs = 5 })
    apply(npcs, out, tick)
    tick = tick + 300
  end
  local full, short = 0, 0
  for i, c in ipairs(out.crews) do
    if i <= 6 and #c.npcs == 2 then full = full + 1 end
    if i > 6 and #c.npcs == 0 then short = short + 1 end
  end
  check(full == 6 and short == 6 and #out.zone_short == 6, "12 zones : les 6 plus prioritaires tenues par 2 PNJ nommés, 6 signalées sous effectif")
  local again = O.plan({ tick = tick, npcs = npcs, need = BIG, orientation = "equilibre", zones = zones, chiefs = 5 })
  check(ser(again.crews) == ser(out.crews), "équipes de zone stables d'une pensée à l'autre")
  -- Une zone peu prioritaire a SES PNJ, qui prennent ses tâches d'abord.
  local z3 = make_team(30, 5, { 10, 10, 5 })
  local zl = { { id = 1, prio = 80 }, { id = 2, prio = 50 }, { id = 3, prio = 5 } }
  local tk = 0
  local o3
  for _ = 1, 10 do
    o3 = O.plan({ tick = tk, npcs = z3, need = BIG, orientation = "equilibre", zones = zl, chiefs = 5 })
    apply(z3, o3, tk)
    tk = tk + 300
  end
  local crew3 = o3.crews[3]
  check(crew3.zone == 3 and #crew3.npcs == 2, "zone de priorité 5 : 2 PNJ nommés (" .. ser(crew3.npcs) .. ")")
  local tasks = O.sort_tasks({
    { key = "refill:hq", kind = "refill", prio = 95 },
    { key = "zone_ring:1", kind = "zone_ring", prio = 80, zone = 1 },
    { key = "zone_ring:3", kind = "zone_ring", prio = 10, zone = 3 },
  })
  local m3 = find(z3, crew3.npcs[1])
  local i3 = O.pick_task(m3, tasks)
  check(i3 and tasks[i3].key == "zone_ring:3", "un PNJ de la zone 3 prend la tâche de SA zone (10) avant celle de la zone 1 (80) et l'urgence (95)")
  local other = { id = 999, role = "executant", pole = "territoire" }
  local io = O.pick_task(other, tasks)
  check(io and tasks[io].key == "refill:hq", "un exécutant du territoire sans zone prend l'urgence")
end

---------------------------------------------------------------------------------------------------
section("Généralistes : promotion, pôles de référence, meneurs")
do
  local npcs = make_team(30, 5, { 10, 10, 5 })
  -- Un généraliste meurt : il en reste 4 pour 5 voulus.
  local alive = {}
  for _, a in ipairs(npcs) do if a.id ~= 3 then alive[#alive + 1] = a end end
  local tick = 100000
  local early = O.plan({ tick = tick, npcs = alive, need = BIG, chiefs = 5, vacancy_since = tick - 60 * 60 })
  check(early.promote == nil, "généraliste mort il y a 1 min : pas encore de promotion")
  local due = O.plan({ tick = tick, npcs = alive, need = BIG, chiefs = 5, vacancy_since = tick - 2 * 3600 })
  local best
  for _, a in ipairs(alive) do
    if a.role == "executant" and (not best or a.rank > best.rank or (a.rank == best.rank and (a.xp > best.xp or (a.xp == best.xp and a.id < best.id)))) then best = a end
  end
  check(due.promote == best.id, "après 2 min : promotion du meilleur exécutant (rang, XP, id) : " .. tostring(due.promote))
  check(#due.gen_poles == 5, "5 généralistes après promotion")
  local growth = O.plan({ tick = tick, npcs = alive, need = BIG, chiefs = 5 })
  check(growth.promote ~= nil, "croissance (pas de mort) : promotion immédiate")
  local full = O.plan({ tick = tick, npcs = npcs, need = BIG, chiefs = 5 })
  check(full.promote == nil and full.generalists_wanted == 5, "5 généralistes sur 30 : aucune promotion")
end
check(ser(O.generalist_quotas(5, { 40, 40, 20 })) == ser({ 2, 2, 1 }), "quotas 5 généralistes, équilibre : 2/2/1")
check(ser(O.generalist_quotas(5, { 47, 47, 6 })) == ser({ 3, 2, 0 }), "technocrate (territoire 6 %) : 3/2/0")
check(ser(O.generalist_quotas(2, O.normalize("protection"))) == ser({ 0, 1, 1 }), "2 généralistes, « Protection » : territoire puis base")
check(ser(O.generalist_quotas(3, { 40, 40, 20 })) == ser({ 1, 1, 1 }), "3 généralistes, 3 pôles >= 15 % : un chacun")
do
  -- Stabilité des pôles de référence : changer l'orientation déplace le minimum de généralistes.
  local npcs = make_team(30, 5, { 10, 10, 5 })
  local o1 = O.plan({ tick = 0, npcs = npcs, need = BIG, orientation = "equilibre", chiefs = 5 })
  apply(npcs, o1, 0)
  local o1b = O.plan({ tick = 0, npcs = npcs, need = BIG, orientation = "equilibre", chiefs = 5 })
  check(ser(o1b.gen_poles) == ser(o1.gen_poles), "pôles des généralistes stables à orientation constante")
  local before = {}
  for _, gp in ipairs(o1.gen_poles) do before[gp.id] = gp.pole end
  local o2 = O.plan({ tick = 0, npcs = npcs, need = BIG, orientation = "protection", chiefs = 5 })
  local changed = 0
  for _, gp in ipairs(o2.gen_poles) do if before[gp.id] ~= gp.pole then changed = changed + 1 end end
  local q1, q2 = O.generalist_quotas(5, O.normalize("equilibre")), O.generalist_quotas(5, O.normalize("protection"))
  local minimal = 0
  for p = 1, 3 do if q2[p] > q1[p] then minimal = minimal + q2[p] - q1[p] end end
  check(changed == minimal and #o2.gen_moves == minimal, "« Protection » : " .. changed .. " généraliste(s) change(nt) de pôle, le minimum (" .. minimal .. ")")
  -- Délai de garde : un généraliste changé il y a 5 min garde son pôle, même au-delà du quota.
  apply(npcs, o2, 0)
  local o3 = O.plan({ tick = 5 * 3600, npcs = npcs, need = BIG, orientation = "equilibre", chiefs = 5 })
  local held = true
  for _, gm in ipairs(o2.gen_moves) do for _, gm3 in ipairs(o3.gen_moves) do if gm.id == gm3.id then held = false end end end
  check(held, "généraliste changé il y a 5 min : il garde son pôle (délai de garde de 10 min)")
end
do
  local npcs = make_team(30, 5, { 10, 10, 5 })
  local o0 = O.plan({ tick = 0, npcs = npcs, need = BIG, chiefs = 5 })
  apply(npcs, o0, 0)
  local projects = {
    { id = 1, domain = "production", prio = 60 }, { id = 2, domain = "gisements", prio = 90, started = true },
    { id = 3, domain = "defense", prio = 50 }, { id = 4, domain = "logistique", prio = 85 },
    { id = 5, domain = "infrastructures", prio = 40 }, { id = 6, domain = "production", prio = 70 },
    { id = 7, domain = "gisements", prio = 30 },
  }
  local out = O.plan({ tick = 0, npcs = npcs, need = BIG, chiefs = 5, projects = projects })
  check(#out.leaders == 5 and #out.waiting == 2, "7 projets, 5 généralistes : 5 menés, 2 en attente")
  local led, uniq = {}, true
  for _, l in ipairs(out.leaders) do
    if led[l.npc] then uniq = false end
    led[l.npc] = l.project
  end
  check(uniq, "un généraliste mène un seul projet")
  local waiting = ser(out.waiting)
  check(waiting == ser({ 5, 7 }), "les 2 projets les moins prioritaires attendent : " .. waiting)
  local pole_of = {}
  for _, gp in ipairs(out.gen_poles) do pole_of[gp.id] = gp.pole end
  local first = out.leaders[1]
  check(first.project == 2 and pole_of[first.npc] == "extraction", "le projet le plus prioritaire (gisements) va à un généraliste de l'extraction")
  -- Stabilité : les priorités changent, les meneurs restent.
  for _, pr in ipairs(projects) do
    for _, l in ipairs(out.leaders) do if l.project == pr.id then pr.leader = l.npc end end
  end
  projects[5].prio = 99
  local out2 = O.plan({ tick = 300, npcs = npcs, need = BIG, chiefs = 5, projects = projects })
  local kept = 0
  for _, l in ipairs(out2.leaders) do
    for _, l1 in ipairs(out.leaders) do if l1.project == l.project and l1.npc == l.npc then kept = kept + 1 end end
  end
  check(kept == 5 and ser(out2.waiting) == ser({ 5, 7 }), "priorités changées : les 5 meneurs gardent leur projet (pas de reprise en cours de route)")
  -- Mort d'un meneur : son projet passe au premier généraliste libre à la pensée suivante… s'il y en a un.
  local dead = out.leaders[1].npc
  local alive = {}
  for _, a in ipairs(npcs) do if a.id ~= dead then alive[#alive + 1] = a end end
  local out3 = O.plan({ tick = 600, npcs = alive, need = BIG, chiefs = 5, projects = projects, vacancy_since = 600 })
  local p2_led = false
  for _, l in ipairs(out3.leaders) do if l.project == 2 then p2_led = true end end
  check(not p2_led and out3.promote == nil, "meneur mort, aucun généraliste libre : le projet attend (mode dégradé), pas de promotion avant 2 min")
  local out4 = O.plan({ tick = 600 + 2 * 3600, npcs = alive, need = BIG, chiefs = 5, projects = projects, vacancy_since = 600 })
  check(out4.promote ~= nil, "2 min plus tard : un exécutant est promu")
  local promoted = deep(alive)
  find(promoted, out4.promote).role = "generalist"
  local out5 = O.plan({ tick = 600 + 2 * 3600 + 300, npcs = promoted, need = BIG, chiefs = 5, projects = projects })
  for _, l in ipairs(out5.leaders) do if l.project == 2 then p2_led = l.npc == out4.promote end end
  check(p2_led, "le promu reprend le chantier COMMENCÉ orphelin (90 + 20) avant le nouveau projet de priorité 99")
end

---------------------------------------------------------------------------------------------------
section("Prise de tâche : urgence avant le pôle, un seul passage sur une liste triée une fois")
do
  local tasks = O.sort_tasks({
    { key = "plan_module:1", kind = "plan_module", prio = 50, project = 1 },
    { key = "refill:hq", kind = "refill", prio = 95 },
    { key = "mine:iron-ore", kind = "mine", prio = 30 },
    { key = "craft:gear:1", kind = "craft", prio = 50 },
    { key = "service:3", kind = "service", prio = 70 },
    { key = "ghost:1", kind = "ghost", prio = 40, project = 2 },
    { key = "taken", kind = "craft", prio = 99, worker = 42 },
  })
  check(tasks[1].key == "taken" and tasks[2].key == "refill:hq", "tri : priorité décroissante puis clé")
  local function pick(npc, ctx)
    local i = O.pick_task(npc, tasks, ctx)
    return i and tasks[i].key or "rien"
  end
  local full = { urgent_away = 5, urgent_away_cap = 5 } -- plafond des PNJ hors pôle atteint
  check(pick({ id = 1, role = "executant", pole = "base" }) == "refill:hq", "exécutant de la base : l'urgence d'un autre pôle (95) avant sa fabrication (50)")
  check(pick({ id = 1, role = "executant", pole = "base" }, full) == "craft:gear:1", "plafond hors pôle atteint : la fabrication, jamais la conception")
  check(pick({ id = 2, role = "executant", pole = "extraction" }) == "refill:hq", "exécutant de l'extraction : l'urgence (95) avant la tournée (70) et le minage (30)")
  check(pick({ id = 2, role = "executant", pole = "extraction" }, full) == "service:3", "plafond hors pôle atteint : la tournée (70) avant le minage (30)")
  local capped = { manual_busy = { portage = 5, minage = 1 }, manual_cap = { portage = 5, minage = 5 }, urgent_away = 5, urgent_away_cap = 5 }
  check(pick({ id = 2, role = "executant", pole = "extraction" }, capped) == "mine:iron-ore", "portage au plafond : la tournée reste au tableau, le PNJ mine")
  local both = { manual_busy = { portage = 5, minage = 5 }, manual_cap = { portage = 5, minage = 5 }, urgent_away = 5, urgent_away_cap = 5 }
  check(pick({ id = 2, role = "executant", pole = "extraction" }, both) == "refill:hq", "tout le manuel au plafond, plafond hors pôle atteint : l'urgence reste prise faute de mieux")
  check(pick({ id = 3, role = "generalist", pole = "territoire", project = 2 }) == "ghost:1", "généraliste : les tâches de SON projet d'abord (même peu prioritaires)")
  check(pick({ id = 4, role = "generalist", pole = "base" }) == "refill:hq", "généraliste sans projet : l'urgence avant la conception de son pôle")
  check(pick({ id = 4, role = "generalist", pole = "base" }, full) == "plan_module:1", "généraliste, plafond hors pôle atteint : la conception de son pôle")
  check(pick({ id = 5, role = "executant", pole = "territoire" }, full) == "refill:hq", "exécutant du territoire : SON urgence, même plafond atteint")
  check(pick({ id = 6, role = "executant", pole = "base", dest = "extraction" }, full) == "service:3", "PNJ en partance pour l'extraction : il ne reprend plus de tâche de la base")
  local only_design = O.sort_tasks({ { key = "open_zone:1", kind = "open_zone", prio = 80 } })
  check(O.pick_task({ id = 6, role = "executant", pole = "territoire" }, only_design) == nil, "exécutant devant une seule tâche de conception : il n'y touche pas")
  local other = O.sort_tasks({ { key = "craft:x", kind = "craft", prio = 50 } })
  check(O.pick_task({ id = 7, role = "executant", pole = "territoire" }, other) == nil, "exécutant : pas de tâche ordinaire d'un autre pôle (hystérésis du cerveau)")
  check(O.pick_task({ id = 8, role = "generalist", pole = "territoire" }, other) == 1, "généraliste : n'importe quelle tâche faute de mieux (ouvrier à part entière)")
end
do
  -- Régression évitée (correcteur) : un exécutant ou un généraliste de l'extraction préférait le minage (20) au
  -- ravitaillement (95).
  local tk = O.sort_tasks({ { key = "mine:iron", kind = "mine", prio = 20 }, { key = "refill:hq", kind = "refill", prio = 95 } })
  local ie = O.pick_task({ id = 1, role = "executant", pole = "extraction" }, tk)
  local ig = O.pick_task({ id = 2, role = "generalist", pole = "extraction" }, tk)
  check(tk[ie].key == "refill:hq" and tk[ig].key == "refill:hq", "extraction (exécutant et généraliste) : ravitaillement 95 avant minage 20")
  -- Son urgence d'abord, à rang égal : l'avant-poste à sec (service 95) de l'extraction avant la recharge d'ailleurs.
  local both = O.sort_tasks({ { key = "refill:hq", kind = "refill", prio = 95 }, { key = "service:2", kind = "service", prio = 95 } })
  local i2 = O.pick_task({ id = 3, role = "executant", pole = "extraction" }, both)
  check(both[i2].key == "service:2", "deux urgences : celle de son pôle d'abord (combustible de l'avant-poste)")
  -- Avant-poste à court de combustible servi par la base.
  local fuel = O.sort_tasks({ { key = "craft:gear", kind = "craft", prio = 50 }, { key = "service:2", kind = "service", prio = 95 } })
  local ib, away = O.pick_task({ id = 4, role = "executant", pole = "base" }, fuel)
  check(fuel[ib].key == "service:2" and away, "avant-poste à sec (service 95) : servi par un exécutant de la base (hors pôle compté)")
  -- Sous attaque, exécutants du territoire tous occupés (garnisons) : 6 recharges, 10 exécutants de la base
  -- libres ; la limite hors pôle (5 pour 25 exécutants) laisse la base travailler.
  local board = {}
  for i = 1, 6 do board[#board + 1] = { key = "refill:" .. i, kind = "refill", prio = 90 } end
  for i = 1, 10 do board[#board + 1] = { key = "craft:" .. string.format("%02d", i), kind = "craft", prio = 50 } end
  O.sort_tasks(board)
  local ctx = { urgent_away = 0, urgent_away_cap = O.urgent_away_cap(25) }
  local refills, crafts = 0, 0
  for id = 1, 10 do
    local i, aw = O.pick_task({ id = id, role = "executant", pole = "base" }, board, ctx)
    board[i].worker = id
    if board[i].kind == "refill" then refills = refills + 1 else crafts = crafts + 1 end
    if aw then ctx.urgent_away = ctx.urgent_away + 1 end
  end
  check(O.urgent_away_cap(25) == 5 and refills == 5 and crafts == 5, "sous attaque, territoire occupé : 5 recharges servies par la base (limite 20 %), 5 restent à leur fabrication")
  check(O.urgent_away_cap(4) == 2 and O.urgent_away_cap(0) == 2, "limite hors pôle : au moins 2")
end

---------------------------------------------------------------------------------------------------
section("Jetons de travail par tick, partagés à tour de rôle entre les équipes")
check(ser(O.share_tokens(10, { 5, 5, 5 }, 1)) == ser({ 4, 3, 3 }), "10 jetons, 3 équipes à 5 : 4/3/3 à partir de l'équipe 1")
check(ser(O.share_tokens(10, { 5, 5, 5 }, 2)) == ser({ 3, 4, 3 }), "à partir de l'équipe 2 : 3/4/3")
check(ser(O.share_tokens(10, { 0, 20, 1 }, 1)) == ser({ 0, 9, 1 }), "demande nulle sautée, le reste à qui en veut")
check(ser(O.share_tokens(10, { 1, 1, 1 }, 1)) == ser({ 1, 1, 1 }), "demande totale sous le budget : tout est servi")
check(ser(O.share_tokens(0, { 3, 3 }, 1)) == ser({ 0, 0 }) and #O.share_tokens(5, {}, 1) == 0, "budget nul ou aucune équipe")
do
  local ok = true
  for _ = 1, 500 do
    local n = rnd(6)
    local d = {}
    local sd = 0
    for i = 1, n do d[i] = rnd(30) - 1; sd = sd + d[i] end
    local total = rnd(40) - 1
    local s = O.share_tokens(total, d, rnd(9))
    local sum = 0
    for i = 1, n do
      sum = sum + s[i]
      if s[i] > d[i] or s[i] < 0 then ok = false end
    end
    if sum ~= math.min(total, sd) then ok = false end
    for i = 1, n do
      if s[i] < d[i] then
        for j = 1, n do if s[j] > s[i] + 1 then ok = false end end
      end
    end
  end
  check(ok, "500 tirages : somme = min(budget, demandes), chacune <= sa demande, équité à 1 près")
  local acc = { 0, 0, 0, 0, 0 }
  for tick = 0, 99 do
    local s = O.share_tokens(O.TICK_BUDGET, { 1000, 1000, 1000, 1000, 1000 }, tick % 5 + 1)
    for i = 1, 5 do acc[i] = acc[i] + s[i] end
  end
  check(acc[1] == acc[5] and acc[1] * 5 == 100 * O.TICK_BUDGET, "100 ticks, 5 équipes saturées : budget global tenu, parts égales (" .. acc[1] .. " chacune)")
end

---------------------------------------------------------------------------------------------------
section("Tailles 10 / 30 / 50 / 60 et coût de calcul compté")
local ops_of = {}
for _, n in ipairs({ 10, 30, 50, 60 }) do
  local chiefs = n >= 50 and 8 or 5
  local npcs = make_team(n, chiefs)
  local projects = {}
  for i = 1, 12 do projects[i] = { id = i, domain = O.DOMAINS[(i - 1) % 5 + 1].key, prio = 100 - i } end
  local tasks = {}
  for i = 1, 3 * n do
    local kinds_list = { "craft", "service", "mine", "refill", "ghost", "upgrade", "carry", "plan_module" }
    tasks[i] = { key = "t" .. i, kind = kinds_list[(i - 1) % #kinds_list + 1], prio = (i * 13) % 100, project = (i % 4 == 0) and (i % 12 + 1) or nil }
  end
  local zones = { { id = 1, prio = 50 }, { id = 2, prio = 20 } }
  local out = O.plan({ tick = 0, npcs = npcs, tasks = tasks, orientation = "equilibre", chiefs = chiefs, projects = projects, zones = zones })
  local g = O.generalists_wanted(n, chiefs)
  check(sum3(out.targets) == n - g, string.format("%d PNJ : %d généralistes, cibles %s (somme %d)", n, g, ser(out.targets), n - g))
  check(#out.gen_poles == g and #out.leaders == math.min(g, #projects), string.format("%d PNJ : %d meneurs", n, #out.leaders))
  ops_of[n] = out.ops
  local bound = 50 * n + 20 * #projects + 25 * #tasks + 300
  check(out.ops <= bound, string.format("%d PNJ, %d tâches, %d projets, 2 zones : %d unités de travail <= %d", n, #tasks, #projects, out.ops, bound))
end
check(ops_of[60] <= 8 * ops_of[10], string.format("croissance presque linéaire : 60 PNJ = %.1f × 10 PNJ (<= 8)", ops_of[60] / ops_of[10]))
print(string.format("   unités de travail par pensée : 10 PNJ %d, 30 PNJ %d, 50 PNJ %d, 60 PNJ %d", ops_of[10], ops_of[30], ops_of[50], ops_of[60]))

---------------------------------------------------------------------------------------------------
section("Résurrection, recrutement (option la moins chère), coût d'une mort")
local r1 = O.resurrection(1, 1, nil)
check(ser(r1.cost) == ser({ { "firearm-magazine", 10 }, { "iron-plate", 25 }, { "pistol", 1 } }) and r1.ticks == 600,
  "rang 1, époque 1 : kit + 25 fer, 10 s : " .. ser(r1))
local r3 = O.resurrection(3, 2, "steel-plate")
check(ser(r3.cost) == ser({ { "firearm-magazine", 10 }, { "iron-plate", 75 }, { "pistol", 1 }, { "steel-plate", 6 } }) and r3.ticks == 1800,
  "rang 3, époque 2 : kit + 75 fer + 6 acier, 30 s")
local r5 = O.resurrection(5, 6, "battery")
check(ser(r5.cost) == ser({ { "battery", 10 }, { "firearm-magazine", 10 }, { "iron-plate", 125 }, { "pistol", 1 } }) and r5.ticks == 3000,
  "rang 5, époque 6 : kit + 125 fer + 10 batteries, 50 s")
check(ser(O.resurrection(5, 6, "battery", 0).cost) == ser({ { "firearm-magazine", 10 }, { "pistol", 1 } }), "multiplicateur 0 : le kit seul")
check(O.resurrection(1, 1, nil, 2).cost[2][2] == 50, "multiplicateur 2 : 50 fer au rang 1")
check(O.resurrection(2, 1, "steel-plate").cost[3] == nil or O.resurrection(2, 1, "steel-plate").cost[3][1] == "pistol", "époque 1 : jamais de matériau d'époque")
check(ser(O.resurrection(2, 3, "iron-plate").cost) == ser({ { "firearm-magazine", 10 }, { "iron-plate", 54 }, { "pistol", 1 } }), "matériau = fer : lignes fusionnées (50 + 4)")
check(O.resurrection(9, 1).ticks == 3000 and O.resurrection(0, 1).ticks == 600, "rang hors bornes ramené à 1..5")
check(O.resurrection_slots(0) == 1 and O.resurrection_slots(4) == 1 and O.resurrection_slots(5) == 2 and O.resurrection_slots(15) == 4,
  "résurrections simultanées : 1, plus 1 tous les 5 niveaux du centre")
check(ser(O.recruit_cost(0)) == ser({ { "firearm-magazine", 10 }, { "iron-plate", 10 }, { "pistol", 1 } }), "recrue n° 1 : kit + 10 fer")
check(O.recruit_cost(30)[2][2] == 40 and O.recruit_cost(29)[2][2] == 39, "recrue à 30 PNJ : kit + 40 fer")
do
  -- Piège évité : ceil(10 × (1 + 0,1 × h)) donne 25 au lieu de 24 pour h = 14 en flottant (9 valeurs fausses
  -- entre 0 et 60). Le modèle calcule 10 + h.
  local exact = true
  for h = 0, 60 do if O.recruit_cost(h)[2][2] ~= 10 + h then exact = false end end
  check(exact, "recrue : 10 + effectif plaques, exact pour 0 à 60 PNJ (arithmétique entière)")
end
local MU = { pistol = 10, ["firearm-magazine"] = 4 } -- recettes vanilla : 5 fer + 5 cuivre ; 4 fer (plaque = 1 MU)
local res1 = O.cost_value(r1.cost, MU)
check(res1 == 75 and O.cost_value(O.recruit_cost(10), MU) == 70, "valeurs : résurrection rang 1 = 75 MU ; recrue à 10 PNJ = 70 MU")
check(O.revive_policy(1, true, true, res1, O.cost_value(O.recruit_cost(10), MU)) == "recruit", "rang 1, 10 PNJ : la recrue (70) est moins chère que la résurrection (75)")
check(O.revive_policy(1, true, true, res1, O.cost_value(O.recruit_cost(20), MU)) == "resurrect", "rang 1, 20 PNJ : la résurrection (75) est moins chère que la recrue (80)")
check(O.revive_policy(1, true, true, 75, 75) == "resurrect", "rang 1, égalité : on ressuscite (nom et expérience gardés)")
check(O.revive_policy(1, true, true) == "resurrect", "rang 1 sans valeurs : on ressuscite")
check(O.revive_policy(2, true, true, 100, 70) == "resurrect", "rang 2 et plus : on ressuscite (l'expérience vaut au moins 30 min de travail)")
check(O.revive_policy(4, false, true) == "recruit", "résurrection impayable : on recrute")
check(O.revive_policy(1, true, false) == "resurrect", "recrue impayable : on ressuscite")
check(O.revive_policy(3, false, false) == "wait", "rien n'est payable : on attend")
do
  local cheapest = true
  for h = 0, 60 do
    local rec = O.cost_value(O.recruit_cost(h), MU)
    local choice = O.revive_policy(1, true, true, res1, rec)
    if (choice == "recruit") ~= (rec < res1) then cheapest = false end
  end
  check(cheapest, "rang 1, effectif de 0 à 60 : la politique choisit toujours l'option la moins chère")
end
check(ser(r5):find("FONCTION") == nil, "coût sérialisable")
do
  -- Coût d'une mort en secondes du débit NOMINAL du joueur X0 (débit moyen de l'époque) ; l'équipe produit m fois
  -- plus (m non mesuré) : diviser par m. Valeurs en MU : plaque 1, pistolet 10, chargeur 4, monnaie d'époque X0.
  print("   coût d'une résurrection en secondes de débit nominal X0 (rang 1 / 3 / 5) :")
  local ok = true
  for _, e in ipairs({ 1, 2, 3, 4, 6, 10, 15 }) do
    local c = X.currency_of(e)
    local vals = { pistol = 10, ["firearm-magazine"] = 4 }
    if c then vals[c.item] = c.value end
    local line = {}
    for _, r in ipairs({ 1, 3, 5 }) do
      local v = O.cost_value(O.resurrection(r, e, c and c.item).cost, vals)
      line[#line + 1] = string.format("%d MU = %.1f s", v, v / X.rate_avg(e))
      if v <= 0 then ok = false end
    end
    print(string.format("     époque %2d (%.0f MU/s) : %s", e, X.rate_avg(e), table.concat(line, " ; ")))
  end
  check(ok, "coût d'une mort chiffré pour 7 époques (table du §9)")
end

---------------------------------------------------------------------------------------------------
section("Progression des PNJ et comparaison au joueur")
local ranks = { { 0, 1 }, { 29, 1 }, { 30, 2 }, { 119, 2 }, { 120, 3 }, { 359, 3 }, { 360, 4 }, { 899, 4 }, { 900, 5 }, { 1e6, 5 } }
for _, c in ipairs(ranks) do check(O.rank(c[1]) == c[2], string.format("%d XP -> rang %d", c[1], c[2])) end
local xp, carry = O.gain(0, 0, 3600, false)
check(xp == 1 and carry == 0, "1 min de travail = 1 XP")
xp, carry = O.gain(0, 0, 1800, true)
check(xp == 1 and carry == 0, "conception : 30 s comptent 1 min")
xp, carry = O.gain(0, 0, 1800, false)
xp, carry = O.gain(xp, carry, 1800, false)
check(xp == 1 and carry == 0, "le reste est conservé d'une tâche à l'autre")
local m1 = O.modifiers(1, "leger")
check(m1.character_crafting_speed_modifier == 0 and m1.character_running_speed_modifier == 0
  and m1.character_mining_speed_modifier == 0 and m1.character_inventory_slots_bonus == 0,
  "rang 1 : exactement le joueur (fabrication, course, minage, inventaire)")
check(m1.character_build_distance_bonus == nil and m1.character_reach_distance_bonus == nil and O.SCRIPT_BUILD_DISTANCE == 16,
  "aucun bonus de portée écrit (sans effet sur LuaEntity.revive) : distance de 16 tuiles contrôlée par le script")
local m5 = O.modifiers(5, "leger")
check(m5.character_crafting_speed_modifier == 2 and m5.character_mining_speed_modifier == 1.5
  and m5.character_running_speed_modifier == 0.15 and m5.character_inventory_slots_bonus == 40,
  "rang 5, profil léger : fabrication ×3, minage ×2,5, course +15 %, +40 cases")
local e5 = O.modifiers(5, "egal")
check(e5.character_crafting_speed_modifier == 0 and e5.character_running_speed_modifier == 0, "profil égal : aucun bonus")
local f5 = O.modifiers(5, "fort")
check(f5.character_crafting_speed_modifier == 3 and f5.character_running_speed_modifier == 0.15 and f5.character_inventory_slots_bonus == 60,
  "profil fort : ×4 en fabrication, course plafonnée à +15 %, +60 cases")
check(O.modifiers(3, "leger", "merciless").character_crafting_speed_modifier > O.modifiers(3, "leger", "easy").character_crafting_speed_modifier,
  "Impitoyable > Facile (bonus multipliés par la difficulté)")
local mono_ok, run_ok = true, true
for _, prof in ipairs({ "egal", "leger", "fort" }) do
  for _, dif in ipairs({ "peaceful", "easy", "normal", "hard", "merciless", "__nil" }) do
    local d = dif ~= "__nil" and dif or nil
    local prev
    for r = 1, 5 do
      local m = O.modifiers(r, prof, d)
      if m.character_running_speed_modifier > O.RUN_CAP then run_ok = false end
      if prev then
        for _, k in ipairs(O.MODIFIER_ORDER) do if m[k] < prev[k] then mono_ok = false end end
      end
      prev = m
    end
  end
end
check(run_ok, "course : jamais plus de +15 % (« légèrement plus vite »), tous profils, rangs et difficultés")
check(mono_ok, "chaque modificateur croît avec le rang (3 profils × 6 difficultés)")
-- Chiffres de comparaison (référence vanilla relue dans data/base/prototypes/entity/entities.lua).
print(string.format("   course joueur 0,15 tuile/tick ; PNJ rang 5 : %.4f ; minage joueur 0,5 ; PNJ rang 5 : %.2f ; inventaire 80 / %d",
  0.15 * (1 + m5.character_running_speed_modifier), 0.5 * (1 + m5.character_mining_speed_modifier), 80 + m5.character_inventory_slots_bonus))

---------------------------------------------------------------------------------------------------
section("Règle d'automatisation et plafonds de travail manuel")
check(O.needs_automation(61, 11, 64), "61/min, 11 min, 64 tuiles : tapis ou conduite")
check(not O.needs_automation(60, 11, 64), "60/min : porteurs")
check(not O.needs_automation(100, 10, 30), "besoin de 10 min seulement : porteurs")
check(not O.needs_automation(100, 30, 65), "plus de 64 tuiles : porteurs (trains et longs tapis hors IA1)")
check(O.manual_cap(25, 1) == 12 and O.manual_cap(25, 2) == 5 and O.manual_cap(25, 9) == 5, "plafond manuel : 12 à l'époque 1, puis 5 sur 25 (20 %)")
check(O.manual_cap(3, 2) == 1 and O.manual_cap(0, 2) == 1, "plafond manuel : au moins 1")

---------------------------------------------------------------------------------------------------
section("Amélioration instantanée : combien de bâtiments en un trajet")
do
  local cost = { { "steel-plate", 20 }, { "iron-gear-wheel", 10 } }
  local costs = {}
  for i = 1, 6 do costs[i] = cost end
  local stack = { ["steel-plate"] = 100, ["iron-gear-wheel"] = 100 }
  local served, take = O.trip_capacity(costs, stack, 2)
  check(served == 5 and ser(take) == ser({ { "iron-gear-wheel", 50 }, { "steel-plate", 100 } }),
    "2 cases libres : 5 fours sur 6 en un trajet (100 acier + 50 engrenages)")
  local all6 = O.trip_capacity(costs, stack, 3)
  check(all6 == 6, "3 cases : tout le module (6 fours) en un trajet")
  check(O.trip_capacity(costs, stack, 0) == 0, "inventaire plein : aucun")
end

---------------------------------------------------------------------------------------------------
section("Chiffres des maquettes du §8 (époque 4, 24 PNJ vivants, Yanis généraliste de rang 5 disparu)")
do
  check(O.headcount_cap(4, 30) == 30, "§8.3 : plafond de l'époque 4 = 30")
  check(O.generalists_wanted(24, 5) == 4, "§8.1 : 24 vivants -> 4 généralistes (pas 5)")
  check(ser(O.generalist_quotas(4, O.normalize("equilibre"))) == ser({ 2, 1, 1 }), "§8.1 : 4 généralistes en équilibre -> 2/1/1")
  local team = make_team(25, 5, { 8, 8, 4 })
  local alive = {}
  for _, a in ipairs(team) do if a.id ~= 1 then alive[#alive + 1] = a end end -- l'id 1 (généraliste) a disparu
  local out = O.plan({ tick = 0, npcs = alive, need = BIG, orientation = "equilibre", chiefs = 5, vacancy_since = 0 })
  check(out.generalists_wanted == 4 and #out.gen_poles == 4 and out.promote == nil, "§8.1 : avec Yanis disparu, 4 généralistes voulus, aucune promotion")
  check(O.recruit_cost(24)[2][2] == 34, "§8.3 : recruter à 24 PNJ = kit + 34 fer")
  local y = O.resurrection(5, 4, X.currency_of(4).item)
  check(ser(y.cost) == ser({ { "firearm-magazine", 10 }, { "iron-plate", 125 }, { "pistol", 1 }, { "plastic-bar", 10 } }) and y.ticks == 3000,
    "§8.3 : ressusciter Yanis (rang 5, époque 4) = kit + 125 fer + 10 plastiques, 50 s")
end

---------------------------------------------------------------------------------------------------
section("Compatibilité avec le cerveau d'équipe actuel (planner.lua, vraies recettes)")
do
  local book = Book.new(dofile("tests/fixtures/recipes.lua"))
  local stock = {}
  for _, it in ipairs(T.start_kit_generous) do stock[it[1]] = it[2] end
  local view = {
    tech = 0, personality = "balanced", done = { coal = true, iron = true, copper = true, stone = true }, deferred = {},
    stock = stock, incoming = {},
    outposts = {
      { id = 1, kind = "coal", drills = 4, turrets = 0, fuel_low = false, output = 60, idle_ticks = 0, has_task = false },
      { id = 2, kind = "iron", drills = 8, turrets = 0, fuel_low = true, output = 10, idle_ticks = 0, has_task = false },
      { id = 3, kind = "copper", drills = 3, turrets = 0, fuel_low = false, output = 50, idle_ticks = 0, has_task = false },
      { id = 4, kind = "stone", drills = 2, turrets = 0, fuel_low = false, output = 0, idle_ticks = 0, has_task = false },
    },
    pending = {}, sites = { coal = 1, iron = 1, copper = 1, stone = 1 },
    smelters = 2, smelters_pending = 0, smelter_task = false, smelter_output = 5, smelter_fuel_low = false, smelter_coal = 10,
    turret_groups = { { key = "hq", low = 2, has_task = false } },
    soldiers = 0, soldiers_max = 100, workers = 8, workers_max = 30, workers_idle = 4, threatened = false, open = {},
  }
  local plan = Planner.plan(view, book)
  check(#plan.tasks > 0, "le cerveau actuel produit " .. #plan.tasks .. " tâches")
  local d = O.demand_from_tasks(plan.tasks)
  local known = true
  for _, t in ipairs(plan.tasks) do if not O.TASK_DOMAIN[t.kind] then known = false end end
  check(known, "chaque tâche du cerveau actuel a un domaine et un pôle")
  local dsum = 0
  for _, dom in ipairs(O.DOMAINS) do dsum = dsum + d.domains[dom.key] end
  check(dsum == sum3(d.poles) and dsum > 0, "travail par domaine = travail par pôle (" .. dsum .. " s)")
  local npcs = make_team(30, 5, { 10, 10, 5 })
  local out = O.plan({ tick = 0, npcs = npcs, tasks = plan.tasks, orientation = O.PERSONALITY.balanced, chiefs = 5 })
  check(sum3(out.targets) == 25, "cibles calculées sur le vrai tableau : " .. ser(out.targets) .. ", surplus " .. out.surplus)
  print(string.format("   tableau actuel : %d tâches, %d s de travail (extraction %d, base %d, territoire %d) ; %d exécutants au-delà du carnet à 5 min",
    #plan.tasks, dsum, d.poles[1], d.poles[2], d.poles[3], out.surplus))
  -- Constat H-E1 (pourquoi l'échelle stagne avant le pack chimique) : le moteur de fabrication à la main ne
  -- sait pas faire le moteur (catégorie advanced-crafting) ni le plastique (chimie) : il faut des machines.
  check(not book:handcraftable("engine-unit") and not book:handcraftable("plastic-bar") and not book:handcraftable("sulfur"),
    "H-E1 : moteur, plastique et soufre ne se fabriquent pas à la main (il faut un atelier ou un assembleur, une usine chimique, du pétrole)")
  check(book:handcraftable("electronic-circuit") and book:handcraftable("advanced-circuit"),
    "circuits verts et rouges se fabriquent à la main… si le plastique existe")
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
