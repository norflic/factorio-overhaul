--[[
  Lot PERF4 : Gen.resource_values (shared/ai3/general.lua) rend EXACTEMENT ce que rendait la version d'avant (copiée ici,
  `ref_rv` : un dépliage COMPLET, G.prepare, par ressource inconnue, à chaque appel).
  Ce qui a changé :
    - le dépliage d'essai ne calcule plus que la FAISABILITÉ (G.prepare_feas : la même boucle de point fixe, sans la boucle des
      coûts, que Gen.resource_values ne lit pas : elle ne lit que feas et tfeas, Gen.value ne lit que feas) ;
    - mémo par ressource et par clé d'état (argument `memo`), pour les appels répétés sur un même état (mur des recherches).

  1. Partie du moteur simulé (4 factions, 30 PNJ, financées : celle de tests/iag_scale_mock.lua) : à CHAQUE appel du jeu, le
     résultat est comparé, sérialisé, à `ref_rv` sur le même état ; coût des deux, mesuré.
  2. Journal : la même partie rejouée avec `ref_rv` à la place donne les mêmes lignes de journal, toutes (F238).
  3. Mur des recherches (pur) : deux appels sur le même état : le second sert TOUTES les ressources par le mémo, même résultat ;
     un état changé n'est pas servi par l'ancien mémo.
  4. Mutants : mémo jamais invalidé, mémo commun à toutes les ressources, faisabilité sans les technologies : au moins un écart.

  Usage : lua5.2 tests/perf4_rv_test.lua [minutes = 15]
]]
package.path = "./?.lua;" .. package.path
local minutes = tonumber(arg[1]) or 15
local M = require("tests.mock_engine")

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 print("OK     " .. msg) else fail_n = fail_n + 1 print("ECHEC : " .. msg) end
end

local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end

local function ser(v, out)
  local t = type(v)
  if t == "table" then
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
      out[#out + 1] = tostring(k) .. "="
      ser(v[k], out)
      out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  else
    out[#out + 1] = tostring(v)
  end
  return out
end
local function s(v) return table.concat(ser(v, {})) end

local function sorted_keys(t)
  local k = {}
  for x in pairs(t) do k[#k + 1] = x end
  table.sort(k, function(a, b) return tostring(a) < tostring(b) end)
  return k
end

--- La version d'AVANT, recopiée telle quelle (0.6.53, 38ee70e1) : dépliage complet par ressource, sans mémo.
local function ref_rv(Gen, G, cat, ev, state, ctx)
  ctx = ctx or {}
  local w = ctx.weights
  local function wf(ww, fam) return ((ww or {})[fam] or 1000) / 1000 end
  local out = {}
  local base_role = { pack = Gen.V_PACK, militaire = Gen.V_MIL, machine = Gen.V_MACHINE, logistique = Gen.V_LOG }
  for _, res in ipairs(cat.resource_list) do
    local r = cat.resources[res]
    if not state.known[res] and r and cat.g.by_rescat[r.category] then
      local known = {}
      for _, k in ipairs(sorted_keys(state.known)) do known[k] = state.known[k] end
      known[res] = true
      local s2 = { stock = state.stock, techs = state.techs, built = state.built, known = known }
      local ev2 = G.prepare(cat.g, s2)
      local v, techs = 0, {}
      for _, t in ipairs(cat.tech_list) do
        if not state.techs[t] and ev2.tfeas[t] and not ev.tfeas[t] then
          local tv = Gen.value(cat, ev2, s2, t, ctx)
          if tv > 0 then
            v = v + tv
            techs[#techs + 1] = t
          end
        end
      end
      for _, item in ipairs(sorted_keys(cat.role)) do
        if ev2.feas[item] and not ev.feas[item] then
          local role = cat.role[item]
          v = v + math.floor((base_role[role] or 0) * wf(w, Gen.FAMILY[role] or "capital"))
        end
      end
      out[#out + 1] = { res, v, techs }
    end
  end
  table.sort(out, function(a, b)
    if a[2] ~= b[2] then return a[2] > b[2] end
    return a[1] < b[1]
  end)
  return out
end

--- Joue la partie. mode : "jeu" (version du jeu, contrôlée à chaque appel contre ref_rv), "ref" (ref_rv à la place : la partie
--- d'avant), et les mutants "fige" (clé constante), "commun" (un mémo pour toutes les ressources), "notech" (faisabilité sans
--- les technologies). Rend { logs, calls, diffs, t_new, t_ref, max_new, max_ref, last = {cat, ev, state, ctx} }.
local function play(mode)
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
  M.world().settings["fo-recruit-idle-max"] = 60
  M.world().settings["fo-war-workers"] = 30
  local Gen = require("shared.ai3.general")
  local G = require("shared.ai3.graphe")
  local orig = Gen.resource_values
  local r = { calls = 0, diffs = 0, t_new = 0, t_ref = 0, max_new = 0, max_ref = 0 }
  Gen.resource_values = function(cat, ev, state, ctx, memo)
    if mode == "ref" then return ref_rv(Gen, G, cat, ev, state, ctx) end
    local use = memo
    local real_key, real_feas = G.state_key, G.prepare_feas
    if mode == "fige" then
      G.state_key = function() return "x" end
    elseif mode == "commun" then
      use = setmetatable({}, { __index = function() return memo.one end, __newindex = function(_, _, v) memo.one = v end })
    elseif mode == "notech" then
      G.prepare_feas = function(c, st) local e = real_feas(c, st) e.tfeas = {} return e end
    end
    r.calls = r.calls + 1
    local c0 = os.clock()
    local got = orig(cat, ev, state, ctx, use)
    local c1 = os.clock()
    G.state_key, G.prepare_feas = real_key, real_feas
    local want = ref_rv(Gen, G, cat, ev, state, ctx)
    local c2 = os.clock()
    r.t_new, r.t_ref = r.t_new + (c1 - c0), r.t_ref + (c2 - c1)
    if c1 - c0 > r.max_new then r.max_new = c1 - c0 end
    if c2 - c1 > r.max_ref then r.max_ref = c2 - c1 end
    if s(got) ~= s(want) then r.diffs = r.diffs + 1 end
    r.last = { cat = cat, ev = ev, state = state, ctx = ctx }
    return got
  end
  assert(remote.call("factorio-overhaul", "war_start", 4, 100, nil, 320) == true)
  remote.call("factorio-overhaul", "war_fund", 3000)
  M.run_ticks(minutes * 3600)
  r.logs = M.world().logs
  r.Gen, r.G, r.orig = Gen, G, orig
  Gen.resource_values = orig
  return r
end

local t0 = os.clock()
local a = play("jeu")
print(string.format("[PERF4-RV] partie (%d min) : %d appel(s), %d écart(s) contre la version d'avant, %d ligne(s) de journal (%.1f s)",
  minutes, a.calls, a.diffs, #a.logs, os.clock() - t0))
print(string.format("[PERF4-RV] coût par appel (moteur simulé, MÊMES états) : avant %.2f ms (max %.1f), après %.2f ms (max %.1f) ; total %.0f -> %.0f ms",
  a.t_ref * 1e3 / math.max(1, a.calls), a.max_ref * 1e3, a.t_new * 1e3 / math.max(1, a.calls), a.max_new * 1e3, a.t_ref * 1e3, a.t_new * 1e3))
check(a.calls >= 4, "la partie appelle Gen.resource_values (" .. a.calls .. ")")
check(a.diffs == 0, "après = avant à chaque appel de la partie (" .. a.diffs .. " écart(s))")

-- 3. Mur des recherches : le même état deux fois (pur, sur le dernier état de la partie).
do
  local L, Gen = a.last, a.Gen
  local memo = {}
  local c0 = os.clock()
  local first = Gen.resource_values(L.cat, L.ev, L.state, L.ctx, memo)
  local c1 = os.clock()
  local n = 0
  for _ in pairs(memo) do n = n + 1 end
  local G = a.G
  local preps, real = 0, G.prepare_feas
  G.prepare_feas = function(...) preps = preps + 1 return real(...) end
  local c2 = os.clock()
  local again = Gen.resource_values(L.cat, L.ev, L.state, L.ctx, memo)
  local c3 = os.clock()
  G.prepare_feas = real
  local want = ref_rv(Gen, G, L.cat, L.ev, L.state, L.ctx)
  check(n > 0 and n == #want and preps == 0 and s(again) == s(want) and s(first) == s(want),
    string.format("mur : second appel sur le même état servi en entier par le mémo (%d ressource(s), %d dépliage(s) refait(s)), même résultat", n, preps))
  print(string.format("[PERF4-RV] mur (même état) : premier appel %.1f ms, second %.1f ms", (c1 - c0) * 1e3, (c3 - c2) * 1e3))
  -- état changé (une ressource inconnue devient connue) : l'ancien mémo ne sert pas
  local res = want[1] and want[1][1]
  if res then
    local known = {}
    for k, v in pairs(L.state.known) do known[k] = v end
    known[res] = true
    local st2 = { stock = L.state.stock, techs = L.state.techs, built = L.state.built, known = known }
    local ev2 = G.prepare(L.cat.g, st2)
    local got2 = Gen.resource_values(L.cat, ev2, st2, L.ctx, memo)
    local want2 = ref_rv(Gen, G, L.cat, ev2, st2, L.ctx)
    check(s(got2) == s(want2), "mur : état changé (" .. res .. " connue) : pas servi par l'ancien mémo, même résultat que la version d'avant")
  end
  -- État changé dans l'autre sens : une ressource CONNUE et extractible redevient inconnue (le mémo de l'état d'avant la croit
  -- connue dans chaque dépliage d'essai). Version du jeu : même résultat que la version d'avant ; mutant « mémo jamais
  -- invalidé » (clé constante) : un écart.
  local gone
  for _, k in ipairs(sorted_keys(L.state.known)) do
    local rr = L.cat.resources[k]
    if L.state.known[k] and rr and L.cat.g.by_rescat[rr.category] then gone = k break end
  end
  if gone then
    local known = {}
    for k, v in pairs(L.state.known) do if k ~= gone then known[k] = v end end
    local st3 = { stock = L.state.stock, techs = L.state.techs, built = L.state.built, known = known }
    local ev3 = G.prepare(L.cat.g, st3)
    local want3 = ref_rv(Gen, G, L.cat, ev3, st3, L.ctx)
    local mg = {}
    Gen.resource_values(L.cat, L.ev, L.state, L.ctx, mg)
    check(s(Gen.resource_values(L.cat, ev3, st3, L.ctx, mg)) == s(want3),
      "mur : " .. gone .. " redevenue inconnue : le mémo de l'état d'avant ne sert pas, même résultat que la version d'avant")
    local real_key = G.state_key
    G.state_key = function() return "x" end
    local mm = {}
    Gen.resource_values(L.cat, L.ev, L.state, L.ctx, mm)
    local stale = Gen.resource_values(L.cat, ev3, st3, L.ctx, mm)
    G.state_key = real_key
    check(s(stale) ~= s(want3), "mutant « mémo jamais invalidé » détecté (" .. gone .. " redevenue inconnue)")
  else
    check(false, "mur : aucune ressource connue extractible pour le contrôle d'invalidation")
  end
end

-- 4. Pur, sur le catalogue de tests/iag_fixture.lua (celui d'iag_test) : des états où les ressources inconnues RAPPORTENT (cuivre,
-- fer, charbon inconnus) ; la partie du moteur simulé n'en a que de valeur nulle à 15 min, où un mémo faux ne se voit pas.
do
  local F = require("tests.iag_fixture")
  local K = require("shared.ai3.catalogue")
  local Gen = require("shared.ai3.general")
  local G = require("shared.ai3.graphe")
  local T = require("shared.team.config")
  local cat = K.build(F.dump(), F.opts())
  local cu, fe, co = T.outposts.copper.resource, T.outposts.iron.resource, T.outposts.coal.resource
  local states = {
    { "cuivre inconnu", F.start_state({ unknown = { cu } }) },
    { "cuivre et fer inconnus", F.start_state({ unknown = { cu, fe } }) },
    { "cuivre, fer et charbon inconnus", F.start_state({ unknown = { cu, fe, co } }) },
    { "tout connu", F.start_state({}) },
  }
  for _, e in ipairs(states) do e[2].stock[T.outposts.copper.product] = nil end
  -- a. G.prepare_feas = la faisabilité de G.prepare (tout sauf les coûts), sur ces états et sur chacun de leurs essais
  local feas_ok, n_cmp = true, 0
  local function same_feas(st)
    local a, b = G.prepare(cat.g, st), G.prepare_feas(cat.g, st)
    n_cmp = n_cmp + 1
    return s({ a.feas, a.tfeas, a.order, a.nfeas, a.passes, a.known, a.techs, a.built })
      == s({ b.feas, b.tfeas, b.order, b.nfeas, b.passes, b.known, b.techs, b.built }) and next(b.cost) == nil
  end
  for _, e in ipairs(states) do
    feas_ok = feas_ok and same_feas(e[2])
    for _, res in ipairs(cat.resource_list) do
      if not e[2].known[res] then
        local known = {}
        for k, v in pairs(e[2].known) do known[k] = v end
        known[res] = true
        feas_ok = feas_ok and same_feas({ stock = e[2].stock, techs = e[2].techs, built = e[2].built, known = known })
      end
    end
  end
  check(feas_ok, "G.prepare_feas rend la faisabilité de G.prepare (feas, tfeas, order, nfeas, passes) sans coûts (" .. n_cmp .. " états)")
  -- b. résultat identique à la version d'avant, sans mémo puis avec un mémo partagé d'un état à l'autre
  local memo, all_ok, nz = {}, true, 0
  for _, e in ipairs(states) do
    local ev = Gen.prepare(cat, e[2])
    local want = ref_rv(Gen, G, cat, ev, e[2], {})
    for _, x in ipairs(want) do if x[2] > 0 then nz = nz + 1 end end
    local a1 = Gen.resource_values(cat, ev, e[2], {}, nil)
    local a2 = Gen.resource_values(cat, ev, e[2], {}, memo)
    local a3 = Gen.resource_values(cat, ev, e[2], {}, memo)
    if not (s(a1) == s(want) and s(a2) == s(want) and s(a3) == s(want)) then
      all_ok = false
      print("   écart : " .. e[1])
    end
  end
  check(all_ok and nz >= 3, "fixture : même résultat que la version d'avant, sans et avec mémo, d'un état à l'autre (" .. nz .. " ressource(s) de valeur > 0)")
  -- c. mutants : chacun doit donner au moins un écart sur l'enchaînement des 4 états
  local function run_chain(setup, teardown)
    local mm, diff = {}, false
    for _, e in ipairs(states) do
      local ev = Gen.prepare(cat, e[2])
      local want = ref_rv(Gen, G, cat, ev, e[2], {})
      setup(mm)
      local got = Gen.resource_values(cat, ev, e[2], {}, mm.use or mm)
      teardown()
      if s(got) ~= s(want) then diff = true end
    end
    return diff
  end
  local real_key, real_feas = G.state_key, G.prepare_feas
  check(run_chain(function() G.state_key = function() return "x" end end, function() G.state_key = real_key end),
    "mutant « mémo jamais invalidé » (clé constante) détecté")
  check(run_chain(function(mm)
      mm.use = mm.use or setmetatable({}, { __index = function() return mm.one end, __newindex = function(_, _, v) mm.one = v end })
    end, function() end), "mutant « un mémo pour toutes les ressources » détecté")
  check(run_chain(function() G.prepare_feas = function(c, st) local e = real_feas(c, st) e.tfeas = {} return e end end,
    function() G.prepare_feas = real_feas end), "mutant « faisabilité sans les technologies » détecté")
  check(run_chain(function() G.prepare_feas = function(c, st) local e = real_feas(c, st) e.feas = {} return e end end,
    function() G.prepare_feas = real_feas end), "mutant « faisabilité sans les objets » détecté")
  -- d. coût sur la fixture (mêmes états, 20 répétitions)
  local c0 = os.clock()
  for _ = 1, 20 do
    for _, e in ipairs(states) do ref_rv(Gen, G, cat, Gen.prepare(cat, e[2]), e[2], {}) end
  end
  local c1 = os.clock()
  for _ = 1, 20 do
    for _, e in ipairs(states) do Gen.resource_values(cat, Gen.prepare(cat, e[2]), e[2], {}, nil) end
  end
  local c2 = os.clock()
  print(string.format("[PERF4-RV] fixture (4 états x 20, préparation de la base comprise) : avant %.0f ms, après %.0f ms (sans mémo)",
    (c1 - c0) * 1e3, (c2 - c1) * 1e3))
end

-- Lot PERF4 (petrole:think) : Pet.pack_recipes rend, dans le même ordre, les recettes que la boucle d'avant gardait (au moins un
-- pack produit) avec ces packs dans leur ordre.
do
  local General = require("script.ai3.general")
  local Pet = require("script.ai3.petrole")
  local c = General.catalogue()
  local old = {}
  local names = {}
  for rn in pairs(c.products) do names[#names + 1] = rn end
  table.sort(names)
  for _, rn in ipairs(names) do
    for _, pk in ipairs(c.products[rn]) do
      if c.packs[pk] then old[#old + 1] = rn .. ">" .. pk end
    end
  end
  local new = {}
  for _, row in ipairs(Pet.pack_recipes(c)) do
    for _, pk in ipairs(row.packs) do new[#new + 1] = row.rn .. ">" .. pk end
  end
  check(#old > 0 and table.concat(old, ",") == table.concat(new, ","),
    string.format("petrole : recettes à pack identiques (%d couples avant, %d après, sur %d recettes)", #old, #new, #names))
  print(string.format("[PERF4-RV] petrole : %d recette(s) parcourue(s) avant, %d après (%d couple(s) recette>pack)", #names,
    #Pet.pack_recipes(c), #new))
  local mut = {}
  for i = 2, #new do mut[#mut + 1] = new[i] end
  check(table.concat(old, ",") ~= table.concat(mut, ","), "petrole : mutant (un couple oublié) détecté")
end

local t1 = os.clock()
local b = play("ref")
print(string.format("[PERF4-RV] même partie avec la version d'avant : %d ligne(s) de journal (%.1f s)", #b.logs, os.clock() - t1))
local first = nil
for i = 1, math.max(#a.logs, #b.logs) do
  if a.logs[i] ~= b.logs[i] then first = i break end
end
check(#a.logs > 100, "la partie écrit un journal (" .. #a.logs .. " lignes)")
check(first == nil, "journal identique ligne à ligne, après contre avant" .. (first and (" ; premier écart ligne " .. first .. " :\n  après : "
  .. tostring(a.logs[first]) .. "\n  avant : " .. tostring(b.logs[first])) or ""))

-- (Les mutants se jouent sur la fixture, §4 : dans la partie du moteur simulé, à 15 min, toutes les ressources inconnues valent
-- 0, et un mémo faux n'y change rien de visible : mesuré, 0 écart pour les trois mutants joués dans la partie.)

print(string.format("[PERF4-RV] BILAN : %d OK, %d ECHEC(S) (%.1f s)", ok_n, fail_n, os.clock() - t0))
os.exit(fail_n == 0 and 0 or 1)
