--[[
  Lot PERF3 : ÉQUIVALENCE OCTET À OCTET du plan du champ entre deux sources du mod. Rejoue un banc hors jeu (champ_test,
  champ_colonne_test…) en enregistrant CHAQUE appel de Ch.plan (shared/team/champ.lua) et de Co.route (shared/team/champ_colonne.lua) :
  son résultat sérialisé (clés triées), une ligne par appel, dans l'ordre ; de même pour Cv.verify (shared/team/champ_verif.lua). Deux sources (avant / après une optimisation) qui écrivent
  le même fichier rendent les mêmes plans sur toutes les entrées du banc.

    cd <racine des sources>          (le banc charge ./shared/... : la source mesurée est le dossier courant)
    lua5.2 <ce fichier> <banc hors jeu, ex. tests/champ_test.lua> <sortie>
    cmp sortie-avant sortie-apres

  Le temps de chaque appel n'est PAS écrit (il change d'une source à l'autre) ; la somme est affichée à la fin.
]]
local test, outp = arg[1], arg[2]
assert(test and outp, "usage : lua5.2 perf3_plans.lua <banc> <sortie>")
package.path = "./?.lua;" .. package.path
local Ch = require("shared.team.champ")
local Co = require("shared.team.champ_colonne")
local Cv = require("shared.team.champ_verif")

local function ser(v, out, seen)
  local t = type(v)
  if t == "number" then
    if v ~= v then out[#out + 1] = "nan"
    elseif v == math.floor(v) and math.abs(v) < 2 ^ 53 then out[#out + 1] = string.format("%d", v)
    else out[#out + 1] = string.format("%.17g", v) end
  elseif t == "string" then out[#out + 1] = string.format("%q", v)
  elseif t == "boolean" then out[#out + 1] = v and "true" or "false"
  elseif t == "table" then
    if seen[v] then out[#out + 1] = "<cycle>" return end
    seen[v] = true
    local nk, sk = {}, {}
    for k in pairs(v) do
      if type(k) == "number" then nk[#nk + 1] = k elseif type(k) == "string" then sk[#sk + 1] = k end
    end
    table.sort(nk)
    table.sort(sk)
    out[#out + 1] = "{"
    for _, k in ipairs(nk) do out[#out + 1] = "[" .. k .. "]="; ser(v[k], out, seen); out[#out + 1] = "," end
    for _, k in ipairs(sk) do out[#out + 1] = "[" .. string.format("%q", k) .. "]="; ser(v[k], out, seen); out[#out + 1] = "," end
    out[#out + 1] = "}"
    seen[v] = nil
  elseif t == "function" then out[#out + 1] = "<fonction>"
  else out[#out + 1] = "nil" end
end
local function s(v) local o = {}; ser(v, o, {}); return table.concat(o) end

local out = assert(io.open(outp, "w"))
local n_plan, n_route, ms_plan = 0, 0, 0
local real_plan, real_route = Ch.plan, Co.route
local depth = 0
Ch.plan = function(spec)
  depth = depth + 1
  local t0 = os.clock()
  local p, why = real_plan(spec)
  if depth == 1 then ms_plan = ms_plan + (os.clock() - t0) * 1000 end
  depth = depth - 1
  n_plan = n_plan + 1
  out:write("plan ", s({ p = p, why = why }), "\n")
  return p, why
end
Co.route = function(...)
  local r, w = real_route(...)
  n_route = n_route + 1
  out:write("route ", s({ r = r, w = w }), "\n")
  return r, w
end
local real_verify = Cv.verify
Cv.verify = function(...)
  local rep = real_verify(...)
  out:write("verif ", s(rep), "\n")
  return rep
end
local real_exit = os.exit
os.exit = function(c)
  out:close()
  print(string.format("[PERF3-PLANS] %s : %d plan(s), %d trace(s), %.0f ms dans Ch.plan", test, n_plan, n_route, ms_plan))
  real_exit(c)
end
dofile(test)
os.exit(0)
