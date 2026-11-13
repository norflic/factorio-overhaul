--[[
  Lot FOREUSES-THERMIQUES, partie C : le réseau qui tombe (fo-logs/2026-11-05_FOREUSES-TH/C_CRITERES.md, critères C1 à C8).
  Une électrique d'avant-poste sans courant (statut no_power) se tait ; après `wait` ticks de panne continue, elle redevient thermique, à
  la place notée au remplacement (sinon la place inverse qui dépose dans le même récepteur) ; la place reste ensuite tranquille `hold`
  ticks avant un nouveau remplacement.

  A. Règle pure (shared/team/repli_thermique.lua) : Rt.cfg, Rt.observe, Rt.plan, Rt.places.
  B. Exécutant (script/team/foreuse_swap.lua : Swap.repli, revert_one, place notée par swap_one, nettoyage de compact) sur le monde factice
     de tests/foreuse_monde.lua (statut d'une électrique lu à la couverture des poteaux d'un réseau vivant ; modèle pessimiste : une
     foreuse figée rend aussi no_power).
  Mutants : chacun doit faire tomber au moins un contrôle (règle pure : suite pure ET suite de l'exécutant avec le module mutant).

  Usage, depuis la racine du mod :   lua5.2 tests/repli_thermique_test.lua
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Monde = require("tests.foreuse_monde")

local ok_n, bad = 0, 0
local function check(name, cond, detail)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[REPLI-THERMIQUE] ECHEC : " .. name .. (detail and (" (" .. tostring(detail) .. ")") or "")) end
end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end
local PURE = read("shared/team/repli_thermique.lua")
local SCRIPT = read("script/team/foreuse_swap.lua")
local MOD = "shared.team.repli_thermique"

local function load_pure(src)
  local fn = load(src, "=repli_thermique", "t", setmetatable({ require = require }, { __index = _G }))
  if not fn then return nil end
  local okc, mod = pcall(fn)
  return okc and mod or nil
end

---------------------------------------------------------------------------------------------------
-- A. Règle pure
---------------------------------------------------------------------------------------------------
local BURNER = { size = 2, drop = T.drill_drop }
local CFG = { wait = 900, hold = 1200, per_pass = 2, every = 300 }

local function pure_suite(Rt)
  local res = {}
  local function c(name, cond, detail) res[#res + 1] = { name, cond and true or false, detail } end
  -- A1 : réglage
  local d = Rt.cfg(nil)
  c("A1 defauts : 5 min, 10 min, 4 par passe, toutes les 300 ticks, allumee", d.wait == 18000 and d.hold == 36000 and d.per_pass == 4
    and d.every == 300 and d.on == true)
  local o = Rt.cfg({ wait = 600, hold = 600, on = false, per_pass = -1 })
  c("A1 banc : wait et hold remplaces, valeur negative ignoree, eteinte", o.wait == 600 and o.hold == 600 and o.per_pass == 4 and o.on == false)
  -- A2 : observation PAR ÉLECTRIQUE (C1 : signal à la première observation ; aucun repli avant wait ; panne CONTINUE de chacune)
  local m, r, s, st = Rt.observe(nil, {}, 100, CFG)
  c("A2 aucune sans courant : rien, pas de memoire", m == nil and #r == 0 and s == nil and st == "rien")
  m, r, s, st = Rt.observe(nil, { 7, 5 }, 300, CFG)
  c("A2 C1 premiere observation sans courant : signal, debut note pour chacune", m and m[7] == 300 and m[5] == 300 and #r == 0
    and s == 300 and st == "signal", tostring(st))
  local m2, r2, s2, st2 = Rt.observe(m, { 7, 5 }, 1199, CFG)
  c("A2 C1 aucun repli avant wait (899 ticks)", #r2 == 0 and s2 == 300 and st2 == "signal", tostring(st2))
  local m3, r3, s3, st3 = Rt.observe(m2, { 5, 9 }, 1200, CFG)
  c("A2 repli a wait (900 ticks) : seule l'electrique sans courant depuis 900 ticks est prete ; la nouvelle commence",
    #r3 == 1 and r3[1] == 5 and m3[9] == 1200 and m3[7] == nil and s3 == 300 and st3 == "repli",
    tostring(st3) .. " " .. #r3 .. " " .. tostring(m3 and m3[9]))
  local m4, r4, s4, st4 = Rt.observe(m3, {}, 1500, CFG)
  c("A2 courant revenu : memoire effacee", m4 == nil and #r4 == 0 and s4 == nil and st4 == "rien")
  local m5 = Rt.observe(m4, { 5 }, 1800, CFG)
  local _, r6, s6, st6 = Rt.observe(m5, { 5 }, 2400, CFG)
  c("A2 panne qui reprend : horloge repartie de zero", #r6 == 0 and s6 == 1800 and st6 == "signal", tostring(s6) .. " " .. tostring(st6))
  -- banc foreuses-panne-diag (8/11) : électriques JUSTE posées (sans courant au tick de leur pose) à chaque observation, les anciennes au
  -- travail : la panne d'avant-poste ne doit pas se prolonger d'une pose à l'autre
  local mf = Rt.observe(nil, { 149 }, 180, CFG)
  local _, rf, _, stf = Rt.observe(mf, { 193, 195 }, 1080, CFG)
  c("A2 electriques juste posees a chaque pensee : jamais pretes (memoire par electrique)", #rf == 0 and stf == "signal", #rf .. " " .. tostring(stf))
  -- A3 : plan (C4 : combustible d'abord, au plus per_pass ; C5 : sans thermique, attente)
  local list = {
    { id = 7, fuel = false, dark = { 31, 30, 32 } },
    { id = 9, fuel = true, dark = { 50 } },
    { id = 3, fuel = false, dark = { 12, 11 } },
  }
  local picks, short = Rt.plan(list, 10, CFG)
  c("A3 C4 combustible d'abord, puis le plus d'electriques sans courant ; au plus per_pass",
    #picks == 2 and short == 0 and picks[1].id == 9 and picks[1].unit == 50 and picks[2].id == 7 and picks[2].unit == 30,
    #picks .. " " .. tostring(picks[1] and picks[1].id) .. ":" .. tostring(picks[1] and picks[1].unit) .. " " .. tostring(picks[2] and picks[2].id)
      .. ":" .. tostring(picks[2] and picks[2].unit))
  local p2 = Rt.plan(list, 10, { per_pass = 5 })
  local seq = {}
  for _, p in ipairs(p2) do seq[#seq + 1] = p.id .. ":" .. p.unit end
  c("A3 ordre complet : numeros d'unite croissants dans un avant-poste, a egalite le numero d'avant-poste",
    table.concat(seq, " ") == "9:50 7:30 7:31 7:32 3:11", table.concat(seq, " "))
  local p3, sh3 = Rt.plan({ { id = 1, dark = { 4, 5, 6 } }, { id = 2, dark = { 8 } } }, 1, { per_pass = 3 })
  c("A3 C5 au plus les thermiques du stock, le reste attend", #p3 == 1 and p3[1].unit == 4 and sh3 == 2, #p3 .. " " .. sh3)
  local p4, sh4 = Rt.plan({ { id = 1, dark = { 4 } } }, 0, CFG)
  c("A3 C5 aucune thermique : rien, une en attente", #p4 == 0 and sh4 == 1)
  c("A3 liste d'entree intacte (copie triee)", list[1].id == 7 and list[1].dark[1] == 31)
  -- A4 : places (C2 place notée ; C8 place inverse dans le même récepteur)
  local sink = { x = 10, y = 8, w = 2, h = 2 }
  local pl = Rt.places({ x = 11, y = 10, dir = 0 }, 10.5, 10.5, 0, sink, BURNER, 3)
  c("A4 C2 place notee d'abord, puis la place inverse", #pl == 2 and pl[1].how == "notee" and pl[1].x == 11 and pl[1].y == 10
    and pl[2].how == "inverse" and pl[2].x == 10 and pl[2].y == 10, #pl .. " " .. tostring(pl[1] and pl[1].how))
  local pi = Rt.places(nil, 10.5, 10.5, 0, sink, BURNER, 3)
  local ok8 = #pi == 1 and pi[1].how == "inverse"
  if ok8 then
    local vx, vy = BURNER.drop[1], BURNER.drop[2]
    local px, py = pi[1].x + vx, pi[1].y + vy
    ok8 = math.abs(px - sink.x) < 1 and math.abs(py - sink.y) < 1 and math.abs(pi[1].x - 10.5) + 1 <= 1.5 and math.abs(pi[1].y - 10.5) + 1 <= 1.5
  end
  c("A4 C8 sans place notee : place inverse, 2 x 2 dans l'ancienne 3 x 3, depot dans le meme recepteur", ok8)
  local pw = Rt.places({ x = 14, y = 10, dir = 0 }, 10.5, 10.5, 0, sink, BURNER, 3)
  c("A4 place notee dont le depot ne tombe plus dans le recepteur : ecartee", #pw == 1 and pw[1].how == "inverse", #pw)
  local pe = Rt.places({ x = 10, y = 10, dir = 0 }, 10.5, 10.5, 0, sink, BURNER, 3)
  c("A4 place notee egale a l'inverse : une seule candidate", #pe == 1 and pe[1].how == "notee", #pe)
  c("A4 sans recepteur : aucune place", #Rt.places({ x = 11, y = 10, dir = 0 }, 10.5, 10.5, 0, nil, BURNER, 3) == 0)
  local pr = Rt.places(nil, 10.5, 10.5, 4, { x = 11, y = 13, w = 2, h = 2 }, BURNER, 3)
  -- (10, 11) et (11, 11) déposent dans le four sud ; x puis y croissants : (10, 11)
  c("A4 electrique tournee vers le sud : place inverse vers le sud", #pr == 1 and pr[1].dir == 4 and pr[1].x == 10 and pr[1].y == 11,
    pr[1] and (pr[1].x .. "," .. pr[1].y .. "," .. pr[1].dir) or "aucune")
  c("A5 fin de garde = maintenant + hold", Rt.hold_until(1200, CFG) == 2400)
  return res
end

local function run_pure(src)
  local Rt = load_pure(src)
  if not Rt then return { { "chargement de la regle pure", false } } end
  local okr, res = pcall(pure_suite, Rt)
  if not okr then return { { "suite pure : " .. tostring(res), false } } end
  return res
end

---------------------------------------------------------------------------------------------------
-- B. Exécutant, monde factice
---------------------------------------------------------------------------------------------------
-- Avant-postes déjà passés à l'électrique (comme après le remplacement sur place) : électrique i de l'avant-poste j centrée en
-- (10,5 + 5 i, 10,5 + 20 (j - 1)), direction nord ; réceptacle au nord (four 2 x 2 centré 2,5 tuiles plus haut, ou coffre 1 x 1 deux
-- tuiles plus haut) ; un petit poteau SOURCE sous chaque électrique (le couper : W.cut) ; place notée de la thermique (+0,5 ; -0,5).
local function build_dark(spec, no_from)
  return function(W)
    local hq = W.add("fo-team-chest", 20.5, 300.5, 0, { force = "player" })
    hq.surface = W.surface
    local outposts, poles = {}, {}
    for j, sp in ipairs(spec) do
      local oy = 20 * (j - 1)
      local o = { id = sp.id, kind = sp.kind, pos = { x = 20, y = 10 + oy }, drill_list = {}, sinks = {}, drills = 0, swap_from = {} }
      for i = 0, sp.n - 1 do
        local cx, cy = 10.5 + 5 * i, 10.5 + oy
        for x = -1, 1 do for y = -1, 1 do W.add("iron-ore", cx + x, cy + y, 0) end end
        local d = W.add("electric-mining-drill", cx, cy, 0, { force = "player" })
        local s
        if T.outposts[sp.kind].sink == "stone-furnace" then
          s = W.add("stone-furnace", cx - 0.5, cy - 2.5, 0, { force = "player" })
        else
          s = W.add("iron-chest", cx, cy - 2, 0, { force = "player" })
        end
        poles[#poles + 1] = W.add("small-electric-pole", cx, cy + 2, 0, { force = "player", source = true })
        o.drill_list[#o.drill_list + 1] = d
        o.sinks[#o.sinks + 1] = s
        o.drills = o.drills + 1
        if not no_from then o.swap_from[d.unit_number] = { x = cx + 0.5, y = cy - 0.5, dir = 0 } end
      end
      outposts[sp.id] = o
    end
    W.poles = poles
    W.cut = function(on) for _, q in ipairs(poles) do q.source = not on end end
    return hq, outposts, poles[1]
  end
end

local function fresh(text, build, cfg, stock)
  local R = Monde.fresh(text, false, nil, build)
  for _, q in ipairs(R.W.poles or {}) do R.env.own[q.unit_number] = { f = "player", kind = "pole" } end
  R.f.team.repli = cfg
  -- électriques posées par le remplacement sur place : son état existe (Swap.think l'a créé)
  R.f.swap = { next = 0, done = 0, failed = 0, retry = {} }
  for k, v in pairs(stock or {}) do R.env.stock[k] = v end
  return R
end

--- Une pensée au tick `tick`, dans l'ordre de TT.e5 (script/team/team.lua) : repli (Swap.repli, hors de la garde de la pile), puis
--- remplacement (Swap.think, si `swap`), puis les minuteries des tranches. `swap_first` : le pire ordre (remplacement PUIS repli au même
--- tick). Rend le nombre de replis.
local function think(R, tick, swap, swap_first)
  Monde.use(R)
  game.tick = tick
  local free = {}
  for _, n in ipairs(Monde.sorted_keys(R.env.stock)) do free[n] = R.env.stock[n] end
  local n = 0
  if swap_first and swap then R.Swap.think(R.f, R.W.surface, R.env.book, free, tick) end
  n = R.Swap.repli(R.f, R.W.surface, R.env.book, free, tick)
  if swap and not swap_first then R.Swap.think(R.f, R.W.surface, R.env.book, free, tick) end
  local guard = 0
  while #R.env.queue > 0 and guard < 1000 do
    guard = guard + 1
    local q = table.remove(R.env.queue, 1)
    game.tick = q.at
    R.env.timers[q.name](q.p, q.at)
  end
  return n
end

local function count(o)
  local b, e = 0, 0
  for _, d in ipairs(o.drill_list) do
    if d.valid then if d.name == T.DRILL then b = b + 1 else e = e + 1 end end
  end
  return b, e
end
local function logged(R, pat)
  for _, l in ipairs(R.W.logs) do if l:find(pat, 1, true) then return true end end
  return false
end

local function script_suite(text)
  local res = {}
  local function c(name, cond, detail) res[#res + 1] = { name, cond and true or false, detail } end
  local CF = { wait = 900, hold = 1200, every = 300, per_pass = 2 }

  -- B1 : C1 et C2 sur un avant-poste de fer de 2 électriques ; courant coupé au tick 300
  local R = fresh(text, build_dark({ { id = 1, kind = "iron", n = 2 } }), CF, { ["burner-mining-drill"] = 5 })
  local o = R.f.outposts[1]
  local e1, e2, s1 = o.drill_list[1], o.drill_list[2], o.sinks[1]
  local u1, u2 = e1.unit_number, e2.unit_number
  think(R, 0)
  c("B1 courant la : aucun signal", (o.unpowered or -1) == 0 and o.electric == 2 and o.dark_since == nil,
    tostring(o.unpowered) .. " " .. tostring(o.electric))
  R.W.cut(true)
  think(R, 300)
  c("B1 C1 signal leve a la premiere pensee sans courant", o.unpowered == 2 and o.dark_since == 300
    and logged(R, "panne vue, pose suspendue : avant-poste 1 (iron), 2 electrique(s) sans courant sur 2"), tostring(o.unpowered) .. " " .. tostring(o.dark_since))
  think(R, 600)
  think(R, 900)
  local b0, el0 = count(o)
  c("B1 C1 aucun repli avant wait", b0 == 0 and el0 == 2 and e1.valid and e2.valid, b0 .. " " .. el0)
  local n = think(R, 1200)
  local d1 = o.drill_list[1]
  local fuel = d1.valid and d1.inv.fuel.coal or 0
  c("B1 C2 repli apres wait : 2 thermiques (per_pass), electriques retirees", n == 2 and not e1.valid and not e2.valid and count(o) == 2,
    tostring(n))
  c("B1 C2 thermique a la place notee, direction nord, avec son combustible", d1.valid and d1.name == T.DRILL and d1.position.x == 11
    and d1.position.y == 10 and d1.direction == 0 and fuel == T.fuel_per_burner, string.format("%s (%.1f, %.1f) combustible %d", d1.name,
      d1.position.x, d1.position.y, fuel))
  c("B1 C2 electriques rendues au stock, thermiques et combustible pris", R.env.stock["electric-mining-drill"] == 6
    and R.env.stock["burner-mining-drill"] == 3 and R.env.stock.coal == 100 - 2 * T.fuel_per_burner,
    string.format("electriques %s thermiques %s charbon %s", tostring(R.env.stock["electric-mining-drill"]), tostring(R.env.stock["burner-mining-drill"]),
      tostring(R.env.stock.coal)))
  c("B1 C2 recepteur inchange (meme four, depot de la thermique dedans)", s1.valid and o.sinks[1] == s1 and d1.drop_target == s1)
  c("B1 C2 propriete tenue, places notees retirees, compte de foreuses", R.env.own[d1.unit_number] ~= nil and R.env.own[u1] == nil
    and R.env.own[u2] == nil and o.swap_from[u1] == nil and o.swap_from[u2] == nil and o.drills == 2)
  c("B1 C2 journal du repli", logged(R, "repli : avant-poste 1 (iron), electrique " .. u1 .. " rendue thermique (place notee, 5 combustible(s))"))
  c("B1 remplacement retenu hold ticks sur la place", (R.f.swap.retry["11:10"] or 0) == 1200 + CF.hold, tostring(R.f.swap.retry["11:10"]))

  -- B2 : C3 low_power (le réseau produit) : jamais de repli
  local R2 = fresh(text, build_dark({ { id = 1, kind = "iron", n = 2 } }), CF, { ["burner-mining-drill"] = 5 })
  R2.W.low = true
  for k = 0, 8 do think(R2, 300 * k) end
  local _, el2 = count(R2.f.outposts[1])
  c("B2 C3 low_power : jamais compte, aucun repli", el2 == 2 and R2.f.outposts[1].unpowered == 0 and R2.f.outposts[1].dark_since == nil, el2)
  -- B3 : C3 foreuse figée (active == false), réseau coupé : jamais comptée
  local R3 = fresh(text, build_dark({ { id = 1, kind = "iron", n = 2 } }), CF, { ["burner-mining-drill"] = 5 })
  R3.W.cut(true)
  for _, d in ipairs(R3.f.outposts[1].drill_list) do d.active = false end
  for k = 0, 8 do think(R3, 300 * k) end
  local _, el3 = count(R3.f.outposts[1])
  c("B3 C3 foreuses figees : jamais comptees, aucun repli", el3 == 2 and R3.f.outposts[1].unpowered == 0, el3)

  -- B4 : C4 combustible d'abord, au plus per_pass par passe
  local R4 = fresh(text, build_dark({ { id = 1, kind = "iron", n = 3 }, { id = 2, kind = "coal", n = 1 } }), CF, { ["burner-mining-drill"] = 9 })
  R4.W.cut(true) -- coupé avant le tick 0 : panne vue au tick 0, repli au tick 900
  for k = 0, 2 do think(R4, 300 * k) end
  local n4 = think(R4, 900)
  local bi, ei = count(R4.f.outposts[1])
  local bc, ec = count(R4.f.outposts[2])
  c("B4 C4 premiere passe : la thermique de charbon d'abord, 2 en tout", n4 == 2 and bc == 1 and ec == 0 and bi == 1 and ei == 2,
    string.format("n %d ; charbon %d/%d ; fer %d/%d", n4, bc, ec, bi, ei))
  think(R4, 1200)
  think(R4, 1500)
  local bi2, ei2 = count(R4.f.outposts[1])
  c("B4 passes suivantes : le reste replie, 2 par passe", bi2 == 3 and ei2 == 0, bi2 .. "/" .. ei2)

  -- B5 : C5 sans thermique ni fabrication : attente et sa raison, rien de retiré ; fabricable : tâche de fabrication
  local R5 = fresh(text, build_dark({ { id = 1, kind = "iron", n = 2 } }), CF, { ["burner-mining-drill"] = 0 })
  R5.env.book.handcraftable = function(_, item) return item ~= T.DRILL end
  R5.W.cut(true)
  for k = 0, 5 do think(R5, 300 * k) end
  local _, el5 = count(R5.f.outposts[1])
  c("B5 C5 sans thermique : rien de retire, raison au journal", el5 == 2 and ((R5.f.swap.repli.why or {})["pas de thermique"] or 0) > 0
    and logged(R5, "pas de thermique"), el5)
  local R5b = fresh(text, build_dark({ { id = 1, kind = "iron", n = 2 } }), CF, { ["burner-mining-drill"] = 0 })
  R5b.W.cut(true)
  for k = 0, 4 do think(R5b, 300 * k) end
  local craft = false
  for _, l in ipairs(R5b.env.board) do if l:find("craft:burner-mining-drill:foreuse burner-mining-drill 2", 1, true) then craft = true end end
  c("B5 thermique fabricable : tache de fabrication (2), raison au journal", craft and logged(R5b, "thermique a fabriquer"),
    table.concat(R5b.env.board, " | "))

  -- B6 : C6 courant revenu : pas de nouveau remplacement avant hold, puis remplacement de nouveau
  local R6 = fresh(text, build_dark({ { id = 1, kind = "iron", n = 1 } }), CF, { ["burner-mining-drill"] = 2 })
  local o6 = R6.f.outposts[1]
  think(R6, 0, true)
  R6.W.cut(true)
  for k = 1, 4 do think(R6, 300 * k, true) end -- repli au tick 1 200
  local b6 = count(o6)
  R6.W.cut(false) -- courant rendu au tick 1 500
  local early = false
  for k = 5, 7 do -- 1 500 à 2 100 : avant la fin de la garde (2 400)
    think(R6, 300 * k, true)
    local _, e = count(o6)
    if e > 0 then early = true end
  end
  c("B6 C6 repli fait, puis aucun remplacement avant hold", b6 == 1 and not early, tostring(b6) .. " " .. tostring(early))
  think(R6, 2400, true)
  think(R6, 2700, true)
  local b6b, e6b = count(o6)
  c("B6 C6 apres hold, courant la : remplacement de nouveau", e6b == 1 and b6b == 0 and logged(R6, "courant revenu") == false,
    b6b .. "/" .. e6b)

  -- B7 : C7 place prise entre le plan et l'exécution : rien de retiré
  local R7 = fresh(text, build_dark({ { id = 1, kind = "iron", n = 1 } }), CF, { ["burner-mining-drill"] = 2 })
  local o7 = R7.f.outposts[1]
  local e7 = o7.drill_list[1]
  R7.W.cut(true) -- coupé avant le tick 0 : repli dû au tick 900
  for k = 0, 2 do think(R7, 300 * k) end
  R7.W.add("iron-chest", 10.5, 10.5, 0, { force = "player" }) -- posé par script PAR-DESSUS (F70) : les deux places sont prises
  think(R7, 900)
  c("B7 C7 place prise : la meme electrique reste, stock intact, raison au journal", e7.valid and o7.drill_list[1] == e7 and o7.drills == 1
    and R7.env.stock["burner-mining-drill"] == 2 and R7.env.stock["electric-mining-drill"] == 4 and ((R7.f.swap.repli.why or {})["place prise"] or 0) > 0,
    tostring(e7.valid) .. " " .. tostring(R7.env.stock["electric-mining-drill"]))

  -- B8 : C8 électrique d'avant la partie C (sans place notée) : place inverse, dépôt dans le même récepteur
  local R8 = fresh(text, build_dark({ { id = 1, kind = "iron", n = 1 } }, true), CF, { ["burner-mining-drill"] = 2 })
  local o8 = R8.f.outposts[1]
  local s8 = o8.sinks[1]
  R8.W.cut(true)
  for k = 0, 4 do think(R8, 300 * k) end
  local d8 = o8.drill_list[1]
  c("B8 C8 sans place notee : thermique a la place inverse (10, 10), meme recepteur", d8.valid and d8.name == T.DRILL and d8.position.x == 10
    and d8.position.y == 10 and d8.drop_target == s8 and logged(R8, "place inverse"),
    d8.valid and string.format("%s (%.1f, %.1f)", d8.name, d8.position.x, d8.position.y) or "invalide")

  -- B9 : coffre plein : rien de retiré
  local R9 = fresh(text, build_dark({ { id = 1, kind = "iron", n = 1 } }), CF, { ["burner-mining-drill"] = 2 })
  R9.W.full = true
  R9.W.cut(true)
  for k = 0, 4 do think(R9, 300 * k) end
  c("B9 coffre plein : l'electrique reste, aucune thermique prise", R9.f.outposts[1].drill_list[1].valid and R9.env.stock["burner-mining-drill"] == 2
    and ((R9.f.swap.repli.why or {})["coffre plein"] or 0) > 0)

  -- B10 : règle éteinte (témoin des bancs) : rien
  local R10 = fresh(text, build_dark({ { id = 1, kind = "iron", n = 1 } }), { on = false }, { ["burner-mining-drill"] = 2 })
  R10.W.cut(true)
  for k = 0, 80 do think(R10, 300 * k) end
  local _, e10 = count(R10.f.outposts[1])
  c("B10 regle eteinte : aucune observation, aucun repli", e10 == 1 and R10.f.outposts[1].unpowered == nil)

  -- B12 : sans état du remplacement (aucun Swap.think) : rien, et aucun état créé (gisement.lua lit f.swap.ready)
  local R12 = fresh(text, build_dark({ { id = 1, kind = "iron", n = 1 } }), CF, { ["burner-mining-drill"] = 2 })
  R12.f.swap = nil
  R12.W.cut(true)
  for k = 0, 4 do think(R12, 300 * k) end
  local _, e12 = count(R12.f.outposts[1])
  c("B12 sans etat du remplacement : rien, f.swap non cree", e12 == 1 and R12.f.swap == nil)

  -- B13 : banc foreuses-panne-diag du 8/11 (mesuré) : une électrique posée est sans courant AU TICK de sa pose (monde factice : e.born) ;
  -- remplacement puis repli au même tick (le pire ordre), réseau alimenté tout du long : aucun repli
  local R13 = Monde.fresh(text, false, nil, Monde.build_fer)
  R13.f.team.repli = { wait = 300, hold = 600, every = 300, per_pass = 2 }
  R13.env.stock["burner-mining-drill"] = 4
  local seen_dark = false
  for k = 0, 9 do
    think(R13, 300 * k, true, true)
    if (R13.f.outposts[1].unpowered or 0) > 0 then seen_dark = true end
  end
  local _, e13 = count(R13.f.outposts[1])
  c("B13 electriques juste posees (sans courant au tick de la pose), reseau alimente : aucun repli", seen_dark and e13 >= 4
    and (R13.f.swap.repli.done or 0) == 0, string.format("vues sans courant %s, electriques %d, replis %d", tostring(seen_dark), e13,
      R13.f.swap.repli.done or 0))

  -- B14 : lead, 8/11 : coupure (le flux de la dernière minute reste positif : W.stats_lag), puis AUCUNE pose du remplacement entre la
  -- coupure et le retour du courant ; ligne « pose suspendue » ; pose reprise au retour
  local R14 = Monde.fresh(text, false, nil, Monde.build_fer)
  R14.f.team.repli = { wait = 900, hold = 600, every = 300, per_pass = 2 }
  R14.env.stock["electric-mining-drill"] = 20
  for k = 0, 1 do think(R14, 300 * k, true) end -- 2 électriques posées (le monde factice se sature au-delà de 6 : « 3x3 bloquee »)
  local _, e_cut = count(R14.f.outposts[1])
  R14.W.dead, R14.W.stats_lag = true, true -- coupure : réseau intact, plus de production, flux de la dernière minute encore positif
  local max_during = e_cut
  for k = 2, 4 do -- panne vue au tick 600 ; wait 900 : aucun repli jusqu'au tick 1 200
    think(R14, 300 * k, true)
    local _, e = count(R14.f.outposts[1])
    if e > max_during then max_during = e end
  end
  c("B14 coupure : aucune electrique posee avant le retour du courant, pose suspendue au journal", e_cut > 0 and max_during == e_cut
    and logged(R14, "pose suspendue : avant-poste 1 (iron)") and (R14.f.swap.repli.done or 0) == 0,
    string.format("a la coupure %d, au plus %d pendant, replis %d", e_cut, max_during, R14.f.swap.repli.done or 0))
  R14.W.dead, R14.W.stats_lag = false, false
  for k = 5, 8 do think(R14, 300 * k, true) end
  local _, e_back = count(R14.f.outposts[1])
  c("B14 courant revenu : pose reprise (journal), electriques de nouveau posees", e_back > e_cut and logged(R14, "courant revenu, pose reprise"),
    string.format("%d -> %d", e_cut, e_back))
  -- B15 : règle éteinte après une panne vue : la mémoire est effacée, la pose n'est pas suspendue pour toujours
  local R15 = fresh(text, build_dark({ { id = 1, kind = "iron", n = 1 } }), CF, { ["burner-mining-drill"] = 2 })
  R15.W.cut(true)
  think(R15, 0)
  local had = R15.f.outposts[1].dark_units ~= nil
  R15.f.team.repli = { on = false }
  think(R15, 300)
  c("B15 regle eteinte : memoire de panne effacee (pose plus suspendue)", had and R15.f.outposts[1].dark_units == nil)

  -- B11 : la place notée par le remplacement sur place (swap_one), et nettoyée par compact
  local R11 = Monde.fresh(text, false, nil, Monde.build_fer)
  local starts = {}
  for _, oid in ipairs({ 1, 2 }) do
    for _, d in ipairs(R11.f.outposts[oid].drill_list) do starts[d.position.x .. ":" .. d.position.y .. ":" .. d.direction] = true end
  end
  Monde.play(R11, 6)
  local o11 = R11.f.outposts[1]
  local n_el, n_ok = 0, 0
  for _, d in ipairs(o11.drill_list) do
    if d.valid and d.name ~= T.DRILL then
      n_el = n_el + 1
      local fr = o11.swap_from and o11.swap_from[d.unit_number]
      if fr and starts[fr.x .. ":" .. fr.y .. ":" .. fr.dir] then n_ok = n_ok + 1 end
    end
  end
  c("B11 swap_one note la place et la direction de la thermique remplacee", n_el > 0 and n_ok == n_el, n_ok .. "/" .. n_el)
  local victim
  for _, d in ipairs(o11.drill_list) do if d.valid and d.name ~= T.DRILL then victim = d break end end
  local vu = victim and victim.unit_number
  if victim then victim.valid = false end
  R11.env.stock["electric-mining-drill"] = 6
  for k = 6, 8 do think(R11, k * T.swap.every, true) end -- passes suivantes (Monde.play repartirait du tick 0)
  local stale = 0
  local live = {}
  for _, d in ipairs(o11.drill_list) do if d.valid then live[d.unit_number] = true end end
  for u in pairs(o11.swap_from or {}) do if not live[u] then stale = stale + 1 end end
  c("B11 compact retire les places notees des electriques disparues", vu ~= nil and (o11.swap_from or {})[vu] == nil and stale == 0,
    tostring(vu) .. " " .. stale)
  return res
end

local function run_script(text)
  local okr, res = pcall(script_suite, text)
  if not okr then return { { "suite de l'executant : " .. tostring(res), false } } end
  return res
end

for _, r in ipairs(run_pure(PURE)) do check(r[1], r[2], r[3]) end
for _, r in ipairs(run_script(SCRIPT)) do check(r[1], r[2], r[3]) end

---------------------------------------------------------------------------------------------------
-- Mutants : chacun doit faire tomber au moins un contrôle
---------------------------------------------------------------------------------------------------
local MUT = {
  { "pur", "signal jamais leve", { { '  if not mem then return nil, ready, nil, "rien" end', '  if true then return nil, ready, nil, "rien" end' } } },
  { "pur", "repli avant wait", { { "    if now - s >= cfg.wait then ready[#ready + 1] = u end", "    if now - s >= 0 then ready[#ready + 1] = u end" } } },
  { "pur", "panne non continue (memoire jamais effacee)", { { "  local mem, ready, since = nil, {}, nil", "  local mem, ready, since = prev, {}, nil" } } },
  { "pur", "horloge repartie a chaque observation", { { "    local s = (prev and prev[u]) or now", "    local s = now" } } },
  { "pur", "memoire commune a l'avant-poste (banc diag du 8/11)", { { "    local s = (prev and prev[u]) or now", "    local s = (prev and prev[next(prev)]) or now" } } },
  { "pur", "ordre du combustible ignore", { { "  if fa ~= fb then return fa end", "  if false then return fa end" } } },
  { "pur", "per_pass ignore", { { "      if #picks + short >= cfg.per_pass then return picks, short end", "" } } },
  { "pur", "stock de thermiques ignore", { { "      if #picks < have then", "      if true then" } } },
  { "pur", "place notee sans controle du depot", { { "    if S.inside(sink, from.x + vx, from.y + vy) and not S.overlap(box, sink) then", "    if true then" } } },
  { "pur", "garde nulle", { { "  return now + cfg.hold", "  return now" } } },
  { "script", "signal jamais leve (o.unpowered)", { { "    o.electric, o.unpowered = electric, #dark", "    o.electric, o.unpowered = electric, 0" } } },
  { "script", "foreuse figee comptee", { { "          if d.status == NO and d.active ~= false then", "          if d.status == NO then" } } },
  { "script", "repli pendant que le reseau produit (low_power compte)", { { "          if d.status == NO and d.active ~= false then",
      "          if (d.status == NO or d.status == defines.entity_status.low_power) and d.active ~= false then" } } },
  { "script", "ordre du combustible ignore (executant)", { { "fuel = fuel_outpost(o) and true or false", "fuel = false" } } },
  { "script", "pas de garde hold", { { '  f.swap.retry[new.position.x .. ":" .. new.position.y] = Rt.hold_until(tick, cfg)', "" } } },
  { "script", "place non verifiee", { { "    if not place_taken(surface, c.x, c.y, burner.size, d) then place = c break end", "    place = c break" } } },
  { "script", "electrique non rendue", { { "d.mine({ inventory = inv, force = false, raise_destroyed = true })", "(d.destroy() or true)" } } },
  { "script", "combustible non pose", { { "    if fuel > 0 then new.get_fuel_inventory().insert({ name = T.fuel, count = fuel }) end", "" } } },
  { "script", "place notee oubliee au remplacement", { { "  o.swap_from[new.unit_number] = { x = pos.x, y = pos.y, dir = dir }", "" } } },
  { "script", "compact ne nettoie pas", { { "    for _, u in ipairs(sorted_keys(o.swap_from)) do if not live[u] then o.swap_from[u] = nil end end", "" } } },
  { "script", "regle eteinte ignoree", { { "  if not cfg.on then", "  if false then" } } },
  { "script", "etat du remplacement cree par le repli", { { "  if not (st and st.retry) then return 0 end", "  if not st then st = { next = 0, done = 0, failed = 0, retry = {} }; f.swap = st end" } } },
  { "script", "pose de B qui ignore dark_units (lead, 8/11)", { { '      local list = (o.migr == "en cours" or o.dark_units ~= nil) and {} or (o.drill_list or {})',
      '      local list = o.migr == "en cours" and {} or (o.drill_list or {})' },
    -- s42 thermiques : la satisfaction du site (Th.replace_one) refuse aussi cette pose ; le mutant retire les deux gardes
    { "if (status == defines.entity_status.no_power or status == defines.entity_status.low_power) and d.active ~= false then site.starved = site.starved + 1 end", "" } } },
  { "script", "memoire non effacee quand la regle est eteinte", { { "      if o.dark_units then o.dark_units, o.dark_since = nil, nil end", "" } } },
  { "script", "coffre plein ignore", { { '    return false, "coffre plein"', '    mined = true' } } },
}
local CR = SCRIPT:find("\r\n", 1, true) and "\r\n" or "\n"
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local src = m[1] == "pur" and PURE or SCRIPT
  local found = true
  for _, rp in ipairs(m[3]) do
    local a, z = src:find(rp[1], 1, true)
    if not a then found = false break end
    src = src:sub(1, a - 1) .. rp[2] .. src:sub(z + 1)
  end
  if not found then
    kept[#kept + 1] = m[2] .. " (motif introuvable)"
  else
    local res
    if m[1] == "pur" then
      res = run_pure(src)
      -- le module mutant, servi par require à l'exécutant (puis le vrai rendu)
      local real = package.loaded[MOD]
      local mut = load_pure(src)
      if mut then
        package.loaded[MOD] = mut
        for _, r in ipairs(run_script(SCRIPT)) do res[#res + 1] = r end
      end
      package.loaded[MOD] = real
    else
      res = run_script(src)
    end
    local seen
    for _, r in ipairs(res) do if not r[2] then seen = r[1] break end end
    if seen then
      refused = refused + 1
      print(string.format("[REPLI-THERMIQUE] mutant « %s » refuse par : %s", m[2], seen))
    else
      kept[#kept + 1] = m[2]
    end
  end
end
local _ = CR
check(string.format("mutants refuses %d/%d%s", refused, #MUT, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUT)
print(string.format("[REPLI-THERMIQUE] mutants refuses %d/%d", refused, #MUT))
print(string.format("[REPLI-THERMIQUE] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
