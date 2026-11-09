--[[
  RANGÉE EXTENSIBLE LE LONG D'UN BUS (fichier COMMUN, propriétaire : lot MEGA-FONDERIE ; lecteurs : méga-fonderie, PETROLE-RANGEE, MALL ;
  accord du 8/11, 19 h 20). Règle PURE : aucune API du jeu, aucun nom d'objet ; testée hors jeu : tests/rangee_bus_test.lua (mutants).

  Directive du DC (8/11, vers 18 h) : « Bannissez ce comportement de "micro-bloc d'usine autonome" pour les ressources primaires.
  L'algorithme de placement doit passer d'une logique de "bloc fermé" à une logique de "rangée extensible alimentée par un bus". » ;
  « Le pattern de construction doit être un module capable d'être dupliqué (copié-collé) de gauche à droite pour former une longue rangée
  extensible à l'infini tant que la demande le justifie. La duplication de la ligne ne doit s'arrêter que devant un obstacle physique
  infranchissable (lac, falaise). Si c'est un obstacle destructible (caillou, arbre), l'agent le détruit et continue sa rangée. »

  Un MODULE (colonne de fonte, cellule de raffinerie, cellule d'assembleurs) occupe `pas` tuiles le long de l'axe de la rangée et `largeur`
  tuiles en travers ; sa géométrie interne vient d'ailleurs (base de motifs : shared/team/motifs/, Cat.instancier ; ou le gabarit du lot).
  Cette règle ne dit que COMBIEN de modules et OÙ :
    Rb.origine(k, x, y, axe, sens, pas)      coin nord-ouest du module k (k ≥ 1) d'une rangée partie de (x, y) ;
    Rb.extent(r)                             modules posables avant la première tuile infranchissable, tuiles à défricher, cause d'arrêt ;
    Rb.count(demande, offre, n_max)          modules que la demande justifie (⌈demande ÷ offre d'un module⌉) ;
    Rb.capacite(lignes, conso)               modules que le débit de CHAQUE ligne du bus nourrit (la plus faible borne) ;
    Rb.croissance(c)                         cible de la rangée, jamais en baisse, et sa cause.
  Repère : axe "x" (rangée d'ouest en est si sens = 1, d'est en ouest si sens = −1) ou "y" (du nord au sud si sens = 1) ; le module k couvre
  le long de l'axe [a, a + pas − 1] et en travers [b, b + largeur − 1] à partir de son coin. Une tuile répond "libre", "defricher" (arbre,
  rocher : détruit par l'agent, la rangée continue) ou "bloque:<cause>" (eau, falaise, bâtiment, réservé : la rangée s'arrête) ; toute
  autre réponse compte comme "bloque:inconnu" (garde fermée).
  Déterminisme : parcours dans l'ordre (module, puis le long de l'axe, puis en travers), aucun `pairs`, aucun temps mesuré.
]]

local Rb = {}

Rb.EPS = 1e-9
local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local EPS = Rb.EPS
local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end

--- Coin nord-ouest (plus petites coordonnées) du module k d'une rangée partie de (x, y).
function Rb.origine(k, x, y, axe, sens, pas)
  local a = (sens == -1) and (-k * pas + 1) or ((k - 1) * pas)
  if axe == "y" then return x, y + a end
  return x + a, y
end

--- r = { x, y, axe, sens, pas, largeur, n_max, tuile = fn(tx, ty) -> réponse, debut (premier module relu, défaut 1), budget (tuiles lues
--- au plus, facultatif) }. Rend { n (modules posables à la suite, debut − 1 compris), stop ("obstacle:<cause>" | "n_max" | "budget" |
--- "invalide"), defricher = { { x, y } } (tuiles des modules 1..n à défricher), lues (tuiles lues) }. Avec stop = "budget", la relecture
--- reprend à debut = n + 1 (passes bornées sur plusieurs ticks) ; ses tuiles à défricher s'ajoutent à celles des passes précédentes.
function Rb.extent(r)
  r = r or {}
  local out = { n = 0, stop = "invalide", defricher = {}, lues = 0 }
  local pas, larg, nmax = r.pas, r.largeur, r.n_max
  if not (num(pas) and pas >= 1 and num(larg) and larg >= 1 and num(nmax) and nmax >= 0 and type(r.tuile) == "function"
    and num(r.x) and num(r.y)) then return out end
  pas, larg, nmax = floor(pas + EPS), floor(larg + EPS), floor(nmax + EPS)
  local k0 = max(1, floor((r.debut or 1) + EPS))
  local budget = num(r.budget) and r.budget or nil
  out.n = k0 - 1
  local lues = 0
  for k = k0, nmax do
    if budget and lues + pas * larg > budget then out.stop, out.lues = "budget", lues return out end
    local x0, y0 = Rb.origine(k, r.x, r.y, r.axe, r.sens, pas)
    local here = {}
    for i = 0, pas - 1 do
      for j = 0, larg - 1 do
        local tx, ty
        if r.axe == "y" then tx, ty = x0 + j, y0 + i else tx, ty = x0 + i, y0 + j end
        lues = lues + 1
        local t = r.tuile(tx, ty)
        if t == "defricher" then here[#here + 1] = { tx, ty }
        elseif t ~= "libre" then
          local cause = (type(t) == "string" and t:match("^bloque:(.+)$")) or "inconnu"
          out.stop, out.lues = "obstacle:" .. cause, lues
          return out
        end
      end
    end
    for _, t in ipairs(here) do out.defricher[#out.defricher + 1] = t end
    out.n = k
  end
  out.stop, out.lues = "n_max", lues
  return out
end

--- Modules que la demande justifie : ⌈demande ÷ offre⌉, borné par n_max (facultatif) ; 0 sans demande ou sans offre lisible.
function Rb.count(demande, offre, n_max)
  if not (num(demande) and num(offre)) or demande <= 0 or offre <= 0 then return 0 end
  local n = ceil(demande / offre - EPS)
  if num(n_max) then n = min(n, max(0, floor(n_max + EPS))) end
  return n
end

--- Modules que le bus nourrit : lignes = { débit de la ligne k } (objets ou unités de fluide par seconde), conso = { débit pris par UN module
--- sur la ligne k } (même ordre ; 0 ou absent : le module ne prend rien sur cette ligne). Rend n (le plus petit ⌊ligne ÷ conso⌋) et le numéro
--- de la ligne qui borne ; nil, nil si aucune ligne n'est consommée (pas de borne de débit).
function Rb.capacite(lignes, conso)
  local best, which = nil, nil
  for k, c in ipairs(conso or {}) do
    if num(c) and c > 0 then
      local l = (lignes or {})[k]
      local n = (num(l) and l > 0) and floor(l / c + EPS) or 0
      if not best or n < best then best, which = n, k end
    end
  end
  return best, which
end

--- Cible de la rangée. c = { n (modules posés), prev (cible précédente), voulu (Rb.count), extent (Rb.extent(...).n), stop (sa cause),
--- cap (Rb.capacite, nil : sans borne) }. Rend { cible, cause } : la plus petite des bornes, sa cause (« demande couverte », la cause d'arrêt
--- de l'étendue, « debit:ligne »), jamais sous les modules posés ni sous la cible précédente (une rangée ne rétrécit pas).
function Rb.croissance(c)
  c = c or {}
  local voulu = num(c.voulu) and max(0, floor(c.voulu + EPS)) or 0
  local ext = num(c.extent) and max(0, floor(c.extent + EPS)) or 0
  local cap = num(c.cap) and max(0, floor(c.cap + EPS)) or nil
  local cible, cause = voulu, "demande couverte"
  if ext < cible then cible, cause = ext, c.stop or "obstacle:inconnu" end
  if cap and cap < cible then cible, cause = cap, "debit:ligne" end
  local floor_n = max(num(c.n) and c.n or 0, num(c.prev) and c.prev or 0)
  if cible < floor_n then cible, cause = floor_n, "jamais en baisse (" .. cause .. ")" end
  return { cible = cible, cause = cause }
end

return Rb
