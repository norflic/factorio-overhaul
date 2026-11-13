--[[
  Sprint s40, axe « décision » (shared/ai3/projets.lua) : plans du livre refaits pour rien pendant le dépliage des projets.
    p2 : plafond de fabrications de la pensée atteint (E.crafts = P.MAX_CRAFTS) : P.want ne planifie plus que le manque (1 plan), même résultat ;
    p3 : une fabrication qui tient en un morceau ne refait pas le plan qui a servi à mesurer son énergie, même tâche.
  Lancement, depuis la racine du mod :   lua5.2 tests/s40_decision_test.lua
]]
package.path = "./?.lua;" .. package.path
local Book = require("shared.team.book")
local P = require("shared.ai3.projets")

local book = Book.new(dofile("tests/fixtures/recipes.lua"))
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end

-- Livre compteur : mêmes réponses que le livre, nombre de plans relevé.
local plans = 0
local counted = setmetatable({ plan = function(_, wants, stock) plans = plans + 1 return book:plan(wants, stock) end }, { __index = book })

local ITEM = "burner-mining-drill"
local function stock() return { ["iron-plate"] = 500, stone = 500, ["copper-plate"] = 500, coal = 500 } end
local function ser(t)
  if type(t) ~= "table" then return tostring(t) end
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  local out = {}
  for _, k in ipairs(ks) do if t[k] ~= 0 then out[#out + 1] = tostring(k) .. "=" .. ser(t[k]) end end -- (une case à 0 vaut une case absente)
  return "{" .. table.concat(out, ",") .. "}"
end
local function run(bk, crafts, n)
  local E = P.context(stock(), bk, { open = {} }, {})
  E.crafts = crafts
  local proj = { id = 7, key = "essai" }
  local ok = P.want(E, proj, { { ITEM, n } }, 50, false, "t")
  return E, ok, proj
end

check(book:handcraftable(ITEM), "l'objet d'essai se fabrique à la main")

-- p2 : plafond atteint.
plans = 0
local E, ok, proj = run(counted, P.MAX_CRAFTS, 3)
check(plans == 1, "plafond atteint : un seul plan du livre (celui du manque), relevé " .. plans)
check(ok == false and #E.tasks == 0 and E.crafts == P.MAX_CRAFTS, "plafond atteint : rien n'est fabriqué, le besoin n'est pas servi")
check(E.raw[ITEM] and E.raw[ITEM].n == 3 and (proj.missing or {})[ITEM] == 3, "plafond atteint : l'objet reste un manque du projet (3)")
check(ser(E.avail) == ser(stock()), "plafond atteint : le stock virtuel est intact")
-- matière qui manque ET plafond atteint : les manques bruts sont ceux du plan entier
plans = 0
local Ep = P.context({ stone = 500 }, counted, { open = {} }, {})
Ep.crafts = P.MAX_CRAFTS
P.want(Ep, { id = 8, key = "pauvre" }, { { ITEM, 2 } }, 50, false, "t")
local want_raw = book:plan({ { ITEM, 2 } }, { stone = 500 }).raw
local same = true
for k, v in pairs(want_raw) do if not (Ep.raw[k] and Ep.raw[k].n == math.ceil(v)) then same = false end end
check(same and next(want_raw) ~= nil and plans == 1, "plafond atteint, matière absente : manques bruts du plan entier, un seul plan (" .. plans .. ")")

-- p3 : un morceau = le plan de mesure réutilisé ; la tâche est la même qu'avec un plan refait.
plans = 0
local E1 = run(counted, 0, 1)
check(#E1.tasks == 1 and E1.crafts == 1, "une fabrication courte : une tâche")
check(plans == 2, "une fabrication courte : 2 plans (fabricable ?, puis la fabrication), relevé " .. plans)
local t = E1.tasks[1]
local ref = book:plan({ { ITEM, 1 } }, stock())
check(t.count == 1 and ser(t.steps) == ser(ref.crafts) and ser(E1.avail) == ser(ref.avail), "une fabrication courte : étapes et stock restant du plan du livre")
local uses = {}
for _, u in ipairs(t.uses) do uses[u[1]] = u[2] end
check(ser(uses) == ser(ref.uses), "une fabrication courte : prélèvements du plan du livre")
-- plusieurs morceaux : inchangé (somme des tâches = commande, stock restant = plans enchaînés)
local En = run(book, 0, 40)
local total = 0
for _, tk in ipairs(En.tasks) do total = total + tk.count end
check(total == 40 and #En.tasks >= 1 and #En.tasks <= P.MAX_CRAFTS, "grosse commande : " .. #En.tasks .. " morceau(x), 40 objets")

-- p4, p5 (script/ai3/cerveau.lua, hors moteur : contrôle statique du source, comme tests/decoupage_pensee_test.lua).
local fh = assert(io.open("script/ai3/cerveau.lua", "rb"))
local src = fh:read("*a")
fh:close()
-- p4 : aucune sortie de research_step sur un add_research refusé sans dater l'horloge du laboratoire
check(src:find("if not force.add_research(tech) then lab.last = tick return info end", 1, true) ~= nil
  and src:find("if not force.add_research(tech) then return info end", 1, true) == nil,
  "p4 : un add_research refusé date lab.last avant de sortir (le temps du refus n'est pas du temps de laboratoire)")
-- p5 : reach_of lit la carte de connaissance une seule fois par ressource
local body = src:match("local function reach_of%(.-\nend\n") or ""
local _, calls = body:gsub("Ia3%.known_deposits%(f, res, tick%)", "")
check(body ~= "" and calls == 1, "p5 : reach_of appelle Ia3.known_deposits une fois par ressource (relevé " .. calls .. ")")

print(string.format("[S40-DECISION] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
