--[[
  Lot TV-GARDES (TODO_VIDEO V88) : exécutant de la table défaut -> signal -> levier (shared/ai3/defauts.lua). Appelé UNE FOIS par pensée,
  à la fin de Ia3.plan_b (script/ai3/cerveau.lua), pour les factions et votre équipe. Il LIT la table, évalue les mesures de la vue de
  l'équipe, pose le résultat dans le plan (plan.ia3.defauts = { [défaut] = état }, plan.ia3.defauts_n) et écrit une ligne [FO-DEFAUT] à
  chaque CHANGEMENT d'état d'un défaut (jamais pour un état sain vu pour la première fois). Il ne modifie aucune tâche : les leviers sont
  ceux du tableau (extraction, tournée de service, ravitaillement...), la table dit lequel répond à quel défaut et la boucle vérifie
  qu'il est à l'œuvre. État sauvegardé : st.defaut_etat = { [défaut] = texte }, st.defaut_logs = nombre (jamais de fonction).
]]

local Df = require("shared.ai3.defauts")

local Rt = {}

Rt.LOGS = 300 -- lignes au plus par équipe et par partie (un état qui oscille ne remplit pas le journal)

--- f : équipe ; st : f.team.ia3 ; view : vue de la pensée ; plan : plan rendu par C.think ; tick.
function Rt.think(f, st, view, plan, tick)
  local rows = Df.evaluer(Df.mesures(view.outposts, st.short), plan.tasks)
  local etats, n = Df.etats(rows)
  plan.ia3.defauts, plan.ia3.defauts_n = etats, n
  st.defaut_etat = st.defaut_etat or {}
  for _, r in ipairs(rows) do
    local before = st.defaut_etat[r.id]
    if before ~= r.etat then
      st.defaut_etat[r.id] = r.etat
      if (before ~= nil or r.etat ~= "sain") and (st.defaut_logs or 0) < Rt.LOGS then
        st.defaut_logs = (st.defaut_logs or 0) + 1
        log(Df.ligne(f.key or (f.is_player and "player") or "?", tick / 3600, r))
      end
    end
  end
  return etats
end

return Rt
