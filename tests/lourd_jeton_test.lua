--[[
  Lot LOURD (S6 point 2, fo-logs\2026-11-07_LOURD\CRITERES.md §2) : l'ordonnanceur des travaux lourds (script/core/lourd.lua), à budget
  par tick (coûts DÉCLARÉS) et en file équitable.
    J1. TÉMOIN D'IDENTITÉ : mêmes réponses, demande par demande, que le jeton de la 0.6.61 (tests/fixtures/pouls_jeton_0661.lua, copie
        exacte de script/team/pouls_jeton.lua à a5df66a4, chargée à part avec son propre global), sur 200 suites de demandes tirées d'une
        graine : (a) sans coût ; (b) coûts déclarés au hasard, J.COSTS = faux (chaque travail coûte tout le budget).
    J2. Petits travaux : plusieurs au même tick tant que la somme tient dans le budget ; le refusé passe le premier au tick suivant.
    J3. Un travail plus grand que le budget a son tick à lui seul.
    J4. Personne n'est affamé : un GROS travail (tout le budget, chaque tick) et 5 petits demandeurs chaque tick, dans un ordre tournant
        ou avec le gros appelé le DERNIER ; plus longue suite de refus de chacun bornée, chacun servi.
    J5. Période : un demandeur des passes du pouls (période 5) en tête de file ne retient pas une étape aux autres ticks.
    J6. Une entrée qui ne redemande plus sort de la file (max(STALE, période)).
    J7. Sauvegarde : module rechargé en plein milieu (la file est dans global) : mêmes réponses que la suite continue.
    J8. Valeurs du jeu : deux tranches du relevé du réseau (32 chunks, Rv.COLS) passent au même tick ; une bande du raccord sur une boîte
        de 76 chunks de large (152) a son tick à elle seule.
    Mutants (texte de la source changé) : ils DOIVENT tous être vus.
  Usage : lua5.2 tests/lourd_jeton_test.lua
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 print("OK     " .. msg) else fail_n = fail_n + 1 print("ECHEC : " .. msg) end
end

local store = {}
package.loaded["script.core.storage"] = {
  declare = function(name, init) store[name] = store[name] or init() end,
  ns = function(name) return store[name] end,
}

local function read(path)
  local fh = assert(io.open(path, "rb"))
  local src = fh:read("*a")
  fh:close()
  return src
end

local function mutated(path, subs)
  local src = read(path)
  for _, x in ipairs(subs or {}) do
    local a, b = src:find(x[1], 1, true)
    assert(a, "mutant : texte absent de " .. path .. " : " .. x[1])
    assert(not src:find(x[1], b + 1, true), "mutant : texte present plusieurs fois : " .. x[1])
    src = src:sub(1, a - 1) .. x[2] .. src:sub(b + 1)
  end
  return src
end

--- Charge lourd.lua (éventuellement changé) ; keep : garder global (rechargement après une sauvegarde).
local function load_j(subs, keep)
  package.loaded["script.core.lourd"] = nil
  package.preload["script.core.lourd"] = nil
  if subs then
    local src = mutated("script/core/lourd.lua", subs)
    package.preload["script.core.lourd"] = function(name) return assert(load(src, "=script/core/lourd.lua"))(name) end
  end
  if not keep then store = {} end
  return require("script.core.lourd")
end

--- Le jeton de la 0.6.61 (fichier tel quel), chargé avec SON global (une table à part) : la référence de J1.
local FIXTURE = read("tests/fixtures/pouls_jeton_0661.lua")
local function ref_jeton()
  local own = {}
  local storage = {
    declare = function(name, init) own[name] = own[name] or init() end,
    ns = function(name) return own[name] end,
  }
  local env = setmetatable({ require = function(n)
    if n == "script.core.storage" then return storage end
    return require(n)
  end }, { __index = _G })
  return assert(load(FIXTURE, "=tests/fixtures/pouls_jeton_0661.lua", "t", env))("script.team.pouls_jeton")
end

local function lcg(seed)
  local st = seed
  return function(n)
    st = (st * 1103515245 + 12345) % 2147483648
    return math.floor(st / 65536) % n + 1
  end
end

-- J1 : with_costs : coûts déclarés au hasard (le témoin J.COSTS = faux doit les ignorer)
local function j1(J, with_costs)
  local diffs, n, first = 0, 0, nil
  local costs = { 1, 10, 32, 64, 152 }
  for seed = 1, 200 do
    local r = lcg(seed)
    J.reset()
    local R = ref_jeton()
    local who = { "a:rv", "a:ra", "b:rv", "b:ra", "player:rv", "player:ra" }
    for t = 0, 600, 5 do
      for _ = 1, r(6) do
        local w = who[r(#who)]
        local k = r(#costs + 1)
        local a = J.take(t, w, nil, with_costs and costs[k] or nil)
        local b = R.take(t, w)
        n = n + 1
        if a ~= b then
          diffs = diffs + 1
          first = first or string.format("graine %d, tick %d, %s : %s contre %s", seed, t, w, tostring(a), tostring(b))
        end
      end
    end
  end
  return diffs, n, first
end

--- Joue `fn(J)` avec J.BUDGET = 100 (les cas J2 à J4 sont écrits pour ce budget), puis rend le budget du jeu.
local function at100(J, fn, ...)
  local saved = J.BUDGET
  J.BUDGET = 100
  local a, b, c = fn(J, ...)
  J.BUDGET = saved
  return a, b, c
end

-- J2, J3
local function j2(J)
  J.reset()
  local g = {}
  for i = 1, 6 do g[i] = J.take(10, "p" .. i, 1, 20) end
  local next1 = J.take(11, "p6", 1, 20)
  return g, next1
end
local function j3(J)
  J.reset()
  local a = J.take(20, "gros", 1, 150)
  local b = J.take(20, "petit", 1, 1)
  local c = J.take(21, "petit", 1, 1)
  return a, b, c
end

-- J4 : gros travail régulier et 5 petits ; ordre d'appel tournant à chaque tick, ou FIXE avec le gros appelé le DERNIER (sans la
-- réserve du budget pour la tête de file, les petits le mangeraient à chaque tick avant lui)
local function j4(J, ticks, fixed)
  J.reset()
  local who = { "gros", "s1", "s2", "s3", "s4", "s5" }
  if fixed then who = { "s1", "s2", "s3", "s4", "s5", "gros" } end
  local cost = { gros = 100, s1 = 30, s2 = 30, s3 = 30, s4 = 30, s5 = 30 }
  local run, worst, got = {}, {}, {}
  for t = 1, ticks do
    for k = 0, #who - 1 do
      local w = fixed and who[k + 1] or who[(t + k) % #who + 1]
      local ok = J.take(t, w, 1, cost[w])
      if ok then
        run[w] = 0
        got[w] = (got[w] or 0) + 1
      else
        run[w] = (run[w] or 0) + 1
        if run[w] > (worst[w] or 0) then worst[w] = run[w] end
      end
    end
  end
  local mx, all = 0, true
  for _, w in ipairs(who) do
    mx = math.max(mx, worst[w] or 0)
    if (got[w] or 0) == 0 then all = false end
  end
  return mx, all, got
end

-- J5 : « a:rv » (période 5) refusé à la passe 10, donc en tête de file ; « e:etape » demande aux ticks 11 à 14
local function j5(J)
  J.reset()
  J.take(10, "x:ra", 5)
  J.take(10, "a:rv", 5) -- refusé : en file, période 5
  local out = {}
  for t = 11, 14 do out[#out + 1] = J.take(t, "e:etape", 1) end
  local rv15 = J.take(15, "a:rv", 5)
  return out, rv15
end

-- J6
local function j6(J)
  J.reset()
  J.take(0, "x", 1)
  J.take(0, "mort", 1) -- refusé, en file, ne redemandera plus
  local first_ok
  for k = 1, 10 do if J.take(k, "vivant", 1) and not first_ok then first_ok = k end end
  return first_ok
end

-- J7 : suite continue contre suite avec rechargement au tick 300
local function j7(subs)
  local function run(reload_at)
    local J = load_j(subs)
    local r = lcg(77)
    local who = { "a:rv", "b:ra", "c:etape", "d:pnj", "e:etape" }
    local out = {}
    for t = 1, 600 do
      if t == reload_at then J = load_j(subs, true) end -- (global gardé, locales neuves)
      for _ = 1, r(4) do
        local w = who[r(#who)]
        out[#out + 1] = J.take(t, w, (w:sub(-2) == "rv") and 5 or 1, ({ 10, 40, 100, nil })[r(4)]) and "1" or "0"
      end
    end
    return table.concat(out)
  end
  return run(nil) == run(300)
end

-- J8 : valeurs du jeu
local function j8(J)
  J.reset()
  local a = J.take(100, "f1:rv", nil, 32)
  local b = J.take(100, "f2:rv", nil, 32)
  local c = J.take(100, "f3:rv", nil, 32)
  local d = J.take(105, "f4:ra", nil, 152)
  local e = J.take(105, "f3:rv", nil, 32)
  local g = J.take(110, "f4:ra", nil, 152)
  local h = J.take(110, "f1:rv", nil, 32)
  return a, b, c, d, e, g, h
end

---------------------------------------------------------------------------------------------------
local J = load_j(nil)
local d1, n1, f1 = j1(J, false)
check(d1 == 0, string.format("J1 : sans coût, mêmes réponses que le jeton de la 0.6.61 (%d demandes, %d écart(s))%s", n1, d1, f1 and (" : " .. f1) or ""))
J.COSTS = false
local d1b, n1b, f1b = j1(J, true)
J.COSTS = true
check(d1b == 0, string.format("J1 : coûts déclarés, J.COSTS = faux : mêmes réponses que le jeton de la 0.6.61 (%d demandes, %d écart(s))%s", n1b, d1b,
  f1b and (" : " .. f1b) or ""))
local d1c = j1(J, true)
check(d1c > 0, string.format("J1 : coûts déclarés, J.COSTS = vrai : les réponses changent bien (%d écart(s) avec la 0.6.61)", d1c))
local g, nx = at100(J, j2)
check(g[1] and g[2] and g[3] and g[4] and g[5] and not g[6] and nx,
  "J2 : 5 travaux de 20 au même tick (budget 100), le 6e refusé, servi le premier au tick suivant")
local a3, b3, c3 = at100(J, j3)
check(a3 and not b3 and c3, "J3 : un travail de 150 (plus que le budget de 100) a son tick à lui seul ; le petit passe au tick suivant")
local mx, all, got = at100(J, j4, 3000)
check(all and mx <= 6, string.format("J4 : gros travail régulier et 5 petits, ordre tournant : tous servis (gros %d, s1 %d), plus longue suite de refus %d (borne 6)",
  got.gros or 0, got.s1 or 0, mx))
local mxf, allf, gotf = at100(J, j4, 3000, true)
check(allf and mxf <= 6, string.format("J4 : même chose, le gros appelé le DERNIER à chaque tick : tous servis (gros %d, s5 %d), plus longue suite de refus %d (borne 6)",
  gotf.gros or 0, gotf.s5 or 0, mxf))
local o5, rv15 = j5(J)
check(o5[1] and o5[2] and o5[3] and o5[4] and rv15, "J5 : « a:rv » (période 5) en tête de file ne retient pas l'étape aux ticks 11 à 14, et passe à 15")
local f6 = j6(J)
check(f6 == J.STALE + 1, string.format("J6 : un demandeur qui ne redemande plus retient la file %d ticks au plus (STALE), pas au-delà (premier passage au tick %s)", J.STALE, tostring(f6)))
check(j7(nil), "J7 : rechargement au tick 300 (file dans global) : mêmes réponses que la suite continue")
J = load_j(nil)
local a8, b8, c8, d8, e8, g8, h8 = j8(J)
check(J.BUDGET == 64 and a8 and b8 and not c8 and not d8 and e8 and g8 and not h8,
  string.format("J8 : budget du jeu %d : deux tranches de 32 au même tick, la 3e refusée ; une bande de 152 attend la tête de file, puis passe seule sur son tick",
    J.BUDGET))

local NL = string.char(10)
local MUT = {
  { "coût ignoré", { { "local c = (J.COSTS and cost) or J.BUDGET", "local c = J.BUDGET" } },
    function(Jm) local gm = at100(Jm, j2); return not gm[2] end },
  { "réserve ignorée (le budget des premiers de la file n'est pas gardé)", { { "      r = r + ((J.COSTS and s.cost[k]) or J.BUDGET)" .. NL, "" } },
    function(Jm) local m, al = at100(Jm, j4, 3000, true); return not al or m > 6 end },
  { "file ignorée", { { "local ok = (used + r + c <= J.BUDGET) or (used == 0 and not ahead)", "local ok = (used + c <= J.BUDGET) or (used == 0)" } },
    function(Jm) local d = j1(Jm, false); return d > 0 end },
  { "période ignorée", { { "return (tick - (s.last[k] or tick)) % p == 0", "return true" } },
    function(Jm) local o = j5(Jm); return not (o[1] and o[2] and o[3] and o[4]) end },
  { "témoin qui garde les coûts (J.COSTS lu nulle part)", { { "local c = (J.COSTS and cost) or J.BUDGET", "local c = cost or J.BUDGET" } },
    function(Jm) Jm.COSTS = false; local d = j1(Jm, true); Jm.COSTS = true; return d > 0 end },
  { "un travail plus grand que le budget jamais servi", { { " or (used == 0 and not ahead)", "" } },
    function(Jm) local a = at100(Jm, j3); return not a end },
}
for _, m in ipairs(MUT) do
  local Jm = load_j(m[2])
  check(m[3](Jm), "mutant " .. m[1] .. " : vu")
end

print(string.format("[LOURD-JETON] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
