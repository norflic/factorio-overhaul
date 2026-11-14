--[[
  s43 3d-ecorches (13/11) : feuilles des Écorchés refondues (tools/render/pieces/titans/ecorche.py, modèle organique). Lua 5.2, depuis la
  racine du mod :   lua5.2 tests/s43_3d-ecorches_test.lua
    1. le modèle : SERIE (course 8, attaque 4, 8 directions implicites) et FOULEE lus dans ecorche.py ;
    2. les feuilles (graphics/robots/titans/sprites.lua, généré par feuilles_titans.py --seul ecorche) : animées, 8 directions, foulée =
       FOULEE du modèle (sinon les pieds glissent en jeu : distance_per_frame = foulée × échelle / images), course 8 et attaque 4 par
       variante, densité = SERIE.densite ;
    3. lisibilité : luminance mesurée rôdeur > hurleur > porteur (écarts >= 0,03) et chaque paire séparée par la luminance (>= 0,06)
       ou la couleur moyenne (distance RVB >= 0,08) (même règle que tests/titans_test.lua §8) ;
    4. mutants : une foulée fausse, des images manquantes, des luminances confondues sont refusées.
  Les PNG sont hors de git (D-6) : sans sprites.lua lisible, les §2 à §4 sont sautés (signalé).
]]
package.path = "./?.lua;" .. package.path

local T = require("shared.robots.titans")
local pass, fail = 0, 0
local function check(c, m)
  if c then pass = pass + 1 else fail = fail + 1; print("ECHEC : " .. m) end
end
local function read(p)
  local f = assert(io.open(p, "r"))
  local s = f:read("*a")
  f:close()
  return s
end
local function py_num(expr)
  local f = load("return " .. expr:gsub("%s+$", ""), "=py", "t", {})
  return f and f()
end

-- 1. modèle
local PY = read("tools/render/pieces/titans/ecorche.py")
local SERIE = {}
for k, v in PY:match("\nSERIE = {(.-)}"):gmatch('"(%a+)":%s*([%d%.]+)') do SERIE[k] = tonumber(v) end
local FOULEE = py_num(PY:match("\nFOULEE = ([^#\n]+)"))
check(SERIE.course == 8 and SERIE.attaque == 4, "1 modèle : course 8 images, attaque 4")
check(FOULEE and FOULEE > 0, "1 modèle : FOULEE lisible")
check(SERIE.densite and SERIE.densite >= 32, "1 modèle : densité du rendu")

-- 2 à 4 : feuilles
local function juge(EC)
  local refus = {}
  local function non(t) refus[#refus + 1] = t end
  if not (EC and EC.anime == true and EC.directions == 8) then non("feuilles non animées ou pas 8 directions") return refus end
  if not (EC.foulee and FOULEE and math.abs(EC.foulee - FOULEE) < 1e-3) then non("foulée des feuilles différente de FOULEE") end
  for iv, v in ipairs(T.ECORCHE.variants) do
    local e = EC[tostring(iv)]
    if not (e and e.course and e.attaque and e.course.images == SERIE.course and e.attaque.images == SERIE.attaque) then
      non("variante " .. v.id .. " : images de course ou d'attaque")
    elseif not (e.course.densite == SERIE.densite) then
      non("variante " .. v.id .. " : densité des feuilles différente de SERIE.densite")
    end
  end
  local M = EC.mesure or {}
  local l = {}
  for i, v in ipairs(T.ECORCHE.variants) do l[v.id] = M[tostring(i)] and M[tostring(i)].luminance end
  if not (l.rodeur and l.hurleur and l.porteur) then non("luminances non mesurées")
  elseif l.rodeur - l.hurleur < 0.03 or l.hurleur - l.porteur < 0.03 then non("luminances confondues ou dans le désordre")
  else
    for i = 1, 3 do
      for j = i + 1, 3 do
        local a, b = M[tostring(i)], M[tostring(j)]
        local dc = (a.rgb and b.rgb) and math.sqrt((a.rgb[1] - b.rgb[1]) ^ 2 + (a.rgb[2] - b.rgb[2]) ^ 2 + (a.rgb[3] - b.rgb[3]) ^ 2) or 0
        if math.abs(a.luminance - b.luminance) < 0.06 and dc < 0.08 then non("variantes " .. i .. "/" .. j .. " confondues (luminance et teinte)") end
      end
    end
  end
  return refus
end

local ok, SPR = pcall(dofile, "graphics/robots/titans/sprites.lua")
if not ok or not SPR or not SPR.ecorche then
  print("[S43-ECORCHES] sprites.lua illisible : §2 à §4 sautés")
else
  local EC = SPR.ecorche
  local r = juge(EC)
  check(#r == 0, "2-3 feuilles des Écorchés : " .. table.concat(r, " ; "))
  if EC.mesure then
    for i, v in ipairs(T.ECORCHE.variants) do
      local m = EC.mesure[tostring(i)]
      if m then print(string.format("[S43-ECORCHES] %s : luminance %.3f", v.id, m.luminance)) end
    end
  end
  local function copie(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in next, t do o[k] = copie(v) end
    return o
  end
  local muts = {
    { "foulée fausse", function(E) E.foulee = E.foulee * 1.8 end },
    { "attaque à 3 images", function(E) E["2"].attaque.images = 3 end },
    { "luminances confondues", function(E) E.mesure["1"].luminance = E.mesure["3"].luminance end },
    { "porteur plus clair que le hurleur", function(E) E.mesure["2"].luminance = E.mesure["3"].luminance + 0.1 end },
    { "rôdeur et hurleur de même couleur", function(E) E.mesure["1"].rgb = E.mesure["3"].rgb; E.mesure["1"].luminance = E.mesure["3"].luminance + 0.04 end },
  }
  for _, m in ipairs(muts) do
    local E = copie(EC)
    local okm = pcall(m[2], E)
    check(okm and #juge(E) > 0, "4 mutant refusé : " .. m[1])
  end
end

print(string.format("[S43-ECORCHES] %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
