--[[
  ORIENT (lot PD-FONDERIEQG, demande D82 de l'inventaire de la vague 9) : SENS d'un gisement, pour orienter les rangées de
  foreuses et leur collecteur. PUR : aucune API Factorio, aucun nom d'objet (les tuiles arrivent en coordonnées).

  Le DC (29/10, 14 h, en jouant la 0.6.13) : « on met un max de foreuses électriques, on essaie de les compacter, de les aligner,
  de faire des rangées […] de haut en bas ou de bas en haut, ça dépend finalement de la forme également du gisement. S'il est
  parfaitement rond […] ça importe peu finalement, mais pour des formes plutôt verticales […] faire des inputs horizontalement
  ou verticalement. Verticalement, c'est moins efficace parce que l'output des foreuses correspondra pas assez au flux
  disponible pour les convoyeurs. Donc ça, voilà, c'est aussi un truc à analyser. »

  Ce que faisait le code (shared/team/plan.lua, P.fit) : les 4 rotations d'une ligne de foreuses sont essayées ; le score est
  la distance du CENTRE de la ligne à l'arrivée moins la couverture. Une ligne courte couvre 100 % dans les deux sens : le sens
  tombait au hasard de la première rotation essayée (k = 0, collecteur vers le sud), et deux rotations opposées (k et k + 2)
  ont le même centre : la sortie du collecteur pouvait tourner le dos à l'arrivée, d'où un tapis qui contourne la ligne (le
  « crochet » du DC, 29/10, 14 h : « on monte puis on redescend »).

  Règle (opt-in par P.fit, opts.axis et opts.out_toward, posée par script/team/build.lua pour les seules lignes de foreuses) :
    1. le SENS du gisement est lu sur ses tuiles dans le lot (moments d'ordre 2, entiers, sans trigonométrie) : « y »
       (vertical) quand la variance en y dépasse Or.RATIO fois celle en x, « x » dans l'autre cas, nil quand il est à peu près
       rond ou trop petit (le DC : « ça importe peu ») ;
    2. une ligne dont le collecteur est en TRAVERS du sens du gisement prend une pénalité (P.AXIS_PENALTY tuiles de distance,
       sous l'écart de couverture d'une ligne vraiment meilleure : 10 tuiles = 10 points de couverture) ;
    3. la distance est mesurée depuis la SORTIE du collecteur (la tuile après sa dernière) : la sortie regarde l'arrivée.
  Le DÉBIT (« l'output des foreuses correspondra pas au flux des convoyeurs ») : une ligne ne porte jamais plus de paires que
  ce qu'une voie de son tapis écoule (gabarit « drills » : n ≤ M.LANE_RATE / débit d'une foreuse, chaque colonne de foreuses
  sur SA voie) ; un gisement plus long que la ligne reçoit des lignes PARALLÈLES dans le même sens, chacune avec son
  collecteur, au lieu d'une ligne qui saturerait son tapis. Le sens ne change donc jamais le débit par tapis ; il change le
  nombre de lignes qui tiennent sur le gisement.

  Or.moments()                 -> accumulateur { n, sx, sy, sxx, syy } (entiers).
  Or.add(m, x, y)              -> ajoute une tuile (coordonnées entières, relatives à un coin fixe pour rester petites).
  Or.axis(m, ratio, min_tiles) -> "x" | "y" | nil, et les deux variances × n² (entiers) pour le journal.
  Or.line_axis(dir)            -> sens d'un collecteur d'après la direction de son tapis (0/4 : "y", 2/6 : "x").
]]
local Or = {}

Or.RATIO = 1.5      -- variance le long ÷ variance en travers au-delà de laquelle le gisement a un sens (≈ 1,22 en écart type)
Or.MIN_TILES = 12   -- sous ce nombre de tuiles de minerai dans le lot, aucun sens (une paire de foreuses en mine 25)

function Or.moments() return { n = 0, sx = 0, sy = 0, sxx = 0, syy = 0 } end

function Or.add(m, x, y)
  m.n = m.n + 1
  m.sx, m.sy = m.sx + x, m.sy + y
  m.sxx, m.syy = m.sxx + x * x, m.syy + y * y
end

--- Sens du gisement : n² · variance = n · Σx² − (Σx)², en entiers (exact en double pour des coordonnées de lot).
function Or.axis(m, ratio, min_tiles)
  if type(m) ~= "table" or (m.n or 0) < (min_tiles or Or.MIN_TILES) then return nil, 0, 0 end
  ratio = ratio or Or.RATIO
  local vx = m.n * m.sxx - m.sx * m.sx
  local vy = m.n * m.syy - m.sy * m.sy
  if vy > ratio * vx then return "y", vx, vy end
  if vx > ratio * vy then return "x", vx, vy end
  return nil, vx, vy
end

--- Sens d'un collecteur d'après la direction (0 nord, 2 est, 4 sud, 6 ouest) de son tapis.
function Or.line_axis(dir)
  if dir == 0 or dir == 4 then return "y" end
  if dir == 2 or dir == 6 then return "x" end
  return nil
end

return Or
