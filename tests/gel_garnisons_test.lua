--[[
  Lot X10-GEL, garnisons (Q7), au MOTEUR SIMULÉ (monde factice écrit ici : soldats, tourelles, ennemis, forces). Ce n'est pas une preuve
  en jeu : le micro-banc `x10-gel-garnison` la fait (L1_CRITERES.md §4, C12 à C17). Ici, la chaîne de script/faction/gel_garnisons.lua :
    N1  au calme, joueur loin : figés à Gel.CALM ticks de calme exactement (pas avant) ; jamais figés : escorte, blessé, en route, robot,
        soldat d'un groupe ;
    N2  coup reçu par un mur de la faction, par un soldat figé : TOUS ses soldats figés réveillés dans le gestionnaire (même tick) ;
        coup sur un biter, sur une autre faction : rien ; puis Gel.CALM ticks de calme avant un nouveau gel (cause « attaque ») ;
    N3  ennemi à moins de G.HQ_R du QG, dans la boîte d'un amas de tourelles, tourelle qui tire (filet), alerte d'armée, alerte de
        site : toute la garnison réveillée au guet suivant ;
    N4  ennemi près d'un poste de garde loin du QG : ce poste seul réveillé ;
    N5  joueur à 220 tuiles d'un poste : réveillé au guet suivant ; à 240 tuiles d'un poste figé : reste figé (hystérésis) ;
    N6  ordre changé (clé), groupe, crochet Gel.before_command (même tick) ;
    N7  mort d'un bâtiment de l'équipe : réveil au tick même ;
    N8  réglage éteint : tout réveillé ; données changées : tout réveillé, état vidé ; votre équipe jamais figée ;
    N9  `destructible` jamais écrit ; seul `active` change ; requêtes par guet bornées ;
    N10 déterminisme : deux passages, mêmes journaux ;
    N13 faction anéantie sans mort vue, guerre arrêtée : tout réveillé au guet suivant (relecture de revue-s, 8/11) ;
    N14 portées fines du guet (C19, 8/11 : mesure seulement) fermées sous leur nom, au sommet ; portées et compteurs vus ;
    N15 guets étalés (C19, décision du lead du 8/11) : garnisons aux ticks impairs de la période (1 : commun ; 3 : faction 1) ;
    Mutants (texte de gel_garnisons.lua changé) : tous vus, dont « destructible mis à false au gel » (demande du lead, 7/11).
  Usage : lua5.2 tests/gel_garnisons_test.lua   (depuis la racine du mod ; shared/faction/cadence.lua de x10-s10 requis)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local quiet = false
local function check(c, msg)
  if c then ok_n = ok_n + 1; if not quiet and os.getenv("FO_VERBOSE") then print("[GEL-GARNISONS] OK : " .. msg) end
  else fail_n = fail_n + 1; if not quiet then print("[GEL-GARNISONS] ECHEC : " .. msg) end end
  return c
end

local SRC_PATH = "script/faction/gel_garnisons.lua"
local fh = assert(io.open(SRC_PATH, "rb"))
local SOURCE = fh:read("*a")
fh:close()

---------------------------------------------------------------------------------------------------
-- Monde factice
---------------------------------------------------------------------------------------------------
local W

local function entity(o)
  W.un = W.un + 1
  local e = { valid = true, unit_number = W.un, name = o.name, type = o.type, force = { name = o.force or "fo-a" },
    position = { x = o.x, y = o.y }, _active = true, _health = o.health or 1, surface = W.surface }
  e.get_health_ratio = function() return rawget(e, "_health") end
  setmetatable(e, { __index = function(t, k)
    if k == "active" then return rawget(t, "_active") end
    return nil
  end, __newindex = function(t, k, v)
    if k == "active" then rawset(t, "_active", v); W.writes = W.writes + 1; return end
    if k == "destructible" then W.destructible = W.destructible + 1 end
    rawset(t, k, v)
  end })
  W.ents[#W.ents + 1] = e
  return e
end

local function in_q(p, q)
  if q.area then return p.x >= q.area[1][1] and p.x <= q.area[2][1] and p.y >= q.area[1][2] and p.y <= q.area[2][2] end
  local dx, dy = p.x - q.position.x, p.y - q.position.y
  return dx * dx + dy * dy <= q.radius * q.radius
end
local function has(list, x)
  if type(list) == "string" then return list == x end
  for _, y in ipairs(list or {}) do if y == x then return true end end
  return false
end

local function new_world()
  W = { un = 1000, ents = {}, foes = {}, writes = 0, destructible = 0, tick = 0, logs = {}, store = {}, queries = 0 }
  W.surface = { index = 1 }
  W.surface.count_entities_filtered = function(q)
    W.queries = W.queries + 1
    local n = 0
    for _, e in ipairs(W.foes) do
      if e.valid and has(q.type, e.type) and has(q.force, e.force.name) and in_q(e.position, q) then n = n + 1 end
    end
    return n
  end
  local function force(name, enemies)
    return { name = name, is_enemy = function(other) return enemies[other.name] == true end }
  end
  game = { tick = 0, connected_players = {}, surfaces = { [1] = W.surface },
    forces = { ["fo-a"] = force("fo-a", { enemy = true, ["fo-b"] = true }), ["fo-b"] = force("fo-b", { enemy = true, ["fo-a"] = true }),
      enemy = force("enemy", { ["fo-a"] = true, ["fo-b"] = true, player = true }), player = force("player", { enemy = true }) },
    entity_prototypes = { ["gun-turret"] = { attack_parameters = { range = 18 } } } }
  W.player = { valid = true, surface = W.surface, position = { x = 5000, y = 5000 } }
  game.connected_players = { W.player }
end

defines = { events = { on_entity_damaged = 101, on_entity_died = 102 } }
settings = { global = { ["fo-war-gel"] = { value = true } } }
log = function(s) W.logs[#W.logs + 1] = s end

---------------------------------------------------------------------------------------------------
-- Modules réels du lot, sur un bus d'événements et un stockage factices
---------------------------------------------------------------------------------------------------
-- Pile du profileur factice (portées start/stop et fines) ; PROF.bad compte les fermetures hors du sommet ou sans ouverture.
PROF = { stack = {}, bad = 0, seen = {}, cnt = {} }
function prof_open(n)
  PROF.stack[#PROF.stack + 1] = n
  PROF.seen[n] = true
  if n == "gel:garnisons" then -- ticks de la période qui portent un guet (C19 : guets étalés)
    PROF.at = PROF.at or {}
    PROF.at[game.tick % 20] = true
  end
end
function prof_close(n)
  if PROF.stack[#PROF.stack] == n then PROF.stack[#PROF.stack] = nil else PROF.bad = PROF.bad + 1 end
end
--- Portées du profileur factice depuis le dernier PROF neuf : toutes fermées sous leur nom, au sommet ; portées et compteurs attendus vus
--- (C19, 8/11 : instrumentation fine du guet, sans décision changée).
function prof_check(tag, scopes, counters)
  local miss = {}
  for _, n in ipairs(scopes) do if not PROF.seen[n] then miss[#miss + 1] = n end end
  for _, n in ipairs(counters) do if not ((PROF.cnt[n] or 0) > 0) then miss[#miss + 1] = "#" .. n end end
  return #miss == 0 and PROF.bad == 0 and #PROF.stack == 0, string.format("%s : portees fermees sous leur nom (%d hors du sommet, %d ouverte(s)) ; vues : %s",
    tag, PROF.bad, #PROF.stack, #miss == 0 and "toutes" or ("MANQUENT " .. table.concat(miss, " ")))
end
local H
local function load_mod(src)
  H = { on = {}, nth = {}, died = {}, config = {} }
  for _, m in ipairs({ "script.core.events", "script.core.storage", "script.core.profiler", "script.faction.state", "script.faction.gel",
    "script.faction.gel_garnisons", "script.ai3.comportement", "shared.faction.gel" }) do package.loaded[m] = nil end
  package.loaded["script.core.events"] = {
    on = function(id, fn) H.on[id] = H.on[id] or {}; table.insert(H.on[id], fn) end,
    on_nth_tick = function(n, fn) H.nth[n] = H.nth[n] or {}; table.insert(H.nth[n], fn) end,
    on_died = function(fn, interet) table.insert(H.died, { fn = fn, interet = interet }) end,
    on_init = function() end, on_load = function() end,
    on_configuration_changed = function(fn) table.insert(H.config, fn) end,
  }
  package.loaded["script.core.storage"] = {
    declare = function(name, init) W.store[name] = W.store[name] or init() end,
    ns = function(name) return W.store[name] end,
    raw = function() return W.store end,
  }
  -- Profileur factice : start/stop et portées FINES (C19, 8/11) sur une pile, pour contrôler qu'elles se ferment sous leur nom, au
  -- sommet ; compteurs (fcount) cumulés. PROF est global au fichier (vidé par le seul passage qui le lit).
  package.loaded["script.core.profiler"] = { start = prof_open, stop = prof_close, fstart = prof_open, fstop = prof_close,
    fcount = function(n, k) PROF.cnt[n] = (PROF.cnt[n] or 0) + (k or 1) end }
  package.loaded["script.faction.commander"] = { army_out = function() return W.army_out == true, nil end }
  package.loaded["script.ai3.comportement"] = {
    enabled = function() return true end,
    team = function(f) W.teams[f.id] = W.teams[f.id] or { sd = { per = {} } }; return W.teams[f.id] end,
  }
  local Gel = require("script.faction.gel")
  local Ga
  if src then
    Ga = assert(load(src, "=" .. SRC_PATH))()
    package.loaded["script.faction.gel_garnisons"] = Ga
  else
    Ga = require("script.faction.gel_garnisons")
  end
  return Gel, Ga
end

local function run(n)
  for _ = 1, n do
    W.tick = W.tick + 1
    game.tick = W.tick
    for _, fn in ipairs(H.nth[1] or {}) do fn({ tick = W.tick }) end -- guets étalés (C19) : un abonné par tick
    if W.tick % 20 == 0 then for _, fn in ipairs(H.nth[20] or {}) do fn({ tick = W.tick }) end end
  end
end

local function damage(e, tick)
  for _, fn in ipairs(H.on[defines.events.on_entity_damaged] or {}) do fn({ entity = e, tick = tick or W.tick, final_health = 100 }) end
end
local function died(e)
  for _, d in ipairs(H.died) do
    local types = d.interet and d.interet.types
    if has(types, e.type) and not (d.interet.ennemi == false and e.force.name == "enemy") then d.fn({ entity = e, tick = W.tick }) end
  end
end

--- Faction de banc : QG en (0, 0) ; 6 soldats au QG, 2 gardes en (200, 0) ; escorte, blessé, en route, robot, membre d'un groupe ;
--- 2 tourelles près du QG ; un mur.
local function build(src, opts)
  opts = opts or {}
  new_world()
  W.teams = {}
  local Gel, Ga = load_mod(src)
  local S = W.store
  local f = { id = 1, key = "a", force = "fo-a", hq = { valid = true, surface = W.surface }, hq_pos = { x = 0, y = 0 }, soldiers = {},
    soldiers_count = 0, turrets = {}, is_player = opts.is_player }
  S.war.active, S.war.surface, S.war.factions[1], S.war.by_force["fo-a"] = true, 1, f, 1
  local per = package.loaded["script.ai3.comportement"].team(f).sd.per
  local E = { home = {}, guard = {} }
  local function soldier(x, y, o)
    o = o or {}
    local e = entity({ name = o.name or "fo-scarlet-rifleman", type = "unit", x = x, y = y, health = o.health })
    f.soldiers[e.unit_number] = { entity = e, group = o.group }
    f.soldiers_count = f.soldiers_count + 1
    if o.role then per[e.unit_number] = { role = o.role, key = o.key } end
    return e
  end
  for i = 1, 6 do E.home[i] = soldier(-6 + 2 * i, 14 + (i % 2)) end
  for i = 1, 2 do E.guard[i] = soldier(200 + i, 1, { role = "guard", key = "guard:200:0:" }) end
  E.escort = soldier(2, 12, { role = "escort", key = "escort:2:12:7" })
  E.wounded = soldier(1, 15, { health = 0.6 })
  E.away = soldier(0, 90)
  E.robot = soldier(3, 13, { name = "fo-robot-x" })
  E.grouped = soldier(-1, 13, { group = 55 })
  for i = 1, 2 do
    local t = entity({ name = "gun-turret", type = "ammo-turret", x = -20 + 40 * (i - 1), y = -20 })
    f.turrets[t.unit_number] = t
    E["t" .. i] = t
  end
  E.wall = entity({ name = "stone-wall", type = "wall", x = 0, y = -30 })
  E.biter = entity({ name = "small-biter", type = "unit", x = 4000, y = 4000, force = "enemy" })
  W.foes = { E.biter }
  return f, E, Gel, Ga
end

local function n_frozen(list)
  local n = 0
  for _, e in ipairs(list) do if e.valid and e.active == false then n = n + 1 end end
  return n
end
local function all_soldiers(E)
  local l = {}
  for _, e in ipairs(E.home) do l[#l + 1] = e end
  for _, e in ipairs(E.guard) do l[#l + 1] = e end
  for _, k in ipairs({ "escort", "wounded", "away", "robot", "grouped" }) do l[#l + 1] = E[k] end
  return l
end

---------------------------------------------------------------------------------------------------
-- Scènes
---------------------------------------------------------------------------------------------------
local function cases(src)
  local f0 = fail_n
  PROF = { stack = {}, bad = 0, seen = {}, cnt = {} }
  local CALM = 600
  -- N1
  do
    local f, E = build(src)
    run(600) -- premier guet au tick 20 : calme et aptitude comptés depuis 20 ; gel au guet de 620
    check(n_frozen(all_soldiers(E)) == 0, "N1 : rien de fige avant Gel.CALM ticks de calme (tick 600)")
    run(20)
    check(n_frozen(E.home) == 6 and n_frozen(E.guard) == 2, "N1 : 6 soldats du QG et 2 gardes figes au tick 620 (" .. n_frozen(E.home) .. ", " .. n_frozen(E.guard) .. ")")
    check(E.escort.active and E.wounded.active and E.away.active and E.robot.active and E.grouped.active,
      "N1 : escorte, blesse, en route, robot, membre d'un groupe : jamais figes")
    check(W.destructible == 0, "N9 : destructible jamais ecrit (" .. W.destructible .. ")")
    local q0 = W.queries
    run(20)
    check(W.queries - q0 <= 4, "N9 : requetes d'un guet au calme bornees (" .. (W.queries - q0) .. " : QG, 2 amas, 1 poste loin)")
    -- un soldat qui arrive à son poste déjà figé attend Gel.CALM ticks d'aptitude
    E.away.position = { x = 0, y = 16 }
    run(20 * 29) -- tick 1220 : apte depuis le guet de 660
    check(E.away.active, "N1 : soldat arrive au poste fige : pas fige avant Gel.CALM ticks d'aptitude")
    run(40)
    check(E.away.active == false, "N1 : soldat arrive au poste fige : fige apres Gel.CALM ticks d'aptitude (tick 1260)")
  end
  -- N2 coup reçu
  do
    local f, E = build(src)
    run(640)
    local t = W.tick
    damage(E.biter, t)
    check(n_frozen(all_soldiers(E)) == 8, "N2 : coup sur un biter : rien ne change")
    damage(E.wall, t)
    check(n_frozen(all_soldiers(E)) == 0, "N2 : coup sur un mur de la faction : tous reveilles dans le gestionnaire (meme tick)")
    run(880)
    check(n_frozen(all_soldiers(E)) == 0, "N2 : apres un coup, rien de refige tant que dure la cause attaque (900 ticks)")
    run(900 + 640)
    check(n_frozen(E.home) == 6, "N2 : regel apres le calme (" .. n_frozen(E.home) .. ")")
    damage(E.home[3], W.tick)
    check(n_frozen(all_soldiers(E)) == 0, "N2 : coup sur un soldat FIGE : toute la garnison reveillee au tick meme")
  end
  -- N3 menaces de faction
  do
    local cases3 = {
      { "ennemi a 50 tuiles du QG", function(E) E.biter.position = { x = 50, y = 0 } end },
      { "ennemi dans la boite d'un amas de tourelles (a 68 tuiles du QG)", function(E) E.biter.position = { x = 48, y = -48 } end },
      { "tourelle qui tire (filet)", function(E) E.t2.shooting_target = E.biter end },
      { "alerte d'armee", function(E, f) f.armee = { alert = true } end },
      { "alerte de site", function(E, f) W.teams[1].alerts = { { x = 0, y = 0, ["until"] = W.tick + 100 } } end },
      { "soldat d'une faction ennemie pres du QG", function(E) E.biter.force = { name = "fo-b" }; E.biter.position = { x = 20, y = 40 } end },
    }
    for _, c in ipairs(cases3) do
      local f, E = build(src)
      run(640)
      local before = n_frozen(all_soldiers(E))
      c[2](E, f)
      run(20)
      check(before == 8 and n_frozen(all_soldiers(E)) == 0, "N3 : " .. c[1] .. " : toute la garnison reveillee au guet suivant")
    end
    local f, E = build(src)
    run(640)
    E.biter.position = { x = 0, y = -95 } -- hors des boîtes des amas (portée 18 + marge 12) et à 95 tuiles du QG
    run(20)
    check(n_frozen(E.home) == 6, "N3 : ennemi a 95 tuiles du QG, loin des tourelles : la garnison reste figee")
  end
  -- N4 menace d'un poste loin du QG
  do
    local f, E = build(src)
    run(640)
    E.biter.position = { x = 200, y = 40 }
    run(20)
    check(n_frozen(E.guard) == 0 and n_frozen(E.home) == 6, "N4 : ennemi a 40 tuiles du poste de garde : ce poste seul reveille")
  end
  -- N5 joueur
  do
    local f, E = build(src)
    run(640)
    W.player.position = { x = 200 + 220 + 0.5, y = 0 }
    run(20)
    check(n_frozen(E.guard) == 0 and n_frozen(E.home) == 6, "N5 : joueur a 220 tuiles du poste de garde : reveille au guet suivant, le QG reste fige")
    check(W.store.gel.gar.stats.why["joueur proche"] == 2, "N5 : cause du reveil : joueur proche (" .. tostring(W.store.gel.gar.stats.why["joueur proche"]) .. ")")
    local f2, E2 = build(src)
    run(640)
    W.player.position = { x = 200 + 240 + 0.5, y = 0 }
    run(100)
    check(n_frozen(E2.guard) == 2, "N5 : joueur a 240 tuiles d'un poste fige : reste fige (hysteresis)")
  end
  -- N6 ordres
  do
    local f, E, Gel = build(src)
    run(640)
    W.teams[1].sd.per[E.guard[1].unit_number].key = "guard:180:0:"
    f.soldiers[E.home[1].unit_number].group = 77
    run(20)
    check(E.guard[1].active and E.home[1].active and n_frozen(E.home) == 5, "N6 : ordre change (cle) et groupe : reveilles au guet suivant")
    local why = W.store.gel.gar.stats.why
    check(why.ordre == 1 and why.groupe == 1, "N6 : causes lues : ordre " .. tostring(why.ordre) .. ", groupe " .. tostring(why.groupe))
    Gel.before_command(E.home[2])
    check(E.home[2].active and n_frozen(E.home) == 4, "N6 : crochet Gel.before_command : reveille au tick meme, les autres restent figes")
  end
  -- N7 mort
  do
    local f, E = build(src)
    run(640)
    E.wall.valid = true
    died(E.wall)
    check(n_frozen(all_soldiers(E)) == 0, "N7 : mort d'un mur de l'equipe : reveil au tick meme")
    local f2, E2 = build(src)
    run(640)
    E2.biter.position = { x = 4000, y = 4000 }
    died(E2.biter)
    check(n_frozen(E2.home) == 6, "N7 : mort d'un biter : rien")
  end
  -- N8 réglage, données, votre équipe
  do
    local f, E = build(src)
    run(640)
    settings.global["fo-war-gel"].value = false
    run(20)
    check(n_frozen(all_soldiers(E)) == 0, "N8 : reglage eteint : tout reveille au guet suivant")
    run(1300)
    check(n_frozen(all_soldiers(E)) == 0, "N8 : reglage eteint : plus rien de fige")
    settings.global["fo-war-gel"].value = true
    local f2, E2 = build(src)
    run(640)
    for _, fn in ipairs(H.config) do fn({}) end
    check(n_frozen(all_soldiers(E2)) == 0 and W.store.gel.gar.n == 0, "N8 : donnees changees : tout reveille, etat vide")
    local f3, E3 = build(src, { is_player = true })
    run(1300)
    check(n_frozen(all_soldiers(E3)) == 0, "N8 : votre equipe : jamais figee")
  end
  -- N11 invariant : un soldat figé ne reste jamais dans un poste éveillé (état incohérent posé à la main)
  do
    local f, E = build(src)
    run(640)
    W.store.gel.gar.posts[1].home.st.frozen, W.store.gel.gar.posts[1].home.st.calm = false, nil
    run(20)
    check(n_frozen(E.home) == 0, "N11 : poste eveille avec des soldats figes : reveilles au guet suivant")
  end
  -- N13 faction anéantie (hors de State.alive) SANS mort vue (QG détruit par script) : rien ne reste figé (relecture de revue-s)
  do
    local f, E = build(src)
    run(640)
    f.eliminated = true
    run(20)
    check(n_frozen(all_soldiers(E)) == 0, "N13 : faction aneantie sans mort vue : tous reveilles au guet suivant")
    local f2, E2 = build(src)
    run(640)
    W.store.war.active = false
    run(20)
    check(n_frozen(all_soldiers(E2)) == 0, "N13 : guerre arretee : tous reveilles au guet suivant")
  end
  -- N14 instrumentation fine du guet (C19) : portées fermées, portées et compteurs vus
  check(prof_check("N14", { "gel:garnisons", "gel:reveil", "gel:gar:soldats", "gel:gar:menaces", "gel:gar:listes", "gel:gar:tirs", "gel:gar:req",
    "gel:gar:regle", "gel:gar:aptitude", "gel:gar:entrees" }, { "gel:soldats", "gel:postes", "gel:requetes", "gel:tourelles", "gel:aptes_lus" }))
  -- N15 (C19) : guets étalés : le guet des garnisons ne tombe qu'aux ticks 1 (commun) et 3 (faction 1) de la période de 20, jamais à
  -- un tick pair (ceux des usines)
  do
    local at, ks, bad = PROF.at or {}, {}, 0
    for k = 0, 19 do if at[k] then ks[#ks + 1] = k; if k ~= 1 and k ~= 3 then bad = bad + 1 end end end
    check(bad == 0 and at[1] and at[3], "N15 : guet des garnisons aux ticks 1 (commun) et 3 (faction 1) de la periode seulement (" .. table.concat(ks, ",") .. ")")
  end
  return fail_n - f0
end

---------------------------------------------------------------------------------------------------
-- Déroulé
---------------------------------------------------------------------------------------------------
cases(nil)
-- N10 déterminisme
do
  local function trace()
    local f, E = build(nil)
    run(640)
    damage(E.wall, W.tick)
    run(1800)
    E.biter.position = { x = 30, y = 0 }
    run(40)
    local out = table.concat(W.logs, "\n")
    for _, e in ipairs(all_soldiers(E)) do out = out .. (e.active and "1" or "0") end
    return out
  end
  local a, b = trace(), trace()
  check(a == b and #a > 0, "N10 : deux passages : memes journaux et memes etats")
end
-- N12 coût d'un guet en instructions Lua (debug.sethook : déterministe ; monde factice compris). Coût MARGINAL par soldat (8/11, C19) :
-- même partie à 13 puis à 65 soldats (52 de plus, aptes), écart divisé par 52 ; le coût fixe d'une période (abonné de chaque tick
-- depuis l'étalement des guets, boucle du banc, profileur factice) s'annule. Avant l'étalement, la mesure divisait le TOTAL par 65
-- (104 instructions par soldat au guet figé) ; à l'étalement, le total par 65 est passé à 121 sans travail de plus par soldat.
do
  local function play(extra)
    local f = build(nil)
    for i = 1, extra do
      local e = entity({ name = "fo-scarlet-rifleman", type = "unit", x = -8 + (i % 8) * 2, y = 10 + math.floor(i / 8) })
      f.soldiers[e.unit_number] = { entity = e }
      f.soldiers_count = f.soldiers_count + 1
    end
    local function cost(n)
      local c = 0
      debug.sethook(function() c = c + 1 end, "", 1)
      run(n)
      debug.sethook()
      return c
    end
    local c1 = cost(20)
    run(600)
    local c2 = cost(20)
    return c1, c2, f.soldiers_count
  end
  local a1, a2, na = play(0)
  local b1, b2, nb = play(52)
  local per1, per2 = (b1 - a1) / (nb - na), (b2 - a2) / (nb - na)
  print(string.format("[GEL-GARNISONS] cout : %d soldats, guet au calme %d, guet fige %d ; %d soldats, %d et %d : %.0f et %.0f instructions par soldat de plus (total par soldat a %d : %.0f et %.0f)",
    na, a1, a2, nb, b1, b2, per1, per2, nb, b1 / nb, b2 / nb))
  check(per1 <= 200 and per2 <= 120, string.format("N12 : guet borne (%.0f et %.0f instructions par soldat de plus ; seuils 200 et 120)", per1, per2))
end
-- N9 statique
do
  check(not SOURCE:find("destructible%s*="), "N9 : gel_garnisons.lua n'ecrit jamais destructible")
  local n = 0
  for line in SOURCE:gmatch("[^\n]+") do
    if line:find("pairs%(") and not line:find("ipairs%(") and not line:find("game%.forces") then n = n + 1 end
  end
  check(n == 0, "N9 : aucun pairs hors de la liste triee des forces (" .. n .. ")")
end

local MUTANTS = {
  { "destructible mis a false au gel", "local function freeze(a, vid, id, e, post, tick)\n  e.active = false",
    "local function freeze(a, vid, id, e, post, tick)\n  e.active = false\n  e.destructible = false" },
  { "coup recu ignore", "    wake_view(a, vid, \"degat\", e.tick)\n", "" },
  { "mort ignoree", "    wake_view(a, vid, \"perte\", e.tick)\n", "" },
  { "menace de faction ignoree", "fh = faction_hazard(a, vid, view, L, tick)", "fh = nil" },
  { "menace du poste ignoree", "if not fup and not hz then hz = post_hazard(a, view, L, p.pt) end", "" },
  { "aptitude ignoree", "        if unfit then\n          a.el[m.id] = nil", "        if false then\n          a.el[m.id] = nil" },
  { "calme du soldat ignore", "tick - el.t >= G.CALM and", "true and" },
  { "ordre change ignore", "if r and (sl.group or not garrison or r.post ~= post) then", "if r and (sl.group or not garrison) then" },
  { "robot fige", "local garrison = G.GARRISON_ROLES[role] ~= nil and NAMES[e.name] == true", "local garrison = G.GARRISON_ROLES[role] ~= nil" },
  { "filet des tourelles coupe", "if t.valid and t.shooting_target ~= nil then firing = true; break end", "" },
  { "amas de tourelles ignores", "      return \"ennemi pres des tourelles\"", "      return nil" },
  { "poste eveille garde ses figes", "if not p.st.frozen then wake_one(a, vid, m.id, \"poste eveille\") end", "" },
  { "reveil du poste ignore", "        if m.frozen and wake_one(a, vid, m.id, o.cause or \"reveil\") then", "        if false then" },
  { "faction disparue ignoree", "if type(vid) == \"number\" and not seen[vid] and a.v[vid].n > 0 then wake_view(a, vid, \"faction disparue\", tick) end", "" },
  { "portee fine non fermee", "  Profiler.fstop(\"gel:gar:regle\")\n", "" },
  { "guet des garnisons aux ticks des usines (C19)", "local who = G.guet_of(tick % G.GUET, \"garnisons\")", "local who = G.guet_of(tick % G.GUET, \"usines\")" },
  { "attaque oubliee (regel immediat)", "s.attack_t, s.lost_t = max_t(s.attack_t, a.hit[fid]), max_t(s.lost_t, a.lost[fid])", "" },
}
quiet = true
local seen, missed = 0, {}
for _, mu in ipairs(MUTANTS) do
  local s, e = SOURCE:find(mu[2], 1, true)
  if not s then missed[#missed + 1] = mu[1] .. " (texte introuvable)" else
    local before = fail_n
    local okc = pcall(cases, SOURCE:sub(1, s - 1) .. mu[3] .. SOURCE:sub(e + 1))
    local died_ = (fail_n > before) or not okc
    fail_n = before
    settings.global["fo-war-gel"].value = true
    if died_ then seen = seen + 1 else missed[#missed + 1] = mu[1] end
  end
end
quiet = false
check(#missed == 0, string.format("mutants : %d/%d vus%s", seen, #MUTANTS, #missed > 0 and (" ; NON VUS : " .. table.concat(missed, " ; ")) or ""))

print(string.format("[GEL-GARNISONS] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
