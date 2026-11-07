--[[
  Lot L12 de la feuille de route « Factorio Automated » (docs/VIDEO_AUTOMATISATION.md §6 L12 ; docs/TODO_VIDEO.md G15, G16, G17) :
  HYSTÉRÉSIS ET VERROU DES CRISES. Règle PURE et GÉNÉRIQUE (aucune API Factorio, aucun nom d'objet : anti-échelle de tests/iag_test.lua §8).
  Testée hors jeu : tests/hysteresis_test.lua. NON BRANCHÉE : le plan du branchement est dans le rapport du lot (drapeaux à seuil unique,
  fichier:ligne).

  Le modèle (gist de l'auteur, l.48-53) : la crise d'énergie ENTRE quand la charge des accumulateurs passe sous 40, elle DURE tant que la
  charge reste sous 50, et le besoin `need_power` reste VERROUILLÉ jusqu'à ce qu'une mégatuile d'énergie soit POSÉE. Deux défauts évités :
    1. un SEUIL UNIQUE fait clignoter la crise autour du seuil (chaque passage remet et retire le besoin) ;
    2. un besoin levé quand le signal « guérit » un instant (avant la pose du correctif) laisse la cause en place : la crise revient.

  H.update(st, valeur, entree, sortie, pose[, opts]) : une MESURE (une pensée, une décision). « Bas = mauvais » (charge, satisfaction) :
    - ENTRÉE   valeur < entree (strict) : crise ouverte, besoin verrouillé ;
    - SORTIE   crise ouverte et valeur > sortie (strict) pendant opts.sortie_n mesures DE SUITE (défaut 1) : crise fermée ;
               entre les deux seuils, l'état ne change pas (c'est l'hystérésis) ;
    - VERROU   le besoin reste vrai, crise fermée ou non, jusqu'à une mesure où `pose` est vrai (le correctif est POSÉ ; avec L5,
               posé ET confirmé : le runtime ne passe `pose` qu'à la première production du correctif) ;
    - RÉARMEMENT si la crise est encore ouverte à la mesure qui suit la pose, le besoin se reverrouille : un correctif de plus (une seule
               unité par mesure : petites marches, L6). La mesure de la pose ne se reverrouille pas elle-même (anti-répétition : le
               signal est en retard sur la pose, G27).
    - ABSENT   valeur nil ou non nombre : rien ne change (garde fermée, L13 : une mesure manquante ne lève jamais une crise).
    - SEUILS INVERSÉS (entree > sortie) : refusés, rien ne change, événement « seuils ».
  H.update_haut(...) : même règle pour « haut = mauvais » (menace, file d'attente) : entrée AU-DESSUS de `entree`, sortie SOUS `sortie`.
  Rend (st, evenement) ; evenement : "entree", "sortie", "pose", "rearme", "absent", "seuils" ou nil.
  État `st` : nombres et booléens seulement (vit dans la sauvegarde) : crise, besoin, haut_n (mesures de suite au-delà de la sortie),
  entrees, poses.
  Déterminisme : aucune table parcourue, aucun hasard, aucun temps mesuré : la cadence est celle de l'appelant (ticks de jeu).
]]

local H = {}

function H.new()
  return { crise = false, besoin = false, haut_n = 0, entrees = 0, poses = 0 }
end

local function num(v) return type(v) == "number" and v == v end

--- Une mesure, « bas = mauvais ». Voir l'en-tête.
function H.update(st, valeur, entree, sortie, pose, opts)
  st.haut_n = st.haut_n or 0
  if not num(entree) or not num(sortie) or entree > sortie then return st, "seuils" end
  if not num(valeur) then return st, "absent" end
  local ev = nil
  if pose and st.besoin then
    st.besoin = false
    st.poses = (st.poses or 0) + 1
    ev = "pose"
  end
  if not st.crise then
    if valeur < entree then
      st.crise, st.besoin, st.haut_n = true, true, 0
      st.entrees = (st.entrees or 0) + 1
      ev = "entree"
    end
  else
    if valeur > sortie then st.haut_n = st.haut_n + 1 else st.haut_n = 0 end
    local need_n = (opts and opts.sortie_n) or 1
    if st.haut_n >= need_n then
      st.crise, st.haut_n = false, 0
      ev = ev or "sortie"
    elseif not st.besoin and ev ~= "pose" then
      -- crise encore ouverte à la mesure qui SUIT la pose : un correctif de plus
      st.besoin = true
      ev = "rearme"
    end
  end
  return st, ev
end

--- Une mesure, « haut = mauvais » : entrée au-dessus de `entree`, sortie sous `sortie` (entree >= sortie).
function H.update_haut(st, valeur, entree, sortie, pose, opts)
  if not num(entree) or not num(sortie) or entree < sortie then return st, "seuils" end
  if not num(valeur) then return st, "absent" end
  return H.update(st, -valeur, -entree, -sortie, pose, opts)
end

--- Ligne de journal (aucune décision ne la lit).
function H.describe(st)
  return string.format("crise %s, besoin %s, %d entree(s), %d pose(s), %d mesure(s) au-dela de la sortie",
    st.crise and "OUVERTE" or "fermee", st.besoin and "VERROUILLE" or "libre", st.entrees or 0, st.poses or 0, st.haut_n or 0)
end

return H
