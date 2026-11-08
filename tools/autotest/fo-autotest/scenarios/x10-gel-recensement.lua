--[[
  Lot X10-GEL, C20' (b) : RECENSEMENT de la partie du DC avant de bâtir la scène x10-gel-echelle (fo-logs/2026-11-07_X10/L1_CRITERES.md
  §4, « Scène de C20' (b) » : même composition que la partie, relevée sur la sauvegarde AVANT la scène). Sauvegarde rejouée telle
  quelle, `fo-war-gel` allumé par le mod (remote « fo-gel », reglage), un relevé complet des candidats (Gu.SCAN_PER_TICK par tick),
  puis remote « fo-gel » recensement : une ligne par faction et une par îlot relevé. Aucune mesure de temps : banc sans --seul.
    py -3.9 -B tools/autotest/banc.py --qui X10-GEL --sauvegarde "<racine>\fo-logs\2026-11-05_PARTIE-DC-ESSAI\autosave1-2121.zip"
       --out <archive> -- 1700 x10-gel-recensement <source>
  Lecture : lignes [FO-X10-RECENS] du benchmark.log (faction ..., ilot ...).
]]
local S = {
  description = "X10-GEL C20' (b) : recensement des ilots, refus, avant-postes et garnisons de la partie du DC",
  check_tick = -1, -- fixé à l'init : tick de la sauvegarde + 1 600
}

local function roles_text(t)
  local ks = {}
  for k in next, t do ks[#ks + 1] = k end
  table.sort(ks)
  local parts = {}
  for _, k in ipairs(ks) do parts[#parts + 1] = k .. "=" .. t[k] end
  return table.concat(parts, " ")
end

S.init = function(ctx)
  local t = game.tick
  S.check_tick = t + 1600
  ctx.state().debut = t
  local now = ctx.remote("fo-gel", "reglage", true)
  ctx.check(now == true, "fo-war-gel ecrit par le mod au chargement : allume", tostring(now))
  ctx.check(t > 0, "partie chargee depuis une sauvegarde (tick de depart > 0)", t)
end

S.finish = function(ctx)
  local r = ctx.remote("fo-gel", "recensement")
  ctx.check(r ~= nil and #r.factions > 0, "recensement rendu, au moins une faction", r and #r.factions or "-")
  if not r then return end
  local fini = true
  for _, F in ipairs(r.factions) do
    local ap, amas = {}, {}
    for _, a in ipairs(F.avant_postes) do ap[#ap + 1] = a.foreuses .. "@" .. a.dist end
    for _, a in ipairs(F.amas) do amas[#amas + 1] = a.tourelles .. "@" .. a.dist end
    log(string.format("[FO-X10-RECENS] faction %s (%s) qg %d,%d ; candidats %d lus %d ; refus [%s] ; fours_qg %d ; soldats %d [%s] noms [%s] dist [%s] postes %d [%s] ; tourelles %d [%s] amas [%s] ; avant-postes [%s]",
      F.fid, F.key, F.hq.x, F.hq.y, F.candidats, F.lus, roles_text(F.refus), F.fours_qg, F.soldats, roles_text(F.roles), roles_text(F.noms),
      table.concat(F.dist_soldats, " "), F.postes, table.concat(F.dist_postes, " "), F.tourelles, roles_text(F.noms_tourelles), table.concat(amas, " "), table.concat(ap, " ")))
    if F.lus < F.candidats then fini = false end
  end
  for _, I in ipairs(r.ilots) do
    log(string.format("[FO-X10-RECENS] ilot %s %s foreuses %d machines %d dist %d minerai %s gisement %d charbon %d-%d fige %s etats %s",
      I.fid, I.sorte, I.foreuses, I.machines, I.dist, I.minerai, I.gisement, I.charbon_min, I.charbon_max, tostring(I.fige), I.etats))
  end
  ctx.check(#r.ilots > 0, "ilots releves sur la partie", #r.ilots)
  ctx.check(fini, "releve des candidats fini pour chaque faction (sinon refus et ilots incomplets)", fini)
end

return S
