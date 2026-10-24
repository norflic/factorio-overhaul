--[[
  Tests hors jeu du caractère des factions tiré de la graine (lot IA2-0) et du journal des mesures.
  Usage, depuis la racine du mod :   lua5.2 tests/traits_test.lua

  Vérifie :
    1. tirages purs (shared/faction/traits.lua) : déterminisme, flux indépendants par faction, traits dans
       ±25 % de l'archétype, multiplicateur de seuil dans ±20 %, personnalités réparties (permutation, les
       24 répartitions et chaque archétype à chaque couleur sur 2 400 graines), variété entre graines ;
    2. caractère effectif : sans traits = archétype au nombre près ; avec traits, aggression, keep et caution
       dans l'ENVELOPPE des 4 archétypes, donc grâce, garnison gardée, rapport de force et tailles contre le
       joueur dans les bornes déjà testées par tests/pvp_test.lua, à chaque niveau ; ordre des niveaux tenu
       pour chaque caractère ; les règles pures acceptent la clé ou le caractère, au même résultat ;
    3. seuil d'attaque entre factions : règle d'IA0 sans tirage, seuil multiplié avec tirage ;
    4. moteur simulé : guerre lancée sur deux graines (personnalités et traits de la graine, lignes
       « [FO-STRAT] fondation »), même graine = même caractère et même partie, partie EXISTANTE sans traits
       (personnalité gardée, traits tirés une fois, origine « migration », stables après rechargement), lignes
       « [FO-SHAPE] » toutes les 10 min et « [FO-STRAT] attaque », octants sans trigonométrie.
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local F = require("shared.faction.config")
local S = require("shared.faction.strategy")
local Tr = require("shared.faction.traits")
local ARCH = { "conqueror", "technocrat", "builder", "balanced" }
local LEVELS = F.pvp_order

---------------------------------------------------------------------------------------------------
section("Flux et tirages purs")
do
  check(Tr.seed(20261020, 1) == Tr.seed(20261020, 1), "graine d'un flux : déterministe")
  check(Tr.seed(20261020, 1) ~= Tr.seed(20261020, 2), "graines des factions 1 et 2 différentes")
  check(Tr.seed(20261020, 1) ~= Tr.seed(20261021, 1), "graines de deux cartes voisines différentes")
  local ok_range = true
  for _, ms in ipairs({ 0, 1, 42, 20261020, 4294967295, 2147483646, 2147483647 }) do
    for salt = 0, 4 do
      local s = Tr.seed(ms, salt)
      if not (s >= 1 and s <= Tr.MOD - 1 and s == math.floor(s)) then ok_range = false end
    end
  end
  check(ok_range, "graine dans [1, MOD - 1], entière, même pour 0 et 2^32 - 1")
  -- Flux indépendants : tirer davantage dans le flux d'une faction ne change pas les traits d'une autre.
  local _, t2 = Tr.found(777, 2, "builder")
  local s1 = Tr.new_stream(777, 1)
  for _ = 1, 50 do Tr.next(s1) end
  local _, t2b = Tr.found(777, 2, "builder")
  local same = true
  for _, k in ipairs(Tr.ORDER) do if t2[k] ~= t2b[k] then same = false end end
  check(same, "flux indépendants : 50 tirages chez la faction 1 ne changent pas la faction 2")
  -- Traits dans ±25 % de l'archétype, multiplicateur dans ±20 %, sur 400 graines × 4 archétypes.
  local in_range, jit_ok, jit_lo, jit_hi, draws_ok = true, true, 2000, 0, true
  for ms = 1, 400 do
    for i, p in ipairs(ARCH) do
      local st, t, j = Tr.found(ms * 7919, i, p)
      for _, k in ipairs(Tr.ORDER) do
        local a = Tr.ARCHETYPES[p][k]
        if t[k] < math.floor(a * 0.75) or t[k] > math.ceil(a * 1.25) then in_range = false end
      end
      if j < 800 or j > 1200 then jit_ok = false end
      if j < jit_lo then jit_lo = j end
      if j > jit_hi then jit_hi = j end
      if st.draws ~= #Tr.ORDER + 1 then draws_ok = false end
    end
  end
  check(draws_ok, "9 tirages par fondation (8 traits et le seuil)")
  check(in_range, "traits dans ±25 % de l'archétype (1 600 fondations)")
  check(jit_ok and jit_lo <= 805 and jit_hi >= 1195, string.format("multiplicateur du seuil dans [800, 1200], bornes atteintes (%d à %d)", jit_lo, jit_hi))
end

section("Personnalités réparties par la graine")
do
  local perms, at = {}, {}
  for i = 1, 4 do at[i] = {} end
  local all_perm = true
  local N = 2400
  for ms = 1, N do
    local p = Tr.personalities(ms * 104729 + 3, 4)
    local seen = {}
    for i = 1, 4 do
      seen[p[i]] = (seen[p[i]] or 0) + 1
      at[i][p[i]] = (at[i][p[i]] or 0) + 1
    end
    for _, a in ipairs(ARCH) do if seen[a] ~= 1 then all_perm = false end end
    perms[table.concat(p, ",")] = true
  end
  local np = 0
  for _ in pairs(perms) do np = np + 1 end
  check(all_perm, "chaque partie a un archétype de chaque (permutation)")
  check(np == 24, "les 24 répartitions apparaissent (" .. np .. " sur 2 400 graines)")
  local fair = true
  local worst = 0
  for i = 1, 4 do
    for _, a in ipairs(ARCH) do
      local share = (at[i][a] or 0) / N
      if math.abs(share - 0.25) > worst then worst = math.abs(share - 0.25) end
      if share < 0.20 or share > 0.30 then fair = false end
    end
  end
  check(fair, string.format("chaque archétype à chaque couleur entre 20 et 30 %% (écart maximal %.1f points)", worst * 100))
  local p2 = Tr.personalities(20261020, 2)
  local p4 = Tr.personalities(20261020, 4)
  check(#p2 == 2 and p2[1] == p4[1] and p2[2] == p4[2], "2 factions : les 2 premières de la répartition à 4")
  check(Tr.personalities(20261020, 4)[1] == p4[1], "répartition déterministe")
  print("  graine 20261020 : " .. table.concat(p4, ", ") .. " (Écarlate, Azur, Émeraude, Ambre)")
end

section("Variété des caractères entre graines")
do
  local distinct, aggr = {}, {}
  for ms = 1, 100 do
    local p = Tr.personalities(ms, 4)
    for i = 1, 4 do
      local _, t = Tr.found(ms, i, p[i])
      distinct[i .. ":" .. Tr.describe(t)] = true
      local c = Tr.character(p[i], t)
      aggr[i] = aggr[i] or {}
      aggr[i][#aggr[i] + 1] = c.aggression
    end
  end
  local nd = 0
  for _ in pairs(distinct) do nd = nd + 1 end
  check(nd == 400, "400 caractères distincts sur 100 graines × 4 factions (" .. nd .. ")")
  for i = 1, 4 do
    local lo, hi = 9, 0
    for _, a in ipairs(aggr[i]) do
      if a < lo then lo = a end
      if a > hi then hi = a end
    end
    check(lo <= 0.75 and hi >= 1.45, string.format("faction %d : agressivité de %.2f à %.2f selon la graine (couleur non collée)", i, lo, hi))
  end
end

---------------------------------------------------------------------------------------------------
section("Caractère effectif et bornes des niveaux de difficulté")
do
  -- Sans traits : l'archétype au nombre près.
  for _, p in ipairs(ARCH) do
    local c, P = Tr.character(p, nil), F.personalities[p]
    check(c.aggression == P.aggression and c.keep == P.keep and c.caution == P.caution and c.greed == P.greed
      and c.research == P.research and c.archetype == p, p .. " : caractère sans traits = archétype")
    -- Les règles pures rendent le même résultat avec la clé ou le caractère.
    local same = true
    for _, lv in ipairs(LEVELS) do
      if S.grace_ticks(lv, p) ~= S.grace_ticks(lv, c) or S.player_keep(lv, p) ~= S.player_keep(lv, c)
        or S.player_min_size(lv, p, 100) ~= S.player_min_size(lv, c, 100) or S.player_ratio(lv, p) ~= S.player_ratio(lv, c)
        or S.player_goal(lv, p, 100) ~= S.player_goal(lv, c, 100) or S.siege_cap(lv, p, 100) ~= S.siege_cap(lv, c, 100)
        or S.army_target(p, 100) ~= S.army_target(c, 100) then same = false end
    end
    check(same, p .. " : règles PvP identiques avec la clé ou le caractère sans traits")
  end
  -- Bornes par niveau sur les 4 archétypes (ce que pvp_test vérifie déjà).
  local B = {}
  local function widen(lv, name, v)
    B[lv] = B[lv] or {}
    local b = B[lv][name]
    if not b then B[lv][name] = { v, v } else
      if v < b[1] then b[1] = v end
      if v > b[2] then b[2] = v end
    end
  end
  local function fields(lv, pers)
    return {
      grace = S.grace_ticks(lv, pers) or -1, keep = S.player_keep(lv, pers), ratio = S.player_ratio(lv, pers),
      min = S.player_min_size(lv, pers, 100), goal = S.player_goal(lv, pers, 100),
    }
  end
  -- Bornes EXIGÉES : grâce, garnison gardée, rapport de force (fonctions monotones des grandeurs bornées). Les
  -- TAILLES (minimale, visée) dépendent aussi de l'armée visée, qui reste celle de l'archétype : un technocrate peu
  -- agressif demande 26 soldats (25 pour l'archétype le plus timide) ; elles sont imprimées, et l'ordre des niveaux
  -- avec ces caractères est prouvé par la campagne de tests/pvp_test.lua (section « lot IA2-0 »).
  local NAMES = { "grace", "keep", "ratio" }
  local SIZES = { "min", "goal" }
  local size_range = {}
  for _, lv in ipairs(LEVELS) do
    for _, p in ipairs(ARCH) do
      local v = fields(lv, p)
      for _, n in ipairs(NAMES) do widen(lv, n, v[n]) end
      for _, n in ipairs(SIZES) do widen(lv, n, v[n]) end
    end
  end
  local env_ok, bounds_ok, order_ok = true, true, true
  local bad = nil
  local E = Tr.ENVELOPE
  for ms = 1, 500 do
    local p = Tr.personalities(ms * 31 + 7, 4)
    for i = 1, 4 do
      local _, t = Tr.found(ms * 31 + 7, i, p[i])
      local c = Tr.character(p[i], t)
      if c.aggression < E.aggression[1] or c.aggression > E.aggression[2] or c.keep < E.keep[1] or c.keep > E.keep[2]
        or c.caution < E.caution[1] or c.caution > E.caution[2] then env_ok = false end
      local prev
      for _, lv in ipairs(LEVELS) do
        local v = fields(lv, c)
        for _, n in ipairs(NAMES) do
          if v[n] < B[lv][n][1] - 1e-9 or v[n] > B[lv][n][2] + 1e-9 then
            bounds_ok = false
            bad = bad or string.format("%s %s = %s hors de [%s, %s]", lv, n, tostring(v[n]), tostring(B[lv][n][1]), tostring(B[lv][n][2]))
          end
        end
        for _, n in ipairs(SIZES) do
          local key = lv .. " " .. n
          local r = size_range[key]
          if not r then size_range[key] = { v[n], v[n] } else
            if v[n] < r[1] then r[1] = v[n] end
            if v[n] > r[2] then r[2] = v[n] end
          end
        end
        -- Ordre des niveaux agressifs pour CE caractère : grâce plus courte, garnison gardée et rapport exigé
        -- plus petits quand le niveau monte (Facile → Impitoyable).
        if F.pvp_params(lv).aggressive then
          if prev and not (v.grace < prev.grace and v.keep < prev.keep and v.ratio < prev.ratio) then order_ok = false end
          prev = v
        end
      end
    end
  end
  check(env_ok, string.format("2 000 caractères : aggression dans [%.2f, %.2f], keep dans [%.2f, %.2f], caution dans [%.2f, %.2f]",
    E.aggression[1], E.aggression[2], E.keep[1], E.keep[2], E.caution[1], E.caution[2]))
  check(bounds_ok, "2 000 caractères : grâce, garnison gardée et rapport de force contre le joueur dans les bornes des archétypes, à chaque niveau" .. (bad and (" (" .. bad .. ")") or ""))
  for _, lv in ipairs(LEVELS) do
    print(string.format("  %-9s taille minimale contre le joueur %d à %d (archétypes %d à %d) ; visée %d à %d (archétypes %d à %d)", lv,
      size_range[lv .. " min"][1], size_range[lv .. " min"][2], B[lv].min[1], B[lv].min[2],
      size_range[lv .. " goal"][1], size_range[lv .. " goal"][2], B[lv].goal[1], B[lv].goal[2]))
  end
  check(order_ok, "2 000 caractères : ordre strict des niveaux (grâce, garnison gardée, rapport exigé)")
  print(string.format("  Normal : grâce de %.1f à %.1f min selon le caractère (archétypes : conquérant 20, équilibré 30, technocrate 37,5, bâtisseur 42,9)",
    B.normal.grace[1] / 3600, B.normal.grace[2] / 3600))
end

section("Seuil d'attaque entre factions")
do
  local base = { tech = 0, upgrades = 0, garrison = 40, soldiers_max = 100, can_attack = true, enemy_defense = 0 }
  local function v(o)
    local t = {}
    for k, x in pairs(base) do t[k] = x end
    for k, x in pairs(o) do t[k] = x end
    return t
  end
  -- Sans tirage : règle d'IA0 (conquérant : 13 soldats envoyés au moins ; garnison 16 → 12 envoyables).
  check(S.attack(v({ personality = "conqueror", garrison = 17 })) == 13, "conquérant sans tirage : part à 13 (garnison 17)")
  check(S.attack(v({ personality = "conqueror", garrison = 16 })) == nil, "conquérant sans tirage : pas à 12")
  -- Avec tirage : seuil 13 × 1,2 = 16 (garnison 20 : 16 envoyables), × 0,8 = 10.
  check(S.jittered_size(13, 1200) == 16 and S.jittered_size(13, 800) == 10 and S.jittered_size(1, 800) == 1, "seuil multiplié et arrondi")
  check(S.attack(v({ personality = "conqueror", garrison = 17, attack_jitter = 1200 })) == nil, "seuil × 1,2 : 13 envoyables ne suffisent plus")
  check(S.attack(v({ personality = "conqueror", garrison = 20, attack_jitter = 1200 })) == 16, "seuil × 1,2 : part à 16")
  check(S.attack(v({ personality = "conqueror", garrison = 13, attack_jitter = 800 })) == 10, "seuil × 0,8 : part à 10")
  -- Le bâtisseur (seuil 28, 24 envoyables avec son armée visée de 40) peut partir avec un tirage bas.
  check(S.attack(v({ personality = "builder", garrison = 40 })) == nil, "bâtisseur sans tirage : jamais à 24 envoyables (défaut connu E21)")
  check(S.attack(v({ personality = "builder", garrison = 40, attack_jitter = 850 })) == 24, "bâtisseur, seuil × 0,85 : part à 24")
  -- À un niveau agressif, la guerre entre factions suit la règle d'IA0 (archétype, sans tirage) ; en Paisible, le
  -- caractère et le tirage.
  local bold = Tr.character("conqueror", { ambition = 1000, prudence = 600, agressivite = 1500, curiosite = 800, rancune = 1300,
    opportunisme = 1200, discipline = 800, ruse = 900 })
  local pv_n = { difficulty = "normal", tick = 0, anchor = 0 }
  local pv_p = { difficulty = "peaceful", tick = 0, anchor = 0 }
  check(S.attack(v({ personality = "conqueror", character = bold, garrison = 13, attack_jitter = 800, pvp = pv_n })) == nil,
    "Normal : seuil d'IA0 (13), tirage ignoré (10 envoyables : pas d'attaque)")
  check(S.attack(v({ personality = "conqueror", character = bold, garrison = 13, attack_jitter = 800, pvp = pv_p })) == 10,
    "Paisible : seuil tiré (13 × 0,8 = 10)")
  check(bold.war_keep < 0.2 + 1e-9 and S.attack(v({ personality = "conqueror", character = bold, garrison = 20, pvp = pv_p })) == 16,
    "Paisible : garnison gardée du caractère (bornée à 0,20 : 16 envoyables sur 20)")
  -- La guerre contre le JOUEUR n'est pas touchée par le tirage.
  local pv = { difficulty = "normal", tick = 40 * 3600, anchor = 0, declared = true, sent_player = 0, sent_total = 0, player_groups = 0 }
  local d1 = S.decide(v({ personality = "conqueror", garrison = 40, pvp = pv, player = { score = 4, defense = 8, reachable = true } }))
  local d2 = S.decide(v({ personality = "conqueror", garrison = 40, attack_jitter = 1200, pvp = pv, player = { score = 4, defense = 8, reachable = true } }))
  check(d1.attack and d2.attack and d1.attack.target == "player" and d1.attack.count == d2.attack.count, "attaque contre le joueur identique avec ou sans tirage")
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
local function logs(pattern)
  local out = {}
  for _, l in ipairs(W().logs) do if l:find(pattern, 1, true) then out[#out + 1] = l end end
  return out
end
local function start(seed)
  M.new_game({ seed = seed, patches = patches(), p_busy = 0.02, p_nopath = 0.02, p_lost = 0.005 })
  M.command("fo-war", "start 4 100 10 320")
  return global.fo.war
end
local function digest()
  local parts = {}
  for _, f in ipairs(global.fo.war.factions) do
    parts[#parts + 1] = table.concat({ f.key, f.personality, Tr.describe(f.traits), tostring(f.attack_jitter),
      tostring(f.rng and f.rng.state), f.outposts_count, f.soldiers_count, f.stats.attacks, f.tech }, "|")
  end
  return table.concat(parts, "\n")
end

section("Moteur simulé : guerre lancée sur une graine")
local seedA, seedB = 20261020, 123456789
local war = start(seedA)
do
  local expect = Tr.personalities(seedA, 4)
  local ok_p, ok_t = true, true
  for i, f in ipairs(war.factions) do
    if f.personality ~= expect[i] then ok_p = false end
    local _, t = Tr.found(seedA, i, expect[i])
    if Tr.describe(t) ~= Tr.describe(f.traits) or f.traits_origin ~= "graine" then ok_t = false end
  end
  check(ok_p, "personnalités = répartition de la graine (" .. table.concat(expect, ", ") .. ")")
  check(ok_t, "traits = tirage pur de la graine, origine « graine »")
  local fl = logs("[FO-STRAT] fondation")
  check(#fl == 4 and fl[1]:find("origine graine", 1, true) and fl[1]:find("agressivite=", 1, true), "4 lignes « [FO-STRAT] fondation » avec les traits")
end
local ok_run = pcall(M.run_ticks, 12 * 3600)
check(ok_run, "12 min de guerre sans erreur")
local digestA = digest()
do
  local shapes = logs("[FO-SHAPE]")
  check(#shapes == 8, "8 lignes « [FO-SHAPE] » en 12 min (une par faction à la 1re seconde, puis à 10 min) : " .. #shapes)
  check(shapes[1] and shapes[1]:find("batiments", 1, true) and shapes[1]:find("cov", 1, true) and shapes[1]:find("avant-postes", 1, true),
    "ligne de forme : bâtiments, covariance, avant-postes")
  -- Énumération par les listes de la faction = recherche de zone (même lignes de forme, sauf le coût).
  local J = require("script.faction.journal")
  local same = true
  for _, f in ipairs(war.factions) do
    local before = #W().logs
    J.shape(f, W().surface, game.tick)
    J.shape(f, W().surface, game.tick, true)
    local a, b = W().logs[before + 1], W().logs[before + 2]
    if not (a and b and a:gsub("^.-%[FO%-SHAPE%]", "") == b:gsub("^.-%[FO%-SHAPE%]", "")) then
      same = false
      print("  listes : " .. tostring(a))
      print("  zone   : " .. tostring(b))
    end
  end
  check(same, "forme : listes de la faction = recherche de zone (4 factions, 12 min)")
  local attacks = 0
  for _, f in ipairs(war.factions) do attacks = attacks + f.stats.attacks end
  check(#logs("[FO-STRAT] attaque") == attacks, string.format("une ligne « [FO-STRAT] attaque » par groupe lancé (%d)", attacks))
end

section("Moteur simulé : même graine, même partie ; autre graine, autre caractère")
do
  start(seedA)
  pcall(M.run_ticks, 12 * 3600)
  check(digest() == digestA, "même graine : mêmes caractères, mêmes tirages, même partie (12 min)")
  start(seedB)
  local expect = Tr.personalities(seedB, 4)
  local diff = false
  for i, f in ipairs(global.fo.war.factions) do
    if f.personality ~= Tr.personalities(seedA, 4)[i] or Tr.describe(f.traits) ~= Tr.describe(select(2, Tr.found(seedA, i, f.personality))) then diff = true end
    check(f.personality == expect[i], "graine B : faction " .. i .. " " .. f.personality)
  end
  check(diff, "graine B : caractères différents de la graine A")
end

section("Moteur simulé : partie existante (avant IA2-0)")
do
  start(seedA)
  pcall(M.run_ticks, 2 * 3600)
  -- Sauvegarde d'avant IA2-0 : personnalité de la couleur, aucun trait.
  for i, f in ipairs(global.fo.war.factions) do
    f.personality = F.factions[i].personality
    f.traits, f.rng, f.traits_origin, f.attack_jitter = nil, nil, nil, nil
  end
  local saved = M.deepcopy_global(global)
  M.load_mod()
  _G.global = saved
  local ok_load = pcall(function() W().on_load() end)
  check(ok_load, "rechargement sans erreur")
  local ok = pcall(M.run_ticks, 600)
  check(ok, "la guerre continue")
  local kept, drawn = true, true
  local first = {}
  for i, f in ipairs(global.fo.war.factions) do
    if f.personality ~= F.factions[i].personality then kept = false end
    local _, t = Tr.found(seedA, i, F.factions[i].personality)
    if f.traits_origin ~= "migration" or Tr.describe(f.traits) ~= Tr.describe(t) then drawn = false end
    first[i] = Tr.describe(f.traits)
  end
  check(kept, "personnalité de la sauvegarde gardée (couleur)")
  check(drawn, "traits tirés une fois de la graine autour de cette personnalité, origine « migration »")
  check(#logs("origine migration") == 4, "4 lignes de fondation « migration »")
  local saved2 = M.deepcopy_global(global)
  M.load_mod()
  _G.global = saved2
  pcall(function() W().on_load() end)
  pcall(M.run_ticks, 3 * 3600)
  local stable = true
  for i, f in ipairs(global.fo.war.factions) do
    if Tr.describe(f.traits) ~= first[i] or f.traits_origin ~= "migration" then stable = false end
  end
  check(stable, "caractère stable après un second rechargement et 3 min")
end

section("Octants sans trigonométrie")
do
  local J = require("script.faction.journal")
  local cases = { { 10, 0, 0 }, { 10, 10, 1 }, { 0, 10, 2 }, { -10, 10, 3 }, { -10, 0, 4 }, { -10, -10, 5 }, { 0, -10, 6 },
    { 10, -10, 7 }, { 10, 4, 0 }, { 10, 4.2, 1 }, { 4, 10, 2 }, { 0, 0, -1 } }
  local ok = true
  for _, c in ipairs(cases) do if J.octant(c[1], c[2]) ~= c[3] then ok = false; print("  octant", c[1], c[2], J.octant(c[1], c[2])) end end
  check(ok, "octants : 8 directions, bornes à 22,5° (tan = 0,4142), vecteur nul")
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
