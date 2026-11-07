--[[
  Lot STOCKAGE-VITAL : règle pure shared/team/stockage.lua (réserve des matières vitales, matières à ne plus ramasser, coffre urgent).
  Usage, depuis la racine du mod :   lua5.2 tests/stockage_test.lua
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/team/stockage.lua"
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end
local SRC = read(PATH)

local ok_n, bad = 0, 0
local function check(name, cond, detail)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[STOCKAGE] ECHEC : " .. name .. (detail and (" (" .. tostring(detail) .. ")") or "")) end
end

local function suite(Sg)
  local res = {}
  local function c(name, cond, detail) res[#res + 1] = { name, cond and true or false, detail } end
  local CFG = { reserve = 0.15, stop_at = 0.80, urgent_at = 0.85 }
  local V = { ["iron-plate"] = true, coal = true }
  -- réserve : 15 % des cases, au moins 1
  c("reserve : 200 cases -> 30 gardees", Sg.reserve_slots(200, CFG) == 30, tostring(Sg.reserve_slots(200, CFG)))
  c("reserve : 4 cases -> 1 gardee (arrondi au-dessus)", Sg.reserve_slots(4, CFG) == 1, tostring(Sg.reserve_slots(4, CFG)))
  c("reserve : aucune case -> 0", Sg.reserve_slots(0, CFG) == 0)
  -- cases vides prises : vitale toutes, non vitale au-delà de la réserve
  c("fer : toutes les cases vides (10 sur 200)", Sg.new_stacks("iron-plate", 10, 200, V, CFG) == 10)
  c("pierre : rien quand il reste moins que la reserve (10 vides, 30 gardees)", Sg.new_stacks("stone", 10, 200, V, CFG) == 0)
  c("pierre : au-dela de la reserve (50 vides -> 20)", Sg.new_stacks("stone", 50, 200, V, CFG) == 20, tostring(Sg.new_stacks("stone", 50, 200, V, CFG)))
  c("charbon : vital", Sg.new_stacks("coal", 5, 200, V, CFG) == 5)
  -- ne plus ramasser : non vitale saturée ; toutes les non vitales au-dessus de stop_at ; jamais une vitale
  local sk = Sg.skip({ stone = true, ["iron-plate"] = true }, 0.5, V, CFG)
  c("pierre saturee : plus ramassee", Sg.skipped(sk, "stone", V) == true)
  c("fer sature : toujours ramasse (vital), absent de l'ensemble", Sg.skipped(sk, "iron-plate", V) == false and sk["iron-plate"] == nil)
  c("cuivre non sature, stock a moitie : ramasse", Sg.skipped(sk, "copper-plate", V) == false)
  -- une seule règle pour « ne plus ramasser une matière saturée » : le stop_stone de la sortie de spirale (pierre saturée ET fer qui
  -- manque) s'y ramène ; rien ne manque (short = false, comme le cerveau) : la saturée reste ramassée tant que le stock a de la place
  c("pierre saturee, rien ne manque : ramassee (stock a moitie)", Sg.skipped(Sg.skip({ stone = true }, 0.5, V, CFG, false), "stone", V) == false)
  c("pierre saturee, fer qui manque (stop_stone de la spirale) : plus ramassee", Sg.skipped(Sg.skip({ stone = true }, 0.5, V, CFG, true), "stone", V) == true)
  c("pierre saturee, rien ne manque, stock a 80 % : plus ramassee", Sg.skipped(Sg.skip({ stone = true }, 0.8, V, CFG, false), "stone", V) == true)
  local sk2 = Sg.skip({}, 0.80, V, CFG)
  c("stock a 80 % : aucune non vitale ramassee (cuivre)", Sg.skipped(sk2, "copper-plate", V) == true)
  c("stock a 80 % : le charbon reste ramasse", Sg.skipped(sk2, "coal", V) == false)
  c("stock a 79 % : cuivre ramasse", Sg.skipped(Sg.skip({}, 0.79, V, CFG), "copper-plate", V) == false)
  -- coffre urgent : au-dessus de urgent_at, aucun en main
  c("coffre urgent a 85 % sans coffre en main", Sg.urgent(0.85, false, CFG) == true)
  c("pas d'urgence a 84 %", Sg.urgent(0.84, false, CFG) == false)
  c("pas d'urgence avec un coffre en main", Sg.urgent(0.95, true, CFG) == false)
  -- valeurs par défaut quand la configuration manque
  c("defauts : reserve 15 %", Sg.reserve_slots(100) == 15)
  return res
end

local function run(text)
  local chunk, err = load(text, "=" .. PATH)
  if not chunk then return { { "module illisible : " .. tostring(err), false } } end
  local okm, Sg = pcall(chunk)
  if not okm then return { { "module : " .. tostring(Sg), false } } end
  local okr, res = pcall(suite, Sg)
  if not okr then return { { "suite : " .. tostring(res), false } } end
  return res
end
for _, r in ipairs(run(SRC)) do check(r[1], r[2], r[3]) end
-- cablage (texte) : le ramassage des avant-postes ecarte ce que Stock.skip_fn refuse ; le depot garde la reserve des vitales
do
  local op, wk, sk = read("script/faction/outposts.lua"), read("script/team/worker.lua"), read("script/team/stock.lua")
  check("cablage : collect ecarte les matieres refusees", op:find("if not (skip and skip(name)) then", 1, true) ~= nil
    and op:find("function Outposts.service(o, carrier, tick, fill, skip)", 1, true) ~= nil)
  check("cablage : la tournee passe Stock.skip_fn", wk:find("Stock.skip_fn and Stock.skip_fn(f))", 1, true) ~= nil)
  check("cablage : Stock.insert borne les non vitales (Sg.new_stacks)", sk:find("local allowed = Sg.new_stacks(item, empty, size, VITAL, T.stockage)", 1, true) ~= nil
    and sk:find("if not VITAL[item] then", 1, true) ~= nil)
  check("cablage : coffre urgent demande (Stock.wanted) et journal [FO-STOCKAGE]", sk:find("if Sg.urgent(used / size, have > 0, T.stockage) and n < capacity(f) then w = math.max(w, 1) end", 1, true) ~= nil
    and sk:find("[FO-STOCKAGE]", 1, true) ~= nil)
end

-- coffre URGENT (shared/team/fond.lua, F.annex_urgent) : fabriqué cerveau en manque et fond coupé, planchers compris
local function urgent_suite(F)
  local res = {}
  local function check(name, cond, detail) res[#res + 1] = { name, cond and true or false, detail } end
  do
    local T = require("shared.team.config")
    local IRON, WOOD = T.outposts.iron.product, "wood"
    local CH = T.annex.kinds[1].item
    local function book(ok_items)
      return {
        handcraftable = function(_, item) return ok_items[item] == true end,
        plan = function(_, list, avail)
          local item = list[1][1]
          local need = (item == CH) and { [IRON] = 8 } or { [WOOD] = 2 }
          local raw = {}
          for k, v in pairs(need) do if (avail[k] or 0) < v then raw[k] = v end end
          return { raw = raw, crafts = {}, uses = need }
        end,
      }
    end
    local B = book({ [CH] = true, [T.annex.kinds[2].item] = true })
    local t = F.annex_urgent({}, { [IRON] = 8 }, { book = B, annex_urgent = true })
    check("urgent : coffre de fer fabrique avec 8 plaques (cerveau en manque ou non)", #t == 1 and t[1].item == CH and t[1].prio == F.URGENT_PRIO and t[1].prio > F.PRIO.extend, #t)
    check("urgent : rien sans urgence", #F.annex_urgent({}, { [IRON] = 8 }, { book = B, annex_urgent = false }) == 0)
    check("urgent : rien avec un coffre en main", #F.annex_urgent({}, { [IRON] = 8, [CH] = 1 }, { book = B, annex_urgent = true }) == 0)
    check("urgent : rien quand la tache est deja au tableau", #F.annex_urgent({}, { [IRON] = 8 }, { book = B, annex_urgent = true,
      keys = { ["fond:craft:" .. CH .. ":annexe-urgente"] = true } }) == 0)
    local tw = F.annex_urgent({}, { [IRON] = 0, [WOOD] = 4 }, { book = B, annex_urgent = true })
    check("urgent : sans fer, le coffre en bois", #tw == 1 and tw[1].item == T.annex.kinds[2].item, #tw)
    -- par le fond : cerveau EN MANQUE et fer au seul plancher (F.FLOOR) : le coffre de fer passe quand même (planchers rendus)
    local c = F.candidates({ incoming = {} }, { [IRON] = F.FLOOR[IRON], ["copper-plate"] = 0, stone = 0 },
      { book = B, keys = {}, brain_short = true, annex_want = 1, annex_urgent = true })
    local found = false
    for _, x in ipairs(c.base) do if x.key == "fond:craft:" .. CH .. ":annexe-urgente" then found = true end end
    check("fond, cerveau en manque, fer au plancher : coffre de fer urgent propose", found)
    local c2 = F.candidates({ incoming = {} }, { [IRON] = F.FLOOR[IRON], ["copper-plate"] = 0, stone = 0 },
      { book = B, keys = {}, brain_short = true, annex_want = 1 })
    local plain = false
    for _, x in ipairs(c2.base) do if x.item == CH then plain = true end end
    check("temoin : sans urgence, cerveau en manque, aucun coffre de fer (comportement de 0.6.58)", not plain)
  end
  return res
end
package.path = "./?.lua;" .. package.path
local FOND_PATH = "shared/team/fond.lua"
local FOND_SRC = read(FOND_PATH)
local function run_fond(text)
  local chunk, err = load(text, "=" .. FOND_PATH)
  if not chunk then return { { "fond illisible : " .. tostring(err), false } } end
  local okm, F = pcall(chunk)
  if not okm then return { { "fond : " .. tostring(F), false } } end
  local okr, res = pcall(urgent_suite, F)
  if not okr then return { { "suite fond : " .. tostring(res), false } } end
  return res
end
for _, r in ipairs(run_fond(FOND_SRC)) do check(r[1], r[2], r[3]) end
local FMUT = {
  { "fond : planchers non rendus au coffre urgent", "    for k, v in pairs(floors) do all[k] = (all[k] or 0) + v end\n", "" },
  { "fond : urgence ignoree par le fond", "  if ctx.annex_urgent then\n    -- lot STOCKAGE-VITAL", "  if false then\n    -- lot STOCKAGE-VITAL" },
  { "fond : coffre en main ignore", "    if (free[k.item] or 0) > 0 or (incoming[k.item] or 0) > 0 or keys", "    if keys" },
  { "fond : coffre urgent sous la priorite du fond", "F.URGENT_PRIO = F.PRIO.extend + 1", "F.URGENT_PRIO = F.PRIO.craft" },
}
local frefused, fkept = 0, {}
for _, m in ipairs(FMUT) do
  local a1, z1 = FOND_SRC:find(m[2], 1, true)
  if not a1 then fkept[#fkept + 1] = m[1] .. " (motif introuvable)" else
    local res = run_fond(FOND_SRC:sub(1, a1 - 1) .. m[3] .. FOND_SRC:sub(z1 + 1))
    local seen = false
    for _, r in ipairs(res) do if not r[2] then seen = true break end end
    if seen then frefused = frefused + 1 else fkept[#fkept + 1] = m[1] end
  end
end
check(string.format("mutants du fond refuses %d/%d%s", frefused, #FMUT, #fkept > 0 and (" ; survivants : " .. table.concat(fkept, ", ")) or ""), frefused == #FMUT)
print(string.format("[STOCKAGE] mutants du fond refuses %d/%d", frefused, #FMUT))

local MUT = {
  { "reserve arrondie au-dessous", "  return math.ceil(cfg.reserve * size - 1e-9)", "  return math.floor(cfg.reserve * size + 1e-9)" },
  { "vitale soumise a la reserve", "  if vital and vital[item] then return empty end", "" },
  { "non vitale sans reserve", "  return math.max(0, empty - Sg.reserve_slots(size, cfg))", "  return empty" },
  { "vitale saturee plus ramassee", "    if not vital[item] then out[item] = true end", "    out[item] = true" },
  { "saturee ecartee meme quand rien ne manque", "  if short ~= false then\n", "  if true then\n" },
  { "stock presque plein ignore", "  out.__all_non_vital = (fill or 0) >= cfg.stop_at or nil", "  out.__all_non_vital = nil" },
  { "seuil de plein a l'envers", "(fill or 0) >= cfg.stop_at", "(fill or 0) > cfg.stop_at" },
  { "vitale jamais protegee au ramassage", "  if not set or (vital and vital[item]) then return false end", "  if not set then return false end" },
  { "urgence malgre un coffre en main", "  return (fill or 0) >= cfg.urgent_at and not have_chest", "  return (fill or 0) >= cfg.urgent_at" },
  { "urgence trop tard", "  return (fill or 0) >= cfg.urgent_at and not have_chest", "  return (fill or 0) > cfg.urgent_at and not have_chest" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local a, z = SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local res = run(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(z + 1))
    local seen = false
    for _, r in ipairs(res) do if not r[2] then seen = true break end end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(string.format("mutants refuses %d/%d%s", refused, #MUT, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUT)
print(string.format("[STOCKAGE] mutants refuses %d/%d", refused, #MUT))
print(string.format("[STOCKAGE] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
