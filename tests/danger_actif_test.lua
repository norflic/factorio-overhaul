--[[
  Lot DANGER-ACTIF : banc HORS JEU de la règle pure shared/team/danger_actif.lua (demande du DC, 4/11, 19 h 10 : « déssactive le comportement
  "trop dangereux", l'idée est qu'ils continuent de travailler en évitant le danger » ; 19 h 12 : « ... ou en défandant »).
    1. mise de côté (menace fixe ou morts au but) contre départ (route, morts de la route, cases mobiles, escorte absente) ;
    2. pause bornée d'une tâche mise de côté (shared/team/actif.lua, A.retry) ;
    3. suivi du repos pour cause de danger (critère C1 : plus de 30 s) ;
    4. la chaîne dans les sources de la porte (plus d'étiquette « attente », plus d'étape d'attente d'escorte) ;
    5. mutants : chacun doit faire échouer au moins un cas des sections 1 à 3.
  Lancement : lua5.2 tests/danger_actif_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local cur_fail, quiet
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; cur_fail = true; if not quiet then print("  ECHEC : " .. msg) end end
end
local function section(name) print("== " .. name) end

local function read(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end

--- Les cas des sections 1 à 3, rejoués sur un module `Da` (le vrai ou un mutant).
local function cases(Da, A)
  local B = 650
  -- 1. mise de côté ou départ
  check(Da.after_wait({ fixed = B, deaths = 0, mobile = 0 }, B, "but", 0) == "aside", "menace fixe au but (= seuil) : mise de côté")
  check(Da.after_wait({ fixed = B + 500, deaths = 0, mobile = 0 }, B, "bloque", 0) == "aside", "menace fixe forte au but : mise de côté")
  check(Da.after_wait({ fixed = B - 1, deaths = 0, mobile = 0 }, B, "but", 0) == "go", "menace fixe juste sous le seuil : départ")
  check(Da.after_wait({ fixed = 0, deaths = 0, mobile = 5000 }, B, "marque", 0) == "go", "attaque en cours (cases mobiles) au but : départ par le moindre danger")
  check(Da.after_wait({ fixed = 0, deaths = 5000, mobile = 0 }, B, "morts", 2) == "go", "2 morts, danger de morts seul : départ (morts de PNJ sur la route)")
  check(Da.after_wait({ fixed = 0, deaths = 0, mobile = 0 }, B, "morts", Da.DEATHS_GOAL) == "aside", "Da.DEATHS_GOAL morts au but : mise de côté (pas de marche suicide)")
  check(Da.after_wait({ fixed = 0, deaths = 0, mobile = 0 }, B, "morts", Da.DEATHS_GOAL - 1) == "go", "une mort de moins au but : départ")
  check(Da.after_wait({ fixed = 0, deaths = 0, mobile = 0 }, B, "boucle", 0) == "aside", "but où l'on a tourné en rond : mise de côté")
  check(Da.after_wait(nil, B, "marque", nil) == "go", "sans mesure du but : départ")
  check(Da.DEATHS_GOAL == 3, "garde-fou des morts au but : 3 (même valeur que la famine)")
  -- 2. pause bornée
  check(A.retry(Da.ASIDE_FAIL, false, 1800) == Da.ASIDE_TICKS and Da.ASIDE_TICKS == 3600, "tâche mise de côté : pause de 3600 ticks (1 min)")
  check(A.retry("danger", false, 1800) == A.RETRY_DANGER, "refus ordinaire pour danger : pause de 10 s (inchangée)")
  check(A.retry("chemin", false, 1800) == 1800, "autre échec : pause d'avant")
  -- 3. repos
  local st, a = {}, {}
  Da.rest_open(a, 100)
  Da.rest_open(a, 400)
  check(a.rest_since == 100, "le repos s'ouvre au premier refus et ne se rouvre pas")
  check(Da.rest_close(a, st, 100 + Da.REST_MAX) == Da.REST_MAX and (st.rest_over or 0) == 0 and st.rest_n == 1, "repos de 30 s pile : fermé, pas compté « au-delà de 30 s »")
  check(a.rest_since == nil and Da.rest_close(a, st, 5000) == 0, "fermé : plus de repos ; fermer deux fois ne compte rien")
  Da.rest_open(a, 1000)
  Da.rest_close(a, st, 1000 + Da.REST_MAX + 1)
  check(st.rest_over == 1 and st.rest_max == Da.REST_MAX + 1 and st.rest_n == 2, "repos de plus de 30 s : compté, plus long retenu")
  -- 4. défendre : alerte de soldats en cours et fréquence de l'alerte
  local al = { { x = 100, y = 100, ["until"] = 5000 }, { x = -300, y = 0, ["until"] = 9000 } }
  check(Da.site_alert(al, { x = 120, y = 100 }, 1000) == true, "PNJ à 20 tuiles d'une alerte en cours : sur le site attaqué")
  check(Da.site_alert(al, { x = 140, y = 100 }, 1000) == false, "PNJ à 40 tuiles de l'alerte : pas sur le site")
  check(Da.site_alert(al, { x = 120, y = 100 }, 5000) == false, "alerte expirée : plus de site attaqué")
  check(Da.site_alert(nil, { x = 0, y = 0 }, 0) == false, "aucune alerte : faux")
  check(Da.alert_due(nil, 10) == true and Da.alert_due(100, 100 + Da.ALERT_GAP - 1) == false and Da.alert_due(100, 100 + Da.ALERT_GAP) == true,
    "alerte des soldats : la première tout de suite, puis au plus une par " .. Da.ALERT_GAP .. " ticks")
  local ags = { [1] = { rest_since = 100 }, [2] = {}, [3] = { rest_since = 9000 } }
  local n, worst = Da.rest_open_over(ags, { 1, 2, 3 }, 9100)
  check(n == 1 and worst == 9000, "repos encore ouverts au-delà de 30 s : 1 sur 3 (" .. n .. ", " .. worst .. ")")
end

section("1 à 3. Règle pure")
local Da = require("shared.team.danger_actif")
local A = require("shared.team.actif")
cases(Da, A)

section("4. Chaîne dans les sources de la porte")
local CO = read("script/ai3/comportement.lua")
check(CO:find('label(agent, "attente"', 1, true) == nil, "plus aucune étiquette « attente » (« Trop dangereux »)")
check(CO:find('{ "wait", M.ESCORT_WAIT }', 1, true) == nil, "plus d'étape d'attente d'escorte au QG")
check(CO:find('label(agent, "contourne"', 1, true) ~= nil, "étiquette « contourne le danger » posée")
check(CO:find("return set_aside(", 1, true) ~= nil and CO:find("task.fail = Da.ASIDE_FAIL", 1, true) ~= nil, "mise de côté : task.fail = Da.ASIDE_FAIL")
check(CO:find("th.b = tick", 1, true) ~= nil, "la menace du but est signalée aux soldats (th.b)")
for _, lang in ipairs({ "fr", "en" }) do
  check(read("locale/" .. lang .. "/danger_actif.cfg"):find("etat-contourne=", 1, true) ~= nil, "locale " .. lang .. " : etat-contourne")
  check(read("locale/" .. lang .. "/ia3k.cfg"):find("etat-attente", 1, true) == nil, "locale " .. lang .. " : etat-attente supprimé")
end

section("4 bis. Défendre : chaîne dans les sources")
local RPS = read("script/team/reparation.lua")
check(RPS:find("Rep.on_attack and hitter and hitter ~= ent.force and Da.alert_due(f.attack_alert_t, e.tick)", 1, true) ~= nil,
  "un bâtiment de l'équipe touché par une force adverse appelle le crochet d'alerte (au plus un par Da.ALERT_GAP)")
local SDS = read("script/ai3/soldats.lua")
check(SDS:find("Rep.on_attack = function(f, pos, tick)", 1, true) ~= nil and SDS:find('C.on_alert(f, pos, "unit", tick)', 1, true) ~= nil,
  "le crochet alerte les soldats par C.on_alert (existant)")
check(CO:find("site_alert = Da.site_alert(t.alerts, p, tick)", 1, true) ~= nil, "le regard passe l'alerte de site à Re.decide")

section("5. Mutants (chacun doit faire échouer au moins un cas)")
local src = read("shared/team/danger_actif.lua")
local mutants = {
  { "seuil > au lieu de >=", ">= B or (deaths_n or 0)", "> B or (deaths_n or 0)" },
  { "morts au but ignorées", " or (deaths_n or 0) >= Da.DEATHS_GOAL", "" },
  { "garde-fou des morts à 4", "Da.DEATHS_GOAL = 3", "Da.DEATHS_GOAL = 4" },
  { "boucle plus mise de côté", 'why == "boucle" or ', "" },
  { "tout part", 'return "aside" end\n  return "go"', 'return "go" end\n  return "go"' },
  { "tout est mis de côté", 'return "aside" end\n  return "go"', 'return "aside" end\n  return "aside"' },
  { "cases mobiles comptées", "return ((parts and parts.fixed) or 0) >= B", "return ((parts and parts.fixed) or 0) + ((parts and parts.mobile) or 0) >= B" },
  { "pause de 2 min", "Da.ASIDE_TICKS = 3600", "Da.ASIDE_TICKS = 7200" },
  { "site sans limite de distance", "dx * dx + dy * dy <= Da.SITE_R * Da.SITE_R", "true" },
  { "alerte expirée comptée", 'if tick < (a["until"] or 0) then', "if true then" },
  { "alerte à chaque coup", "return last == nil or tick - last >= Da.ALERT_GAP", "return true" },
  { "repos rouvert à chaque refus", "if not a.rest_since then a.rest_since = tick end", "a.rest_since = tick" },
  { "30 s compté trop tôt", "if d > Da.REST_MAX then st.rest_over", "if d >= Da.REST_MAX then st.rest_over" },
  { "plus long non retenu", "if d > (st.rest_max or 0) then st.rest_max = d end", "" },
}
local refused = 0
for _, mu in ipairs(mutants) do
  local a, b = src:find(mu[2], 1, true)
  if not a then
    failures = failures + 1
    print("  ECHEC : mutant « " .. mu[1] .. " » : motif introuvable dans la source")
  else
    local code = src:sub(1, a - 1) .. mu[3] .. src:sub(b + 1)
    local chunk = assert(load(code, "mutant", "t"))
    local M = chunk()
    local p0, f0 = passes, failures
    cur_fail = false
    -- l'actif.lua du vrai module lit le vrai Da : on rejoue la pause avec le mutant par une copie minimale de A.retry
    local A2 = { RETRY_DANGER = A.RETRY_DANGER, retry = function(fail, fond, base)
      if fail == M.ASIDE_FAIL then return M.ASIDE_TICKS end
      return A.retry(fail, fond, base)
    end }
    quiet = true
    local ok = pcall(cases, M, A2)
    quiet = false
    local failed = (not ok) or cur_fail
    passes, failures = p0, f0 -- les cas du mutant ne comptent pas dans le bilan
    check(failed, "mutant « " .. mu[1] .. " » refusé")
    if failed then refused = refused + 1 end
  end
end
print(string.format("  mutants refusés : %d sur %d", refused, #mutants))

print(string.format("[DANGER-ACTIF] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
