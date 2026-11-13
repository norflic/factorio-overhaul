--[[
  s42 bus-direct : ligne directe d'une colonne de fours à la tête d'une ligne du tronc du mall (shared/team/sortie_directe.lua). Pur, aucune
  API Factorio. Usage, depuis la racine du mod :   lua5.2 tests/s42_bus-direct_test.lua
  1. Co.layout : le bout de la ligne de plaques (`fin`) est la dernière tuile du trop-plein, une seule, jamais sans trop-plein ;
  2. Sd.ends : bouts au format des sites de la liaison, dans les quatre sens ;
  3. Sd.choose : seuil « plusieurs colonnes », objet de la tête, plus proche, départage, paires prises ou refusées ;
  4. Sd.verify : tracé juste, et chaque écart (départ, face à face, rupture, arrivée de côté, doublon) ;
  5. Sd.quai et Sd.bar : coffres du quai d'une colonne posée par Co.layout, barre ;
  6. tête du tronc : la tuile visée est le premier tapis de Mt.tete_ligne, la tuile d'arrivée est hors de la place du tronc ;
  7. câblage : les modules de script se compilent et portent les crochets attendus.
]]
package.path = "./?.lua;" .. package.path
local Sd = require("shared.team.sortie_directe")
local Co = require("shared.team.champ_colonne")
local Mt = require("shared.team.mall_tronc")
local Li = require("shared.team.liaison")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

local SPEC = { furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 }, inserter = { rate = 0.83 }, pole = { reach = 2, wire = 7.5 } }

print("== 1. Co.layout : bout de la ligne de plaques")
for _, mode in ipairs({ "voie", "coffre" }) do
  for _, count in ipairs({ 1, 6, 24 }) do
    local name = mode .. " " .. count .. " fours"
    local a = Co.layout(SPEC, 0, 1, 0, count, mode)
    local b = Co.layout(SPEC, 0, 1, 0, count, mode, nil, Co.EXT)
    local na, nb, fin, umax = 0, 0, nil, -math.huge
    for _, e in ipairs(a) do if e.fin then na = na + 1 end end
    for _, e in ipairs(b) do
      if e.fin then nb = nb + 1; fin = e end
      if e.kind == "tapis" and e.role == "sortie" then umax = math.max(umax, e.u) end
    end
    check(na == 0, name .. " : sans trop-plein, aucun bout déclaré")
    check(nb == 1, name .. " : un seul bout (" .. nb .. ")")
    check(fin and fin.kind == "tapis" and fin.role == "sortie" and fin.u == umax and not fin.piq, name .. " : le bout est la dernière tuile de la ligne de plaques, non piquable")
  end
end

print("== 2. Sd.ends")
do
  local e = Sd.ends({ x = 10, y = 5, dir = 2 }, { x = -8, y = -3, dir = 4 })
  check(e.src.ax == 10 and e.src.ay == 5 and e.src.bx == 11 and e.src.by == 5 and e.src.dir == 2, "départ : la tuile devant le bout de la colonne")
  check(e.dst.ax == -8 and e.dst.ay == -3 and e.dst.bx == -8 and e.dst.by == -4, "arrivée : la tuile derrière la tête")
  check(Li.end_dir(e.dst) == 4, "la dernière tuile va dans le sens de la tête")
  for _, d in ipairs({ 0, 2, 4, 6 }) do
    local v = Sd.DV[d]
    local e2 = Sd.ends({ x = 0, y = 0, dir = d }, { x = 20, y = 20, dir = d })
    check(e2.src.bx == v[1] and e2.src.by == v[2] and e2.dst.bx == 20 - v[1] and e2.dst.by == 20 - v[2] and Li.end_dir(e2.dst) == d, "sens " .. d)
  end
  check(Sd.ends({ x = 0, y = 0, dir = 1 }, { x = 1, y = 1, dir = 4 }) == nil and Sd.ends({ x = 0, y = 0, dir = 2 }, { x = 1, y = 1, dir = 3 }) == nil, "direction fausse : nil")
end

print("== 3. Sd.choose")
do
  local heads = { { k = 1, item = "A", x = 0, y = 0, dir = 4 }, { k = 2, item = "B", x = -3, y = 0, dir = 4 } }
  local e1 = { key = "7:d1", x = 50, y = 0, dir = 2, item = "A" }
  local e2 = { key = "9:d1", x = 30, y = 0, dir = 2, item = "A" }
  local e3 = { key = "8:d1", x = 0, y = 30, dir = 2, item = "A" }
  local e4 = { key = "5:d1", x = 10, y = 0, dir = 2, item = "B" }
  local p, why = Sd.choose({ e2 }, heads, {})
  check(p == nil and why:find("1 bout", 1, true), "une seule colonne : rien (" .. tostring(why) .. ")")
  p, why = Sd.choose({ e1, e2 }, {}, {})
  check(p == nil and why:find("aucune tete", 1, true), "aucune tête : rien")
  p = Sd.choose({ e1, e2 }, heads, {})
  check(p and p.exit == e2 and p.head.k == 1 and p.d == 30, "le bout du même objet le plus proche")
  p = Sd.choose({ e1, e3, e2 }, heads, {})
  check(p and p.exit == e3, "égalité de distance : la plus petite clé (8:d1 avant 9:d1)")
  p = Sd.choose({ e3, e2, e1 }, heads, {})
  check(p and p.exit == e3, "le choix ne dépend pas de l'ordre de la liste")
  p = Sd.choose({ e1, e2, e4 }, heads, { exits = { ["9:d1"] = true }, heads = { [1] = true } })
  check(p and p.exit == e4 and p.head.k == 2, "tête 1 reliée : la tête 2 prend le bout de son objet")
  p = Sd.choose({ e1, e2 }, heads, { exits = { ["9:d1"] = true } })
  check(p and p.exit == e1, "bout déjà relié : le suivant")
  p = Sd.choose({ e1, e2 }, heads, {}, function(e, h) return e.key == "9:d1" and h.k == 1 end)
  check(p and p.exit == e1, "paire refusée récemment : le suivant")
  p, why = Sd.choose({ e1, e2 }, heads, { heads = { [1] = true, [2] = true } })
  check(p == nil and why:find("toutes les tetes", 1, true), "toutes les têtes reliées : rien")
  p, why = Sd.choose({ e1, e2 }, { heads[2] }, {})
  check(p == nil and why:find("aucun bout", 1, true), "aucun bout de l'objet de la tête : rien, jamais un autre objet")
end

print("== 4. Sd.verify")
do
  local exit, head = { x = 0, y = 0, dir = 2 }, { x = 3, y = 3, dir = 4 }
  local function line() return { { x = 1, y = 0, dir = 2 }, { x = 2, y = 0, dir = 2 }, { x = 3, y = 0, dir = 4 }, { x = 3, y = 1, dir = 4 }, { x = 3, y = 2, dir = 4 } } end
  check(#Sd.verify(line(), exit, head) == 0, "tracé juste : aucun écart (" .. tostring(Sd.verify(line(), exit, head)[1]) .. ")")
  check(#Sd.verify({}, exit, head) > 0, "tracé vide refusé")
  local t = line(); table.remove(t, 1)
  check(#Sd.verify(t, exit, head) > 0, "le bout de la colonne ne verse pas sur la première tuile : refusé")
  check(#Sd.verify({ { x = 1, y = 0, dir = 6 } }, exit, { x = 0, y = 0, dir = 6 }) > 0, "première tuile face au bout : refusé")
  t = line(); t[2].dir = 0
  check(#Sd.verify(t, exit, head) > 0, "chaîne rompue : refusé")
  t = line(); t[5] = nil
  check(#Sd.verify(t, exit, head) > 0, "la dernière tuile ne verse pas sur la tête : refusé")
  local side = { { x = 1, y = 0, dir = 2 }, { x = 2, y = 0, dir = 4 }, { x = 2, y = 1, dir = 4 }, { x = 2, y = 2, dir = 4 }, { x = 2, y = 3, dir = 2 } }
  check(#Sd.verify(side, exit, head) > 0, "arrivée par le côté de la tête (une seule voie) : refusé")
  t = line(); t[#t + 1] = { x = 3, y = 3, dir = 4 }
  check(#Sd.verify(t, exit, head) > 0, "tuile du tracé sur la tête : refusé")
  check(#Sd.verify({ { x = 1, y = 0, dir = 2 }, { x = 2, y = 0, dir = 6 }, { x = 1, y = 0, dir = 2 } }, exit, head) > 0, "deux tapis sur une tuile : refusé")
  check(#Sd.verify({ { x = 1, y = 0, dir = 3 } }, exit, head) > 0, "direction fausse : refusé")
end

print("== 5. Sd.quai et Sd.bar")
for _, count in ipairs({ 1, 6, 24 }) do
  local ents = Co.layout(SPEC, 0, 1, 0, count, "voie", nil, Co.EXT)
  local K = Co.bay_size(SPEC, count)
  local outs, fin, far_chest = {}, nil, { x = 0.5, y = 100.5 }
  for _, e in ipairs(ents) do
    if e.kind == "coffre" and e.role == "sortie" then outs[#outs + 1] = { x = e.u + 0.5, y = e.v + 0.5 } end
    if e.fin then fin = e end
  end
  outs[#outs + 1] = far_chest
  local idx = Sd.quai({ x = fin.u, y = fin.v, dir = 2 }, outs)
  check(#idx == K and #outs == K + 1, count .. " fours : les " .. K .. " coffres du quai, pas le coffre d'une autre colonne (" .. #idx .. ")")
  -- la même colonne tournée d'un quart de tour (u -> y, v -> -x) : même quai
  local r = {}
  for i, o in ipairs(outs) do r[i] = { x = -(o.y - 0.5) + 0.5, y = (o.x - 0.5) + 0.5 } end
  check(#Sd.quai({ x = -fin.v, y = fin.u, dir = 4 }, r) == K, count .. " fours : même quai, colonne tournée")
end
check(#Sd.quai({ x = 0, y = 0, dir = 2 }, { { x = 1.5, y = 2.5 }, { x = -45.5, y = 2.5 }, { x = -3.5, y = 3.5 }, { x = -3.5, y = 0.5 } }) == 0, "coffres en aval, trop loin, ou hors de la rangée du quai : aucun")
check(#Sd.quai({ x = 0, y = 0, dir = 2 }, { { x = -3.5, y = 2.5 }, { x = -3.5, y = -1.5 } }) == 2, "colonne double : les deux quais, de part et d'autre de la ligne")
check(Sd.bar(200, 100, 16) == 3, "barre : 2 cases pour 200 objets en piles de 100")
check(Sd.bar(50, 100, 16) == 2 and Sd.bar(nil, nil, 16) == 2, "barre : une case au moins")
check(Sd.bar(5000, 100, 16) == 17, "barre : jamais plus que le coffre")

print("== 6. tête du tronc")
for k = 1, Mt.KMAX do
  local t = Mt.tete_ligne(k, "A", { tapis = "t", bras = "b", coffre = "c", poteau = "p" })
  local top
  for _, e in ipairs(t.ents) do
    if e.role == "mall-tronc" and (not top or e.y < top.y) then top = e end
  end
  check(top and math.floor(top.x) == Mt.XL(k) and math.floor(top.y) == Mt.Y_TOP and top.dir == 4, "ligne " .. k .. " : la tête est la tuile (XL, Y_TOP), vers le sud")
  local e = Sd.ends({ x = 100, y = 100, dir = 2 }, { x = Mt.XL(k), y = Mt.Y_TOP, dir = 4 })
  check(e.dst.by == Mt.Y_TOP - 1 and e.dst.by < -Mt.NORTH, "ligne " .. k .. " : la tuile d'arrivée est au nord de la place du tronc")
  for _, x in ipairs(t.ents) do
    check(not (math.floor(x.x) == e.dst.bx and math.floor(x.y) == e.dst.by), "ligne " .. k .. " : aucune pièce de la tête sur la tuile d'arrivée")
  end
end

print("== 7. câblage")
do
  local function src(path) local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s end
  for _, path in ipairs({ "script/team/rapatriement.lua", "script/team/mall_rangee.lua", "script/team/champ.lua", "script/team/build.lua" }) do
    check(loadfile(path) ~= nil, path .. " se compile")
  end
  local rap = src("script/team/rapatriement.lua")
  check(rap:find("Rap.directes(api, f, surface, b, st, tick)", 1, true) ~= nil, "le relevé appelle Rap.directes")
  check(rap:find("Sd.verify(Tv.virtual_belts(tiles)", 1, true) ~= nil, "le plan prouve la ligne par Sd.verify")
  check(src("script/team/mall_rangee.lua"):find("function Rt.tetes(f)", 1, true) ~= nil, "le mall rend les têtes du tronc")
  check(src("script/team/build.lua"):find("p.sorties_directes = lay.directes", 1, true) ~= nil, "le projet de bande porte ses bouts de ligne de plaques")
  local sd = src("shared/team/sortie_directe.lua")
  check(not sd:find("game%."), "règle pure : aucune API du jeu")
  check(not sd:find("[^i]pairs%("), "aucun pairs dans la règle")
end

print(string.format("\n%d OK, %d ECHEC", passes, failures))
os.exit(failures == 0 and 0 or 1)
