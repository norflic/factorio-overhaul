--[[
  Lot JOURNAUX-DC (30/10, rapport fo-logs/2026-10-30_AMELIO/CINQ-POINTS.md, points 1, 2, 3 et 5) : règles PURES des
  journaux et des messages qui rendent lisible une partie du Directeur Créatif. Aucune décision de jeu ici : ces règles
  disent quoi écrire (journal, message, ligne de l'onglet « Partie »), jamais quoi faire.

    J.cause(killer_force, own_force, faction_key_of)  -> genre, clé : qui a détruit un QG (« rival », « biters »,
                                                         « joueur », « elle-meme », « autre », « inconnue »)
    J.fin_de_guerre(n_vivantes, genre, tueur, survivante) -> nil | "victoire" | "seule" : le message « remporte la guerre »
                                                         n'est dit que si la SURVIVANTE a détruit le QG du dernier rival
    J.plafond_observe(st, tick, cap, effectif, fer, cout) -> alerte nouvelle ou nil (une fois par épisode de plafond)
    J.plafond_alerte(st, tick)                          -> nil | { minutes, fer, cout, cap, recrues }
    J.resume_objets(contenu, max)                       -> total, texte « objet n, … » (plus nombreux d'abord)
    J.ligne_reglages(valeurs)                           -> « nom=valeur nom=valeur … » (noms triés)
    J.mur_bloque(st, tick, sig)                         -> st, action : recherche bloquée (« annonce », « change » ou nil)
    J.mur_libre(st)                                     -> "fin" si un mur avait été annoncé

  Déterminisme : aucune itération par pairs sans tri ; aucun nom d'objet du jeu (le fer est passé par l'appelant).
]]

local J = {}

-- Forces du moteur : les biters et le joueur (noms des forces de base du moteur, pas des objets).
J.ENEMY_FORCE = "enemy"
J.PLAYER_FORCE = "player"

-- Point 2 du rapport : « plafond d'ouvriers atteint, N fers inemployés » quand une équipe est au plafond depuis
-- J.PLAFOND_TICKS avec un stock libre d'au moins J.PLAFOND_FACTEUR fois le coût en fer d'une recrue.
J.PLAFOND_TICKS = 30 * 3600
J.PLAFOND_FACTEUR = 10

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

-- Point 3 : un mur de recherche n'est annoncé qu'après J.MUR_DELAI de blocage CONTINU (au début d'une partie, une équipe
-- dont le gisement de fer n'est pas encore connu est « bloquée » quelques secondes : ce n'est pas un mur).
J.MUR_DELAI = 5 * 3600

--- Qui a détruit le QG ? `killer_force` = nom de la force du tueur (nil : inconnu, destruction par script),
--- `own_force` = force de l'équipe, `faction_key_of(nom de force)` = clé de faction ou nil.
function J.cause(killer_force, own_force, faction_key_of)
  if killer_force == nil or killer_force == "" then return "inconnue", nil end
  if killer_force == own_force then return "elle-meme", nil end
  local k = faction_key_of and faction_key_of(killer_force)
  if k then return "rival", k end
  if killer_force == J.ENEMY_FORCE then return "biters", nil end
  if killer_force == J.PLAYER_FORCE then return "joueur", nil end
  return "autre", killer_force
end

--- Message de fin de guerre quand une faction vient de tomber. `n_vivantes` = factions encore en vie après la chute,
--- `genre`, `tueur` = J.cause de la chute, `survivante` = clé de la dernière faction vivante.
--- nil : la guerre continue ; "victoire" : la survivante a battu le dernier rival ; "seule" : message neutre.
function J.fin_de_guerre(n_vivantes, genre, tueur, survivante)
  if n_vivantes ~= 1 then return nil end
  if genre == "rival" and tueur ~= nil and tueur == survivante then return "victoire" end
  return "seule"
end

--- Alerte en cours (sans rien écrire) : au plafond depuis J.PLAFOND_TICKS et fer libre ≥ J.PLAFOND_FACTEUR × coût.
function J.plafond_alerte(st, tick)
  if not st or st.depuis == nil then return nil end
  local dt = (tick or 0) - st.depuis
  if dt < J.PLAFOND_TICKS then return nil end
  local fer, cout = st.fer or 0, st.cout or 0
  if cout <= 0 or fer < J.PLAFOND_FACTEUR * cout then return nil end
  return { minutes = math.floor(dt / 3600), fer = fer, cout = cout, cap = st.cap or 0, recrues = math.floor(fer / cout) }
end

--- Une pensée de l'équipe : `cap` = plafond d'ouvriers, `effectif` = ouvriers vivants, `fer` = fer LIBRE au stock,
--- `cout` = fer d'une recrue. Écrit `st` (table de l'état de l'équipe) ; rend l'alerte quand elle devient vraie pour la
--- première fois de l'épisode (le runtime l'écrit au journal), nil sinon. Sous le plafond, l'épisode se termine.
function J.plafond_observe(st, tick, cap, effectif, fer, cout)
  if not st then return nil end
  if not cap or cap <= 0 or (effectif or 0) < cap then
    st.depuis, st.signale = nil, nil
    return nil
  end
  if st.depuis == nil then st.depuis = tick end
  st.cap, st.fer, st.cout = cap, fer or 0, cout or 0
  local a = J.plafond_alerte(st, tick)
  if a and not st.signale then
    st.signale = tick
    return a
  end
  return nil
end

--- Résumé d'un contenu { [objet] = n } : total et « objet n, … » (les `max` plus nombreux, puis le nom).
function J.resume_objets(contenu, max)
  local list, total = {}, 0
  for _, k in ipairs(sorted_keys(contenu)) do
    local n = contenu[k] or 0
    if n > 0 then
      list[#list + 1] = { k, n }
      total = total + n
    end
  end
  table.sort(list, function(a, b)
    if a[2] ~= b[2] then return a[2] > b[2] end
    return a[1] < b[1]
  end)
  local parts = {}
  for i = 1, math.min(max or 6, #list) do parts[#parts + 1] = list[i][1] .. " " .. list[i][2] end
  if #list > (max or 6) then parts[#parts + 1] = "..." end
  return total, table.concat(parts, ", ")
end

--- Ligne des réglages : { [nom] = valeur } -> « nom=valeur … », noms triés (valeurs booléennes, nombres, chaînes).
function J.ligne_reglages(valeurs)
  local parts = {}
  for _, k in ipairs(sorted_keys(valeurs)) do
    local v = valeurs[k]
    if type(v) == "number" and v == math.floor(v) then v = string.format("%d", v) end
    parts[#parts + 1] = k .. "=" .. tostring(v)
  end
  return table.concat(parts, " ")
end

--- Recherche bloquée à `tick` (aucune technologie payable), `sig` = signature de la situation (technologies prêtes
--- impayables, nombre restant). `st` = état du mur (nil : pas encore bloquée). Rend le nouvel état et l'action à écrire au
--- journal : "annonce" (premier passage après J.MUR_DELAI), "change" (situation différente après l'annonce), nil sinon.
function J.mur_bloque(st, tick, sig)
  if not st then return { since = tick }, nil end
  if tick - st.since < J.MUR_DELAI then return st, nil end
  if st.dit and st.sig == sig then return st, nil end
  local action = st.dit and "change" or "annonce"
  st.sig, st.dit = sig, true
  return st, action
end

--- Une technologie est de nouveau payable : "fin" si le mur avait été annoncé (le runtime l'écrit), nil sinon.
function J.mur_libre(st)
  return (st and st.dit) and "fin" or nil
end

return J
