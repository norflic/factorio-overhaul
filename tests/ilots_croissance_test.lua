--[[
  Lot C3 EXTENSION, point 4 : le treillis grandit au-delà du mur, en îlots défendus (shared/team/ilots_croissance.lua, règle pure, et son
  branchement : Build.beyond_step de script/team/build.lua, texte extrait entre deux repères comme tests/ilots_flux_test.lua, avec des
  bouchons du moteur ; aucun banc moteur).
    §1 règle : ouverture (enceinte complète à contour serré), nombre d'îlots selon l'effectif, plafond de tourelles, porte (menace, chantier
       du mur, chantier dehors, îlot sans mur, îlot sans tourelles, plafond), croissance (place libre, chantiers, rayon maximal, rien de fini) ;
    §2 lots : rendus quand la porte s'ouvre (seulement ceux ENTIÈREMENT dehors), repris quand elle se ferme (jamais un lot pris) ;
    §3 flux : la boucle de Build.beyond_step (porte, lots, croissance d'un anneau, journal [FO-EXTENSION] une ligne par changement) ;
    §4 déterminisme ; MUTANTS.
  Usage : lua5.2 tests/ilots_croissance_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local I = require("shared.team.ilots")
local P = require("shared.team.plan")

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/ilots_croissance.lua")
local BUILD_SRC = read("script/team/build.lua")

local function load_ic(src)
  local fn, err = load(src, "=ilots_croissance", "t")
  if not fn then return nil, err end
  local ok, mod = pcall(fn)
  if not ok then return nil, mod end
  return mod
end

local lat = P.lattice({ x = 339.5, y = 339.5 })
-- contour serré : 3 x 3 lots autour du QG (rayon 1 + marges), tuiles du mur incluses
local x0, y0, x1, y1 = P.lot_rect(lat, -1, -1)
local _, _, x2, y2 = P.lot_rect(lat, 1, 1)
local BOUNDS = { x0 - 4, y0 - 4, x2 + 3, y2 + 3 }

local function lot_row(i, j, o)
  local a, b, c, d = P.lot_rect(lat, i, j)
  local r = { k = P.lot_key(i, j), out = false, used = false, free = true, busy = false, x0 = a, y0 = b, x1 = c, y1 = d }
  for k, v in next, o or {} do r[k] = v end
  return r
end

local function suite(Ic, BUILD)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end

  -- §1 Règle.
  check(Ic.open({ bounds = BOUNDS, complete = true }) and not Ic.open({ bounds = BOUNDS, complete = false })
    and not Ic.open({ complete = true }) and not Ic.open(nil), "§1 ouverture : enceinte complète ET contour serré")
  check(Ic.max_islands(0) == I.MAX and Ic.max_islands(8) == I.MAX and Ic.max_islands(30) == I.MAX + 3 and Ic.max_islands(1000) == Ic.ISLANDS_MAX,
    "§1 îlots au plus : 4 à 8 PNJ, 7 à 30, plafond " .. Ic.ISLANDS_MAX)
  check(Ic.team_turrets(0) == I.TEAM_MAX and Ic.team_turrets(7) == 14 and Ic.team_turrets(2) == I.TEAM_MAX, "§1 plafond de tourelles des îlots : 8 au moins, 2 par îlot sinon")
  local base = { islands = 1, max = 4, unwalled = 0, unguarded = 0, threatened = false, main_busy = false, outside_busy = 0 }
  local function with(o)
    local t = {}
    for k, v in next, base do t[k] = v end
    for k, v in next, o do t[k] = v end
    return t
  end
  check(Ic.gate(base), "§1 porte ouverte : îlots murés et gardés, rien en cours")
  local ok, why = Ic.gate(with({ threatened = true }))
  check(not ok and why == "menace", "§1 porte : menace")
  ok, why = Ic.gate(with({ main_busy = true }))
  check(not ok and why == "enceinte en cours", "§1 porte : segment de l'enceinte en cours")
  ok, why = Ic.gate(with({ outside_busy = 2 }))
  check(not ok and why == "chantier hors du mur", "§1 porte : deux chantiers dehors")
  check(Ic.gate(with({ outside_busy = 1 })), "§1 porte : un chantier dehors est toléré")
  ok, why = Ic.gate(with({ unwalled = 1 }))
  check(not ok and why == "ilot sans mur", "§1 porte : îlot sans mur complet")
  ok, why = Ic.gate(with({ unguarded = 1 }))
  check(not ok and why == "ilot sans tourelles", "§1 porte : îlot sous sa cible de tourelles")
  ok, why = Ic.gate(with({ islands = 4 }))
  check(not ok and why == "plafond d'ilots", "§1 porte : plafond d'îlots")
  local grow = with({ radius = 5, rmax = 12, pending = 0, free = 0, busy = 0, done = 10 })
  check(Ic.grow_due(grow), "§1 croissance : plus de lot libre, porte ouverte")
  local function not_due(o, reason)
    local t = {}
    for k, v in next, grow do t[k] = v end
    for k, v in next, o do t[k] = v end
    local d, w = Ic.grow_due(t)
    check(not d and w == reason, "§1 croissance refusée (" .. reason .. ") : " .. tostring(w))
  end
  not_due({ free = 3 }, "place libre")
  not_due({ radius = 12 }, "rayon maximal")
  not_due({ pending = 4 }, "evaluation en cours")
  not_due({ busy = 3 }, "chantiers en cours")
  not_due({ done = 0 }, "rien de fini")
  not_due({ unwalled = 1 }, "ilot sans mur")
  not_due({ threatened = true }, "menace")

  -- §2 Lots.
  local rows = {
    lot_row(0, 0),                                     -- dedans
    lot_row(4, 0, { out = true }),                     -- dehors, écarté : rendu quand la porte s'ouvre
    lot_row(0, 4, { out = true, used = true }),        -- dehors, écarté, pris : rendu aussi (le drapeau ne sert plus), jamais repris
    lot_row(-4, 0, { out = false, free = true }),      -- dehors, libre, non écarté (lot de croissance) : repris quand la porte se ferme
    lot_row(-4, 4, { out = false, used = true }),      -- dehors, pris : jamais repris
    lot_row(2, 0, { out = true }),                     -- collé au contour (écart < 3) : jamais touché
  }
  local freed, parked = Ic.release(rows, BOUNDS, true)
  check(#freed == 2 and freed[1] == rows[2].k and freed[2] == rows[3].k and #parked == 0, "§2 porte ouverte : les lots écartés ENTIÈREMENT dehors sont rendus (" .. #freed .. ")")
  freed, parked = Ic.release(rows, BOUNDS, false)
  check(#freed == 0 and #parked == 1 and parked[1] == rows[4].k, "§2 porte fermée : seul le lot libre, dehors, non pris, non écarté est repris (" .. #parked .. ")")
  freed, parked = Ic.release(rows, nil, true)
  check(#freed == 0 and #parked == 0, "§2 sans contour serré : rien")
  check(Ic.count_busy({ lot_row(4, 0, { busy = true }), lot_row(0, 0, { busy = true }), lot_row(0, 4, { busy = false }) }, BOUNDS) == 1,
    "§2 chantiers dehors : seuls ceux entièrement dehors comptent")

  -- §3 Flux : Build.beyond_step du vrai build.lua.
  local a = assert(BUILD_SRC:find("--- Lot C3 EXTENSION (audit n°11 et 12, PLAN D4)", 1, true), "repere de debut absent")
  local b_ = assert(BUILD_SRC:find("--- Segment d'enceinte en cours", 1, true), "repere de fin absent")
  local chunk_src = BUILD_SRC:sub(a, b_ - 1)
  local LOGS, GROWN, DONE = {}, {}, 10
  local Build = {}
  function Build.beyond_wall(b) return b.enc ~= nil and Ic.open(b.enc) end
  Build.RADIUS_ORE = 12
  function Build.grow(_, r, cap) GROWN[#GROWN + 1] = r GROWN.cap = cap end
  local ISL = { n = 0, unwalled = 0, unguarded = 0 }
  local env = { Build = Build, Ilots = { state = function() return ISL end }, Ic = Ic, P = P, ipairs = ipairs, string = string, tostring = tostring,
    sorted_keys = function(t) local k = {} for x in next, t do k[#k + 1] = x end table.sort(k) return k end,
    ACTIVE = { chantier = true, plan = true },
    space_info = function(bb)
      local free = 0
      for _, l in next, bb.lots do if not l.out and (l.state == "libre") then free = free + 1 end end
      return { radius = bb.radius, rmax = 5, pending = 0, free = free, busy = 0, done = DONE }
    end,
    log = function(t) LOGS[#LOGS + 1] = t end }
  local chunk = assert(load("local Build, Ilots, Ic, P, ipairs, string, tostring, sorted_keys, ACTIVE, space_info, log = Build, Ilots, Ic, P, ipairs, string, tostring, sorted_keys, ACTIVE, space_info, log\n"
    .. chunk_src .. "\nreturn Build", "beyond_step", "t", setmetatable(env, { __index = _G })))
  chunk()
  local function make()
    local bb = { lat = lat, lots = {}, projects = {}, radius = 5, enc = { bounds = BOUNDS, complete = true, r = 5 } }
    for i = -5, 5 do
      for j = -5, 5 do
        local x0_, y0_, x1_, y1_ = P.lot_rect(lat, i, j)
        local inside = x0_ >= BOUNDS[1] and y0_ >= BOUNDS[2] and x1_ <= BOUNDS[3] + 1 and y1_ <= BOUNDS[4] + 1
        bb.lots[P.lot_key(i, j)] = { i = i, j = j, state = "libre", out = (not inside) or nil }
      end
    end
    return bb
  end
  local f = { key = "Azure", engineers_count = 12 }
  local bb = make()
  Build.beyond_step(f, bb, bb.enc, 3600, false)
  local still_out = 0
  for _, l in next, bb.lots do if l.out then still_out = still_out + 1 end end
  check(#LOGS >= 1 and LOGS[1]:find("porte des ilots ouverte", 1, true), "§3 la porte s'ouvre : une ligne [FO-EXTENSION]")
  check(#GROWN == 0 and still_out < 121 and still_out > 0, "§3 lots rendus (restent écartés seulement ceux collés au contour : " .. still_out .. "), pas de croissance : il y a de la place")
  local n_log = #LOGS
  Build.beyond_step(f, bb, bb.enc, 3600 + 1800, false)
  check(#LOGS == n_log, "§3 la porte ne change pas : aucune ligne de plus")
  -- plus de lot libre : la croissance
  for _, l in next, bb.lots do if l.state == "libre" then l.used = 1 end end
  bb.projects[1] = { state = "fini" }
  for _, l in next, bb.lots do l.state = "gisement" end -- ni libre ni à défricher : aucun lot utilisable
  Build.beyond_step(f, bb, bb.enc, 3600 + 3600, false)
  check(#GROWN == 1 and GROWN[1] == 6 and GROWN.cap == 12, "§3 aucun lot libre, porte ouverte : le treillis grandit d'un anneau AU-DELA du mur (rayon 6), jusqu'au plafond des gisements (12), non plus RADIUS_MAX")
  check(LOGS[#LOGS]:find("AU-DELA du mur", 1, true) ~= nil, "§3 la croissance est écrite au journal")
  -- croissance voulue mais refusée (rien de fini) : la cause est écrite UNE fois
  do
    local b2 = make()
    for _, l in next, b2.lots do l.state = "gisement" end
    DONE = 0
    GROWN = {}
    local n0 = #LOGS
    Build.beyond_step(f, b2, b2.enc, 6000, false)
    Build.beyond_step(f, b2, b2.enc, 7800, false)
    local wait_logs = 0
    for i = n0 + 1, #LOGS do if LOGS[i]:find("attendue : rien de fini", 1, true) then wait_logs = wait_logs + 1 end end
    check(#GROWN == 0 and wait_logs == 1, "§3 croissance voulue mais refusee : la cause (rien de fini) est ecrite une seule fois (" .. wait_logs .. ")")
    DONE = 10
  end
  -- un îlot sans mur : la porte se ferme, pas de croissance
  ISL.n, ISL.unwalled = 1, 1
  GROWN = {}
  bb = make()
  for _, l in next, bb.lots do l.out = nil end
  Build.beyond_step(f, bb, bb.enc, 7200, false)
  local parked_n = 0
  for _, l in next, bb.lots do if l.out then parked_n = parked_n + 1 end end
  check(#GROWN == 0 and parked_n > 0 and LOGS[#LOGS]:find("fermee : ilot sans mur", 1, true), "§3 un îlot sans mur : porte fermée, lots libres dehors repris (" .. parked_n .. "), aucune croissance")
  ISL.n, ISL.unwalled = 0, 0
  -- enceinte incomplète ou sans contour serré : rien
  n_log = #LOGS
  bb = make()
  bb.enc.complete = false
  Build.beyond_step(f, bb, bb.enc, 9000, false)
  check(#LOGS == n_log and #GROWN == 0, "§3 enceinte incomplète : rien (le rayon reste figé)")
  -- chantier du mur
  bb = make()
  for _, l in next, bb.lots do l.out = nil end
  Build.beyond_step(f, bb, bb.enc, 9100, true)
  check(LOGS[#LOGS]:find("enceinte en cours", 1, true) ~= nil, "§3 segment du mur en cours : porte fermée")
  -- menace
  f.threatened_until = 99999
  Build.beyond_step(f, bb, bb.enc, 9200, false)
  check(LOGS[#LOGS]:find("menace", 1, true) ~= nil, "§3 équipe menacée : porte fermée")
  f.threatened_until = nil

  -- §4 Déterminisme.
  local r1a, r1b = Ic.release(rows, BOUNDS, true)
  local r2a, r2b = Ic.release(rows, BOUNDS, true)
  check(table.concat(r1a, ",") == table.concat(r2a, ",") and #r1b == #r2b, "§4 même entrée, même sortie")
  return pass, fail, msgs
end

-- Hors suite : le texte de build.lua branche bien la règle.
local extra_fail = {}
do
  local function need(cond, m) if not cond then extra_fail[#extra_fail + 1] = m end end
  -- (lot PERIMETRE2 G3 essai 3 : le plafond passe par Build.radius_frozen, levé par Build.beyond_wall ou, pour l'enceinte de votre équipe
  -- en construction, par enc.grow ; les factions n'ont jamais enc.grow : pour elles, la règle d'avant)
  need(BUILD_SRC:find("if Build.radius_frozen(b) then r = math.min(r, b.enc.r) end", 1, true), "Build.grow : plafond de l'enceinte levé seulement par Build.beyond_wall (ou enc.grow)")
  need(BUILD_SRC:find("return b.enc ~= nil and not Build.beyond_wall(b) and not b.enc.grow", 1, true), "Build.radius_frozen : figé sauf au-delà du mur ou enc.grow")
  need(BUILD_SRC:find("return b.radius < Build.RADIUS_MAX and not Build.radius_frozen(b)", 1, true), "Build.can_grow : la croissance au-delà du mur est possible")
  need(BUILD_SRC:find("Build.beyond_step(f, b, enc, tick, active_segment(b, enc) ~= nil)", 1, true), "Build.space_step appelle Build.beyond_step")
  need(BUILD_SRC:find("return b.enc ~= nil and Ic.open(b.enc) and Rsv.on()", 1, true), "Build.beyond_wall : enceinte complète ET réglage maître")
end

local Ic0 = assert(load_ic(SRC))
local pass, fail, msgs = suite(Ic0)
for _, m in ipairs(extra_fail) do fail = fail + 1 msgs[#msgs + 1] = "§0 " .. m end

local MUTANTS = {
  { "ouverture sans contour", "return enc ~= nil and enc%.bounds ~= nil and enc%.complete == true", "return enc ~= nil and enc.complete == true" },
  { "ouverture sans enceinte complète", "return enc ~= nil and enc%.bounds ~= nil and enc%.complete == true", "return enc ~= nil and enc.bounds ~= nil" },
  { "îlots au plus sans effectif", "local n = I%.MAX %+ math%.floor%(math%.max%(0, workers or 0%) / Ic%.WORKERS_PER_ISLAND%)", "local n = I.MAX" },
  { "îlots sans plafond", "if n > Ic%.ISLANDS_MAX then n = Ic%.ISLANDS_MAX end", "" },
  { "tourelles sans plancher", "return c > I%.TEAM_MAX and c or I%.TEAM_MAX", "return c" },
  { "porte : menace ignorée", "if info%.threatened then return false, \"menace\" end", "" },
  { "porte : mur principal ignoré", "if info%.main_busy then return false, \"enceinte en cours\" end", "" },
  { "porte : chantiers dehors ignorés", "if %(info%.outside_busy or 0%) > Ic%.OUTSIDE_BUSY_MAX then return false, \"chantier hors du mur\" end", "" },
  { "porte : îlot sans mur toléré", "if %(info%.unwalled or 0%) > Ic%.UNWALLED_MAX then return false, \"ilot sans mur\" end", "" },
  { "porte : îlot sans tourelles toléré", "if %(info%.unguarded or 0%) > Ic%.UNGUARDED_MAX then return false, \"ilot sans tourelles\" end", "" },
  { "porte : plafond d'îlots ignoré", "if %(info%.islands or 0%) >= %(info%.max or Ic%.max_islands%(0%)%) then return false, \"plafond d'ilots\" end", "" },
  { "croissance sans porte", "local ok, why = Ic%.gate%(info%)\n  if not ok then return false, why end", "" },
  { "croissance malgré la place libre", "if %(info%.free or 0%) >= Ic%.GROW_FREE_MIN then return false, \"place libre\" end", "" },
  { "croissance sans rayon maximal", "if info%.radius >= info%.rmax then return false, \"rayon maximal\" end", "" },
  { "croissance malgré les chantiers", "if %(info%.busy or 0%) > Ic%.BUSY_MAX then return false, \"chantiers en cours\" end", "" },
  { "croissance sans rien de fini", "if %(info%.done or 0%) < 1 then return false, \"rien de fini\" end", "" },
  { "lots jamais rendus", "if l%.out then freed%[#freed %+ 1%] = l%.k end", "" },
  { "lots rendus même dedans", "if I%.outside%(bounds, { x0 = l%.x0, y0 = l%.y0, x1 = l%.x1, y1 = l%.y1 }%) then\n      if gate_ok then", "if true then\n      if gate_ok then" },
  { "lot pris repris", "elseif not l%.out and l%.free and not l%.used then", "elseif not l.out and l.free then" },
  { "lots jamais repris", "parked%[#parked %+ 1%] = l%.k", "" },
  { "chantiers dehors comptés dedans", "if l%.busy and I%.outside%(bounds, { x0 = l%.x0, y0 = l%.y0, x1 = l%.x1, y1 = l%.y1 }%) then n = n %+ 1 end", "if l.busy then n = n + 1 end" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local src, n = SRC:gsub(m[2], function() return m[3] end)
  local ok = false
  if n == 1 then
    local Ic = load_ic(src)
    if Ic then
      local okp, _p, f = pcall(suite, Ic)
      ok = (not okp) or f > 0
    else
      ok = true
    end
  end
  if n ~= 1 then kept[#kept + 1] = m[1] .. " (motif trouvé " .. n .. " fois)" elseif ok then refused = refused + 1 else kept[#kept + 1] = m[1] end
end
if #kept > 0 then
  fail = fail + 1
  msgs[#msgs + 1] = "mutants NON refusés : " .. table.concat(kept, " ; ")
end
print(string.format("[ILOTS-CROISSANCE] mutants refusés : %d sur %d", refused, #MUTANTS))
for _, m in ipairs(msgs) do print("  ECHEC : " .. m) end
print(string.format("[ILOTS-CROISSANCE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
