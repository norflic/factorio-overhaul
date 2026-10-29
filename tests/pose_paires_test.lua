--[[
  Tests hors jeu du lot EXTENSION-FER : pose des paires foreuse + four d'un avant-poste (shared/team/pose_paires.lua).
  Usage :  lua5.2 tests/pose_paires_test.lua
  Audit du 29/10 : « avant-poste de fer » alors que la base touche un énorme gisement de fer. Cause : `place_pairs` comptait CHAQUE
  tuile essayée, libre ou non, jusqu'à 40, depuis le même centre ; un agrandissement retombait sur les 40 tuiles déjà occupées par la
  construction, ne posait rien et marquait l'avant-poste `full` pour toute la partie.
  Cas : géométrie (tuiles, boîtes), tri, composante connexe d'un gisement, parcours (occupé écarté sans coût, plafond d'essais,
  mémoire des échecs, reprise), verdict (full seulement par balayage complet ou couverture P.KAPPA ; plafond de foreuses supprimé au lot PLAFOND-FOREUSES, garde-fou facultatif), libellé du projet, et un
  SIMULATEUR de gisement : l'ancienne règle ne pose plus rien à l'agrandissement, la nouvelle remplit jusqu'au plafond de foreuses ;
  absence de `pairs`, de nom d'objet, de hasard ; MUTANTS refusés.
]]
package.path = "./?.lua;" .. package.path
local P = require("shared.team.pose_paires")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local function set_of(keys)
  local s = {}
  for _, k in ipairs(keys) do s[k] = true end
  return s
end
local function count(set)
  local n = 0
  for _ in next, set do n = n + 1 end
  return n
end

---------------------------------------------------------------------------------------------------
-- Gisement et moteur simulés
---------------------------------------------------------------------------------------------------
-- Tuiles de minerai (centres x.5) d'un disque de rayon r autour de (cx, cy).
local function disc(cx, cy, r)
  local out = {}
  for ty = math.floor(cy - r) - 1, math.ceil(cy + r) + 1 do
    for tx = math.floor(cx - r) - 1, math.ceil(cx + r) + 1 do
      local x, y = tx + 0.5, ty + 0.5
      if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r then out[#out + 1] = { x = x, y = y } end
    end
  end
  return out
end

local function within(ore, center, radius)
  local out = {}
  for _, r in ipairs(ore) do
    if (r.x - center.x) ^ 2 + (r.y - center.y) ^ 2 <= radius * radius then out[#out + 1] = r end
  end
  return out
end

-- Une paire = foreuse 2x2 en `pos` et four 2x2 juste au nord. Elle passe si aucune de ses 8 tuiles n'est prise ou bloquée.
local function own_tiles(pos) -- emprise 2x2 centrée en un point entier, SANS passer par la règle testée
  return { (pos.x - 1) * 65536 + (pos.y - 1), (pos.x) * 65536 + (pos.y - 1), (pos.x - 1) * 65536 + pos.y, pos.x * 65536 + pos.y }
end
local function pair_tiles(pos)
  local t = own_tiles(pos)
  for _, k in ipairs(own_tiles({ x = pos.x, y = pos.y - 2 })) do t[#t + 1] = k end
  return t
end
local function fits(world, pos)
  for _, k in ipairs(pair_tiles(pos)) do
    if world.occ[k] or (world.blocked and world.blocked[k]) then return false end
  end
  return true
end
local function put(world, pos)
  for _, k in ipairs(pair_tiles(pos)) do world.occ[k] = true end
end

-- L'ANCIENNE règle : chaque tuile essayée compte, libre ou non, plafond de 40, aucun emplacement mémorisé.
local function run_old(world, ore, center, radius, want)
  local tiles = P.sorted(within(ore, center, radius), center)
  local placed, attempts, tried = 0, 0, {}
  for _, r in ipairs(tiles) do
    if placed >= want or attempts >= 40 then break end
    local pos = { x = math.floor(r.x + 0.5), y = math.floor(r.y + 0.5) }
    local key = P.key(pos.x, pos.y)
    if not tried[key] then
      tried[key] = true
      attempts = attempts + 1
      if fits(world, pos) then put(world, pos); placed = placed + 1 end
    end
  end
  return placed, attempts
end

-- La NOUVELLE règle, comme script/faction/outposts.lua l'emploie. `o` : { dead } mémorisé d'un appel à l'autre.
local function run_new(world, ore, center, radius, want, o, same_deposit, cap)
  local tiles = P.sorted(within(ore, center, radius), center)
  if same_deposit then tiles = P.component(tiles, P.GAP, center) end
  o.dead = o.dead or {}
  local pl = P.new({ resources = tiles, cap = cap or P.MAX_ATTEMPTS, w = 2, h = 2, occupied = world.occ, dead = o.dead })
  local placed = 0
  while placed < want do
    local pos = pl.next()
    if not pos then break end
    if fits(world, pos) then
      put(world, pos)
      pl.occupy(pair_tiles(pos))
      placed = placed + 1
    else
      pl.fail(pos)
    end
  end
  local rep = pl.report()
  if rep.exhausted then o.dead = nil end
  return placed, rep
end

---------------------------------------------------------------------------------------------------
section("1. Tuiles d'une emprise et d'une boîte")
do
  local t = set_of(P.tiles({ x = 11, y = 11 }, 2, 2))
  check(count(t) == 4 and t[P.key(10, 10)] and t[P.key(11, 10)] and t[P.key(10, 11)] and t[P.key(11, 11)], "foreuse 2x2 centrée en (11, 11) : tuiles 10-11 x 10-11")
  local c = P.tiles({ x = 10.5, y = 4.5 }, 1, 1)
  check(#c == 1 and c[1] == P.key(10, 4), "coffre 1x1 centré en (10.5, 4.5) : la tuile (10, 4)")
  local neg = set_of(P.tiles({ x = -3, y = -3 }, 2, 2))
  check(count(neg) == 4 and neg[P.key(-4, -4)] and neg[P.key(-3, -3)], "coordonnées négatives")
  check(P.key(1, 2) ~= P.key(2, 1) and P.key(0, 1) ~= P.key(1, 0), "clés de tuile distinctes")
  local b = set_of(P.box_tiles(10, 10, 12, 12))
  check(count(b) == 4 and b[P.key(10, 10)] and b[P.key(11, 11)], "boîte (10, 10)-(12, 12) : 4 tuiles")
  check(not b[P.key(12, 10)] and not b[P.key(9, 10)], "...un contact par le bord ne compte pas (F96)")
  local fine = set_of(P.box_tiles(10.1, 10.1, 10.9, 10.9))
  check(count(fine) == 1 and fine[P.key(10, 10)], "boîte à l'intérieur d'une tuile : cette tuile")
  local drift = set_of(P.box_tiles(9.998, 10, 12.002, 12)) -- bruit de la virgule fixe 1/256 (F98)
  check(count(drift) == 4, "bruit de 1/256 sur les bords de la boîte : toujours 4 tuiles")
end

section("2. Tri des tuiles de minerai")
do
  local res = { { x = 5.5, y = 0.5 }, { x = 0.5, y = 0.5 }, { x = -0.5, y = 0.5 }, { x = 0.5, y = -0.5 }, { x = 0.5, y = 1.5 } }
  local s = P.sorted(res, { x = 0, y = 0 })
  check(s[1].x == -0.5 and s[1].y == 0.5, "à distance égale : x puis y croissants (-0.5, 0.5)")
  check(s[2].x == 0.5 and s[2].y == -0.5 and s[3].x == 0.5 and s[3].y == 0.5, "...(0.5, -0.5) puis (0.5, 0.5)")
  check(s[#s].x == 5.5, "le plus éloigné en dernier")
  check(res[1].x == 5.5, "l'entrée n'est pas modifiée (copie triée)")
  local again = P.sorted({ res[5], res[4], res[3], res[2], res[1] }, { x = 0, y = 0 })
  local same = true
  for i = 1, #s do if s[i].x ~= again[i].x or s[i].y ~= again[i].y then same = false end end
  check(same, "indépendant de l'ordre d'entrée (déterminisme)")
end

section("3. Composante connexe : le gisement du centre, pas celui d'à côté")
do
  local center = { x = 0, y = 0 }
  local near = disc(0, 0, 8)
  local far = disc(30, 0, 5) -- autre gisement, à 22 tuiles du bord du premier
  local all = {}
  for _, r in ipairs(near) do all[#all + 1] = r end
  for _, r in ipairs(far) do all[#all + 1] = r end
  local comp = P.component(P.sorted(all, center), P.GAP, center)
  check(#comp == #near, "deux gisements éloignés : seule la composante du centre (" .. #comp .. " / " .. #near .. ")")
  local tail_ok = true
  for _, r in ipairs(comp) do if r.x > 10 then tail_ok = false end end
  check(tail_ok, "...aucune tuile de l'autre gisement")
  -- pont : une rangée de tuiles espacées de 3 (trou de 2) relie les deux gisements
  local bridged = {}
  for _, r in ipairs(all) do bridged[#bridged + 1] = r end
  for x = 9, 25, 3 do bridged[#bridged + 1] = { x = x + 0.5, y = 0.5 } end
  local both = P.component(P.sorted(bridged, center), P.GAP, center)
  check(#both > #near, "un trou de 2 tuiles est franchi (même gisement clairsemé)")
  local wide = {}
  for _, r in ipairs(all) do wide[#wide + 1] = r end
  for x = 13, 25, 5 do wide[#wide + 1] = { x = x + 0.5, y = 0.5 } end
  check(#P.component(P.sorted(wide, center), P.GAP, center) == #near, "un trou de 4 tuiles ne l'est pas")
  check(#P.component({}, P.GAP, center) == 0, "aucune tuile : rien")
  -- gisement épuisé sous l'avant-poste : la tuile la plus proche est à plus de 18 tuiles
  local elsewhere = P.sorted(disc(25, 0, 4), center)
  check(#P.component(elsewhere, P.GAP, center) == 0, "la tuile la plus proche à plus de 18 tuiles : gisement épuisé ici, rien")
  check(#P.component(elsewhere, P.GAP) > 0, "...sans centre donné : la composante est rendue telle quelle")
  local sorted = P.sorted(near, center)
  local c2 = P.component(sorted, P.GAP, center)
  local ordered = true
  for i = 1, #c2 do if c2[i].x ~= sorted[i].x or c2[i].y ~= sorted[i].y then ordered = false end end
  check(ordered, "l'ordre (distance au centre) est conservé")
end

section("4. Parcours : occupé écarté sans coût, plafond d'essais")
do
  local ore = P.sorted(disc(0, 0, 6), { x = 0, y = 0 })
  local pl = P.new({ resources = ore, cap = 5, w = 2, h = 2 })
  local seen = {}
  local n = 0
  while true do
    local pos = pl.next()
    if not pos then break end
    n = n + 1
    seen[#seen + 1] = pos
  end
  local rep = pl.report()
  check(n == 5 and rep.attempts == 5 and rep.capped and not rep.exhausted, "libre : plafond de 5 essais atteint, balayage non fini")
  check(pl.next() == nil and pl.report().attempts == 5, "...et il reste atteint aux appels suivants")
  check(seen[1].x == 0 or seen[1].x == 1, "le premier essai est au plus près du centre")

  -- tout occupé : zéro essai, balayage fini
  local occ = {}
  for _, r in ipairs(ore) do
    for _, k in ipairs(P.tiles({ x = math.floor(r.x + 0.5), y = math.floor(r.y + 0.5) }, 2, 2)) do occ[k] = true end
  end
  local pl2 = P.new({ resources = ore, cap = 5, w = 2, h = 2, occupied = occ })
  check(pl2.next() == nil, "tout occupé : aucun emplacement")
  local r2 = pl2.report()
  check(r2.attempts == 0 and r2.exhausted and not r2.capped and r2.occupied > 0, "...zéro essai compté, balayage COMPLET (exhausted)")

  -- une tuile occupée en bout de liste ne consomme pas d'essai
  local pl3 = P.new({ resources = { { x = 0.5, y = 0.5 }, { x = 3.5, y = 0.5 }, { x = 6.5, y = 0.5 } }, cap = 2, w = 2, h = 2,
    occupied = set_of(P.tiles({ x = 4, y = 1 }, 2, 2)) })
  local a, b, c = pl3.next(), pl3.next(), pl3.next()
  check(a and b and not c and a.x == 1 and b.x == 7 and pl3.report().occupied == 1, "l'emplacement occupé du milieu est sauté sans coût")
  check(pl3.report().exhausted and not pl3.report().capped, "...balayage fini sans plafond (2 essais sur 2 permis, plus rien ensuite)")

  -- un même emplacement n'est essayé qu'une fois (deux tuiles voisines ne donnent pas la même position)
  local pl4 = P.new({ resources = { { x = 0.5, y = 0.5 }, { x = 0.5, y = 0.5 } }, cap = 9, w = 2, h = 2 })
  check(pl4.next() ~= nil and pl4.next() == nil and pl4.report().attempts == 1, "doublon : un seul essai")
end

section("5. Mémoire des échecs et reprise")
do
  local ore = P.sorted(disc(0, 0, 3), { x = 0, y = 0 })
  local dead = {}
  local calls, fails = 0, {}
  local last
  repeat
    calls = calls + 1
    local pl = P.new({ resources = ore, cap = 4, w = 2, h = 2, dead = dead })
    while true do
      local pos = pl.next()
      if not pos then break end
      fails[P.key(pos.x, pos.y)] = (fails[P.key(pos.x, pos.y)] or 0) + 1
      pl.fail(pos)
    end
    last = pl.report()
  until last.exhausted or calls > 50
  local twice = false
  for _, n in next, fails do if n > 1 then twice = true end end
  check(not twice, "un emplacement échoué n'est jamais réessayé d'un appel à l'autre")
  check(last.exhausted and calls > 1, "plafond 4 : plusieurs appels, puis balayage complet (" .. calls .. " appels)")
  check(last.dead > 0, "...les emplacements déjà échoués sont comptés à part")
  local total = 0
  for _ in next, fails do total = total + 1 end
  local expected = {}
  for _, r in ipairs(ore) do expected[P.key(math.floor(r.x + 0.5), math.floor(r.y + 0.5))] = true end
  check(total == count(expected), "tous les emplacements ont été essayés exactement une fois (" .. total .. ")")
end

section("6. Verdict : plein seulement par le plafond de foreuses ou un balayage complet")
do
  local v = P.verdict({ placed = 3, drills_after = 20, drills_max = 20, exhausted = false, capped = false })
  check(v.full and v.why == "plafond", "plafond de foreuses atteint : plein")
  v = P.verdict({ placed = 0, drills_after = 8, drills_max = 20, exhausted = true, capped = false })
  check(v.full and v.why == "gisement" and not v.fail, "balayage complet sans pose : plein (gisement saturé)")
  v = P.verdict({ placed = 2, drills_after = 10, drills_max = 20, exhausted = true, capped = false })
  check(v.full, "balayage complet après quelques poses : plein aussi (plus rien à poser)")
  v = P.verdict({ placed = 4, drills_after = 12, drills_max = 20, exhausted = false, capped = true })
  check(not v.full and not v.fail, "posé, plafond d'essais atteint : pas plein")
  v = P.verdict({ placed = 0, drills_after = 8, drills_max = 20, exhausted = false, capped = true })
  check(not v.full and v.fail and v.why == "essais", "RIEN posé, plafond d'essais atteint : PAS plein (c'était l'erreur d'origine), échec compté")
  v = P.verdict({ placed = 0, drills_after = 8, drills_max = 20, exhausted = false, capped = false, lacking = true })
  check(not v.full and not v.fail and v.why == "objets", "ouvrier sans foreuse ni four : pas plein, pas d'échec")
  v = P.verdict({ placed = 8, drills_after = 16, drills_max = 20, exhausted = false, capped = false })
  check(not v.full, "nombre voulu posé : pas plein")
end

section("7. Libellé d'un projet d'avant-poste")
do
  check(P.mode({ tasks = { { kind = "extend" } } }) == "extend", "tâche d'agrandissement : agrandir")
  check(P.mode({ tasks = { { kind = "build", lost = false } } }) == "build", "tâche de construction : nouvel avant-poste")
  check(P.mode({ tasks = { { kind = "build", lost = true } } }) == "rebuild", "construction sur un site perdu : reconstruire")
  check(P.mode({ tasks = { { kind = "build" }, { kind = "extend" } } }) == "extend", "agrandissement avant construction")
  check(P.mode({ tasks = {}, cause = "site:iron" }) == "build", "bloqué en quête de site : nouvel avant-poste")
  check(P.mode({ tasks = {}, cause = "", extendable = true }) == "extend", "sans tâche, un avant-poste peut grandir : agrandir")
  check(P.mode({ tasks = {}, cause = "" }) == nil and P.mode({}) == nil, "rien de précis : pas de libellé")
  check(P.mode({ tasks = { { kind = "service" } }, cause = "tourelles" }) == nil, "tâche d'un autre genre : pas de libellé")
end

---------------------------------------------------------------------------------------------------
section("8. Simulateur : l'ancienne règle bloque à l'agrandissement, la nouvelle remplit le gisement")
local OLD_STUCK, NEW_REACHED
do
  local center = { x = 0, y = 0 }
  local ore = disc(0, 0, 20)
  -- ancienne règle : construction (rayon 14, 8 voulues) puis agrandissements (rayon 18)
  local w_old = { occ = {} }
  local b_old = run_old(w_old, ore, center, 14, 8)
  local ext_old, att_old = 0, 0
  for _ = 1, 3 do
    local n, a = run_old(w_old, ore, center, 18, 8)
    ext_old, att_old = ext_old + n, att_old + a
  end
  check(b_old >= 3 and b_old <= 8, "ancienne règle : la construction pose " .. b_old .. " paire(s) (modèle simplifié ; l'audit lit 6 à 8 en jeu)")
  check(ext_old == 0 and att_old >= 40, "ancienne règle : 3 agrandissements, " .. ext_old .. " paire posée, " .. att_old .. " essais perdus (la cause de l'audit)")
  OLD_STUCK = ext_old == 0

  -- nouvelle règle : même construction, puis agrandissements jusqu'au plafond de foreuses (20 pour le fer)
  local w_new = { occ = {} }
  local o = {}
  local b_new = run_new(w_new, ore, center, 14, 8, o, false)
  check(b_new >= b_old, "nouvelle règle : la construction pose au moins autant (" .. b_new .. " contre " .. b_old .. ")")
  local drills, calls, every_call_posed, full = b_new, 0, true, false
  while drills < 20 and calls < 10 do
    calls = calls + 1
    local want = math.min(8, 20 - drills)
    local n, rep = run_new(w_new, ore, center, P.EXTEND_RADIUS, want, o, true)
    drills = drills + n
    if n == 0 then every_call_posed = false end
    local v = P.verdict({ placed = n, drills_after = drills, drills_max = 20, exhausted = rep.exhausted, capped = rep.capped })
    full = v.full
  end
  check(drills == 20 and every_call_posed, "nouvelle règle : " .. calls .. " agrandissement(s), " .. drills .. " foreuses, chaque appel pose au moins une paire")
  check(full, "...et l'avant-poste est plein parce qu'il est au plafond de 20")
  NEW_REACHED = drills == 20
  -- 20 paires = 160 tuiles sur ~1 250 : bien au-delà du « 8 foreuses pour toute la partie » mesuré
  check(drills >= 2.5 * b_old, "au moins 2,5 fois les foreuses d'avant (" .. drills .. " contre " .. b_old .. ")")
end

section("9. Simulateur : gisement saturé, obstacles, plafond d'essais")
do
  local center = { x = 0, y = 0 }
  -- petit gisement (rayon 4, ~50 tuiles) : il se remplit puis le balayage complet dit « plein »
  local ore = disc(0, 0, 4)
  local world, o = { occ = {} }, {}
  local drills, n_calls, verdict = 0, 0, nil
  repeat
    n_calls = n_calls + 1
    local n, rep = run_new(world, ore, center, P.EXTEND_RADIUS, 8, o, true)
    drills = drills + n
    verdict = P.verdict({ placed = n, drills_after = drills, drills_max = 20, exhausted = rep.exhausted, capped = rep.capped })
  until verdict.full or n_calls > 10
  check(verdict.full and verdict.why == "gisement" and drills > 0 and drills < 20, "petit gisement : " .. drills .. " paire(s) puis « plein » par balayage complet")
  local again, rep = run_new(world, ore, center, P.EXTEND_RADIUS, 8, {}, true)
  check(again == 0 and rep.exhausted and rep.attempts <= 10, "...un nouveau balayage ne pose rien et coûte peu d'essais (" .. rep.attempts .. ")")

  -- obstacles (eau) sur la moitié du gisement : posé là où c'est possible, jamais plein à tort
  local blocked = {}
  for ty = -20, 20 do for tx = -20, 20 do if tx >= 0 then blocked[P.key(tx, ty)] = true end end end
  local big = disc(0, 0, 20)
  local w2, o2 = { occ = {}, blocked = blocked }, {}
  local total, calls, stopped = 0, 0, false
  while calls < 40 do
    calls = calls + 1
    local n, rep = run_new(w2, big, center, P.EXTEND_RADIUS, math.min(8, 20 - total), o2, true)
    total = total + n
    local v = P.verdict({ placed = n, drills_after = total, drills_max = 20, exhausted = rep.exhausted, capped = rep.capped })
    if v.full then stopped = true break end
  end
  check(stopped and total == 20, "moitié du gisement sous l'eau : 20 foreuses posées sur l'autre moitié (" .. total .. " en " .. calls .. " appels)")

  -- tout bloqué : aucun emplacement ne passe, plafond d'essais de 10 : plusieurs appels, aucun « plein » avant le balayage complet
  local all_blocked = {}
  for ty = -10, 10 do for tx = -10, 10 do all_blocked[P.key(tx, ty)] = true end end
  local w3, o3 = { occ = {}, blocked = all_blocked }, {}
  local seq, ended = {}, nil
  for i = 1, 60 do
    local n, rep = run_new(w3, disc(0, 0, 5), center, P.EXTEND_RADIUS, 8, o3, true, 10)
    local v = P.verdict({ placed = n, drills_after = 0, drills_max = 20, exhausted = rep.exhausted, capped = rep.capped })
    seq[#seq + 1] = v.why
    if v.full then ended = i break end
  end
  local premature = false
  for i = 1, #seq - 1 do if seq[i] ~= "essais" then premature = true end end
  check(ended and ended > 1 and not premature and seq[#seq] == "gisement",
    "tout bloqué, plafond 10 : " .. tostring(ended) .. " appels, « essais » puis « gisement » (jamais plein avant le balayage complet)")
end

section("10. Pas de pairs, pas de nom d'objet, pas de hasard dans la règle pure ; l'exécutant l'emploie")
do
  local f = io.open("shared/team/pose_paires.lua", "r")
  local src = f:read("*a")
  f:close()
  local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:gsub("ipairs%(", ""):find("pairs%("), "aucun appel à pairs")
  check(not code:find("burner") and not code:find("iron%-") and not code:find("stone%-furnace") and not code:find("math%.random")
    and not code:find("math%.sin") and not code:find("math%.cos") and not code:find("game%.tick"),
    "aucun nom d'objet du jeu, aucun hasard, aucune trigonométrie, aucun temps")
  local g = io.open("script/faction/outposts.lua", "r")
  local out = g:read("*a")
  g:close()
  check(out:find("Paires%.verdict", 1) and out:find("Paires%.new", 1) and out:find("%[FO%-EXTEND%]", 1),
    "script/faction/outposts.lua emploie le parcours et le verdict, et écrit [FO-EXTEND]")
  check(not out:find("if #drills == 0 or o%.drills >= T%.max_drills"), "l'ancien « plein si rien posé » a disparu de l'agrandissement")
  check(not out:find("local MAX_ATTEMPTS"), "l'ancien plafond d'essais global (tuiles occupées comprises) a disparu")
end

---------------------------------------------------------------------------------------------------
section("11. MUTANTS (chacun doit faire échouer la scène de référence)")
do
  -- Scène de référence : agrandissements d'un gisement de rayon 20 jusqu'au plafond de 20, puis petit gisement saturé, puis
  -- verdicts. Rend vrai quand TOUT est conforme.
  local function reference()
    local center = { x = 0, y = 0 }
    local ore = disc(0, 0, 20)
    local world, o = { occ = {} }, {}
    local drills, rep0 = run_new(world, ore, center, 14, 8, o, false)
    local calls, attempts = 0, rep0.attempts
    local ok = true
    while drills < 20 and calls < 10 do
      calls = calls + 1
      local n, rep = run_new(world, ore, center, P.EXTEND_RADIUS, math.min(8, 20 - drills), o, true)
      if n == 0 then ok = false end
      attempts = attempts + rep.attempts
      drills = drills + n
      local v = P.verdict({ placed = n, drills_after = drills, drills_max = 20, exhausted = rep.exhausted, capped = rep.capped })
      if v.full and drills < 20 then ok = false end
    end
    if drills ~= 20 then ok = false end
    if attempts > 70 then ok = false end -- 60 mesurés : un emplacement proposé se pose presque toujours (3 essais par paire au plus)
    -- gisement voisin : ne doit pas être pris
    local both = {}
    for _, r in ipairs(disc(0, 0, 4)) do both[#both + 1] = r end
    for _, r in ipairs(disc(28, 0, 4)) do both[#both + 1] = r end
    local w2 = { occ = {} }
    local n2 = 0
    local o2 = {}
    for _ = 1, 12 do
      local n = run_new(w2, both, center, P.EXTEND_RADIUS, 8, o2, true)
      n2 = n2 + n
    end
    local took_far = false
    for ty = -6, 6 do for tx = 24, 34 do if w2.occ[P.key(tx, ty)] then took_far = true end end end
    if took_far or n2 == 0 then ok = false end
    -- tout bloqué : jamais « plein » avant le balayage complet
    local blocked = {}
    for ty = -10, 10 do for tx = -10, 10 do blocked[P.key(tx, ty)] = true end end
    local w3, o3 = { occ = {}, blocked = blocked }, {}
    local premature, ended = false, false
    for i = 1, 60 do
      local n, rep = run_new(w3, disc(0, 0, 5), center, P.EXTEND_RADIUS, 8, o3, true, 10)
      local v = P.verdict({ placed = n, drills_after = 0, drills_max = 20, exhausted = rep.exhausted, capped = rep.capped })
      if v.full then ended = i > 1 break end
      if v.why ~= "essais" then premature = true end
    end
    if premature or not ended then ok = false end
    -- verdicts
    if P.verdict({ placed = 0, drills_after = 8, drills_max = 20, capped = true }).full then ok = false end
    if P.verdict({ placed = 0, drills_after = 8, drills_max = 20, lacking = true }).full then ok = false end
    if not P.verdict({ placed = 0, drills_after = 8, drills_max = 20, exhausted = true }).full then ok = false end
    if not P.verdict({ placed = 1, drills_after = 20, drills_max = 20 }).full then ok = false end
    return ok
  end
  check(reference(), "la scène de référence passe sur la règle non mutée")

  local function kill(name, mutate)
    local saved = {}
    for _, k in ipairs({ "new", "verdict", "component", "sorted", "tiles", "box_tiles", "MAX_ATTEMPTS", "EXTEND_RADIUS", "GAP", "SEED_MAX" }) do saved[k] = P[k] end
    local ok_run, ok = pcall(function() mutate(); return reference() end)
    for k, v in pairs(saved) do P[k] = v end
    check(not (ok_run and ok), "mutant refusé : " .. name)
  end
  local new, verdict, component, sorted, tiles = P.new, P.verdict, P.component, P.sorted, P.tiles

  kill("emplacements occupés non écartés (ancienne règle)", function()
    P.new = function(spec) spec.occupied = {}; return new(spec) end
  end)
  kill("emplacements échoués non mémorisés", function()
    P.new = function(spec) spec.dead = {}; return new(spec) end
  end)
  kill("plafond d'essais supprimé", function()
    P.new = function(spec) spec.cap = math.huge; return new(spec) end
  end)
  kill("plafond d'essais réduit à 1", function()
    P.new = function(spec) spec.cap = 1; return new(spec) end
  end)
  kill("plein dès que le plafond d'essais est atteint", function()
    P.verdict = function(v) local r = verdict(v); if v.capped then r.full = true end; return r end
  end)
  kill("plein dès que rien n'est posé (ancienne règle)", function()
    P.verdict = function(v) local r = verdict(v); if v.placed == 0 and not v.lacking then r.full = true end; return r end
  end)
  kill("plein même sans objets", function()
    P.verdict = function(v) local r = verdict(v); if v.lacking then r.full = true end; return r end
  end)
  kill("jamais plein au plafond de foreuses", function()
    P.verdict = function(v) v.drills_max = math.huge; return verdict(v) end
  end)
  kill("balayage complet jamais dit plein", function()
    P.verdict = function(v) v.exhausted = false; return verdict(v) end
  end)
  kill("gisement voisin pris (composante ignorée)", function()
    P.component = function(list) return list end
  end)
  kill("trous du gisement non franchis (jointure à 0)", function()
    P.component = function(list, _, center) return component(list, -1, center) end
  end)
  kill("tri inversé (le plus loin d'abord)", function()
    P.sorted = function(res, center)
      local out = sorted(res, center)
      local rev = {}
      for i = #out, 1, -1 do rev[#rev + 1] = out[i] end
      return rev
    end
  end)
  kill("emprise réduite à une tuile", function()
    P.tiles = function(pos, w, h) return tiles(pos, 1, 1) end
  end)
  kill("emprise décalée d'une tuile", function()
    P.tiles = function(pos, w, h) return tiles({ x = pos.x + 1, y = pos.y }, w, h) end
  end)
end

---------------------------------------------------------------------------------------------------
section("12. Lot PLAFOND-FOREUSES : plus de plafond, la couverture P.KAPPA (= Ca.KAPPA) et le balayage complet arrêtent seuls")
do
  local Ca = require("shared.ai3.capitalisation")
  local T = require("shared.team.config")
  check(P.KAPPA == Ca.KAPPA, "P.KAPPA = Ca.KAPPA (" .. P.KAPPA .. ", " .. Ca.KAPPA .. ")")
  check(T.max_drills("iron") == math.huge and T.max_drills("copper") == math.huge and T.max_drills("coal") == math.huge
    and T.max_drills("stone") == math.huge, "T.max_drills : l'infini pour tous les minerais")
  -- verdict sans plafond : 500 foreuses, pas plein ; drills_max absent accepté
  local v = P.verdict({ placed = 8, drills_after = 500, drills_max = T.max_drills("iron"), covered = 100, tiles = 1000 })
  check(not v.full and v.why == "pose", "500 foreuses, 10 % couvert : pas plein (" .. v.why .. ")")
  v = P.verdict({ placed = 8, drills_after = 500, covered = 799, tiles = 1000 })
  check(not v.full, "79,9 % : pas plein (drills_max absent)")
  v = P.verdict({ placed = 8, drills_after = 500, covered = 800, tiles = 1000 })
  check(v.full and v.why == "couverture", "80 % : plein, motif « couverture »")
  v = P.verdict({ placed = 0, drills_after = 0, covered = 0, tiles = 0, capped = true })
  check(not v.full and v.why == "essais", "aucune tuile lue : jamais plein par la couverture")
  check(P.permille(1, 3) == 333 and P.permille(5, 0) == 0 and P.permille(nil, 10) == 0, "permille entier, sans division par zéro")
  -- report().covered : tuiles du parcours minées (spec.mined puis pl.cover)
  local res = { { x = 0.5, y = 0.5 }, { x = 1.5, y = 0.5 }, { x = 2.5, y = 0.5 }, { x = 3.5, y = 0.5 } }
  local pl = P.new({ resources = res, mined = set_of({ P.key(0, 0) }) })
  check(pl.report().covered == 1 and pl.report().tiles == 4, "couverture lue depuis spec.mined (1 sur 4)")
  pl.cover({ P.key(1, 0), P.key(2, 0), P.key(9, 9) })
  check(pl.report().covered == 3, "pl.cover compte les tuiles du gisement seulement (3 sur 4)")
  check(P.new({ resources = res }).report().covered == 0, "sans spec.mined : 0")
  -- mutants de la couverture
  local verdict, permille = P.verdict, P.permille
  local function ref()
    return P.verdict({ placed = 8, drills_after = 500, covered = 800, tiles = 1000 }).full
      and not P.verdict({ placed = 8, drills_after = 500, covered = 799, tiles = 1000 }).full
      and not P.verdict({ placed = 8, drills_after = 500, drills_max = math.huge, covered = 10, tiles = 1000 }).full
  end
  check(ref(), "référence de la couverture")
  local function kill2(name, mutate)
    local sk, sp = P.KAPPA, P.permille
    mutate()
    local ok_run, ok = pcall(ref)
    P.KAPPA, P.permille, P.verdict = sk, sp, verdict
    check(not (ok_run and ok), "mutant refusé : " .. name)
  end
  kill2("couverture ignorée", function() P.permille = function() return 0 end end)
  kill2("seuil à 0 (plein dès la première foreuse)", function() P.KAPPA = 0 end)
  kill2("plafond de 20 rétabli", function() P.verdict = function(x) x.drills_max = 20 return verdict(x) end end)
  kill2("seuil à 100 %", function() P.KAPPA = 1000 end)
  check(P.permille == permille, "règle restaurée")
end

print(string.format("[POSE-PAIRES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
