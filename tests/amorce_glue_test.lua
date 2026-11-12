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
    6. mutants refusés ;
    7. lot VIDEO-COUVERTURE 5 : cycles de la décision -> graine (C5.1), 1re production écrite [FO-CONFIRMATION] (C5.2), ordre refusé par
       l'exécutant occupé re-émis à l'identique après Cf.RETRY (C5.3), crochets de capitalisation.lua.
]]
package.path = "./?.lua;" .. package.path
local Ml = require("shared.ai3.mall")
local Am = require("shared.ai3.amorce")
local Cf = require("shared.ai3.confirmation")
local AmRt0 = require("script.ai3.amorce_rt")
local LOGS = {}
log = function(s) LOGS[#LOGS + 1] = s end -- le `log` du moteur, pour la colle
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
  ck(#lines == 2 and lines[1]:find("[FO-AMORCE] player", 1, true) and lines[1]:find("3 fourni", 1, true), "ligne [FO-AMORCE]")
  ck(lines[2] and lines[2]:find("[FO-CONFIRMATION] player", 1, true) and lines[2]:find("101", 1, true) and lines[2]:find("1re fois", 1, true),
    "ligne [FO-CONFIRMATION] : la 1re production de l'unite 101 leve la retenue du module suivant (" .. tostring(lines[2]) .. ")")
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

-- 7. lot VIDEO-COUVERTURE 5
local function battery7(AmRt, verbose)
  local fails = 0
  local function ck(c, msg)
    if not c then fails = fails + 1 if verbose then print("  ECHEC : " .. msg) end end
    if verbose then check(c, msg) end
  end
  local RETRY = Cf.RETRY
  -- C5.1 : les cycles de la décision deviennent la graine du mall, bornée, avec sa cause
  local f = team()
  f.team.capi = {}
  local cs = f.team.capi
  cs.st = { bank = 500 }
  cs.open = {}
  local res = { orders = {}, refus = {}, rang_cycles = { seed = { cata = { { "cata", 40 }, { "autre", 5 } } }, cyc = { cata = "cata" } } }
  local out = AmRt.after_decision(f, cs, res, 100, 1.0)
  ck(out == res.orders and #out == 0, "after_decision : sans ordre mis de cote, la liste des ordres est rendue telle quelle")
  ck(type(cs.cyc) == "table" and #cs.cyc == 2 and cs.cyc[2].item == "cata", "C5.1 : les cycles de la decision sont publies (cs.cyc, liste triee)")
  local ml = f.team.ia3.mall
  local seeded = AmRt.seed(f, ml, 120, BOOK, function(it) return it == "autre" and 3 or 0 end)
  local need = {}
  for _, s in ipairs(seeded) do need[s.item] = s end
  ck(need.cata and need.cata.need == 80 and need.autre and need.autre.need == 7, "C5.1 : graine du cycle (80 cata, 10 - 3 autre) en plus du materiel")
  ck(need.cata and tostring(need.cata.cause):find("cycle cata", 1, true), "C5.1 : la cause du cycle est ecrite")
  ck(ml.want.cata and ml.want.cata.src == Am.SRC, "C5.1 : la graine du cycle entre au mall")
  local said = 0
  for _, l in ipairs(LOGS) do if l:find("[FO-AMORCE] player : graine de cycle cata : 80 a fabriquer ; cause : cycle cata", 1, true) then said = said + 1 end end
  ck(said == 1, "C5.1 : la graine du cycle et sa cause sont ecrites au journal (" .. said .. ")")
  AmRt.seed(f, ml, 180, BOOK, function(it) return it == "autre" and 3 or 0 end)
  said = 0
  for _, l in ipairs(LOGS) do if l:find("graine de cycle cata", 1, true) then said = said + 1 end end
  ck(said == 1, "C5.1 : la meme graine n'est pas reecrite a chaque pensee")
  AmRt.after_decision(f, cs, { orders = {}, refus = {}, rang_cycles = { seed = {}, cyc = {} } }, 200, 1.0)
  ck(cs.cyc == nil, "C5.1 : sans cycle, cs.cyc est efface (le global reste celui d'avant)")
  do -- objet de cycle sans recette a la main : refus ecrit une fois
    local f3 = team()
    f3.team.capi = { cyc = Am.flatten({ seed = { m = { { "brut", 10 } } }, cyc = { m = "m" } }) }
    LOGS = {}
    AmRt.seed(f3, f3.team.ia3.mall, 120, { recipe_for = function(_, it) return it ~= "brut" and { name = it } or nil end }, function() return 0 end)
    AmRt.seed(f3, f3.team.ia3.mall, 180, { recipe_for = function(_, it) return it ~= "brut" and { name = it } or nil end }, function() return 0 end)
    ck(#LOGS == 1 and LOGS[1]:find("cycle brut non seme (20 voulus) : aucune recette a la main ; cause : cycle m", 1, true),
      "C5.1 : cycle non fabricable a la main : refus ecrit une seule fois (" .. #LOGS .. ")")
  end
  local f2 = team()
  f2.team.capi = {}
  local sd = AmRt.seed(f2, f2.team.ia3.mall, 120, BOOK, function() return 0 end)
  local only = {}
  for _, s in ipairs(sd) do only[s.item] = true end
  ck(not only.cata and not only.autre, "C5.1 : sans cycle, aucune graine de cycle")

  -- C5.3 : l'ordre refusé par l'exécutant occupé
  local plan = { key = "chaine:x", kind = "chaine", item = "x", n = 3, cost_m = 100, recipe = "r", items = { { "y", 2 } } }
  local busy = "executant : plan directeur occupe (2 module(s) ouvert(s), au plus 2)"
  local csd = { st = { bank = 500 }, open = {} }
  ck(AmRt.defer(csd, plan, "budget : 12 MU > 4", 0) == false and csd.cfo == nil, "C5.3 : un refus qui n'est pas l'executant occupe n'est pas mis de cote")
  ck(AmRt.defer(csd, { key = "equiper:m", kind = "equiper", item = "m" }, busy, 0) == false, "C5.3 : seuls les ordres de module sont mis de cote")
  ck(AmRt.defer(csd, plan, busy, 0) == true, "C5.3 : un ordre de module refuse par l'executant occupe est mis de cote")
  local fx = { key = "player" }
  local o1 = AmRt.after_decision(fx, csd, { orders = {}, refus = {} }, RETRY - 1, 4.9)
  ck(#o1 == 0, "C5.3 : rien avant Cf.RETRY")
  LOGS = {}
  local o2 = AmRt.after_decision(fx, csd, { orders = {}, refus = {} }, RETRY, 5.0)
  ck(#o2 == 1 and o2[1].key == "chaine:x" and o2[1].n == 3 and o2[1].cost_m == 100 and o2[1].items[1][1] == "y" and o2[1].relances == 1,
    "C5.3 : apres Cf.RETRY, le MEME plan est re-emis en tete (relances 1)")
  ck(csd.st.bank == 400, "C5.3 : l'epargne paie de nouveau le plan (500 - 100)")
  ck(#LOGS == 1 and LOGS[1]:find("relance du MEME plan chaine:x", 1, true), "C5.3 : la relance est ecrite (" .. tostring(LOGS[1]) .. ")")
  local o3 = AmRt.after_decision(fx, csd, { orders = {}, refus = {} }, RETRY + 3600, 6.0)
  ck(#o3 == 0, "C5.3 : une seule relance par mise de cote")
  -- refusé de nouveau : mis de côté de nouveau avec relances 1, puis une 2e relance, puis laissé à la décision
  ck(AmRt.defer(csd, o2[1], busy, RETRY + 3600) == true, "C5.3 : refuse de nouveau : mis de cote encore (relances 1 < 2)")
  local o4 = AmRt.after_decision(fx, csd, { orders = {}, refus = {} }, 2 * RETRY + 3600, 11.0)
  ck(#o4 == 1 and o4[1].relances == 2, "C5.3 : 2e relance du meme plan")
  ck(AmRt.defer(csd, o4[1], busy, 3 * RETRY) == false, "C5.3 : au-dela de RELANCES_MAX, l'ordre est laisse a la decision")
  -- le plan n'est pas re-émis quand il n'a plus d'actualité
  local function deferred()
    local c = { st = { bank = 500 }, open = {} }
    AmRt.defer(c, plan, busy, 0)
    return c
  end
  local c1 = deferred()
  local x1 = AmRt.after_decision(fx, c1, { orders = { { key = "chaine:x", kind = "chaine", n = 5, cost_m = 10 } }, refus = {} }, RETRY, 5.0)
  ck(#x1 == 1 and x1[1].n == 5 and c1.st.bank == 500 and c1.cfo.ids["ordre:chaine:x"] == nil,
    "C5.3 : la decision a refait l'ordre d'elle-meme : le sien est garde, rien n'est paye de plus, la mise de cote est levee")
  local c2 = deferred()
  c2.open = { { key = "chaine:x" } }
  ck(#AmRt.after_decision(fx, c2, { orders = {}, refus = {} }, RETRY, 5.0) == 0 and c2.st.bank == 500, "C5.3 : un ordre de meme cle est deja ouvert : rien")
  local c3 = deferred()
  ck(#AmRt.after_decision(fx, c3, { orders = {}, refus = { { key = "chaine:x", why = "danger" } } }, RETRY, 5.0) == 0 and c3.st.bank == 500,
    "C5.3 : une AUTRE raison (danger) refuse le plan maintenant : jamais re-emis")
  ck(#AmRt.after_decision(fx, deferred(), { orders = {}, refus = { { key = "chaine:x", why = busy } } }, RETRY, 5.0) == 1,
    "C5.3 : refuse encore pour la seule raison de l'executant occupe : re-emis")
  local c4 = deferred()
  c4.st.bank = 50
  ck(#AmRt.after_decision(fx, c4, { orders = {}, refus = {} }, RETRY, 5.0) == 0 and c4.st.bank == 50, "C5.3 : l'epargne ne paie plus le plan : rien n'est re-emis ni debite")
  LOGS = {}
  ck(#AmRt.after_decision(fx, c4, { orders = {}, refus = {} }, Cf.STALL, 10.0) == 0 and #LOGS == 1 and LOGS[1]:find("abandonne", 1, true),
    "C5.3 : abandon ecrit a Cf.STALL (" .. tostring(LOGS[1]) .. ")")
  ck(next(c4.cfo.ids) == nil, "C5.3 : plus rien en suspens apres l'abandon")
  local function has_fn(t, seen)
    seen = seen or {}
    if seen[t] then return false end
    seen[t] = true
    for _, v in pairs(t) do
      if type(v) == "function" or (type(v) == "table" and has_fn(v, seen)) then return true end
    end
    return false
  end
  local c5 = deferred()
  ck(not has_fn(c5) and not has_fn(cs), "C5.3 : etat sans fonction (global)")
  return fails
end
-- 8. remise directe (C3 de DIAG_CONSO)
local function battery8(AmRt, verbose)
  local fails = 0
  local function ck(c, msg)
    if not c then fails = fails + 1 if verbose then print("  ECHEC : " .. msg) end end
    if verbose then check(c, msg) end
  end
  local function world()
    -- lot CHARBON-CENTRALE : le projet 3, ROUVERT pour reconstruction (reopened, Sw.rebuilding) et deja en chantier (REBUILD-RAPIDE), place
    -- APRES la reserve 94 dans la file ; le 7, rouvert puis refini (finished apres reopened_tick), n'attend rien
    local f = { key = "player", team = { delivered = {} }, build = { order = { 94, 95, 60, 3, 7 }, projects = {
      [94] = { id = 94, state = "reserve", stock = { asm2 = 1 }, missing = { { "asm2", 3 }, { "belt", 23 } } },
      [95] = { id = 95, state = "reserve", stock = {}, missing = { { "asm2", 4 } }, reserve_next = 99999 },
      [60] = { id = 60, state = "chantier", stock = {}, missing = { { "asm2", 9 } } },
      [3] = { id = 3, state = "chantier", reopened = 1, reopened_tick = 121000, stock = {}, missing = { { "belt", 30 } } },
      [7] = { id = 7, state = "chantier", reopened = 1, reopened_tick = 1000, finished = 2000, stock = {}, missing = { { "belt", 4 } } },
    } } }
    local inv = { has = { asm2 = 6, belt = 40 } }
    function inv.remove(t) inv.has[t.name] = (inv.has[t.name] or 0) - t.count; return t.count end
    return f, inv
  end
  local f, inv = world()
  LOGS = {}
  local took = AmRt.deliver(f, inv, "asm2", 6)
  local p94, p95, p60 = f.build.projects[94], f.build.projects[95], f.build.projects[60]
  ck(took == 6 and inv.has.asm2 == 0, "remise directe : 6 assembleurs 2 retires de l'inventaire du PNJ (" .. tostring(took) .. ")")
  ck(p94.stock.asm2 == 4 and p95.stock.asm2 == 3, "remise directe : p.stock du module 94 (1 + 3) et du 95 (3)")
  ck(#p94.missing == 1 and p94.missing[1][1] == "belt" and p94.missing[1][2] == 23, "remise directe : le manque du module 94 ne garde que les courroies")
  ck(p95.missing[1][1] == "asm2" and p95.missing[1][2] == 1, "remise directe : le module 95 attend encore 1 assembleur 2")
  ck(p95.reserve_next == nil, "remise directe : la reserve est relue au plus tot (reserve_next efface)")
  ck(p60.stock.asm2 == nil and p60.missing[1][2] == 9, "remise directe : un projet en chantier n'est pas touche")
  ck(f.team.delivered.asm2 == 6, "remise directe : comptee comme livree au QG (f.team.delivered)")
  ck(#LOGS == 2 and LOGS[1]:find("[FO-AMORCE] player : remise directe : 3 asm2 au module 94", 1, true), "remise directe : une ligne [FO-AMORCE] par module (" .. #LOGS .. ")")
  LOGS = {}
  local p3, p7 = f.build.projects[3], f.build.projects[7]
  ck(AmRt.deliver(f, inv, "belt", 100) == 53 and f.build.projects[94].missing and #f.build.projects[94].missing == 0, "remise directe : les courroies, au plus le manque (30 au projet 3 rouvert + 23 au module 94 sur 100)")
  ck(p3.stock.belt == 30 and #p3.missing == 0, "remise directe : le projet 3 rouvert en chantier recoit ses 30 tapis dans p.stock (pris par le PNJ a sa prise, Build.take_reserved)")
  ck(p7.stock.belt == nil and p7.missing[1][2] == 4, "remise directe : un projet rouvert puis refini (Sw.rebuilding faux) n'attend rien")
  ck(#LOGS == 2 and LOGS[1]:find("remise directe : 30 belt au module 3", 1, true) and LOGS[1]:find("reconstruction", 1, true), "remise directe : ligne [FO-AMORCE] du projet rouvert d'abord (" .. tostring(LOGS[1]) .. ")")
  local f2, inv2 = world()
  ck(AmRt.deliver(f2, inv2, "inconnu", 5) == 0 and inv2.has.asm2 == 6, "remise directe : objet que personne n'attend : rien retire")
  ck(AmRt.deliver({ key = "x", team = {} }, inv2, "asm2", 5) == 0, "remise directe : equipe sans plan directeur : rien")
  ck(AmRt.deliver(f2, inv2, "asm2", 0) == 0 and AmRt.deliver(f2, inv2, "asm2", nil) == 0, "remise directe : quantite nulle ou absente : rien")
  local f3, inv3 = world()
  inv3.remove = function() return 0 end -- l'inventaire ne rend rien (objet deja parti) : aucune remise inventee
  ck(AmRt.deliver(f3, inv3, "asm2", 6) == 0 and f3.build.projects[94].stock.asm2 == 1, "remise directe : rien retire de l'inventaire = rien donne au module")
  return fails
end
print("[AMORCE-GLUE] 8. remise directe")
check(battery8(AmRt0, true) == 0, "batterie 8 sans echec")

print("[AMORCE-GLUE] 7. cycles, ordre mis de cote")
check(battery7(AmRt0, true) == 0, "batterie 7 sans echec")

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

do -- crochets de capitalisation.lua du lot VIDEO-COUVERTURE 5 : la décision, puis les portes L6, puis la boucle d'envoi
  local h1 = capi:find("res.orders = AmRt.after_decision(f, cs, res, tick, minutes(f, tick))", 1, true)
  local h2 = capi:find("local gate_why = Capi.portes(f, cs, res, view, tick)", 1, true)
  local h3 = capi:find("AmRt.defer(cs, o, why, tick)", 1, true)
  local h4 = capi:find("cs.refused[o.key] = tick", 1, true)
  check(h1 and h2 and h1 < h2, "capitalisation.lua : after_decision AVANT les portes L6 (elles voient les ordres re-emis)")
  check(h3 and h4 and h4 < h3 and h3 - h4 < 200, "capitalisation.lua : AmRt.defer dans la branche des ordres refuses (apres cs.refused)")
  local _, n = capi:gsub("AmRt%.after_decision", "")
  local _, m = capi:gsub("AmRt%.defer", "")
  check(n == 1 and m == 1, "capitalisation.lua : un seul appel de chaque crochet (" .. n .. ", " .. m .. ")")
end
do -- crochet du depot des PNJ (C3) : la remise directe AVANT le coffre
  local wk = read("script/team/worker.lua")
  local d1 = wk:find("AmRt.deliver(f, inv, name, n, kits and kits[name])", 1, true) -- (lot KITS-VOLES : les kits portes)
  local d2 = wk:find("local moved = Stock.insert(f, name, n", 1, true) -- (intégrateur : STOCKAGE-VITAL y ajoute DEPOSIT_OPTS)
  local d0 = wk:find("local function deposit_inventory", 1, true)
  -- Les deux appels doivent rester dans deposit_inventory, deliver AVANT tout le reste. La limite d'avant, « moins de 400 octets entre
  -- les deux », a sauté quand le lot STOCK-QG a posé entre eux le retrait de la poche au plafond de rapatriement (915 octets) : elle
  -- mesurait la proximité, pas l'ordre. L'ordre est conservé, et deliver doit aussi précéder ce retrait (un module en réserve qui attend
  -- un brut le reçoit même quand le stock n'en veut plus).
  local dend = d0 and wk:find("\nend\n", d0, true)
  local d3 = wk:find("Stock.cap_room(f, name)", 1, true)
  check(d0 and d1 and d2 and dend and d0 < d1 and d1 < d2 and d2 < dend and (not d3 or (d1 < d3 and d3 < dend)),
    "worker.lua : deposit_inventory offre d'abord l'objet aux modules en reserve (AmRt.deliver), puis au coffre")
  local _, k = wk:gsub("AmRt%.deliver", "")
  check(k == 1, "worker.lua : un seul crochet (" .. k .. ")")
end

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
  local ok, fl = pcall(function() return battery(AmRt0, false) + battery7(AmRt0, false) + battery8(AmRt0, false) end)
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

-- mutants du lot VIDEO-COUVERTURE 5 (batterie 7)
mutant("ordre refuse jamais mis de cote (C5.3)", function(M) M.defer = function() return false end end)
mutant("toute raison de refus mise de cote, pas seulement l'executant occupe (C5.3)", function(M)
  local base = M.defer
  M.defer = function(cs, o, why, tick) return base(cs, o, "plan directeur occupe", tick) end
end)
mutant("relances sans limite (C5.3)", function(M)
  local base = M.defer
  M.defer = function(cs, o, why, tick)
    local c = {}
    for k, v in pairs(o) do c[k] = v end
    c.relances = nil
    return base(cs, c, why, tick)
  end
end)
mutant("plan refait par la decision aussi re-emis (doublon, C5.3)", function(M)
  local base = M.after_decision
  M.after_decision = function(f, cs, res, tick, mn)
    local fresh = res.orders
    res.orders = {}
    local out = base(f, cs, res, tick, mn)
    res.orders = fresh
    local o2 = {}
    for _, o in ipairs(out) do o2[#o2 + 1] = o end
    for _, o in ipairs(fresh) do o2[#o2 + 1] = o end
    return o2
  end
end)
mutant("relance qui ne debite pas l'epargne (C5.3)", function(M)
  local base = M.after_decision
  M.after_decision = function(f, cs, res, tick, mn)
    local b = cs.st and cs.st.bank
    local out = base(f, cs, res, tick, mn)
    if cs.st then cs.st.bank = b end
    return out
  end
end)
mutant("relance malgre une autre raison de refus (C5.3)", function(M)
  local base = M.after_decision
  M.after_decision = function(f, cs, res, tick, mn) return base(f, cs, { orders = res.orders, refus = {}, rang_cycles = res.rang_cycles }, tick, mn) end
end)
mutant("cycles de la decision non publies (C5.1)", function(M)
  local base = M.after_decision
  M.after_decision = function(f, cs, res, tick, mn)
    local out = base(f, cs, res, tick, mn)
    cs.cyc = nil
    return out
  end
end)
mutant("graine qui ignore les cycles publies (C5.1)", function(M)
  local base = M.seed
  M.seed = function(f, ml, tick, book, count)
    local cap = f.team and f.team.capi
    local saved = cap and cap.cyc
    if cap then cap.cyc = nil end
    local r = base(f, ml, tick, book, count)
    if cap then cap.cyc = saved end
    return r
  end
end)
mutant("1re production non ecrite (C5.2)", function(M)
  local base = M.lines
  M.lines = function(f, ml, retraits, mn)
    local r2 = {}
    for _, x in ipairs(retraits or {}) do r2[#r2 + 1] = x end
    return base(f, ml, r2, mn)
  end
end)

mutant("remise directe jamais faite (C3)", function(M) M.deliver = function() return 0 end end)
mutant("remise directe sans retirer l'objet du PNJ (C3, duplication)", function(M)
  local base = M.deliver
  M.deliver = function(f, inv, name, n)
    local fake = { remove = function(t) return t.count end }
    return base(f, fake, name, n)
  end
end)
mutant("remise directe a un projet qui n'est pas en reserve (C3)", function(M)
  local base = M.deliver
  M.deliver = function(f, inv, name, n)
    for _, p in pairs(f.build.projects) do p.state = "reserve" end
    return base(f, inv, name, n)
  end
end)
mutant("remise directe sans mettre a jour le manque (C3)", function(M)
  local base = M.deliver
  M.deliver = function(f, inv, name, n)
    local saved = {}
    for id, p in pairs(f.build.projects) do saved[id] = p.missing end
    local r = base(f, inv, name, n)
    for id, p in pairs(f.build.projects) do p.missing = saved[id] end
    return r
  end
end)
mutant("remise directe non comptee comme livree (C3)", function(M)
  local base = M.deliver
  M.deliver = function(f, inv, name, n)
    local r = base(f, inv, name, n)
    f.team.delivered[name] = nil
    return r
  end
end)

print(string.format("[AMORCE-GLUE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
