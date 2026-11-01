-- Scénario greffé du lot RB-0 (31/10), essai E8 (suite) : le banc d4-geant (usine géante + galerie de 960 têtes, 18 contrôles)
-- AVEC les feuilles de remplissage `rb0-fill-<k>` dessinées au centre de l'usine (grille de 5 colonnes, pas de 32 tuiles,
-- échelle 0,5), donc visibles dans les vues z030 et z050 ET dans les captures de détail ; la galerie des têtes (64 poses par âge)
-- est ensuite regardée ailleurs : les têtes se dessinent-elles encore juste quand l'atlas virtuel plein a déjà servi aux feuilles ?
-- Se lance comme d4-geant (tools/autotest/README.md §5.3), sur une copie fabriquée avec --remplissage <Mpx> :
--   banc.py --out <archive> --captures --visuel="--quality normal --video-memory low --texture-compression low-quality
--       --no-atlas-cache" --qui RB0 -- 600 rb0-atlas-d4 <copie>
-- Les lignes du journal portent l'étiquette [FO-RB0-ATLAS-D4] au lieu de [FO-D4-GEANT] (vram.py ne les voit donc pas : lire le
-- BILAN, les lignes TETES et les captures). Témoin : la même commande sur une copie sans remplissage.
local D = require("scenarios/d4-geant")

local W = {}
for k, v in pairs(D) do W[k] = v end
W.description = "RB-0 E8 : d4-geant avec feuilles de remplissage au centre de l'usine"

W.init = function(ctx)
  D.init(ctx)
  local st = ctx.state()
  local s = ctx.surface()
  local c = st.center
  local n, poses = 0, 0
  while game.entity_prototypes["rb0-fill-" .. (n + 1)] do n = n + 1 end
  if c then
    for k = 1, n do
      local col, row = (k - 1) % 5, math.floor((k - 1) / 5)
      local e = s.create_entity({ name = "rb0-fill-" .. k, position = { c.x + 32 * (col - 2), c.y + 32 * (row - 1) }, force = "neutral" })
      if e then poses = poses + 1 end
    end
  end
  ctx.log(string.format("remplissage : %d feuille(s) chargee(s), %d posee(s) au centre de l'usine (%s)", n, poses, c and (c.x .. "," .. c.y) or "centre inconnu"))
end

return W
