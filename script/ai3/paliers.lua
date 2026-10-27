--[[
  Lot IA-G : paliers de recherche de la section IA3 (docs/IA3_CERVEAU.md §6.1 ; critère A1 de docs/IA_ATTENDUS.md),
  MESURE SEULEMENT : lus par Ia3.measure (script/ai3/cerveau.lua) pour écrire « palier k atteint » au journal et dans
  f.team.ia3m (interface « fo-ia3c » des bancs). Déplacés ici depuis script/ai3/cerveau.lua (Ia3.PALIERS, sans
  changement). Le test anti-échelle (tests/iag_test.lua §8) exempte ce fichier et vérifie qu'aucune autre fonction que
  Ia3.measure ne lit ces paliers : aucune décision n'en dépend.
]]
return {
  LIST = {
    { tech = "automation", pack = "automation-science-pack", n = 10 },
    { tech = "logistic-science-pack", pack = "logistic-science-pack", n = 10 },
    { tech = "military-science-pack", pack = "military-science-pack", n = 10 },
    { tech = "chemical-science-pack", pack = "chemical-science-pack", n = 40 },
  },
}
