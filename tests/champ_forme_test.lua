--[[
  Tests hors jeu du lot CHAMP-COUVERTURE, étape 0 : la forme d'un champ en une ligne de journal ([FO-CHAMP-FORME],
  shared/team/champ_forme.lua), relue hors jeu pour rejouer Ch.plan à l'identique. Pur, aucune API Factorio.
  Usage, depuis la racine du mod :   lua5.2 tests/champ_forme_test.lua
  1. aller-retour exact (ensembles, classes d'obstacles, nombres à virgule, charbon, souterrains) et point fixe de l'écriture ;
  2. le plan ne dépend pas de l'ordre de la liste du minerai (la relecture le range par (x, y)) ;
  3. le plan ne modifie pas la spec (la forme écrite après le plan est celle d'avant) ;
  4. plan rejoué IDENTIQUE (entité par entité) sur des formes à colonne et à coffres ; résultat r= relu ;
  5. taille d'une ligne ; ligne entière du journal (préfixe du moteur) ;
  6. mutants : plage tronquée, classe perdue, nombre arrondi, obstacles perdus, tous vus.
]]
package.path = "./?.lua;" .. package.path

local Ch = require("shared.team.champ")
local Cv = require("shared.team.champ_verif")
local Fo = require("shared.team.champ_forme")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local function disc(cx, cy, r, skip, out)
  out = out or {}
  for x = cx - r, cx + r do for y = cy - r, cy + r do
    if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r and not (skip and skip(x, y)) then out[#out + 1] = x; out[#out + 1] = y end
  end end
  return out
end

--- Spec « du jeu » au large de l'origine (coordonnées négatives), avec tout ce que le runtime remplit.
local function game_spec(colonne)
  local cx, cy = -404, 339
  local blocked, mine, foreign, soft = {}, {}, {}, {}
  for x = cx + 33, cx + 45 do for y = cy - 6, cy + 6 do blocked[Ch.key(x, y)] = "eau" end end
  for y = cy - 20, cy - 17 do blocked[Ch.key(cx - 34, y)] = "cliff" end
  for dx = 0, 1 do for dy = 0, 1 do blocked[Ch.key(cx - 33 + dx, cy + 10 + dy)] = "gun-turret" end end
  for x = cx - 3, cx + 3 do blocked[Ch.key(x, cy + 31)] = "couloir" end
  blocked[Ch.key(cx + 5, cy - 32)] = "reserve"
  for dx = 0, 1 do for dy = 0, 1 do mine[Ch.key(cx + dx, cy + dy)] = true; blocked[Ch.key(cx + dx, cy + dy)] = "burner-mining-drill" end end
  local ore = disc(cx, cy, 30, function(x, y)
    if (x * 3 + y * 5) % 23 == 0 then foreign[Ch.key(x, y)] = true; return true end
    return blocked[Ch.key(x, y)] == "eau"
  end)
  for x = cx - 40, cx - 36 do soft[Ch.key(x, cy + 2)] = true end
  local sp = { ore = ore, blocked = blocked, mine = mine, foreign = foreign, nforeign = 0, soft = colonne and soft or nil,
    drill = { size = 3, reach = 1, rate = 0.5 * (1 + 1 / 3) }, pole = { reach = 2, wire = 7.5 }, belts = { { lane = 7.5 }, { lane = 15 } },
    inserter = { rate = 0.83 }, target = { x = -340.5, y = 339.25 }, max_side = 8, logistics = { splitter = false, underground = 5 } }
  for _ in pairs(foreign) do sp.nforeign = sp.nforeign + 1 end
  if colonne then
    sp.furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 90000 / 4000000 }
    sp.design = "colonne"
    local coal = disc(cx + 60, cy + 40, 8)
    -- le runtime range le charbon par (x, y)
    local cells = {}
    for i = 1, #coal - 1, 2 do cells[#cells + 1] = { coal[i], coal[i + 1] } end
    table.sort(cells, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
    local flat = {}
    for _, c in ipairs(cells) do flat[#flat + 1] = c[1]; flat[#flat + 1] = c[2] end
    sp.coal = { tiles = flat, rate = 0.5, foreign = { [Ch.key(cx + 60, cy + 49)] = true }, nforeign = 1 }
    sp.ug_tiles = { { cx + 50, cy + 30 }, { cx + 55, cy + 30 } }
  end
  return sp
end

local function set_eq(a, b)
  a, b = a or {}, b or {}
  for k, v in pairs(a) do if v and not b[k] then return false end end
  for k, v in pairs(b) do if v and not a[k] then return false end end
  return true
end
local function class_map(v) return Fo.UNCLASS[Fo.CLASS[v] or "b"] end
local function classes_eq(a, b)
  for k, v in pairs(a or {}) do if b[k] ~= class_map(v) then return false end end
  for k in pairs(b or {}) do if not a[k] then return false end end
  return true
end
local function flat_set(flat)
  local s = {}
  for i = 1, #(flat or {}) - 1, 2 do s[Ch.key(flat[i], flat[i + 1])] = true end
  return s
end

--- Différences entre une spec et sa relecture (liste vide : identiques).
local function diff(a, b)
  local out = {}
  local function eq(name, x, y) if x ~= y then out[#out + 1] = name .. " " .. tostring(x) .. " ~= " .. tostring(y) end end
  eq("drill.size", a.drill.size, b.drill.size); eq("drill.reach", a.drill.reach, b.drill.reach); eq("drill.rate", a.drill.rate, b.drill.rate)
  eq("pole.reach", a.pole.reach, b.pole.reach); eq("pole.wire", a.pole.wire, b.pole.wire)
  eq("belts", #a.belts, #b.belts)
  for i = 1, #a.belts do eq("lane" .. i, a.belts[i].lane, b.belts[i] and b.belts[i].lane) end
  eq("furnace", a.furnace ~= nil, b.furnace ~= nil)
  if a.furnace and b.furnace then
    for _, k in ipairs({ "size", "rate", "fuel", "fuel_rate", "yield" }) do eq("furnace." .. k, a.furnace[k], b.furnace[k]) end
  end
  eq("inserter", a.inserter and a.inserter.rate, b.inserter and b.inserter.rate)
  eq("max_side", a.max_side, b.max_side); eq("design", a.design, b.design)
  eq("splitter", a.logistics and a.logistics.splitter, b.logistics and b.logistics.splitter)
  eq("underground", a.logistics and a.logistics.underground, b.logistics and b.logistics.underground)
  eq("target.x", a.target and a.target.x, b.target and b.target.x); eq("target.y", a.target and a.target.y, b.target and b.target.y)
  eq("nforeign", a.nforeign, b.nforeign)
  if not set_eq(flat_set(a.ore), flat_set(b.ore)) then out[#out + 1] = "ore" end
  if #a.ore ~= #b.ore then out[#out + 1] = "ore (taille)" end
  if not classes_eq(a.blocked, b.blocked) then out[#out + 1] = "blocked" end
  if not set_eq(a.mine, b.mine) then out[#out + 1] = "mine" end
  if not set_eq(a.foreign, b.foreign) then out[#out + 1] = "foreign" end
  eq("soft", a.soft ~= nil, b.soft ~= nil)
  if a.soft and not set_eq(a.soft, b.soft) then out[#out + 1] = "soft" end
  eq("coal", a.coal ~= nil, b.coal ~= nil)
  if a.coal and b.coal then
    eq("coal.rate", a.coal.rate, b.coal.rate); eq("coal.nforeign", a.coal.nforeign, b.coal.nforeign)
    local same = #a.coal.tiles == #b.coal.tiles
    for i = 1, #a.coal.tiles do if a.coal.tiles[i] ~= b.coal.tiles[i] then same = false end end
    if not same then out[#out + 1] = "coal.tiles (ordre (x, y) compris)" end
    if not set_eq(a.coal.foreign, b.coal.foreign) then out[#out + 1] = "coal.foreign" end
  end
  eq("ug_tiles", a.ug_tiles and #a.ug_tiles, b.ug_tiles and #b.ug_tiles)
  for i = 1, #(a.ug_tiles or {}) do
    eq("ug" .. i, a.ug_tiles[i][1] .. "," .. a.ug_tiles[i][2], b.ug_tiles[i] and (b.ug_tiles[i][1] .. "," .. b.ug_tiles[i][2]))
  end
  return out
end

local function sig(e)
  return string.format("%s:%.2f:%.2f:%d:%s:%s:%s", e.kind, e.x, e.y, e.dir, tostring(e.band), tostring(e.group), tostring(e.role))
end
local function serial(p)
  if not p then return "nil" end
  local t = { p.axis, tostring(p.exit), tostring(p.phase) }
  for _, e in ipairs(p.ents) do t[#t + 1] = sig(e) end
  return table.concat(t, ";")
end
local function result(p, sp)
  local rep = Cv.verify(p, sp)
  local n = 0
  for _, bd in ipairs(p.bands) do if #bd.groups > 0 then n = n + 1 end end
  return { covered = rep.covered, tiles = rep.tiles, drills = p.stats.drills, bands = n }
end

section("1. aller-retour exact")
local specs = { { "colonne au charbon", game_spec(true) }, { "coffres", game_spec(false) } }
for _, it in ipairs(specs) do
  local sp = it[2]
  local line = Fo.encode(sp, { covered = 1, tiles = 2, drills = 3, bands = 4 })
  local back, res = Fo.decode(line)
  check(back ~= nil, it[1] .. " : relue (" .. tostring(res) .. ")")
  if back then
    local d = diff(sp, back)
    check(#d == 0, it[1] .. " : spec relue identique (" .. table.concat(d, ", ") .. ")")
    check(res.covered == 1 and res.tiles == 2 and res.drills == 3 and res.bands == 4, it[1] .. " : resultat r= relu")
    check(Fo.encode(back, res) == line, it[1] .. " : point fixe (ecrire la relecture redonne la meme ligne)")
    check(not string.find(line, "\n"), it[1] .. " : une seule ligne")
  end
end

section("2. ordre du minerai")
do
  local sp = game_spec(true)
  local p0 = serial(Ch.plan(sp))
  local cells = {}
  for i = 1, #sp.ore - 1, 2 do cells[#cells + 1] = { sp.ore[i], sp.ore[i + 1] } end
  local seed = 12345
  for i = #cells, 2, -1 do
    seed = (seed * 1103515245 + 12345) % 2147483648
    local j = seed % i + 1
    cells[i], cells[j] = cells[j], cells[i]
  end
  local sh = {}
  for k, v in pairs(sp) do sh[k] = v end
  sh.ore = {}
  for _, c in ipairs(cells) do sh.ore[#sh.ore + 1] = c[1]; sh.ore[#sh.ore + 1] = c[2] end
  check(serial(Ch.plan(sh)) == p0, "plan identique avec le minerai dans un autre ordre")
end

section("3. le plan ne modifie pas la spec")
for _, it in ipairs(specs) do
  local before = Fo.encode(it[2], {})
  Ch.plan(it[2])
  check(Fo.encode(it[2], {}) == before, it[1] .. " : forme identique avant et apres le plan")
end

section("4. plan rejoue identique")
for _, it in ipairs(specs) do
  local sp = it[2]
  local p = Ch.plan(sp)
  check(p ~= nil, it[1] .. " : plan rendu")
  if p then
    local r = result(p, sp)
    local back, res = Fo.decode(Fo.encode(sp, r))
    local q = Ch.plan(back)
    check(serial(q) == serial(p), it[1] .. " : plan rejoue identique, entite par entite (" .. #p.ents .. " entites)")
    local r2 = result(q, back)
    check(r2.covered == res.covered and r2.tiles == res.tiles and r2.drills == res.drills and r2.bands == res.bands,
      string.format("%s : resultat rejoue = resultat ecrit (%d/%d, %d foreuses, %d bandes)", it[1], r2.covered, r2.tiles, r2.drills, r2.bands))
  end
end

section("5. taille, ligne du journal")
do
  local sp = game_spec(true)
  local line = Fo.encode(sp, {})
  print(string.format("  ligne de la forme : %d caracteres (%d tuiles de minerai)", #line, #sp.ore / 2))
  check(#line <= 6000, "une forme de disque r30 avec obstacles tient en 6 000 caracteres au plus (" .. #line .. ")")
  local full = "  324.260 Script @__factorio-overhaul__/script/team/champ.lua:530: [FO-CHAMP-FORME] emerald : avant-poste 4 (iron) : " .. line
  local back = Fo.decode(full)
  check(back ~= nil and #diff(sp, back) == 0, "ligne entiere du journal (prefixe du moteur) relue")
  check(Fo.decode("[FO-CHAMP] rien") == nil, "ligne sans forme refusee")
  check(Fo.decode(Fo.VERSION .. " | r=1/2,3,4 | O=5:x+1") == nil, "plage illisible refusee")
end

section("6. mutants")
do
  local sp = game_spec(true)
  local line = Fo.encode(sp, {})
  -- champs de la ligne, retouchés un par un (le séparateur « | » est gardé)
  local function split(l)
    local t = {}
    for part in string.gmatch(l .. " | ", "(.-) | ") do t[#t + 1] = part end
    return t
  end
  local function edit(l, k, fn)
    local t = split(l)
    local out = {}
    for _, part in ipairs(t) do
      local kk, v = string.match(part, "^(%a+)=(.*)$")
      if kk == k then
        local nv = fn(v)
        if nv then out[#out + 1] = k .. "=" .. nv end
      else out[#out + 1] = part end
    end
    return table.concat(out, " | ")
  end
  local muts = {
    { "plage tronquee (derniere plage de chaque rangee du minerai perdue)", function(l)
        return edit(l, "O", function(v) return (v:gsub(",[^,;]+;", ";")) end) end },
    { "classe d'obstacle perdue (toutes en b)", function(l)
        return edit(l, "X", function(v) return (v:gsub("%a", "b")) end) end },
    { "nombre arrondi (debit de foreuse a 6 chiffres)", function(l)
        return edit(l, "d", function() return string.format("%d,%d,%.6g", sp.drill.size, sp.drill.reach, sp.drill.rate) end) end },
    { "obstacles perdus (champ X retire)", function(l) return edit(l, "X", function() return nil end) end },
  }
  for _, m in ipairs(muts) do
    local ml = m[2](line)
    local back = Fo.decode(ml)
    local seen = (back == nil) or (#diff(sp, back) > 0)
    check(ml ~= line and seen, "mutant vu : " .. m[1])
  end
  -- un mutant qui change le PLAN (pas seulement la spec) : disque r30 entre deux lacs (mesure_essai-a : 23 % au lieu de 81 %), ses
  -- obstacles perdus rendent un autre plan
  local lk = game_spec(true)
  local cx, cy = -404, 339
  lk.blocked = {}
  for x = 33, 60 do for y = -15, 15 do lk.blocked[Ch.key(cx + x, cy + y)] = "eau"; lk.blocked[Ch.key(cx - x, cy + y)] = "eau" end end
  local ll = Fo.encode(lk, {})
  local back = Fo.decode(muts[4][2](ll))
  check(back and serial(Ch.plan(back)) ~= serial(Ch.plan(lk)), "mutant vu au plan rejoue : obstacles perdus (disque entre deux lacs)")
end

print(string.format("[CHAMP-FORME] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
