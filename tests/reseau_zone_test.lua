--[[
  Lot UPS-2 (sprint du DC, 10/11) : le relevé du réseau vivant (script/team/reseau_vivant.lua, par tranches de chunks) ne cherche plus
  que dans la ZONE de l'équipe (script/team/zone_equipe.lua, F470) : intersections de chaque tranche avec la zone (Ze.clip).
    §1 Zone qui couvre toutes les entités de l'équipe : même relevé (îlots, sans poteau, réseaux des îlots, réseaux vivants) que sans zone,
       sur 120 mondes tirés d'une graine, tranches de 1 à 3 chunks et toute la largeur.
    §2 Une entité vue par deux intersections (deux rectangles qui la touchent) n'est comptée qu'une fois.
    §3 Les tranches hors zone ne cherchent plus rien ; le nombre de tranches et le coût DÉCLARÉ au jeton (Rv.cout) sont inchangés.
    §4 Rv.zone : nil (toute la tranche) quand un joueur humain est connecté à la force, ou sans plan ni QG ; la zone sinon.
    §5 Câblage : les deux débuts de relevé de Rv.step passent la zone.
    §6 Mutants (source changée, rechargée) : chacun doit être vu.
  Lancer : lua5.2 tests/reseau_zone_test.lua
]]
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local quiet = false
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 if not quiet then print("  ECHEC : " .. msg) end end end
local function slurp(path) local fh = assert(io.open(path, "rb")) local s = fh:read("*a") fh:close() return s end

log = function() end
defines = defines or {}
defines.events = defines.events or { on_chunk_generated = 34 }
local FORCES = { ["fo-test"] = { connected_players = {} } }
game = { entity_prototypes = {}, tick = 0, forces = FORCES }

local zone_answer = nil
package.loaded["script.core.events"] = { on = function() end, on_init = function() end, on_configuration_changed = function() end }
package.loaded["script.core.storage"] = { declare = function() end, ns = function() return {} end }

local function mutated(path, subs)
  local src = slurp(path)
  for _, x in ipairs(subs or {}) do
    local a, b = src:find(x[1], 1, true)
    assert(a, "mutant : texte absent : " .. x[1])
    assert(not src:find(x[1], b + 1, true), "mutant : texte present plusieurs fois : " .. x[1])
    src = src:sub(1, a - 1) .. x[2] .. src:sub(b + 1)
  end
  return src
end

local function load_rv(subs)
  package.loaded["script.team.reseau_vivant"] = nil
  package.preload["script.team.reseau_vivant"] = nil
  package.loaded["script.team.zone_equipe"] = { rects = function() return zone_answer end }
  if subs then
    local src = mutated("script/team/reseau_vivant.lua", subs)
    package.preload["script.team.reseau_vivant"] = function(name) return assert(load(src, "=reseau_vivant"))(name) end
  end
  return require("script.team.reseau_vivant")
end

---------------------------------------------------------------------------------------------------
-- Monde simulé (la recherche par zone rend ce qui TOUCHE la zone, F96) ; chaque entité a son unit_number
---------------------------------------------------------------------------------------------------
local function new_world() return { ents = {}, searches = 0, area = 0, next_u = 1 } end
local function add(w, e)
  e.valid = true
  e.unit_number = w.next_u
  w.next_u = w.next_u + 1
  local hw, hh = e.hw or 0.5, e.hh or 0.5
  e.box = { e.position.x - hw, e.position.y - hh, e.position.x + hw, e.position.y + hh }
  e.prototype = { electric_energy_source_prototype = e.consumer and {} or nil }
  w.ents[#w.ents + 1] = e
  return e
end
local function has_type(t, ty)
  if t == nil then return true end
  if type(t) == "string" then return t == ty end
  for _, x in ipairs(t) do if x == ty then return true end end
  return false
end
local function surface_of(w)
  return { find_entities_filtered = function(q)
    w.searches = w.searches + 1
    if q.area then w.area = w.area + (q.area[2][1] - q.area[1][1]) * (q.area[2][2] - q.area[1][2]) end
    local out = {}
    for _, e in ipairs(w.ents) do
      if e.valid and (q.force == nil or e.force == q.force) and has_type(q.type, e.type) then
        local a = q.area
        if not a or (e.box[1] <= a[2][1] and e.box[3] >= a[1][1] and e.box[2] <= a[2][2] and e.box[4] >= a[1][2]) then out[#out + 1] = e end
      end
    end
    return out
  end }
end
local function ent(type_, x, y, o)
  o = o or {}
  return { name = type_, type = type_, position = { x = x, y = y }, consumer = o.consumer, electric_network_id = o.net, hw = o.hw, hh = o.hh,
    force = o.force or "fo-test" }
end
local function lcg(seed)
  local st = seed
  return function(n) st = (st * 1103515245 + 12345) % 2147483648 return math.floor(st / 65536) % n + 1 end
end
local SIZES = { { "inserter", 0.15 }, { "furnace", 1.5 }, { "assembling-machine", 1.5 }, { "mining-drill", 1.5 }, { "lab", 1.5 } }
local function random_world(seed)
  local r = lcg(seed)
  local w = new_world()
  local nlive = r(4)
  for k = 1, nlive do add(w, ent("generator", r(200) - 100 + 0.5, (r(9) - 5) * 32 + ({ 0, 0.5, 31.5, 16 })[r(4)], { net = k + 1, hw = 1.5, hh = 2.5 })) end
  for _ = 1, 20 + r(80) do
    local sz = SIZES[r(#SIZES)]
    local y = (r(9) - 5) * 32 + ({ 0, 0.5, 1.5, 15.5, 30.5, 31.5, 32, 16 })[r(8)]
    local x = r(300) - 150 + ({ 0, 0.5 })[r(2)]
    local net
    local pick = r(10)
    if pick <= 4 then net = r(nlive) + 1 elseif pick <= 7 then net = 10 + r(5) elseif pick <= 8 then net = 1 end
    add(w, ent(sz[1], x, y, { net = net, consumer = r(6) > 1, hw = sz[2], hh = sz[2] }))
  end
  for _ = 1, 10 do add(w, ent("assembling-machine", r(300) - 150, r(200) - 100, { net = 99, consumer = true, force = "autre" })) end
  return w
end
local function box_of(w)
  local b
  for _, e in ipairs(w.ents) do
    local cx, cy = math.floor(e.position.x / 32), math.floor(e.position.y / 32)
    if b then b.x0, b.x1, b.y0, b.y1 = math.min(b.x0, cx), math.max(b.x1, cx), math.min(b.y0, cy), math.max(b.y1, cy)
    else b = { x0 = cx, y0 = cy, x1 = cx, y1 = cy } end
  end
  b.y0 = b.y0 - 2 -- (lignes vides en haut : des tranches sans rien)
  return b
end
local function keys_str(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = tostring(k) end
  table.sort(ks)
  return table.concat(ks, ",")
end
local function nr_str(nr) return string.format("i%d u%d n[%s] l[%s]", nr.islands, nr.uncovered, keys_str(nr.nets), keys_str(nr.live)) end
local F = { key = "rnd", force = "fo-test", build = { order = {}, projects = {} } }

local function banded(Rv, sfc, box, rects)
  local j = Rv.bandes.new(box, rects)
  local n, guard = 0, 0
  repeat
    local done = Rv.bandes.band(F, sfc, j)
    n = n + 1
    guard = guard + 1
  until done or guard > 100000
  return Rv.bandes.finish(F.build, j), n, j
end

--- Rectangles de tuiles qui couvrent toutes les entités de l'équipe (une boîte par entité + 3 tuiles, fusionnées par la règle pure).
local Ze = require("shared.team.zone_equipe")
local function cover(w)
  local rs = {}
  for _, e in ipairs(w.ents) do
    if e.force == "fo-test" then
      rs[#rs + 1] = { x0 = math.floor(e.box[1]) - 3, y0 = math.floor(e.box[2]) - 3, x1 = math.ceil(e.box[3]) + 3, y1 = math.ceil(e.box[4]) + 3 }
    end
  end
  return Ze.merge(rs)
end

local function battery(Rv)
  local saved = Rv.COLS
  -- §1 zone qui couvre tout : même relevé
  local diffs, runs, fewer, more = 0, 0, 0, 0
  for seed = 1, 120 do
    local w = random_world(seed)
    local sfc = surface_of(w)
    local box = box_of(w)
    local rects = cover(w)
    for _, cols in ipairs({ 1, 2, 3, math.huge }) do
      Rv.COLS = cols
      w.area = 0
      local want, n0 = banded(Rv, sfc, box, nil)
      local s0 = w.area
      w.area = 0
      local got, n1 = banded(Rv, sfc, box, rects)
      runs = runs + 1
      if nr_str(got) ~= nr_str(want) or n1 ~= n0 then diffs = diffs + 1 end
      if w.area < s0 then fewer = fewer + 1 end
      if w.area > s0 then more = more + 1 end
    end
  end
  Rv.COLS = saved
  check(diffs == 0, string.format("§1 zone couvrante : même relevé et même nombre de tranches que sans zone (%d écart(s) sur %d)", diffs, runs))
  check(more == 0 and fewer > runs / 2, string.format("§1 surface parcourue par le moteur : plus petite avec la zone dans %d relevés sur %d, jamais plus grande (%d)", fewer, runs, more))
  -- §2 une entité touchée par deux rectangles : comptée une fois
  local w = new_world()
  add(w, ent("generator", 500.5, 500.5, { net = 2, hw = 1.5, hh = 1.5 }))
  add(w, ent("assembling-machine", 10.5, 10.5, { net = 7, consumer = true, hw = 1.5, hh = 1.5 }))
  local sfc = surface_of(w)
  local box = { x0 = 0, y0 = 0, x1 = 15, y1 = 15 }
  local two = { { x0 = 0, y0 = 0, x1 = 10, y1 = 40 }, { x0 = 11, y0 = 0, x1 = 40, y1 = 40 } }
  Rv.COLS = math.huge
  local nr = banded(Rv, sfc, box, two)
  check(nr.islands == 1, "§2 machine à cheval sur deux rectangles : un seul îlot (" .. tostring(nr.islands) .. ")")
  -- §3 tranches hors zone : aucune recherche ; tranches et coût déclaré inchangés
  Rv.COLS = 2
  local w3 = random_world(7)
  local s3 = surface_of(w3)
  local b3 = box_of(w3)
  w3.searches = 0
  local _, n_full = banded(Rv, s3, b3, nil)
  local full = w3.searches
  w3.searches = 0
  local tiny = { { x0 = b3.x0 * 32, y0 = b3.y0 * 32, x1 = b3.x0 * 32 + 10, y1 = b3.y0 * 32 + 10 } }
  local _, n_tiny = banded(Rv, s3, b3, tiny)
  check(n_tiny == n_full and w3.searches == 1 and full == n_full, string.format("§3 zone d'un coin : %d recherche(s) au lieu de %d, mêmes %d tranches",
    w3.searches, full, n_tiny))
  local ja, jb = Rv.bandes.new(b3, nil), Rv.bandes.new(b3, tiny)
  local same = true
  for _ = 1, 40 do
    if Rv.cout(ja) ~= Rv.cout(jb) then same = false end
    local da = Rv.bandes.band(F, s3, ja)
    local db = Rv.bandes.band(F, s3, jb)
    if da ~= db then same = false end
    if da then break end
  end
  check(same, "§3 coût déclaré au jeton (Rv.cout) et fin du relevé identiques avec et sans zone")
  local stored = Rv.bandes.new(b3, tiny)
  tiny[1].x1 = tiny[1].x1 + 1000
  check(stored.rects[1].x1 == b3.x0 * 32 + 10 and stored.rects[1] ~= tiny[1], "§3 la zone est copiée dans l'état du relevé (nombres seulement)")
  Rv.COLS = saved
  -- §4 Rv.zone
  zone_answer = { { x0 = 1, y0 = 2, x1 = 3, y1 = 4 } }
  FORCES["fo-test"].connected_players = {}
  check(Rv.zone(F, nil, 0) == zone_answer, "§4 force sans joueur connecté : la zone de l'équipe")
  FORCES["fo-test"].connected_players = { {} }
  check(Rv.zone(F, nil, 0) == nil, "§4 joueur humain connecté : nil (toute la tranche : ses machines hors plan restent comptées)")
  FORCES["fo-test"].connected_players = {}
  zone_answer = nil
  check(Rv.zone(F, nil, 0) == nil, "§4 sans plan ni QG : nil")
  check(Rv.zone({ key = "x", force = "inconnue", build = {} }, nil, 0) == nil, "§4 force inconnue : nil")
end

local Rv0 = load_rv(nil)
battery(Rv0)

-- §5 câblage
local src = slurp("script/team/reseau_vivant.lua")
check(src:find("sv.nr_job = job_new(box, Rv.zone(f, surface, tick))", 1, true) ~= nil, "§5 relevé périodique : la zone est passée")
check(src:find("sv.nr_job = job_new(rbox, Rv.zone(f, surface, tick))", 1, true) ~= nil, "§5 relevé de la décision « relier » : la zone est passée")
check(src:find('Rv.cout(j)', 1, true) ~= nil and not src:find("j.rects", src:find("function Rv.cout", 1, true), true) or
  (src:find("j.rects", src:find("function Rv.cout", 1, true), true) or 0) > (src:find("local function job_step", 1, true) or 0),
  "§5 Rv.cout ne lit pas la zone (coût déclaré inchangé)")

-- §6 mutants
local function mutant(label, subs)
  local Rv = load_rv(subs)
  local f0 = fail_n
  quiet = true
  local ok = pcall(battery, Rv)
  quiet = false
  local caught = fail_n > f0 or not ok
  fail_n = f0
  check(caught, "mutant refusé : " .. label)
end
mutant("doublons non écartés", { { "if not (u and seen[u]) then", "if true then" } })
mutant("zone ignorée (toute la tranche)", { { "  if j.rects then\n    -- lot UPS-2", "  if false then\n    -- lot UPS-2" } })
mutant("zone non rangée dans l'état", { { "rects = zr }", "rects = nil }" } })
mutant("joueur humain ignoré", { { "if not force or #force.connected_players > 0 then return nil end", "if not force then return nil end" } })
mutant("intersection remplacée par la zone entière", { { "Ze.clip(j.rects, { x0 = left, y0 = top, x1 = right, y1 = bottom })", "j.rects" } })
mutant("zone stockée par référence", { { "zr[i] = { x0 = r.x0, y0 = r.y0, x1 = r.x1, y1 = r.y1 }", "zr[i] = r" } })

print(string.format("[RESEAU-ZONE] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
