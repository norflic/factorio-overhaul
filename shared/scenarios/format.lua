--[[
  SCÉNARIOS EN BOUCLE FERMÉE (sprint s43, pilier A) : FORMAT DÉCLARATIF ET ÉVALUATION PURE (Lua pur, testable hors jeu :
  tests/s43_scen-moteur_test.lua).

  Une boucle = (1) une THÉORIE écrite AVANT le test (ce que le cerveau doit faire), (2) une MISE EN SCÈNE appliquée pendant
  une partie de banc, (3) un VERDICT par prédicat, écrit dans le journal, (4) un bilan (tools/autotest/scenarios_loop.py).

  ── Où sont les fichiers ───────────────────────────────────────────────────────────────────────────────────────────────
    shared/scenarios/<id>.lua                       la déclaration (une table Lua, AUCUN require, aucune fonction) ;
    shared/scenarios/format.lua                     ce fichier : validation, relevés dérivés, évaluation, lignes du journal ;
    tools/autotest/fo-autotest/scenarios/scen_moteur.lua   le câblage en jeu (mod de test) : applique la mise en scène,
                                                    prend les relevés, écrit les lignes [FO-SCEN] ;
    tools/autotest/fo-autotest/scenarios/scen-<id avec tirets>.lua   le greffon à une ligne que le banc choisit par son nom :
                                                    return require("scenarios/scen_moteur")("<id>")
    tools/autotest/scenarios_loop.py                le lanceur : joue une liste de scénarios par banc.py, un ticket à la fois,
                                                    évalue les prédicats « ligne » sur le journal, écrit le bilan.
  Ajouter un scénario = écrire shared/scenarios/<id>.lua + le greffon d'une ligne ; rien d'autre.

  ── La déclaration ─────────────────────────────────────────────────────────────────────────────────────────────────────
    return {
      nom = "famine-fer-attaque",          -- nom du scénario au banc (le greffon s'appelle scen-<nom>.lua)
      description = { fr = "...", en = "..." },
      base = "partie",                     -- scénario intégré du banc qui fonde la partie (control.lua, SCENARIOS) :
                                           -- "partie" = la guerre à 4 factions avec l'effectif du réglage (défaut)
      duree_min = 35,                      -- durée de jeu ; ticks du banc = F.ticks(scen) (duree_min * 3600 + 600)
      equipes = "toutes",                  -- équipes mises en scène et jugées : "toutes" (rows de fo-ia1 « teams »,
                                           -- triées par clé) ou une liste de clés { "scarlet", "player" }
      rayon_qg = 80,                       -- tuiles autour du QG pour les coffres, tourelles, ennemis et destructions
      suivre = { "iron-plate" },           -- objets dont on relève le stock (QG + coffres de la force dans rayon_qg) et le
                                           -- débit produit (statistiques de production de la force) chaque minute
      mise_en_scene = { <action>, ... },   -- voir plus bas ; appliquées au tick minute * 3600, dans l'ordre de la liste
      theorie = { <attendu>, ... },        -- voir plus bas ; chaque attendu est jugé à SA minute, par équipe
    }

  ── Actions de mise en scène (champ `action`, plus `minute`) ──────────────────────────────────────────────────────────
    vider_coffres  objets = {..}, quantite = n|nil    retire les objets du QG et des coffres (container, logistic-container)
                                                      de la force dans rayon_qg ; quantite nil = tout ;
    attaque        unites = { {nom, n}, .. }, distance = d, rayon = r|16
                                                      fait apparaître n unités ennemies (force enemy) à d tuiles du QG
                                                      (angle fixé par le rang de l'équipe), groupe d'unités, ordre
                                                      attack_area sur le QG (rayon r) ;
    poser          entite = nom, dx, dy, n = 1, force = "equipe"|"enemy"|"neutral"
                                                      pose n entités autour de QG + (dx, dy) (position libre la plus proche) ;
    detruire       type = t | nom = n, part = 0..1 | n = k
                                                      détruit les entités de la force (type ou nom), dans rayon_qg, triées
                                                      par position (x puis y) : les k premières ou la part arrondie au-dessus.
    assecher_centrale  rayon = r|6, tapis_coupes = k|2   (s43 scen-energie) BLACKOUT : sur toute la surface, pour chaque
                                                      chaudière de la force : combustible retiré (inventaire, flamme), et dans
                                                      `rayon` tuiles : coffres, mains des bras et tapis (rayon 2 r) vidés de
                                                      tout combustible (objet dont le prototype a une valeur de combustion) ;
                                                      les k tapis porteurs de combustible les plus proches d'une chaudière sont
                                                      détruits (tapis coupé). Le stock du QG n'est pas touché.
  Les noms d'objets et d'unités vivent dans la déclaration du scénario (jamais dans shared/ai3 ni script/ai3) ; un nom qui
  n'existe pas dans les prototypes chargés donne une ligne « [FO-SCEN] <nom> min <m> | mise en scene ... : ECHEC ».

  ── Relevé d'état (une ligne par équipe et par minute, de 1 à duree_min) ───────────────────────────────────────────────
    champs :  stock:<objet>   prod:<objet> (cumul produit par la force)   debit:<objet> (production de la minute écoulée,
              objets/min, dérivé par F.deriver ; nil à la première minute relevée)
              tourelles  tourelles_vides  (ammo-turret de la force dans rayon_qg, inventaire de munitions vide)
              pnj  pnj_inactifs  (fo-ia1 « teams » : n et last.idle)   avant_postes  pnj_perdus  (outposts, lost)
              ennemis_proches  (unités de la force enemy dans rayon_qg)   qg_vie  (santé du QG, 0..1 ; 0 = détruit)
              elec_sat  (s43 : Σ énergie / Σ tampon des consommateurs électriques de la force, 0..1 ; nil sans consommateur)
              elec_kw  (kW des machines à vapeur et générateurs)   chaudieres  chaudieres_a_sec  (ni combustible ni flamme)
    journal : [FO-SCEN] <nom> releve min <m> <equipe> | champ=valeur champ=valeur ...   (marque aussi les minutes pour le
              lanceur, qui découpe le journal entre deux relevés pour les prédicats « ligne »)

  ── Attendus (la THÉORIE) ──────────────────────────────────────────────────────────────────────────────────────────────
    { id = "fer-revenu", texte = { fr = "...", en = "..." }, predicat = <prédicat> }
    Prédicats (minutes entières, bornes comprises) :
      { type = "seuil",   champ = c, minute = m, op = o, valeur = v }          la valeur du champ à la minute m ;
      { type = "agregat", champ = c, de = a, a = b, fn = "max"|"min"|"moyenne"|"somme", op = o, valeur = v } ;
      { type = "atteint", champ = c, de = a, a = b, op = o, valeur = v }       vrai si une minute de [a, b] satisfait ;
                                                                               valeur rendue = délai (minute - a) ;
      { type = "avant",   premier = <atteint>, second = <atteint> }           vrai si `premier` est atteint et que `second`
                                                                               ne l'est pas avant lui (égalité : vrai) ;
      { type = "ligne",   motif = regex, de = a, a = b, fn = "nombre"|"max"|"min"|"somme", op = o, valeur = v }
                          jugé par le LANCEUR sur le journal (regex Python ; « {equipe} » remplacé par la clé de l'équipe ;
                          fn autre que « nombre » : premier groupe capturé, lu comme un nombre), entre la marque du relevé
                          de la minute a et celle de la minute b + 1 ; le jeu écrit « EN ATTENTE (journal) ».
    op : "<", "<=", "==", ">=", ">", "~=".
    valeur : un nombre, ou une RÉFÉRENCE tirée des relevés de la même équipe :
             { ref = c, de = a, a = b, fn = "moyenne"|"max"|"min"|"somme", facteur = k|1 }   (ex. 0,8 × le débit d'avant).
    Minute de jugement : `minute` (seuil) ou `a` (les autres ; avant : le plus grand `a` de ses deux branches).

  ── Lignes de verdict (journal du banc, une par attendu et par équipe) ─────────────────────────────────────────────────
    [FO-SCEN] <nom> min <m> | attendu <id>@<equipe> : OK <valeur>
    [FO-SCEN] <nom> min <m> | attendu <id>@<equipe> : ECHEC <valeur>
    [FO-SCEN] <nom> min <m> | attendu <id>@<equipe> : EN ATTENTE (journal)
    [FO-SCEN] <nom> min <m> | mise en scene <action>@<equipe> : OK|ECHEC <détail>
    [FO-SCEN] <nom> BILAN : <n> OK, <n> ECHEC, <n> EN ATTENTE
  <valeur> = la valeur observée (nombre arrondi à 2 décimales, « nil » si le relevé manque) puis « (attendu <op> <v>) ».
]]

local F = {}

F.TICKS_PAR_MIN = 3600
F.MARGE_TICKS = 600
F.TAG = "[FO-SCEN]"

local OPS = {
  ["<"] = function(x, v) return x < v end,
  ["<="] = function(x, v) return x <= v end,
  ["=="] = function(x, v) return x == v end,
  [">="] = function(x, v) return x >= v end,
  [">"] = function(x, v) return x > v end,
  ["~="] = function(x, v) return x ~= v end,
}
F.OPS = OPS

local ACTIONS = { vider_coffres = true, attaque = true, poser = true, detruire = true, assecher_centrale = true }
F.ACTIONS = ACTIONS
local AGREGATS = { max = true, min = true, moyenne = true, somme = true }
local LIGNE_FN = { nombre = true, max = true, min = true, somme = true }

--- Ticks de banc pour jouer le scénario jusqu'au dernier jugement.
function F.ticks(scen)
  return (scen.duree_min or 0) * F.TICKS_PAR_MIN + F.MARGE_TICKS
end

local function is_int(x) return type(x) == "number" and x == math.floor(x) end

local function check_valeur(v, where)
  if type(v) == "number" then return nil end
  if type(v) == "table" and type(v.ref) == "string" and is_int(v.de) and is_int(v.a) and v.de <= v.a
    and AGREGATS[v.fn or "moyenne"] and (v.facteur == nil or type(v.facteur) == "number") then
    return nil
  end
  return where .. " : valeur ni nombre ni référence { ref, de, a, fn, facteur }"
end

local function check_pred(p, where)
  if type(p) ~= "table" then return where .. " : prédicat absent" end
  local t = p.type
  if t == "avant" then
    if type(p.premier) ~= "table" or p.premier.type ~= "atteint" then return where .. " : avant.premier doit être un « atteint »" end
    if type(p.second) ~= "table" or p.second.type ~= "atteint" then return where .. " : avant.second doit être un « atteint »" end
    return check_pred(p.premier, where .. ".premier") or check_pred(p.second, where .. ".second")
  end
  if not OPS[p.op or ""] then return where .. " : op inconnu " .. tostring(p.op) end
  local e = check_valeur(p.valeur, where)
  if e then return e end
  if t == "seuil" then
    if type(p.champ) ~= "string" or not is_int(p.minute) then return where .. " : seuil = { champ, minute, op, valeur }" end
  elseif t == "agregat" or t == "atteint" then
    if type(p.champ) ~= "string" or not is_int(p.de) or not is_int(p.a) or p.de > p.a then
      return where .. " : " .. t .. " = { champ, de <= a, op, valeur }"
    end
    if t == "agregat" and not AGREGATS[p.fn or ""] then return where .. " : fn inconnue " .. tostring(p.fn) end
  elseif t == "ligne" then
    if type(p.motif) ~= "string" or not is_int(p.de) or not is_int(p.a) or p.de > p.a then
      return where .. " : ligne = { motif, de <= a, fn, op, valeur }"
    end
    if not LIGNE_FN[p.fn or "nombre"] then return where .. " : fn inconnue " .. tostring(p.fn) end
    if type(p.valeur) ~= "number" then return where .. " : une ligne se compare à un nombre" end
  else
    return where .. " : type inconnu " .. tostring(t)
  end
  return nil
end

--- Rend nil si la déclaration est bien formée, sinon le premier défaut (texte).
function F.valider(scen)
  if type(scen) ~= "table" then return "scénario : pas une table" end
  if type(scen.nom) ~= "string" or not scen.nom:match("^[a-z0-9%-]+$") then return "nom : minuscules, chiffres et tirets" end
  if not is_int(scen.duree_min) or scen.duree_min < 1 then return "duree_min : entier >= 1" end
  if type(scen.description) ~= "table" or type(scen.description.fr) ~= "string" or type(scen.description.en) ~= "string" then
    return "description : { fr, en }"
  end
  if scen.equipes ~= nil and scen.equipes ~= "toutes" and type(scen.equipes) ~= "table" then return "equipes : \"toutes\" ou liste" end
  if scen.suivre ~= nil and type(scen.suivre) ~= "table" then return "suivre : liste d'objets" end
  for i, a in ipairs(scen.mise_en_scene or {}) do
    local w = "mise_en_scene[" .. i .. "]"
    if not ACTIONS[a.action or ""] then return w .. " : action inconnue " .. tostring(a.action) end
    if not is_int(a.minute) or a.minute < 1 or a.minute > scen.duree_min then return w .. " : minute dans [1, duree_min]" end
    if a.action == "vider_coffres" and type(a.objets) ~= "table" then return w .. " : objets = { .. }" end
    if a.action == "attaque" and (type(a.unites) ~= "table" or type(a.distance) ~= "number") then
      return w .. " : unites = { {nom, n} }, distance"
    end
    if a.action == "poser" and type(a.entite) ~= "string" then return w .. " : entite" end
    if a.action == "detruire" and not (a.type or a.nom) then return w .. " : type ou nom" end
    if a.action == "assecher_centrale" and ((a.rayon ~= nil and type(a.rayon) ~= "number")
      or (a.tapis_coupes ~= nil and not is_int(a.tapis_coupes))) then
      return w .. " : rayon (nombre), tapis_coupes (entier)"
    end
  end
  if type(scen.theorie) ~= "table" or #scen.theorie == 0 then return "theorie : au moins un attendu" end
  local ids = {}
  for i, att in ipairs(scen.theorie) do
    local w = "theorie[" .. i .. "]"
    if type(att.id) ~= "string" or not att.id:match("^[a-z0-9%-]+$") then return w .. " : id (minuscules, chiffres, tirets)" end
    if ids[att.id] then return w .. " : id en double " .. att.id end
    ids[att.id] = true
    if type(att.texte) ~= "table" or type(att.texte.fr) ~= "string" or type(att.texte.en) ~= "string" then
      return w .. " : texte = { fr, en }"
    end
    local e = check_pred(att.predicat, w)
    if e then return e end
    if F.minute_de(att.predicat) > scen.duree_min then return w .. " : jugé après duree_min" end
  end
  return nil
end

--- Minute à laquelle un prédicat se juge.
function F.minute_de(p)
  if p.type == "seuil" then return p.minute end
  if p.type == "avant" then return math.max(F.minute_de(p.premier), F.minute_de(p.second)) end
  return p.a
end

--- Actions de mise en scène dues à la minute m (ordre de la liste).
function F.actions_a(scen, m)
  local out = {}
  for _, a in ipairs(scen.mise_en_scene or {}) do if a.minute == m then out[#out + 1] = a end end
  return out
end

--- Attendus jugés à la minute m (ordre de la théorie).
function F.attendus_a(scen, m)
  local out = {}
  for _, att in ipairs(scen.theorie) do if F.minute_de(att.predicat) == m then out[#out + 1] = att end end
  return out
end

--- Champs dérivés : debit:<objet> = prod:<objet>(m) - prod:<objet>(m-1). `rel` = { [m] = { champ = v } } d'une équipe ;
--- complète rel[m] en place (prod:<objet> est le cumul brut relevé en jeu).
function F.deriver(rel, m, suivre)
  local cur, prev = rel[m], rel[m - 1]
  if not cur then return end
  for _, it in ipairs(suivre or {}) do
    local a, b = cur["prod:" .. it], prev and prev["prod:" .. it]
    if a and b then cur["debit:" .. it] = a - b end
  end
end

local function serie(rel, champ, de, a)
  local vs = {}
  for m = de, a do
    local r = rel[m]
    local v = r and r[champ]
    if type(v) == "number" then vs[#vs + 1] = v end
  end
  return vs
end

local function agreger(vs, fn)
  if #vs == 0 then return nil end
  local acc = (fn == "max" or fn == "min") and vs[1] or 0
  for _, v in ipairs(vs) do
    if fn == "max" then acc = math.max(acc, v)
    elseif fn == "min" then acc = math.min(acc, v)
    else acc = acc + v end
  end
  if fn == "moyenne" then acc = acc / #vs end
  return acc
end
F.agreger = agreger

--- Valeur de comparaison (nombre ou référence) ; nil si la référence n'a aucun relevé.
function F.valeur(v, rel)
  if type(v) == "number" then return v end
  local x = agreger(serie(rel, v.ref, v.de, v.a), v.fn or "moyenne")
  return x and x * (v.facteur or 1) or nil
end

local function premiere(p, rel, cible)
  for m = p.de, p.a do
    local r = rel[m]
    local x = r and r[p.champ]
    if type(x) == "number" and OPS[p.op](x, cible) then return m end
  end
  return nil
end

--- Juge un prédicat sur les relevés d'UNE équipe. Rend etat ("OK" | "ECHEC" | "EN ATTENTE"), observé (nombre ou nil), cible.
function F.juger(p, rel)
  if p.type == "ligne" then return "EN ATTENTE", nil, p.valeur end
  if p.type == "avant" then
    local c1, c2 = F.valeur(p.premier.valeur, rel), F.valeur(p.second.valeur, rel)
    local m1 = c1 and premiere(p.premier, rel, c1)
    local m2 = c2 and premiere(p.second, rel, c2)
    local ok = m1 ~= nil and (m2 == nil or m1 <= m2)
    return ok and "OK" or "ECHEC", m1, m2
  end
  local cible = F.valeur(p.valeur, rel)
  if cible == nil then return "ECHEC", nil, nil end
  if p.type == "seuil" then
    local r = rel[p.minute]
    local x = r and r[p.champ]
    if type(x) ~= "number" then return "ECHEC", nil, cible end
    return OPS[p.op](x, cible) and "OK" or "ECHEC", x, cible
  elseif p.type == "agregat" then
    local x = agreger(serie(rel, p.champ, p.de, p.a), p.fn)
    if x == nil then return "ECHEC", nil, cible end
    return OPS[p.op](x, cible) and "OK" or "ECHEC", x, cible
  elseif p.type == "atteint" then
    local m = premiere(p, rel, cible)
    return m and "OK" or "ECHEC", m and (m - p.de) or nil, cible
  end
  return "ECHEC", nil, nil
end

local function num(x)
  if type(x) ~= "number" then return "nil" end
  if x == math.floor(x) then return string.format("%d", x) end
  return string.format("%.2f", x)
end
F.num = num

--- Texte de la valeur observée et de la cible.
function F.detail(p, observe, cible)
  if p.type == "avant" then
    return "premier min " .. num(observe) .. ", second min " .. num(cible)
  end
  if p.type == "atteint" then
    return "delai " .. num(observe) .. " min (attendu " .. p.champ .. " " .. p.op .. " " .. num(cible) .. ")"
  end
  return num(observe) .. " (attendu " .. p.op .. " " .. num(cible) .. ")"
end

--- Ligne de verdict d'un attendu.
function F.ligne_attendu(scen, m, att, equipe, etat, observe, cible)
  local tail = etat == "EN ATTENTE" and "EN ATTENTE (journal)" or (etat .. " " .. F.detail(att.predicat, observe, cible))
  return string.format("%s %s min %d | attendu %s@%s : %s", F.TAG, scen.nom, m, att.id, equipe, tail)
end

--- Ligne d'un relevé (champs triés).
function F.ligne_releve(scen, m, equipe, r)
  local ks = {}
  for k in pairs(r) do ks[#ks + 1] = k end
  table.sort(ks)
  local parts = {}
  for _, k in ipairs(ks) do parts[#parts + 1] = k .. "=" .. num(r[k]) end
  return string.format("%s %s releve min %d %s | %s", F.TAG, scen.nom, m, equipe, table.concat(parts, " "))
end

--- Ligne d'une action de mise en scène.
function F.ligne_action(scen, m, action, equipe, ok, detail)
  return string.format("%s %s min %d | mise en scene %s@%s : %s %s", F.TAG, scen.nom, m, action, equipe, ok and "OK" or "ECHEC",
    tostring(detail or ""))
end

--- Équipes jugées : clés des rows (déjà triées par l'appelant) filtrées par scen.equipes.
function F.equipes(scen, keys)
  local sorted = {}
  for _, k in ipairs(keys) do sorted[#sorted + 1] = k end
  table.sort(sorted)
  if scen.equipes == nil or scen.equipes == "toutes" then return sorted end
  local want = {}
  for _, k in ipairs(scen.equipes) do want[k] = true end
  local out = {}
  for _, k in ipairs(sorted) do if want[k] then out[#out + 1] = k end end
  return out
end

--- Nombre d'unités à détruire pour une action detruire sur `total` entités.
function F.a_detruire(a, total)
  if a.n then return math.min(a.n, total) end
  return math.min(total, math.ceil((a.part or 1) * total - 1e-9))
end

return F
