--[[
  Lot X10-S10 « factions lointaines plus lentes » (fo-logs/2026-11-07_X10/SCRIPT.md, gain S10 ; accepté par le DC en QCM le 7/11 à
  17 h 47 : « Oui, factions lointaines plus lentes (Recommandé) »). RÈGLE PURE (aucune API Factorio ; tests/cadence_test.lua).

  Une FACTION loin de tout joueur et sans menace pense toutes les Cd.SLOW ticks au lieu de sa période (300) : à son créneau, la pensée
  est SAUTÉE tant que la dernière date de moins de Cd.SLOW. Elle reprend son rythme dès qu'une de ces causes apparaît, et une faction
  qui dormait (créneau sauté) repense AU TICK SUIVANT (Cd.wake, guetté à chaque tick par le runtime) :
    « joueur proche »     un joueur connecté de la surface dans la ZONE de la faction (boîte de son QG et de ses avant-postes, élargie
                          de Cd.NEAR tuiles) ;
    « menace »            tick < f.threatened_until (une perte près du QG : script/faction/commander.lua, on_died) ;
    « attaque »           un bâtiment touché par une unité ou un personnage adverse depuis moins de Cd.ALERT ticks (f.attack_alert_t,
                          script/team/reparation.lua), ou TOUT coup d'une force adverse sur un type relevé, tourelles comprises
                          (f.hit_t, même fichier, noté avant ses filtres ; revue de 87ac84fe : une ligne de tourelles attaquée ne
                          réveillait la faction qu'à la première mort) ;
    « perte »             une entité de la faction morte, où qu'elle soit, depuis moins de Cd.ALERT ticks (f.lost_t, on_died) ;
    « ennemi pres du QG » la base menacée ou envahie à la dernière pensée (DefChoix.base, view.base_alert), tenue jusqu'à la suivante ;
    « armee dehors »      une force de la faction hors du QG ou qui s'y prépare (Cd.army_out) : groupe armé en route ou au combat
                          (attaque, retour, éclaireur : f.groups, entretenus par Military.maintain DANS la pensée), attaque en
                          préparation (f.route_pending), opération de nettoyage d'un site (IA3, rassemblement ou attaque), expédition
                          contre un champ de nids (IA3), armée de la prévision en alerte ou au regroupement : une armée qui attaque
                          votre base loin de son QG n'est pas pilotée à Cd.SLOW (condition du lead, 7/11 ; IA3 : revue de 87ac84fe).
  Votre équipe garde son rythme (« votre equipe »).
  Au créneau, une faction qui a pensé depuis moins d'une période (réveil compris) laisse ce créneau (Cd.recent) : un réveil à T + k
  suivi du créneau T + P referait penser la faction P − k ticks plus tard, et pour k >= P − 3 ses étapes E1 à E4 se rejoueraient d'un
  bloc pendant celles de la première (revue de 87ac84fe). L'écart qui suit un réveil est donc entre P et 2 P − 1 ticks.

  GARDE FERMÉE PAR DÉFAUT (comme le lot L13) : une entrée absente ne ralentit jamais. Zone inconnue (aucun QG relevé), liste des joueurs
  absente, état de l'armée non dit (army_out ni vrai ni faux) : la faction reste au rythme normal (causes « zone inconnue », « joueurs
  inconnus », « armee inconnue ») ; dans Cd.army_out, un état de forme inconnue compte comme « dehors ».
  Aucun temps mesuré : seulement des ticks de jeu et des positions. Déterminisme : joueurs dans l'ordre donné (game.connected_players),
  points de la zone triés par l'appelant, aucun hasard.
]]

local Cd = {}

Cd.SLOW = 600     -- ticks entre deux pensées d'une faction lointaine et calme (sa période normale : F.defaults.think_period = 300)
Cd.NEAR = 160     -- tuiles autour du QG et des avant-postes : au dézoom le plus large (0,3 à 1 920 px), l'écran montre environ 100 tuiles de
                  -- part et d'autre du joueur ; la faction se réveille avant d'entrer dans son champ (DÉDUIT, pas mesuré)
Cd.ALERT = 900    -- ticks pendant lesquels une attaque ou une perte la garde éveillée (THREAT_TICKS de shared/team/defchoix.lua)

--- Zone d'une faction : boîte des points { {x, y}, ... } élargie de `near` tuiles ; nil sans point.
function Cd.zone(points, near)
  local x0, y0, x1, y1
  for _, p in ipairs(points or {}) do
    local x, y = p.x or p[1], p.y or p[2]
    if type(x) == "number" and type(y) == "number" then
      if not x0 then x0, y0, x1, y1 = x, y, x, y else
        if x < x0 then x0 = x end
        if x > x1 then x1 = x end
        if y < y0 then y0 = y end
        if y > y1 then y1 = y end
      end
    end
  end
  if not x0 then return nil end
  local d = near or Cd.NEAR
  return { x0 = x0 - d, y0 = y0 - d, x1 = x1 + d, y1 = y1 + d }
end

local function inside(b, x, y) return x >= b.x0 and x <= b.x1 and y >= b.y0 and y <= b.y1 end

--- Une force de la faction est-elle hors du QG, ou s'y prépare-t-elle ? a = { groups (f.groups : table des groupes armés ou nil),
--- route_pending (attaque préparée), nt (opération de nettoyage d'un site, IA3 : nil ou table), clearing (expédition contre un champ
--- de nids, IA3 : nil ou table), armee (f.armee, prévision : nil ou { alert, muster, ... }) }. Rend (vrai, cause) ou (faux, nil).
--- GARDE FERMÉE : un état de forme inconnue (a absent, groups ou armee qui ne sont pas des tables, opération dans une phase inconnue,
--- alerte ni vraie ni fausse) compte comme « dehors ».
function Cd.army_out(a)
  if type(a) ~= "table" then return true, "armee inconnue" end
  local g = a.groups
  if g ~= nil then
    if type(g) ~= "table" then return true, "armee inconnue" end
    if next(g) ~= nil then return true, "groupe arme" end
  end
  if a.route_pending ~= nil and a.route_pending ~= false then return true, "attaque preparee" end
  if a.nt ~= nil then return true, "nettoyage" end -- rassemblement ou attaque (toute autre fin retire l'opération)
  if a.clearing ~= nil then return true, "expedition" end
  local ar = a.armee
  if ar ~= nil then
    if type(ar) ~= "table" then return true, "armee inconnue" end
    if ar.alert ~= nil and ar.alert ~= false then return true, "alerte" end
    if ar.muster ~= nil then return true, "regroupement" end
  end
  return false, nil
end

--- La faction doit-elle penser à son rythme normal ? s = { is_player, box (Cd.zone), players = { {x, y}, ... }, threatened_until,
--- attack_t, hit_t, lost_t, base_alert, army_out (booléen, Cd.army_out) }. Rend (vrai, cause) ou (faux, « loin et calme »).
function Cd.awake(s, tick)
  if s.is_player then return true, "votre equipe" end
  if type(s.box) ~= "table" then return true, "zone inconnue" end
  if type(s.players) ~= "table" then return true, "joueurs inconnus" end
  if type(s.threatened_until) == "number" and tick < s.threatened_until then return true, "menace" end
  if type(s.attack_t) == "number" and tick - s.attack_t < Cd.ALERT then return true, "attaque" end
  if type(s.hit_t) == "number" and tick - s.hit_t < Cd.ALERT then return true, "attaque" end
  if type(s.lost_t) == "number" and tick - s.lost_t < Cd.ALERT then return true, "perte" end
  if s.base_alert then return true, "ennemi pres du QG" end
  if s.army_out ~= false then return true, s.army_out == true and "armee dehors" or "armee inconnue" end
  for _, p in ipairs(s.players) do
    local x, y = p.x or p[1], p.y or p[2]
    if type(x) == "number" and type(y) == "number" and inside(s.box, x, y) then return true, "joueur proche" end
  end
  return false, "loin et calme"
end

--- À son créneau : la dernière pensée (réveil compris) date-t-elle de moins de `period` ticks ? Alors ce créneau est laissé, sans
--- endormir la faction (voir l'en-tête). Sans dernière pensée ou sans période : faux (la faction pense).
function Cd.recent(st, tick, period)
  return type(st.last) == "number" and type(period) == "number" and tick - st.last < period
end

--- À son créneau : la pensée est-elle sautée ? st = état de la faction ({ last = tick de la dernière pensée }). Rend (sautée, cause).
function Cd.skip(st, s, tick)
  local up, why = Cd.awake(s, tick)
  if up then return false, why end
  if type(st.last) ~= "number" then return false, "premiere pensee" end
  if tick - st.last >= Cd.SLOW then return false, why end
  return true, why
end

--- Guet : une faction qui DORT (créneau sauté, st.asleep) et qu'une cause réveille doit repenser maintenant. Rend (réveil, cause).
function Cd.wake(st, s, tick)
  if not st.asleep then return false, nil end
  local up, why = Cd.awake(s, tick)
  return up, why
end

return Cd
