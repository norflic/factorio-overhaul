-- Lot CORR-RALLIEMENT (EFFONDREMENT, 5/11) : 5 mitrailleurs de faction (fo-amber-gunner : portee d'attaque 20, boite a boite ;
-- 0,11 tuile/tick) chargent le QG de votre equipe, entoure de 8 mitrailleuses (portee 18). Ils tuent les tourelles hors de leur
-- portee, comme dans la partie du DC rejouee (graine 717152950 : tourelles du QG tuees depuis 20,9 et 21,2 tuiles). Anneau de rayon
-- 12 : le point de ralliement (centre des tourelles vivantes) recule a mesure que les tourelles de l'est meurent, et les PNJ qui s'y
-- rallient passent a portee des mitrailleurs. Critères ECRITS AVANT : fo-logs/2026-11-05_EFFONDREMENT/CRITERES.md (M0 a M4).
-- scenarios/ia3k_vague_common.lua (options facultatives) ; deux bancs sur la MEME source : effondrement-mitrailleurs-temoin
-- (regle eteinte) puis effondrement-mitrailleurs (regle allumee).
-- 7/11 (0.6.59, decision du lead) : `v` facultatif = { unit = nom de l'unite (defaut fo-amber-gunner), seuils = false (temoin sans
-- lost_min ni turret_far : premiere mesure d'une unite), hq_expect = controles du lot (defaut : debordement, eloignement, aucun
-- ralliement) }. Sans `v`, le scenario est celui du 5/11, a l'identique.
local RING = { { 12, 0 }, { 8, 8 }, { 0, 12 }, { -8, 8 }, { -12, 0 }, { -8, -8 }, { 0, -12 }, { 8, -8 } }
return function(temoin, v)
  v = v or {}
  local unit = v.unit or "fo-amber-gunner"
  local opts = { unit = unit, n = 5, turrets = RING, kills_min = 0, outrange = not temoin,
    description = (v.unit and ("EFFONDREMENT : vague de " .. unit .. " contre les tourelles du QG (")
      or "EFFONDREMENT : vague de mitrailleurs qui debordent les tourelles du QG (") .. (temoin and "temoin, regle eteinte" or "lot") .. ")" }
  if temoin then
    if v.seuils ~= false then
      opts.lost_min = 4
      opts.turret_far = 18
    else
      -- (8/11) « sans seuil » : sans lost_free, ia3k_vague_common appliquait son defaut « PNJ perdus <= 2 » au temoin
      opts.lost_free = true
    end
    opts.hq_expect = { hq_outranged = "zero", hq_rally = "pos" }
  else
    opts.hq_expect = v.hq_expect or { hq_outranged = "pos", hq_rally = "zero", hq_away = "pos" }
  end
  return require("scenarios/ia3k_vague_common")(opts)
end
