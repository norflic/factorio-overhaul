--[[
  Lot STOCK-QG (preuve en moteur, demande du lead, 8/11) : la partie de etape1-geants (gisements immenses, 144 200 ticks) avec, toutes les
  10 minutes et pour chaque équipe, le CONTENU DU STOCK du QG (coffre du QG ET annexes, par l'interface fo-ia1 `stock_cost` : Stock.contents,
  remplissage, annexes) : lignes [FO-STOCK-QG]. Sert à comparer deux sources du mod (sans et avec les plafonds de rapatriement) sur la même
  carte : charbon, pierre, bois, fours de pierre, soufre, plaques de fer, puis les 8 objets les plus nombreux.
  Lancement : banc.py --out <archive> --qui stock-qg -- 144200 etape1-stock-qg <source>
  Lecture : tools/autotest/stock_qg_lecture.py <archive> [<archive> ...]
]]

local geants = require("scenarios/etape1-geants")

local base = {}
for k, v in pairs(geants) do base[k] = v end
local tick0 = geants.tick
base.description = "ETAPE1-STOCK-QG : etape1-geants + contenu du stock du QG toutes les 10 min"

local WATCH = { "coal", "stone", "wood", "iron-ore", "stone-furnace", "sulfur", "iron-plate", "copper-plate", "iron-gear-wheel" }

local function report(minute)
  local rows = remote.call("fo-ia1", "teams") or {}
  for _, r in ipairs(rows) do
    local ok, c = pcall(remote.call, "fo-ia1", "stock_cost", r.key, "copper-plate", 1, 1)
    if ok and type(c) == "table" and type(c.contents) == "table" then
      local ct = c.contents
      local w = {}
      for _, n in ipairs(WATCH) do w[#w + 1] = n .. "=" .. (ct[n] or 0) end
      local names = {}
      for n in pairs(ct) do names[#names + 1] = n end
      table.sort(names, function(a, b) if ct[a] ~= ct[b] then return ct[a] > ct[b] end return a < b end)
      local top = {}
      for i = 1, math.min(8, #names) do top[#top + 1] = names[i] .. "=" .. ct[names[i]] end
      log(string.format("[FO-STOCK-QG] minute %d | %s | cases %d/%d | annexes %d | %s | top %s", minute, r.key, c.fill_used or -1, c.fill_size or -1,
        c.annexes or -1, table.concat(w, " "), table.concat(top, " ")))
    else
      log(string.format("[FO-STOCK-QG] minute %d | %s | stock illisible", minute, r.key))
    end
  end
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick > 0 and e.tick % 36000 == 0 then
    local ok, err = pcall(report, e.tick / 3600)
    if not ok then log("[FO-STOCK-QG] ERREUR au tick " .. e.tick .. " : " .. tostring(err)) end
  end
end

return base
