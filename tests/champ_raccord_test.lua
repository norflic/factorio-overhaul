--[[
  Lot FONDERIE (3/11) : tous les poteaux d'une bande de champ rejoignent le réseau alimenté (shared/team/champ_raccord.lua).
  Reproduit le défaut mesuré par ENERGIE4 (lot7bis-20261020 : colonne de 16 à 20 poteaux à 101 tuiles du réseau, jamais raccordée) :
  l'ancien raccord (une chaîne depuis le poteau le plus proche) laisse des composantes hors réseau ; la règle n'en laisse aucune.
  Lancement : lua5.2 tests/champ_raccord_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path

local Ra = require("shared.team.champ_raccord")
local Ch = require("shared.team.champ")
local P = require("shared.team.plan")

local okc, fail = 0, 0
local function check(cond, msg)
  if cond then okc = okc + 1 else fail = fail + 1; print("ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local R = 7.5
local function chain_free(free) return function(a, b) return P.pole_chain(a, b, R, false, free, nil) end end
local function all_free() return true end

--- Vrai si tous les poteaux de `pts` sont dans la composante d'une cible.
local function all_powered(pts, targets)
  local list, nt = {}, #targets
  for _, t in ipairs(targets) do list[#list + 1] = t end
  for _, p in ipairs(pts) do list[#list + 1] = p end
  local comp = Ra.components(list, R)
  local ok = {}
  for i = 1, nt do ok[comp[i]] = true end
  local off = 0
  for i = nt + 1, #list do if not ok[comp[i]] then off = off + 1 end end
  return off == 0, off
end

section("1. composantes")
do
  local comp, n = Ra.components({ { x = 0, y = 0 }, { x = 7, y = 0 }, { x = 30, y = 0 }, { x = 37.5, y = 0 }, { x = 45.1, y = 0 } }, R)
  check(n == 3, "3 composantes (" .. n .. ")")
  check(comp[1] == comp[2] and comp[3] == comp[4] and comp[1] ~= comp[3] and comp[5] ~= comp[4], "portée 7,5 incluse, 7,6 exclue")
  local _, n0 = Ra.components({}, R)
  check(n0 == 0, "aucun point : 0 composante")
end

-- bande à 100 tuiles du réseau : rangée de poteaux de la bande + colonne loin (2 composantes), cible à 100 tuiles
local function band_case()
  local own = {}
  for x = 0, 42, 7 do own[#own + 1] = { x = x + 0.5, y = 0.5 } end        -- rangée de la bande
  for y = 30, 72, 6 do own[#own + 1] = { x = 60.5, y = y + 0.5 } end       -- colonne à 30 tuiles en travers (rien ne la relie)
  return own, { { x = -99.5, y = 0.5 } }
end

section("2. defaut reproduit : ancien raccord (chaine depuis le poteau le plus proche)")
do
  local own, tg = band_case()
  local net = tg[1]
  local start, sd
  for _, p in ipairs(own) do local d = (p.x - net.x) ^ 2 + (p.y - net.y) ^ 2; if not sd or d < sd then start, sd = p, d end end
  local ch = P.pole_chain({ x = start.x, y = start.y }, net, R, false, all_free, nil)
  local pts = {}
  for _, p in ipairs(own) do pts[#pts + 1] = p end
  for _, p in ipairs(ch or {}) do pts[#pts + 1] = p end
  local okp, off = all_powered(pts, tg)
  check(ch ~= nil and not okp and off == 8, "ancien raccord : 8 poteaux de la colonne restent hors réseau (" .. tostring(off) .. ")")
end

section("3. regle : toutes les composantes raccordees")
do
  local own, tg = band_case()
  local added, fails, linked = Ra.connect(own, tg, R, chain_free(all_free))
  local pts = {}
  for _, p in ipairs(own) do pts[#pts + 1] = p end
  for _, p in ipairs(added) do pts[#pts + 1] = p end
  local okp, off = all_powered(pts, tg)
  check(okp, "0 poteau hors réseau (" .. tostring(off) .. ")")
  check(#fails == 0 and linked == 2, "2 chaînes, 0 échec (" .. linked .. ", " .. #fails .. ")")
  check(#added >= 13 and #added <= 22, "poteaux ajoutés : de 13 à 22 (" .. #added .. ")")
  -- la colonne se raccorde à la bande (la plus proche), pas au réseau à 100 tuiles
  local a2, f2, l2 = Ra.connect(own, tg, R, chain_free(all_free))
  local same = #a2 == #added
  for i = 1, math.min(#a2, #added) do same = same and a2[i].x == added[i].x and a2[i].y == added[i].y end
  check(same and #f2 == 0 and l2 == linked, "déterministe (deux appels identiques)")
end

section("4. deja raccordee : rien a poser")
do
  local own = { { x = 0.5, y = 0.5 }, { x = 7.5, y = 0.5 } }
  local added, fails, linked = Ra.connect(own, { { x = -6.5, y = 0.5 } }, R, chain_free(all_free))
  check(#added == 0 and #fails == 0 and linked == 0, "à portée d'une cible : 0 poteau, 0 chaîne")
  local a1, f1, l1 = Ra.connect({ { x = 0.5, y = 0.5 } }, { { x = 12.5, y = 0.5 } }, R, chain_free(all_free))
  check(#a1 == 1 and #f1 == 0 and l1 == 1, "cible à 12 tuiles (entre 1 et 2 portées) : 1 poteau posé (" .. #a1 .. ")")
end

section("5. chaine impossible : composante rendue en echec")
do
  local own, tg = band_case()
  -- mur infranchissable entre la colonne (x = 60) et le reste : x de 50 à 56, toute hauteur
  local function free(x, y) local tx = math.floor(x); return tx < 50 or tx > 56 end
  local added, fails = Ra.connect(own, tg, R, chain_free(free))
  check(#fails == 1 and fails[1].n == 8, "1 composante en échec, 8 poteaux (" .. #fails .. ", " .. tostring(fails[1] and fails[1].n) .. ")")
  local pts = {}
  for _, p in ipairs(own) do pts[#pts + 1] = p end
  for _, p in ipairs(added) do pts[#pts + 1] = p end
  local _, off = all_powered(pts, tg)
  check(off == 8, "la bande est raccordée, la colonne non (" .. off .. ")")
  local a0, f0 = Ra.connect(own, {}, R, chain_free(all_free))
  check(#a0 == 0 and #f0 == 2, "aucune cible : 2 composantes en échec, rien posé")
end

section("6. vraie colonne a tapis (shared/team/champ.lua) a 100 tuiles du reseau")
do
  local ore, coal = {}, {}
  for x = -12, 12 do for y = -12, 12 do if x * x + y * y <= 144 then ore[#ore + 1] = x; ore[#ore + 1] = y end end end
  for x = 34, 44 do for y = -44, -34 do coal[#coal + 1] = x; coal[#coal + 1] = y end end
  local spec = { ore = ore, blocked = {}, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = R },
    belts = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }, furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 },
    inserter = { rate = 0.83 }, target = { x = 1000, y = 0 }, max_side = 8, design = "colonne", coal = { tiles = coal, rate = 0.5 },
    logistics = { splitter = false } }
  local plan = Ch.plan(spec)
  check(plan ~= nil and plan.design == "colonne", "plan en colonne")
  local own, used = {}, {}
  for _, e in ipairs(plan and plan.ents or {}) do
    if e.kind == "poteau" then own[#own + 1] = { x = e.x, y = e.y } end
    local w, h = e.w or e.size or 1, e.h or e.size or 1
    for x = math.floor(e.x - w / 2 + 0.5), math.floor(e.x - w / 2 + 0.5) + w - 1 do
      for y = math.floor(e.y - h / 2 + 0.5), math.floor(e.y - h / 2 + 0.5) + h - 1 do used[Ch.key(x, y)] = true end
    end
  end
  local function free(x, y) return not used[Ch.key(math.floor(x), math.floor(y))] end
  local tg = { { x = -112.5, y = 0.5 } }
  local _, ncomp = Ra.components(own, R)
  local added, fails = Ra.connect(own, tg, R, chain_free(free))
  local pts = {}
  for _, p in ipairs(own) do pts[#pts + 1] = p end
  for _, p in ipairs(added) do pts[#pts + 1] = p; check(free(p.x, p.y), "poteau ajouté sur une tuile libre") end
  local okp, off = all_powered(pts, tg)
  local msg = string.format("%d poteaux du plan en %d composante(s) : 0 hors réseau après la règle (%d), %d ajoutés", #own, ncomp, off, #added)
  print("  " .. msg)
  check(okp and #fails == 0, msg)
end

section("7. mutants")
do
  local src = io.open("shared/team/champ_raccord.lua"):read("*a")
  local muts = {
    { "un seul tour", "for _ = 1, #own + 1 do", "for _ = 1, 1 do" },
    { "portee double pour la cible", "<= r2 then ok[comp[i]] = true", "<= 4 * r2 then ok[comp[i]] = true" },
    { "union absente", "if a ~= b then if a < b then parent[b] = a else parent[a] = b end end", "" },
    { "echec oublie", "fails[#fails + 1] = { n = cnt, d = math.sqrt(best.d2), at = { x = best.first.x, y = best.first.y } }\n    end\n  end",
      "end\n  end" },
  }
  local caught = 0
  for _, m in ipairs(muts) do
    local s, n = src:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")), 1)
    assert(n == 1, "mutant introuvable : " .. m[1])
    local M = assert(load(s))()
    local own, tg = band_case()
    local bad = false
    local okr, err = pcall(function()
      local added, fails = M.connect(own, tg, R, chain_free(all_free))
      local pts = {}
      for _, p in ipairs(own) do pts[#pts + 1] = p end
      for _, p in ipairs(added) do pts[#pts + 1] = p end
      if not all_powered(pts, tg) or #fails > 0 then bad = true end
      local function free(x, y) local tx = math.floor(x); return tx < 50 or tx > 56 end
      local _, f2 = M.connect(own, tg, R, chain_free(free))
      if #f2 ~= 1 then bad = true end
      local _, n = M.components({ { x = 0, y = 0 }, { x = 7, y = 0 } }, R)
      if n ~= 1 then bad = true end
      local a1 = M.connect({ { x = 0.5, y = 0.5 } }, { { x = 12.5, y = 0.5 } }, R, chain_free(all_free))
      if #a1 ~= 1 then bad = true end
    end)
    if not okr or bad then caught = caught + 1 else print("mutant survivant : " .. m[1]) end
  end
  check(caught == #muts, string.format("mutants refusés : %d sur %d", caught, #muts))
end

print(string.format("[CHAMP-RACCORD] BILAN : %d OK, %d ECHEC(S)", okc, fail))
if fail > 0 then os.exit(1) end
