--[[
  Tests hors jeu du CHEF des factions (lot IA2-a) : shared/faction/chef.lua (pur) et script/faction/chef.lua
  (moteur simulé). Usage, depuis la racine du mod :   lua5.2 tests/chef_test.lua [minutes=40]

  Vérifie :
    1. règles pures : courbes, hasard borné (jamais une option sous 90 % de la meilleure, tirage au prorata),
       ordre des objectifs (4 marches d'amorçage en tête, prérequis, au plus 3 marches d'avance, pétrole en dernier,
       des ordres différents selon les postures), pensée (déterministe, durée minimale d'une dominante, crise,
       traits qui pèsent, les 8 traits lus), mémoire (attaque repoussée : seuil × 1,3, cible moins attirante,
       autre côté), côté d'arrivée (toujours parmi les 3 meilleurs octants, la ruse disperse), bornes ;
    2. moteur simulé : 4 factions pensent une fois par minute (ligne « [FO-STRAT] posture »), ordre des objectifs
       valide, attaques avec rassemblement avancé, issues publiées, global sérialisable ; deux parties de même graine
       identiques (lignes du chef) ; sauvegarde et rechargement = partie continue ; partie existante sans chef
       (migration) : chef recréé à la pensée suivante.
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local MINUTES = tonumber(arg and arg[1]) or 40
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local C = require("shared.faction.chef")
local T = require("shared.team.config")
local Tr = require("shared.faction.traits")

local function stream(seed) return Tr.new_stream(seed, 201) end
local function drawer(st) return function(n) return Tr.range(st, 1, n) end end

---------------------------------------------------------------------------------------------------
section("Règles pures : courbes et hasard borné")
check(C.lin(0, 0, 10) == 0 and C.lin(5, 0, 10) == 500 and C.lin(12, 0, 10) == 1000 and C.lin(-3, 0, 10) == 0, "courbe linéaire bornée")
do
  local list = { { key = "a", score = 1000, i = 1 }, { key = "b", score = 950, i = 2 }, { key = "c", score = 899, i = 3 }, { key = "d", score = 10, i = 4 } }
  local st = stream(7)
  local seen = { a = 0, b = 0, c = 0, d = 0 }
  for _ = 1, 3000 do
    local it = C.pick(list, drawer(st))
    seen[it.key] = seen[it.key] + 1
  end
  check(seen.c == 0 and seen.d == 0, "hasard borné : jamais une option sous 90 % de la meilleure (899/1000 : " .. seen.c .. ")")
  local ra = seen.a / (seen.a + seen.b)
  check(ra > 0.47 and ra < 0.56, string.format("tirage au prorata du score (a : %.3f, attendu 0,513)", ra))
  local alone = { { key = "a", score = 1000, i = 1 }, { key = "b", score = 899, i = 2 } }
  local ok = true
  for _ = 1, 200 do if C.pick(alone, drawer(st)).key ~= "a" then ok = false end end
  check(ok, "une seule option à 90 % : la meilleure, sans tirage")
end

---------------------------------------------------------------------------------------------------
section("Règles pures : ordre des objectifs")
local BASE_LADDER_TRAITS = {}
for _, k in ipairs(Tr.ORDER) do BASE_LADDER_TRAITS[k] = 1000 end
do
  local index = {}
  for i, g in ipairs(T.ladder) do index[g.key] = i end
  local all_ok, boot_ok, req_ok, shift_ok, last_ok, army_ok = true, true, true, true, true, true
  local orders, opening, swaps = {}, {}, 0
  local function test_mix(mix, tr)
    local o = C.ladder_order(mix, nil, tr)
    if #o ~= #T.ladder then all_ok = false end
    if o[1] ~= "coal" or o[2] ~= "iron" or not ((o[3] == "copper" and o[4] == "stone") or (o[3] == "stone" and o[4] == "copper")) then boot_ok = false end
    if o[3] == "stone" then swaps = swaps + 1 end
    if o[#o] ~= "oil" then last_ok = false end
    local pos = {}
    for k, key in ipairs(o) do pos[key] = k end
    for key, reqs in pairs(C.AFTER) do
      for _, r in ipairs(reqs) do if pos[r] > pos[key] then req_ok = false end end
    end
    for key, k in pairs(pos) do if index[key] - k > 4 then shift_ok = false end end
    if pos.army > 7 then army_ok = false end
    return table.concat(o, ",")
  end
  local TRS = { BASE_LADDER_TRAITS }
  for _, k in ipairs(Tr.ORDER) do
    for _, d in ipairs({ -400, 500 }) do
      local t = {}
      for _, k2 in ipairs(Tr.ORDER) do t[k2] = 1000 end
      t[k] = 1000 + d
      TRS[#TRS + 1] = t
    end
  end
  for _, tr in ipairs(TRS) do
    for _, p in ipairs(C.POSTURES) do
      orders[test_mix({ { key = p, w = 1000 } }, tr)] = true
      for _, q in ipairs(C.POSTURES) do
        if q ~= p then test_mix({ { key = p, w = 600 }, { key = q, w = 250 } }, tr) end
      end
    end
    -- Ouverture : 1re pensée, dominante « expansion » pour toutes ; le caractère seul la fait varier.
    opening[test_mix({ { key = "expansion", w = 600 }, { key = "technologie", w = 250 }, { key = "armee", w = 150 } }, tr)] = true
  end
  local distinct, nopen = 0, 0
  for _ in pairs(orders) do distinct = distinct + 1 end
  for _ in pairs(opening) do nopen = nopen + 1 end
  check(all_ok and boot_ok, "17 marches ; charbon puis fer en tête, cuivre et pierre ensuite (amorçage)")
  check(swaps > 0, "pierre avant cuivre pour certains mélanges ou caractères (" .. swaps .. ")")
  check(req_ok, "prérequis respectés (fer II avant fer III, tech 1 avant tech 2, armée avant armée II...), 17 caractères × 64 mélanges")
  check(shift_ok, "aucune marche n'avance de plus de 4 rangs")
  check(army_ok, "l'armée jamais après la 7e place")
  check(last_ok, "pétrole toujours en dernier")
  check(distinct >= 20, "des ordres différents selon la posture et le caractère (" .. distinct .. " ordres distincts)")
  check(nopen >= 5, "ouverture (même mélange) : le caractère seul donne " .. nopen .. " ordres différents")
  local o = C.ladder_order({ { key = "technologie", w = 1000 } })
  local pos = {}
  for k, key in ipairs(o) do pos[key] = k end
  check(pos.tech2 < index.tech2 and pos.tech3 < index.tech3 and pos.tech1 > pos.iron2,
    "technologie : les recherches avancent (tech2 " .. index.tech2 .. " -> " .. pos.tech2 .. "), jamais avant le fer II")
  local e = C.ladder_entries({ ladder = o })
  check(e and #e == #T.ladder and e[pos.tech1] == T.ladder[index.tech1], "marches rendues = tables de T.ladder (identité, lue par le planificateur)")
  check(C.ladder_entries(nil) == nil and C.ladder_entries({ ladder = { "coal" } }) == nil, "sans chef ou ordre incomplet : T.ladder (nil)")
end

---------------------------------------------------------------------------------------------------
section("Règles pures : pensée")
local BASE_TRAITS = { ambition = 1000, prudence = 900, agressivite = 1000, curiosite = 1000, rancune = 1000, opportunisme = 1000, discipline = 1000, ruse = 1000 }
local function traits(o)
  local t = {}
  for k, v in pairs(BASE_TRAITS) do t[k] = (o and o[k]) or v end
  return t
end
local function view(tick, o)
  o = o or {}
  return {
    tick = tick, minutes = math.floor(tick / 3600), traits = o.traits or traits(),
    outposts = o.outposts or 4, desired = o.desired or 6, sites = o.sites or 1,
    iron = o.iron or 150, copper = o.copper or 400, coal = 100, stone = o.stone or 200,
    tech = o.tech or 1, workers = 10, idle = o.idle or 3, goals = o.goals or 6,
    soldiers = o.garrison or 20, garrison = o.garrison or 20, army_target = 60, strength = 1,
    reserve = 0, unprotected = o.unprotected or 2, threatened = o.threatened or false, soldiers_lost = o.lost or 0,
    enemy_near = o.enemy_near or false,
    rivals = o.rivals or {
      { id = 2, outposts_seen = 3, defense = 12, army_out = false, weak = true, dist = 700 },
      { id = 3, outposts_seen = 1, defense = 40, army_out = false, weak = false, dist = 900 },
    },
  }
end
do
  local function run(seed, n)
    local st = C.new(stream(seed), 0)
    local out = {}
    for k = 0, n - 1 do
      local d = C.think(st, view(k * 3600, { garrison = 10 + (k * 7) % 40, copper = (k * 131) % 900 }), drawer(st.stream))
      out[#out + 1] = d.dominant .. ":" .. d.war_mult .. ":" .. tostring(d.target) .. ":" .. tostring(d.raid)
    end
    return table.concat(out, " "), st
  end
  local a = run(11, 60)
  local b = run(11, 60)
  local c = run(12, 60)
  check(a == b, "pensée déterministe (même flux, mêmes vues : mêmes 60 décisions)")
  check(a ~= c, "un autre flux donne une autre suite (hasard borné entre ex æquo)")
  -- Durée minimale d'une dominante.
  local _, st = run(13, 120)
  check(st.changes <= 120 / 5, "au plus une dominante nouvelle toutes les 5 min (" .. st.changes .. " changements en 120 pensées)")
  local hold_ok = true
  local st2 = C.new(stream(14), 0)
  local last, since = nil, 0
  for k = 0, 119 do
    local d = C.think(st2, view(k * 3600, { garrison = (k * 13) % 60, copper = (k * 977) % 2500, unprotected = k % 5 }), drawer(st2.stream))
    if d.dominant ~= last then
      if last and (k - since) < 5 then hold_ok = false end
      last, since = d.dominant, k
    end
  end
  check(hold_ok, "dominante tenue au moins 5 pensées hors crise")
  -- Crise : la dominante change avant 5 min.
  local st3 = C.new(stream(15), 0)
  C.think(st3, view(0, { copper = 2500 }), drawer(st3.stream))
  local before = st3.dominant
  local d = C.think(st3, view(3600, { threatened = true, enemy_near = true, lost = 10, unprotected = 4, garrison = 5 }), drawer(st3.stream))
  st3.lost = { 3600, 3600 }
  d = C.think(st3, view(7200, { threatened = true, enemy_near = true, lost = 10, unprotected = 4, garrison = 5 }), drawer(st3.stream))
  check(d.threat >= C.CRISIS and (d.dominant == "fortification" or d.dominant == "reconstruction" or d.dominant == "armee") and d.dominant ~= before,
    "crise (menace " .. d.threat .. ") : la dominante change avant 5 min (" .. tostring(before) .. " -> " .. d.dominant .. ")")
  -- Les traits pèsent : un caractère curieux choisit plus souvent la technologie qu'un caractère peu curieux.
  local function share(tr, posture)
    local n = 0
    for s = 1, 40 do
      local stx = C.new(stream(100 + s), 0)
      local dd = C.think(stx, view(20 * 3600, { traits = tr, copper = 300, garrison = 30 }), drawer(stx.stream))
      if dd.dominant == posture then n = n + 1 end
    end
    return n
  end
  local hi = share(traits({ curiosite = 1600 }), "technologie")
  local lo = share(traits({ curiosite = 600 }), "technologie")
  check(hi > lo, "curiosité 1 600 : technologie dominante " .. hi .. " fois sur 40 ; curiosité 600 : " .. lo)
  -- Les 8 traits sont lus : chacun change au moins un score.
  local read = {}
  local v0 = view(20 * 3600, { copper = 900, garrison = 30 })
  local st0 = C.new(stream(5), 0)
  st0.grudge[2] = 500
  v0.threat = C.threat(v0, st0)
  local best = C.rank_targets(v0, st0)[1]
  local function sig(tr)
    local vv = view(20 * 3600, { traits = tr, copper = 900, garrison = 30 })
    vv.threat = C.threat(vv, st0)
    local ranked = C.rank_targets(vv, st0)
    local sc = C.scores(vv, st0, best)
    local parts = {}
    for _, s in ipairs(sc) do parts[#parts + 1] = s.key .. s.score end
    for _, r in ipairs(ranked) do parts[#parts + 1] = r.id .. ":" .. r.score end
    return table.concat(parts, ",")
  end
  local ref = sig(traits())
  for _, k in ipairs(Tr.ORDER) do
    if sig(traits({ [k] = BASE_TRAITS[k] + 300 })) ~= ref then read[#read + 1] = k end
  end
  -- La ruse est lue par le choix du côté (C.pick_side), pas par les scores.
  local same_side = true
  local sa, sb = C.new(stream(6), 0), C.new(stream(6), 0)
  local ha, hb = {}, {}
  for _ = 1, 400 do
    local oa = C.pick_side(sa, 2, 100, 0, 600, drawer(sa.stream))
    local ob = C.pick_side(sb, 2, 100, 0, 1500, drawer(sb.stream))
    ha[oa] = (ha[oa] or 0) + 1
    hb[ob] = (hb[ob] or 0) + 1
  end
  if (ha[0] or 0) ~= (hb[0] or 0) then same_side = false end
  if not same_side then read[#read + 1] = "ruse (côté)" end
  check(#read >= 8, "les 8 traits sont lus (" .. table.concat(read, ", ") .. ")")
  check((ha[0] or 0) > (hb[0] or 0), "ruse : une faction rusée arrive moins souvent par le côté direct (" .. (ha[0] or 0) .. " contre " .. (hb[0] or 0) .. " sur 400)")
end

---------------------------------------------------------------------------------------------------
section("Règles pures : mémoire et côté d'arrivée")
do
  local st = C.new(stream(21), 0)
  local v = view(10 * 3600, { garrison = 40 })
  local d1 = C.think(st, v, drawer(st.stream))
  local target = d1.target
  check(target ~= nil and d1.war_mult >= C.MULT_LO and d1.war_mult <= C.MULT_HI, "cible choisie, multiplicateur borné (" .. d1.war_mult .. ")")
  -- Une attaque contre cette cible, par l'octant 4, repoussée.
  C.record_attack(st, { target = target, octant = 4, n = 20, tick = 10 * 3600, gid = 77 })
  local a = C.record_outcome(st, 77, "repoussee", 20, 8, 11 * 3600)
  check(a and a.outcome == "repoussee" and st.extra_defense[target] == 12 and st.avoid[target] == 11 * 3600 + C.AVOID_TICKS,
    "issue repoussée : défense apprise (12 pertes), cible évitée 10 min")
  -- Groupe défait par le moteur (F174) : aucune leçon.
  local sd = C.new(stream(25), 0)
  C.record_attack(sd, { target = 3, octant = 2, n = 20, tick = 0, gid = 9 })
  local ad = C.record_outcome(sd, 9, "dissous", 20, 0, 300)
  check(ad and ad.outcome == "dissous" and sd.avoid[3] == nil and sd.extra_defense[3] == nil, "issue « dissous » (F174) : ni cible évitée ni défense apprise")
  C.record_attack(sd, { target = 3, octant = 2, n = 20, tick = 600, gid = 10 })
  C.record_outcome(sd, 10, "dissous", 20, 0, 900)
  check(sd.avoid[3] == 900 + C.AVOID_TICKS and sd.extra_defense[3] == nil, "2 groupes défaits de suite contre la même cible : cible évitée 10 min (sans défense apprise)")
  -- Le côté suivant change (l'octant repoussé est pénalisé).
  local again = 0
  for _ = 1, 500 do
    if C.pick_side(st, target, -100, 0, 1000, drawer(st.stream)) == 4 then again = again + 1 end
  end
  check(again < 50, "côté : l'octant repoussé (direct) n'est repris que " .. again .. " fois sur 500")
  -- Seuil plus gros contre la même cible (même tirage).
  local stA, stB = C.new(stream(22), 0), C.new(stream(22), 0)
  local vA = view(10 * 3600, { garrison = 40, rivals = { { id = 2, outposts_seen = 3, defense = 12, weak = false, dist = 700 } } })
  vA.jitter = 1000
  local dA = C.think(stA, vA, drawer(stA.stream))
  C.record_attack(stB, { target = 2, octant = 1, n = 20, tick = 0, gid = 5 })
  C.record_outcome(stB, 5, "aneantie", 20, 0, 60)
  local vB = view(10 * 3600, { garrison = 40, rivals = { { id = 2, outposts_seen = 3, defense = 12, weak = false, dist = 700 } } })
  vB.jitter = 1000
  local dB = C.think(stB, vB, drawer(stB.stream))
  check(dB.war_mult >= math.min(C.MULT_HI, math.floor(dA.war_mult * 13 / 10) - 1),
    "après un échec contre la même cible : attaque suivante plus grosse (seuil " .. dA.war_mult .. " -> " .. dB.war_mult .. ")")
  -- Côté : toujours parmi les 3 meilleurs octants, entropie > 1 bit avec la ruse.
  local s2 = C.new(stream(23), 0)
  local hist, top_ok = {}, true
  for _ = 1, 600 do
    local o = C.pick_side(s2, 3, 0, 100, 1300, drawer(s2.stream))
    hist[o] = (hist[o] or 0) + 1
    -- Direct = octant 2 (sud) ; les 3 meilleurs : 2, 1, 3.
    if o ~= 1 and o ~= 2 and o ~= 3 then top_ok = false end
  end
  local H = 0
  for _, n in pairs(hist) do H = H - n / 600 * math.log(n / 600) / math.log(2) end
  check(top_ok and H > 1, string.format("côté tiré parmi les 3 meilleurs octants, entropie %.2f bit", H))
  -- Rancune : un site perdu par la faction 3 la fait monter dans les cibles.
  local s3 = C.new(stream(24), 0)
  local rv = { { id = 2, outposts_seen = 2, defense = 20, weak = false, dist = 700 }, { id = 3, outposts_seen = 2, defense = 20, weak = false, dist = 700 } }
  local vv = view(10 * 3600, { rivals = rv })
  vv.threat = C.threat(vv, s3)
  local r0 = C.rank_targets(vv, s3)
  C.record_loss(s3, 10 * 3600, 3)
  local r1 = C.rank_targets(vv, s3)
  check(r0[1].id == 2 and r1[1].id == 3, "rancune : la faction qui a détruit notre site devient la cible (2 -> 3 à valeur égale)")
end

---------------------------------------------------------------------------------------------------
section("Règles pures : satiété du vainqueur, trêve, survie (lot IA2-a2)")
do
  -- Rivale 2 (la plus attirante) battue : 12 des siens tués par nous depuis la pensée précédente.
  local st = C.new(stream(31), 0)
  local d0 = C.think(st, view(10 * 3600, { garrison = 40 }), drawer(st.stream))
  check(d0.target == 2 and not d0.hold, "avant la bataille : la rivale 2 est visée")
  C.record_kill(st, 2, 12)
  local d1 = C.think(st, view(11 * 3600, { garrison = 40 }), drawer(st.stream))
  check(st.beaten[2] == 11 * 3600 + C.SATIETY + 2 * C.SATIETY_PER_KILL and #d1.sated_new == 1 and d1.target == 3 and not d1.hold,
    "12 tués : rivale 2 battue (épargnée 15 min + 2 × 30 s), le chef vise la 3 (" .. tostring(d1.target) .. ")")
  -- Toutes les rivales battues : trêve (la première reste désignée, ni attaque ni raid).
  C.record_kill(st, 3, 10)
  local d2 = C.think(st, view(12 * 3600, { garrison = 40 }), drawer(st.stream))
  check(d2.hold and d2.target ~= nil and d2.raid == nil, "toutes battues : trêve (cible " .. tostring(d2.target) .. ", raid nul)")
  local d3 = C.think(st, view(11 * 3600 + C.SATIETY + 2 * C.SATIETY_PER_KILL, { garrison = 40 }), drawer(st.stream))
  check(not d3.hold and d3.target == 2, "fin de la satiété (16 min) : la rivale 2 redevient la cible")
  -- Tués étalés : 5 par minute pendant 3 min (compte amorti × 0,8) : battue à la 3e pensée.
  local se = C.new(stream(32), 0)
  local beaten_at
  for k = 1, 4 do
    C.record_kill(se, 2, 5)
    C.think(se, view((10 + k) * 3600, { garrison = 40 }), drawer(se.stream))
    if se.beaten[2] and not beaten_at then beaten_at = k end
  end
  check(beaten_at == 3, "5 tués par minute : rivale battue à la 3e pensée (" .. tostring(beaten_at) .. ")")
  -- Rancune forte : passe outre la satiété.
  local sg = C.new(stream(33), 0)
  C.record_kill(sg, 2, 12)
  for _ = 1, 3 do C.record_loss(sg, 10 * 3600, 2) end
  local dg = C.think(sg, view(10 * 3600, { garrison = 40, traits = traits({ rancune = 1300 }) }), drawer(sg.stream))
  check(sg.beaten[2] ~= nil and dg.target == 2, "rancune (3 sites détruits par la 2) : la rivale battue reste visée")
  -- Attaque réussie : satiété aussi.
  local sr = C.new(stream(34), 0)
  C.record_attack(sr, { target = 3, octant = 1, n = 20, tick = 0, gid = 4 })
  C.record_outcome(sr, 4, "reussie", 20, 18, 600)
  check(sr.beaten[3] == 600 + C.SATIETY, "attaque réussie : rivale épargnée 15 min")
  -- SURVIE : 3 ouvriers sur 8 au départ, dominante quelconque : reconstruction imposée, seuil au plus haut.
  local ss = C.new(stream(35), 0)
  C.think(ss, view(10 * 3600, { garrison = 40 }), drawer(ss.stream))
  local vs = view(11 * 3600, { garrison = 40 })
  vs.workers, vs.floor = 3, 8
  local ds = C.think(ss, vs, drawer(ss.stream))
  check(ds.survive and ds.dominant == "reconstruction" and ds.reason == "survie" and ds.war_mult == C.MULT_HI and ss.rebuild
    and ds.raid == nil, "survie (3 ouvriers sur 8) : reconstruction imposée, seuil " .. ds.war_mult .. ", équipe en reconstruction")
  local va = view(12 * 3600, { garrison = 2, lost = 12 })
  va.army_done, va.floor, va.soldiers = true, 8, 2
  check(C.survival(va), "survie : armée détruite (12 soldats perdus, 2 sur 60 visés)")
  local vb = view(12 * 3600, { garrison = 40, lost = 12 })
  vb.army_done, vb.floor = true, 8
  check(not C.survival(vb), "pas de survie : 12 soldats perdus mais 40 sur 60 visés")
  -- La survie tient jusqu'au rétablissement (ouvriers au départ ET armée au quart de sa cible), pertes anciennes ou non.
  local vl = view(13 * 3600, { garrison = 2, lost = 0 })
  vl.workers, vl.floor, vl.army_done, vl.soldiers = 8, 8, true, 2
  local dl = C.think(ss, vl, drawer(ss.stream))
  local vr = view(14 * 3600, { garrison = 16, lost = 0 })
  vr.workers, vr.floor, vr.army_done, vr.soldiers = 8, 8, true, 16
  check(dl.survive and not C.survival(vl) and not C.survival(vr, ss),
    "survie tenue (8 ouvriers, 2 soldats sur 60, aucune perte récente), levée à 16 soldats sur 60")
  -- QG nu (aucun avant-poste) : épargné, sauf rancune.
  local sb = C.new(stream(36), 0)
  local rb = { { id = 2, outposts_seen = 0, defense = 0, weak = false, dist = 600, bare = true },
    { id = 3, outposts_seen = 2, defense = 30, weak = false, dist = 900 } }
  local db = C.think(sb, view(10 * 3600, { garrison = 40, rivals = rb }), drawer(sb.stream))
  local sb2 = C.new(stream(36), 0)
  for _ = 1, 3 do C.record_loss(sb2, 10 * 3600, 2) end
  local db2 = C.think(sb2, view(10 * 3600, { garrison = 40, rivals = rb, traits = traits({ rancune = 1300 }) }), drawer(sb2.stream))
  check(db.target == 3 and db2.target == 2, "QG nu épargné (cible 3) ; avec rancune, visé (cible " .. tostring(db2.target) .. ")")
  -- Périphérie d'abord : l'avant-poste de la zone de départ (45 tuiles du QG rival) n'est visé qu'en dernier.
  local hq, me = { x = 0, y = 0 }, { x = 600, y = 0 }
  local start_zone, frontier = { x = 45, y = 0 }, { x = -200, y = 50 }
  local tp1 = C.target_point({ start_zone, frontier }, hq, me)
  local tp2 = C.target_point({ start_zone }, hq, me)
  check(tp1 == frontier and tp2 == start_zone and C.target_point({}, hq, me) == hq,
    "périphérie d'abord : avant-poste à 206 tuiles du QG rival plutôt qu'à 45 (plus proche de nous) ; sinon la zone de départ ; sinon le QG")
  -- Trêve et décision d'attaque (shared/faction/strategy.lua) : en Paisible, aucune attaque ni raid contre la rivale ;
  -- à un niveau agressif, règle inchangée (ordre strict de la campagne de pvp_test).
  local S = require("shared.faction.strategy")
  local function sv(level, hold)
    return { personality = "conqueror", tech = 1, upgrades = 0, garrison = 60, soldiers_max = 100, can_attack = true,
      enemy_defense = 5, rival = { id = 2, outposts = 4 }, pvp = { difficulty = level, tick = 0, sent_player = 0, sent_total = 0 },
      chef = { war_mult = 1400, raid = 8, raid_defense = 0, hold = hold } }
  end
  local p0, p1 = S.attack(sv("peaceful", nil)), S.attack(sv("peaceful", true))
  local n0, n1 = S.attack(sv("normal", nil)), S.attack(sv("normal", true))
  check(p0 ~= nil and p1 == nil and S.raid(sv("peaceful", true)) == nil and S.raid(sv("peaceful", nil)) ~= nil,
    "trêve en Paisible : ni attaque (" .. tostring(p0) .. " -> nil) ni raid contre la rivale")
  check(n0 ~= nil and n0 == n1, "trêve à un niveau agressif : attaque inchangée (" .. tostring(n0) .. ", " .. tostring(n1) .. ")")

  -- Lot ARMEE : `hold_rival` (trêve, vague en route, attaque sans effet) épargne la rivale à un niveau agressif ; le
  -- chemin contre le joueur (S.decide) est identique avec et sans lui, à tous les niveaux et à tous les stades du plan.
  local function sw(level, extra)
    local v = sv(level, nil)
    for k, x in pairs(extra or {}) do v.chef[k] = x end
    return v
  end
  for _, lv in ipairs({ "easy", "normal", "hard", "merciless" }) do
    local a0, a1 = S.attack(sw(lv)), S.attack(sw(lv, { hold_rival = true }))
    check(a0 ~= nil and a1 == nil, "hold_rival au niveau " .. lv .. " : la rivale est épargnée (" .. tostring(a0) .. " -> nil)")
    check(S.raid(sw(lv, { vain = "echec" })) == nil and S.raid(sw(lv)) ~= nil, "attaque sans effet au niveau " .. lv .. " : pas de raid non plus")
  end
  check(S.attack(sw("peaceful", { vain = "portee" })) == nil, "attaque sans effet en Paisible : rivale épargnée aussi")
  local function player_view(level, garrison, extra, sent_player)
    local v = sw(level, extra)
    v.garrison = garrison
    v.player = { score = 40, defense = 6, reachable = true }
    v.pvp.declared, v.pvp.anchor, v.pvp.tick = true, 0, 400 * 3600
    v.pvp.sent_player, v.pvp.sent_total = sent_player or 0, 100
    return v
  end
  local same, saw_attack = true, 0
  for _, lv in ipairs({ "easy", "normal", "hard", "merciless" }) do
    for g = 0, 120, 3 do
      local o0, o1 = S.decide(player_view(lv, g)), S.decide(player_view(lv, g, { hold_rival = true, vain = "echec" }))
      local a0, a1 = o0.attack, o1.attack
      if o0.plan ~= o1.plan or o0.need ~= o1.need or o0.count ~= o1.count or ((a0 and a0.target) == "player") ~= ((a1 and a1.target) == "player")
        or (a0 and a0.target == "player" and a0.count ~= a1.count) then same = false end
      if a0 and a0.target == "player" then saw_attack = saw_attack + 1 end
    end
  end
  -- Part du joueur déjà servie (règle du déficit : il n'est pas « dû ») : une rivale épargnée le rend dû, exactement comme
  -- une faction sans rivale ; sans elle, il attend.
  local like_norival, waits, fired = true, true, 0
  for _, lv in ipairs({ "easy", "normal", "hard", "merciless" }) do
    for g = 0, 120, 3 do
      local held = S.decide(player_view(lv, g, { hold_rival = true }, 100))
      local free = S.decide(player_view(lv, g, nil, 100))
      local none = player_view(lv, g, nil, 100)
      none.rival = nil
      local o = S.decide(none)
      if held.plan ~= o.plan or held.need ~= o.need or held.count ~= o.count
        or ((held.attack and held.attack.target) == "player") ~= ((o.attack and o.attack.target) == "player") then like_norival = false end
      if free.plan ~= nil then waits = false end
      if held.attack and held.attack.target == "player" then fired = fired + 1 end
    end
  end
  check(like_norival and waits and fired > 10, "rivale épargnée : le joueur devient dû comme sans rivale (" .. fired .. " attaques), il attendait sinon")
  check(same and saw_attack > 10, "hold_rival : décision contre le joueur identique (plan, besoin, effectif) sur 164 garnisons x 4 niveaux (" .. saw_attack .. " attaques du joueur comparées)")
end

---------------------------------------------------------------------------------------------------
section("Règles pures : attaques sans effet, attente croissante et portée (lot ARMEE)")
do
  local st = C.new(stream(31), 0)
  local T0 = 20 * 3600
  -- Sans historique : tout est permis.
  check(C.vain_hold(st, 2, T0, 768) == nil, "sans historique : attaque permise")
  -- 1re attaque : un groupe dissous (0 survivant) qui n'a pas dépassé 300 tuiles sur 768.
  C.record_attack(st, { target = 2, octant = 6, n = 16, tick = T0, gid = 1, dist = 768 })
  check(C.vain_hold(st, 2, T0 + 100, 768) == nil, "tant que l'issue n'est pas connue, `vain_hold` ne bloque pas (la vague en route, elle, est Chef.engaged)")
  local t1 = T0 + 16000
  C.record_outcome(st, 1, "dissous", 16, 0, t1, nil, 300)
  check(C.vain_hold(st, 2, t1 + 1, 768) == "echec", "dissous sans effet : attente (1re : " .. C.VAIN_WAIT .. " ticks)")
  check(st.vain[2].ok_at == t1 + C.VAIN_WAIT and st.vain[2].n == 1, "attente de la 1re attaque sans effet = VAIN_WAIT")
  check(C.vain_hold(st, 2, t1 + C.VAIN_WAIT, 768) == "portee", "attente écoulée, mais portée 300 sur 768 tuiles : même distance interdite")
  check(C.vain_hold(st, 2, t1 + C.VAIN_WAIT, 500) == "portee" and C.vain_hold(st, 2, t1 + C.VAIN_WAIT, 400) == nil,
    "une cible plus proche que la portée (+ marge du point visé) reste permise")
  check(C.vain_hold(st, 2, t1 + C.REACH_MEMORY + 1, 768) == nil, "la portée est oubliée après REACH_MEMORY")
  check(C.vain_hold(st, 3, t1 + 1, 768) == nil, "une autre cible n'est pas touchée")
  -- 2e et 3e échecs : attente doublée, plafonnée.
  local t = t1 + C.REACH_MEMORY + 10
  for k = 2, 6 do
    C.record_attack(st, { target = 2, octant = 6, n = 16, tick = t, gid = 10 + k, dist = 768 })
    C.record_outcome(st, 10 + k, "dissous", 16, 0, t + 500, nil, 700)
    local want = math.min(C.VAIN_CAP, C.VAIN_WAIT * 2 ^ (k - 1))
    check(st.vain[2].n == k and st.vain[2].ok_at == t + 500 + want, "échec " .. k .. " de suite : attente " .. want .. " ticks (cap " .. C.VAIN_CAP .. ")")
    check(st.vain[2].reach == nil and C.vain_hold(st, 2, t + 500 + want, 768) == nil, "portée 700 sur 768 : atteint le but, aucune restriction de portée")
    t = t + 500 + want + 10
  end
  -- Repoussée ou anéantie (un combat a eu lieu : défense apprise ailleurs) et renonce : ni échec de plus ni remise à zéro.
  local n_before = st.vain[2].n
  C.record_attack(st, { target = 2, octant = 6, n = 16, tick = t, gid = 98, dist = 768 })
  C.record_outcome(st, 98, "repoussee", 16, 3, t + 50, nil, 700)
  check(st.vain[2].n == n_before, "repoussée : pas un échec « sans effet » de plus (elle a combattu)")
  C.record_attack(st, { target = 2, octant = 6, n = 16, tick = t, gid = 99, dist = 768 })
  C.record_outcome(st, 99, "renonce", 16, 16, t + 100, 20, 600)
  check(st.vain[2].n == n_before, "renonce : pas un échec de plus")
  -- Réussie : remise à zéro.
  C.record_attack(st, { target = 2, octant = 6, n = 16, tick = t + 200, gid = 100, dist = 768 })
  C.record_outcome(st, 100, "reussie", 16, 14, t + 900, nil, 760)
  check(st.vain[2] == nil and C.vain_hold(st, 2, t + 901, 768) == nil, "attaque réussie : plus aucune restriction")
  -- Portée inconnue : seulement l'attente.
  local s2 = C.new(stream(32), 0)
  C.record_attack(s2, { target = 5, octant = 1, n = 10, tick = 0, gid = 1, dist = 500 })
  C.record_outcome(s2, 1, "dissous", 10, 0, 1000, nil, nil)
  check(s2.vain[5].reach == nil and C.vain_hold(s2, 5, 1000 + C.VAIN_WAIT, 500) == nil, "portée inconnue : l'attente seule joue")
  -- Bornes de short_of.
  check(not C.short_of(200, 100) and C.short_of(768, 300) and not C.short_of(768, 650) and C.short_of(768, 500),
    "short_of : but proche jamais « trop loin » (rassemblement avancé), but lointain si manque > 20 %")
end

---------------------------------------------------------------------------------------------------
-- Moteur simulé
---------------------------------------------------------------------------------------------------
local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end
local function W() return M.world() end
local function chef_lines()
  local out = {}
  for _, l in ipairs(W().logs) do
    if l:find("[FO-STRAT] posture", 1, true) or l:find("[FO-STRAT] attaque", 1, true) or l:find("[FO-STRAT] issue", 1, true) then
      out[#out + 1] = l
    end
  end
  return out
end
local function count(lines, pat)
  local n = 0
  for _, l in ipairs(lines) do if l:find(pat, 1, true) then n = n + 1 end end
  return n
end
local function game(minutes)
  M.new_game({ patches = patches(), p_busy = 0.02, p_nopath = 0.02, p_lost = 0.005 })
  M.command("fo-war", "start 4 100 10 320")
  local ok, err = pcall(M.run_ticks, minutes * 3600)
  return ok, err
end

section(string.format("Moteur simulé : %d min de guerre, 4 factions", MINUTES))
local t0 = os.clock()
local ok, err = game(MINUTES)
check(ok, "simulation sans erreur Lua (" .. tostring(err) .. ")")
print(string.format("  (%.1f s CPU)", os.clock() - t0))
local lines = chef_lines()
local per = {}
for _, f in ipairs(global.fo.war.factions) do per[f.key] = count(lines, "posture tick ") end
local thinks_ok, ladder_ok = true, true
for _, f in ipairs(global.fo.war.factions) do
  local n = 0
  for _, l in ipairs(lines) do if l:find("posture tick %d+ " .. f.key .. " :") then n = n + 1 end end
  if not f.eliminated and (n < MINUTES - 1 or n > MINUTES + 1) then thinks_ok = false end
  if f.chef then
    local e = require("shared.faction.chef").ladder_entries(f.chef)
    if not e or #e ~= #T.ladder then ladder_ok = false end
  end
end
check(thinks_ok, "une pensée du chef par minute et par faction vivante (lignes « posture »)")
check(ladder_ok, "ordre des objectifs du chef valide (17 marches) pour chaque faction")
local dominants = {}
for _, l in ipairs(lines) do
  local p = l:match("posture tick %d+ %w+ : dominante (%w+)")
  if p then dominants[p] = (dominants[p] or 0) + 1 end
end
local nd = 0
for _ in pairs(dominants) do nd = nd + 1 end
check(nd >= 3, "au moins 3 postures dominantes différentes sur la partie (" .. nd .. ")")
local att = count(lines, "[FO-STRAT] attaque")
local with_side = count(lines, "rassemblement (")
local raids = 0
for _, l in ipairs(lines) do if l:find("[FO-STRAT] attaque", 1, true) and l:find(", raid$") then raids = raids + 1 end end
print(string.format("  attaques %d (dont %d avec rassemblement avancé), issues %d, raids %d", att, with_side, count(lines, "[FO-STRAT] issue"), raids))
for k, l in ipairs(lines) do if k <= 6 or l:find("[FO-STRAT] issue", 1, true) then print("    " .. l) end end
check(att == 0 or with_side >= 1, "attaques entre factions avec un rassemblement avancé (côté choisi par le chef)")
-- Lot IA2-c : go / no-go au rassemblement avancé (une ligne par groupe arrivé) et modèle des rivales (styles).
do
  local go, ren, models = 0, 0, 0
  for _, l in ipairs(W().logs) do
    if l:find("[FO-STRAT] rassemblement", 1, true) then
      if l:find(": go,", 1, true) then go = go + 1 elseif l:find(": renonce,", 1, true) then ren = ren + 1 end
    elseif l:find("[FO-STRAT] modele", 1, true) then
      models = models + 1
    end
  end
  print(string.format("  lot IA2-c : rassemblements %d go, %d renonce ; changements de style des rivales %d", go, ren, models))
  check(with_side == 0 or go + ren >= 1, "IA2-c : décision au rassemblement avancé publiée (« [FO-STRAT] rassemblement »)")
  local styled = 0
  for _, f in ipairs(global.fo.war.factions) do
    for _, mem in pairs(f.chef and f.chef.seen or {}) do if mem.style then styled = styled + 1 end end
  end
  check(styled >= 1, "IA2-c : style des rivales tenu par le chef (" .. styled .. " modèles)")
end
check(pcall(M.serialize, global), "global sérialisable (état du chef)")
M.command("fo-war", "status")
local status_ok = false
-- Correction VERIF-NUIT (25/10) : ligne traduite (clé fo-chef.status, locale/*/ia2.cfg), postures et raison traduites.
local status_line
for _, l in ipairs(W().prints) do if l:find("{fo-chef.status:", 1, true) then status_ok, status_line = true, l end end
check(status_ok, "statut /fo-war : ligne du chef (clé fo-chef.status)")
check(status_line ~= nil and status_line:find("{fo-chef.posture-", 1, true) ~= nil
  and status_line:find("{fo-chef.reason-", 1, true) ~= nil and status_line:find("{fo-faction.name-", 1, true) ~= nil,
  "ligne du chef : posture, raison et cible traduites (" .. tostring(status_line and status_line:sub(1, 120)) .. ")")

section("Moteur simulé : déterminisme (deux parties de même graine)")
local first = table.concat(lines, "\n")
game(MINUTES)
check(table.concat(chef_lines(), "\n") == first, "lignes du chef identiques d'une partie à l'autre")

section("Moteur simulé : sauvegarde et rechargement = partie continue")
do
  game(30)
  local cont = table.concat(chef_lines(), "\n")
  -- Partie rechargée à 15 min (même monde simulé : modules rechargés, global copié comme par une sauvegarde).
  game(15)
  local saved = M.deepcopy_global(global)
  M.load_mod()
  _G.global = saved
  check(pcall(function() W().on_load() end), "on_load sans erreur")
  M.run_ticks(15 * 3600)
  local relo = table.concat(chef_lines(), "\n")
  check(relo == cont and #cont > 0, "partie rechargée à 15 min : lignes du chef identiques à la partie continue (30 min)")
end

section("Moteur simulé : partie existante sans chef (migration)")
do
  game(10)
  for _, f in ipairs(global.fo.war.factions) do f.chef = nil end
  local okm, errm = pcall(M.run_ticks, 3 * 3600)
  check(okm, "3 min sans erreur après l'effacement des chefs (" .. tostring(errm) .. ")")
  local recreated = true
  for _, f in ipairs(global.fo.war.factions) do
    if not f.eliminated and not (f.chef and f.chef.thinks and f.chef.thinks >= 2 and f.chef.ladder) then recreated = false end
  end
  check(recreated, "chef recréé à la pensée suivante, flux tiré de la graine (sel 200 + numéro)")
  check(pcall(M.serialize, global), "global sérialisable après migration")
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
