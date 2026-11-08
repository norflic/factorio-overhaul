--[[
  Lot DEBUG-CERVEAU : micro-banc SANS JOUEUR de la vue « Cerveau » en moteur réel (la fenêtre et le rendu demandent un joueur : captures à part).
  Même carte et même guerre que `default` (base "default") ; le scénario ne fait qu'OBSERVER. À 3 ticks précis, l'interface distante
  « fo-dbg-cerveau » (probe_all) relève 40 tranches de chaque équipe observable (script/debug/lecture.lua : recensement des projets et des
  avant-postes, statuts des machines au moteur, lectures du cerveau, écarts), sous un LuaProfiler ; une erreur Lua fait échouer le banc.
  Lancement : banc.py --qui DEBUG-CERVEAU -- 9400 dbg-cerveau <source>. Journal : [FO-DBG-CERVEAU].
]]

local PROBES = { 900, 3800, 6600, 9200 } -- les premieres decisions de capitalisation tombent apres 3 600 ticks
local SLICES = 40

return {
  description = "DEBUG-CERVEAU : relevé de la vue Cerveau sur la guerre `default` (sans joueur)",
  base = "default",
  check_tick = 9300,

  tick = function(ctx, e)
    local st = ctx.state()
    st.n = st.n or 0
    local due = false
    for _, t in ipairs(PROBES) do if e.tick == t then due = true end end
    if not due then return end
    local prof = game.create_profiler()
    local ok, res = pcall(remote.call, "fo-dbg-cerveau", "probe_all", SLICES)
    prof.stop()
    if not ok then
      st.erreur = tostring(res)
      ctx.log("ERREUR LUA au tick " .. e.tick .. " : " .. tostring(res))
      return
    end
    st.n = st.n + 1
    st.last = res
    local parts = {}
    for _, t in ipairs(res or {}) do
      parts[#parts + 1] = string.format("%s: %d zone(s) dont %d mesuree(s) [vert %d, orange %d, rouge %d, gris %d], %d alerte(s), anneau %d, %d liaison(s), %d entree(s)/sortie(s)", t.key, t.zones,
        t.mesurees, t.couleurs.vert, t.couleurs.orange, t.couleurs.rouge, t.couleurs.gris, t.alertes, t.anneau, t.liens or 0, t.ios or 0)
      st.zones_max = math.max(st.zones_max or 0, t.zones)
      st.mesurees_max = math.max(st.mesurees_max or 0, t.mesurees)
      st.anneau_max = math.max(st.anneau_max or 0, t.anneau)
    end
    ctx.log(string.format("tick %d | %d tranche(s) par equipe | cout total : %s | %s", e.tick, SLICES, "(voir ligne suivante)", table.concat(parts, " | ")))
    log({ "", "[FO-DBG-CERVEAU] cout du releve de ", tostring(SLICES), " tranches x ", tostring(#(res or {})), " equipe(s) au tick ", tostring(e.tick), " : ", prof })
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.erreur == nil, "aucune erreur Lua dans le releve", st.erreur or "")
    ctx.check((st.n or 0) == #PROBES, "les " .. #PROBES .. " releves ont tourne", tostring(st.n or 0))
    ctx.check((st.last and #st.last or 0) >= 1, "au moins une equipe observable", tostring(st.last and #st.last or 0))
    ctx.check((st.zones_max or 0) >= 1, "au moins une zone recensee (projet ou avant-poste)", tostring(st.zones_max or 0))
    ctx.check((st.mesurees_max or 0) >= 1, "au moins une zone mesuree au moteur", tostring(st.mesurees_max or 0))
    ctx.check((st.anneau_max or 0) >= 1, "l'anneau des decisions de la capitalisation s'est rempli", tostring(st.anneau_max or 0))
  end,
}
