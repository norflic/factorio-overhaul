--[[
  Lot L10 de la feuille de route « Factorio Automated » (docs/VIDEO_AUTOMATISATION.md §6 L10 ; docs/TODO_VIDEO.md V57, V58, V65, V66, G30,
  G64, G66, G69) : CROISSANCE PAR MARCHES APRÈS STABILITÉ. Règle PURE (aucune API Factorio, aucun nom d'objet : anti-échelle de
  tests/iag_test.lua §8). Testée hors jeu : tests/palier_test.lua. NON BRANCHÉE, et ne REMPLACE PAS C2 (Dm.step, shared/ai3/demande.lua) :
  c'est la VARIANTE B, à comparer à C2 (variante A) par le critère Pl.verdict avant toute bascule.

  La source (vidéo 7:44-8:40 ; gist l.486-511, 559-564) : quand plus rien ne manque, un minuteur de 5 minutes (18 000 ticks) démarre ; si
  rien ne manque pendant 5 minutes D'AFFILÉE, une tuile de recherche de plus est posée, et la cascade de demande pose ensuite ce qu'il faut
  pour suivre ; TOUTE pose annule le minuteur.

  Pl.step(st, a, tick), une fois par décision (pensée ou minute de la capitalisation ; tick = tick de JEU, jamais une horloge) :
    - STABLE (Pl.stable) : aucun manque à aucun rang (a.manques = 0 : nombre de rangs ou d'objets en manque, L1 et L3), aucune crise
      (a.crise faux : énergie, fer, danger, L12) et au moins Pl.HANDS_MIN bras libres (a.bras_libres). Une entrée ABSENTE n'est pas stable
      (garde fermée par défaut, L13) ;
    - POSE (a.pose vrai : un bâtiment ou un module posé depuis la décision précédente) : le minuteur repart de ZÉRO (G69) ; elle libère
      aussi l'attente de la marche précédente (I1) ;
    - INSTABLE : le minuteur est jeté (stabilité CONTINUE, V65 « 5 minutes straight ») ;
    - STABLE sans minuteur : minuteur = tick + Pl.TICKS (G66) ;
    - STABLE et minuteur échu : UNE marche au sommet (G64) : { kind = "recherche", labs = 1 } (un laboratoire de plus et ses packs comme
      puits), ou { kind = "equipement", n = 1 } quand l'arbre est fini (a.arbre_fini), comme C2 aujourd'hui ; puis plus aucune marche
      tant qu'aucune pose n'est venue (I1 : jamais deux marches sans pose entre elles).
  Rend (marche ou nil, evenement) ; evenement : "arme", "attente", "marche", "annule", "instable", "attend_pose", "tick".

  CRITÈRE A/B (Pl.verdict), écrit AVANT la mesure pour ne pas choisir après coup. A = C2 seul (croissance continue : +10 % par cycle quand
  le stock dort) ; B = C2 avec les marches de ce module (le puits élastique de C2 n'est ouvert qu'à l'échéance d'une marche). Même carte,
  même durée, mêmes réglages, Pl.SEEDS graines (F252 : la partie diverge au moindre changement). Mesures par graine, lues aux journaux :
  prod (MU/min produits sur les Pl.LAST_MIN dernières minutes), manque_min (minutes avec au moins un manque), crise_min (minutes en crise),
  ordres (ordres de la capitalisation). B est retenu SEULEMENT si, sur CHAQUE graine, prod_B >= prod_A × (1000 - Pl.PROD_TOL_PM) / 1000 et
  crise_min_B <= crise_min_A, ET si, sur au moins Pl.WIN_MIN graines, manque_min_B < manque_min_A. Sinon A reste (C2 inchangé).
  Déterminisme : aucune table parcourue par `pairs`, aucun hasard, aucun temps mesuré. Coût : O(1) par décision ; Pl.verdict O(graines).
]]

local Pl = {}

Pl.TICKS = 5 * 3600      -- 18 000 ticks : 5 min de stabilité continue (gist l.506-511)
Pl.HANDS_MIN = 1         -- bras libres au moins
Pl.SEEDS = 3             -- graines du critère A/B
Pl.PROD_TOL_PM = 50      -- ‰ : B ne perd jamais plus de 5 % de production sur une graine
Pl.WIN_MIN = 2           -- graines sur 3 où B doit avoir moins de minutes de manque
Pl.LAST_MIN = 30         -- minutes de fin de partie lues pour la production

function Pl.new() return { until_tick = nil, wait_pose = false, marches = 0, annules = 0 } end

local function num(v) if type(v) ~= "number" or v ~= v then return nil end return v end

--- L'état est-il stable ? a = { manques, crise, bras_libres }. Rend vrai, ou faux et la raison.
function Pl.stable(a)
  if type(a) ~= "table" then return false, "entrees absentes" end
  local m, h = num(a.manques), num(a.bras_libres)
  if m == nil or h == nil or type(a.crise) ~= "boolean" then return false, "entree absente (garde fermee)" end
  if m > 0 then return false, string.format("%d manque(s)", m) end
  if a.crise then return false, "crise" end
  if h < Pl.HANDS_MIN then return false, "aucun bras libre" end
  return true
end

--- Une décision. Voir l'en-tête.
function Pl.step(st, a, tick)
  if type(tick) ~= "number" then return nil, "tick" end
  a = a or {}
  local cancelled = false
  if a.pose then
    if st.until_tick then st.annules = (st.annules or 0) + 1 end
    st.until_tick, st.wait_pose, cancelled = nil, false, true
  end
  local ok = Pl.stable(a)
  if not ok then
    if st.until_tick then st.until_tick = nil return nil, "instable" end
    return nil, cancelled and "annule" or "instable"
  end
  if st.wait_pose then return nil, "attend_pose" end
  if not st.until_tick then
    st.until_tick = tick + Pl.TICKS
    return nil, cancelled and "annule" or "arme"
  end
  if tick >= st.until_tick then
    st.until_tick, st.wait_pose = nil, true
    st.marches = (st.marches or 0) + 1
    if a.arbre_fini then return { kind = "equipement", n = 1 }, "marche" end
    return { kind = "recherche", labs = 1 }, "marche"
  end
  return nil, "attente"
end

--- Critère A/B. A, B = listes de { seed, prod, manque_min, crise_min } (mêmes graines, même ordre). Rend "B" ou "A", et la cause.
function Pl.verdict(A, B)
  if type(A) ~= "table" or type(B) ~= "table" or #A < Pl.SEEDS or #A ~= #B then
    return "A", "mesures incompletes : C2 reste"
  end
  local wins = 0
  for i = 1, #A do
    local a, b = A[i], B[i]
    if a.seed ~= b.seed then return "A", "graines differentes au rang " .. i end
    local pa, pb = num(a.prod), num(b.prod)
    local ca, cb, ma, mb = num(a.crise_min), num(b.crise_min), num(a.manque_min), num(b.manque_min)
    if not (pa and pb and ca and cb and ma and mb) then return "A", "mesure absente a la graine " .. tostring(a.seed) end
    if pb * 1000 < pa * (1000 - Pl.PROD_TOL_PM) then return "A", "production perdue a la graine " .. tostring(a.seed) end
    if cb > ca then return "A", "plus de crise a la graine " .. tostring(a.seed) end
    if mb < ma then wins = wins + 1 end
  end
  if wins < Pl.WIN_MIN then return "A", string.format("moins de manque sur %d graine(s) seulement (%d exigees)", wins, Pl.WIN_MIN) end
  return "B", string.format("production tenue sur %d graines, moins de manque sur %d", #A, wins)
end

return Pl
