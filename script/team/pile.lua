--[[
  Lot PILE-PRIORITE : RUNTIME de la pile de priorité (la règle pure est shared/ai3/pile.lua).
    - PileRt.inputs(f, book, tick) : entrées du runtime pour la pensée du cerveau par besoins (script/ai3/cerveau.lua, ctx.pile) :
      pièces détruites du registre de reconstruction (f.recon, toutes celles qui ne sont pas abandonnées, AVEC OU SANS leur objet
      au stock : audit M4 et A5) et projet du plan directeur rouvert qui doit encore prendre des objets au coffre (plan_reopened) ;
    - PileRt.hold(f) : la pile retient-elle l'amélioration ? Lu par script/team/team.lua (changement de foreuses, migration du
      champ, paiement du capital) ;
    - PileRt.journal(f, tick) : ligne « [FO-PILE] » à chaque changement de sommet et toutes les 5 min (aucune décision ne la lit).
  L'état vit dans f.team.ia3.pile (écrit par la pensée, en événement ; global par script/core/storage.lua). Aucun require en
  événement, aucun `pairs` décisionnel (clés triées), aucun temps mesuré.
]]

local State = require("script.faction.state")
local Stock = require("script.team.stock")
local Rule = require("shared.team.rebuild_sweep")
local R = require("shared.ai3.reglages")
local Rc = require("shared.team.reconstruction")
local Pi = require("shared.ai3.pile")

local PileRt = {}

--- Relecture PILE : projets du plan directeur ROUVERTS qui doivent encore PRENDRE des objets au coffre (pièces à refaire, Rule.todo,
--- moins ce que leur réserve tient déjà, q.stock). Rend (ouvert, voie) : ouvert = au moins un tel projet ; voie = chaque objet manquant
--- est au coffre ou fabricable à la main. Remplace l'appel à Sweep.hold (D4 : 20 min après la réouverture), qui (1) était un gel dans
--- le temps, ce que le DC a fait supprimer (« Supprimer le gel », 29/10), et (2) disparaît avec le lot SANS-GEL (Sweep.upgrade_stock) :
--- l'appel aurait planté à chaque pensée après la fusion des deux lots. Ici : aucune durée ; un projet dont la matière est réservée
--- (siège compris) ne retient plus rien ; même lecture que Sw.project_needs de SANS-GEL, écrite sur Rule.todo et Rule.HOLD_STATES,
--- présents des deux côtés.
local function plan_reopened(f, book, have, craft)
  local b = f.build
  if not (R.REBUILD_SWEEP and b and b.projects and b.order and Rule.todo and Rule.HOLD_STATES) then return false, true end
  local open, path = false, true
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if Rule.rebuilding(q) and Rule.HOLD_STATES[q.state] then -- lot FUITES-PILE : reconstruction seulement (pas un agrandissement)
      local held = q.stock or {}
      for _, it in ipairs((Rule.todo(q))) do
        local item = it[1]
        if it[2] - (held[item] or 0) > 0 then
          open = true
          if have[item] == nil then
            have[item] = Stock.count(f, item)
            craft[item] = (book and book:handcraftable(item)) or false
          end
          if have[item] <= 0 and not craft[item] then path = false end
        end
      end
    end
  end
  return open, path
end

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
  local reopened, path = plan_reopened(f, book, have, craft)
  return { repair = repair, plan_reopened = reopened, plan_path = path }
end

--- La pile retient-elle l'amélioration de l'équipe ? (faux sans cerveau par besoins ni pile)
function PileRt.hold(f)
  local st = f.team and f.team.ia3 and f.team.ia3.pile
  return (st and st.hold) or false
end

--- Relecture PILE : une migration du champ est-elle EN CHANTIER (paires thermiques déjà retirées, ligne neuve en construction ;
--- script/team/migration_champ.lua, étape « chantier ») ? Pendant la retenue, elle continue : son étape ne retire plus rien, elle
--- compte la ligne qui produit (o.drills, sinon une capacité fausse fait grandir l'extraction à tort) et écarte du registre les
--- paires de l'avant-poste migré (purge_recon : sans elle, une paire thermique tuée là ouvrait un cadre « réparer » qui retenait,
--- donc suspendait la migration, donc gardait la pièce au registre). Une migration qui n'a encore rien retiré attend.
function PileRt.migration_building(f)
  local ms = f.migration
  local st = ms and ms.cur and ms.o and ms.o[ms.cur]
  return (st and st.stage == "chantier") or false
end

---------------------------------------------------------------------------------------------------
-- Lot FUITES-PILE : la porte des chemins du runtime qui contournaient la pile (capitalisation, réserve des modules neufs au plan
-- directeur, agrandissement des lignes, amélioration des tapis, équipement en modules) et le journal de ses refus.
---------------------------------------------------------------------------------------------------
local function pile_of(f)
  return f and f.team and f.team.ia3 and f.team.ia3.pile
end

--- Un travail de la famille `family` (shared/ai3/pile.lua Pi.FAMILY_RANK) produisant `item` (facultatif) peut-il avancer ? Rend
--- (permis, raison). Lit l'état écrit par la dernière pensée (f.team.ia3.pile) et ses manques (f.team.ia3.short : la matière manque,
--- investissement de production permis). Sans cerveau par besoins ni pile : permis.
function PileRt.porte(f, family, item)
  local st = pile_of(f)
  if not (st and st.hold) then return true, nil end
  local short = f.team.ia3.short or {}
  return Pi.porte(st, family, item, item ~= nil and (short[item] or 0) > 0)
end

--- Comme PileRt.porte pour plusieurs objets (un ordre qui produit un minerai et sa plaque) : permis si l'un d'eux l'est.
function PileRt.porte_any(f, family, items)
  local why = nil
  local any = false
  for _, it in ipairs(items or {}) do
    any = true
    local ok, w = PileRt.porte(f, family, it)
    if ok then return true, nil end
    why = why or w
  end
  if not any then return PileRt.porte(f, family, nil) end
  return false, why
end

--- Écrit au journal les refus en attente (Pi.suspend) : une ligne « [FO-PILE] <équipe> : refus : <clé> : <raison> » chacun.
function PileRt.flush(f, tick)
  local st = pile_of(f)
  if not (st and st.refus_out and #st.refus_out > 0) then return 0 end
  local n = #st.refus_out
  for _, line in ipairs(st.refus_out) do
    log(string.format("[FO-PILE] %s : refus : %s a %.1f min", f.key or "player", line, (tick - (f.started or 0)) / 3600))
  end
  if (st.refus_lost or 0) > 0 then
    log(string.format("[FO-PILE] %s : refus : %d autre(s) non ecrit(s) (au plus %d par pensee) a %.1f min", f.key or "player",
      st.refus_lost, Pi.REFUS_OUT_MAX, (tick - (f.started or 0)) / 3600))
  end
  st.refus_out, st.refus_lost = nil, nil
  return n
end

--- Note un refus de la pile (une fois par clé et par épisode de retenue) et l'écrit tout de suite au journal.
function PileRt.refuse(f, key, text, tick)
  local st = pile_of(f)
  if not st then return false end
  local new = Pi.suspend(st, key, text)
  if new then PileRt.flush(f, tick) end
  return new
end

--- Journal [FO-PILE] : à chaque changement de sommet ou de retenue, et toutes les Pi.LOG_EVERY ticks.
function PileRt.journal(f, tick)
  local st = f.team and f.team.ia3 and f.team.ia3.pile
  PileRt.flush(f, tick) -- lot FUITES-PILE : refus notés par la pensée pure (buts suspendus)
  if not st or st.tick ~= tick then return false end
  if not st.changed and tick < (st.log_at or 0) then return false end
  st.log_at = tick + Pi.LOG_EVERY
  log(string.format("[FO-PILE] %s : %s a %.1f min", f.key or "player", Pi.describe(st),
    (tick - (f.started or 0)) / 3600))
  return true
end

return PileRt
