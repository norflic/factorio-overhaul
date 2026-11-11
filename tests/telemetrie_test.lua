--[[
  Lot TELEMETRIE : banc HORS JEU des règles pures de shared/debug/telemetrie.lua. Lancement, depuis la racine du mod :
    lua5.2 tests/telemetrie_test.lua
  Sections : 1. classement de la décision active ; 2. tailles comptées et bornées ; 3. orphelines (équipes disparues) ; 4. mutants.
  Aucun nom du jeu : chaînes opaques.
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/debug/telemetrie.lua"
local function slurp(p) local f = assert(io.open(p, "rb")) local x = f:read("*a") f:close() return x end
local SRC = slurp(PATH)
local function load_te(mutate)
  local src = SRC
  if mutate then
    local i, j = src:find(mutate[1], 1, true)
    if not i then error("texte de mutant introuvable : " .. mutate[1]) end
    src = src:sub(1, i - 1) .. mutate[2] .. src:sub(j + 1)
  end
  return assert(load(src, "=" .. PATH))()
end

local function suite(Te, check)
  -- 1. classement
  check(Te.classify({}).cat == "attente_ressource", "rien : attente")
  check(Te.classify({ defstock = { rows = { { key = "q", kind = "qg", have = 1, want = 5, skip = "stock" } } } }).cat == "defense", "défense : manque de stock")
  check(Te.classify({ defstock = { rows = { { key = "q", kind = "qg", have = 5, want = 5, skip = "servie" } } } }).cat ~= "defense", "défense servie : pas défense")
  check(Te.classify({ defstock = { rows = { { kind = "attaque" } } }, team = { capital = { current = { key = "k" } } } }).cat == "defense", "attaque prime")
  check(Te.classify({ team = { capi = { open = { { item = "a", missing = { { "b", 3 } } } } } } }).cat == "attente_ressource", "ordre en manque : attente")
  check(Te.classify({ team = { sources = { dec = { r1 = { choix = "sortie", raison = "en_marche" } } } } }).cat == "expansion_mine", "sortie : expansion")
  check(Te.classify({ team = { sources = { dec = { r1 = { choix = "stock", raison = "sorties_vides" } } } } }).cat == "attente_ressource", "sorties vides : attente")
  local c = Te.classify({ team = { capital = { current = { key = "k1" } } } })
  check(c.cat == "reinvestissement" and c.why == "k1", "capital courant : réinvestissement")
  check(Te.classify({ team = { capi = { open = { { item = "a" } } } } }).cat == "reinvestissement", "ordre ouvert : réinvestissement")
  -- 2. tailles
  local f = { team = { capi = { open = { 1, 2, 3 }, refused = { a = 1, b = 2 } }, capital = { history = { 1 } } }, defstock = { rows = { 1, 2 } } }
  local s, total = Te.sizes(f)
  local by = {}
  for _, e in ipairs(s) do by[e.name] = e end
  check(total == 8, "total 8 entrées, vu " .. tostring(total))
  check(by["capi.open"].n == 3 and by["capi.refused"].n == 2 and by["defstock.rows"].n == 2 and by["sources.dec"].n == 0, "tailles par table")
  local big = {}
  for i = 1, 50 do big[i] = i end
  local s2 = Te.sizes({ team = { capi = { open = big } } }, 10)
  check(s2[1].n == 10 and s2[1].full == true, "comptage borné")
  -- 3. orphelines
  local o = Te.orphans({ player = {}, f2 = {}, f9 = {}, f3 = {} }, { player = true, f2 = true })
  check(#o == 2 and o[1] == "f3" and o[2] == "f9", "orphelines triées : f3, f9")
  check(#Te.orphans({ player = {}, f2 = {} }, { player = true, f2 = true }) == 0, "aucune orpheline : rien")
  local m = {}
  for i = 1, 40 do m["x" .. i] = true end
  check(#Te.orphans(m, {}, 5) == 5, "purge bornée")
end

local passes, failures = 0, 0
suite(load_te(), function(ok, msg) if ok then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end end)

local MUTANTS = {
  { "r.kind == \"attaque\" or", "false or" },
  { "r.have < r.want", "r.have > r.want" },
  { "#rec.missing > 0", "#rec.missing > 99" },
  { "d.choix == \"sortie\" or", "" },
  { "if n >= cap then break end", "" },
  { "if not alive[k] then", "if alive[k] then" },
  { "if #out >= max then break end", "" },
  { "return { cat = \"reinvestissement\", why = tostring(cap.current.key) }", "return { cat = \"defense\", why = \"\" }" },
}
local killed = 0
for i, mu in ipairs(MUTANTS) do
  local fails = 0
  local ok = pcall(function() suite(load_te(mu), function(c) if not c then fails = fails + 1 end end) end)
  if not ok or fails > 0 then killed = killed + 1 else failures = failures + 1; print("  ECHEC : mutant " .. i .. " survit : " .. mu[1]) end
end
print(string.format("telemetrie : %d contrôles, %d échecs, %d/%d mutants tués", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
