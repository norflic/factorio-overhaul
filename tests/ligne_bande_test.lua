--[[
  Lot RACCORD-BANDE 2 (partie neuve 0.6.72 : « plus proche cible a 163 a 281 tuiles », 0 foreuse électrique) : shared/team/ligne_bande.lua, la ligne de
  poteaux par tronçons d'un poteau alimenté jusqu'à une bande lointaine.
    §1 sol libre, 280 tuiles : ligne complète, chaque pas à portée, nombre de poteaux voisin du minimum ;
    §2 un lac en travers de la droite : contourné ; §3 des tuiles occupées semées (thermiques, bâtiments) : aucun poteau dessus ;
    §4 mur infranchissable : refus avec la raison ; arbres (« clear ») : seulement au second essai ;
    §5 coût d'une étape (debug.sethook) ; l'état ne contient que des nombres (rien de plus dans global) ; déterminisme ;
    §6 mutants.
  Usage : lua5.2 tests/ligne_bande_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local P = require("shared.team.plan")

local passes, failures = 0, 0
local function check(cond, msg) if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end end
local function read(path) local fh = assert(io.open(path, "rb")) local s = fh:read("*a") fh:close() return s end
local SRC = read("shared/team/ligne_bande.lua")
local function load_lb(src) return assert(load(src, "=ligne_bande(variante)"))() end
local Lb = load_lb(SRC)

local R = 7.5
local function key(x, y) return (math.floor(x) + 50000) * 100000 + (math.floor(y) + 50000) end

--- Carte : rectangles occupés (eau, bâtiments), rectangles d'arbres (libres seulement si trees).
local function world(blocked_rects, tree_rects)
  local function set_of(rects)
    local s = {}
    for _, r in ipairs(rects) do for x = r[1], r[3] do for y = r[2], r[4] do s[key(x, y)] = true end end end
    return s
  end
  local blk, trees = set_of(blocked_rects), set_of(tree_rects or {})
  return {
    blk = blk, trees = trees,
    free = function(x, y, tr)
      local k = key(x, y)
      if blk[k] then return false end
      if trees[k] and not tr then return false end
      return true
    end,
  }
end

local function ctx_of(w)
  return { free = w.free, pole_chain = P.pole_chain, opts = function(dist) return { div = 2, max_cells = 200, max_expand = 250, widths = { 1, 2 } } end }
end

local function run(Lb2, a, b, w, max_steps)
  local st = Lb2.new(a, b, R)
  local status, why
  local steps = 0
  repeat
    status, why = Lb2.step(st, ctx_of(w))
    steps = steps + 1
  until status ~= "more" or steps >= (max_steps or 60)
  return st, status, why, steps
end

local function valid(st, a, b, w, allow_trees)
  local pts = { a }
  for _, p in ipairs(st.poles) do pts[#pts + 1] = p end
  pts[#pts + 1] = b
  local seen = {}
  for i = 1, #pts - 1 do
    local dx, dy = pts[i].x - pts[i + 1].x, pts[i].y - pts[i + 1].y
    if dx * dx + dy * dy > R * R + 1e-6 then return false, string.format("pas %d trop long (%.1f)", i, math.sqrt(dx * dx + dy * dy)) end
  end
  for _, p in ipairs(st.poles) do
    local k = key(p.x, p.y)
    if w.blk[k] then return false, "poteau sur une tuile occupee" end
    if w.trees[k] and not allow_trees then return false, "poteau sur un arbre" end
    if seen[k] then return false, "deux poteaux sur une tuile" end
    seen[k] = true
  end
  return true
end

local A, B = { x = 0.5, y = 0.5 }, { x = 280.5, y = 5.5 }

-- §1 sol libre
do
  local w = world({})
  local st, status, _, steps = run(Lb, A, B, w)
  check(status == "done", "§1 sol libre : ligne complète (" .. tostring(status) .. ")")
  local ok, why = valid(st, A, B, w, false)
  check(ok, "§1 chaîne valide (" .. tostring(why) .. ")")
  local minimum = math.ceil(math.sqrt(280 * 280 + 5 * 5) / R) - 1
  check(#st.poles >= minimum and #st.poles <= minimum + 12, string.format("§1 %d poteaux pour un minimum de %d", #st.poles, minimum))
  check(steps >= 6, "§1 découpée en tronçons (" .. steps .. " étapes)")
end

-- §2 lac de 60 x 60 en travers de la droite
do
  local w = world({ { 120, -30, 180, 40 } })
  local st, status, why = run(Lb, A, B, w)
  check(status == "done", "§2 lac : ligne complète (" .. tostring(status) .. " " .. tostring(why) .. ")")
  local ok, why2 = valid(st, A, B, w, false)
  check(ok, "§2 aucun poteau dans le lac (" .. tostring(why2) .. ")")
end

-- §3 tuiles occupées semées (thermiques, bâtiments)
do
  local rects = {}
  local seed = 20261108
  local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
  for i = 1, 140 do
    local x, y = math.floor(rnd() * 280), math.floor(rnd() * 60) - 30
    rects[#rects + 1] = { x, y, x + 3 + math.floor(rnd() * 5), y + 3 + math.floor(rnd() * 5) }
  end
  local w = world(rects)
  local st, status, why = run(Lb, A, B, w)
  check(status == "done", "§3 semis de bâtiments : ligne complète (" .. tostring(status) .. " " .. tostring(why) .. ")")
  local ok, why2 = valid(st, A, B, w, false)
  check(ok, "§3 aucun poteau sur une tuile occupée (" .. tostring(why2) .. ")")
end

-- §4 mur infranchissable (toute la hauteur lue), puis arbres : seulement au second essai
do
  local w = world({ { 100, -400, 140, 400 } })
  local _, status, why = run(Lb, A, B, w)
  check(status == "fail" and type(why) == "string" and why:find("aucun troncon", 1, true) ~= nil, "§4 mur : refus avec la raison (" .. tostring(status) .. " " .. tostring(why) .. ")")
  local wt = world({}, { { 100, -400, 140, 400 } })
  local st, st2 = run(Lb, A, B, wt)
  check(st2 == "done" and st.trees == true, "§4 forêt sur toute la hauteur : passée à travers bois au second essai")
  local ok = valid(st, A, B, wt, true)
  check(ok, "§4 chaîne à travers bois valide")
  local w0 = world({}, { { 60, 2, 66, 3 } })
  local st0, s0 = run(Lb, A, B, w0)
  check(s0 == "done" and st0.trees == false and valid(st0, A, B, w0, false), "§4 quelques arbres : contournés sans passer à travers bois")
end

-- §5 coût d'une étape, état en nombres seulement, déterminisme
local function cost(fn)
  local count = 0
  debug.sethook(function() count = count + 1 end, "", 1000)
  fn()
  debug.sethook()
  return count * 1000
end
do
  local w = world({ { 120, -30, 180, 40 } })
  local st = Lb.new(A, B, R)
  local worst, total, n = 0, 0, 0
  local status
  repeat
    local c = cost(function() status = Lb.step(st, ctx_of(w)) end)
    worst, total, n = math.max(worst, c), total + c, n + 1
  until status ~= "more" or n > 60
  print(string.format("[LIGNE-BANDE] cout (sethook, 1 M instructions ~ 9 ms) : %d etapes, la pire %.2f M (~%.1f ms), total %.2f M (lac de 60 x 70)", n, worst / 1e6, worst / 1e6 * 9, total / 1e6))
  check(status == "done" and worst < 0.8e6, "§5 chaque étape sous 0,8 million d'instructions (" .. worst .. ")")
  local function plain(t, seen)
    seen = seen or {}
    if seen[t] then return false end
    seen[t] = true
    for k, v in pairs(t) do
      if type(k) ~= "number" and type(k) ~= "string" then return false end
      if type(v) == "function" or type(v) == "userdata" then return false end
      if type(v) == "table" and not plain(v, seen) then return false end
    end
    return true
  end
  check(plain(st), "§5 l'état ne contient ni fonction ni référence cyclique (peut vivre dans global)")
  local st1 = run(Lb, A, B, w)
  local st2 = run(Lb, A, B, w)
  local same = #st1.poles == #st2.poles
  for i = 1, math.min(#st1.poles, #st2.poles) do if st1.poles[i].x ~= st2.poles[i].x or st1.poles[i].y ~= st2.poles[i].y then same = false end end
  check(same, "§5 déterministe : deux exécutions, mêmes poteaux")
end

-- §6 mutants
local function battery(L)
  local bad = 0
  local function exp(c) if not c then bad = bad + 1 end end
  local w1 = world({})
  local s1, t1 = run(L, A, B, w1)
  exp(t1 == "done" and valid(s1, A, B, w1, false))
  local w2 = world({ { 120, -30, 180, 40 } })
  local s2, t2 = run(L, A, B, w2)
  exp(t2 == "done" and valid(s2, A, B, w2, false))
  local w3 = world({ { 100, -400, 140, 400 } })
  local _, t3 = run(L, A, B, w3)
  exp(t3 == "fail")
  local wt = world({}, { { 100, -400, 140, 400 } })
  local st, t4 = run(L, A, B, wt)
  exp(t4 == "done" and st.trees == true)
  local w0 = world({}, { { 60, 2, 66, 3 } })
  local s0, t0 = run(L, A, B, w0)
  exp(t0 == "done" and s0.trees == false and valid(s0, A, B, w0, false))
  -- la ligne ne s'arrête pas à mi-chemin
  exp(s1.done and #s1.poles >= 30)
  -- plafond de poteaux : une ligne de 700 tuiles (plus de 80 poteaux) est refusée avec sa raison
  local _, tm, whym = run(L, A, { x = 700.5, y = 0.5 }, w1, 120)
  exp(tm == "fail" and tostring(whym):find("au-dela", 1, true) ~= nil)
  -- les tuiles des poteaux déjà posés ne sont plus libres pour les tronçons suivants
  local sT = L.new(A, B, R)
  L.step(sT, ctx_of(w1))
  local probe
  local cx = ctx_of(w1)
  cx.pole_chain = function(a, bb, r, big, free, known, opts)
    probe = free(sT.poles[1].x, sT.poles[1].y)
    return P.pole_chain(a, bb, r, big, free, known, opts)
  end
  L.step(sT, cx)
  exp(probe == false)
  return bad
end
check(battery(Lb) == 0, "§6 la batterie des mutants passe sur le vrai module")
local function plain(from, to) return function(s) local i, j = s:find(from, 1, true) if not i then return nil end return s:sub(1, i - 1) .. to .. s:sub(j + 1) end end
local MUT = {
  { "pas de decalage lateral", plain("Lb.SHIFTS = { 0, 12, -12, 24, -24, 40, -40, 60, -60, 90, -90 }", "Lb.SHIFTS = { 0 }") },
  { "pas de second essai a travers bois", plain("if not st.trees then", "if false then") },
  { "tuiles de la ligne reprises", plain("if st.taken[key(x, y)] then return false end", "") },
  { "arbres toujours libres", plain("return ctx.free(x, y, trees)", "return ctx.free(x, y, true)") },
  { "tronçon final jamais atteint", plain("local final = d <= Lb.LEG + reach", "local final = false") },
  { "plafond de poteaux ignore", plain("if #st.poles > Lb.MAX_POLES then", "if false then") },
  { "tronçon de 8 tuiles", plain("Lb.LEG = 36", "Lb.LEG = 8") },
}
local refused = 0
for _, m in ipairs(MUT) do
  local src2 = m[2](SRC)
  if not src2 or src2 == SRC then
    print("  MUTANT introuvable : " .. m[1])
  else
    local ok, L2 = pcall(load_lb, src2)
    local killed = not ok
    if ok then
      local ok2, bad = pcall(battery, L2)
      killed = (not ok2) or bad > 0
    end
    if killed then refused = refused + 1 else print("  MUTANT SURVIVANT : " .. m[1]) end
  end
end
check(refused == #MUT, "§6 mutants refusés : " .. refused .. " sur " .. #MUT)
print(string.format("[LIGNE-BANDE] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, refused, #MUT))
os.exit(failures == 0 and 0 or 1)
