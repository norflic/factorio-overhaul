-- Lot FIX-P4 : quatre failles d'audit (débit des foreuses en arrivée latérale, quai de repli refusé, voie 2 d'un port à un seul
-- minerai, tapis rapide au stock plus court que le tracé). Règles pures + branchements lus dans le source. lua5.2 tests/fix_p4_test.lua
package.path = "./?.lua;" .. package.path
local Db = require("shared.team.debit")
local P = require("shared.team.plan")
local C = require("shared.team.convoyeurs")

local ok, ko = 0, 0
local function check(c, msg)
  if c then ok = ok + 1 else ko = ko + 1; print("ECHEC : " .. msg) end
end
local function read(path)
  local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s
end
local build = read("script/team/build.lua")
local function body(src, head)
  local s = src:find(head, 1, true); if not s then return "" end
  local e = src:find("\nfunction ", s + 1, true) or src:find("\nlocal function ", s + 1, true) or #src
  return src:sub(s, e)
end

-- 1. Arrivée latérale : la ligne ne porte que la moitié des paires
check(P.FEEDER_SIDE_LOAD == true, "faille 1 : la tete recoit le tapis des foreuses par le cote")
check(Db.head_pairs(15, true) == 7, "faille 1 : 15 par voie, arrivee laterale : 7 paires")
check(Db.head_pairs(14, true) == 7, "faille 1 : 14 -> 7")
check(Db.head_pairs(15, false) == 15, "faille 1 : arrivee de face : inchange")
check(Db.head_pairs(1, true) == 1, "faille 1 : au moins une paire")
check(Db.head_pairs(0, true) == 0, "faille 1 : aucun tapis lisible : 0")
for _, sp in ipairs({ 0.03125, 0.0625, 0.09375 }) do
  for _, dr in ipairs({ 0.25, 0.5, 0.75 }) do
    local lane = Db.lane_capacity(sp)
    local np = Db.head_pairs(Db.belt_pairs(lane, dr, nil), true)
    check(2 * np * dr <= lane + 1e-9, string.format("faille 1 : %d paires x2 a %.2f/s tiennent sur UNE voie de %.1f/s", np, dr, lane))
  end
end
local dp = body(build, "function Build.debit_pairs(")
check(dp:find("Db.head_pairs(by_belt, lateral)", 1, true) ~= nil, "faille 1 : Build.debit_pairs borne par Db.head_pairs")
check(build:find("Build.debit_pairs(f, prm.ore, pairs_line, dsp.speed, P.FEEDER_SIDE_LOAD)", 1, true) ~= nil, "faille 1 : line_rows passe l'arrivee laterale")

-- 2. Quai de repli refusé : l'échec remonte
check(build:find('if not reserve_tiles(b, p, extra) then return false, "quai de repli : tuiles prises" end', 1, true) ~= nil,
  "faille 2 : quai de repli refuse -> return false")
check(build:find("if reserve_tiles(b, p, extra) then", 1, true) == nil, "faille 2 : plus de repli silencieux")

-- 3. Port à un seul minerai : la voie 2 est sourcée au-delà d'une voie
local s1 = Db.lane_split(5, 7.5)
check(#s1 == 1 and s1[1] == 5 and s1[2] == nil, "faille 3 : 5/s sur une voie de 7,5 : voie 1 seule")
local s2 = Db.lane_split(10, 7.5)
check(s2[1] == 5 and s2[2] == 5, "faille 3 : 10/s > 7,5 : deux voies de 5/s")
local s3 = Db.lane_split(7.5, 7.5)
check(s3[2] == nil and s3[1] == 7.5, "faille 3 : au seuil exact : une voie")
check(Db.lane_split(10, 0)[2] == nil, "faille 3 : voie illisible : comportement d'avant")
check(build:find("split = Db.lane_split(all, Db.lane_capacity(sp))", 1, true) ~= nil, "faille 3 : plan_feed lit Db.lane_split")
check(build:find("if item and not (split and not split[lane]) then", 1, true) ~= nil, "faille 3 : la voie 2 est sourcee si split[2]")
check(build:find("local flow = split and split[lane] or", 1, true) ~= nil, "faille 3 : chaque voie porte sa moitie")

-- 4. Tapis rapide au stock : il doit couvrir le tracé
local bl = { { name = "a", speed = 1, item = "ia" }, { name = "b", speed = 2, item = "ib" }, { name = "c", speed = 3, item = "ic" } }
local all = function() return true end
local function cnt(t) return function(i) return t[i] or 0 end end
check(C.stocked(bl, all, cnt({ ic = 30 }), 24, 50) == nil, "faille 4 : 30 au stock, trace de 50 : pas pris")
check(C.stocked(bl, all, cnt({ ic = 30, ib = 60 }), 24, 50) == "b", "faille 4 : le plus rapide qui couvre le trace (b)")
check(C.stocked(bl, all, cnt({ ic = 50 }), 24, 50) == "c", "faille 4 : au seuil exact de la longueur")
check(C.stocked(bl, all, cnt({ ic = 24 }), 24, 10) == "c", "faille 4 : trace court : NEW_MIN reste le plancher")
check(C.stocked(bl, all, cnt({ ic = 23 }), 24, 10) == nil, "faille 4 : sous NEW_MIN : nil")
check(C.stocked(bl, all, cnt({ ic = 24 }), 24) == "c", "faille 4 : sans longueur : comportement d'avant")
local conv = read("script/team/convoyeurs.lua")
check(conv:find("function Conv.choose(f, flow, len)", 1, true) ~= nil and conv:find("Conv.NEW_MIN, len)", 1, true) ~= nil,
  "faille 4 : Conv.choose passe la longueur")
check(build:find("head_belt = Conv.choose(f, top, len)", 1, true) ~= nil, "faille 4 : la tete passe la distance du gisement")

print(string.format("fix_p4_test : %d ok, %d echec(s)", ok, ko))
if ko > 0 then os.exit(1) end
