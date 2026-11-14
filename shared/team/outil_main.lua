--[[
  s46 crash : mettre un outil (objet `name`) dans la main d'un joueur sans lever d'erreur Lua (règle pure, objets du jeu en duck typing).
  Om.give(player, name, known) -> "ok" | "deja" | raison du refus
    - known : vrai si le prototype d'objet existe (lu par l'appelant dans game.item_prototypes) ;
    - joueur absent ou invalide, prototype absent, main absente (cursor_stack nil : contrôleur sans curseur) : refus, rien ne change ;
    - l'outil déjà en main : rien ne change (« deja ») ;
    - clear_cursor refusé (inventaire plein) : refus, l'objet en main reste en main.
]]
local Om = {}

function Om.give(player, name, known)
  if not (player and player.valid) then return "joueur" end
  if not (name and known) then return "prototype" end
  local cs = player.cursor_stack
  if not (cs and cs.valid) then return "main" end
  if cs.valid_for_read and cs.name == name then return "deja" end
  if not player.clear_cursor() then return "inventaire" end
  cs = player.cursor_stack
  if not (cs and cs.valid) then return "main" end
  if not cs.set_stack({ name = name, count = 1 }) then return "pose" end
  return "ok"
end

return Om
