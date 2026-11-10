--[[
  Tests hors jeu du lot CC-SANCTUAIRE (directive du DC du 10/11, 22 h : « aucun four sur une tuile de ressource ; un site de fonderie
  dont l'emprise touche une seule tuile de ressource est rejeté et décalé sur le sol neutre voisin »). Pur, aucune API Factorio.
  Usage, depuis la racine du mod :   lua5.2 tests/sanctuaire_test.lua

  Partie du DC en 0.6.89 (graine 4271945338) : l'avant-poste 4 (cuivre) du joueur, axe x, sortie -, pose sa fonderie en colonnes à
  l'ouest… en travers du gisement de fer voisin (« autres ressources minables autour : 1602 tuile(s) du champ »). Deux maillons de la
  même règle d'emprise : la place de la fonderie (Fd.place, Co.place) ne lisait que le minerai VISÉ (`is_ore`), jamais les autres
  ressources (`foreign`), et sa seconde passe acceptait le minerai quand la première ne trouvait rien.

  1. Fd.place (fonderie à coffres) : minerai sur toute la portée du recul → aucune place (nil) ; minerai près du bord → décalée au-delà ;
  2. Co.place (fonderie en colonne) : mêmes cas ;
  3. plan du champ (Ch.plan) : un gisement de fer, et un AUTRE gisement là où la fonderie irait : aucun four ni bras de fonderie sur une
     tuile de ressource, avec les deux fonderies (coffres et colonne) ; sans l'autre gisement, la fonderie est posée (aucune régression) ;
  4. mutants : chaque défaut injecté (seconde passe rendue, autre ressource ignorée, minerai visé ignoré) est vu.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local MODS = { fd = "shared.team.champ_fonderie", co = "shared.team.champ_colonne", ch = "shared.team.champ" }

local function read(path)
  local h = assert(io.open(path, "rb")); local s = h:read("*a"); h:close(); return s
end

-- charge les trois modules, l'un d'eux éventuellement muté (source réécrite) ; rend Fd, Co, Ch liés entre eux
local function load_mods(mut)
  for _, m in pairs(MODS) do package.loaded[m] = nil end
  if mut then
    local src = read(mut.file)
    local s2, n = src:gsub(mut.from, mut.to, 1)
    assert(n == 1, "mutant introuvable : " .. mut.name)
    package.loaded[mut.mod] = assert(load(s2, "=" .. mut.name))()
  end
  local Fd, Co = require(MODS.fd), require(MODS.co)
  local Ch = require(MODS.ch)
  return Fd, Co, Ch
end

local function all_free() return true end

local SPEC_FD = { furnace = { size = 2, rate = 0.3125, fuel = true }, inserter = { rate = 0.83 }, pole = { reach = 2, wire = 7.5 } }
local SPEC_CO = { furnace = { size = 2, rate = 0.3125 }, inserter = { rate = 0.83 }, pole = { reach = 2, wire = 7.5 } }

local function on_res(list, is_res)
  for _, e in ipairs(list or {}) do
    for u = e.u, e.u + e.size - 1 do for v = e.v, e.v + e.size - 1 do if is_res(u, v) then return true end end end
  end
  return false
end

-- 1 et 2 : les deux règles de place, minerai partout sur la portée du recul, puis minerai seulement près du bord
local function placers(Fd, Co, tag)
  local far = function(u) return u >= 1 and u <= 400 end
  local near = function(u) return u >= 1 and u <= 10 end
  local l1 = Fd.place(SPEC_FD, 0, 1, 0, 1.2, 2, 24, all_free, function(u) return far(u) end)
  check(l1 == nil, tag .. "Fd : minerai sur toute la portée du recul -> aucune place (rendu " .. tostring(l1 and #l1) .. " entités)")
  local l2, _, s2 = Fd.place(SPEC_FD, 0, 1, 0, 1.2, 2, 24, all_free, function(u) return near(u) end)
  check(l2 ~= nil and not on_res(l2, function(u) return near(u) end) and s2 and s2 > 10,
    tag .. "Fd : minerai près du bord -> fonderie décalée au-delà (s_edge " .. tostring(s2) .. ")")
  local count = Fd.count(SPEC_CO, 1.2)
  local c1 = Co.place(SPEC_CO, 0, 1, 0, count, 2, 24, all_free, function(u) return far(u) end, nil, nil)
  check(c1 == nil, tag .. "Co : minerai sur toute la portée du recul -> aucune place (rendu " .. tostring(c1 and #c1) .. " entités)")
  local c2, _, cs2 = Co.place(SPEC_CO, 0, 1, 0, count, 2, 24, all_free, function(u) return near(u) end, nil, nil)
  check(c2 ~= nil and not on_res(c2, function(u) return near(u) end) and cs2 and cs2 > 10,
    tag .. "Co : minerai près du bord -> colonne décalée au-delà (s_edge " .. tostring(cs2) .. ")")
  -- côté négatif, minerai près du bord : seule la dernière tuile d'une emprise peut toucher le minerai (toute l'emprise est lue)
  local nearm = function(u) return u <= -1 and u >= -10 end
  local l4 = Fd.place(SPEC_FD, 0, -1, 0, 1.2, 2, 24, all_free, function(u) return nearm(u) end)
  check(l4 ~= nil and not on_res(l4, function(u) return nearm(u) end), tag .. "Fd sortie - : minerai près du bord -> aucune tuile de l'emprise sur le minerai")
  local c4 = Co.place(SPEC_CO, 0, -1, 0, count, 2, 24, all_free, function(u) return nearm(u) end, nil, nil)
  check(c4 ~= nil and not on_res(c4, function(u) return nearm(u) end), tag .. "Co sortie - : minerai près du bord -> aucune tuile de l'emprise sur le minerai")
  -- côté négatif (sortie -, comme l'avant-poste 4 du DC)
  local l3 = Fd.place(SPEC_FD, 0, -1, 0, 1.2, 2, 24, all_free, function(u) return u <= -1 and u >= -400 end)
  check(l3 == nil, tag .. "Fd sortie - : minerai sur toute la portée -> aucune place")
end

-- 3 : plan du champ ; fer sur [0, 59] x [0, 23], cible à l'est (sortie +, axe x) ; `other` : un autre gisement à l'est du champ
local BELTS3 = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }
local function field(other, design, key)
  local ore, foreign = {}, {}
  for x = 0, 59 do for y = 0, 23 do ore[#ore + 1] = x; ore[#ore + 1] = y end end
  if other then for x = 60, 220 do for y = -30, 53 do foreign[key(x, y)] = true end end end
  local fuel = design ~= "colonne"
  return { ore = ore, blocked = {}, foreign = foreign, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = BELTS3, furnace = { size = 2, rate = 0.3125, fuel = fuel }, inserter = { rate = 0.83 }, target = { x = 1000, y = 0 },
    design = design }, ore, foreign
end

local SMELTER = { four = true, coffre = true }
local function smelters_on_resource(Ch, plan, ore, foreign)
  local orek = {}
  for i = 1, #ore - 1, 2 do orek[Ch.key(ore[i], ore[i + 1])] = true end
  local n, total = 0, 0
  for _, e in ipairs(plan and plan.ents or {}) do
    if SMELTER[e.kind] then
      total = total + 1
      local s = e.size or 1
      local x0, y0 = math.floor(e.x - s / 2 + 0.5), math.floor(e.y - s / 2 + 0.5)
      local hit = false
      for x = x0, x0 + s - 1 do for y = y0, y0 + s - 1 do
        local k = Ch.key(x, y)
        if orek[k] or foreign[k] then hit = true end
      end end
      if hit then n = n + 1 end
    end
  end
  return n, total
end

local function plans(Ch, tag)
  for _, design in ipairs({ "coffres", "colonne" }) do
    local d = design == "colonne" and "colonne" or nil
    local spec, ore, foreign = field(true, d, Ch.key)
    local plan = Ch.plan(spec)
    local n, total = smelters_on_resource(Ch, plan, ore, foreign)
    check(n == 0, tag .. design .. " : autre gisement sous la fonderie -> aucun four sur une ressource (" .. n .. " sur " .. total .. ")")
    local spec0, ore0, foreign0 = field(false, d, Ch.key)
    local plan0 = Ch.plan(spec0)
    local n0, total0 = smelters_on_resource(Ch, plan0, ore0, foreign0)
    check(plan0 ~= nil and total0 > 0 and n0 == 0, tag .. design .. " : sans autre gisement, la fonderie est posée hors du minerai ("
      .. total0 .. " fours, " .. n0 .. " sur le minerai)")
  end
end

section("1-2. règles de place (Fd.place, Co.place)")
local Fd, Co, Ch = load_mods(nil)
placers(Fd, Co, "")
section("3. plan du champ (Ch.plan) avec un autre gisement sous la fonderie")
plans(Ch, "")

section("4. mutants")
local MUTANTS = {
  { name = "Fd ressource ignorée (ancienne seconde passe)", mod = MODS.fd, file = "shared/team/champ_fonderie.lua",
    from = "if not free%(u, v%) or is_res%(u, v%) then ok = false end", to = "if not free(u, v) then ok = false end" },
  { name = "Co ressource ignorée (ancienne seconde passe)", mod = MODS.co, file = "shared/team/champ_colonne.lua",
    from = "if is_ore%(u, v%) then ok = false end", to = "if false then ok = false end" },
  { name = "Ch : autre ressource ignorée", mod = MODS.ch, file = "shared/team/champ.lua",
    from = "return c%.is_ore%(u, v%) or c%.is_foreign%(u, v%)", to = "return c.is_ore(u, v)" },
  { name = "Fd : recul arrêté au premier essai", mod = MODS.fd, file = "shared/team/champ_fonderie.lua",
    from = "for t = 0, shift do", to = "for t = 0, 0 do" },
  { name = "Co : recul arrêté au premier essai", mod = MODS.co, file = "shared/team/champ_colonne.lua",
    from = "for t = 0, shift do", to = "for t = 0, 0 do" },
  { name = "Fd : seul le coin de l'emprise lu", mod = MODS.fd, file = "shared/team/champ_fonderie.lua",
    from = "if not free%(u, v%) or is_res%(u, v%) then ok = false end", to = "if not free(u, v) or (u == e.u and v == e.v and is_res(u, v)) then ok = false end" },
}
for _, m in ipairs(MUTANTS) do
  local p0, f0 = passes, failures
  local ok, err = pcall(function()
    local mFd, mCo, mCh = load_mods(m)
    placers(mFd, mCo, "[" .. m.name .. "] ")
    plans(mCh, "[" .. m.name .. "] ")
  end)
  local seen = (not ok) or failures > f0
  passes, failures = p0, f0
  check(seen, "mutant refusé : " .. m.name .. (ok and "" or (" (erreur : " .. tostring(err) .. ")")))
end
load_mods(nil)

print(string.format("[SANCTUAIRE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
