--[[
  Lot POSE-PERDUE (banc 0.6.75 A, graine 1618033988 : « azure : avant-poste 2 : 0 paire(s) posee(s) avec 41 iron-plate pris(es) sur
  place par le PNJ 13 a 53.9 min », [FO-EXTEND] « essais 0 … (objets) » : le PNJ est arrivé sans une seule foreuse).
  Cause : l'étape « craft_now » lançait TOUTES les recettes du plan dans le même tick. Le moteur retire les ingrédients de
  l'inventaire au moment où la fabrication est mise en file, et les produits n'y entrent qu'à la fin : la 3e recette (le produit,
  qui a pour ingrédients les produits des deux premières) ne trouvait plus rien dans l'inventaire : begin_crafting rendait 0
  (30 fabrications lancées sur 38 : 15 + 15 + 0). Les deux autres chemins de fabrication (état « craft », fond craft_bg) lancent
  une recette à la fois et attendent la file vide : celui-ci fait de même.

  Règle PURE (aucun appel au moteur hors de l'entité passée) :

    Fp.avance(e, crafts, st, tick, timeout)
        e        : personnage (lectures : crafting_queue_size ; appel : begin_crafting{ count, recipe, silent })
        crafts   : { { recipe, runs }, ... } dans l'ordre exécutable du livre (ingrédients avant produits, Book:plan)
        st       : état DE DONNÉES porté par le PNJ : { i = prochaine recette, n = fabrications lancées, t0 = tick du départ }
        rend     : "attend" (file encore occupée : la recette suivante attend ses ingrédients),
                   "lance"  (une recette vient d'être mise en file ; le moteur la fabrique),
                   "fini"   (plus de recette et file vide : tout est dans l'inventaire),
                   "delai"  (file occupée depuis plus de `timeout` ticks : on n'attend plus)
]]
local Fp = {}

function Fp.avance(e, crafts, st, tick, timeout)
  if e.crafting_queue_size > 0 then
    if timeout and (tick - (st.t0 or tick)) > timeout then return "delai" end
    return "attend"
  end
  local c = crafts[st.i]
  if not c then return "fini" end
  local ok, k = pcall(e.begin_crafting, { count = c.runs, recipe = c.recipe, silent = true })
  if ok and type(k) == "number" then st.n = (st.n or 0) + k end
  st.i = st.i + 1
  return "lance"
end

return Fp
