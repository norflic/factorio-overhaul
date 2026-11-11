--[[
  Lot DEBUG-CERVEAU : banc HORS JEU des règles pures de la vue « Cerveau » (shared/debug/*.lua). Lancement, depuis la racine du mod :
    lua5.2 tests/debug_cerveau_test.lua
  Sections :
     1. couleur d'une zone (shared/debug/zone.lua) : construction, refus, blocage, fini mesuré, jamais vert sans mesure ;
     2. cause principale et départage déterministe ; statuts du moteur -> causes ;
     3. écart IA / réel (shared/debug/ecart.lua) : accord, croit marche, croit arrêt, périmé, jamais lu, non applicable ;
     4. améliorations (shared/debug/ameliorations.lua) : une absence reste « absente » quelles que soient les faits ;
     5. lignes (shared/debug/lignes.lua) : âge, texte de zone, tâches d'une zone, décisions récentes ;
     6. coût en INSTRUCTIONS (debug.sethook, jamais os.clock) d'un relevé de 200 zones ;
     7. mutants : chaque règle retirée fait échouer au moins un contrôle.
  Aucun nom du jeu : les objets sont des chaînes opaques.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end
local function slurp(p) local f = assert(io.open(p, "rb")) local x = f:read("*a") f:close() return x end

local function load_mod(path, mutate)
  local src = slurp(path)
  if mutate then
    local i, j = src:find(mutate[1], 1, true)
    if not i then error("texte de mutant introuvable dans " .. path .. " : " .. mutate[1]) end
    src = src:sub(1, i - 1) .. mutate[2] .. src:sub(j + 1)
  end
  local fn, err = load(src, "@" .. path)
  if not fn then error(err) end
  return fn()
end

-- Un jeu complet de contrôles sur des modules donnés (les mutants rejouent exactement les mêmes).
local function run_all(Zn, Ec, Am, Lg, Pn, Bl)
  section("1. couleur d'une zone")
  for _, st in ipairs({ "attente", "plan", "reserve", "defrichage", "fantomes", "chantier", "raccordement" }) do
    local r = Zn.classify({ state = st, machines = { marche = 9 } })
    check(r.color == "gris" and r.cause == st, "construction " .. st .. " : gris, cause = l'etat (" .. tostring(r.color) .. "/" .. tostring(r.cause) .. ")")
  end
  check(Zn.classify({ state = "refuse" }).color == "gris", "refuse : gris")
  check(Zn.classify({ state = "bloque" }).color == "orange", "bloque : orange")
  check(Zn.classify({ state = "bloque" }).cause == "bloque", "bloque : cause bloque")
  check(Zn.classify(nil).color == "gris" and Zn.classify({}).color == "gris" and Zn.classify({ state = "zzz" }).color == "gris", "entree absente ou etat inconnu : gris (ferme par defaut)")
  local r = Zn.classify({ state = "fini" })
  check(r.color == "gris" and r.cause == "non_mesure", "fini sans mesure : gris non_mesure, JAMAIS vert")
  r = Zn.classify({ state = "fini", machines = {} })
  check(r.color == "gris", "fini, table vide : gris")
  r = Zn.classify({ state = "fini", machines = { marche = 10 } })
  check(r.color == "vert" and r.ratio == 1 and r.n == 10, "10 sur 10 : vert")
  r = Zn.classify({ state = "fini", machines = { marche = 8, entree = 2 } })
  check(r.color == "vert" and r.ratio == 0.8, "8 sur 10 : vert (seuil inclus)")
  r = Zn.classify({ state = "fini", machines = { marche = 7, entree = 3 } })
  check(r.color == "orange" and r.cause == "entree", "7 sur 10 : orange, cause entree")
  r = Zn.classify({ state = "fini", machines = { entree = 4 } })
  check(r.color == "rouge" and r.cause == "entree" and r.ratio == 0, "0 sur 4 : rouge")
  r = Zn.classify({ state = "fini", machines = { sortie = 3, courant = 1 } })
  check(r.color == "rouge" and r.cause == "sortie", "rouge : la cause la plus frequente (sortie 3 > courant 1)")
  r = Zn.classify({ state = "fini", machines = { marche = 10 }, lost = 1 })
  check(r.color == "orange" and r.cause == "pieces", "10 sur 10 mais une piece manquante : orange, cause pieces")
  -- A1 (DBG-COURANT, partie du DC en 0.7.3 : ~15 zones « sans courant » dont toutes les machines tournent) : un bras sans courant n'est pas une
  -- machine ; « courant » seulement si au moins une MACHINE du module manque d'alimentation (règle du DC, 11/11)
  r = Zn.classify({ state = "fini", machines = { marche = 10 }, aux = { courant = 2 } })
  check(r.color == "vert" and r.cause == nil, "bras sans courant, 10 machines sur 10 en marche : vert (pas « sans courant »)")
  r = Zn.classify({ state = "fini", machines = { marche = 1 }, aux = { courant = 5 } })
  check(r.color == "vert" and #r.top == 0, "1 machine en marche, 5 bras sans courant : vert, aucune cause")
  r = Zn.classify({ state = "fini", aux = { courant = 3 } })
  check(r.color == "gris" and r.cause == "non_mesure", "aucune machine, 3 bras sans courant : non mesure (jamais « sans courant »)")
  do
    local m = {}
    for _, s in ipairs({ "working", "working", "working", "working", "working", "working", "working", "no_power", "low_power", "no_power" }) do
      local c = Zn.cause_of_status(s)
      m[c] = (m[c] or 0) + 1
    end
    r = Zn.classify({ state = "fini", machines = m })
    check(r.color == "orange" and r.cause == "courant" and r.top[1].n == 3, "3 machines sur 10 sans courant (statuts du moteur) : orange, cause courant")
  end
  r = Zn.classify({ state = "fini", lost = 3 })
  check(r.color == "orange" and r.cause == "pieces" and r.n == 0, "fini sans machine mesuree mais 3 pieces manquantes : orange (jamais gris silencieux)")
  r = Zn.classify({ state = "fini", machines = { marche = 1, courant = 5 } })
  check(r.color == "orange" and r.top[1].cause == "courant" and r.top[1].n == 5, "top : courant 5 (machines)")

  section("2. cause principale, departage, statuts")
  r = Zn.classify({ state = "fini", machines = { entree = 2, sortie = 2 } })
  check(r.cause == "entree", "egalite entree/sortie : l'ordre de Zn.CAUSES (entree avant sortie)")
  r = Zn.classify({ state = "fini", machines = { sortie = 2, courant = 2, combustible = 2 } })
  check(r.cause == "courant" and r.top[1].cause == "courant" and r.top[2].cause == "combustible" and r.top[3].cause == "sortie", "egalite a 3 : courant, combustible, sortie")
  check(Zn.cause_of_status("working") == "marche", "working -> marche")
  check(Zn.cause_of_status("no_power") == "courant" and Zn.cause_of_status("low_power") == "courant", "courant")
  check(Zn.cause_of_status("full_output") == "sortie" and Zn.cause_of_status("waiting_for_space_in_destination") == "sortie", "sortie")
  check(Zn.cause_of_status("no_ingredients") == "entree" and Zn.cause_of_status("fluid_ingredient_shortage") == "entree", "entree")
  check(Zn.cause_of_status("no_fuel") == "combustible", "combustible")
  check(Zn.cause_of_status("no_minable_resources") == "gisement", "gisement")
  check(Zn.cause_of_status("statut_inconnu") == "autre" and Zn.cause_of_status(nil) == "autre", "statut inconnu : autre, jamais marche")

  section("3. ecart IA / reel")
  local verte = { color = "vert" }
  local rouge = { color = "rouge", cause = "sortie" }
  local orange = { color = "orange", cause = "entree" }
  local NOW = 100000
  local e = Ec.compare({ { src = "manque", verdict = "marche", tick = NOW - 2400 } }, verte, NOW)
  check(e.kind == "accord" and e.sev == "ok" and e.age == 2400, "IA marche, reel vert : accord, age 2400")
  e = Ec.compare({ { src = "manque", verdict = "marche", tick = NOW - 2400 } }, rouge, NOW)
  check(e.kind == "croit_marche" and e.sev == "alerte", "IA marche, reel rouge : croit_marche, alerte")
  e = Ec.compare({ { src = "manque", verdict = "marche", tick = NOW - 600 } }, orange, NOW)
  check(e.kind == "croit_marche" and e.sev == "attention", "IA marche, reel orange : croit_marche, attention")
  e = Ec.compare({ { src = "manque", verdict = "arret", why = "courant", tick = NOW - 600 } }, verte, NOW)
  check(e.kind == "croit_arret" and e.sev == "alerte" and e.why == "courant", "IA arret, reel vert : croit_arret")
  e = Ec.compare({ { src = "manque", verdict = "arret", tick = NOW - 600 } }, rouge, NOW)
  check(e.kind == "accord", "IA arret, reel rouge : accord")
  e = Ec.compare({ { src = "manque", verdict = "marche", tick = NOW - Ec.STALE - 1 } }, rouge, NOW)
  check(e.kind == "perime" and e.sev == "alerte" and e.stale == true and e.age == Ec.STALE + 1, "lecture plus vieille que le seuil : perime, alerte si reel pas vert")
  e = Ec.compare({ { src = "manque", verdict = "marche", tick = NOW - Ec.STALE } }, verte, NOW)
  check(e.kind == "accord", "lecture a l'age exact du seuil : encore valable")
  e = Ec.compare({ { src = "manque", verdict = "marche", tick = NOW - Ec.STALE - 1 } }, verte, NOW)
  check(e.kind == "perime" and e.sev == "info", "perime et reel vert : info")
  e = Ec.compare({}, rouge, NOW)
  check(e.kind == "jamais_lu" and e.sev == "alerte", "aucune lecture, reel rouge : jamais_lu, alerte")
  e = Ec.compare({}, verte, NOW)
  check(e.kind == "jamais_lu" and e.sev == "info", "aucune lecture, reel vert : jamais_lu, info")
  e = Ec.compare(nil, verte, NOW)
  check(e.kind == "jamais_lu", "lectures absentes : jamais_lu")
  e = Ec.compare({}, { color = "gris" }, NOW)
  check(e.kind == "non_applicable" and e.sev == "ok", "zone en construction : non_applicable")
  e = Ec.compare({ { src = "manque", verdict = "marche" } }, rouge, NOW)
  check(e.kind == "perime", "lecture SANS date : comptee perimee (ferme par defaut)")
  e = Ec.compare({ { src = "manque", verdict = "marche", tick = NOW + 50 } }, rouge, NOW)
  check(e.kind == "perime", "lecture datee dans le futur : perimee")
  e = Ec.compare({ { src = "manque", verdict = "marche", tick = NOW - 100 }, { src = "debit", verdict = "arret", why = "rien", tick = NOW - 5000 } }, rouge, NOW)
  check(e.kind == "accord" and e.verdict == "arret" and e.src == "debit", "deux lectures valables, l'une dit arret : la zone est arretee pour le cerveau")
  e = Ec.compare({ { src = "manque", verdict = "marche", tick = NOW - 100 }, { src = "debit", verdict = "arret", tick = NOW - Ec.STALE - 5 } }, rouge, NOW)
  check(e.kind == "croit_marche" and e.src == "manque", "une lecture arret PERIMEE ne compte pas")
  e = Ec.compare({ { src = "a", verdict = "marche", tick = NOW - 900 }, { src = "b", verdict = "marche", tick = NOW - 100 } }, verte, NOW)
  check(e.src == "b" and e.age == 100, "deux lectures marche : la plus recente est citee")
  e = Ec.compare({ { src = "a", verdict = "marche", tick = NOW - 900 } }, verte, NOW, 500)
  check(e.kind == "perime", "seuil donne en argument")
  e = Ec.compare({ { src = "pensee", verdict = "inconnu", tick = NOW - 300 } }, rouge, NOW)
  check(e.kind == "lu_sans_verdict" and e.sev == "attention" and e.src == "pensee", "lu mais verdict non garde, reel rouge : lu_sans_verdict, attention")
  e = Ec.compare({ { src = "pensee", verdict = "inconnu", tick = NOW - 300 } }, verte, NOW)
  check(e.kind == "lu_sans_verdict" and e.sev == "info", "lu mais verdict non garde, reel vert : info")
  e = Ec.compare({ { src = "pensee", verdict = "inconnu", tick = NOW - 300 }, { src = "debit", verdict = "arret", tick = NOW - 600 } }, rouge, NOW)
  check(e.kind == "accord" and e.src == "debit", "verdict inconnu + une lecture arret : la lecture connue tranche")
  local rows = { { key = "z3", sev = "ok" }, { key = "z2", sev = "alerte" }, { key = "z1", sev = "alerte" }, { key = "z4", sev = "attention" }, { key = "z5", sev = "info" } }
  Ec.sort(rows)
  check(rows[1].key == "z1" and rows[2].key == "z2" and rows[3].key == "z4" and rows[4].key == "z5" and rows[5].key == "z3", "tri : alertes (par cle), attention, info, ok")

  section("4. ameliorations")
  local L = Am.evaluate(nil)
  check(#L == #Am.CATALOGUE, "une ligne par entree du catalogue")
  local by = {}
  for _, row in ipairs(L) do by[row.key] = row end
  check(by.niveau.state == "aucune" and by.liaison.state == "aucune", "mecanisme existant sans fait : aucune")
  check(by.charbon_tapis.state == "absente" and by.bras_repartiteur.state == "absente", "charbon -> tapis et bras -> repartiteur : absentes")
  check(by.charbon_tapis.exists == false and by.charbon_tapis.owner == nil, "absente : pas de proprietaire")
  L = Am.evaluate({ charbon_tapis = { state = "prevue", why = "invente" }, bras_repartiteur = { state = "en_cours" }, niveau = { state = "prevue", why = "famille X" }, liaison = { state = "refusee", why = "ennemi a portee" } })
  by = {}
  for _, row in ipairs(L) do by[row.key] = row end
  check(by.charbon_tapis.state == "absente" and by.bras_repartiteur.state == "absente", "des faits ne font PAS exister une amelioration absente")
  check(by.niveau.state == "prevue" and by.niveau.why == "famille X", "fait recopie : prevue + raison")
  check(by.liaison.state == "refusee" and by.liaison.why == "ennemi a portee", "fait recopie : refusee + raison")
  L = Am.evaluate({ niveau = { state = "n_importe_quoi" } })
  check(L[1].state == "aucune", "etat inconnu : aucune")
  local abs = Am.absentes()
  check(#abs == 2 and abs[1] == "charbon_tapis" and abs[2] == "bras_repartiteur", "liste des absences pour l'integrateur")

  -- piquage (lot PIQUAGE) : lu dans f.build.piquage, mots fixes
  L = Am.evaluate({ bras_repartiteur = { present = true, state = "en_cours", why = { "cle", "x" } }, charbon_tapis = { state = "prevue" } })
  by = {}
  for _, row in ipairs(L) do by[row.key] = row end
  check(by.bras_repartiteur.exists == true and by.bras_repartiteur.present == true and by.bras_repartiteur.state == "en_cours", "present = true : le mecanisme existe, son etat est recopie")
  check(by.bras_repartiteur.why[1] == "cle", "la raison peut etre une chaine localisee (table)")
  check(by.charbon_tapis.state == "absente" and by.charbon_tapis.exists == false, "un fait SANS present ne fait toujours pas exister l'absence")
  check(by.niveau.present == nil, "un mecanisme deja existant n'est pas marque present")
  L = Am.evaluate({ charbon_tapis = { present = false, state = "prevue" }, bras_repartiteur = { present = "oui", state = "prevue" } })
  by = {}
  for _, row in ipairs(L) do by[row.key] = row end
  check(by.charbon_tapis.state == "absente" and by.bras_repartiteur.state == "absente", "present different de true (false, texte) : reste absente")
  local quais = {
    ["7:q1"] = { verdict = "refuse", cause = "trop_loin", tick = 100 },
    ["7:q2"] = { verdict = "demande", cause = "ok", tick = 50 },
    ["7:q10"] = { verdict = "actif", cause = "livre", tick = 70 },
    ["8:q1"] = { verdict = "inerte", cause = "ne_livre_pas", tick = 10 },
    ["70:q1"] = { verdict = "laisser", cause = "ok", tick = 10 },
  }
  local rows = Am.piquage_rows(quais, 7)
  check(#rows == 3 and rows[1].i == 1 and rows[2].i == 2 and rows[3].i == 10, "quais du projet 7 seulement (pas 70, pas 8), tries par numero : " .. #rows)
  local sm = Am.piquage_summary(quais)
  check(sm.state == "en_cours" and sm.why.verdict == "demande" and sm.why.n == 1, "resume : un travail en cours passe devant un refus")
  sm = Am.piquage_summary({ ["1:q1"] = { verdict = "refuse", cause = "trop_loin", tick = 5 }, ["1:q2"] = { verdict = "refuse", cause = "ne_se_paie_pas", tick = 9 } })
  check(sm.state == "refusee" and sm.why.cause == "ne_se_paie_pas" and sm.why.n == 2, "resume : refus, le plus recent cite, 2 quais")
  sm = Am.piquage_summary({ ["1:q1"] = { verdict = "actif", cause = "livre", tick = 5 } })
  check(sm.state == "aucune" and sm.why == nil, "resume : actif seul = rien d'envisage")
  check(Am.piquage_summary(nil).state == "aucune" and #Am.piquage_rows(nil, 1) == 0, "pas de champ : aucune")
  rows = Am.piquage_rows({ ["3:q1"] = { verdict = "mot jamais vu", cause = "texte libre", tick = 1 } }, 3)
  check(rows[1].verdict == "inconnu" and rows[1].cause == "inconnu", "mot hors liste : inconnu, jamais un texte brut derriere une cle")

  section("5. lignes")
  check(Lg.ago(nil)[1] == "fo-dbg-cerveau.ago-inconnu" and Lg.ago(-5)[1] == "fo-dbg-cerveau.ago-inconnu", "age inconnu")
  local a = Lg.ago(2400)
  check(a[1] == "fo-dbg-cerveau.ago-s" and a[2] == 40, "2400 ticks = 40 s")
  a = Lg.ago(60 * 60 * 3)
  check(a[1] == "fo-dbg-cerveau.ago-min" and a[2] == 3, "3 min")
  a = Lg.ago(60 * 60 * 120)
  check(a[1] == "fo-dbg-cerveau.ago-h" and a[2] == "2.0", "120 min = 2.0 h")
  local lab = Lg.label({ kind = "module", product = "objetA", rate_meas = 41.6, rate_nom = 60, color = "orange", cause = "entree" })
  check(lab[1] == "fo-dbg-cerveau.zone-produit" and lab[2] == "[item=objetA]" and lab[3] == "42" and lab[4] == "60" and lab[5][1] == "fo-dbg-cerveau.cause-entree", "label avec produit")
  lab = Lg.label({ kind = "fonderie", product = "objetA", rate_meas = 227, rate_nom = 570, color = "orange", cause = "entree", n = 30, run = 12 })
  check(lab[7][1] == "fo-dbg-cerveau.zone-machines" and lab[7][2] == 12 and lab[7][3] == 30, "fonderie a 30 fours, 12 en marche : X/N en marche dans l'etiquette")
  lab = Lg.label({ kind = "module", product = "objetA", color = "orange", cause = "entree" })
  check(lab[7] == "", "sans machine mesuree : pas de X/N")
  lab = Lg.label({ kind = "centrale", color = "vert" })
  check(lab[1] == "fo-dbg-cerveau.zone-simple" and lab[3][1] == "fo-dbg-cerveau.cause-aucune", "label sans produit, vert : cause aucune")
  lab = Lg.label({ kind = "module", product = "objetA", color = "vert", cause = "entree" })
  check(lab[5][1] == "fo-dbg-cerveau.cause-aucune", "vert : pas de cause affichee")
  lab = Lg.label({ kind = "module", product = "objetA" })
  check(lab[3] == "?" and lab[4] == "?", "debit absent : ?")
  local tasks = {
    { key = "t3", kind = "ravitailler", prio = 70, taken = false, pid = 7 },
    { key = "t1", kind = "ravitailler", prio = 95, taken = false, pid = 7 },
    { key = "t2", kind = "construire", prio = 50, taken = true, pid = 7 },
    { key = "t9", kind = "autre", prio = 99, taken = false, pid = 8 },
    { key = "t5", kind = "tournee", prio = 70, taken = false, outpost = 4 },
  }
  local tz = Lg.tasks_for_zone(tasks, { pid = 7 })
  check(#tz == 3 and tz[1].key == "t2" and tz[2].key == "t1" and tz[3].key == "t3", "taches du projet 7 : prise d'abord, puis priorite")
  tz = Lg.tasks_for_zone(tasks, { oid = 4 })
  check(#tz == 1 and tz[1].key == "t5", "taches de l'avant-poste 4")
  tz = Lg.tasks_for_zone(tasks, { pid = 99 })
  check(#tz == 0, "aucune tache")
  tz = Lg.tasks_for_zone(tasks, { pid = 7 }, 2)
  check(#tz == 2, "plafond de taches")
  check(Lg.task_key("service", nil) == "service" and Lg.task_key("carry", "fill") == "carry-fill" and Lg.task_key("carry", "collect") == "carry-collect", "etiquettes de tache : kind et kind/mode")
  check(Lg.task_key("carry", "zzz") == "autre" and Lg.task_key("inconnue", nil) == "autre" and Lg.task_key(nil, nil) == "autre", "tache inconnue : autre, jamais une cle absente")
  check(Lg.task_key("rebuild") == "repare" and Lg.task_key("repair") == "repare", "reparer : trois kinds, une etiquette")
  local sr = Lg.source_row("iron-ore", { choix = "sortie", raison = "en_marche", n = 120, d = 34, tick = 500, why = "texte libre jamais lu" })
  check(sr.kind == "source" and sr.tick == 500 and sr.ltext[3][1] == "fo-dbg-cerveau.src-choix-sortie" and sr.ltext[4][1] == "fo-dbg-cerveau.src-raison-en_marche" and sr.ltext[5] == "120" and sr.ltext[6] == "34", "decision de minage : mots fixes traduits")
  check(not sr.text:find("libre", 1, true), "le champ why (texte libre) n'est jamais lu")
  sr = Lg.source_row("iron-ore", { choix = "n'importe quoi", raison = "texte libre" })
  check(sr.ltext[3][1] == "fo-dbg-cerveau.src-choix-inconnu" and sr.ltext[4][1] == "fo-dbg-cerveau.src-raison-inconnu" and sr.ltext[5] == "?" and sr.tick == nil, "mot hors liste : inconnu, nombres absents : ?")
  check(Lg.source_row("x", nil) == nil, "entree absente : pas de ligne")
  local dr = Lg.defense_row({ key = "qg1", kind = "qg", have = 2, want = 3, skip = "refus", why = "ennemi", tick = 900, x = 1, y = 2 })
  check(dr.kind == "defense" and dr.tick == 900 and dr.ltext[2][1] == "fo-dbg-cerveau.def-kind-qg" and dr.ltext[5][1] == "" and dr.ltext[5][4][1] == "fo-dbg-cerveau.def-why-ennemi", "defense du stock : lieu, a portee, cause et pourquoi en mots fixes")
  dr = Lg.defense_row({ key = "s", kind = "n'importe quoi", skip = "texte libre", why = "libre", have = 1 })
  check(dr.ltext[2][1] == "fo-dbg-cerveau.def-kind-inconnu" and dr.ltext[5][1] == "fo-dbg-cerveau.def-skip-inconnu" and dr.ltext[4] == "?", "defense : mot hors liste = inconnu, pourquoi libre ignore")
  dr = Lg.defense_row({ key = "s", kind = "site", skip = "servie" })
  check(dr.ltext[5][1] == "fo-dbg-cerveau.def-skip-servie", "sans pourquoi : la seule cause")
  check(Lg.defense_row(nil) == nil, "defense : entree absente")
  local ar = Lg.am_refus("p12|furnace", { cause = "plafond-centre", tick = 500 })
  check(ar.pid == 12 and ar.famille == "furnace" and ar.cause == "plafond-centre" and ar.tick == 500 and ar.bloc[1] == "fo-dbg-cerveau.am-bloc-projet", "refus d'amelioration : bloc projet, famille, cause fixe")
  check(Lg.am_refus("qg|gun", { cause = "emprise" }).bloc[1] == "fo-dbg-cerveau.am-bloc-qg" and Lg.am_refus("t4|gun", { cause = "emprise" }).bloc[2] == "4", "blocs qg et tourelles")
  ar = Lg.am_refus("zzz|x", { cause = "texte libre" })
  check(ar.cause == "inconnu" and ar.bloc[1] == "fo-dbg-cerveau.am-bloc-inconnu" and ar.pid == nil, "bloc ou cause hors liste : inconnu")
  check(Lg.am_refus(nil, {}) == nil and Lg.am_refus("a|b", nil) == nil, "entree absente : nil")
  check(Lg.am_refus_row("p3|x", { cause = "sans-gain", tick = 9 }).kind == "amelioration_refus", "ligne de decision")
  local dec = Lg.decisions({
    { tick = 100, kind = "ordre", text = "A" }, { tick = 300, kind = "ordre", text = "B" }, { tick = 200, kind = "refus", text = "C" },
    { tick = 50, kind = "ordre", text = "A" }, { kind = "note", text = "sans date" },
  }, 10)
  check(#dec == 4 and dec[1].text == "B" and dec[2].text == "C" and dec[3].text == "A" and dec[3].tick == 100 and dec[4].text == "sans date", "decisions : recentes d'abord, doublon retire (le plus recent garde), sans date a la fin")
  dec = Lg.decisions({ { tick = 1, kind = "k", text = "a" }, { tick = 2, kind = "k", text = "b" }, { tick = 3, kind = "k", text = "c" } }, 2)
  check(#dec == 2 and dec[1].text == "c" and dec[2].text == "b", "decisions : plafond")
  check(#Lg.decisions(nil) == 0, "decisions : entree absente")

  section("5 bis. PNJ (shared/debug/pnj.lua)")
  local ex = Pn.explain({ has_task = true, state = "step" })
  check(ex.cause == "en_marche", "PNJ avec tache : en marche")
  ex = Pn.explain({ has_task = true, state = "wait", wait_left = 300 })
  check(ex.cause == "attente" and ex.left == 300, "attente chronometree")
  ex = Pn.explain({ has_task = true, state = "walk", nav_fail = "no_path" })
  check(ex.cause == "marche_echec" and ex.why == "no_path", "echec de marche")
  ex = Pn.explain({ has_task = false, free = {} })
  check(ex.cause == "aucune_tache" and ex.n == 0, "tableau sans tache libre")
  ex = Pn.explain({ has_task = false, free = { { key = "a", pause = 600 }, { key = "b", pause = 100 } } })
  check(ex.cause == "pauses" and ex.key == "a" and ex.n == 2 and ex.n_pause == 2, "toutes en pause d'echec")
  ex = Pn.explain({ has_task = false, free = { { key = "a", pause = 600 }, { key = "b", missing = { item = "fer", need = 50, free = 10 } } } })
  check(ex.cause == "matiere" and ex.key == "b" and ex.item == "fer" and ex.need == 50 and ex.free == 10 and ex.n_pause == 1 and ex.n_matiere == 1, "manque de matiere : l'objet, le besoin et le libre")
  ex = Pn.explain({ has_task = false, free = { { key = "a", pause = 600 }, { key = "b", missing = { item = "fer", need = 5, free = 0 } }, { key = "c" } } })
  check(ex.cause == "pret" and ex.key == "c", "une tache prenable : pret")
  check(Pn.explain(nil).cause == "aucune_tache", "entree absente : aucune tache (ferme)")
  check(Pn.state_word("walk") == "walk" and Pn.state_word("zzz") == "inconnu" and Pn.state_word(nil) == "inconnu", "mot d'etat")
  local sr = Pn.step_rows({ { "home" }, { "goto", { x = 10.4, y = -3 } }, { "take", { { "fer", 4 }, { "cuivre", 2 }, { "pierre", 1 } } }, { "bizarre" }, { "mine", "iron-ore" } }, 2)
  check(sr.total == 5 and sr.left == 4 and #sr.rows == 4 and sr.rows[1].kind == "goto" and sr.rows[1].current == true and sr.rows[1].arg == "(10, -3)", "etapes restantes depuis l'etape en cours")
  check(sr.rows[2].kind == "take" and sr.rows[2].arg == "fer 4, cuivre 2, …" and sr.rows[3].kind == "autre" and sr.rows[4].arg == "iron-ore", "arguments courts, etape inconnue = autre")
  local many = {}
  for i = 1, 20 do many[i] = { "home" } end
  check(#Pn.step_rows(many, 1).rows == Pn.STEPS_MAX and Pn.step_rows(many, 1).left == 20, "etapes plafonnees")
  check(#Pn.step_rows(nil, 1).rows == 0 and #Pn.step_rows({ { "home" } }, 5).rows == 0, "sans etapes : vide")
  local nx = Pn.next_rows({ { key = "t3", kind = "mine", prio = 40 }, { key = "t1", kind = "build", prio = 90, pause = 120 }, { key = "t2", kind = "carry", prio = 90, missing = { item = "fer", need = 9, free = 1 } },
    { key = "t4", kind = "mine", prio = 10 }, { key = "t5", kind = "mine", prio = 5 }, { key = "t6", kind = "mine", prio = 1 }, { key = 7 } })
  check(#nx == Pn.NEXT_MAX and nx[1].key == "t1" and nx[1].status == "pause" and nx[2].key == "t2" and nx[2].status == "matiere" and nx[2].item == "fer" and nx[3].key == "t3" and nx[3].status == "ok", "taches suivantes : priorite puis cle, statut pause / matiere / ok, plafond " .. Pn.NEXT_MAX)

  section("5 ter. blocs, lignes et tampons (shared/debug/blocs.lua, liens.lua, lignes.lua)")
  local Li = require("shared.debug.liens")
  local lines = Li.lines({
    { pid = 9, state = "fini", spec = { liaison = { key = "a", item = "iron-plate", dock = { pid = 3, x = 10, y = 10 }, src = { pid = 2, x = 0, y = 10 } } } },
    { pid = 4, state = "chantier", spec = { liaison = { key = "b", bus = true, item = "copper-plate", dock = { pid = 5, x = 50, y = 0 }, src = { pid = 6, x = 20, y = 0 } } } },
    { pid = 7, state = "fini", spec = { liaison = { key = "c", piquage = true, item = "transport-belt", geo = { x = 30.5, y = 5.5 }, dock = { pid = 3, x = 12, y = 12 } } } },
    { pid = 8, state = "refuse", reason = "ennemi a portee", spec = { liaison = { key = "d", item = "x", dock = { x = 1, y = 1 }, src = { x = 2, y = 2 } } } },
    { pid = 11, state = "fini", spec = { rapatriement = { key = "r", item = "iron-plate", src = { pid = 2, x = 70, y = 20 }, point = { x = 40, y = 20 } } }, rap = { tampon_x = 41, tampon_y = 21 } },
  }, { piquage = { links = { c = { split = true } }, quais = {} } })
  check(#lines == 5 and lines[1].pid == 4 and lines[2].pid == 7 and lines[3].pid == 8 and lines[5].pid == 11, "lignes : refusee GARDEE (en rouge), rapatriement compris, triees par projet : " .. #lines)
  check(lines[3].status == "refuse" and lines[3].cause and lines[3].cause.text == "ennemi a portee", "ligne refusee : sa cause (motif du plan) est la")
  check(lines[5].kind == "rapatriement" and lines[5].to.x == 41.5 and lines[5].to.y == 21.5, "rapatriement : arrive au coffre TAMPON, au centre de la tuile")
  check(lines[1].kind == "bus" and Li.dashed(lines[1]) and lines[1].src_pid == 6 and lines[1].dock_pid == 5, "tronc de bus en chantier : pointille, bouts connus")
  check(lines[2].kind == "piquage" and lines[2].status == "actif" and lines[2].from.x == 30.5 and lines[2].src_pid == nil, "branche de piquage posee : part du repartiteur, pas d'un bloc")
  check(lines[4].kind == "quai" and lines[4].from.x == 0.5 and lines[4].to.x == 10.5 and lines[4].status == "actif", "liaison de quai : centres des coffres (tuile + 0,5)")
  local buf = Li.buffers(lines)
  check(#buf == 4, "tampons : un par coffre d'arrivee, refusee exclue : " .. #buf)
  local sp = Bl.splitters(lines)
  check(#sp == 1 and sp[1].x == 30.5 and sp[1].item == "transport-belt", "repartiteurs de piquage")
  check(#Bl.splitters({ { kind = "piquage", status = "chantier", from = { x = 1, y = 1 } }, { kind = "piquage", status = "refuse", from = { x = 1, y = 1 } },
    { kind = "piquage", status = "attente", from = { x = 1, y = 1 } } }) == 0, "pas de repartiteur tant que la branche n'est pas posee")
  -- textes des lignes et des tampons
  check(Lg.item("iron-plate") == "[item=iron-plate]", "objet : texte riche (les objets qui posent une entite n'ont pas de cle item-name)")
  check(Lg.link_state({ status = "actif" }) == "" and Lg.link_state({ status = "chantier" })[1] == "fo-dbg-cerveau.lien-statut-chantier", "etat d'une ligne : active = rien, chantier = mot")
  local ls = Lg.link_state(lines[3])
  check(ls[1] == "fo-dbg-cerveau.lien-statut-cause" and ls[2][1] == "fo-dbg-cerveau.lien-statut-refuse" and ls[3] == "ennemi a portee", "ligne refusee : REFUSEE + cause")
  check(Lg.link_cause({ kind = "etat", code = "bloque" })[1] == "fo-dbg-cerveau.etat-bloque" and Lg.link_cause({ kind = "etat", code = "zz" }) == "zz", "cause d'etat : cle connue ou mot brut")
  check(Lg.link_cause({ kind = "piquage", code = "ennemi" })[1] == "fo-dbg-cerveau.pq-cause-ennemi" and Lg.link_cause({ kind = "piquage", code = "zz" })[1] == "fo-dbg-cerveau.pq-cause-inconnu", "cause de piquage : cle connue ou inconnue")
  check(#Lg.link_cause({ kind = "texte", text = string.rep("x", 300) }) == Lg.LINK_CAUSE_TEXT_MAX + 2, "motif libre coupe")
  local cut = Lg.link_cause({ kind = "texte", text = string.rep(string.char(195, 169), 100) })
  check(#cut % 2 == 1 and cut:sub(-3) == "..." and (#cut - 3) % 2 == 0, "motif coupe sans casser un caractere UTF-8 : " .. #cut)
  check(Lg.link_state({ status = "zz" })[1] == "fo-dbg-cerveau.lien-statut-inconnu", "statut inconnu : dit inconnu, pas chantier")
  check(Lg.link_cause(nil) == nil and Lg.link_cause({ kind = "?" }) == nil, "pas de cause : rien")
  local lt = Lg.link_text(lines[5])
  check(lt[1] == "fo-dbg-cerveau.lien-ligne" and lt[2][1] == "fo-dbg-cerveau.lien-rapatriement" and lt[3] == "[item=iron-plate]", "texte d'une ligne de rapatriement")
  check(Lg.buffer_label(buf[1])[1] == "fo-dbg-cerveau.lien-tampon", "tampon ordinaire")
  local rapb
  for _, b in ipairs(buf) do for _, k in ipairs(b.kinds) do if k == "rapatriement" then rapb = b end end end
  check(rapb and Lg.buffer_label(rapb)[1] == "fo-dbg-cerveau.lien-tampon-rap" and Lg.buffer_label(rapb)[2][2] == "p2", "tampon de rapatriement : etiquette propre et bloc source")
  check(Lg.buffer_label({ kinds = { "piquage" }, sources = {} })[2][1] == "fo-dbg-cerveau.lien-source-tapis", "tampon d'un piquage : source = tapis existant")
  local io = Bl.io({ { x = 1, y = 2, item = "fer" }, { x = 3, y = 4 }, { x = "a", y = 1 } }, { { x = 5, y = 6 } }, 6)
  check(#io.ins == 2 and io.ins[1].item == "fer" and io.ins[2].item == nil and #io.outs == 1, "entrees et sorties : coordonnees valides seulement")
  local many_q = {}
  for i = 1, 20 do many_q[i] = { x = i, y = i } end
  check(#Bl.io(many_q, many_q, 4).ins == 4 and #Bl.io(many_q, many_q, 4).outs == 4, "entrees et sorties plafonnees")
  check(#Bl.cap({ 1, 2, 3, 4, 5 }, 3) == 3 and #Bl.cap({ 1, 2 }, 5) == 2 and #Bl.cap({ 1 }, 0) == 0, "plafond d'objets de rendu")

  section("6. cout en instructions (200 zones)")
  local count = 0
  local function hook() count = count + 1000 end
  debug.sethook(hook, "", 1000)
  for i = 1, 200 do
    local z = Zn.classify({ state = "fini", machines = { marche = 6, entree = 2, sortie = 1 }, aux = { courant = i % 3 } })
    local ec = Ec.compare({ { src = "m", verdict = "marche", tick = 1000 - i }, { src = "d", verdict = "marche", tick = 900 } }, z, 1000)
    Lg.label({ kind = "module", product = "p" .. i, rate_meas = i, rate_nom = 60, color = z.color, cause = z.cause })
    if ec.sev == "x" then error("unreachable") end
  end
  debug.sethook()
  check(count <= 400000, "200 zones classees et comparees : " .. count .. " instructions (<= 400000)")
  if not quiet then print("  instructions pour 200 zones : environ " .. count) end
end

local function load_all(mut)
  local Pn = load_mod("shared/debug/pnj.lua", mut and mut.pnj)
  local Bl = load_mod("shared/debug/blocs.lua", mut and mut.blocs)
  local Zn = load_mod("shared/debug/zone.lua", mut and mut.zone)
  local Ec = load_mod("shared/debug/ecart.lua", mut and mut.ecart)
  local Am = load_mod("shared/debug/ameliorations.lua", mut and mut.am)
  local Lg = load_mod("shared/debug/lignes.lua", mut and mut.lg)
  return Zn, Ec, Am, Lg, Pn, Bl
end

run_all(load_all(nil))

section("8. traductions (contrat des cles)")
do
  local function keys_of(path)
    local keys, cur = {}, nil
    for line in (slurp(path) .. "\n"):gmatch("(.-)\r?\n") do
      local sec = line:match("^%[(.-)%]$")
      if sec then cur = sec
      elseif cur == "fo-dbg-cerveau" then
        local k = line:match("^([%w_%-]+)=")
        if k then keys[k] = true end
      end
    end
    return keys
  end
  local fr, en = keys_of("locale/fr/debug_cerveau.cfg"), keys_of("locale/en/debug_cerveau.cfg")
  local missing_en, missing_fr = {}, {}
  for k in pairs(fr) do if not en[k] then missing_en[#missing_en + 1] = k end end -- comparaison seule : l'ordre ne compte pas
  for k in pairs(en) do if not fr[k] then missing_fr[#missing_fr + 1] = k end end
  table.sort(missing_en) table.sort(missing_fr)
  check(#missing_en == 0, "cles FR absentes de l'anglais : " .. table.concat(missing_en, ", "))
  check(#missing_fr == 0, "cles EN absentes du francais : " .. table.concat(missing_fr, ", "))
  -- 1. chaque cle ecrite en toutes lettres dans le code existe
  local lit_missing = {}
  for _, path in ipairs({ "shared/debug/zone.lua", "shared/debug/ecart.lua", "shared/debug/ameliorations.lua", "shared/debug/lignes.lua",
      "script/debug/lecture.lua", "script/debug/rendu.lua", "script/debug/panneau.lua", "script/debug/cerveau.lua" }) do
    for key in slurp(path):gmatch('"fo%-dbg%-cerveau%.([%w_%-]+)"') do
      -- une clé qui finit par « - » est le début d'une clé construite à l'exécution : ses valeurs sont contrôlées plus bas (familles)
      if key:sub(-1) ~= "-" and not fr[key] then lit_missing[#lit_missing + 1] = path .. " : " .. key end
    end
  end
  table.sort(lit_missing)
  check(#lit_missing == 0, "cles ecrites dans le code mais absentes du .cfg : " .. table.concat(lit_missing, "; "))
  -- 2. familles construites a l'execution : chaque valeur possible a sa cle
  local Zn, Ec, Am, Lg, Pn, Bl = load_all(nil)
  local fam = {}
  local function add(prefix, list) fam[#fam + 1] = { prefix, list } end
  add("sorte-", { "module", "fonderie", "labos", "centrale", "champ", "site", "quartier", "liaison", "raccord", "enceinte", "avant_poste" })
  local states = { "fini", "refuse", "bloque" }
  for st in pairs(Zn.BUILD) do states[#states + 1] = st end -- liste a completer : l'ordre ne compte pas
  add("etat-", states)
  local causes = { "aucune", "bloque", "inconnu", "refuse", "non_mesure", "debit_nul" }
  for _, c in ipairs(Zn.CAUSES) do causes[#causes + 1] = c end
  for st in pairs(Zn.BUILD) do causes[#causes + 1] = st end
  add("cause-", causes)
  add("couleur-", Zn.COLORS)
  add("source-", { "manque", "debit", "sante", "pensee" })
  add("verdict-", { "marche", "arret", "inconnu" })
  add("ecart-", Ec.KINDS)
  local amk = {}
  for _, c in ipairs(Am.CATALOGUE) do amk[#amk + 1] = c.key end
  add("am-", amk)
  local amn = {}
  for _, k in ipairs(amk) do amn[#amn + 1] = "note-" .. k end
  add("am-", amn)
  add("amstate-", Am.STATES)
  local tk = { "autre", "prise", "libre" }
  for _, v in pairs(Lg.TASK_KEYS) do tk[#tk + 1] = v end -- valeurs a lister : l'ordre ne compte pas
  add("tache-", tk)
  local pc, pe, ps = {}, { "autre" }, { "inconnu" }
  for _, v in ipairs(Pn.CAUSES) do pc[#pc + 1] = v end
  for _, v in ipairs(Pn.STEP_KINDS) do pe[#pe + 1] = v end
  for _, v in ipairs(Pn.STATES) do ps[#ps + 1] = v end
  add("pnj-cause-", pc)
  add("pnj-rien-", { "matiere", "bloquees", "aucune" })
  add("pnj-zero-", { "aucun_libre", "servis", "stock", "combustible", "plein", "en_cours", "non_defendu", "menace", "palier", "aucune_fonderie", "autre" })
  add("pnj-etape-", pe)
  add("pnj-etat-", ps)
  add("lien-", require("shared.debug.liens").KINDS)
  add("lien-statut-", Lg.LINK_STATUS)
  add("lien-sens-", { "entree", "sortie" })
  local amc = { "inconnu" }
  for _, v in ipairs(Lg.AM_CAUSES) do amc[#amc + 1] = v end
  add("am-refus-", amc)
  add("am-bloc-", { "projet", "qg", "tourelles", "inconnu" })
  add("decision-", { "amelioration_refus" })
  local dk, ds, dw = { "inconnu" }, { "inconnu" }, {}
  for _, v in ipairs(Lg.DEF_KIND) do dk[#dk + 1] = v end
  for _, v in ipairs(Lg.DEF_SKIP) do ds[#ds + 1] = v end
  for _, v in ipairs(Lg.DEF_WHY) do dw[#dw + 1] = v end
  add("def-kind-", dk)
  add("def-skip-", ds)
  add("def-why-", dw)
  add("decision-", { "defense" })
  local sc, sr2 = { "inconnu" }, { "inconnu" }
  for _, v in ipairs(Lg.SRC_CHOIX) do sc[#sc + 1] = v end
  for _, v in ipairs(Lg.SRC_RAISON) do sr2[#sr2 + 1] = v end
  add("src-choix-", sc)
  add("src-raison-", sr2)
  add("decision-", { "source" })
  local pqv, pqc = { "inconnu" }, { "inconnu" }
  for _, v in ipairs(Am.PQ_VERDICTS) do pqv[#pqv + 1] = v end
  for _, v in ipairs(Am.PQ_CAUSES) do pqc[#pqc + 1] = v end
  add("pq-verdict-", pqv)
  add("pq-cause-", pqc)
  add("am-note-", { "bras_repartiteur-present", "charbon_tapis-present" })
  add("decision-", { "ordre_ouvert", "ordre_fini", "ordre_echec", "refus", "envoye", "refus_sans_raison", "repli", "module", "capital", "capital_courant" })
  add("ago-", { "s", "min", "h", "inconnu" })
  local fam_missing = {}
  for _, f in ipairs(fam) do
    for _, v in ipairs(f[2]) do
      if not fr[f[1] .. v] then fam_missing[#fam_missing + 1] = f[1] .. v end
    end
  end
  table.sort(fam_missing)
  check(#fam_missing == 0, "cles de familles absentes du .cfg : " .. table.concat(fam_missing, ", "))
end

section("7. mutants")
local MUTANTS = {
  { "zone: seuil 0.8 -> 0.5", "zone", { "Zn.OK_RATIO = 0.8", "Zn.OK_RATIO = 0.5" } },
  { "zone: construction non grise", "zone", { "if Zn.BUILD[st] then return { color = \"gris\"", "if false then return { color = \"gris\"" } },
  { "zone: fini sans mesure vert", "zone", { "return { color = \"gris\", cause = \"non_mesure\", n = 0, top = {} }", "return { color = \"vert\", cause = \"non_mesure\", n = 0, top = {} }" } },
  { "zone: ratio 0 non rouge", "zone", { "if ratio == 0 then return { color = \"rouge\"", "if ratio < 0 then return { color = \"rouge\"" } },
  { "zone: pieces manquantes ignorees", "zone", { "if c == \"pieces\" then n = n + num(lost) end", "" } },
  { "zone: bras sans courant comptes en cause", "zone", { "local top = ranked(m, z.lost)", "local mm = {} for k, v in pairs(m or {}) do mm[k] = v end mm.courant = num(mm.courant) + num(z.aux and z.aux.courant) local top = ranked(mm, z.lost)" } },
  { "zone: bras sans courant degradent", "zone", { "local degraded = num(z.lost) > 0", "local degraded = num(z.lost) + num(z.aux and z.aux.courant) > 0" } },
  { "zone: machines sans courant ignorees", "zone", { "local top = ranked(m, z.lost)", "local top = ranked(nil, z.lost)" } },
  { "zone: no_power hors courant", "zone", { "no_power = \"courant\", low_power", "no_power = \"autre\", low_power" } },
  { "zone: departage inverse", "zone", { "return ORDER[a.cause] < ORDER[b.cause]", "return ORDER[a.cause] > ORDER[b.cause]" } },
  { "zone: bloque non orange", "zone", { "if st == \"bloque\" then return { color = \"orange\"", "if st == \"bloque\" then return { color = \"gris\"" } },
  { "zone: statut inconnu = marche", "zone", { "return Zn.STATUS[name] or \"autre\"", "return Zn.STATUS[name] or Zn.RUN" } },
  { "zone: degrade ignore", "zone", { "if ratio >= Zn.OK_RATIO and not degraded then", "if ratio >= Zn.OK_RATIO then" } },
  { "ecart: lecture perimee comptee", "ecart", { "if a ~= nil and a <= stale then", "if a ~= nil then" } },
  { "ecart: sans date valable", "ecart", { "if not (type(read) == \"table\" and finite(read.tick) and finite(now)) then return nil end", "if not (type(read) == \"table\" and finite(now)) then return nil end" } },
  { "ecart: futur valable", "ecart", { "if read.tick > now then return nil end", "" } },
  { "ecart: croit_marche absent", "ecart", { "if verdict == \"marche\" and color ~= \"vert\" then", "if false then" } },
  { "ecart: croit_arret absent", "ecart", { "elseif verdict == \"arret\" and color == \"vert\" then", "elseif false then" } },
  { "ecart: jamais_lu vert alerte", "ecart", { "local sev = color == \"vert\" and \"info\" or \"alerte\"\n    return { kind = \"jamais_lu\"", "local sev = \"alerte\"\n    return { kind = \"jamais_lu\"" } },
  { "ecart: verdict inconnu = marche", "ecart", { "if not known then", "if false then" } },
  { "ecart: gris traite comme reel", "ecart", { "if color == \"gris\" then return", "if false then return" } },
  { "ecart: orange = alerte", "ecart", { "out.sev = color == \"rouge\" and \"alerte\" or \"attention\"", "out.sev = \"alerte\"" } },
  { "ecart: arret perime compte", "ecart", { "if r.verdict == \"arret\" and not any_stop then", "if r.verdict == \"arret\" and not any_stop and false then" } },
  { "ecart: tri sans severite", "ecart", { "if sa ~= sb then return sa < sb end", "" } },
  { "am: absente devenue prevue", "am", { "row.state = \"absente\"", "row.state = (facts[c.key] and facts[c.key].state) or \"aucune\"" } },
  { "am: absence declaree existante", "am", { "{ key = \"charbon_tapis\", exists = false", "{ key = \"charbon_tapis\", exists = true" } },
  { "am: etat inconnu accepte", "am", { "if type(f) == \"table\" and STATES[f.state] then", "if type(f) == \"table\" then" } },
  { "lg: age en s faux", "lg", { "local s = math.floor(ticks / 60)", "local s = math.floor(ticks / 30)" } },
  { "lg: age inconnu accepte", "lg", { "if type(ticks) ~= \"number\" or ticks ~= ticks or ticks < 0 then", "if type(ticks) ~= \"number\" then" } },
  { "lg: taches sans prise d'abord", "lg", { "if (a.taken and true or false) ~= (b.taken and true or false) then return a.taken and true or false end", "" } },
  { "lg: taches d'une autre zone", "lg", { "local hit = (zone.pid ~= nil and t.pid == zone.pid) or (zone.oid ~= nil and t.outpost == zone.oid)", "local hit = true" } },
  { "lg: kind/mode ignore", "lg", { "if mode ~= nil and Lg.TASK_KEYS", "if false and Lg.TASK_KEYS" } },
  { "lg: tache inconnue = kind brut", "lg", { "return Lg.TASK_KEYS[tostring(kind)] or \"autre\"", "return Lg.TASK_KEYS[tostring(kind)] or tostring(kind)" } },
  { "lg: X/N en marche absent", "lg", { "local mach = (type(z.n) == \"number\" and z.n > 0)", "local mach = (false)" } },
  { "am: present ignore", "am", { "local present = c.exists or (type(fact) == \"table\" and fact.present == true)", "local present = c.exists" } },
  { "am: fait sans present fait exister", "am", { "fact.present == true)", "fact.present ~= nil)" } },
  { "am: mot hors liste brut", "am", { "return (type(w) == \"string\" and known[w]) and w or \"inconnu\"", "return w" } },
  { "am: quais d'un autre projet", "am", { "key:sub(1, #prefix) == prefix and", "true and" } },
  { "am: refus avant travail", "am", { "local rank = { aucune = 0, refusee = 1, en_cours = 2 }", "local rank = { aucune = 0, refusee = 2, en_cours = 1 }" } },
  { "lg: mot de minage hors liste brut", "lg", { "local choix = (type(d.choix) == \"string\" and SRC_C[d.choix]) and d.choix or \"inconnu\"", "local choix = d.choix" } },
  { "lg: pourquoi libre brut", "lg", { "local why = (type(r.why) == \"string\" and DEF_W[r.why]) and r.why or nil", "local why = r.why" } },
  { "lg: cause d'amelioration libre brute", "lg", { "local cause = (type(r.cause) == \"string\" and AM_C[r.cause]) and r.cause or \"inconnu\"", "local cause = r.cause" } },
  { "pnj: avec tache non en marche", "pnj", { "return { cause = \"en_marche\", n = 0 }", "return { cause = \"autre\", n = 0 }" } },
  { "pnj: pret ignore", "pnj", { "if ready then return", "if false then return" } },
  { "pnj: matiere avant pauses", "pnj", { "if n_mat > 0 then", "if n_mat > 0 and false then" } },
  { "pnj: pas de tache libre", "pnj", { "if n == 0 then return", "if n < 0 then return" } },
  { "pnj: etapes depuis le debut", "pnj", { "for i = pc, #steps do", "for i = 1, #steps do" } },
  { "pnj: etape inconnue brute", "pnj", { "local kind = (type(s[1]) == \"string\" and STEP_OK[s[1]]) and s[1] or \"autre\"", "local kind = s[1]" } },
  { "pnj: suivantes sans tri de priorite", "pnj", { "return (num(a.prio) or 0) > (num(b.prio) or 0)", "return (num(a.prio) or 0) < (num(b.prio) or 0)" } },
  { "pnj: suivantes sans plafond", "pnj", { "if #out >= Pn.NEXT_MAX then break end", "" } },
  { "blocs: repartiteur sans etat", "blocs", { "if l.kind == \"piquage\" and (l.status == \"actif\" or l.status == \"inerte\" or l.status == \"coupe\") then", "if l.kind == \"piquage\" then" } },
  { "lg: objet sans texte riche", "lg", { "return \"[item=\" .. name .. \"]\"", "return \"item-name.\" .. name" } },
  { "lg: cause coupee", "lg", { "if #t > Lg.LINK_CAUSE_TEXT_MAX then", "if false then" } },
  { "lg: ligne active avec un etat", "lg", { "if s == \"actif\" or s == nil then return \"\" end", "if s == nil then return \"\" end" } },
  { "lg: cause oubliee", "lg", { "if cause == nil then return word end", "if true then return word end" } },
  { "lg: tampon de rapatriement non distingue", "lg", { "rap and \"fo-dbg-cerveau.lien-tampon-rap\" or", "false and \"fo-dbg-cerveau.lien-tampon-rap\" or" } },
  { "blocs: io sans plafond", "blocs", { "if #r.ins >= max then break end", "" } },
  { "lg: doublons gardes", "lg", { "if not seen[k] then", "if true then" } },
  { "lg: decisions anciennes d'abord", "lg", { "if ta ~= tb and ta ~= nil then return ta > tb end", "if ta ~= tb and ta ~= nil then return ta < tb end" } },
  { "lg: label affiche la cause du vert", "lg", { "local cause = (z.color ~= \"vert\" and z.cause)", "local cause = (z.cause)" } },
}
local killed = 0
local passes0 = passes
quiet = true
for _, m in ipairs(MUTANTS) do
  local mut = { [m[2]] = m[3] }
  local f0 = failures
  local ok = pcall(function()
    local Zn, Ec, Am, Lg, Pn, Bl = load_all(mut)
    run_all(Zn, Ec, Am, Lg, Pn, Bl)
  end)
  local died = (failures > f0) or not ok
  failures = f0 -- les échecs d'un mutant ne sont pas ceux du banc
  if died then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. m[1]) end
end
quiet = false
passes = passes0 + killed
failures = failures + (#MUTANTS - killed)
print(string.format("[DEBUG-CERVEAU] mutants : %d/%d refuses", killed, #MUTANTS))
print(string.format("[DEBUG-CERVEAU] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
