--[[
  Lot JOURNAUX-DC (30/10) : règles pures des journaux et messages (shared/team/journaux_dc.lua) et repli de la recherche
  quand aucune technologie de valeur n'est payable (shared/ai3/general.lua, Gen.fallback), sur les données RÉELLES des
  fixtures (tests/iag_fixture.lua). Lancer depuis la racine du mod : lua5.2 tests/journaux_dc_test.lua
  Chiffres de la partie du DC du 29/10 (fo-logs/2026-10-30_AMELIO/CINQ-POINTS.md) repris dans les cas.
]]

package.path = "./?.lua;" .. package.path

local J = require("shared.team.journaux_dc")
local F = require("tests.iag_fixture")
local K = require("shared.ai3.catalogue")
local Gen = require("shared.ai3.general")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    print("[JOURNAUX-DC] ECHEC : " .. msg)
  end
end

---------------------------------------------------------------------------------------------------
-- §1 Cause de la chute d'un QG et message de fin de guerre
---------------------------------------------------------------------------------------------------
local factions = { ["fo-scarlet"] = "scarlet", ["fo-azure"] = "azure", ["fo-emerald"] = "emerald", ["fo-amber"] = "amber" }
local function key_of(force) return factions[force] end

local g, k = J.cause("enemy", "fo-emerald", key_of)
check(g == "biters" and k == nil, "§1 QG detruit par la force enemy : biters")
g, k = J.cause("fo-azure", "fo-amber", key_of)
check(g == "rival" and k == "azure", "§1 QG detruit par une faction : rival et sa cle")
check(J.cause("player", "fo-amber", key_of) == "joueur", "§1 QG detruit par le joueur")
check(J.cause("fo-amber", "fo-amber", key_of) == "elle-meme", "§1 QG detruit par sa propre force")
check(J.cause(nil, "fo-amber", key_of) == "inconnue", "§1 sans tueur (destruction par script) : inconnue")
g, k = J.cause("neutral", "fo-amber", key_of)
check(g == "autre" and k == "neutral", "§1 autre force : autre et son nom")

-- Partie du DC du 29/10 : emerald tombée « par enemy », Écarlate seule survivante -> PAS de victoire.
check(J.fin_de_guerre(1, "biters", nil, "scarlet") == "seule", "§1 partie du DC : dernier rival tue par les biters -> message neutre")
-- Session de 15 h : QG tombés « par fo-azure », Azur seule survivante -> victoire.
check(J.fin_de_guerre(1, "rival", "azure", "azure") == "victoire", "§1 dernier rival tue par la survivante -> victoire")
check(J.fin_de_guerre(1, "rival", "amber", "azure") == "seule",
  "§1 dernier rival tue par une faction deja eliminee (ses soldats) -> message neutre")
check(J.fin_de_guerre(1, "joueur", nil, "azure") == "seule", "§1 dernier rival tue par le joueur -> message neutre")
check(J.fin_de_guerre(2, "rival", "azure", nil) == nil, "§1 deux factions vivantes : la guerre continue")
check(J.fin_de_guerre(0, "rival", "azure", nil) == nil, "§1 aucune faction vivante : aucun message de fin")

---------------------------------------------------------------------------------------------------
-- §2 Plafond d'ouvriers et fer inemployé
---------------------------------------------------------------------------------------------------
local MIN = 3600
local st = {}
-- Écarlate : 8/8 de la minute 0, coût en fer d'une recrue 18 (10 + effectif 8), fer libre qui monte.
check(J.plafond_observe(st, 0, 8, 8, 500, 18) == nil, "§2 minute 0 : au plafond, pas encore 30 min")
check(st.depuis == 0, "§2 debut de l'episode note")
check(J.plafond_observe(st, 29 * MIN, 8, 8, 9000, 18) == nil, "§2 29 min : pas d'alerte")
local a = J.plafond_observe(st, 30 * MIN, 8, 8, 14471, 18)
check(a ~= nil and a.minutes == 30 and a.fer == 14471 and a.cap == 8 and a.recrues == 803, "§2 30 min : alerte (fer, plafond, recrues)")
check(J.plafond_observe(st, 120 * MIN, 8, 8, 24494, 18) == nil, "§2 alerte ecrite UNE fois par episode")
local live = J.plafond_alerte(st, 311 * MIN)
check(live and live.minutes == 311 and live.fer == 24494, "§2 l'onglet lit l'alerte en cours (depuis la minute 0)")
-- Fer insuffisant : pas d'alerte (moins de 10 fois le coût).
local st2 = {}
J.plafond_observe(st2, 0, 8, 8, 100, 18)
check(J.plafond_observe(st2, 40 * MIN, 8, 8, 179, 18) == nil, "§2 fer libre < 10 x cout : pas d'alerte")
check(J.plafond_alerte(st2, 40 * MIN) == nil, "§2 onglet : pas d'alerte sous 10 x cout")
check(J.plafond_observe(st2, 41 * MIN, 8, 8, 180, 18) ~= nil, "§2 fer libre = 10 x cout : alerte")
-- Sous le plafond (une perte) : l'épisode se termine, un nouveau recommence de zéro.
check(J.plafond_observe(st2, 42 * MIN, 8, 7, 5000, 18) == nil and st2.depuis == nil and st2.signale == nil,
  "§2 sous le plafond : episode termine")
check(J.plafond_alerte(st2, 42 * MIN) == nil, "§2 sous le plafond : aucune alerte a l'onglet")
J.plafond_observe(st2, 43 * MIN, 8, 8, 5000, 18)
check(J.plafond_observe(st2, 72 * MIN, 8, 8, 5000, 18) == nil, "§2 nouvel episode : 29 min, pas d'alerte")
check(J.plafond_observe(st2, 73 * MIN, 8, 8, 5000, 18) ~= nil, "§2 nouvel episode : alerte a 30 min")
check(J.plafond_observe({}, 0, 0, 0, 1e6, 18) == nil, "§2 plafond nul : rien")
local st3 = {}
J.plafond_observe(st3, 0, 8, 8, 1e6, 0)
check(J.plafond_alerte(st3, 60 * MIN) == nil, "§2 cout nul (recrue sans fer) : pas d'alerte")

---------------------------------------------------------------------------------------------------
-- §3 Résumés de journal
---------------------------------------------------------------------------------------------------
local total, txt = J.resume_objets({ ["iron-plate"] = 4800, coal = 900, ["copper-plate"] = 900, stone = 0, wood = 3 }, 2)
check(total == 6603, "§3 total des objets (zeros exclus)")
check(txt == "iron-plate 4800, coal 900, ...", "§3 plus nombreux d'abord, egalite par nom, coupe : " .. txt)
check(J.resume_objets({}, 3) == 0, "§3 contenu vide")
local l = J.ligne_reglages({ ["fo-war-workers"] = 8, ["fo-war-autostart"] = true, ["fo-pvp-difficulty"] = "peaceful",
  ["fo-war-ia3e"] = false, ["fo-x"] = 0.5 })
check(l == "fo-pvp-difficulty=peaceful fo-war-autostart=true fo-war-ia3e=false fo-war-workers=8 fo-x=0.5",
  "§3 reglages tries, entiers sans decimale : " .. l)

---------------------------------------------------------------------------------------------------
-- §3 bis Mur de recherche : annonce après 5 min de blocage continu, une fois par situation
---------------------------------------------------------------------------------------------------
local m, act = J.mur_bloque(nil, 0, "a|10")
check(m and m.since == 0 and act == nil, "§3b debut du blocage : rien d'annonce")
m, act = J.mur_bloque(m, 5 * MIN - 1, "a|10")
check(act == nil, "§3b blocage passager (< 5 min) : pas de mur (votre equipe a la minute 0, fer pas encore connu)")
check(J.mur_libre(m) == nil, "§3b sortie avant l'annonce : pas de ligne de fin")
m, act = J.mur_bloque(m, 5 * MIN, "a|10")
check(act == "annonce", "§3b 5 min de blocage continu : mur annonce")
m, act = J.mur_bloque(m, 20 * MIN, "a|10")
check(act == nil, "§3b meme situation : une seule annonce")
m, act = J.mur_bloque(m, 21 * MIN, "b|9")
check(act == "change" and m.since == 0, "§3b situation changee : nouvelle ligne, debut garde")
check(J.mur_libre(m) == "fin", "§3b sortie apres l'annonce : ligne de fin")
-- Partie du DC : Écarlate bloquée de la minute 289 (287,8) à 312 -> annonce vers 292,8 min.
local mdc = J.mur_bloque(nil, math.floor(287.8 * MIN), "x|7")
local _, adc = J.mur_bloque(mdc, math.floor(292.9 * MIN), "x|7")
check(adc == "annonce", "§3b partie du DC : mur annonce 5 min apres le dernier choix payable")

---------------------------------------------------------------------------------------------------
-- §4 Recherche : jamais bloquée tant qu'une technologie prête est payable (données réelles)
---------------------------------------------------------------------------------------------------
local function run(cat, fallback_on)
  local saved = Gen.fallback
  if not fallback_on then Gen.fallback = function() return nil end end
  local stt = F.start_state()
  for _, it in ipairs({ "iron-plate", "copper-plate", "coal", "stone" }) do stt.stock[it] = 50000 end
  local seq, stuck_with_payable, repli = {}, false, 0
  for _ = 1, 400 do
    local ev = Gen.prepare(cat, stt)
    local d = Gen.choose(cat, ev, stt, {})
    if not d.tech then
      for _, t in ipairs(Gen.ready(cat, stt, {})) do if ev.tfeas[t] then stuck_with_payable = true end end
      break
    end
    if d.repli then repli = repli + 1 end
    seq[#seq + 1] = d.tech
    stt.techs[d.tech] = true
  end
  Gen.fallback = saved
  return seq, stuck_with_payable, repli
end

local cat = K.build(F.dump(), F.opts())
local seq, stuck, repli = run(cat, true)
check(not stuck, "§4 avec le repli : jamais bloquee tant qu'une technologie prete est payable")
check(repli > 0, "§4 le repli a servi (" .. repli .. " fois)")
local seq0, stuck0 = run(cat, false)
check(stuck0, "§4 MUTANT sans repli : bloquee avec une technologie payable (le defaut existait)")
check(#seq > #seq0, string.format("§4 plus de recherches avec le repli : %d contre %d", #seq, #seq0))
-- Le repli ne change rien AVANT le premier blocage : mêmes premières décisions.
local same = true
for i = 1, #seq0 do if seq[i] ~= seq0[i] then same = false end end
check(same, "§4 decisions identiques jusqu'au premier blocage (le repli ne joue que sans candidate de valeur)")
-- Le premier repli choisit la technologie qui ouvre le plus de technologies (ici le prérequis d'une branche).
local first = seq[#seq0 + 1]
local opens = 0
for _, u in ipairs(cat.tech_list) do
  for _, p in ipairs(cat.techs[u].prerequisites) do if p == first then opens = opens + 1 end end
end
check(opens > 0, "§4 premier repli : un prerequis d'autres technologies (" .. tostring(first) .. ", ouvre " .. opens .. ")")
-- Déterminisme : données dans l'ordre inverse, même suite.
local seqr = run(K.build(F.dump({ reverse = true }), F.opts()), true)
check(table.concat(seq, ",") == table.concat(seqr, ","), "§4 determinisme : meme suite de recherches sur les donnees inversees")
-- Une candidate de valeur passe toujours devant le repli : état de départ.
local s0 = F.start_state()
local d0 = Gen.choose(cat, Gen.prepare(cat, s0), s0, {})
check(d0.tech ~= nil and not d0.repli, "§4 etat de depart : technologie de valeur, pas de repli")
-- Texte du journal du repli.
check(Gen.why_text({ tech = "x", repli = true, opens = 3, why = {} }):find("repli", 1, true) ~= nil, "§4 texte du repli au journal")

print(string.format("[JOURNAUX-DC] recherches : %d avec le repli, %d sans (premier repli : %s)", #seq, #seq0, tostring(first)))
print(string.format("[JOURNAUX-DC] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
