--[[
  Tests hors-jeu du PvP et des niveaux de difficulté (lot IA0, OBJECTIFS.md C4), moteur simulé.
  Usage, depuis la racine du mod :   lua5.2 tests/pvp_test.lua

  Vérifie :
    1. le réglage (étape settings) et les traductions FR/EN ;
    2. les règles pures (shared/faction/strategy.lua) : paramètres monotones, grâce, préavis, déclaration,
       provocation, trêve, règle du déficit, coalition, intervalle, défense, équivalence avec la décision
       d'avant IA0 en « Paisible » ;
    3. une campagne pure de 180 min par niveau et par personnalité, dans 4 configurations (joueur non
       leader, joueur leader, leader défendu, gros leader) : première attaque, nombre, taille, part des
       forces, attaques contre la rivale (mesures chiffrées imprimées, ordre STRICT exigé partout) ;
    4. le runtime sur le moteur simulé (les tourelles du joueur tuent les attaquants : option
       turrets_kill) : base témoin attaquée en Normal après la grâce et jamais en Paisible, légitime
       défense (abattre un attaquant n'est pas une provocation), Difficile et Impitoyable plus tôt / plus
       souvent / plus nombreux, changement de réglage en cours de partie (Paisible, puis Difficile ; Facile
       puis Impitoyable avec préavis garanti), interface distante, sauvegarde et rechargement, partie
       continue = partie rechargée, sauvegarde d'avant IA0 (hostilité héritée), déterminisme, coût borné
       du repérage, coexistence défense de tours.
    Lot IA0b (base défendue) : rapport de force par niveau et personnalité, siège, dissuasion, plancher des
    attaques suivantes, assaut coordonné (Difficile, Impitoyable ; cible commune, jamais sous la taille
    minimale), taille minimale contre le joueur plafonnée par l'armée visée, fin de l'impasse de la règle du
    déficit (rival_wait), guerre ENTRE factions identique à une copie figée de S.attack d'IA0 ; campagne sur
    11 configurations (dont 5 bases défendues : 2, 3 et 6 tourelles en tech 0, 8 et 12 tourelles en tech 2,
    et 2 configurations avec une rivale de défense 30) avec l'armée visée du planificateur ; partie pure à
    4 factions (assaut coordonné) ; moteur simulé : 12 tourelles en Normal (4 factions, 60 min), 6 tourelles
    en Impitoyable (assaut coordonné), ordre strict des 4 niveaux agressifs.
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function W() return M.world() end

local F = require("shared.faction.config")
local S = require("shared.faction.strategy")
local Tr = require("shared.faction.traits") -- lot IA2-0
local A = require("shared.faction.adversaire") -- lot IA2-c
local LEVELS = F.pvp_order

-- Copie FIGÉE de S.attack au lot IA0 (commit 4240248), constantes comprises : la guerre ENTRE factions (et donc
-- « Paisible ») ne doit pas changer au lot IA0b. Ne pas la mettre à jour avec le code : c'est la référence.
local IA0_P = { conqueror = { 1.5, 0.20 }, technocrat = { 0.8, 0.35 }, builder = { 0.7, 0.40 }, balanced = { 1.0, 0.30 } }
local function ia0_attack(v)
  local P = IA0_P[v.personality] or IA0_P.balanced
  local s = v.tech >= 2 and { 450, 80, 120 } or v.tech >= 1 and { 600, 14, 10 } or { 200, 8, 20 } -- PV, dégâts, cadence
  local strength = (s[2] / s[3] * s[1]) / (8 / 20 * 200) * 1.1 ^ v.tech * (1 + 0.10 * (v.upgrades or 0))
  local count = math.floor(v.garrison * (1 - P[2]))
  local min_size = math.floor(20 / P[1])
  local needed = (v.enemy_defense or 0) * 1.3
  if v.can_attack ~= false and count >= min_size and count * strength >= needed then return count end
  return nil
end
local AGGRO = { "easy", "normal", "hard", "merciless" }
local PERS = { "conqueror", "balanced", "technocrat", "builder" }
local MIN = 3600

---------------------------------------------------------------------------------------------------
section("Réglage (étape settings)")
do
  local declared = {}
  _G.data = { extend = function(_, list) for _, p in ipairs(list) do declared[#declared + 1] = p end end }
  package.loaded["settings.faction"] = nil
  local ok, err = pcall(dofile, "settings.lua")
  check(ok, "settings.lua + settings/faction.lua s'exécutent (" .. tostring(err) .. ")")
  local byname, dup = {}, false
  for _, p in ipairs(declared) do
    if byname[p.name] then dup = true end
    byname[p.name] = p
  end
  check(not dup, "aucun nom de réglage en double")
  local s = byname["fo-pvp-difficulty"]
  check(s and s.type == "string-setting" and s.setting_type == "runtime-global", "fo-pvp-difficulty : chaîne, runtime-global")
  check(s and s.default_value == "normal", "défaut : Normal (réponse « oui » à Q4)")
  local same = s and #s.allowed_values == #LEVELS
  for i, v in ipairs(LEVELS) do same = same and s.allowed_values[i] == v and F.pvp[v] ~= nil end
  check(same, "valeurs : peaceful, easy, normal, hard, merciless (source unique : shared/faction/config.lua)")
  _G.data = nil
end

---------------------------------------------------------------------------------------------------
section("Traductions FR et EN")
do
  local function parse(path)
    local keys, section_name = {}, nil
    local fh = io.open(path, "r")
    if not fh then return nil end
    for line in fh:lines() do
      local sec = line:match("^%[([^%]]+)%]")
      if sec then section_name = sec
      else
        local k, v = line:match("^([^=;#]+)=(.*)$")
        if k and section_name then keys[section_name .. "." .. k] = v end
      end
    end
    fh:close()
    return keys
  end
  local fr, en = parse("locale/fr/ia0.cfg"), parse("locale/en/ia0.cfg")
  check(fr ~= nil and en ~= nil, "locale/fr/ia0.cfg et locale/en/ia0.cfg présents")
  fr, en = fr or {}, en or {}
  local need = { "mod-setting-name.fo-pvp-difficulty", "mod-setting-description.fo-pvp-difficulty" }
  for _, v in ipairs(LEVELS) do
    need[#need + 1] = "string-mod-setting.fo-pvp-difficulty-" .. v
    need[#need + 1] = "fo-pvp.level-" .. v
  end
  -- Toutes les clés « fo-pvp.* » employées par le code
  local src = io.open("script/faction/pvp.lua"):read("*a")
  for k in src:gmatch('"(fo%-pvp%.[%w%-]+)"') do
    if not k:match("%-$") then need[#need + 1] = k end -- "fo-pvp.level-" .. niveau : listé ci-dessus
  end
  local missing = {}
  for _, k in ipairs(need) do
    if not fr[k] then missing[#missing + 1] = "fr:" .. k end
    if not en[k] then missing[#missing + 1] = "en:" .. k end
  end
  check(#missing == 0, "clés présentes (" .. table.concat(missing, ", ") .. ")")
  local diff = {}
  for k, v in pairs(fr) do
    if not en[k] then diff[#diff + 1] = "en manque " .. k end
    local function params(s) local n = 0 for i = 1, 5 do if s:find("__" .. i .. "__", 1, true) then n = i end end return n end
    if en[k] and params(v) ~= params(en[k]) then diff[#diff + 1] = "paramètres " .. k end
  end
  for k in pairs(en) do if not fr[k] then diff[#diff + 1] = "fr manque " .. k end end
  table.sort(diff)
  check(#diff == 0, "mêmes clés et mêmes paramètres en FR et EN (" .. table.concat(diff, ", ") .. ")")
  -- Pas de doublon avec le fichier commun
  local common = parse("locale/fr/factorio-overhaul.cfg") or {}
  local dups = {}
  for k in pairs(fr) do if common[k] then dups[#dups + 1] = k end end
  check(#dups == 0, "aucune clé en double avec factorio-overhaul.cfg (" .. table.concat(dups, ", ") .. ")")
end

---------------------------------------------------------------------------------------------------
section("Règles pures : paramètres par niveau")
check(S.grace_ticks("peaceful", "conqueror") == nil, "Paisible : aucune grâce (jamais d'attaque délibérée)")
for _, p in ipairs(PERS) do
  local ok_g, ok_c, ok_n, ok_m, ok_s = true, true, true, true, true
  for i = 2, #AGGRO do
    local a, b = AGGRO[i - 1], AGGRO[i]
    ok_g = ok_g and S.grace_ticks(a, p) > S.grace_ticks(b, p)
    ok_c = ok_c and S.cooldown_ticks(a) > S.cooldown_ticks(b)
    ok_n = ok_n and S.player_count(a, p, 40) < S.player_count(b, p, 40)
    ok_m = ok_m and S.player_goal(a, p) < S.player_goal(b, p)
    ok_s = ok_s and F.pvp[a].share < F.pvp[b].share
  end
  check(ok_g, p .. " : grâce strictement décroissante de Facile à Impitoyable")
  check(ok_c, p .. " : intervalle entre attaques strictement décroissant")
  check(ok_n, p .. " : effectif envoyé (garnison 40) strictement croissant")
  check(ok_m, p .. " : taille visée (attaques suivantes) strictement croissante")
  check(ok_s, p .. " : part des forces visée strictement croissante")
  -- Normal = la logique contre une faction rivale (même garnison gardée, même seuil).
  local Pp = F.personalities[p]
  check(S.player_count("normal", p, 40) == math.floor(40 * (1 - Pp.keep))
    and S.player_min_size("normal", p) == math.floor(F.military.attack_base / Pp.aggression),
    p .. " : Normal = même garnison gardée et même seuil que contre une faction")
end
check(S.grace_ticks("normal", "conqueror") == 20 * MIN and S.grace_ticks("normal", "balanced") == 30 * MIN,
  "Normal : grâce 20 min (conquérant), 30 min (équilibré)")
print("  grâce (min) par niveau et personnalité :")
for _, lv in ipairs(AGGRO) do
  local parts = {}
  for _, p in ipairs(PERS) do parts[#parts + 1] = string.format("%s %.1f", p, S.grace_ticks(lv, p) / MIN) end
  print(string.format("    %-9s %s | intervalle %d min | part %.0f %% | envoyés (garnison 40, équilibré) %d | taille min / visée (équilibré) %d / %d | attente max %d min",
    lv, table.concat(parts, ", "), F.pvp[lv].cooldown_min, F.pvp[lv].share * 100,
    S.player_count(lv, "balanced", 40), S.player_min_size(lv, "balanced"), S.player_goal(lv, "balanced"), F.pvp[lv].save_min))
end

---------------------------------------------------------------------------------------------------
section("Règles pures : décision")
local function view(level, tick, o)
  o = o or {}
  local v = {
    personality = o.personality or "conqueror", tech = 0, upgrades = 0, garrison = o.garrison or 40,
    soldiers_max = 100, can_attack = o.can_attack ~= false, enemy_defense = o.enemy_defense or 10,
    rival = o.no_rival and nil or { id = 2, outposts = 4 }, own_outposts = o.own or 4, leader_outposts = o.leader or 4,
    pvp = {
      difficulty = level, tick = tick, anchor = o.anchor or 0, declared = o.declared or false,
      provoked = o.provoked or false, warned = o.warned or false, last_attack = o.last_attack,
      sent_player = o.sent_player or 0, sent_total = o.sent_total or 0, player_groups = o.groups or 0,
      due_since = o.due_since, grace_floor = o.grace_floor, rally_until = o.rally_until,
      last_rival = o.last_rival, rally_defense = o.rally_defense,
    },
    player = o.no_player and nil or { score = o.score or 4, defense = o.defense or 8, reachable = o.reachable ~= false },
  }
  if o.no_rival then v.rival = nil end
  return v
end

do -- Paisible : jamais d'attaque délibérée, même après 10 h, même avec une cible offerte
  local never = true
  for tick = 0, 600 * MIN, 300 do
    local a = S.decide(view("peaceful", tick, { no_rival = (tick % 600 == 0), garrison = 100, defense = 0 }))
    if a.declare or a.warn or (a.attack and a.attack.target == "player") then never = false end
  end
  check(never, "Paisible : ni préavis, ni déclaration, ni attaque contre le joueur en 10 h")
  local a = S.decide(view("peaceful", 5 * MIN, { provoked = true, no_rival = true, garrison = 100, defense = 0 }))
  check(not a.declare and a.attack == nil, "Paisible + provoqué : hostile mais aucune attaque délibérée (comportement d'avant IA0)")
  a = S.decide(view("peaceful", 5 * MIN, { declared = true, groups = 1 }))
  check(a.truce and a.recall, "Paisible : une faction déclarée par la difficulté rétablit la trêve et rappelle ses troupes")
  a = S.decide(view("peaceful", 5 * MIN, { declared = true, provoked = true }))
  check(not a.truce, "Paisible : une faction provoquée reste hostile")
end

do -- Normal : préavis à grâce - 2 min, déclaration à la fin de la grâce
  local g = S.grace_ticks("normal", "conqueror")
  local a = S.decide(view("normal", g - 2 * MIN - 1))
  check(not a.warn and not a.declare, "Normal : rien avant le préavis")
  a = S.decide(view("normal", g - 2 * MIN))
  check(a.warn == 2 and not a.declare, "Normal : préavis 2 min avant la fin de la grâce")
  a = S.decide(view("normal", g - 1, { warned = true }))
  check(not a.declare and (a.attack == nil or a.attack.target ~= "player"), "Normal : aucune attaque contre le joueur pendant la grâce")
  a = S.decide(view("normal", g, { warned = true }))
  check(a.declare == "grace", "Normal : déclaration de guerre à la fin de la grâce")
  check(a.attack and a.attack.target == "player", "Normal : la première attaque après la déclaration vise le joueur (part due)")
  a = S.decide(view("normal", g, { anchor = 10 * MIN }))
  check(not a.declare, "la grâce part de l'ancre (changement de réglage, sauvegarde reprise)")
  a = S.decide(view("normal", 60, { provoked = true }))
  check(a.declare == "provoked", "Normal + provoqué : déclaration immédiate (fin de la grâce pour cette faction)")
  -- Préavis garanti après un changement de niveau : fin de grâce au plus tôt (grace_floor).
  local v2 = view("merciless", 15 * MIN, { grace_floor = 17 * MIN })
  a = S.decide(v2)
  check(a.warn == 2 and not a.declare, "grâce déjà écoulée mais fin au plus tôt dans 2 min : préavis, pas de déclaration")
  a = S.decide(view("merciless", 17 * MIN - 1, { grace_floor = 17 * MIN, warned = true }))
  check(not a.declare, "pas de déclaration avant la fin au plus tôt")
  a = S.decide(view("merciless", 17 * MIN, { grace_floor = 17 * MIN, warned = true }))
  check(a.declare == "grace", "déclaration à la fin au plus tôt")
  check(S.grace_end(0, 5, "normal", "conqueror") == 20 * MIN and S.grace_end(0, 30 * MIN, "normal", "conqueror") == 30 * MIN
    and S.grace_end(0, 30 * MIN, "peaceful", "conqueror") == nil, "S.grace_end : max(ancre + grâce, fin au plus tôt), nil en Paisible")
end

do -- Cible, part due, intervalle, défense, coalition
  local cd = S.cooldown_ticks("normal")
  local a = S.decide(view("normal", 40 * MIN, { declared = true, no_rival = true }))
  check(a.attack and a.attack.target == "player" and a.attack.count == 32, "sans rivale : le joueur, 32 soldats (garnison 40, conquérant)")
  a = S.decide(view("normal", 40 * MIN, { declared = true, sent_player = 20, sent_total = 20 }))
  check(a.attack and a.attack.target == 2, "part atteinte (20/20 > 40 %) : la rivale")
  a = S.decide(view("normal", 40 * MIN, { declared = true, sent_player = 20, sent_total = 50 }))
  check(a.attack and a.attack.target == "player", "part en retard (20/50 ≤ 40 %) : le joueur")
  a = S.decide(view("normal", 40 * MIN, { declared = true, last_attack = 40 * MIN - cd + 1, no_rival = true }))
  check(a.attack == nil, "intervalle non écoulé : pas d'attaque contre le joueur")
  a = S.decide(view("normal", 40 * MIN, { declared = true, last_attack = 40 * MIN - cd, no_rival = true }))
  check(a.attack and a.attack.target == "player", "intervalle écoulé : attaque")
  a = S.decide(view("normal", 40 * MIN, { declared = true, defense = 60 }))
  check(a.attack == nil and a.plan == "siege" and a.need == 41 and a.due_since == 40 * MIN,
    "joueur trop défendu (besoin 41 = 0,9 × 0,75 × 60 > 32 disponibles) : SIÈGE, la faction garde ses soldats (attente démarrée)")
  a = S.decide(view("normal", 40 * MIN, { declared = true, defense = 60, due_since = 37 * MIN }))
  check(a.attack == nil and a.plan == "siege",
    "après 3 min (save_min), toujours en siège : pas de repli sur la rivale (avant IA0b : repli, la garnison ne s'accumulait jamais)")
  a = S.decide(view("normal", 40 * MIN, { declared = true, defense = 60, due_since = 20 * MIN }))
  check(a.attack and a.attack.target == 2 and a.plan == "fallback" and a.due_since == false,
    "siège de 20 min expiré : répit, attaque contre la rivale, puis nouveau siège (attente effacée)")
  a = S.decide(view("normal", 40 * MIN, { declared = true, defense = 24 }))
  check(a.attack and a.attack.target == "player" and a.need == 17, "besoin 17 = 0,9 × 0,75 × 24 ≤ 32 : attaque contre le joueur")
  a = S.decide(view("normal", 40 * MIN, { declared = true, garrison = 10, no_rival = true }))
  check(a.attack == nil, "garnison trop petite (8 < 13) : pas d'attaque")
  a = S.decide(view("normal", 40 * MIN, { declared = true, reachable = false, no_rival = true }))
  check(a.attack == nil, "joueur inaccessible : pas d'attaque")
  local v = view("normal", 40 * MIN, { declared = true, score = 10, own = 3, leader = 4, sent_player = 50, sent_total = 100 })
  check(S.player_is_leader(v) and math.abs(S.player_share(v, "normal") - 0.55) < 1e-9,
    "coalition : joueur leader (10 secteurs = 5 avant-postes > 1,3 × 3), part 0,40 + 0,25 × 0,60 = 55 %")
  check(S.decide(v).attack.target == "player", "coalition : 50/100 ≤ 55 % : le joueur")
  check(not S.player_is_leader(view("normal", 0, { score = 8, own = 4 })), "unité commune : 8 secteurs = 4 avant-postes, pas leader face à 4")
  local ok_order, min_left = true, 1
  for i, lv in ipairs(AGGRO) do
    local sh = S.player_share(view(lv, 0, { score = 40, own = 3 }), lv)
    if i > 1 and not (sh > S.player_share(view(AGGRO[i - 1], 0, { score = 40, own = 3 }), AGGRO[i - 1])) then ok_order = false end
    if 1 - sh < min_left then min_left = 1 - sh end
  end
  check(ok_order and min_left >= 0.075 - 1e-9,
    string.format("coalition : parts strictement croissantes de Facile à Impitoyable, au moins %.1f %% laissés aux rivales", min_left * 100))
  -- Accumulation : après la première attaque, la faction vise une taille plus grande.
  local goal = S.player_goal("hard", "conqueror")
  local need = S.player_need(view("hard", 0), "hard")
  a = S.decide(view("hard", 40 * MIN, { declared = true, sent_player = 15, sent_total = 30, garrison = 15 }))
  check(goal == 18 and need == 11 and a.attack == nil and a.plan == "save",
    "Difficile : 13 soldats disponibles < 18 visés : la faction garde ses soldats (pas d'attaque contre la rivale)")
  a = S.decide(view("hard", 40 * MIN, { declared = true, sent_player = 15, sent_total = 30, garrison = 15, due_since = 35 * MIN }))
  check(a.attack == nil and a.plan == "save" and S.player_floor(view("hard", 0), "hard", 11, 18) == 14,
    "Difficile : après 5 min d'attente, 13 < plancher 14 (0,75 × 18) : la faction attend encore")
  a = S.decide(view("hard", 40 * MIN, { declared = true, sent_player = 15, sent_total = 30, garrison = 16, due_since = 35 * MIN }))
  check(a.attack and a.attack.target == "player" and a.attack.count == 14, "Difficile : après 5 min d'attente, attaque avec 14 (plancher)")
  a = S.decide(view("hard", 40 * MIN, { declared = true, sent_player = 15, sent_total = 30, garrison = 21 }))
  check(a.attack and a.attack.target == "player" and a.attack.count == 18, "Difficile : taille visée atteinte (18) : attaque aussitôt")
  a = S.decide(view("hard", 40 * MIN, { declared = true, sent_player = 0, sent_total = 0, garrison = 13 }))
  check(a.attack and a.attack.target == "player" and a.attack.count == 11, "première attaque après la déclaration : dès le minimum (11)")
  a = S.decide(view("normal", 40 * MIN, { declared = true, sent_player = 20, sent_total = 20, due_since = 30 * MIN }))
  check(a.due_since == false, "joueur plus dû : attente effacée")
  for _, lv in ipairs(AGGRO) do
    local aa = S.decide(view(lv, 600 * MIN, { declared = true, no_rival = true, garrison = 60, personality = "balanced" }))
    check(aa.attack and aa.attack.count == S.player_count(lv, "balanced", 60), lv .. " : effectif = player_count (" .. (aa.attack and aa.attack.count or 0) .. ")")
  end
end

---------------------------------------------------------------------------------------------------
section("Règles pures : base défendue (lot IA0b)")
do
  local a
  -- Rapport de force exigé : plus prudent en Facile, plus téméraire en Impitoyable ; le conquérant le plus
  -- téméraire à chaque niveau.
  local ok_lv, ok_p = true, true
  for _, p in ipairs(PERS) do
    for i = 2, #AGGRO do
      if not (S.player_ratio(AGGRO[i - 1], p) > S.player_ratio(AGGRO[i], p)) then ok_lv = false end
    end
  end
  for _, lv in ipairs(AGGRO) do
    for _, p in ipairs(PERS) do
      if p ~= "conqueror" and not (S.player_ratio(lv, "conqueror") < S.player_ratio(lv, p)) then ok_p = false end
    end
  end
  check(ok_lv, "rapport de force exigé strictement décroissant de Facile à Impitoyable (4 personnalités)")
  check(ok_p, "le conquérant est le plus téméraire à chaque niveau")
  print("  rapport de force exigé (× défense estimée) :")
  for _, lv in ipairs(AGGRO) do
    local parts = {}
    for _, p in ipairs(PERS) do parts[#parts + 1] = string.format("%s %.3f", p, S.player_ratio(lv, p)) end
    print(string.format("    %-9s %s | siège %d min, plafond %.0f %% de l'armée visée | assaut coordonné %d min, jointe à %.0f %% du besoin",
      lv, table.concat(parts, ", "), F.pvp[lv].siege_min, F.pvp[lv].siege_cap * 100, F.pvp[lv].rally_min, F.pvp[lv].join_frac * 100))
  end
  -- Avant IA0b : 1,3 partout ; 3 tourelles (24) en tech 0 exigeaient 32 soldats envoyés.
  check(S.player_need(view("normal", 0, { defense = 24 }), "normal") == 17 and S.player_need(view("easy", 0, { defense = 24 }), "easy") == 27,
    "3 tourelles en tech 0, conquérant : besoin 17 en Normal (avant IA0b : 32), 27 en Facile")

  -- Taille minimale plafonnée par l'armée visée : le bâtisseur peut enfin attaquer (joueur ET rivale).
  check(S.army_target("builder", 100) == 40 and S.army_target("conqueror", 100) == 80, "armée visée = planificateur (bâtisseur 40, conquérant 80)")
  check(S.player_min_size("normal", "builder") == 28 and S.player_min_size("normal", "builder", 100) == 21,
    "bâtisseur, Normal : taille minimale 28 ramenée à 21 (0,9 × 24 envoyables avec son armée visée)")
  local same = true
  for _, p in ipairs({ "conqueror", "balanced", "technocrat" }) do
    for _, lv in ipairs(AGGRO) do
      if S.player_min_size(lv, p, 100) ~= S.player_min_size(lv, p) then same = false end
    end
  end
  check(same, "conquérant, équilibré, technocrate : taille minimale inchangée (le plafond ne lie pas)")
  local vb = view("peaceful", 0, { personality = "builder", garrison = 40, enemy_defense = 10 })
  check(S.attack(vb) == nil, "bâtisseur, armée visée au complet (40) : toujours aucune attaque contre sa rivale (24 < 28 : défaut antérieur E21, hors contrat IA0b)")
  local unchanged, cases = true, 0
  for _, p in ipairs(PERS) do
    for tech = 0, 2 do
      for _, up in ipairs({ 0, 2 }) do
        for g = 0, 100 do
          for _, def in ipairs({ 0, 5, 10, 20, 30, 40, 80, math.huge }) do
            for _, smax in ipairs({ 100, 60, false }) do
              local v = view("peaceful", 0, { personality = p, garrison = g, enemy_defense = def, can_attack = (g % 7 ~= 0) })
              v.tech, v.upgrades, v.soldiers_max = tech, up, smax or nil
              cases = cases + 1
              if S.attack(v) ~= ia0_attack(v) then unchanged = false end
            end
          end
        end
      end
    end
  end
  check(unchanged, "guerre entre factions : S.attack identique à la copie figée d'IA0 (" .. cases .. " cas : 4 personnalités, tech 0 à 2, armée max 60, 100 ou absente)")

  -- Siège faisable ou dissuasion (plafond), et Facile qui ne fait jamais de siège.
  for _, p in ipairs(PERS) do
    local need = S.player_need(view("normal", 0, { personality = p, defense = 24 }), "normal")
    check(S.player_garrison_for("normal", p, need) <= S.siege_cap("normal", p, 100),
      string.format("Normal, %s : 3 tourelles en tech 0, siège faisable (garnison %d ≤ plafond %d)", p,
        S.player_garrison_for("normal", p, need), S.siege_cap("normal", p, 100)))
  end
  a = S.decide(view("normal", 40 * MIN, { declared = true, defense = 200 }))
  check(a.plan == "deterred" and a.attack and a.attack.target == 2 and a.due_since == 40 * MIN,
    "défense 200 (25 tourelles) : garnison nécessaire > plafond, faction DISSUADÉE (rivale), sans siège")
  a = S.decide(view("easy", 60 * MIN, { declared = true, defense = 24, garrison = 35 }))
  check(a.plan == "fallback" and a.attack and a.attack.target == 2, "Facile : jamais de siège (repli immédiat sur la rivale, besoin 27 > 24 disponibles)")
  check(S.player_garrison_for("normal", "conqueror", 17) == 22 and S.player_garrison_for("merciless", "conqueror", 0) == 0,
    "garnison minimale pour envoyer n soldats (conquérant, Normal : 22 pour 17)")

  -- Assaut coordonné : Difficile et Impitoyable seulement, dans la fenêtre ouverte par une autre faction.
  local function siege_view(lv, garrison, rally_until)
    return view(lv, 40 * MIN, { declared = true, defense = 48, garrison = garrison, due_since = 38 * MIN, rally_until = rally_until })
  end
  local vh = siege_view("hard", 20)
  local need_h = S.player_need(vh, "hard")
  a = S.decide(vh)
  check(a.plan == "siege" and a.attack == nil and need_h == 24 and S.join_need(vh, "hard", need_h) == 20,
    "Difficile, 6 tourelles : 18 disponibles < besoin 24, siège (jointe possible dès 20)")
  a = S.decide(siege_view("hard", 23, 41 * MIN))
  check(a.plan == "join" and a.attack and a.attack.target == "player" and a.attack.join and a.attack.count == 20 and not a.rally,
    "Difficile, fenêtre ouverte : 20 disponibles ≥ 0,8 × 24, la faction se joint à l'assaut (sans rouvrir la fenêtre)")
  -- Cible commune : le besoin de la jointe se calcule contre la défense de la cible de la fenêtre.
  local vr = siege_view("hard", 15, 41 * MIN)
  vr.pvp.rally_defense = 24
  a = S.decide(vr)
  check(a.plan == "join" and a.need == 12 and a.attack and a.attack.count == 13 and S.join_need(vr, "hard", 12) == 11,
    "cible commune : 13 disponibles < 24 (défense 48 chez soi), mais ≥ 11 (taille minimale ; 0,8 × 12 = 10, 12 = besoin contre la cible de la fenêtre, défense 24) : jointe")
  -- Jamais sous la taille minimale du niveau (vérificateur : jointes de 7 soldats pour une taille de 10).
  local vm = view("merciless", 40 * MIN, { declared = true, defense = 8, garrison = 9, due_since = 38 * MIN, rally_until = 41 * MIN, rally_defense = 8 })
  a = S.decide(vm)
  check(S.player_need(vm, "merciless") == 10 and S.join_need(vm, "merciless", 10) == 10 and a.plan ~= "join" and a.attack == nil,
    "Impitoyable, 1 tourelle : 8 disponibles, besoin 10 = taille minimale : pas de jointe (avant : jointe dès 7)")
  local ok_min = true
  for _, lv in ipairs({ "hard", "merciless" }) do
    for _, p in ipairs(PERS) do
      for def = 0, 200, 4 do
        local vv = view(lv, 0, { personality = p, defense = def })
        if S.join_need(vv, lv, S.player_need(vv, lv)) < S.player_min_size(lv, p, 100) then ok_min = false end
      end
    end
  end
  check(ok_min, "jointe jamais sous la taille minimale du niveau (Difficile, Impitoyable, 4 personnalités, défense 0 à 200)")
  -- Plancher atteint : la faction part avec l'assaut ouvert au lieu d'attendre la fin de save_min.
  local vf = view("hard", 40 * MIN, { declared = true, sent_player = 15, sent_total = 30, garrison = 16, due_since = 39 * MIN, rally_until = 41 * MIN, defense = 8 })
  a = S.decide(vf)
  check(a.plan == "join" and a.attack and a.attack.count == 14,
    "Difficile, 14 disponibles = plancher, 1 min d'attente sur 5 : la faction se joint à l'assaut ouvert")
  vf.pvp.rally_until = nil
  a = S.decide(vf)
  check(a.plan == "save" and a.attack == nil, "même cas sans fenêtre : elle attend la fin de save_min")
  a = S.decide(siege_view("hard", 23, 40 * MIN))
  check(a.plan == "siege" and a.attack == nil, "fenêtre refermée : siège")
  a = S.decide(siege_view("hard", 21, 41 * MIN))
  check(a.plan == "siege" and a.attack == nil, "fenêtre ouverte mais 18 < 20 : siège (pas de jointe suicidaire)")
  a = S.decide(siege_view("normal", 40, 41 * MIN))
  check(a.plan ~= "join" and not (a.attack and a.attack.join), "Normal : jamais d'assaut coordonné")
  a = S.decide(view("hard", 40 * MIN, { declared = true, garrison = 40, defense = 8 }))
  check(a.attack and a.attack.target == "player" and a.rally, "Difficile : une attaque prête ouvre la fenêtre d'assaut coordonné")
  a = S.decide(view("normal", 40 * MIN, { declared = true, garrison = 40, defense = 8 }))
  check(a.attack and a.attack.target == "player" and not a.rally, "Normal : une attaque n'ouvre aucune fenêtre")
  check(S.rally_ticks("hard") == 2 * MIN and S.rally_ticks("merciless") == 3 * MIN and S.rally_ticks("normal") == 0,
    "fenêtre : 2 min (Difficile), 3 min (Impitoyable), aucune ailleurs")
  local self_join = true
  for _, lv in ipairs(AGGRO) do
    if S.rally_ticks(lv) > S.cooldown_ticks(lv) then self_join = false end
  end
  check(self_join, "fenêtre ≤ intervalle entre attaques : une faction ne peut pas se joindre à sa propre fenêtre")

  -- Fin de l'impasse de la règle du déficit. Après une attaque contre le joueur, le déficit ne se comble
  -- qu'en attaquant la rivale ; une faction qui ne le peut pas (bâtisseur : 24 envoyables < 28) n'attaquait
  -- plus jamais le joueur (vérificateur : 1 attaque en 180 min).
  local wait = S.rival_wait_ticks("normal")
  check(wait == F.pvp_rules.rival_wait * S.cooldown_ticks("normal") and S.rival_wait_ticks("easy") > wait
    and wait > S.rival_wait_ticks("hard") and S.rival_wait_ticks("hard") > S.rival_wait_ticks("merciless"),
    string.format("attente avant de se retourner contre le joueur : %d × l'intervalle (Normal %d min), décroissante de Facile à Impitoyable",
      F.pvp_rules.rival_wait, wait / MIN))
  local t0 = 60 * MIN
  local function vi(tick, o)
    o = o or {}
    return view("normal", tick, { personality = "builder", declared = true, garrison = 40, defense = 8, sent_player = 24,
      sent_total = 24, last_attack = t0, last_rival = o.last_rival })
  end
  check(S.attack(vi(t0)) == nil, "bâtisseur : rivale inattaquable (24 < 28)")
  a = S.decide(vi(t0 + S.cooldown_ticks("normal")))
  check(a.attack == nil and a.plan == nil and a.due_since == nil, "intervalle écoulé, déficit comblé (24/24 > 40 %) : joueur pas dû, rien à lancer")
  a = S.decide(vi(t0 + wait - 300))
  check(a.plan == nil, "pas encore " .. wait / MIN .. " min sans rien lancer : joueur toujours pas dû")
  a = S.decide(vi(t0 + wait))
  check(a.plan ~= nil and a.due_since == t0 + wait, "rien lancé depuis " .. wait / MIN .. " min : le joueur redevient dû (fin de l'impasse)")
  a = S.decide(vi(t0 + wait, { last_rival = t0 + 10 * MIN }))
  check(a.plan == nil, "une attaque contre la rivale depuis relance l'attente")
  check(not S.rival_stalled(view("normal", 600 * MIN, { declared = true }), "normal"),
    "aucune attaque depuis la déclaration : pas d'impasse (le déficit rend déjà le joueur dû)")
end

do -- Équivalence avec la décision d'avant IA0 quand le joueur n'est pas visé
  local same = true
  for _, p in ipairs(PERS) do
    for g = 0, 100, 3 do
      for _, def in ipairs({ 0, 5, 10, 20, 40, 80, math.huge }) do
        local v = view("peaceful", 100 * MIN, { personality = p, garrison = g, enemy_defense = def })
        local old = ia0_attack(v)
        local a = S.decide(v)
        local new = a.attack and a.attack.count
        if old ~= new or (a.attack and a.attack.target ~= 2) then same = false end
      end
    end
  end
  check(same, "Paisible : décision identique à la copie figée de S.attack d'IA0 (4 personnalités × 34 garnisons × 7 défenses)")
end

---------------------------------------------------------------------------------------------------
section("Campagne pure de 180 min (mesures par niveau)")
-- Modèle : chaque faction gagne +1 soldat toutes les 45 s jusqu'à son ARMÉE VISÉE (lot IA0b : même plafond
-- que le planificateur, T.army_share × 100 : conquérant 80, équilibré 60, technocrate 45, bâtisseur 40 ;
-- avant IA0b, plafond 100 pour tous), pense toutes les 5 s, a une rivale toujours disponible (défense 10,
-- ou cfg.rdef ; `own` avant-postes comme la faction). Un groupe envoyé revient 5 min plus tard avec 60 % de
-- survivants. La décision reçoit la dernière attaque contre la rivale (last_rival) et la défense de la cible
-- de la fenêtre d'assaut coordonné (rally_defense = défense de la base, cible commune).
-- Configurations (cfg) : secteurs du joueur (score), avant-postes de la faction (own), défense de la cible
-- joueur (defense = 8 × tourelles), niveau technologique (tech). Les configurations 5 à 8 sont les bases
-- DÉFENDUES du lot IA0b. Une partie à plusieurs factions (game_campaign) partage la fenêtre d'assaut
-- coordonné (pensées étalées de 75 ticks d'une faction à l'autre).
local T = require("shared.team.config")
local CONFIGS = {
  { name = "joueur non leader (4 secteurs, 1 tourelle, tech 0)", score = 4, own = 4, defense = 8, tech = 0, leader = false },
  { name = "joueur leader (12 secteurs contre 4 avant-postes, 1 tourelle, tech 0)", score = 12, own = 4, defense = 8, tech = 0, leader = true },
  { name = "leader défendu (12 secteurs, 3 tourelles, tech 1)", score = 12, own = 4, defense = 24, tech = 1, leader = true },
  { name = "gros leader (40 secteurs contre 7 avant-postes, 6 tourelles, tech 2)", score = 40, own = 7, defense = 48, tech = 2, leader = true },
  -- Lot IA0b : bases défendues. Exigences : Normal attaque toute base de ≤ 3 tourelles en tech 0 (cfg 5) ;
  -- Difficile et Impitoyable attaquent aussi 6 tourelles en tech 0 (cfg 6) et 8 tourelles en tech 2 (cfg 7).
  { name = "base défendue (4 secteurs, 3 tourelles, tech 0)", score = 4, own = 4, defense = 24, tech = 0, leader = false,
    must = { normal = true, hard = true, merciless = true } },
  { name = "base défendue (6 secteurs, 6 tourelles, tech 0)", score = 6, own = 4, defense = 48, tech = 0, leader = false,
    must = { hard = true, merciless = true } },
  { name = "base défendue (12 secteurs contre 7 avant-postes, 8 tourelles, tech 2)", score = 12, own = 7, defense = 64, tech = 2, leader = false,
    must = { hard = true, merciless = true } },
  { name = "base défendue (20 secteurs contre 7 avant-postes, 12 tourelles, tech 2)", score = 20, own = 7, defense = 96, tech = 2, leader = true,
    must = {} },
  -- Correction IA0b (vérificateur) : seuil de Facile (2 tourelles en tech 0), et rivale plus forte (défense 30 :
  -- le technocrate et le bâtisseur ne peuvent plus l'attaquer ; avant la fin de l'impasse, ils n'attaquaient
  -- le joueur qu'une fois en 180 min). Avec une rivale de défense 30, l'ordre strict n'est PAS exigé (mesuré,
  -- imprimé : écarts connus sur la taille moyenne du conquérant) ; on exige les attaques et la fin de l'impasse.
  { name = "base défendue (4 secteurs, 2 tourelles, tech 0)", score = 4, own = 4, defense = 16, tech = 0, leader = false,
    must = { normal = true, hard = true, merciless = true } },
  { name = "rivale de défense 30 (4 secteurs, 1 tourelle, tech 0)", score = 4, own = 4, defense = 8, tech = 0, leader = false, rdef = 30,
    must = { normal = true, hard = true, merciless = true }, no_order = true, repeat_min = 2 },
  { name = "rivale de défense 30, base défendue (4 secteurs, 3 tourelles, tech 0)", score = 4, own = 4, defense = 24, tech = 0, leader = false,
    rdef = 30, must = { normal = true, hard = true, merciless = true }, no_order = true, repeat_min = 2 },
}
for i = 1, 4 do CONFIGS[i].must = { normal = true, hard = true, merciless = true } end

--- Partie pure : `pers_list` factions (une par personnalité), `minutes` minutes. opts.prod : ticks par
--- soldat produit (défaut 2700 = 45 s) ; opts.cap = false : ancien plafond (100 soldats pour tous).
local function game_campaign(level, pers_list, minutes, cfg, opts)
  cfg, opts = cfg or CONFIGS[1], opts or {}
  local prod = opts.prod or 2700
  local shared = { rally_until = nil, rallies = 0 }
  local fs = {}
  for i, pers in ipairs(pers_list) do
    fs[i] = {
      pers = pers, garrison = 0, total = 0, acc = 0, back = {}, offset = (i - 1) * 75,
      cap = opts.cap == false and 100 or math.floor(100 * (T.army_share[F.archetype_of(pers)] or 0.6)),
      fp = { declared = false, provoked = false, warned = false, sent_player = 0, sent_total = 0 },
      -- Lot IA2-0 : opts.jitter = graine : seuil des attaques entre factions tiré à ±20 % (flux de la faction),
      -- retiré après chaque attaque contre la rivale, comme en jeu (script/faction/character.lua).
      stream = opts.jitter and Tr.new_stream(opts.jitter, i) or nil,
      -- Lot IA2-a : opts.chef = graine : chef modélisé par un multiplicateur du seuil tiré CHAQUE MINUTE dans toute sa
      -- plage (700 à 1 400 pour mille) et, une minute sur trois, un raid de 5 à 10 soldats (défense de la cible 0).
      chef = opts.chef and Tr.new_stream(opts.chef, 200 + i) or nil,
      -- Lot IA2-a2 : TRÊVE du chef (rivales épargnées par satiété : aucun raid ; en Paisible, aucune attaque contre la
      -- rivale ; seuil 1 400), une minute sur quatre, flux à part (les tirages d'IA2-a sont inchangés).
      hold_stream = opts.chef and Tr.new_stream(opts.chef, 300 + i) or nil,
      -- Lot IA2-c : opts.tempo (pour mille) = moment de la 1re attaque de la partie (valeur du niveau × tempo) ;
      -- opts.cd = graine : intervalle entre deux attaques contre le joueur × tempo tiré à ±20 % après chaque attaque.
      cd_stream = opts.cd and Tr.new_stream(opts.cd, 400 + i) or nil, cd_mult = opts.cd and 1000 or nil,
      r = { attacks = 0, soldiers = 0, first = nil, declare = nil, warn = nil, rival = 0, rival_war = 0, sent_total = 0,
        joins = 0, siege = 0, deterred = 0, fallback = 0, launches = {}, raids = 0, varied = 0 },
    }
    if fs[i].stream then fs[i].jitter = Tr.jitter(fs[i].stream) end
  end
  for tick = 75, minutes * MIN, 75 do
    for _, f in ipairs(fs) do
      local t = tick - f.offset
      if t >= 300 and t % 300 == 0 then
        f.acc = f.acc + 300
        while f.acc >= prod do
          f.acc = f.acc - prod
          if f.total < f.cap then f.garrison, f.total = f.garrison + 1, f.total + 1 end
        end
        local keep = {}
        for _, b in ipairs(f.back) do
          if b.at <= tick then
            local alive = math.floor(b.n * 0.6)
            f.garrison = f.garrison + alive
            f.total = f.total - (b.n - alive)
          else keep[#keep + 1] = b end
        end
        f.back = keep
        if f.chef and t % 3600 == 0 then
          f.war_mult = Tr.range(f.chef, 700, 1400)
          f.raid = Tr.range(f.chef, 1, 3) == 1 and Tr.range(f.chef, 5, 10) or nil
          f.hold = Tr.range(f.hold_stream, 1, 4) == 1
        end
        local fp, r = f.fp, f.r
        local v = {
          personality = f.pers, tech = cfg.tech, upgrades = 0, garrison = f.garrison, soldiers_max = 100, can_attack = true,
          attack_jitter = f.jitter,
          enemy_defense = cfg.rdef or 10, rival = { id = 2, outposts = cfg.own }, own_outposts = cfg.own, leader_outposts = cfg.own,
          pvp = { difficulty = level, tick = tick, anchor = 0, declared = fp.declared, provoked = false, warned = fp.warned,
            last_attack = fp.last_attack, last_rival = fp.last_rival, sent_player = fp.sent_player, sent_total = fp.sent_total,
            player_groups = 0, due_since = fp.due_since, rally_until = shared.rally_until,
            rally_defense = shared.rally_until and cfg.defense or nil,
            first_after = opts.tempo and not shared.first_done and A.first_after(0, level, opts.tempo) or nil,
            first_prep = A.PREP, cooldown_mult = f.cd_mult },
          player = { score = cfg.score, defense = cfg.defense, reachable = true },
        }
        if f.chef then
          v.chef = { war_mult = f.hold and 1400 or (f.war_mult or 1000), raid = f.raid, raid_defense = 0, hold = f.hold or nil }
        end
        local a = S.decide(v)
        if a.warn then fp.warned = true; r.warn = r.warn or tick end
        if a.declare then fp.declared = true; fp.sent_player, fp.sent_total, fp.due_since = 0, 0, nil; r.declare = tick end
        if a.due_since ~= nil then fp.due_since = a.due_since or nil end
        if a.plan == "siege" then r.siege = r.siege + 1 elseif a.plan == "deterred" then r.deterred = r.deterred + 1
        elseif a.plan == "fallback" then r.fallback = r.fallback + 1 end
        if a.attack then
          local n = a.attack.count
          f.garrison = f.garrison - n
          f.back[#f.back + 1] = { at = tick + 5 * MIN, n = n }
          -- Lot IA2-a : un raid ne compte ni dans la part visée ni comme attaque contre la rivale (comme en jeu).
          if not a.attack.raid then
            fp.sent_total = fp.sent_total + n
            if fp.declared then r.sent_total = r.sent_total + n end
          end
          if a.attack.rule == "variee" and level ~= "peaceful" then r.varied = r.varied + 1 end
          if a.attack.raid then
            r.raids = r.raids + 1
            f.raid = nil
          elseif a.attack.target == "player" then
            fp.sent_player = fp.sent_player + n
            fp.last_attack, fp.due_since = tick, nil
            shared.first_done = true
            if f.cd_stream then f.cd_mult = Tr.range(f.cd_stream, 800, 1200) end
            r.attacks, r.soldiers = r.attacks + 1, r.soldiers + n
            r.first = r.first or tick
            r.launches[#r.launches + 1] = { tick = tick, n = n, join = a.attack.join or false }
            if a.attack.join then r.joins = r.joins + 1 end
            if a.rally then
              local u = tick + S.rally_ticks(level)
              if not shared.rally_until or u > shared.rally_until then shared.rally_until = u end
              shared.rallies = shared.rallies + 1
            end
          else
            fp.last_rival = tick
            r.rival = r.rival + 1
            if fp.declared then r.rival_war = r.rival_war + 1 end
            if f.stream then f.jitter = Tr.jitter(f.stream) end
          end
        end
      end
    end
  end
  local out = {}
  for i, f in ipairs(fs) do
    local r = f.r
    r.mean = r.attacks > 0 and r.soldiers / r.attacks or 0
    r.share = r.sent_total > 0 and r.soldiers / r.sent_total or 0
    out[i] = r
  end
  out.rallies = shared.rallies
  return out
end
local function campaign(level, pers, minutes, cfg, opts)
  return game_campaign(level, { pers }, minutes, cfg, opts)[1]
end

-- Ordre STRICT exigé dans chaque configuration (C4-3) parmi les niveaux qui attaquent : un niveau qui
-- attaque implique que tous les niveaux plus durs attaquent ; 1re attaque plus tôt, plus d'attaques, plus
-- grandes, part des forces plus grande. Et des guerres entre factions qui continuent après la
-- déclaration : au moins RIVAL_MIN attaques contre la rivale en Normal et en Difficile, au moins 1 en
-- Impitoyable (coalition : au moins 7,5 % des soldats restent pour les rivales).
local RIVAL_MIN = 4
local MEASURES = {} -- [config][personnalité][niveau] : rapport (BALANCE_SHEET §10 bis)
local ORDER_GAPS = {} -- écarts d'ordre mesurés (non exigés) avec une rivale de défense 30
local function order_ok(c, field, cmp)
  local prev
  for _, lv in ipairs(AGGRO) do
    local r = c[lv]
    if r.attacks > 0 then
      if prev and not cmp(c[prev][field], r[field]) then return false end
      prev = lv
    elseif prev then
      return false -- un niveau plus dur n'attaque plus
    end
  end
  return true
end
for ci, cfg in ipairs(CONFIGS) do
  print("  -- [config " .. ci .. "] " .. cfg.name)
  print("  niveau      personnalité  déclaration  1re attaque  attaques  soldats  taille moy.  part   (rivale : total / après déclaration) siège/dissuasion/répit (pensées)")
  local camp = {}
  MEASURES[ci] = camp
  for _, p in ipairs(PERS) do
    camp[p] = {}
    for _, lv in ipairs(LEVELS) do
      local r = campaign(lv, p, 180, cfg)
      camp[p][lv] = r
      print(string.format("  %-11s %-13s %11s  %11s  %8d  %7d  %11.1f  %4.0f %%  (%d / %d) %d/%d/%d", lv, p,
        r.declare and string.format("%.1f min", r.declare / MIN) or "-", r.first and string.format("%.1f min", r.first / MIN) or "jamais",
        r.attacks, r.soldiers, r.mean, r.share * 100, r.rival, r.rival_war, r.siege, r.deterred, r.fallback))
    end
  end
  local tag = "[config " .. ci .. "] "
  check(S.player_is_leader({ player = { score = cfg.score }, own_outposts = cfg.own, leader_outposts = cfg.own }) == cfg.leader,
    tag .. "joueur " .. (cfg.leader and "leader" or "non leader") .. " comme prévu")
  for _, p in ipairs(PERS) do
    local c = camp[p]
    local t = tag .. p
    check(c.peaceful.attacks == 0 and c.peaceful.declare == nil, t .. " : Paisible, 0 attaque contre le joueur en 180 min")
    for _, lv in ipairs(AGGRO) do
      if cfg.must[lv] then
        check(c[lv].first ~= nil and c[lv].first >= S.grace_ticks(lv, p),
          string.format("%s : %s attaque au moins une fois, après la grâce (%d attaques)", t, lv, c[lv].attacks))
        if cfg.repeat_min then
          check(c[lv].attacks >= cfg.repeat_min,
            string.format("%s : %s, rivale inattaquable ou non, au moins %d attaques (fin de l'impasse : %d)", t, lv, cfg.repeat_min, c[lv].attacks))
        end
      end
    end
    local orders = {
      { "first", function(a, b) return a > b end, "1re attaque de plus en plus tôt (niveaux qui attaquent)" },
      { "attacks", function(a, b) return a < b end, "attaques de plus en plus fréquentes" },
      { "mean", function(a, b) return a < b end, "attaques de plus en plus nombreuses (taille moyenne)" },
    }
    -- La part des forces n'a de sens que si la faction attaque sa rivale (sinon 100 % à tous les niveaux).
    if c.peaceful.rival > 0 then
      orders[#orders + 1] = { "share", function(a, b) return a < b end, "part des forces contre le joueur croissante" }
    end
    for _, o in ipairs(orders) do
      if cfg.no_order then
        if not order_ok(c, o[1], o[2]) then
          ORDER_GAPS[#ORDER_GAPS + 1] = t .. " : " .. o[3]
          print("  ÉCART (non exigé, rivale de défense 30) : " .. t .. " : " .. o[3])
        end
      else
        check(order_ok(c, o[1], o[2]), t .. " : " .. o[3])
      end
    end
    if c.peaceful.rival > 0 and not cfg.rdef then
      check(c.normal.rival_war >= RIVAL_MIN and c.hard.rival_war >= RIVAL_MIN and c.merciless.rival_war >= 1,
        string.format("%s : les guerres entre factions continuent après la déclaration (rivale : Normal %d, Difficile %d, Impitoyable %d)",
          t, c.normal.rival_war, c.hard.rival_war, c.merciless.rival_war))
    elseif c.peaceful.rival > 0 then
      check(c.normal.rival_war + c.hard.rival_war + c.merciless.rival_war >= 1,
        string.format("%s : la rivale (défense 30) reçoit encore des attaques après la déclaration (Normal %d, Difficile %d, Impitoyable %d)",
          t, c.normal.rival_war, c.hard.rival_war, c.merciless.rival_war))
    elseif ci == 1 or cfg.rdef then
      -- Défaut ANTÉRIEUR à IA0b, hors de son périmètre (Paisible inchangé) : avec son armée visée (40), le
      -- bâtisseur n'atteint jamais sa taille d'attaque contre une faction (28 > 24 envoyables). Moteur réel
      -- E21 : Émeraude, 0 attaque en 60 min. Avec une rivale de défense 30, le technocrate non plus.
      print("  NOTE : " .. p .. " n'attaque jamais sa rivale, même en Paisible : défaut antérieur, non corrigé (le joueur reste attaqué : fin de l'impasse)")
    end
  end
end
print(string.format("  rivale de défense 30 : %d écart(s) d'ordre strict (non exigé, voir BALANCE_SHEET §10 bis)", #ORDER_GAPS))
-- Seuil de Facile (vérificateur) : dissuadé dès 2 tourelles en tech 0, attaque 1 tourelle.
do
  local deterred2, attacks1 = true, true
  for _, p in ipairs(PERS) do
    if MEASURES[9][p].easy.attacks > 0 then deterred2 = false end
    if MEASURES[1][p].easy.attacks == 0 then attacks1 = false end
  end
  check(attacks1 and deterred2, "Facile (sans siège) : attaque une base d'1 tourelle, dissuadé dès 2 tourelles en tech 0 (4 personnalités) : question au Directeur Créatif")
end
local c1, c2 = campaign("hard", "balanced", 120), campaign("hard", "balanced", 120)
check(c1.attacks == c2.attacks and c1.soldiers == c2.soldiers and c1.first == c2.first, "campagne pure déterministe")

---------------------------------------------------------------------------------------------------
section("Campagne pure : caractères tirés de la graine (lot IA2-0)")
-- Lot IA2-0 : chaque faction a un caractère tiré de la graine (shared/faction/traits.lua), agressivité, garnison
-- gardée et prudence bornées à l'enveloppe des archétypes. Mêmes exigences que ci-dessus (une attaque après la
-- grâce là où elle est exigée, ordre STRICT des niveaux, guerres entre factions après la déclaration) pour 16
-- caractères : les 2 extrêmes de chaque archétype (traits d'agressivité et de prudence à −25 % et +25 %) et les
-- 8 caractères tirés des graines 20261020 et 123456789 (carte des bancs, et la 2e graine des mesures).
local CHARS = {}
for _, p in ipairs(PERS) do
  for _, sgn in ipairs({ -1, 1 }) do
    local t = {}
    for _, k in ipairs(Tr.ORDER) do t[k] = Tr.ARCHETYPES[p][k] end
    t.agressivite = math.floor(t.agressivite * (1000 + sgn * Tr.SPREAD) / 1000 + 0.5)
    t.prudence = math.floor(t.prudence * (1000 - sgn * Tr.SPREAD) / 1000 + 0.5)
    CHARS[#CHARS + 1] = { name = p .. (sgn < 0 and " timide" or " hardi"), pers = Tr.character(p, t) }
  end
end
for _, ms in ipairs({ 20261020, 123456789 }) do
  local ps = Tr.personalities(ms, 4)
  for i = 1, 4 do
    local _, t = Tr.found(ms, i, ps[i])
    CHARS[#CHARS + 1] = { name = string.format("%d/%d %s", ms, i, ps[i]), pers = Tr.character(ps[i], t) }
  end
end
local ia2_gaps = 0
for ci, cfg in ipairs(CONFIGS) do
  for _, ch in ipairs(CHARS) do
    local c = {}
    for _, lv in ipairs(LEVELS) do c[lv] = campaign(lv, ch.pers, 180, cfg, { jitter = 1000 + ci }) end
    local t = string.format("[IA2-0, config %d] %s (agressivité %.3f, garnison gardée %.3f, prudence %.3f)", ci, ch.name,
      ch.pers.aggression, ch.pers.keep, ch.pers.caution)
    local ok = c.peaceful.attacks == 0 and c.peaceful.declare == nil
    for _, lv in ipairs(AGGRO) do
      if cfg.must[lv] and not (c[lv].first ~= nil and c[lv].first >= S.grace_ticks(lv, ch.pers)) then ok = false; print("  ECHEC : " .. t .. " : " .. lv .. " n'attaque pas") end
      if cfg.must[lv] and cfg.repeat_min and c[lv].attacks < cfg.repeat_min then ok = false; print("  ECHEC : " .. t .. " : " .. lv .. " moins de " .. cfg.repeat_min .. " attaques") end
    end
    local orders = {
      { "first", function(a, b) return a > b end, "1re attaque de plus en plus tôt" },
      { "attacks", function(a, b) return a < b end, "attaques de plus en plus fréquentes" },
      { "mean", function(a, b) return a < b end, "taille moyenne croissante" },
    }
    -- À un niveau agressif, la guerre entre factions suit la règle d'IA0 (archétype, sans tirage) : la part des forces
    -- et les guerres après la déclaration s'exigent quand l'ARCHÉTYPE attaque sa rivale (campagne ci-dessus).
    local arch_rival = MEASURES[ci][ch.pers.archetype].peaceful.rival > 0
    if arch_rival then orders[#orders + 1] = { "share", function(a, b) return a < b end, "part des forces croissante" } end
    for _, o in ipairs(orders) do
      if not order_ok(c, o[1], o[2]) then
        if cfg.no_order then
          ia2_gaps = ia2_gaps + 1
        else
          ok = false
          print("  ECHEC : " .. t .. " : " .. o[3])
        end
      end
    end
    if arch_rival and not cfg.rdef and not (c.normal.rival_war >= RIVAL_MIN and c.hard.rival_war >= RIVAL_MIN and c.merciless.rival_war >= 1) then
      ok = false
      print(string.format("  ECHEC : %s : guerres entre factions après la déclaration (Normal %d, Difficile %d, Impitoyable %d)", t,
        c.normal.rival_war, c.hard.rival_war, c.merciless.rival_war))
    end
    check(ok, t .. " : exigences de la configuration")
  end
end
print(string.format("  16 caractères × 11 configurations ; écarts d'ordre avec une rivale de défense 30 (non exigés) : %d", ia2_gaps))

---------------------------------------------------------------------------------------------------
section("Campagne pure : chef d'IA2-a (réserve du joueur, seuil tiré chaque minute, raids)")
-- Lot IA2-a : sous le chef, la guerre ENTRE factions suit le caractère tiré à TOUS les niveaux, avec les seuls soldats
-- au-delà de la réserve du joueur (S.player_reserve), puis la règle d'IA0 si la variée ne part pas ; raids hors de la
-- part visée. Modèle : multiplicateur du seuil tiré chaque minute dans toute sa plage (700 à 1 400), raid de 5 à 10
-- soldats une minute sur trois. Mêmes exigences que la section précédente, 24 caractères (les 16 ci-dessus et les 8
-- des graines 777 et 3141592653) × 11 configurations. Mesuré (essai hors banc) : la réserve SEULE, sans repli sur la
-- règle d'IA0, échoue dans 143 cas sur 264 (guerres entre factions affamées, ordre des tailles).
local CHARS_CHEF = {}
for _, ch in ipairs(CHARS) do CHARS_CHEF[#CHARS_CHEF + 1] = ch end
for _, ms in ipairs({ 777, 3141592653 }) do
  local ps = Tr.personalities(ms, 4)
  for i = 1, 4 do
    local _, t = Tr.found(ms, i, ps[i])
    CHARS_CHEF[#CHARS_CHEF + 1] = { name = string.format("%s/%d %s", tostring(ms), i, ps[i]), pers = Tr.character(ps[i], t) }
  end
end
local chef_gaps, chef_raids, chef_varied, chef_rival = 0, 0, 0, 0
for ci, cfg in ipairs(CONFIGS) do
  for _, ch in ipairs(CHARS_CHEF) do
    local c = {}
    for _, lv in ipairs(LEVELS) do c[lv] = campaign(lv, ch.pers, 180, cfg, { jitter = 1000 + ci, chef = 5000 + ci }) end
    for _, lv in ipairs(LEVELS) do
      chef_raids, chef_varied, chef_rival = chef_raids + c[lv].raids, chef_varied + c[lv].varied, chef_rival + c[lv].rival
    end
    local t = string.format("[IA2-a, config %d] %s", ci, ch.name)
    local ok = c.peaceful.attacks == 0 and c.peaceful.declare == nil
    for _, lv in ipairs(AGGRO) do
      if cfg.must[lv] and not (c[lv].first ~= nil and c[lv].first >= S.grace_ticks(lv, ch.pers)) then ok = false; print("  ECHEC : " .. t .. " : " .. lv .. " n'attaque pas") end
      if cfg.must[lv] and cfg.repeat_min and c[lv].attacks < cfg.repeat_min then ok = false; print("  ECHEC : " .. t .. " : " .. lv .. " moins de " .. cfg.repeat_min .. " attaques") end
    end
    local orders = {
      { "first", function(a, b) return a > b end, "1re attaque de plus en plus tôt" },
      { "attacks", function(a, b) return a < b end, "attaques de plus en plus fréquentes" },
      { "mean", function(a, b) return a < b end, "taille moyenne croissante" },
    }
    local arch_rival = MEASURES[ci][ch.pers.archetype].peaceful.rival > 0
    if arch_rival then orders[#orders + 1] = { "share", function(a, b) return a < b end, "part des forces croissante" } end
    for _, o in ipairs(orders) do
      if not order_ok(c, o[1], o[2]) then
        if cfg.no_order then
          chef_gaps = chef_gaps + 1
        else
          ok = false
          print("  ECHEC : " .. t .. " : " .. o[3])
        end
      end
    end
    if arch_rival and not cfg.rdef and not (c.normal.rival_war >= RIVAL_MIN and c.hard.rival_war >= RIVAL_MIN and c.merciless.rival_war >= 1) then
      ok = false
      print(string.format("  ECHEC : %s : guerres entre factions après la déclaration (Normal %d, Difficile %d, Impitoyable %d)", t,
        c.normal.rival_war, c.hard.rival_war, c.merciless.rival_war))
    end
    check(ok, t .. " : exigences de la configuration")
  end
end
print(string.format("  24 caractères × 11 configurations : raids %d, attaques contre la rivale %d (dont règle variée à un niveau agressif : %d) ; écarts non exigés (rivale de défense 30) : %d",
  chef_raids, chef_rival, chef_varied, chef_gaps))
check(chef_raids > 0, "le chef lance des raids dans la campagne (" .. chef_raids .. ")")

---------------------------------------------------------------------------------------------------
section("Campagne pure : moment varié contre le joueur (lot IA2-c)")
-- Lot IA2-c : sous le chef (section précédente), en plus : 1re attaque de la partie pas avant la valeur du niveau ×
-- tempo de la partie (±20 % ; un tempo par configuration, extrêmes compris), préparation 4 min avant (garnison gardée),
-- et intervalle entre deux attaques contre le joueur × tempo tiré à ±20 % après chaque attaque. Mêmes exigences
-- (ordre STRICT des niveaux, attaques exigées, guerres entre factions), plus : jamais d'attaque avant le moment.
local TEMPOS = { 800, 1200, 1000, 850, 1150, 950, 1050, 900, 1100, 800, 1200 }
local tempo_gaps, early, n_first, n_lo, n_hi = 0, 0, 0, 1e18, 0
for ci, cfg in ipairs(CONFIGS) do
  for _, ch in ipairs(CHARS_CHEF) do
    local c = {}
    local tempo = TEMPOS[ci]
    local nocd = os.getenv("IA2C_NOCD") == "1" -- TEMPORAIRE (diagnostic)
    for _, lv in ipairs(LEVELS) do c[lv] = campaign(lv, ch.pers, 180, cfg, { jitter = 1000 + ci, chef = 5000 + ci, tempo = (not nocd or os.getenv("IA2C_NOT") ~= "1") and tempo or nil, cd = (not nocd) and (7000 + ci) or nil }) end
    local t = string.format("[IA2-c, config %d, tempo %d] %s", ci, tempo, ch.name)
    local ok = c.peaceful.attacks == 0 and c.peaceful.declare == nil
    for _, lv in ipairs(AGGRO) do
      if cfg.must[lv] and not (c[lv].first ~= nil and c[lv].first >= S.grace_ticks(lv, ch.pers)) then ok = false; print("  ECHEC : " .. t .. " : " .. lv .. " n'attaque pas") end
      if cfg.must[lv] and cfg.repeat_min and c[lv].attacks < cfg.repeat_min then ok = false; print("  ECHEC : " .. t .. " : " .. lv .. " moins de " .. cfg.repeat_min .. " attaques") end
      if c[lv].first and c[lv].first < A.first_after(0, lv, tempo) then early = early + 1; ok = false; print("  ECHEC : " .. t .. " : " .. lv .. " attaque avant le moment") end
    end
    if c.normal.first then
      n_first = n_first + 1
      if c.normal.first < n_lo then n_lo = c.normal.first end
      if c.normal.first > n_hi then n_hi = c.normal.first end
    end
    local orders = {
      { "first", function(a, b) return a > b end, "1re attaque de plus en plus tôt" },
      { "attacks", function(a, b) return a < b end, "attaques de plus en plus fréquentes" },
      { "mean", function(a, b) return a < b end, "taille moyenne croissante" },
    }
    local arch_rival = MEASURES[ci][ch.pers.archetype].peaceful.rival > 0
    if arch_rival then orders[#orders + 1] = { "share", function(a, b) return a < b end, "part des forces croissante" } end
    for _, o in ipairs(orders) do
      if not order_ok(c, o[1], o[2]) then
        if cfg.no_order then
          tempo_gaps = tempo_gaps + 1
        else
          ok = false
          local d = {}
          for _, lv in ipairs(AGGRO) do
            d[#d + 1] = string.format("%s %s/%d/%.1f", lv, c[lv].first and string.format("%.1f", c[lv].first / MIN) or "-", c[lv].attacks, c[lv].mean)
          end
          print("  ECHEC : " .. t .. " : " .. o[3] .. " (1re/attaques/taille : " .. table.concat(d, ", ") .. ")")
        end
      end
    end
    if arch_rival and not cfg.rdef and not (c.normal.rival_war >= RIVAL_MIN and c.hard.rival_war >= RIVAL_MIN and c.merciless.rival_war >= 1) then
      ok = false
      print(string.format("  ECHEC : %s : guerres entre factions après la déclaration (Normal %d, Difficile %d, Impitoyable %d)", t,
        c.normal.rival_war, c.hard.rival_war, c.merciless.rival_war))
    end
    check(ok, t .. " : exigences de la configuration")
  end
end
print(string.format("  24 caractères × 11 configurations (tempos 800 à 1 200) : 1re attaque en Normal de %.1f à %.1f min (%d cas) ; attaques avant le moment : %d ; écarts non exigés : %d",
  n_lo / MIN, n_hi / MIN, n_first, early, tempo_gaps))

---------------------------------------------------------------------------------------------------
section("Campagne pure : partie à 4 factions, assaut coordonné (Difficile, Impitoyable)")
-- Les 4 personnalités dans l'ordre des factions du jeu, contre les bases défendues (cfg 5 à 8).
local GAME = { "conqueror", "technocrat", "builder", "balanced" }
print("  config  niveau      1re attaque  attaques (dont jointes)  fenêtres  écart max d'une jointe à l'ouverture")
for _, ci in ipairs({ 5, 6, 7, 8 }) do
  local cfg = CONFIGS[ci]
  for _, lv in ipairs(AGGRO) do
    local g = game_campaign(lv, GAME, 180, cfg)
    local first, att, joins, worst, small = nil, 0, 0, 0, 0
    local opens = {}
    for i = 1, #GAME do
      local r = g[i]
      att, joins = att + r.attacks, joins + r.joins
      if r.first and (not first or r.first < first) then first = r.first end
      for _, l in ipairs(r.launches) do if not l.join then opens[#opens + 1] = l.tick end end
    end
    -- Chaque attaque jointe part dans la fenêtre d'une attaque « prête » d'une autre faction.
    local inside = true
    for i = 1, #GAME do
      for _, l in ipairs(g[i].launches) do
        if l.join and l.n < S.player_min_size(lv, GAME[i], 100) then small = small + 1 end
        if l.join then
          local best
          for _, o in ipairs(opens) do
            if o <= l.tick and (not best or l.tick - o < best) then best = l.tick - o end
          end
          if not best or best > S.rally_ticks(lv) then inside = false end
          if best and best > worst then worst = best end
        end
      end
    end
    print(string.format("  %-7d %-11s %11s  %8d (%d)  %16d  %s", ci, lv, first and string.format("%.1f min", first / MIN) or "jamais",
      att, joins, g.rallies, joins > 0 and string.format("%.1f min", worst / MIN) or "-"))
    local t = string.format("[partie, config %d] %s", ci, lv)
    if lv == "hard" or lv == "merciless" then
      check(joins >= 1 and inside, t .. " : assaut coordonné (" .. joins .. " attaques jointes, toutes dans la fenêtre d'une autre)")
      check(small == 0, t .. " : aucune attaque jointe sous la taille minimale du niveau (" .. small .. ")")
    else
      check(joins == 0 and g.rallies == 0, t .. " : aucun assaut coordonné hors Difficile et Impitoyable")
    end
    if cfg.must[lv] then check(first ~= nil, t .. " : la base est attaquée") end
  end
end

---------------------------------------------------------------------------------------------------
section("Campagne pure : sensibilité à une production plus lente (1 soldat / 90 s)")
-- Le moteur réel produit moins vite que le modèle (E21 : 58 soldats en 59 min pour Écarlate, moins pour les
-- autres). Mesure seule (pas d'exigence) : 1re attaque contre les bases défendues des cfg 5 à 7.
print("  config  personnalité  Facile        Normal        Difficile     Impitoyable")
for ci = 5, 7 do
  for _, p in ipairs(PERS) do
    local parts = {}
    for _, lv in ipairs(AGGRO) do
      local r = campaign(lv, p, 180, CONFIGS[ci], { prod = 5400 })
      parts[#parts + 1] = string.format("%-13s", r.first and string.format("%.0f min (%d)", r.first / MIN, r.attacks) or "jamais")
    end
    print(string.format("  %-7d %-13s %s", ci, p, table.concat(parts, " ")))
  end
end

if arg and arg[1] == "pure" then -- règles pures seulement (itération rapide)
  print(string.format("\nRésultat (règles pures) : %d OK, %d ECHEC(S)", passes, failures))
  os.exit(failures == 0 and 0 or 1)
end

---------------------------------------------------------------------------------------------------
-- Runtime (moteur simulé)
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

-- Base témoin du joueur : un secteur « avant-poste » loin du QG Écarlate (secteur -2,1) avec 4 machines,
-- 2 fours et 1 tourelle (défense 8), et une « base de départ » (secteur 0,0) de 3 machines.
local OUTPOST = { x = -96, y = 96 }
-- Lot IA0b : extra.turrets = n tourelles à l'avant-poste (rangées de 7 au nord, la 1re à la place d'origine) ;
-- extra.machines = n assembleurs de plus dans le secteur de l'avant-poste (la base n'est pas rasée avant la
-- fin d'une mesure : chaque attaque du moteur simulé y détruit une installation).
local TURRET_DX = { 0, -3, 3, -6, 6, -9, 9 }
local function new_world(level, extra)
  local o = { patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = level, groups_hit_player = true,
    turrets_kill = true }
  local turrets, machines = 1, 0
  for k, v in pairs(extra or {}) do
    if k == "turrets" then turrets = v elseif k == "machines" then machines = v else o[k] = v end
  end
  M.new_game(o)
  local w = W()
  w.prototypes["assembling-machine-1"] = { type = "assembling-machine", max_health = 300 }
  local s = w.surface
  for i = 0, 3 do s.create_entity({ name = "assembling-machine-1", position = { x = OUTPOST.x - 6 + 4 * i, y = OUTPOST.y }, force = "player" }) end
  for i = 0, 1 do s.create_entity({ name = "stone-furnace", position = { x = OUTPOST.x - 2 + 4 * i, y = OUTPOST.y + 4 }, force = "player" }) end
  for i = 1, turrets do
    local col, row = (i - 1) % #TURRET_DX + 1, math.floor((i - 1) / #TURRET_DX)
    local t = s.create_entity({ name = "gun-turret", position = { x = OUTPOST.x + TURRET_DX[col], y = OUTPOST.y - 4 - 4 * row }, force = "player" })
    t.insert({ name = "piercing-rounds-magazine", count = 50 })
  end
  for i = 0, 2 do s.create_entity({ name = "assembling-machine-1", position = { x = 10 + 4 * i, y = 10 }, force = "player" }) end
  for i = 1, machines do
    local col, row = (i - 1) % 12, math.floor((i - 1) / 12)
    s.create_entity({ name = "assembling-machine-1", position = { x = -124 + 5 * col, y = 108 + 5 * row }, force = "player" })
  end
end
local function war(text) M.command("fo-war", text) end
local function printed(key)
  local n = 0
  for _, line in ipairs(W().game_prints) do if line:find(key, 1, true) then n = n + 1 end end
  return n
end
local function pvp() return global.fo.war.pvp end
local function fac(i) return global.fo.war.factions[i] end
-- Lot IA2-0 : caractère tiré de la graine (personnalité répartie par la graine, agressivité de la grâce tirée) :
-- les délais attendus se calculent sur ce caractère, plus sur la seule couleur (graine 42 du moteur simulé :
-- Écarlate équilibrée, grâce 27,8 min en Normal ; Azur bâtisseur, 42,9 min).
local function char(i) return Tr.character(fac(i).personality, fac(i).traits) end
-- Lot IA2-c : secteurs du joueur VUS par la faction i (brouillard).
local function known(i)
  local v = fac(i).pvp and fac(i).pvp.vision
  local n = 0
  if v then for _ in pairs(v.known) do n = n + 1 end end
  return n
end
local function ceasefire(i) return game.forces[fac(i).force].get_cease_fire(game.forces.player) end
local function player_groups(i)
  local n = 0
  for _, g in pairs(fac(i).groups) do if g.target_faction == "player" then n = n + 1 end end
  return n
end
local function player_buildings()
  local n = 0
  for _, e in ipairs(W().entities) do if e.valid and e.force.name == "player" and e.type ~= "character" then n = n + 1 end end
  return n
end

--- Mesure d'une partie : 2 factions (Écarlate conquérant, Azur technocrate), `minutes` minutes.
-- Lot IA0b : base agrandie de 36 assembleurs. Avec la seule base témoin (10 installations), Impitoyable
-- l'avait rasée vers 28 min et plafonnait à 8 attaques en 45 min, comme Difficile (9) : le décompte mesurait
-- la taille de la base, plus le niveau.
local function measure(level, minutes)
  new_world(level, { machines = 36 })
  war("start 2 60 6 320")
  local r = { first = nil, declare = nil }
  for _ = 1, minutes * 12 do
    M.run_ticks(300)
    for i = 1, 2 do
      local fp = fac(i).pvp
      if fp.declared_at and (not r.declare or fp.declared_at < r.declare) then r.declare = fp.declared_at end
      if fp.attacks > 0 and fp.last_attack and not r.first_seen then r.first_seen = true end
    end
  end
  r.attacks, r.soldiers, r.sent_total = 0, 0, 0
  for i = 1, 2 do
    local fp = fac(i).pvp
    r.attacks = r.attacks + fp.attacks
    r.soldiers = r.soldiers + fp.soldiers
    r.sent_total = r.sent_total + fp.sent_total
  end
  -- 1re attaque : la plus ancienne ligne « attaque » du journal
  for _, line in ipairs(W().logs) do
    local t = line:match("^%[FO%-PVP%] attaque tick (%d+)")
    if t and not r.first then r.first = tonumber(t) end
  end
  r.mean = r.attacks > 0 and r.soldiers / r.attacks or 0
  r.losses = pvp().losses
  r.ceasefire1 = ceasefire(1)
  return r
end

---------------------------------------------------------------------------------------------------
section("Runtime : Normal, base témoin attaquée après la grâce")
local runs = {}
do
  new_world("normal")
  war("start 2 60 6 320")
  check(printed("fo-pvp.intro:") == 1, "message d'introduction (difficulté, délai)")
  check(ceasefire(1) and ceasefire(2), "cessez-le-feu au lancement")
  M.run_ticks(2400)
  -- Lot IA2-c : BROUILLARD (D-16). Avant IA2-c, le balayage global trouvait la base en 40 s ; désormais, à 320 tuiles
  -- (champ du QG : 160), aucune faction ne sait rien du joueur avant son éclaireur.
  check(known(1) == 0 and known(2) == 0, "brouillard : rien de vu du joueur à 40 s (QG à 320 tuiles, champ du QG 160)")
  local g1 = S.grace_ticks("normal", char(1))
  M.run_ticks(g1 - 2 * MIN - game.tick + 300)
  check(printed("fo-pvp.warn:") >= 1, "préavis affiché avant la fin de la grâce")
  check((fac(1).stats.scouts or 0) >= 1 and known(1) >= 2,
    string.format("éclaireur d'Écarlate parti avant la fin de sa grâce : base de départ et avant-poste du joueur VUS (%d éclaireur(s), %d secteurs)",
      fac(1).stats.scouts or 0, known(1)))
  M.run_ticks(g1 - game.tick - 1)
  check(ceasefire(1) and not fac(1).pvp.declared and player_groups(1) == 0,
    string.format("rien pendant la grâce (Écarlate, %.1f min)", g1 / MIN))
  M.run_ticks(301)
  check(fac(1).pvp.declared and not ceasefire(1), "Écarlate déclare la guerre à la fin de sa grâce")
  check(printed("fo-pvp.declare:") >= 1, "déclaration annoncée au joueur")
  check(ceasefire(2) and S.grace_ticks("normal", char(2)) > g1 + 301,
    string.format("Azur (grâce %.1f min) toujours en cessez-le-feu", S.grace_ticks("normal", char(2)) / MIN))
  local before = player_buildings()
  M.run_ticks(20 * MIN)
  local fp = fac(1).pvp
  check(fp.attacks >= 1, "Écarlate a attaqué le joueur (" .. fp.attacks .. " attaques, " .. fp.soldiers .. " soldats)")
  check(printed("fo-pvp.attack:") >= 1 and printed("[gps=") >= 1, "départ d'attaque annoncé, avec lien [gps]")
  local t = fp.target
  check(t and t.pos.x < -64 and t.pos.y >= 64, "cible : l'avant-poste du joueur, pas la base de départ (« QG en dernier »)")
  -- Lot IA2-c : côté d'arrivée publié, décision au rassemblement avancé, issue de l'attaque, moment de la 1re attaque.
  do
    local sided, rallies, issues, first = 0, 0, 0, nil
    for _, line in ipairs(W().logs) do
      if line:find("^%[FO%-PVP%] attaque tick") then
        first = first or tonumber(line:match("tick (%d+)"))
        if line:find(", octant %d") and line:find(", cote %d+ sur %d+") then sided = sided + 1 end
      elseif line:find("^%[FO%-PVP%] rassemblement tick") then
        rallies = rallies + 1
      elseif line:find("^%[FO%-PVP%] issue tick") then
        issues = issues + 1
      end
    end
    check(sided >= 1, "IA2-c : attaques contre le joueur avec un côté d'arrivée choisi sur la défense vue (" .. sided .. ")")
    check(rallies >= 1 and issues >= 1, string.format("IA2-c : décision au rassemblement (%d) et issue (%d) publiées", rallies, issues))
    local fa = A.first_after(pvp().anchor, "normal", pvp().tempo)
    check(first ~= nil and pvp().tempo and first >= fa and pvp().first_done,
      string.format("IA2-c : 1re attaque de la partie au tick %s, pas avant son moment (%d, tempo %s)", tostring(first), fa or -1,
        tostring(pvp().tempo)))
  end
  check(pvp().losses >= 1 and player_buildings() < before, "pertes du joueur causées par la faction (" .. pvp().losses .. ")")
  check(fac(1).stats.attacks > fp.attacks or fac(2).stats.attacks > 0, "les guerres entre factions continuent")
  check(fp.sent_total >= fp.sent_player, "comptes cohérents (envoyés au joueur ≤ envoyés)")
  local ok_ser = pcall(M.serialize, global)
  check(ok_ser, "global sérialisable")
  -- Légitime défense : la tourelle de l'avant-poste a abattu des attaquants (moteur simulé : turrets_kill),
  -- et le joueur abat lui-même un soldat écarlate. Ce n'est pas une provocation.
  local soldier
  for _, e in ipairs(W().entities) do
    if e.valid and e.type == "unit" and e.force.name == fac(1).force then soldier = e break end
  end
  check(soldier ~= nil, "un soldat écarlate à abattre")
  if soldier then soldier.die(game.forces.player) end
  M.run_ticks(2)
  check(not fac(1).pvp.provoked and fac(1).pvp.declared, "légitime défense : Écarlate n'est pas « provoquée » (guerre déclarée par la grâce)")
  check(printed("fo-pvp.declare-provoked:") == 0, "légitime défense : aucun message « représailles »")
  local st = remote.call("fo-pvp", "status")
  check(st.difficulty == "normal" and st.factions[1].declared and st.factions[1].attacks == fp.attacks, "interface distante : status")
  war("status")
  local found = false
  for _, l in ipairs(W().prints) do if l:find("PvP : difficulte normal", 1, true) then found = true end end
  check(found, "statut /fo-war : ligne PvP")

  section("Runtime : sauvegarde et rechargement en pleine guerre contre le joueur")
  local saved = M.deepcopy_global(global)
  local attacks0, anchor0 = fp.attacks, pvp().anchor
  M.load_mod()
  _G.global = saved
  check(pcall(function() W().on_load() end), "on_load sans erreur")
  local ok_r, err_r = pcall(M.run_ticks, 15 * MIN)
  check(ok_r, "15 min après rechargement (" .. tostring(err_r) .. ")")
  check(pvp().anchor == anchor0 and fac(1).pvp.declared, "état PvP conservé (ancre, déclaration)")
  check(fac(1).pvp.attacks > attacks0, "les attaques contre le joueur continuent (" .. attacks0 .. " -> " .. fac(1).pvp.attacks .. ")")

  section("Runtime : passage à Paisible en cours de partie, puis à Difficile")
  -- Une attaque en route vers le joueur, si possible, pour vérifier le rappel.
  for _ = 1, 40 do
    if player_groups(1) > 0 then break end
    M.run_ticks(300)
  end
  local had_group = player_groups(1) > 0
  W().settings["fo-pvp-difficulty"] = "peaceful"
  M.dispatch(W().events[defines.events.on_runtime_mod_setting_changed],
    { name = defines.events.on_runtime_mod_setting_changed, setting = "fo-pvp-difficulty", setting_type = "runtime-global", player_index = 1, tick = game.tick })
  check(pvp().difficulty == "peaceful", "réglage pris en compte immédiatement")
  check(ceasefire(1) and not fac(1).pvp.declared, "Paisible : Écarlate rétablit le cessez-le-feu")
  check(printed("fo-pvp.truce:") >= 1 and printed("fo-pvp.changed:") >= 1, "trêve et changement annoncés")
  local still = 0
  for _, g in pairs(fac(1).groups) do if g.target_faction == "player" and g.state == "attack" then still = still + 1 end end
  check(still == 0 and not (fac(1).route_pending and fac(1).route_pending.target_faction == "player"),
    "attaques en route rappelées" .. (had_group and "" or " (aucune n'était en route)"))
  local a0 = fac(1).pvp.attacks + fac(2).pvp.attacks
  local sc0 = pvp().sweeps
  M.run_ticks(15 * MIN)
  check(fac(1).pvp.attacks + fac(2).pvp.attacks == a0 and ceasefire(1) and ceasefire(2), "Paisible : 15 min sans attaque ni déclaration")
  check(pvp().sweeps == sc0, "Paisible : repérage à l'arrêt (coût nul)")
  local t_switch = game.tick
  check(remote.call("fo-pvp", "set_difficulty", "hard") == true and pvp().difficulty == "hard", "interface distante : passage à Difficile")
  check(pvp().anchor == t_switch, "la grâce repart du passage de Paisible à Difficile")
  local gh = S.grace_ticks("hard", char(1))
  M.run_ticks(gh - 301)
  check(not fac(1).pvp.declared and ceasefire(1), string.format("Difficile : rien avant %.1f min (grâce d'Écarlate), malgré les soldats abattus avant la trêve", gh / MIN))
  M.run_ticks(602)
  check(fac(1).pvp.declared and not ceasefire(1), string.format("Difficile : déclaration après %.1f min", gh / MIN))
  check(printed("fo-pvp.declare-provoked:") == 0, "aucun message « représailles » de toute la partie (le joueur n'a fait que se défendre)")
  check(remote.call("fo-pvp", "set_difficulty", "bogus") == false, "niveau inconnu refusé")
end

---------------------------------------------------------------------------------------------------
section("Runtime : Paisible, la base témoin n'est jamais attaquée")
do
  new_world("peaceful")
  war("start 2 60 6 320")
  check(printed("fo-pvp.intro-peaceful:") == 1, "introduction « Paisible »")
  M.run_ticks(45 * MIN)
  local att = fac(1).pvp.attacks + fac(2).pvp.attacks
  check(att == 0 and pvp().losses == 0, "45 min : 0 attaque, 0 perte du joueur")
  check(ceasefire(1) and ceasefire(2), "45 min : cessez-le-feu intact")
  check(fac(1).stats.attacks + fac(2).stats.attacks > 0, "les factions se battent entre elles")
  check(pvp().sweeps == 0, "aucun repérage en Paisible")
  -- Le joueur détruit une foreuse Écarlate : cessez-le-feu rompu (comme avant IA0), mais pas d'attaque.
  local victim
  for _, e in ipairs(W().entities) do
    if e.valid and e.name == "burner-mining-drill" and e.force.name == fac(1).force then victim = e break end
  end
  if victim then
    victim.die(game.forces.player)
    M.run_ticks(2)
    check(not ceasefire(1) and fac(1).pvp.provoked, "provocation : Écarlate rompt le cessez-le-feu")
    check(printed("fo-pvp.declare-provoked:") == 1, "représailles annoncées")
    M.run_ticks(15 * MIN)
    check(fac(1).pvp.attacks == 0, "Paisible + provoqué : toujours aucune attaque délibérée en 15 min")
  else
    check(false, "aucune foreuse Écarlate pour la provocation")
  end
end

---------------------------------------------------------------------------------------------------
section("Runtime : mesures par niveau (2 factions, 45 min)")
for _, lv in ipairs(LEVELS) do runs[lv] = measure(lv, 45) end
print("  niveau      1re déclaration  1re attaque  attaques  soldats  taille moy.  pertes du joueur")
for _, lv in ipairs(LEVELS) do
  local r = runs[lv]
  print(string.format("  %-11s %15s  %11s  %8d  %7d  %11.1f  %d", lv,
    r.declare and string.format("%.1f min", r.declare / MIN) or "-", r.first and string.format("%.1f min", r.first / MIN) or "jamais",
    r.attacks, r.soldiers, r.mean, r.losses))
end
check(runs.peaceful.attacks == 0 and runs.peaceful.losses == 0 and runs.peaceful.declare == nil, "Paisible : jamais attaqué")
check(runs.normal.first and runs.normal.first >= 20 * MIN, "Normal : attaqué, après la grâce (" .. tostring(runs.normal.first) .. ")")
local function f_(lv) return runs[lv].first or 1e18 end
check(f_("hard") < f_("normal") and f_("merciless") < f_("hard"), "Difficile puis Impitoyable : 1re attaque plus tôt")
check(runs.hard.attacks > runs.normal.attacks and runs.merciless.attacks > runs.normal.attacks, "Difficile et Impitoyable : plus d'attaques que Normal")
check(runs.hard.mean > runs.normal.mean and runs.merciless.mean > runs.normal.mean, "Difficile et Impitoyable : attaques plus nombreuses (taille moyenne)")
check(f_("easy") > f_("normal"), "Facile : 1re attaque plus tard que Normal")
-- Lot IA0b : ordre STRICT sur les 4 niveaux agressifs (moteur simulé).
check(runs.easy.attacks < runs.normal.attacks and runs.normal.attacks < runs.hard.attacks and runs.hard.attacks < runs.merciless.attacks,
  string.format("ordre strict du nombre d'attaques : %d < %d < %d < %d", runs.easy.attacks, runs.normal.attacks, runs.hard.attacks, runs.merciless.attacks))
check(runs.easy.mean < runs.normal.mean and runs.normal.mean < runs.hard.mean and runs.hard.mean < runs.merciless.mean,
  string.format("ordre strict de la taille moyenne : %.1f < %.1f < %.1f < %.1f", runs.easy.mean, runs.normal.mean, runs.hard.mean, runs.merciless.mean))

---------------------------------------------------------------------------------------------------
section("Runtime : base défendue (lot IA0b, 4 factions)")
-- Moteur simulé : les factions y atteignent la tech 2 vers 20 min (comme Écarlate en moteur réel, E21) ;
-- 3 tourelles n'y lient donc plus la règle de force, même avant IA0b. Il faut 12 tourelles (défense 96) pour
-- retrouver le défaut : ANCIEN CODE, Normal, 60 min : 2 attaques (Azur seulement, 1re à 46,5 min), Écarlate
-- déclarée à 20 min et 0 attaque.
local function pvp_lines(pattern)
  local out = {}
  for _, line in ipairs(W().logs) do
    local t = line:match(pattern)
    if t then out[#out + 1] = { tick = tonumber(t), line = line } end
  end
  return out
end
do
  new_world("normal", { turrets = 12 })
  war("start 4 60 6 320")
  M.run_ticks(60 * MIN)
  local attackers, total = 0, 0
  for i = 1, 4 do
    total = total + fac(i).pvp.attacks
    if fac(i).pvp.attacks > 0 then attackers = attackers + 1 end
  end
  local att = pvp_lines("^%[FO%-PVP%] attaque tick (%d+)")
  local first_def = att[1] and tonumber(att[1].line:match("defense estimee (%d+)")) or 0
  print(string.format("  Normal, 12 tourelles, 60 min : %d attaques de %d factions (Écarlate %d), 1re au tick %s (défense estimée %d), %d sièges, %d dissuasions",
    total, attackers, fac(1).pvp.attacks, att[1] and att[1].tick or "-", first_def, #pvp_lines("^%[FO%-PVP%] siege tick (%d+)"),
    #pvp_lines("^%[FO%-PVP%] dissuasion tick (%d+)")))
  check(fac(1).pvp.attacks >= 1, "Normal, 12 tourelles : Écarlate (conquérant) attaque la base défendue (ancien code : 0 en 60 min)")
  check(attackers >= 3 and total >= 6, string.format("Normal, 12 tourelles : %d factions sur 4 attaquent, %d attaques (ancien code : 1 faction, 2 attaques)", attackers, total))
  check(first_def >= 96, "la 1re attaque vise la base défendue en connaissant sa défense (" .. first_def .. " ≥ 96)")
  check(#pvp_lines("^%[FO%-PVP%] siege tick (%d+)") >= 1, "sièges journalisés (« [FO-PVP] siege »)")
  check(pvp().losses >= 1, "pertes du joueur (" .. pvp().losses .. ")")
  check(pcall(M.serialize, global), "global sérialisable (plan, sièges, fenêtre)")
end
do
  new_world("merciless", { turrets = 6 })
  war("start 4 60 6 320")
  M.run_ticks(40 * MIN)
  local opens = pvp_lines("^%[FO%-PVP%] assaut coordonne ouvert tick (%d+)")
  local joined = {}
  for _, l in ipairs(pvp_lines("^%[FO%-PVP%] attaque tick (%d+)")) do
    if l.line:find("(assaut coordonne)", 1, true) then joined[#joined + 1] = l end
  end
  -- Chaque attaque jointe part dans la fenêtre (3 min) d'une attaque prête d'une AUTRE faction (le départ
  -- suit la décision du temps de calcul de l'itinéraire : marge de 10 s).
  local inside = #joined > 0
  for _, j in ipairs(joined) do
    local key = j.line:match("^%[FO%-PVP%] attaque tick %d+ (%a+)")
    local ok = false
    for _, o in ipairs(opens) do
      local by = o.line:match("par (%a+)")
      if by ~= key and o.tick <= j.tick and j.tick <= o.tick + S.rally_ticks("merciless") + 600 then ok = true end
    end
    if not ok then inside = false end
  end
  local total = 0
  for i = 1, 4 do total = total + fac(i).pvp.attacks end
  print(string.format("  Impitoyable, 6 tourelles, 40 min : %d attaques, dont %d jointes ; %d fenêtres ouvertes", total, #joined, #opens))
  check(#opens >= 1 and #joined >= 1 and inside,
    string.format("Impitoyable : assaut coordonné (%d attaques jointes, chacune dans la fenêtre d'une autre faction)", #joined))
  check(printed("fo-pvp.attack-joined:") == #joined, "attaques jointes annoncées au joueur (« se joint à l'assaut »)")
  local st = remote.call("fo-pvp", "status")
  local joins = 0
  for _, f in ipairs(st.factions) do joins = joins + f.joins end
  check(joins == #joined and st.rally_until ~= nil, "statut : attaques jointes et fenêtre exposées")
end

---------------------------------------------------------------------------------------------------
section("Runtime : coût borné du repérage")
do
  new_world("normal")
  war("start 2 60 6 320")
  local s = W().surface
  local real = s.count_entities_filtered
  local calls = 0
  s.count_entities_filtered = function(t)
    if t.force == "player" then calls = calls + 1 end
    return real(t)
  end
  M.run_ticks(MIN)
  s.count_entities_filtered = real
  local bound = math.ceil(MIN / F.pvp_rules.scan_period) * F.pvp_rules.scan_per_pass
  check(calls <= bound + 8, string.format("au plus %d comptages par minute (mesuré : %d)", bound, calls))
  -- Lot IA2-c : plus de balayage global (disque de 1 793 secteurs) : chaque regard porte sur un secteur du champ des
  -- yeux d'une faction (1 comptage), les factions à tour de rôle, au plus un regard par passe de 8 ticks.
  local looks = pvp().sweeps
  check(looks > 0 and looks <= math.ceil(MIN / F.pvp_rules.scan_period), string.format("regards sous brouillard : %d en 1 min (au plus %d)",
    looks, math.ceil(MIN / F.pvp_rules.scan_period)))
  check(F.pvp_rules.scan_per_pass == 1, "au plus 1 comptage par tick porteur (pic de coût minimal)")
end

---------------------------------------------------------------------------------------------------
section("Runtime : sauvegarde d'avant IA0 (guerre en cours, sans état PvP)")
do
  new_world("normal")
  war("start 2 60 6 320")
  M.run_ticks(12 * MIN)
  local w = global.fo.war
  -- Ce qu'avait une guerre d'avant IA0 : aucun état PvP ; Azur avait été provoquée (cessez-le-feu rompu).
  w.pvp = nil
  for _, f in pairs(w.factions) do f.pvp = nil end
  game.forces[fac(1).force].set_cease_fire(game.forces.player, true)
  game.forces.player.set_cease_fire(game.forces[fac(1).force], true)
  game.forces[fac(2).force].set_cease_fire(game.forces.player, false)
  game.forces.player.set_cease_fire(game.forces[fac(2).force], false)
  local t_load = game.tick
  M.load_mod()
  local ok, err = pcall(M.dispatch, W().on_config, { mod_changes = {} })
  check(ok, "on_configuration_changed sans erreur (" .. tostring(err) .. ")")
  check(pvp() ~= nil and pvp().anchor == t_load, "état PvP créé, grâce comptée depuis le chargement")
  check(printed("fo-pvp.resumed:") == 1, "joueur prévenu (nouveau réglage, grâce depuis maintenant)")
  check(not ceasefire(2) and fac(2).pvp.provoked and fac(2).pvp.inherited and fac(2).pvp.declared,
    "Azur, déjà hostile : hostilité héritée (provoquée, en guerre déclarée en Normal)")
  check(printed("fo-pvp.inherited:") == 1 and printed("fo-pvp.declare:") == 0 and printed("fo-pvp.declare-provoked:") == 0,
    "hostilité héritée annoncée une fois, sans fausse « déclaration de guerre »")
  check(ceasefire(1) and not fac(1).pvp.provoked and not fac(1).pvp.declared, "Écarlate, en cessez-le-feu : grâce normale")
  local gn = S.grace_ticks("normal", char(1))
  M.run_ticks(gn - MIN)
  check(not fac(1).pvp.declared and ceasefire(1), string.format("Écarlate : grâce de %.1f min comptée depuis le chargement", gn / MIN))
  check(fac(1).pvp.attacks == 0, "aucune attaque d'Écarlate contre le joueur pendant la grâce reprise")
  M.run_ticks(2 * MIN)
  check(fac(1).pvp.declared, string.format("Écarlate déclare la guerre %.1f min après le chargement", gn / MIN))
  check(printed("fo-pvp.declare:") == 1, "une seule déclaration annoncée (Écarlate), aucune pour Azur")
  check(remote.call("fo-pvp", "set_difficulty", "peaceful") == true, "passage en Paisible")
  check(ceasefire(1) and not ceasefire(2), "Paisible : trêve d'Écarlate, Azur (hostilité héritée) reste hostile comme avant IA0")
  -- Même chose sans on_configuration_changed (script modifié sans changement de version) : état créé à la
  -- pensée suivante.
  global.fo.war.pvp = nil
  for _, f in pairs(global.fo.war.factions) do f.pvp = nil end
  M.run_ticks(301)
  check(pvp() ~= nil and printed("fo-pvp.resumed:") == 2, "état PvP recréé à la pensée suivante")
end

---------------------------------------------------------------------------------------------------
section("Runtime : Facile puis Impitoyable à 15 min, préavis garanti")
do
  new_world("easy")
  war("start 2 60 6 320")
  M.run_ticks(15 * MIN)
  check(not fac(1).pvp.declared and ceasefire(1), "Facile, 15 min : Écarlate en cessez-le-feu (grâce 30 min)")
  local warns0 = printed("fo-pvp.warn:")
  local t_switch = game.tick
  check(remote.call("fo-pvp", "set_difficulty", "merciless") == true, "passage à Impitoyable (grâce du conquérant 6,7 min, déjà écoulée)")
  M.run_ticks(300)
  check(not fac(1).pvp.declared and ceasefire(1), "pas de déclaration immédiate")
  check(printed("fo-pvp.warn:") > warns0, "préavis affiché après le changement")
  M.run_ticks(t_switch + F.pvp_rules.warn_ticks - game.tick - 1)
  check(not fac(1).pvp.declared, "rien avant la fin du préavis (2 min)")
  M.run_ticks(301)
  check(fac(1).pvp.declared and not ceasefire(1), "déclaration à la fin du préavis")
end

---------------------------------------------------------------------------------------------------
section("Runtime : partie continue = partie rechargée (désynchronisation à l'arrivée d'un joueur)")
do
  -- Partie continue en Difficile (graine fixe), pas à pas : tick de la déclaration d'Écarlate, puis 1re
  -- route en attente vers le joueur. Puis deux parties rechargées (copie fidèle de global, références
  -- partagées conservées), comparées à la partie continue 10 min après la route.
  local function start() new_world("hard", { seed = 7 }); war("start 2 60 6 320") end
  start()
  local t_decl, t_route
  while game.tick < 40 * MIN and not t_route do
    M.run_ticks(1)
    if not t_decl and fac(1).pvp.declared then t_decl = game.tick end
    if t_decl then
      for i = 1, 2 do
        local rp = fac(i).route_pending
        if rp and rp.target_faction == "player" then t_route = game.tick end
      end
    end
  end
  check(t_decl ~= nil and t_route ~= nil, "déclaration et route vers le joueur trouvées (" .. tostring(t_decl) .. ", " .. tostring(t_route) .. ")")
  if t_decl and t_route then
    local t_end = t_route + 10 * MIN
    M.run_ticks(t_end - game.tick)
    local ref = M.serialize(global)
    local att = fac(1).pvp.attacks + fac(2).pvp.attacks
    print(string.format("  déclaration d'Écarlate au tick %d, route vers le joueur en attente au tick %d, comparaison au tick %d (%d attaques contre le joueur)",
      t_decl, t_route, t_end, att))
    local function reloaded(at)
      start()
      M.run_ticks(at - game.tick)
      local saved = M.deepcopy_global(global)
      M.load_mod()
      _G.global = saved
      W().on_load()
      M.run_ticks(t_end - game.tick)
      return M.serialize(global)
    end
    check(reloaded(t_decl + 1) == ref, "rechargée juste après la déclaration : global identique à la partie continue (" .. att .. " attaques contre le joueur)")
    check(reloaded(t_route) == ref, "rechargée pendant le calcul d'une route vers le joueur : global identique")
    check(att > 0, "la partie comparée comporte des attaques contre le joueur")
  end
end

---------------------------------------------------------------------------------------------------
section("Déterminisme")
local function scenario()
  new_world("hard", { seed = 7 })
  war("start 2 60 6 320")
  -- Lot IA2-0 : personnalités tirées de la graine (graine 7 : technocrate et équilibré, au lieu de conquérant et
  -- technocrate ; grâces en Difficile 21,9 et 20,4 min selon les traits) : 36 min de partie (25 avant IA2-0).
  M.run_ticks(36 * MIN)
  return M.serialize(global), fac(1).pvp.attacks + fac(2).pvp.attacks
end
local s1, n1 = scenario()
local s2, n2 = scenario()
check(s1 == s2, "deux parties identiques en Difficile produisent le même état global (" .. n1 .. " attaques contre le joueur)")
check(n1 > 0, "le scénario de déterminisme comporte des attaques contre le joueur")

---------------------------------------------------------------------------------------------------
section("Coexistence : défense de tours et arrêt de la guerre")
do
  new_world("merciless")
  war("start 2 60 6 320")
  M.command("fo-waves", "on 1")
  local ok, err = pcall(M.run_ticks, 20 * MIN)
  check(ok, "guerre (Impitoyable) + vagues pendant 20 min sans erreur (" .. tostring(err) .. ")")
  check(global.fo.td.wave >= 1, "les vagues tournent")
  war("stop")
  M.run_ticks(2)
  check(global.fo.war.pvp == nil and not require("script.core.scheduler").has("fo-pvp-scan", 1), "arrêt : état PvP et repérage retirés")
  ok = pcall(M.run_ticks, 600)
  check(ok, "le jeu continue après l'arrêt")
  war("start 2 60 6 320")
  check(pvp() ~= nil and pvp().anchor == game.tick, "relance : état PvP neuf")
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
