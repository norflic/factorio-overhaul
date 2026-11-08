--[[
  Lot TV-PLACE, G38 : test hors jeu de shared/team/defrichage_prev.lua (défrichage préventif 50 x 50).
    lua5.2 tests/defrichage_prev_test.lua   -> [DEFRICHAGE-PREV] BILAN : N OK, 0 ECHEC(S)
  Mutants : substitution unique dans le source, rechargé ; la suite doit ECHOUER.
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/team/defrichage_prev.lua"
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[DEFRICHAGE-PREV] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local SRC = read(PATH)
local function load_mod(src) return assert(load(src, "=" .. PATH, "t", _ENV))() end

local function lot(i, j, state, extra)
  local l = { k = i .. ":" .. j, i = i, j = j, state = state or "defricher" }
  for k, v in pairs(extra or {}) do l[k] = v end
  return l
end

local function suite(Dp)
  local bad, n = {}, 0
  local function want(ok, msg) n = n + 1 if not ok then bad[#bad + 1] = msg end end
  -- 1. Géométrie : 50 x 50 centré, quatre quarts de 25 x 25.
  want(Dp.SIZE == 50 and Dp.QUARTERS == 4, "50 x 50 en 4 quarts")
  local x0, y0, x1, y1 = Dp.rect(100, 200, 124, 224)
  want(x0 == 87 and y0 == 187 and x1 == 137 and y1 == 237, "zone 50 x 50 centree sur le lot de 24 : (87,187)-(137,237)")
  want(x1 - x0 == 50 and y1 - y0 == 50, "cote 50")
  local ux0, uy0, ux1, uy1 = Dp.rect(0, 0, 60, 60)
  want(ux0 == 0 and uy0 == 0 and ux1 == 60 and uy1 == 60, "un lot plus large que la zone : inchange")
  local qs = Dp.quarters(x0, y0, x1, y1)
  want(#qs == 4 and qs[1].x0 == 87 and qs[1].x1 == 112 and qs[1].y1 == 212, "quart NO 25 x 25")
  want(qs[4].x0 == 112 and qs[4].x1 == 137 and qs[4].y0 == 212 and qs[4].y1 == 237, "quart SE")
  want(qs[2].ax == 124.5 and qs[2].ay == 199.5, "point d'appui = centre du quart NE")
  for q = 1, 4 do want(qs[q].q == q and qs[q].x1 - qs[q].x0 == 25 and qs[q].y1 - qs[q].y0 == 25, "quart " .. q .. " : 25 x 25") end
  -- 2. Choix : le plus proche du QG, parmi les lots à défricher libres.
  local st = Dp.new()
  local lots = { lot(2, 0), lot(1, 1), lot(0, 1), lot(-1, 0), lot(0, 0), lot(0, 2, "libre"), lot(1, 0, "defricher", { used = 5 }) }
  local k, why = Dp.pick(lots, st, 100000, {})
  want(k == "-1:0", "le plus proche du QG : -1:0 (couronne 1, d2 1, j 0, i -1) ; recu " .. tostring(k) .. " " .. tostring(why))
  want((Dp.pick({ lot(0, 0) }, st, 100000, {})) == nil, "le lot du QG n'est jamais defriche d'avance")
  want((Dp.pick({ lot(1, 0, "libre"), lot(1, 1, "occupe"), lot(0, 1, "gisement") }, st, 100000, {})) == nil, "seuls les lots a defricher")
  want((Dp.pick({ lot(4, 0) }, st, 100000, {})) == nil, "au-dela de Dp.RING_MAX couronnes : non")
  want((Dp.pick({ lot(3, 3) }, st, 100000, {})) == "3:3", "a Dp.RING_MAX couronnes : oui")
  want((Dp.pick({ lot(1, 0, "defricher", { out = true }) }, st, 100000, {})) == nil, "hors contour : non")
  want((Dp.pick({ lot(1, 0, "defricher", { bad = 2 }) }, st, 100000, {})) == nil, "deux echecs : non")
  want((Dp.pick({ lot(1, 0, "defricher", { bad = 1 }) }, st, 100000, {})) == "1:0", "un echec : oui")
  want((Dp.pick({ lot(1, 0, "defricher", { pre_n = 2 }) }, st, 100000, {})) == nil, "deja tente Dp.MAX_TRIES fois : non")
  want((Dp.pick({ lot(1, 0, "defricher", { pre_n = 1 }) }, st, 100000, {})) == "1:0", "une tentative : encore une")
  local _, w1 = Dp.pick(lots, st, 100000, { clearing = 1 })
  want(w1 == "projet en defrichage", "jamais pendant qu'un projet defriche")
  local _, w2 = Dp.pick(lots, st, 100000, { threatened = true })
  want(w2 == "menace", "jamais pendant une menace")
  local _, w3 = Dp.pick({}, st, 100000, {})
  want(w3 == "aucun lot", "aucun lot")
  -- ordre indépendant de l'entrée
  local rev = {}
  for idx = #lots, 1, -1 do rev[#rev + 1] = lots[idx] end
  want(Dp.pick(rev, st, 100000, {}) == Dp.pick(lots, st, 100000, {}), "meme choix quel que soit l'ordre d'entree")
  -- 3. Cycle : ouverture, quarts, fin, repos.
  Dp.start(st, "-1:0", 5000)
  want(st.open == "-1:0" and #Dp.pending(st) == 4, "ouvert : 4 quarts a couper")
  local _, w4 = Dp.pick(lots, st, 5100, {})
  want(w4 == "en cours", "un seul lot a la fois")
  want(Dp.quarter_done(st, 2) == false and #Dp.pending(st) == 3 and Dp.pending(st)[1] == 1, "un quart coupe : il en reste 3 (1, 3, 4)")
  Dp.quarter_done(st, 1); Dp.quarter_done(st, 3)
  want(Dp.quarter_done(st, 4) == true and #Dp.pending(st) == 0, "le 4e quart coupe : fini")
  want(Dp.quarter_done(st, 9) == false and Dp.quarter_done(st, 0) == false, "numero de quart hors de 1..4 : ignore")
  want(Dp.expired(st, 5000 + Dp.GIVE_UP) == false and Dp.expired(st, 5000 + Dp.GIVE_UP + 1) == true, "abandon au-dela de Dp.GIVE_UP ticks")
  Dp.finish(st, 7000)
  want(st.open == nil and #Dp.pending(st) == 0 and st.last == 7000, "fini : plus rien d'ouvert, repos note")
  local _, w5 = Dp.pick(lots, st, 7000 + Dp.COOLDOWN - 1, {})
  want(w5 == "repos", "repos apres un lot")
  want(Dp.pick(lots, st, 7000 + Dp.COOLDOWN, {}) ~= nil, "repos fini : un autre lot")
  want(Dp.expired(Dp.new(), 999999999) == false, "rien d'ouvert : jamais expire")
  want(Dp.expired({ open = nil, since = 0 }, 999999999) == false, "rien d'ouvert (reste d'une horloge) : jamais expire")
  want(Dp.GIVE_UP == 21600 and Dp.COOLDOWN == 3600, "6 min d'abandon, 1 min de repos")
  want((Dp.pick({ lot(1, -1), lot(0, 1) }, Dp.new(), 100000, {})) == "0:1", "meme couronne : la distance avant j (0:1 avant 1:-1)")
  -- Dp.gate : la porte seule, sans liste de lots.
  local g = Dp.new()
  want(Dp.gate(g, 100000, {}) == nil, "porte ouverte")
  want(Dp.gate(g, 100000, { clearing = 2 }) == "projet en defrichage" and Dp.gate(g, 100000, { threatened = true }) == "menace", "porte : projet en defrichage, menace")
  Dp.start(g, "1:0", 1)
  want(Dp.gate(g, 100000, {}) == "en cours", "porte : lot ouvert")
  -- 4. Constantes déclarées (budget des travaux lourds).
  want(Dp.COST >= 1 and Dp.COST <= 4 and Dp.PERIOD >= 1 and Dp.WAIT_MAX >= 1, "cout declare 1 a 4 chunks, periode et patience positives")
  return bad, n
end

local bad, n = suite(load_mod(SRC))
for _, m in ipairs(bad) do check(false, m) end
pass = pass + (n - #bad)

local MUTANTS = {
  { "Dp.SIZE = 50", "Dp.SIZE = 48" },
  { "Dp.RING_MAX = 3", "Dp.RING_MAX = 4" },
  { "Dp.MAX_TRIES = 2", "Dp.MAX_TRIES = 3" },
  { "Dp.GIVE_UP = 21600", "Dp.GIVE_UP = 3600" },
  { "if st.open then return \"en cours\" end", "" },
  { "if (ctx.clearing or 0) > 0 then return \"projet en defrichage\" end", "" },
  { "if ctx.threatened then return \"menace\" end", "" },
  { "if tick - (st.last or -1000000) < Dp.COOLDOWN then return \"repos\" end", "" },
  { "l.state == \"defricher\" and not l.used", "l.state ~= \"occupe\" and not l.used" },
  { "and not l.out and not (l.bad", "and not (l.bad" },
  { "(l.bad and l.bad >= 2)", "(l.bad and l.bad >= 3)" },
  { "and not (l.i == 0 and l.j == 0)\n      and ring(l)", "\n      and ring(l)" },
  { "and (l.pre_n or 0) < Dp.MAX_TRIES", "" },
  { "if da ~= db then return da < db end", "" },
  { "if a.j ~= b.j then return a.j < b.j end", "if a.j ~= b.j then return a.j > b.j end" },
  { "{ x0, my, mx, y1 }, { mx, my, x1, y1 },", "{ x0, my, mx, y1 }, { mx, my, x1, y1 + 1 }," },
  { "return #Dp.pending(st) == 0", "return true" },
  { "q < 1 or q > Dp.QUARTERS", "q < 1" },
  { "return st.open ~= nil and tick - (st.since or tick) > Dp.GIVE_UP", "return tick - (st.since or tick) > Dp.GIVE_UP" },
  { "st.open, st.since, st.q, st.last = nil, nil, {}, tick", "st.open, st.since, st.q = nil, nil, {}" },
}
local killed = 0
for i, mu in ipairs(MUTANTS) do
  local s, e = SRC:find(mu[1], 1, true)
  if not s then
    check(false, "mutant " .. i .. " : motif introuvable : " .. mu[1])
  else
    local src2 = SRC:sub(1, s - 1) .. mu[2] .. SRC:sub(e + 1)
    local ok, mod = pcall(load_mod, src2)
    local survived = ok and #(suite(mod)) == 0
    if survived then check(false, "mutant " .. i .. " survit : " .. mu[1] .. " -> " .. mu[2]) else killed = killed + 1 end
  end
end
pass = pass + killed
print(string.format("[DEFRICHAGE-PREV] BILAN : %d OK, %d ECHEC(S) (dont %d mutants sur %d refuses)", pass, fail, killed, #MUTANTS))
os.exit(fail == 0 and 0 or 1)
