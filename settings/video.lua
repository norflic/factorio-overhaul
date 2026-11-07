--[[
  Réglages de la feuille de route « Factorio Automated » (lots VIDEO, fo-logs/2026-11-07_VIDEO-AUTOMATISATION/INTEGRATION_VIDEO.md),
  déclarés par l'intégrateur de video-integ sur délégation du lead (7/11). Étape settings uniquement ; requis par settings.lua.
  Tous ALLUMÉS par défaut depuis la 0.6.60 (ordre du DC du 7/11, 21 h 37 : « TOUTES les règles de la vidéo (L1 à L13 et la saturation)
  sont ALLUMÉES par défaut »). Leurs lecteurs gardent un repli à « éteint » quand le réglage MANQUE (moteur simulé des tests, qui ne les
  déclare pas : les suites gardent la décision d'avant ; chaque lot a son test allumé).

  fo-war-portes         lot L6 : portes avant d'étendre (shared/ai3/portes_extension.lua ; lu par Capi.portes,
                        script/ai3/capitalisation.lua). Traductions : locale/*/portes.cfg.
  fo-war-paliers        lot L10 : croissance par marches après 5 min de stabilité, variante B de C2 (shared/ai3/palier.lua ;
                        lu par Capi.paliers_on). Traductions : locale/*/paliers.cfg.
  fo-debug-trace-carte  lot L11 : étiquettes des décisions des factions sur la carte du joueur (script/ai3/trace_carte.lua).
                        Traductions : locale/*/trace.cfg (lot L11).
  fo-war-lots-minerai   lot L9 : les lots de gisement du treillis réservés au minerai (shared/team/lot_minerai.lua ;
                        script/team/lots_minerai_glue.lua). Traductions : locale/*/lots_minerai.cfg (lot L9).
  Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-portes",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-video-a",
  },
  {
    type = "bool-setting",
    name = "fo-war-paliers",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-video-b",
  },
  {
    type = "bool-setting",
    name = "fo-war-lots-minerai",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-video-c",
  },
  {
    type = "bool-setting",
    name = "fo-debug-trace-carte",
    setting_type = "runtime-global",
    default_value = true,
    order = "a-trace-carte",
  },
})
