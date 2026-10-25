--[[
  Accès à l'interface « Équipe et factions » (lot IA1-i, docs/EQUIPES_PNJ.md §8) :
    - un bouton dans la barre de raccourcis (ShortcutPrototype, action « lua », à bascule : allumé quand la fenêtre
      est ouverte) ;
    - une touche (CustomInputPrototype), Maj + T par défaut, modifiable dans Paramètres > Contrôles. Maj + T ne figure
      pas dans la liste des touches par défaut du jeu de base (T seul : arbre technologique ; Alt + T : télécommande
      d'artillerie) ; `consuming = "none"` : si un autre mod la prend aussi, les deux reçoivent la touche.
  Icônes : tools/gui/icones_ia1i.py (même format que celles du jeu de base : 32 px + mipmap, sombre et claire).
]]

local function icon(file, size)
  return {
    filename = "__factorio-overhaul__/graphics/gui/" .. file,
    priority = "extra-high-no-scale",
    size = size,
    scale = 0.5,
    mipmap_count = 2,
    flags = { "gui-icon" },
  }
end

data:extend({
  {
    type = "custom-input",
    name = "fo-team-gui",
    key_sequence = "SHIFT + T",
    consuming = "none",
    order = "b[fo-team-gui]",
  },
  {
    type = "shortcut",
    name = "fo-team-gui",
    -- Avant les raccourcis de plans (« b[blueprints] ») : visible sans faire défiler la barre (2 rangées de 6 à
    -- l'écran : un ordre en fin de liste le mettait sur une 3e rangée cachée, capture du 25/10).
    order = "a[fo-team]",
    action = "lua",
    toggleable = true,
    associated_control_input = "fo-team-gui",
    localised_name = { "shortcut-name.fo-team-gui" },
    icon = icon("team-x32.png", 32),
    small_icon = icon("team-x24.png", 24),
    disabled_icon = icon("team-x32-white.png", 32),
    disabled_small_icon = icon("team-x24-white.png", 24),
  },
})
