--[[
  Lot FOREUSES-THERMIQUES (décision du DC par QCM, 5/11 20 h 47 : « Remplacer au fur et à mesure » : les thermiques sont remplacées une à une
  par des électriques AVEC LEUR POTEAU, même hors des bandes du champ). PUR : règle de shared/team/foreuse_swap.lua (S.plan, S.pole_plan,
  S.pole_targets, S.chain_ok, S.reach_estimate, S.power_ok, S.pole_item), chaîne de poteaux de shared/team/plan.lua (P.pole_chain).

  Défaut reproduit (partie du DC, 0.6.53, journal fo-logs/2026-11-05_PARTIE-DC-ESSAI) : le remplacement exigeait un poteau ALIMENTÉ déjà
  là ; 5 remplacements en 150 min, 201 thermiques de fer. Cas construit : une foreuse à combustion dont le four reçoit le minerai, le réseau
  alimenté à 31 tuiles : l'ancienne règle ne la remplace pas (ROUGE sur 38ee70e1), la nouvelle la remplace avec sa chaîne (VERT).

  Usage, depuis la racine du mod :
    lua5.2 tests/foreuse_chaine_test.lua                       (module du dossier, mutants compris)
    lua5.2 tests/foreuse_chaine_test.lua <foreuse_swap.lua>    (autre texte : celui de 38ee70e1 doit être ROUGE)
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local P = require("shared.team.plan")

local ok_n, bad = 0, 0
local function check(name, cond, detail)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[FOREUSE-CHAINE] ECHEC : " .. name .. (detail and (" (" .. detail .. ")") or "")) end
end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end
local PATH = arg[1] or "shared/team/foreuse_swap.lua"
local SRC = read(PATH)
local function load_mod(src)
  local fn = load(src, "=foreuse_swap", "t", setmetatable({ require = require }, { __index = _G }))
  if not fn then return nil end
  local okc, mod = pcall(fn)
  return okc and mod or nil
end

local E = T.drill_electric
local SMALL = { supply = 2.5, wire = 7.5 }
local function k(x, y) return math.floor(x) .. "," .. math.floor(y) end

local function suite(S)
  local res = {}
  local function c(name, cond, detail) res[#res + 1] = { name, cond and true or false, detail } end
  local function entry(id, x, y) return { id = id, x = x, y = y, dir = 0, sink = { x = x - 1, y = y - 2, w = 2, h = 2 } } end
  local function free_all(blocked)
    return function(e, box)
      return function(x, y)
        if blocked and blocked[k(x, y)] then return false end
        if S.overlap({ x = x, y = y, w = 1, h = 1 }, box) or S.overlap({ x = x, y = y, w = 1, h = 1 }, e.sink) then return false end
        return true
      end
    end
  end
  -- un module sans ces fonctions (38ee70e1) donne des ECHEC lisibles, pas un plantage
  local function fn(name) return S[name] or function() return nil, "absent" end end
  local pole_plan, power_ok, pole_item, reach_estimate = fn("pole_plan"), fn("power_ok"), fn("pole_item"), fn("reach_estimate")
  local chain_ok = fn("chain_ok")
  local calls = 0
  local chain = function(a, b, reach, big, free) calls = calls + 1 return P.pole_chain(a, b, reach, big, free) end
  local function ctx_of(poles, o)
    o = o or {}
    return { poles = poles, electric = E, have = o.have or 5, obtainable = true, limit = o.limit or 2, pole = o.pole or SMALL,
      free_for = o.free_for or free_all(o.blocked), chain = o.chain or chain, chain_max = o.max, tries = o.tries }
  end
  local function props(out_i, poles, e, blocked)
    -- chaîne connexe depuis un poteau alimenté, dernier poteau qui couvre la foreuse, aucun poteau sur la foreuse, son four ou une tuile bloquée
    local box = { x = out_i.cx, y = out_i.cy, w = 3, h = 3 }
    local src
    for _, p in ipairs(poles) do
      if p.powered and #out_i.poles > 0 and (out_i.poles[1].x - p.x) ^ 2 + (out_i.poles[1].y - p.y) ^ 2 <= 7.5 * 7.5 + 1e-6 then src = p end
    end
    local last = out_i.poles[#out_i.poles]
    local clean = true
    for _, q in ipairs(out_i.poles) do
      local qb = { x = q.x, y = q.y, w = 1, h = 1 }
      if S.overlap(qb, box) or S.overlap(qb, e.sink) or (blocked and blocked[k(q.x, q.y)]) then clean = false end
    end
    return src ~= nil and chain_ok(src, out_i.poles, 7.5) and last ~= nil and S.covered(last.x, last.y, 2.5, box) and clean
  end

  -- 1. le défaut : réseau alimenté à 31 tuiles, aucun poteau à portée de la future foreuse
  local e1 = entry(1, 10, 10)
  local net = { { x = 40.5, y = 10.5, dist = 2.5, wire = 7.5, powered = true } }
  local out, ready = S.plan({ e1 }, ctx_of(net))
  c("1 : foreuse sans poteau a 31 tuiles du reseau : remplacee avec sa chaine", #out == 1 and out[1].poles and #out[1].poles >= 1, "sorties " .. #out)
  if #out == 1 and out[1].poles then
    c("1 : chaine connexe, dernier poteau qui alimente la 3x3, rien sur la foreuse ni sur son four", props(out[1], net, e1))
    c("1 : au plus le minimum + 1 poteaux (31 tuiles, fil 7,5)", #out[1].poles <= 5, tostring(#out[1].poles))
    c("1 : la sortie porte le poteau source (pose reliee par l'executant)", out[1].source ~= nil and out[1].source.powered == true)
    c("1 : n_ready garde son sens (deja alimentees seulement : politique des paires inchangee)", ready == 0, tostring(ready))
  end
  -- 2. déjà alimentée : aucun poteau neuf
  local near = { { x = 9.5, y = 14.5, dist = 3.5, wire = 9, powered = true } }
  local o2, r2 = S.plan({ e1 }, ctx_of(near))
  c("2 : deja alimentee : remplacee sans poteau", #o2 == 1 and o2[1].poles ~= nil and #o2[1].poles == 0 and r2 == 1)
  -- 3. trop loin : au-delà de CHAIN_MAX poteaux
  local far = { { x = 110.5, y = 10.5, dist = 2.5, wire = 7.5, powered = true } }
  local o3 = S.plan({ e1 }, ctx_of(far))
  c("3 : reseau a 100 tuiles : pas candidate (chaine bornee)", #o3 == 0)
  c("3 : pole_plan rend une raison", select(2, pole_plan({ x = 9.5, y = 10.5, w = 3, h = 3 }, far, SMALL, function() return true end, { chain = chain })) == "reseau trop loin")
  -- 4. poteau éteint : ne compte pas
  local off = { { x = 20.5, y = 10.5, dist = 2.5, wire = 7.5, powered = false } }
  c("4 : poteau sur un reseau qui ne produit pas : rien", #S.plan({ e1 }, ctx_of(off)) == 0)
  -- 5. tuiles bloquées : la chaîne les évite ; tout bloqué : refus
  local wall = {}
  for y = -20, 40 do wall[k(25.5, y + 0.5)] = true; wall[k(26.5, y + 0.5)] = true end -- mur de 2 tuiles (le fil passe dessus)
  local o5 = S.plan({ e1 }, ctx_of(net, { blocked = wall }))
  c("5 : mur de 2 tuiles en travers : chaine qui l'enjambe, aucun poteau dessus", #o5 == 1 and props(o5[1], net, e1, wall))
  local ring = {}
  for x = 0, 20 do for y = 0, 20 do ring[k(x + 0.5, y + 0.5)] = true end end
  local ctx5 = ctx_of(net, { blocked = ring })
  local o5b = S.plan({ e1 }, ctx5)
  c("5 : aucune place libre autour de la foreuse : refus avec raison", #o5b == 0 and (ctx5.refused or {})[1] ~= nil and (ctx5.refused or {})[1].why == "aucune place de poteau",
    (ctx5.refused or {})[1] and (ctx5.refused or {})[1].why)
  -- 6. priorité : déjà alimentées d'abord, puis le moins de poteaux, puis l'id ; bornée par la limite et le stock
  local eA, eB, eC = entry(5, 10, 10), entry(2, 10, 40), entry(9, 60, 60)
  local mix = { { x = 40.5, y = 10.5, dist = 2.5, wire = 7.5, powered = true }, { x = 9.5, y = 44.5, dist = 3.5, wire = 9, powered = true },
    { x = 70.5, y = 60.5, dist = 2.5, wire = 7.5, powered = true } }
  local o6 = S.plan({ eA, eB, eC }, ctx_of(mix, { limit = 3 }))
  c("6 : ordre : alimentee (2), puis la plus courte chaine (9, 1 a 2 poteaux), puis 5", #o6 == 3 and o6[1].id == 2 and o6[2].id == 9 and o6[3].id == 5,
    #o6 == 3 and (o6[1].id .. "," .. o6[2].id .. "," .. o6[3].id) or tostring(#o6))
  local o6b = S.plan({ eA, eB, eC }, ctx_of(mix, { limit = 3, have = 1 }))
  c("6 : borne par le stock d'electriques", #o6b == 1 and o6b[1].id == 2)
  -- 7. coût borné : 10 candidats sans place, au plus S.TRIES plans de chaîne par passe
  local many = {}
  for i = 1, 10 do many[i] = entry(100 + i, 10 + 30 * i, 200) end
  local srcs = {}
  for i = 1, 10 do srcs[i] = { x = 10 + 30 * i + 20, y = 200.5, dist = 2.5, wire = 7.5, powered = true } end
  calls = 0
  local blocked_all = setmetatable({}, { __index = function() return true end })
  local ctx7a = ctx_of(srcs, { limit = 10, have = 10, free_for = function() return function() return false end end })
  local o7 = S.plan(many, ctx7a)
  c("7 : candidats sans place : aucun remplacement", #o7 == 0)
  c("7 : 10 candidats sans place : au plus S.TRIES essais dans la passe", #(ctx7a.refused or {}) == (S.TRIES or 4), tostring(#(ctx7a.refused or {})))
  local ctx7 = ctx_of(srcs, { limit = 10, have = 10, free_for = function(e, box) return function(x, y) return not S.overlap({ x = x, y = y, w = 1, h = 1 }, box) and y < 199 end end })
  calls = 0
  S.plan(many, ctx7)
  c("7 : au plus S.TRIES plans de chaine par passe", #(ctx7.refused or {}) <= (S.TRIES or 4), tostring(#(ctx7.refused or {})))
  -- 8. chaîne fausse rendue par la recherche (maillon trop long) : refusée par S.chain_ok
  local liar = function() return {} end -- prétend que la source touche la place du dernier poteau
  local o8 = S.plan({ e1 }, ctx_of(net, { chain = liar }))
  c("8 : chaine non connexe rendue par la recherche : refusee", #o8 == 0)
  -- 9. déterminisme : sources dans un autre ordre, même plan
  local twin = { { x = 40.5, y = 10.5, dist = 2.5, wire = 7.5, powered = true }, { x = 10.5, y = 41.5, dist = 2.5, wire = 7.5, powered = true } }
  local a = S.plan({ e1 }, ctx_of(twin))
  local b = S.plan({ e1 }, ctx_of({ twin[2], twin[1] }))
  local same = #a == 1 and #b == 1 and #a[1].poles == #b[1].poles
  if same then for i, p in ipairs(a[1].poles) do if p.x ~= b[1].poles[i].x or p.y ~= b[1].poles[i].y then same = false end end end
  c("9 : ordre des poteaux sans effet", same)
  -- 10. puissance : marge de la centrale (kW)
  c("10 : sous la capacite : passe", power_ok({ capacity = 1800, used = 900, committed = 500 }, 90, 0.6) == true)
  c("10 : au-dela : retenu", power_ok({ capacity = 1800, used = 1500, committed = 500 }, 90, 0.6) == false)
  c("10 : sans centrale connue : passe", power_ok({ capacity = 0 }, 90, 0.6) == true and power_ok(nil, 90) == true)
  -- 11. poteau à poser : le premier au stock, sinon le premier fabricable
  c("11 : petit au stock", pole_item({ { name = "small", have = 3 }, { name = "medium", have = 5 } }) == "small")
  c("11 : seul le moyen au stock", pole_item({ { name = "small", have = 0, craftable = true }, { name = "medium", have = 5 } }) == "medium")
  c("11 : rien au stock : le premier fabricable", pole_item({ { name = "small", have = 0, craftable = true }, { name = "medium", have = 0, craftable = true } }) == "small")
  c("11 : rien : nil", pole_item({ { name = "small" } }) == nil)
  -- 12. estimation : 0 si alimentée, nil au-delà de la borne
  local bx = { x = 9.5, y = 10.5, w = 3, h = 3 }
  c("12 : estimation", reach_estimate(bx, near, SMALL) == 0 and reach_estimate(bx, far, SMALL) == nil and (reach_estimate(bx, net, SMALL) or 99) <= 4)
  -- 13. la règle elle-même ne pose jamais un poteau sur la foreuse, même avec un `free` qui laisse tout passer
  local anyfree = function() return true end
  local p13 = pole_plan(bx, net, SMALL, anyfree, { chain = chain })
  local on_box = false
  for _, q in ipairs(p13 and p13.poles or {}) do if S.overlap({ x = q.x, y = q.y, w = 1, h = 1 }, bx) then on_box = true end end
  c("13 : free permissif : aucun poteau sur la boite de la foreuse", p13 ~= nil and #p13.poles >= 1 and not on_box)
  -- 13 bis : seule la rangée ajoutée de la 3×3 est libre (la thermique 2×2 n'y est pas) : la règle n'y pose pas le dernier poteau
  local only_box = function(x, y) return S.overlap({ x = x, y = y, w = 1, h = 1 }, bx) end
  local p13b, why13b = pole_plan(bx, net, SMALL, only_box, { chain = chain })
  c("13 bis : seules les tuiles de la future boite sont libres : refus", p13b == nil and why13b == "aucune place de poteau", tostring(why13b))
  -- 14. borne de la chaîne : source à 12 tuiles, max 1 poteau (il en faut 2) : refus ; max 2 : passe
  local src12 = { { x = 21.5, y = 10.5, dist = 2.5, wire = 7.5, powered = true } }
  c("14 : chaine plus longue que la borne : refus", pole_plan(bx, src12, SMALL, anyfree, { chain = chain, max = 1 }) == nil)
  local p14 = pole_plan(bx, src12, SMALL, anyfree, { chain = chain, max = 2 })
  c("14 : dans la borne : 2 poteaux au plus", p14 ~= nil and #p14.poles >= 1 and #p14.poles <= 2)
  -- 15. un poteau sur un réseau qui ne produit pas n'est jamais une source
  local w15, why15 = pole_plan(bx, off, SMALL, anyfree, { chain = chain })
  c("15 : poteau eteint : aucune source", w15 == nil and why15 == "aucun poteau alimente", tostring(why15))
  -- 17. la 3×3 doit tenir AVANT tout poteau (banc du 7/11 : 23 poses sur 24 refusées, débord sur la paire voisine)
  local function ctx_fit(poles, fits, o)
    local cx_ = ctx_of(poles, o)
    cx_.fits = fits
    return cx_
  end
  -- premier centre (9,5 ; 10,5) bloqué, le suivant (10,5 ; 9,5)… seul celui en x = 10,5 tient
  local seen_fit = 0
  local only_east = function(e, cx, cy) seen_fit = seen_fit + 1 return cx > e.x + 1 end
  local o17 = S.plan({ e1 }, ctx_fit(net, only_east))
  c("17 : le placement qui tient est pris (autre cote du four, autre direction)", #o17 == 1 and o17[1].cx > 11 and o17[1].dir ~= nil and #o17[1].poles >= 1,
    #o17 == 1 and (o17[1].cx .. "," .. o17[1].cy) or tostring(#o17))
  if #o17 == 1 then c("17 : chaine planifiee pour CE centre (dernier poteau qui l'alimente)", props(o17[1], net, e1)) end
  local ctx17 = ctx_fit(net, function() return false end)
  local o17b = S.plan({ e1 }, ctx17)
  c("17 : aucune place : aucun remplacement, refus « 3x3 bloquee », aucun plan de chaine", #o17b == 0 and (ctx17.refused or {})[1] ~= nil
    and ctx17.refused[1].why == "3x3 bloquee", (ctx17.refused or {})[1] and ctx17.refused[1].why)
  local o17c = S.plan({ e1 }, ctx_fit(near, function() return false end))
  c("17 : deja alimentee mais bloquee : rien", #o17c == 0)
  local many17 = {}
  for i = 1, 20 do many17[i] = entry(200 + i, 10 + 6 * i, 10) end
  local mnear = {}
  for i = 1, 20 do mnear[i] = { x = 10 + 6 * i - 0.5, y = 14.5, dist = 3.5, wire = 9, powered = true } end
  local nfit = 0
  local ctx17d = ctx_fit(mnear, function() nfit = nfit + 1 return false end, { limit = 20, have = 20 })
  S.plan(many17, ctx17d)
  c("17 : au plus S.FIT_TRIES foreuses lues par passe", #(ctx17d.refused or {}) == (S.FIT_TRIES or 8), tostring(#(ctx17d.refused or {})))
  -- 18. placements admissibles : dépôt dans le four, boîte hors du four, SUR l'ancienne emprise ; le premier est celui d'avant
  local cs18 = S.electric_centers and S.electric_centers(10, 10, 0, e1.sink, E) or {}
  local ok18, dirs = #cs18 > 1, {}
  for _, c0 in ipairs(cs18) do
    local vx, vy = S.rotate(c0[4], E.drop[1], E.drop[2])
    local box = { x = c0[1], y = c0[2], w = 3, h = 3 }
    if not (S.inside(e1.sink, c0[1] + vx, c0[2] + vy) and not S.overlap(box, e1.sink) and S.overlap(box, { x = 10, y = 10, w = 2, h = 2 })) then ok18 = false end
    dirs[c0[4]] = true
  end
  local nd = 0
  for _ in pairs(dirs) do nd = nd + 1 end
  c("18 : placements admissibles (depot dans le four, hors du four, sur l'ancienne emprise), plusieurs directions", ok18 and nd >= 2, #cs18 .. " placements, " .. nd .. " direction(s)")
  c("18 : le premier placement est celui de la regle d'avant (9,5 ; 10,5, nord)", cs18[1] ~= nil and cs18[1][1] == 9.5 and cs18[1][2] == 10.5 and cs18[1][4] == 0)
  -- dans les 4 directions : le premier placement garde la direction de la thermique (et le centre de la règle d'avant)
  local first_ok = true
  for _, d0 in ipairs({ 0, 2, 4, 6 }) do
    local sx, sy = S.rotate(d0, -1, -2)
    local sk = { x = 10 + sx, y = 10 + sy, w = 2, h = 2 }
    local ox, oy = S.electric_center(10, 10, d0, sk, E)
    local l = S.electric_centers and S.electric_centers(10, 10, d0, sk, E) or {}
    if not (l[1] and l[1][4] == d0 and l[1][1] == ox and l[1][2] == oy) then first_ok = false end
  end
  c("18 : 4 directions : le premier placement garde la direction et le centre d'avant", first_ok)
  -- 16. rangement des poteaux par cases (coût) : mêmes réponses que la lecture de TOUS les poteaux, sur 60 cartes pseudo-aléatoires
  local seed = 7
  local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648 return math.floor(seed / 65536) % n end -- bits hauts (les bas bits d un LCG ont une courte periode)
  local diff, n_pw, n_ch = 0, 0, 0
  for _ = 1, 60 do
    local es, ps = {}, {}
    for i = 1, 12 do es[i] = entry(i, rnd(200) - 100, rnd(200) - 100) end
    for i = 1, 40 do ps[i] = { x = rnd(240) - 120 + 0.5, y = rnd(240) - 120 + 0.5, dist = (rnd(2) == 0) and 2.5 or 3.5, wire = 7.5, powered = rnd(4) > 0 } end
    -- poteaux tout près de la moitié des foreuses (couverture à cheval sur deux cases), et à 10-40 tuiles (chaînes)
    for i = 1, 12 do
      if i % 2 == 0 then ps[#ps + 1] = { x = es[i].x + (i % 4 == 0 and 2.5 or -3.5), y = es[i].y + 0.5, dist = 2.5, wire = 7.5, powered = true } end
      if i % 3 == 0 then ps[#ps + 1] = { x = es[i].x + 10 + 3 * i + 0.5, y = es[i].y - 7.5, dist = 2.5, wire = 7.5, powered = true } end
    end
    local _, r1, c1 = S.plan(es, ctx_of(ps, { limit = 0, have = 0 }))
    -- référence : tous les poteaux lus pour chaque foreuse
    local r2, c2 = 0, 0
    for _, e in ipairs(es) do
      local cs = S.electric_centers and S.electric_centers(e.x, e.y, e.dir, e.sink, E) or {}
      if #cs > 0 then
        local pw = false
        for _, c0 in ipairs(cs) do
          local box = { x = c0[1], y = c0[2], w = 3, h = 3 }
          for _, p in ipairs(ps) do if p.powered and S.covered(p.x, p.y, p.dist, box) then pw = true end end
        end
        local box1 = { x = cs[1][1], y = cs[1][2], w = 3, h = 3 }
        if pw then r2 = r2 + 1 ; n_pw = n_pw + 1 elseif reach_estimate(box1, ps, SMALL) then c2 = c2 + 1 ; n_ch = n_ch + 1 end
      end
    end
    if r1 ~= r2 or c1 ~= c2 then diff = diff + 1 end
  end
  c("16 : rangement par cases : memes candidats que la lecture de tous les poteaux (60 cartes)", diff == 0, tostring(diff))
  c("16 : les cartes ont des foreuses alimentees et des chaines (le cas n'est pas vide)", n_pw > 0 and n_ch > 0, n_pw .. " / " .. n_ch)
  return res
end

local function run(mod)
  if not mod then return { { "module illisible", false } } end
  local okr, res = pcall(suite, mod)
  if not okr then return { { "suite : " .. tostring(res), false } } end
  return res
end
for _, r in ipairs(run(load_mod(SRC))) do check(r[1], r[2], r[3]) end
if arg[1] then
  print(string.format("[FOREUSE-CHAINE] (texte %s) BILAN : %d OK, %d ECHEC(S)", PATH, ok_n, bad))
  os.exit(bad == 0 and 0 or 1)
end

local MUT = {
  { "chaine non verifiee", "if S.chain_ok(c.s, list, c.reach) then", "if true then" },
  { "dernier poteau qui n'alimente pas", "if S.covered(p.x, p.y, supply, box) and not S.overlap", "if true and not S.overlap" },
  { "poteau sur la foreuse", "and not S.overlap({ x = p.x, y = p.y, w = 1, h = 1 }, box) and free(p.x, p.y) then", "and free(p.x, p.y) then" },
  { "borne de la chaine ignoree", "if mid and #mid + 1 <= maxn then", "if mid then" },
  { "estimation sans borne", "if n <= maxn and (not best or n < best) then best = n end", "if not best or n < best then best = n end" },
  { "ordre des candidats ignore", "table.sort(chained, function(a, b) if a.est ~= b.est then return a.est < b.est end return a.id < b.id end)", "" },
  { "n_ready compte les chaines", "return out, #ready, #chained", "return out, #ready + #chained, #chained" },
  { "essais sans borne", "if #out >= n or tries >= (ctx.tries or S.TRIES) or fit_tries >= (ctx.fit_tries or S.FIT_TRIES) then break end", "if #out >= n or fit_tries >= (ctx.fit_tries or S.FIT_TRIES) then break end" },
  { "place de la 3x3 ignoree", "and (not ctx.fits or ctx.fits(it.e, c[1], c[2], c[4])) then return c end", "then return c end" },
  { "lectures de place sans borne", "    if #out >= n or fit_tries >= (ctx.fit_tries or S.FIT_TRIES) then break end", "    if #out >= n then break end" },
  { "puissance a l'envers", "<= c.capacity + EPS", ">= c.capacity - EPS" },
  { "cases voisines ignorees (couverture)", "for _, p in ipairs(near(box, 1)) do", "for _, p in ipairs(near(box, 0)) do" },
  { "cases trop proches (chaine)", "near(box_at(cs[1]), far_r)", "near(box_at(cs[1]), 1)" },
  -- (mutants équivalents écartés, 7/11 : retirer « recouvre l'ancienne emprise » ou la priorité de la direction ne change aucun placement :
  -- les décalages de ±1,5 recouvrent toujours la 2 × 2, et un placement d'une autre direction est toujours plus loin de l'ancien centre)
  { "poteau eteint compte", "  for _, s in ipairs(sources or {}) do\n    if s.powered then\n      if S.covered(s.x, s.y, s.dist, box) then return { poles = {}, source = s } end", "  for _, s in ipairs(sources or {}) do\n    if true then\n      if S.covered(s.x, s.y, s.dist, box) then return { poles = {}, source = s } end" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local a, z = SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local res = run(load_mod(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(z + 1)))
    local seen = false
    for _, r in ipairs(res) do if not r[2] then seen = true break end end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(string.format("mutants refuses %d/%d%s", refused, #MUT, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUT)
print(string.format("[FOREUSE-CHAINE] mutants refuses %d/%d", refused, #MUT))
print(string.format("[FOREUSE-CHAINE] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
