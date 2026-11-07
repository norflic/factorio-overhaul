--[[
  Réglages de la feuille de route « Factorio Automated » (lots VIDEO, fo-logs/2026-11-07_VIDEO-AUTOMATISATION/INTEGRATION_VIDEO.md),
  déclarés par l'intégrateur de video-integ sur délégation du lead (7/11). Étape settings uniquement ; requis par settings.lua. Tous
  ÉTEINTS par défaut : leurs lecteurs ont un repli à « éteint » quand le réglage manque (partie ou banc d'avant).

  fo-war-portes         lot L6 (étape 2c, allumée à l'étape 6) : portes avant d'étendre (shared/ai3/portes_extension.lua ; lu par
                        Capi.portes, script/ai3/capitalisation.lua). Traductions : locale/*/portes.cfg.
  fo-war-paliers        lot L10 (étape 7) : croissance par marches après 5 min de stabilité, variante B de C2 (shared/ai3/palier.lua ;
                        lu par Capi.paliers_on). Traductions : locale/*/paliers.cfg.
  fo-debug-trace-carte  lot L11 (étape 11) : étiquettes des décisions des factions sur la carte du joueur (script/ai3/trace_carte.lua).
                        Traductions : locale/*/trace.cfg (lot L11).
  fo-war-lots-minerai   lot L9 (étape 12) : les lots de gisement du treillis réservés au minerai (shared/team/lot_minerai.lua).
                        Traductions : locale/*/lots_minerai.cfg (lot L9).
  Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-portes",
    setting_type = "runtime-global",
    default_value = false,
    order = "e-war-z-video-a",
  },
  {
    type = "bool-setting",
    name = "fo-war-paliers",
    setting_type = "runtime-global",
    default_value = false,
    order = "e-war-z-video-b",
  },
  {
    type = "bool-setting",
    name = "fo-war-lots-minerai",
    setting_type = "runtime-global",
    default_value = false,
    order = "e-war-z-video-c",
  },
  {
    type = "bool-setting",
    name = "fo-debug-trace-carte",
    setting_type = "runtime-global",
    default_value = false,
    order = "a-trace-carte",
  },
})
