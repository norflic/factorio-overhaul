--[[
  Lot P2-ENERGIE (pilier 2 du DC, 15/11 : « l'énergie suit en continu ») : une pièce planifiée dont l'emprise porte déjà une VARIANTE
  d'elle-même (même type de prototype, même groupe de remplacement rapide, même position, même orientation, même force ; par exemple le
  tapis jaune d'une centrale monté en tapis rapide par l'amélioration) est BÂTIE. PUR (aucune API Factorio, aucun nom d'objet).

  Mesuré : banc C3-APRES (2026-11-15, graine 123456789), centrale 1 rouverte à 14,9 min, ses 5 tapis « a refaire » alors que des tapis
  rapides de l'équipe occupaient leurs tuiles : fantôme refusé « occupe » sans fin, projet « bloque » de 20 à 40 min ; partie du DC 0.9.4,
  même chose de 39 à 54 min. La centrale bloquée tenait le but « auto:centrale » du cerveau (une seule centrale servie à la fois).
]]
local V = {}

local function eq(a, b) return math.abs((a or 0) - (b or 0)) < 0.01 end

--- `plan` : { type, group, x, y, dir, ug } de la pièce planifiée (type et groupe de remplacement rapide lus au prototype, ug : « input » |
--- « output » d'un tapis souterrain ou nil) ; `occ` : { type, group, x, y, dir, ug, own } de l'entité qui occupe (own : force de l'équipe).
--- Rend vrai si `occ` tient la place de la pièce.
function V.same_piece(plan, occ)
  if not (plan and occ and occ.own) then return false end
  if type(plan.type) ~= "string" or plan.type ~= occ.type then return false end
  if type(plan.group) ~= "string" or plan.group == "" or plan.group ~= occ.group then return false end
  if not (eq(plan.x, occ.x) and eq(plan.y, occ.y)) then return false end
  if (plan.dir or 0) ~= (occ.dir or 0) then return false end
  if plan.ug ~= nil and plan.ug ~= occ.ug then return false end
  return true
end

return V
