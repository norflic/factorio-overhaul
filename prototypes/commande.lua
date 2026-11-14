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

-- Lot s45 OUTILS : un outil par action (glisser = l'action ; bouton droit = annuler les ordres de la zone), chacun avec son raccourci.
--   fo-cmd-gisement (Maj + A), fo-cmd-amelioration (Maj + Z), fo-cmd-liaison (Maj + E : glisser = point A, Maj + glisser = point B,
--   ou deux glisser successifs), fo-cmd-bastion (Maj + R). L'ancien fo-commande-outil reste (compatibilité).
local TOOLS = {
  { name = "fo-cmd-gisement", key = "SHIFT + A", c = GREEN, tint = { r = 0.4, g = 1, b = 0.45 }, mode = { "any-entity" }, filter = true },
  { name = "fo-cmd-amelioration", key = "SHIFT + Z", c = colour(1, 0.75, 0.2), tint = { r = 1, g = 0.8, b = 0.3 }, mode = { "nothing" } },
  { name = "fo-cmd-liaison", key = "SHIFT + E", c = BLUE, tint = { r = 0.4, g = 0.65, b = 1 }, mode = { "nothing" } },
  { name = "fo-cmd-bastion", key = "SHIFT + R", c = colour(0.85, 0.3, 0.85), tint = { r = 0.95, g = 0.4, b = 0.95 }, mode = { "nothing" } },
}
for i, t in ipairs(TOOLS) do
  local alt = t.name == "fo-cmd-liaison" and BLUE or t.c
  data:extend({
    {
      type = "selection-tool", name = t.name,
      localised_name = { "item-name." .. t.name }, localised_description = { "item-description." .. t.name },
      icons = { { icon = "__base__/graphics/icons/upgrade-planner.png", icon_size = 64, icon_mipmaps = 4, tint = t.tint } },
      flags = { "hidden", "only-in-cursor", "spawnable" }, subgroup = "tool", order = "z[fo-commande]-" .. i, stack_size = 1,
      selection_color = t.c, alt_selection_color = alt, reverse_selection_color = RED, alt_reverse_selection_color = RED,
      chart_selection_color = t.c, chart_alt_selection_color = alt, chart_reverse_selection_color = RED, chart_alt_reverse_selection_color = RED,
      selection_count_button_color = t.c, alt_selection_count_button_color = alt,
      reverse_selection_count_button_color = RED, alt_reverse_selection_count_button_color = RED,
      selection_cursor_box_type = "entity", alt_selection_cursor_box_type = "copy",
      reverse_selection_cursor_box_type = "not-allowed", alt_reverse_selection_cursor_box_type = "not-allowed",
      selection_mode = t.mode, entity_type_filters = t.filter and { "resource" } or nil,
      -- s46 outils : Maj + glisser (on garde Maj enfoncée après Maj + A) sélectionne comme le glisser simple (le gestionnaire du slot 2 fait
      -- la même action) : avant, « nothing » rendait une sélection vide et l'ordre de gisement était refusé (« aucun minerai »).
      alt_selection_mode = t.mode, alt_entity_type_filters = t.filter and { "resource" } or nil,
      reverse_selection_mode = { "nothing" }, alt_reverse_selection_mode = { "nothing" },
    },
    -- s46 outils : « game-only » : la touche ne fait plus AUSSI l'action du jeu (Maj + R tournait en sens inverse l'objet en main).
    { type = "custom-input", name = t.name .. "-touche", key_sequence = t.key, consuming = "game-only", action = "lua" },
  })
end
