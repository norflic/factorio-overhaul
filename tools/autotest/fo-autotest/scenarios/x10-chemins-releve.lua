--[[
  Lot X10-CHEMINS (7/11 ; fo-logs/2026-11-07_X10/CHEMINS_CRITERES.md §1.3 et §2.2) : RELEVÉ des demandes de chemin sur la
  SAUVEGARDE du DC, rejouée telle quelle (banc.py --sauvegarde). Le scénario ne change rien à la partie : il allume le journal du
  service de chemins (interface « fo-chemins », lignes [FO-CHEMINS-J] : une par demande émise, refusée ou finie ; lignes
  [FO-CHEMINS-P] : une par itinéraire de script/ai3/comportement.lua, M.plan, pour le mémo de l'A* de S8a), écrit le tick de
  départ ([FO-PERF4] debut tick D, lu par tools/autotest/perf3.py) et, à D + FIN, les compteurs du service avant et après.
  Profileur éteint. Lecture hors jeu : PYTHONUTF8=1 py -3.9 -B tools/autotest/chemins_releve.py <archive>.
  Micro-banc, sans --seul (aucun temps n'en est tiré) :
    py -3.9 -B tools/autotest/banc.py --qui X10-CHEMINS --sauvegarde "<racine>\fo-logs\2026-11-05_PARTIE-DC-ESSAI\autosave1-2121.zip"
       --out "<racine>\fo-logs\2026-11-07_X10\CH-releve-<n>" -- 2400 x10-chemins-releve <source>
]]
local FIN = 2300
local KEYS = { "requested", "issued", "ok", "fail", "fail_water", "fail_other", "fail_start", "fail_blocked", "refused_water",
  "start_unpadded", "start_moved", "latency_sum", "fail_latency_sum", "waypoints_sum", "retry", "timeout", "dropped" }

local function stats_text(s)
  local parts = {}
  for _, k in ipairs(KEYS) do parts[#parts + 1] = k .. "=" .. tostring(s and s[k] or 0) end
  return table.concat(parts, " ")
end

local S = {
  description = "X10-CHEMINS : releve des demandes de chemin sur la sauvegarde du DC (journal [FO-CHEMINS-J])",
  check_tick = -1, -- fixé à l'init (tick de la sauvegarde + FIN)
}

S.init = function(ctx)
  local t = game.tick
  S.check_tick = t + FIN
  local st = ctx.state()
  st.debut = t
  local mods = {}
  for name, v in pairs(script.active_mods) do mods[#mods + 1] = name .. " " .. v end
  table.sort(mods)
  log(string.format("[FO-PERF4] debut tick %d (%.1f min de jeu) ; mode x10-chemins-releve ; mods : %s", t, t / 3600, table.concat(mods, ", ")))
  ctx.call("profiler", false, false)
  ctx.check(t > 0, "partie chargee depuis une sauvegarde (tick de depart > 0)", t)
  local has = remote.interfaces["fo-chemins"] ~= nil
  ctx.check(has, "interface fo-chemins presente (source du lot X10-CHEMINS)", has)
  if has then
    local s0 = remote.call("fo-chemins", "stats")
    st.s0 = s0
    ctx.log("STATS depart " .. stats_text(s0))
    ctx.check(remote.call("fo-chemins", "journal", true) == true, "journal des demandes allume", true)
  end
end

S.finish = function(ctx)
  local st = ctx.state()
  if remote.interfaces["fo-chemins"] then
    local s1 = remote.call("fo-chemins", "stats")
    ctx.log("STATS fin " .. stats_text(s1))
    local d = (s1.requested or 0) - ((st.s0 and st.s0.requested) or 0)
    ctx.check(d > 0, "demandes de chemin pendant le releve", d)
    remote.call("fo-chemins", "journal", false)
  end
  local poi = ctx.call("points_of_interest")
  ctx.check(poi ~= nil, "interface du mod lisible a la fin", poi and #poi.factions)
end

return S
