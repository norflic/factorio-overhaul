--[[
  Lot PETROLE 2 : ligne de poteaux qui CONTOURNE les obstacles (shared/ai3/fluides.lua, Fl.pole_route et pas des relais).
  Défaut vu en moteur réel (28/10, etape1-guide 271828182) : « ligne de poteaux jusqu'au reseau impossible » refusait, 4 fois
  de suite, le site des moteurs près du QG de la faction (relais en ligne droite, 4 tuiles de côté au plus : une falaise ou
  un bâtiment sur la ligne la coupait). Le relais cherche toujours la ligne droite d'abord (résultat inchangé quand elle
  passe), puis A* sur les tuiles libres.
    §1 terrain libre : saut de `wire` tuiles au plus, dernier relais à portée de la cible, peu de relais ;
    §2 mur avec une brèche : la ligne passe par la brèche, aucun relais sur une tuile bloquée ;
    §3 enclos fermé : aucun chemin (nil) dans le budget de nœuds ;
    §4 déterminisme ; §5 pas valides pour plusieurs portées de fil ;
    §6 MUTANTS du contrôle : le contrôle refuse un chemin qui traverse le mur, un saut trop long, une ligne qui ne finit pas
       à portée, une absence de chemin et un A* aveugle aux obstacles ; budget de nœuds nul.
  (L'intégration dans Fl.layout, avec un mur entre le site et le réseau, est dans tests/petrole_test.lua §4c.)
  Lancement : lua5.2 tests/petrole_poteaux_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local Fl = require("shared.ai3.fluides")

local pass, fail = 0, 0
local function check(c, msg)
  if c then pass = pass + 1 else fail = fail + 1; print("[PETROLE-POTEAUX] ECHEC : " .. msg) end
end
local function say(s) print("[PETROLE-POTEAUX] " .. s) end

--- Contrôle d'une ligne : chaque saut ≤ wire, aucun relais sur une tuile bloquée, dernier relais à portée de b.
--- Rend ok, raison.
local function verify(a, b, path, wire, blocked)
  if not path then return false, "aucun chemin" end
  local prev = a
  for i, p in ipairs(path) do
    if (p.x - prev.x) ^ 2 + (p.y - prev.y) ^ 2 > wire * wire + 1e-9 then return false, "saut trop long au relais " .. i end
    if blocked(math.floor(p.x), math.floor(p.y)) then return false, "relais " .. i .. " sur une tuile bloquée" end
    prev = p
  end
  if (b.x - prev.x) ^ 2 + (b.y - prev.y) ^ 2 > wire * wire + 1e-9 then return false, "le dernier relais n'est pas à portée" end
  return true
end

local function free_of(blocked) return function(tx, ty) return not blocked(tx, ty) end end

-- §1 terrain libre
local A, B = { x = 0.5, y = 0.5 }, { x = 100.5, y = 0.5 }
local none = function() return false end
for _, wire in ipairs({ 7.5, 9 }) do
  local path = Fl.pole_route(A, B, wire, free_of(none), 6000)
  local ok, why = verify(A, B, path, wire, none)
  check(ok, "§1 terrain libre, fil " .. wire .. " : " .. tostring(why))
  local minimum = math.ceil(100 / math.floor(wire)) - 1 -- pas entiers : 7 tuiles au plus pour un fil de 7,5
  check(path and #path <= minimum + 2, string.format("§1 fil %s : %d relais (minimum %d)", wire, path and #path or -1, minimum))
  say(string.format("§1 fil %s : %d relais", wire, path and #path or -1))
end
check(#(Fl.pole_route(A, { x = 5.5, y = 0.5 }, 9, free_of(none), 10) or { 1 }) == 0, "§1 déjà à portée : aucun relais")

-- §2 mur épais (12 tuiles : un fil de 9 ne l'enjambe pas) en x = 44 .. 56, y de -80 à 80, avec une brèche en y = 40 .. 42
local function wall(tx, ty) return tx >= 44 and tx <= 56 and ty >= -80 and ty <= 80 and not (ty >= 40 and ty <= 42) end
local pw = Fl.pole_route(A, B, 9, free_of(wall), 6000)
local okw, whyw = verify(A, B, pw, 9, wall)
check(okw, "§2 mur à brèche : " .. tostring(whyw))
local through = false
for _, p in ipairs(pw or {}) do if p.y > 30 then through = true end end
check(through, "§2 la ligne passe par la brèche (y > 30)")
say(string.format("§2 mur à brèche : %d relais", pw and #pw or -1))
-- un mur étroit : un saut l'enjambe (un fil passe par-dessus) ; seuls les relais comptent, jamais sur une tuile bloquée
local slim = function(tx, ty) return tx == 50 and ty >= -2 and ty <= 2 end
local ps = Fl.pole_route(A, B, 9, free_of(slim), 6000)
check(select(1, verify(A, B, ps, 9, slim)), "§2 mur étroit : un saut l'enjambe, aucun relais dessus")

-- §3 enclos fermé autour de la cible : aucun chemin
local box = function(tx, ty)
  local dx, dy = tx - 100, ty
  local r = math.max(math.abs(dx), math.abs(dy))
  return r >= 10 and r <= 22 -- anneau de 13 tuiles : un fil de 9 ne l'enjambe pas
end
local t0 = os.clock()
local pb = Fl.pole_route(A, B, 9, free_of(box), 2500)
check(pb == nil, "§3 enclos fermé : aucun chemin")
say(string.format("§3 enclos : refus en %.3f s (2500 noeuds)", os.clock() - t0))

-- §4 déterminisme
local p1 = Fl.pole_route(A, B, 9, free_of(wall), 6000)
local p2 = Fl.pole_route(A, B, 9, free_of(wall), 6000)
local same = p1 and p2 and #p1 == #p2
if same then for i, p in ipairs(p1) do if p.x ~= p2[i].x or p.y ~= p2[i].y then same = false end end end
check(same, "§4 deux routes identiques")

-- §5 les décalages de cellules respectent la portée
for _, wire in ipairs({ 5, 7.5, 9, 30 }) do
  local ok = true
  for _, st in ipairs(Fl.pole_cells(wire)) do if Fl.POLE_CELL * math.sqrt(st[1] * st[1] + st[2] * st[2]) > wire + 2 then ok = false end end
  check(ok and #Fl.pole_cells(wire) > 8, "§5 décalages de cellules à portée pour un fil de " .. wire)
end

-- §6 mutants du CONTRÔLE : chaque défaut doit être refusé par `verify`
local straight_through = { { x = 25.5, y = 0.5 }, { x = 50.5, y = 0.5 }, { x = 75.5, y = 0.5 }, { x = 91.5, y = 0.5 } }
check(verify(A, B, straight_through, 30, wall) == false, "§6 mutant : chemin qui traverse le mur refusé")
check(verify(A, B, { { x = 20.5, y = 0.5 } }, 9, none) == false, "§6 mutant : saut trop long refusé")
check(verify(A, B, { { x = 8.5, y = 0.5 }, { x = 16.5, y = 0.5 } }, 9, none) == false, "§6 mutant : ligne qui ne finit pas à portée refusée")
check(verify(A, B, nil, 9, none) == false, "§6 mutant : absence de chemin refusée")
check(Fl.pole_route(A, B, 9, free_of(none), 0) == nil, "§6 mutant : budget de nœuds nul : aucun chemin")
-- un A* qui ignorerait les obstacles serait pris par le contrôle
local blind = Fl.pole_route(A, B, 9, function() return true end, 6000)
check(verify(A, B, blind, 9, wall) == false, "§6 mutant : A* aveugle aux obstacles refusé par le contrôle")

-- §7 zones interdites (abords des menaces connues) : la ligne les contourne
do
  local set = Fl.disc_tiles({ { x = 50.5, y = 0.5, r = 10 } })
  check(set ~= nil and set[Fl.tkey(50, 0)] and set[Fl.tkey(55, 5)] and not set[Fl.tkey(62, 0)] and not set[Fl.tkey(50, 12)],
    "§7 disque : le centre et l'intérieur interdits, l'extérieur libre")
  check(Fl.disc_tiles({}) == nil and Fl.disc_tiles(nil) == nil, "§7 aucune menace : rien d'interdit")
  local zone = function(tx, ty) return set[Fl.tkey(tx, ty)] == true end
  local pz = Fl.pole_route(A, B, 9, free_of(zone), 6000)
  local okz, whyz = verify(A, B, pz, 9, zone)
  check(okz, "§7 la ligne contourne la zone interdite : " .. tostring(whyz))
  local detour = false
  for _, p in ipairs(pz or {}) do if math.abs(p.y) > 6 then detour = true end end
  check(detour, "§7 la ligne s'écarte de l'axe (elle passe à côté du disque)")
  -- mutant : une ligne qui traverse la zone est refusée par le contrôle
  local straight = { { x = 20.5, y = 0.5 }, { x = 40.5, y = 0.5 }, { x = 50.5, y = 0.5 }, { x = 60.5, y = 0.5 }, { x = 80.5, y = 0.5 } }
  check(verify(A, B, straight, 30, zone) == false, "§7 mutant : un relais dans la zone interdite est refusé")
end

print(string.format("[PETROLE-POTEAUX] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
