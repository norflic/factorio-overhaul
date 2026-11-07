-- Lot DESIGN-ATTAQUES (5/11) : MICRO-BANC des 5 grandes attaques en moteur réel, SANS images (palier 3, avant toute capture).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui DESIGN-ATTAQUES -- 5000 att2-controle <source>
-- Les 5 géants frappent EN MÊME TEMPS (tick 100) leur base ennemie ; contrôles au tick 2 500 (depuis le budget par tick du 7/11, PARTAGÉ :
-- cinq grandes attaques ensemble durent plus longtemps qu'une seule ; environ 1 300 ticks au moteur simulé) :
--   le prototype charge (sprites, tuiles, falaises, rayons, jets, sons, touche) ; chaque attaque finit sans erreur et touche des cibles ;
--   Cairn : 40 poteaux au moins grillés ; Stylet : balayage laser de 30° (idée du DC), sillage de sol brûlé ; Trombe : rochers posés, elle finit au centre ;
--   Ixion : tuiles de lave posées, infranchissables (collision) ; Tournesol : verre chaud posé ; le bâtiment ami de chaque zone intact ;
--   coût : opérations au pire tick (compte du script), lu dans les statistiques.
-- Puis les SÉQUELLES d'1 h (QCM-7/11), sans attendre l'heure : au tick 2 500, l'heure des séquelles est avancée de 1 h (remote « vieillir »,
-- bancs seulement) ; contrôles finaux au tick 4 900 : lave et verre refroidis puis rendus à leur sol d'origine, registre vide, rochers de
-- la Trombe effacés.
local C = require("scenarios/att2_commun")

local Y = 3000
local IDS = { "cairn", "stylet", "trombe", "ixion", "tournesol" }
local function sx(k) return 6000 + (k - 1) * 400 end
local LANCE = 100
local CHECK = 2500
local FIN = 4900
local HEURE = 216000 + 600 -- Ech.TRACE_TICKS (1 h), et un peu plus

local attaques
--- Contrôles des 5 attaques (au tick CHECK).
attaques = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local stats = remote.call("fo-att2", "stats")
    ctx.check(remote.call("fo-att2", "en_cours") == 0, "les 5 attaques sont finies au tick " .. CHECK)
    for k, ss in ipairs(st.sites) do
      local x = stats[ss.id] or {}
      ctx.check((x.cibles or 0) > 0 and (x.recherches or 0) == 1, ss.id .. " : une recherche, des cibles touchees",
        string.format("recherches %d, candidats %d, cibles %d, tues %d, degats %.0f, max ops/tick %d", x.recherches or 0, x.candidats or 0,
          x.cibles or 0, x.tues or 0, x.degats or 0, x.max_ops or 0))
      ctx.check(ss.ami and ss.ami.valid and ss.ami.health == ss.ami.prototype.max_health, ss.id .. " : le batiment ami dans la zone est intact")
    end
    local c = stats.cairn or {}
    ctx.check((c.poteaux or 0) >= 40, "cairn : la surtension grille le reseau", tostring(c.poteaux))
    local sy = stats.stylet or {}
    local br = s.count_entities_filtered({ area = { { sx(2) - 50, Y - 20 }, { sx(2) + 10, Y + 25 } }, name = "fo-xp-medium-scorchmark" }) -- brûlures d'1 h (QCM-7/11)
    ctx.check((sy.feux or 0) >= 40 and br >= 40, "stylet : le balayage laisse un sillage de sol brule", string.format("%d feux, %d brulures lues", sy.feux or 0, br))
    local tr = stats.trombe or {}
    local g3 = st.sites[3].g
    ctx.check((tr.rochers or 0) >= 1, "trombe : rochers sur le couloir", tostring(tr.rochers))
    ctx.check(g3 and g3.valid and math.abs(g3.position.x - sx(3) - 0.5) < 1 and math.abs(g3.position.y - Y - 0.5) < 1,
      "trombe : elle a parcouru la base et finit au centre", g3 and g3.valid and string.format("(%.1f, %.1f)", g3.position.x - sx(3), g3.position.y - Y) or "?")
    local ix = stats.ixion or {}
    local lave = s.count_tiles_filtered({ area = { { sx(4) - 25, Y - 25 }, { sx(4) + 25, Y + 25 } }, name = "fo-att2-lave" })
    local t = s.get_tile(sx(4), Y)
    ctx.check((ix.tuiles or 0) >= 500 and lave >= 500 and t.collides_with("player-layer") and t.collides_with("object-layer"),
      "ixion : lac de lave pose, infranchissable et inconstructible", string.format("%d posees, %d lues, tuile du centre %s", ix.tuiles or 0, lave, t.name))
    local tz = stats.tournesol or {}
    local verre = s.count_tiles_filtered({ area = { { sx(5) - 80, Y - 80 }, { sx(5) + 80, Y + 80 } }, name = "fo-att2-verre-chaud" })
    ctx.check((tz.tuiles or 0) >= 800 and verre >= 800, "tournesol : spirale de verre chaud posee", string.format("%d posees, %d lues", tz.tuiles or 0, verre))
    ctx.check(remote.call("fo-att2", "laves") == 1 and remote.call("fo-att2", "verres") == 1, "sequelles enregistrees (lave et verre refroidiront)")
end

return {
  description = "DESIGN-ATTAQUES : micro-banc des 5 grandes attaques et de leurs sequelles d'1 h (sans images)",
  check_tick = FIN,

  init = function(ctx)
    local st = ctx.state()
    C.forces()
    remote.call("fo-att2", "journal", true)
    st.sites = {}
    for k, id in ipairs(IDS) do
      -- géant posé au lancement (C.poser) : sa 1re attaque ne laisse pas son propre cratère sous le lac avant la grande
      st.sites[k] = C.site(ctx, k, id, sx(k), Y, true)
      local ss = st.sites[k]
      ctx.log(string.format("site %d %s : %d poteaux", k, id, ss.poles))
    end
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == LANCE then
      for k, ss in ipairs(st.sites) do
        local g = C.poser(ctx.surface(), ss)
        ctx.check(g ~= nil and g.valid, ss.id .. " : geant pose")
        local okl, why = remote.call("fo-att2", "lancer", g, sx(k) + 0.5, Y + 0.5, true)
        ctx.check(okl == true, ss.id .. " : grande attaque lancee", tostring(why))
      end
    end
    if e.tick == LANCE + 2 then
      -- une seconde demande pendant la charge est refusée (une à la fois)
      local okl, why = remote.call("fo-att2", "lancer", st.sites[1].g, sx(1), Y, true)
      ctx.check(okl == false and why == "deja en cours", "une grande attaque a la fois", tostring(why))
    end
    if e.tick == CHECK then
      attaques(ctx)
      local q = remote.call("fo-att2", "sequelles")
      st.avant = q
      ctx.log(string.format("[ATT2-SEQUELLES] avant l'heure : %d tuile(s) au registre, %d rendue(s), %d rocher(s) en attente", q.marquees, q.rendues, q.rochers))
      ctx.check(q.marquees >= 1000 and q.rochers >= 1 and q.rendues == 0, "sequelles notees : lave et verre au registre, rochers en attente, rien rendu avant l'heure",
        string.format("%d tuiles, %d rochers, %d rendues", q.marquees, q.rochers, q.rendues))
      remote.call("fo-att2", "vieillir", HEURE)
    end
  end,

  finish = function(ctx)
    local s = ctx.surface()
    local q = remote.call("fo-att2", "sequelles")
    local ix = (remote.call("fo-att2", "stats").ixion or {})
    ctx.log(string.format("[ATT2-SEQUELLES] apres l'heure : %d tuile(s) au registre, %d rendue(s), %d rocher(s) en attente, %d efface(s)", q.marquees,
      q.rendues, q.rochers, q.effaces))
    local chaud = s.count_tiles_filtered({ area = { { sx(4) - 80, Y - 80 }, { sx(5) + 80, Y + 80 } }, name = { "fo-att2-lave", "fo-att2-verre-chaud", "fo-att2-verre" } })
    ctx.check(q.marquees == 0 and chaud == 0 and q.rendues >= (ix.tuiles or 0), "apres 1 h : lave et verre refroidis puis rendus a leur sol d'origine, registre vide",
      string.format("%d au registre, %d tuiles de lave ou de verre lues, %d rendues (lave posee %d)", q.marquees, chaud, q.rendues, ix.tuiles or 0))
    local herbe = s.get_tile(sx(4), Y)
    ctx.check(herbe.name == "dry-dirt", "apres 1 h : le centre du lac d'Ixion a retrouve son sol d'origine (dry-dirt du banc)", herbe.name)
    ctx.check(q.rochers == 0 and q.effaces >= 1, "apres 1 h : les rochers de la Trombe se sont effaces", string.format("%d en attente, %d effaces", q.rochers, q.effaces))
  end,
}
