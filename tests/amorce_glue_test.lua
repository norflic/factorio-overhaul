--[[
  Lot VIDEO L7, branchement : banc HORS JEU de la colle script/ai3/amorce_rt.lua avec la VRAIE confirmation de L5
  (shared/ai3/confirmation.lua, Cf.step) et la vraie règle de l'amorce (shared/ai3/amorce.lua) sur le mall (shared/ai3/mall.lua).
  Lancement, depuis la racine du mod : lua5.2 tests/amorce_glue_test.lua
    1. graine : liste de matériel des prochains projets du plan directeur (pièces non posées moins p.stock, moins le stock BRUT) ;
    2. LE PIÈGE DE LA FORCE PARTAGÉE : le joueur fabrique à la main AVANT toute machine (les statistiques de la force montent) ;
       la main des PNJ n'est PAS retirée ; le repli par les statistiques de la force, lui, la retirerait (témoin du piège) ;
    3. retrait à la 1re production d'une MACHINE (confirmed_now de L5), compteur d'amorce = la main des PNJ d'avant ;
    4. verrou levé quand l'unité est perdue (plus aucun producteur) ;
    5. câblage (source) : capitalisation.lua après conf_log, industrie.lua avant Ml.sources, cerveau.lua (Am.filter_crafts) ;
    6. mutants refusés.
]]
package.path = "./?.lua;" .. package.path
local Ml = require("shared.ai3.mall")
local Am = require("shared.ai3.amorce")
local Cf = require("shared.ai3.confirmation")
local AmRt0 = require("script.ai3.amorce_rt")
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end
local BOOK = { recipe_for = function(_, it) return { name = it } end }
local BRAS, TAPIS = "bras", "tapis" -- données du banc (la colle n'en nomme aucun)

local function team()
  local f = { key = "player", force = "player", is_player = true, team = { ia3 = { mall = Ml.new() }, ia3e = { hand_all = {} } },
    build = { order = { 1, 2, 3 }, projects = {
      [1] = { id = 1, state = "chantier", stock = { [BRAS] = 1 },
        ents = { { item = BRAS }, { item = BRAS }, { item = BRAS, built = true }, { item = TAPIS }, { item = TAPIS } } },
      [2] = { id = 2, state = "fini", stock = {}, ents = { { item = BRAS } } },
      [3] = { id = 3, state = "attente", stock = {}, ents = {} },
    } } }
  return f
end

local function battery(AmRt, verbose)
  local fails = 0
  local function ck(c, msg)
    if not c then fails = fails + 1 if verbose then print("  ECHEC : " .. msg) end end
    if verbose then check(c, msg) end
  end
  -- 1. graine
  local f = team()
  local ml = f.team.ia3.mall
  local stock = { [TAPIS] = 1 }
  local seeded = AmRt.seed(f, ml, 60, BOOK, function(it) return stock[it] or 0 end)
  local need = {}
  for _, s in ipairs(seeded) do need[s.item] = s.need end
  ck(need[BRAS] == 1, "graine : 2 bras non poses moins 1 deja pris par le projet (" .. tostring(need[BRAS]) .. ")")
  ck(need[TAPIS] == 1, "graine : 2 tapis moins 1 au stock brut (" .. tostring(need[TAPIS]) .. ")")
  ck(ml.want[BRAS] and ml.want[BRAS].src == Am.SRC, "la graine entre au mall (Ml.want, source amorce)")
  local projets = AmRt.projects(f)
  ck(#projets == 1 and projets[1].id == 1, "projet fini et projet sans piece ecartes")

  -- 2. le piège : le joueur fabrique à la main, aucune machine n'a produit
  local cs = { cf = Cf.new() }
  Cf.engage(cs.cf, { id = 101, item = BRAS, base = 0 }, 0)                  -- l'assembleur du mall, posé, rien produit
  f.team.ia3e.hand_all[BRAS] = 2
  local cfr = Cf.step(cs.cf, { [101] = { count = 0 } }, 3600, { complete = true })
  AmRt.observe(f, cs, ml, cfr, cs.cf, 3600)                                   -- 1er relevé : base des compteurs de la main
  f.team.ia3e.hand_all[BRAS] = 5                                              -- 3 bras de plus faits à la main par les PNJ
  local force_stats = { [BRAS] = { made = 3 + 7, hand = 3 } }                 -- + 7 faits à la main par le JOUEUR (statistiques)
  cfr = Cf.step(cs.cf, { [101] = { count = 0 } }, 7200, { complete = true })
  local r = AmRt.observe(f, cs, ml, cfr, cs.cf, 7200)
  ck(#r == 0 and Am.hand_allowed(ml, BRAS, 4, Ml), "PIEGE : le joueur fabrique a la main avant toute machine, la main des PNJ n'est PAS retiree")
  ck(Am.supplied(ml, BRAS) == 3, "compteur d'amorce : 3 bras des PNJ (pas ceux du joueur) (" .. Am.supplied(ml, BRAS) .. ")")
  do -- témoin : le repli par les statistiques de la force tombe dans le piège
    local ml2 = Ml.new()
    Am.seed(ml2, 0, projets, {}, BOOK, Ml)
    Am.observe(ml2, 7200, force_stats, nil)
    ck(not Am.hand_allowed(ml2, BRAS, 4, Ml), "temoin : par les statistiques de la force, la main serait retiree (le piege existe)")
  end
  -- 3. 1re production d'une machine
  f.team.ia3e.hand_all[BRAS] = 6
  cfr = Cf.step(cs.cf, { [101] = { count = 2 } }, 10800, { complete = true })
  ck(#cfr.confirmed_now == 1, "L5 confirme l'assembleur a sa 1re production")
  r = AmRt.observe(f, cs, ml, cfr, cs.cf, 10800)
  ck(#r == 1 and r[1].item == BRAS and r[1].hand == 3, "retrait a la 1re production de la machine ; la main de ce releve n'entre pas au compteur")
  ck(not Am.hand_allowed(ml, BRAS, 4, Ml) and Am.hand_allowed(ml, BRAS, 0, Ml), "main refusee apres, toujours permise a stock nul")
  local lines = AmRt.lines(f, ml, r, 3.0)
  ck(#lines == 1 and lines[1]:find("[FO-AMORCE] player", 1, true) and lines[1]:find("3 fourni", 1, true), "ligne [FO-AMORCE]")
  -- verrou tenu quand la machine s'arrête (aucune production à ce relevé)
  cfr = Cf.step(cs.cf, { [101] = { count = 2, cause = "sortie" } }, 14400, { complete = true })
  AmRt.observe(f, cs, ml, cfr, cs.cf, 14400)
  ck(not Am.hand_allowed(ml, BRAS, 4, Ml), "machine a l'arret, encore suivie : le retrait tient")
  -- 4. unité perdue : plus aucun producteur
  cfr = Cf.step(cs.cf, {}, 18000, { complete = true })
  AmRt.observe(f, cs, ml, cfr, cs.cf, 18000)
  ck(Am.hand_allowed(ml, BRAS, 4, Ml), "unite perdue : plus aucun producteur, la main revient")
  ck(Am.supplied(ml, BRAS) == 3, "compteur garde")
  ck(#AmRt.observe(f, cs, ml, nil, cs.cf, 21600) == 0, "sans confirmation (L5 eteinte) : aucun releve")
  return fails
end

print("[AMORCE-GLUE] 1-4. colle, confirmation de L5, regle")
check(battery(AmRt0, true) == 0, "batterie sans echec")

-- 5. câblage
print("[AMORCE-GLUE] 5. cablage")
local function read(p) local fh = assert(io.open(p, "rb")); local s = fh:read("*a"); fh:close(); return s end
local capi, ind, cer = read("script/ai3/capitalisation.lua"), read("script/ai3/industrie.lua"), read("shared/ai3/cerveau.lua")
local a = capi:find("conf_log(f, cs, cfr, tick)", 1, true)
local b = capi:find("AmRt.observe(f, cs, ml, cfr, cs.cf, tick)", 1, true)
check(a and b and b > a and b - a < 600, "capitalisation.lua : AmRt.observe juste apres conf_log, sur cfr de Cf.step")
check(not capi:find("AmRt.observe(f, cs, ml, cs.flows", 1, true), "capitalisation.lua : aucun releve de l'amorce sur cs.flows (statistiques de la force)")
local s1 = ind:find("AmRt.seed(f, ml, tick, book, function(it) return Stock.count(f, it) end)", 1, true)
local s2 = ind:find("local sources = Ml.sources(ml, tick)", 1, true)
check(s1 and s2 and s1 < s2, "industrie.lua : graine (stock brut) avant Ml.sources")
check(cer:find("Am.filter_crafts(st.mall, base.tasks", 1, true) and cer:find("Am.filter_crafts(st.mall, E.tasks", 1, true)
  and not cer:find("Ml.filter_crafts(st.mall", 1, true), "cerveau.lua : le filtre des fabrications garde le verrou (Am.filter_crafts)")

-- 6. mutants
print("[AMORCE-GLUE] 6. mutants")
local function mutant(name, patch)
  -- le module est patché EN PLACE (ses fonctions s'appellent entre elles par la table du module), puis rendu tel quel
  local saved = {}
  for k, v in pairs(AmRt0) do saved[k] = v end
  local M = {}
  for k, v in pairs(AmRt0) do M[k] = v end
  patch(M)
  for k, v in pairs(M) do AmRt0[k] = v end
  local ok, fl = pcall(battery, AmRt0, false)
  for k in pairs(M) do AmRt0[k] = saved[k] end
  check((not ok) or fl > 0, "mutant refuse : " .. name)
end
mutant("releve sur les statistiques de la force (le piege)", function(M)
  M.observe = function(f, cs, ml, cfr, book, tick)
    if not cfr then return {} end
    local ha = f.team.ia3e.hand_all
    local prev = cs.amorce_hand or {}
    local fl = {}
    for k, v in pairs(ha) do
      local d = v - (prev[k] or v)
      if d > 0 then fl[k] = { made = d + 7, hand = d } end -- + ce que le joueur fabrique
    end
    local now = {}
    for k, v in pairs(ha) do now[k] = v end
    cs.amorce_hand = now
    return Am.observe(ml, tick, fl, nil)
  end
end)
mutant("verrou jamais leve (alive ignore)", function(M)
  local base = M.observe
  M.observe = function(f, cs, ml, cfr, book, tick) return base(f, cs, ml, cfr, { list = { 101 }, ids = { [101] = { item = BRAS } } }, tick) end
end)
mutant("graine sur les pieces deja posees", function(M)
  M.projects = function(f)
    local out = {}
    for _, id in ipairs(f.build.order) do
      local p = f.build.projects[id]
      if p.state ~= "fini" then
        local bom = {}
        for _, e in ipairs(p.ents) do bom[e.item] = (bom[e.item] or 0) + 1 end
        if next(bom) then out[#out + 1] = { id = id, bom = bom } end
      end
    end
    return out
  end
end)
mutant("graine sur le stock libre au lieu du stock brut (le stock ignore)", function(M)
  local base = M.seed
  M.seed = function(f, ml, tick, book) return base(f, ml, tick, book, function() return 0 end) end
end)
mutant("la main du releve de la confirmation entre au compteur", function(M)
  local base = M.observe
  M.observe = function(f, cs, ml, cfr, book, tick)
    local r = base(f, cs, ml, cfr, book, tick)
    for _, x in ipairs(r) do ml.amorce.hand[x.item] = (ml.amorce.hand[x.item] or 0) + 1; x.hand = ml.amorce.hand[x.item] end
    return r
  end
end)

print(string.format("[AMORCE-GLUE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
