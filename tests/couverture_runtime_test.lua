--[[
  Lot COUVERTURE (8/11) : branchement dans le runtime de la capitalisation (script/ai3/capitalisation.lua : Capi.portes, Capi.say_couverture,
  Capi.slots, Capi.think_tail). Moteur simulé (tests/mock_engine.lua). Lancer depuis la racine du mod :
    lua5.2 tests/couverture_runtime_test.lua   -> [COUVERTURE-RT] BILAN : N OK, 0 ECHEC(S)
  §1 la couverture en boucle passe la porte du transport FERMÉE (le défaut mesuré en 0.6.64 : 15 couvrir sur 15 retenus) ; §2 produit saturé,
  gisement couvert, crise : retenue, avec sa cause au journal [FO-COUVERTURE] ; §3 journal : une ligne par changement ; §4 modules posés
  cumulés (Capi.slots) ; §5 compteur cumulé (Capi.think_tail) ; §6 câblage (lecture du source).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[COUVERTURE-RT] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end

M.new_world({ p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful" })
M.load_mod()
local W = M.world()
M.dispatch(W.on_init)
local Capi = package.loaded["script.ai3.capitalisation"]
check(Capi ~= nil and type(Capi.say_couverture) == "function" and type(Capi.portes) == "function", "Capi.portes et Capi.say_couverture chargent")

local function count_logs(tag)
  local n = 0
  for _, l in ipairs(W.logs or {}) do if l:find(tag, 1, true) then n = n + 1 end end
  return n
end
local function last_log(tag)
  local out
  for _, l in ipairs(W.logs or {}) do if l:find(tag, 1, true) then out = l end end
  return out
end
local couv = { key = "couvrir:iron-ore@1,2", kind = "couvrir", resource = "iron-ore", deposit = "1,2", n = 14 }
local chain = { key = "chaine:gun-turret", kind = "chaine", item = "gun-turret", n = 1 }
local function res_for(free) return { orders = { couv, chain }, coverage = { { id = "1,2", resource = "iron-ore", kappa = 400, free = free, open = true } } } end
-- 0 PNJ libre sur 8, 57 tâches libres : tendu (le cas mesuré chez Azure)
local TENDU = { workers = 8, workers_waiting = 0, backlog = 57 }
W.settings["fo-war-portes"] = true

-- §1 Porte fermée, produit non saturé, 11 places libres : le couvrir passe EN BOUCLE, la chaîne reste retenue.
local f1 = { key = "azure", team = { ia3 = { saturated = {} } } }
local c1 = { slots = { batis = 0, open_sites = 0 } }
Capi.portes(f1, c1, res_for(11), TENDU, 3600)
local w1 = Capi.portes(f1, c1, res_for(11), TENDU, 7200)
check(c1.portes and c1.portes.closed == true, "§1 porte du transport fermee (2 mesures tendues)")
check(w1 and w1[couv.key] == nil, "§1 porte fermee : le couvrir en boucle PASSE")
check(w1 and w1[chain.key] ~= nil and tostring(w1[chain.key]):find("transport sature", 1, true) ~= nil, "§1 la chaine reste retenue")
local lg = last_log("[FO-COUVERTURE]")
check(lg ~= nil and lg:find("EN BOUCLE", 1, true) ~= nil and lg:find("iron-plate non sature", 1, true) ~= nil and lg:find("11 place", 1, true) ~= nil,
  "§1 journal [FO-COUVERTURE] : passe en boucle, produit et places (" .. tostring(lg) .. ")")
check(count_logs("racine :") == 0, "§1 le journal des racines ne parle pas d'une boucle (pas de « manque » invente)")

-- §1b Les emplacements de chantier de la capitalisation (cs.slots.cap, Em.slots) sont le plancher de la porte des chantiers : 2 couvrir de front.
do
  local couv2 = { key = "couvrir:iron-ore@5,6", kind = "couvrir", resource = "iron-ore", deposit = "5,6", n = 14 }
  local function two() return { orders = { couv, couv2 }, coverage = { { id = "1,2", free = 11 }, { id = "5,6", free = 9 } } } end
  local fa = { key = "azure", team = { ia3 = { saturated = {} } } }
  local ca = { slots = { batis = 0, open_sites = 0, cap = 2 } }
  Capi.portes(fa, ca, two(), TENDU, 3600)
  local wa = Capi.portes(fa, ca, two(), TENDU, 7200)
  check(wa and wa[couv.key] == nil and wa[couv2.key] == nil, "§1b 2 emplacements, 0 module pose : deux couvrir en boucle de front")
  local fb = { key = "azure", team = { ia3 = { saturated = {} } } }
  local cb = { slots = { batis = 0, open_sites = 0, cap = 1 } }
  Capi.portes(fb, cb, two(), TENDU, 3600)
  local wb = Capi.portes(fb, cb, two(), TENDU, 7200)
  check(wb and wb[couv.key] == nil and wb[couv2.key] ~= nil and tostring(wb[couv2.key]):find("chantier", 1, true) ~= nil,
    "§1b 1 emplacement : le second est retenu par la porte des chantiers")
end

-- §2 Produit saturé : retenu, la cause au journal.
local f2 = { key = "azure", team = { ia3 = { saturated = { ["iron-plate"] = true } } } }
local c2 = { slots = { batis = 0, open_sites = 0 } }
Capi.portes(f2, c2, res_for(11), TENDU, 3600)
local w2 = Capi.portes(f2, c2, res_for(11), TENDU, 7200)
check(w2 and w2[couv.key] ~= nil and tostring(w2[couv.key]):find("transport sature", 1, true) ~= nil, "§2 produit sature : retenu par la porte fermee")
lg = last_log("[FO-COUVERTURE]")
check(lg and lg:find("RETENU", 1, true) and lg:find("sature", 1, true) and lg:find("plus de debouche", 1, true), "§2 journal : retenu, produit sature (" .. tostring(lg) .. ")")
-- gisement couvert (0 place)
local f3 = { key = "azure", team = { ia3 = { saturated = {} } } }
local c3 = { slots = { batis = 0, open_sites = 0 } }
Capi.portes(f3, c3, res_for(0), TENDU, 3600)
local w3 = Capi.portes(f3, c3, res_for(0), TENDU, 7200)
check(w3 and w3[couv.key] ~= nil, "§2 gisement couvert : retenu")
check((last_log("[FO-COUVERTURE]") or ""):find("sans place libre", 1, true) ~= nil, "§2 journal : gisement sans place libre")
-- crise (mode survie)
local f4 = { key = "azure", team = { ia3 = { saturated = {} } } }
local c4 = { slots = { batis = 0, open_sites = 0 } }
local VC = { workers = 8, workers_waiting = 0, backlog = 57, survie = true }
Capi.portes(f4, c4, res_for(11), VC, 3600)
local w4 = Capi.portes(f4, c4, res_for(11), VC, 7200)
check(w4 and w4[couv.key] ~= nil, "§2 crise : retenu")
check((last_log("[FO-COUVERTURE]") or ""):find("crise", 1, true) ~= nil, "§2 journal : crise")
-- état de l'équipe sans cerveau IA3 (f.team.ia3 absent) : aucune saturation connue, la règle reste applicable
local f5 = { key = "player", team = {} }
local c5 = { slots = { batis = 0, open_sites = 0 } }
Capi.portes(f5, c5, res_for(11), TENDU, 3600)
local w5 = Capi.portes(f5, c5, res_for(11), TENDU, 7200)
check(w5 and w5[couv.key] == nil, "§2 sans cerveau IA3 : aucune saturation connue, passe")

-- §3 Journal : une ligne par CHANGEMENT de verdict, pas une par décision.
local before = count_logs("[FO-COUVERTURE]")
Capi.portes(f1, c1, res_for(11), TENDU, 10800)
Capi.portes(f1, c1, res_for(11), TENDU, 14400)
check(count_logs("[FO-COUVERTURE]") == before, "§3 verdict inchange : aucune ligne de plus")
f1.team.ia3.saturated = { ["iron-plate"] = true }
Capi.portes(f1, c1, res_for(11), TENDU, 18000)
check(count_logs("[FO-COUVERTURE]") == before + 1, "§3 verdict change (produit sature) : une ligne")
check(type(c1.couv_sig) == "table", "§3 etat cs.couv_sig : table")
check(M.serialize(c1.couv_sig) ~= nil, "§3 etat serialisable")

-- §4 Capi.slots : modules posés = cumul + finis des ordres ouverts.
do
  local Auto = package.loaded["script.ai3.automatisation"]
  local STATES = { [1] = "fini", [3] = "chantier" }
  local orig = Auto.module
  Auto.module = function(_, id) local s = STATES[id] return s and { state = s, reason = "x" } or nil end
  local fs = { key = "f1", team = { ia3 = {} }, hq_pos = { x = 0, y = 0 } }
  local open = function() return { { key = "m1", exec = "module", mod_ids = { 1, 3 } } } end
  local ok1, s1 = pcall(Capi.slots, fs, { open = open(), batis_done = 30 }, {}, 3000, nil)
  local ok2, s2 = pcall(Capi.slots, fs, { open = open() }, {}, 3000, nil)
  local ok3, s3 = pcall(Capi.slots, fs, { open = open(), done = { { exec = "module", state = "fini" }, { exec = "champ", state = "fini" },
    { exec = "module", state = "echec" } } }, {}, 3000, nil)
  Auto.module = orig
  check(ok1 and s1 and s1.batis == 31 and s1.open_sites == 1, "§4 cumul 30 + 1 fini ouvert = 31 modules poses, 1 chantier ouvert (" ..
    tostring(ok1 and s1 and s1.batis) .. ", " .. tostring(ok1 and s1 and s1.open_sites) .. (ok1 and "" or (" ; " .. tostring(s1))) .. ")")
  check(ok2 and s2 and s2.batis == 1, "§4 sans compteur ni historique : comme avant (1)")
  check(ok3 and s3 and s3.batis == 3, "§4 sans compteur, amorce sur l'historique (module + champ finis) : 2 + 1 fini ouvert = 3 (" ..
    tostring(ok3 and s3 and s3.batis) .. ")")
end

-- §4b Les emplacements de chantier grandissent avec les chantiers finis (mesure du 8/11 : « plan directeur occupé (4 modules ouverts, 2 emplacements) »).
do
  local fs = { key = "f1", team = { ia3 = {} }, hq_pos = { x = 0, y = 0 } }
  local ok0, s0 = pcall(Capi.slots, fs, { open = {} }, {}, 3000, nil)
  local ok1, s1 = pcall(Capi.slots, fs, { open = {}, batis_done = 55 }, {}, 3000, nil)
  local ok2, s2 = pcall(Capi.slots, fs, { open = {}, batis_done = 5000 }, {}, 3000, nil)
  check(ok0 and ok1 and ok2 and s0.cap and s1.cap == s0.cap + 2, "§4b 55 chantiers finis : 2 emplacements de plus (" .. tostring(s0 and s0.cap) .. " -> " .. tostring(s1 and s1.cap) .. ")")
  check(ok2 and s2.cap <= 8 + 2, "§4b borne : Dm.SLOTS_HARD (8) plus le stock riche au plus (" .. tostring(s2 and s2.cap) .. ")")
end

-- §4c Saturation totale : l'ordre marqué saturation passe la porte du transport même produit saturé ; journal [FO-SATURATION].
do
  local fsa = { key = "azure", team = { ia3 = { saturated = { ["iron-plate"] = true } } } }
  local csa = { slots = { batis = 0, open_sites = 0, cap = 2 }, open = {} }
  local sat_order = { key = "couvrir:iron-ore@1,2", kind = "couvrir", resource = "iron-ore", deposit = "1,2", n = 14, saturation = true }
  local resa = function(order) return { orders = { order }, coverage = { { id = "1,2", resource = "iron-ore", kappa = 40, free = 200, open = true,
    tiles = 3000, covered = 120 } }, sat = {}, refus = {} } end
  Capi.portes(fsa, csa, resa(sat_order), TENDU, 3600)
  local wsa = Capi.portes(fsa, csa, resa(sat_order), TENDU, 7200)
  check(wsa and wsa[sat_order.key] == nil, "§4c produit sature + ordre de saturation : passe la porte du transport")
  local plain = { key = "couvrir:iron-ore@1,2", kind = "couvrir", resource = "iron-ore", deposit = "1,2", n = 14 }
  local fpl = { key = "azure", team = { ia3 = { saturated = { ["iron-plate"] = true } } } }
  local cpl = { slots = { batis = 0, open_sites = 0, cap = 2 }, open = {} }
  Capi.portes(fpl, cpl, resa(plain), TENDU, 3600)
  local wpl = Capi.portes(fpl, cpl, resa(plain), TENDU, 7200)
  check(wpl and wpl[plain.key] ~= nil, "§4c le meme ordre sans marque de saturation reste retenu (debouche seulement)")
  local n0 = count_logs("[FO-SATURATION]")
  Capi.say_saturation(fsa, csa, resa(sat_order), 10800)
  local l = last_log("[FO-SATURATION]")
  check(count_logs("[FO-SATURATION]") == n0 + 1 and l and l:find("120/3000 tuiles couvertes", 1, true) and l:find("ordre ouvert", 1, true), "§4c [FO-SATURATION] : ordre ouvert, tuiles couvertes (" .. tostring(l) .. ")")
  Capi.say_saturation(fsa, csa, resa(sat_order), 14400)
  check(count_logs("[FO-SATURATION]") == n0 + 1, "§4c verdict inchange : pas de nouvelle ligne")
  local none = { orders = {}, coverage = { { id = "1,2", resource = "iron-ore", kappa = 40, free = 200, open = true, tiles = 3000, covered = 120 } },
    sat = { ["1,2"] = { false, "x" } }, refus = {} }
  none.sat["1,2"] = { ok = false, why = "foreuse a combustion : la saturation se fait en electrique" }
  Capi.say_saturation(fsa, csa, none, 18000)
  l = last_log("[FO-SATURATION]")
  check(l and l:find("ordre ferme", 1, true) and l:find("foreuse a combustion", 1, true), "§4c [FO-SATURATION] : ordre ferme avec sa cause (" .. tostring(l) .. ")")
  local wanted = { orders = {}, coverage = { { id = "1,2", resource = "iron-ore", kappa = 40, free = 200, open = true, tiles = 3000, covered = 120 } },
    sat = { ["1,2"] = { ok = true, why = "200 place(s) libre(s)" } }, refus = {} }
  Capi.say_saturation(fsa, csa, wanted, 19000)
  l = last_log("[FO-SATURATION]")
  check(l and l:find("ordre ferme", 1, true) and l:find("voulu mais non retenu", 1, true), "§4c ordre voulu mais absent : la cause le dit, pas « 200 places libres » (" .. tostring(l) .. ")")
  local opening = { orders = { { key = "ouvrir:iron-ore@1,2", kind = "ouvrir", deposit = "1,2", n = 2 } }, coverage = wanted.coverage, sat = {}, refus = {} }
  Capi.say_saturation(fsa, csa, opening, 19500)
  l = last_log("[FO-SATURATION]")
  check(l and l:find("ordre ouvert", 1, true), "§4c un ordre d'ouverture du gisement compte comme ordre ouvert (" .. tostring(l) .. ")")
  check(Capi.saturation_on() == true, "§4c reglage non declare : saturation allumee")
  W.settings["fo-war-saturation"] = false
  check(Capi.saturation_on() == false, "§4c reglage a faux : saturation eteinte")
  W.settings["fo-war-saturation"] = nil
  Capi.say_saturation(fsa, csa, { orders = {}, coverage = {} }, 20000) -- res.sat absent : rien, sans erreur
end

-- §5 Compteur cumulé : lu dans le source (Capi.think_tail est lourd à rejouer hors moteur) et mutants du câblage.
do
  local src = read("script/ai3/capitalisation.lua")
  local a = src:find('if state == "fini" and Cv.SITE_EXECS[rec.exec] then', 1, true)
  local b = src:find("cs.done[#cs.done + 1] = { key = rec.key", a or 1, true)
  check(a ~= nil and b ~= nil and b > a, "§5 le compteur est incremente AVANT l'ajout a cs.done (l'amorce lit cs.done)")
  check(src:find("cs.batis_done = (cs.batis_done or Cv.seed(cs.done)) + math.max(1, #(rec.mod_ids or { rec.module }))", 1, true) ~= nil,
    "§5 compteur : amorce puis cumul")
  check(src:find("local batis = Cv.batis(cs.batis_done or Cv.seed(cs.done), fini_open)", 1, true) ~= nil, "§5 Capi.slots lit le cumul")
  check(src:find("sl.batis, sl.open_sites = batis, open_sites", 1, true) ~= nil, "§5 Capi.slots rend toujours batis et open_sites")
  check(src:find("Capi.say_couverture(f, cs, res, r, verdict, tick)", 1, true) ~= nil, "§5 Capi.portes ecrit le journal [FO-COUVERTURE]")
  check(src:find("local ok, why = Cv.loop(", 1, true) ~= nil, "§5 root_of appelle la regle de boucle")
  local g1 = src:find("local gate_why = Capi.portes(f, cs, res, view, tick)", 1, true)
  local g2 = src:find("cs.couv_wants = Cv.reserve_wants(res.orders, gate_why)", g1 or 1, true)
  local g3 = src:find("res.orders, seat_why = Capi.arbitre(", g1 or 1, true)
  check(g1 and g2 and g3 and g2 > g1 and g2 < g3, "§5 la pose prevue est notee APRES la porte L6 et AVANT l'arbitre des sieges (cs.couv_wants)")
  check(src:find("sat_k, sat_gap = Cv.sat_modules(sat_want, cs.slots and cs.slots.hands or 0, Dm.HANDS_PER_SITE, Dm.SLOTS_HARD)", 1, true) ~= nil
    and src:find("Capi.split(rate, Rp.factor(repli, rkey, tick), sat_k)", 1, true) ~= nil,
    "§5 un ordre de saturation a plusieurs modules (Cv.sat_modules, bras libres), les autres ordres gardent Capi.MODULES_PER_ORDER")
  check(src:find("module(s) voulu(s), %d obtenu(s)", 1, true) ~= nil, "§5 [FO-SATURATION] : modules voulus et obtenus, cause de l'ecart")
  check(src:find("sl.hands = hands", 1, true) ~= nil, "§5 Capi.slots rend les bras libres (sl.hands)")
  local isrc = read("script/ai3/industrie.lua")
  check(isrc:find("for _, w in ipairs(cs.couv_wants or {}) do", 1, true) ~= nil and isrc:find("Ml.want(ml, tick, w.item, w.rate, Cv.SRC)", 1, true) ~= nil,
    "§5 Ind.think transmet la pose prevue au mall (Ml.want, source couverture)")
end

-- §6 Mutants du runtime : substitution unique dans Capi.portes, fonction rejouée.
do
  local src = read("script/ai3/capitalisation.lua")
  local function body(name)
    local i = src:find("function Capi." .. name .. "(", 1, true)
    local j = src:find("\nend\n", i, true)
    return src:sub(i, j + 4)
  end
  local Cv = require("shared.ai3.couverture")
  local function mutant(name, old, new, probe)
    local b = body(name)
    local b2, n = b:gsub(old:gsub("%p", "%%%0"), (new:gsub("%%", "%%%%")))
    if n ~= 1 then return false, "introuvable" end
    local env = setmetatable({ Capi = Capi, Pe = require("shared.ai3.portes_extension"), Pi = require("shared.ai3.pile"), Cv = Cv,
      PORTES_TOURS = { couvrir = true, ouvrir = true, chaine = true, packs = true, labos = true },
      METHOD_OF_ORE = { ["iron-ore"] = { product = "iron-plate" }, ["copper-ore"] = { product = "copper-plate" } },
      minutes = function() return 0 end, sorted_keys = function(t) local k = {} for x in next, t or {} do k[#k + 1] = x end table.sort(k) return k end },
      { __index = _G })
    local chunk = assert(load("local Capi, Pe, Pi, Cv, PORTES_TOURS, METHOD_OF_ORE, minutes, sorted_keys = Capi, Pe, Pi, Cv, PORTES_TOURS, METHOD_OF_ORE, minutes, sorted_keys\n" .. b2,
      "=mut", "t", env))
    local saved = Capi[name]
    chunk()
    local killed = probe()
    Capi[name] = saved
    return killed
  end
  local function probe(saturated, free, view)
    return function()
      local fx = { key = "m", team = { ia3 = { saturated = saturated } } }
      local cx = { slots = { batis = 0, open_sites = 0 } }
      Capi.portes(fx, cx, res_for(free), view, 3600)
      local w = Capi.portes(fx, cx, res_for(free), view, 7200)
      return w
    end
  end
  -- témoin : la fonction non mutée, rejouée dans le même environnement, donne bien « passe » (sinon les mutants ne prouvent rien)
  local okT, wT = pcall(mutant, "portes", "return r.why", "return r.why", probe({}, 11, TENDU))
  check(okT and type(wT) == "table" and wT[couv.key] == nil, "§6 temoin : sans mutation, le couvrir en boucle passe")
  local MUT = {
    { "portes", "saturated = saturated,", "saturated = {},", function() local w = probe({ ["iron-plate"] = true }, 11, TENDU)() return w and w[couv.key] == nil end, "saturation non lue" },
    { "portes", "free = free_of[tostring(o.deposit)],", "free = 99,", function() local w = probe({}, 0, TENDU)() return w and w[couv.key] == nil end, "places libres non lues" },
    { "portes", "local crisis = (view.survie or view.hq_threat) and true or false", "local crisis = false",
      function() local w = probe({}, 11, { workers = 8, workers_waiting = 0, backlog = 57, survie = true })() return w and w[couv.key] == nil end, "crise non lue" },
    { "portes", "site_floor = sl.cap }", "site_floor = nil }", function()
      local fx = { key = "m", team = { ia3 = { saturated = {} } } }
      local cx = { slots = { batis = 0, open_sites = 0, cap = 2 } }
      local c2 = { key = "couvrir:iron-ore@5,6", kind = "couvrir", resource = "iron-ore", deposit = "5,6", n = 14 }
      local r2 = { orders = { couv, c2 }, coverage = { { id = "1,2", free = 11 }, { id = "5,6", free = 9 } } }
      Capi.portes(fx, cx, r2, TENDU, 3600)
      local w = Capi.portes(fx, cx, r2, TENDU, 7200)
      return w and w[c2.key] ~= nil end, "plancher des emplacements non transmis" },
    { "portes", "if ok then return 1 end", "if ok then return nil end", function() local w = probe({}, 11, TENDU)() return w and w[couv.key] ~= nil end, "verdict de boucle jete" },
  }
  local refused = 0
  for _, m in ipairs(MUT) do
    local ok, killed = pcall(mutant, m[1], m[2], m[3], m[4])
    -- (le probe du mutant rend « la mutation s'est vue » : vrai = le mutant est refuse)
    killed = ok and killed == true
    if killed then refused = refused + 1 else print("[COUVERTURE-RT] mutant NON refuse : " .. m[5] .. (ok and "" or (" (" .. tostring(killed) .. ")"))) end
    check(killed, "§6 mutant refuse : " .. m[5])
  end
  print(string.format("[COUVERTURE-RT] §6 mutants du runtime refuses : %d sur %d", refused, #MUT))
end

W.settings["fo-war-portes"] = nil
print(string.format("[COUVERTURE-RT] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
