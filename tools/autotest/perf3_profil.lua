--[[
  Lot PERF3 : profilage HORS JEU par échantillons (debug.sethook toutes les N instructions) d'un banc hors jeu : lignes et fonctions
  les plus vues. Mesure seulement (aucune écriture). Depuis la racine des sources :
    lua5.2 tools/autotest/perf3_profil.lua <banc, ex. tests/champ_colonne_test.lua> [plafond en s de processeur] [pas, défaut 1000]
]]
package.path = "./?.lua;" .. package.path
local test, cap, step = arg[1], tonumber(arg[2] or "") or math.huge, tonumber(arg[3] or "") or 1000
local counts, fcounts = {}, {}
local real_exit = os.exit
local done = false
local function report()
  if done then return end
  done = true
  debug.sethook()
  for _, pair in ipairs({ { counts, "lignes" }, { fcounts, "fonctions (ligne de definition)" } }) do
    local c, tot, keys = pair[1], 0, {}
    for k, v in pairs(c) do keys[#keys + 1] = k; tot = tot + v end
    table.sort(keys, function(a, b) return c[a] > c[b] end)
    print("-- " .. pair[2] .. string.format(" (%d echantillons)", tot))
    for i = 1, math.min(30, #keys) do print(string.format("%5.1f %%  %s", 100 * c[keys[i]] / tot, keys[i])) end
  end
end
local function hook()
  if os.clock() > cap then report(); real_exit(0) end
  local info = debug.getinfo(2, "Sl")
  if info then
    local k = info.short_src .. ":" .. (info.currentline or 0)
    counts[k] = (counts[k] or 0) + 1
    local kf = info.short_src .. ":" .. (info.linedefined or 0)
    fcounts[kf] = (fcounts[kf] or 0) + 1
  end
end
os.exit = function(c) report(); real_exit(c) end
debug.sethook(hook, "", step)
dofile(test)
report()
