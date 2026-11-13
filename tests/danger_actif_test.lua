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
  check(Da.after_wait({ fixed = 0, deaths = 5000, mobile = 0 }, B, "morts", 1) == "go", "1 mort au but, danger de morts seul : départ")
  check(Da.after_wait({ fixed = 0, deaths = 0, mobile = 0 }, B, "morts", Da.DEATHS_GOAL) == "aside", "Da.DEATHS_GOAL morts au but : mise de côté (pas de marche suicide)")
  check(Da.after_wait({ fixed = 0, deaths = 0, mobile = 0 }, B, "morts", Da.DEATHS_GOAL - 1) == "go", "une mort de moins au but : départ")
  -- relecture du lead (5/11) : B1 chemin du moindre danger qui passe forcément à portée d'une menace fixe, B2 2 morts de l'heure sur ce chemin
  check(Da.after_wait({ fixed = 0, deaths = 0, mobile = 0 }, B, "bloque", 0, { fixed = B, deaths = 0 }) == "aside", "B1 : le meilleur chemin atteint le seuil par des menaces FIXES : mise de côté")
  check(Da.after_wait({ fixed = 0, deaths = 0, mobile = 0 }, B, "bloque", 0, { fixed = B - 1, deaths = 0 }) == "go", "B1 : juste sous le seuil : départ")
  check(Da.after_wait({ fixed = 0, deaths = 0, mobile = 0 }, B, "bloque", 0, { fixed = 0, deaths = 0 }) == "go", "B1 : route bloquée par des cases MOBILES seules : départ (attaque qui passe)")
  check(Da.after_wait({ fixed = 0, deaths = 0, mobile = 0 }, B, "morts", 0, { fixed = 0, deaths = Da.DEATHS_ROUTE }) == "aside", "B2 : 2 morts de l'heure sur le chemin : mise de côté")
  check(Da.after_wait({ fixed = 0, deaths = 0, mobile = 0 }, B, "mort", 0, { fixed = 0, deaths = Da.DEATHS_ROUTE - 1 }) == "go", "B2 : 1 mort sur le chemin : départ")
  check(Da.DEATHS_ROUTE == 2, "morts de l'heure sur le chemin : 2")
  check(Da.after_wait({ fixed = 0, deaths = 0, mobile = 0 }, B, "boucle", 0) == "aside", "but où l'on a tourné en rond : mise de côté")
  check(Da.after_wait(nil, B, "marque", nil) == "go", "sans mesure du but : départ")
  check(Da.DEATHS_GOAL == 2, "garde-fou des morts au but : 2 (docs/IA_ATTENDUS.md C5)")
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
  check(Da.mobile_cause("unit") and Da.mobile_cause("character") and not Da.mobile_cause("unit-spawner") and not Da.mobile_cause("turret") and not Da.mobile_cause(nil),
    "alerte des soldats : unités et personnages seulement, jamais un nid, un ver ni une tourelle")
  -- 5. abri : exposition et ralliement
  check(Da.exposed({ x = 60, y = 0 }, { x = 0, y = 0 }, 62) == true and Da.exposed({ x = 63, y = 0 }, { x = 0, y = 0 }, 62) == false, "exposé à moins de la portée + marges de la menace, pas au-delà")
  check(Da.shelter_resp("rally", { x = 40, y = 0 }, { x = 0, y = 0 }) == "rally" and Da.shelter_resp("rally", { x = 41, y = 0 }, { x = 0, y = 0 }) == "stand",
    "ralliement général seulement pour une menace à 40 tuiles du QG au plus")
  check(Da.shelter_resp("away", { x = 90, y = 0 }, { x = 0, y = 0 }) == "away" and Da.shelter_resp("stand", { x = 90, y = 0 }, { x = 0, y = 0 }) == "stand", "éloignement et « stand » inchangés")
  -- 6. Alertes de SITE (relecture du lead, 5/11 17 h 34 et 17 h 41 ; F251, F253) : leur SOMME, proches comprises, ne prend que ce qui dépasse la
  -- réserve du QG ; servies par distance croissante, par groupe entier, sinon rien.
  local Sd = require("shared.ai3.soldats")
  local n1, l1 = Da.site_send(8)
  check(n1 == 4 and l1 == 4, "alerte de site, 8 soldats au-dessus de la réserve : un groupe de 4 part, 4 restent")
  local n4, l4 = Da.site_send(3)
  check(n4 == 0 and l4 == 3, "3 soldats au-dessus de la réserve : aucun envoi (jamais de soldats isolés)")
  check(Da.site_send(nil) == 0 and Da.site_send(0) == 0, "aucun surplus : aucun envoi")
  check(Da.SITE_GROUP == 4, "groupe d'une alerte de site : 4 (C.on_alert)")
  -- Cas du lead : 3 alertes proches (60, 100, 150 tuiles) + 1 lointaine (400), 14 soldats libres : le QG en garde au moins 8.
  local function plan_case(free_n)
    local al = { { d2 = 400 * 400, x = 400, y = 0, tag = "loin" }, { d2 = 150 * 150, x = 0, y = 150, tag = "150" },
      { d2 = 60 * 60, x = 60, y = 0, tag = "60" }, { d2 = 100 * 100, x = 0, y = -100, tag = "100" } }
    local out, rest = Da.site_plan(al, Sd.surplus(free_n))
    local taken, by = 0, {}
    for _, sv in ipairs(out) do taken = taken + sv.n by[sv.item.tag] = sv.n end
    return free_n - taken, by, out, rest, al
  end
  local kept, by, out, _, al = plan_case(14)
  check(kept >= 8 and kept == 10 and by["60"] == 4 and by["100"] == 0 and by["150"] == 0 and by["loin"] == 0,
    string.format("3 alertes proches + 1 lointaine, 14 soldats : un groupe à la plus proche (60 tuiles), le QG en garde %d (>= 8)", kept))
  check(out[1].item.tag == "60" and out[2].item.tag == "100" and out[3].item.tag == "150" and out[4].item.tag == "loin" and al[1].tag == "loin",
    "alertes servies par distance croissante au QG ; la liste d'entrée n'est pas modifiée")
  local kept20, by20 = plan_case(20)
  check(kept20 == 8 and by20["60"] == 4 and by20["100"] == 4 and by20["150"] == 4 and by20["loin"] == 0,
    string.format("20 soldats (réserve 8) : 3 groupes aux 3 alertes proches, rien au loin, le QG en garde %d", kept20))
  local kept40, by40 = plan_case(40)
  check(kept40 == 24 and by40["loin"] == 4 and Sd.reserve(40) == 14, "40 soldats (réserve 35 % = 14) : les 4 alertes servies, le QG en garde 24")
  check(#Da.site_plan({}, 10) == 0 and select(2, Da.site_plan({}, 10)) == 10, "aucune alerte : rien de pris")
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
check(SDS:find("Rep.on_attack = function(f, pos, tick, critical)", 1, true) ~= nil and SDS:find('C.on_alert(f, pos, "unit", tick, "site", critical)', 1, true) ~= nil,
  "le crochet alerte les soldats par C.on_alert (existant)")
check(RPS:find("Da.mobile_cause(cause.type)", 1, true) ~= nil and RPS:find("State.owner(u)", 1, true) ~= nil, "bâtiment touché : cause mobile seulement ; votre équipe : bâtiment enregistré seulement")
check(SDS:find('C.on_alert(f, pos, "unit", tick, "site", critical)', 1, true) ~= nil and SDS:find('mode ~= "site" and d2(ep, f.hq_pos)', 1, true) ~= nil, "alerte « site » : enregistrée à toute distance du QG")
check(SDS:find("local left = hq_en and 0 or Sd.surplus(#list)", 1, true) ~= nil and SDS:find("served, left = Da.site_plan(site, left, res)", 1, true) ~= nil
  and SDS:find("elseif a.site and not a.role then", 1, true) ~= nil and SDS:find("left = (n == nil) and 0 or math.max(0, left - n)", 1, true) ~= nil
  and SDS:find('if mode == "site" then a.site = true end', 1, true) ~= nil and SDS:find('site = (mode == "site") or nil', 1, true) ~= nil,
  "alertes de site, proches comprises : soldats pris au-dessus de la réserve du QG, après le QG menacé, l'armée et les alertes de fuite (relecture du lead 17 h 41)")
check(SDS:find("Da.exposed(p, threat, reach)", 1, true) ~= nil and SDS:find('{ "wait", SD.SHELTER_TICKS }', 1, true) ~= nil and SDS:find('{ { "goto", to, 3 }, { "home" } }', 1, true) ~= nil,
  "shelter : seuls les exposés lâchent leur tâche ; l'attente fixe n'est plus dans les étapes (seulement citée en commentaire)")
local WK = read("script/team/worker.lua")
check(WK:find("recall_armed_kept", 1, true) ~= nil and WK:find("Worker.hook.has_ammo(e)", 1, true) ~= nil, "Worker.recall_near : un ouvrier armé n'est pas rappelé (il défend)")
check(CO:find("quick_back", 1, true) ~= nil and SDS:find("shelter_again", 1, true) ~= nil, "allers-retours et abris répétés comptés")
check(CO:find("site_alert = Da.site_alert(t.alerts, p, tick)", 1, true) ~= nil, "le regard passe l'alerte de site à Re.decide")

section("5. Mutants (chacun doit faire échouer au moins un cas)")
local src = read("shared/team/danger_actif.lua")
local mutants = {
  { "seuil > au lieu de >=", ">= B or (deaths_n or 0)", "> B or (deaths_n or 0)" },
  { "morts au but ignorées", " or (deaths_n or 0) >= Da.DEATHS_GOAL", "" },
  { "garde-fou des morts à 3", "Da.DEATHS_GOAL = 2", "Da.DEATHS_GOAL = 3" },
  { "chemin sans menace fixe ignoré", "(route.fixed or 0) >= B or", "false and" },
  { "morts du chemin ignorées", "or (route.deaths or 0) >= Da.DEATHS_ROUTE", "" },
  { "boucle plus mise de côté", 'why == "boucle" or ', "" },
  { "tout part", 'return "aside" end\n  return "go"', 'return "go" end\n  return "go"' },
  { "tout est mis de côté", 'return "aside" end\n  return "go"', 'return "aside" end\n  return "aside"' },
  { "cases mobiles comptées", "return ((parts and parts.fixed) or 0) >= B", "return ((parts and parts.fixed) or 0) + ((parts and parts.mobile) or 0) >= B" },
  { "pause de 2 min", "Da.ASIDE_TICKS = 3600", "Da.ASIDE_TICKS = 7200" },
  { "nid pris pour une attaque mobile", 'return ctype == "unit" or ctype == "character"', 'return ctype == "unit" or ctype == "character" or ctype == "unit-spawner"' },
  { "tous exposés", "return dx * dx + dy * dy <= reach * reach", "return true" },
  { "ralliement sans limite", "if dx * dx + dy * dy > Da.RALLY_HQ_R * Da.RALLY_HQ_R then return \"stand\" end", "" },
  { "site sans limite de distance", "dx * dx + dy * dy <= Da.SITE_R * Da.SITE_R", "true" },
  { "alerte expirée comptée", 'if tick < (a["until"] or 0) then', "if true then" },
  { "alerte à chaque coup", "return last == nil or tick - last >= Da.ALERT_GAP", "return true" },
  { "repos rouvert à chaque refus", "if not a.rest_since then a.rest_since = tick end", "a.rest_since = tick" },
  { "30 s compté trop tôt", "if d > Da.REST_MAX then st.rest_over", "if d >= Da.REST_MAX then st.rest_over" },
  { "plus long non retenu", "if d > (st.rest_max or 0) then st.rest_max = d end", "" },
  { "alerte de site : groupe partiel", "if left >= Da.SITE_GROUP then return Da.SITE_GROUP, left - Da.SITE_GROUP end",
    "if left > 0 then local k = math.min(left, Da.SITE_GROUP) return k, left - k end" },
  { "alerte de site : surplus non décompté", "return Da.SITE_GROUP, left - Da.SITE_GROUP end", "return Da.SITE_GROUP, left end" },
  { "alerte de site : toujours un groupe", "if left >= Da.SITE_GROUP then", "if true then" },
  { "réserve seulement pour les lointaines", "      n, left = Da.site_send(left)\n      out[i] = { item = it, n = n }",
    "      if it.d2 <= 226 * 226 then n = Da.SITE_GROUP else n, left = Da.site_send(left) end\n      out[i] = { item = it, n = n }" },
  { "ordre d'arrivée au lieu de la distance", "if a.d2 ~= b.d2 then return a.d2 < b.d2 end", "if a.d2 ~= b.d2 then return a.d2 > b.d2 end" },
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

--- 2e essai (5/11) : danger AJOUTÉ par un trajet (shared/ai3/danger.lua, D.fixed_prep / D.fixed_at) et exemptions du but (Da.goal_deaths,
--- Da.base_defense). Verif-guide 271828182, essai 2 : une meute marquée à 24 tuiles de la case du QG mettait de côté tous les trajets partis du QG.
local function cases2(D, Da)
  local B = 600
  local function map_of(list)
    local m = D.new()
    for _, th in ipairs(list) do m.threats[#m.threats + 1] = { x = th[1], y = th[2], k = th[3], r = th[4], t = th[5] or 0 } end
    return m
  end
  local box = { -400, -400, 400, 400 }
  local function at(m, tick, from, skip, x, y)
    local prep = D.fixed_prep(m, tick, box[1], box[2], box[3], box[4], { from = from, skip = skip })
    return D.fixed_at(prep, x, y)
  end
  -- Meute (r 36, zone 40) centrée en (26, 0) ; le PNJ au QG (0, 0) est DANS la zone (26 <= 40).
  local m = map_of({ { 26, 0, "pack", 36 } })
  local hq = { x = 0, y = 0 }
  check(at(m, 0, nil, nil, -10, 0) == 800, "sans départ (règle d'avant) : point à 36 tuiles de la meute, dans sa zone : 800")
  check(at(m, 0, hq, nil, -10, 0) == 0, "départ dans la zone : un point à l'opposé (36 tuiles, le départ à 26) ne compte pas")
  check(at(m, 0, hq, nil, 10, 0) == 800, "départ dans la zone : un point plus près de la meute (16 tuiles) compte")
  check(at(m, 0, hq, nil, 0, 0) == 0, "départ dans la zone : le départ lui-même (même distance) ne compte pas")
  check(at(m, 0, hq, nil, 0, 26) == 0, "départ dans la zone : un point à côté, plus loin de la meute (36,8 tuiles) ne compte pas")
  check(at(m, 0, hq, nil, 1, 0) == 800, "départ dans la zone : un pas vers la meute (25 tuiles) compte")
  check(at(m, 0, hq, "pack", 10, 0) == 0, "genre écarté (la défense de la base ignore la meute) : 0")
  -- Ver (r 25, zone 29) en (100, 0) : départ HORS de sa zone : la règle ne change rien.
  local m2 = map_of({ { 100, 0, "worm", 25 } })
  check(at(m2, 0, hq, nil, 71, 0) == 1000 and at(m2, 0, hq, nil, 70, 0) == 0, "départ hors de la zone d'un ver : compté jusqu'au bord (29 tuiles), comme avant")
  check(at(m2, 0, hq, "pack", 80, 0) == 1000, "genre écarté : le ver compte toujours")
  -- PNJ au bord du ver (départ à 27 tuiles, dans la zone) : s'enfoncer compte, s'éloigner non.
  local edge = { x = 73, y = 0 }
  check(at(m2, 0, edge, nil, 80, 0) == 1000 and at(m2, 0, edge, nil, 60, 0) == 0, "PNJ au bord d'un ver : vers lui compte, à l'opposé non")
  -- Deux menaces : une qui couvre le départ, une autre plus loin (entrer dans la seconde compte).
  local m3 = map_of({ { 26, 0, "pack", 36 }, { -100, 0, "worm", 25 } })
  check(at(m3, 0, hq, nil, -75, 0) == 1000, "sortir de la meute pour entrer dans la zone d'un ver : le ver compte")
  -- Mêmes poids décrus que D.exact_parts (règle d'avant, sans départ) : nid vu il y a 10 min, meute vue il y a 2 min.
  local m4 = map_of({ { 0, 50, "spawner", 30, 0 }, { 40, 0, "pack", 30, 0 } })
  local tick = 10 * 3600 + 10
  for _, q in ipairs({ { 0, 30 }, { 30, 0 }, { 20, 20 }, { 0, 0 }, { 70, 0 } }) do
    check(at(m4, tick, nil, nil, q[1], q[2]) == D.exact_parts(m4, q[1], q[2], tick).fixed,
      string.format("sans départ : même danger fixe que D.exact_parts en (%d, %d)", q[1], q[2]))
  end
  -- Rectangle : une menace hors de portée du rectangle n'est pas préparée.
  local prep = D.fixed_prep(m2, 0, -10, -10, 10, 10, { from = hq })
  check(prep.nt == 0, "ver hors de portée du rectangle : écarté")
  -- Exemptions du but (Da.goal_deaths) et défense de la base (Da.base_defense).
  check(Da.goal_deaths(5, true, false, 3) == 0, "défense, morts de la route toutes dans la base (PORTE-BASE) : morts au but ignorées")
  check(Da.goal_deaths(2, false, true, 3) == 0 and Da.goal_deaths(3, false, true, 3) == 3, "au calme : morts au but ignorées sous le garde-fou (3), comptées à partir de lui")
  check(Da.goal_deaths(2, false, false, 3) == 2 and Da.goal_deaths(nil, false, false, 3) == 0, "hors exemption : toutes les morts au but")
  check(Da.base_defense("garrison", true, true) == true and Da.base_defense("refill", true, true) == true and Da.base_defense("fortify", true, true) == true,
    "garde, recharge, pose de tourelles dans la base par un PNJ armé : défense de la base")
  check(Da.base_defense("refill", true, false) == false and Da.base_defense("fortify", true, nil) == false and Da.base_defense("garrison", true, false) == false,
    "relecture de revue-danger : garde, recharge ou pose par un PNJ sans munitions chargées dans la base : pas d'exemption")
  check(Da.base_defense("garrison", false, true) == false and Da.base_defense("mine", true, true) == false and Da.base_defense("service", true, true) == false,
    "hors de la base, ou une autre tâche : pas d'exemption")
  check(Da.after_wait({ fixed = 0 }, B, "marque", 0, { fixed = 0, deaths = 0 }) == "go", "trajet qui sort de la meute (danger ajouté nul) : départ")
  -- Cas TIRÉS de c4 (verif-guide 271828182, essai 2, journal [FO-IA3K] de 44 à 48 min) : meute vue en (30, 6) (« detour (camarade) : pack en (30, 6) »),
  -- départ à la case du QG (6, 9) (« tache garrison vers (6, 9) »). Rayon de la meute : vue des déchiqueteurs 30 + étendue du groupe (0 à 24, inconnue) :
  -- les deux bornes sont jouées. Trajets en ligne droite échantillonnés comme la porte (R.samples, pas de 4 tuiles, 6 premières tuiles exclues).
  local Rr = require("shared.ai3.route")
  local function route_max(mm, from, goal, use_from)
    local qs = Rr.samples(from, {}, goal, Rr.SAMPLE)
    local prep = D.fixed_prep(mm, 0, -400, -400, 400, 400, { from = use_from and from or nil })
    local mx = 0
    for _, q in ipairs(qs) do
      if (q.x - from.x) ^ 2 + (q.y - from.y) ^ 2 > 36 then
        local v = D.fixed_at(prep, q.x, q.y)
        if v > mx then mx = v end
      end
    end
    return mx, D.fixed_at(prep, goal.x, goal.y)
  end
  local qg = { x = 6, y = 9 }
  for _, r in ipairs({ 30, 54 }) do
    local mc4 = map_of({ { 30, 6, "pack", r } })
    -- Mis de côté en c4 (« met de cote (marque) ... menace fixe au but 0 ») : trajets partis du QG à l'opposé de l'attaque.
    for _, g in ipairs({ { -42, 171, "ghost" }, { -59, 180, "ghost" }, { -100, 196, "ghost" }, { -20, 16, "mine" }, { -186, 231, "service" }, { -13, 9, "service" } }) do
      local a_route = route_max(mc4, qg, { x = g[1], y = g[2] }, false)
      local r_route, r_goal = route_max(mc4, qg, { x = g[1], y = g[2] }, true)
      check(a_route >= B, string.format("c4, meute r %d : %s vers (%d, %d) : règle d'avant, route à %d (>= seuil : mis de côté, comme en c4)", r, g[3], g[1], g[2], a_route))
      check(r_route == 0 and r_goal == 0 and Da.after_wait({ fixed = r_goal }, B, "marque", 0, { fixed = r_route, deaths = 0 }) == "go",
        string.format("c4, meute r %d : %s vers (%d, %d) s'éloigne de la meute : danger ajouté nul, départ", r, g[3], g[1], g[2]))
    end
    -- Vers l'attaque (c4 : « carry vers (20, 28) », « ghost vers (48, 4) », « rebuild vers (56, 2) ») : toujours mis de côté.
    for _, g in ipairs({ { 20, 28, "carry" }, { 48, 4, "ghost" }, { 56, 2, "rebuild" } }) do
      local r_route, r_goal = route_max(mc4, qg, { x = g[1], y = g[2] }, true)
      check(Da.after_wait({ fixed = r_goal }, B, "marque", 0, { fixed = r_route, deaths = 0 }) == "aside",
        string.format("c4, meute r %d : %s vers (%d, %d) va vers la meute : mis de côté (route %d, but %d)", r, g[3], g[1], g[2], r_route, r_goal))
    end
  end
  -- Départ HORS de toute zone : identique à la règle d'avant, point par point (c4 : ver posé sur le trajet du QG vers (-42, 171)).
  local mw = map_of({ { -10, 90, "worm", 25 }, { 30, 6, "pack", 30 } })
  local far = { x = -60, y = 20 } -- à 90 tuiles de la meute, 72 du ver : hors des deux zones
  for _, g in ipairs({ { -42, 171 }, { 40, 100 }, { 20, 6 } }) do
    local a1, a2 = route_max(mw, far, { x = g[1], y = g[2] }, false)
    local b1, b2 = route_max(mw, far, { x = g[1], y = g[2] }, true)
    check(a1 == b1 and a2 == b2, string.format("départ hors de toute zone : même danger que la règle d'avant vers (%d, %d) (route %d/%d, but %d/%d)", g[1], g[2], a1, b1, a2, b2))
  end
  -- Lot CORR-RALLIEMENT (tenue, 7/11) : état « away » et coffre de dépôt hors de portée (RAPPORT EFFONDREMENT §12).
  local w = { x = 30, y = 0, reach = 25, ["until"] = 1000 }
  check(Da.away_live(w, 999) == true and Da.away_live(w, 1000) == false and Da.away_live(nil, 0) == false,
    "« away » vivant avant until, mort à until, absent : mort")
  local cs = { { x = 10, y = 0 }, { x = -40, y = 0 }, { x = -20, y = 10 } } -- QG (à 20 de la menace : exposé), deux annexes à l'ouest
  check(Da.safe_chest(cs, { x = -10, y = 0 }, w) == 3, "coffre sûr le plus proche du PNJ (annexe à 51 de la menace), le QG exposé (20 < 25) écarté")
  check(Da.safe_chest(cs, { x = -45, y = 0 }, w) == 2, "coffre sûr le plus proche d'un PNJ à l'ouest : l'annexe lointaine")
  check(Da.safe_chest({ { x = 10, y = 0 }, { x = 10, y = 5 } }, { x = -10, y = 0 }, w) == nil, "aucun coffre hors de portée : nil (le PNJ attend)")
  check(Da.safe_chest({}, { x = 0, y = 0 }, w) == nil, "aucun coffre : nil")
end

section("6. Danger ajouté par le trajet (2e essai)")
local D = require("shared.ai3.danger")
cases2(D, Da)

section("7. Mutants du danger ajouté (chacun doit faire échouer au moins un cas)")
local srcD = read("shared/ai3/danger.lua")
local mutantsD = {
  { "départ ignoré", "if f2 <= r * r then lim[nt], strict[nt] = f2, true end", "" },
  { "départ dans la zone : tout compte", "if f2 <= r * r then lim[nt], strict[nt] = f2, true end", "if f2 <= r * r then lim[nt], strict[nt] = r * r, true end" },
  { "même distance comptée", "if dd < lim[i] or (dd == lim[i] and not strict[i]) then", "if dd <= lim[i] then" },
  { "bord de zone exclu", "if dd < lim[i] or (dd == lim[i] and not strict[i]) then", "if dd < lim[i] then" },
  { "genre écarté compté", "if t.k ~= skip then", "if true then" },
  { "sans décroissance", "lui comptent\n        end\n        tw[nt] = math.floor(K.w * (K.fast and D.dec10(tick - t.t) or D.dec2(tick - t.t)) / 1000)",
    "lui comptent\n        end\n        tw[nt] = K.w" },
  { "rectangle ignoré", "if ddx * ddx + ddy * ddy <= r * r then\n        nt = nt + 1\n        tx[nt], ty[nt], lim[nt], strict[nt]", "if true then\n        nt = nt + 1\n        tx[nt], ty[nt], lim[nt], strict[nt]" },
}
local srcDa = read("shared/team/danger_actif.lua")
local mutantsDa = {
  { "défense : morts au but gardées", "if def_base then return 0 end", "" },
  { "« away » jamais vivant", "return w ~= nil and tick < (w[\"until\"] or -1)", "return false" },
  { "« away » sans fin", "return w ~= nil and tick < (w[\"until\"] or -1)", "return w ~= nil" },
  { "coffre exposé accepté", "    if not Da.exposed(c, w, w.reach) then\n", "    if true then\n" },
  { "coffre sûr le plus loin", "if bd == nil or d < bd then best, bd = i, d end", "if bd == nil or d > bd then best, bd = i, d end" },
  { "calme : garde-fou ignoré", "if calm and (n or 0) < (cap or 0) then return 0 end", "if calm then return 0 end" },
  { "calme ignoré", "if calm and (n or 0) < (cap or 0) then return 0 end", "" },
  { "défense hors de la base", "Da.DEFENSE_KINDS[kind] and in_base and armed", "Da.DEFENSE_KINDS[kind] and armed" },
  { "désarmé exempté", "and in_base and armed) and true or false", "and in_base) and true or false" },
  { "garde toujours exemptée", "and in_base and armed) and true or false", "and in_base and (armed or kind == \"garrison\")) and true or false" },
  { "garde retirée de la défense", "Da.DEFENSE_KINDS = { fortify = true, garrison = true, refill = true }", "Da.DEFENSE_KINDS = { fortify = true, refill = true }" },
}
local refused2, total2 = 0, 0
local function try(name, src, pat, rep, which)
  total2 = total2 + 1
  local a, b = src:find(pat, 1, true)
  if not a then
    failures = failures + 1
    print("  ECHEC : mutant « " .. name .. " » : motif introuvable dans la source")
    return
  end
  local code = src:sub(1, a - 1) .. rep .. src:sub(b + 1)
  local Mu = assert(load(code, "mutant", "t"))()
  local p0, f0 = passes, failures
  cur_fail = false
  quiet = true
  local ok = pcall(cases2, which == "D" and Mu or D, which == "Da" and Mu or Da)
  quiet = false
  local failed = (not ok) or cur_fail
  passes, failures = p0, f0
  check(failed, "mutant « " .. name .. " » refusé")
  if failed then refused2 = refused2 + 1 end
end
for _, mu in ipairs(mutantsD) do try(mu[1], srcD, mu[2], mu[3], "D") end
for _, mu in ipairs(mutantsDa) do try(mu[1], srcDa, mu[2], mu[3], "Da") end
print(string.format("  mutants refusés : %d sur %d", refused2, total2))

print(string.format("[DANGER-ACTIF] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
