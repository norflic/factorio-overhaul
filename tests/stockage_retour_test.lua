--[[
  Lot STOCKAGE-VITAL, relecture revue-0659 du 7/11 (bloquant 2) : la réserve des vitales ne s'applique QU'AU dépôt d'un PNJ au QG
  (Stock.insert(f, item, n, { reserve = true }), script/team/worker.lua deposit_inventory). Un objet NON vital pris par un script puis
  rendu (remboursement, retour de valeur ignoré par l'appelant) tombait sur une case libérée DANS la réserve et était refusé : perdu.
  Aller-retour écrit par revue-0659 (pistolet, chargeurs, four), repris ici avec des contrôles et des mutants de script/team/stock.lua.
  Usage, depuis la racine du mod :   lua5.2 tests/stockage_retour_test.lua
]]
package.path = "./?.lua;" .. package.path
defines = { inventory = { chest = 1 } }
local STACK = { coal = 50, pistol = 5, ["firearm-magazine"] = 200, ["stone-furnace"] = 50 }
game = { tick = 0, item_prototypes = setmetatable({}, { __index = function(_, k) return { stack_size = STACK[k] or 50 } end }) }
function log() end

local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end
local PATH = "script/team/stock.lua"
local SRC = read(PATH)

local ok_n, bad = 0, 0
local function check(name, cond, detail)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[STOCKAGE-RETOUR] ECHEC : " .. name .. (detail and (" (" .. tostring(detail) .. ")") or "")) end
end

local function new_chest(size)
  local e = { valid = true, items = {}, size = size }
  local function slots()
    local n = 0
    for k, v in pairs(e.items) do n = n + math.ceil(v / (STACK[k] or 50)) end
    return n
  end
  local inv = {}
  setmetatable(inv, { __len = function() return size end })
  inv.count_empty_stacks = function() return size - slots() end
  inv.get_contents = function() local o = {} for k, v in pairs(e.items) do o[k] = v end return o end
  inv.get_insertable_count = function(name)
    local stack = STACK[name] or 50
    local have = e.items[name] or 0
    return math.ceil(have / stack) * stack - have + inv.count_empty_stacks() * stack
  end
  e.get_inventory = function() return inv end
  e.get_item_count = function(name) return e.items[name] or 0 end
  e.remove_item = function(s)
    local n = math.min(s.count, e.items[s.name] or 0)
    if n > 0 then e.items[s.name] = e.items[s.name] - n; if e.items[s.name] == 0 then e.items[s.name] = nil end end
    return n
  end
  inv.remove = function(s) return e.remove_item(s) end
  e.insert = function(s)
    local stack = STACK[s.name] or 50
    local have = e.items[s.name] or 0
    local room = math.ceil(have / stack) * stack - have + (size - slots()) * stack
    local n = math.min(s.count, room)
    if n > 0 then e.items[s.name] = have + n end
    return n
  end
  return e
end
package.loaded["script.ai3.places_qg"] = { place_list = function() return 0 end }

local DEP = { reserve = true }
local CASES = { { "pistol", 1, "pistolet (recrue)" }, { "firearm-magazine", 10, "chargeurs" }, { "stone-furnace", 1, "four de pierre" } }

local function suite(Stock)
  local res = {}
  local function c(name, cond, detail) res[#res + 1] = { name, cond and true or false, detail } end
  local function team()
    -- 20 cases : 17 de charbon (vital), 1 de l'objet non vital, 2 vides ; réserve = ceil(0,15 x 20) = 3 cases
    local f = { key = "t", force = "x", hq = new_chest(20), hq_pos = { x = 0, y = 0 }, stats = {}, started = 0 }
    f.hq.items.coal = 50 * 17
    return f
  end
  for _, cs in ipairs(CASES) do
    local item, n, label = cs[1], cs[2], cs[3]
    local f = team()
    f.hq.items[item] = n
    local before = Stock.count(f, item)
    local got = Stock.remove(f, item, n)
    local put = Stock.insert(f, item, got) -- remboursement d'un script : ancien chemin, sans réserve
    local after = Stock.count(f, item)
    c("aller-retour " .. label .. " : rien de perdu", got == n and put == got and after == before,
      string.format("avant %d, pris %d, rendu %d, apres %d", before, got, put, after))
    -- le même objet déposé par un PNJ : la réserve s'applique (3 cases vides = la réserve) : refusé, il reste en poche
    local g = team()
    g.hq.items[item] = n
    Stock.remove(g, item, n)
    c("depot d'un PNJ " .. label .. " : la reserve des vitales s'applique (refuse)", Stock.insert(g, item, n, DEP) == 0)
  end
  -- une matière vitale déposée par un PNJ prend toujours les cases gardées
  local h = team()
  c("depot d'un PNJ : le charbon (vital) prend les cases gardees", Stock.insert(h, "coal", 100, DEP) == 100)
  return res
end

local function run(text)
  package.loaded["script.team.stock"] = nil
  local chunk, err = load(text, "=" .. PATH)
  if not chunk then return { { "stock.lua illisible : " .. tostring(err), false } } end
  local okm, Stock = pcall(chunk)
  if not okm then return { { "stock.lua : " .. tostring(Stock), false } } end
  local okr, res = pcall(suite, Stock)
  if not okr then return { { "suite : " .. tostring(res), false } } end
  return res
end
for _, r in ipairs(run(SRC)) do check(r[1], r[2], r[3]) end

-- câblage : SEUL le dépôt d'un PNJ demande la réserve
do
  local wk = read("script/team/worker.lua")
  check("cablage : deposit_inventory passe { reserve = true }", wk:find("local DEPOSIT_OPTS = { reserve = true }", 1, true) ~= nil
    and wk:find("local moved = Stock.insert(f, name, n, DEPOSIT_OPTS)", 1, true) ~= nil)
  local n = select(2, wk:gsub("DEPOSIT_OPTS%)", ""))
  check("cablage : aucun autre Stock.insert de worker.lua ne passe le drapeau", n == 1, n)
end

local MUT = {
  { "drapeau ignore (reserve pour tous les appelants)", "local plan = opts and opts.reserve and not VITAL[item]", "local plan = not VITAL[item]" },
  { "drapeau jamais lu (reserve pour personne)", "local plan = opts and opts.reserve and not VITAL[item]", "local plan = false and not VITAL[item]" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local a, z = SRC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif introuvable)" else
    local seen = false
    for _, r in ipairs(run(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(z + 1))) do if not r[2] then seen = true break end end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(string.format("mutants refuses %d/%d%s", refused, #MUT, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUT)
print(string.format("[STOCKAGE-RETOUR] mutants refuses %d/%d", refused, #MUT))
print(string.format("[STOCKAGE-RETOUR] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
