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

  Mécanique du moteur reprise (Factorio 1.1 ; MESURÉE en moteur réel au lot PREVISION-CALIB du 30/10, bancs `prev-mesure`
  et `prev-cible`, fo-logs/2026-10-30_VAGUE12/PREVISION-CALIB ; le reste est marqué HYPOTHÈSE) :
    * un nid absorbe À LA DEMANDE : il prend la pollution dont il a besoin pour envoyer ses unités, une par
      `pollution_to_join_attack` absorbé, au plus une par délai de ponte (spawn_cooldown, interpolé selon l'évolution :
      360 ticks à 0, 150 à 1, lus au prototype). MESURÉ (banc prev-mesure, passage 3) : un nid seul, évolution 0, envoie
      10 unités/min et absorbe 40 à 45/min, que sa case lise 1 ou 40 ; 4 nids à 32 tuiles : 4 fois plus, un seul groupe. Le
      plafond du prototype (pollution_absorption_absolute 20, proportional 0,01) N'EST PAS « par minute » (réfuté : 45/min
      absorbés à c ≈ 1) ; il est pris par SECONDE (HYPOTHÈSE compatible avec la mesure) et n'est jamais atteint ;
    * C5 corrigé : la pollution LUE à la case du nid est un RESTE. Une case au-dessus du seuil de diffusion (min_to_diffuse,
      lu aux réglages de carte) en a plus qu'il n'en faut : le nid tourne à sa cadence. En dessous, la lecture ne dit rien de
      ce qui arrive (l'ancienne règle « case polluée : plafond de 20/min » créditait chaque nid touché par un reste de
      5 unités/min ; mesure 0.6.24 : prévision 3 à 60 fois trop grosse) : le nid ne reçoit que la diffusion des voisines
      AU-DESSUS du seuil (`diffusion_ratio` lu aux réglages, Pv.CYCLES fois par minute, HYPOTHÈSE de 64 ticks par cycle), au
      plus sa demande ;
    * C6 (§3.2, §3.3) : la pollution n'a pas de propriétaire et la vague va vers la SOURCE : chaque nid est rattaché à NOTRE
      site le plus attirant (émission ÷ distance², sites : QG, avant-postes, champs), et seule la PART de notre équipe compte
      (contre les QG rivaux connus : Pv.share) ;
    * C7 (§3.4, §3.5) : TAILLE d'une vague (débit × temps de rassemblement MOYEN, au plus la taille de groupe du moteur ; la
      doc 1.1.91 dit « a random time between the minimum and maximum times » : la moyenne (min + max) / 2, loi uniforme
      SUPPOSÉE ; l'ancien maximum doublait presque les vagues non plafonnées) distincte du DÉBIT sur l'horizon (munitions) ;
      ÉCHÉANCE PESSIMISTE = rassemblement minimal + marche la plus courte ;
      plafond de cadence d'un nid lu au prototype (spawn_cooldown) ; évolution PROJETÉE à l'horizon (time_factor, pollution) ;
    * C9 (§3.9) : valeurs de défense CALCULÉES depuis les prototypes (dégâts par seconde × temps sous le feu ; aucune table
      par âge) ; un seul facteur d'arène Pv.ARENA (efficacité réelle ÷ calculée, à mesurer) ;
    * C8 (§3.7) : calibration SYMÉTRIQUE (Pv.calibrate) : vague reçue mesurée par ce qui est VU au contact, par les unités que
      nous TUONS près du site (ajout PREVISION-CALIB : un relevé par minute ne voit presque jamais une vague que les tourelles
      tuent en quelques secondes) ET par nos PERTES ; fausse alerte et RATÉ comptés sur des faits. k est UN par équipe (l'écart
      du modèle est le même à tous ses sites ; un k par site n'apprenait pas : 1 à 3 vagues par site en une heure), appris en
      moyenne GÉOMÉTRIQUE (l'écart mesuré va de 1/60 à 3 : une moyenne linéaire bornée à [0,5 ; 2] ne le suivait pas), borné
      à [Pv.K_MIN, Pv.K_MAX] ; un raté ne touche plus k (la vague est allée AILLEURS : plancher du site).
    * C12 : défense induite par un agrandissement (Pv.hp_per_emit, Pv.defense_price).

  Unité commune : les PV ennemis (une vague = somme des PV de ses unités ; une défense = PV ennemis qu'elle neutralise pendant
  une vague). Entrées triées par l'appelant, aucun `pairs` décisionnel, aucune trigonométrie (racines carrées seulement),
  aucun hasard, aucun temps mesuré.
]]

local Pv = {}

Pv.H_COURT, Pv.H_MOYEN = 5, 15   -- horizons (min) : court (imminent, « préparer ») et moyen (armée visée)
Pv.PERIOD = 3600                 -- un relevé par minute et par équipe (runtime)
-- Nids (HYPOTHÈSES sur le moteur, données vanilla ; contrôlées contre data/base par tests/prevision_test.lua).
Pv.ABS = 20                      -- plafond d'absorption d'un nid, part fixe (vanilla), PAR SECONDE (HYPOTHÈSE ; « par minute » réfuté)
Pv.PROP = 10                     -- ‰ de la pollution de sa case, part proportionnelle (même unité)
Pv.CYCLES = 3600 / 64            -- cycles de diffusion de la pollution par minute (HYPOTHÈSE)
Pv.DIFF0 = 20                    -- ‰ : diffusion vers chaque voisine quand les réglages de carte ne la donnent pas
Pv.SAT0 = 15                     -- seuil de diffusion (min_to_diffuse, défaut du moteur) quand les réglages ne le donnent pas
Pv.NESTS_MAX = 32                -- nids connus examinés au plus (les plus proches de nos sites)
Pv.R_ATTR = 224                  -- tuiles : un nid plus loin de tous nos sites ne nous vise pas
-- Défense (C9 : un seul facteur d'arène, le reste vient des prototypes).
Pv.T_HOLD = 10                   -- s : une tourelle tient sous le contact (HYPOTHÈSE, couverte par Pv.ARENA)
Pv.T_SOLDIER = 20                -- s : un soldat se bat avant de tomber (HYPOTHÈSE, couverte par Pv.ARENA)
Pv.ARENA = 1000                  -- ‰ : efficacité réelle ÷ calculée (1000 tant qu'elle n'est pas mesurée en arène)
Pv.SPEED0 = 0.2                  -- tuiles/tick : vitesse ennemie quand aucune n'est connue
-- Calibration (C8) : k de l'équipe, rangé dans la calibration sous la clé réservée Pv.TEAM (jamais une clé de site).
Pv.K0, Pv.K_MIN, Pv.K_MAX = 1000, 50, 4000
Pv.TEAM = "*"
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

--- Cadence au plus d'un nid (unités/min) à l'évolution e (‰) : le délai de ponte va linéairement de 3600 / r0 ticks à
--- l'évolution 0 à 3600 / r1 à l'évolution 1 (spawn_cooldown du prototype ; mesuré : 10 unités/min à l'évolution 0).
--- Sans r1 : r0 ; sans r0 : illimitée.
function Pv.rate_at(r0, r1, e)
  if not r0 then return math.huge end
  if not r1 or r1 <= 0 then return r0 end
  local x = math.max(0, math.min(1000, e or 0)) / 1000
  local cd0, cd1 = 3600 / r0, 3600 / r1
  return 3600 / (cd0 + (cd1 - cd0) * x)
end

--- Unité moyenne des nids à l'évolution e (‰). kinds = { { units = { { hp, cost, speed, pts } }, rate_max, rate_max1 } } (un type
--- de nid par entrée, triés par l'appelant ; cost = pollution_to_join_attack ; rate_max, rate_max1 = unités/min au plus d'un nid
--- de ce type à l'évolution 0 et 1, lus à spawn_cooldown). Les types de nids pèsent pareil (on ne sait pas lequel on voit).
--- Rend { pbar, hbar, speed, cap } ou nil (cap : unités/min d'un nid à l'évolution e).
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
      cap = cap + Pv.rate_at(k.rate_max, k.rate_max1, e)
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
--- Pollution/min absorbée par un nid : c = pollution de sa case, nb = somme de ses cases voisines AU-DESSUS du seuil de
--- diffusion (les autres ne diffusent pas, doc 1.1.91 de min_to_diffuse : le runtime ne somme qu'elles), diff = diffusion (‰),
--- need = sa demande (pollution/min qu'il sait changer en unités : cadence × coût moyen), sat = seuil de diffusion.
--- Case au-dessus du seuil : la demande (il en reste plus qu'il n'en prend, MESURÉ) ; sinon ce qui arrive des voisines, au
--- plus la demande. Toujours sous le plafond du prototype (pris par seconde).
function Pv.absorbed(c, nb, diff, need, sat)
  c = (c and c > 0) and c or 0
  nb = (nb and nb > 0) and nb or 0
  local cap = (Pv.ABS + Pv.PROP * c / 1000) * 60
  if need and need < cap then cap = need end
  if c >= (sat or Pv.SAT0) then return cap end
  local inflow = nb * (diff or Pv.DIFF0) / 1000 * Pv.CYCLES
  if inflow < cap then return inflow end
  return cap
end

--- Clé de la case de pollution (32 × 32 tuiles, comme le moteur) d'une position.
function Pv.chunk_key(x, y)
  return floor(x / 32) .. "," .. floor(y / 32)
end

--- Unités ennemies TUÉES par l'équipe, rattachées aux sites : kills = { { x, y, hp } } (ordre des événements), sites = { { key,
--- x, y } } (triés), nests = { { x, y } } (nids connus, ce relevé et le précédent), loss_r et garrison_r (tuiles). Une unité tuée
--- à moins de garrison_r d'un nid connu est sa GARNISON (raid, nettoyage d'un champ) : elle n'est pas une vague reçue (même
--- règle que les unités VUES). Les autres comptent au site le plus proche à moins de loss_r. Rend { [clé] = PV }.
function Pv.kills_by_site(kills, sites, nests, loss_r, garrison_r)
  local out = {}
  local l2, g2 = loss_r * loss_r, garrison_r * garrison_r
  for _, h in ipairs(kills or {}) do
    local gar = false
    for _, n in ipairs(nests or {}) do
      if d2(h.x, h.y, n.x, n.y) <= g2 then gar = true break end
    end
    if not gar then
      local best, bd = nil, nil
      for _, s in ipairs(sites or {}) do
        local dd = d2(h.x, h.y, s.x, s.y)
        if dd <= l2 and (not bd or dd < bd) then best, bd = s, dd end
      end
      if best then out[best.key] = (out[best.key] or 0) + (h.hp or 0) end
    end
  end
  return out
end

--- Temps de rassemblement moyen (min) : le moteur tire un temps entre le minimum et le maximum (doc 1.1.91 ; loi uniforme
--- SUPPOSÉE).
function Pv.gather_mean(gather)
  local g = gather or {}
  return ((g.min or 1) + (g.max or 10)) / 2
end

--- Unités d'une vague : débit (unités/min) × rassemblement moyen, au plus la taille de groupe du moteur.
function Pv.wave_units(rate, gather)
  local units = (rate or 0) * Pv.gather_mean(gather)
  local size = (gather and gather.size) or 200
  if units > size then units = size end
  return units
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
---   diff (‰), sat (seuil de diffusion), sites = { { key, x, y, emit (pollution/min), dps, dpsr, turrets, seen (PV vus à portée d'œil), contact,
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
  local gmin = ga.min or 1
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
  -- C5 (relecture PREVISION-CALIB) : la diffusion arrive à la CASE de 32 × 32 (le moteur tient la pollution par case), pas à
  -- chaque nid ; les nids connus d'une même case se partagent ce flux (même demande : parts égales). Sans ce partage, une case
  -- de 5 nids sous le seuil comptait 5 fois le flux de ses voisines.
  local per_chunk = {}
  for _, n in ipairs(inp.nests or {}) do
    local ck = Pv.chunk_key(n.x, n.y)
    per_chunk[ck] = (per_chunk[ck] or 0) + 1
  end
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
      local abs = Pv.absorbed(n.c, (n.nb or 0) / (per_chunk[Pv.chunk_key(n.x, n.y)] or 1), inp.diff, mix0 and mix0.cap * mix0.pbar, inp.sat)
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
      local units = Pv.wave_units(o.rate, ga)
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
--- k (‰) de l'équipe rangé dans la calibration (Pv.K0 sans fait).
function Pv.k_of(cal)
  local t = cal and cal[Pv.TEAM]
  return (t and t.k) or Pv.K0
end

local function bound_k(k)
  if k < Pv.K_MIN then return Pv.K_MIN end
  if k > Pv.K_MAX then return Pv.K_MAX end
  return k
end

--- Nouvelle calibration. cal = { [Pv.TEAM] = { k, hit, fa }, [clé de site] = { ep = { pred, t, until } | nil, atk, peak, kill,
--- lost, miss, floor } } (état persistant, créé ici ; une calibration 0.6.24 sans entrée d'équipe repart de Pv.K0, ses anciens
--- k de site sont ignorés). facts = { [clé] = { pred_raw (PV prévus avant k), contact (PV vus au contact), killed (PV des unités
--- tuées près du site depuis le relevé précédent), losses (pièces perdues depuis le relevé précédent), hbar, window (min :
--- rassemblement maximal + marche + marge), source (vrai : un nid nous vise encore) } }. keys = clés de sites triées.
--- Vague reçue d'une attaque = max(pic vu au contact, PV tués pendant l'attaque) + pertes × Pv.LOSS_UNITS × hbar.
--- k de l'équipe : vague → moyenne géométrique de k et du rapport reçu ÷ prévu (racine carrée : déterministe), SAUF une reçue
--- censurée (ni vue ni tuée : pertes seules, borne basse) qui ne peut que relever k ; fausse alerte → × 7/8 ; raté → plancher du
--- site seulement. Rend la liste des événements { key, kind = "vague"|"fausse"|"rate", pred, recv,
--- seen, killed, lost, k0, k1 } (journal).
function Pv.calibrate(cal, keys, facts, tick)
  local evs = {}
  local team = cal[Pv.TEAM]
  if not team then
    team = { k = Pv.K0, hit = 0, fa = 0 }
    cal[Pv.TEAM] = team
  end
  for _, key in ipairs(keys or {}) do
    local f = facts[key] or {}
    local c = cal[key]
    if not c then
      c = { miss = 0 }
      cal[key] = c
    end
    local lost_now = (f.losses or 0) * Pv.LOSS_UNITS * (f.hbar or 0)
    local hit_now = (f.contact or 0) > 0 or (f.losses or 0) > 0 or (f.killed or 0) > 0
    if hit_now then
      c.atk = true
      if (f.contact or 0) > (c.peak or 0) then c.peak = f.contact end
      c.kill = (c.kill or 0) + (f.killed or 0)
      c.lost = (c.lost or 0) + lost_now
      -- Attaque sans épisode ouvert : la prévision du moment (0 : un raté) devient la référence de cette attaque.
      if not c.ep then c.ep = { pred = f.pred_raw or 0, t = tick } end
    elseif c.atk then
      -- Fin d'une attaque (fait) : reçu contre prévu.
      local seen, killed, lost = c.peak or 0, c.kill or 0, c.lost or 0
      local recv = math.max(seen, killed) + lost
      local pred = c.ep and c.ep.pred or 0
      local k0 = team.k
      if pred > 0 then
        local r = math.max(1, floor(1000 * recv / pred))
        -- Reçue CENSURÉE (relecture PREVISION-CALIB) : rien de vu, rien de tué, seulement nos pertes. La vague a survécu à nos
        -- défenses (ou un tiers l'a tuée) : ses pertes ne bornent sa taille que PAR EN DESSOUS. Elle peut relever k, jamais le
        -- baisser (rejeu 0.6.24 : une « reçue » d'une seule perte, 41 PV, divisait k par 8 et la vague suivante était
        -- sous-estimée 8 fois).
        local censored = seen <= 0 and killed <= 0
        if not (censored and r <= team.k) then team.k = bound_k(floor(math.sqrt(team.k * r))) end
        team.hit = (team.hit or 0) + 1
        evs[#evs + 1] = { key = key, kind = "vague", pred = pred, recv = recv, seen = seen, killed = killed, lost = lost, k0 = k0, k1 = team.k,
          censored = censored }
        c.floor = nil
      else
        c.miss = (c.miss or 0) + 1
        c.floor = recv
        evs[#evs + 1] = { key = key, kind = "rate", pred = 0, recv = recv, seen = seen, killed = killed, lost = lost, k0 = k0, k1 = team.k }
      end
      c.atk, c.peak, c.kill, c.lost, c.ep = nil, nil, nil, nil, nil
    end
    if not c.atk then
      if c.ep and c.ep.pred > 0 and tick >= c.ep["until"] then
        -- Fausse alerte (fait) : la vague prévue n'est pas venue dans la fenêtre que le moteur permet.
        local k0 = team.k
        team.k = bound_k(floor(7 * team.k / 8))
        team.fa = (team.fa or 0) + 1
        evs[#evs + 1] = { key = key, kind = "fausse", pred = c.ep.pred, recv = 0, k0 = k0, k1 = team.k }
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
--- moyens (rassemblement moyen, comme la taille d'une vague).
function Pv.hp_per_emit(est, gather)
  if not est or not est.mix or (est.nests_used or 0) == 0 then return 0 end
  local reach = est.reach or 0
  if reach <= 0 then reach = Pv.REACH_DEFAULT end
  return reach / 1000 / est.mix.pbar * Pv.gather_mean(gather) * est.mix.hbar
end

--- Prix de la défense induite, en MU par pollution/min : PV de vague en plus × marge ÷ valeur d'une tourelle × MU d'une tourelle
--- garnie. 0 si une des grandeurs manque.
function Pv.defense_price(hp_per_emit, turret_value, turret_mu, marge)
  if not (hp_per_emit and hp_per_emit > 0 and turret_value and turret_value > 0 and turret_mu and turret_mu > 0) then return 0 end
  return hp_per_emit * (marge or 1000) / 1000 / turret_value * turret_mu
end

return Pv
