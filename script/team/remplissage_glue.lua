--[[
  Lot REMPLISSAGE, branchement : la colle entre quai_tasks (script/team/build.lua) et la règle pure shared/team/remplissage.lua (Rm).
  Requise au CHARGEMENT par build.lua dans un champ de sa table (`Build.Rempl` : le bloc principal de build.lua est à 199 locales).

  Ce que fait Rempl.adjust : la règle ordinaire de quai_tasks (Build.Quotas.refill) a déjà rendu son verdict `r` ; si le stock de l'objet est
  ABONDANT (au moins Rm.MULT_IN fois le besoin ordinaire de tous les quais de l'objet, dans toute l'équipe), la cible du coffre monte
  jusqu'à sa capacité réelle (get_insertable_count : barre respectée, F95), bornée par la part du quai (Rm.share) ; le seuil de relance monte
  avec elle ; le compte d'une tournée est borné par la capacité du sac d'un PNJ. Stock juste : `r` est rendu tel quel (l'ancienne règle).
  Le centre des chaudières (Cc.refill, charbon de centrale) garde sa règle d'urgence : il ne passe pas ici.

  État gardé dans le quai (p.quais[i], sérialisable) : q.rw (cible ordinaire), q.rempl = { cible, cause }. Le besoin total d'un objet est
  relevé sur tous les projets (quais distincts par position : un quai dupliqué par un réessai de plan ne compte qu'une fois), mis en cache
  300 ticks dans f.build.rempl_cache. Journal [FO-REMPLISSAGE] : une ligne par changement de cible d'un quai (Rempl.LOGS par force au plus).
  Aucun nom d'objet ni de coffre (anti-échelle de tests/iag_test.lua).
]]

local Rm = require("shared.team.remplissage")

local Rempl = {}
Rempl.Rm = Rm
Rempl.LOGS = 80           -- lignes [FO-REMPLISSAGE] au plus par force
Rempl.CACHE_TICKS = 300   -- durée de vie du relevé du besoin total
Rempl.BAG_FALLBACK = 80   -- cases du sac d'un PNJ si le prototype ne répond pas

--- Capacité du sac d'un PNJ pour `item`, en objets : (cases du corps + bonus de recherche de la force - Rm.BAG_RESERVE) x pile.
function Rempl.bag(f, item)
  local slots = Rempl.BAG_FALLBACK
  local ok, v = pcall(function() return game.entity_prototypes["character"].get_inventory_size(defines.inventory.character_main) end)
  if ok and type(v) == "number" and v > 0 then slots = v end
  local force = game.forces[f.force]
  local bonus = force and force.character_inventory_slots_bonus
  if type(bonus) == "number" and bonus > 0 then slots = slots + bonus end
  local pr = game.item_prototypes[item]
  local stack = pr and pr.stack_size or 1
  return math.max(1, slots - Rm.BAG_RESERVE) * stack
end

--- Besoin ordinaire total par objet (somme des q.rw, QUAI_FILL à défaut) et nombre de quais distincts, relevés sur tous les projets.
local function census(f, fill, tick)
  local b = f.build
  local c = b.rempl_cache
  if c and c.tick and tick >= c.tick and tick - c.tick < Rempl.CACHE_TICKS then return c end
  local need, nq, seen = {}, {}, {}
  for _, pid in ipairs(b.order or {}) do
    local p = b.projects[pid]
    for _, q in ipairs((p and p.quais) or {}) do
      local key = string.format("%d,%d", math.floor(q.x * 2), math.floor(q.y * 2)) -- demi-tuiles : le quai est un coffre 1x1
      if q.item and not seen[key] then
        seen[key] = true
        need[q.item] = (need[q.item] or 0) + (q.rw or fill)
        nq[q.item] = (nq[q.item] or 0) + 1
      end
    end
  end
  c = { tick = tick, need = need, nq = nq }
  b.rempl_cache = c
  return c
end

local function say(f, p, i, q, last, lvl, stock, need, nq, tick)
  f.stats.rempl_logs = (f.stats.rempl_logs or 0) + 1
  if f.stats.rempl_logs > Rempl.LOGS then return end
  log(string.format("[FO-REMPLISSAGE] %s a %.1f min : quai %d du projet %s (%.0f, %.0f) %s : cible %d -> %d (%s : stock %d, besoin %d sur %d quai(s), part %d, relance sous %d)",
    f.key or "player", tick / 3600, i, tostring(p.id), q.x, q.y, tostring(q.item), last and last.cible or 0, lvl.want,
    lvl.cause == "abondant" and "stock abondant" or lvl.cause == "proportionnel" and "stock libre partage" or "stock juste", stock, need, nq, lvl.bound, lvl.low))
end

--- r : verdict ordinaire { due, count } de Build.Quotas.refill ; low, fill : constantes ordinaires de l'appelant (Build.QUAI_LOW, QUAI_FILL).
--- Rend le verdict à appliquer { due, count } (r lui-même quand le stock est juste).
function Rempl.adjust(f, p, i, q, chest, n, have, qta, r, low, fill)
  local b = f.build
  local qin = qta and qta.ins and qta.ins[i]
  local base_want, base_low = fill, low
  if qin and not qin.free then base_want, base_low = qin.want, qin.low end
  q.rw = base_want
  local inv = chest.get_inventory(defines.inventory.chest)
  if not inv then return r end
  local tick = game.tick
  local cs = census(f, fill, tick)
  local lvl = Rm.level({
    base_want = base_want, base_low = base_low, cap = n + inv.get_insertable_count(q.item),
    stock = have, need = cs.need[q.item] or base_want, nq = cs.nq[q.item] or 1,
    was = q.rempl and q.rempl.cause == "abondant" or false,
  })
  if Rm.changed(q.rempl, lvl) then say(f, p, i, q, q.rempl, lvl, have, cs.need[q.item] or base_want, cs.nq[q.item] or 1, tick) end
  q.rempl = { cible = lvl.want, cause = lvl.cause }
  if lvl.cause == "juste" then return r end
  return Rm.refill(lvl.want, lvl.low, n, have, Rempl.bag(f, q.item))
end

return Rempl
