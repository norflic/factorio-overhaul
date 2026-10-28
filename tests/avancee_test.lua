--[[
  Tests hors jeu du POSTE AVANCÉ de VOTRE équipe (lot FORTIFY, shared/team/avancee.lua).
  Usage, depuis la racine du mod :   lua5.2 tests/avancee_test.lua

  Vérifie la règle pure : point d'arrêt sur le segment menace -> QG à A.PACK_BACK de la menace ; menace fixe refusée ; menace périmée,
  trop près du QG, trop loin, case déjà posée, plafond de postes, une seule demande ouverte, expiration ; déterminisme ;
  et 11 mutants de la règle, tous refusés par au moins un contrôle.
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local function load_rule(mut)
  local src = io.open("shared/team/avancee.lua"):read("*a")
  if mut then
    local n
    src, n = src:gsub(mut[1], mut[2], 1)
    assert(n == 1, "mutant sans effet : " .. mut[1])
  end
  local f = assert(load(src, "avancee"))
  return f()
end

--- Jeu de contrôles de la règle ; rend le nombre d'échecs (utilisé aussi pour tuer les mutants).
local function suite(A)
  local bad = 0
  local n = 0
  local function ok(c) n = n + 1; if not c then bad = bad + 1; if os.getenv("AV_DEBUG") then print("  contrôle " .. n .. " faux, ligne " .. debug.getinfo(2, "l").currentline) end end end
  local hq = { x = 0, y = 0 }
  local tick = 100000
    local p = A.stand(hq, { x = 100, y = 0 })
  ok(p and p.x == 72 and p.y == 0)                       -- 28 tuiles de la meute vers le QG
  local q = A.stand(hq, { x = 0, y = 100 })
  ok(q and q.x == 0 and q.y == 72)
  ok(A.stand(hq, { x = 55, y = 0 }) == nil)              -- trop près du QG : rien ne reste
  local m = A.stand(hq, { x = 100, y = 0 }, 40)          -- recul explicite
  ok(m and m.x == 60)
  -- 2. demande acceptée
  local st = A.new()
  local key, info = A.note(st, hq, { x = 100, y = 0, seen = tick - 100 }, tick)
  ok(key == A.key(72, 0) and info.x == 72)
  ok(#A.open(st, tick) == 1)
  -- 3. déjà ouverte : même clé, pas de doublon
  local k2 = A.note(st, hq, { x = 101, y = 0, seen = tick }, tick)
  ok(k2 == key and #A.open(st, tick) == 1)
  -- 4. une autre demande pendant qu'une est ouverte : refusée
  local k3, why3 = A.note(st, hq, { x = 0, y = 150, seen = tick }, tick)
  ok(k3 == nil and why3 == "occupe")
  -- 5. pose : demande close, case mémorisée, compteur
  A.done(st, key, tick, 2)
  ok(#A.open(st, tick) == 0 and st.made == 1)
  local k4, why4 = A.note(st, hq, { x = 100, y = 0, seen = tick }, tick + 10)
  ok(k4 == nil and why4 == "deja-pose")
  local k5 = A.note(st, hq, { x = 100, y = 0, seen = tick + A.COOLDOWN }, tick + A.COOLDOWN)
  ok(k5 == key)                                            -- après le délai, la case peut être retentée
  A.done(st, k5, tick + A.COOLDOWN, 0)
  ok(st.made == 1)                                         -- une pose à 0 tourelle ne compte pas
  -- 6. menace périmée
  local st2 = A.new()
  local k6, why6 = A.note(st2, hq, { x = 100, y = 0, seen = tick - 2 * 3600 - 1 }, tick)
  ok(k6 == nil and why6 == "perimee")
  ok((A.note(st2, hq, { x = 100, y = 0, seen = tick - 2 * 3600 }, tick)) ~= nil) -- exactement A.FRESH : encore fraîche
  -- 6 bis. menace fixe (ver, nid) : refusée, des tourelles ne l'atteignent pas
  local kf, whyf = A.note(A.new(), hq, { x = 100, y = 0, fixed = true, seen = tick }, tick)
  ok(kf == nil and whyf == "fixe")
  -- 7. trop loin / trop près
  local st3 = A.new()
  local k7, why7 = A.note(st3, hq, { x = 400, y = 0, seen = tick }, tick)
  ok(k7 == nil and why7 == "loin")
  local k8, why8 = A.note(st3, hq, { x = 55, y = 0, seen = tick }, tick)
  ok(k8 == nil and why8 == "pres-du-QG")
  -- 8. plafond de postes
  local st4 = A.new()
  for i = 1, A.MAX_POSTS do
    local kk = A.note(st4, hq, { x = 60 + 40 * i, y = 0, seen = tick }, tick)
    ok(kk ~= nil)
    A.done(st4, kk, tick, 2)
  end
  local k9, why9 = A.note(st4, hq, { x = 0, y = 150, seen = tick }, tick)
  ok(k9 == nil and why9 == "plafond")
  -- 9. expiration d'une demande jamais prise
  local st5 = A.new()
  A.note(st5, hq, { x = 100, y = 0, seen = tick }, tick)
  ok(#A.open(st5, tick + A.EXPIRE) == 1)
  ok(#A.open(st5, tick + A.EXPIRE + 1) == 0)
  -- 10. clés de case : deux points de la même case partagent la clé, deux cases voisines non
  ok(A.key(33, 1) == A.key(63, 31) and A.key(33, 1) ~= A.key(64, 1))
  -- 11. symétrie : une menace à l'ouest donne un point à l'ouest
  local w = A.stand(hq, { x = -100, y = 0 })
  ok(w and w.x == -72)
  return bad
end

section("règle pure")
local A = load_rule()
local bad = suite(A)
check(bad == 0, "la règle passe tous ses contrôles (" .. bad .. " échec(s))")
-- déterminisme : deux passes, mêmes états
local s1, s2 = A.new(), A.new()
for _, s in ipairs({ s1, s2 }) do
  A.note(s, { x = 0, y = 0 }, { x = 100, y = 20, seen = 5 }, 10)
end
check(next(s1.reqs) == next(s2.reqs), "deux passes identiques donnent la même clé")

section("mutants")
local MUT = {
  { "A.FRESH = 2 %* 3600", "A.FRESH = 200 * 3600" },                                  -- plus de péremption
  { "tick %- %(req.seen or %-1e9%) > A.FRESH", "tick - (req.seen or -1e9) >= A.FRESH" }, -- borne ouverte
  { "back = back or A.PACK_BACK", "back = 0" },                                        -- les tourelles sur la meute
  { "if req.fixed then return nil, \"fixe\" end", "" },                                -- une menace fixe acceptée
  { "if len < back %+ A.MIN_HQ then return nil end", "if len < back then return nil end" },  -- plus de place pour le QG
  { "if dh > A.MAX_HQ then", "if dh > 1e9 then" },                                     -- sans limite de distance
  { "tick %- at < A.COOLDOWN", "tick - at < 0" },                                      -- case retentée aussitôt
  { "%(st.made or 0%) >= A.MAX_POSTS", "(st.made or 0) >= 1e9" },                      -- pas de plafond
  { "if #sorted_keys%(st.reqs%) >= 1 then", "if #sorted_keys(st.reqs) >= 9 then" },    -- plusieurs demandes ouvertes
  { "if tick %- r.t > A.EXPIRE then", "if false then" },                               -- jamais d'expiration
  { "if %(n or 0%) > 0 then st.made", "if true then st.made" },                        -- une pose vide compte
  { "local k = back / len", "local k = len / back" },                                  -- point à l'envers
}
for i, mu in ipairs(MUT) do
  local okload, Am = pcall(load_rule, mu)
  local killed = false
  if not okload then killed = true else
    local okrun, b = pcall(suite, Am)
    killed = (not okrun) or b > 0
  end
  check(killed, "mutant " .. i .. " refusé : " .. mu[2])
end

print(string.format("[AVANCEE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
