--[[
  PIQUAGE (lot PIQUAGE, demande du DC du 8/11, en jouant la 0.6.65). Règle PURE : aucune API du jeu, aucun nom d'objet, aucun nom de minerai ;
  lue hors jeu (tests/piquage_test.lua) et en jeu (script/team/piquage.lua).

  Le DC : « il y a donc un rectangle, une boîte, une box de fonderie qui a un input à tel endroit et qui a besoin de charbon. À cet endroit-là,
  il y a un coffre avec un bras [...] Ce qui est rigolo, c'est qu'à trois tuiles de ça, il y a littéralement un convoyeur que j'ai posé moi
  [...] ils pourraient clairement utiliser un splitter pour relier l'input de ce bloc avec le flux du splitter [...] les inputs des box
  [...] sont jamais améliorés. »

  Aujourd'hui (mesuré, journaux MESURE-DC et partie du DC) : 0 à 5 % des quais d'entrée de modules sont servis par un tapis (liaison à la
  sortie d'un autre module) ; tout le reste est un coffre vidé par des tournées « fill » de PNJ. Aucun code ne regarde les tapis du monde.

  IDÉE. Une entrée de bloc servie à la main peut être alimentée par le SURPLUS d'un tapis déjà posé qui porte son objet : un répartiteur
  posé sur ce tapis, sa sortie secondaire prolongée par un tapis jusqu'au bras du quai. Le coffre du quai reste en tampon (aucune tête de
  module touchée, repli PNJ gratuit : le coffre baisse sous Build.QUAI_LOW, la tournée reprend seule).

  1. NON-AFFAMEMENT (P1). Le répartiteur est écrit avec la priorité de sortie sur le tapis PRINCIPAL (Pq.geometry) : la branche ne reçoit
     que ce que l'aval ne peut pas prendre. Garantie du moteur, pas une estimation. Conséquence : un tapis dont l'aval prend tout ne donne
     rien ; la règle exige donc un SURPLUS OBSERVÉ (tuile dense dans une part des relevés, Pq.observe / Pq.tile_verdict). Un tapis MIXTE
     (un autre objet vu) est refusé : un filtre de répartiteur enverrait TOUT l'objet à la branche.
  2. SOURCES (Pq.rank). Pour un quai : chaque tuile candidate d'un tapis (côté gauche ou droit du répartiteur) et chaque sortie de module
     de même objet (appariement Li.pairs, tel quel) sont classées par retour (coût / valeur du travail + temps de pose, sur le gain Li.worth).
     À égalité de retour, la sortie de module (déjà éprouvée) passe avant le tapis.
  3. GÉOMÉTRIE (Pq.geometry) : centre du répartiteur au milieu des deux tuiles, priorité = côté du tapis principal, premier tuile de la
     branche devant la tuile latérale. ENTITÉS (Pq.entities) et PREUVE (Pq.verify) : tuiles distinctes, chaînage, dernière tuile vers le bras,
     le bras prend au bout du tapis et dépose dans le coffre. Le répartiteur lui-même est posé par le script (remplacement sur place,
     comme l'amélioration des tapis), APRÈS la branche : jamais de moitié de débit perdue vers une branche inachevée.
  4. COFFRE (Pq.CHEST) : toujours gardé en tampon, barre posée (Li.bar).
  5. JOURNAL (Pq.line, Pq.bilan_line) : une ligne [FO-PIQUAGE] par quai amélioré ou refusé, avec la cause.

  Déterminisme : listes triées, aucun `pairs` dans une décision, aucune trigonométrie, aucun temps mesuré.
]]

local Li = require("shared.team.liaison")

local Pq = {}

-- Observation d'un tapis (relevés toutes les Li.PERIOD)
Pq.MIN_SAMPLES = 3          -- relevés d'une tuile avant toute décision
Pq.WINDOW = 9               -- relevés qui comptent : au-delà, les anciens pèsent de moins en moins (un tapis qui se remplit tard doit pouvoir qualifier ;
                            -- micro-banc du 8/11 : 33 relevés denses sur 50 après un début vide)
Pq.TILE_CAP = 8             -- objets d'une tuile de tapis pleine (4 par voie)
Pq.DENSE_AT = 6             -- objets sur la tuile à partir desquels le relevé la dit dense (tapis qui s'accumule)
Pq.JAM_FRAC = 0.66          -- part des relevés denses exigée (surplus observé)
Pq.MAX_CANDS = 6            -- tuiles essayées au plus par plan
Pq.MAX_SPAN = Li.MAX_SPAN   -- tuiles : une sortie de module plus loin n'est pas appariée (règle de la liaison)
Pq.SEARCH_SPAN = Pq.MAX_SPAN -- tuiles (Manhattan) : un tapis plus loin du bras du quai n'est pas cherché (30 jusqu'au 8/11 13 h ; 40 = la portée de la liaison,
                            -- le tracé reste borné par Li.route_ok : 48 tuiles et détour 1,5 au plus)
Pq.PREFER_TAPIS = 2.0       -- le tapis existant est le choix PAR DÉFAUT : il passe devant une sortie de module dont le retour ne vaut pas moins de la moitié du sien

-- Prix (plaques-équivalent par pièce, NON MESURÉS : un répartiteur et une paire de souterrains valent de l'ordre de 24 et 17 plaques)
Pq.PRICE = { belt = Li.PRICE.belt, arm = Li.PRICE.arm, pole = Li.PRICE.pole, split = 24, ug = 17.5 }

-- Coffre du quai
Pq.CHEST = "tampon"
Pq.CHEST_WHY = "le repli PNJ existe deja (le coffre baisse sous QUAI_LOW et la tournee reprend), la tete du module n'est pas touchee "
  .. "(remplacement sur place, F70, F86, F90) et le retirer ne gagnerait rien"

local DV = Li.DV
local LEFT = { [0] = { -1, 0 }, [2] = { 0, -1 }, [4] = { 1, 0 }, [6] = { 0, 1 } } -- gauche d'un tapis tourné vers d (nord : ouest)
Pq.LEFT = LEFT

---------------------------------------------------------------------------------------------------
-- 1. Observation d'une tuile de tapis
---------------------------------------------------------------------------------------------------
--- Accumule un relevé. obs = { n, dense, mixed, sum } ou nil ; sample = { count = objets VOULUS sur la tuile (les deux voies),
--- other = objets d'une autre nature }. Rend le nouvel obs (nombres seuls : gardé en mémoire de la passe, jamais d'entité).
function Pq.observe(obs, sample)
  obs = obs or { n = 0, dense = 0, mixed = 0, sum = 0, hist = "" }
  obs.n = obs.n + 1
  obs.sum = obs.sum + (sample.count or 0)
  if (sample.count or 0) >= Pq.DENSE_AT then obs.dense = obs.dense + 1 end
  if (sample.other or 0) > 0 then obs.mixed = obs.mixed + 1 end
  -- fenêtre glissante : les WINDOW derniers relevés (« 1 » dense, « 0 » non) décident ; `mixed` ne s'oublie pas (un autre objet vu reste vu)
  obs.hist = ((obs.hist or "") .. ((sample.count or 0) >= Pq.DENSE_AT and "1" or "0")):sub(-Pq.WINDOW)
  return obs
end

--- La tuile peut-elle porter un répartiteur ? c = { obs, shape ("straight" ...), back (une tuile alimente celle-ci), front (le tapis se
--- prolonge devant) }. Rend ok, cause.
function Pq.tile_verdict(c)
  local o = c.obs
  if not o or o.n < Pq.MIN_SAMPLES then
    return false, string.format("releves insuffisants (%d sur %d)", o and o.n or 0, Pq.MIN_SAMPLES), "releves_insuffisants"
  end
  if o.mixed > 0 then return false, "tapis mixte (un autre objet vu : un repartiteur filtre affamerait l'aval)", "tapis_mixte" end
  local wn = o.hist and #o.hist or o.n
  local wd = o.hist and select(2, o.hist:gsub("1", "")) or o.dense
  local need = math.ceil(Pq.JAM_FRAC * wn - 1e-9)
  if wd < need then
    return false, string.format("surplus non observe (tuile dense %d fois sur les %d derniers releves, il en faut %d)", wd, wn, need), "surplus_non_observe"
  end
  if c.shape ~= "straight" then return false, "tapis en courbe", "tuile_impropre" end
  if not c.back then return false, "rien n'alimente la tuile", "tuile_impropre" end
  if not c.front then return false, "le tapis ne se prolonge pas", "tuile_impropre" end
  return true, string.format("surplus observe (dense %d fois sur les %d derniers releves)", wd, wn)
end

---------------------------------------------------------------------------------------------------
-- 2. Géométrie du répartiteur
---------------------------------------------------------------------------------------------------
--- Répartiteur posé sur la tuile (tx, ty) d'un tapis tourné vers d, la branche partant du côté `side` ("left" ou "right"). Rend
--- { x, y (centre), dir, side_tile, branch (première tuile de la branche), main (tuile du tapis qui continue), priority (côté du tapis
--- PRINCIPAL : "left" ou "right"), side }.
function Pq.geometry(tx, ty, d, side)
  local l = LEFT[d]
  local v = DV[d]
  local sgn = (side == "left") and 1 or -1
  local sx, sy = tx + sgn * l[1], ty + sgn * l[2]
  return {
    x = (tx + sx) / 2 + 0.5, y = (ty + sy) / 2 + 0.5, dir = d, side = side,
    tile = { x = tx, y = ty }, side_tile = { x = sx, y = sy },
    branch = { x = sx + v[1], y = sy + v[2] }, main = { x = tx + v[1], y = ty + v[2] },
    priority = (side == "left") and "right" or "left",
  }
end

---------------------------------------------------------------------------------------------------
-- 3. Prix
---------------------------------------------------------------------------------------------------
--- Longueur de tapis estimée avant tracé (le tracé réel remplace l'estimation).
function Pq.est_tiles(span) return math.ceil(span * Li.EST_FACTOR + 2) end

--- Coût en plaques-équivalent : tapis, paires de souterrains, un répartiteur, un bras (celui du quai), un poteau.
function Pq.cost(tiles, ug_pairs, price)
  price = price or Pq.PRICE
  return tiles * price.belt + (ug_pairs or 0) * price.ug + price.split + price.arm + price.pole
end

--- Le piquage se paie-t-il ? inp = { flow, dist (du quai au QG), tiles, ug, fill, low, threat, price, labor, tmax }. Même gain que la
--- liaison (Li.worth : tournées économisées), coût de la branche. Rend ok, raison, détail { payback_min, cost, labor_s_min, tmax, tiles }.
function Pq.worth(inp)
  local flow = inp.flow or 0
  if flow < Li.MIN_FLOW then
    return false, string.format("debit du quai %.3f/s : rien a economiser", flow), { payback_min = math.huge }
  end
  local tiles = inp.tiles or Pq.est_tiles(inp.span or 0)
  local ug = inp.ug or 0
  local ok0, _, d0 = Li.worth({ flow = flow, dist = inp.dist, span = 0, tiles = 0, fill = inp.fill, low = inp.low, tmax = math.huge,
    price = { belt = 0, arm = 0, pole = 0 }, labor = inp.labor })
  local labor = inp.labor or Li.LABOR_VALUE
  local cost = Pq.cost(tiles, ug, inp.price)
  local n_ent = tiles + 2 + 2 * ug -- le répartiteur est posé par le script : ni marche ni temps de PNJ
  local build_s = n_ent * Li.POSE_S + math.ceil(n_ent / Li.BATCH) * d0.trip_s
  local pay_s = cost / labor + build_s
  local payback = pay_s / d0.labor_s_min
  local tmax = inp.tmax or Li.TMAX
  if inp.threat then tmax = tmax / Li.THREAT_DIV end
  local det = { payback_min = payback, cost = cost, labor_s_min = d0.labor_s_min, tmax = tmax, tiles = tiles, ug = ug, build_s = build_s,
    trips_min = d0.trips_min }
  if not ok0 then return false, "gain nul", det end
  if payback > tmax then
    return false, string.format("retour %.0f min > %.0f min (%.2f PNJ-s/min economisees, %d tuiles, cout %.0f)", payback, tmax, d0.labor_s_min, tiles, cost), det
  end
  return true, string.format("retour %.0f min <= %.0f min (%.2f PNJ-s/min economisees, %d tuiles, cout %.0f)", payback, tmax, d0.labor_s_min, tiles, cost), det
end

---------------------------------------------------------------------------------------------------
-- 4. Classement des sources d'un quai
---------------------------------------------------------------------------------------------------
--- dock = { key, item, flow, dist, fill, low, threat }.
--- cands = tuiles de tapis candidates { key, x, y, dir, obs, shape, back, front, sides = { left = { span }, right = { span } } } : `sides`
---   ne porte que les côtés dont la tuile latérale ET la tuile de départ de la branche sont libres ; span = Manhattan de la tuile de départ
---   de la branche à la tuile d'arrivée du tapis près du bras du quai.
--- outs = sorties de module appariées { key, span } (Li.pairs).
--- opts = { arm_rate (objets/s du bras du quai, nil : non contrôlé), price, labor }.
--- Rend la liste des options, la meilleure d'abord : { kind = "tapis" | "sortie", key, ok, why, payback, cost, span, tiles, side, x, y, dir }.
function Pq.rank(dock, cands, outs, opts)
  opts = opts or {}
  local list = {}
  local function w(span)
    return Pq.worth({ flow = dock.flow, dist = dock.dist, span = span, fill = dock.fill, low = dock.low, threat = dock.threat,
      price = opts.price, labor = opts.labor })
  end
  for _, c in ipairs(cands or {}) do
    local opt = { kind = "tapis", key = c.key, x = c.x, y = c.y, dir = c.dir }
    local ok, why, code = Pq.tile_verdict(c)
    local best_side, best_span
    for _, side in ipairs({ "left", "right" }) do
      local s = c.sides and c.sides[side]
      if s and (not best_span or s.span < best_span) then best_side, best_span = side, s.span end
    end
    if not ok then
      opt.ok, opt.why, opt.code = false, why, code
    elseif not best_side then
      opt.ok, opt.why, opt.code = false, "aucune place pour le repartiteur et le depart de la branche", "aucune_place"
    elseif best_span > Pq.SEARCH_SPAN then
      opt.ok, opt.why, opt.code = false, string.format("trop loin (%d tuiles > %d)", best_span, Pq.SEARCH_SPAN), "trop_loin"
    elseif opts.arm_rate and dock.flow > opts.arm_rate then
      opt.ok, opt.why, opt.code = false, string.format("bras du quai trop lent (%.2f/s voulus, %.2f/s)", dock.flow, opts.arm_rate), "bras_lent"
    else
      local pok, pwhy, det = w(best_span)
      opt.ok, opt.why, opt.payback, opt.cost, opt.span, opt.tiles, opt.side = pok, pwhy, det.payback_min, det.cost, best_span, det.tiles, best_side
      opt.code = pok and "ok" or "ne_se_paie_pas"
      if pok then opt.why = why .. " ; " .. pwhy end
    end
    list[#list + 1] = opt
  end
  for _, o in ipairs(outs or {}) do
    local opt = { kind = "sortie", key = o.key, span = o.span }
    local pok, pwhy, det = Li.worth({ flow = dock.flow, dist = dock.dist, span = o.span, fill = dock.fill, low = dock.low, threat = dock.threat,
      price = opts.price and { belt = opts.price.belt, arm = opts.price.arm, pole = opts.price.pole } or nil, labor = opts.labor })
    opt.ok, opt.why, opt.payback, opt.cost, opt.tiles = pok, pwhy, det.payback_min, det.cost, det.tiles
    opt.code = pok and "ok" or "ne_se_paie_pas"
    list[#list + 1] = opt
  end
  table.sort(list, function(a, b)
    if (a.ok == true) ~= (b.ok == true) then return a.ok == true end
    local pa, pb = a.payback or math.huge, b.payback or math.huge
    if pa ~= pb then return pa < pb end
    if a.kind ~= b.kind then return a.kind == "sortie" end
    return tostring(a.key) < tostring(b.key)
  end)
  -- choix par défaut : un tapis qui se paie passe devant une sortie de module qui ne rapporte pas plus de PREFER_TAPIS fois mieux
  if list[1] and list[1].kind == "sortie" and list[1].ok then
    for i = 2, #list do
      local t = list[i]
      if t.kind == "tapis" and t.ok then
        if t.payback <= list[1].payback * Pq.PREFER_TAPIS then table.remove(list, i); table.insert(list, 1, t) end
        break
      end
    end
  end
  return list
end

--- MOTS FIXES des verdicts et des causes écrits à l'état (b.piquage.quais, lus par la vue du cerveau, script/team/piquage.lua) : jamais un texte libre.
Pq.VERDICT_CODES = { "attente", "demande", "branche_finie", "repartiteur_pose", "actif", "inerte", "coupe", "refuse", "laisser" }
Pq.CAUSE_CODES = { "ok", "releves_insuffisants", "tapis_mixte", "surplus_non_observe", "tuile_impropre", "aucune_place", "trop_loin", "bras_lent",
  "ne_se_paie_pas", "aucune_source", "sortie_plus_rentable", "a_confirmer", "menace", "ennemi", "essais_epuises", "pieces_inconnues",
  "repartiteur_manquant", "repartiteur_a_fabriquer", "remplacement_refuse", "projet_refuse", "projet_rouvert", "livre", "ne_livre_pas" }

--- Verdict d'un quai sans option qui se paie : la raison de la meilleure option refusée (ou « aucune source »).
function Pq.why_none(list)
  if not list or #list == 0 then return "aucune source : ni tapis qui porte l'objet a portee, ni sortie de module du meme objet" end
  return list[1].why
end

---------------------------------------------------------------------------------------------------
-- 5. Entités et preuve
---------------------------------------------------------------------------------------------------
--- Entités de la BRANCHE (le répartiteur n'en fait pas partie, il est posé par le script). inp = { geo, dst (site d'arrivée Li.sites),
--- route = { {x, y, dir} } de geo.branch à dst.bx/by, names = { arm, belt, pole }, pole = { tx, ty } }.
function Pq.entities(inp)
  local out = {}
  for _, t in ipairs(inp.route) do -- (lot COLONNES : t.ug = "input" | "output" : pièce souterraine du tracé de Trav.route)
    out[#out + 1] = { name = t.ug and inp.names.ug or inp.names.belt, type = t.ug, x = t.x + 0.5, y = t.y + 0.5, dir = t.dir, role = "liaison-tapis" }
  end
  local d = inp.dst
  out[#out + 1] = { name = inp.names.arm, x = d.ax + 0.5, y = d.ay + 0.5, dir = d.dir, role = "liaison-bras" }
  if inp.pole then
    out[#out + 1] = { name = inp.names.pole, x = inp.pole[1] + 0.5, y = inp.pole[2] + 0.5, dir = 0, role = "liaison" }
  end
  return out
end

--- Preuve géométrique. geo = Pq.geometry(...), D = tuile du coffre du quai { x, y }, isbelt(e), isarm(e) : prédicats. Rend les écarts (vide : juste).
function Pq.verify(geo, ents, D, isbelt, isarm)
  local bad = {}
  local belts, arms, count = {}, {}, 0
  local function key(x, y) return x .. ":" .. y end
  for _, e in ipairs(ents) do
    local tx, ty = math.floor(e.x), math.floor(e.y)
    if isbelt(e) then
      if belts[key(tx, ty)] then bad[#bad + 1] = "deux tapis sur " .. key(tx, ty) end
      belts[key(tx, ty)] = e
      count = count + 1
    elseif isarm(e) then
      arms[#arms + 1] = { tx = tx, ty = ty, dir = e.dir }
    end
  end
  if #arms ~= 1 then bad[#bad + 1] = string.format("%d bras au lieu de 1", #arms) return bad end
  if count == 0 then bad[#bad + 1] = "aucun tapis" return bad end
  local arm = arms[1]
  local av = DV[arm.dir]
  if arm.tx - av[1] ~= D.x or arm.ty - av[2] ~= D.y then bad[#bad + 1] = "le bras ne depose pas dans le coffre du quai" end
  local px, py = arm.tx + av[1], arm.ty + av[2] -- tuile où le bras prend
  local cx, cy = geo.branch.x, geo.branch.y
  local first = belts[key(cx, cy)]
  if not first then bad[#bad + 1] = "pas de tapis sur la sortie du repartiteur" return bad end
  if first.dir == (geo.dir + 4) % 8 then bad[#bad + 1] = "le premier tapis remonte vers le repartiteur" end
  local n = 0
  while true do
    local e = belts[key(cx, cy)]
    if not e then bad[#bad + 1] = string.format("le tapis s'arrete en %s sans atteindre le bras", key(cx, cy)) return bad end
    n = n + 1
    if n > count then bad[#bad + 1] = "boucle de tapis" return bad end
    local v = DV[e.dir]
    local nx, ny = cx + v[1], cy + v[2]
    if belts[key(nx, ny)] then
      cx, cy = nx, ny
    else
      if nx ~= arm.tx or ny ~= arm.ty then bad[#bad + 1] = string.format("la derniere tuile %s ne mene pas au bras", key(cx, cy)) end
      if px ~= cx or py ~= cy then bad[#bad + 1] = "le bras ne prend pas sur la derniere tuile" end
      break
    end
  end
  if n ~= count then bad[#bad + 1] = string.format("%d tuile(s) de tapis hors de la chaine sur %d", count - n, count) end
  return bad
end

---------------------------------------------------------------------------------------------------
-- 6. Décision et suivi
---------------------------------------------------------------------------------------------------
--- Même décision que la liaison (confirmation, essais bornés, menace, ennemi, plafond d'ouvertes) : Li.decide, tel quel.
function Pq.decide(inp) return Li.decide(inp) end

--- Le piquage livre-t-il ? stock_n = objets au coffre du quai, low = Build.QUAI_LOW, branch = objets vus sur le tapis de la branche.
function Pq.delivers(stock_n, low, branch)
  return (stock_n or 0) >= (low or 0) or (branch or 0) > 0
end

---------------------------------------------------------------------------------------------------
-- 7. Journal
---------------------------------------------------------------------------------------------------
--- `[FO-PIQUAGE] <equipe> : quai <cle> (<objet>, <debit>/s, a <d> tuiles du QG) : <verdict> : <cause> a <min> min`
Pq.VERDICTS = { "piquage demande", "piquage refuse", "laisser", "attendre", "branche finie", "repartiteur pose", "piquage actif",
  "piquage ne livre pas", "coupe" }
function Pq.line(team, dock, verdict, cause, minutes)
  return string.format("[FO-PIQUAGE] %s : quai %s (%s, %.2f/s, a %.0f tuiles du QG) : %s : %s a %.1f min", team or "player", tostring(dock.key),
    tostring(dock.item), dock.flow or 0, dock.dist or 0, verdict, tostring(cause), minutes or 0)
end

--- `[FO-PIQUAGE] <equipe> : bilan : quais d'entree N, servis par tapis T, par piquage K, tournees fill R (objets O) a <min> min`
function Pq.bilan_line(team, n)
  return string.format("[FO-PIQUAGE] %s : bilan : quais d'entree %d, servis par tapis %d, par piquage %d, tournees fill %d (objets %d) a %.1f min%s",
    team or "player", n.docks or 0, n.linked or 0, n.piques or 0, n.tours or 0, n.items or 0, n.minutes or 0,
    n.causes and n.causes ~= "" and (" ; verdict/cause par quai : " .. n.causes) or "")
end

return Pq
