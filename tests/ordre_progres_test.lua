--[[
  Lot CAPI-ANNULATION : test hors jeu de la règle du progrès d'un ordre (shared/ai3/ordre_progres.lua).
    §1 cas nommés : manque qui baisse, constant, baisse puis plateau, oscillation, plafond, entités posées, ordre sans mesure,
       ordre d'une ancienne sauvegarde (champs absents), manque nul avant la première mesure ;
    §2 force brute : toutes les suites d'observations (écart de temps, entités posées, manque) comparées à une définition
       de référence écrite A PART (recalcul du dernier instant de progrès depuis l'historique complet) avec les valeurs
       de la règle écrites ici en dur (30 et 60 min) : un réglage changé est vu ;
    §3 déterminisme (même suite, même résultat) et aucun nom du jeu ni pairs ni hasard dans le module ;
    §4 mutants : chaque ligne de la règle retirée ou changée est vue (au moins 10).
  Usage : lua5.2 tests/ordre_progres_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/ai3/ordre_progres.lua")

local MIN = 3600
local TTL_REF, MAX_REF = 30 * MIN, 60 * MIN -- valeurs ÉCRITES de la règle (CRITERES.md §2)

local pass, fail = 0, 0
local QUIET = false -- vrai pendant les mutants : le premier échec arrête la suite (le mutant est vu)
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if QUIET then error("mutant vu : " .. msg, 0) end
    print("[ORDRE-PROGRES] ECHEC : " .. msg)
  end
end

local function load_op(src)
  local fn, err = load(src, "=ordre_progres", "t")
  if not fn then return nil, err end
  local ok, mod = pcall(fn)
  if not ok then return nil, mod end
  return mod
end

--- Référence : l'ordre est-il à retirer à l'observation i de l'historique ? (recalcul complet, sans état)
local function ref_expired(hist, i)
  local last, prev_built, min_m, measured = 0, nil, nil, false
  for j = 1, i do
    local h = hist[j]
    if h.built ~= prev_built then last = h.t end
    prev_built = h.built
    if h.m ~= nil then
      if min_m ~= nil and h.m < min_m then last = h.t end
      if min_m == nil or h.m < min_m then min_m = h.m end
      measured = true
    end
  end
  local now = hist[i].t
  if now - last > TTL_REF then return true end
  if measured and hist[i].built == 0 and now > MAX_REF then return true end
  return false
end

--- Joue l'historique avec la règle ; rend la liste des verdicts à chaque observation.
local function play(Op, hist)
  local rec = { opened = 0, progress_tick = 0 }
  local out = {}
  for i, h in ipairs(hist) do
    Op.observe(rec, h.t, h.built, h.m)
    out[i] = Op.expired(rec, h.t) and true or false
  end
  return out, rec
end

local function suite(Op)
  local p0, f0 = pass, fail
  -- §1 cas nommés (historiques écrits à la main : instants en minutes)
  local function H(list)
    local h = {}
    for i, e in ipairs(list) do h[i] = { t = e[1] * MIN, built = e[2], m = e[3] } end
    return h
  end
  local function last_verdict(list)
    local o = play(Op, H(list))
    return o[#o]
  end
  check(last_verdict({ { 1, 0, 100 }, { 20, 0, 90 }, { 40, 0, 80 }, { 55, 0, 70 } }) == false,
    "§1a un manque qui baisse tous les 15-20 min n'est pas retiré à 55 min")
  check(last_verdict({ { 1, 0, 100 }, { 20, 0, 100 }, { 31.5, 0, 100 } }) == true,
    "§1b un manque constant est retiré à plus de 30 min")
  check(last_verdict({ { 1, 0, 100 }, { 29, 0, 100 } }) == false, "§1c un manque constant n'est pas retiré avant 30 min")
  check(last_verdict({ { 1, 0, 100 }, { 20, 0, 90 }, { 49, 0, 90 } }) == false,
    "§1d baisse à 20 min, plateau : le délai repart de la dernière baisse (49 < 50)")
  check(last_verdict({ { 1, 0, 100 }, { 20, 0, 90 }, { 51, 0, 90 } }) == true,
    "§1e baisse à 20 min, plateau : retiré à 51 min")
  check(last_verdict({ { 1, 0, 100 }, { 10, 0, 90 }, { 20, 0, 100 }, { 30, 0, 90 }, { 41.5, 0, 90 } }) == true,
    "§1f oscillation : revenir à 90 ne bat pas le minimum 90, pas de progrès (41,5 - 10 > 30)")
  check(last_verdict({ { 1, 0, 100 }, { 10, 0, 90 }, { 20, 0, 100 }, { 30, 0, 95 }, { 39, 0, 90 } }) == false,
    "§1g oscillation sans nouveau minimum : le dernier progrès reste 10 min (39 - 10 < 30)")
  check(last_verdict({ { 1, 0, 100 }, { 30, 0, 80 }, { 59, 0, 60 }, { 61, 0, 55 } }) == true,
    "§1h plafond : 61 min sans aucune entité posée, même si le manque baisse")
  check(last_verdict({ { 1, 0, 100 }, { 30, 0, 80 }, { 59, 0, 60 }, { 60, 0, 55 } }) == false,
    "§1i plafond : exactement 60 min n'est pas encore retiré")
  check(last_verdict({ { 1, 0, 100 }, { 30, 3, nil }, { 59, 4, nil }, { 90, 5, nil }, { 118, 6, nil } }) == false,
    "§1j des entités posées sans cesse : jamais retiré, le plafond ne vise pas un chantier commencé")
  check(last_verdict({ { 1, 0, 100 }, { 30, 3, nil }, { 62, 3, nil } }) == true,
    "§1k des entités posées puis plus rien : retiré 30 min après la dernière pose")
  check(last_verdict({ { 1, 0, 100 }, { 20, 2, 60 }, { 70, 2, 60 } }) == true,
    "§1l entités posées puis plus de progrès : retiré (la pose à 20 min est le dernier progrès)")
  check(last_verdict({ { 1, 2, nil }, { 31.5, 2, nil } }) == true, "§1m ordre sans mesure de manque : ancienne règle, retiré à 30 min")
  check(last_verdict({ { 1, 2, nil }, { 100, 2, nil } }) == true and
    last_verdict({ { 1, 0, nil }, { 29, 0, nil } }) == false, "§1n ordre sans mesure : pas de plafond de 60 min, seulement 30 min")
  check(last_verdict({ { 1, 0, nil }, { 25, 0, nil }, { 61, 0, nil } }) == true,
    "§1o ordre sans mesure ni progrès : retiré (ancienne règle)")
  -- manque nul avant la première mesure : jamais le minimum
  do
    local rec = { opened = 0, progress_tick = 0 }
    Op.observe(rec, 1 * MIN, 0, nil) -- pas de module en réserve
    Op.observe(rec, 5 * MIN, 0, nil)
    check(rec.best_missing == nil, "§1p sans module en réserve, aucun minimum n'est enregistré")
    Op.observe(rec, 9 * MIN, 0, 40)
    check(rec.best_missing == 40, "§1q le premier manque mesuré devient le minimum")
    Op.observe(rec, 10 * MIN, 0, 35)
    check(rec.best_missing == 35 and rec.progress_tick == 10 * MIN, "§1r une baisse remet le délai à zéro")
  end
  -- ancienne sauvegarde : rec sans best_missing mais avec built et progress_tick
  do
    local rec = { opened = 0, progress_tick = 5 * MIN, built = 0 }
    Op.observe(rec, 20 * MIN, 0, 70)
    check(rec.best_missing == 70 and rec.progress_tick == 5 * MIN,
      "§1s ancienne sauvegarde : la première mesure ne compte pas comme progrès")
    check(Op.expired(rec, 35.5 * MIN) == true, "§1t ancienne sauvegarde : retiré 30 min après son dernier progrès connu")
    check(select(2, Op.expired(rec, 35.5 * MIN)) == "ttl", "§1u raison « ttl »")
    local r2 = { opened = 0, progress_tick = 59 * MIN, built = 0, best_missing = 10 }
    local e, why = Op.expired(r2, 61 * MIN)
    check(e == true and why == "plafond", "§1v raison « plafond »")
    check(Op.reason("ttl") == "aucun progres en 30 min", "§1w texte de l'ancien retrait inchangé : " .. Op.reason("ttl"))
    check(Op.reason("plafond") == "plafond de 60 min sans entite posee", "§1x texte du plafond : " .. Op.reason("plafond"))
  end

  -- §2 force brute
  local dts = { 10, 31, 61 }
  local built_v, miss_v = { 0, 1 }, { false, 0, 1, 2 } -- false : pas de mesure (nil)
  local cases = 0
  local bad = nil
  local function expand(hist, t, depth, max_depth, dts_l, built_l, miss_l)
    if depth > 0 then
      local o = play(Op, hist)
      for i = 1, #hist do
        cases = cases + 1
        if o[i] ~= ref_expired(hist, i) and not bad then
          local d = {}
          for _, h in ipairs(hist) do d[#d + 1] = string.format("(%d,%s,%s)", h.t / MIN, tostring(h.built), tostring(h.m)) end
          bad = table.concat(d, " ") .. " en " .. i
        end
      end
    end
    if depth >= max_depth then return end
    for _, dt in ipairs(dts_l) do
      for _, b in ipairs(built_l) do
        for _, m in ipairs(miss_l) do
          hist[#hist + 1] = { t = t + dt * MIN, built = b, m = m or nil }
          expand(hist, t + dt * MIN, depth + 1, max_depth, dts_l, built_l, miss_l)
          hist[#hist] = nil
        end
      end
    end
  end
  -- une seule vérification par suite complète (le dernier verdict) suffit pour les longues : les préfixes sont des suites
  -- plus courtes déjà jouées ; on compare TOUS les verdicts de chaque suite.
  expand({}, 0, 0, 4, dts, built_v, miss_v)
  check(bad == nil, "§2a force brute (longueur 4, 3 écarts de temps) : écart à la référence : " .. tostring(bad))
  local cases_a = cases
  expand({}, 0, 0, 5, { 20, 31 }, { 0, 1 }, { false, 1, 2 })
  check(bad == nil, "§2b force brute (longueur 5, 2 écarts) : écart à la référence : " .. tostring(bad))
  check(cases_a > 300000 and cases > 600000, "§2c nombre de cas joués : " .. cases_a .. " puis " .. cases)

  return pass - p0, fail - f0
end

local Op0 = assert(load_op(SRC))
local p, f = suite(Op0)
print(string.format("[ORDRE-PROGRES] §1-§2 : %d OK, %d ECHEC(S)", p, f))

-- §3 déterminisme et pureté du module
do
  local hist = {}
  for i = 1, 20 do hist[i] = { t = i * 4 * MIN, built = (i > 12) and 1 or 0, m = (i % 3 == 0) and (30 - i) or nil } end
  local a, ra = play(Op0, hist)
  local b, rb = play(Op0, hist)
  local same = #a == #b and ra.progress_tick == rb.progress_tick and ra.best_missing == rb.best_missing
  for i = 1, #a do same = same and a[i] == b[i] end
  check(same, "§3a même suite, même résultat")
  local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:find("[^i]pairs%(") and not code:find("math.random", 1, true) and not code:find("os.time", 1, true) and
    not code:find("os.clock", 1, true), "§3b ni pairs, ni hasard, ni temps mesuré dans le module")
  check(not code:find("require", 1, true) and not code:find("game", 1, true) and not code:find("global", 1, true),
    "§3c aucune API du jeu, aucun require, aucun global")
  local named = false
  for _, w in ipairs({ "iron", "copper", "plate", "belt", "inserter", "assembling", "stone", "coal", "steel" }) do
    if code:find(w, 1, true) then named = true end
  end
  check(not named, "§3d aucun nom du jeu dans le code")
end

-- §4 mutants
local MUTANTS = {
  { "baisse au moins égale comptée", "elseif missing < rec.best_missing then", "elseif missing <= rec.best_missing then" },
  { "baisse du manque sans effet", "rec.best_missing, rec.progress_tick = missing, tick", "rec.best_missing = missing" },
  { "première mesure comptée comme progrès", "    if rec.best_missing == nil then\n      rec.best_missing = missing",
    "    if rec.best_missing == nil then\n      rec.best_missing, rec.progress_tick = missing, tick" },
  { "oscillation comptée", "elseif missing < rec.best_missing then", "elseif missing ~= rec.best_missing then" },
  { "entités posées sans effet", "if built ~= rec.built then rec.built, rec.progress_tick = built, tick end",
    "if built ~= rec.built then rec.built = built end" },
  { "délai strict relâché", "if tick - last > Op.TTL then", "if tick - last >= Op.TTL then" },
  { "délai de 30 min allongé", "Op.TTL = 30 * 3600", "Op.TTL = 60 * 3600" },
  { "délai de 30 min raccourci", "Op.TTL = 30 * 3600", "Op.TTL = 15 * 3600" },
  { "plafond supprimé", "tick - rec.opened > Op.MAX_UNBUILT then", "tick - rec.opened > 1e12 then" },
  { "plafond même chantier commencé", "(rec.built or 0) == 0 and rec.opened", "rec.opened" },
  { "plafond même sans mesure", "if rec.best_missing ~= nil and (rec.built or 0) == 0", "if (rec.built or 0) == 0" },
  { "plafond allongé", "Op.MAX_UNBUILT = 60 * 3600", "Op.MAX_UNBUILT = 120 * 3600" },
  { "dernier progrès ignoré", "local last = rec.progress_tick or rec.opened or tick", "local last = rec.opened or tick" },
  { "manque absent compté nul", "  if missing ~= nil then\n    if rec.best_missing == nil then",
    "  missing = missing or 0\n  if missing ~= nil then\n    if rec.best_missing == nil then" },
  { "raison du plafond perdue", "return true, \"plafond\"", "return true, \"ttl\"" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif absent)" else
    local msrc = SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1)
    local mod = load_op(msrc)
    local f2 = 1
    if mod then
      local pp, ff = pass, fail
      QUIET = true
      local ok, _, nf = pcall(suite, mod)
      QUIET = false
      f2 = ok and nf or 1
      pass, fail = pp, ff -- les échecs d'un mutant ne comptent pas
    end
    if f2 > 0 then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(#kept == 0, "§4 mutants NON refusés : " .. table.concat(kept, " ; "))
print(string.format("[ORDRE-PROGRES] mutants refusés : %d sur %d", refused, #MUTANTS))
check(#MUTANTS >= 10, "§4 au moins 10 mutants")

print(string.format("[ORDRE-PROGRES] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
