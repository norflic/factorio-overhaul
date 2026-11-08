--[[
  Lot TV-GARDES (V88) : table défaut -> signal -> levier, lue par la décision. Banc HORS JEU. Lancement, depuis la racine du mod :
  lua5.2 tests/defauts_test.lua
    A. la table : champs écrits, identifiants uniques, fichiers cités existants, aucun nom d'objet du jeu ;
    B. Df.mesures : une lecture manquante rend la mesure ABSENTE (jamais 0) ;
    C. Df.evaluer : sain, traité (au tableau et hors tableau), sans levier, non mesuré (refus écrit qui nomme la mesure) ; déterminisme ;
    D. journal : une ligne par CHANGEMENT d'état (jamais pour un premier état sain), plafond de lignes, état sauvegardable ;
    E. branchement : cerveau.lua appelle l'exécutant dans plan_b, la vue porte `unpowered` ;
    F. mutants du texte source (chacun doit faire échouer le banc).
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function slurp(p) local f = io.open(p, "rb"); if not f then return nil end local x = f:read("*a"); f:close(); return x end

local function load_text(path, mutate, name)
  local src = slurp(path)
  if mutate then
    local i, j = src:find(mutate[1], 1, true)
    assert(i, "texte introuvable : " .. mutate[1])
    src = src:sub(1, i - 1) .. mutate[2] .. src:sub(j + 1)
  end
  return assert(load(src, "@" .. path))()
end

-- Df : module de la table ; rt_mut : mutation facultative de l'exécutant (il charge toujours le Df passé)
local function run(Df, rt_mut)
  -- A. table
  local seen = {}
  for _, d in ipairs(Df.TABLE) do
    check(not seen[d.id], "A : identifiant en double " .. d.id); seen[d.id] = true
    check(type(d.defaut) == "string" and d.defaut ~= "" and type(d.mesure) == "string" and Df.OPS[d.op] and type(d.seuil) == "number"
      and type(d.levier) == "string" and type(d.ou) == "string" and d.ou ~= "", "A : ligne complete : " .. tostring(d.id))
    for path in d.ou:gmatch("([%w_/]+%.lua)") do
      check(slurp(path) ~= nil, "A : " .. d.id .. " cite un fichier absent : " .. path)
    end
    local text = (d.defaut .. d.levier .. d.ou):lower()
    for _, w in ipairs({ "iron", "copper", "plate", "stone", "gear", "circuit" }) do check(not text:find(w, 1, true), "A : nom d'objet en dur : " .. w) end
  end
  check(#Df.TABLE >= 6, "A : six defauts au moins (matiere, sortie pleine, combustible, courant, chemin, danger)")

  -- B. mesures
  local outs = { { stuck = 2, dry = 0, unpowered = 0, fails = 1, unsafe = true }, { stuck = 0, dry = 3, unpowered = 4 } }
  local m = Df.mesures(outs, { a = 5, b = 0, c = 2 })
  check(m.manques == 2 and m.sorties_pleines == 2 and m.a_sec == 1 and m.hors_courant == 4 and m.tournees_ratees == 1 and m.dangereux == 1,
    "B : mesures lues")
  local m2 = Df.mesures({ { stuck = 1, dry = 0 } }, nil)
  check(m2.manques == nil, "B : stock manquant : mesure absente, pas 0")
  check(m2.hors_courant == nil and m2.sorties_pleines == 1, "B : rangee sans unpowered : cette mesure est absente, les autres restent")
  local m3 = Df.mesures(nil, {})
  check(m3.manques == 0 and m3.sorties_pleines == nil and m3.a_sec == nil, "B : vue sans avant-postes : mesures d'avant-poste absentes ; stock vide : 0 manque")
  local m4 = Df.mesures({}, {})
  check(m4.sorties_pleines == 0 and m4.hors_courant == 0, "B : liste d'avant-postes vide mais PRESENTE : 0")
  check(Df.mesures({ { stuck = 0 / 0, dry = 0, unpowered = 0 } }, {}).sorties_pleines == nil, "B : NaN : mesure absente")

  -- C. evaluer
  local function by(rows) local o = {} for _, r in ipairs(rows) do o[r.id] = r end return o end
  local tasks = { { kind = "mine" }, { kind = "service" } }
  local r = by(Df.evaluer({ manques = 3, sorties_pleines = 2, a_sec = 1, hors_courant = 4, tournees_ratees = 0, dangereux = 2 }, tasks))
  check(r.matiere.etat == "traite" and r.matiere.agit == 1, "C : matiere traitee (une tache d'extraction au tableau)")
  check(r.sortie_pleine.etat == "traite" and r.combustible.etat == "traite", "C : sortie pleine et combustible traites (tache service)")
  check(r.courant.etat == "traite" and r.courant.agit == nil and r.courant.why:find("hors tableau", 1, true), "C : courant : levier hors tableau, dit")
  check(r.chemin.etat == "sain", "C : 0 tournee ratee : sain")
  check(r.danger.etat == "sans_levier" and r.danger.agit == 0 and r.danger.why:find("fortification", 1, true), "C : danger sans tache de fortification : SANS LEVIER, ecrit")
  local r2 = by(Df.evaluer({ manques = 3 }, {}))
  check(r2.matiere.etat == "sans_levier", "C : manque sans tache d'extraction : sans levier")
  check(r2.sortie_pleine.etat == "non_mesure" and r2.sortie_pleine.why == "signal non mesure : sorties_pleines", "C : mesure absente : non mesure, la raison nomme la mesure")
  check(by(Df.evaluer(nil, nil)).matiere.etat == "non_mesure", "C : aucune mesure : tout non mesure")
  check(by(Df.evaluer({ manques = -1 }, {})).matiere.etat == "non_mesure", "C : mesure negative : non mesure")
  local a, b = Df.evaluer({ manques = 1, a_sec = 2 }, tasks), Df.evaluer({ manques = 1, a_sec = 2 }, tasks)
  local same = #a == #b
  for i = 1, #a do same = same and a[i].etat == b[i].etat and a[i].id == b[i].id end
  check(same, "C : determinisme")
  local e, n = Df.etats(Df.evaluer({ manques = 3, sorties_pleines = 0, a_sec = 0, hors_courant = 0, tournees_ratees = 0, dangereux = 0 }, tasks))
  check(n == 1 and e.matiere == "traite" and e.danger == "sain", "C : etats : un defaut present")
  local line = Df.ligne("q", 12.5, r.danger)
  check(line:find("^%[FO%-DEFAUT%] q minute 12.5 : avant%-poste dangereux : signal present %(valeur 2%) %-> levier .* sans_levier"), "C : ligne [FO-DEFAUT] : " .. line)
  check(Df.ligne("q", 1, r2.sortie_pleine):find("garde fermee", 1, true) ~= nil, "C : ligne d'un signal non mesure : garde fermee")

  -- D. journal (l'exécutant, avec un journal simulé)
  local lines = {}
  _G.log = function(s) lines[#lines + 1] = s end
  package.loaded["shared.ai3.defauts"] = Df
  local Rt = load_text("script/ai3/defauts_rt.lua", rt_mut)
  local f = { key = "q" }
  local st = { short = { x = 2 } }
  local view = { outposts = { { stuck = 1, dry = 0, unpowered = 0, fails = 0 } } }
  local plan = { tasks = { { kind = "mine" } }, ia3 = {} }
  Rt.think(f, st, view, plan, 3600)
  local n1 = #lines
  check(plan.ia3.defauts and plan.ia3.defauts.matiere == "traite" and plan.ia3.defauts_n == 2, "D : plan.ia3.defauts pose (matiere traitee, sortie pleine sans levier)")
  check(st.defaut_etat.matiere == "traite" and type(st.defaut_etat.matiere) == "string", "D : etat sauvegardable (texte)")
  local healthy_first = 0
  for _, l in ipairs(lines) do if l:find("signal eteint", 1, true) then healthy_first = healthy_first + 1 end end
  check(healthy_first == 0, "D : aucun etat sain vu pour la premiere fois n'est journalise")
  Rt.think(f, st, view, plan, 3660)
  check(#lines == n1, "D : etat inchange : aucune ligne de plus")
  view.outposts[1].stuck = 0
  Rt.think(f, st, view, { tasks = {}, ia3 = {} }, 3720)
  check(#lines > n1 and lines[#lines]:find("signal eteint", 1, true), "D : un defaut qui guerit est journalise")
  st.defaut_logs = Rt.LOGS
  local before = #lines
  view.outposts[1].stuck = 5
  Rt.think(f, st, view, { tasks = {}, ia3 = {} }, 3780)
  check(#lines == before, "D : plafond de lignes atteint : plus de ligne")

  -- E. branchement
  local cerv = slurp("script/ai3/cerveau.lua") or ""
  check(cerv:find("Defauts.think(f, st, view, plan, tick)", 1, true) ~= nil, "E : plan_b appelle l'executant")
  check(cerv:find('require("script.ai3.defauts_rt")', 1, true) ~= nil, "E : cerveau.lua charge l'executant")
  check((slurp("script/team/team.lua") or ""):find("unpowered = st.unpowered", 1, true) ~= nil, "E : la vue des avant-postes porte unpowered")
end

local Df = load_text("shared/ai3/defauts.lua")
run(Df, nil)

-- F. mutants
local MUT = {
  { "mesure absente lue 0", "shared", 'local v = type(mesures) == "table" and mesures[d.mesure] or nil', 'local v = type(mesures) == "table" and mesures[d.mesure] or 0' },
  { "sans levier jamais dit", "shared", 'if row.agit > 0 then row.etat = "traite"', 'if row.agit >= 0 then row.etat = "traite"' },
  { "operateur inverse", "shared", '[">"] = function(a, b) return a > b end', '[">"] = function(a, b) return a < b end' },
  { "rangee sans stuck comptee 0", "shared", "if num(o.stuck) then sums.sorties_pleines = sums.sorties_pleines + o.stuck else ok.sorties_pleines = false end", "sums.sorties_pleines = sums.sorties_pleines + (o.stuck or 0)" },
  { "stock manquant lu 0", "shared", 'if type(short) == "table" then', "if true then short = short or {}" },
  { "hors tableau cherche au tableau", "shared", "elseif d.preuve_kinds == nil then", "elseif false then" },
  { "journal a chaque pensee", "rt", "if before ~= r.etat then", "if true then" },
  { "premier sain journalise", "rt", '(before ~= nil or r.etat ~= "sain") and', "true and" },
  { "plafond de lignes ignore", "rt", "(st.defaut_logs or 0) < Rt.LOGS", "true" },
  { "etat non pose dans le plan", "rt", "plan.ia3.defauts, plan.ia3.defauts_n = etats, n", "" },
}
local seen_mut = 0
for _, mu in ipairs(MUT) do
  local before, before_p = failures, passes
  local ok = pcall(function()
    quiet = true
    if mu[2] == "shared" then
      run(load_text("shared/ai3/defauts.lua", { mu[3], mu[4] }), nil)
    else
      run(Df, { mu[3], mu[4] })
    end
  end)
  quiet = false
  package.loaded["shared.ai3.defauts"] = Df
  local caught = (not ok) or failures > before
  failures, passes = before, before_p -- les ECHEC et OK d'un mutant ne sont pas ceux du banc
  check(caught, "F : le mutant « " .. mu[1] .. " » n'est PAS vu")
  if caught then seen_mut = seen_mut + 1 end
end

print(string.format("[DEFAUTS] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d vus", passes, failures, seen_mut, #MUT))
os.exit(failures == 0 and 0 or 1)
