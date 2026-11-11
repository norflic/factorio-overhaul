--[[
  Lot RESEAU-GRAPHE (suite de l'audit) : test hors jeu du dimensionnement du quai d'entrée (shared/team/quai_debit.lua, M.ARMS de modules.lua,
  P.feeder à plusieurs bras de plan.lua).
    §1 choix du bras par le débit ; §2 sources et débit par voie sur les gabarits réels ; §3 n borné à ce que le quai porte, sur les 51
    gabarits : le défaut relevé par l'audit disparaît pour ceux qui ont une extension ; §4 P.feeder : un bras = comme avant, deux bras =
    deux fois plus de bras et de coffres, tuiles distinctes de l'arrivée latérale ; §5 hygiène ; §6 mutants.
  Usage : lua5.2 tests/quai_debit_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/quai_debit.lua")
local M = require("shared.team.modules")
local P = require("shared.team.plan")
local Au = require("shared.team.blocs_audit")

local function load_qd(src)
  local fn, err = load(src, "=quai_debit", "t")
  assert(fn, err)
  return fn()
end

local function ser(v)
  if type(v) == "table" then
    local ks = {}
    for k in next, v do ks[#ks + 1] = k end
    table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(ks) do out[#out + 1] = tostring(k) .. "=" .. ser(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
  end
  return tostring(v)
end

local function suite(Qd, quick, out)
  local ok_n, fail_n, failed = 0, 0, {}
  local function check(c, msg)
    if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 failed[#failed + 1] = msg if out then print("  ECHEC : " .. msg) end end
  end

  -- §1 bras
  check(M.ARMS[1] ~= nil and M.spec(M.ARMS[1]).rate <= M.spec(M.ARMS[#M.ARMS]).rate and #M.ARMS >= 2, "1.1 M.ARMS : bras électriques de portée 1, du plus lent au plus rapide (" .. table.concat(M.ARMS, ", ") .. ")")
  local slow, fast = M.ARMS[1], M.ARMS[#M.ARMS]
  local n1, c1, ok1 = Qd.arm_for(M, 0.5)
  check(n1 == slow and c1 == 1 and ok1, "1.2 0,5/s : le bras de base, un seul")
  local n2, c2, ok2 = Qd.arm_for(M, 1.5)
  check(n2 == fast and c2 == 1 and ok2, "1.3 1,5/s : un bras rapide")
  local n3, c3, ok3 = Qd.arm_for(M, 3.0)
  check(n3 == fast and c3 == 2 and ok3, "1.4 3/s : deux bras rapides")
  local n4, c4, ok4 = Qd.arm_for(M, 12.0)
  check(n4 == fast and c4 == 2 and not ok4, "1.5 12/s : deux bras rapides ne suffisent pas (tenu = faux)")
  check(select(2, Qd.arm_for(M, 3.0, 1)) == 1, "1.6 un seul bras permis : un seul rendu")
  check(math.abs(Qd.arm_cap(M, fast, 2) - 2 * M.spec(fast).rate * M.MARGIN) < 1e-9, "1.7 capacité = cadence x marge x nombre de bras")

  -- §2 sources et voies sur les gabarits réels
  local g = M.get("engrenages")
  local src = Qd.sources(g)
  local nsrc = 0
  for _ in next, src do nsrc = nsrc + 1 end
  check(nsrc == 1, "2.1 engrenages : une entrée servie par quai (un objet sur les deux voies d'un port compte une fois)")
  local lf = Qd.lane_flows(g)
  local the_item
  for k in next, lf do the_item = k end
  check(the_item and math.abs(lf[the_item] - g.inputs[the_item]) < 1e-9, "2.2 une source : le débit de la voie est le débit d'entrée")
  check(next(Qd.sources(g, function() return true end)) == nil, "2.3 skip : un objet servi autrement n'est pas jugé")
  local c = M.get("circuits-verts")
  local cs = Qd.sources(c)
  local cn = 0
  for _ in next, cs do cn = cn + 1 end
  check(cn == 2, "2.4 circuits verts : deux entrées")

  -- §3 n borné
  if not quick then
    local ctx = { recipes = M.RECIPES, spec_of = M.spec, fuel = "coal", ores = M.ORES, ignore = { ["electricity-kw"] = true } }
    local list = M.catalogue()
    for _, e in ipairs(M.era_variants()) do list[#list + 1] = e.g end
    local before, after, fixed, still, noext, fewer = 0, 0, 0, 0, 0, 0
    for _, h in ipairs(list) do
      local rep0 = M.analyze(h)
      local r0 = Au.audit(h, rep0, ctx)
      local gap0 = #Au.of_code(r0, "quai-sous-dimensionne") > 0
      local skip = Qd.skip(M, h)
      if gap0 then before = before + 1 end
      if gap0 then
        local n, h2 = Qd.max_n(M, h, skip)
        if not n then noext = noext + 1 else
          local p = Qd.plan(M, h2, skip)
          if p.ok then fixed = fixed + 1 else still = still + 1 end
          if h2 ~= h then fewer = fewer + 1 end
          check(#M.analyze(h2).errors == 0, "3.0 " .. h.key .. " refait à n = " .. tostring(n) .. " : l'analyse ne trouve aucune erreur")
        end
      end
    end
    -- (ILOTS-COLONNES F463, 073d7102 : circuits rouges et moteurs-n7 refaits en îlots à liaisons par colonne ne sont plus en écart : 21 -> 19)
    check(before >= 19, "3.1 le défaut de l'audit est là au départ (" .. before .. " gabarits)")
    check(fixed >= 1 and fewer >= 1, "3.2 des gabarits sont refaits à un n plus petit et tiennent (" .. fixed .. " tiennent, " .. fewer .. " refaits, " .. still .. " ne tiennent pas, " .. noext .. " sans extension)")
    print(string.format("[QUAI-DEBIT] sur %d gabarits : %d en écart avant ; avec le bras choisi par le débit et n borné : %d tiennent, %d ne tiennent pas même à n = 1, %d sans extension", #list, before, fixed, still, noext))
    -- un gabarit qui tient d'emblée n'est pas touché
    local e = M.get("fonderie-fer-pierre")
    local ne, he = Qd.max_n(M, e, Qd.skip(M, e))
    check(ne == e.args[e.extensions[1].arg] and he == e, "3.3 une fonderie dont le minerai arrive par foreuses et tapis n'est pas refaite")
  end
  -- n borné : bornes exactes (une fonderie dont le minerai passerait par le quai : 8 rangées demandent 5 minerais/s)
  local eg = M.get("fonderie-fer-pierre")
  local n, h = Qd.max_n(M, eg, nil)
  local cur = eg.args[eg.extensions[1].arg]
  check(n and n > 1 and n < cur and h and Qd.plan(M, h, nil).ok, "3.4 fonderie sur quai : n réduit de " .. cur .. " à " .. tostring(n) .. ", le quai tient")
  local above = n and M.extend(eg, n + 1)
  check(n and above and not Qd.plan(M, above, nil).ok, "3.5 n est le plus grand qui tient (n + 1 ne tient pas)")
  local keep = M.get("circuits-rouges")
  local nk, hk = Qd.max_n(M, keep, nil)
  check(nk == keep.args[keep.extensions[1].arg] and hk == keep, "3.6 un gabarit dont le quai tient d'emblée n'est pas refait")
  -- plusieurs sources, plusieurs voies (gabarit fictif)
  local fake = { inputs = { a = 3, b = 1 }, ports = { { kind = "tapis", io = "in", lanes = { "a", "b" } }, { kind = "tapis", io = "in", lanes = { "a", "a" } } } }
  local ff = Qd.lane_flows(fake)
  check(ff.a == 1.5 and ff.b == 1, "3.7 un objet servi par deux ports : le débit se partage (a 3/s sur 2 ports = 1,5/s par voie)")
  local fp = Qd.plan(M, fake)
  check(fp.flow == 1.5 and math.abs(fp.caps.a - 2 * Qd.arm_cap(M, fp.arm, fp.count)) < 1e-9, "3.8 le plan retient le plus gros débit de voie ; la capacité d'un objet est celle de ses voies")
  local fake2 = { inputs = { a = 1, b = 3 }, ports = { { kind = "tapis", io = "in", lanes = { "a", "b" } } } }
  check(Qd.plan(M, fake2).flow == 3, "3.9 le plus gros débit de voie est le plus grand")

  -- §4 P.feeder
  local port = { x = 10, y = 10, dir = 4, lanes = { "a", "b" } }
  local f0 = P.feeder(port, { "quai", "quai" }, "inserter", nil)
  local f1 = P.feeder(port, { "quai", "quai" }, "inserter", nil, 1)
  local f2 = P.feeder(port, { "quai", "quai" }, "fast-inserter", nil, 2)
  check(ser(f0) == ser(f1), "4.1 un bras : identique à l'appel d'avant")
  local function count(list, role) local k = 0 for _, e in ipairs(list) do if e.role == role then k = k + 1 end end return k end
  check(count(f1.entities, "quai-bras") == 2 and count(f1.entities, "quai") == 2 and #f1.chests == 2, "4.2 deux voies, un bras : 2 bras, 2 coffres")
  check(count(f2.entities, "quai-bras") == 4 and count(f2.entities, "quai") == 4 and #f2.chests == 4, "4.3 deux voies, deux bras : 4 bras, 4 coffres")
  local seen, dup = {}, false
  for _, e in ipairs(f2.entities) do
    local k = e.x .. ":" .. e.y
    if seen[k] then dup = true end
    seen[k] = true
  end
  check(not dup, "4.4 aucune tuile occupée deux fois")
  local f3 = P.feeder({ x = 10, y = 10, dir = 4, lanes = { "a", "b" } }, { "tapis", "quai" }, "fast-inserter", nil, 2)
  local seen3, dup3 = {}, false
  for _, e in ipairs(f3.entities) do
    local k = e.x .. ":" .. e.y
    if seen3[k] then dup3 = true end
    seen3[k] = true
  end
  for _, a in ipairs(f3.arrivals) do
    if seen3[(a.x + 0.5) .. ":" .. (a.y + 0.5)] then dup3 = true end
  end
  check(not dup3 and #f3.arrivals == 1 and count(f3.entities, "quai-bras") == 2, "4.5 une voie en tapis, l'autre en quai à deux bras : le second bras ne prend pas la tuile de l'arrivée latérale")
  check(count(P.feeder(port, { "quai", nil }, "inserter", nil, 2).entities, "tete") == 3, "4.6 deux bras : la tête a ses 3 tuiles même sans tapis")
  check(count(P.feeder(port, { "quai", nil }, "inserter", nil, 1).entities, "tete") == 1, "4.7 un bras sans tapis : une tuile de tête, comme avant")

  return ok_n, fail_n, failed
end

local Qd = load_qd(SRC)
local ok_n, fail_n = suite(Qd, false, true)
local function check(c, msg)
  if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end
end

do
  local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:find("iron%-") and not code:find("copper%-") and not code:find("[a-z]%-inserter") and not code:find("assembling") and not code:find("%-plate"),
    "5.1 aucun nom d'objet (les bras viennent de M.ARMS)")
  check(not code:find("[^i%.]pairs%("), "5.2 aucun pairs")
  check(not code:find("math%.random") and not code:find("os%.time") and not code:find("os%.clock") and not code:find("math%.sin"), "5.3 ni hasard, ni horloge")
  check(not code:find("game%.") and not code:find("global") and not code:find("script%.") and not code:find("require"), "5.4 aucune API du jeu, aucun require")
end

local MUTANTS = {
  { "un objet sur deux voies compté deux fois", "if it and not seen[it] and not (skip and skip(it)) then seen[it] = true; n[it] = (n[it] or 0) + 1 end", "if it and not (skip and skip(it)) then n[it] = (n[it] or 0) + 1 end" },
  { "skip ignoré", "and not (skip and skip(it)) then seen[it]", "then seen[it]" },
  { "débit de voie non divisé", "out[it] = ((g.inputs or {})[it] or 0) / src[it]", "out[it] = ((g.inputs or {})[it] or 0)" },
  { "marge ignorée", "return M.spec(name).rate * M.MARGIN * count", "return M.spec(name).rate * count" },
  { "nombre de bras ignoré", "return M.spec(name).rate * M.MARGIN * count", "return M.spec(name).rate * M.MARGIN" },
  { "jamais plus d'un bras", "Qd.MAX_ARMS = 2", "Qd.MAX_ARMS = 1" },
  { "repli sans le plus rapide", "return arms[#arms] or M.ELECTRIC_ARM, math.min(max_arms or Qd.MAX_ARMS, Qd.MAX_ARMS), false", "return arms[1], math.min(max_arms or Qd.MAX_ARMS, Qd.MAX_ARMS), false" },
  { "tenu toujours vrai", "if name then return name, count, true end", "if true then return name or arms[#arms], (count > 0) and count or 1, true end" },
  { "plus gros débit de voie : le plus petit", "if flows[it] > top then top = flows[it] end end\n  local name, count, ok", "if flows[it] < top or top == 0 then top = flows[it] end end\n  local name, count, ok" },
  { "capacité par objet sans le nombre de sources", "caps[it] = cap * src[it]", "caps[it] = cap" },
  { "n borné trop bas", "local n = math.max(1, math.floor(cur * best / top + 1e-9))", "local n = 1" },
}
local refused = 0
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    check(false, "6 motif de mutant introuvable : " .. m[1])
  else
    local okl, Mu = pcall(load_qd, SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    if not okl then refused = refused + 1 else
      local oks, okn, failn = pcall(suite, Mu, true, false)
      if not oks or failn > 0 then refused = refused + 1 else check(false, "6 mutant SURVIVANT : " .. m[1]) end
    end
  end
end
print(string.format("[QUAI-DEBIT] mutants refusés : %d sur %d", refused, #MUTANTS))
check(refused == #MUTANTS, "6.1 tous les mutants sont refusés")
print(string.format("[QUAI-DEBIT] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
