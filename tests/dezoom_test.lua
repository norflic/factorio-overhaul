--[[
  Dézoom étendu : règle pure (shared/gui/dezoom.lua) et câblage (touches déclarées, traductions FR et EN).
  Usage : lua5.2 tests/dezoom_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path
local M = require("shared.gui.dezoom")

local ok, bad = 0, 0
local function check(cond, name, detail)
  if cond then ok = ok + 1 else
    bad = bad + 1
    print("[DEZOOM] ECHEC " .. name .. (detail ~= nil and (" : " .. tostring(detail)) or ""))
  end
end
local function near(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < 1e-9 end

-- §1 les crans : le premier est 20 % sous la limite de la molette, la suite décroît strictement
check(M.count() == 4, "4 crans", M.count())
check(near(M.VALUES[1], M.WHEEL_LIMIT * 0.8), "cran 1 = 20 % sous la limite", M.VALUES[1])
for i = 2, M.count() do check(M.VALUES[i] < M.VALUES[i - 1], "crans strictement decroissants " .. i) end
for i = 1, M.count() do check(M.VALUES[i] > 0 and M.VALUES[i] < M.WHEEL_LIMIT, "cran " .. i .. " sous la limite et positif") end
check(near(M.zoom_of(0), M.WHEEL_LIMIT), "cran 0 : la limite de la molette")
check(M.zoom_of(5) == nil and M.zoom_of(-1) == nil, "hors bornes : nil")

-- §2 descente puis remontée
local idx, z = 0, nil
for k = 1, 4 do
  idx, z = M.step(idx, true)
  check(idx == k and near(z, M.VALUES[k]), "descente " .. k, idx)
end
idx, z = M.step(idx, true)
check(idx == 4 and near(z, M.VALUES[4]), "au dernier cran, le bas reecrit le meme zoom", idx)
for k = 3, 1, -1 do
  idx, z = M.step(idx, false)
  check(idx == k and near(z, M.VALUES[k]), "remontee " .. k, idx)
end
idx, z = M.step(idx, false)
check(idx == 0 and near(z, M.WHEEL_LIMIT), "retour au cran 0 : ecrit la limite de la molette", z)
idx, z = M.step(idx, false)
check(idx == 0 and z == nil, "remonter au cran 0 : rien a ecrire", z)

-- §3 entrées abîmées (sauvegarde, nil)
idx, z = M.step(nil, true)
check(idx == 1 and near(z, M.VALUES[1]), "cran nil traite comme 0")
idx = M.step(99, false)
check(idx == 3, "cran trop grand ramene au dernier puis remonte", idx)
idx = M.step(-4, true)
check(idx == 1, "cran negatif ramene a 0", idx)

-- §4 pourcentage affiché
check(M.view_percent(M.WHEEL_LIMIT) == 100, "limite = 100 %")
check(M.view_percent(M.VALUES[1]) == 125, "cran 1 = 125 %", M.view_percent(M.VALUES[1]))

-- §5 câblage : touches, traductions, require
local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local proto = read("prototypes/dezoom.lua")
for _, n in ipairs({ "fo-dezoom-down", "fo-dezoom-up" }) do
  check(proto:find('name = "' .. n .. '"', 1, true), "prototype " .. n)
  for _, lang in ipairs({ "fr", "en" }) do
    check(read("locale/" .. lang .. "/dezoom.cfg"):find("\n" .. n .. "=", 1, true), "traduction " .. lang .. " de la touche " .. n)
  end
end
check(proto:find('"CONTROL + mouse-wheel-down"', 1, true) and proto:find('"CONTROL + mouse-wheel-up"', 1, true), "Ctrl + molette")
for _, lang in ipairs({ "fr", "en" }) do
  local cfg = read("locale/" .. lang .. "/dezoom.cfg")
  check(cfg:find("\ncran=", 1, true) and cfg:find("\nnormal=", 1, true), "messages " .. lang)
  check(cfg:find("__1__", 1, true) and cfg:find("__2__", 1, true) and cfg:find("__3__", 1, true), "parametres du message " .. lang)
end
check(read("control.lua"):find('require("script.gui.dezoom")', 1, true), "control.lua charge script.gui.dezoom")
check(read("data.lua"):find('require("prototypes.dezoom")', 1, true), "data.lua charge prototypes.dezoom")
local script = read("script/gui/dezoom.lua")
check(not script:find("on_tick", 1, true) and not script:find("on_nth_tick", 1, true), "aucune boucle par tick")

print(string.format("[DEZOOM] BILAN : %d OK, %d ECHEC(S)", ok, bad))
os.exit(bad == 0 and ok > 0 and 0 or 1)
