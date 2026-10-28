--[[
  Lot EXPANSION, micro-banc en moteur réel : le BESOIN CROISSANT déclenche l'expansion (shared/ai3/besoin.lua,
  shared/ai3/expansion.lua ; runtime script/ai3/besoin.lua).
  La partie du guide (reglages de carte, scenarios/verif_guide_common.lua), puis au tick 10 800 (3 min : votre équipe a ses
  4 avant-postes) l'interface « fo-ia3c » (bench_expansion) amène votre équipe dans l'état d'une partie avancée pour le fer
  (économie faite, gisements bâtis pleins, gros besoin gardé), SANS autre intervention : le reste est la décision du jeu.
  Mesures : la décision du cerveau (explore ou open) au journal et au statut, le projet « expansion:iron » ouvert, la
  demande de sites (f.site_needs), le nombre d'avant-postes avant et après (si un site est retenu, un nouvel avant-poste de
  fer est BÂTI), aucune erreur Lua (la partie va au bout).
  Lancement : banc.py --out <archive> --qui EXPANSION -- 15000 expansion-site <source>. Journal : [FO-EXPANSION-SITE].
]]

local base = require("scenarios/verif_guide_common")(30)

local FORCE_AT = 10800
local KIND = "iron"
local TAG = "[FO-EXPANSION-SITE] "

local function count_iron(ctx)
  local st = remote.call("fo-ia3c", "status", "player")
  return st and st.outposts and st.outposts[KIND] or 0, st
end

return {
  description = "EXPANSION : etat de partie avancee force pour le fer de votre equipe, decision du jeu ensuite",
  base = nil,
  check_tick = 15000,

  init = base.init,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick >= FORCE_AT and e.tick % 60 == 0 then
      local ok = remote.call("fo-ia3c", "bench_expansion", "player", KIND, 20, 6000)
      if not st.forced then
        st.forced = e.tick
        st.n0 = count_iron(ctx)
        ctx.log(TAG .. string.format("etat avance pose au tick %d (%s) ; avant-postes de %s : %d", e.tick, tostring(ok), KIND, st.n0))
      end
      local n, status = count_iron(ctx)
      if n > (st.nmax or 0) then st.nmax = n end
      local ex = status and status.expansion and status.expansion[KIND]
      if ex and ex.act ~= "none" and not st.act then
        st.act, st.act_tick = ex.act, e.tick
        ctx.log(TAG .. string.format("decision %s (%s) au tick %d, besoin %s/min, exploitation %s %%, sites %s", ex.act, ex.why,
          e.tick, tostring(ex.need), tostring(ex.sat), tostring(ex.free)))
      end
      if status then
        for _, p in ipairs(status.projects or {}) do
          if p.key == "expansion:" .. KIND and not st.project then
            st.project = e.tick
            ctx.log(TAG .. string.format("projet %s %s %s au tick %d", p.key, p.state, tostring(p.cause), e.tick))
          end
        end
        if status.site_needs and (status.site_needs["iron-ore"] or 0) > 0 and not st.needs then
          st.needs = e.tick
          ctx.log(TAG .. "sites demandes a la prospection au tick " .. e.tick)
        end
      end
    end
    if e.tick >= FORCE_AT and e.tick % 1800 == 0 then
      local n, status = count_iron(ctx)
      local ex = status and status.expansion and status.expansion[KIND]
      ctx.log(TAG .. string.format("tick %d : avant-postes %s %d | decision %s (%s)", e.tick, KIND, n, ex and ex.act or "?", ex and ex.why or "?"))
    end
    base.tick(ctx, e)
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.forced ~= nil, "etat avance pose", st.forced)
    ctx.check(st.act == "explore" or st.act == "open", "le besoin croissant donne une decision d'expansion (explore ou open)",
      tostring(st.act) .. " au tick " .. tostring(st.act_tick))
    ctx.check(st.project ~= nil, "le projet expansion:" .. KIND .. " est ouvert", st.project)
    ctx.check(st.needs ~= nil or (st.nmax or 0) > (st.n0 or 0), "des sites sont demandes a la prospection, ou un nouvel avant-poste est bati",
      tostring(st.needs) .. " / avant-postes " .. tostring(st.n0) .. " -> " .. tostring(st.nmax))
    local line = ctx.call("team_status")
    ctx.check(line ~= nil, "equipe du joueur toujours active (aucune erreur Lua)", line and line:sub(1, 120))
  end,
}
