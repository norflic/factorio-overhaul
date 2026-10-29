--[[
  MIGRATION-CHAMP (retour du DC du 29/10 en jouant la 0.6.16) : un avant-poste de PAIRES foreuse thermique + four posés SUR le minerai
  est migré PAR PARTIES vers des foreuses électriques en rangées, reliées à un collecteur qui alimente une ligne de fonte hors du minerai.
  PUR : aucune API Factorio, aucun nom d'objet (noms, cadences et gabarits arrivent en DONNÉES : tests/iag_test.lua §8 bis).

  Le DC : « les foreuses thermiques, elles mettent directement dans des fours parce qu'évidemment, c'est le plus optimal. Sauf qu'en
  fait, si jamais on doit poser des foreuses thermiques, l'idée, ça serait de supprimer ces foreuses [...] des foreuses électriques,
  pardon, ou des foreuses tiers 1, tiers 2 [...] L'idéal, ça serait du coup de revoir l'organisation du champ, en tout cas de parties
  du champ qui, par exemple, sont sur thermique, c'est pas optimal, on met de l'électrique à la place, on enlève les fours ceux qui
  sont directement sur les ressources, on place des foreuses à la place » ; « on veut des rangées de foreuses ».

  Principe (l'exécution est script/team/migration_champ.lua, qui réutilise le PLAN DIRECTEUR : gabarit « fonderie à tapis » et « ligne de
  foreuses » de 0.6.17, poteaux, tapis, fantômes, PNJ bâtisseurs) :
    1. choisir une PARTIE du champ (M.pick_band) : quelques paires voisines d'un même lot du treillis dont le retrait libère assez de
       place pour une ligne de foreuses électriques (M.fits), sans jamais retirer la dernière paire qui produit (M.can_retire) ;
    2. demander au plan directeur une fonderie à tapis dont les tuiles de la partie comptent comme LIBRES au plan (spec.degel) ;
    3. attendre que le projet ait ses matières (le retrait n'a lieu qu'ensuite : le champ produit pendant l'attente), puis retirer
       la partie (M.gate) : objets repris au stock, rien de détruit sans être rendu ;
    4. la partie suivante ne démarre que lorsque la ligne neuve a PRODUIT (M.watch).
  Garanties : la production ne tombe jamais à 0 par la faute de la migration (au moins keep_pairs paires debout tant qu'aucune ligne neuve
  n'a produit) ; rien n'est retiré avec un ennemi à moins de CFG.safe tuiles ; une partie qui ne libère rien n'est pas retirée.

  M.match(drills, sinks, drop)         -> paires foreuse/four (le dépôt de la foreuse tombe dans le four).
  M.sizing(k, r)                       -> taille de la ligne neuve pour k paires retirées : { old, pairs, rows, rate }.
  M.fits(rect, freed, others, w, h)    -> place d'une ligne w x h dans le lot, libre de toute paire restante.
  M.pick_band(pairs, ctx)              -> la partie à migrer { lot, ids, n, pairs, rows, rate, thaw, fit } ou nil, raison.
  M.start_ok(c)                        -> faut-il lancer la migration de cet avant-poste ? (vrai/faux, raison)
  M.can_retire(c)                      -> le retrait garde-t-il de la production ? (vrai/faux, raison)
  M.gate(st, p, env)                   -> décision au moment du retrait : retirer, passer, attendre, annuler.
  M.watch(st, p, env)                  -> suite du chantier : produit, attendre, ligne perdue.

  Déterminisme : listes triées, égalités départagées par les identifiants, aucun `pairs` décisionnel, aucun temps mesuré.
]]

local Sw = require("shared.team.foreuse_swap")

local M = {}

-- Réglages propres à la migration (ni dans shared/team/config.lua, ni de nom d'objet). Durées en ticks.
M.CFG = {
  every = 600,            -- une pensée de migration toutes les 10 s
  safe = 28,              -- tuiles : aucun ennemi plus près (un nid à cette portée : on attend)
  min_pairs = 3,          -- paires thermiques au moins pour lancer la migration d'un avant-poste
  max_part_pairs = 8,     -- paires retirées d'un coup au plus
  keep_pairs = 1,         -- paires debout tant qu'aucune ligne neuve n'a produit
  min_rows = 2,           -- rangées de fours au moins (sous 2 rangées, le tapis de foreuses est refusé par le plan : seuil du tapis)
  min_plates = 150,       -- plaques libres au coffre au moins pour lancer (la ligne coûte du fer : jamais au détriment du reste)
  min_overlap = 0.4,      -- part de la ligne qui doit tomber sur la place libérée
  lot_margin = 1,         -- tuiles : marge du lot (P.fit)
  zone_slack = 2,         -- tuiles : jeu laissé au plan autour de la ligne promise (la ligne neuve se pose DANS la place libérée)
  lots_tried = 3,         -- lots essayés
  seeds_tried = 3,        -- points de départ essayés par lot
  gate_wait = 30 * 3600,  -- 30 min : matières ou plan attendus avant d'annuler la demande
  safe_wait = 20 * 3600,  -- 20 min : zone sûre attendue au moment du retrait
  build_warn = 45 * 3600, -- 45 min : chantier lent (journal)
  fini_wait = 15 * 3600,  -- 15 min : ligne finie qui ne produit pas encore (journal)
  build_max = 90 * 3600,  -- 90 min : chantier de la ligne neuve qui n'aboutit pas : la migration s'arrête (le plan garde son projet)
  fini_max = 60 * 3600,   -- 60 min : ligne finie qui ne produit toujours rien : la migration s'arrête
  retry = 15 * 3600,      -- 15 min avant un nouvel essai
  max_fails = 3,          -- demandes annulées ou refusées de suite avant d'abandonner l'avant-poste
  max_noop = 2,           -- lignes posées sans libérer la place voulue avant d'abandonner
  produce_min = 10,       -- produits finis par la ligne neuve avant de passer à la partie suivante
  logs = 60,              -- lignes de journal [FO-MIGRATION] au plus par équipe
  prio = 52,              -- priorité des tâches du chantier
  -- lot MIGRATION-DECLENCHE (retour du DC du 29/10 en jouant la 0.6.18 : « ils peuvent plus laisser des foreuses thermiques comme ça
  -- posées ») : une partie REFUSÉE par le plan n'est plus redemandée telle quelle (partie de scarlet refusée 3 fois à l'identique,
  -- « tapis des foreuses (minerai) », puis champ de 20 paires abandonné pour toujours) ; un abandon n'est plus définitif.
  retry_refuse = 3600,    -- 1 min : nouvel essai après un refus du plan (une AUTRE partie : la refusée est écartée)
  max_bad = 8,            -- parties refusées retenues au plus par avant-poste
  revive = 30 * 3600,     -- 30 min : un avant-poste abandonné (échecs de suite) repart d'un état neuf
}

local EPS = 1e-6
local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max

---------------------------------------------------------------------------------------------------
-- Géométrie
---------------------------------------------------------------------------------------------------
--- Boîte { x0, y0, x1, y1 } d'un objet { x, y, w, h } (centre et taille).
function M.box(c)
  return { x0 = c.x - c.w / 2, y0 = c.y - c.h / 2, x1 = c.x + c.w / 2, y1 = c.y + c.h / 2 }
end

local function union(a, b)
  return { x0 = min(a.x0, b.x0), y0 = min(a.y0, b.y0), x1 = max(a.x1, b.x1), y1 = max(a.y1, b.y1) }
end

--- Tuiles recouvertes par les boîtes (un contact par le bord ne compte pas, F96) : liste PLATE { tx, ty, tx, ty... }, sans doublon,
--- triée par ty puis tx.
function M.tiles(boxes)
  local seen, list = {}, {}
  for _, b in ipairs(boxes) do
    for ty = floor(b.y0 + EPS), ceil(b.y1 - EPS) - 1 do
      for tx = floor(b.x0 + EPS), ceil(b.x1 - EPS) - 1 do
        local k = ty * 1048576 + tx
        if not seen[k] then seen[k] = true; list[#list + 1] = { tx, ty } end
      end
    end
  end
  table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] < b[2] end return a[1] < b[1] end)
  local out = {}
  for _, t in ipairs(list) do out[#out + 1] = t[1]; out[#out + 1] = t[2] end
  return out
end

local function inside(b, rect, margin)
  return b.x0 >= rect.x0 + margin - EPS and b.y0 >= rect.y0 + margin - EPS and b.x1 <= rect.x1 - margin + EPS and b.y1 <= rect.y1 - margin + EPS
end

---------------------------------------------------------------------------------------------------
-- Paires
---------------------------------------------------------------------------------------------------
--- Paires foreuse + four d'un avant-poste. drills = { { id, x, y, dir, w, h } }, sinks = { { id, x, y, w, h } }, drop = { dx, dy } (point
--- de dépôt de la foreuse vers le nord). Une foreuse forme une paire avec le premier four (par id) dont la boîte contient son dépôt.
--- Rend la liste triée par id de foreuse de { id, sink_id, drill = { x, y, w, h }, sink = { x, y, w, h } }.
function M.match(drills, sinks, drop)
  local ds, ss = {}, {}
  for _, d in ipairs(drills) do ds[#ds + 1] = d end
  for _, s in ipairs(sinks) do ss[#ss + 1] = s end
  table.sort(ds, function(a, b) return a.id < b.id end)
  table.sort(ss, function(a, b) return a.id < b.id end)
  local out = {}
  for _, d in ipairs(ds) do
    local vx, vy = Sw.rotate(d.dir or 0, drop[1], drop[2])
    for _, s in ipairs(ss) do
      if Sw.inside({ x = s.x, y = s.y, w = s.w, h = s.h }, d.x + vx, d.y + vy) then
        out[#out + 1] = { id = d.id, sink_id = s.id, drill = { x = d.x, y = d.y, w = d.w, h = d.h },
          sink = { x = s.x, y = s.y, w = s.w, h = s.h } }
        break
      end
    end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Taille de la ligne neuve
---------------------------------------------------------------------------------------------------
--- Ligne neuve pour k paires thermiques retirées. r = { burner, electric (minerai/s par foreuse), row_cap (plaques/s d'une rangée de
--- 2 fours), furnace (plaques/s d'un four), pairs_max (paires au plus d'un collecteur) }.
--- old   : plaques/s que les k paires livraient (une foreuse thermique, un four : le plus lent des deux) ;
--- pairs : paires de foreuses électriques (2 foreuses chacune) qui livrent au moins old ;
--- rows  : rangées de fours (2 fours) qui fondent old, au moins CFG.min_rows (le plan refuse un tapis sous 1 minerai/s) ;
--- rate  : débit demandé au plan (plaques/min) qui donne exactement `rows` rangées.
function M.sizing(k, r, cfg)
  cfg = cfg or M.CFG
  local old = k * min(r.burner, r.furnace or math.huge)
  local pairs_n = max(1, min(r.pairs_max or 1, ceil(old / (2 * r.electric) - 1e-9)))
  local rows = max(cfg.min_rows, ceil(old / r.row_cap - 1e-9))
  return { old = old, pairs = pairs_n, rows = rows, rate = rows * r.row_cap * 60 }
end

---------------------------------------------------------------------------------------------------
-- Place libérée
---------------------------------------------------------------------------------------------------
--- Une ligne w x h (ou h x w) tient-elle dans le lot `rect` { x0, y0, x1, y1 } (x1, y1 exclus), à `lot_margin` tuiles du bord, sans
--- toucher une tuile d'`others` (paires qui RESTENT) et avec au moins min_overlap de ses tuiles sur la place libérée `freed` ?
--- freed, others : listes plates de tuiles. Rend { x, y, w, h, freed } (le meilleur recouvrement, puis le premier balayé) ou nil.
function M.fits(rect, freed, others, w, h, cfg)
  cfg = cfg or M.CFG
  local W, H = rect.x1 - rect.x0, rect.y1 - rect.y0
  if W <= 0 or H <= 0 then return nil end
  local function sat_of(flat)
    local cell = {}
    for i = 1, #flat - 1, 2 do
      local x, y = flat[i] - rect.x0, flat[i + 1] - rect.y0
      if x >= 0 and x < W and y >= 0 and y < H then cell[y * W + x + 1] = true end
    end
    local sat = {}
    for x = 0, W do sat[x] = 0 end
    for y = 1, H do
      sat[y * (W + 1)] = 0
      local row = 0
      for x = 1, W do
        if cell[(y - 1) * W + x] then row = row + 1 end
        sat[y * (W + 1) + x] = sat[(y - 1) * (W + 1) + x] + row
      end
    end
    return sat
  end
  local occ, fre = sat_of(others), sat_of(freed)
  local function count(sat, x0, y0, lw, lh) -- x0, y0 relatifs au lot
    local a, b = y0 * (W + 1), (y0 + lh) * (W + 1)
    return sat[b + x0 + lw] - sat[a + x0 + lw] - sat[b + x0] + sat[a + x0]
  end
  local m = cfg.lot_margin
  local best
  local orients = { { w, h } }
  if w ~= h then orients[2] = { h, w } end
  for _, o in ipairs(orients) do
    local lw, lh = o[1], o[2]
    local need = ceil(cfg.min_overlap * lw * lh - 1e-9)
    for ty = m, H - m - lh do
      for tx = m, W - m - lw do
        if count(occ, tx, ty, lw, lh) == 0 then
          local fr = count(fre, tx, ty, lw, lh)
          if fr >= need and (not best or fr > best.freed) then
            best = { x = rect.x0 + tx, y = rect.y0 + ty, w = lw, h = lh, freed = fr }
          end
        end
      end
    end
  end
  return best
end

---------------------------------------------------------------------------------------------------
-- Choix de la partie
---------------------------------------------------------------------------------------------------
--- Clé d'une partie (lot et paires triées) : une partie refusée par le plan est écartée des choix suivants (ctx.skip).
function M.band_key(lot, ids)
  return tostring(lot) .. "/" .. table.concat(ids, ",")
end

local function d2(ax, ay, bx, by) return (ax - bx) * (ax - bx) + (ay - by) * (ay - by) end

local function by_dist(list, cx, cy)
  local out = {}
  for _, it in ipairs(list) do out[#out + 1] = it end
  table.sort(out, function(a, b)
    local da, db = d2(a.cx, a.cy, cx, cy), d2(b.cx, b.cy, cx, cy)
    if da ~= db then return da < db end
    return a.p.id < b.p.id
  end)
  return out
end

--- Partie à migrer. pairs : { { id, lot (clé du lot du treillis ou nil), drill = { x, y, w, h }, sink = { x, y, w, h } } } (paires
--- VIVANTES de l'avant-poste) ; ctx = {
---   rects  = { [lot] = { x0, y0, x1, y1 } }  lots de gisement du treillis (x1, y1 exclus) ;
---   toward = { x, y }                        point que la partie doit regarder (le QG : la ligne neuve près de la base) ;
---   produced = vrai quand une ligne neuve de cet avant-poste a déjà produit ;
---   line   = function(n) -> w, h | nil        emprise d'une ligne de n paires de foreuses (le gabarit) ;
---   rates  = r de M.sizing ;
---   skip   = { [clé de partie] = true }       parties refusées par le plan (M.band_key), jamais rendues ; cfg }
--- Rend { lot, ids (triés), n, pairs, rows, rate, thaw (tuiles à compter comme libres, liste plate), fit, zone (où le plan peut poser la
--- ligne : la ligne promise et CFG.zone_slack tuiles de jeu), cx, cy } ou nil et une raison :
--- "vide" (plus de paire), "garde" (la dernière paire qui produit reste), "treillis" (aucune paire dans un lot de gisement),
--- "gabarit" (le gabarit refuse), "place" (aucune partie ne libère assez de place), "refusees" (seules des parties déjà refusées
--- par le plan tiennent).
function M.pick_band(plist, ctx)
  local cfg = ctx.cfg or M.CFG
  local total = #plist
  if total == 0 then return nil, "vide" end
  local allowed = min(ctx.produced and total or (total - cfg.keep_pairs), cfg.max_part_pairs)
  if allowed < 1 then return nil, "garde" end
  local info = {}
  for _, p in ipairs(plist) do
    local bd, bs = M.box(p.drill), M.box(p.sink)
    local u = union(bd, bs)
    info[#info + 1] = { p = p, box = u, cx = (u.x0 + u.x1) / 2, cy = (u.y0 + u.y1) / 2, tiles = M.tiles({ bd, bs }) }
  end
  table.sort(info, function(a, b) return a.p.id < b.p.id end)
  local groups, order = {}, {}
  for _, it in ipairs(info) do
    local key = it.p.lot
    local rect = key and ctx.rects[key]
    if rect and inside(it.box, rect, cfg.lot_margin) then
      if not groups[key] then groups[key] = {}; order[#order + 1] = key end
      groups[key][#groups[key] + 1] = it
    end
  end
  if #order == 0 then return nil, "treillis" end
  table.sort(order, function(a, b)
    if #groups[a] ~= #groups[b] then return #groups[a] > #groups[b] end
    return a < b
  end)
  local why = "place"
  for li = 1, min(#order, cfg.lots_tried) do
    local key = order[li]
    local cands, rect = groups[key], ctx.rects[key]
    local seeds = by_dist(cands, ctx.toward.x, ctx.toward.y)
    for si = 1, min(#seeds, cfg.seeds_tried) do
      local seed = seeds[si]
      local ranked = by_dist(cands, seed.cx, seed.cy)
      for k = 1, min(allowed, #ranked) do
        local sz = M.sizing(k, ctx.rates, cfg)
        local w, h = ctx.line(sz.pairs)
        if not w then
          why = "gabarit"
          break
        end
        local member, boxes = {}, {}
        for i = 1, k do member[ranked[i].p.id] = true; boxes[#boxes + 1] = ranked[i] end
        local fboxes = {}
        for _, it in ipairs(boxes) do
          fboxes[#fboxes + 1] = M.box(it.p.drill)
          fboxes[#fboxes + 1] = M.box(it.p.sink)
        end
        local freed = M.tiles(fboxes)
        local others = {}
        for _, it in ipairs(info) do
          if not member[it.p.id] then for _, v in ipairs(it.tiles) do others[#others + 1] = v end end
        end
        local fit = M.fits(rect, freed, others, w, h, cfg)
        if fit then
          local ids, sx, sy = {}, 0, 0
          for _, it in ipairs(boxes) do ids[#ids + 1] = it.p.id; sx, sy = sx + it.cx, sy + it.cy end
          table.sort(ids)
          local bkey = M.band_key(key, ids)
          if ctx.skip and ctx.skip[bkey] then
            why = "refusees" -- lot MIGRATION-DECLENCHE : partie déjà refusée par le plan, on cherche plus loin (k + 1, autre départ, autre lot)
          else
            local z = cfg.zone_slack
            return { lot = key, ids = ids, key = bkey, n = k, pairs = sz.pairs, rows = sz.rows, rate = sz.rate, thaw = freed, fit = fit,
              zone = { x0 = fit.x - z, y0 = fit.y - z, x1 = fit.x + fit.w + z, y1 = fit.y + fit.h + z }, cx = sx / k, cy = sy / k }
          end
        end
      end
    end
  end
  return nil, why
end

---------------------------------------------------------------------------------------------------
-- Décisions
---------------------------------------------------------------------------------------------------
--- Faut-il lancer la migration de cet avant-poste ? c = { migr (o.migr), plan (plan directeur allumé), power (réseau qui produit),
--- obtainable (objet de foreuse électrique au stock ou fabricable), plates (plaques libres), lattice (le champ est dans un lot de
--- gisement du treillis), pairs (paires thermiques vivantes), enemy (ennemi à CFG.safe tuiles), now, retry (tick avant lequel on
--- n'essaie pas) }. Rend vrai, ou faux et la raison.
function M.start_ok(c, cfg)
  cfg = cfg or M.CFG
  if c.migr == "fini" or c.migr == "partiel" or c.abandoned then return false, "fait" end
  if not c.plan then return false, "plan" end
  if not c.power then return false, "courant" end
  if not c.obtainable then return false, "objet" end
  if (c.pairs or 0) < cfg.min_pairs then return false, "paires" end
  if not c.lattice then return false, "treillis" end
  if (c.plates or 0) < cfg.min_plates then return false, "plaques" end
  if c.retry and c.now < c.retry then return false, "attente" end
  if c.enemy then return false, "ennemi" end
  return true, "ok"
end

--- Le retrait de la partie laisse-t-il de la production ? c = { present (paires de la partie encore là), total (paires vivantes de
--- l'avant-poste), produced (une ligne neuve a produit), enemy }. Rend vrai, ou faux et la raison.
function M.can_retire(c, cfg)
  cfg = cfg or M.CFG
  if c.enemy then return false, "ennemi" end
  if (c.present or 0) == 0 then return true, "vide" end
  local remaining = (c.total or 0) - c.present
  if remaining < cfg.keep_pairs and not c.produced then return false, "garde" end
  return true, "ok"
end

--- Décision au moment du retrait. st : { t0 } (début de la demande) ; p : l'état du projet du plan { state, reason } ou nil ;
--- env = { now, enemy, total, present, produced, uses (le plan s'est servi de la place de la partie), gate_age (ticks depuis que
--- le projet attend le retrait) }. Rend (action, raison) : "retirer", "passer" (le plan n'a pas besoin de la place : la ligne se
--- construit sans rien retirer), "attendre", "annuler", "echec" (projet refusé ou disparu : rien n'a été retiré).
function M.gate(st, p, env, cfg)
  cfg = cfg or M.CFG
  if not p or p.state == "refuse" then return "echec", "refuse" end
  if p.state == "attente" or p.state == "plan" then
    if env.now - st.t0 > cfg.gate_wait then return "annuler", "delai-plan" end
    return "attendre", "plan"
  end
  if p.state == "reserve" then
    if p.reason ~= "degel" then
      if env.now - st.t0 > cfg.gate_wait then return "annuler", "matieres" end
      return "attendre", "matieres"
    end
    if not env.uses then return "passer", "hors-partie" end
    local ok, why = M.can_retire(env, cfg)
    if ok then return "retirer", why end
    if why == "garde" then return "annuler", "garde" end
    if (env.gate_age or 0) > cfg.safe_wait then return "annuler", why end
    return "attendre", why
  end
  return "passer", "deja-avance" -- état plus avancé que prévu (sauvegarde ou projet repris) : on ne retire rien de plus
end

--- Suite du chantier après le retrait. env = { now, made (produits finis des fours de la ligne), t_done (tick où la ligne est finie ou nil) }.
--- Rend (action, raison) : "produit", "attendre", "perdu" (projet refusé ou disparu : la partie est vide, rien à produire), "abandonner"
--- (chantier ou production qui n'aboutit pas dans CFG.build_max / CFG.fini_max : la migration de cet avant-poste s'arrête).
function M.watch(st, p, env, cfg)
  cfg = cfg or M.CFG
  if not p or p.state == "refuse" then return "perdu", "refuse" end
  if p.state == "fini" then
    if (env.made or 0) >= cfg.produce_min then return "produit", "ok" end
    if st.t_done and env.now - st.t_done > cfg.fini_max then return "abandonner", "fini-sans-produit" end
    return "attendre", "fini-sans-produit"
  end
  if st.t_degel and env.now - st.t_degel > cfg.build_max then return "abandonner", p.state end
  if p.state == "bloque" then return "attendre", "bloque" end
  return "attendre", p.state
end

return M
