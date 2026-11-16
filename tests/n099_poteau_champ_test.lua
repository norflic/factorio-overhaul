-- n099 (interblocage B5, banc N099-INT1, graine 4251870853) : une bande de champ prenait le premier poteau débloqué (le moyen, à l'acier)
-- sans regarder l'acier ; la bande attendait l'acier, le noyau de la pile avec elle (« noyau non couvert (manque steel-plate 67) »), la
-- pile SUSPENDUE refusait tout le capital : aucun assembleur pour votre équipe ni pour amber. Le poteau d'un cadre neuf passe par
-- l'arbitre du mall (A.choose_pole) avec `made_ok` : une matière fabriquée qui manque au stock doit être au coffre ou produite.
-- Un cadre figé garde le poteau de son treillis (frame.pole). Usage : lua5.2 tests/n099_poteau_champ_test.lua (depuis la racine du mod)
package.path = "./?.lua;" .. package.path
local A = require("shared.ai3.automatiser")
local Book = require("shared.team.book")
local recipes = dofile("tests/fixtures/recipes.lua")

local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1; print("[N099-POTEAU] ECHEC : " .. msg) end end

-- Les noms viennent de la table triée des poteaux (shared/team/modules.lua, M.POLES : du plus court fil au plus long), pas d'ici
local M = require("shared.team.modules")
local CHEAP, LONG = M.POLES[1], M.POLES[#M.POLES]
local late = Book.new(recipes, { allowed = function(n) return true end })
-- matières fabriquées du poteau le plus long qui manquent à coffre vide (lues au livre, pas écrites ici)
local long_raw = {}
for _, it in ipairs(A.short_of(late, late:plan({ { LONG, A.POLE_BATCH } }, {}).raw, {})) do long_raw[#long_raw + 1] = it[1] end
check(#long_raw > 0, "le poteau le plus long demande des matieres fabriquees (" .. table.concat(long_raw, ",") .. ")")

-- 1. Sans récolte (le moins cher demande une matière naturelle), sans made_ok : la règle d'avant (le mall) retient le plus long
local sans = A.choose_pole(late, {}, {})
check(sans ~= nil and sans ~= CHEAP, "sans made_ok : regle d'avant inchangee (" .. tostring(sans) .. ")")

-- 2. made_ok : aucune matière fabriquée ni au coffre ni produite -> aucun poteau obtenable (plus le poteau à l'acier absent)
local function none() return false end
check(A.choose_pole(late, {}, {}, none) == nil, "made_ok faux : aucun poteau retenu sans ses matieres")

-- 3. Les matières du poteau long produites (débit mesuré, ou coffre) -> il redevient obtenable
local produced = {}
for _, k in ipairs(long_raw) do produced[k] = true end
check(A.choose_pole(late, {}, {}, function(it) return produced[it] == true end) == sans, "matieres produites : poteau long obtenable")

-- 4. Le bois se récolte : le moins cher, quand seules SES matières fabriquées sont là (celles du poteau long qu'il n'a pas manquent)
local HARV = { wood = 48 }
local cheap_raw = {}
for _, it in ipairs(A.short_of(late, late:plan({ { CHEAP, A.POLE_BATCH } }, {}).raw, HARV)) do cheap_raw[it[1]] = true end
check(A.choose_pole(late, {}, HARV, function(it) return cheap_raw[it] == true end) == CHEAP,
  "bois recolte, matieres du seul poteau long absentes : le poteau le moins cher (" .. tostring(CHEAP) .. ")")

-- 5. Câblage du moteur : le cadre garde son poteau, le neuf passe par l'arbitre (lu dans le source)
local fh = assert(io.open("script/team/champ.lua", "rb")); local src = fh:read("*a"); fh:close()
check(src:find("Champ.data(f, o.kind, frame)", 1, true) ~= nil, "SPEC.ore passe le cadre a Champ.data")
check(src:find("plan.frame.pole = spec.pole_name", 1, true) ~= nil, "le cadre neuf garde le nom de son poteau")
check(src:find("Auto.choose_pole(pole_book(f), Stock.contents(f), Harvest.reachable(f), made_ok)", 1, true) ~= nil,
  "le poteau d'un cadre neuf vient de l'arbitre avec made_ok")
local fold = src:match("function Champ%.data%(f, kind, frame%)(.-)local usable")
check(fold ~= nil and fold:find("frame and frame.pole", 1, true) ~= nil and fold:find("Champ.pole_choice(f)", 1, true) ~= nil
    and fold:find("Mods.cheapest_pole", 1, true) ~= nil,
  "Champ.data : poteau du cadre, sinon l'arbitre, sinon le moins cher debloque")

print(string.format("[N099-POTEAU] %d OK, %d ECHEC(S)", ok_n, fail_n))
if fail_n > 0 then os.exit(1) end
