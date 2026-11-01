-- Scénario greffé du lot RB-0 (31/10), essai E8 : l'atlas virtuel du plancher (12 pages sur 12, F186) a-t-il un plafond ?
-- SESSION AVEC IMAGES seulement (place 1) ; copie jetable fabriquée avec --remplissage <Mpx> (0 = témoin sans remplissage) :
--   py -3.9 tools/autotest/robots/jetable.py --dest <neuf> --remplissage 30
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui RB0 --captures
--       --visuel="--quality normal --video-memory low --texture-compression low-quality --no-atlas-cache" -- 700 rb0-atlas <copie>
-- La copie a N feuilles opaques de 2048 x 2048 (4,19 Mpx) `rb0-fill-<k>`, toutes différentes ; elles sont chargées avec le
-- reste (pages de l'atlas virtuel : ligne « Created virtual atlas pages 4096x4096xP » du journal du jeu, F186) et DESSINÉES
-- ici, côte à côte, à l'échelle 0,25 (512 px = 16 tuiles au zoom 1) pour vérifier qu'aucune image ne manque ni ne reste floue.
-- Captures : le premier et le dernier remplissage, chacun pris deux fois (tick d'écart : mise au net, F205) ; un
-- script lit ensuite les PNG (tools/autotest/robots/atlas_images.py) : écart moyen à la source réduite.

local C = require("scenarios/rb0_common")

local X0, Y0 = 12000, 12000
local CHECK = 600
local N_MAX = 16
local PAS = 32   -- feuille de 2048 px a l'echelle 0,5 = 1024 px = 32 tuiles ; grille de 4 colonnes

local function nb_fill()
  local n = 0
  while game.entity_prototypes["rb0-fill-" .. (n + 1)] do n = n + 1 end
  return n
end

return {
  description = "RB-0 E8 : feuilles de remplissage dessinees au plancher (atlas virtuel)",
  base = nil,
  check_tick = CHECK,
  shots_delay = 200,

  init = function(ctx)
    local st = ctx.state()
    st.pret = false
    local s = ctx.surface()
    st.n = nb_fill()
    ctx.prepare_area(X0 - 40, Y0 - 40, X0 + PAS * 4 + 40, Y0 + PAS * 4 + 40, "grass-1")
    C.sans_ennemis(s, X0 - 60, Y0 - 60, X0 + PAS * 4 + 60, Y0 + PAS * 4 + 60)
    st.poses = 0
    for k = 1, math.min(st.n, N_MAX) do
      local e = s.create_entity({ name = "rb0-fill-" .. k, position = { X0 + PAS * ((k - 1) % 4), Y0 + PAS * math.floor((k - 1) / 4) }, force = "neutral" })
      if e then st.poses = st.poses + 1 end
    end
    ctx.log(string.format("remplissage : %d feuille(s) chargee(s), %d posee(s) ; Mpx = %.1f", st.n, st.poses, st.n * 2048 * 2048 / 1e6))
    st.pret = true
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    ctx.check(st.poses == math.min(st.n, N_MAX), "E8 toutes les feuilles de remplissage sont posees", st.poses .. " / " .. st.n)
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if not st.pret or st.n == 0 then return end
    local o = { res = { 640, 640 }, info = false, aa = false }
    -- mosaique : toutes les feuilles dans le meme cadre (zoom 0,25 : 256 px par feuille)
    local rows = math.ceil(math.min(st.n, N_MAX) / 4)
    add("e8-mosaique", X0 + PAS * 1.5, Y0 + PAS * (rows - 1) / 2, 0.25, 0, { res = { 1280, 720 }, info = false, aa = false })
    add("e8-fill-1-a", X0, Y0, 2, 0, o)
    add("e8-fill-1-b", X0, Y0, 2, 0, o)
    local k = math.min(st.n, N_MAX)
    add("e8-fill-" .. k .. "-a", X0 + PAS * ((k - 1) % 4), Y0 + PAS * math.floor((k - 1) / 4), 2, 0, o)
    add("e8-fill-" .. k .. "-b", X0 + PAS * ((k - 1) % 4), Y0 + PAS * math.floor((k - 1) / 4), 2, 0, o)
  end,
}
