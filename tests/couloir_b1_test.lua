--[[
  Lot ÉTAGE 5, revue B1 (2e relecture, lead 5/11 17 h 38) : remplacement SUR PLACE d'une foreuse à combustion 2×2 par une électrique 3×3
  posée sur un couloir d'accès. PUR : le texte de Build.reserved_entity est extrait de build.lua et joué avec les VRAIES emprises
  (2×2 → 3×3 : tile_width donné par un faux game.entity_prototypes) et le vrai couloir (shared/team/couloir.lua, Co.tiles).

  Exemple de la relecture : accès (40,5 ; 0,5), QG (0,5 ; 0,5) : couloir x 8 à 40, y 0 à 1. Foreuse en x 20-21, y 0-1 : la 3×3 contient
  la 2×2 et ajoute une colonne ET une rangée, donc touche (19, 0) ou (22, 0) dans ses 4 placements : 433cc88c la refusait dans les 4.

  Usage, depuis la racine du mod :
    lua5.2 tests/couloir_b1_test.lua                 (build.lua du dossier)
    lua5.2 tests/couloir_b1_test.lua <build.lua>     (autre texte : `git show 433cc88c:script/team/build.lua > x.lua` doit être ROUGE)
]]
package.path = "./?.lua;" .. package.path
local Co = require("shared.team.couloir")
local P = require("shared.team.plan")

local ok_n, bad = 0, 0
local function check(name, cond, detail)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[COULOIR-B1] ECHEC : " .. name .. (detail and (" (" .. detail .. ")") or "")) end
end

local function read(p)
  local h = assert(io.open(p, "rb"))
  local s = h:read("*a")
  h:close()
  return s
end
local BUILD_PATH = arg[1] or "script/team/build.lua"
local B = read(BUILD_PATH)
local CO_SRC = read("shared/team/couloir.lua")

-- Build.reserved_entity extrait du texte (fonction entière, jusqu'au premier « end » en colonne 0)
local function reserved_from(text, co)
  local a = text:find("function Build.reserved_entity(f, name, pos, dir, opts)", 1, true)
  if not a then return nil, "fonction introuvable" end
  local z = text:find("\nend\n", a, true)
  local body = text:sub(a, z + 4)
  local Build = { NO_COULOIR = {}, Co = co }
  local env = setmetatable({ Build = Build, P = P, NO_COULOIR = Build.NO_COULOIR, next = next, math = math, game = {
    entity_prototypes = {
      ["burner-mining-drill"] = { tile_width = 2, tile_height = 2 },
      ["electric-mining-drill"] = { tile_width = 3, tile_height = 3 },
    } } }, { __index = _G })
  local fn, err = load(body, "=reserved_entity", "t", env)
  if not fn then return nil, err end
  fn()
  return Build
end

-- couloir de l'exemple, au format de Build.couloirs : { [P.tkey] = id }
local function corridor(ax, ay, hx, hy)
  local set = {}
  for _, t in ipairs(Co.tiles(ax, ay, hx, hy)) do set[P.tkey(t.x, t.y)] = 7 end
  return set
end
-- ancienne emprise d'une foreuse 2×2 centrée en (x, y), calculée comme script/team/foreuse_swap.lua (boîte ±0,7)
local function keep_of(x, y)
  local l, t, r, b = x - 0.7, y - 0.7, x + 0.7, y + 0.7
  return { math.floor(l + 0.01), math.floor(t + 0.01), math.ceil(r - 0.01) - 1, math.ceil(b - 0.01) - 1 }
end
-- les 4 placements 3×3 qui contiennent la 2×2 centrée en (x, y) : centres (x ± 0,5, y ± 0,5)
local function placements(x, y)
  return { { x = x - 0.5, y = y - 0.5 }, { x = x + 0.5, y = y - 0.5 }, { x = x - 0.5, y = y + 0.5 }, { x = x + 0.5, y = y + 0.5 } }
end

local function suite(Build)
  local res = {}
  local function c(name, cond, detail) res[#res + 1] = { name, cond and true or false, detail } end
  local set = corridor(40.5, 0.5, 0.5, 0.5)
  c("couloir de l'exemple : x 8 a 40, y 0 a 1", set[P.tkey(8, 0)] and set[P.tkey(40, 1)] and set[P.tkey(20, 0)] and set[P.tkey(20, 1)]
    and not set[P.tkey(7, 0)] and not set[P.tkey(20, 2)] and not set[P.tkey(20, -1)])
  local f = { key = "f1", stats = {} }
  Build.couloirs = function() return set end
  local function refuse(pos, opts) return Build.reserved_entity(f, "electric-mining-drill", pos, 0, opts) end
  local function count(cx, cy, opts)
    local n = 0
    for _, p in ipairs(placements(cx, cy)) do if refuse(p, opts) then n = n + 1 end end
    return n
  end
  -- A. l'exemple : la 2×2 ferme déjà la section ; la 3×3 ne fait pas pire : les 4 placements passent
  local kA = keep_of(21, 1)
  c("A : ancienne emprise x 20-21, y 0-1", kA[1] == 20 and kA[2] == 0 and kA[3] == 21 and kA[4] == 1, table.concat(kA, ","))
  local nA = count(21, 1, { keep = kA })
  c("A : foreuse sur une partie droite : remplacee dans les 4 placements", nA == 0, nA .. " refus sur 4")
  -- A bis : mêmes placements avec un bâtiment voisin (la section est fermée de toute façon) : passe aussi
  local nA2 = count(21, 1, { keep = kA, blocked = function(x, y) return x == 24 and (y == 0 or y == 1) end })
  c("A bis : voisin a 2 tuiles, section deja fermee : passe", nA2 == 0, nA2 .. " refus sur 4")
  -- B. ancienne emprise sur UNE rangée du couloir (y 1-2) : la 3×3 en y 0-2 ferme la rangée 0 restée libre : refus ; en y 1-3 : passe
  local kB = keep_of(21, 2)
  c("B : ancienne emprise x 20-21, y 1-2", kB[2] == 1 and kB[4] == 2, table.concat(kB, ","))
  c("B : la 3x3 ferme la derniere rangee libre (y 0-2, a gauche) : refus", refuse({ x = 20.5, y = 1.5 }, { keep = kB }) == true)
  c("B : la 3x3 ferme la derniere rangee libre (y 0-2, a droite) : refus", refuse({ x = 21.5, y = 1.5 }, { keep = kB }) == true)
  c("B : la 3x3 en y 1-3 ne fait que garder la rangee 1 : passe", refuse({ x = 20.5, y = 2.5 }, { keep = kB }) == false
    and refuse({ x = 21.5, y = 2.5 }, { keep = kB }) == false)
  -- C. ancienne emprise hors du couloir (y 2-3) : la 3×3 en y 1-3 rétrécit le couloir (rangée 0 libre) : passe ; si un voisin
  -- tient la rangée 0 au même endroit, elle le ferme : refus
  local kC = keep_of(21, 3)
  c("C : retrecir le couloir d'une rangee : passe", refuse({ x = 20.5, y = 2.5 }, { keep = kC }) == false)
  c("C : retrecir face a un voisin qui tient l'autre rangee : refus",
    refuse({ x = 20.5, y = 2.5 }, { keep = kC, blocked = function(x, y) return y == 0 and x >= 19 and x <= 21 end }) == true)
  c("C : voisin decale (plus de face a face) : passe",
    refuse({ x = 20.5, y = 2.5 }, { keep = kC, blocked = function(x, y) return y == 0 and x >= 24 and x <= 25 end }) == false)
  -- C ter : voisin en quinconce (coin contre coin avec la 3×3) : un PNJ ne passe pas en diagonale entre deux boîtes (4-connexité)
  c("C : voisin en quinconce, coin contre coin : refus",
    refuse({ x = 20.5, y = 2.5 }, { keep = kC, blocked = function(x, y) return y == 0 and (x == 22 or x == 23) end }) == true)
  -- D. pose NEUVE (sans keep) sur le couloir : toujours refusée (agrandissements, tourelles : lecteur 1 inchangé)
  c("D : pose neuve sur le couloir : refus", refuse({ x = 30.5, y = 1.5 }) == true)
  c("D : pose neuve a cote du couloir : passe", refuse({ x = 30.5, y = 4.5 }) == false)
  c("D : pose neuve qui ne fait que retrecir : refus (les poses neuves gardent les 2 rangees)", refuse({ x = 30.5, y = 2.5 }) == true)
  -- E. au bout du couloir côté QG (x 8) : la 3×3 en x 7-9 ne sépare rien (le bout disparaît) : passe
  c("E : bout du couloir : passe", refuse({ x = 8.5, y = 0.5 }, { keep = keep_of(9, 1) }) == false)
  -- F. B2 inchangé : adoption (couloir = false) jamais refusée par le couloir
  c("F : adoption hors couloir", refuse({ x = 30.5, y = 1.5 }, { couloir = false }) == false)
  -- G. couloir en COUDE (relecture du lead : fenêtre de 2 tuiles face à un coude). Accès (20,5 ; 30,5), QG (0,5 ; 0,5) : axe y d'abord,
  -- colonnes 19-20 de y 30 à 0, puis rangées 0 et -1 de x 19 à 15 ; la tuile (19, 0) est le coin.
  local setG = corridor(20.5, 30.5, 0.5, 0.5)
  c("G : couloir en coude (colonnes 19-20, rangees -1/0, coin (19,0))", setG[P.tkey(20, 0)] and setG[P.tkey(19, 0)] and setG[P.tkey(19, -1)]
    and setG[P.tkey(15, -1)] and setG[P.tkey(20, 30)] and not setG[P.tkey(20, -1)] and not setG[P.tkey(21, 5)])
  Build.couloirs = function() return setG end
  c("G : section deja fermee par la 2x2 au pied du coude : la 3x3 qui prend le coin passe",
    refuse({ x = 19.5, y = 1.5 }, { keep = keep_of(20, 2) }) == false)
  c("G : 2x2 hors du couloir, la 3x3 retrecit la colonne 20 au coude : passe", refuse({ x = 21.5, y = 1.5 }, { keep = keep_of(22, 2) }) == false)
  c("G : meme retrecissement face a un rocher sur la colonne 19 : refus",
    refuse({ x = 21.5, y = 1.5 }, { keep = keep_of(22, 2), blocked = function(x, y) return x == 19 and y == 1 end }) == true)
  c("G : la 3x3 prend le coin (19,0) : la colonne 20 ne rejoint plus les rangees du coude (diagonale seule) : refus",
    refuse({ x = 18.5, y = 1.5 }, { keep = keep_of(18, 2) }) == true)
  return res
end

local function run(text, co)
  local Build, err = reserved_from(text, co)
  if not Build then return { { "extraction de reserved_entity : " .. tostring(err), false } } end
  local okr, res = pcall(suite, Build)
  if not okr then return { { "suite : " .. tostring(res), false } } end
  return res
end

for _, r in ipairs(run(B, Co)) do check(r[1], r[2], r[3]) end

if arg[1] then
  print(string.format("[COULOIR-B1] (texte %s) BILAN : %d OK, %d ECHEC(S)", BUILD_PATH, ok_n, bad))
  os.exit(bad == 0 and 0 or 1)
end

-- Pureté de la règle : Co.cuts ne lit que has/blocked (aucune API du moteur)
check("Co.cuts present et pur", type(Co.cuts) == "function" and not CO_SRC:find("game%.") and not CO_SRC:find("surface"))
-- Câblage : foreuse_swap passe l'ancienne emprise ET les voisins
local FS = read("script/team/foreuse_swap.lua")
check("foreuse_swap passe keep et blocked (toutes forces, rochers, falaises, eau ; ni l'ancienne foreuse ni ce qui bouge)",
  FS:find("{ keep = keep, blocked = blocked }", 1, true) ~= nil
  and FS:find('surface.find_entities_filtered({ area = area, collision_mask = "player-layer" })', 1, true) ~= nil
  and FS:find('surface.find_tiles_filtered({ area = area, collision_mask = "player-layer" })', 1, true) ~= nil
  and FS:find("e ~= d and not MOVING[e.type]", 1, true) ~= nil)

-- Mutants : de la règle (couloir.lua) et de build.lua ; chacun doit faire échouer la suite
local function load_co(src)
  local fn = load(src, "=couloir", "t", setmetatable({ require = require }, { __index = _G }))
  if not fn then return nil end
  local okc, mod = pcall(fn)
  return okc and mod or nil
end
local MUT = {
  { "co", "cuts : separation jamais vue", "elseif map[a] ~= b then return true end", "elseif false then return true end" },
  { "co", "cuts : voisins ignores", "return has(x, y) and not (blocked and blocked(x, y))", "return has(x, y)" },
  { "co", "cuts : fenetre sans marge", "local m = Co.WIDTH", "local m = 0" },
  { "co", "cuts : ancienne et nouvelle inversees", "local lo, ln = label(old), label(new)", "local lo, ln = label(new), label(old)" },
  { "co", "cuts : 8-connexite", "local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }", "local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 } }" },
  { "b", "B1 : coupe ignoree (tout couloir refuse, 433cc88c sans keep)", "  if by_cor and keep then by_cor = Build.Co.cuts(", "  if false then by_cor = Build.Co.cuts(" },
  { "b", "B1 : voisins non transmis", "{ x0, y0, x0 + w - 1, y0 + h - 1 }, opts.blocked) end", "{ x0, y0, x0 + w - 1, y0 + h - 1 }, nil) end" },
  { "b", "B1 : coupe pour toute pose (keep ignore)", "  if by_cor and keep then by_cor = Build.Co.cuts(function(x, y) return cor[P.tkey(x, y)] ~= nil end, keep,",
    "  if by_cor then by_cor = Build.Co.cuts(function(x, y) return cor[P.tkey(x, y)] ~= nil end, keep or { x0, y0, x0 - 1, y0 - 1 }," },
}
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local src = m[1] == "co" and CO_SRC or B
  local a, z = src:find(m[3], 1, true)
  if not a then
    kept[#kept + 1] = m[2] .. " (motif introuvable)"
  else
    local mut = src:sub(1, a - 1) .. m[4] .. src:sub(z + 1)
    local res
    if m[1] == "co" then
      local mco = load_co(mut)
      res = mco and run(B, mco) or { { "regle illisible", false } }
    else
      res = run(mut, Co)
    end
    local seen = false
    for _, r in ipairs(res) do if not r[2] then seen = true break end end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[2] end
  end
end
check(string.format("mutants refuses %d/%d%s", refused, #MUT, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUT)
print(string.format("[COULOIR-B1] mutants refuses %d/%d", refused, #MUT))
print(string.format("[COULOIR-B1] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
