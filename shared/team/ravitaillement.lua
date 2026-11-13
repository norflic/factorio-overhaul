--[[
  Lot BLOCAGE-COMBUSTIBLE (8/11, mesure sur la sauvegarde du DC en 0.6.64, fo-logs/2026-11-08_BLOCAGE-COMBUSTIBLE/CRITERES.md) :
  le ravitaillement des BRULEURS des avant-postes (foreuses a combustion, fours). PUR : aucune API Factorio, aucun nom d'objet (le
  combustible, les quantites et les verdicts du stock arrivent en DONNEES) ; tests/ravitaillement_test.lua.

  Mesure : 22,8 % des releves de machines sont `no_fuel` (foreuses a combustion 5 537, fours 2 823 sur 36 695 releves) ; [FO-FLUX]
  « bruleurs vitaux 214 dont 133 a sec » (azure) avec 10 000 charbons au coffre ; [FO-CHARBON] « 126 bruleurs sur 131 sous 3 charbons
  apres la tournee » au meme avant-poste a 22 s puis 33 s d'ecart.

  Maillon manquant : Sm.carry_fuel (shared/team/sorties_main.lua, lot CHARBON-MAIN) deduit de ce que la tournee PORTE le charbon des
  coffres PROPRES de l'avant-poste de combustible (`need - own`), en comptant qu'elle le ramassera ; mais Outposts.service ramasse avec
  Stock.skip_fn (lot STOCKAGE-VITAL, C2 de DIAG_CONSO) qui ecarte le charbon, vital compris, quand le coffre du QG le tient deja au
  plafond (20 piles) : le charbon des coffres propres n'est ni porte ni ramasse, les bruleurs restent a sec, la tournee est refaite.
  Ce charbon-la ne va PAS au coffre du QG : il passe du coffre de l'avant-poste a ses bruleurs, sur place. Le plafond du coffre du QG
  ne le concerne pas.

  Regles :
    Rv.onsite_quota(need, carried)   combustible a prendre dans les coffres propres MEME si le stock refuse de le recevoir : ce qui
                                     manque aux bruleurs apres ce que le porteur a deja (jamais negatif).
    Rv.cause(a)                      verdict d'une tournee, pour le journal : "ok", "ramassage_ecarte", "coffre_sans_charbon",
                                     "porte_insuffisant", "autre".
    Rv.log_due(n)                    la n-ieme tournee courte d'un avant-poste est-elle ecrite au journal ?
    Rv.pause_until(a)                tournee FUTILE (des bruleurs restent bas et rien n'a ete pose) : tick avant lequel l'avant-poste
                                     n'est plus signale « a court de combustible » (pas de nouvelle tournee de ravitaillement) ; nil sinon.
    Rv.paused(until_tick, tick)      la pause court-elle encore ?
    Rv.field_burners(prev, rows)     lot COMBUSTIBLE (13/11) : fours d'un CHAMP (bandes du plan directeur) a ravitailler a la main par la
                                     tournee de leur avant-poste : ceux vus A SEC au releve, et ceux deja ravitailles a la main tant qu'ils
                                     sont debout. Mesure (v0.7.93, 4 graines, 120 min) : scarlet 271828182, 45 fours de champ sur 47 a sec de
                                     50 a 120 min avec 381 a 406 charbons au coffre du QG ; amber 314159265, 16 sur 16 de 35 a 90 min, QG
                                     perdu. Le reseau du charbon de la bande (projet lie, tout-ou-rien) attend des tapis que seul le fer de
                                     ces fours paierait (gardes croisees) ; aucune tournee ne les comptait (Outposts.burners).
  Determinisme : aucune table parcourue par pairs, aucun temps mesure.
]]

local Rv = {}

Rv.LOG_FIRST = 6   -- tournees courtes ecrites une a une par avant-poste
Rv.LOG_EVERY = 10  -- puis une sur dix
Rv.FUTILE_PAUSE = 3600 -- 60 s : mesure 0.6.64, la meme tournee futile revenait toutes les 22 a 33 s au meme avant-poste

local function num(x)
  if type(x) ~= "number" or x ~= x then return 0 end
  return x
end

--- Combustible a prendre dans les coffres propres d'un avant-poste, stock ou non : `need` = ce qui manque a ses bruleurs pour atteindre
--- le niveau de remplissage, `carried` = combustible deja dans le sac du porteur (pris au coffre du QG avant de partir).
function Rv.onsite_quota(need, carried)
  local q = num(need) - num(carried)
  if q < 0 then return 0 end
  return q - q % 1
end

--- a = { low_after = bruleurs encore sous le seuil bas apres la tournee, need = manque avant la tournee, carried = combustible dans le sac
---       au depart, took = combustible ramasse dans les coffres propres, left = combustible resté dans les coffres propres apres le
---       ramassage, skipped = le ramassage ecarte le combustible (Stock.skip_fn), stock = combustible libre au coffre du QG }.
function Rv.cause(a)
  if num(a.low_after) <= 0 then return "ok" end
  if num(a.left) > 0 and a.skipped == true then return "ramassage_ecarte" end
  if num(a.carried) + num(a.took) < num(a.need) then
    if num(a.stock) < num(a.need) - num(a.carried) - num(a.took) then return "coffre_sans_charbon" end
    return "porte_insuffisant"
  end
  return "autre"
end

--- n = rang (1, 2, ...) de la tournee courte de cet avant-poste.
function Rv.log_due(n)
  n = num(n)
  if n <= 0 then return false end
  if n <= Rv.LOG_FIRST then return true end
  return (n - Rv.LOG_FIRST) % Rv.LOG_EVERY == 0
end

--- a = { low_after = bruleurs encore bas apres la tournee, placed = combustible pose aux bruleurs, tick }.
function Rv.pause_until(a)
  if num(a.low_after) > 0 and num(a.placed) <= 0 then return num(a.tick) + Rv.FUTILE_PAUSE end
  return nil
end

function Rv.paused(until_tick, tick)
  if type(until_tick) ~= "number" or type(tick) ~= "number" then return false end
  return num(tick) < until_tick
end

--- Lot COMBUSTIBLE : fours d'un champ que la tournee de leur avant-poste ravitaille a la main. `rows` = fours a bruleur du champ debout au
--- releve, dans l'ordre du plan : { { id = numero d'unite, dry = vrai si le four est a l'arret faute de combustible } } ; `prev` = { [id] = vrai }
--- des fours deja ravitailles a la main. Rend la liste des id gardes, dans l'ordre de `rows`, sans doublon : un four a sec entre, un four deja
--- entre reste tant qu'il est debout (sa voie de charbon le tient au-dessus du seuil bas quand elle marche : aucune tournee n'en nait), un four
--- absent du releve (detruit, demonte) sort.
function Rv.field_burners(prev, rows)
  local keep, seen = {}, {}
  if type(prev) ~= "table" then prev = {} end
  if type(rows) ~= "table" then rows = {} end
  for i = 1, #rows do
    local r = rows[i]
    if type(r) == "table" and r.id ~= nil and not seen[r.id] and (r.dry == true or prev[r.id] == true) then
      seen[r.id] = true
      keep[#keep + 1] = r.id
    end
  end
  return keep
end

return Rv
