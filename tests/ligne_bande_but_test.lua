-- Lot RACCORD-BANDE 2 : le but « auto:ligne-bande » (poteaux de la ligne de poteaux d'une bande lointaine) ne prend pas de place parmi les K projets.
-- Partie neuve 0.6.72 : le but passait « attente » 12 min sur 20 (K places prises par l'extraction et la centrale), 104 poteaux manquants de 8 à 38 min.
-- Règle : shared/ai3/automatiser.lua (A.goals : fond + invest quand m.line) + shared/ai3/projets.lua (P.update : un but de fond n'use pas les K places).
package.path = "./?.lua;" .. package.path
local A = require("shared.ai3.automatiser")
local P = require("shared.ai3.projets")

local ok, bad = 0, 0
local function check(name, cond)
  if cond then ok = ok + 1 else bad = bad + 1 print("ECHEC : " .. name) end
end

local function goals_with(line)
  local goals = {}
  for i = 1, 6 do goals[#goals + 1] = { key = "extraction:" .. i, family = "extraction", kind = "outpost", value = 90 - i } end
  A.goals(goals, { mods = {
    { product = "ligne-bande", state = "chantier", missing = { { "small-electric-pole", 3 } }, gain = 0, pile = "couverture", line = line } } }, nil, nil)
  return goals
end

local function run(line)
  local st = {}
  local goals = goals_with(line)
  local g
  for _, x in ipairs(goals) do if x.key == "auto:ligne-bande" then g = x end end
  P.update(st, goals, 0, 8)
  local p
  for _, x in ipairs(st.projects) do if x.key == "auto:ligne-bande" then p = x end end
  return g, p
end

local g, p = run(true)
check("le but existe", g ~= nil)
check("fond", g and g.fond == true)
check("invest", g and g.invest == true)
check("le projet est actif avec K places toutes prises", p and p.state == "actif")
local _, order = P.update({}, goals_with(true), 0, 8)
check("K reste petit (la preuve a un sens)", order and order < 6)

-- témoin : une ligne qui n'est pas marquée garde le comportement d'avant (attente quand les K places sont prises)
local g2, p2 = run(nil)
check("sans m.line : pas de fond", g2 and g2.fond == nil)
check("sans m.line : pas de place (aucun projet ouvert)", p2 == nil)

-- ordre de service : un but de fond + invest vient avant les projets ordinaires (« rest ») et après le premier
local st = {}
local goals = goals_with(true)
local order_list = P.update(st, goals, 0, 8)
local pos
for i, x in ipairs(order_list) do if x.key == "auto:ligne-bande" then pos = i end end
check("servi parmi les premiers (invest)", pos ~= nil and pos <= 2)

print(string.format("[LIGNE-BANDE-BUT] BILAN : %d OK, %d ECHEC(S)", ok, bad))
os.exit(bad == 0 and 0 or 1)
