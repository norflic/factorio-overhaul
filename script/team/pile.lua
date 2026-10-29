--[[
  Lot PILE-PRIORITE : RUNTIME de la pile de priorité (la règle pure est shared/ai3/pile.lua).
    - PileRt.inputs(f, book, tick) : entrées du runtime pour la pensée du cerveau par besoins (script/ai3/cerveau.lua, ctx.pile) :
      pièces détruites du registre de reconstruction (f.recon, toutes celles qui ne sont pas abandonnées, AVEC OU SANS leur objet
      au stock : audit M4 et A5) et projet du plan directeur rouvert (Sweep.hold) ;
    - PileRt.hold(f) : la pile retient-elle l'amélioration ? Lu par script/team/team.lua (changement de foreuses, migration du
      champ, paiement du capital) ;
    - PileRt.journal(f, tick) : ligne « [FO-PILE] » à chaque changement de sommet et toutes les 5 min (aucune décision ne la lit).
  L'état vit dans f.team.ia3.pile (écrit par la pensée, en événement ; global par script/core/storage.lua). Aucun require en
  événement, aucun `pairs` décisionnel (clés triées), aucun temps mesuré.
]]

local State = require("script.faction.state")
local Stock = require("script.team.stock")
local Sweep = require("script.team.rebuild_sweep")
local Rc = require("shared.team.reconstruction")
local Pi = require("shared.ai3.pile")

local PileRt = {}

--- Entrées de la pile pour la pensée de l'équipe `f`.
function PileRt.inputs(f, book, tick)
  local repair = {}
  local s = f.recon
  -- Stock et recette relus une fois par objet (un registre peut compter des dizaines de tapis du même objet).
  local have, craft = {}, {}
  if s and s.lost then
    for _, k in ipairs(State.sorted_keys(s.lost)) do
      local r = s.lost[k]
      if r.item and not r.abandoned then
        if have[r.item] == nil then
          have[r.item] = Stock.count(f, r.item)
          craft[r.item] = (book and book:handcraftable(r.item)) or false
        end
        repair[#repair + 1] = { key = r.key or k, item = r.item, value = r.value or 0, prio = Rc.task_prio(r.value or 0),
          have = have[r.item], craftable = craft[r.item],
          claimed = r.claimed ~= nil, enemy = (r.retry ~= nil and tick < r.retry) or false, infra = r.infra or false }
      end
    end
  end
  return { repair = repair, plan_reopened = Sweep.hold(f, tick) or false }
end

--- La pile retient-elle l'amélioration de l'équipe ? (faux sans cerveau par besoins ni pile)
function PileRt.hold(f)
  local st = f.team and f.team.ia3 and f.team.ia3.pile
  return (st and st.hold) or false
end

--- Journal [FO-PILE] : à chaque changement de sommet ou de retenue, et toutes les Pi.LOG_EVERY ticks.
function PileRt.journal(f, tick)
  local st = f.team and f.team.ia3 and f.team.ia3.pile
  if not st or st.tick ~= tick then return false end
  if not st.changed and tick < (st.log_at or 0) then return false end
  st.log_at = tick + Pi.LOG_EVERY
  log(string.format("[FO-PILE] %s : %s a %.1f min", f.key or "player", Pi.describe(st),
    (tick - (f.started or 0)) / 3600))
  return true
end

return PileRt
