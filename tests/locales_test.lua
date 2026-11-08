--[[
  Garde-fou « 200 locales » (intégrateur, 5/11) : Lua 5.2 refuse de charger un fichier dont le bloc principal
  dépasse 200 variables locales actives (« too many local variables (limit is 200) in main function »).
  Factorio étant en Lua 5.2, un tel fichier empêche le mod de charger. Trouvé par PERIMETRE2 : la fusion de son lot
  avec corr-etage5 portait script/team/build.lua à 202 locales.

  Ce test, depuis la racine du mod (lua5.2 tests/locales_test.lua) :
  1. compile chaque fichier .lua suivi par git (load du texte, sans l'exécuter) : ECHEC si un fichier ne compile pas ;
  2. mesure la MARGE de chaque fichier : le plus grand N tel que « local a1, …, aN » placé EN TÊTE du texte compile
     encore (ces locales sont actives dans tout le bloc principal et s'ajoutent à son pire point) ;
  3. imprime les 8 plus petites marges ; ECHEC si une marge est sous MARGE_MIN (0 par défaut : le fichier est au bord).
  Option : --min N pour exiger une marge d'au moins N.
]]

local MARGE_MIN = 0
for i = 1, #arg do
  if arg[i] == "--min" and tonumber(arg[i + 1]) then MARGE_MIN = tonumber(arg[i + 1]) end
end

local ok_n, fail_n = 0, 0
local function check(cond, msg)
  if cond then ok_n = ok_n + 1 else fail_n = fail_n + 1; print("  ECHEC : " .. msg) end
end

local function read(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function compiles(text, name)
  local fn, err = load(text, "=" .. name, "t")
  return fn ~= nil, err
end

-- Plus grand N (0 à 255) tel que le texte + N locales compile ; -1 si le texte seul ne compile pas.
local function margin(text, name)
  if not compiles(text, name) then return -1 end
  local lo, hi = 0, 255
  while lo < hi do
    local mid = math.floor((lo + hi + 1) / 2)
    local names = {}
    for i = 1, mid do names[i] = "__fo_marge_" .. i end
    -- Locales ajoutées EN TÊTE : actives dans tout le bloc principal, elles s'ajoutent au pire point du fichier
    -- (et un fichier qui finit par « return » reste valide, contrairement à un ajout en fin).
    if compiles("local " .. table.concat(names, ", ") .. "\n" .. text, name) then lo = mid else hi = mid - 1 end
  end
  return lo
end

-- Lot TESTS-GIT (0.6.64) : liste par tests/depot.lua (git ls-files ; sans git, le disque, annoncé par une ligne [ENVIRONNEMENT]).
package.path = "./?.lua;" .. package.path
local D = require("tests.depot")
local files = {}
local all, source = D.lua_files({ "." })
for _, line in ipairs(all) do
  if not line:find("^tests/") and not line:find("^tools/") then files[#files + 1] = line end
end
if source == "disque" then D.env("liste des fichiers Lua du mod (git ls-files)", #files > 0) end
table.sort(files)
check(#files > 100, "fichiers du mod listés (" .. source .. ") (" .. #files .. ")")

local rows = {}
for _, path in ipairs(files) do
  local text = read(path)
  if text then
    local m = margin(text, path)
    check(m >= 0, path .. " compile (Lua 5.2)")
    if m >= 0 then rows[#rows + 1] = { path = path, m = m } end
  end
end
table.sort(rows, function(a, b) if a.m ~= b.m then return a.m < b.m end return a.path < b.path end)
print("Plus petites marges (locales encore possibles dans le bloc principal) :")
for i = 1, math.min(8, #rows) do print(string.format("  %3d  %s", rows[i].m, rows[i].path)) end
for _, r in ipairs(rows) do
  check(r.m >= MARGE_MIN, string.format("%s : marge %d >= %d", r.path, r.m, MARGE_MIN))
end

-- Auto-contrôle : un texte à 201 locales ne compile pas, un texte à 200 compile avec une marge de 0.
local function locals_text(n)
  local t = {}
  for i = 1, n do t[i] = "local v" .. i .. " = " .. i end
  return table.concat(t, "\n")
end
check(margin(locals_text(201), "auto201") == -1, "auto-contrôle : 201 locales ne compilent pas")
check(margin(locals_text(200), "auto200") == 0, "auto-contrôle : 200 locales, marge 0")
check(margin(locals_text(150), "auto150") == 50, "auto-contrôle : 150 locales, marge 50")

print(string.format("[LOCALES] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
