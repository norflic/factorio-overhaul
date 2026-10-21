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
local LEVELS = F.pvp_order
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
      due_since = o.due_since, grace_floor = o.grace_floor,
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
  a = S.decide(view("normal", 40 * MIN, { declared = true, defense = 40 }))
  check(a.attack == nil and a.plan == "save" and a.due_since == 40 * MIN, "joueur trop défendu (40 × 1,3 > 32) : la faction accumule d'abord (attente démarrée)")
  a = S.decide(view("normal", 40 * MIN, { declared = true, defense = 40, due_since = 37 * MIN }))
  check(a.attack and a.attack.target == 2 and a.plan == "fallback", "après 3 min d'attente, toujours hors d'atteinte : repli sur la rivale")
  a = S.decide(view("normal", 40 * MIN, { declared = true, defense = 24 }))
  check(a.attack and a.attack.target == "player", "force 32 ≥ 1,3 × 24 : attaque contre le joueur")
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
  check(a.attack and a.attack.target == "player" and a.attack.count == 13, "Difficile : après 5 min d'attente, attaque avec 13 (≥ minimum 11)")
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

do -- Équivalence avec la décision d'avant IA0 quand le joueur n'est pas visé
  local same = true
  for _, p in ipairs(PERS) do
    for g = 0, 100, 3 do
      for _, def in ipairs({ 0, 5, 10, 20, 40, 80, math.huge }) do
        local v = view("peaceful", 100 * MIN, { personality = p, garrison = g, enemy_defense = def })
        local old = S.attack(v)
        local a = S.decide(v)
        local new = a.attack and a.attack.count
        if old ~= new or (a.attack and a.attack.target ~= 2) then same = false end
      end
    end
  end
  check(same, "Paisible : décision identique à celle d'avant IA0 (4 personnalités × 34 garnisons × 7 défenses)")
end

---------------------------------------------------------------------------------------------------
section("Campagne pure de 180 min (mesures par niveau)")
-- Modèle : +1 soldat toutes les 45 s (plafond 100), une pensée toutes les 5 s, une rivale toujours
-- disponible (défense 10, `own` avant-postes comme la faction). Un groupe envoyé revient 5 min plus tard
-- avec 60 % de survivants. Configurations (cfg) : secteurs du joueur (score), avant-postes de la faction
-- (own), défense de la cible joueur (defense), niveau technologique (tech).
local CONFIGS = {
  { name = "joueur non leader (4 secteurs, 1 tourelle, tech 0)", score = 4, own = 4, defense = 8, tech = 0, leader = false },
  { name = "joueur leader (12 secteurs contre 4 avant-postes, 1 tourelle, tech 0)", score = 12, own = 4, defense = 8, tech = 0, leader = true },
  { name = "leader défendu (12 secteurs, 3 tourelles, tech 1)", score = 12, own = 4, defense = 24, tech = 1, leader = true },
  { name = "gros leader (40 secteurs contre 7 avant-postes, 6 tourelles, tech 2)", score = 40, own = 7, defense = 48, tech = 2, leader = true },
}
local function campaign(level, pers, minutes, cfg)
  cfg = cfg or CONFIGS[1]
  local garrison, total, acc = 0, 0, 0
  local fp = { declared = false, provoked = false, warned = false, sent_player = 0, sent_total = 0 }
  local back = {}
  local r = { attacks = 0, soldiers = 0, first = nil, declare = nil, warn = nil, rival = 0, rival_war = 0, sent_total = 0 }
  for tick = 300, minutes * MIN, 300 do
    acc = acc + 300
    while acc >= 2700 do
      acc = acc - 2700
      if total < 100 then garrison, total = garrison + 1, total + 1 end
    end
    local keep = {}
    for _, b in ipairs(back) do
      if b.at <= tick then
        local alive = math.floor(b.n * 0.6)
        garrison = garrison + alive
        total = total - (b.n - alive)
      else keep[#keep + 1] = b end
    end
    back = keep
    local v = {
      personality = pers, tech = cfg.tech, upgrades = 0, garrison = garrison, soldiers_max = 100, can_attack = true,
      enemy_defense = 10, rival = { id = 2, outposts = cfg.own }, own_outposts = cfg.own, leader_outposts = cfg.own,
      pvp = { difficulty = level, tick = tick, anchor = 0, declared = fp.declared, provoked = false, warned = fp.warned,
        last_attack = fp.last_attack, sent_player = fp.sent_player, sent_total = fp.sent_total, player_groups = 0,
        due_since = fp.due_since },
      player = { score = cfg.score, defense = cfg.defense, reachable = true },
    }
    local a = S.decide(v)
    if a.warn then fp.warned = true; r.warn = r.warn or tick end
    if a.declare then fp.declared = true; fp.sent_player, fp.sent_total, fp.due_since = 0, 0, nil; r.declare = tick end
    if a.due_since ~= nil then fp.due_since = a.due_since or nil end
    if a.attack then
      local n = a.attack.count
      garrison = garrison - n
      back[#back + 1] = { at = tick + 5 * MIN, n = n }
      fp.sent_total = fp.sent_total + n
      if fp.declared then r.sent_total = r.sent_total + n end
      if a.attack.target == "player" then
        fp.sent_player = fp.sent_player + n
        fp.last_attack, fp.due_since = tick, nil
        r.attacks, r.soldiers = r.attacks + 1, r.soldiers + n
        r.first = r.first or tick
      else
        r.rival = r.rival + 1
        if fp.declared then r.rival_war = r.rival_war + 1 end
      end
    end
  end
  r.mean = r.attacks > 0 and r.soldiers / r.attacks or 0
  r.share = r.sent_total > 0 and r.soldiers / r.sent_total or 0
  return r
end

-- Ordre STRICT exigé dans chaque configuration (C4-3), et des guerres entre factions qui continuent après
-- la déclaration : au moins RIVAL_MIN attaques contre la rivale en Normal et en Difficile, au moins 1 en
-- Impitoyable (coalition : au moins 7,5 % des soldats restent pour les rivales).
local RIVAL_MIN = 4
for ci, cfg in ipairs(CONFIGS) do
  print("  -- " .. cfg.name)
  print("  niveau      personnalité  déclaration  1re attaque  attaques  soldats  taille moy.  part   (rivale : total / après déclaration)")
  local camp = {}
  for _, p in ipairs(PERS) do
    camp[p] = {}
    for _, lv in ipairs(LEVELS) do
      local r = campaign(lv, p, 180, cfg)
      camp[p][lv] = r
      print(string.format("  %-11s %-13s %11s  %11s  %8d  %7d  %11.1f  %4.0f %%  (%d / %d)", lv, p,
        r.declare and string.format("%.1f min", r.declare / MIN) or "-", r.first and string.format("%.1f min", r.first / MIN) or "jamais",
        r.attacks, r.soldiers, r.mean, r.share * 100, r.rival, r.rival_war))
    end
  end
  local tag = "[config " .. ci .. "] "
  check(S.player_is_leader({ player = { score = cfg.score }, own_outposts = cfg.own, leader_outposts = cfg.own }) == cfg.leader,
    tag .. "joueur " .. (cfg.leader and "leader" or "non leader") .. " comme prévu")
  for _, p in ipairs(PERS) do
    local c = camp[p]
    local t = tag .. p
    check(c.peaceful.attacks == 0 and c.peaceful.declare == nil, t .. " : Paisible, 0 attaque contre le joueur en 180 min")
    check(c.normal.first ~= nil and c.normal.first >= S.grace_ticks("normal", p), t .. " : Normal attaque, après la grâce")
    local inf = 1e18
    local function first(lv) return c[lv].first or inf end
    check(first("easy") > first("normal") and first("normal") > first("hard") and first("hard") > first("merciless"),
      t .. " : 1re attaque de plus en plus tôt (Facile > Normal > Difficile > Impitoyable)")
    check(c.easy.attacks < c.normal.attacks and c.normal.attacks < c.hard.attacks and c.hard.attacks < c.merciless.attacks,
      t .. " : attaques de plus en plus fréquentes")
    check(c.easy.mean < c.normal.mean and c.normal.mean < c.hard.mean and c.hard.mean < c.merciless.mean,
      t .. " : attaques de plus en plus nombreuses (taille moyenne)")
    check(c.easy.share < c.normal.share and c.normal.share < c.hard.share and c.hard.share < c.merciless.share,
      t .. " : part des forces contre le joueur croissante")
    check(c.normal.rival_war >= RIVAL_MIN and c.hard.rival_war >= RIVAL_MIN and c.merciless.rival_war >= 1,
      string.format("%s : les guerres entre factions continuent après la déclaration (rivale : Normal %d, Difficile %d, Impitoyable %d)",
        t, c.normal.rival_war, c.hard.rival_war, c.merciless.rival_war))
  end
end
local c1, c2 = campaign("hard", "balanced", 120), campaign("hard", "balanced", 120)
check(c1.attacks == c2.attacks and c1.soldiers == c2.soldiers and c1.first == c2.first, "campagne pure déterministe")

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
local function new_world(level, extra)
  local o = { patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = level, groups_hit_player = true,
    turrets_kill = true }
  for k, v in pairs(extra or {}) do o[k] = v end
  M.new_game(o)
  local w = W()
  w.prototypes["assembling-machine-1"] = { type = "assembling-machine", max_health = 300 }
  local s = w.surface
  for i = 0, 3 do s.create_entity({ name = "assembling-machine-1", position = { x = OUTPOST.x - 6 + 4 * i, y = OUTPOST.y }, force = "player" }) end
  for i = 0, 1 do s.create_entity({ name = "stone-furnace", position = { x = OUTPOST.x - 2 + 4 * i, y = OUTPOST.y + 4 }, force = "player" }) end
  local t = s.create_entity({ name = "gun-turret", position = { x = OUTPOST.x, y = OUTPOST.y - 4 }, force = "player" })
  t.insert({ name = "piercing-rounds-magazine", count = 50 })
  for i = 0, 2 do s.create_entity({ name = "assembling-machine-1", position = { x = 10 + 4 * i, y = 10 }, force = "player" }) end
end
local function war(text) M.command("fo-war", text) end
local function printed(key)
  local n = 0
  for _, line in ipairs(W().game_prints) do if line:find(key, 1, true) then n = n + 1 end end
  return n
end
local function pvp() return global.fo.war.pvp end
local function fac(i) return global.fo.war.factions[i] end
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
local function measure(level, minutes)
  new_world(level)
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
  check(pvp().score >= 2, "repérage : base de départ et avant-poste du joueur trouvés en 40 s (" .. pvp().score .. " secteurs)")
  local g1 = S.grace_ticks("normal", fac(1).personality)
  M.run_ticks(g1 - 2 * MIN - game.tick + 300)
  check(printed("fo-pvp.warn:") >= 1, "préavis affiché avant la fin de la grâce")
  M.run_ticks(g1 - game.tick - 1)
  check(ceasefire(1) and not fac(1).pvp.declared and player_groups(1) == 0, "rien pendant la grâce (Écarlate, 20 min)")
  M.run_ticks(301)
  check(fac(1).pvp.declared and not ceasefire(1), "Écarlate déclare la guerre à la fin de sa grâce")
  check(printed("fo-pvp.declare:") >= 1, "déclaration annoncée au joueur")
  check(ceasefire(2), "Azur (technocrate, 37,5 min) toujours en cessez-le-feu")
  local before = player_buildings()
  M.run_ticks(20 * MIN)
  local fp = fac(1).pvp
  check(fp.attacks >= 1, "Écarlate a attaqué le joueur (" .. fp.attacks .. " attaques, " .. fp.soldiers .. " soldats)")
  check(printed("fo-pvp.attack:") >= 1 and printed("[gps=") >= 1, "départ d'attaque annoncé, avec lien [gps]")
  local t = fp.target
  check(t and t.pos.x < -64 and t.pos.y >= 64, "cible : l'avant-poste du joueur, pas la base de départ (« QG en dernier »)")
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
  local gh = S.grace_ticks("hard", fac(1).personality)
  M.run_ticks(gh - 301)
  check(not fac(1).pvp.declared and ceasefire(1), "Difficile : rien avant 12 min (grâce du conquérant), malgré les soldats abattus avant la trêve")
  M.run_ticks(602)
  check(fac(1).pvp.declared and not ceasefire(1), "Difficile : déclaration après 12 min")
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
  check(require("script.faction.pvp").SECTORS == 1793, "disque de 1 793 secteurs (rayon 24, balayage complet en " ..
    math.ceil(1793 / F.pvp_rules.scan_per_pass) * F.pvp_rules.scan_period .. " ticks)")
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
  M.run_ticks(19 * MIN)
  check(not fac(1).pvp.declared and ceasefire(1), "Écarlate : grâce de 20 min comptée depuis le chargement")
  check(fac(1).pvp.attacks == 0, "aucune attaque d'Écarlate contre le joueur pendant la grâce reprise")
  M.run_ticks(2 * MIN)
  check(fac(1).pvp.declared, "Écarlate déclare la guerre 20 min après le chargement")
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
  M.run_ticks(25 * MIN)
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
