-- Lot CORR-RALLIEMENT (tenue, 7/11, 0.6.59) : la meme vague de grenadiers, regle du debordement ETEINTE (temoin). Premiere mesure de
-- cette unite : morts lues SANS seuil (pas de lost_min ni de turret_far) ; controles : aucun debordement juge, ralliement.
return require("scenarios/effondrement_mitrailleurs_common")(true, { unit = "fo-amber-rocketeer", seuils = false })
