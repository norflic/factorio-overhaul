--[[
  Lot TV-ENERGIE (V89, docs/TODO_VIDEO.md l.155 : « keep UPS above 60 for a couple hundred mega tiles » : la performance tient, puis cède) :
  DÉGRADATION GRADUÉE sous charge. RÈGLE PURE (aucune API Factorio, aucun nom d'objet ; tests/tv_energie_test.lua §V89, avec mutants).

  CONTRAINTE DE DÉTERMINISME (CLAUDE.md §6, multijoueur) : aucune décision ne dépend d'un temps mesuré ; le signal de charge ne peut donc être ni
  les UPS ni un chronomètre. Le signal est la PROFONDEUR DE LA FILE du jeton des travaux lourds (script/core/lourd.lua, J.depth) : le nombre
  de demandeurs (pensées d'équipe par étapes, relevés du réseau, raccords) qui attendent leur tour. Cette file vit dans `global`, elle est la
  même sur tous les clients et après un chargement ; elle monte quand le travail déclaré à un tick dépasse le budget J.BUDGET (plus d'équipes,
  de machines, de chunks à relever), c'est-à-dire quand le jeu approche de ce qu'il peut faire en 1/60 s. C'est un PROXY de charge, DÉDUIT et
  non prouvé comme corrélé aux UPS mesurés : il est lu au journal [FO-DEGRADE] pour être confronté aux UPS d'une vraie partie.

  Niveaux 0 (normal) à 3. Un niveau monte quand la profondeur reste à son seuil (Dg.ENTER[niveau]) pendant Dg.CHECKS lectures de suite, redescend
  quand elle reste sous la MOITIÉ de ce seuil pendant Dg.CHECKS lectures de suite (hystérésis d'ÉTAT, jamais d'horloge), d'un niveau à la fois.
  Effet : une faction LOINTAINE et CALME (Cd.awake faux) pense moins souvent (Dg.slow : sa période de repos Cd.SLOW × Dg.MULT[niveau]).
  Jamais ralenti : votre équipe, une faction que le joueur approche, menacée, attaquée, qui a perdu une pièce ou dont l'armée est dehors
  (Cd.awake garde la main : la survie et la défense ne sont pas des variables d'ajustement). Dg.ON = false : aucune dégradation (témoin).
]]
local Dg = {}

Dg.ON = true                 -- ALLUMÉ par défaut
Dg.ENTER = { 4, 8, 14 }      -- profondeur de file à partir de laquelle le niveau 1, 2, 3 est visé (un pic de 2 à 3 demandeurs est normal)
Dg.CHECKS = 3                -- lectures de suite avant de changer de niveau (une lecture par seconde de jeu : 3 s)
Dg.MULT = { 1, 1.5, 2, 3 }   -- multiplicateur de Cd.SLOW au niveau 0, 1, 2, 3
Dg.MAX = 3

--- Niveau visé par une profondeur : le plus haut dont le seuil est atteint (0 sinon). Profondeur absente ou illisible : 0 (garde fermée :
--- jamais de dégradation sur une mesure qu'on n'a pas).
function Dg.target(depth)
  if type(depth) ~= "number" or depth ~= depth then return 0 end
  local lvl = 0
  for k = 1, #Dg.ENTER do
    if depth >= Dg.ENTER[k] then lvl = k end
  end
  return lvl
end

--- Une lecture. st = mémoire { level, up_n, down_n } (nombres) ; depth = profondeur de la file à cette lecture. Rend (niveau, changé).
function Dg.update(st, depth)
  st.level, st.up_n, st.down_n = st.level or 0, st.up_n or 0, st.down_n or 0
  if not Dg.ON then
    local was = st.level
    st.level, st.up_n, st.down_n = 0, 0, 0
    return 0, was ~= 0
  end
  local tgt = Dg.target(depth)
  local lvl = st.level
  if tgt > lvl then
    st.up_n, st.down_n = st.up_n + 1, 0
    if st.up_n >= Dg.CHECKS then st.level, st.up_n = math.min(Dg.MAX, lvl + 1), 0 end
  else
    st.up_n = 0
    -- redescente : la profondeur (0 si illisible : aucune charge prouvée) est sous la moitié du seuil du niveau tenu
    local d = (type(depth) == "number" and depth == depth) and depth or 0
    local low = lvl > 0 and d < Dg.ENTER[lvl] / 2
    if low then
      st.down_n = st.down_n + 1
      if st.down_n >= Dg.CHECKS then st.level, st.down_n = lvl - 1, 0 end
    else
      st.down_n = 0
    end
  end
  return st.level, st.level ~= lvl
end

--- Période de repos d'une faction lointaine et calme au niveau `level` (ticks) pour la base `slow` (Cd.SLOW). Niveau inconnu : la base.
function Dg.slow(slow, level)
  local m = Dg.MULT[(level or 0) + 1] or 1
  return math.floor(slow * m + 0.5)
end

--- Ligne du journal [FO-DEGRADE] (un changement de niveau).
function Dg.line(ev)
  return string.format("[FO-DEGRADE] niveau %d -> %d a %.1f min : file des travaux lourds a %d demandeur(s) (seuils %s, %d lectures de suite) : factions lointaines et calmes, une pensee toutes les %d ticks (au lieu de %d) ; votre equipe, menaces et defense inchanges",
    ev.from, ev.to, (ev.tick or 0) / 3600, ev.depth or 0, table.concat(Dg.ENTER, "/"), Dg.CHECKS, ev.slow, ev.base)
end

return Dg
