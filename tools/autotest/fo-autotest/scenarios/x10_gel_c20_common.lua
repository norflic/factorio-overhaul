--[[
  Lot X10-GEL, C20 (gain net, fo-logs/2026-11-07_X10/L1_CRITERES.md §4, écrit avant la mesure) : la SAUVEGARDE du DC rejouée telle
  quelle (banc.py --sauvegarde), profileur ÉTEINT, comme perf4-partie ; la seule différence entre les deux scénarios est le réglage
  de carte `fo-war-gel`, écrit au chargement par le mod lui-même (remote « fo-gel », reglage : un mod n'écrit que ses propres
  réglages) :
    x10-gel-c20-temoin : éteint (rien n'est figé ; la partie du DC sans le gel) ;
    x10-gel-c20-gel    : allumé (valeur par défaut d'une partie neuve pour ce réglage).
  Toutes les 600 ticks et au bilan : ce que le gel tient figé (remote « fo-gel », bilan), pour dire si la fenêtre de mesure a bien
  un gel en marche. Lancement (PC au repos, accord du lead) :
    py -3.9 -B tools/autotest/banc.py --seul --qui X10-GEL --sauvegarde "<racine>\fo-logs\2026-11-05_PARTIE-DC-ESSAI\autosave1-2121.zip"
       --out <archive> -- 8000 x10-gel-c20-temoin <copie figée>       (puis x10-gel-c20-gel ; ordre T, G, T, G, T, G)
]]
return function(ON)
  local S = {
    description = "X10-GEL C20 : sauvegarde du DC rejouee, profileur eteint, fo-war-gel " .. (ON and "ALLUME" or "ETEINT"),
    check_tick = -1, -- fixé à l'init : tick de la sauvegarde + 7 900
  }
  local function report(ctx, tag)
    local b = ctx.remote("fo-gel", "bilan")
    if b then
      log(string.format("[FO-X10-C20] %s tick %d : gel %s ; ilots %d, figes %d, machines figees %d (n_frozen %d), soldats figes %d", tag,
        game.tick, ON and "allume" or "eteint", b.ilots, b.figes, b.machines_figees, b.n_frozen, b.soldats_figes))
    end
    return b
  end
  S.init = function(ctx)
    local t = game.tick
    S.check_tick = t + 7900
    local st = ctx.state()
    st.debut = t
    log(string.format("[FO-PERF4] debut tick %d (%.1f min de jeu) ; mode off ; X10-C20 gel %s", t, t / 3600, ON and "allume" or "eteint"))
    ctx.call("profiler", false, false)
    local now = ctx.remote("fo-gel", "reglage", ON)
    ctx.check(now == ON, "fo-war-gel ecrit par le mod au chargement : " .. (ON and "allume" or "eteint"), tostring(now))
    ctx.check(t > 0, "partie chargee depuis une sauvegarde (tick de depart > 0)", t)
  end
  S.tick = function(ctx, e)
    local st = ctx.state()
    if st.debut and e.tick > st.debut and (e.tick - st.debut) % 600 == 0 then report(ctx, "releve") end
  end
  S.finish = function(ctx)
    local b = report(ctx, "bilan")
    if ON then
      ctx.check(b ~= nil and (b.figes > 0 or b.soldats_figes > 0), "gel en marche au bilan (quelque chose est fige)",
        b and string.format("%d ilot(s), %d soldat(s)", b.figes, b.soldats_figes) or "-")
    else
      ctx.check(b ~= nil and b.figes == 0 and b.soldats_figes == 0 and b.n_frozen == 0, "temoin : rien de fige", b and
        string.format("%d ilot(s), %d soldat(s)", b.figes, b.soldats_figes) or "-")
    end
  end
  return S
end
