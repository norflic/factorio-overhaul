-- n107-loin (banc fo-logs/2026-11-17_n106-repli-1, graine 2030089248 = partie du DC, player) : la centrale lointaine du projet 71
-- (demandée à 74,1 min, « gardee avec le poteau medium-electric-pole (obtenable ...) », plan à 76,3 min, 86 entités dont 67 poteaux de
-- ligne et de rue) attendait « medium-electric-pole manque (69) et n'est pas fabricable avec le stock libre » : la ligne et la rue
-- prenaient le poteau du GABARIT (PA.size : recette ouverte, sans regarder l'acier). Même piège que F719 (cadres de champ, n099) :
-- elles passent désormais par l'arbitre, A.choose_pole avec made_ok (Champ.pole_choice), portée lue aux prototypes.
-- Usage : lua5.2 tests/n107_loin_test.lua (depuis la racine du mod). Mutant : `N107_MUTANT=1` rejoue l'ancienne règle (poteau du gabarit).
package.path = "./?.lua;" .. package.path
local A = require("shared.ai3.automatiser")
local Book = require("shared.team.book")
local M = require("shared.team.modules")
local Cl = require("shared.team.centrale_loin")
local recipes = dofile("tests/fixtures/recipes.lua")

local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1; print("[N107-LOIN] ECHEC : " .. msg) end end

local line_pole = Cl.line_pole
if os.getenv("N107_MUTANT") then line_pole = function(own, _, wire) return own, wire(own), wire(own) end end

-- portée de fil des prototypes (ici la table des modules, copie des données du jeu : aucun nom écrit dans ce test)
local function wire(n) return M.spec(n).wire end
local OWN = M.DEFAULT_POLE                     -- poteau du gabarit retenu par PA.size à 74,1 min (« gardee avec le poteau ... »)
local CHEAP = M.POLES[1]
check(OWN ~= CHEAP, "le poteau du gabarit n'est pas le moins cher")

-- valeurs rejouées : recettes ouvertes (acier compris), coffre sans le poteau du gabarit ni ses matières fabriquées, aucune production
-- de ces matières (IA3E à 83 min : steel-plate 0.01/0) ; le bois se récolte (arbres à portée)
local book = Book.new(recipes, { allowed = function() return true end })
local own_raw = {}
for _, it in ipairs(A.short_of(book, book:plan({ { OWN, A.POLE_BATCH } }, {}).raw, {})) do own_raw[it[1]] = true end
local HARV = { wood = 48 }
local cheap_made = {}
for _, it in ipairs(A.short_of(book, book:plan({ { CHEAP, A.POLE_BATCH } }, {}).raw, HARV)) do cheap_made[it[1]] = true end
local missing = nil
for k in pairs(own_raw) do if not cheap_made[k] and not book:natural(k) then missing = missing or k end end
check(missing ~= nil, "le poteau du gabarit demande une matiere fabriquee que le moins cher n'a pas")
local function made_ok(it) return cheap_made[it] == true end -- produit ou au coffre : seulement les matières du moins cher
local pick = A.choose_pole(book, {}, HARV, made_ok)
check(pick == CHEAP, "arbitre avec made_ok : le moins cher (" .. tostring(pick) .. ")")

-- 1. la ligne et la rue prennent le poteau de l'arbitre ; portée de la ligne = la sienne, liaison au gabarit = la plus courte
local name, reach, link = line_pole(OWN, pick, wire)
check(name == CHEAP, "ligne et rue au poteau de l'arbitre (" .. tostring(name) .. ")")
check(reach == wire(CHEAP), "portee de la ligne lue au poteau de l'arbitre (" .. tostring(reach) .. ")")
check(link == math.min(wire(CHEAP), wire(OWN)), "liaison au gabarit a la plus courte des deux portees (" .. tostring(link) .. ")")
-- 2. aucun poteau obtenable (arbitre nil) : le poteau du gabarit, comme avant
local n2, r2, l2 = line_pole(OWN, nil, wire)
check(n2 == OWN and r2 == wire(OWN) and l2 == wire(OWN), "arbitre muet : poteau du gabarit")
-- 3. l'arbitre retient le poteau du gabarit (ses matières produites) : rien ne change
local n3 = line_pole(OWN, A.choose_pole(book, {}, {}, function() return true end), wire)
check(n3 == A.choose_pole(book, {}, {}, function() return true end), "arbitre au poteau long : meme poteau")

-- 4. câblage (lu dans le source) : plan_power demande l'arbitre pour la centrale lointaine et pose la ligne avec ce poteau
local function src(path) local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s end
local b = src("script/team/build.lua")
check(b:find("Cl.line_pole(mp.name, Build.POLE_CHOICE(f),", 1, true) ~= nil, "plan_power : poteau de ligne par l'arbitre")
check(b:find("local pole, reach = pole_kind(f, line_pole or mp.name)", 1, true) ~= nil, "la rue prend le poteau de la ligne")
check(b:find("Far.line(f, surface, p, { x = mp.x, y = mp.y }, npos, line_link,", 1, true) ~= nil, "Far.line a la portee de liaison")
check(b:find("name = line_pole or mp.name, x = c.x", 1, true) ~= nil, "poteaux de la ligne au poteau de l'arbitre")
check(b:find("max_wire_distance end)", 1, true) ~= nil, "portee lue aux prototypes")
check(src("script/team/champ.lua"):find("Build.POLE_CHOICE = Champ.pole_choice", 1, true) ~= nil, "crochet de l'arbitre pose par champ.lua")

-- 5. déterminisme : deux appels, même résultat
local a1, b1, c1 = line_pole(OWN, pick, wire)
local a2, b2, c2 = line_pole(OWN, pick, wire)
check(a1 == a2 and b1 == b2 and c1 == c2, "deterministe")

print(string.format("[N107-LOIN] %d OK, %d ECHEC(S)", ok_n, fail_n))
if fail_n > 0 then os.exit(1) end
