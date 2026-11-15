--[[
  Tests hors jeu du lot ENERGIE-0916 (partie du DC en 0.9.2 : centrales nourries à la main, refus « foreuses : minerai »).
  1. shared/team/eviction_charbon.lua : éviction voulue (refus « minerai » d'un projet d'alimentation, une fois) ; entités du lot, triées.
  2. shared/team/charbon_centrale.lua : chaudières à sec = pause courte, jamais la pause longue (B2 + consigne « étendre le charbon » lue).
  3. shared/team/centrale.lua : verrou de survie des améliorations (C.survie).
  4. Câblage statique : build.lua appelle l'éviction dans Build.plan_drills et passe Sante.coal_short à Cc.refused ; team.lua garde les
     paiements d'amélioration derrière C.survie.
  Chaque bloc est rejoué sur des mutants : un mutant qui passe est un test qui ne prouve rien.
  Usage, depuis la racine du mod :   lua5.2 tests/eviction_charbon_test.lua
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

local function fresh(name)
  package.loaded[name] = nil
  return require(name)
end

-- 1. Éviction ---------------------------------------------------------------------------------------------------------------------------
local function ev_battery(Ev)
  local ok = 0
  local function c(cond) if cond then ok = ok + 1 end return cond end
  local n = 0
  n = n + 1; c(Ev.wanted({ alim = true, why = "minerai" }) == true)
  n = n + 1; c(not Ev.wanted({ alim = true, why = "minerai", done = true }))
  n = n + 1; c(not Ev.wanted({ alim = true, why = "pas de lot" }))
  n = n + 1; c(not Ev.wanted({ alim = false, why = "minerai" }))
  n = n + 1; c(not Ev.wanted(nil))
  local rect = { x0 = 299, y0 = -268, x1 = 323, y1 = -244 }
  local list = {
    { x = 310, y = -250, kind = "drill" }, { x = 300, y = -260, kind = "sink" }, { x = 300, y = -260, kind = "drill" },
    { x = 323, y = -250, kind = "drill" }, -- x1 exclu
    { x = 298.5, y = -250, kind = "drill" }, { x = 305, y = -244, kind = "sink" }, -- hors lot
    { x = 299, y = -268, kind = "sink" }, -- coin inclus
  }
  local got = Ev.inside(list, rect)
  n = n + 1; c(#got == 4)
  n = n + 1; c(got[1] and got[1].x == 299 and got[1].y == -268)
  n = n + 1; c(got[2] and got[2].x == 300 and got[2].kind == "drill" and got[3].kind == "sink")
  n = n + 1; c(got[4] and got[4].x == 310)
  n = n + 1; c(#Ev.inside(list, nil) == 0)
  n = n + 1; c(type(Ev.line({ team = "amber", pid = 6, plant = 1, x0 = 299, y0 = -268, drills = 18, sinks = 9, kept = 0, tick = 3600 })) == "string")
  return ok, n
end

local Ev = fresh("shared.team.eviction_charbon")
local ok, n = ev_battery(Ev)
check(ok == n, string.format("1. eviction : %d/%d", ok, n))
do -- mutants
  local m1 = setmetatable({ wanted = function(c) return c ~= nil and c.alim == true and c.why == "minerai" end }, { __index = Ev })
  local m2 = setmetatable({ wanted = function(c) return c ~= nil and c.alim == true and not c.done end }, { __index = Ev })
  local m3 = setmetatable({ inside = function(list, rect)
    local out = {}
    for _, e in ipairs(list or {}) do if rect and e.x >= rect.x0 and e.x <= rect.x1 and e.y >= rect.y0 and e.y <= rect.y1 then out[#out + 1] = e end end
    return out end }, { __index = Ev })
  for i, m in ipairs({ m1, m2, m3 }) do
    local k, t = ev_battery(m)
    check(k < t, "1. mutant " .. i .. " d'eviction doit echouer")
  end
end

-- 2. Pause du projet d'alimentation --------------------------------------------------------------------------------------------------
local Cc = fresh("shared.team.charbon_centrale")
local function cc_battery(C)
  local ok, n = 0, 0
  local function c(cond) n = n + 1 if cond then ok = ok + 1 end end
  c(C.pause(0) == Cc.RETRY_TICKS)
  c(C.pause(Cc.MAX_TRIES) == Cc.LONG_RETRY_TICKS)
  c(C.pause(Cc.MAX_TRIES, true) == Cc.RETRY_TICKS)
  c(C.pause(Cc.MAX_TRIES + 5, true) == Cc.RETRY_TICKS)
  local st = { tries = Cc.MAX_TRIES - 1 }
  C.refused(st, 1000, false, true)
  c(st.tries == Cc.MAX_TRIES and st.retry_at == 1000 + Cc.RETRY_TICKS and st.alim == nil)
  local st2 = { tries = Cc.MAX_TRIES - 1 }
  C.refused(st2, 1000, false, false)
  c(st2.retry_at == 1000 + Cc.LONG_RETRY_TICKS)
  return ok, n
end
ok, n = cc_battery(Cc)
check(ok == n, string.format("2. pause : %d/%d", ok, n))
do
  local m = setmetatable({}, { __index = Cc })
  m.pause = function(tries) return ((tries or 0) < Cc.MAX_TRIES) and Cc.RETRY_TICKS or Cc.LONG_RETRY_TICKS end
  m.refused = function(st, tick, grew) st.tries = (st.tries or 0) + (grew and 0 or 1); st.retry_at = tick + m.pause(st.tries); st.alim = nil end
  local k, t = cc_battery(m)
  check(k < t, "2. mutant (pause d'avant le lot) doit echouer")
end

-- 3. Verrou de survie -----------------------------------------------------------------------------------------------------------------
local C = fresh("shared.team.centrale")
local function sv_battery(S)
  local ok, n = 0, 0
  local function c(cond) n = n + 1 if cond then ok = ok + 1 end end
  local h, why = S(nil, true)
  c(h == true and why == "energie:chaudieres a sec")
  h, why = S({ saturated = true }, false)
  c(h == true and why == "energie:centrale saturee")
  h = S({ saturated = false }, false)
  c(h == false)
  h = S(nil, false)
  c(h == false)
  -- de bout en bout avec C.observe : 6 relevés à 80 % saturent (verrou), un relevé sous 70 % le lève
  local g = {}
  for _ = 1, C.SAT_CHECKS do C.observe(g, 0.85 * 1000, 1000) end
  c(S(g, false) == true)
  C.observe(g, 0.5 * 1000, 1000)
  c(S(g, false) == false)
  return ok, n
end
ok, n = sv_battery(C.survie)
check(ok == n, string.format("3. survie : %d/%d", ok, n))
do
  local k, t = sv_battery(function(g, dry) if dry then return true, "energie:chaudieres a sec" end return false, nil end)
  check(k < t, "3. mutant (saturation ignoree) doit echouer")
  k, t = sv_battery(function(g) if g and g.saturated then return true, "energie:centrale saturee" end return false, nil end)
  check(k < t, "3. mutant (chaudieres a sec ignorees) doit echouer")
end

-- 4. Câblage statique -----------------------------------------------------------------------------------------------------------------
local function read(p) local fh = assert(io.open(p, "rb")); local s = fh:read("*a"); fh:close(); return s end
local build = read("script/team/build.lua")
local s0 = build:find("function Build.plan_drills", 1, true)
local s1 = s0 and build:find("\nfunction ", s0 + 10, true)
local body = s0 and build:sub(s0, s1 or #build) or ""
check(body:find("EvC.wanted(", 1, true) ~= nil, "4. plan_drills consulte EvC.wanted")
check(body:find("EvRt.lot(", 1, true) ~= nil, "4. plan_drills appelle EvRt.lot")
check(body:find("try_lots()", body:find("EvRt.lot(", 1, true) or #body, true) ~= nil, "4. plan_drills refait le placement apres l'eviction")
do -- l'essai à blanc (tuiles d'avant-poste comptées libres) passe AVANT le retrait : aucun lot n'est vidé pour rien (scarlet, banc ENERGIE-0916-apres)
  local dry, ev = body:find("try_lots(tiles)", 1, true), body:find("EvRt.lot(", 1, true)
  check(dry ~= nil and ev ~= nil and dry < ev, "4. essai a blanc avant l'eviction")
  check(body:find("if fits then", 1, true) ~= nil and (body:find("if fits then", 1, true) < ev), "4. eviction seulement si la ligne tient")
  check(build:find("if opts and opts.free_also then", 1, true) ~= nil, "4. place_module lit free_also")
end
check(build:find("Cc.refused(st, tick, alim.cv_grew, Sante.coal_short(f))", 1, true) ~= nil, "4. charbon_step passe les chaudieres a sec a Cc.refused")
local team = read("script/team/team.lua")
check(team:find("Centrale.survie(", 1, true) ~= nil, "4. team.lua lit le verrou de survie")
check(team:find("if ia3 and not energie_hold then Ia3.capital_continu(", 1, true) ~= nil, "4. remplacement continu sous le verrou")
check(team:find("if energie_hold then\n    Ia3.capital_attente(f, energie_why, tick)\n  elseif ia3 and not (pile_hold or recon_hold) then", 1, true) ~= nil,
  "4. paiement de l'amelioration sous le verrou (avant le degel)")
local rt = read("script/team/eviction_charbon.lua")
check(rt:find("State.disown(unit)", 1, true) ~= nil and rt:find("raise_destroyed = true", 1, true) ~= nil, "4. retrait comme revert_one (plus possedee, mine)")

print(string.format("eviction_charbon_test : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
