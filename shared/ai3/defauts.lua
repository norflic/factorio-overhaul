--[[
  Lot TV-GARDES (TODO_VIDEO V88, « this Factory is able to address its own issues » : chaque panne produit un signal que la même boucle
  traite) : TABLE défaut -> signal -> levier, LUE par la boucle de décision des équipes (script/ai3/defauts_rt.lua, appelée une fois par
  pensée par Ia3.plan_b). PUR : aucune API Factorio, aucun nom d'objet du jeu (tests/iag_test.lua §8 bis). Déterministe : la table est une
  LISTE ordonnée, aucun pairs, aucun temps mesuré.

  Une ligne de table dit, en donnée :
    id, defaut      le défaut, en français ;
    mesure          la mesure (clé de `mesures`) qui le PROUVE : un nombre >= 0 ; absente = « signal non mesuré », refus écrit (W04), jamais 0 ;
    op, seuil       le défaut est PRÉSENT quand mesure op seuil ;
    levier          le nom de la règle qui agit ; ou = où elle agit (fichier:ligne à la date du lot, 0.6.64) ;
    preuve_kinds    sortes de tâches du tableau (plan.tasks) qui montrent le levier à l'œuvre ; nil = le levier agit hors du tableau
                    (passe périodique, porte), la ligne le dit au lieu de prétendre le mesurer.

  Df.evaluer(mesures, tasks) rend une ligne par défaut, dans l'ordre de la table :
    { id, defaut, levier, ou, valeur, etat, agit, why }  etat : "sain" | "traite" | "sans_levier" | "non_mesure".
    traite       défaut présent et le levier est visible au tableau (agit > 0), ou agit hors du tableau (agit = nil) ;
    sans_levier  défaut présent et AUCUNE tâche du levier au tableau : la boucle le dit ([FO-DEFAUT]), elle ne l'oublie pas ;
    non_mesure   la mesure manque : garde fermée, la raison nomme la mesure.
  Df.mesures(outposts, short) construit les mesures depuis la vue de l'équipe (view.outposts, st.short) : une rangée sans le champ lu rend la
  mesure absente (nil), jamais 0. Exception écrite : `fails` (compteur créé au premier échec d'une tournée, script/team/board.lua:984).
  Df.ligne(who, minute, row) : la ligne du journal [FO-DEFAUT].
]]

local Df = {}

Df.OPS = {
  [">"] = function(a, b) return a > b end,
  [">="] = function(a, b) return a >= b end,
}

--- La table. Les « ou » sont des lignes du code de 0.6.64 : tests/defauts_test.lua vérifie que chaque fichier existe.
Df.TABLE = {
  { id = "matiere", defaut = "manque de matiere", mesure = "manques", op = ">", seuil = 0,
    levier = "extraction", ou = "shared/ai3/cerveau.lua:364-370 (st.short) -> shared/team/planner.lua:915 (tache mine), :645 (extend)",
    preuve_kinds = { "mine", "extend" } },
  { id = "sortie_pleine", defaut = "sortie pleine (le four ne fond plus)", mesure = "sorties_pleines", op = ">", seuil = 0,
    levier = "tournee de service", ou = "shared/team/flux.lua:131-157 (priorite des tournees) -> shared/team/planner.lua:618 (tache service)",
    preuve_kinds = { "service" } },
  { id = "combustible", defaut = "pas de combustible", mesure = "a_sec", op = ">", seuil = 0,
    levier = "ravitaillement", ou = "shared/team/planner.lua:693 (tache refill) ; shared/team/flux.lua:153 (AGE_CAP_DRY)",
    preuve_kinds = { "refill", "service" } },
  { id = "courant", defaut = "pas de courant", mesure = "hors_courant", op = ">", seuil = 0,
    levier = "remplacement electrique", ou = "script/team/foreuse_swap.lua:1070-1085 (Swap.repli, passe periodique)",
    preuve_kinds = nil },
  { id = "chemin", defaut = "chemin rate", mesure = "tournees_ratees", op = ">", seuil = 0,
    levier = "delai de reprise", ou = "script/team/bail.lua:101 (Bl.count) ; script/team/board.lua:984 (flux_fails)",
    preuve_kinds = nil },
  { id = "danger", defaut = "avant-poste dangereux", mesure = "dangereux", op = ">", seuil = 0,
    levier = "fortification et porte du danger", ou = "shared/team/planner.lua:754 (tache fortify) ; shared/ai3/danger.lua:452 (D.gate)",
    preuve_kinds = { "fortify", "garrison" } },
}

local function num(v) return type(v) == "number" and v == v and v >= 0 and v ~= math.huge end

--- Mesures depuis la vue. outposts = view.outposts (liste de rangées) ; short = st.short ({ [matiere] = manque }). Rend { [mesure] = nombre }
--- avec une clé absente quand la lecture manque (liste absente, ou une rangée sans le champ).
function Df.mesures(outposts, short)
  local m = {}
  if type(short) == "table" then
    local n = 0
    local ks = {}
    for k in pairs(short) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, k in ipairs(ks) do
      local v = short[k]
      if num(v) and v > 0 then n = n + 1 end
    end
    m.manques = n
  end
  if type(outposts) == "table" then
    local sums = { sorties_pleines = 0, a_sec = 0, hors_courant = 0, tournees_ratees = 0, dangereux = 0 }
    local ok = { sorties_pleines = true, a_sec = true, hors_courant = true, tournees_ratees = true, dangereux = true }
    for _, o in ipairs(outposts) do
      if type(o) ~= "table" then
        for k in pairs(ok) do ok[k] = false end
      else
        if num(o.stuck) then sums.sorties_pleines = sums.sorties_pleines + o.stuck else ok.sorties_pleines = false end
        if num(o.dry) then sums.a_sec = sums.a_sec + (o.dry > 0 and 1 or 0) else ok.a_sec = false end
        if num(o.unpowered) then sums.hors_courant = sums.hors_courant + o.unpowered else ok.hors_courant = false end
        sums.tournees_ratees = sums.tournees_ratees + (num(o.fails) and o.fails or 0) -- compteur créé au premier échec : absent = aucun échec
        if o.unsafe ~= nil or o.lethal ~= nil then
          sums.dangereux = sums.dangereux + ((o.unsafe or o.lethal) and 1 or 0)
        else
          sums.dangereux = sums.dangereux + 0 -- `unsafe` n'est cherché que si une tournée est en jeu (team.lua) : nil = pas cherché = pas de danger lu
        end
      end
    end
    for _, k in ipairs({ "sorties_pleines", "a_sec", "hors_courant", "tournees_ratees", "dangereux" }) do
      if ok[k] then m[k] = sums[k] end
    end
  end
  return m
end

local function count_kinds(tasks, kinds)
  local n = 0
  for _, t in ipairs(tasks or {}) do
    for _, k in ipairs(kinds) do
      if t.kind == k then n = n + 1; break end
    end
  end
  return n
end

--- Évalue la table. mesures = Df.mesures(...) ; tasks = plan.tasks (liste). Rend la liste des lignes (une par défaut, ordre de la table).
function Df.evaluer(mesures, tasks)
  local out = {}
  for _, d in ipairs(Df.TABLE) do
    local row = { id = d.id, defaut = d.defaut, levier = d.levier, ou = d.ou }
    local v = type(mesures) == "table" and mesures[d.mesure] or nil
    local cmp = Df.OPS[d.op]
    if not num(v) or not cmp then
      row.etat, row.why = "non_mesure", "signal non mesure : " .. d.mesure
    else
      row.valeur = v
      if not cmp(v, d.seuil) then
        row.etat = "sain"
      elseif d.preuve_kinds == nil then
        row.etat, row.why = "traite", "levier hors tableau : " .. d.levier
      else
        row.agit = count_kinds(tasks, d.preuve_kinds)
        if row.agit > 0 then row.etat = "traite" else row.etat, row.why = "sans_levier", "aucune tache de " .. d.levier .. " au tableau" end
      end
    end
    out[#out + 1] = row
  end
  return out
end

--- Résumé d'une évaluation pour le plan : { [id] = etat } et le compte des défauts présents. Les valeurs sont des textes et des nombres
--- (vit dans la sauvegarde de l'équipe, st.defauts).
function Df.etats(rows)
  local e, n = {}, 0
  for _, r in ipairs(rows) do
    e[r.id] = r.etat
    if r.etat == "traite" or r.etat == "sans_levier" then n = n + 1 end
  end
  return e, n
end

--- Ligne du journal [FO-DEFAUT] : défaut, signal (mesure et valeur), levier, ce qui le prouve.
function Df.ligne(who, minute, row)
  if row.etat == "non_mesure" then
    return string.format("[FO-DEFAUT] %s minute %.1f : %s : %s (garde fermee : rien n'est declare sain)", tostring(who), minute, row.defaut, row.why)
  end
  local preuve = row.agit ~= nil and string.format("%d tache(s) au tableau", row.agit) or (row.why or "")
  return string.format("[FO-DEFAUT] %s minute %.1f : %s : signal %s (valeur %s) -> levier %s : %s ; %s", tostring(who), minute, row.defaut,
    row.etat == "sain" and "eteint" or "present", tostring(row.valeur), row.levier, row.etat == "sain" and "sans objet" or row.etat, preuve)
end

return Df
