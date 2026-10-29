--[[
  Lot INSTRUMENT-CENTRALE : la ligne de journal [FO-CENTRALE-MORT] écrite à la mort d'une pièce de centrale d'équipe. PUR (aucune API
  Factorio, aucun nom d'objet), testé hors jeu par tests/centrale_mort_test.lua (avec mutants).

  Journal SEUL : rien dans la partie n'en dépend (diagnostic de la perte de centrale à 7,8 % des trajectoires, 29/10).
  Le script (script/team/centrale_mort.lua) lit l'événement et le moteur, remplit un enregistrement de données simples, et cette règle
  en fait la ligne : cause lue à l'événement (« inconnue » si l'événement ne la donne pas), tourelles à moins de C.TURRET_R tuiles
  (armées à munitions, électriques ou à fluide, vides), ennemi le plus proche dans C.ENEMY_R tuiles.
]]
local C = {}

C.TURRET_R = 25
C.ENEMY_R = 150

--- Cause lue à l'événement : { name, type, force } (champs facultatifs) ou nil. « inconnue » si rien.
function C.cause(c)
  if type(c) ~= "table" or (c.name == nil and c.type == nil) then return "inconnue" end
  return string.format("%s/%s/%s", tostring(c.name or "?"), tostring(c.type or "?"), tostring(c.force or "?"))
end

--- Tourelles voisines : liste de { kind = "munitions" | "electrique" | "fluide", rounds = n (munitions), dist }. Rend les comptes
--- et la distance de la tourelle ARMÉE la plus proche (munitions > 0, ou électrique : alimentée par le réseau, comptée à part).
function C.turrets(list)
  local r = { armees = 0, electriques = 0, fluides = 0, vides = 0, nearest_armed = nil, nearest_any = nil }
  for _, t in ipairs(list or {}) do
    local d = t.dist or 0
    if r.nearest_any == nil or d < r.nearest_any then r.nearest_any = d end
    if t.kind == "munitions" then
      if (t.rounds or 0) > 0 then
        r.armees = r.armees + 1
        if r.nearest_armed == nil or d < r.nearest_armed then r.nearest_armed = d end
      else
        r.vides = r.vides + 1
      end
    elseif t.kind == "electrique" then r.electriques = r.electriques + 1
    else r.fluides = r.fluides + 1 end
  end
  return r
end

local function f1(x) return string.format("%.1f", x) end

--- La ligne. rec = { minute, force, type, name, x, y, cause, killer_force, damage, hq_dist, turrets (liste), enemy = { type, name,
--- dist } ou nil }.
function C.line(rec)
  local tr = C.turrets(rec.turrets)
  local near = tr.nearest_armed and (" (la plus proche armee a " .. f1(tr.nearest_armed) .. ")") or ""
  local enemy
  if rec.enemy then
    enemy = string.format("%s/%s a %s tuiles", tostring(rec.enemy.type or "?"), tostring(rec.enemy.name or "?"), f1(rec.enemy.dist or 0))
  else
    enemy = "aucun a " .. C.ENEMY_R .. " tuiles"
  end
  return string.format(
    "[FO-CENTRALE-MORT] minute %s | force %s | %s (%s) en (%s, %s) | cause %s | force tueuse %s | degats %s | QG a %s tuiles"
      .. " | tourelles a moins de %d : armees %d%s, electriques %d, fluides %d, vides %d | ennemi le plus proche : %s",
    f1(rec.minute or 0), tostring(rec.force or "?"), tostring(rec.type or "?"), tostring(rec.name or "?"), f1(rec.x or 0), f1(rec.y or 0),
    C.cause(rec.cause), tostring(rec.killer_force or "inconnue"), tostring(rec.damage or "inconnu"),
    rec.hq_dist and f1(rec.hq_dist) or "?", C.TURRET_R, tr.armees, near, tr.electriques, tr.fluides, tr.vides, enemy)
end

return C
