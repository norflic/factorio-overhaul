--[[
  Lot QGSURVIE2 : banc HORS JEU de la ligne [FO-QG-TOURELLE] (shared/team/qg_tourelle.lua). Lancement : lua5.2 tests/qg_tourelle_test.lua
  (racine du mod). Côtés en 8 secteurs, appui (tourelles qui avaient la cause à portée), unités triées, ligne complète ; mutants.
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function read_src(path)
  local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s
end
local SRC = read_src("shared/team/qg_tourelle.lua")
local function load_q(src) return assert(load(src, "@shared.team.qg_tourelle"))() end

local function facts(Q)
  local r = {}
  r.n, r.s, r.e, r.o = Q.side(0, -10), Q.side(0, 10), Q.side(10, 0), Q.side(-10, 0)
  r.ne, r.so, r.se, r.no = Q.side(10, -10), Q.side(-10, 10), Q.side(10, 10), Q.side(-10, -10)
  r.edge_e, r.edge_ne = Q.side(1000, -414), Q.side(1000, -415)
  r.centre = Q.side(0.5, -0.5)
  local reach, armed = Q.support({ { dist = 18, range = 18, rounds = 5 }, { dist = 18.1, range = 18, rounds = 5 },
    { dist = 10, range = 18, rounds = 0 }, { dist = 5, range = 20, rounds = nil } })
  r.reach, r.armed = reach, armed
  local u, total = Q.units({ ["small-spitter"] = 3, ["small-biter"] = 2 })
  r.units, r.total = u, total
  r.none = Q.units({})
  r.line = Q.line({ minute = 47.5, team = "player", name = "gun-turret", dx = -10, dy = 10, rounds = 0, range = 18,
    cause = { name = "small-spitter", type = "unit", force = "enemy" }, damage = "acid", cause_dist = 13.2, cause_range = 13,
    support = { { dist = 12, range = 18, rounds = 4 } }, qg_left = 3, qg_armed = 2, units = { ["small-spitter"] = 4 }, wave_dx = -20, wave_dy = 25 })
  r.line_nil = Q.line({})
  return r
end

local F = facts(load_q(SRC))
check(F.n == "N" and F.s == "S" and F.e == "E" and F.o == "O", "côtés droits (y vers le bas = sud)")
check(F.ne == "NE" and F.so == "SO" and F.se == "SE" and F.no == "NO", "côtés en diagonale")
check(F.edge_e == "E" and F.edge_ne == "NE", "bord du secteur à tan(22,5°) = 0,414")
check(F.centre == "centre", "moins d'une tuile : centre")
check(F.reach == 3 and F.armed == 2, "appui : portée bord compris (18 <= 18), 18,1 hors portée ; vide non armée ; sans munitions (électrique) armée")
check(F.units == "small-biter x2, small-spitter x3" and F.total == 5 and F.none == "aucune", "unités triées par nom, total")
check(F.line:find("[FO-QG-TOURELLE] player minute 47.5 | gun-turret cote SO a 14.1 tuiles du QG", 1, true) ~= nil, "ligne : tête, côté, distance")
check(F.line:find("chargeurs restants 0 (portee 18.0) | cause small-spitter/unit/enemy, degats acid, a 13.2 tuiles (portee de son attaque 13.0)", 1, true) ~= nil,
  "ligne : chargeurs, cause, distance et portée")
check(F.line:find("tourelles qui l'avaient a portee 1 dont armees 1 | QG restant 3 tourelle(s) dont 2 armee(s)", 1, true) ~= nil, "ligne : appui et QG restant")
check(F.line:find("vague a 30 tuiles : 4 unite(s) [small-spitter x4], centre cote SO", 1, true) ~= nil, "ligne : vague")
check(F.line_nil:find("cause inconnue", 1, true) ~= nil and F.line_nil:find("chargeurs restants ?", 1, true) ~= nil
  and F.line_nil:find("centre cote -", 1, true) ~= nil, "enregistrement vide : rien ne plante, inconnus écrits")

local function mutate(old, new)
  local a, b = SRC:find(old, 1, true)
  if not a then return nil end
  return SRC:sub(1, a - 1) .. new .. SRC:sub(b + 1)
end
local mutants = {
  { "nord et sud inversés", "local ns = dy < 0 and \"N\" or \"S\"", "local ns = dy < 0 and \"S\" or \"N\"" },
  { "secteur droit trop large", "Q.TAN_1000 = 414", "Q.TAN_1000 = 600" },
  { "pas de secteur droit E/O", "if ay * 1000 <= Q.TAN_1000 * ax then return eo end", "" },
  { "portée exclusive", "if (t.dist or math.huge) <= (t.range or 0) then", "if (t.dist or math.huge) < (t.range or 0) then" },
  { "vides comptées armées", "if t.rounds == nil or t.rounds > 0 then armed = armed + 1 end", "armed = armed + 1" },
  { "électriques non armées", "if t.rounds == nil or t.rounds > 0 then armed = armed + 1 end", "if (t.rounds or 0) > 0 then armed = armed + 1 end" },
  { "unités non triées", "  table.sort(keys)\n  local parts", "  local parts" },
  { "pas de centre", "if ax < 1 and ay < 1 then return \"centre\" end", "" },
}
local killed = 0
for _, m in ipairs(mutants) do
  local txt = mutate(m[2], m[3])
  if not txt then check(false, "mutant « " .. m[1] .. " » : texte introuvable")
  else
    local ok, G = pcall(function() return facts(load_q(txt)) end)
    local same = ok
    if ok then for k, v in pairs(F) do if G[k] ~= v then same = false end end end
    if not same then killed = killed + 1 end
    check(not same, "mutant « " .. m[1] .. " » détecté")
  end
end
print(string.format("[QG-TOURELLE] mutants refusés : %d sur %d", killed, #mutants))
print(string.format("[QG-TOURELLE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
