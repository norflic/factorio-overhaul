--[[
  N104-ERREURS : test PUR du journal d'erreurs de partie (shared/debug/erreurs_partie.lua), avec mutants (chaque mutant doit rendre la
  batterie ROUGE). Valeurs tirées des journaux : partie du DC (dc-final.log, 0.9.10, graine 2030089248 : épargne 41 891 à 73 min, demande
  nominale 29 860 kW pour 25 200 kW bâtis) et banc N100-INT-4251870853 (emerald à 87 min : 3 chaudières nourries sur 15, 27 000 kW,
  demande 32 093 kW).
  Lancement (racine du mod) : lua5.2 tests/n104_erreurs_test.lua   -> [N104-ERREURS] BILAN : N OK, 0 ECHEC(S)
]]
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1; print("[N104-ERREURS] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local PATH = "shared/debug/erreurs_partie.lua"
local SRC = read(PATH)
local function load_e(src) return assert(load(src, "=" .. PATH, "t", _ENV))() end
local function sub1(src, a, b, name)
  local i, j = src:find(a, 1, true)
  assert(i, "mutant introuvable : " .. name)
  assert(not src:find(a, j + 1, true), "mutant ambigu : " .. name)
  return src:sub(1, i - 1) .. b .. src:sub(j + 1)
end

local function has(lines, pat)
  for _, l in ipairs(lines) do if l:find(pat, 1, true) then return true end end
  return false
end
local function cats_of(E, facts, cfg)
  local out = {}
  for _, c in ipairs(E.conds(facts, cfg)) do out[c.cat] = (out[c.cat] or 0) + 1 end
  return out
end

-- Rend le nombre d'échecs de la batterie (quiet : ne rien imprimer).
local function battery(E, quiet)
  local bad = 0
  local function ok(c, msg) if not c then bad = bad + 1; if not quiet then print("  - " .. msg) end end end
  local cfg = E.seuils({ cap = 40 })
  ok(cfg.durable == 5 and cfg.stall == 10 and cfg.h_epargne == 10, "seuils derives : T_LAG 5, blocage 10, horizon du stock 10")

  -- 1. Épargne qui dort (DC, 73 min) : budget engagé 56 MU pour un flux de 1 396 MU/min, épargne 41 891 > 10 × 1 396
  local dc73 = { capi = { Y = 2792.7, spent = 56.0, budget = 49559.9, bank = 41891.1, s = 500, delta = 0, alpha = 0 } }
  ok(cats_of(E, dc73, cfg)["INVESTISSEMENT:epargne_dort"] == 1, "DC 73 min : epargne qui dort")
  -- 66 min : 2 982 MU engagés (plus d'une minute de flux) : rien ne dort
  local dc66 = { capi = { Y = 2631.2, spent = 2982.1, budget = 49541.6, bank = 39468.6, s = 500, delta = 0, alpha = 0 } }
  ok(cats_of(E, dc66, cfg)["INVESTISSEMENT:epargne_dort"] == nil, "DC 66 min : budget engage, pas d'epargne qui dort")
  -- épargne de 5 min de flux seulement : sous le seuil
  local petit = { capi = { Y = 1000, spent = 0, budget = 2500, bank = 2500, s = 500, delta = 0, alpha = 0 } }
  ok(cats_of(E, petit, cfg)["INVESTISSEMENT:epargne_dort"] == nil, "epargne sous 10 min de flux : rien")

  -- 2. Déficit électrique DURABLE (DC 72 -> 86 min) : ouvert à la 5e minute, pas avant ; épargne au détail ; fermé à la reprise
  local st = E.new()
  local lines_all = {}
  for m = 72, 80 do
    local f = { elec = { demand = 29225 + (m - 72) * 600, cap = 25200, fed = 7, boilers = 14 }, capi = dc73.capi }
    local l = E.step(st, "player", m, E.conds(f, cfg), cfg)
    for _, x in ipairs(l) do lines_all[#lines_all + 1] = { m, x } end
  end
  local open_at
  for _, r in ipairs(lines_all) do if r[2]:find("FLUX:deficit_electrique", 1, true) and r[2]:find("etat=ouvre", 1, true) then open_at = open_at or r[1] end end
  ok(open_at == 77, "deficit electrique ouvert a 77 min (72 + T_LAG), vu " .. tostring(open_at))
  local with_bank = false
  for _, r in ipairs(lines_all) do if r[2]:find("deficit_electrique", 1, true) and r[2]:find("epargne=41891", 1, true) then with_bank = true end end
  ok(with_bank, "le detail du deficit porte l'epargne")
  local l = E.step(st, "player", 81, E.conds({ elec = { demand = 20000, cap = 30600, fed = 17, boilers = 17 } }, cfg), cfg)
  ok(has(l, "FLUX:deficit_electrique min=81 - etat=fin duree=9"), "deficit ferme a 81 min, duree 9 min")
  ok(st.stats["FLUX:deficit_electrique"].n == 1 and st.stats["FLUX:deficit_electrique"].dur == 9, "bilan : 1 episode, 9 min")

  -- 2 bis. Sous-production : 4 min ne font pas une erreur (le niveau du bilan clignote), 6 min si
  local sm = E.new()
  for m = 1, 4 do E.step(sm, "amber", m, E.conds({ sous = { { "x", -20, 0 } } }, cfg), cfg) end
  E.step(sm, "amber", 5, {}, cfg)
  ok(sm.stats["FLUX:deficit_matiere"] == nil, "sous-production de 4 min : rien")
  for m = 6, 12 do E.step(sm, "amber", m, E.conds({ sous = { { "x", -20, 0 } } }, cfg), cfg) end
  ok(sm.stats["FLUX:deficit_matiere"] and sm.stats["FLUX:deficit_matiere"].n == 1, "sous-production durable : erreur")

  -- 3. Chaudières à sec (emerald, 4251, 87 min) : 3/15 nourries, capacité utile 5 400 kW < 32 093 kW
  local em = { elec = { demand = 32093, cap = 27000, fed = 3, boilers = 15 } }
  ok(cats_of(E, em, cfg)["FLUX:chaudieres_a_sec"] == 1, "emerald 87 min : chaudieres a sec")
  -- une chaudière à sec sur 15, capacité utile 25 200 kW > demande 20 000 : pas une erreur
  ok(cats_of(E, { elec = { demand = 20000, cap = 27000, fed = 14, boilers = 15 } }, cfg)["FLUX:chaudieres_a_sec"] == nil,
    "une chaudiere seche sans manque de courant : rien")

  -- 4. Besoin non couvert SANS augmentation : la capacité monte -> l'attente repart ; plate -> ouvert après T_LAG
  local sb = E.new()
  for m = 1, 8 do E.step(sb, "azure", m, E.conds({ besoins = { { "x", 100, m * 10 } } }, cfg), cfg) end
  ok(sb.stats["FLUX:besoin_non_couvert"] == nil, "besoin avec capacite qui monte : pas d'erreur")
  local sc = E.new()
  for m = 1, 8 do E.step(sc, "azure", m, E.conds({ besoins = { { "x", 100, 30 } } }, cfg), cfg) end
  ok(sc.stats["FLUX:besoin_non_couvert"] and sc.stats["FLUX:besoin_non_couvert"].n == 1, "besoin sans hausse de capacite : erreur")

  -- 5. Projet bloqué : âge porté par le fait, daté de son début
  local sp = E.new()
  local lp = E.step(sp, "scarlet", 30, E.conds({ bloques = { { pid = 49, age = 35, built = 0, total = 110, x = 26.5, y = 33.5, cause = "chantier", kind = "bloc" } } }, cfg), cfg)
  ok(has(lp, "INVESTISSEMENT:projet_bloque min=30 26,33 etat=ouvre depuis=-5"), "projet bloque date de son debut")
  ok(cats_of(E, { bloques = { { pid = 1, age = 9 } } }, cfg)["INVESTISSEMENT:projet_bloque"] == nil, "9 min sans progres : pas encore bloque")

  -- 6. Attaques répétées sans tourelle ajoutée ; avec une tourelle de plus : défendu
  ok(cats_of(E, { attaques = { { ck = "3:-2", x = 100, y = -50, vagues = 3, perdus = 7, pv = 2100, t0 = 0, t1 = 0, par = "enemy" } } }, cfg)["DEFENSE:attaque_repetee"] == 1,
    "3 vagues, aucune tourelle : erreur")
  ok(cats_of(E, { attaques = { { ck = "3:-2", vagues = 3, t0 = 0, t1 = 2 } } }, cfg)["DEFENSE:attaque_repetee"] == nil, "tourelles ajoutees : defendu")
  ok(cats_of(E, { attaques = { { ck = "3:-2", vagues = 1, t0 = 0, t1 = 0 } } }, cfg)["DEFENSE:attaque_repetee"] == nil, "une seule vague : pas repetee")

  -- 7. Bande au cadre posé sans foreuse : seulement après le délai de blocage (10 min)
  local sv = E.new()
  local seen
  for m = 20, 31 do
    for _, x in ipairs(E.step(sv, "player", m, E.conds({ vides = { { pid = 91, x = -38, y = 10, cadre = 120 } } }, cfg), cfg)) do
      if x:find("bande_sans_foreuses", 1, true) then seen = seen or m end
    end
  end
  ok(seen == 30, "bande sans foreuses ouverte a 30 min (20 + 10), vu " .. tostring(seen))

  -- 8. Culs-de-sac : seules les impasses et les coupures sont des erreurs
  local cu = cats_of(E, { culs = { { classe = "impasse", x = 1, y = 2, n = 8 }, { classe = "alimentation", x = 3, y = 4, n = 8 },
    { classe = "coupe", x = 5, y = 6, n = 8 }, { classe = "souterrain_ampute", x = 7, y = 8, n = 9 } } }, cfg)
  ok(cu["PLACEMENT:cul_de_sac"] == 1 and cu["PLACEMENT:tapis_coupe"] == 2, "impasse et coupures comptees, alimentation non")

  -- 9. Plafond des lignes par catégorie ; le bilan compte tout
  local sx = E.new()
  local conds = {}
  for i = 1, 45 do conds[i] = { cat = "PLACEMENT:chevauchement", key = "p" .. i, val = 1, txt = "" } end
  local lx = E.step(sx, "amber", 5, conds, cfg)
  local opens = 0
  for _, x in ipairs(lx) do if x:find("etat=ouvre", 1, true) then opens = opens + 1 end end
  ok(opens == 40 and has(lx, "etat=plafond"), "40 lignes ouvertes au plus, une ligne de plafond")
  ok(E.bilan(sx, "amber", 5):find("PLACEMENT:chevauchement=45/45/1", 1, true) ~= nil, "le bilan compte les 45 episodes")

  -- 10. Classe des tapis : la même règle que la sonde du scénario
  local Cc = load(read("tools/autotest/fo-autotest/scenarios/cul_classe.lua"), "=cul_classe", "t", _ENV)()
  local same = true
  for _, sp_ in ipairs({ true, false }) do for _, ug in ipairs({ true, false }) do for _, pr in ipairs({ 0, 2 }) do
    for _, occ in ipairs({ "nil", 7, 8, "cadre:1" }) do
      local c = { suite_a_poser = sp_, souterrain_seul = ug, preneurs = pr, occ_suiv = occ ~= "nil" and occ or nil, propre = 7 }
      if E.cul_classe(c) ~= Cc.classe(c) then same = false end
    end
  end end end
  ok(same, "E.cul_classe = scenarios/cul_classe.lua sur les 32 combinaisons")
  return bad
end

local E = load_e(SRC)
check(battery(E, false) == 0, "batterie sur le code livre")

-- Aucun nom d'objet du jeu dans la règle (anti-noms, tests/iag_test.lua §8)
for _, w in ipairs({ "iron-", "copper-", "\"coal\"", "-plate", "mining-drill", "-turret\"", "transport-belt", "steam-engine" }) do
  check(not SRC:find(w, 1, true), "aucun nom d'objet dans la regle : " .. w)
end

local MUTANTS = {
  { "durable ignore", "local need = (cfg.durable_of or {})[c.cat] or 0", "local need = 0" },
  { "epargne sans la garde du budget engage", "if pm > 0 and num(c.spent) <= pm and num(c.bank) >= seuil then", "if pm > 0 and num(c.bank) >= seuil then" },
  { "epargne au seuil nul", "local seuil = cfg.h_epargne * pm", "local seuil = 0" },
  { "chaudieres sans la capacite utile", "if nb > 0 and fed < nb and cap * fed / nb < d then", "if nb > 0 and fed < nb then" },
  { "besoin sans la garde d'augmentation", "local grown = c.grow ~= nil and ep.grow0 ~= nil and c.grow > ep.grow0", "local grown = false" },
  { "attaque sans la garde des tourelles", "if num(a.vagues) >= 2 and num(a.t1) <= num(a.t0) then", "if num(a.vagues) >= 2 then" },
  { "bloque sans le delai", "if num(p.age) >= cfg.stall then\n      add(\"INVESTISSEMENT:projet_bloque\"", "if true then\n      add(\"INVESTISSEMENT:projet_bloque\"" },
  { "age ignore", "t0 = minute - (c.age and math.floor(num(c.age)) or 0)", "t0 = minute" },
  { "classe sans les preneurs", "  if (c.preneurs or 0) > 0 then return \"alimentation\" end\n", "" },
  { "plafond ignore", "if n <= (cfg.cap or 40) then", "if true then" },
}
for _, m in ipairs(MUTANTS) do
  local ok_, Em = pcall(function() return load_e(sub1(SRC, m[2], m[3], m[1])) end)
  check(ok_ and battery(Em, true) > 0, "mutant rouge : " .. m[1])
end

print(string.format("[N104-ERREURS] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
