--[[
  Lot VIDEO L9, branchement : banc HORS JEU de la colle script/team/lots_minerai_glue.lua (règle shared/team/lot_minerai.lua) et du
  câblage de script/team/build.lua. Lancement, depuis la racine du mod : lua5.2 tests/lots_minerai_glue_test.lua
    1. diagnostic [FO-LOTS-MINERAI] : modules posés sur un lot de gisement par sorte, dont sans ressource (fabrique, énergie), projets
       refusés écartés, une ligne par équipe et par minute de jeu, compteurs de replis remis à zéro ;
    2. interrupteur ÉTEINT par défaut (réglage absent : le repli d'avant) ; allumé : une fabrique ne se replie plus sur un gisement,
       la fonte et l'extraction gardent leur repli ; un refus est compté ;
    3. câblage de build.lua (source) : champ Build.LotsMinerai, repli de try_place gardé par la règle, ligne par Build.think, aucune
       locale de plus au bloc principal, et les crochets du lot video-minerai (quantités du relevé, classement avec les seuils, lot
       évalué, tronçon fermé, relevé refait par Build.think) ;
    4. mutants refusés.
  Lot video-minerai (C4.1 à C4.3, section 5 de la batterie) : seuils lus en données, quantités solides seulement, lot de minerai neuf
  RESERVE à l'évaluation (aucune crise ne lit la marque), événements (porte fermée, pièce détruite, ennemi vu) et relevé refait une fois.
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end
local SET = {}
_G.settings = { global = setmetatable({}, { __index = function(_, k)
  if SET[k] == nil then error("parametre inconnu : " .. k, 2) end
  return { value = SET[k] }
end }) }
local LOGS = {}
_G.log = function(s) LOGS[#LOGS + 1] = s end
local Lg0 = require("script.team.lots_minerai_glue")

local function team()
  local lots = { a = { state = "gisement" }, b = { state = "libre" }, c = { state = "gisement" } }
  local function pr(id, gen, lot, st, kind) return { id = id, state = st or "fini", spec = { gen = gen }, parts = { { kind = kind or "module", lot = lot } } } end
  return { key = "rouge", build = { order = { 1, 2, 3, 4, 5, 6, 7 }, lots = lots, projects = {
    [1] = pr(1, "patron", "a"), [2] = pr(2, "smelter", "c"), [3] = pr(3, "drills", "a"), [4] = pr(4, "labs", "b"),
    [5] = pr(5, "patron", "a", "refuse"), [6] = pr(6, "steam", "a", "chantier", "centrale"), [7] = { id = 7, state = "attente", spec = { gen = "patron" }, parts = {} },
  } } }
end

local function battery(Lg, verbose)
  local fails = 0
  local function ck(c, msg)
    if not c then fails = fails + 1 if verbose then print("  ECHEC : " .. msg) end end
    if verbose then check(c, msg) end
  end
  for k in pairs(SET) do SET[k] = nil end
  -- 1. diagnostic
  local f = team()
  local c = Lg.census(f)
  ck(c.by.fabrique == 1 and c.by.energie == 1 and c.by.fonte == 1 and c.by.extraction == 1, "par sorte : fabrique 1, energie 1, fonte 1, extraction 1")
  ck(c.sans == 2 and c.total == 5, "sans ressource 2 (chaine et centrale) sur 5 poses (refuse et sans lieu ecartes)")
  ck(table.concat(c.list, " ") == "1:patron 6:steam", "projets cites : " .. table.concat(c.list, " "))
  local n0 = #LOGS
  local line = Lg.minute(f, 3600)
  ck(line and line:find("[FO-LOTS-MINERAI] rouge", 1, true) and line:find("sans ressource 2", 1, true) and line:find("regle eteinte", 1, true),
    "ligne [FO-LOTS-MINERAI] : " .. tostring(line))
  ck(Lg.minute(f, 3600 + 3599) == nil and #LOGS == n0 + 1, "une ligne par minute de jeu au plus")
  -- 2. interrupteur
  local function has_ore(list) for _, st in ipairs(list) do if st.gisement then return true end end return false end
  local function first(list) return list[1] end
  ck(Lg.states(f, "patron") == Lg.LEGACY and Lg.states(f, "labs") == Lg.LEGACY, "reglage absent : eteint, le repli d'avant (libres, puis gisement)")
  SET[Lg.SETTING] = false
  ck(Lg.states(f, "patron") == Lg.LEGACY, "reglage eteint : le repli d'avant")
  SET[Lg.SETTING] = true
  ck(not has_ore(Lg.states(f, "patron")), "allume : une fabrique n'a plus de gisement (Lm.states_for)")
  local sm = Lg.states(f, "smelter")
  ck(first(sm).libre and has_ore(sm), "allume : la fonte essaie les libres, puis garde son repli sur le gisement")
  local dr = Lg.states(f, "drills")
  ck(#dr == 1 and dr[1].gisement, "allume : l'extraction ne va que sur un gisement")
  Lg.after(f, "smelter", { ok = true }, 2, sm[2])   -- fonderie posée sur un gisement au 2e essai : un repli
  Lg.after(f, "drills", { ok = true }, 1, dr[1])    -- foreuses sur un gisement au 1er essai : pas un repli
  Lg.after(f, "patron", nil, 1, nil)                -- fabrique sans lot libre : repli refusé par la règle
  Lg.after(f, "smelter", nil, 2, nil)               -- fonderie sans lot : pas un refus de la règle
  line = Lg.minute(f, 7200)
  ck(line and line:find("replis sur un gisement 1, replis refuses 1 (regle allumee)", 1, true), "replis et refus comptes : " .. tostring(line))
  line = Lg.minute(f, 10800)
  ck(line and line:find("replis sur un gisement 0, replis refuses 0", 1, true), "compteurs remis a zero a chaque ligne")
  -- 5. MINERAI-SONDE : seuils, quantités, réservation, relevé refait.
  for k in pairs(SET) do SET[k] = nil end
  ck(Lg.seuils() == nil, "5. reglage absent : pas de seuils (le seuil unique d'avant)")
  SET[Lg.SETTING] = false
  ck(Lg.seuils() == nil, "5. reglage eteint : pas de seuils")
  SET[Lg.SETTING] = true
  ck(Lg.seuils() == Lg.SEUILS and Lg.SEUILS.sum == 1000000, "5. allume : les seuils des donnees")
  local function ent(name, amount, infinite, ptype)
    return { name = name, amount = amount, prototype = { infinite_resource = infinite or false,
      mineable_properties = { products = { { type = ptype or "item" } } } } }
  end
  local s = { res = {} }
  Lg.amount(s, ent("r_a", 4000), false)
  Lg.amount(s, ent("r_a", 6000), false)
  Lg.amount(s, ent("r_b", 500), false)
  Lg.amount(s, ent("r_huile", 300000, true), false)
  Lg.amount(s, ent("r_eau", 90000, false, "fluid"), false)
  ck(s.amount and s.amount.r_a == 10000 and s.amount.r_b == 500, "5. quantites additionnees par ressource (10 000 et 500)")
  ck(s.amount and s.amount.r_huile == nil and s.amount.r_eau == nil, "5. une ressource infinie ou liquide n'entre pas dans la somme (C4.2)")
  local sg = { res = {} }
  Lg.amount(sg, ent("r_a", 4000), true)
  ck(sg.amount == nil, "5. un releve de TRONCON ne compte aucune quantite")
  SET[Lg.SETTING] = false
  local so = { res = {} }
  Lg.amount(so, ent("r_a2", 4000), false)
  ck(so.amount == nil, "5. eteint : aucune quantite lue")
  SET[Lg.SETTING] = true

  local PREC = nil
  do for k, v in pairs(Lg.SEUILS.amount) do if v == 100000 then PREC = k end end end
  local function lot(i, j, st, extra)
    local l = { i = i, j = j, state = st, tick = 100 }
    for k, v in pairs(extra or {}) do l[k] = v end
    return l
  end
  local function fteam(lots) return { key = "bleu", build = { lots = lots, queue = {}, qhead = 1, order = {}, projects = {} } } end
  -- réservation à l'évaluation (C4.2) : un lot de 10 tuiles à 120 000 d'un minerai précieux, ou plus de 1 000 000 en tout
  local fr = fteam({})
  local n_log = #LOGS
  local l1 = lot(1, 1, "gisement")
  Lg.evaluated(fr, 5000, "1:1", l1, { res = { [PREC] = 10 }, amount = { [PREC] = 120000 } }, "inconnu")
  ck(l1.reserved == PREC, "5. lot de minerai neuf : RESERVE tout de suite (" .. tostring(l1.reserved) .. ")")
  ck(#LOGS == n_log + 1 and LOGS[#LOGS]:find("RESERVE au minerai (" .. PREC .. ", motif quantite", 1, true), "5. une ligne le dit : " .. tostring(LOGS[#LOGS]))
  Lg.evaluated(fr, 6000, "1:1", l1, { res = { [PREC] = 10 }, amount = { [PREC] = 120000 } }, "gisement")
  ck(l1.reserved == PREC and #LOGS == n_log + 1, "5. releve refait : toujours reserve, pas de seconde ligne")
  local l2 = lot(-1, 1, "gisement")
  Lg.evaluated(fr, 5000, "-1:1", l2, { res = { r_a = 20 }, amount = { r_a = 1500000 } }, "inconnu")
  ck(l2.reserved == "r_a", "5. plus de 1 000 000 en tout, 20 tuiles : reserve (C4.2)")
  local l3 = lot(2, 2, "libre")
  Lg.evaluated(fr, 5000, "2:2", l3, { res = { [PREC] = 10 }, amount = { [PREC] = 99000 } }, "inconnu")
  ck(l3.reserved == nil, "5. 99 000 : lot libre, non reserve (C4.1)")
  local l4 = lot(3, 3, "gisement", { used = 7 })
  Lg.evaluated(fr, 5000, "3:3", l4, { res = { r_a = 40 } }, "inconnu")
  ck(l4.reserved == nil, "5. un lot deja pris par un projet n'est pas reserve")
  local l5 = lot(1, 1, "libre", { reserved = PREC })
  Lg.evaluated(fr, 7000, "1:1", l5, { res = {} }, "gisement")
  ck(l5.reserved == nil, "5. le minerai a disparu au releve : la reservation tombe")
  SET[Lg.SETTING] = false
  local l6 = lot(4, 4, "gisement")
  Lg.evaluated(fr, 5000, "4:4", l6, { res = { r_a = 40 } }, "inconnu")
  ck(l6.reserved == nil, "5. eteint : rien n'est reserve")
  SET[Lg.SETTING] = true

  -- événements et relevé refait (C4.3)
  local lots = {
    ["0:0"] = lot(0, 0, "occupe"), ["1:0"] = lot(1, 0, "libre"), ["-1:0"] = lot(-1, 0, "gisement"), ["0:1"] = lot(0, 1, "refuse"),
    ["0:-1"] = lot(0, -1, "libre", { used = 3 }), ["2:0"] = { i = 2, j = 0, state = "inconnu" }, ["1:1"] = lot(1, 1, "defricher"), ["-1:1"] = lot(-1, 1, "occupe"),
    ["3:3"] = lot(3, 3, "refuse", { reason = "eau" }), ["3:4"] = lot(3, 4, "refuse", { reason = "falaise" }), ["3:5"] = lot(3, 5, "refuse", { reason = "nid" }),
  }
  local fe = fteam(lots)
  ck(Lg.think(fe, 1000) == 0 and #fe.build.queue == 0, "5. sans evenement : aucun releve refait")
  Lg.seg_changed(fe, 1000, "inconnu", "ferme")
  ck(fe.build.lm == nil or fe.build.lm.ev == nil, "5. une rue vue fermee a sa premiere evaluation n'est pas un evenement")
  Lg.seg_changed(fe, 1000, "ouvert", "ferme")
  ck(fe.build.lm and fe.build.lm.ev == 1000 and fe.build.lm.ev_why == "porte fermee", "5. une rue ouverte qui se ferme : porte fermee, evenement")
  Lg.seg_changed(fe, 1100, "ouvert", "ferme")
  ck(fe.build.lm.ev == 1000, "5. deux evenements a moins de " .. Lg.EVENT_GAP .. " ticks n'en font qu'un")
  local cap0 = Lg.RESURVEY_PER_PASS
  Lg.RESURVEY_PER_PASS = 4 -- la borne par pensee se contrôle avec 5 lots et une borne de 4
  local q = Lg.think(fe, 1010)
  ck(q == 4 and #fe.build.queue == 4, "5. releve refait : " .. tostring(q) .. " lot(s) remis a la file (la borne de la pensee)")
  local queued = {}
  for _, it in ipairs(fe.build.queue) do queued[it[2]] = true end
  ck(not queued["0:0"] and not queued["0:-1"] and not queued["2:0"], "5. ni le QG, ni un lot pris, ni un lot jamais releve")
  ck(queued["1:0"] and queued["-1:0"] and queued["1:1"] and not queued["0:1"], "5. les lots qui peuvent recevoir un module d'abord (libre, defricher, gisement)")
  ck(Lg.think(fe, 1020) == 2 and #fe.build.queue == 6, "5. pensee suivante : les deux derniers lots (refus par un nid, refus ordinaire)")
  ck(not queued["3:3"] and not queued["3:4"], "5. un lot d'eau ou de falaise n'est jamais remis a la file (le terrain ne bouge pas)")
  Lg.RESURVEY_PER_PASS = cap0
  ck(Lg.think(fe, 1030) == 0 and #fe.build.queue == 6, "5. rien de plus : chaque lot n'est remis qu'une fois par evenement")
  for _, it in ipairs(fe.build.queue) do fe.build.lots[it[2]].tick = 1040 end -- le moteur a refait les releves
  ck(Lg.think(fe, 1050) == 0 and fe.build.lm.ev_done == fe.build.lm.ev, "5. releves refaits : le besoin tombe (vrai une fois, puis faux)")
  ck(Lg.event(fe, 3000, "batiment detruit") == false, "5. un evenement a moins de " .. Lg.EVENT_GAP .. " ticks du precedent est ecarte (pas de releve en rafale)")
  ck(Lg.event(fe, 1000 + Lg.EVENT_GAP, "batiment detruit") == true and Lg.think(fe, 1000 + Lg.EVENT_GAP + 10) == 6,
    "5. un nouvel evenement refait les releves (les 6 lots en une pensee, borne " .. Lg.RESURVEY_PER_PASS .. ")")
  -- pièce détruite et ennemi vu, lus au relevé de reconstruction
  local fs = fteam({ ["1:0"] = lot(1, 0, "libre") })
  fs.build.sweep = { reopened = 0, danger = 0 }
  Lg.think(fs, 100)
  ck(fs.build.lm.ev == nil, "5. releve de reconstruction vide : pas d'evenement")
  fs.build.sweep.reopened = 3
  Lg.think(fs, 200)
  ck(fs.build.lm.ev == 200 and fs.build.lm.ev_why == "batiment detruit", "5. pieces rouvertes : batiment detruit")
  fs.build.sweep.danger = 1
  Lg.think(fs, 200 + Lg.EVENT_GAP)
  ck(fs.build.lm.ev == 200 + Lg.EVENT_GAP and fs.build.lm.ev_why == "ennemi vu", "5. danger vu : ennemi vu")
  ck(fs.build.lm.evn == 2, "5. deux evenements comptes")
  -- ennemi vu à l'évaluation d'un lot : un nid apparaît
  local fn = fteam({})
  Lg.evaluated(fn, 900, "5:5", lot(5, 5, "refuse", { reason = "nid" }), { res = {} }, "inconnu")
  ck(fn.build.lm == nil or fn.build.lm.ev == nil, "5. un nid vu des la premiere evaluation n'est pas un evenement")
  Lg.evaluated(fn, 900, "5:6", lot(5, 6, "refuse", { reason = "nid" }), { res = {} }, "libre")
  ck(fn.build.lm and fn.build.lm.ev == 900 and fn.build.lm.ev_why == "ennemi vu", "5. un nid sur un lot qui etait libre : ennemi vu")
  SET[Lg.SETTING] = false
  local fo2 = fteam(lots)
  Lg.seg_changed(fo2, 1000, "ouvert", "ferme")
  ck(Lg.think(fo2, 1010) == 0 and (fo2.build.lm == nil or fo2.build.lm.ev == nil), "5. eteint : ni evenement ni releve refait")
  SET[Lg.SETTING] = true
  -- ligne de la minute : lots réservés et relevés refaits
  local fl = fteam({ ["1:1"] = lot(1, 1, "gisement", { reserved = "r_a" }), ["2:1"] = lot(2, 1, "libre") })
  fl.build.lm = { repli = 0, refus = 0, rv = 2, re = 3 }
  local ln = Lg.minute(fl, 3600)
  ck(ln and ln:find("lots de minerai reserves 1 (neufs 2), releves refaits apres evenement 3", 1, true), "5. ligne de la minute : reserves et releves : " .. tostring(ln))
  ck(fl.build.lm.rv == 0 and fl.build.lm.re == 0, "5. compteurs de la ligne remis a zero")
  -- lecture des bancs (remote fo-ia1d.lots_minerai)
  _G.game = { tick = 9000 }
  local fq = fteam({ ["1:0"] = lot(1, 0, "gisement", { reserved = "r_x" }), ["0:1"] = lot(0, 1, "libre"), ["0:0"] = lot(0, 0, "occupe"),
    ["2:2"] = lot(2, 2, "gisement", { reserved = "r_y" }) })
  local r0 = Lg.remote(fq, "report")
  ck(r0 and r0.on == true and r0.reserved == 2 and r0.keys[1] == "1:0=r_x" and r0.keys[2] == "2:2=r_y" and r0.events == 0 and r0.stale == 0,
    "5. remote report : lots reserves tries, aucun evenement, aucun releve en retard")
  ck(Lg.remote(fq, "event", "banc") == true, "5. remote event : declenche l'evenement a game.tick")
  local r1 = Lg.remote(fq, "report")
  ck(r1 and r1.events == 1 and r1.ev == 9000 and r1.ev_why == "banc" and r1.stale == 3, "5. remote report : 3 lots au releve en retard (le QG ecarte) : " .. tostring(r1 and r1.stale))
  game.tick = 9010
  ck(Lg.think(fq, 9010) == 3 and Lg.remote(fq, "report").resurveyed == 3, "5. la pensee remet les 3 lots a la file")
  for _, l in pairs(fq.build.lots) do l.tick = 9020 end
  game.tick = 9030
  ck(Lg.remote(fq, "report").stale == 0, "5. releves refaits : plus aucun en retard")
  ck(Lg.remote(fq, "autre") == nil and Lg.remote({}, "report") == nil, "5. commande inconnue ou equipe sans plan : rien")
  _G.game = nil
  for k in pairs(SET) do SET[k] = nil end
  return fails
end

print("[LOTS-MINERAI-GLUE] 1-2. diagnostic et interrupteur")
check(battery(Lg0, true) == 0, "batterie sans echec")

-- 3. câblage
print("[LOTS-MINERAI-GLUE] 3. cablage de build.lua")
local SRC = assert(io.open("script/team/build.lua", "rb")):read("*a")
check(SRC:find('Build.LotsMinerai = require("script.team.lots_minerai_glue")', 1, true) ~= nil, "Build.LotsMinerai requis au chargement (champ, pas une locale)")
local a = SRC:find("for i, states in ipairs(Build.LotsMinerai.states(f, gx.gen)) do", 1, true)
local g = SRC:find("m, w = place_module(f, surface, gx, states, toward, nil, fopts)", 1, true)
local h = SRC:find("Build.LotsMinerai.after(f, gx.gen, m, mi, ms)", 1, true)
check(a and g and h and a < g and g < h and h - a < 600, "try_place : les etats essayes viennent de la regle (Lm.states_for allumee, repli d'avant eteinte)")
check(not SRC:find("if not m then m, w = place_module(f, surface, gx, { gisement = true }", 1, true), "try_place : plus de repli sans condition")
do
  local sv = SRC:find("local function survey(surface, force, x0, y0, x1, y1, seg)", 1, true)
  local am = SRC:find("Build.LotsMinerai.amount(s, e, seg)", 1, true)
  local ev = SRC:find("local function eval_one(f, surface, item, tick)", 1, true)
  check(sv and am and ev and sv < am and am < ev, "survey : la quantite de chaque ressource du lot est lue (Build.LotsMinerai.amount)")
  local cl = SRC:find("P.classify_lot(s, Build.LotsMinerai.seuils())", 1, true)
  local evd = SRC:find("Build.LotsMinerai.evaluated(f, tick, item[2], l, s, old)", 1, true)
  check(cl and evd and ev < cl and cl < evd and evd - cl < 3000, "eval_one : le lot est classe avec les seuils, puis reserve (Build.LotsMinerai.evaluated)")
  check(not SRC:find("P.classify_lot(s)", 1, true), "eval_one : plus de classement au seuil unique sans la regle")
  local sc = SRC:find("Build.LotsMinerai.seg_changed(f, tick, old, g.state)", 1, true)
  check(sc and evd and sc > evd and sc - evd < 3000, "eval_one : un troncon qui se ferme est un evenement (Build.LotsMinerai.seg_changed)")
end
local t1 = SRC:find("function Build.think(f, surface, tick)", 1, true)
local t2 = SRC:find("Build.LotsMinerai.minute(f, tick)", 1, true)
check(t1 and t2 and t2 > t1 and t2 - t1 < 400, "Build.think : une ligne [FO-LOTS-MINERAI] par minute")
check(SRC:find("lots_minerai = function(key, cmd, arg) return Build.LotsMinerai.remote(team_of_key(key), cmd, arg) end", 1, true) ~= nil,
  "interface fo-ia1d : lots_minerai (lecture des bancs)")
local t3 = SRC:find("Build.LotsMinerai.think(f, tick)", 1, true)
check(t1 and t3 and t3 > t1 and t3 - t1 < 700, "Build.think : les releves de lots sont refaits apres un evenement (Build.LotsMinerai.think)")
do
  local cut
  for pos in SRC:gmatch("()\nreturn Build%s*$") do cut = pos end
  local head, tail = SRC:sub(1, cut), SRC:sub(cut + 1)
  local function ok_with(n)
    local t = {}
    for i = 1, n do t[i] = "local zz_" .. i .. " = nil" end
    return load(head .. table.concat(t, "\n") .. "\n" .. tail, "=x") ~= nil
  end
  local free = 0
  while free < 201 and ok_with(free + 1) do free = free + 1 end
  print(string.format("[LOTS-MINERAI-GLUE] build.lua : %d locales au bloc principal (encore %d)", 200 - free, free))
  check(200 - free <= 199, "aucune locale de plus au bloc principal de build.lua (199 au plus)")
end

-- 4. mutants
print("[LOTS-MINERAI-GLUE] 4. mutants")
local function mutant(name, patch)
  local saved = {}
  for k, v in pairs(Lg0) do saved[k] = v end
  patch(Lg0)
  local ok, fl = pcall(battery, Lg0, false)
  for k in pairs(Lg0) do Lg0[k] = saved[k] end
  check((not ok) or fl > 0, "mutant refuse : " .. name)
end
mutant("interrupteur allume par defaut", function(Lg) Lg.on = function() local ok, v = pcall(function() return settings.global[Lg.SETTING].value end) return (not ok) or v == true end end)
mutant("fabrique encore repliee regle allumee", function(Lg) Lg.states = function() return Lg.LEGACY end end)
mutant("refus jamais compte", function(Lg)
  local base = Lg.after
  Lg.after = function(f, gen, m, i, st) if m then return base(f, gen, m, i, st) end end
end)
mutant("fonderie comptee sans ressource", function(Lg)
  local base = Lg.kind
  Lg.kind = function(gen, plant) local k = base(gen, plant) if k == "fonte" then return "fabrique" end return k end
end)
mutant("seuils toujours donnes, regle eteinte comprise", function(Lg) Lg.seuils = function() return Lg.SEUILS end end)
mutant("quantite d'un liquide additionnee", function(Lg)
  Lg.amount = function(s, e) s.amount = s.amount or {}; s.amount[e.name] = (s.amount[e.name] or 0) + (e.amount or 0) end
end)
mutant("quantite lue pour un troncon", function(Lg)
  local base = Lg.amount
  Lg.amount = function(s, e) return base(s, e, false) end
end)
mutant("lot non reserve", function(Lg) Lg.evaluated = function() end end)
mutant("porte fermee ignoree", function(Lg) Lg.seg_changed = function() end end)
mutant("releve jamais refait", function(Lg) Lg.think = function() return 0 end end)
mutant("releve remis a la file sans fin", function(Lg)
  local base = Lg.think
  Lg.think = function(f, tick)
    for _, l in pairs(f.build.lots or {}) do l.lm_q = nil end
    return base(f, tick)
  end
end)
mutant("lot d'eau remis a la file", function(Lg)
  local base = Lg.think
  Lg.think = function(f, tick)
    for _, l in pairs(f.build.lots or {}) do if l.reason == "eau" then l.state, l.reason = "libre", nil end end
    return base(f, tick)
  end
end)
mutant("lot pris remis a la file", function(Lg)
  local base = Lg.think
  Lg.think = function(f, tick)
    for _, l in pairs(f.build.lots or {}) do l.used = nil end
    return base(f, tick)
  end
end)
mutant("remote : retard jamais compte", function(Lg)
  local base = Lg.remote
  Lg.remote = function(f, cmd, arg) local r = base(f, cmd, arg) if type(r) == "table" then r.stale = 0 end return r end
end)
mutant("evenements en rafale", function(Lg) Lg.EVENT_GAP = 0 end)
mutant("une ligne a chaque appel", function(Lg)
  local base = Lg.minute
  Lg.minute = function(f, tick) if f.build and f.build.lm then f.build.lm.t = nil end return base(f, tick) end
end)
mutant("compteurs jamais remis a zero", function(Lg)
  local base = Lg.minute
  Lg.minute = function(f, tick)
    local st = f.build.lm or { repli = 0, refus = 0 }
    local r, s = st.repli, st.refus
    local line = base(f, tick)
    if line and f.build.lm then f.build.lm.repli, f.build.lm.refus = r, s end
    return line
  end
end)

print(string.format("[LOTS-MINERAI-GLUE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
