--[[
  Lot PREVISION (demande du DC du 29/10 en jouant la 0.6.18 : « l'intelligence, c'est également prévoir […] pour chaque faction,
  les équipes […] dans les choix généraux […] le cerveau principal des IA » ; arbitrages du 29/10, 22 h 15 : les IA voient
  « comme le joueur » (nids déjà vus, évolution, pollution ; aucune triche) et « oui, compter la défense » dans le coût de chaque
  investissement de production). Conception : fo-logs/2026-10-29_VAGUE9/PREVISION/CONCEPTION.md, corrigée par CRITIQUE.md
  (C5 à C9, C12).

  L'ESTIMATEUR UNIQUE de la menace des biters (il remplace le corps de l'ancien A.estimate du lot ARMEE-ANTICIPATION,
  shared/ai3/armee.lua : « 2 par nid + unités trouvées autour du champ », qui lisait des unités jamais vues). PUR (aucune API
  Factorio, aucun nom d'objet : nids, unités et tourelles arrivent en nombres lus par le runtime, script/ai3/prevision.lua).
  Testé hors jeu : tests/prevision_test.lua (avec mutants).

  Mécanique du moteur reprise (Factorio 1.1 ; HYPOTHÈSES marquées, à mesurer en moteur réel, banc `prev-vague`) :
    * un nid ABSORBE la pollution de sa case : au plus Pv.ABS + Pv.PROP × c par minute (données vanilla
      data/base/prototypes/entity/enemies.lua:127-128 : 20 et 0,01 ; l'unité « par minute » est une HYPOTHÈSE) ; chaque fois
      qu'il a absorbé le `pollution_to_join_attack` d'une unité (lu au prototype), cette unité part rejoindre un groupe ;
    * C5 (critique §3.1) : la pollution LUE à la case du nid est ce qui RESTE après absorption, pas ce qui ARRIVE. Case polluée :
      le nid absorbe à son plafond (borne haute honnête : il en reste, donc il en reçoit au moins autant). Case propre : il
      n'absorbe que ce qui arrive des 4 cases voisines (diffusion `diffusion_ratio` lue aux réglages de carte, Pv.CYCLES fois
      par minute, HYPOTHÈSE de 64 ticks par cycle), au plus son plafond ;
    * C6 (§3.2, §3.3) : la pollution n'a pas de propriétaire et la vague va vers la SOURCE : chaque nid est rattaché à NOTRE
      site le plus attirant (émission ÷ distance², sites : QG, avant-postes, champs), et seule la PART de notre équipe compte
      (contre les QG rivaux connus : Pv.share) ;
    * C7 (§3.4, §3.5) : TAILLE d'une vague (pic : débit × temps de rassemblement maximal, au plus la taille de groupe du moteur)
      distincte du DÉBIT sur l'horizon (munitions) ; ÉCHÉANCE PESSIMISTE = rassemblement minimal + marche la plus courte ;
      plafond de cadence d'un nid lu au prototype (spawn_cooldown) ; évolution PROJETÉE à l'horizon (time_factor, pollution) ;
    * C9 (§3.9) : valeurs de défense CALCULÉES depuis les prototypes (dégâts par seconde × temps sous le feu ; aucune table
      par âge) ; un seul facteur d'arène Pv.ARENA (efficacité réelle ÷ calculée, à mesurer) ;
    * C8 (§3.7) : calibration SYMÉTRIQUE (Pv.calibrate) : vague reçue mesurée par ce qui est VU au contact ET par nos PERTES ;
      fausse alerte (la vague prévue n'est pas venue dans la fenêtre que le moteur permet) et RATÉ (attaque sans prévision)
      comptés sur des faits ; k borné.
    * C12 : défense induite par un agrandissement (Pv.hp_per_emit, Pv.defense_price).

  Unité commune : les PV ennemis (une vague = somme des PV de ses unités ; une défense = PV ennemis qu'elle neutralise pendant
  une vague). Entrées triées par l'appelant, aucun `pairs` décisionnel, aucune trigonométrie (racines carrées seulement),
  aucun hasard, aucun temps mesuré.
]]

local Pv = {}

Pv.H_COURT, Pv.H_MOYEN = 5, 15   -- horizons (min) : court (imminent, « préparer ») et moyen (armée visée)
Pv.PERIOD = 3600                 -- un relevé par minute et par équipe (runtime)
-- Nids (HYPOTHÈSES sur le moteur, données vanilla ; contrôlées contre data/base par tests/prevision_test.lua).
Pv.ABS = 20                      -- pollution/min absorbée au plus par un nid, part fixe
Pv.PROP = 10                     -- ‰ de la pollution de sa case, part proportionnelle
Pv.CYCLES = 3600 / 64            -- cycles de diffusion de la pollution par minute
Pv.DIFF0 = 20                    -- ‰ : diffusion vers chaque voisine quand les réglages de carte ne la donnent pas
Pv.NESTS_MAX = 32                -- nids connus examinés au plus (les plus proches de nos sites)
Pv.R_ATTR = 224                  -- tuiles : un nid plus loin de tous nos sites ne nous vise pas
-- Défense (C9 : un seul facteur d'arène, le reste vient des prototypes).
Pv.T_HOLD = 10                   -- s : une tourelle tient sous le contact (HYPOTHÈSE, couverte par Pv.ARENA)
Pv.T_SOLDIER = 20                -- s : un soldat se bat avant de tomber (HYPOTHÈSE, couverte par Pv.ARENA)
Pv.ARENA = 1000                  -- ‰ : efficacité réelle ÷ calculée (1000 tant qu'elle n'est pas mesurée en arène)
Pv.SPEED0 = 0.2                  -- tuiles/tick : vitesse ennemie quand aucune n'est connue
-- Calibration (C8).
Pv.K0, Pv.K_MIN, Pv.K_MAX = 1000, 500, 2000
Pv.K_MISS = 250                  -- ‰ : un raté (attaque sans vague prévue) relève k de cela
Pv.LOSS_UNITS = 3                -- une pièce perdue au contact compte comme 3 unités moyennes reçues (HYPOTHÈSE)
-- C12 : part de notre pollution qui atteint des nids quand aucun n'en absorbe encore (nids connus seulement).
Pv.REACH_DEFAULT = 100           -- ‰

local function floor(x) return math.floor(x) end
local function d2(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return dx * dx + dy * dy end

---------------------------------------------------------------------------------------------------
-- Composition des vagues (prototypes des nids lus par le runtime)
---------------------------------------------------------------------------------------------------
--- Poids d'une unité à l'évolution e (‰) : `points` = { { e‰, poids } } triés par évolution (result_units du nid),
--- interpolation linéaire entre deux points, bornée aux extrémités (règle du moteur ; au-delà du dernier point : son poids).
function Pv.weight_at(points, e)
  local n = #(points or {})
  if n == 0 then return 0 end
  if e <= points[1][1] then return points[1][2] end
  for i = 2, n do
    local a, b = points[i - 1], points[i]
    if e <= b[1] then
      if b[1] <= a[1] then return b[2] end
      return a[2] + (b[2] - a[2]) * (e - a[1]) / (b[1] - a[1])
    end
  end
  return points[n][2]
end

--- Unité moyenne des nids à l'évolution e (‰). kinds = { { units = { { hp, cost, speed, pts } }, rate_max } } (un type de nid
--- par entrée, triés par l'appelant ; cost = pollution_to_join_attack ; rate_max = unités/min au plus d'un nid de ce type,
--- lu à spawn_cooldown). Les types de nids pèsent pareil (on ne sait pas lequel on voit). Rend { pbar, hbar, speed, cap } ou nil.
function Pv.mix(kinds, e)
  local nk, sc, sh, sv, cap = 0, 0, 0, 0, 0
  for _, k in ipairs(kinds or {}) do
    local W, C, H, V = 0, 0, 0, 0
    for _, u in ipairs(k.units or {}) do
      local w = Pv.weight_at(u.pts, e)
      if w > 0 and (u.cost or 0) > 0 then
        W, C, H, V = W + w, C + w * u.cost, H + w * (u.hp or 0), V + w * (u.speed or Pv.SPEED0)
      end
    end
    if W > 0 then
      nk = nk + 1
      sc, sh, sv = sc + C / W, sh + H / W, sv + V / W
      cap = cap + (k.rate_max or math.huge)
    end
  end
  if nk == 0 then return nil end
  return { pbar = sc / nk, hbar = sh / nk, speed = sv / nk, cap = cap / nk }
end

--- Évolution (‰) projetée de H minutes : chaque minute, e += (1000 − e) × g (g = gain par minute en fraction : time_factor
--- × 60 + pollution_factor × pollution émise par minute, lus aux réglages de carte) ; jamais au-dessus de 1000.
function Pv.evo_at(e, g, H)
  local x = e or 0
  for _ = 1, H or 0 do x = x + (1000 - x) * (g or 0) end
  if x > 1000 then x = 1000 end
  return floor(x + 0.5)
end

---------------------------------------------------------------------------------------------------
-- Pollution qui ARRIVE au nid (C5), part de l'équipe (C6)
---------------------------------------------------------------------------------------------------
--- Pollution/min absorbée par un nid : c = pollution de sa case, nb = somme de ses 4 cases voisines, diff = diffusion (‰).
function Pv.absorbed(c, nb, diff)
  c = (c and c > 0) and c or 0
  nb = (nb and nb > 0) and nb or 0
  local cap = Pv.ABS + Pv.PROP * c / 1000
  if c > 0 then return cap end
  local inflow = nb * (diff or Pv.DIFF0) / 1000 * Pv.CYCLES
  if inflow < cap then return inflow end
  return cap
end

--- Part (‰) de notre équipe dans un nid : attraction de notre meilleur site contre celle du QG rival le plus attirant.
function Pv.share(a_ours, a_rival)
  if not a_ours or a_ours <= 0 then return 0 end
  a_rival = (a_rival and a_rival > 0) and a_rival or 0
  return floor(1000 * a_ours / (a_ours + a_rival))
end

--- Attraction d'un site pollueur (émission/min ÷ distance²) ; 0 sans émission.
function Pv.attraction(emit, dd)
  if not emit or emit <= 0 then return 0 end
  return emit / math.max(1, dd)
end

---------------------------------------------------------------------------------------------------
-- Valeurs de défense (C9) : PV ennemis neutralisés pendant une vague
---------------------------------------------------------------------------------------------------
--- Tourelles : Σ dps × (temps de traversée de la portée + Pv.T_HOLD) × arène. dps = somme des dégâts par seconde, dpsr = somme
--- des dps × portée (tuiles) ; speed = vitesse ennemie moyenne (tuiles/tick).
function Pv.turrets_value(dps, dpsr, speed)
  local v = (speed and speed > 0) and speed or Pv.SPEED0
  return ((dps or 0) * Pv.T_HOLD + (dpsr or 0) / (v * 60)) * Pv.ARENA / 1000
end

--- Un soldat (dps lu aux données des soldats, bonus compris).
function Pv.soldier_value(dps) return (dps or 0) * Pv.T_SOLDIER * Pv.ARENA / 1000 end

---------------------------------------------------------------------------------------------------
-- L'estimation
---------------------------------------------------------------------------------------------------
--- inp = {
---   evo (‰), g (gain d'évolution par minute, fraction), kinds (Pv.mix), gather = { min, max, size } (minutes, minutes, unités),
---   diff (‰), sites = { { key, x, y, emit (pollution/min), dps, dpsr, turrets, seen (PV vus à portée d'œil), contact,
---   vx, vy (sommes PV × position des unités vues) } }
---   (triés par l'appelant), nests = { { x, y, c, nb } } (connus, triés), rivals = { { x, y } } (QG rivaux connus),
---   k = { [clé] = ‰ }, floor = { [clé] = PV } }.
--- Rend { evo5, evo15, mix, sites = { … }, by = { [clé] = site }, emit, absorbed, reach (‰), nests_used, rate }.
--- Site rendu : { key, x, y, rate (unités/min), u5, u15, w5, w15, wmod5, wmod15, wvu, eta (min), d (PV, tourelles),
---   turrets, wraw5 (PV prévus avant calibration), debit15 (PV sur 15 min), nests = { { i, u, x, y, dist } } (contributions triées), tx, ty (barycentre de la menace) }.
function Pv.estimate(inp)
  local out = { sites = {}, by = {}, emit = 0, absorbed = 0, nests_used = 0, rate = 0 }
  local g = inp.g or 0
  out.evo5 = Pv.evo_at(inp.evo or 0, g, Pv.H_COURT)
  out.evo15 = Pv.evo_at(inp.evo or 0, g, Pv.H_MOYEN)
  local mix0 = Pv.mix(inp.kinds, inp.evo or 0)
  local mix5 = Pv.mix(inp.kinds, out.evo5)
  local mix15 = Pv.mix(inp.kinds, out.evo15)
  out.mix = mix0
  local ga = inp.gather or {}
  local gmin, gmax, gsize = ga.min or 1, ga.max or 10, ga.size or 200
  local sites = inp.sites or {}
  for i, s in ipairs(sites) do
    out.emit = out.emit + math.max(0, s.emit or 0)
    local o = { key = s.key, x = s.x, y = s.y, rate = 0, nests = {}, wvu = s.seen or 0, contact = s.contact or 0,
      turrets = s.turrets or 0, emit = s.emit or 0, i = i }
    out.sites[i] = o
    out.by[s.key] = o
  end
  -- Attribution des nids (C6) : au site le plus attirant, à la part de l'équipe ; débit au plafond du prototype.
  local ref = 0
  for _, s in ipairs(sites) do if (s.emit or 0) > ref then ref = s.emit end end
  local r2max = Pv.R_ATTR * Pv.R_ATTR
  local used = 0
  for ni, n in ipairs(inp.nests or {}) do
    if used >= Pv.NESTS_MAX then break end
    local best, ba, bd = nil, 0, nil
    for _, o in ipairs(out.sites) do
      local dd = d2(n.x, n.y, o.x, o.y)
      if dd <= r2max then
        local a = Pv.attraction(o.emit, dd)
        if a > ba then best, ba, bd = o, a, dd end
      end
    end
    if best then
      used = used + 1
      local ar = 0
      for _, r in ipairs(inp.rivals or {}) do
        local a = Pv.attraction(ref, d2(n.x, n.y, r.x, r.y))
        if a > ar then ar = a end
      end
      local share = Pv.share(ba, ar)
      local abs = Pv.absorbed(n.c, n.nb, inp.diff)
      out.absorbed = out.absorbed + abs * share / 1000
      if mix0 and share > 0 and abs > 0 then
        local u = abs / mix0.pbar
        if u > mix0.cap then u = mix0.cap end
        u = u * share / 1000
        best.rate = best.rate + u
        best.nests[#best.nests + 1] = { i = ni, u = u, x = n.x, y = n.y, dist = math.sqrt(bd) }
      end
    end
  end
  out.nests_used = used
  out.reach = out.emit > 0 and math.min(1000, floor(1000 * out.absorbed / out.emit)) or 0
  -- Vagues par site (C7) : taille au pic (rassemblement maximal), échéance pessimiste (rassemblement minimal + marche la plus
  -- courte), débit sur l'horizon moyen ; ce qui est VU à portée d'œil l'emporte s'il est plus gros ; k calibré par site.
  for _, o in ipairs(out.sites) do
    table.sort(o.nests, function(a, b)
      if a.u ~= b.u then return a.u > b.u end
      return a.i < b.i
    end)
    local k = (inp.k or {})[o.key] or Pv.K0
    local wvu = o.wvu
    local fl = (inp.floor or {})[o.key] or 0
    o.wmod5, o.wmod15, o.wraw5, o.u5, o.u15, o.debit15 = 0, 0, 0, 0, 0, 0
    if o.rate > 0 and mix0 then
      out.rate = out.rate + o.rate
      local near = o.nests[1].dist
      for _, c in ipairs(o.nests) do if c.dist < near then near = c.dist end end
      local sx, sy, sw = 0, 0, 0
      for _, c in ipairs(o.nests) do sx, sy, sw = sx + c.x * c.u, sy + c.y * c.u, sw + c.u end
      o.tx, o.ty = sx / sw, sy / sw
      local travel = near / (mix0.speed * 3600)
      o.eta = gmin + travel
      local units = o.rate * gmax
      if units > gsize then units = gsize end
      o.u5, o.u15 = units, units
      if o.eta <= Pv.H_COURT then
        o.wraw5 = units * (mix5 or mix0).hbar -- prévision AVANT calibration (comparée à la vague reçue, Pv.calibrate)
        o.wmod5 = o.wraw5 * k / 1000
      end
      if o.eta <= Pv.H_MOYEN then o.wmod15 = units * (mix15 or mix0).hbar * k / 1000 end
      o.debit15 = o.rate * Pv.H_MOYEN * (mix15 or mix0).hbar
    end
    if wvu > 0 or fl > 0 then
      o.eta = o.eta and math.min(o.eta, gmin) or gmin
    end
    -- Direction de la menace sans nid rattaché : le barycentre des unités VUES (vx, vy : sommes PV × position du runtime).
    local si = inp.sites[o.i]
    if not o.tx and wvu > 0 and si.vx and si.vy then o.tx, o.ty = si.vx / wvu, si.vy / wvu end
    o.w5 = math.max(o.wmod5, wvu, fl)
    o.w15 = math.max(o.wmod15, wvu, fl)
    o.d = Pv.turrets_value(inp.sites[o.i].dps, inp.sites[o.i].dpsr, mix0 and mix0.speed)
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Calibration symétrique (C8)
---------------------------------------------------------------------------------------------------
--- Nouvelle calibration par site. cal = { [clé] = { k, ep = { pred, t, until } | nil, atk, peak, hit, fa, miss, floor } } (état
--- persistant, créé ici). facts = { [clé] = { pred_raw (PV prévus avant k), contact (PV vus au contact), losses (pièces
--- perdues depuis le relevé précédent), hbar, window (min : rassemblement maximal + marche + marge), source (vrai : un nid
--- nous vise encore) } }. keys = clés triées. Rend la liste des événements { key, kind = "vague"|"fausse"|"rate", pred, recv,
--- k0, k1 } (journal).
function Pv.calibrate(cal, keys, facts, tick)
  local evs = {}
  for _, key in ipairs(keys or {}) do
    local f = facts[key] or {}
    local c = cal[key]
    if not c then
      c = { k = Pv.K0, hit = 0, fa = 0, miss = 0 }
      cal[key] = c
    end
    local hit_now = (f.contact or 0) > 0 or (f.losses or 0) > 0
    local recv_now = (f.contact or 0) + (f.losses or 0) * Pv.LOSS_UNITS * (f.hbar or 0)
    if hit_now then
      c.atk = true
      if recv_now > (c.peak or 0) then c.peak = recv_now end
      -- Attaque sans épisode ouvert : la prévision du moment (0 : un raté) devient la référence de cette attaque.
      if not c.ep then c.ep = { pred = f.pred_raw or 0, t = tick } end
    elseif c.atk then
      -- Fin d'une attaque (fait) : reçu contre prévu.
      local recv = c.peak or 0
      local pred = c.ep and c.ep.pred or 0
      local k0 = c.k
      if pred > 0 then
        local r = math.floor(1000 * recv / pred)
        c.k = floor((7 * c.k + r) / 8)
        c.hit = c.hit + 1
        evs[#evs + 1] = { key = key, kind = "vague", pred = pred, recv = recv, k0 = k0 }
      else
        c.k = c.k + Pv.K_MISS
        c.miss = c.miss + 1
        c.floor = recv
        evs[#evs + 1] = { key = key, kind = "rate", pred = 0, recv = recv, k0 = k0 }
      end
      if c.k < Pv.K_MIN then c.k = Pv.K_MIN elseif c.k > Pv.K_MAX then c.k = Pv.K_MAX end
      evs[#evs].k1 = c.k
      if pred > 0 then c.floor = nil end
      c.atk, c.peak, c.ep = nil, nil, nil
    end
    if not c.atk then
      if c.ep and c.ep.pred > 0 and tick >= c.ep["until"] then
        -- Fausse alerte (fait) : la vague prévue n'est pas venue dans la fenêtre que le moteur permet.
        local k0 = c.k
        c.k = floor(7 * c.k / 8)
        if c.k < Pv.K_MIN then c.k = Pv.K_MIN end
        c.fa = c.fa + 1
        evs[#evs + 1] = { key = key, kind = "fausse", pred = c.ep.pred, recv = 0, k0 = k0, k1 = c.k }
        c.ep, c.floor = nil, nil
      elseif not c.ep and (f.pred_raw or 0) > 0 then
        c.ep = { pred = f.pred_raw, t = tick, ["until"] = tick + math.floor((f.window or 30) * 3600) }
      elseif c.ep and (f.pred_raw or 0) > c.ep.pred then
        c.ep.pred = f.pred_raw -- la vague prévue grossit pendant l'attente : on garde la plus grosse prévision
      end
      -- Plancher d'un raté : il tombe quand plus rien ne nous vise (aucun nid rattaché, rien de vu).
      if c.floor and not f.source then c.floor = nil end
    end
  end
  return evs
end

---------------------------------------------------------------------------------------------------
-- C12 : défense induite par notre propre pollution
---------------------------------------------------------------------------------------------------
--- PV de vague en plus par pollution/min émise en plus : part qui atteint des nids (reach ‰ mesurée, Pv.REACH_DEFAULT quand
--- des nids sont connus mais n'absorbent encore rien, 0 sans nid connu) ÷ coût moyen d'une unité × rassemblement maximal × PV
--- moyens.
function Pv.hp_per_emit(est, gather)
  if not est or not est.mix or (est.nests_used or 0) == 0 then return 0 end
  local reach = est.reach or 0
  if reach <= 0 then reach = Pv.REACH_DEFAULT end
  local gmax = (gather and gather.max) or 10
  return reach / 1000 / est.mix.pbar * gmax * est.mix.hbar
end

--- Prix de la défense induite, en MU par pollution/min : PV de vague en plus × marge ÷ valeur d'une tourelle × MU d'une tourelle
--- garnie. 0 si une des grandeurs manque.
function Pv.defense_price(hp_per_emit, turret_value, turret_mu, marge)
  if not (hp_per_emit and hp_per_emit > 0 and turret_value and turret_value > 0 and turret_mu and turret_mu > 0) then return 0 end
  return hp_per_emit * (marge or 1000) / 1000 / turret_value * turret_mu
end

return Pv
