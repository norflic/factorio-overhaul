--[[
  Lot X10-S0, compteur « stock:place » (demande de charbonmain, 8/11) : Stock.engine_calls compte AUSSI les lectures de place de
  STOCKAGE-VITAL. Critères, écrits avant le code :
  C1. Invariant, pour chaque scénario (Stock.inventories, room, can_take, fill, balance, note_claim, insert d'une non vitale qui mord
      la réserve, insert ordinaire, contents) : appels RÉELS au moteur de get_inventory + count_empty_stacks + get_insertable_count +
      get_contents (comptés par les faux coffres) = hausse de engine_calls.place + engine_calls.contents. Et get_item_count = hausse de
      engine_calls.count.
  C2. Chaque scénario de place fait au moins un appel de place (le contrôle n'est pas vide).
  C3. Profileur hors du mode fin : aucun compteur ne bouge, et les fonctions rendent la même chose.
  C4. Mutants (une ligne de compte retirée ou fausse) : chacun casse C1.
  Coffres de bouchons, aucun jeu. Lancement, depuis la racine du mod : lua5.2 tests/x10_s0_place_test.lua
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 else fail_n = fail_n + 1; print("  ECHEC : " .. msg) end
end

function log() end
defines = { inventory = { chest = 1 } }
game = { tick = 0, item_prototypes = setmetatable({}, { __index = function() return { stack_size = 50 } end }) }

local SRC
do
  local fh = assert(io.open("script/team/stock.lua", "rb"))
  SRC = fh:read("*a")
  fh:close()
end

local FINE = { on = true }
local function load_stock(src)
  package.loaded["script.ai3.places_qg"] = { on_resource = function() return false end } -- (lot DECOUPLAGE : sol sans ressource)
  package.loaded["script.core.profiler"] = { fine = function() return FINE.on end, fcount = function() end }
  return assert(load(src, "=script/team/stock.lua"))("script.team.stock")
end

-- Faux coffres : chaque appel au moteur compté.
local C = { gi = 0, ces = 0, gic = 0, gc = 0, gcount = 0 }
local function inv(size, used, contents)
  local t = { size = size, used = used, contents = contents or {} }
  return setmetatable({
    count_empty_stacks = function() C.ces = C.ces + 1 return t.size - t.used end,
    get_insertable_count = function() C.gic = C.gic + 1 return (t.size - t.used) * 50 end,
    get_contents = function() C.gc = C.gc + 1 return t.contents end,
    remove = function(s) return s.count end,
  }, { __len = function() return t.size end })
end
local function chest(i)
  return { valid = true, get_inventory = function() C.gi = C.gi + 1 return i end,
    get_item_count = function() C.gcount = C.gcount + 1 return 0 end,
    insert = function(s) return math.min(s.count, 10) end, remove_item = function() return 0 end }
end
local function team()
  return { key = "t", hq = chest(inv(48, 47, { ["iron-plate"] = 2000, stone = 300 })),
    annex = { chest(inv(48, 5)), chest(inv(48, 40)) }, team = {} }
end

local SCEN = {
  { "inventories", function(S, f) return #S.inventories(f) end, true },
  { "room", function(S, f) return S.room(f, "iron-plate") end, true },
  { "can_take", function(S, f) return S.can_take(f, { { "iron-plate", 10 }, { "coal", 5 }, { "iron-plate", 3 } }) end, true },
  { "fill", function(S, f) return S.fill(f) end, true },
  { "balance", function(S, f) return S.balance(f) end, true },
  { "note_claim", function(S, f) S.note_claim(f, inv(80, 79), 10) return f.stats and f.stats.claim_full end, true },
  { "insert non vitale (réserve)", function(S, f) return S.insert(f, "stone", 500, { reserve = true }) end, true },
  { "insert ordinaire", function(S, f) return S.insert(f, "stone", 5) end, false },
  { "contents", function(S, f) local c = S.contents(f) return c.stone end, false },
}

--- Joue les scénarios ; rend { [nom] = { réels, comptés, get_item_count, compté count, valeur } }.
local function play(src)
  local S = load_stock(src)
  local out = {}
  for _, sc in ipairs(SCEN) do
    local f = team()
    local c0 = { gi = C.gi, ces = C.ces, gic = C.gic, gc = C.gc, gcount = C.gcount }
    local e = S.engine_calls
    local e0 = { place = e.place, contents = e.contents, count = e.count }
    local v = sc[2](S, f)
    local real = (C.gi - c0.gi) + (C.ces - c0.ces) + (C.gic - c0.gic) + (C.gc - c0.gc)
    local counted = (e.place - e0.place) + (e.contents - e0.contents)
    out[sc[1]] = { real = real, counted = counted, gcount = C.gcount - c0.gcount, ccount = e.count - e0.count, value = v,
      place = e.place - e0.place }
  end
  return out
end

-- C1, C2
local r = play(SRC)
for _, sc in ipairs(SCEN) do
  local x = r[sc[1]]
  check(x.real == x.counted and x.gcount == x.ccount,
    string.format("C1 : %s : %d appel(s) réel(s), %d compté(s) ; get_item_count %d, compté %d", sc[1], x.real, x.counted, x.gcount, x.ccount))
  if sc[3] then check(x.place > 0, "C2 : " .. sc[1] .. " fait au moins un appel de place (" .. x.place .. ")") end
end

-- C3
do
  FINE.on = false
  local r0 = play(SRC)
  FINE.on = true
  local still, same = true, true
  for _, sc in ipairs(SCEN) do
    local x0, x = r0[sc[1]], r[sc[1]]
    if x0.counted ~= 0 or x0.ccount ~= 0 then still = false end
    if tostring(x0.value) ~= tostring(x.value) or x0.real ~= x.real then same = false end
  end
  check(still, "C3 : profileur hors du mode fin : aucun compteur ne bouge")
  check(same, "C3 : mêmes valeurs rendues et mêmes appels au moteur, compteurs tenus ou non")
end

-- C4 : mutants
local function mutate(a, b)
  local s, e = SRC:find(a, 1, true)
  assert(s, "mutant : texte absent : " .. a)
  assert(not SRC:find(a, e + 1, true), "mutant : texte présent plusieurs fois : " .. a)
  return SRC:sub(1, s - 1) .. b .. SRC:sub(e + 1)
end
local MUT = {
  { "slots_of sans compte", '  ec("place", 1) -- count_empty_stacks\n', "" },
  { "inventories sans compte", '  ec("place", #list) -- get_inventory du coffre du QG et de chaque annexe\n', "" },
  { "can_take : un appel par objet au lieu de deux", '    ec("place", 2 * #invs)', '    ec("place", #invs)' },
  { "annexe du dépôt non vital sans compte", '    ec("place", 3) -- les mêmes, d\'une annexe\n', "" },
  { "rangement : get_contents oublié", '  ec("contents", 1) -- get_contents du coffre du QG (le rangement)\n', "" },
  { "poche sans compte", '  ec("place", 1) -- count_empty_stacks de la poche\n', "" },
}
for _, m in ipairs(MUT) do
  local okm, rm = pcall(play, mutate(m[2], m[3]))
  local seen = not okm
  if okm then for _, sc in ipairs(SCEN) do local x = rm[sc[1]] if x.real ~= x.counted then seen = true end end end
  check(seen, "C4 : mutant « " .. m[1] .. " » vu")
end

-- C5 : COÛT en instructions de la VM (debug.sethook, compte à chaque instruction : déterministe, jamais os.clock), scénario par
-- scénario : stock.lua SANS les lignes de compte de ce lot (retirées du texte), avec, mode fin éteint (le jeu), mode fin allumé.
do
  local base = {}
  for line in (SRC .. "\n"):gmatch("([^\n]*)\n") do
    if not (line:find('ec("place"', 1, true) or line:find('ec("contents", 1) -- get_contents du coffre du QG (le rangement)', 1, true)) then
      base[#base + 1] = line
    end
  end
  local BASE = table.concat(base, "\n")
  local function cost(src, fine)
    FINE.on = fine
    local S = load_stock(src)
    local out = {}
    for _, sc in ipairs(SCEN) do
      local f = team()
      local n = 0
      debug.sethook(function() n = n + 1 end, "", 1)
      sc[2](S, f)
      debug.sethook()
      out[sc[1]] = n
    end
    FINE.on = true
    return out
  end
  local b, off, on = cost(BASE, false), cost(SRC, false), cost(SRC, true)
  local worst, tot_b, tot_off = 0, 0, 0
  for _, sc in ipairs(SCEN) do
    local nm = sc[1]
    print(string.format("[X10-S0-PLACE] coût %-28s sans compte %6d, compte éteint %6d (+%d), allumé %6d (+%d) instructions",
      nm, b[nm], off[nm], off[nm] - b[nm], on[nm], on[nm] - b[nm]))
    tot_b, tot_off = tot_b + b[nm], tot_off + off[nm]
    worst = math.max(worst, (off[nm] - b[nm]) / b[nm])
  end
  print(string.format("[X10-S0-PLACE] coût total, compte éteint : +%d instructions sur %d (+%.1f %%) ; pire scénario +%.1f %%",
    tot_off - tot_b, tot_b, 100 * (tot_off - tot_b) / tot_b, 100 * worst))
  check(BASE ~= SRC and tot_off >= tot_b, "C5 : coût mesuré (base retirée du texte, compte éteint au moins aussi cher)")
end

print(string.format("[X10-S0-PLACE] BILAN : %d OK%s", ok_n, fail_n > 0 and (", " .. fail_n .. " ECHEC(S)") or ""))
os.exit(fail_n == 0 and 0 or 1)
