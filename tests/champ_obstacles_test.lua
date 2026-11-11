--[[
  Lot CHAMP-OBSTACLES (ordre du DC du 11/11) : « si un poteau électrique, un arbre résiduel ou un bâtiment gêne une tuile de foreuse,
  l'algorithme ne doit jamais annuler la rangée ni déclarer le champ plein ; il saute la tuile bloquée et pose 100 % des autres foreuses ».
  Usage, depuis la racine du mod :   lua5.2 tests/champ_obstacles_test.lua
  1. règle du saut (shared/team/champ_saut.lua) : une foreuse de bande refusée FAIL_LIMIT fois est sautée quel que soit le bloqueur ;
  2. simulation pure d'une rangée bâtie pièce par pièce (refus répétés sur les tuiles prises) : la rangée finit, toutes les autres foreuses
     sont posées ; un manque temporaire d'objet n'est jamais un refus (aucun compte) ;
  3. plan pur (shared/team/champ.lua) : une tuile prise n'enlève au plus que les foreuses qui la couvrent ;
  4. mutants refusés.
]]
package.path = "./?.lua;" .. package.path
local Sa = require("shared.team.champ_saut")
local Ch = require("shared.team.champ")

local passes, failures = 0, 0
local function check(cond, msg) if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end end
local LIMIT = 3

-- 1. règle
local POLE, TREE, BLD, MINE = { { own_turret = false } }, {}, { { own_turret = false }, { own_turret = false } }, { { own_turret = true } }
local function rule_ok(skip)
  local ok = true
  for _, c in ipairs({ { "occupe", POLE }, { "obstacle", TREE }, { "occupe", BLD }, { "occupe", MINE } }) do
    ok = ok and skip("champ-foreuse", c[1], LIMIT - 1, c[2], LIMIT) == true
  end
  ok = ok and skip("champ-foreuse", "occupe", LIMIT - 2, POLE, LIMIT) == false -- pas avant la limite
  ok = ok and skip("champ-charbon", "occupe", LIMIT - 1, POLE, LIMIT) == false -- la ligne de charbon n'est jamais sautée
  return ok
end

-- 2. rangée de `n` foreuses bâtie pièce par pièce : `taken` = indices pris (poteau, arbre, bâtiment) ; `short` = passes sans l'objet.
-- Rend (posées, sautées, rangée annulée).
local function build_row(skip, n, taken, short)
  local st = {}
  for i = 1, n do st[i] = { fails = 0 } end
  for pass = 1, 20 do
    local left = 0
    for i = 1, n do
      local e = st[i]
      if not e.built then
        if short and pass <= short then
          -- manque temporaire : aucun essai, aucun compte (build.lua revive_one : `return false` avant tout refus)
        elseif taken[i] then
          local why = taken[i]
          if skip("champ-foreuse", why == "arbre" and "obstacle" or "occupe", e.fails, POLE, LIMIT) then
            e.built, e.skipped = true, true
          else
            e.fails = e.fails + 1
            if e.fails >= LIMIT then return 0, 0, true end -- Build.FAIL_LIMIT : le module (la bande) est bloqué
          end
        else
          e.built = true
        end
        if not e.built then left = left + 1 end
      end
    end
    if left == 0 then break end
  end
  local put, skipped = 0, 0
  for i = 1, n do if st[i].skipped then skipped = skipped + 1 elseif st[i].built then put = put + 1 end end
  return put, skipped, false
end
local function row_ok(skip)
  local N = 20
  local taken = { [4] = "poteau", [9] = "arbre", [15] = "batiment" }
  local put, skipped, cut = build_row(skip, N, taken)
  if cut or put ~= N - 3 or skipped ~= 3 then return false end
  put, skipped, cut = build_row(skip, N, {}, 10) -- manque d'objet pendant 10 passes
  return not cut and put == N and skipped == 0
end

-- 3. plan pur : une tuile prise au milieu d'un gisement ne coûte que les foreuses qui la couvrent
local function rect(w, h) local o = {} for x = 0, w - 1 do for y = 0, h - 1 do o[#o + 1] = x; o[#o + 1] = y end end return o end
local function spec(bl) return { ore = rect(40, 16), blocked = bl or {}, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
  belts = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }, furnace = { size = 2, rate = 0.3125, fuel = true }, inserter = { rate = 0.83 }, target = { x = 1000, y = 0 } } end
local function drills(p) local n = 0 for _, e in ipairs(p and p.ents or {}) do if e.kind == "foreuse" then n = n + 1 end end return n end
local function plan_ok(plan)
  local base = drills(plan(spec()))
  if base == 0 then return false end
  for _, t in ipairs({ { 20, 3 }, { 10, 8 }, { 33, 0 }, { 5, 12 } }) do
    local n = drills(plan(spec({ [Ch.key(t[1], t[2])] = "poteau" })))
    if base - n > 2 then return false end -- 1 tuile : au plus les foreuses qui la touchent (décalage compris)
  end
  return true
end

print("== règle du saut")
check(rule_ok(Sa.skip), "foreuse de bande au 3e refus : sautée sous un poteau, un arbre, un bâtiment, une tourelle ; pas avant ; jamais la ligne de charbon")
print("== rangée bâtie")
check(row_ok(Sa.skip), "3 tuiles prises sur 20 : 17 foreuses posées, 3 sautées, rangée jamais annulée ; un manque d'objet n'annule rien")
print("== plan pur")
check(plan_ok(Ch.plan), "une tuile prise coûte au plus 2 foreuses du plan")

print("== mutants")
-- M1 : l'ancienne règle (tourelle de l'équipe seulement, raison « occupe » seulement)
local function old(role, reason, fails, bl, lim)
  if role ~= "champ-foreuse" or reason ~= "occupe" then return false end
  if (fails or 0) + 1 < (lim or 3) then return false end
  if not bl or #bl == 0 then return false end
  for _, b in ipairs(bl) do if not b.own_turret then return false end end
  return true
end
check(not rule_ok(old) and not row_ok(old), "mutant M1 (règle d'avant : tourelle seulement) refusé")
-- M2 : arbre (obstacle) jamais sauté
local function m2(role, reason, ...) if reason == "obstacle" then return false end return Sa.skip(role, reason, ...) end
check(not rule_ok(m2) and not row_ok(m2), "mutant M2 (arbre résiduel jamais sauté) refusé")
-- M3 : jamais sauté (la rangée s'annule au 3e refus)
local function m3() return false end
check(not rule_ok(m3) and not row_ok(m3), "mutant M3 (aucun saut) refusé")
-- M4 : sauté dès le 1er refus (une tuile occupée un instant, un PNJ, perdrait sa foreuse)
local function m4(role) return role == "champ-foreuse" end
check(not rule_ok(m4), "mutant M4 (saut au 1er refus) refusé")
-- M5 : la ligne de charbon sautée aussi
local function m5(role, reason, fails, bl, lim) return (fails or 0) + 1 >= (lim or 3) end
check(not rule_ok(m5), "mutant M5 (ligne de charbon sautée) refusé")
-- M6 : plan qui abandonne la rangée entière derrière une tuile prise
local function m6(sp)
  local any = false
  for _ in pairs(sp.blocked) do any = true end
  local p = Ch.plan(sp)
  if not any or not p then return p end
  local keep, row = {}, nil
  for _, e in ipairs(p.ents) do if e.kind == "foreuse" and not row then row = e.y end end
  for _, e in ipairs(p.ents) do if not (e.kind == "foreuse" and e.y == row) then keep[#keep + 1] = e end end
  return { ents = keep }
end
check(not plan_ok(m6), "mutant M6 (rangée abandonnée derrière une tuile prise) refusé")

print(string.format("champ_obstacles_test : %d passes, %d echecs", passes, failures))
if failures > 0 then os.exit(1) end
