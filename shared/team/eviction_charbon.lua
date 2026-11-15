--[[
  Lot ENERGIE-0916 (partie du DC en 0.9.2, 90 min : 5 centrales sur 6 nourries à la main, coffre du QG à 0 charbon, champ à 18 charbon/s) :
  le projet d'alimentation d'une centrale était refusé « foreuses : minerai » (shared/team/plan.lua, P.fit) parce que le lot de charbon le
  plus proche était pris à 94 % par les foreuses de l'avant-poste de combustible (banc DIAG-ENERGIE, graine 123456789 : 524 places
  occupées sur 560). Décision du DC (15/11) : l'alimentation de la centrale passe AVANT l'avant-poste sur ce lot ; ses foreuses et coffres
  y sont retirés, puis le placement est refait. Règles pures (testées hors jeu : tests/eviction_charbon_test.lua).
]]

local Ev = {}

Ev.LOGS = 20 -- lignes [FO-EVICTION-CHARBON] au plus par équipe
Ev.MAX_LOTS = 4 -- lots portant des entités d'avant-poste essayés à blanc au plus, par projet

--- L'éviction est-elle voulue ? c = { alim = projet d'alimentation d'une centrale, why = cause du refus du placement, done = déjà faite
--- pour ce projet }. Seul un refus « minerai » (aucune place sur les tuiles du minerai) se lève en libérant des tuiles : « pas de lot »
--- (aucun lot de ce minerai) ne s'y prête pas.
function Ev.wanted(c)
  return c ~= nil and c.alim == true and c.why == "minerai" and not c.done
end

--- Entités de la liste ({ x, y, kind }, positions des centres) dont le centre tombe dans rect { x0, y0, x1, y1 } (x1, y1 exclus), triées
--- par x, puis y, puis genre (ordre stable, aucun `pairs`).
function Ev.inside(list, rect)
  local out = {}
  if not rect then return out end
  for _, e in ipairs(list or {}) do
    if e.x >= rect.x0 and e.x < rect.x1 and e.y >= rect.y0 and e.y < rect.y1 then out[#out + 1] = e end
  end
  table.sort(out, function(a, b)
    if a.x ~= b.x then return a.x < b.x end
    if a.y ~= b.y then return a.y < b.y end
    return tostring(a.kind) < tostring(b.kind)
  end)
  return out
end

--- Ligne de journal (texte seul).
function Ev.line(r)
  return string.format("[FO-EVICTION-CHARBON] %s : projet %d (alimentation de la centrale %s) : lot (%d, %d) libere pour la centrale : %d foreuse(s) et %d coffre(s) de l'avant-poste retires au stock, %d garde(s) (stock plein) a %.1f min",
    tostring(r.team), r.pid or 0, tostring(r.plant), r.x0 or 0, r.y0 or 0, r.drills or 0, r.sinks or 0, r.kept or 0, (r.tick or 0) / 3600)
end

--- Ligne « aucune éviction » : la ligne de foreuses ne tiendrait dans aucun des lots essayés à blanc, rien n'est retiré.
function Ev.line_vain(r)
  return string.format("[FO-EVICTION-CHARBON] %s : projet %d (alimentation de la centrale %s) : aucune eviction : la ligne de foreuses ne tient dans aucun des %d lot(s) d'avant-poste essayes a blanc a %.1f min",
    tostring(r.team), r.pid or 0, tostring(r.plant), r.tried or 0, (r.tick or 0) / 3600)
end

return Ev
