--[[
  Lot PERF3 : tracé du charbon (Co.route, shared/team/champ_colonne.lua) avec la PREUVE RAPIDE d'impossibilité (Co.unreachable) contre
  l'A* seul (Co.PREUVE = false, la référence) : MÊME RÉPONSE sur des milliers de cas tirés au hasard (graine fixe) : tracé, nombre d'états,
  « aucun chemin », « trop long », « depart », « arrivee » ; la preuve est tentée très tôt (Co.PREUVE_APRES petit) pour qu'elle serve
  sur de petites boîtes, avec des remplissages parfois très bornés (Co.PREUVE_TUILES) et des plafonds bas (le « trop long »).
  Puis le cas qui gelait le jeu (arrivée enfermée dans une grande boîte) : même réponse, au moins 20 fois plus vite.
  Mutants : une règle fausse dans la preuve (arête des souterrains oubliée, borne des états fausse, cible développée, départ hors de la
  boîte refusé) est vue par la comparaison.
  Lancement : lua5.2 tests/perf3_route_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local SRC = io.open("shared/team/champ_colonne.lua"):read("*a")
local function load_variant(subs)
  local src = SRC
  for _, sb in ipairs(subs or {}) do
    local a, b = src:find(sb[1], 1, true)
    assert(a, "mutant : texte introuvable : " .. sb[1])
    src = src:sub(1, a - 1) .. sb[2] .. src:sub(b + 1)
  end
  return assert(load(src, "=champ_colonne(variante)"))()
end

local function ser(v)
  if type(v) ~= "table" then return tostring(v) end
  local parts = {}
  for i, x in ipairs(v) do
    parts[#parts + 1] = string.format("%d:%d,%d,%d,%s,%s", i, x.u, x.v, x.d, tostring(x.kind), tostring(x.ug))
  end
  return "{" .. table.concat(parts, ";") .. "}"
end

local seed = 20261105
-- (bits de poids FORT : les bits faibles d'un générateur congruentiel modulo 2^31 ont des périodes courtes)
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; local x = seed / 2147483648; return n and math.floor(x * n) or x end

--- Un cas, d'une de quatre familles : (1) obstacles au hasard ; (2) anneau autour de l'arrivée, souterrains souvent (sauter
--- l'anneau) ; (3) anneau autour du départ ; (4) boîte presque vide, arrivée murée, plafond proche du nombre d'états (« trop long »
--- contre « aucun chemin ») ; (5) poche de deux tuiles (arrivée et sortie d'une paire de souterrains) murée : seul un saut y mène.
--- Départ parfois hors de la boîte (l'A* l'accepte : seule l'arrivée d'une arête y est contrôlée).
local function make_case()
  local fam = rnd(20)
  fam = (fam < 7) and 1 or (fam < 11) and 2 or (fam < 14) and 3 or (fam < 17) and 4 or 5
  local W, H = 5 + rnd(18), 5 + rnd(14)
  local box = { u0 = 0, v0 = 0, u1 = W - 1, v1 = H - 1 }
  local dens = (fam == 4) and rnd() * 0.12 or (fam == 1) and rnd() * 0.55 or rnd() * 0.3
  local wall = {}
  for u = -3, W + 2 do for v = -3, H + 2 do if rnd() < dens then wall[u * 1000 + v] = true end end end
  local s = { u = rnd(W + 2) - 1, v = rnd(H + 2) - 1 }
  if rnd(3) == 0 then s.u = (rnd(2) == 0) and -1 or W end
  local t = { u = rnd(W + 2) - 1, v = rnd(H + 2) - 1 }
  local function ring(c, r)
    for u = c.u - r, c.u + r do for v = c.v - r, c.v + r do
      if math.max(math.abs(u - c.u), math.abs(v - c.v)) == r then wall[u * 1000 + v] = true end
    end end
  end
  if fam == 2 then ring(t, 1 + rnd(3)) elseif fam == 3 then ring(s, 1 + rnd(3)) elseif fam == 4 then ring(t, 1) end
  if fam == 5 then
    -- poche : t et m = t - d libres, tout autour muré ; on y entre par un saut dans le sens d (sortie en m, arrivée en t)
    local d = ({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } })[1 + rnd(4)]
    local m = { u = t.u - d[1], v = t.v - d[2] }
    for _, c in ipairs({ t, m }) do for du = -1, 1 do for dv = -1, 1 do wall[(c.u + du) * 1000 + (c.v + dv)] = true end end end
    wall[m.u * 1000 + m.v] = nil
  end
  wall[s.u * 1000 + s.v], wall[t.u * 1000 + t.v] = nil, nil
  if rnd(15) == 0 then wall[s.u * 1000 + s.v] = true end -- « depart »
  if rnd(15) == 0 then wall[t.u * 1000 + t.v] = true end -- « arrivee »
  local nospan = {}
  for u = -3, W + 2 do for v = -3, H + 2 do if rnd() < 0.1 then nospan[u * 1000 + v] = true end end end
  local soft = {}
  for u = -3, W + 2 do for v = -3, H + 2 do if rnd() < 0.15 then soft[u * 1000 + v] = true end end end
  local ug = ({ false, 2, 3, 4, 5 })[1 + rnd(5)] or nil
  if (fam == 2 or fam == 3) and rnd(3) > 0 then ug = 2 + rnd(4) end
  if fam == 5 then ug = 2 + rnd(4) end
  local cap = nil
  if fam == 4 then cap = (W * H) * (3 + rnd(6)) + rnd(40) elseif rnd(6) == 0 then cap = 10 + rnd(400) end
  return {
    s = s, t = t, sd = 1 + rnd(4), td = 1 + rnd(4), box = box,
    free = function(u, v) return not wall[u * 1000 + v] end,
    span = (fam ~= 5 and rnd(3) > 0) and function(u, v) return not nospan[u * 1000 + v] end or nil,
    ug = ug, cap = cap,
    tcost = (rnd(2) == 0) and function(u, v) return soft[u * 1000 + v] and 9 or 1 end or nil,
    apres = ({ 1, 2, 5, 20 })[1 + rnd(4)], tuiles = ({ 6, 40, 3000, 3000 })[1 + rnd(4)],
  }
end

local function run(Co, c, preuve)
  Co.PREUVE = preuve
  Co.PREUVE_APRES, Co.PREUVE_TUILES = c.apres, c.tuiles
  local r, w = Co.route(c.s, c.sd, c.t, c.td, c.free, c.span, c.ug, c.box, c.cap, c.tcost)
  return ser(r) .. "|" .. tostring(w)
end

--- Compare la variante à la référence (A* seul) sur n cas ; rend (différences, preuves conclues, cas « aucun chemin », exemple).
local function compare(Co, n)
  seed = 20261105
  local diff, proved, none, example = 0, 0, 0, nil
  -- (coût, 7/11, voie des TRANCHES) l'A* mène la preuve REPRENABLE (Co.unreachable_new / Co.unreachable_run) : comptée à sa fin
  local real = Co.unreachable_run
  Co.unreachable_run = function(st, ...)
    local done = real(st, ...)
    if done and st.res then proved = proved + 1 end
    return done
  end
  for i = 1, n do
    local c = make_case()
    local a = run(Co, c, false)
    local b = run(Co, c, true)
    if a:find("aucun chemin", 1, true) then none = none + 1 end
    if a ~= b then
      diff = diff + 1
      example = example or string.format("cas %d : A* %s ; avec preuve %s", i, a:sub(-60), b:sub(-60))
    end
  end
  Co.unreachable_run = real
  Co.PREUVE, Co.PREUVE_APRES, Co.PREUVE_TUILES = true, 2000, 3000
  return diff, proved, none, example
end

---------------------------------------------------------------------------------------------------
section("1. même réponse que l'A* seul (3 000 cas tirés au hasard)")
local Co = require("shared.team.champ_colonne")
local N = 3000
local d, proved, none, ex = compare(Co, N)
print(string.format("  %d cas, %d « aucun chemin » de l'A*, %d conclus par la preuve, %d différence(s)", N, none, proved, d))
check(d == 0, "réponses identiques à l'A* seul" .. (ex and (" ; " .. ex) or ""))
check(proved >= 100, "la preuve conclut souvent (" .. proved .. " cas)")
check(none > proved, "et pas toujours : remplissages bornés, plafonds (" .. none .. " « aucun chemin » de l'A*)")

---------------------------------------------------------------------------------------------------
section("2. le cas du gel : arrivée enfermée dans une boîte de 301 x 121 tuiles")
local wall = {}
for u = 95, 105 do wall[Co.tk(u, 25)] = true; wall[Co.tk(u, 35)] = true end
for v = 25, 35 do wall[Co.tk(95, v)] = true; wall[Co.tk(105, v)] = true end
local big = { u0 = -150, v0 = -60, u1 = 150, v1 = 60 }
local function free(u, v) return not wall[Co.tk(u, v)] end
Co.PREUVE = false
local t0 = os.clock()
local r0, w0 = Co.route({ u = -100, v = 0 }, 2, { u = 100, v = 30 }, 2, free, nil, nil, big)
local ms0 = (os.clock() - t0) * 1000
Co.PREUVE = true
t0 = os.clock()
local r1, w1 = Co.route({ u = -100, v = 0 }, 2, { u = 100, v = 30 }, 2, free, nil, nil, big)
local ms1 = (os.clock() - t0) * 1000
print(string.format("  A* seul : %s en %.0f ms ; avec la preuve : %s en %.0f ms", tostring(w0), ms0, tostring(w1), ms1))
check(r0 == nil and r1 == nil and w0 == "aucun chemin" and w1 == w0, "même réponse : aucun chemin")
check(ms1 * 20 < ms0, string.format("au moins 20 fois plus vite (%.0f ms contre %.0f)", ms1, ms0))
-- un tracé possible dans la même boîte : inchangé (la preuve n'est même pas tentée)
local r2, n2 = Co.route({ u = -100, v = 0 }, 2, { u = 100, v = 50 }, 2, free, nil, 4, big)
Co.PREUVE = false
local r3, n3 = Co.route({ u = -100, v = 0 }, 2, { u = 100, v = 50 }, 2, free, nil, 4, big)
Co.PREUVE = true
check(ser(r2) == ser(r3) and n2 == n3, "tracé possible : identique, même nombre d'états (" .. tostring(n2) .. ")")

---------------------------------------------------------------------------------------------------
section("3. mutants de la preuve : vus par des cas construits, puis par la comparaison au hasard")
--- Cas construits (chacun réfute un mutant) : rend la réponse de Co.route d'un module donné, preuve allumée tout de suite.
local function poche(V, big_start)
  -- poche murée {m, t} (sens d = est), entrée par un saut de souterrains de longueur 2 depuis x0 = t - 3d ; départ seul (x0) ou dans
  -- une grande zone libre (big_start)
  local t = { u = 20, v = 10 }
  local wallp = {}
  for u = 0, 30 do for v = 0, 20 do wallp[u * 1000 + v] = not big_start end end
  for u = 18, 21 do for v = 9, 11 do wallp[u * 1000 + v] = true end end
  wallp[19 * 1000 + 10], wallp[20 * 1000 + 10] = nil, nil -- m (sortie) et t
  local x0 = { u = 17, v = 10 }
  wallp[17 * 1000 + 10] = nil
  if big_start then for u = 0, 16 do for v = 0, 20 do wallp[u * 1000 + v] = nil end end end
  local s = big_start and { u = 2, v = 10 } or x0
  V.PREUVE, V.PREUVE_APRES, V.PREUVE_TUILES = true, 1, 3000
  local r, w = V.route(s, 2, t, 2, function(u, v) return not wallp[u * 1000 + v] end, nil, 2, { u0 = 0, v0 = 0, u1 = 30, v1 = 20 })
  V.PREUVE_APRES = 2000
  return (r and "chemin" or "nil") .. "|" .. tostring(w)
end
local function muree(V, ug, cap)
  -- boîte 15 x 12 presque vide, arrivée murée (anneau de rayon 1) : l'A* conclut « trop long » si les états dépassent le plafond
  local wallm = {}
  for u = 9, 11 do for v = 5, 7 do if not (u == 10 and v == 6) then wallm[u * 1000 + v] = true end end end
  V.PREUVE, V.PREUVE_APRES = true, 1
  local r, w = V.route({ u = 0, v = 0 }, 2, { u = 10, v = 6 }, 2, function(u, v) return not wallm[u * 1000 + v] end, nil, ug,
    { u0 = 0, v0 = 0, u1 = 14, v1 = 11 }, cap)
  V.PREUVE_APRES = 2000
  return tostring(w)
end
local CASES = {
  { "poche, depart seul", function(V) return poche(V, false) end },
  { "poche, grande zone de depart", function(V) return poche(V, true) end },
  { "muree, souterrains 4, plafond 900", function(V) return muree(V, 4, 900) end },
  { "muree, sans souterrain, plafond 500", function(V) return muree(V, nil, 500) end },
}
local ref = {}
for i, c in ipairs(CASES) do
  ref[i] = c[2](Co)
  Co.PREUVE = false
  print(string.format("  %-40s %s", c[1], ref[i]))
end
check(ref[1]:sub(1, 6) == "chemin" and ref[2]:sub(1, 6) == "chemin", "poches : le saut mène à l'arrivée (A* avec la preuve)")
check(ref[3] == "trop long" and ref[4] == "trop long", "murées : « trop long » au plafond bas (A* avec la preuve)")
local mutants = {
  { "arete des souterrains oubliee", { { [=[
      for kk = 2, maxk do
        local mu, mv = u + kk * d[1], v + kk * d[2]]=], [=[
      for kk = 2, 1 do
        local mu, mv = u + kk * d[1], v + kk * d[2]]=] },
    { [=[
        for kk = 2, maxk do
          local xu2, xv2]=], [=[
        for kk = 2, 1 do
          local xu2, xv2]=] } } },
  { "borne des etats : 4 par tuile meme avec souterrains", { { "local per = (maxk >= 2) and 8 or 4", "local per = 4" } } },
  { "borne des etats : boite ignoree", { { "if per * area <= cap then", "if true then" } } },
  { "saut : sortie de la paire a la mauvaise distance (arriere)", { { "local xu2, xv2 = u - (kk + 1) * d[1], v - (kk + 1) * d[2]", "local xu2, xv2 = u - kk * d[1], v - kk * d[2]" } } },
  { "saut : la cible refusee comme arrivee (avant)", { { "if fr(mu, mv) and not is_t(mu, mv) and landing(yu, yv) then", "if fr(mu, mv) and not is_t(mu, mv) and landing(yu, yv) and not is_t(yu, yv) then" } } },
}
for _, m in ipairs(mutants) do
  local V = load_variant(m[2])
  local seen = {}
  for i, c in ipairs(CASES) do if c[2](V) ~= ref[i] then seen[#seen + 1] = c[1] end end
  local dm = compare(V, 600)
  check(#seen > 0 or dm > 0, string.format("mutant vu : %s (cas construits : %s ; %d différence(s) sur 600 cas au hasard)", m[1],
    #seen > 0 and table.concat(seen, ", ") or "aucun", dm))
end

print(string.format("[PERF3-ROUTE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
