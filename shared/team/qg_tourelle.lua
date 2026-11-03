--[[
  Lot QGSURVIE2 : la ligne de journal [FO-QG-TOURELLE] écrite à la mort d'une tourelle près du QG d'une équipe. PUR (aucune API Factorio,
  aucun nom d'objet), testé hors jeu par tests/qg_tourelle_test.lua (avec mutants).

  Question (lead, 3/11) : pourquoi 5 à 7 tourelles ARMÉES du QG (« hors de péril », 2 873 à 4 023 PV comptés par Sq.peril) tombent-elles
  en moins d'une minute devant 1 100 à 2 900 PV (verif-guide 1618033988, 4 parties sur 5 de 0.6.4x) ? Journal SEUL : rien dans la partie
  n'en dépend. Le script (script/team/qg_tourelle.lua) lit l'événement et le moteur et remplit un enregistrement de nombres et de noms :
    * la tourelle morte : côté du QG (8 secteurs, sans trigonométrie), distance, chargeurs restants, portée ;
    * la cause : nom, type, force, dégâts, distance de la cause à la tourelle et portée de son attaque ;
    * l'appui : tourelles de l'équipe (et armées) qui avaient la cause à portée ; tourelles du QG restantes (et armées) ;
    * la vague : unités ennemies à moins de Q.WAVE_R tuiles de la tourelle, par nom, et le côté de leur centre vu du QG.
]]
local Q = {}

Q.QG_R = 48      -- tuiles : une tourelle à moins de Q.QG_R du coffre est « du QG » (rayon de la menace du QG, T.hq_threat_radius)
Q.WAVE_R = 30    -- tuiles : unités ennemies comptées autour de la tourelle morte
-- tan(22,5°) ≈ 0,4142, en millièmes : secteur droit si |petit| <= 0,4142 × |grand|
Q.TAN_1000 = 414

--- Côté de (dx, dy) vu du QG, en 8 secteurs (y vers le bas = sud) ; « centre » à moins d'une tuile.
function Q.side(dx, dy)
  dx, dy = dx or 0, dy or 0
  local ax, ay = math.abs(dx), math.abs(dy)
  if ax < 1 and ay < 1 then return "centre" end
  local ns = dy < 0 and "N" or "S"
  local eo = dx < 0 and "O" or "E"
  if ay * 1000 <= Q.TAN_1000 * ax then return eo end
  if ax * 1000 <= Q.TAN_1000 * ay then return ns end
  return ns .. eo
end

--- Appui : liste de { dist (de la tourelle à la cause), range, rounds (nil : tourelle sans munitions, électrique ou à fluide) }. Rend le
--- nombre de tourelles qui avaient la cause à portée, et parmi elles les armées (munitions > 0, ou sans munitions : électriques, fluides).
function Q.support(list)
  local reach, armed = 0, 0
  for _, t in ipairs(list or {}) do
    if (t.dist or math.huge) <= (t.range or 0) then
      reach = reach + 1
      if t.rounds == nil or t.rounds > 0 then armed = armed + 1 end
    end
  end
  return reach, armed
end

--- Unités de la vague : { [nom] = n } -> chaîne « nom xN » triée par nom ; total.
function Q.units(by_name)
  local keys, total = {}, 0
  for k, n in pairs(by_name or {}) do keys[#keys + 1] = k; total = total + n end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = string.format("%s x%d", k, by_name[k]) end
  return (#parts > 0 and table.concat(parts, ", ") or "aucune"), total
end

local function f1(x) return string.format("%.1f", x or 0) end

--- La ligne. rec = { minute, team, name, dx, dy (tourelle - QG), rounds, range, cause = { name, type, force } ou nil, damage,
--- cause_dist, cause_range, support = liste (Q.support), qg_left, qg_armed (tourelles du QG restantes, armées), units = { [nom] = n },
--- wave_dx, wave_dy (centre de la vague - QG, nil sans unité) }.
function Q.line(rec)
  local reach, armed = Q.support(rec.support)
  local units, total = Q.units(rec.units)
  local cause = rec.cause and string.format("%s/%s/%s", tostring(rec.cause.name or "?"), tostring(rec.cause.type or "?"),
    tostring(rec.cause.force or "?")) or "inconnue"
  local cd = rec.cause_dist and f1(rec.cause_dist) or "?"
  local cr = rec.cause_range and f1(rec.cause_range) or "?"
  local wave = (rec.wave_dx and rec.wave_dy) and Q.side(rec.wave_dx, rec.wave_dy) or "-"
  local d = math.sqrt((rec.dx or 0) ^ 2 + (rec.dy or 0) ^ 2)
  return string.format(
    "[FO-QG-TOURELLE] %s minute %s | %s cote %s a %s tuiles du QG | chargeurs restants %s (portee %s) | cause %s, degats %s, a %s tuiles"
      .. " (portee de son attaque %s) | tourelles qui l'avaient a portee %d dont armees %d | QG restant %d tourelle(s) dont %d armee(s)"
      .. " | vague a %d tuiles : %d unite(s) [%s], centre cote %s",
    tostring(rec.team or "?"), f1(rec.minute), tostring(rec.name or "?"), Q.side(rec.dx, rec.dy), f1(d),
    rec.rounds and tostring(rec.rounds) or "?", rec.range and f1(rec.range) or "?", cause, tostring(rec.damage or "inconnu"), cd, cr,
    reach, armed, rec.qg_left or 0, rec.qg_armed or 0, Q.WAVE_R, total, units, wave)
end

return Q
