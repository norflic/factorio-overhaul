--[[
  Tests hors jeu du lot DECOUPLAGE (directive du DC du 11/11 : « Cesse de concevoir des bandes hybrides qui associent foreuses et
  fours dans un même gabarit » ; BOX_MINAGE sur le minerai, BOX_FONDERIE sur le sol neutre). Pur, aucune API Factorio.
  Usage, depuis la racine du mod :   lua5.2 tests/decouplage_test.lua

  1. Sm.mining_box : foreuses + poteaux + tapis = BOX_MINAGE ; un seul four, bras ou coffre = BOX_FONDERIE ; sans lecteur de type : strict ;
  2. P.fit, BOX_FONDERIE (colonne de fours) : ressource sur la moitié du lot -> posée sur l'autre moitié, aucune tuile de l'emprise ni
     des têtes sur une ressource ; ressource partout -> refus ; sans `res` -> comme avant ;
  3. P.fit, BOX_MINAGE (ligne de foreuses) : posée sur le minerai malgré `res` ;
  4. Co.place, cadre figé (`fixed`) : une colonne figée sur une ressource est refusée (le cadre d'avant F500 ne la gardait pas) ;
  5. mutants : chaque coupe retirée est vue ;
  9. (lot FONDERIE-BOUT) bout de bande muré : la colonne se pose ailleurs sur le sol neutre (Co.away), hors ressource, nourrie par le
     tapis collecteur prolongé (aucun relais) ; plan vérifié (Cv.verify) avec combustible et four électrique ;
  6. règle 3 (plan_feed, script/team/build.lua) : la voie de minerai d'une fonderie est servie par foreuses et tapis, quel que soit le
     mode demandé ou le seuil ; sans tapis possible, le plan est refusé (plus de quai de minerai de repli). Le combustible garde son quai.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local function read(path) local h = assert(io.open(path, "rb")); local s = h:read("*a"); h:close(); return s end

local MODS = { sm = "shared.team.sol_minerai", p = "shared.team.plan", co = "shared.team.champ_colonne", ch = "shared.team.champ" }
-- type de prototype des entités des gabarits de test (le moteur le lit dans game.entity_prototypes)
local TYPE_OF_KIND = { drill = "mining-drill", pole = "electric-pole", belt = "transport-belt", furnace = "furnace",
  inserter = "inserter", chest = "container" }

local function load_mods(mut)
  for _, m in pairs(MODS) do package.loaded[m] = nil end
  if mut then
    local s2, n = read(mut.file):gsub(mut.from, mut.to, 1)
    assert(n == 1, "mutant introuvable : " .. mut.name)
    package.loaded[mut.mod] = assert(load(s2, "=" .. mut.name))()
  end
  local Sm, P, Co = require(MODS.sm), require(MODS.p), require(MODS.co)
  local M = require("shared.team.modules")
  Sm.type_of = function(name) local s = M.spec(name); return s and TYPE_OF_KIND[s.kind] end
  return Sm, P, Co, M
end

-- tuiles d'un gabarit posé (emprise et têtes) qui tombent sur `res`
local function hits(P, M, g, fit, res)
  local inst = M.instantiate(g, fit.k, fit.ox, fit.oy)
  local n = 0
  for _, e in ipairs(inst.entities) do
    for _, t in ipairs(P.tiles_of({ name = e.name, x = e.position.x, y = e.position.y, dir = e.direction })) do
      if res[P.tkey(t[1], t[2])] then n = n + 1 end
    end
  end
  for _, t in ipairs(P.port_room(inst)) do if res[P.tkey(t[1], t[2])] then n = n + 1 end end
  return n
end

local function scenario(tag, Sm, P, Co, M)
  local lat = P.lattice({ x = 0, y = 0 })
  local x0, y0, x1, y1 = P.lot_rect(lat, 1, 0)
  local rect = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  local smelter = M.GEN.smelter("stone-furnace", "iron-ore", 2)
  local drills = M.GEN.drills("iron-ore", 2)
  local half, all = {}, {}
  for y = y0, y1 - 1 do
    for x = x0, x1 - 1 do
      all[P.tkey(x, y)] = true
      if x >= x0 + 12 then half[P.tkey(x, y)] = true end
    end
  end
  -- 1.
  check(Sm.mining_box(drills) == true, tag .. "ligne de foreuses (foreuses, tapis, poteaux) : BOX_MINAGE")
  check(Sm.mining_box(smelter) == false, tag .. "colonne de fours : BOX_FONDERIE")
  -- 2.
  local f0 = P.fit(smelter, rect, { toward = { x = x1, y = y0 } })
  check(f0 ~= nil, tag .. "fonderie sans `res` : posée (comme avant)")
  local f1 = P.fit(smelter, rect, { toward = { x = x1, y = y0 }, res = half })
  check(f1 ~= nil and hits(P, M, smelter, f1, half) == 0,
    tag .. "fonderie, ressource sur la moitié est : aucune tuile de l'emprise ni des têtes sur la ressource ("
      .. tostring(f1 and hits(P, M, smelter, f1, half)) .. ")")
  if f0 then -- ressource sous la seule emprise de la meilleure place (pas sous ses têtes) : la fonderie va ailleurs
    local inst, under = M.instantiate(smelter, f0.k, f0.ox, f0.oy), {}
    for _, e in ipairs(inst.entities) do
      for _, t in ipairs(P.tiles_of({ name = e.name, x = e.position.x, y = e.position.y, dir = e.direction })) do under[P.tkey(t[1], t[2])] = true end
    end
    local fu = P.fit(smelter, rect, { toward = { x = x1, y = y0 }, res = under })
    check(fu ~= nil and hits(P, M, smelter, fu, under) == 0, tag .. "fonderie, ressource sous l'emprise seule : déplacée hors de la ressource")
  end
  local f2 = P.fit(smelter, rect, { res = all })
  check(f2 == nil, tag .. "fonderie, ressource partout : refus")
  -- 3.
  local f3 = P.fit(drills, rect, { ore = all, res = all })
  check(f3 ~= nil, tag .. "foreuses sur le minerai : posées malgré `res` (BOX_MINAGE)")
  -- 4.
  local spec = { furnace = { size = 2, rate = 0.3125 }, inserter = { rate = 0.83 }, pole = { reach = 2, wire = 7.5 } }
  local function free() return true end
  local count = 2
  local c0, _, s0 = Co.place(spec, 0, 1, 0, count, 2, 0, free, function() return false end, nil, nil)
  check(c0 ~= nil, tag .. "colonne sans minerai : posée")
  local cf = Co.place(spec, 0, 1, 0, count, 2, 0, free, function() return true end, nil, { s_edge = s0, count = count })
  check(cf == nil, tag .. "colonne d'un cadre figé sur une ressource : refusée")
  -- 7. la foreuse ne dépend QUE du minerai (agent PAVAGE-GEANT, 0.7.5, graine 2507543475 : émeraude fer, 37 foreuses sur 42 retirées du
  -- plan faute de place pour les fours) : champ muré, aucune place de fonderie -> toutes les foreuses des rangées restent, aucun four
  local Ch = require(MODS.ch)
  local ore, wall = {}, {}
  for x = -12, 12 do for y = -8, 8 do if (x / 12) ^ 2 + (y / 8) ^ 2 <= 1 then ore[#ore + 1] = x; ore[#ore + 1] = y end end end
  for x = -80, 80 do for y = -80, 80 do if not (x >= -16 and x <= 16 and y >= -11 and y <= 11) then wall[Ch.key(x, y)] = true end end end
  local sp = { ore = ore, blocked = wall, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }, furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 },
    inserter = { rate = 0.83 }, target = { x = 1000, y = 0 }, max_side = 8, design = "colonne", logistics = {} }
  local pw = Ch.plan(sp)
  local fours, drills = 0, 0
  for _, e in ipairs(pw and pw.ents or {}) do
    if e.kind == "four" then fours = fours + 1 elseif e.kind == "foreuse" then drills = drills + 1 end
  end
  check(pw ~= nil and pw.stats.no_smelter >= 1 and drills > 0 and drills == pw.stats.band_drills - pw.stats.capped and fours == 0,
    string.format(tag .. "champ sans place de fonderie : les foreuses restent (%d sur %d possibles, %d groupe(s) sans fonderie, %d four)",
      drills, pw and pw.stats.band_drills or -1, pw and pw.stats.no_smelter or -1, fours))
  -- et leur tapis collecteur sort du champ, la tuile devant sa sortie libre
  local belts = 0
  for _, e in ipairs(pw and pw.ents or {}) do if e.kind == "tapis" then belts = belts + 1 end end
  check(belts > 0, tag .. "tapis collecteur posé sans fonderie (" .. belts .. ")")
  -- 9. lot FONDERIE-BOUT : bouts de bande murés (aucune place de colonne dans leur prolongement), sol neutre plus loin, une autre ressource
  -- au sud : la colonne se pose AILLEURS, hors de toute ressource, et le collecteur la nourrit sans relais (tapis continu, Cv.flow)
  local Cv = require("shared.team.champ_verif")
  for _, fuel in ipairs({ true, false }) do
    local wall2, foreign = {}, {}
    for x = -140, 140 do for y = -11, 11 do if math.abs(x) >= 16 then wall2[Ch.key(x, y)] = true end end end
    for x = 13, 45 do for y = 12, 15 do foreign[Ch.key(x, y)] = true end end
    local s9 = { ore = ore, blocked = wall2, foreign = foreign, drill = sp.drill, pole = sp.pole, belts = sp.belts,
      furnace = { size = 2, rate = 0.3125, fuel = fuel, fuel_rate = 0.0225 }, inserter = sp.inserter, target = sp.target, max_side = 8,
      design = "colonne", logistics = { underground = 5 }, window = { -150, -40, 150, 40 } }
    local t9 = tag .. (fuel and "[combustible] " or "[électrique] ")
    local p9 = Ch.plan(s9)
    local res = {}
    for i = 1, #ore - 1, 2 do res[Ch.key(ore[i], ore[i + 1])] = true end
    for k in pairs(foreign) do res[k] = true end
    local away, f9, on_res, links = 0, 0, 0, 0
    for _, bd in ipairs(p9 and p9.bands or {}) do for _, g in ipairs(bd.groups) do if g.away then away = away + 1 end end end
    for _, e in ipairs(p9 and p9.ents or {}) do
      if e.kind == "four" then f9 = f9 + 1 end
      if e.role == "lien" then links = links + 1 end
      if e.kind == "four" or e.kind == "bras" or e.kind == "coffre" then
        local w, h = e.w or e.size, e.h or e.size
        local x0, y0 = math.floor(e.x - w / 2 + 0.5), math.floor(e.y - h / 2 + 0.5)
        for x = x0, x0 + w - 1 do for y = y0, y0 + h - 1 do if res[Ch.key(x, y)] then on_res = on_res + 1 end end end
      end
    end
    check(p9 ~= nil and away >= 2 and f9 > 0 and links > 0,
      string.format(t9 .. "bouts murés : colonnes posées ailleurs (%d groupe(s), %d fours, %d tapis de lien)", away, f9, links))
    check(on_res == 0, t9 .. "colonne ailleurs : aucune tuile de four, bras ou coffre sur une ressource (" .. on_res .. ")")
    local r = p9 and Cv.verify(p9, s9) or {}
    check(r.overlaps == 0 and r.blocked == 0 and r.traverse == 0 and r.drops == 0 and r.arms == 0 and r.no_ore == 0 and r.no_coal == 0
      and r.no_plate == 0 and r.junction == 0 and r.mixed == 0 and r.unpowered == 0,
      t9 .. "colonne ailleurs : plan vérifié, chaque four reçoit le minerai du collecteur (" .. (p9 and Cv.line(r) or "pas de plan") .. ")")
  end
end

section("1 à 4. Règle BOX_MINAGE / BOX_FONDERIE")
scenario("", load_mods())

-- sans lecteur de type : tout gabarit est une BOX_FONDERIE (le plus strict)
do
  local Sm, P, _, M = load_mods()
  Sm.type_of = nil
  check(Sm.mining_box(M.GEN.drills("iron-ore", 1)) == false, "sans lecteur de type : BOX_FONDERIE (strict)")
end

section("6. Règle 3 : la voie de minerai d'une fonderie vient par tapis, jamais par quai (plan_feed)")
do
  local Sm, _, _, M = load_mods()
  local T = require("shared.team.config")
  local ore, plate
  for _, k in ipairs({ "iron-ore", "copper-ore", "stone" }) do if M.ORES[k] and k ~= T.fuel then ore = ore or k end end
  plate = M.PLATE_OF[ore]
  check(Sm.belt_only(ore, M.ORES, T.fuel) == true, "voie de minerai (" .. tostring(ore) .. ") : tapis obligatoire")
  check(Sm.belt_only(T.fuel, M.ORES, T.fuel) == false, "voie du combustible : son quai reste permis")
  check(Sm.belt_only(plate, M.ORES, T.fuel) == false and Sm.belt_only(nil, M.ORES, T.fuel) == false, "plaque, voie vide : pas de tapis imposé")
  local src = read("script/team/build.lua")
  local a = src:find("local function plan_feed", 1, true)
  local body = a and src:sub(a, (src:find("\nlocal function ", a + 1, true) or #src)) or ""
  check(body:find("local need_belt = Build.Sm.belt_only(item, M.ORES, T.fuel)", 1, true) ~= nil, "plan_feed lit la règle (quel que soit spec.feed)")
  check(body:find("if need_belt or (M.ORES[item]", 1, true) ~= nil, "plan_feed : voie de minerai sous le seuil du tapis servie par tapis")
  check(body:find("if not ok and d.need then", 1, true) ~= nil, "plan_feed : tapis des foreuses impossible -> plan refusé, pas de quai de repli pour le minerai")
  check(body:find('p.spec.feed == "tapis" and M.ORES', 1, true) == nil and body:find("sous le seuil du tapis", 1, true) == nil,
    "plan_feed : plus de quai de minerai selon le mode ou le seuil")
end

section("8. Poses du moteur (fours et labos du QG, coffres annexes, tourelles) : même règle (Sm.forbidden)")
do
  local Sm = load_mods()
  local asked = 0
  local function yes() asked = asked + 1 return true end
  local function no() asked = asked + 1 return false end
  check(Sm.forbidden("furnace", yes) == true and Sm.forbidden("ammo-turret", yes) == true and Sm.forbidden("container", yes) == true,
    "four, tourelle, coffre sur une ressource : interdits")
  check(Sm.forbidden("furnace", no) == false, "four sur le sol neutre : permis")
  asked = 0
  check(Sm.forbidden("mining-drill", yes) == false and Sm.forbidden("electric-pole", yes) == false and asked == 0,
    "foreuse, poteau : permis sans relever le sol")
  local q = read("script/ai3/places_qg.lua")
  check(q:find("can_place_entity({ name = name, position = p, force = force }) or Q.on_resource(surface, name, p)", 1, true) ~= nil,
    "places_qg : chaque place vérifiée contre la ressource (fours, labos, annexes)")
  local o = read("script/faction/outposts.lua")
  -- (fusion TUILES-RESERVEES : les deux places, recherche et repli, lisent le même prédicat `banned`, qui interroge la ressource)
  local _, n_o = o:gsub("PlacesQG%.on_resource%(surface, T%.turret, q%)", "")
  local _, n_b = o:gsub("not banned%(q%)", "")
  check(n_o == 1 and n_b >= 1 and o:find("if banned(q) then return true end", 1, true) ~= nil,
    "outposts.fortify : les deux places de tourelle vérifiées (" .. n_o .. ", " .. n_b .. ")")
  check(read("script/team/team.lua"):find("if tpos and not PlacesQG.on_resource(surface, T.turret, tpos) then", 1, true) ~= nil,
    "team : tourelles de départ hors des ressources")
end

section("5. mutants")
local MUTANTS = {
  { name = "P.fit : emprise sur la ressource", mod = MODS.p, file = "shared/team/plan.lua",
    from = "and %(%(not rsat%) or count%(rsat, ox %- rect%.x0, oy %- rect%.y0, r%.w, r%.h%) == 0%)", to = "" },
  { name = "P.fit : têtes sur la ressource", mod = MODS.p, file = "shared/team/plan.lua",
    from = " or %(rsat and opts%.res%[tkey%(tx, ty%)%]%)", to = "" },
  { name = "P.fit : BOX_MINAGE refusée", mod = MODS.p, file = "shared/team/plan.lua",
    from = "opts%.res and not Sm%.mining_box%(g%)", to = "opts.res" },
  { name = "Ch.plan : groupe sans fonderie retiré (0.7.5)", mod = MODS.ch, file = "shared/team/champ.lua",
    from = "bare_todo%[#bare_todo %+ 1%] = { bi = bi, bd = bd, used = used, side = side, edge = edge, refused = refused and true or nil }", to = "" },
  { name = "Ch.plan : aucune colonne ailleurs (avant FONDERIE-BOUT)", mod = MODS.ch, file = "shared/team/champ.lua",
    from = "if colonne and not t%.refused then", to = "if false then" },
  { name = "Co.away : colonne sur une ressource", mod = MODS.co, file = "shared/team/champ_colonne.lua",
    from = "m = inb%(u, v%) and free%(u, v%) and not is_ore%(u, v%)", to = "m = inb(u, v) and free(u, v)" },
  { name = "Co.away : tapis de lien sauté", mod = MODS.co, file = "shared/team/champ_colonne.lua",
    from = "        if route then\n", to = "        if route then route = {}\n" },
  { name = "Co.place : cadre figé sur la ressource", mod = MODS.co, file = "shared/team/champ_colonne.lua",
    from = "if not free%(u, v%) or is_ore%(u, v%) then return false end", to = "if not free(u, v) then return false end" },
}
-- (règle 3) mutant de la règle pure : le combustible n'est plus exclu / le minerai n'est plus vu
do
  local p0, f0 = passes, failures
  local Sm, _, _, M = load_mods()
  local T = require("shared.team.config")
  local keep = Sm.belt_only
  Sm.belt_only = function(item, ores) return item ~= nil and ores[item] ~= nil end
  local bad1 = Sm.belt_only(T.fuel, M.ORES, T.fuel) == true
  Sm.belt_only = function() return false end
  local bad2 = Sm.belt_only("iron-ore", M.ORES, T.fuel) == false
  Sm.belt_only = keep
  passes, failures = p0, f0
  check(bad1 and bad2 and keep("iron-ore", M.ORES, T.fuel) and not keep(T.fuel, M.ORES, T.fuel), "mutants de Sm.belt_only vus")
end
for _, mu in ipairs(MUTANTS) do
  local p0, f0 = passes, failures
  scenario("[" .. mu.name .. "] ", load_mods(mu))
  local seen = failures > f0
  passes, failures = p0, f0
  check(seen, "mutant vu : " .. mu.name)
end

print(string.format("[DECOUPLAGE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
