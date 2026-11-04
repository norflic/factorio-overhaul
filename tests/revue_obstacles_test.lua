-- lua5.2 tests/revue_obstacles_test.lua : curseur de la revue des obstacles (shared/team/revue_obstacles.lua), lot AGEBLOCAGE.
package.path = "./?.lua;" .. package.path
local R = require("shared.team.revue_obstacles")

local ok, ko = 0, 0
local quiet = false
local function check(c, m)
  if c then ok = ok + 1 else ko = ko + 1; if not quiet then print("[REVUE-OBSTACLES] ECHEC : " .. m) end end
end

local function world(n, trees)
  local obs = {}
  for i = 1, n do obs[i] = { id = i } end
  local has = function(o) return o.id <= trees end
  return obs, has
end

local function suite()
  -- §1 Le cas mesuré : 30 obstacles, les 8 premiers gardent un arbre ; les 22 autres sont revus (et fermés) en 4 appels au plus.
  local obs, has = world(30, 8)
  local cur, left
  local calls = 0
  repeat
    calls = calls + 1
    left, cur = R.review(obs, cur, 8, has)
  until left == 8 or calls > 10
  check(left == 8 and calls <= 4, "§1 les 22 obstacles vides fermés en " .. calls .. " appel(s) (ouverts restants " .. tostring(left) .. ")")
  local open = 0
  for _, o in ipairs(obs) do if not o.done then open = open + 1 end end
  check(open == 8, "§1 seuls les 8 obstacles avec arbre restent ouverts (" .. open .. ")")
  -- §2 Le curseur repart juste après le dernier revu.
  local o2, h2 = world(30, 30)
  local l2, c2 = R.review(o2, 1, 8, h2)
  check(l2 == 30 and c2 == 9, "§2 8 revus depuis 1 : curseur à 9 (" .. tostring(c2) .. ")")
  l2, c2 = R.review(o2, c2, 8, h2)
  check(c2 == 17, "§2 appel suivant : curseur à 17 (" .. tostring(c2) .. ")")
  l2, c2 = R.review(o2, 27, 8, h2)
  check(c2 == 5, "§2 le tour boucle : depuis 27, curseur à 5 (" .. tostring(c2) .. ")")
  -- §3 Tout est fait : rien n'est revu, 0 ouvert, curseur gardé.
  local o3 = { { done = true }, { done = true } }
  local l3, c3 = R.review(o3, 2, 8, function() return true end)
  check(l3 == 0 and c3 == 2, "§3 tout fait : 0 ouvert, curseur gardé")
  local l4, c4 = R.review({}, nil, 8, function() return true end)
  check(l4 == 0 and c4 == 1, "§3 liste vide : 0 ouvert, curseur 1")
  -- §4 Curseur hors de la liste (obstacles retirés) : repart de 1.
  local o5, h5 = world(5, 0)
  local l5 = R.review(o5, 12, 8, h5)
  check(l5 == 0, "§4 curseur hors liste : tout revu, 0 ouvert")
  -- §5 Le compte des ouverts est exact au-delà des revus.
  local o6, h6 = world(20, 20)
  local l6 = R.review(o6, 1, 3, h6)
  check(l6 == 20, "§5 3 revus, 20 ouverts comptés (" .. l6 .. ")")
end

suite()

-- Mutants
local function mutant(name, impl)
  local saved = R.review
  R.review = impl
  local o0, k0 = ok, ko
  quiet = true
  pcall(suite)
  quiet = false
  local caught = ko > k0
  ok, ko = o0, k0
  R.review = saved
  check(caught, "mutant refusé : " .. name)
end
local orig = R.review
mutant("le curseur revient à son départ (ancienne boucle)", function(obs, cur, checks, has)
  local _, _ = orig(obs, cur, checks, has)
  return (function()
    local left = 0
    for _, o in ipairs(obs) do if not o.done then left = left + 1 end end
    return left
  end)(), cur or 1
end)
mutant("curseur toujours à 1", function(obs, cur, checks, has) local l = orig(obs, 1, checks, has) return l, 1 end)
mutant("aucun obstacle fermé", function(obs, cur, checks, has) return orig(obs, cur, checks, function() return true end) end)

print(string.format("[REVUE-OBSTACLES] BILAN : %d OK, %d ECHEC(S)", ok, ko))
os.exit(ko == 0 and 0 or 1)
