--[[
  Lot TV-PLACE, G57 : test hors jeu de shared/faction/sonde10.lua (sonde des sites des factions en fenêtres de 10 x 10).
    lua5.2 tests/sonde10_test.lua   -> [SONDE10] BILAN : N OK, 0 ECHEC(S)
  Mutants : substitution unique dans le source, rechargé ; la suite doit ECHOUER.
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/faction/sonde10.lua"
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[SONDE10] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local SRC = read(PATH)
local function load_mod(src) return assert(load(src, "=" .. PATH, "t", _ENV))() end

-- carré de w x h tuiles dont le coin nord-ouest est (x, y)
local function block(x, y, w, h, into)
  into = into or {}
  for dx = 0, w - 1 do for dy = 0, h - 1 do into[#into + 1] = { x = x + dx, y = y + dy } end end
  return into
end

local function suite(S)
  local bad, n = {}, 0
  local function want(ok, msg) n = n + 1 if not ok then bad[#bad + 1] = msg end end
  want(S.SIZE == 10 and S.MIN == 24 and S.AREA == 32, "fenetre 10 x 10, seuil 24, zone de lecture 32")
  -- 1. Zone élargie.
  local x0, y0, x1, y1 = S.expanded(2, -1)
  want(x0 == 54 and y0 == -42 and x1 == 106 and y1 == 10, "chunk (2,-1) elargi de 10 : (54,-42)-(106,10)")
  -- 2. Fenêtre : un carré 5 x 5 pose 25 tuiles.
  local w = S.best_window(block(100, 100, 5, 5))
  want(w and w.n == 25 and w.x0 == 100 and w.y0 == 100, "carre de 25 : une fenetre de 25")
  want(w and w.cx == 102.5 and w.cy == 102.5, "barycentre au centre du carre (tuiles +0,5)")
  -- 3. Gisement coupé par la frontière de deux chunks (x = 96) : 12 + 12 tuiles.
  local pts = {}
  block(92, 40, 4, 3, pts)               -- chunk 2 (x 64..95), x 92..95 : 12 tuiles
  block(96, 40, 4, 3, pts)               -- chunk 3 (x 96..127), x 96..99 : 12 tuiles
  local win = S.best_window(pts)
  want(win and win.n == 24, "12 + 12 tuiles a cheval : une fenetre de 24")
  want(S.retained(win, math.floor(win.cx / 32), math.floor(win.cy / 32)) == true, "retenu par le chunk qui porte le barycentre")
  want(S.retained(win, 2, 1) ~= S.retained(win, 3, 1) and S.retained(win, 3, 1) == true, "un seul des deux chunks voisins retient le gisement")
  want(S.retained(win, 0, 0) == false, "un chunk lointain ne le retient pas")
  local a = S.read_area(win)
  want(a[2][1] - a[1][1] == 32 and a[2][2] - a[1][2] == 32, "zone de lecture 32 x 32")
  want(a[1][1] < win.cx and a[2][1] > win.cx and a[1][2] < win.cy and a[2][2] > win.cy, "la zone de lecture contient le barycentre")
  want(math.abs((a[1][1] + a[2][1]) / 2 - win.cx) <= 1 and math.abs((a[1][2] + a[2][2]) / 2 - win.cy) <= 1, "centree sur le barycentre a une tuile pres")
  -- 4. Seuil : 23 tuiles ne passent pas.
  local p23 = block(0, 0, 23, 1)
  local w23 = S.best_window(p23)
  want(w23 and w23.n == 10 and not S.retained(w23, 0, 0), "une ligne de 23 tuiles : fenetre de 10 seulement")
  local sparse = {}
  for i = 0, 29 do sparse[#sparse + 1] = { x = i * 3, y = i * 3 } end -- 30 tuiles en diagonale espacee de 3
  local ws = S.best_window(sparse)
  want(ws and ws.n <= 4 and not S.retained(ws, 0, 0), "30 tuiles eparpillees (diagonale) : aucune fenetre de 24")
  local dense = block(0, 0, 4, 6) -- 24 tuiles
  local wd = S.best_window(dense)
  want(wd and wd.n == 24 and S.retained(wd, 0, 0), "24 tuiles dans 4 x 6 : retenu")
  -- 5. Bords de fenêtre : x0 + 10 exclu.
  local wide = block(0, 0, 11, 1)
  want(S.best_window(wide).n == 10, "11 tuiles alignees : une fenetre de 10 (le bord est exclu)")
  local tall = block(0, 0, 1, 11)
  want(S.best_window(tall).n == 10, "11 tuiles en colonne : une fenetre de 10")
  -- 6. Choix de la meilleure fenêtre et déterminisme.
  local two = block(0, 0, 3, 3)
  block(50, 0, 4, 4, two)
  local wt = S.best_window(two)
  want(wt and wt.n == 16 and wt.x0 == 50, "deux gisements : le plus dense (16 contre 9)")
  local rev = {}
  for i = #two, 1, -1 do rev[#rev + 1] = two[i] end
  local wr = S.best_window(rev)
  want(wr.n == wt.n and wr.x0 == wt.x0 and wr.y0 == wt.y0 and wr.cx == wt.cx, "meme fenetre quel que soit l'ordre d'entree")
  local tie = block(0, 0, 2, 2)
  block(40, 40, 2, 2, tie)
  local wtie = S.best_window(tie)
  want(wtie.n == 4 and wtie.x0 == 0 and wtie.y0 == 0, "egalite : la fenetre la plus au nord-ouest")
  -- 7. Entrées bornées / invalides.
  want(S.best_window({}) == nil and S.best_window(nil) == nil, "aucune tuile : nil")
  want(S.best_window({ "x", { x = "a", y = 1 } }) == nil, "entrees invalides ignorees")
  local big = block(0, 0, 40, 40) -- 1600 tuiles
  local wb = S.best_window(big)
  want(wb and wb.n <= S.MAX_POINTS and wb.n >= 24, "au plus S.MAX_POINTS tuiles lues")
  local capped = block(0, 0, 700, 1)
  block(5000, 0, 5, 5, capped)
  want(S.best_window(capped).n == 10, "borne S.MAX_POINTS : les tuiles au-dela de 600 (tri x, y) ne sont pas lues")
  want(S.retained(nil, 0, 0) == false, "pas de fenetre : pas retenu")
  want(S.best_window(block(5, 5, 1, 1), 3).n == 1, "taille de fenetre en parametre")
  return bad, n
end

local bad, n = suite(load_mod(SRC))
for _, m in ipairs(bad) do check(false, m) end
pass = pass + (n - #bad)

local MUTANTS = {
  { "S.SIZE = 10", "S.SIZE = 12" },
  { "S.MIN = 24", "S.MIN = 20" },
  { "S.REACH = 10", "S.REACH = 8" },
  { "S.AREA = 32", "S.AREA = 30" },
  { "if pts[j].x >= x0 + size then break end", "if pts[j].x > x0 + size then break end" },
  { "while col[hi].y - col[lo].y >= size do", "while col[hi].y - col[lo].y > size do" },
  { "if not best or n > best.n then", "if not best or n >= best.n then" },
  { "while #pts > S.MAX_POINTS do pts[#pts] = nil end", "" },
  { "sx, sy = sx + best.col[i].x + 0.5, sy + best.col[i].y + 0.5", "sx, sy = sx + best.col[i].x, sy + best.col[i].y" },
  { "if not win or win.n < S.MIN then return false end", "if not win then return false end" },
  { "return math.floor(win.cx / 32) == ccx and math.floor(win.cy / 32) == ccy", "return true" },
  { "return cx * 32 - S.REACH, cy * 32 - S.REACH, cx * 32 + 32 + S.REACH, cy * 32 + 32 + S.REACH", "return cx * 32 - S.REACH, cy * 32 - S.REACH, cx * 32 + 32, cy * 32 + 32" },
  { "table.sort(pts, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)", "" },
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
print(string.format("[SONDE10] BILAN : %d OK, %d ECHEC(S) (dont %d mutants sur %d refuses)", pass, fail, killed, #MUTANTS))
os.exit(fail == 0 and 0 or 1)
