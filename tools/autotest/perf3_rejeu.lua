--[[
  Lot PERF3 : rejeu HORS JEU du plan du champ (Ch.plan, règle pure de shared/team/champ.lua) sur les ENTRÉES relevées en moteur réel
  par le banc de détail (lignes « [FO-PERF3-DUMP] <tick> champ-frame|champ-band <table> », script/core/profiler.lua, Profiler.dump).
  Mesure le temps de chaque plan (os.clock) et écrit chaque RÉSULTAT sérialisé (clés triées) : deux sources du mod (avant / après une
  optimisation) rejouées sur les mêmes entrées doivent écrire des fichiers IDENTIQUES (équivalence au plan près).

    zcat <archive>/benchmark.log.gz | grep FO-PERF3-DUMP > dumps.txt
    lua5.2 tools/autotest/perf3_rejeu.lua dumps.txt sortie.txt [racine des sources du mod, défaut .] [tours, défaut 1]
    cmp sortie-avant.txt sortie-apres.txt

  Aucune API Factorio (les modules du plan sont du Lua pur) ; rien n'est écrit ailleurs que dans le fichier de sortie.
]]
local dumps, outp, root, tours = arg[1], arg[2], arg[3] or ".", tonumber(arg[4] or "1")
assert(dumps and outp, "usage : lua5.2 perf3_rejeu.lua <dumps> <sortie> [racine] [tours]")
package.path = root .. "/?.lua;" .. package.path
local Ch = require("shared.team.champ")

local function ser(v, out)
  local t = type(v)
  if t == "number" then
    if v ~= v then out[#out + 1] = "nan"
    elseif v == math.floor(v) and math.abs(v) < 2 ^ 53 then out[#out + 1] = string.format("%d", v)
    else out[#out + 1] = string.format("%.17g", v) end
  elseif t == "string" then out[#out + 1] = string.format("%q", v)
  elseif t == "boolean" then out[#out + 1] = v and "true" or "false"
  elseif t == "table" then
    local nk, sk = {}, {}
    for k in pairs(v) do
      if type(k) == "number" then nk[#nk + 1] = k elseif type(k) == "string" then sk[#sk + 1] = k end
    end
    table.sort(nk)
    table.sort(sk)
    out[#out + 1] = "{"
    for _, k in ipairs(nk) do out[#out + 1] = "[" .. k .. "]="; ser(v[k], out); out[#out + 1] = "," end
    for _, k in ipairs(sk) do out[#out + 1] = "[" .. string.format("%q", k) .. "]="; ser(v[k], out); out[#out + 1] = "," end
    out[#out + 1] = "}"
  elseif t == "function" then out[#out + 1] = "<fonction>"
  else out[#out + 1] = "nil" end
end

local out = assert(io.open(outp, "w"))
local n, total, worst, worst_at = 0, 0, 0, "-"
for line in io.lines(dumps) do
  local tick, label, body = line:match("%[FO%-PERF3%-DUMP%] (%d+) (%S+) (.*)$")
  if tick then
    local best = math.huge
    local res
    for _ = 1, tours do
      local d = assert(load("return " .. body))()
      local saved = {}
      for k, v in pairs(d.cfg or {}) do saved[k] = Ch.CFG[k]; Ch.CFG[k] = v end
      local t0 = os.clock()
      local p, why = Ch.plan(d.spec)
      local ms = (os.clock() - t0) * 1000
      for k, v in pairs(saved) do Ch.CFG[k] = v end
      if ms < best then best = ms end
      res = { plan = p, why = why }
    end
    local parts = {}
    ser(res, parts)
    n = n + 1
    total = total + best
    if best > worst then worst, worst_at = best, tick .. " " .. label end
    out:write(string.format("%s %s ", tick, label), table.concat(parts), "\n")
    print(string.format("%8s %-12s %9.1f ms  %s", tick, label, best,
      res.plan and string.format("%d entites", #(res.plan.ents or {})) or ("refus : " .. tostring(res.why))))
  end
end
out:close()
print(string.format("[PERF3-REJEU] %d plan(s), %.0f ms en tout, le plus long %.1f ms (%s)", n, total, worst, worst_at))
