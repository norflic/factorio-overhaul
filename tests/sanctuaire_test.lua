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
  5 à 7. Lot CC-SANCTUAIRE-2 (F509) : le réceptacle d'une paire thermique (four, coffre) n'est jamais posé sur une ressource ; une
     foreuse intérieure n'a pas de réceptacle, une foreuse au bord verse sur le sol neutre ; câblage de la pose et de l'aperçu ; mutants.
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
    from = "if not free%(u, v%) or is_ore%(u, v%) then return false end", to = "if not free(u, v) then return false end" },
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

---------------------------------------------------------------------------------------------------
-- Lot CC-SANCTUAIRE-2 (F509) : réceptacle d'une PAIRE thermique (four 2 x 2 ou coffre 1 x 1) jamais sur une ressource.
-- Partie du DC en 0.6.89 (graine 4271945338) : 45 thermiques chez le joueur, 51 Écarlate, 26 Azur, 17 Émeraude, 41 Ambre, chacune avec son four
-- en pierre (ou son coffre de charbon) posé sur le minerai, au point de dépôt de la foreuse (script/faction/outposts.lua, sink_position : seule
-- la place libre était testée). Foreuse thermique 2 x 2 posée en (0, 1) (tuiles x -1..0, y 0..1), point de dépôt vers le nord (-0.5, -0.3).
---------------------------------------------------------------------------------------------------
local PAIRES = "shared.team.pose_paires"
local function load_paires(mut)
  package.loaded[PAIRES] = nil
  if mut then
    local src = read("shared/team/pose_paires.lua")
    local s2, n = src:gsub(mut.from, mut.to, 1)
    assert(n == 1, "mutant introuvable : " .. mut.name)
    package.loaded[PAIRES] = assert(load(s2, "=" .. mut.name))()
  end
  return require(PAIRES)
end
local DRILL, DROP = { x = 0, y = 1 }, { x = -0.5, y = -0.3 }
local function tile_key(x, y) return x * 65536 + y end
-- place libre : seules les tuiles de la foreuse sont prises
local function fits_of(sw, sh)
  return function(c)
    for ty = c.y - sh / 2, c.y + sh / 2 - 1 do
      for tx = c.x - sw / 2, c.x + sw / 2 - 1 do
        if tx >= -1 and tx <= 0 and ty >= 0 and ty <= 1 then return false end
      end
    end
    return true
  end
end
-- ressource sur toutes les tuiles y >= y_min (gisement au sud d'un bord horizontal)
local function ore_from(y_min)
  return function(x0, y0, w, h)
    for ty = y0, y0 + h - 1 do for tx = x0, x0 + w - 1 do if ty >= y_min then return true end end end
    return false
  end
end
local function sinks(P, tag)
  tag = tag or ""
  -- four 2 x 2
  local c = P.sink_site(DROP, DRILL, 2, 2, fits_of(2, 2), ore_from(-1000))
  check(c == nil, tag .. "four : foreuse intérieure (minerai partout) -> aucun four (rendu " .. (c and (c.x .. "," .. c.y) or "nil") .. ")")
  c = P.sink_site(DROP, DRILL, 2, 2, fits_of(2, 2), ore_from(0))
  check(c ~= nil and c.x == -1 and c.y == -1, tag .. "four : foreuse au bord nord -> four sur le sol neutre en (-1, -1), le plus loin")
  if c then check(not ore_from(0)(c.x - 1, c.y - 1, 2, 2), tag .. "four au bord : aucune tuile de son emprise sur le minerai") end
  c = P.sink_site(DROP, DRILL, 2, 2, fits_of(2, 2), ore_from(-1))
  check(c == nil, tag .. "four : une seule rangée de minerai sous le point de dépôt -> refusé")
  c = P.sink_site(DROP, DRILL, 2, 2, function() return false end, ore_from(1000))
  check(c == nil, tag .. "four : aucune place libre -> nil")
  c = P.sink_site(DROP, DRILL, 2, 2, fits_of(2, 2), ore_from(1000))
  check(c ~= nil and c.x == -1 and c.y == -1, tag .. "four : aucun minerai -> même place qu'avant le lot (le plus loin de la foreuse)")
  -- coffre 1 x 1
  c = P.sink_site(DROP, DRILL, 1, 1, fits_of(1, 1), ore_from(-1000))
  check(c == nil, tag .. "coffre : foreuse intérieure -> aucun coffre")
  c = P.sink_site(DROP, DRILL, 1, 1, fits_of(1, 1), ore_from(0))
  check(c ~= nil and c.x == -0.5 and c.y == -0.5, tag .. "coffre : foreuse au bord -> coffre sur le sol neutre en (-0.5, -0.5)")
  c = P.sink_site(DROP, DRILL, 1, 1, fits_of(1, 1), ore_from(-1))
  check(c == nil, tag .. "coffre : tuile du point de dépôt sur le minerai -> refusé")
end
-- parcours « bord d'abord » : carré de 10 x 10 tuiles de minerai (centres x.5), trié par distance au centre
local function square(n)
  local l = {}
  for iy = 0, n - 1 do for ix = 0, n - 1 do l[#l + 1] = { x = ix - n / 2 + 0.5, y = iy - n / 2 + 0.5 } end end
  table.sort(l, function(a, b)
    local da, db = a.x * a.x + a.y * a.y, b.x * b.x + b.y * b.y
    if da ~= db then return da < db end
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end)
  return l
end
local function edge_dist(r, n) -- distance (Chebyshev) au bord d'un carré n x n : 1 sur la dernière rangée
  local tx, ty = math.floor(r.x + n / 2), math.floor(r.y + n / 2)
  return math.min(tx, ty, n - 1 - tx, n - 1 - ty) + 1
end
local function border(P, tag)
  tag = tag or ""
  local l = square(10)
  local b = P.border_first(l, 2)
  check(#b == #l, tag .. "bord d'abord : même nombre de tuiles (" .. #b .. ")")
  local near = 0
  for _, r in ipairs(l) do if edge_dist(r, 10) <= 2 then near = near + 1 end end
  local ok_head, ok_tail = true, true
  for i = 1, near do if edge_dist(b[i], 10) > 2 then ok_head = false end end
  for i = near + 1, #b do if edge_dist(b[i], 10) <= 2 then ok_tail = false end end
  check(near == 64 and ok_head, tag .. "bord d'abord : les 64 tuiles à 2 au plus du bord passent en tête")
  check(ok_tail, tag .. "bord d'abord : les 36 tuiles intérieures ensuite")
  -- partition stable : dans chaque groupe, l'ordre de la liste triée est gardé
  local pos = {}
  for i, r in ipairs(l) do pos[r] = i end
  local stable = true
  for i = 2, near do if pos[b[i]] < pos[b[i - 1]] then stable = false end end
  for i = near + 2, #b do if pos[b[i]] < pos[b[i - 1]] then stable = false end end
  check(stable, tag .. "bord d'abord : ordre gardé dans chaque groupe (distance au centre)")
  local b1 = P.border_first(l, 1)
  local n1 = 0
  for i = 1, #b1 do if edge_dist(b1[i], 10) == 1 then n1 = n1 + 1 else break end end
  check(n1 == 36, tag .. "portée 1 : seule la dernière rangée (36 tuiles) en tête (" .. n1 .. ")")
end
section("5. réceptacle des paires thermiques (F509)")
local P0 = load_paires(nil)
check(type(P0.sink_site) == "function", "Paires.sink_site existe")
if type(P0.sink_site) == "function" then sinks(P0) end
check(type(P0.border_first) == "function", "Paires.border_first existe")
if type(P0.border_first) == "function" then border(P0) end

section("6. câblage : la pose et l'aperçu des paires passent par la règle, avec le test des ressources")
local OUT = read("script/faction/outposts.lua")
local sp = OUT:match("local function sink_position%(.-\nend")
check(sp ~= nil and sp:find("Paires%.sink_site%(") ~= nil, "sink_position délègue à Paires.sink_site")
check(sp ~= nil and sp:find('type = "resource"', 1, true) ~= nil, "sink_position lit les ressources de l'emprise")
check(sp ~= nil and sp:find("stone%-furnace") == nil, "sink_position ne choisit plus la forme au nom du four (taille du prototype)")
local npos = 0
for _ in OUT:gmatch("sink_position%(surface, spec%.sink") do npos = npos + 1 end
check(npos == 2, "la pose (place_pairs) et l'aperçu (preview_pairs) appellent sink_position (" .. npos .. ")")
local nb = 0
for _ in OUT:gmatch("resources = Paires%.border_first%(resource_tiles%(") do nb = nb + 1 end
check(nb == 2, "la pose et l'aperçu parcourent le bord du gisement d'abord (" .. nb .. ")")
local nr = 0
for _ in OUT:gmatch("local rr = read_radius%(radius%)") do nr = nr + 1 end
check(nr == 2 and OUT:find("return math%.max%(radius, Paires%.EXTEND_RADIUS%)") ~= nil,
  "la construction lit le gisement jusqu'au rayon d'agrandissement (bord d'un grand gisement), pose et aperçu (" .. nr .. ")")

section("7. mutants de la règle des réceptacles et du parcours bord d'abord")
local PMUT = {
  { name = "ressource ignorée", from = "local function off_ore%(c%) return not ore%(c%.x %- sw / 2, c%.y %- sh / 2, sw, sh%) end",
    to = "local function off_ore(c) return true end" },
  { name = "seule la tuile du coin lue", from = "local function off_ore%(c%) return not ore%(c%.x %- sw / 2, c%.y %- sh / 2, sw, sh%) end",
    to = "local function off_ore(c) return not ore(c.x - sw / 2, c.y - sh / 2, 1, 1) end" },
  { name = "emprise décalée d'une tuile", from = "local function off_ore%(c%) return not ore%(c%.x %- sw / 2, c%.y %- sh / 2, sw, sh%) end",
    to = "local function off_ore(c) return not ore(c.x - sw / 2 + 1, c.y - sh / 2 + 1, sw, sh) end" },
  { name = "coffre sans test de ressource", from = "if off_ore%(c%) and fits%(c%) then return c end",
    to = "if fits(c) then return c end" },
  { name = "four le plus proche au lieu du plus loin", from = "if not best_d or d > best_d then", to = "if not best_d or d < best_d then" },
  { name = "four sans test de place", from = "<= sh / 2 and off_ore%(c%) and fits%(c%) then", to = "<= sh / 2 and off_ore(c) then" },
  { name = "bord : portée dépassée d'une tuile", from = "if d < reach then", to = "if d <= reach then" },
  { name = "bord : intérieur jamais essayé", from = "for _, r in ipairs%(far%) do near%[#near %+ 1%] = r end", to = "" },
  { name = "bord : diagonales ignorées au bord", from = "for dy = %-1, 1 do for dx = %-1, 1 do if not ore", to = "for dy = 0, 0 do for dx = -1, 1 do if not ore" },
  { name = "bord : aucune propagation vers l'intérieur", from = "if d < reach then", to = "if d < 1 then" },
}
for _, m in ipairs(PMUT) do
  local p0, f0 = passes, failures
  local ok, err = pcall(function() local Pm = load_paires(m); sinks(Pm, "[" .. m.name .. "] "); border(Pm, "[" .. m.name .. "] ") end)
  local seen = (not ok) or failures > f0
  passes, failures = p0, f0
  check(seen, "mutant refusé : " .. m.name .. (ok and "" or (" (erreur : " .. tostring(err) .. ")")))
end
load_paires(nil)

print(string.format("[SANCTUAIRE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
