-- Lot CORR-RALLIEMENT (EFFONDREMENT, 5/11) : 5 mitrailleurs de faction (fo-amber-gunner : portee d'attaque 20, boite a boite ;
-- 0,11 tuile/tick) chargent le QG de votre equipe, entoure de 8 mitrailleuses (portee 18). Ils tuent les tourelles hors de leur
-- portee, comme dans la partie du DC rejouee (graine 717152950 : tourelles du QG tuees depuis 20,9 et 21,2 tuiles). Anneau de rayon
-- 12 : le point de ralliement (centre des tourelles vivantes) recule a mesure que les tourelles de l'est meurent, et les PNJ qui s'y
-- rallient passent a portee des mitrailleurs. Critères ECRITS AVANT : fo-logs/2026-11-05_EFFONDREMENT/CRITERES.md (M0 a M4).
-- scenarios/ia3k_vague_common.lua (options facultatives) ; deux bancs sur la MEME source : effondrement-mitrailleurs-temoin
-- (regle eteinte) puis effondrement-mitrailleurs (regle allumee).
local RING = { { 12, 0 }, { 8, 8 }, { 0, 12 }, { -8, 8 }, { -12, 0 }, { -8, -8 }, { 0, -12 }, { 8, -8 } }
return function(temoin)
  local opts = { unit = "fo-amber-gunner", n = 5, turrets = RING, kills_min = 0, outrange = not temoin,
    description = "EFFONDREMENT : vague de mitrailleurs qui debordent les tourelles du QG (" .. (temoin and "temoin, regle eteinte" or "lot") .. ")" }
  if temoin then
    opts.lost_min = 4
    opts.turret_far = 18
    opts.hq_expect = { hq_outranged = "zero", hq_rally = "pos" }
  else
    opts.hq_expect = { hq_outranged = "pos", hq_rally = "zero", hq_away = "pos" }
  end
  return require("scenarios/ia3k_vague_common")(opts)
end
