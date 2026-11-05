--[[
  Lot PANNEAU (4/11) : QUAND le panneau « Évolution » (script/levels/panel.lua) s'ouvre et se ferme. Lua pur, testé hors jeu
  (tests/levels_panneau_cases.lua, joué par tests/levels_test.lua).

  Demande du DC (4/11, vers 19 h 40), mot pour mot : « Aussi pour les pop-ups d'améliorations ou autre, dès que le curseur
  passe sur un truc, c'est ultra chiant. Il faudrait que ce soit déclenchable ou même dans l'interface uniquement quand on
  clique sur le bâtiment concerné. »

  Réglage par joueur `fo-levels-panneau` (settings/levels_panneau.lua) :
    « clic » (défaut)  le survol n'ouvre plus rien ; un clic gauche sur un bâtiment à niveaux de votre force ouvre son panneau
                       (fo-level-open, avec ou sans interface : murs, lasers…) ; ouvert avec l'interface du bâtiment, il se
                       ferme avec elle ; la touche U améliore le bâtiment survolé SANS ouvrir le panneau ; Maj+U
                       (fo-level-panel) ouvre ou ferme le panneau du bâtiment survolé.
    « survol »         le comportement d'avant, inchangé (survol et U ouvrent le panneau, qui reste affiché) ; Maj+U marche aussi.

  P.decide(déclencheur, état) -> action, via
    déclencheurs : "hover" (le curseur passe sur un bâtiment), "click" (clic gauche sur un bâtiment : touche fo-level-open liée
                   à la commande « open-gui », avec ou sans interface), "gui-opened", "gui-closed" (interface d'un bâtiment),
                   "key-up" (touche U), "key-panel" (Maj+U), "tick" (rafraîchissement périodique), "replaced" (juste après une
                   action qui a pu remplacer la cible : amélioration, réparation de l'épave).
    état         : mode ("clic" | "survol"), open (le panneau est ouvert), has (le déclencheur porte sur un bâtiment à niveaux
                   de la force du joueur), same (ce bâtiment est la cible du panneau), via (comment le panneau a été ouvert :
                   "gui", "click", "key", "hover", nil pour un panneau d'une sauvegarde d'avant = survol), bound (l'interface
                   ouverte du joueur est la cible ; lu pour via "gui" seulement), upgrading (une amélioration du joueur est en
                   cours : le remplacement peut fermer l'interface de l'ANCIENNE entité, encore valide, avant que la cible
                   suive la nouvelle ; relecture de dcccb525, R1).
    actions      : "open" (+ via), "close", "refresh", "reopen" (rouvrir l'interface de la cible remplacée), "none".
  Le clic et l'interface arrivent dans les deux ordres (doc 1.1.91 : une touche non consommée passe AVANT l'événement du jeu) :
  un clic sur la cible déjà montrée ne change rien (jamais de bascule), l'interface ouverte rattache le panneau à elle.
]]

local P = {}

P.SETTING = "fo-levels-panneau"
P.CLIC = "clic"
P.SURVOL = "survol"
P.VALUES = { P.CLIC, P.SURVOL }
P.DEFAULT = P.CLIC

--- Mode d'une valeur du réglage : toute valeur inconnue vaut le défaut (« clic »).
function P.mode_of(value)
  if value == P.SURVOL then return P.SURVOL end
  return P.CLIC
end

local function hover(st)
  if st.mode ~= P.SURVOL or not st.has then return "none" end
  if st.open and st.same then return "none" end
  return "open", "hover"
end

local function gui_opened(st)
  if st.mode ~= P.CLIC or not st.has then return "none" end
  return "open", "gui"
end

--- Clic gauche sur un bâtiment à niveaux (en « clic ») : ouvre son panneau, qu'il ait une interface ou non ; la cible déjà
--- montrée ne bouge pas (l'interface, si elle s'ouvre aussi, garde ou prend le panneau). En « survol » : rien (comportement
--- d'avant inchangé).
local function click(st)
  if st.mode ~= P.CLIC or not st.has then return "none" end
  if st.open and st.same then return "none" end
  return "open", "click"
end

local function gui_closed(st)
  if st.upgrading then return "none" end
  if st.open and st.via == "gui" and st.same then return "close" end
  return "none"
end

--- Touche U : l'amélioration se fait toujours (script) ; en « survol », elle ouvre le panneau du bâtiment comme avant ; en
--- « clic », elle ne fait que rafraîchir un panneau déjà ouvert (le stock a pu changer).
local function key_up(st)
  if not st.has then return "none" end
  if st.mode == P.SURVOL then return "open", "hover" end
  if st.open then return "refresh" end
  return "none"
end

--- Maj+U : bascule le panneau du bâtiment survolé ; sans bâtiment survolé, ferme le panneau ouvert.
local function key_panel(st)
  if not st.has then return st.open and "close" or "none" end
  if st.open and st.same then return "close" end
  return "open", "key"
end

local function tick(st)
  if not st.open then return "none" end
  if st.via == "gui" then return st.bound and "refresh" or "close" end
  if st.mode == P.CLIC and st.via ~= "key" and st.via ~= "click" then return "close" end
  return "refresh"
end

local function replaced(st)
  if st.open and st.via == "gui" and not st.bound then return "reopen" end
  return "none"
end

local RULES = {
  hover = hover,
  click = click,
  ["gui-opened"] = gui_opened,
  ["gui-closed"] = gui_closed,
  ["key-up"] = key_up,
  ["key-panel"] = key_panel,
  tick = tick,
  replaced = replaced,
}

function P.decide(trigger, st)
  local rule = RULES[trigger]
  if not rule then error("panneau : déclencheur inconnu " .. tostring(trigger)) end
  return rule(st)
end

return P
