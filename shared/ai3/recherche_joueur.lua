--[[
  Lot RECHERCHE (3/11, retour du DC sur 0.6.46) : votre équipe et la recherche COURANTE de votre force. Lua PUR.

  Retour : « dès que l'utilisateur modifie ce qu'il veut rechercher, ça coupe entièrement le fil de recherche de la base et
  du coup la recherche se bloque. [...] j'ai dû remettre la recherche initiale et ça remarche. »
  Cause (script/ai3/cerveau.lua, Ia3.plan avant ce lot) : la recherche de l'équipe n'était pas pensée du tout tant que la
  recherche courante de la force n'était ni vide ni celle de l'équipe ; si le joueur choisissait une autre technologie
  qu'il ne pouvait pas payer (pas de laboratoire, pas de packs), la force gardait cette courante indéfiniment et l'équipe
  ne cherchait plus jamais. Remettre la technologie de l'équipe rendait la main.

  Règle : une force n'a qu'UNE recherche courante.
    - courante vide, ou celle de l'équipe : l'équipe écrit dans la force (add_research, research_progress) comme avant ;
    - courante d'un autre (le joueur) : l'équipe NE TOUCHE PAS à la courante, ne lutte pas contre ce choix ; elle
      continue ses propres unités en parallèle, hors de la courante (avancement gardé par l'équipe), et la termine par
      `technologies[x].researched = true` (F270) ; jamais bloquée, jamais en travers du joueur.
  Aucun nom d'objet, de pack ni de technologie.
]]

local R = {}

R.LIBRE = "libre"       -- aucune recherche courante
R.SIENNE = "sienne"     -- la courante est celle que l'équipe a lancée
R.JOUEUR = "joueur"     -- la courante est un autre choix (celui du joueur)

--- Qui tient la recherche courante de la force ? `cur` : nom de la courante (nil : aucune), `mine` : technologie lancée par
--- l'équipe (st.lab.tech, nil : aucune).
function R.holder(cur, mine)
  if cur == nil then return R.LIBRE end
  if mine ~= nil and cur == mine then return R.SIENNE end
  return R.JOUEUR
end

--- L'équipe pense-t-elle sa recherche à cette pensée ? Toujours (avant ce lot : seulement si la courante n'était pas au joueur,
--- d'où le blocage du retour du DC).
function R.thinks(holder)
  return holder ~= nil
end

--- L'équipe peut-elle écrire dans la recherche courante de la force (add_research, research_progress) ?
function R.writes_force(holder)
  return holder ~= R.JOUEUR
end

--- Comment l'équipe termine sa technologie : "progress" (research_progress = 1, comme un laboratoire) quand elle tient la
--- courante, "flag" (researched = true) quand la courante est au joueur.
function R.finish_by(holder)
  return R.writes_force(holder) and "progress" or "flag"
end

--- Les prérequis de la technologie sont-ils faits ? (`done` : ensemble des technologies faites, `pre` : liste de noms.)
--- Hors de la courante, rien ne vérifie les prérequis à la place de add_research : l'équipe les contrôle.
function R.prereqs_done(pre, done)
  for _, p in ipairs(pre or {}) do
    if not (done and done[p]) then return false end
  end
  return true
end

return R
