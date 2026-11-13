--[[
  Lot s43 UX-COMMANDE : l'OUTIL DE COMMANDEMENT du joueur (script/gui/commande.lua ; règles : shared/ai3/commande.lua).
    glisser (bouton gauche)   -> gisement à coloniser tout de suite (minerais seulement) ;
    Maj + glisser             -> liaison prioritaire (une zone) ;
    bouton droit              -> annuler les ordres de la zone.
  Mis en main par le panneau de commandement (bouton de la barre du haut) ; jamais dans l'inventaire.
]]

local function colour(r, g, b) return { r = r, g = g, b = b, a = 0.5 } end
local GREEN, BLUE, RED = colour(0.25, 0.85, 0.35), colour(0.3, 0.6, 1), colour(0.9, 0.25, 0.2)

data:extend({
  {
    type = "selection-tool", name = "fo-commande-outil",
    localised_name = { "item-name.fo-commande-outil" }, localised_description = { "item-description.fo-commande-outil" },
    icons = { { icon = "__base__/graphics/icons/upgrade-planner.png", icon_size = 64, icon_mipmaps = 4, tint = { r = 0.55, g = 1, b = 0.6 } } },
    flags = { "hidden", "only-in-cursor", "spawnable" }, subgroup = "tool", order = "z[fo-commande]", stack_size = 1,
    selection_color = GREEN, alt_selection_color = BLUE, reverse_selection_color = RED, alt_reverse_selection_color = RED,
    chart_selection_color = GREEN, chart_alt_selection_color = BLUE, chart_reverse_selection_color = RED, chart_alt_reverse_selection_color = RED,
    selection_count_button_color = GREEN, alt_selection_count_button_color = BLUE,
    reverse_selection_count_button_color = RED, alt_reverse_selection_count_button_color = RED,
    selection_cursor_box_type = "entity", alt_selection_cursor_box_type = "copy",
    reverse_selection_cursor_box_type = "not-allowed", alt_reverse_selection_cursor_box_type = "not-allowed",
    selection_mode = { "any-entity" }, entity_type_filters = { "resource" },
    alt_selection_mode = { "nothing" }, reverse_selection_mode = { "nothing" }, alt_reverse_selection_mode = { "nothing" },
  },
})
