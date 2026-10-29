-- Lot FACTIONS-BLOQUEES : règles pures de shared/team/blocage.lua (lua5.2 tests/blocage_test.lua)
package.path = "./?.lua;" .. package.path
local Bl = require("shared.team.blocage")
local ok, ko = 0, 0
local function check(c, msg) if c then ok = ok + 1 else ko = ko + 1 print("ECHEC : " .. msg) end end

-- spots : ordre fixe, premier = le point, 1 + 8 * RINGS positions, aucun doublon
local s = Bl.spots(10, 20)
check(#s == 1 + 8 * Bl.RINGS, "nombre de positions")
check(s[1].x == 10 and s[1].y == 20, "premier = le point lui-même")
local seen, dup = {}, false
for _, p in ipairs(s) do local k = p.x .. ":" .. p.y if seen[k] then dup = true end seen[k] = true end
check(not dup, "aucun doublon")
local s2 = Bl.spots(10, 20)
for i = 1, #s do check(s[i].x == s2[i].x and s[i].y == s2[i].y, "déterministe " .. i) end

-- first_free : le « moteur » recale sur la case multiple de 3 la plus proche ; la première est réservée, on prend la suivante libre
local function find(sp) return { x = math.floor(sp.x / 3 + 0.5) * 3, y = math.floor(sp.y / 3 + 0.5) * 3 } end
local function reserved(p) return p.x == 9 and p.y == 21 end
local pos = Bl.first_free(Bl.spots(10, 20), find, reserved)
check(pos and not (pos.x == 9 and pos.y == 21), "position réservée écartée")
check(Bl.first_free(Bl.spots(10, 20), find, function() return true end) == nil, "tout réservé -> nil")
check(Bl.first_free(Bl.spots(10, 20), function() return nil end, nil) == nil, "moteur sans place -> nil")
local pos2 = Bl.first_free(Bl.spots(10, 20), find, nil)
check(pos2 and pos2.x == 9 and pos2.y == 21, "sans réservation : la première trouvée (ancien comportement)")
local calls = 0
Bl.first_free(Bl.spots(10, 20), function() calls = calls + 1 return { x = calls, y = 1 } end, function() return true end)
check(calls == #s, "toutes les positions essayées")

-- own_blockers
check(Bl.own_blockers({ { name = "t", force = "f" } }, "f", "t"), "une tourelle de l'équipe")
check(not Bl.own_blockers({}, "f", "t"), "rien -> faux")
check(not Bl.own_blockers({ { name = "t", force = "f" }, { name = "tree", force = "neutral" } }, "f", "t"), "tourelle + arbre -> faux")
check(not Bl.own_blockers({ { name = "t", force = "g" } }, "f", "t"), "tourelle d'une autre équipe -> faux")
check(not Bl.own_blockers({ { name = "mur", force = "f" } }, "f", "t"), "autre bâtiment de l'équipe -> faux")

-- cause
check(Bl.cause("bloque", "fantome refuse (transport-belt en 498.5,320.5)") == "fantome:transport-belt", "cause bloque")
check(Bl.cause("chantier", nil) == "chantier", "cause chantier")

-- stall : 10 min sans changement -> une seule fois par cause ; un progrès remet l'horloge
local rec, say = Bl.stall(nil, "a", "c1", 0)
check(rec and not say, "premier appel")
rec, say = Bl.stall(rec, "a", "c1", 30000) check(not say, "9 min : rien")
rec, say = Bl.stall(rec, "a", "c1", 36000) check(say == "c1", "10 min : dit")
rec, say = Bl.stall(rec, "a", "c1", 40000) check(not say, "pas redit")
rec, say = Bl.stall(rec, "a", "c2", 41000) check(say == "c2", "autre cause : dite")
rec, say = Bl.stall(rec, "b", "c1", 50000) check(not say and rec.since == 50000, "progrès : horloge remise à zéro")
rec, say = Bl.stall(rec, "b", "c1", 90000) check(not say, "c1 déjà dite : pas redite")
local _, s3 = Bl.stall({ sig = "x", since = 0, said = {} }, "x", "c", 100, 50)
check(s3 == "c", "limite réglable")

print(string.format("[BLOCAGE] BILAN : %d OK, %d ECHEC(S)", ok, ko))
os.exit(ko == 0 and 0 or 1)
