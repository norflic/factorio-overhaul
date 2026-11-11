--[[
  Lot LOURD (point 2 c, cible 0.6.64 ; fo-logs\2026-11-07_LOURD\CRITERES.md §2, « Partie (c) » ; accord d'effondrement à 4 conditions) :
  les ÉTAPES d'une pensée (script/team/team.lua : E1a dans Team.think, E1b à E6 par le minuteur « fo-team-etape ») prennent le jeton des
  travaux lourds (script/core/lourd.lua, coûts A : tout le budget). Au moteur simulé (tests/mock_engine.lua), vraies étapes.
    T1 étape refusée : RIEN n'est joué à ce tick, la MÊME étape se joue au tick suivant, puis une par tick ; la pensée finit ;
    T2 rattrapage d'un état « E1a en attente » (n = 1 ; condition 1) : votre équipe, Team.think appelé pendant l'attente (budget du tick
       pris) : l'E1a de l'attente puis la suite se jouent d'un bloc, sans erreur (une vue, team:view), et la nouvelle pensée attend à son
       tour ;
    T3 changement de configuration SANS changement de version pendant l'attente (condition 2) : l'état n = 1 (avec sa signature) est
       GARDÉ, puis joué au tick suivant ;
    T4 t0 (condition 3) : l'état rendu par E1a jouée en attente porte t0 = le tick où E1a se JOUE (pas le tick du créneau) ;
    T5 pire cas (condition 4 et borne de CRITERES §2) : 4 factions et votre équipe, réveils (S10, toutes les 97 ticks), et dix
       relevés de banc aux passes du pouls
       (période 5, coûts 32 et 152) en plus des vrais : aucun tick au-delà du budget ; plus longue attente d'une étape ≤ 7 ticks ; durée
       d'une pensée ≤ 103 ticks (13 étapes au plus, E1b rejouée par la décision de capitalisation comprise) ;
    T7 entrées périmées (décision du lead du 8/11, trou relevé par effondrement ; Lourd.drop) : (a) CHANGEMENT DE VERSION avec 5 pensées
       en cours (4 factions et votre équipe, toutes en attente du jeton au tick t) : toutes effacées, aucune entrée « <clé>:etape » ne
       reste en file ; (b) ABANDON (faction éliminée pendant l'attente de son étape) ; (c) votre équipe PREND FIN (coffre perdu :
       Storage.ns("pteam").team = nil, trou relevé par effondrement le 8/11) pendant l'attente de son étape, le créneau mesuré est alors
       celui de la 1re faction. Dans les trois cas, quatre demandeurs par tick
       (« banc ») attendent derrière, puis le créneau de votre équipe arrive : son E1a passe en au plus 7 ticks ; sans Lourd.drop, les
       entrées mortes retiennent tout le budget jusqu'à leur purge (J.STALE) et le créneau prend plus de 7 ticks de retard ;
    T8 relevés à la période du pouls (partie « api.pulse » du point 2 b, gardée sans S10 : la borne de 7 ticks en dépend) : un relevé
       « banc:rv » (période Build.PULSE = 5, coût 32) refusé au tick X ne retient PAS le budget au tick X + 1 : l'E1a de votre équipe y
       passe ; câblage : build.lua passe pulse = Build.PULSE aux deux relevés, chaque prise du jeton des relevés transmet api.pulse.
       Sans la période (relevés à la période 1, comme sur e6eab76c), le T5 joué avec des relevés de banc sans période donne une attente
       d'étape de 35 ticks et une pensée de 559 ticks (mesuré le 8/11, CRITERES §2) ;
    T6 mutants de source : jeton ignoré par une étape ; étape refusée perdue (pas redemandée) ; étape refusée jouée quand même ;
       rattrapage d'un état n = 1 (branche retirée) ; état n = 1 sans signature ; t0 du créneau recopié ; entrée laissée à l'abandon
       (T7 b : retard de plus de 7 ticks) ; entrée laissée à l'effacement (T7 a : idem) ; entrée laissée quand votre équipe prend fin
       (T7 c : idem) ; période ignorée par le jeton (T8 échoue).
  Avec S10 (essai-0664, c3e89e23) : la pensée d'un RÉVEIL passe aussi par E1a (Commander.wake ne prend plus le jeton) ; la garde
  « pensée en cours » de Commander.think (créneau et réveil) est contrôlée par tests/cadence_moteur_test.lua §8 et
  tests/reveil_jeton_test.lua ; les scènes ci-dessous n'en dépendent pas (T1 attend une pensée, endormie ou non).
  Usage : lua5.2 tests/etapes_jeton_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1; if not quiet then print("[ETAPES-JETON] OK : " .. msg) end
  else failures = failures + 1; if not quiet then print("[ETAPES-JETON] ECHEC : " .. msg) end end
  return cond
end
local function W() return M.world() end
local function slurp(p) local h = assert(io.open(p, "rb")) local x = h:read("*a") h:close() return x end
local NL = string.char(10)

--- Monde neuf : guerre de `n` factions, votre équipe (coffre d'équipe), joueur loin ; `mutants` = { { module, path, old, new } }.
local function setup(n, mutants)
  M.new_world({ p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true, raise_damaged = true })
  local pre = {}
  for _, m in ipairs(mutants or {}) do
    local src = slurp(m.path)
    local mold, mnew = m.old, m.new
    local i, j = src:find(mold, 1, true)
    if not i then
      -- Lot TESTS-VERTS : script/team/team.lua mêle des fins de ligne CRLF et LF (P1-ELAGAGE f1f62e9d a passé le retour de l'étape
      -- refusée en CRLF) : le même texte, fins de ligne CRLF
      mold, mnew = mold:gsub(NL, "\r" .. NL), mnew:gsub(NL, "\r" .. NL)
      i, j = src:find(mold, 1, true)
    end
    assert(i, "texte du mutant introuvable dans " .. m.path .. " : " .. m.old)
    assert(not src:find(mold, j + 1, true), "texte du mutant present plusieurs fois : " .. m.old)
    src = src:sub(1, i - 1) .. mnew .. src:sub(j + 1)
    package.preload[m.module] = function() return assert(load(src, "=" .. m.module .. "(mutant)"))() end
    pre[#pre + 1] = m.module
  end
  M.load_mod()
  for _, name in ipairs(pre) do package.preload[name] = nil end
  M.dispatch(W().on_init)
  local char = W().player.character
  char.teleport({ x = 20000, y = 20000 })
  M.command("fo-war", "start " .. n .. " 30 30 320")
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 20005, y = 20005 }, force = "player" })
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  local ctx = { char = char, Lourd = require("script.core.lourd"), Team = require("script.team.team"),
    State = require("script.faction.state"), f = global.fo.war.factions[1] }
  M.run_ticks(2000)
  return ctx
end

local function et_of(f) return f and f.team and f.team.etape end

---------------------------------------------------------------------------------------------------
-- T1 : étape refusée, même étape au tick suivant
---------------------------------------------------------------------------------------------------
--- À la première pensée de la faction dont l'étape attendue est E2 (n = 4), tout le budget est pris au tick de E2.
--- Rend { held, n_at, n_next, done, k } ou nil.
local function scene_refuse(ctx)
  local f = ctx.f
  local guard = 0
  while not (et_of(f) and et_of(f).n == 4) and guard < 1200 do M.run_ticks(1); guard = guard + 1 end
  if not (et_of(f) and et_of(f).n == 4) then return nil end
  local x = game.tick + 1
  local held = ctx.Lourd.take(x, "banc:lourd")
  M.run_ticks(1)
  local n_at = et_of(f) and et_of(f).n
  M.run_ticks(1)
  local n_next = et_of(f) and et_of(f).n
  local k = 0
  while et_of(f) and k < 60 do M.run_ticks(1); k = k + 1 end
  return { held = held, n_at = n_at, n_next = n_next, done = et_of(f) == nil, k = k }
end

---------------------------------------------------------------------------------------------------
-- T2, T3, T4 : votre équipe, E1a en attente
---------------------------------------------------------------------------------------------------
--- Pose un état « E1a en attente » pour votre équipe : tout le budget pris au tick courant X, puis Team.think(X). Rend (f, X).
local function pending_player(ctx)
  local f = ctx.State.faction("player")
  local k = 0
  while et_of(f) and k < 400 do M.run_ticks(1); k = k + 1 end
  if et_of(f) then return nil end
  local X = game.tick
  ctx.Lourd.take(X, "banc:lourd")
  ctx.Team.think(f, f.hq.surface, X, nil)
  return f, X
end

--- T2 : rattrapage pendant l'attente. Rend { pending, views, rt, err, after } .
local function scene_catchup(ctx)
  local f, X = pending_player(ctx)
  if not f then return nil end
  local et = et_of(f)
  local pending = et and et.n == 1 and et.t0 == X
  local Profiler = require("script.core.profiler")
  local views = 0
  local o = Profiler.start
  Profiler.start = function(name, ...)
    if name == "team:view" then views = views + 1 end
    return o(name, ...)
  end
  local rt0 = (f.team.etapes and f.team.etapes.rattrapages) or 0
  local ok, err = pcall(ctx.Team.think, f, f.hq.surface, X, nil)
  Profiler.start = o
  local rt1 = (f.team.etapes and f.team.etapes.rattrapages) or 0
  local after = et_of(f)
  return { pending = pending, views = views, rt = rt1 - rt0, ok = ok, err = err,
    after = after and after.n == 1 and after.t0 == X }
end

--- T3 et T4 : changement de configuration sans changement de version, puis les ticks suivants jusqu'au premier où le jeton est libre
--- pour l'attente (au plus 10). Rend { kept, played, t0, X, at } (at : le tick où E1a s'est jouée).
local function scene_config(ctx)
  local f, X = pending_player(ctx)
  if not f then return nil end
  ctx.Team.etapes_config_changed({ mod_changes = {} })
  local kept = et_of(f) ~= nil and et_of(f).n == 1
  local et, at = et_of(f), nil
  for _ = 1, 10 do
    M.run_ticks(1)
    et = et_of(f)
    if et and et.n >= 2 then at = game.tick break end
  end
  return { kept = kept, played = at ~= nil, t0 = et and et.t0, X = X, at = at }
end

---------------------------------------------------------------------------------------------------
-- T8 : relevés à la période du pouls
---------------------------------------------------------------------------------------------------
--- Au tick X (aucune pensée en cours, hors des créneaux, jeton libre) : tout le budget pris, puis « banc:rv » (période 5, coût 32)
--- refusé, en file. Au tick X + 1, Team.think de votre équipe. Rend { rv, X1, at } (at : tick où son E1a s'est jouée, nil si elle attend).
local function scene_pulse(ctx)
  local Lourd, State = ctx.Lourd, ctx.State
  local pf = State.faction("player")
  local function busy()
    if et_of(pf) then return true end
    for _, id in ipairs(State.sorted_keys(global.fo.war.factions)) do if et_of(global.fo.war.factions[id]) then return true end end
    return false
  end
  local guard = 0
  while (game.tick % 300 < 100 or game.tick % 300 > 140 or busy() or Lourd.left(game.tick) < Lourd.BUDGET) and guard < 1200 do
    M.run_ticks(1)
    guard = guard + 1
  end
  if busy() or Lourd.left(game.tick) < Lourd.BUDGET then return nil end
  local X = game.tick
  Lourd.take(X, "banc:lourd")
  local rv = Lourd.take(X, "banc:rv", 5, 32)
  M.run_ticks(1)
  local X1 = game.tick
  ctx.Team.think(pf, pf.hq.surface, X1, nil)
  local et = et_of(pf)
  return { rv = rv, X1 = X1, at = et and et.n >= 2 and et.t0 or nil }
end

---------------------------------------------------------------------------------------------------
-- T5 : pire cas
---------------------------------------------------------------------------------------------------
local function scene_worst(ctx, ticks)
  local Lourd = ctx.Lourd
  local B = Lourd.BUDGET
  local grants = {}  -- [tick] = { n, sum }
  local runs = {}    -- [demandeur d'étape] = refus de suite en cours
  local nsteps, most = {}, 0 -- étapes servies par pensée en cours (par équipe), la plus longue pensée en étapes
  local worst_wait, refusals, steps = 0, 0, 0
  local o = Lourd.take
  Lourd.take = function(t, who, per, cost)
    local r = o(t, who, per, cost)
    if r then
      local g = grants[t] or { n = 0, sum = 0 }
      grants[t] = g
      g.n = g.n + 1
      g.sum = g.sum + ((Lourd.COSTS and cost) or B)
    end
    if who and who:sub(-6) == ":etape" then
      if r then
        steps = steps + 1
        runs[who] = 0
        nsteps[who] = (nsteps[who] or 0) + 1
      else
        refusals = refusals + 1
        runs[who] = (runs[who] or 0) + 1
        if runs[who] > worst_wait then worst_wait = runs[who] end
      end
    end
    return r
  end
  local teams = {}
  for _, id in ipairs(ctx.State.sorted_keys(global.fo.war.factions)) do teams[#teams + 1] = global.fo.war.factions[id] end
  teams[#teams + 1] = ctx.State.faction("player")
  local start, longest, thinks = {}, 0, 0
  for step = 1, ticks do
    local t = game.tick + 1
    if t % 5 == 0 then
      for i = 1, 10 do Lourd.take(t, "banc:releve" .. i, 5, i <= 5 and 32 or 152) end
    end
    if step % 97 == 0 then for _, f in ipairs(teams) do if not f.is_player then f.lost_t = game.tick end end end -- (réveils, S10)
    M.run_ticks(1)
    for i, f in ipairs(teams) do
      local et = et_of(f)
      if et and not start[i] then start[i] = et.t0 end
      if not et and start[i] then
        local d = game.tick - start[i]
        thinks = thinks + 1
        if d > longest then longest = d end
        start[i] = nil
        local who = tostring(f.key or "player") .. ":etape"
        if (nsteps[who] or 0) > most then most = nsteps[who] end
        nsteps[who] = 0
      end
    end
  end
  Lourd.take = o
  local over = 0
  for _, g in pairs(grants) do if g.n > 1 and g.sum > B then over = over + 1 end end
  return { over = over, worst_wait = worst_wait, refusals = refusals, steps = steps, longest = longest, thinks = thinks, most = most }
end

---------------------------------------------------------------------------------------------------
local ctx = setup(2)
check(ctx.f and ctx.f.hq and ctx.f.hq.valid, "une faction avec son QG")
do
  local r = scene_refuse(ctx)
  check(r and r.held and r.n_at == 4 and r.n_next == 5 and r.done,
    string.format("T1 : budget pris au tick de E2 : rien n'est joué (étape attendue %s), E2 se joue au tick suivant (%s), la pensée finit (%s, en %s ticks)",
      tostring(r and r.n_at), tostring(r and r.n_next), tostring(r and r.done), tostring(r and r.k)))
end
do
  local r = scene_catchup(ctx)
  check(r and r.pending and r.ok and r.views == 1 and r.rt == 1 and r.after,
    string.format("T2 : rattrapage pendant « E1a en attente » (votre équipe) : sans erreur (%s), l'E1a de l'attente jouée (vues %s, attendu 1), la nouvelle pensée de nouveau en attente (budget du tick pris : %s), rattrapage compté (%s)",
      tostring(r and r.ok), tostring(r and r.views), tostring(r and r.after), tostring(r and r.rt)))
end
do
  local r = scene_config(ctx)
  check(r and r.kept and r.played, string.format("T3 : changement de configuration sans changement de version pendant l'attente : état gardé (%s), E1a jouée ensuite (au tick %s)",
    tostring(r and r.kept), tostring(r and r.at)))
  check(r and r.at and r.at > r.X and r.t0 == r.at, string.format("T4 : t0 de l'état rendu = le tick où E1a se joue (%s, joué au tick %s ; créneau %s)",
    tostring(r and r.t0), tostring(r and r.at), tostring(r and r.X)))
end
do
  local r = scene_pulse(ctx)
  check(r and r.rv == false and r.at == r.X1,
    string.format("T8 : « banc:rv » (période 5) en file depuis le tick précédent ne retient rien hors de sa période : l'E1a de votre équipe se joue au tick %s (%s)",
      tostring(r and r.X1), tostring(r and r.at)))
end
-- T8, câblage : build.lua passe la période aux deux relevés ; chaque prise du jeton des relevés la transmet.
do
  local b = slurp("script/team/build.lua")
  local n = select(2, b:gsub("pulse = Build%.PULSE", ""))
  -- (MALL tranche 1, 05dad4fe : le secteur du mall, Build.Mall.step, relève aussi par chunks sous le jeton et reçoit la période)
  check(n == 3, string.format("T8 : build.lua passe pulse = Build.PULSE aux deux relevés (Rv.step et Raccord.step) et au mall (Build.Mall.step) : %d", n))
  local rv = slurp("script/team/reseau_vivant.lua")
  local ra = slurp("script/team/raccord.lua")
  local takes_rv = select(2, rv:gsub("api%.jeton%.take%(", ""))
  local with_rv = select(2, rv:gsub("api%.jeton%.take%([^\n]-api%.pulse", ""))
  local takes_ra = select(2, ra:gsub("api%.jeton%.take%(", ""))
  local with_ra = select(2, ra:gsub("api%.jeton%.take%([^\n]-api%.pulse", ""))
  check(takes_rv > 0 and takes_rv == with_rv and takes_ra > 0 and takes_ra == with_ra,
    string.format("T8 : chaque prise du jeton des relevés transmet api.pulse (réseau %d/%d, raccord %d/%d)", with_rv, takes_rv, with_ra, takes_ra))
end

---------------------------------------------------------------------------------------------------
-- T7 : entrées périmées (Lourd.drop)
---------------------------------------------------------------------------------------------------
--- Au tick t (aucune pensée en cours, jeton libre, hors des créneaux) : mode « version » : votre équipe pense (servie, tout le budget),
--- puis les 4 factions, refusées (en file) : 5 pensées en cours, effacées par un changement de version ; mode « abandon » : un banc
--- prend le budget, la 1re faction pense (refusée, en file), puis est éliminée (abandon au tick suivant). Puis 4 « banc » refusés en
--- file (ils redemandent à chaque tick), et le créneau de votre équipe au tick t + 1, derrière eux. Rend { delay, cleared, left }
--- (delay : ticks du créneau à l'E1a de votre équipe ; sans Lourd.drop, les entrées mortes, devant, retiennent tout le budget jusqu'à
--- leur purge et ajoutent leurs J.STALE ticks aux 4 des bancs).
local function scene_stale(ctx, mode)
  local Lourd, Team, State = ctx.Lourd, ctx.Team, ctx.State
  local teams = {}
  for _, id in ipairs(State.sorted_keys(global.fo.war.factions)) do teams[#teams + 1] = global.fo.war.factions[id] end
  local pf = State.faction("player")
  local function busy()
    if et_of(pf) then return true end
    for _, f in ipairs(teams) do if et_of(f) then return true end end
    return false
  end
  local guard = 0
  while (game.tick % 300 < 100 or game.tick % 300 > 140 or busy() or Lourd.left(game.tick) < Lourd.BUDGET) and guard < 1200 do
    M.run_ticks(1)
    guard = guard + 1
  end
  if busy() or Lourd.left(game.tick) < Lourd.BUDGET then return nil end
  local t = game.tick
  local sfc = game.surfaces[1]
  local Storage = require("script.core.storage")
  if mode == "version" then
    Team.think(pf, pf.hq.surface, t, nil)
    for _, f in ipairs(teams) do Team.think(f, sfc, t, nil) end
  elseif mode == "perdue" then
    Lourd.take(t, "banc:lourd")
    Team.think(pf, pf.hq.surface, t, nil)
  else
    Lourd.take(t, "banc:lourd")
    Team.think(teams[1], sfc, t, nil)
  end
  local bancs = { "banc:a", "banc:b", "banc:c", "banc:d" }
  local served = {}
  for _, b in ipairs(bancs) do Lourd.take(t, b) end
  -- le créneau mesuré : celui de votre équipe ; « perdue » : votre équipe a pris fin, celui de la 1re faction
  local sf, ssfc = pf, pf.hq.surface
  if mode == "perdue" then sf, ssfc = teams[1], sfc end
  teams[#teams + 1] = pf
  local cleared, left = 0, 0
  if mode == "version" then
    Team.etapes_config_changed({ mod_changes = { ["factorio-overhaul"] = { old_version = "0.6.63", new_version = "0.6.64" } } })
    for _, f in ipairs(teams) do if not et_of(f) then cleared = cleared + 1 end end
    local q = (Storage.ns("pouls_jeton") or {}).q or {}
    for _, k in ipairs(q) do if k:sub(-6) == ":etape" then left = left + 1 end end
  elseif mode == "perdue" then
    Storage.ns("pteam").team = nil -- (l'état laissé par le gestionnaire « perdu » de script/team/player_team.lua)
  else
    teams[1].eliminated = true
  end
  local slot, e1a = nil, nil
  for _ = 1, 24 do
    M.run_ticks(1)
    local k = game.tick
    for _, b in ipairs(bancs) do if not served[b] and Lourd.take(k, b) then served[b] = true end end
    if not slot then
      slot = k
      Team.think(sf, ssfc, k, nil)
    end
    local et = et_of(sf)
    if not e1a and et and et.n >= 2 and et.t0 >= slot then e1a = et.t0 end
    if e1a then break end
  end
  if mode == "perdue" then
    Storage.ns("pteam").team = pf
    pf.team.etape = nil -- (son minuteur est parti pendant la perte : l'état d'attente ne serait plus joué)
  elseif mode ~= "version" then teams[1].eliminated = false end
  return { delay = e1a and slot and (e1a - slot) or nil, cleared = cleared, left = left }
end

local sctx = setup(4)
do
  local a = scene_stale(sctx, "version")
  check(a and a.cleared == 5 and a.left == 0, string.format("T7 a : changement de version avec 5 pensées en attente : %s effacée(s), %s entrée(s) d'étape laissée(s) en file",
    tostring(a and a.cleared), tostring(a and a.left)))
  check(a and a.delay and a.delay <= 7, string.format("T7 a : créneau de votre équipe derrière 4 demandeurs : E1a en %s tick(s) (borne 7)", tostring(a and a.delay)))
  local b = scene_stale(sctx, "abandon")
  check(b and b.delay and b.delay <= 7, string.format("T7 b : abandon (faction éliminée pendant l'attente) : E1a du créneau suivant en %s tick(s) (borne 7)",
    tostring(b and b.delay)))
  local c = scene_stale(sctx, "perdue")
  check(c and c.delay and c.delay <= 7, string.format("T7 c : votre équipe a pris fin (coffre perdu) pendant l'attente de son étape : E1a du créneau suivant (1re faction) en %s tick(s) (borne 7)",
    tostring(c and c.delay)))
end

local wctx = setup(4)
local w = scene_worst(wctx, 30000)
check(w.thinks >= 50 and w.refusals > 0, string.format("T5 : pire cas joué : %d pensées finies, %d étapes servies, %d refus d'étape", w.thinks, w.steps, w.refusals))
check(w.over == 0, string.format("T5 : aucun tick au-delà du budget (%d)", w.over))
check(w.worst_wait <= 7, string.format("T5 : plus longue attente d'une étape %d tick(s) (borne 7)", w.worst_wait))
check(w.longest <= 103, string.format("T5 : plus longue pensée %d ticks du créneau à la fin (borne 103) ; jusqu'à %d étapes servies dans une pensée (E1b rejouée : plus de 8)",
  w.longest, w.most))

---------------------------------------------------------------------------------------------------
-- T6 : mutants de source (un monde neuf chacun). Le texte du mutant est cherché HORS du pcall (absent : le test plante) ; la scène
-- est jouée dans un pcall : elle doit échouer (ou planter, pour la branche n = 1 retirée, dont le symptôme est le plantage).
---------------------------------------------------------------------------------------------------
local TEAM = "script/team/team.lua"
local function mutant(name, m, scene, allow_crash)
  local c = setup(2, { m })
  quiet = true
  local p0, f0 = passes, failures
  local ok, dead = pcall(scene, c)
  passes, failures = p0, f0
  quiet = false
  check((ok and dead) or (not ok and allow_crash), "T6 : mutant « " .. name .. " » refusé" .. (ok and "" or (" (plantage : " .. tostring(dead) .. ")")))
end
mutant("jeton ignoré par une étape", { module = "script.team.team", path = TEAM,
  old = "  if not Lourd.take(tick, TT.who(f)) then", new = "  if false then" }, function(c)
  local r = scene_refuse(c)
  return r ~= nil and r.n_at ~= 4
end)
mutant("étape refusée perdue (pas redemandée)", { module = "script.team.team", path = TEAM,
  old = "    Scheduler.after(1, TT.TIMER, { key = pl.key, n = pl.n, t0 = pl.t0 })" .. NL .. "    return" .. NL,
  new = "    return" .. NL }, function(c)
  local r = scene_refuse(c)
  return r ~= nil and not r.done
end)
mutant("étape refusée jouée quand même", { module = "script.team.team", path = TEAM,
  old = "    Scheduler.after(1, TT.TIMER, { key = pl.key, n = pl.n, t0 = pl.t0 })" .. NL .. "    return" .. NL,
  new = "    Scheduler.after(1, TT.TIMER, { key = pl.key, n = pl.n, t0 = pl.t0 })" .. NL }, function(c)
  local r = scene_refuse(c)
  return r ~= nil and r.n_at ~= 4
end)
mutant("rattrapage d'un état n = 1 (branche retirée)", { module = "script.team.team", path = TEAM,
  old = "  if n == 1 then" .. NL, new = "  if false then" .. NL }, function(c)
  local r = scene_catchup(c)
  return r ~= nil and not (r.ok and r.views == 1 and r.rt == 1 and r.after)
end, true)
mutant("état n = 1 sans signature", { module = "script.team.team", path = TEAM,
  old = "      et = { n = 1, t0 = tick, tail = tail, sig = Et.SIG }", new = "      et = { n = 1, t0 = tick, tail = tail }" }, function(c)
  local r = scene_config(c)
  return r ~= nil and not (r.kept and r.played)
end)
mutant("entrée laissée à l'abandon", { module = "script.team.team", path = TEAM,
  old = "    Lourd.drop(TT.who(f)) -- (lot LOURD, point 2 c : l'entrée de la pensée abandonnée ne retient plus le budget)" .. NL, new = "" },
  function(c)
    local c4 = setup(4, { { module = "script.team.team", path = TEAM,
      old = "    Lourd.drop(TT.who(f)) -- (lot LOURD, point 2 c : l'entrée de la pensée abandonnée ne retient plus le budget)" .. NL, new = "" } })
    local r = scene_stale(c4, "abandon")
    return r ~= nil and (r.delay == nil or r.delay > 7)
  end)
mutant("entrée laissée à l'effacement", { module = "script.team.team", path = TEAM,
  old = "      Lourd.drop(TT.who(f)) -- (lot LOURD, point 2 c : l'entrée de la pensée effacée ne retient plus le budget)" .. NL, new = "" },
  function(c)
    local c4 = setup(4, { { module = "script.team.team", path = TEAM,
      old = "      Lourd.drop(TT.who(f)) -- (lot LOURD, point 2 c : l'entrée de la pensée effacée ne retient plus le budget)" .. NL, new = "" } })
    local r = scene_stale(c4, "version")
    return r ~= nil and (r.delay == nil or r.delay > 7)
  end)
mutant("entrée laissée quand votre équipe prend fin", { module = "script.team.team", path = TEAM,
  old = '    if pl.key == "player" then Lourd.drop(TT.who({ key = "player" })) end' .. NL, new = "" },
  function(c)
    local c4 = setup(4, { { module = "script.team.team", path = TEAM,
      old = '    if pl.key == "player" then Lourd.drop(TT.who({ key = "player" })) end' .. NL, new = "" } })
    local r = scene_stale(c4, "perdue")
    return r ~= nil and (r.delay == nil or r.delay > 7)
  end)
mutant("t0 du créneau recopié", { module = "script.team.team", path = TEAM,
  old = "    f.team.etape = TT.e1a(f, surface, tick, et.tail)" .. NL,
  new = "    f.team.etape = TT.e1a(f, surface, tick, et.tail)" .. NL .. "    f.team.etape.t0 = et.t0" .. NL }, function(c)
  local r = scene_config(c)
  return r ~= nil and r.at ~= nil and r.t0 ~= r.at
end)
mutant("période ignorée par le jeton", { module = "script.core.lourd", path = "script/core/lourd.lua",
  old = "return (tick - (s.last[k] or tick)) % p == 0", new = "return true" }, function(c)
  local r = scene_pulse(c)
  return r ~= nil and r.rv == false and r.at ~= r.X1
end)

print(string.format("[ETAPES-JETON] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
