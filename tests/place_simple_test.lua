--[[
  Lot TV-PLACE, C07 : test hors jeu de shared/team/place_simple.lua (repli de placement simple).
    lua5.2 tests/place_simple_test.lua   -> [PLACE-SIMPLE] BILAN : N OK, 0 ECHEC(S)
  Mutants : substitution unique dans le source, rechargé ; la suite doit ECHOUER.
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/team/place_simple.lua"
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[PLACE-SIMPLE] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local SRC = read(PATH)
local function load_mod(src) return assert(load(src, "=" .. PATH, "t", _ENV))() end

local function lot(i, j, state, extra)
  local l = { k = i .. ":" .. j, i = i, j = j, state = state or "libre" }
  for k, v in pairs(extra or {}) do l[k] = v end
  return l
end

local function suite(Ps)
  local bad, n = {}, 0
  local function want(ok, msg) n = n + 1 if not ok then bad[#bad + 1] = msg end end
  local FAB = { libre = true, defricher = true, no_edge = true }
  -- 1. Éligibilité : états, lots pris, hors contour, bord de gisement.
  want(Ps.eligible(lot(1, 0), FAB), "lot libre : eligible")
  want(Ps.eligible(lot(1, 0, "defricher"), FAB), "lot a defricher : eligible")
  want(not Ps.eligible(lot(1, 0, "gisement"), FAB), "une fabrique ne va pas sur un gisement")
  want(not Ps.eligible(lot(1, 0, "libre", { used = 4 }), FAB), "lot pris : exclu")
  want(Ps.eligible(lot(1, 0, "gisement", { used = 4 }), { gisement = true }), "un gisement pris sert encore (plusieurs lignes)")
  want(not Ps.eligible(lot(1, 0, "libre", { out = true }), FAB), "lot hors du contour : exclu")
  want(not Ps.eligible(lot(1, 0, "libre", { edge = "r_commun" }), FAB), "lot en bord de gisement : exclu pour une fabrique")
  want(Ps.eligible(lot(1, 0, "libre", { edge = "r_commun" }), { libre = true, defricher = true }), "le bord est permis a la fonte (pas de marque no_edge)")
  want(not Ps.eligible(lot(1, 0, "occupe"), FAB), "lot occupe : exclu")
  want(Ps.eligible(lot(1, 0, "refuse", { reason = "eau" }), { rive = true, eau = true }), "lot refuse pour l'eau : permis a l'etat eau")
  want(not Ps.eligible(lot(1, 0, "refuse", { reason = "nid" }), { rive = true, eau = true }), "lot refuse pour un nid : jamais")
  want(Ps.eligible(lot(1, 0, "libre", { bad = 5 }), FAB), "le compteur d'echecs n'ecarte plus un lot")
  want(not Ps.eligible(nil, FAB) and not Ps.eligible(lot(1, 0), nil), "entrees absentes : refus")
  -- 2. Ordre de la spirale : couronne, distance, j, i.
  local lots = {}
  for j = -2, 2 do for i = -2, 2 do lots[#lots + 1] = lot(i, j) end end
  local o = Ps.order(lots, FAB, 8)
  want(#o == 8, "8 lots demandes, 8 rendus")
  local set = {}
  for _, k in ipairs(o) do set[k] = true end
  want(set["0:-1"] and set["1:0"] and set["0:1"] and set["-1:0"] and set["-1:-1"] and set["1:-1"] and set["-1:1"] and set["1:1"], "la premiere couronne entiere d'abord")
  want(o[1] == "0:-1" and o[2] == "-1:0" and o[3] == "1:0" and o[4] == "0:1", "d2 = 1 d'abord : nord, ouest, est, sud (j puis i)")
  want(not set["0:0"], "le lot du QG n'est jamais offert")
  want(Ps.order(lots, FAB)[Ps.MAX_LOTS + 1] == nil and #Ps.order(lots, FAB) == Ps.MAX_LOTS, "Ps.MAX_LOTS lots par defaut")
  local oc = Ps.order({ lot(4, 0), lot(3, 3) }, FAB, 2)
  want(oc[1] == "3:3" and oc[2] == "4:0", "la couronne prime sur la distance : 3:3 (couronne 3, d2 18) avant 4:0 (couronne 4, d2 16)")
  -- 3. Ordre indépendant de l'ordre d'entrée (aucun `pairs`, tri total).
  local rev = {}
  for idx = #lots, 1, -1 do rev[#rev + 1] = lots[idx] end
  local o2 = Ps.order(rev, FAB, 12)
  local o1 = Ps.order(lots, FAB, 12)
  local same = #o1 == #o2
  for idx = 1, #o1 do if o1[idx] ~= o2[idx] then same = false end end
  want(same, "meme ordre quel que soit l'ordre d'entree")
  -- 4. Écarts : lots pris et bords sautés, les suivants avancent.
  local lots2 = { lot(0, -1, "libre", { used = 3 }), lot(-1, 0, "libre", { edge = "r_commun" }), lot(1, 0), lot(0, 1), lot(2, 0) }
  local o3 = Ps.order(lots2, FAB, 2)
  want(#o3 == 2 and o3[1] == "1:0" and o3[2] == "0:1", "pris et bord sautes : 1:0 puis 0:1")
  want(#Ps.order({}, FAB) == 0 and #Ps.order(nil, FAB) == 0, "aucun lot : liste vide")
  -- 5. Options : la marge seule.
  local fo = Ps.fit_opts()
  want(fo.margin == 0 and fo.nobad == true and fo.toward == nil and fo.head_toward == nil and fo.fan == nil and fo.cover_min == nil, "fit_opts : marge 0, ni tete, ni eventail, ni couverture")
  want(Ps.MAX_LOTS == 6 and Ps.MARGIN == 0, "constantes")
  return bad, n
end

local bad, n = suite(load_mod(SRC))
for _, m in ipairs(bad) do check(false, m) end
pass = pass + (n - #bad)

local MUTANTS = {
  { "Ps.MAX_LOTS = 6", "Ps.MAX_LOTS = 5" },
  { "Ps.MARGIN = 0", "Ps.MARGIN = 1" },
  { "if l.used and l.state ~= \"gisement\" then return false end", "" },
  { "if l.used and l.state ~= \"gisement\" then return false end", "if l.used then return false end" },
  { "if l.out and (l.state == \"libre\" or l.state == \"defricher\") then return false end", "" },
  { "if states.no_edge and l.edge then return false end", "" },
  { "(states.eau and l.state == \"refuse\" and l.reason == \"eau\")", "(states.eau and l.state == \"refuse\")" },
  { "if Ps.eligible(l, states) and not (l.i == 0 and l.j == 0) then", "if Ps.eligible(l, states) then" },
  { "if n < max or before(l, top[n]) then", "if n < max then" },
  { "while pos > 1 and before(l, top[pos - 1]) do pos = pos - 1 end", "" },
  { "if #top > max then top[#top] = nil end", "" },
  { "if ra ~= rb then return ra < rb end", "" },
  { "if da ~= db then return da < db end", "" },
  { "if a.j ~= b.j then return a.j < b.j end", "if a.j ~= b.j then return a.j > b.j end" },
  { "if a.i ~= b.i then return a.i < b.i end", "if a.i ~= b.i then return a.i > b.i end" },
  { "return { margin = Ps.MARGIN, nobad = true }", "return { margin = Ps.MARGIN }" },
}
local killed = 0
for i, mu in ipairs(MUTANTS) do
  local s, e = SRC:find(mu[1], 1, true)
  if not s then
    check(false, "mutant " .. i .. " : motif introuvable")
  else
    local src2 = SRC:sub(1, s - 1) .. mu[2] .. SRC:sub(e + 1)
    local ok, mod = pcall(load_mod, src2)
    local survived = ok and #(suite(mod)) == 0
    if survived then check(false, "mutant " .. i .. " survit : " .. mu[1] .. " -> " .. mu[2]) else killed = killed + 1 end
  end
end
pass = pass + killed
print(string.format("[PLACE-SIMPLE] BILAN : %d OK, %d ECHEC(S) (dont %d mutants sur %d refuses)", pass, fail, killed, #MUTANTS))
os.exit(fail == 0 and 0 or 1)
