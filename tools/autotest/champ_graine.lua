--[[
  Lot FOREUSES-THERMIQUES, point (A) : analyse HORS JEU du relevé du micro-banc foreuses-graine-dc (carte du DC, graine 464616505).
  Lit les lignes « [FO-GRAINE-DC] R <ressource> <y> <intervalles> » d'un journal, reconstruit le gisement de fer de l'avant-poste 1 comme le
  fait script/team/champ.lua (ore_tiles : rayon 96 autour de (−16, −95), composante de shared/team/pose_paires.lua), les autres ressources
  minables autour (lot MELANGE), puis joue la règle pure du champ (shared/team/champ.lua, Ch.plan) dans quatre états :
    1. minerai seul ;
    2. minerai + autres ressources (MELANGE) ;
    3. minerai + couloir d'accès (2 tuiles de large, de l'accès vers le QG : Co.tiles de shared/team/couloir.lua) ;
    4. minerai + autres ressources + couloir.
  Le cas « 0 bande » du DC (40,7 min) doit tomber dans l'un d'eux : la cause est alors celle qui fait passer de « des bandes » à 0.
  Les données du champ (foreuse 3 × 3 de portée 1, cadence 0,5/s ; poteau moyen ; tapis jaune ; four en pierre) sont celles de la partie
  du DC à 40 min (CHAMP_DATA ci-dessous) ; la fonderie en colonne et sa ligne de charbon ne sont PAS jouées (fonderie à coffres) : écart connu.
  Usage, depuis la racine du mod :  lua5.2 tools/autotest/champ_graine.lua <benchmark.log> [ax ay hx hy]
    (ax, ay) : accès de l'avant-poste 1 (défaut : (−16, −95), centre de ses paires, inconnu au journal du DC) ; (hx, hy) : QG (défaut (0, 0)).
]]
package.path = "./?.lua;" .. package.path
local Ch = require("shared.team.champ")
local Pa = require("shared.team.pose_paires")
local Co = require("shared.team.couloir")

local path = arg[1]
if not path then print("usage : lua5.2 tools/autotest/champ_graine.lua <benchmark.log> [ax ay hx hy]") os.exit(2) end
local ax, ay = tonumber(arg[2]) or -16, tonumber(arg[3]) or -95
local hx, hy = tonumber(arg[4]) or 0, tonumber(arg[5]) or 0
local CENTER = { x = -16, y = -95 }
local RES = "iron-ore"
local NOT_MINABLE = { ["crude-oil"] = true }

local by = {}
local nlines = 0
for line in io.lines(path) do
  local name, y, parts = line:match("%[FO%-GRAINE%-DC%] R (%S+) (%-?%d+) (%S+)")
  if name then
    nlines = nlines + 1
    by[name] = by[name] or {}
    for seg in parts:gmatch("[^,]+") do
      local a, b = seg:match("^(%-?%d+)%-(%-?%d+)$")
      a, b = tonumber(a or seg), tonumber(b or seg)
      for x = a, b do by[name][#by[name] + 1] = { x = x, y = tonumber(y) } end
    end
  end
end
if nlines == 0 then print("[CHAMP-GRAINE] aucune ligne [FO-GRAINE-DC] R dans " .. path) os.exit(1) end

-- gisement de fer de l'avant-poste 1 : rayon 96 autour du centre, composante (Pa.GAP) depuis la tuile la plus proche
local raw = {}
for _, t in ipairs(by[RES] or {}) do
  if (t.x + 0.5 - CENTER.x) ^ 2 + (t.y + 0.5 - CENTER.y) ^ 2 <= 96 * 96 then raw[#raw + 1] = { x = t.x + 0.5, y = t.y + 0.5 } end
end
local comp = Pa.component(Pa.sorted(raw, CENTER), Pa.GAP, CENTER)
local ore = {}
local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
for _, t in ipairs(comp) do
  local x, y = math.floor(t.x), math.floor(t.y)
  ore[#ore + 1] = x; ore[#ore + 1] = y
  x0, x1, y0, y1 = math.min(x0, x), math.max(x1, x), math.min(y0, y), math.max(y1, y)
end
-- autres ressources minables dans la boîte du gisement élargie de 6 (côté + 2 × portée + 1, comme champ.lua)
local foreign, nforeign = {}, 0
local names = {}
for n in pairs(by) do names[#names + 1] = n end
table.sort(names)
local fcount = {}
for _, n in ipairs(names) do
  if n ~= RES and not NOT_MINABLE[n] then
    for _, t in ipairs(by[n]) do
      if t.x >= x0 - 6 and t.x <= x1 + 6 and t.y >= y0 - 6 and t.y <= y1 + 6 then
        local k = Ch.key(t.x, t.y)
        if not foreign[k] then foreign[k] = true; nforeign = nforeign + 1; fcount[n] = (fcount[n] or 0) + 1 end
      end
    end
  end
end
local fl = {}
for _, n in ipairs(names) do if fcount[n] then fl[#fl + 1] = n .. " " .. fcount[n] end end
print(string.format("[CHAMP-GRAINE] gisement de fer : %d tuiles (DC : 2 750), boite x %d..%d y %d..%d ; autres ressources autour : %d (DC : 1 970) : %s",
  #ore / 2, x0, x1, y0, y1, nforeign, table.concat(fl, ", ")))

local cor = {}
for _, t in ipairs(Co.tiles(ax + 0.5, ay + 0.5, hx + 0.5, hy + 0.5)) do cor[Ch.key(t.x, t.y)] = true end

local CHAMP_DATA = { drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 3, wire = 9 }, belts = { { lane = 7.5 } },
  furnace = { size = 2, rate = 0.3125, fuel = true }, inserter = { rate = 0.83 } }
local function plan(name, blocked, fgn)
  local p, why = Ch.plan({ ore = ore, blocked = blocked, foreign = fgn, drill = CHAMP_DATA.drill, pole = CHAMP_DATA.pole,
    belts = CHAMP_DATA.belts, furnace = CHAMP_DATA.furnace, inserter = CHAMP_DATA.inserter, target = { x = hx, y = hy } })
  if not p then
    print(string.format("[CHAMP-GRAINE] %-34s : pas de plan (%s)", name, tostring(why)))
    return 0
  end
  local nb = 0
  for _, b in ipairs(p.bands) do if #b.groups > 0 then nb = nb + 1 end end
  print(string.format("[CHAMP-GRAINE] %-34s : axe %s, %d bande(s), %d foreuses", name, p.axis, nb, p.stats.drills))
  return nb
end
local a = plan("1. minerai seul", {}, nil)
local b = plan("2. + autres ressources (MELANGE)", {}, foreign)
local c = plan("3. + couloir d'acces", cor, nil)
local d = plan("4. + autres ressources + couloir", cor, foreign)
print(string.format("[CHAMP-GRAINE] RESULTAT minerai=%d melange=%d couloir=%d les_deux=%d", a, b, c, d))
