--[[
  Lot L12 (hystérésis et verrou des crises) : test hors jeu de shared/ai3/hysteresis.lua. Lancer depuis la racine du mod :
    lua5.2 tests/hysteresis_test.lua   -> [L12] BILAN : N OK, 0 ECHEC(S)
  Mutants : le source du module est relu, une ligne est changée (substitution unique, contrôlée), le module muté est rechargé et la
  suite doit ÉCHOUER. Coût : instructions de la machine virtuelle comptées par debug.sethook (jamais une horloge).
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/ai3/hysteresis.lua"
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[L12] ECHEC : " .. msg) end
end

local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local SRC = read(PATH)
local function load_mod(src) return assert(load(src, "=" .. PATH, "t", _ENV))() end

-- La suite : rend une liste de défauts (vide = la règle tient).
local function suite(H)
  local bad = {}
  local function want(ok, msg) if not ok then bad[#bad + 1] = msg end end
  -- 1. Oscillation autour du seuil d'entrée : 39, 41, 39, 41... ne fait qu'UNE entrée et aucune sortie.
  local st = H.new()
  local n_ev = 0
  for i = 1, 20 do
    local _, ev = H.update(st, (i % 2 == 1) and 39 or 41, 40, 50, false)
    if ev == "entree" or ev == "sortie" then n_ev = n_ev + 1 end
  end
  want(st.crise == true and st.entrees == 1 and n_ev == 1, "oscillation 39/41 : une seule bascule attendue (" .. n_ev .. ", entrees " .. tostring(st.entrees) .. ")")
  -- 2. Entre les deux seuils, rien ne change ; au-dessus de la sortie, la crise se ferme.
  st = H.new()
  H.update(st, 45, 40, 50, false)
  want(st.crise == false, "45 sans crise : pas d'entree")
  H.update(st, 40, 40, 50, false)
  want(st.crise == false, "40 n'entre pas (strict)")
  H.update(st, 39.9, 40, 50, false)
  want(st.crise == true and st.besoin == true, "39,9 : entree et besoin")
  H.update(st, 50, 40, 50, false)
  want(st.crise == true, "50 ne sort pas (strict)")
  local _, ev = H.update(st, 51, 40, 50, false)
  want(st.crise == false and ev == "sortie", "51 : sortie")
  -- 3. VERROU : la crise fermée, le besoin reste jusqu'à la pose.
  want(st.besoin == true, "besoin gardé apres la sortie de crise (verrou)")
  for _ = 1, 5 do H.update(st, 80, 40, 50, false) end
  want(st.besoin == true, "besoin garde tant que rien n'est pose")
  _, ev = H.update(st, 80, 40, 50, true)
  want(st.besoin == false and ev == "pose" and st.poses == 1, "pose : besoin libere")
  -- 4. Pose pendant la crise : pas de réarmement à la mesure de la pose, réarmement à la suivante si la crise dure.
  st = H.new()
  H.update(st, 30, 40, 50, false)
  _, ev = H.update(st, 30, 40, 50, true)
  want(st.crise == true and st.besoin == false and ev == "pose", "pose en crise : besoin libere a cette mesure")
  _, ev = H.update(st, 30, 40, 50, false)
  want(st.besoin == true and ev == "rearme", "crise qui dure apres la pose : rearme (" .. tostring(ev) .. ")")
  _, ev = H.update(st, 60, 40, 50, true)
  want(st.crise == false and st.besoin == false, "pose et sortie a la meme mesure")
  -- 5. Mesure absente : rien ne change (garde fermée).
  st = H.new()
  H.update(st, 10, 40, 50, false)
  _, ev = H.update(st, nil, 40, 50, false)
  want(st.crise == true and st.besoin == true and ev == "absent", "absent : la crise reste")
  _, ev = H.update(st, 0 / 0, 40, 50, false)
  want(st.crise == true and ev == "absent", "NaN : la crise reste")
  -- 6. Seuils inversés : refusés.
  st = H.new()
  _, ev = H.update(st, 10, 50, 40, false)
  want(st.crise == false and ev == "seuils", "seuils inverses refuses")
  -- 7. sortie_n : 3 mesures de suite au-dessus de la sortie.
  st = H.new()
  H.update(st, 10, 40, 50, false)
  H.update(st, 60, 40, 50, false, { sortie_n = 3 })
  H.update(st, 60, 40, 50, false, { sortie_n = 3 })
  H.update(st, 45, 40, 50, false, { sortie_n = 3 })
  H.update(st, 60, 40, 50, false, { sortie_n = 3 })
  want(st.crise == true, "sortie_n : la serie est remise a zero sous la sortie")
  H.update(st, 60, 40, 50, false, { sortie_n = 3 })
  H.update(st, 60, 40, 50, false, { sortie_n = 3 })
  want(st.crise == false, "sortie_n : 3 mesures de suite ferment la crise")
  -- 8. Haut = mauvais (menace) : entrée au-dessus de 2 unités, sortie sous 1 (0 unité) ; 1 ou 2 : rien ne change.
  st = H.new()
  H.update_haut(st, 2, 2, 1, false)
  want(st.crise == false, "haut : 2 unites sans crise (strict)")
  H.update_haut(st, 3, 2, 1, false)
  want(st.crise == true and st.besoin == true, "haut : 3 unites, crise")
  H.update_haut(st, 1, 2, 1, false)
  want(st.crise == true, "haut : 1 unite, la crise dure (hysteresis)")
  H.update_haut(st, 0, 2, 1, false)
  want(st.crise == false and st.besoin == true, "haut : plus d'unite, crise fermee, besoin garde")
  _, ev = H.update_haut(st, 0, 1, 2, false)
  want(ev == "seuils", "haut : seuils inverses refuses (entree < sortie)")
  H.update_haut(st, 0, 2, 1, true)
  want(st.besoin == false, "haut : pose libere")
  -- 9. Déterminisme : deux suites identiques, mêmes états.
  local a, b = H.new(), H.new()
  local seq = { 45, 39, 41, 52, 38, 38, 55, 60, 30, 49 }
  for i, v in ipairs(seq) do
    H.update(a, v, 40, 50, i % 4 == 0)
    H.update(b, v, 40, 50, i % 4 == 0)
  end
  want(H.describe(a) == H.describe(b), "deterministe")
  return bad
end

-- Suite sur le vrai module.
local H = require("shared.ai3.hysteresis")
local bad = suite(H)
for _, m in ipairs(bad) do check(false, m) end
check(#bad == 0, "suite du module")
print(string.format("[L12] suite : %d defaut(s)", #bad))

-- Mutants (chacun DOIT faire échouer la suite).
local MUTANTS = {
  { "seuil unique (sortie = entree)", "if valeur > sortie then st.haut_n", "if valeur >= entree then st.haut_n" },
  { "verrou leve a la sortie de crise", "st.crise, st.haut_n = false, 0", "st.crise, st.haut_n, st.besoin = false, 0, false" },
  { "pose ignoree", "if pose and st.besoin then", "if false and pose then" },
  { "mesure absente = 0 (leve ou ouvre la crise)", 'if not num(valeur) then return st, "absent" end\n  local ev', 'if not num(valeur) then valeur = 100 end\n  local ev' },
  { "entree au-dessus au lieu de dessous", "if valeur < entree then", "if valeur > entree then" },
  { "sortie_n ignore", "local need_n = (opts and opts.sortie_n) or 1", "local need_n = 1" },
  { "pas de rearmement apres la pose", "elseif not st.besoin and ev ~= \"pose\" then", "elseif false then" },
  { "rearmement a la mesure de la pose", "elseif not st.besoin and ev ~= \"pose\" then", "elseif not st.besoin then" },
  { "seuils inverses acceptes", "or entree > sortie then return st, \"seuils\" end\n  if not num(valeur)", "then return st, \"seuils\" end\n  if not num(valeur)" },
}
local refused = 0
for _, m in ipairs(MUTANTS) do
  local s, n = SRC:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")))
  if n ~= 1 then
    check(false, "mutant introuvable (" .. n .. " substitution(s)) : " .. m[1])
  else
    local ok, Hm = pcall(load_mod, s)
    local ran, sb = false, nil
    if ok then ran, sb = pcall(suite, Hm) end
    local killed = (not ok) or (not ran) or (#sb > 0)
    if killed then refused = refused + 1 else print("[L12] mutant NON refuse : " .. m[1]) end
    check(killed, "mutant refuse : " .. m[1])
  end
end
print(string.format("[L12] mutants refuses : %d sur %d", refused, #MUTANTS))

-- Coût en INSTRUCTIONS (debug.sethook, compte de 1 : chaque instruction de la VM).
local function instr(fn, n)
  local worst = 0
  for _ = 1, n do
    local c = 0
    debug.sethook(function() c = c + 1 end, "", 1)
    fn()
    debug.sethook()
    if c > worst then worst = c end
  end
  return worst
end
local st = H.new()
local i = 0
local w = instr(function() i = i + 1 H.update(st, (i % 3) * 30, 40, 50, i % 5 == 0, { sortie_n = 2 }) end, 200)
local wh = instr(function() i = i + 1 H.update_haut(st, i % 4, 2, 1, i % 5 == 0) end, 200)
print(string.format("[L12] cout : H.update pire %d instructions, H.update_haut pire %d (sethook, compte de 1)", w, wh))
check(w <= 150 and wh <= 200, "cout borne : H.update <= 150 instructions, H.update_haut <= 200 (" .. w .. ", " .. wh .. ")")

print(string.format("[L12] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
