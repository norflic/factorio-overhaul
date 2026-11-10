--[[
  Lot ASSAUTS-TITANESQUES (10/11) : banc hors jeu des assauts de boss (shared/combat/assaut_titan.lua). Lua 5.2, depuis la racine du mod :
      lua5.2 tests/assaut_titan_test.lua
    §1 déclenchement : aucune base -> jamais ; trop tôt (âge sous T.AGE_MIN ET évolution sous Ra.EVO_MIN) -> jamais ; sinon à la cadence
       (période qui baisse avec l'évolution et l'âge, plancher Ra.PERIODE_MIN) ; l'âge de la partie = le plus haut des forces ;
    §2 cible : la mieux défendue, rotation (les #bases - 1 dernières visées écartées), égalité -> plus petit id, déterminisme ;
    §3 composition : Kaiju de l'ère de l'âge en tête (nom par T.kaiju_name), escorte 1,5 par tourelle bornée [min, max], palier 2 par ère
       borné à E.TD_TIERS, 30 % de cracheurs, un Kaiju de plus toutes les 3 ères ; données changées (config à 18 époques) : rien en dur ;
    §4 points de rassemblement : à Ra.DISTANCE du centre, répartis sur 12 crans, sans trigonométrie, tour de rôle ;
    §5 phases : annonce -> rassemblement -> marche -> assaut -> tombee ; repoussee ; repli (Kaiju mort) -> fin ; bloque (timeout) ;
    §6 forme : aucun pairs ni hasard ni trigonométrie dans la règle, `global` jamais nommé, aucun nom de prototype entre guillemets ;
       le script lit la règle (Ra.pret, Ra.cible, Ra.composition, Ra.suivante), est requis par le directeur, l'interface distante existe ;
    §7 traductions : clés [fo-assaut] en FR et EN, mêmes clés ;
    §8 mutants (≥ 8) : chacun refusé par ce banc.
]]

package.path = "./?.lua;" .. package.path

local L = require("shared.levels.config")
local T = require("shared.robots.titans")
local E = require("shared.content.enemies")
local Ra = require("shared.combat.assaut_titan")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[ASSAUT] ECHEC : " .. msg) end
end
local function read(p)
  local f = assert(io.open(p, "rb"), "lecture impossible : " .. p)
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/combat/assaut_titan.lua")
local SCR = read("script/combat/assaut_titan.lua")

---------------------------------------------------------------------------------------------------
-- §1 déclenchement
---------------------------------------------------------------------------------------------------
check(Ra.age_partie({ 3, 9, 4 }) == 9 and Ra.age_partie({}) == 1 and Ra.age_partie({ "7", nil }) == 7, "§1 âge de la partie = le plus haut")
local ok, why = Ra.pret({ tick = 10 ^ 7, bases = 0, age = 15, evolution = 1 })
check(ok == false and why == "aucune base", "§1 aucune base : jamais")
ok, why = Ra.pret({ tick = 10 ^ 7, bases = 2, age = T.AGE_MIN - 1, evolution = Ra.EVO_MIN - 0.01 })
check(ok == false and why == "trop tot", "§1 âge sous T.AGE_MIN et évolution sous EVO_MIN : trop tôt")
ok, why = Ra.pret({ tick = 10 ^ 7, bases = 2, age = T.AGE_MIN - 1, evolution = Ra.EVO_MIN })
check(ok == true, "§1 évolution à EVO_MIN suffit (âge bas)")
ok, why = Ra.pret({ tick = 10 ^ 7, bases = 2, age = T.AGE_MIN, evolution = 0 })
check(ok == true, "§1 âge T.AGE_MIN suffit (évolution nulle)")
local p0 = Ra.periode(0, 1)
check(p0 == Ra.PERIODE, "§1 période au départ = Ra.PERIODE")
check(Ra.periode(1, 1) == math.max(Ra.PERIODE_MIN, math.floor(Ra.PERIODE * 0.5)), "§1 évolution pleine : période ÷ 2")
check(Ra.periode(1, L.EPOCHS) == Ra.PERIODE_MIN, "§1 évolution pleine et dernier âge : plancher")
local mono = true
for i = 0, 10 do
  if Ra.periode((i + 1) / 10, 5) > Ra.periode(i / 10, 5) then mono = false end
  if Ra.periode(0.3, i + 2) > Ra.periode(0.3, i + 1) then mono = false end
end
check(mono, "§1 période décroissante avec l'évolution et l'âge")
local pm = Ra.periode(0, T.AGE_MIN)
ok, why = Ra.pret({ tick = pm - 1, bases = 1, age = T.AGE_MIN, evolution = 0 })
check(ok == false and why == "cadence", "§1 avant la première période : cadence")
ok, why = Ra.pret({ tick = pm, bases = 1, age = T.AGE_MIN, evolution = 0 })
check(ok == true, "§1 à la période : prêt")
ok, why = Ra.pret({ tick = pm + 500, last = 1000, bases = 1, age = T.AGE_MIN, evolution = 0 })
check(ok == false and why == "cadence", "§1 depuis le DERNIER départ, pas depuis le début")

---------------------------------------------------------------------------------------------------
-- §2 cible
---------------------------------------------------------------------------------------------------
local bases = { { id = 1, defenses = 4 }, { id = 2, defenses = 9 }, { id = "player", defenses = 9 } }
local c = Ra.cible(bases, {})
check(c and c.id == 2, "§2 la mieux défendue ; égalité -> plus petit id (textuel : « 2 » < « player »)")
c = Ra.cible(bases, { 2 })
check(c and c.id == "player", "§2 rotation : la dernière visée est écartée")
c = Ra.cible(bases, { 2, "player" })
check(c and c.id == 1, "§2 rotation : les deux dernières visées écartées (#bases - 1)")
c = Ra.cible(bases, { 1, 2, "player" })
check(c and c.id == 1, "§2 rotation : seules les #bases - 1 DERNIÈRES comptent (la plus ancienne redevient visable)")
c = Ra.cible({ { id = 5, defenses = 1 } }, { 5 })
check(c and c.id == 5, "§2 une seule base : toujours visable")
local c1, c2 = Ra.cible(bases, { 2 }), Ra.cible({ bases[3], bases[1], bases[2] }, { 2 })
check(c1.id == c2.id, "§2 déterminisme : l'ordre d'entrée des bases ne change pas la cible")
check(Ra.cible({}, {}) == nil, "§2 aucune base : nil")

---------------------------------------------------------------------------------------------------
-- §3 composition
---------------------------------------------------------------------------------------------------
for age = 1, L.EPOCHS do
  local compo = Ra.composition(age, 10)
  local era = T.era(age)
  check(compo[1][1] == T.kaiju_name(era) and compo[1][2] == Ra.kaijus(era), "§3 âge " .. age .. " : Kaiju de l'ère " .. era .. " en tête")
end
check(Ra.kaijus(1) == 1 and Ra.kaijus(3) == 1 and Ra.kaijus(4) == 2, "§3 un Kaiju, puis un de plus toutes les 3 ères")
check(Ra.palier_escorte(1) == 2 and Ra.palier_escorte(T.ERAS) == math.min(E.TD_TIERS, 2 * T.ERAS), "§3 palier d'escorte 2 par ère, borné à E.TD_TIERS")
local m, cr = Ra.escorte(0)
check(m + cr == Ra.ESCORTE.min, "§3 sans tourelle : escorte minimale")
m, cr = Ra.escorte(1000)
check(m + cr == Ra.ESCORTE.max, "§3 mille tourelles : escorte plafonnée")
m, cr = Ra.escorte(20)
check(m + cr == 30 and cr == 9, "§3 vingt tourelles : 30 assaillants dont 30 % de cracheurs")
local compo = Ra.composition(10, 20)
check(compo[2][1] == E.unit_name("biter", Ra.palier_escorte(T.era(10))) and compo[3][1] == E.unit_name("spitter", Ra.palier_escorte(T.era(10))),
  "§3 mordeurs puis cracheurs du palier d'escorte (noms par E.unit_name)")
-- KAIJUS-MUTANTS : dès l'ère des Écorchés, une part Ra.ECORCHES des mordeurs est doublée d'Écorchés (variante tournante, nom par T.ecorche_name)
local ec = T.era(10) >= T.ECORCHE.era_min
check((#compo == 4) == ec and (not ec or (compo[4][1] == T.ecorche_name(T.ECORCHE.variants[1], T.era(10)) and compo[4][2] == math.ceil(21 * Ra.ECORCHES))),
  "§3 Écorchés en queue de composition dès leur ère (part des mordeurs)")
check(Ra.total(compo) == Ra.kaijus(T.era(10)) + 30 + (ec and math.ceil(21 * Ra.ECORCHES) or 0), "§3 total = Kaijus + escorte + Écorchés")
check(#Ra.composition(1, 20) == 3, "§3 ère 1 : aucun Écorché (ère non ouverte)")
local a1, a2 = Ra.composition(10, 20), Ra.composition(10, 20)
check(a1[1][1] == a2[1][1] and a1[2][2] == a2[2][2] and a1[3][2] == a2[3][2], "§3 déterminisme de la composition")
-- rotation des archétypes de Kaiju par le numéro de l'assaut (T.kaiju_pour) : 1er assaut cristallin, 2e Écorcheur dès son ère, puis retour
check(Ra.composition(10, 20, 1)[1][1] == T.kaiju_name(T.era(10), T.KAIJUS[1]) and Ra.composition(10, 20, 2)[1][1] == T.kaiju_name(T.era(10), T.kaiju_pour(T.era(10), 2))
  and Ra.composition(10, 20, 3)[1][1] == Ra.composition(10, 20, 1)[1][1], "§3 rotation des archétypes de Kaiju par le numéro de l'assaut")
check(Ra.composition(1, 20, 2)[1][1] == T.kaiju_name(1, T.KAIJUS[1]), "§3 ère 1 : seul le cristallin est ouvert, quel que soit le numéro")
check(Ra.composition(10, 20, 2)[4][1] == T.ecorche_name(T.ECORCHE.variants[2], T.era(10)), "§3 la variante d'Écorché tourne avec le numéro de l'assaut")
-- données changées : la règle suit la configuration (plus d'époques par ère)
do
  local ERA_SAVE, EPOCHS_SAVE = L.ERA_EPOCHS, L.EPOCHS
  L.ERA_EPOCHS = 2
  package.loaded["shared.robots.titans"] = nil
  local T2 = require("shared.robots.titans")
  package.loaded["shared.combat.assaut_titan"] = nil
  local Ra2 = require("shared.combat.assaut_titan")
  check(T2.era(10) == 5 and Ra2.composition(10, 1)[1][1] == T2.kaiju_name(5), "§3 données changées (2 époques par ère) : Kaiju de l'ère 5 à l'âge 10")
  L.ERA_EPOCHS = ERA_SAVE
  package.loaded["shared.robots.titans"] = nil
  package.loaded["shared.combat.assaut_titan"] = nil
  T = require("shared.robots.titans")
  Ra = require("shared.combat.assaut_titan")
end

---------------------------------------------------------------------------------------------------
-- §4 points de rassemblement
---------------------------------------------------------------------------------------------------
check(Ra.n_points(5) == 1 and Ra.n_points(30) == 2 and Ra.n_points(60) == 3 and Ra.n_points(1000) == Ra.POINTS.max, "§4 nombre de points par tranche de PAR_POINT, borné")
local pts = Ra.points({ x = 100, y = -50 }, 3, 0)
local okd = #pts == 3
for _, p in ipairs(pts) do
  local d = math.sqrt((p.x - 100) ^ 2 + (p.y + 50) ^ 2)
  if math.abs(d - Ra.DISTANCE) > 0.01 * Ra.DISTANCE then okd = false end
end
check(okd, "§4 trois points à Ra.DISTANCE du centre")
check(pts[1].x ~= pts[2].x or pts[1].y ~= pts[2].y, "§4 points distincts (répartis sur le cercle)")
local q1, q2 = Ra.points({ x = 0, y = 0 }, 2, 3), Ra.points({ x = 0, y = 0 }, 2, 3)
check(q1[1].x == q2[1].x and q1[2].y == q2[2].y, "§4 déterminisme des points")
check(Ra.point_de(1, 3) == 1 and Ra.point_de(2, 3) == 2 and Ra.point_de(4, 3) == 1, "§4 assaillants à tour de rôle sur les points")

---------------------------------------------------------------------------------------------------
-- §5 phases
---------------------------------------------------------------------------------------------------
local function run(obs_list)
  local st = { phase = "annonce", t0 = 0, t_phase = 0 }
  local trace = { "annonce" }
  local issue
  for _, o in ipairs(obs_list) do
    local nxt, iss = Ra.suivante(st, o)
    if nxt ~= st.phase then
      st.phase, st.t_phase, st.issue = nxt, o.tick, iss
      trace[#trace + 1] = nxt
      issue = iss
    end
  end
  return table.concat(trace, ">"), issue
end
local tr, iss = run({
  { tick = Ra.ANNONCE - 1 }, { tick = Ra.ANNONCE },
  { tick = Ra.ANNONCE + 60, tout_apparu = false, vivants = 3, kaijus_vivants = 1 },
  { tick = Ra.ANNONCE + 120, tout_apparu = true, vivants = 12, kaijus_vivants = 1 },
  { tick = Ra.ANNONCE + 600, vivants = 12, kaijus_vivants = 1, arrives = false },
  { tick = Ra.ANNONCE + 900, vivants = 10, kaijus_vivants = 1, arrives = true },
  { tick = Ra.ANNONCE + 1200, vivants = 9, kaijus_vivants = 1, arrives = true, defenses = 3 },
  { tick = Ra.ANNONCE + 1500, vivants = 9, kaijus_vivants = 1, arrives = true, defenses = 0 },
})
check(tr == "annonce>rassemblement>marche>assaut>fin" and iss == "tombee", "§5 déroulé complet : base tombée (" .. tr .. ")")
tr, iss = run({ { tick = Ra.ANNONCE }, { tick = Ra.ANNONCE + 60, tout_apparu = true, vivants = 5, kaijus_vivants = 1 },
  { tick = Ra.ANNONCE + 120, vivants = 0, kaijus_vivants = 0 } })
check(tr == "annonce>rassemblement>marche>fin" and iss == "repoussee", "§5 plus un vivant : repoussée (" .. tr .. ")")
tr, iss = run({ { tick = Ra.ANNONCE }, { tick = Ra.ANNONCE + 60, tout_apparu = true, vivants = 5, kaijus_vivants = 1 },
  { tick = Ra.ANNONCE + 120, vivants = 4, kaijus_vivants = 0 },
  { tick = Ra.ANNONCE + 180, vivants = 4, kaijus_vivants = 0 },
  { tick = Ra.ANNONCE + 120 + Ra.REPLI, vivants = 2, kaijus_vivants = 0 } })
check(tr == "annonce>rassemblement>marche>repli>fin" and iss == "repli", "§5 Kaiju mort : repli puis rappel au bout de Ra.REPLI (" .. tr .. ")")
tr, iss = run({ { tick = Ra.ANNONCE }, { tick = Ra.ANNONCE + 60, tout_apparu = true, vivants = 5, kaijus_vivants = 1 },
  { tick = Ra.ANNONCE + 120, vivants = 4, kaijus_vivants = 0 }, { tick = Ra.ANNONCE + 180, vivants = 0, kaijus_vivants = 0 } })
check(tr == "annonce>rassemblement>marche>repli>fin" and iss == "repli", "§5 repli puis plus un vivant : fin (repli)")
tr, iss = run({ { tick = Ra.ANNONCE }, { tick = Ra.ANNONCE + 60, tout_apparu = false, vivants = 5, kaijus_vivants = 1 },
  { tick = Ra.ANNONCE + Ra.RASSEMBLEMENT, tout_apparu = false, vivants = 5, kaijus_vivants = 1 } })
check(tr == "annonce>rassemblement>marche", "§5 rassemblement trop long : la marche part quand même")
tr, iss = run({ { tick = Ra.ANNONCE }, { tick = Ra.ANNONCE + 60, tout_apparu = true, vivants = 5, kaijus_vivants = 1 },
  { tick = Ra.TIMEOUT + 1, vivants = 5, kaijus_vivants = 1, arrives = false } })
check(tr == "annonce>rassemblement>marche>fin" and iss == "bloque", "§5 au-delà de Ra.TIMEOUT : bloqué")
tr, iss = run({ { tick = Ra.ANNONCE }, { tick = Ra.ANNONCE + 60, tout_apparu = true, vivants = 0, kaijus_vivants = 0 } })
check(tr == "annonce>rassemblement>fin" and iss == "repoussee", "§5 tout apparu et déjà tous morts : repoussée")
local ph, is2 = Ra.suivante({ phase = "fin", issue = "tombee" }, { tick = 5 })
check(ph == "fin" and is2 == "tombee", "§5 fin : stable")
check(Ra.ligne("player", 3, "marche", nil, "12 vivant(s)") == "[FO-ASSAUT] assaut 3 sur player : marche ; 12 vivant(s)", "§5 ligne de journal")
check(Ra.ligne(2, 1, "fin", "tombee") == "[FO-ASSAUT] assaut 1 sur 2 : fin (tombee)", "§5 ligne de journal avec issue")

---------------------------------------------------------------------------------------------------
-- §6 forme
---------------------------------------------------------------------------------------------------
check(not SRC:find("[^i]pairs%("), "§6 règle : aucun pairs")
check(not SRC:find("math%.random") and not SRC:find("math%.sin") and not SRC:find("math%.cos") and not SRC:find("math%.atan"), "§6 règle : ni hasard ni trigonométrie")
check(not SRC:find("%f[%w_]global%f[^%w_]") and not SCR:find("%f[%w_]global%f[^%w_]"), "§6 global jamais nommé")
check(not SRC:find("os%.clock") and not SRC:find("os%.time") and not SCR:find("os%.clock") and not SCR:find("os%.time"), "§6 rien de mesuré en temps")
do -- aucun nom de prototype entre guillemets dans la règle ni le script (les noms viennent de T.kaiju_name / E.unit_name)
  local bad = {}
  for s in (SRC .. SCR):gmatch('"([^"\n]*)"') do
    if (s:match("^fo%-") and not s:find(".", 1, true)) or s:match("%-biter$") or s:match("%-spitter$") or s:match("^small%-") or s:match("^big%-") or s:match("^behemoth%-") then
      bad[#bad + 1] = s
    end
  end
  check(#bad == 0, "§6 aucun nom de prototype en dur (" .. table.concat(bad, " ") .. ")")
end
check(not SCR:find("math%.sin") and not SCR:find("math%.cos") and not SCR:find("math%.atan"), "§6 script : aucune trigonométrie")
check(not SCR:find("\n%s+require%("), "§6 script : aucun require dans une fonction")
for _, fn in ipairs({ "Ra.pret(", "Ra.cible(", "Ra.composition(", "Ra.suivante(", "Ra.points(", "Ra.point_de(", "Ra.n_points(", "Ra.age_partie(", "Ra.ligne(" }) do
  check(SCR:find(fn, 1, true) ~= nil, "§6 le script lit " .. fn .. ")")
end
check(SCR:find("evolution_factor", 1, true) ~= nil and SCR:find("Armee.age(", 1, true) ~= nil, "§6 le script lit l'évolution et l'âge des forces")
check(SCR:find("State.alive()", 1, true) ~= nil and SCR:find('State.faction("player")', 1, true) ~= nil, "§6 bases : factions vivantes (triées) et équipe du joueur")
check(SCR:find("Tc.TURRET_TYPES", 1, true) ~= nil, "§6 défenses relevées par les TYPES de tourelles de la configuration")
check(read("script/td/director.lua"):find('require("script.combat.assaut_titan")', 1, true) ~= nil, "§6 requis par le directeur (abonnements statiques)")
check(read("script/remote.lua"):find("assaut = function(action, opts)", 1, true) ~= nil, "§6 interface distante « assaut »")
check(read("control.lua"):find("assaut", 1, true) == nil, "§6 control.lua non touché")

---------------------------------------------------------------------------------------------------
-- §7 traductions
---------------------------------------------------------------------------------------------------
local function cfg(p)
  local t, sec = {}, ""
  for line in read(p):gmatch("[^\r\n]+") do
    local s = line:match("^%[([%w%-_]+)%]$")
    if s then sec = s else
      local k, v = line:match("^([%w%-_]+)=(.*)$")
      if k then t[sec .. "." .. k] = v end
    end
  end
  return t
end
local FR, EN = cfg("locale/fr/assaut.cfg"), cfg("locale/en/assaut.cfg")
local keys = { "fo-assaut.annonce", "fo-assaut.marche", "fo-assaut.kaiju-mort" }
for _, i in ipairs(Ra.ISSUES) do keys[#keys + 1] = "fo-assaut." .. i end
for _, k in ipairs(keys) do check(FR[k] ~= nil and EN[k] ~= nil and FR[k] ~= "" and EN[k] ~= "", "§7 clé en FR et EN : " .. k) end
local same = true
for k in pairs(FR) do if not EN[k] then same = false end end
for k in pairs(EN) do if not FR[k] then same = false end end
check(same, "§7 FR et EN : mêmes clés")
for _, k in ipairs(keys) do
  check(SCR:find('"' .. k .. '"', 1, true) ~= nil or SCR:find('"fo-assaut." .. issue', 1, true) ~= nil, "§7 clé utilisée par le script : " .. k)
end

---------------------------------------------------------------------------------------------------
-- §8 mutants : la règle mutée est rechargée depuis une source modifiée ; chaque mutant doit faire échouer un contrôle ci-dessus
---------------------------------------------------------------------------------------------------
local function load_mut(src)
  local f = assert(load(src, "=mutant"))
  package.loaded["shared.combat.assaut_titan"] = nil
  local saved = package.searchers
  local r = f()
  package.loaded["shared.combat.assaut_titan"] = nil
  Ra = require("shared.combat.assaut_titan")
  return r
end
local function mutant(nom, from, to, verdict)
  local src, n = SRC:gsub(from, to, 1)
  if n == 0 then check(false, "§8 mutant « " .. nom .. " » : motif introuvable") return end
  local M = load_mut(src)
  local refused = not verdict(M)
  check(refused, "§8 mutant « " .. nom .. " » refusé")
end
mutant("déclenchement sans condition d'âge ni d'évolution", "if age < T%.AGE_MIN and evo < Ra%.EVO_MIN then return false, \"trop tot\", nil end", "",
  function(M) return M.pret({ tick = 10 ^ 7, bases = 1, age = 1, evolution = 0 }) == false end)
mutant("cadence ignorée", "if since < p then return false, \"cadence\", p end", "",
  function(M) return M.pret({ tick = 1, bases = 1, age = T.AGE_MIN, evolution = 0 }) == false end)
mutant("aucune base acceptée", "if %(num%(c%.bases%) or 0%) <= 0 then return false, \"aucune base\", nil end", "",
  function(M) return M.pret({ tick = 10 ^ 7, bases = 0, age = 15, evolution = 1 }) == false end)
mutant("période constante (évolution ignorée)", "local p = Ra%.PERIODE %* %(1 %- 0%.5 %* evo%) %* %(1 %- 0%.5 %* part_age%)", "local p = Ra.PERIODE * (1 - 0.5 * part_age)",
  function(M) return M.periode(1, 1) < M.periode(0, 1) end)
mutant("cible : la moins défendue", "%(b%.defenses or 0%) > %(best%.defenses or 0%)", "(b.defenses or 0) < (best.defenses or 0)",
  function(M) return M.cible(bases, {}).id == 2 end)
mutant("cible : rotation ignorée", "if k > 0 then\n    for i = #recent, math%.max%(1, #recent %- k %+ 1%), %-1 do exclus%[tostring%(recent%[i%]%)%] = true end\n  end", "",
  function(M) return M.cible(bases, { 2 }).id == "player" end)
mutant("cible : égalité non déterministe (ordre d'entrée)", "or %(%(b%.defenses or 0%) == %(best%.defenses or 0%) and tostring%(b%.id%) < tostring%(best%.id%)%)", "",
  function(M) return M.cible(bases, {}).id == M.cible({ bases[3], bases[1], bases[2] }, {}).id end)
mutant("composition : escorte fixe (défenses ignorées)", "local n = math%.ceil%(%(num%(defenses%) or 0%) %* Ra%.ESCORTE%.par_tourelle%)", "local n = Ra.ESCORTE.min",
  function(M) local a, b = M.escorte(20); return a + b == 30 end)
mutant("composition : Kaiju d'une ère fixe", "local out = { { T%.kaiju_name%(era, T%.kaiju_pour%(era, n%)%), Ra%.kaijus%(era%) } }", "local out = { { T.kaiju_name(1, T.kaiju_pour(era, n)), Ra.kaijus(era) } }",
  function(M) return M.composition(L.EPOCHS, 1)[1][1] == T.kaiju_name(T.era(L.EPOCHS)) end)
mutant("composition : rotation des archétypes ignorée", "T%.kaiju_pour%(era, n%)", "T.kaiju_pour(era, 1)",
  function(M) return M.composition(10, 20, 2)[1][1] == T.kaiju_name(T.era(10), T.kaiju_pour(T.era(10), 2)) end)
mutant("composition : Écorchés sans condition d'ère", "if era >= T%.ECORCHE%.era_min and m > 0 then", "if m > 0 then",
  function(M) return #M.composition(1, 20) == 3 end)
mutant("phases : repli ignoré (Kaiju mort)", "if kaijus == 0 then return \"repli\", nil end", "",
  function(M) local st = { phase = "marche", t0 = 0, t_phase = 0 }; return M.suivante(st, { tick = 10, vivants = 4, kaijus_vivants = 0 }) == "repli" end)
mutant("phases : base jamais tombée", "if %(num%(obs%.defenses%) or 0%) == 0 then return \"fin\", \"tombee\" end", "",
  function(M) local st = { phase = "assaut", t0 = 0, t_phase = 0 }; local a, b = M.suivante(st, { tick = 10, vivants = 4, kaijus_vivants = 1, defenses = 0 }); return a == "fin" and b == "tombee" end)
mutant("phases : timeout ignoré", "if tick %- %(num%(st%.t0%) or tick%) > Ra%.TIMEOUT then return \"fin\", \"bloque\" end", "",
  function(M) local st = { phase = "marche", t0 = 0, t_phase = 0 }; local a, b = M.suivante(st, { tick = Ra.TIMEOUT + 1, vivants = 4, kaijus_vivants = 1 }); return a == "fin" and b == "bloque" end)
mutant("points : tous au même cran", "local i = %(%(num%(cran%) or 0%) %+ math%.floor%(12 %* %(k %- 1%) / n%)%) %% 12 %+ 1", "local i = ((num(cran) or 0)) %% 12 + 1",
  function(M) local p = M.points({ x = 0, y = 0 }, 3, 0); return p[1].x ~= p[2].x or p[1].y ~= p[2].y end)

print(string.format("[ASSAUT] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
