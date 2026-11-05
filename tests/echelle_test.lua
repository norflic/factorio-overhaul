--[[
  Lot EXPERIMENTAUX-PUISSANCE (5/11) : banc hors jeu de la règle d'échelle par âge (shared/robots/echelle.lua). Lua 5.2, depuis la racine
  du mod :
      lua5.2 tests/echelle_test.lua
    §1 cibles du DC (QCM-5/11-XP) : une unité d'âge A tient au moins 3 min sous 10 déchiqueteurs du palier de son âge ; 5 salves tuent ce
       déchiqueteur, 4 non, pour chaque type de dégâts ; « mouche » : une mitrailleuse de 4 âges de moins ou plus lui fait au plus 3 % de
       ses dégâts sans résistance ; zone + 15 par âge (15 à l'âge 10, 90 à l'âge 15) ;
    §2 valeurs figées (âges 6 à 15) : fixe, PV, rayon, cratère ;
    §3 déchiqueteurs : relus contre la règle de prototypes/enemies.lua (palier 12 : 3,3 M PV, morsure 8 100, physique 76 / 74 %) ;
    §4 coût : plan trié par distance puis identifiant, plafonné, tranches qui couvrent tout une fois ;
    §5 forme : Lua pur, aucun pairs, aucun require dans une fonction ;
    §6 mutants : chaque règle a un mutant, tous refusés.
]]

package.path = "./?.lua;" .. package.path

local function read(p)
  local f = assert(io.open(p, "rb"), "lecture impossible : " .. p)
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/robots/echelle.lua")

local DTYPES = { "physical", "impact", "explosion", "fire", "acid", "poison", "laser", "electric" }

local FIXE = { [6] = 12.2, [7] = 16.1, [8] = 21.3, [9] = 28.2, [10] = 37.2, [11] = 49.2, [12] = 65.1, [13] = 258.2, [14] = 341.5, [15] = 451.7 }
local PV = { [6] = 27600, [7] = 79900, [8] = 171500, [9] = 358400, [10] = 640300, [11] = 1113300, [12] = 1873700, [13] = 3026000,
             [14] = 5074400, [15] = 8260200 }
local RAYON = { [10] = 15, [11] = 30, [12] = 45, [13] = 60, [14] = 75, [15] = 90 }

--- La suite pour un module (réel ou mutant). Rend ok, échecs, messages.
local function suite(Ech)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m) if c then pass = pass + 1 else fail = fail + 1; msgs[#msgs + 1] = m end end
  for a = 6, 15 do
    local p = Ech.palier(a)
    local b = Ech.dechiqueteur(p)
    -- §1 survie : 3 min sous 10 déchiqueteurs du palier de son âge
    local dps = 10 * (60 / b.cadence) * Ech.apres(b.morsure, Ech.fixe(a), 50)
    check(Ech.pv(a) >= 180 * dps and Ech.pv(a) < 180 * dps + 100, string.format("§1 âge %d : %d PV, tient %.0f s sous 10 déchiqueteurs du palier %d",
      a, Ech.pv(a), Ech.pv(a) / dps, p))
    -- §1 salves : 5 tuent, 4 non, pour chaque type
    for _, t in ipairs(DTYPES) do
      local s = Ech.salve(a, t)
      local r = b.res[t] or { 0, 0 }
      local net = s and Ech.apres(s, r[1], r[2])
      check(s and 5 * net >= b.pv and 4 * net < b.pv, string.format("§1 âge %d, %s : salve %s, 5 tuent le palier %d (%d PV), 4 non", a, t, tostring(s), p, b.pv))
    end
    -- §1 mouche : une mitrailleuse de l'âge A − 4 (ou moins) fait au plus 3 % de ses dégâts sans résistance
    for g = 4, 6 do
      local c = Ech.coup_tourelle(a - g)
      if c > 0 then
        check(Ech.apres(c, Ech.fixe(a), 50) <= 0.03 * c, string.format("§1 âge %d : mitrailleuse de l'âge %d (%.1f) réduite à %.3f", a, a - g, c,
          Ech.apres(c, Ech.fixe(a), 50)))
      end
    end
    -- et une mitrailleuse de son âge passe encore (pas d'immunité)
    check(Ech.apres(Ech.coup_tourelle(a), Ech.fixe(a), 50) >= 0.25 * Ech.coup_tourelle(a), "§1 âge " .. a .. " : une mitrailleuse de son âge passe encore")
    -- §2 valeurs figées
    check(math.abs(Ech.fixe(a) - FIXE[a]) < 0.06, string.format("§2 âge %d : fixe %.2f, attendu %.1f", a, Ech.fixe(a), FIXE[a]))
    check(Ech.pv(a) == PV[a], string.format("§2 âge %d : PV %d, attendu %d", a, Ech.pv(a), PV[a]))
    check(Ech.rayon(a) == RAYON[a], string.format("§2 âge %d : rayon %s, attendu %s", a, tostring(Ech.rayon(a)), tostring(RAYON[a])))
    check((Ech.cratere(a) == nil) == (RAYON[a] == nil) and (not RAYON[a] or math.abs(Ech.cratere(a) - RAYON[a] / 6) < 1e-9),
      "§2 âge " .. a .. " : cratère")
    local res = Ech.resistances(a)
    local ok = #res == #DTYPES
    for i, r in ipairs(res) do ok = ok and r.type == DTYPES[i] and math.abs(r.decrease - FIXE[a]) < 0.06 and r.percent == 50 end
    check(ok, "§2 âge " .. a .. " : résistances sur les 8 types, fixe et 50 %")
    if a > 6 then check(Ech.pv(a) > Ech.pv(a - 1), "§1 âge " .. a .. " : échelon, plus de PV qu'à l'âge " .. (a - 1)) end
  end
  -- §3 déchiqueteurs : comme prototypes/enemies.lua
  local d12 = Ech.dechiqueteur(12)
  check(d12.pv == 3300000 and d12.morsure == 8100 and d12.cadence == 50, "§3 palier 12 : 3,3 M PV, morsure 8 100 toutes les 50 ticks")
  check(d12.res.physical[1] == 76 and d12.res.physical[2] == 74 and d12.res.acid[1] == 64 and d12.res.acid[2] == 64 and d12.res.laser == nil,
    "§3 palier 12 : physique 76 / 74 %, acide 64 / 64 %, rien au laser")
  check(Ech.dechiqueteur(3).pv == 375 and Ech.dechiqueteur(4).morsure == 90, "§3 paliers vanilla")
  check(Ech.dechiqueteur(9).res.physical[1] == 52 and Ech.dechiqueteur(9).res.physical[2] == 50, "§3 palier 9 : physique 12 + 40 / 10 + 40 %")
  -- formule du moteur, valeurs écrites
  check(math.abs(Ech.apres(100, 20, 50) - 40) < 1e-9 and math.abs(Ech.apres(10, 10, 0) - 0.5) < 1e-9
    and math.abs(Ech.apres(5, 10, 0) - 1 / 7) < 1e-9 and math.abs(Ech.apres(5, 10, 50) - 1 / 14) < 1e-9, "§3 formule de dégâts du moteur")
  check(Ech.palier(15) == 12 and Ech.palier(6) == 3 and Ech.palier(1) == 1 and Ech.palier(20) == 12, "§3 palier de l'âge : A − 3, borné")
  -- §4 coût
  local cands = {}
  for i = 1, 50 do cands[i] = { x = (i * 37) % 17 - 8, y = (i * 53) % 13 - 6, id = 100 - i } end
  local plan = Ech.plan(cands, { x = 0, y = 0 })
  local sorted = #plan == math.min(50, Ech.PLAFOND)
  local function ring(c) return math.floor(math.sqrt(c.x * c.x + c.y * c.y) / Ech.ANNEAU) end
  local pos = {}
  for i, c in ipairs(cands) do pos[c] = i end
  for i = 2, #plan do
    local a, b = plan[i - 1], plan[i]
    if ring(a) > ring(b) or (ring(a) == ring(b) and pos[a] > pos[b]) then sorted = false end
  end
  check(sorted and Ech.ANNEAU == 3, "§4 plan rangé par anneau de 3 tuiles, du centre au bord, puis dans l'ordre d'entrée")
  check(cands[1].id == 99, "§4 la liste d'entrée n'est pas touchée")
  local big = {}
  for i = 1, Ech.PLAFOND + 500 do big[i] = { x = i % 90, y = 0, id = i } end
  check(#Ech.plan(big, { x = 0, y = 0 }) == Ech.PLAFOND, "§4 plafond par salve")
  local n, seen, dup = 1000, {}, false
  for k = 1, Ech.ticks(n) do
    local a, b = Ech.tranche(k, n)
    for i = a, b do if seen[i] then dup = true end seen[i] = true end
  end
  local all = true
  for i = 1, n do all = all and seen[i] == true end
  check(all and not dup and Ech.ticks(n) == math.ceil(n / Ech.TRANCHE), "§4 tranches : chaque cible une fois")
  return pass, fail, msgs
end

local Ech = require("shared.robots.echelle")
local pass, fail, msgs = suite(Ech)
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1; msgs[#msgs + 1] = m end end

-- §5 forme
check(not SRC:gsub("ipairs%(", ""):find("pairs%("), "§5 aucun pairs")
check(not SRC:find("game%.") and not SRC:find("script%.") and not SRC:find("%f[%w]global%f[%W]"), "§5 Lua pur (ni game, ni script, ni global)")

-- §6 mutants
local MUTANTS = {
  { "écart de 3 âges", "Ech.ECART = 4", "Ech.ECART = 3" },
  { "résistance à 30 %", "Ech.POURCENT = 50", "Ech.POURCENT = 30" },
  { "survie de 2 min", "Ech.SURVIE_S = 180", "Ech.SURVIE_S = 120" },
  { "meute de 5", "Ech.MEUTE = 10", "Ech.MEUTE = 5" },
  { "10 salves", "Ech.SALVES = 5", "Ech.SALVES = 10" },
  { "zone + 10 par âge", "Ech.PAS_ZONE = 15", "Ech.PAS_ZONE = 10" },
  { "zone décalée", "Ech.AGE_ZONE0 = 9", "Ech.AGE_ZONE0 = 10" },
  { "palier de l'âge A − 2", "Ech.DECALAGE_PALIER = 3", "Ech.DECALAGE_PALIER = 2" },
  { "formule sans le cas < 1", "if d < 1 then d = 1 / (2 - d) end", "if d < 0 then d = 0 end" },
  { "résistances du palier sans sa part fixe", "res[t] = { r[1] + nt.resist, math.min(95, r[2] + nt.resist) }", "res[t] = { r[1], math.min(95, r[2] + nt.resist) }" },
  { "acide oublié", 'or t == "acid" then', 'then' },
  { "munition chargeur", "return a <= 8 and 8 or 24", "return 5" },
  { "salve sans la part fixe", "return math.ceil(net / (1 - r[2] / 100) + r[1])", "return math.ceil(net / (1 - r[2] / 100))" },
  { "plan du bord vers le centre", "  for k = 1, top do", "  for k = top, 1, -1 do" },
  { "anneaux de 6 tuiles", "Ech.ANNEAU = 3", "Ech.ANNEAU = 6" },
  { "plafond ignoré", "if #out >= Ech.PLAFOND then return out end", "" },
  { "tranche qui saute une cible", "local a = (k - 1) * Ech.TRANCHE + 1", "local a = (k - 1) * Ech.TRANCHE + 2" },
  { "cratère au quart de la zone", "Ech.CRATERE_PART = 6", "Ech.CRATERE_PART = 4" },
  { "petits avec une zone", "if age < Ech.AGE_ZONE_MIN then return nil end", "" },
}
local kept = {}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif absent)" else
    local src = SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1)
    local f = load(src, "=mutant", "t")
    local bad = 1
    if f then
      local ok, M = pcall(f)
      if ok and type(M) == "table" then
        local ok2, _, ff = pcall(suite, M)
        bad = ok2 and ff or 1
      end
    end
    if bad == 0 then kept[#kept + 1] = m[1] end
  end
end
check(#kept == 0, "§6 mutants NON refusés : " .. table.concat(kept, " ; "))

for _, m in ipairs(msgs) do print("[ECHELLE] ECHEC " .. m) end
print(string.format("[ECHELLE] mutants refusés : %d sur %d", #MUTANTS - #kept, #MUTANTS))
print(string.format("[ECHELLE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
