--[[
  Lot PERIMETRE2 (diagnostic) : banc HORS JEU de shared/team/perte.lua (mesure des pertes et de la couverture, lecture seule).
  Lancement : lua5.2 tests/perte_test.lua (racine du mod). Catégories, sites, côtés, manque, couverture, isolées, cumul et résumé ; mutants.
]]
package.path = "./?.lua;" .. package.path
local function read_src(path) local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s end
local SRC = read_src("shared/team/perte.lua")
local function load_pa(src) return assert(load(src, "@shared.team.perte"))() end

local function suite(Pa)
  local fails, n = {}, 0
  local function check(c, m) n = n + 1 if not c then fails[#fails + 1] = m end end
  check(Pa.category("container", "logistique", true) == "qg" and Pa.category("furnace", "fabrique") == "fonderie"
    and Pa.category("assembling-machine", "fabrique") == "assembleur" and Pa.category("boiler", "chauffe") == "centrale"
    and Pa.category("generator", "generateur") == "centrale" and Pa.category("offshore-pump", "pompe") == "centrale"
    and Pa.category("mining-drill", "foreuse") == "foreuse" and Pa.category("lab", "labo") == "labo", "catégories des bâtiments sensibles")
  check(Pa.category("wall", "militaire") == "mur" and Pa.category("ammo-turret", "militaire") == "tourelle"
    and Pa.category("transport-belt", "logistique") == "logistique" and Pa.category("radar", nil) == "autre", "catégories des autres")
  check(Pa.sensible("fonderie") and Pa.sensible("qg") and not Pa.sensible("tourelle") and not Pa.sensible("logistique"), "sensibles")
  check(Pa.site(40, 10, 3) == "qg" and Pa.site(41, 40, 3) == "ap3" and Pa.site(41, 41, 3) == "base" and Pa.site(193, 100, 3) == "loin"
    and Pa.site(100, nil, nil) == "base", "sites (bords compris)")
  check(Pa.side(0, -10) == "N" and Pa.side(10, 10) == "SE" and Pa.side(-1000, 414) == "O" and Pa.side(-1000, 415) == "SO"
    and Pa.side(0.5, 0.5) == "centre", "côtés en 8 secteurs")
  check(Pa.lack(0, 0, 50) == "a" and Pa.lack(2, 0, 0) == "b" and Pa.lack(3, 2, 10) == "c" and Pa.lack(3, 2, 9) == "d", "manque a, b, c, d")
  local cov = Pa.coverage({ { x = 0, y = 0, role = "qg" }, { x = 30, y = 0, role = "fabrique" }, { x = 60, y = 0, role = "foreuse" },
    { x = 90, y = 0, role = "logistique" } }, { { x = 0, y = 14.4, range = 18, armed = true }, { x = 60, y = 5, range = 18, armed = false } })
  check(cov.w == 24 and cov.wc == 20 and cov.n == 3 and cov.nc == 1, "couverture armée (bord compris, vide exclue, logistique hors compte)")
  check(Pa.isolated({ { x = 0, y = 0, range = 18 }, { x = 18, y = 0, range = 18 }, { x = 100, y = 0, range = 18 } }) == 1, "isolées")
  local agg
  agg = Pa.add(agg, { cat = "fonderie", site = "ap2", side = "N", killer = "mordeur", lack = "a", wall = false })
  agg = Pa.add(agg, { cat = "fonderie", site = "base", side = "N", killer = "cracheur", lack = "c", wall = true })
  agg = Pa.add(agg, { cat = "tourelle", site = "qg", side = "E", killer = "cracheur" })
  check(agg.n == 3 and agg.sens == 2 and agg.cat.fonderie == 2 and agg.side.N == 2 and agg.side.E == nil and agg.lack.a == 1
    and agg.lack.c == 1 and agg.wall == 1 and agg.killer.cracheur == 2, "cumul (côtés et manques des sensibles seulement)")
  local s = Pa.summary(agg)
  check(s:find("3 perte(s) dont 2 sensible(s)", 1, true) ~= nil and s:find("categories : fonderie 2, tourelle 1", 1, true) ~= nil
    and s:find("manque (sensibles) : a 1, c 1", 1, true) ~= nil and s:find("mur a 12 tuiles : 1 sur 2", 1, true) ~= nil, "résumé : " .. s)
  check(Pa.summary(nil) == "aucune perte", "résumé vide")
  return fails, n
end

local fails, total = suite(load_pa(SRC))
for _, m in ipairs(fails) do print("  ECHEC : " .. m) end
local passes, failures = total - #fails, #fails
local function mutate(old, new)
  local a, b = SRC:find(old, 1, true)
  if not a then return nil end
  return SRC:sub(1, a - 1) .. new .. SRC:sub(b + 1)
end
local mutants = {
  { "QG non reconnu", "if is_hq then return \"qg\" end", "" },
  { "site du QG exclusif", "if d_hq and d_hq <= Pa.SITE_R then return \"qg\" end", "if d_hq and d_hq < Pa.SITE_R then return \"qg\" end" },
  { "avant-poste ignoré", "if d_ap and ap_id ~= nil and d_ap <= Pa.SITE_R then return \"ap\" .. tostring(ap_id) end", "" },
  { "nord et sud inversés", "local ns = dy < 0 and \"N\" or \"S\"", "local ns = dy < 0 and \"S\" or \"N\"" },
  { "tourelles vides comptées armées", "if (n_armed or 0) <= 0 then return \"b\" end", "" },
  { "seuil de submersion inclus", "if (units or 0) >= Pa.SWAMP * n_armed then return \"c\" end", "if (units or 0) > Pa.SWAMP * n_armed then return \"c\" end" },
  { "couverture sans l'état armé", "        if t.armed then", "        if true then" },
  { "côtés de toutes les pertes", "    bump(agg.side, rec.side or \"?\")\n", "" },
}
local killed = 0
for _, m in ipairs(mutants) do
  local txt = mutate(m[2], m[3])
  if not txt then failures = failures + 1 print("  ECHEC : mutant « " .. m[1] .. " » : texte introuvable")
  else
    local ok, f = pcall(function() return (suite(load_pa(txt))) end)
    if (not ok) or #f > 0 then killed = killed + 1 passes = passes + 1 else failures = failures + 1 print("  ECHEC : mutant « " .. m[1] .. " » non détecté") end
  end
end
print(string.format("[PERTE] mutants refusés : %d sur %d", killed, #mutants))
print(string.format("[PERTE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
