--[[
  Tests hors jeu du lot ENERGIE-CROISSANCE (retour du DC du 29/10 sur la 0.6.18 : « ils ont un déficit en électricité. Ils n'ont pas
  augmenté […] la production d'électricité »). Usage : lua5.2 tests/energie_croissance_test.lua

  Cause lue au journal de la partie du DC (factorio-current.log, 29/10, Écarlate) :
    83,3 min  centrale saturee (30000 J/tick sur 30000) -> centrale de plus demandee (projet 17) -> « refuse (pas de lot) »
    83,8 min  idem (projet 18) -> « refuse (pas de lot) »
    84,3 min  « pas de centrale de plus : plan refuse deux fois » ; saturee encore a 95,3 et 132,5 min, plus aucune demande.
  La seule eau du treillis était l'étang garanti (make_pond), pris par la première centrale ; candidates() excluait tout lot pris.

  1. Géométrie (pure : shared/team/plan.lua P.fit, shared/team/modules.lua G.steam) : autour d'un étang de 6 × 6 au centre d'un
     lot (make_pond), une DEUXIÈME centrale d'une chaudière tient sur un autre bord, quelle que soit la direction du QG ; elle ne
     chevauche pas la première ; une troisième ne tient pas (borne honnête : 2 centrales, 3,6 MW, sur l'étang seul).
  2. Branchement (lecture des sources, sans moteur) : candidates() accepte la rive d'une centrale FINIE, le lot reste au nom de la
     première centrale, un échec de pose sur la rive partagée ne marque pas le lot mauvais, le refus ouvre une pause et la
     croissance réessaie (plant_arms), la centrale de plus passe devant la production ordinaire mais derrière réparer/protéger.
]]
package.path = "./?.lua;" .. package.path
local M = require("shared.team.modules")
local P = require("shared.team.plan")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

print("== 1. Deux centrales sur l'etang garanti")
local POND = 6 -- Build.POND (script/team/build.lua), relu plus bas dans la source
local function pond_lot(x0, y0)
  local rect = { x0 = x0, y0 = y0, x1 = x0 + P.LOT, y1 = y0 + P.LOT }
  local cx, cy = (rect.x0 + rect.x1) / 2, (rect.y0 + rect.y1) / 2
  local px, py = math.floor(cx - POND / 2), math.floor(cy - POND / 2)
  local water = {}
  for dx = 0, POND - 1 do for dy = 0, POND - 1 do water[P.tkey(px + dx, py + dy)] = true end end
  return rect, water
end

local function place_all(toward, nb_list)
  local rect, water = pond_lot(100, 200)
  local occ = {}
  local free = function(x, y) local k = P.tkey(x, y) return not water[k] and not occ[k] end
  local placed = {}
  for _, nb in ipairs(nb_list) do
    local g = M.GEN.steam(nb)
    local fit = P.fit(g, rect, { free = free, water = water, margin = 0, toward = toward })
    if not fit then break end
    local r = fit.k == 0 and g or M.rotate(g, fit.k)
    local inst = M.instantiate(r, 0, fit.ox, fit.oy)
    local tiles, clash = {}, false
    for _, e in ipairs(inst.entities) do
      for _, t in ipairs(P.tiles_of({ name = e.name, x = e.position.x, y = e.position.y, dir = e.direction })) do
        local k = P.tkey(t[1], t[2])
        if occ[k] or water[k] then clash = true end
        tiles[#tiles + 1] = k
      end
    end
    for _, k in ipairs(tiles) do occ[k] = true end
    -- tête d'alimentation (charbon) réservée elle aussi : la centrale suivante ne la prend pas
    for _, t in ipairs(P.port_room(inst)) do occ[P.tkey(t[1], t[2])] = true end
    placed[#placed + 1] = { fit = fit, clash = clash }
  end
  return placed
end

local dirs = { { 0, 0 }, { 500, 212 }, { 112, 500 }, { 112, -500 }, { -500, 212 }, { 500, 500 }, { -500, -500 } }
for _, d in ipairs(dirs) do
  local placed = place_all({ x = d[1], y = d[2] }, { 1, 1, 1 })
  local tag = string.format("QG vers (%d, %d)", d[1], d[2])
  check(#placed >= 2, tag .. " : une deuxieme centrale tient sur l'etang (" .. #placed .. ")")
  check(#placed == 2, tag .. " : pas de troisieme (borne de l'etang seul : 2 centrales)")
  local clash = false
  for _, p in ipairs(placed) do clash = clash or p.clash end
  check(not clash, tag .. " : aucune centrale sur l'eau ni sur une autre")
  if #placed >= 2 then check(placed[1].fit.k ~= placed[2].fit.k, tag .. " : la deuxieme est sur un autre bord (rotation differente)") end
end
-- une centrale plus grosse ne tient pas a cote de la premiere : la croissance reste a une chaudiere par centrale (C.BOILERS)
for nb = 2, 3 do
  local placed = place_all({ x = 0, y = 0 }, { 1, nb })
  check(#placed == 1, "centrale de " .. nb .. " chaudieres : ne tient pas a cote de la premiere (C.BOILERS = 1 garde)")
end
local C = require("shared.team.centrale")
check(C.BOILERS == 1, "C.BOILERS = 1 : la seule taille qui tient sur l'etang a cote de la premiere")

print("== 2. Branchement dans les sources")
local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local build = read("script/team/build.lua")
local pa = read("script/team/plant_arms.lua")
local function has(src, pat, msg) check(src:find(pat, 1, true) ~= nil, msg) end
-- (Intégration 0.6.21 : l'étang garanti, Build.POND, est retiré par PD-CENTRALE, décision du DC D-24 (1) ; la géométrie de la section 1
-- reste celle d'une rive de 6 x 6 tuiles, une eau naturelle comme une autre.)
has(build, 'if p and p.state == "fini" and not p.abandoned and p.parts and p.parts[1] and p.parts[1].kind == "centrale" then return pid end',
  "plant_owner : seule une centrale FINIE et non abandonnee (site dangereux) partage sa rive")
has(build, 'local shared = l.used and l.state ~= "gisement" and states.rive and plant_owner(b, l.used) or nil',
  "candidates : la rive d'une centrale finie est candidate (states.rive seulement : aucun autre module)")
has(build, '(not l.used or l.state == "gisement" or shared)', "candidates : condition du lot pris elargie a la rive partagee")
has(build, 'k = k, shared = shared }', "candidates : le candidat porte le proprietaire de la rive")
has(build, 'if not (opts and opts.nobad) and not c.shared then c.l.bad', "place_module : un echec sur la rive partagee ne marque pas le lot")
has(build, 'shared = c.shared }', "place_module : le placement rend le proprietaire de la rive")
has(build, 'if main.shared then\n    b.lots[main.lot].used = main.shared', "plan_project : le lot reste au nom de la premiere centrale")
has(build, 'q.reopened or (q.spec and (q.spec.enceinte or q.spec.ilot or q.spec.gen == first.spec.gen))',
  "grow_plant : reparer et proteger (projets rouverts, enceinte, ilots) et les centrales restent devant")
has(build, 'front[#front + 1] = id', "grow_plant : la centrale de plus passe devant la production ordinaire")
has(pa, 'if C.after_refusal(g, refused, tick) then', "plant_arms : un refus ouvre une pause (C.after_refusal)")
has(pa, 'cool = tick < (g.cool_until or 0)', "plant_arms : la pause est lue par la regle de croissance")
has(pa, '[FO-ENERGIE] %s : bilan a %.1f min', "plant_arms : bilan [FO-ENERGIE] (production, capacite, charge, decision)")
has(pa, '[FO-ENERGIE] %s : decision : pas de centrale de plus', "plant_arms : decision negative journalisee avec sa raison")
has(build, '[FO-ENERGIE] %s : decision : centrale de %d chaudiere(s) demandee', "grow_plant : decision positive journalisee")

print("== 3. Etangs de plus (relecture : l'etang garanti ne porte que 2 centrales)")
check(C.MAX_PONDS * 2 >= C.MAX_PLANTS, "C.MAX_PONDS etangs portent C.MAX_PLANTS centrales (2 par etang)")
check(C.pond_allowed(1, "rive") == true, "1 etang releve : un etang de plus est permis")
check(C.pond_allowed(0, nil) == true, "aucun etang garanti (rive naturelle pleine) : un etang est permis")
local ok1, why1 = C.pond_allowed(1, "inconnu")
check(ok1 == false and why1 == "dernier etang pas encore releve", "dernier etang pas encore releve : pas d'autre etang (pas de rafale)")
local ok2, why2 = C.pond_allowed(C.MAX_PONDS, "rive")
check(ok2 == false and why2 == "plafond d'etangs", "plafond d'etangs : C.MAX_PONDS au plus")
check(C.pond_allowed(C.MAX_PONDS - 1, "rive") == true, "sous le plafond : permis")
-- mutant : sans garde du releve, deux etangs d'affilee
do
  local real = C.pond_allowed
  local mut = function(ponds) return (ponds or 0) < C.MAX_PONDS end
  check(mut(1, "inconnu") ~= real(1, "inconnu"), "mutant (garde du releve retiree) refuse par le test")
end
-- Intégration 0.6.21 (PD-CENTRALE, décision du DC D-24 (1) : « si l'eau n'est pas utilisable, il faut aller plus loin ») : plus
-- d'étang posé par le mod, ni garanti ni « de plus » ; une centrale de plus qui ne tient sur aucune rive du treillis va au loin
-- (Far.place). Les 6 contrôles de branchement de make_pond sont remplacés par ceux-ci ; C.pond_allowed (ci-dessus) n'a plus de lecteur.
check(build:find("local function make_pond", 1, true) == nil and build:find("set_tiles(tiles", 1, true) == nil,
  "D-24 : aucun etang pose par le mod (ni garanti, ni de plus)")
has(build, 'main, lwhy, lwait = Far.place(f, surface, g,', "une centrale (de plus comprise) sans rive dans le treillis va au loin (Far.place)")

-- aucun nom d'objet ecrit dans le code ajoute (iag_test section 8 : les noms viennent des donnees)
local added = build:match("local function plant_owner.-\nend") or ""
check(not added:find("boiler") and not added:find("steam%-engine") and not added:find("offshore"), "plant_owner : aucun nom d'objet")

print(string.format("[ENERGIE-CROISSANCE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
