--[[ N098-DETOUR (mandat de nuit 15-16/11, capture 220503 du DC) : la fonderie déportée d'un bout de bande (Co.away,
  shared/team/champ_colonne.lua) ne garde plus le PREMIER tracé trouvé quand c'est un grand détour : un tracé direct (sous
  Co.AWAY_DETOUR × Manhattan + Co.AWAY_SLACK) gagne d'emblée ; sinon le plus court des détours trouvés.
  Lancement : lua5.2 tests/n098_detour_test.lua ]]
package.path = "./?.lua;" .. package.path
local Co = require("shared.team.champ_colonne")

local pass, fail = 0, 0
local function check(c, msg)
  if c then pass = pass + 1 else fail = fail + 1; print("[N098-DETOUR] ECHEC : " .. msg) end
end

-- 1. longueur d'un tracé et tolérance
local function line(u0, v0, path)
  local r, u, v = { { u = u0, v = v0 } }, u0, v0
  for _, s in ipairs(path) do
    for _ = 1, s[3] do u, v = u + s[1], v + s[2]; r[#r + 1] = { u = u, v = v } end
  end
  return r
end
check(Co.route_len({}) == 0 and Co.route_len({ { u = 0, v = 0 } }) == 0, "tracé vide ou d'une tuile : 0")
check(Co.route_len(line(0, 0, { { 1, 0, 17 } })) == 17, "tracé droit de 17")
local ug = { { u = 0, v = 0 }, { u = 1, v = 0 }, { u = 6, v = 0 }, { u = 7, v = 0 } } -- paire de souterrains (saut de 5)
check(Co.route_len(ug) == 7, "souterrain compté à sa longueur au sol")
local from, t = { u = 0, v = 0 }, { u = -17, v = 0 }
local direct = line(0, 0, { { -1, 0, 17 } })
-- le détour de la capture : monter de 20, traverser 17 (et plus), redescendre
local detour = line(0, 0, { { 0, -1, 20 }, { -1, 0, 60 }, { 0, 1, 20 }, { 1, 0, 43 } })
check(Co.direct_enough(direct, from, t), "ligne droite acceptée")
check(not Co.direct_enough(detour, from, t), "grand rectangle (143 tuiles pour 17) refusé")
check(Co.direct_enough(line(0, 0, { { 0, -1, 3 }, { -1, 0, 17 }, { 0, 1, 3 } }), from, t), "petit contournement d'obstacle (23 pour 17) accepté")
  check(Co.direct_enough(line(0, 0, { { 0, -1, 15 }, { -1, 0, 17 }, { 0, 1, 15 } }), from, t), "contournement moyen (47 pour 17) accepté : seul le grand détour coûte une recherche")

-- 2. Co.away : le premier tracé (détour) est gardé en repli, la place suivante en ligne directe gagne
local function run(stub_routes)
  local real = Co.route
  local calls = 0
  Co.route = function(s, sd, tt)
    calls = calls + 1
    local r = stub_routes[calls]
    if r == "direct" then
      local n = math.abs(s.u - tt.u) + math.abs(s.v - tt.v)
      local out = { { u = s.u, v = s.v } }
      for i = 1, n do out[#out + 1] = { u = s.u + i, v = s.v } end
      return out, n
    elseif r == "detour" then
      local out = { { u = s.u, v = s.v } }
      for i = 1, 200 do out[#out + 1] = { u = s.u, v = s.v + i } end
      return out, 200
    end
    return nil, "aucun chemin"
  end
  local layout = function() return { { kind = "tapis", u = 0, v = 0, size = 1, du = 1, dv = 0, role = "colonne" } }, 1, { b_coal = 0, b_link = 0 } end
  local ok, res, why = pcall(Co.away, {}, { u = 0, v = 0 }, 1, 1, nil,
    function() return true end, function(u, v) return u == 1 and v == 0 end, -- la place d = 0 est sur le minerai
    { shift = 6, rows = 2, layout = layout })
  Co.route = real
  assert(ok, res)
  return res, why, calls
end
do
  local res, _, calls = run({ "detour", "direct" })
  check(res ~= nil and Co.route_len(res.route) < 50, "détour puis place directe : la place directe gagne")
  check(calls == 2, "recherche arrêtée au premier tracé direct (" .. calls .. " tracés)")
  local res2 = run({ "detour", "detour" })
  check(res2 ~= nil and Co.route_len(res2.route) == 200, "aucun tracé direct : le détour (le plus court) sert de repli")
  local _, _, c4 = run({ "detour", "detour", "detour", "detour", "direct" })
  check(c4 == 1 + 2, "après un détour, au plus 2 places de plus tracées (" .. c4 .. " tracés)")
  local res3, _, c3 = run({ "direct" })
  check(res3 ~= nil and c3 == 1, "premier tracé direct : rien ne change (une seule recherche)")
end
-- 3. mutant : sans la règle (tolérance infinie), le premier détour est gardé -> la suite le voit
do
  local keep = Co.AWAY_DETOUR
  Co.AWAY_DETOUR = 1e9
  local res = run({ "detour", "direct" })
  Co.AWAY_DETOUR = keep
  local dead = not (res ~= nil and Co.route_len(res.route) < 50)
  print("[N098-DETOUR] mutant tolérance infinie -> " .. (dead and "refusé" or "SURVIT"))
  check(dead, "mutant : tolérance infinie refusée par la suite")
end
print(string.format("[N098-DETOUR] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
