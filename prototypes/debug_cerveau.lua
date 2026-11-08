--[[
  Lot DEBUG-CERVEAU : accès à la vue « Cerveau » (script/debug/cerveau.lua) : un bouton de la barre de raccourcis (à bascule, allumé quand la
  vue est ouverte) et une touche (Ctrl + Maj + B par défaut, modifiable dans Paramètres > Contrôles ; consuming = "none"). À ajouter par
  l'intégrateur : require("prototypes.debug_cerveau") dans data.lua.
  ICÔNE PROVISOIRE : l'icône du mode Alt du jeu de base (aucune icône propre au mod n'existe pour cette vue ; à remplacer si le DC valide
  la vue, comme tout visuel).
]]
local function icon(file, size)
  return {
    filename = "__base__/graphics/icons/shortcut-toolbar/mip/" .. file,
    priority = "extra-high-no-scale",
    size = size,
    mipmap_count = 2,
    flags = { "gui-icon" },
  }
end

data:extend({
  {
    type = "custom-input",
    name = "fo-dbg-cerveau",
    key_sequence = "CONTROL + SHIFT + B",
    consuming = "none",
    order = "b[fo-dbg-cerveau]",
  },
  {
    type = "shortcut",
    name = "fo-dbg-cerveau",
    order = "a[fo-team]-c[cerveau]",
    action = "lua",
    toggleable = true,
    associated_control_input = "fo-dbg-cerveau",
    localised_name = { "shortcut-name.fo-dbg-cerveau" },
    icon = icon("alt-mode-x32.png", 32),
    small_icon = icon("alt-mode-x24.png", 24),
    disabled_icon = icon("alt-mode-x32.png", 32),
    disabled_small_icon = icon("alt-mode-x24-white.png", 24),
  },
})
