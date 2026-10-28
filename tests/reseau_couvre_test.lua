--[[
  Lot RESEAU-VIVANT : test hors jeu de la couverture des consommateurs découverts (shared/team/reseau_couvre.lua), de bout en bout
  avec R.repair (shared/team/reseau.lua, qui choisit le plus petit ensemble) :
    §1 un consommateur découvert à 14 tuiles du réseau : peu de poteaux, et APRÈS la pose de ceux qui sont choisis il est alimenté ;
    §2 plusieurs consommateurs voisins (rangée de laboratoires) : un seul petit groupe de poteaux les alimente tous ;
    §3 consommateur hors d'atteinte (plus de REACH_MAX du réseau) : écarté, jamais de chaîne de 40 poteaux ;
    §4 tuiles occupées (free) : aucun candidat dessus ; le plan en tient compte et trouve un autre chemin ;
    §5 déterminisme et borne du nombre de candidats ;
    §6 aucun nom d'objet de jeu dans la règle ; mutants.
  Usage : lua5.2 tests/reseau_couvre_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local oks, fails = 0, 0
local function check(c, msg) if c then oks = oks + 1 else fails = fails + 1; print("  ECHEC : " .. msg) end end

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/reseau_couvre.lua")
local function load_c(src) local fn, err = load(src, "=couvre", "t"); assert(fn, err); return fn() end
local C = load_c(SRC)
local R = require("shared.team.reseau")

local function pole(x, y) return { x = x, y = y, wire = 7.5, supply = 2.5 } end
local function box(cx, cy, w) return { x0 = cx - w / 2, y0 = cy - w / 2, x1 = cx + w / 2, y1 = cy + w / 2 } end
local function all_free() return true end

--- Applique la proposition : candidats -> R.repair -> poteaux choisis ; rend { n poteaux, tous les consommateurs alimentés ? }.
local function solve(poles, boxes, producers, free)
  local res = C.candidates(boxes, poles, free)
  local plan = R.repair({ poles = poles, consumers = boxes, producers = producers }, res.cands)
  local after = {}
  for _, p in ipairs(poles) do after[#after + 1] = p end
  for _, j in ipairs(plan.chosen) do after[#after + 1] = res.cands[j] end
  local A = R.analyse({ poles = after, consumers = boxes, producers = producers })
  local ok = true
  for k = 1, #boxes do if not A.powered[k] then ok = false end end
  return #plan.chosen, ok, res, plan
end

local gen = { box(0, 0, 3) }
local net = { pole(2, 0), pole(8, 0), pole(14, 0), pole(20, 0) }

-- §1
local n, ok = solve(net, { box(30, 10, 3) }, gen, all_free)
check(ok, "un consommateur decouvert devient alimente apres la pose des poteaux choisis")
check(n >= 1 and n <= 4, "peu de poteaux pour 14 tuiles : " .. n)

-- §2
local row = { box(30, 10, 3), box(34, 10, 3), box(38, 10, 3) }
local n3, ok3 = solve(net, row, gen, all_free)
check(ok3, "trois consommateurs voisins : tous alimentes")
check(n3 <= n + 3, "trois consommateurs voisins : pas un groupe de poteaux par consommateur (" .. n3 .. " contre " .. n .. " pour un)")

-- §3
local far = { box(200, 0, 3) }
local res = C.candidates(far, net, all_free)
check(#res.cands == 0 and #res.skipped == 1, "consommateur a plus de REACH_MAX : aucun candidat, signale comme hors d'atteinte")

-- §4 : une rangee de tuiles occupees entre le reseau et le consommateur ; aucun candidat sur une tuile occupee
local function blocked(tx, ty) return not (ty == 4 or ty == 5) end -- seules les tuiles y = 4 et 5 sont libres (un couloir)
local rb = C.candidates({ box(30, 4.5, 3) }, net, blocked)
local bad = 0
for _, c in ipairs(rb.cands) do if blocked(math.floor(c.x), math.floor(c.y)) == false and false then bad = bad + 1 end end
for _, c in ipairs(rb.cands) do if not blocked(math.floor(c.x), math.floor(c.y)) then bad = bad + 1 end end
check(#rb.cands > 0 and bad == 0, "aucun candidat sur une tuile occupee (" .. #rb.cands .. " candidats, " .. bad .. " interdits)")
local nb, okb = solve(net, { box(30, 4.5, 3) }, gen, blocked)
check(okb, "couloir etroit : le consommateur est quand meme alimente (" .. nb .. " poteaux)")

-- §4 bis : une seule tuile libre, hors de la grille de couloir : seule la couronne autour du consommateur la propose
local function only_25_1(tx, ty) return tx == 25 and ty == 1 end
local nc, okc = solve(net, { box(24, 0, 3) }, gen, only_25_1)
check(okc and nc == 1, "une seule tuile libre autour du consommateur : un poteau suffit (" .. nc .. ")")

-- §5
local a1 = C.candidates(row, net, all_free)
local a2 = C.candidates(row, net, all_free)
local same = #a1.cands == #a2.cands
for i = 1, #a1.cands do same = same and a1.cands[i].x == a2.cands[i].x and a1.cands[i].y == a2.cands[i].y end
check(same and #a1.cands > 0, "deux appels identiques : memes candidats, memes ordres")
local big = {}
for i = 1, 12 do big[i] = box(25 + i * 3, 12, 3) end
check(#C.candidates(big, net, all_free).cands <= C.MAX, "nombre de candidats borne a C.MAX")
local sorted = true
for i = 2, #a1.cands do
  local p, q = a1.cands[i - 1], a1.cands[i]
  if q.y < p.y or (q.y == p.y and q.x < p.x) then sorted = false end
end
check(sorted, "candidats tries (y, x)")

-- §6 aucun nom d'objet de jeu
for _, w in ipairs({ "electric", "pole", "boiler", "steam", "lab", "inserter", "assembling" }) do
  local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:find('"[^"]*' .. w .. '[^"]*"'), "aucun nom d'objet (" .. w .. ") dans une chaine de la regle")
end

-- mutants
local muts = {
  { "tuiles occupees acceptees", "if free(t.tx, t.ty) then out", "if true then out" },
  { "hors d'atteinte traite", "qd > C.REACH_MAX * C.REACH_MAX", "false" },
  { "couverture oubliee", "for ty = y0, y1 do for tx = x0, x1 do add(cover, tx, ty) end end", "" },
  { "couloir oublie", "if (tx - rx0) % step == 0 then add(grid, tx, ty) end", "" },
  { "borne ignoree", "if #out >= limit then return end", "" },
  { "tri oublie", "table.sort(out, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)", "" },
}
local refused = 0
for _, m in ipairs(muts) do
  local s, e = SRC:find(m[2], 1, true)
  assert(s, "mutant introuvable : " .. m[1])
  local C2 = load_c(SRC:sub(1, s - 1) .. m[3] .. SRC:sub(e + 1))
  local killed = false
  local nn, oo = (function()
    local res2 = C2.candidates({ box(30, 10, 3) }, net, all_free)
    local plan2 = R.repair({ poles = net, consumers = { box(30, 10, 3) }, producers = gen }, res2.cands)
    local after = {}
    for _, p in ipairs(net) do after[#after + 1] = p end
    for _, j in ipairs(plan2.chosen) do after[#after + 1] = res2.cands[j] end
    local A = R.analyse({ poles = after, consumers = { box(30, 10, 3) }, producers = gen })
    return #plan2.chosen, A.powered[1]
  end)()
  if not oo then killed = true end
  local r3 = C2.candidates({ box(200, 0, 3) }, net, all_free)
  if #r3.cands > 0 then killed = true end
  local r6 = C2.candidates({ box(24, 0, 3) }, net, only_25_1)
  if #r6.cands == 0 then killed = true end
  local r4 = C2.candidates({ box(30, 4.5, 3) }, net, blocked)
  for _, c in ipairs(r4.cands) do if not blocked(math.floor(c.x), math.floor(c.y)) then killed = true end end
  local r5 = C2.candidates(big, net, all_free)
  if #r5.cands > C.MAX then killed = true end
  local ra, rb2 = C2.candidates(row, net, all_free).cands, a1.cands
  local so = true
  for i = 2, #ra do if ra[i].y < ra[i - 1].y or (ra[i].y == ra[i - 1].y and ra[i].x < ra[i - 1].x) then so = false end end
  if not so then killed = true end
  check(killed, "mutant refuse : " .. m[1])
  if killed then refused = refused + 1 end
end
print(string.format("[COUVRE] mutants refuses : %d sur %d", refused, #muts))
print(string.format("[COUVRE] BILAN : %d OK, %d ECHEC(S)", oks, fails))
os.exit(fails == 0 and 0 or 1)
