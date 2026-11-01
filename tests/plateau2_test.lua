--[[
  Lot C4 PLATEAU 2 : la cible d'extraction d'une ressource qui MANQUE durablement passe au-dela du plancher de 5 capacites
  (shared/ai3/bras.lua Br.beyond, shared/ai3/buts.lua B.targets). Mesure : Emerald, 14 PNJ, cible du fer a 5 de 41 a 121 min
  ([FO-CIBLES]), 28 foreuses a combustion, 501 minerai/min, 494 plaques/min ; manque de fer jusqu'a 207 pensees de suite.
  Usage : lua5.2 tests/plateau2_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local R = require("shared.ai3.reglages")

local function read(path) local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s end
local BR_SRC, BUTS_SRC = read("shared/ai3/bras.lua"), read("shared/ai3/buts.lua")

local function load_mod(name, src, path)
  local fn, err = load(src, "=" .. path, "t")
  assert(fn, err)
  package.loaded[name] = fn()
  return package.loaded[name]
end
local function load_all(br_src, buts_src)
  local Br = load_mod("shared.ai3.bras", br_src or BR_SRC, "bras")
  package.loaded["shared.ai3.buts"] = nil
  local B = load_mod("shared.ai3.buts", buts_src or BUTS_SRC, "buts")
  return Br, B
end

local IRON = T.outposts.iron.product

local function suite(Br, B)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m) if c then pass = pass + 1 else fail = fail + 1; msgs[#msgs + 1] = m end end
  local function sit(cap_iron, stock)
    return { key = R.FALLBACK_KEY, workers = 14, tick = 0, cap = { iron = cap_iron, coal = 3, copper = 2, stone = 2 },
      stock = { [IRON] = stock or 0 }, need = {} }
  end
  local function state(n, short, tg_iron)
    return { targets = { iron = tg_iron or 5, coal = 3, copper = 2, stone = 2 }, iron2_set = true,
      short = { [IRON] = short or 568 }, short_n = { [IRON] = n } }
  end
  check(Br.cap_max(14, 5) == 5, "14 PNJ : le plancher de 5 capacites (cas mesure)")
  -- 1. manque durable : une capacite de plus, compteur remis a zero
  local st = state(60)
  B.targets(sit(4.3), st)
  check(st.targets.iron == 6 and st.short_n[IRON] == 0, "manque durable (60 pensees) : cible 5 -> 6, compteur remis a zero (" .. tostring(st.targets.iron) .. ")")
  -- 2. un cran avant : rien
  local st2 = state(59)
  B.targets(sit(4.3), st2)
  check(st2.targets.iron == 5, "59 pensees de manque : la borne tient")
  -- 3. la capacite deja posee doit suivre (75 %)
  local st3 = state(60)
  B.targets(sit(3.0), st3)
  check(st3.targets.iron == 5, "capacite posee 3,0 < 75 % de 5 : pas de cible de plus")
  -- 4. produit sature : rien
  local st4 = state(60)
  B.targets(sit(4.3, 100000), st4)
  check(st4.targets.iron == 5, "produit sature : pas de cible de plus")
  -- 5. rythme : une capacite par tranche de 60 pensees, pas plus
  local st5 = state(60)
  B.targets(sit(4.3), st5)
  B.targets(sit(4.3), st5)
  check(st5.targets.iron == 6, "deux pensees de suite : une seule capacite de plus")
  -- 6. la suite : de 60 en 60 pensees tant que la capacite suit et que le manque dure (aucun plafond neuf, pas de saut)
  local st6 = state(60)
  local cap = 4.3
  for i = 1, 5 do
    B.targets(sit(cap), st6)
    cap = st6.targets.iron * 0.9
    st6.short_n[IRON] = 60
  end
  check(st6.targets.iron == 10, "5 tranches : 5 -> 10 (" .. tostring(st6.targets.iron) .. ")")
  -- 7. sans manque durable, le comportement d'avant : cible tenue au plancher
  local st7 = state(10, 568)
  B.targets(sit(4.3), st7)
  check(st7.targets.iron == 5, "10 pensees de manque : la borne d'avant tient")
  -- 8. une autre ressource n'en profite pas sans son propre manque
  local st8 = state(60)
  st8.targets.coal = 3
  B.targets(sit(4.3), st8)
  check(st8.targets.coal == 3 and st8.targets.copper == 2 and st8.targets.stone == 2, "seule la ressource en manque durable grandit")
  -- 8 bis. sous la borne, la croissance d'avant exige toujours GROW_THINKS pensees de manque
  local st8b = state(3, 568, 3)
  B.targets(sit(3.0), st8b)
  check(st8b.targets.iron == 3, "3 pensees de manque sous la borne : pas de cible de plus")
  check(Br.LONG_SHORT == 60, "seuil du manque durable : 60 pensees (5 min)")
  -- 9. determinisme
  local a, b = state(60), state(60)
  B.targets(sit(4.3), a); B.targets(sit(4.3), b)
  check(a.targets.iron == b.targets.iron, "meme entree, meme sortie")
  return pass, fail, msgs
end

local Br0, B0 = load_all()
local pass, fail, msgs = suite(Br0, B0)
for _, m in ipairs(msgs) do print("  ECHEC : " .. m) end

-- chaine statique
local function has(s, t) return s:find(t, 1, true) ~= nil end
local function chk(c, m) if c then pass = pass + 1 else fail = fail + 1; print("  ECHEC : " .. m) end end
chk(has(BUTS_SRC, "(tg[kind] < grow_max or Br.beyond(n))"), "buts.lua : la borne lit Br.beyond")
chk(has(BR_SRC, "function Br.beyond(short_n)"), "bras.lua : Br.beyond")

-- mutants
local mutants, caught = 0, 0
local function mutant(label, br_src, buts_src, edit)
  mutants = mutants + 1
  local Br, B = load_all(br_src, buts_src)
  if edit then edit(Br, B) end
  local _, f = suite(Br, B)
  if f > 0 then caught = caught + 1 else print("  MUTANT SURVIVANT : " .. label) end
end
local function sub(src, old, new) local i, j = src:find(old, 1, true); assert(i, "mutant : motif absent " .. old); return src:sub(1, i - 1) .. new .. src:sub(j + 1) end
mutant("seuil a 1", nil, nil, function(Br) Br.LONG_SHORT = 1 end)
mutant("seuil jamais", nil, nil, function(Br) Br.LONG_SHORT = 1e9 end)
mutant("beyond toujours vrai", nil, nil, function(Br) Br.beyond = function() return true end end)
mutant("beyond toujours faux", nil, nil, function(Br) Br.beyond = function() return false end end)
mutant("borne retiree", nil, sub(BUTS_SRC, "(tg[kind] < grow_max or Br.beyond(n))", "true"))
mutant("capacite posee ignoree", nil, sub(BUTS_SRC, "and (s.cap[kind] or 0) >= tg[kind] * 0.75 then\n      tg[kind] = tg[kind] + 1\n      st.short_n[product] = 0", "then\n      tg[kind] = tg[kind] + 1\n      st.short_n[product] = 0"))
mutant("saturation ignoree", nil, sub(BUTS_SRC, "short >= grow_short and not B.saturated(s, product) and (tg", "short >= grow_short and (tg"))
mutant("compteur non remis a zero", nil, sub(BUTS_SRC, "tg[kind] = tg[kind] + 1\n      st.short_n[product] = 0\n    end\n  end\n  -- Lot IA-G", "tg[kind] = tg[kind] + 1\n    end\n  end\n  -- Lot IA-G"))
mutant("seuil du manque durable ignore", nil, sub(BUTS_SRC, "if n >= B.GROW_THINKS and short >= grow_short", "if short >= grow_short"))

print(string.format("[PLATEAU2] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refuses", pass, fail, caught, mutants))
os.exit((fail == 0 and caught == mutants) and 0 or 1)
