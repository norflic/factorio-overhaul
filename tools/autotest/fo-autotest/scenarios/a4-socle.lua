-- Scénario greffé du lot A4 (24/10) : SOCLE ÉMISSIF ANIMÉ de la mitrailleuse, vu de nuit (pilote : âge 6).
--   & "<racine>\fo-autotest.bat" nopause 300 a4-socle "<source>"     (contrôles, sans images)
--   & "<racine>\fo-captures.bat" a4-socle "<source>"                  (captures, sans son)
--   py -3.9 tools/autotest/a4_socle_images.py "<fo-shots>"
-- Sites : niveaux 11 et 12 (âge 6, socle animé ; 12 avec la pièce paire) et niveau 9 (âge 5, socle FIXE : témoin), tête
-- vers le sud (orientation écrite, sans cible ; F122). Captures : de jour une fois, de NUIT à 8 instants (une capture
-- par site toutes les 30 ticks : 5 images du cycle de 16 entre deux instants, cycle de 96 ticks) ; la différence d'un
-- instant à l'autre sur le socle dit si le moteur ANIME base_picture (témoin : nulle). Table : fo-shots/a4-socle-sites.tsv.

local X0, Y0, PAS = 2400, 3000, 14
local NIVEAUX = { 11, 12, 9 }
local INSTANTS = 8

return {
  description = "A4 : socle emissif anime (pilote age 6) de nuit, temoin age 5 fixe",
  base = nil,
  check_tick = 200,
  shots_delay = 120,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.sites = {}
    ctx.prepare_area(X0 - 10, Y0 - 10, X0 + #NIVEAUX * PAS + 10, Y0 + 10, "concrete")
    -- premier passage (24/10, 5 h 30) : un nid voisin a craché de l'acide sur le témoin ; ennemis retirés, cessez-le-feu
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy",
        area = { { X0 - 150, Y0 - 150 }, { X0 + #NIVEAUX * PAS + 150, Y0 + 150 } } })) do
      en.destroy()
    end
    for i, n in ipairs(NIVEAUX) do
      local t = s.create_entity({ name = "fo-lvl-gun-" .. n, position = { X0 + (i - 1) * PAS, Y0 }, force = "player" })
      if t then pcall(function() t.orientation = 0.5 end) end
      st.sites[#st.sites + 1] = { n = n, t = t, x = t and t.position.x or 0, y = t and t.position.y or 0 }
    end
    local poses = 0
    for _, c in ipairs(st.sites) do if c.t then poses = poses + 1 end end
    ctx.check(poses == #st.sites, "tourelles posees (niveaux 11, 12, 9)", poses .. " / " .. #st.sites)
  end,

  finish = function(ctx)
    local st = ctx.state()
    local ok = 0
    for _, c in ipairs(st.sites) do if c.t and c.t.valid then ok = ok + 1 end end
    ctx.check(ok == #st.sites, "tourelles toujours la", ok .. " / " .. #st.sites)
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local L = { "capture\tniveau\tinstant\tnuit\tx\ty" }
    local function cap(nm, c, i, nuit)
      add(nm, c.x, c.y - 0.5, 2, nuit and 0.5 or 0, { res = { 448, 448 }, info = false, aa = false })
      L[#L + 1] = string.format("%s\t%d\t%d\t%d\t%.4f\t%.4f", nm, c.n, i, nuit and 1 or 0, c.x, c.y)
    end
    for _, c in ipairs(st.sites) do cap(string.format("socle-n%02d-jour", c.n), c, 0, false) end
    for i = 1, INSTANTS do
      for _, c in ipairs(st.sites) do cap(string.format("socle-n%02d-nuit-i%d", c.n, i), c, i, true) end
    end
    game.write_file("fo-shots/a4-socle-sites.tsv", table.concat(L, "\n") .. "\n", false)
  end,
}
