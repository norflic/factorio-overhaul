-- Exemple de paramètres de VITRINE, entités vanilla uniquement (format complet : tools/autotest/README.md).
-- Pour vos entités : copier ce fichier en <racine>\fo-vitrine.lua, le modifier, puis lancer
-- fo-captures.bat vitrine [source du mod]. Sans <racine>\fo-vitrine.lua, c'est cet exemple qui sert.
return {
  sol = "concrete",            -- tuile vanilla sous la vitrine, décor retiré (défaut : concrete)
  entites = {
    { name = "assembling-machine-3", recette = "iron-gear-wheel" },        -- machine qui fabrique
    { name = "electric-furnace", contenu = { { "iron-ore", 50 } } },        -- four électrique allumé
    "radar",                                                               -- forme simple : le nom seul
    { name = "flamethrower-turret", direction = "east" },                  -- orientation
  },
  gros_plans = { 2 },          -- zooms des gros plans (2 = résolution native des sprites HR)
  alt_mode = false,            -- icônes « Alt » sur les captures
  anti_alias = false,          -- false : pixels comme en jeu
}
