--[[
  Lot s42 causal (chantier 3.2 du DC) : arbre des causes d'une pénurie. Banc HORS JEU : lua5.2 tests/s42_causal_test.lua
    A. cas RÉELS du journal de la partie du DC (0.7.96, 4 h 15 : lignes [FO-CHAMP-ETAT], [FO-ENERGIE], [FO-RESEAU]) ;
    B. chaque branche de l'arbre, les égalités, le relevé vide, le déterminisme ;
    C. table des ordres et ligne du journal ; aucun nom d'objet du jeu dans la règle ;
    D. câblage (moteur simulé) : relevé par statut d'entité, ordre écrit, horloge du levier avancée, journal au CHANGEMENT de cause seulement ;
    E. branchement dans le texte source (audit des champs).
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function slurp(p) local f = io.open(p, "rb"); if not f then return nil end local x = f:read("*a"); f:close(); return x end

local Ca = require("shared.ai3.causal")
local function is(v, sym, cause, ordre, msg)
  check(v.symptome == sym and v.cause == cause and v.ordre == ordre,
    string.format("%s : attendu %s <- %s -> %s, obtenu %s <- %s -> %s", msg, sym, cause, ordre, tostring(v.symptome), tostring(v.cause), tostring(v.ordre)))
end

-- A. cas réels -----------------------------------------------------------------------------------------------------------------------
-- azure, 216 min : « foreuses 131 (marche 0, figees 18, sans courant 113) | fours 93 (marche 0, sans entree 88, sans combustible 0, sortie
-- pleine 5) » ; [FO-ENERGIE] 215.2 min « production 0 kW, capacite 14400 kW » ; [FO-RESEAU] 218.7 min « sources 1/1 a sec 1 ».
-- Le stock de charbon d'azure à 216 min n'est PAS au journal : les deux hypothèses sont jouées (vide, puis 400).
local azure = {
  plaques = { manque = true },
  foreuses = { n = 131, marche = 0, sortie_pleine = 18, sans_courant = 113 },
  fours = { n = 93, marche = 0, sans_entree = 88, sans_combustible = 0, sortie_pleine = 5 },
  courant = { generatrices = 8, kw = 0, chaudieres = 4, a_sec = 4, saturee = false },
  combustible = { libre = 0 }, pertes = { tapis = 0 },
}
local v = Ca.diagnostiquer(azure)
is(v, "manque_plaques", "centrale_sans_combustible", "extraire_combustible", "A1 azure 216 min, stock vide")
check(#v.chaine == 4 and v.chaine[1]:find("fours:sans_entree 88/93", 1, true) and v.chaine[2]:find("foreuses:sans_courant 113/131", 1, true)
  and v.chaine[3]:find("chaudieres a sec 4/4", 1, true), "A1 chaine remontee four -> foreuse -> courant -> combustible : " .. table.concat(v.chaine, " | "))
azure.combustible.libre = 400
is(Ca.diagnostiquer(azure), "manque_plaques", "chaudieres_a_sec", "amorcer_centrale", "A1 bis azure, charbon au stock")
-- player, 104 min : « foreuses 66 (marche 49, figees 17, sans courant 0) | fours 12 (marche 2, sans entree 0, sans combustible 10, sortie
-- pleine 0) | coffres de combustible 2 (charbon min 0) », « manque coal 97 »
local player = {
  plaques = { manque = true },
  foreuses = { n = 66, marche = 49, sortie_pleine = 17 },
  fours = { n = 12, marche = 2, sans_combustible = 10 },
  courant = { generatrices = 6, kw = 3056, chaudieres = 3, a_sec = 0 }, combustible = { libre = 0 },
}
is(Ca.diagnostiquer(player), "manque_plaques", "combustible_epuise", "extraire_combustible", "A2 player 104 min, stock vide")
player.combustible.libre = 150
is(Ca.diagnostiquer(player), "manque_plaques", "four_sans_combustible", "ravitailler", "A2 bis player 104 min, charbon au stock")
-- emerald, 231 min : « foreuses 11 (marche 0, figees 11, sans courant 0) | fours 58 (marche 0, sans entree 58, ...) », pieces manquantes
-- [champ-tapis 56]
local emerald = { plaques = { manque = true }, foreuses = { n = 11, marche = 0, sortie_pleine = 11 }, fours = { n = 58, marche = 0, sans_entree = 58 },
  pertes = { tapis = 56 } }
is(Ca.diagnostiquer(emerald), "manque_plaques", "ligne_coupee", "reconstruire", "A3 emerald 231 min")
-- amber, 222 min : « foreuses 0 | fours 69 (marche 47, sans entree 22) » : plus du quart a l'arret, aucune foreuse dans les bandes
local amber = { plaques = { manque = false }, foreuses = { n = 0 }, fours = { n = 69, marche = 47, sans_entree = 22 } }
is(Ca.diagnostiquer(amber), "machines_arret", "aucune_foreuse", "etendre", "A4 amber 222 min (22/69 a l'arret)")
amber.fours.marche, amber.fours.sans_entree = 60, 9
is(Ca.diagnostiquer(amber), "sain", "aucune", "aucun", "A4 bis moins du quart a l'arret")

-- B. branches ------------------------------------------------------------------------------------------------------------------------
local function R(t) t.plaques = t.plaques or { manque = true }; return t end
is(Ca.diagnostiquer(nil), "sain", "aucune", "aucun", "B1 releve absent")
is(Ca.diagnostiquer({}), "sain", "aucune", "aucun", "B1 releve vide")
is(Ca.diagnostiquer(R({})), "manque_plaques", "aucune_foreuse", "etendre", "B2 manque sans machine")
is(Ca.diagnostiquer(R({ fours = { n = 4, marche = 0, sortie_pleine = 4 }, foreuses = { n = 4, marche = 4 } })), "manque_plaques", "sortie_pleine", "collecter", "B3 fours sortie pleine")
is(Ca.diagnostiquer(R({ fours = { n = 4, marche = 0, sans_courant = 4 }, courant = { generatrices = 0 } })), "manque_plaques", "pas_de_centrale", "agrandir_centrale", "B4 pas de centrale")
is(Ca.diagnostiquer(R({ foreuses = { n = 9, marche = 0, sans_courant = 9 }, courant = { generatrices = 2, kw = 1800, chaudieres = 1, a_sec = 0, saturee = true } })),
  "manque_plaques", "centrale_saturee", "agrandir_centrale", "B5 centrale saturee")
is(Ca.diagnostiquer(R({ foreuses = { n = 9, marche = 0, sans_courant = 9 }, courant = { generatrices = 2, kw = 1800, chaudieres = 1, a_sec = 0 } })),
  "manque_plaques", "hors_reseau", "raccorder", "B6 hors reseau")
is(Ca.diagnostiquer(R({ foreuses = { n = 9, marche = 0, sans_courant = 9 }, courant = { generatrices = 4, kw = 900, chaudieres = 2, a_sec = 1 } })),
  "manque_plaques", "hors_reseau", "raccorder", "B7 une chaudiere a sec sur deux, la centrale produit : pas la racine")
is(Ca.diagnostiquer(R({ foreuses = { n = 9, marche = 0, sans_courant = 9 }, courant = { generatrices = 4, chaudieres = 2, a_sec = 1 } })),
  "manque_plaques", "hors_reseau", "raccorder", "B7 bis kW non mesure : une chaudiere a sec sur deux ne suffit pas")
is(Ca.diagnostiquer(R({ foreuses = { n = 9, marche = 0, sans_courant = 9 }, courant = { generatrices = 4, chaudieres = 2, a_sec = 2 } })),
  "manque_plaques", "chaudieres_a_sec", "amorcer_centrale", "B8 toutes a sec, stock non mesure : amorce")
is(Ca.diagnostiquer(R({ foreuses = { n = 6, marche = 1, sans_combustible = 5 }, combustible = { libre = 30 } })), "manque_plaques", "foreuse_sans_combustible", "ravitailler", "B9 foreuses a sec")
is(Ca.diagnostiquer(R({ foreuses = { n = 6, marche = 1, sans_combustible = 5 }, combustible = { libre = 0 } })), "manque_plaques", "combustible_epuise", "extraire_combustible", "B9 bis")
is(Ca.diagnostiquer(R({ foreuses = { n = 6, marche = 1, epuisees = 5 } })), "manque_plaques", "gisement_epuise", "etendre", "B10 gisement epuise")
is(Ca.diagnostiquer(R({ foreuses = { n = 6, marche = 0, sortie_pleine = 6 } })), "manque_plaques", "sortie_pleine", "collecter", "B11 foreuses pleines sans four")
is(Ca.diagnostiquer(R({ foreuses = { n = 6, marche = 6 }, fours = { n = 6, marche = 6 } })), "manque_plaques", "debit_insuffisant", "etendre", "B12 tout tourne")
is(Ca.diagnostiquer(R({ foreuses = { n = 6, marche = 6 }, fours = { n = 6, marche = 0, sans_entree = 6 }, pertes = { tapis = 3 } })), "manque_plaques", "ligne_coupee", "reconstruire", "B13 tapis perdus")
-- égalité : le courant passe devant le combustible (ordre de Ca.ETATS_*)
is(Ca.diagnostiquer(R({ fours = { n = 8, marche = 0, sans_courant = 4, sans_combustible = 4 }, courant = { generatrices = 0 } })), "manque_plaques", "pas_de_centrale", "agrandir_centrale", "B14 egalite")
-- nombres invalides : comptés 0
is(Ca.diagnostiquer(R({ foreuses = { n = 0 / 0, marche = -3 }, fours = { n = "x" } })), "manque_plaques", "aucune_foreuse", "etendre", "B15 nombres invalides")
-- déterminisme : deux appels, même verdict et même chaîne
local a, b2 = Ca.diagnostiquer(azure), Ca.diagnostiquer(azure)
check(a.cle == b2.cle and table.concat(a.chaine, "|") == table.concat(b2.chaine, "|"), "B16 determinisme")

-- C. table et journal ---------------------------------------------------------------------------------------------------------------
do
  local seen = {}
  for _, o in ipairs(Ca.ORDRES) do
    check(type(o.id) == "string" and not seen[o.id] and type(o.levier) == "string" and Ca.TEXTE[o.id], "C1 ordre " .. tostring(o.id))
    seen[o.id] = true
  end
  for _, r in ipairs({ azure, player, emerald, amber, {}, R({}) }) do
    local x = Ca.diagnostiquer(r)
    check(Ca.ordre(x.ordre) and Ca.TEXTE[x.cause] and Ca.TEXTE[x.symptome], "C2 verdict hors table : " .. x.cle)
  end
  azure.combustible.libre = 0
  local line = Ca.ligne("azure", 216.2, Ca.diagnostiquer(azure), "levier : x")
  check(line:find("[FO-CAUSAL] azure min 216 | manque de plaques <- panne de courant : chaudieres a sec et stock de combustible vide -> extraire du combustible | chaine : ", 1, true) == 1,
    "C3 ligne : " .. line)
  check(line:find(" | levier : x", 1, true), "C3 effet")
  local src = slurp("shared/ai3/causal.lua")
  local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  local sans_ipairs = code:gsub("ipairs%(", "")
  for _, w in ipairs({ "game%.", "defines", "script%.", "global", "pairs%(" }) do
    check(not sans_ipairs:find(w), "C4 regle pure : " .. w)
  end
  for _, w in ipairs({ "coal", "iron", "copper", "boiler", "furnace", "drill", "belt", "steam" }) do
    check(not code:find(w, 1, true), "C5 nom d'objet du jeu dans la regle : " .. w)
  end
end

-- D. câblage, moteur simulé -----------------------------------------------------------------------------------------------------------
do
  local logs = {}
  _G.log = function(s) logs[#logs + 1] = s end
  _G.defines = { entity_status = { working = 1, no_power = 2, low_power = 3, no_fuel = 4, no_minable_resources = 5,
    waiting_for_space_in_destination = 6, full_output = 7, no_ingredients = 8 } }
  local starved, stock = true, 0
  package.loaded["script.team.stock"] = { count = function() return stock end }
  package.loaded["script.team.famine_fer"] = { team_starved = function() return starved end }
  package.loaded["script.faction.state"] = { sorted_keys = function(t) local k = {} for x in pairs(t) do k[#k + 1] = x end table.sort(k) return k end }
  package.loaded["shared.team.modules"] = { spec = function(n) if n == "ch" then return { water = true, burner_kw = 1800 } elseif n == "ge" then return { power_out = 900 } end return {} end }
  local Rt = require("script.ai3.causal_rt")
  local world = { ["ch"] = { valid = true, status = 4, force = { name = "azure" } }, ["ge"] = { valid = true, status = 1, energy_generated_last_tick = 0, force = { name = "azure" } } }
  local surface = { find_entity = function(name) return world[name] end }
  local function ent(s, ty) return { valid = true, status = s, type = ty } end
  local f = { key = "azure", force = "azure", hq = { valid = true },
    outposts = { [2] = { drill_list = { ent(2), ent(2), { valid = false } }, sinks = { ent(8, "furnace"), ent(1, "container") } }, [1] = { drill_list = { ent(2) } } },
    smelters = { ent(8, "furnace") },
    build = { plant = 1, projects = { [1] = { state = "fini", ents = { { name = "ch", x = 0, y = 0 }, { name = "ge", x = 1, y = 0 }, { name = "autre", x = 2, y = 0 } } } },
      grow = { next = 5000, saturated = false }, raccord = { next = 9000 }, sante = { net_next = 9000 }, sweep = { next = 9000 } } }
  local rd = { d = { n = 10, run = 0, stuck = 1, nopow = 9 }, fu = { n = 5, run = 0, noin = 5, nofuel = 0, full = 0 }, lost = { ["champ-tapis"] = 2, ["champ-bras"] = 7 } }
  local r = Rt.releve(f, surface, 3600, rd)
  check(r.foreuses.n == 13 and r.foreuses.sans_courant == 12 and r.foreuses.sortie_pleine == 1, "D1 foreuses : bandes + avant-postes, entite invalide ignoree")
  check(r.fours.n == 7 and r.fours.sans_entree == 7, "D1 fours : bandes + avant-postes (type four seulement) + equipe")
  check(r.courant.chaudieres == 1 and r.courant.a_sec == 1 and r.courant.generatrices == 1 and r.courant.kw == 0, "D1 courant lu par statut")
  check(r.pertes.tapis == 2 and r.combustible.libre == 0 and r.plaques.manque == true, "D1 pertes, stock, manque")
  local v1 = Rt.audit(f, surface, 3600, rd)
  is(v1, "manque_plaques", "centrale_sans_combustible", "extraire_combustible", "D2 audit")
  check(#logs == 1 and logs[1]:find("[FO-CAUSAL] azure min 1 | ", 1, true) == 1, "D2 une ligne : " .. tostring(logs[1]))
  check(f.build.causal.cause == "centrale_sans_combustible" and f.build.causal.ordre == "extraire_combustible" and f.build.causal.since == 3600, "D2 ordre ecrit")
  check(f.build.grow.next == 5000, "D2 levier sans horloge : rien d'avance")
  Rt.audit(f, surface, 3600 + 18000, rd)
  check(#logs == 1 and f.build.causal.since == 3600, "D3 meme cause : aucune ligne, date gardee")
  stock = 300
  Rt.audit(f, surface, 4000, rd)
  check(#logs == 2 and logs[2]:find("amorcer la centrale", 1, true) and logs[2]:find("horloge avancee : grow.next", 1, true), "D4 cause changee : ligne et reveil : " .. tostring(logs[2]))
  check(f.build.grow.next == 4000 and f.build.raccord.next == 9000, "D4 seule l'horloge du levier est avancee")
  world.ch.status, world.ge.energy_generated_last_tick = 1, 15000
  Rt.audit(f, surface, 4100, rd)
  check(#logs == 3 and logs[3]:find("raccorder au reseau", 1, true) and f.build.raccord.next == 4100 and f.build.sante.net_next == 4100 and f.build.sweep.next == 9000, "D5 hors reseau : raccord reveille")
  -- retour au sain : une ligne (le changement), puis plus rien
  starved = false
  local sain = { d = { n = 10, run = 10 }, fu = { n = 5, run = 5 }, lost = {} }
  f.outposts, f.smelters = {}, {}
  Rt.audit(f, surface, 4200, sain)
  Rt.audit(f, surface, 4300, sain)
  check(#logs == 4 and logs[4]:find("rien a signaler", 1, true), "D6 retour au sain dit une fois")
  -- premier état sain : silence ; état sauvegardable (ni fonction ni entité)
  local g = { key = "amber", force = "amber", build = { projects = {} } }
  Rt.audit(g, surface, 100, sain)
  check(#logs == 4, "D7 premier etat sain : silence")
  local okv = true
  for _, x in pairs(f.build.causal) do if type(x) ~= "string" and type(x) ~= "number" then okv = false end end
  check(okv, "D8 etat fait de textes et de nombres")
  check(Rt.audit({ key = "x" }, surface, 1, nil) == nil, "D9 sans plan directeur : rien")
  -- plafond du journal
  f.build.causal.logs = Rt.LOGS
  starved = true
  Rt.audit(f, surface, 4400, rd)
  check(#logs == 4, "D10 plafond de lignes")
  for _, k in ipairs({ "amorcer_centrale", "agrandir_centrale", "raccorder", "reconstruire" }) do check(Rt.LEVIERS[k] and Ca.ordre(k), "D11 levier " .. k) end
end

-- E. branchement ----------------------------------------------------------------------------------------------------------------------
do
  local mig = slurp("script/team/migration_champ.lua")
  check(mig:find('local CausalRt = require("script.ai3.causal_rt")', 1, true), "E1 require au chargement")
  check(mig:find("local rd = Champ.report(f, surface, tick)", 1, true) and mig:find("CausalRt.audit(f, surface, tick, rd)", 1, true), "E2 audit apres le releve des champs")
  local ch = slurp("script/team/champ.lua")
  check(ch:find("if #ids == 0 then return rd end", 1, true) and ch:find("local rd = { d = d, fu = fu, lost = lost_all }", 1, true), "E3 Champ.report rend ses comptes")
  local rt = slurp("script/ai3/causal_rt.lua")
  local rt_code = rt:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", ""):gsub("ipairs%(", "")
  check(not rt_code:find("global", 1, true) and not rt_code:find("pairs%("), "E4 ni global ni pairs dans le cablage")
end

print(string.format("s42_causal_test : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
