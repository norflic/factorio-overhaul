--[[
  Lot TV-PILOTE, point W04 de docs/TODO_VIDEO.md (§G, « une garde sans mesure se prouve ou se retire ») : l'INVENTAIRE des gardes en
  CODE. Données pures (aucune API Factorio, aucun nom d'objet du jeu), testées hors jeu par tests/gardes_inventaire_test.lua, qui appelle
  chaque garde RÉELLE avec sa mesure manquante et compare le résultat à l'entrée du tableau (un tableau sans preuve ne vaut rien).

  Leçon de la vidéo (V2 0:56-2:36, les « silos sans fin ») : une garde lisait le signal d'un mod absent, l'entrée valait 0, la condition
  « en manque » restait vraie. Deux polarités, deux sens sûrs :
    permission  la garde AUTORISE une action (poser, étendre, admettre, retirer une tournée) : mesure absente = action REFUSÉE, avec un
                refus écrit qui nomme l'entrée manquante (état « ferme »).
    retenue     la garde RETIENT une action déjà permise (pile de priorité, saturation d'un stock) : mesure absente = pas de retenue
                (état « ouvre-voulu »), car retenir sur une mesure absente gèlerait aussi les familles vitales ; la DÉCISION est écrite ici
                (champ `raison`) et le test la fixe.
  États :
    ferme       mesure absente -> refus ; `refus` = fragment du texte renvoyé (le test le cherche dans la raison rendue) ;
    ouvre-voulu mesure absente -> la garde ne retient pas, par décision écrite (`raison`) ;
    retiree     garde supprimée du code (orpheline) ; `raison` dit où est le chemin réel.

  Chaque entrée : id (alias du module + fonction), fichier, polarite, mesure (ce que la garde lit), etat, refus ou raison, lot, appelant
  (le maillon de la décision qui la lit : fonction, pas de numéro de ligne).
]]

local Gd = {}

Gd.STATES = { ferme = true, ["ouvre-voulu"] = true, retiree = true }
Gd.POLARITIES = { permission = true, retenue = true }

Gd.LIST = {
  -- Pf : plafonds (lot VIDEO-L13)
  { id = "Pf.input", file = "shared/ai3/plafonds.lua", polarite = "permission", mesure = "toute entrée numérique d'une garde (demande, posé, ouvert, kW)",
    etat = "ferme", refus = "entree absente", lot = "VIDEO-L13", appelant = "Pf.fits, Pf.test, Pf.room, Pf.kind_room" },
  { id = "Pf.fits", file = "shared/ai3/plafonds.lua", polarite = "permission", mesure = "demand, posed, open, n_posed, n_open, add.rate, add.n, hard",
    etat = "ferme", refus = "entree absente", lot = "VIDEO-L13", appelant = "Ca.decide (cap_ok)" },
  { id = "Pf.fits_item", file = "shared/ai3/plafonds.lua", polarite = "permission", mesure = "registre J.caps de la décision (objet présent)",
    etat = "ferme", refus = "aucun releve", lot = "VIDEO-L13", appelant = "Ca.decide (cap_ok)" },
  { id = "Pf.open_room", file = "shared/ai3/plafonds.lua", polarite = "permission", mesure = "liste des ordres ouverts",
    etat = "ferme", refus = "entree absente", lot = "VIDEO-L13", appelant = "Ca.start (plafond des ordres ouverts)" },
  { id = "Pf.power_missing", file = "shared/ai3/plafonds.lua", polarite = "permission", mesure = "power.have_kw d'une centrale finie",
    etat = "ferme", refus = "entree absente : power.have_kw", lot = "VIDEO-COUVERTURE 5 (W02)", appelant = "Ca.decide (options électriques)" },
  { id = "Pf.kind_room", file = "shared/ai3/plafonds.lua", polarite = "permission", mesure = "unités voulues, unités posées ou ouvertes (sorte plafonnée)",
    etat = "ferme", refus = "entree absente", lot = "VIDEO-PLAFONDS", appelant = "Pf.gate (Ca.options)" },
  -- Pe : portes d'extension (lot VIDEO-L6 ; 0.6.62 : W04 n°1)
  { id = "Pe.transport", file = "shared/ai3/portes_extension.lua", polarite = "permission", mesure = "workers, idle, free_tasks (transport)",
    etat = "ferme", refus = "mesure absente", lot = "VIDEO-L6", appelant = "Capi.portes (Pe.filter)" },
  { id = "Pe.site_room", file = "shared/ai3/portes_extension.lua", polarite = "permission", mesure = "batis (modules posés), open_sites (chantiers ouverts)",
    etat = "ferme", refus = "mesure absente", lot = "5b (W04 n°1)", appelant = "Capi.portes (Pe.gate)" },
  -- S : santé de la centrale (0.6.62 : W04 n°2)
  { id = "S.admit", file = "shared/team/sante_centrale.lua", polarite = "permission", mesure = "capacity et used d'une centrale FINIE",
    etat = "ferme", refus = "capacity", lot = "5b (W04 n°2)", appelant = "script/team/sante_centrale.lua (admission d'un module)" },
  -- Fx : flux (0.6.62 : W04 n°4)
  { id = "Fx.drop_service", file = "shared/team/flux.lua", polarite = "permission", mesure = "o.stuck (sorties bloquées de l'avant-poste)",
    etat = "ferme", refus = "non mesurees", lot = "5b (W04 n°4)", appelant = "C.think (tournées retirées)" },
  -- D : danger (0.6.62 : W04 n°5)
  { id = "D.gate", file = "shared/ai3/danger.lua", polarite = "permission", mesure = "max_d, goal_d, deaths ou blocked (une lecture au moins)",
    etat = "ferme", refus = "danger non lu", lot = "5b (W04 n°5)", appelant = "script/ai3/comportement.lua (porte des tâches)" },
  -- Ic : îlots de croissance (0.6.62 : W04 n°6)
  { id = "Ic.gate", file = "shared/team/ilots_croissance.lua", polarite = "permission", mesure = "info.threatened, islands, max, unwalled, unguarded, outside_busy, main_busy",
    etat = "ferme", refus = "mesure absente", lot = "5b (W04 n°6)", appelant = "script/team/build.lua (croissance des îlots)" },
  -- Lm : lots de minerai (lot VIDEO-L9 ; TV-PILOTE : rôle absent fermé)
  { id = "Lm.allows", file = "shared/team/lot_minerai.lua", polarite = "permission", mesure = "role du lot (minerai ou general) et sorte du module",
    etat = "ferme", refus = "garde fermee", lot = "TV-PILOTE (W04 n°8)", appelant = "script/team/lots_minerai_glue.lua (placement d'un module)" },
  { id = "Lm.states_for", file = "shared/team/lot_minerai.lua", polarite = "permission", mesure = "sorte du module",
    etat = "ferme", refus = "", lot = "VIDEO-L9", appelant = "script/team/build.lua (états de lots essayés)" },
  -- Pl : paliers (lot VIDEO-L10)
  { id = "Pl.stable", file = "shared/ai3/palier.lua", polarite = "permission", mesure = "manques, bras_libres (nombres), crise (booléen)",
    etat = "ferme", refus = "garde fermee", lot = "VIDEO-L10", appelant = "Capi.palier_inputs (Pl.step)" },
  -- Cf : confirmation (lot VIDEO-L5)
  { id = "Cf.engage", file = "shared/ai3/confirmation.lua", polarite = "permission", mesure = "id de l'unité, objet, tick",
    etat = "ferme", refus = "sans id valide", lot = "VIDEO-L5", appelant = "script/ai3/capitalisation.lua (conf_track)" },
  { id = "Cf.step", file = "shared/ai3/confirmation.lua", polarite = "permission", mesure = "carnet et tick de l'observation",
    etat = "ferme", refus = "tick absent", lot = "VIDEO-L5", appelant = "script/ai3/capitalisation.lua (relevé)" },
  { id = "Cf.counts", file = "shared/ai3/confirmation.lua", polarite = "permission", mesure = "unité suivie au carnet (confirmée)",
    etat = "ferme", refus = "", lot = "VIDEO-L5", appelant = "script/ai3/capitalisation.lua (conf_group)" },
  -- Retenues : mesure absente = pas de retenue, par décision écrite
  { id = "Pi.allows", file = "shared/ai3/pile.lua", polarite = "retenue", mesure = "pile de priorité (st.hold, st.top)",
    etat = "ouvre-voulu", lot = "PILE-PRIORITE (W04 n°7)", appelant = "C.think (filtre des buts)",
    raison = "la pile RETIENT les améliorations ; absente (ou sans retenue), rien n'est retenu : retenir sur une pile absente gèlerait aussi les familles vitales. Le cerveau crée toujours st.pile (Pi.new)." },
  { id = "B.saturated", file = "shared/ai3/buts.lua", polarite = "retenue", mesure = "s.stock[objet]",
    etat = "ouvre-voulu", lot = "5b (W04 n°3)", appelant = "B.generate (frein d'extraction)",
    raison = "un objet ABSENT du stock vaut 0 (le moteur n'énumère pas les objets à zéro, get_contents) : pas saturé, l'extraction continue ; ce n'est pas une mesure manquante." },
  { id = "Sa.holds", file = "shared/ai3/saturation.lua", polarite = "retenue", mesure = "drain (fonte mesurée du stock)",
    etat = "ouvre-voulu", lot = "VIDEO-SAT", appelant = "B.saturated",
    raison = "sans fonte mesurée (drain absent), la saturation se juge sur le seuil seul, comme avant le lot : une pente inventée vaudrait moins." },
  { id = "Qt.feed_ok", file = "shared/team/quotas.lua", polarite = "permission", mesure = "counts (objets au coffre de sortie borné)",
    etat = "ouvre-voulu", lot = "VIDEO-COUVERTURE 3 (C11)", appelant = "script/team/build.lua (quai_tasks)",
    raison = "un module sans coffre de sortie borné (centrale, sortie en tapis) est toujours alimenté ; un coffre absent n'est pas compté ; la collecte n'est jamais retenue." },
  -- Retirée
  { id = "Q.filter", file = "shared/team/quotas.lua", polarite = "permission", mesure = "verdicts des quotas",
    etat = "retiree", lot = "TV-PILOTE (W04 n°10)", appelant = "aucun",
    raison = "garde ORPHELINE (aucun appelant à l'exécution) : retirée ; le chemin réel est Qt.feed_ok, appelé par script/team/build.lua." },
}

--- Contrôle de forme du tableau : chaque entrée a un id unique, une polarité et un état connus, un fichier, une mesure, un lot ; un
--- état « ferme » écrit son refus (fragment de texte, vide permis seulement pour un booléen de présence) ; « ouvre-voulu » et « retiree »
--- écrivent leur raison. Rend la liste des défauts (vide si tout va bien).
function Gd.validate(list)
  local bad, seen = {}, {}
  for i, g in ipairs(list or Gd.LIST) do
    local who = tostring(g.id or ("#" .. i))
    if type(g.id) ~= "string" or g.id == "" then bad[#bad + 1] = who .. " : id absent"
    elseif seen[g.id] then bad[#bad + 1] = who .. " : id en double" end
    seen[tostring(g.id)] = true
    if not Gd.STATES[g.etat or ""] then bad[#bad + 1] = who .. " : etat inconnu" end
    if not Gd.POLARITIES[g.polarite or ""] then bad[#bad + 1] = who .. " : polarite inconnue" end
    for _, k in ipairs({ "file", "mesure", "lot", "appelant" }) do
      if type(g[k]) ~= "string" or g[k] == "" then bad[#bad + 1] = who .. " : " .. k .. " absent" end
    end
    if g.etat == "ferme" and type(g.refus) ~= "string" then bad[#bad + 1] = who .. " : refus ecrit absent" end
    if (g.etat == "ouvre-voulu" or g.etat == "retiree") and (type(g.raison) ~= "string" or #g.raison < 20) then
      bad[#bad + 1] = who .. " : raison ecrite absente"
    end
    if g.etat == "ouvre-voulu" and g.polarite == "permission" and #(g.raison or "") < 60 then
      bad[#bad + 1] = who .. " : une garde de permission ouverte sans mesure doit dire pourquoi (60 caracteres au moins)"
    end
  end
  return bad
end

--- Décompte par état, ligne du journal [FO-GARDES] (écrite une fois par session par le runtime, aucune décision ne la lit).
function Gd.counts(list)
  local c = { total = 0, ferme = 0, ["ouvre-voulu"] = 0, retiree = 0 }
  for _, g in ipairs(list or Gd.LIST) do
    c.total = c.total + 1
    c[g.etat] = (c[g.etat] or 0) + 1
  end
  return c
end

function Gd.summary(list)
  local c = Gd.counts(list)
  return string.format("%d garde(s) inventoriee(s) : %d fermee(s) sans mesure (refus ecrit), %d ouverte(s) par decision ecrite, %d retiree(s)",
    c.total, c.ferme, c["ouvre-voulu"], c.retiree)
end

return Gd
