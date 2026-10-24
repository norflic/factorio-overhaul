-- Scénario greffé du lot A4 (24/10) : SOCLE ÉMISSIF ANIMÉ de la mitrailleuse, vu de nuit. Pilote : âge 6 (lot
-- A4-préparation) ; étendu aux 11 âges animés 5 à 15 au lot A4-SOCLE (24/10, Q-A4-2 = A).
--   & "<racine>\fo-autotest.bat" nopause 300 a4-socle "<source>"     (contrôles, sans images)
--   & "<racine>\fo-captures.bat" a4-socle "<source>"                  (captures, sans son)
--   py -3.9 tools/autotest/a4_socle_images.py "<fo-shots>" [--planche P.png] [--gif DOSSIER]
-- Sites : une mitrailleuse par âge animé (5 à 15), plus un TÉMOIN au socle FIXE (âge 4, niveau 8) ; niveau impair aux
-- âges impairs, pair (avec la pièce paire) aux âges pairs. Grille de 4 rangées, une par ère (II : témoin, 5, 6 ; III :
-- 7, 8, 9 ; IV : 10, 11, 12 ; V : 13, 14, 15), tête vers le sud (orientation écrite, sans cible ; F122).
-- Captures (CADENCE de shots.lua : une capture toutes les 10 ticks ; cycle du socle : 16 images à 16/96, 96 ticks) :
--   1. par site, de jour une fois, puis de NUIT à 8 instants : la différence d'un instant à l'autre sur le socle dit si
--      le moteur ANIME base_picture (témoin : identique au pixel). 12 sites + 1 capture « pas » de 32 × 32 px (sans
--      objet) par instant : 130 ticks = 21,67 images entre deux instants. Premier passage (24/10, 21 h 38) : sans la
--      capture « pas », 120 ticks = 4 images, et l'âge 14 (« souffle », 2 battements par cycle : m = 1 aux images 0, 4,
--      8, 12) montrait 8 fois la même image (repliement de l'échantillonnage, pas un défaut du moteur) ;
--   2. pour le Directeur Créatif : toute la grille au zoom 1 (jour, nuit), chaque ère au zoom 2 (jour, nuit), puis
--      10 captures SUCCESSIVES de nuit de chaque ère au zoom 2 (10 ticks d'écart, 100 ticks ≈ un cycle : images
--      0, 1,7, 3,3, … du cycle) pour un GIF par ère.
-- Table : fo-shots/a4-socle-sites.tsv (capture, niveau, âge, instant, nuit, témoin, x, y, genre, ère).

local X0, Y0, PAS, RANG = 2400, 3000, 10, 14
-- { âge, niveau } par rangée (ère) ; le premier site de la première rangée est le témoin (socle fixe)
local GRILLE = {
  { era = "II", sites = { { 4, 8 }, { 5, 9 }, { 6, 12 } } },
  { era = "III", sites = { { 7, 13 }, { 8, 16 }, { 9, 17 } } },
  { era = "IV", sites = { { 10, 20 }, { 11, 21 }, { 12, 24 } } },
  { era = "V", sites = { { 13, 25 }, { 14, 28 }, { 15, 29 } } },
}
local TEMOIN_AGE = 4
local INSTANTS = 8
local SUITE = 10 -- captures successives par ère pour le GIF

--- Emprise d'un niveau (shared/levels/config.lua : 2×2 aux niveaux 1-6, 3×3 aux 7-12, … 6×6 aux 25-30)
local function emprise(n) return 2 + math.floor((n - 1) / 6) end

return {
  description = "A4-SOCLE : socles emissifs animes des ages 5 a 15 de nuit, temoin age 4 fixe",
  base = nil,
  check_tick = 200,
  shots_delay = 120,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.sites = {}
    local x1, y1 = X0 + (3 - 1) * PAS, Y0 + (#GRILLE - 1) * RANG
    ctx.prepare_area(X0 - 12, Y0 - 12, x1 + 12, y1 + 12, "concrete")
    -- premier passage (24/10, 5 h 30) : un nid voisin a craché de l'acide sur le témoin ; ennemis retirés, cessez-le-feu
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy",
        area = { { X0 - 150, Y0 - 150 }, { x1 + 150, y1 + 150 } } })) do
      en.destroy()
    end
    for r, rangee in ipairs(GRILLE) do
      for c, site in ipairs(rangee.sites) do
        local age, n = site[1], site[2]
        local t = s.create_entity({ name = "fo-lvl-gun-" .. n, position = { X0 + (c - 1) * PAS, Y0 + (r - 1) * RANG },
          force = "player" })
        if t then pcall(function() t.orientation = 0.5 end) end
        st.sites[#st.sites + 1] = { n = n, age = age, era = rangee.era, rang = r, t = t, temoin = age == TEMOIN_AGE,
          x = t and t.position.x or 0, y = t and t.position.y or 0 }
      end
    end
    local poses = 0
    for _, c in ipairs(st.sites) do if c.t then poses = poses + 1 end end
    ctx.check(poses == #st.sites, "tourelles posees (ages 5 a 15 et temoin age 4)", poses .. " / " .. #st.sites)
  end,

  finish = function(ctx)
    local st = ctx.state()
    local ok = 0
    for _, c in ipairs(st.sites) do if c.t and c.t.valid then ok = ok + 1 end end
    ctx.check(ok == #st.sites, "tourelles toujours la", ok .. " / " .. #st.sites)
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local L = { "capture\tniveau\tage\tinstant\tnuit\ttemoin\tx\ty\tgenre\tere" }
    local function ligne(nm, n, age, i, nuit, temoin, x, y, genre, era)
      L[#L + 1] = string.format("%s\t%d\t%d\t%d\t%d\t%d\t%.4f\t%.4f\t%s\t%s", nm, n, age, i, nuit and 1 or 0,
        temoin and 1 or 0, x, y, genre, era or "")
    end
    -- 1. par site (contrôle de l'animation)
    local function cap(nm, c, i, nuit)
      local px = (emprise(c.n) + 4) * 64
      add(nm, c.x, c.y - 0.5, 2, nuit and 0.5 or 0, { res = { px, px }, info = false, aa = false })
      ligne(nm, c.n, c.age, i, nuit, c.temoin, c.x, c.y, "site", c.era)
    end
    for _, c in ipairs(st.sites) do cap(string.format("socle-e%02d-n%02d-jour", c.age, c.n), c, 0, false) end
    for i = 1, INSTANTS do
      for _, c in ipairs(st.sites) do cap(string.format("socle-e%02d-n%02d-nuit-i%d", c.age, c.n, i), c, i, true) end
      local nm = string.format("pas-i%d", i) -- écart des instants porté à 130 ticks (voir l'en-tête)
      add(nm, X0 - 40, Y0 - 40, 1, 0.5, { res = { 32, 32 }, info = false, aa = false })
      ligne(nm, 0, 0, i, true, false, X0 - 40, Y0 - 40, "pas")
    end
    -- 2. pour le Directeur Créatif
    local cx, cy = X0 + PAS, Y0 + (#GRILLE - 1) * RANG / 2 - 0.5
    for _, nuit in ipairs({ false, true }) do
      local nm = "grille-z1-" .. (nuit and "nuit" or "jour")
      add(nm, cx, cy, 1, nuit and 0.5 or 0, { res = { 1024, 1728 }, info = false, aa = true })
      ligne(nm, 0, 0, 0, nuit, false, cx, cy, "grille")
    end
    for r, rangee in ipairs(GRILLE) do
      local y = Y0 + (r - 1) * RANG - 0.5
      for _, nuit in ipairs({ false, true }) do
        local nm = string.format("ere-%s-z2-%s", rangee.era, nuit and "nuit" or "jour")
        add(nm, cx, y, 2, nuit and 0.5 or 0, { res = { 1920, 640 }, info = false, aa = true })
        ligne(nm, 0, 0, 0, nuit, false, cx, y, "ere", rangee.era)
      end
    end
    for r, rangee in ipairs(GRILLE) do
      local y = Y0 + (r - 1) * RANG - 0.5
      for i = 1, SUITE do
        local nm = string.format("suite-%s-z2-nuit-%02d", rangee.era, i)
        add(nm, cx, y, 2, 0.5, { res = { 1920, 640 }, info = false, aa = false })
        ligne(nm, 0, 0, i, true, false, cx, y, "suite", rangee.era)
      end
    end
    game.write_file("fo-shots/a4-socle-sites.tsv", table.concat(L, "\n") .. "\n", false)
  end,
}
