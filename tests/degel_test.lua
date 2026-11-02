--[[
  Lot AGES, dernier maillon : le gel du centre n'est pas indéfini (shared/team/degel.lua). Hors jeu, avec mutants.
    §1 le compte : le gel s'accumule seulement quand le centre est payable ET qu'une garde gèle ; le pas est borné ;
    §2 le centre passe après Dg.AFTER de gel cumulé ET défense minimale tenue ; le gel reprend sous le plancher (le cumul reste) ;
    §3 le cumul repart à zéro quand le centre change ou n'est plus payable ;
    §4 le choix (Cap.choose) : avec ctx.thaw, le centre payable passe devant même sans reports ; sans lui, non ;
    §5 câblage (lecture des sources) : la pile laisse passer le BUT du centre seulement, le paiement sous garde ne paie que le centre,
       avec le stock moins la réserve de la reconstruction, la défense minimale est celle de S1 (hors de péril) ;
    §6 aucun nom du jeu dans le module pur ; mutants.
  Usage : lua5.2 tests/degel_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local Dg = require("shared.team.degel")
local L = require("shared.levels.config")
local Cap = require("shared.ai3.capital")

local pass, fail = 0, 0
local quiet = false
local function check(c, m)
  if c then pass = pass + 1 else fail = fail + 1 if not quiet then print("[DEGEL] ECHEC : " .. m) end end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end

local MIN = 3600

local function run_all()
  -- §1 Le compte.
  local st = Dg.step(nil, { key = "c2", open = true, held = true, floor_ok = true, tick = 0 })
  check(st.frozen == 0 and not st.active, "§1 départ : rien de cumulé")
  st = Dg.step(st, { key = "c2", open = true, held = true, floor_ok = true, tick = 5 * MIN })
  check(st.frozen == 5 * MIN and not st.active, "§1 5 min de gel cumulées, pas encore actif")
  local free = Dg.step(st, { key = "c2", open = true, held = false, floor_ok = true, tick = 8 * MIN })
  check(free.frozen == 5 * MIN, "§1 sans garde, le gel ne s'accumule pas")
  local blocked = Dg.step(st, { key = "c2", open = false, held = true, floor_ok = true, tick = 8 * MIN })
  check(blocked.frozen == 5 * MIN, "§1 centre non payable (condition, refus) : le gel ne s'accumule pas")
  local long = Dg.step(st, { key = "c2", open = true, held = true, floor_ok = true, tick = 5 * MIN + 100 * MIN })
  check(long.frozen == 5 * MIN + Dg.DT_MAX, "§1 un pas très long ne compte que Dg.DT_MAX")
  local back = Dg.step(st, { key = "c2", open = true, held = true, floor_ok = true, tick = 2 * MIN })
  check(back.frozen == 5 * MIN, "§1 un tick qui recule ne retire rien")

  -- §2 Le centre passe.
  local t = 0
  local s = Dg.step(nil, { key = "c2", open = true, held = true, floor_ok = true, tick = 0 })
  for _ = 1, 19 do
    t = t + MIN
    s = Dg.step(s, { key = "c2", open = true, held = true, floor_ok = true, tick = t })
  end
  check(s.frozen == 19 * MIN, "§2 19 min cumulées")
  check(not s.active, "§2 sous Dg.AFTER : le centre n'est pas encore autorisé")
  t = t + MIN
  s = Dg.step(s, { key = "c2", open = true, held = true, floor_ok = true, tick = t })
  check(s.active and s.frozen >= Dg.AFTER, "§2 au seuil de gel cumulé, défense tenue : le centre passe")
  local low = Dg.step(s, { key = "c2", open = true, held = true, floor_ok = false, tick = t + MIN })
  check(not low.active and low.frozen >= Dg.AFTER, "§2 défense sous le plancher : le gel reprend, le cumul reste")
  local again = Dg.step(low, { key = "c2", open = true, held = true, floor_ok = true, tick = t + 2 * MIN })
  check(again.active, "§2 défense revenue au plancher : le centre repasse sans recompter")
  local lifted = Dg.step(s, { key = "c2", open = true, held = false, floor_ok = true, tick = t + MIN })
  check(not lifted.active, "§2 plus de garde : plus rien à lever")

  -- §3 Remise à zéro.
  local other = Dg.step(s, { key = "c3", open = true, held = true, floor_ok = true, tick = t + MIN })
  check(other.frozen == 0 and not other.active, "§3 niveau suivant du centre (autre clé) : cumul à zéro")
  local none = Dg.step(s, { key = nil, open = false, held = true, floor_ok = true, tick = t + MIN })
  check(none.frozen == 0 and not none.active, "§3 plus de centre à payer : cumul à zéro")
  local d1 = Dg.step(s, { key = "c2", open = true, held = true, floor_ok = true, tick = t + MIN })
  local d2 = Dg.step(s, { key = "c2", open = true, held = true, floor_ok = true, tick = t + MIN })
  check(d1.frozen == d2.frozen and d1.active == d2.active, "§3 déterminisme")

  -- §4 Le choix avec ctx.thaw.
  local GUN, CC = L.by_key.gun, L.by_key.command
  local UNIT = { ["iron-plate"] = 2, ["copper-plate"] = 2, ["stone-brick"] = 5, ["iron-gear-wheel"] = 5, ["electronic-circuit"] = 8 }
  local proto = function(name)
    local fam, n = L.parse(name)
    if not fam then return nil end
    if fam == CC then return { type = "container", role = "logistique", health = 3000, item = name } end
    return { type = "ammo-turret", role = "militaire", health = 400 * (1.15 ^ (n - 1)), dmg = 1, dps = 0.1 * (1.15 ^ (n - 1)), item = name }
  end
  local list = {}
  for i = 1, 4 do list[i] = { id = 100 + i, name = L.name(GUN, i == 1 and 2 or 1), working = false } end
  local cen = { list = list, center = { id = 1, name = L.name(CC, 1) } }
  local function ctx(over)
    local c = { proto = proto, unit_cost = function(i) return UNIT[i] end, stock = {}, weights = {} }
    for k, v in pairs(over or {}) do c[k] = v end
    return c
  end
  local d0 = Cap.choose(L, cen, ctx())
  check(d0.family == "gun" and not d0.starved, "§4 sans levée : la tourelle moins chère passe devant le centre (" .. tostring(d0.key) .. ")")
  local d1t = Cap.choose(L, cen, ctx({ thaw = true }))
  check(d1t.center == true and d1t.starved == true, "§4 gel levé : le centre payable est la décision (" .. tostring(d1t.key) .. ")")
  local blocked_cen = { list = (function() local l = {} for i = 1, 3 do l[i] = { id = 100 + i, name = L.name(GUN, 1), working = false } end return l end)(),
    center = { id = 1, name = L.name(CC, 1) } }
  local db = Cap.choose(L, blocked_cen, ctx({ thaw = true }))
  check(db.family == "gun" and not db.center, "§4 gel levé mais centre bloqué par la condition : les tourelles d'abord")
  local g = Cap.goal(d1t, {})
  check(g and g.center == true and g.short == true, "§4 le but du centre dégelé est un travail court")

  -- §5 Câblage.
  local cerv = read("shared/ai3/cerveau.lua")
  check(cerv:find('Pi.allows(pile, "capital") or (ctx.thaw and ctx.capital.center)', 1, true) ~= nil,
    "§5 la pile laisse passer le but du centre dégelé, lui seul")
  local rt = read("script/ai3/capital.lua")
  local sc = read("script/ai3/cerveau.lua")
  check(sc:find("thaw = Capital.thaw_active(f),", 1, true) ~= nil, "§5 la pensée du cerveau reçoit l'état de levée (sans lui, la pile retenait le but : essai 5)")
  check(rt:find("function Capital.thaw_active", 1, true) ~= nil, "§5 Capital.thaw_active existe")
  check(rt:find("only_center and not (d and d.center)", 1, true) ~= nil, "§5 sous garde, Capital.pay ne paie que le centre")
  check(rt:find("floor_ok = (s1 ~= nil and s1.was == false)", 1, true) ~= nil, "§5 défense minimale = S1 hors de péril, absente = rien ne passe")
  check(rt:find("thaw = (c.thaw and c.thaw.active) or false", 1, true) ~= nil, "§5 la décision lit l'état de levée")
  local tm = read("script/team/team.lua")
  check(tm:find("Ia3.capital_thaw(f, true, tick)", 1, true) ~= nil and tm:find("Recon.upgrade_stock(f, book_for(f), stock, tick, plan), true)", 1, true) ~= nil,
    "§5 team.lua : le pas de gel et le paiement du centre avec le stock moins la réserve de la reconstruction")
  check(tm:find("Ia3.capital_thaw(f, false, tick)", 1, true) ~= nil, "§5 team.lua : le pas est aussi fait sans garde (le tick suit)")

  -- §6 Aucun nom du jeu.
  local src = read("shared/team/degel.lua")
  for _, w in ipairs({ "iron%-plate", "copper%-plate", "gun%-turret", "stone%-", "steel", "electronic%-circuit" }) do
    check(not src:find(w), "§6 aucun nom du jeu dans le module pur : " .. w)
  end
end

run_all()

-- §6 Mutants.
do
  local n, caught = 0, 0
  local function M(name, apply, undo)
    n = n + 1
    local p0, f0 = pass, fail
    quiet = true
    apply()
    local ok = pcall(run_all)
    undo()
    quiet = false
    local c = (not ok) or fail > f0
    pass, fail = p0, f0
    if c then caught = caught + 1 else print("[DEGEL] mutant survivant : " .. name) end
  end
  local a0 = Dg.AFTER
  M("gel jamais levé", function() Dg.AFTER = 1e12 end, function() Dg.AFTER = a0 end)
  M("gel levé tout de suite", function() Dg.AFTER = 0 end, function() Dg.AFTER = a0 end)
  local d0 = Dg.DT_MAX
  M("pas non borné", function() Dg.DT_MAX = 1e12 end, function() Dg.DT_MAX = d0 end)
  local step = Dg.step
  M("plancher ignoré", function()
    Dg.step = function(st, a) local b = {} for k, v in pairs(a) do b[k] = v end b.floor_ok = true return step(st, b) end
  end, function() Dg.step = step end)
  M("compte sans garde", function()
    Dg.step = function(st, a) local b = {} for k, v in pairs(a) do b[k] = v end b.held = true return step(st, b) end
  end, function() Dg.step = step end)
  M("compte centre bloqué", function()
    Dg.step = function(st, a) local b = {} for k, v in pairs(a) do b[k] = v end b.open = true return step(st, b) end
  end, function() Dg.step = step end)
  M("cumul jamais remis à zéro", function()
    Dg.step = function(st, a) local b = {} for k, v in pairs(a) do b[k] = v end if st then b.key = st.key or b.key end return step(st, b) end
  end, function() Dg.step = step end)
  local ch = Cap.choose
  M("levée ignorée au choix", function()
    Cap.choose = function(Ld, c, x) local y = {} for k, v in pairs(x) do y[k] = v end y.thaw = nil return ch(Ld, c, y) end
  end, function() Cap.choose = ch end)
  check(caught == n, string.format("§6 mutants : %d refusés sur %d", caught, n))
end

print(string.format("[DEGEL] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
