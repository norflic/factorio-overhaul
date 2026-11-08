--[[
  Lot X10-GEL (levier L1 et Q7 du x10, fo-logs/2026-11-07_X10/L1_CRITERES.md ; décisions du DC du 7/11 en QCM : « Oui, figées hors de
  vue (Recommandé) » pour les usines des factions, puis pour leurs garnisons). RÈGLE PURE (aucune API Factorio ; tests/gel_test.lua).

  LA règle commune de zone et de réveil d'un POSTE : un îlot d'usine (script/faction/gel_usines.lua) ou un soldat en garnison. Un
  poste figé (`active = false` au moteur) est réveillé dès qu'une cause est vraie ; un poste actif n'est figé qu'après Gel.CALM ticks
  sans aucune cause et sans joueur à moins de Gel.FREEZE_R tuiles de sa boîte (hystérésis : pas de battement au bord).

  Zone et causes de faction : celles de la cadence S10 (shared/faction/cadence.lua, video-l5), réutilisées telles quelles :
  Cd.zone(points, near) pour les boîtes, Cd.awake(s, tick) pour « menace », « attaque », « perte », « ennemi pres du QG »,
  « armee dehors » (s.army_out, comme S10), « joueur proche » (et « votre equipe », « zone inconnue », « joueurs inconnus »,
  « armee inconnue » : garde fermée, rien n'est figé).
  Entrées propres d'un poste, données par son branchement : `unfit` (le poste ne peut pas être figé : îlot à relire, soldat en
  mission...) et `hazard` (menace LOCALE, garnisons seulement). Réglage éteint (s.off) : tout est réveillé, rien n'est figé.

  Déterminisme : postes dans l'ordre donné (triés par l'appelant), joueurs dans l'ordre donné, aucun hasard, aucun temps mesuré.
  L'état d'un poste st = { frozen = booléen, calm = tick ou nil } est écrit par Gel.decide (champ `calm`) ; le runtime écrit `frozen`
  quand il applique l'action rendue.
]]

local Cd = require("shared.faction.cadence")

local Gel = {}

Gel.WAKE_R = 224   -- réveil : un joueur à moins de 224 tuiles de la boîte (200 vues par le DC + 24 de guet : 20 ticks d'un train)
Gel.FREEZE_R = 256 -- gel : aucun joueur à moins de 256 tuiles de la boîte...
Gel.CALM = 600     -- ... ni aucune cause, depuis 600 ticks
Gel.GUET = 20      -- période du guet (ticks)

--- Boîtes d'un poste à partir de ses points { {x, y}, ... } : { wake, freeze } (nil sans point : le poste n'est jamais figé).
function Gel.boxes(points)
  return { wake = Cd.zone(points, Gel.WAKE_R), freeze = Cd.zone(points, Gel.FREEZE_R) }
end

local function cd_input(s, box, players)
  return { is_player = s.is_player, box = box, players = players, threatened_until = s.threatened_until, attack_t = s.attack_t,
    hit_t = s.hit_t, lost_t = s.lost_t, base_alert = s.base_alert, army_out = s.army_out }
end

--- Une cause de FACTION (sans la distance des joueurs) : rend (vrai, cause) ou (faux, nil).
function Gel.faction_cause(s, tick)
  if s.off then return true, "reglage" end
  local up, why = Cd.awake(cd_input(s, { x0 = 0, y0 = 0, x1 = 0, y1 = 0 }, {}), tick)
  if up then return true, why end
  return false, nil
end

--- Décision pour UN poste. st = { frozen, calm } (calm écrit ici) ; boxes = Gel.boxes(...) ; s = entrées de la faction
--- { is_player, players, threatened_until, attack_t, lost_t, base_alert, army_out, off } ; post = { unfit, hazard }.
--- Rend (action, cause) : action = "eveille" (poste figé à réveiller), "fige" (poste actif à figer) ou nil (rien à faire).
function Gel.decide(st, boxes, s, post, tick)
  local frozen = st.frozen == true
  local block = (s.off and "reglage") or (post and (post.unfit or post.hazard)) or nil
  if block then
    st.calm = nil
    if frozen then return "eveille", block end
    return nil, block
  end
  local box = boxes and (frozen and boxes.wake or boxes.freeze) or nil
  local up, why = Cd.awake(cd_input(s, box, s.players), tick)
  if frozen then
    if up then
      st.calm = nil -- réveillé : le calme repart de zéro (sinon il serait refigé sans Gel.CALM ticks de calme)
      return "eveille", why
    end
    return nil, why
  end
  if up then
    st.calm = nil
    return nil, why
  end
  if type(st.calm) ~= "number" then st.calm = tick end
  if tick - st.calm >= Gel.CALM then return "fige", why end
  return nil, "calme"
end

local function any_player_in(box, players)
  if type(box) ~= "table" or type(players) ~= "table" then return true end -- garde fermée
  for _, p in ipairs(players) do
    local x, y = p.x or p[1], p.y or p[2]
    if type(x) == "number" and type(y) == "number" and x >= box.x0 and x <= box.x1 and y >= box.y0 and y <= box.y1 then return true end
  end
  return false
end

--- Décision pour TOUS les postes d'une faction, avec le raccourci de la faction : si une cause de faction est vraie, tous les postes
--- figés sont réveillés ; si aucun joueur n'est dans la boîte de la faction (`fbox` = Gel.boxes de tous les points de ses postes),
--- aucun poste n'a de joueur proche et la distance n'est plus lue poste par poste. Même résultat que Gel.decide poste par poste
--- (prouvé par tests/gel_test.lua). posts = { { id, st, boxes, unfit, hazard } } (triés) ; rend { { id, action, cause } }.
function Gel.decide_all(posts, s, fbox, tick)
  local out = {}
  local up, why = Gel.faction_cause(s, tick)
  up = up and type(s.players) == "table" -- « joueurs inconnus » passe avant les causes (ordre de Cd.awake)
  local far = (not up) and fbox ~= nil and not any_player_in(fbox.freeze, s.players)
  for _, p in ipairs(posts) do
    local action, cause
    if s.off or p.unfit or p.hazard or not (p.boxes and p.boxes.wake) then
      action, cause = Gel.decide(p.st, p.boxes, s, p, tick) -- même priorité des causes que poste par poste
    elseif up then
      p.st.calm = nil
      if p.st.frozen then action, cause = "eveille", why end
    elseif far and p.boxes and p.boxes.freeze then
      -- même règle que Gel.decide quand aucun joueur n'est à moins de FREEZE_R de la boîte de la faction (la boîte d'un poste y est)
      if not p.st.frozen then
        if type(p.st.calm) ~= "number" then p.st.calm = tick end
        if tick - p.st.calm >= Gel.CALM then action, cause = "fige", "loin et calme" end
      end
    else
      action, cause = Gel.decide(p.st, p.boxes, s, p, tick)
    end
    if action then out[#out + 1] = { id = p.id, action = action, cause = cause } end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Garnisons (Q7, L1_CRITERES.md §3.12) : un soldat est un poste ; ce qui suit dit s'il peut être figé
---------------------------------------------------------------------------------------------------
Gel.GARRISON_ROLES = { home = 18, guard = 4, patrol = 12 } -- rôles de garnison et rayon de marche autour du point (soldats.lua)
Gel.ARRIVED_MARGIN = 6     -- arrivé : à moins de rayon + 6 tuiles de son point
Gel.HAZARD_R = 42          -- menace au poste : ennemi mobile à moins de 30 (vision des soldats) + 12 (guet) tuiles du point
Gel.HQ_R = 60              -- menace au QG : 48 (SD.HQ_THREAT_R) + 12 tuiles
Gel.TURRET_MARGIN = 12     -- menace aux tourelles : portée de la tourelle + 12 tuiles

--- Le soldat peut-il être figé ? o = { is_player, group (vrai si un groupe le tient), role (nil = garnison au QG), health (0 à 1),
--- d (distance à son point), changed (son ordre a changé depuis le gel) }. Rend nil (apte) ou la raison (inapte : jamais figé, réveillé).
function Gel.soldier_unfit(o)
  if o.is_player then return "votre equipe" end
  if o.group then return "groupe" end
  local role = o.role or "home"
  local r = Gel.GARRISON_ROLES[role]
  if not r then return "mission" end
  if o.changed then return "ordre" end
  if type(o.health) ~= "number" or o.health < 0.999 then return "blesse" end
  if type(o.d) ~= "number" or o.d > r + Gel.ARRIVED_MARGIN then return "en route" end
  return nil
end

--- Point de poste d'un soldat : le point de son ordre (clé « rôle:x:y:aid » de shared/ai3/soldats.lua) ; sans ordre, sa place au QG.
function Gel.soldier_point(key, home)
  if type(key) == "string" then
    local _, _, x, y = key:find("^[%a_]+:(%-?%d+):(%-?%d+):")
    if x then return { x = tonumber(x) + 0.5, y = tonumber(y) + 0.5 } end
  end
  return home
end

return Gel
