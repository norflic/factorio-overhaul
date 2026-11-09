--[[
  Lot MALL, tranche 3 : contrôle hors jeu du tronc du mall (shared/team/mall_tronc.lua) : géométrie des lignes, têtes, prises à 1, 2, 3 lignes, portée du souterrain, continuité du flux par
  un suivi de tuiles (ligne -> répartiteur -> sortie -> amenée), recouvrements, deux rangées à la suite (on ajoute sans refaire), déclaration `carries`, mutants.
  Usage : lua5.2 tests/mall_tronc_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, ko_n = 0, 0
local function check(cond, what)
  if cond then ok_n = ok_n + 1 else ko_n = ko_n + 1; print("ECHEC : " .. what) end
end

local Mt = require("shared.team.mall_tronc")
local Pu = require("shared.team.purete")

local NAMES = { tapis = "belt", bras = "arm", coffre = "chest", poteau = "pole", repartiteur = "split", souterrain = "ug" }
local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }

local function tiles_of(e)
  if e.name == "split" then
    -- répartiteur vers le sud : deux tuiles horizontales
    return { { math.floor(e.x - 1), math.floor(e.y) }, { math.floor(e.x), math.floor(e.y) } }
  end
  return { { math.floor(e.x), math.floor(e.y) } }
end

local function index(ents)
  local at, dup = {}, {}
  for _, e in ipairs(ents) do
    for _, t in ipairs(tiles_of(e)) do
      local k = t[1] .. ":" .. t[2]
      if at[k] then dup[#dup + 1] = k end
      at[k] = e
    end
  end
  return at, dup
end

--- Suit le flux depuis la tuile (x, y) : tapis, souterrains, répartiteurs (les deux sorties), jusqu'à l'amenée x = −1 ; rend l'ensemble des tuiles atteintes.
local function follow(at, x, y, seen)
  seen = seen or {}
  local k = x .. ":" .. y
  if seen[k] then return seen end
  local e = at[k]
  if not e then return seen end
  seen[k] = true
  if e.name == "split" then
    -- sorties : une tuile au sud de chacune des deux tuiles
    local e_x0 = math.floor(e.x - 1)
    local dy = DV[e.dir][2]
    follow(at, e_x0, y + dy, seen)
    follow(at, e_x0 + 1, y + dy, seen)
    return seen
  end
  if e.name == "belt" then
    local v = DV[e.dir]
    follow(at, x + v[1], y + v[2], seen)
    return seen
  end
  if e.name == "ug" then
    if e.type == "input" then
      for d = 1, 5 do
        local nx = x + d * DV[e.dir][1]
        local o = at[nx .. ":" .. y]
        if o and o.name == "ug" and o.type == "output" then follow(at, nx, y, seen) return seen end
      end
      return seen
    end
    local v = DV[e.dir]
    follow(at, x + v[1], y + v[2], seen)
  end
  return seen
end

local function lines_for(items)
  local out = {}
  for i, it in ipairs(items) do out[i] = Mt.ligne(i, it) end
  return out
end

-- §1 colonnes
check(Mt.XL(1) == -8 and Mt.XL(2) == -11 and Mt.XL(3) == -14, "§1 colonnes des lignes")
check(Mt.portee(1) < 2, "§1 ligne 1 : aucun souterrain à franchir")
check(Mt.portee(2) == 2, "§1 ligne 2 : souterrain de distance 2")
check(Mt.portee(3) == 5, "§1 ligne 3 : souterrain de distance 5 (jaune)")

-- §2 rangée 1 sur 1, 2, 3 lignes : aucune superposition, flux jusqu'à x = −1
for _, cas in ipairs({
  { items = { "fer" }, a = 1, b = nil },
  { items = { "fer", "cuivre" }, a = 1, b = 2 },
  { items = { "fer", "cuivre", "acier" }, a = 1, b = 2 },
  { items = { "fer", "cuivre", "acier" }, a = 1, b = 3 },
  { items = { "fer", "cuivre", "acier" }, a = 2, b = 3 },
}) do
  local tag = string.format("§2 %d ligne(s), prises %d/%s : ", #cas.items, cas.a, tostring(cas.b))
  local ls = lines_for(cas.items)
  local row = { j = 1, bus = { a = cas.a, b = cas.b } }
  local sec = Mt.section(ls, row, NAMES)
  local at, dup = index(sec.ents)
  check(#dup == 0, tag .. "aucune superposition (" .. table.concat(dup, ",") .. ")")
  local ya, yb = Mt.heights(row)
  local r = follow(at, Mt.XL(cas.a), Mt.Y_TOP)
  check(r[-1 .. ":" .. ya] ~= nil, tag .. "la ligne A atteint la fin de l'amenée (x = -1, y = " .. ya .. ")")
  if cas.b then
    local r2 = follow(at, Mt.XL(cas.b), Mt.Y_TOP)
    check(r2[-1 .. ":" .. yb] ~= nil, tag .. "la ligne B atteint la fin de l'amenée")
    check(r[-1 .. ":" .. yb] == nil, tag .. "le flux A ne rejoint pas l'amenée B (pureté)")
    check(r2[-1 .. ":" .. ya] == nil, tag .. "le flux B ne rejoint pas l'amenée A (pureté)")
  end
  -- chaque ligne continue après sa prise
  for _, ln in ipairs(ls) do
    local rr = follow(at, Mt.XL(ln.k), Mt.Y_TOP)
    check(rr[Mt.XL(ln.k) .. ":" .. yb] ~= nil, tag .. "ligne " .. ln.k .. " continue jusqu'à yb")
  end
  check(#sec.quais == 2 * #cas.items, tag .. "deux coffres de tête par ligne")
  -- tracés déclarés au contrôle de pureté : contigus, sur nos tapis, et refusés si un étranger verse dessus
  check(#sec.routes > 0, tag .. "tracés déclarés")
  for _, r in ipairs(sec.routes) do
    local vide = Pu.check(r.tiles, r.item, function() return nil end, {})
    check(vide == true, tag .. "tracé de " .. r.item .. " contigu, monde vide : accepté")
    for _, t in ipairs(r.tiles) do
      local e = at[t.x .. ":" .. t.y]
      check(e ~= nil and (e.name == "belt" or e.name == "ug"), tag .. "tuile de tracé posée (" .. t.x .. "," .. t.y .. ")")
      check(e ~= nil and e.carries and e.carries[1] == r.item, tag .. "tuile de tracé déclarée du bon objet")
    end
    local t1 = r.tiles[1]
    local etranger = { x = t1.x + 1, y = t1.y, dir = 6, kind = "belt", item = "etranger" } -- à l'est de la première tuile, il verse vers l'ouest
    local bad_ok = Pu.check(r.tiles, r.item, function(x, y) if x == etranger.x and y == etranger.y and not at[x .. ":" .. y] then return etranger end end, {})
    if not at[etranger.x .. ":" .. etranger.y] then check(bad_ok == false, tag .. "un tapis étranger qui verse sur le tracé : refusé") end
  end
  for _, e in ipairs(sec.ents) do
    if e.name == "belt" or e.name == "split" or e.name == "ug" then
      check(type(e.carries) == "table" and #e.carries == 1, tag .. "carries : un objet par tapis du tronc")
    end
  end
  -- bras de tête : prise = coffre à l'ouest, dépose = ligne à l'est
  for _, e in ipairs(sec.ents) do
    if e.role == "quai-bras" then
      local v = DV[e.dir]
      local pick, drop = at[math.floor(e.x + v[1]) .. ":" .. math.floor(e.y + v[2])], at[math.floor(e.x - v[1]) .. ":" .. math.floor(e.y - v[2])]
      check(pick and pick.name == "chest" and drop and drop.name == "belt", tag .. "bras de tête : du coffre à la ligne")
    end
  end
  -- deux poteaux de liaison seulement pour la rangée 1
  local n_pole = 0
  for _, e in ipairs(sec.ents) do if e.name == "pole" then n_pole = n_pole + 1 end end
  check(n_pole == #cas.items + 2, tag .. "poteaux : un par ligne + 2 de liaison (" .. n_pole .. ")")
  local e_rel = nil
  for _, e in ipairs(sec.ents) do if e.role == "mall-poteau" and e.y == -0.5 then e_rel = e end end
  check(e_rel == nil, tag .. "aucun relais pour la rangée 1")
end

-- §3 deuxième rangée : on prolonge, on ne refait rien, pas de recouvrement avec la rangée 1
do
  local ls = lines_for({ "fer", "cuivre" })
  local r1 = { j = 1, bus = { a = 1, b = 2 } }
  local s1 = Mt.section(ls, r1, NAMES)
  for _, ln in ipairs(ls) do ln.y_to = s1.y_to[ln.k] end
  local r2 = { j = 2, bus = { a = 1, b = 2 } }
  local s2 = Mt.section(ls, r2, NAMES)
  local all = {}
  for _, e in ipairs(s1.ents) do all[#all + 1] = e end
  for _, e in ipairs(s2.ents) do all[#all + 1] = e end
  local at, dup = index(all)
  check(#dup == 0, "§3 aucune superposition entre les deux sections (" .. table.concat(dup, ",") .. ")")
  local ya2, yb2 = Mt.heights(r2)
  check(ya2 == 21 and yb2 == 22, "§3 hauteurs de la rangée 2")
  local r = follow(at, Mt.XL(1), Mt.Y_TOP)
  check(r[-1 .. ":" .. Mt.YA0] and r[-1 .. ":" .. ya2], "§3 la ligne 1 sert les deux rangées")
  local rb = follow(at, Mt.XL(2), Mt.Y_TOP)
  check(rb[-1 .. ":" .. Mt.YB0] and rb[-1 .. ":" .. yb2], "§3 la ligne 2 sert les deux rangées")
  check(#s2.quais == 0, "§3 pas de nouvelle tête de ligne")
  local rel
  for _, e in ipairs(s2.ents) do if e.role == "mall-poteau" and e.y == 14.5 then rel = e end end
  check(rel ~= nil, "§3 relais de la rangée 2 dans la tuile de passage (y = 14,5)")
  -- ligne ajoutée après coup (k = 3) : tuiles neuves seulement, hors des lignes existantes
  local ls3 = lines_for({ "fer", "cuivre", "acier" })
  ls3[1].y_to, ls3[2].y_to = s1.y_to[1], s1.y_to[2]
  local r3 = { j = 2, bus = { a = 1, b = 3 } }
  local s3 = Mt.section(ls3, r3, NAMES)
  local all3 = {}
  for _, e in ipairs(s1.ents) do all3[#all3 + 1] = e end
  for _, e in ipairs(s3.ents) do all3[#all3 + 1] = e end
  local _, dup3 = index(all3)
  check(#dup3 == 0, "§3 ligne neuve : aucune superposition (" .. table.concat(dup3, ",") .. ")")
  check(#s3.quais == 2, "§3 ligne neuve : deux coffres de tête")
  local function relais(sec) for _, e in ipairs(sec.ents) do if e.name == "pole" and e.x == -4.5 and e.y == -1.5 then return true end end return false end
  check(not relais(s3), "§3 ligne ajoutée à un tronc existant : pas de second relais de tête")
  check(not relais(s2), "§3 rangée 2 sur des lignes existantes : pas de relais de tête")
  local s4 = Mt.section(lines_for({ "fer", "cuivre" }), { j = 2, bus = { a = 1, b = 2 } }, NAMES)
  check(relais(s4), "§3 tronc commencé à la rangée 2 : relais de la tête vers le poteau de la rangée 1")
end

-- §3b aucune pièce du tronc sur une tuile que la chaîne de poteaux peut prendre
do
  local Mr = require("shared.team.mall_rangee")
  local ls = lines_for({ "fer", "cuivre", "acier" })
  local bad = 0
  for j = 1, 3 do
    local sec = Mt.section(ls, { j = j, bus = { a = 1, b = 3 } }, NAMES)
    for _, ln in ipairs(ls) do ln.y_to = sec.y_to[ln.k] end
    for _, e in ipairs(sec.ents) do
      for _, t in ipairs(tiles_of(e)) do
        if Mr.reserve_libre(t[1], t[2], Mt.WEST, Mt.NORTH) then bad = bad + 1; print("libre : " .. e.name .. " " .. t[1] .. "," .. t[2]) end
      end
    end
  end
  check(bad == 0, "§3b tronc, 3 lignes, 3 rangées : aucune pièce sur une tuile libre (" .. bad .. ")")
end

-- §4 mutants
do
  local path = "shared/team/mall_tronc.lua"
  local src = assert(io.open(path, "rb")):read("*a")
  local function run_mutant(from, to)
    local i, j = src:find(from, 1, true)
    if not i then return "motif introuvable" end
    local code = src:sub(1, i - 1) .. to .. src:sub(j + 1)
    local M2 = assert(load(code, "mutant", "t"))()
    local ok, res = pcall(function()
      local ls = { M2.ligne(1, "fer"), M2.ligne(2, "cuivre") }
      local row = { j = 1, bus = { a = 1, b = 2 } }
      local sec = M2.section(ls, row, NAMES)
      local at, dup = index(sec.ents)
      if #dup > 0 then return false end
      local ya, yb = M2.heights(row)
      local r = follow(at, M2.XL(1), M2.Y_TOP)
      if not r[-1 .. ":" .. ya] then return false end
      local r2 = follow(at, M2.XL(2), M2.Y_TOP)
      if not r2[-1 .. ":" .. yb] then return false end
      if r[-1 .. ":" .. yb] then return false end
      for _, ln in ipairs(ls) do
        local rr = follow(at, M2.XL(ln.k), M2.Y_TOP)
        if not rr[M2.XL(ln.k) .. ":" .. yb] then return false end
      end
      for _, rt in ipairs(sec.routes) do
        if not Pu.check(rt.tiles, rt.item, function() return nil end, {}) then return false end
      end
      for _, e in ipairs(sec.ents) do
        if e.role == "quai-bras" then
          local v = DV[e.dir]
          local pick = at[math.floor(e.x + v[1]) .. ":" .. math.floor(e.y + v[2])]
          if not (pick and pick.name == "chest") then return false end
        end
      end
      return true
    end)
    return ok and res or false
  end
  local mutants = {
    { "function Mt.XL(k) return -8 - 3 * (k - 1) end", "function Mt.XL(k) return -8 - 2 * (k - 1) end", "lignes serrées : entrée du souterrain sur la ligne voisine" },
    { "dir = 4, role = \"mall-prise\"", "dir = 0, role = \"mall-prise\"", "répartiteur à l'envers" },
    { "x = x + 1.5, y = Y + 0.5, dir = 2", "x = x + 1.5, y = Y + 0.5, dir = 4", "sortie du répartiteur qui ne tourne pas" },
    { "if y ~= split_y[ln.k] then", "if true then", "tapis sous le répartiteur" },
    { "dir = 6, role = \"quai-bras\"", "dir = 2, role = \"quai-bras\"", "bras de tête à l'envers" },
    { "for lx = Mt.LEAD_FROM, -1 do ents", "for lx = Mt.LEAD_FROM + 2, -1 do ents", "amenée trouée" },
    { "        flush(seg, ln.item)\n        seg = {}\n", "", "tracé de ligne non coupé au répartiteur" },
    { "for lx = Mt.LEAD_FROM, -1 do route", "for lx = Mt.LEAD_FROM + 1, -1 do route", "tracé de prise troué" },
  }
  local killed = 0
  for _, mu in ipairs(mutants) do
    local res = run_mutant(mu[1], mu[2])
    local refused = res ~= true
    check(refused, "§4 mutant refusé : " .. mu[3] .. " (" .. tostring(res) .. ")")
    if refused then killed = killed + 1 end
  end
  print(string.format("[MALL-TRONC] mutants refusés : %d/%d", killed, #mutants))
end

print(string.format("[MALL-TRONC] BILAN : %d OK, %d ECHEC(S)", ok_n, ko_n))
os.exit(ko_n == 0 and 0 or 1)
