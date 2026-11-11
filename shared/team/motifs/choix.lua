--[[
  Lot MOTIFS : SÉLECTION et ADAPTATION d'un motif (shared/team/motifs/catalogue.lua) à un terrain et à une demande. Lua PUR :
  aucune API du jeu, aucune trigonométrie, aucun hasard, listes triées ; coût borné (mesuré par tests/motifs_test.lua).

  « Face à un gisement ou une zone de construction, l'algorithme ne doit pas appliquer un pattern aveugle. Il doit interroger sa base de
  données, sélectionner le motif optimal qui correspond à l'espace disponible et aux contraintes du terrain, et l'adapter
  dynamiquement. » (DC, 8/11)

  ENTRÉE  Choix.choisir(req)
    req.zone       = { x, y, l, h }        rectangle de travail, tuiles entières (coin nord-ouest) ;
    req.obstacles  = { { x, y, l, h } }    rectangles non destructibles (eau, falaise, bâtiment à garder…) ;
    req.libre      = function(x, y) -> bool  carte de tuiles libres (faux = occupée), facultative, lue sur la zone ;
    req.familles   = { "fonte" } ou req.famille ; req.usage = "acier" (facultatif : filtre sur `usages`) ;
    req.demande    = producteur : { jeton = "P", debit = items/s }
                     bus        : { voies = k, longueur = tuiles }
                     équilibreur: { entrees = k, sorties = m }
    req.entrees    = { { cote = "N"|"E"|"S"|"O", pos = coordonnée monde le long du côté (facultative), jetons = { "A", … } } }
                     les entrées disponibles : côté de la zone par où la matière arrive, et ce qu'elle porte ;
    req.max_n      = nombre de tuiles au plus (facultatif) ;
    req.ctx        = ce que le client a LU aux prototypes (aucun nom d'objet ici) :
        vitesse    = { [role] = vitesse de fabrication (machine) },
        taille     = { [role] = côté de la machine disponible, ou liste de côtés },
        recettes   = { [groupe] = { temps, entrees = { jeton = quantité }, sorties = { jeton = quantité } } }   (groupe « principal » par défaut),
        combustible= { [role] = consommation en items/s par machine },
        bras       = { [role] = items/s d'un bras (bras, bras_long) }  (déjà avec le bonus de pile),
        tapis_voie = items/s d'une voie de tapis (7,5 pour un tapis jaune), marge (0,9 par défaut),
        poteau     = { supply, fil }  (le meilleur poteau disponible) ; energie = false : aucune électricité requise,
        dispo      = { [role] = "oui" | "recherche" }  (absent = indisponible ; table absente = tout disponible).
  SORTIE  { motif = id | nil, n, orient = { rot, miroir }, x, y, l, h (emprise orientée, coin nord-ouest), debit = { tuile, total },
            couvre, limite, retenus = { … classés … }, ecartes = { { id, cause } } triés par id }.
          Instancier le résultat : catalogue.instancier(res.motif, res.n, res.orient) ; poser à (res.x, res.y).
]]

local function need(dotted, slashed)
  local ok, res = pcall(require, dotted)
  if ok and type(res) == "table" then return res end
  return require("__factorio-overhaul__/" .. slashed)
end
local D = need("shared.team.motifs.dsl", "shared/team/motifs/dsl")
local Cat = need("shared.team.motifs.catalogue", "shared/team/motifs/catalogue")

local X = {}

X.BELT_PICKUP = 0.85    -- un bras qui prend sur un tapis (shared/team/modules.lua)
X.MARGE = 0.9           -- toute liaison garde 10 % de marge
X.LANE_RATE = 7.5       -- tapis jaune : 7,5 objets/s par voie
X.MAX_N = 64            -- nombre de tuiles au plus (même plafond que shared/team/modules.lua)

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local EPS = 1e-9

local function floor_eps(x) return floor(x + EPS) end

---------------------------------------------------------------------------------------------------
-- 0. Ratios usuels : CALCULÉS d'après les recettes et les vitesses lues en jeu, jamais écrits
---------------------------------------------------------------------------------------------------
--- Machines amont pour UNE machine aval (insertion directe ou tapis) afin que le jeton intermédiaire s'équilibre.
---   amont = { temps, vitesse, sorties = { jeton = quantité par fabrication } }, aval = { temps, vitesse, entrees = { jeton = quantité } }
--- Exemples (données de la recette, vitesses égales) : engrenage → pack rouge 0,1 (1 pour 10), câble → circuit 1,5 (3 pour 2),
--- plaque → acier 1 (1 pour 1).
function X.rapport(amont, aval, jeton)
  local pa = amont.vitesse / amont.temps * ((amont.sorties or {})[jeton] or 0)
  local cb = aval.vitesse / aval.temps * ((aval.entrees or {})[jeton] or 0)
  if pa <= 0 or cb <= 0 then return nil end
  return cb / pa
end

--- Nombre de bras (entier) pour porter `flux` items/s avec des bras de `cadence` items/s ; depuis_tapis : prise sur un tapis (0,85).
function X.bras_necessaires(flux, cadence, depuis_tapis, marge)
  local c = cadence * (depuis_tapis and X.BELT_PICKUP or 1) * (marge or X.MARGE)
  if c <= 0 then return nil end
  return max(1, ceil(flux / c - EPS))
end

--- Machines qu'une voie de tapis nourrit : floor(voie / consommation d'une machine).
function X.machines_par_voie(conso_par_machine, voie)
  if conso_par_machine <= 0 then return nil end
  return floor_eps((voie or X.LANE_RATE) / conso_par_machine)
end

--- Rapport amont / aval réalisé par une chaîne d'un motif : machines du groupe amont ÷ machines du groupe aval, par tuile.
function X.rapport_motif(m, indice)
  local c = (m.chaines or {})[indice or 1]
  if not c then return nil end
  return m.derive.groupes[c.amont].n / m.derive.groupes[c.aval].n
end

---------------------------------------------------------------------------------------------------
-- 1. Débit d'une tuile
---------------------------------------------------------------------------------------------------
--- Débit nominal d'UNE tuile du motif m selon ctx. Renvoie un tableau
---   { sortie = { jeton = items/s }, util = { groupe = 0..1 }, conso = { [k] = { jeton = items/s } }, rejet = { [k] = { jeton } },
---     limites = { "texte", ... }, n_tapis = nombre de tuiles que les tapis portent au plus (math.huge si aucune limite) }
--- ou (nil, cause) quand une donnée manque.
-- Valeur d'un tableau « par rôle » qui peut aussi être « par rôle puis par côté de machine » : { machine_fonte = { [2] = 1, [3] = 2 } }.
local function par_role(tab, role, taille)
  local v = tab and tab[role]
  if type(v) == "table" then return v[taille] end
  return v
end

function X.debit(m, ctx)
  local der = m.derive
  local marge = ctx.marge or X.MARGE
  local voie = ctx.tapis_voie or X.LANE_RATE
  local rec, cad = {}, {}
  for _, g in ipairs(der.noms) do
    local e = der.groupes[g]
    local r = (ctx.recettes or {})[g]   -- un groupe a SA recette (« principal » pour les motifs à un seul groupe)
    local v = par_role(ctx.vitesse, e.role, e.w)
    if not r or not r.temps or r.temps <= 0 then return nil, "recette_manquante:" .. g end
    if not v or v <= 0 then return nil, "vitesse_manquante:" .. e.role end
    rec[g] = r
    cad[g] = v / r.temps
  end
  local groupes, ids = der.noms, der.ids

  -- terminaux : où sortent les jetons (tapis de sortie numérotés ; 0 = raccord de fluide)
  local term = {}
  for _, s in ipairs(m.sorties or {}) do
    local toks = {}
    for tok in pairs(s.jetons) do toks[#toks + 1] = tok end
    table.sort(toks)
    for _, tok in ipairs(toks) do term[tok] = term[tok] or {}; term[tok][#term[tok] + 1] = s.k end
  end
  for _, fl in ipairs(m.fluides or {}) do
    if fl.io == "out" then term[fl.jeton] = term[fl.jeton] or {}; term[fl.jeton][#term[fl.jeton] + 1] = 0 end
  end
  for _, tok in ipairs(m.produits or {}) do term[tok] = term[tok] or {}; term[tok][#term[tok] + 1] = 0 end   -- produit sans tapis (courant, recherche…)
  -- chaque groupe sert tous les ingrédients de SA recette et sort tous ses produits (jamais une tuile à 1 entrée pour une recette
  -- à 2 matières) ; le combustible aussi
  local amont_de = {}
  for _, c in ipairs(m.chaines or {}) do amont_de[c.amont] = c.jeton end
  for _, g in ipairs(groupes) do
    local serv, sort = {}, {}
    for _, id in ipairs(ids) do
      local l = der.liens[id]
      if l.io == "in" and l.groupe == g then for _, t in ipairs(l.jetons or {}) do serv[t] = true end
      elseif l.io == "mid" and l.vers == g then serv[l.jeton] = true
      elseif l.io == "out" and l.groupe == g then for _, t in ipairs(l.jetons or {}) do sort[t] = true end end
    end
    for _, c in ipairs(m.chaines or {}) do
      if c.contact and c.aval == g then serv[c.jeton] = true end   -- contact direct (vapeur de la chaudière à la machine)
    end
    for _, fl in ipairs(m.fluides or {}) do
      if fl.io == "in" then serv[fl.jeton] = true end              -- fluide amené par tuyau
    end
    local toks = {}
    for tok in pairs(rec[g].entrees or {}) do toks[#toks + 1] = tok end
    table.sort(toks)
    for _, tok in ipairs(toks) do
      if not serv[tok] then return nil, "jeton_non_servi:" .. g .. ":" .. tok end
    end
    local comb = par_role(ctx.combustible, der.groupes[g].role, der.groupes[g].w)
    if comb and comb > 0 and not serv.combustible then return nil, "combustible_non_servi:" .. g end
    toks = {}
    for tok in pairs(rec[g].sorties or {}) do toks[#toks + 1] = tok end
    table.sort(toks)
    for _, tok in ipairs(toks) do
      if not sort[tok] and not term[tok] and amont_de[g] ~= tok then return nil, "produit_non_sorti:" .. g .. ":" .. tok end
    end
  end

  -- demande et capacité de chaque lien (par tuile, à pleine cadence)
  local flux, f, caps = {}, {}, {}
  local limites = {}
  for _, id in ipairs(ids) do
    local l = der.liens[id]
    local g = l.groupe
    local dem = 0
    if l.io == "mid" then
      local vers = l.vers
      local r = rec[vers]
      dem = (l.mg[vers] or 0) * cad[vers] * ((r.entrees or {})[l.jeton] or 0)
    else
      local r = rec[g]
      for _, tok in ipairs(l.jetons or {}) do
        if tok == "combustible" then
          dem = dem + (l.mg[g] or 0) * (par_role(ctx.combustible, der.groupes[g].role, der.groupes[g].w) or 0)
        elseif l.io == "in" then
          dem = dem + (l.mg[g] or 0) * cad[g] * ((r.entrees or {})[tok] or 0)
        else
          dem = dem + (l.mg[g] or 0) * cad[g] * ((r.sorties or {})[tok] or 0)
        end
      end
    end
    local cap = 0
    local roles_bras = {}
    for role in pairs(l.bras) do roles_bras[#roles_bras + 1] = role end
    table.sort(roles_bras)   -- ordre fixe : la somme en virgule flottante ne dépend jamais de l'ordre de pairs
    for _, role in ipairs(roles_bras) do
      local n = l.bras[role]
      local v = (ctx.bras or {})[role]
      if not v then return nil, "bras_inconnu:" .. role end
      cap = cap + n * v * (l.prise_tapis and X.BELT_PICKUP or 1) * marge
    end
    flux[id] = dem
    caps[id] = cap
    if dem > EPS then
      f[id] = min(1, cap / dem)
      if f[id] < 1 - EPS then limites[#limites + 1] = string.format("bras:%s (%.2f/%.2f)", id, cap, dem) end
    else
      f[id] = 1
    end
  end

  -- utilisation de chaque groupe : liens propres, puis chaînes à insertion directe
  local util = {}
  for _, g in ipairs(groupes) do util[g] = 1 end
  for _, id in ipairs(ids) do
    local l = der.liens[id]
    if l.io == "mid" then
      -- une liaison directe borne le groupe qui consomme
      if f[id] < util[l.vers] then util[l.vers] = f[id] end
    elseif f[id] < util[l.groupe] then
      util[l.groupe] = f[id]
    end
  end
  local ch = m.chaines or {}
  local R = {}   -- production et consommation de l'intermédiaire de chaque chaîne (par tuile)
  local n_fixe = math.huge   -- tuiles qu'un producteur de TÊTE (fixe, une fois pour toute la rangée) peut servir
  for i, c in ipairs(ch) do
    local ra, rb = rec[c.amont], rec[c.aval]
    R[i] = {
      a = der.groupes[c.amont].n * cad[c.amont] * ((ra.sorties or {})[c.jeton] or 0),
      b = der.groupes[c.aval].n * cad[c.aval] * ((rb.entrees or {})[c.jeton] or 0),
      fixe = der.groupes[c.amont].fixe,
    }
  end
  -- 1) l'aval est borné par ce que ses amonts fournissent (un amont fixe borne le NOMBRE de tuiles, pas leur utilisation)
  for i, c in ipairs(ch) do
    local r = R[i]
    if r.b > EPS then
      if r.fixe then
        local nf = floor_eps(r.a * util[c.amont] / r.b)
        if nf < n_fixe then n_fixe = nf end
        limites[#limites + 1] = string.format("producteur de tête:%s sert %d tuiles", c.amont, nf)
      else
        local fourni = r.a * util[c.amont]
        local u = min(util[c.aval], fourni / r.b)
        if u < util[c.aval] - EPS then limites[#limites + 1] = string.format("rapport:%s->%s", c.amont, c.aval) end
        util[c.aval] = u
      end
    end
  end
  -- 2) chaque amont ne produit que ce que l'aval consomme
  for i, c in ipairs(ch) do
    local r = R[i]
    if r.a > EPS and not r.fixe then
      util[c.amont] = min(util[c.amont], util[c.aval] * r.b / r.a)
    end
  end
  -- chaîne en série (laboratoires : le premier bras porte les paquets de tous les suivants)
  if m.serie_directe then   -- { lien = décalage } : le bras d'entrée porte n machines (décalage 0), chaque liaison n − 1 (décalage 1)
    local liens_s = {}
    for id in pairs(m.serie_directe) do liens_s[#liens_s + 1] = id end
    table.sort(liens_s)
    for _, id in ipairs(liens_s) do
      local l = der.liens[id]
      local un = flux[id] / max(1, l.mg[l.groupe] or 1)
      if un > EPS then
        local nc = floor_eps(caps[id] / un) + m.serie_directe[id]
        if nc < n_fixe then n_fixe = nc end
        limites[#limites + 1] = string.format("chaîne en série (%s) : %d machines", id, nc)
      end
    end
  end

  -- sorties, consommation des tapis d'entrée, rejet sur les tapis de sortie
  local sortie, conso, rejet = {}, {}, {}
  local avec_lien_sortie = {}
  for _, id in ipairs(ids) do
    local l = der.liens[id]
    local g = l.groupe
    if der.groupes[g] and der.groupes[g].fixe then
      -- groupe de tête : sa consommation et sa production ne croissent pas avec le nombre de tuiles
    elseif l.io == "out" then
      avec_lien_sortie[g] = true
      local r = rec[g]
      for _, tok in ipairs(l.jetons or {}) do
        local q = (l.mg[g] or 0) * cad[g] * util[g] * ((r.sorties or {})[tok] or 0)
        sortie[tok] = (sortie[tok] or 0) + q
        for _, k in ipairs(l.sorties) do
          rejet[k] = rejet[k] or {}
          rejet[k][tok] = (rejet[k][tok] or 0) + q / #l.sorties
        end
      end
    elseif l.io == "in" then
      local r = rec[g]
      for _, tok in ipairs(l.jetons or {}) do
        local q
        if tok == "combustible" then q = (l.mg[g] or 0) * (par_role(ctx.combustible, der.groupes[g].role, der.groupes[g].w) or 0) * util[g]
        else q = (l.mg[g] or 0) * cad[g] * util[g] * ((r.entrees or {})[tok] or 0) end
        for _, k in ipairs(l.entrees) do
          conso[k] = conso[k] or {}
          conso[k][tok] = (conso[k][tok] or 0) + q / #l.entrees
        end
      end
    end
  end
  -- groupes sans lien de sortie (champ de foreuses, chevalets : le produit tombe directement sur le tapis ou dans la conduite)
  for _, g in ipairs(groupes) do
    if not avec_lien_sortie[g] and not der.groupes[g].fixe then
      local r = rec[g]
      local toks = {}
      for tok in pairs(r.sorties or {}) do toks[#toks + 1] = tok end
      table.sort(toks)
      for _, tok in ipairs(toks) do
        local ks = term[tok]
        if ks then
          local q = der.groupes[g].n * cad[g] * util[g] * r.sorties[tok]
          sortie[tok] = (sortie[tok] or 0) + q
          for _, k in ipairs(ks) do
            if k > 0 then
              rejet[k] = rejet[k] or {}
              rejet[k][tok] = (rejet[k][tok] or 0) + q / #ks
            end
          end
        end
      end
    end
  end

  -- nombre de tuiles que les tapis portent
  local n_tapis = math.huge
  local function borne(liste, tab, nom)
    for _, e in ipairs(liste or {}) do
      local t = tab[e.k]
      if t then
        local toks = {}
        for tok in pairs(t) do toks[#toks + 1] = tok end
        table.sort(toks)
        for _, tok in ipairs(toks) do
          local q = t[tok]
          local lanes = e.jetons and e.jetons[tok]
          if lanes and q > EPS then
            local n = floor_eps(#lanes * voie / q)
            if n < n_tapis then n_tapis = n end
            if #limites < 12 then limites[#limites + 1] = string.format("%s %d %s : %d tuiles", nom, e.k, tok, n) end
          end
        end
      end
    end
  end
  borne(m.entrees, conso, "tapis_entree")
  borne(m.sorties, rejet, "tapis_sortie")
  borne(m.sorties_internes, rejet, "tapis_sortie")   -- voies fusionnées en queue : chaque rangée garde SA voie
  if n_fixe < n_tapis then n_tapis = n_fixe end
  return { sortie = sortie, util = util, conso = conso, rejet = rejet, limites = limites, n_tapis = n_tapis }
end

---------------------------------------------------------------------------------------------------
-- 2. Placement dans la zone
---------------------------------------------------------------------------------------------------
-- Obstacles : rectangles { x0, y0, x1, y1 } (x1, y1 exclus) rognés à la zone.
local function obstacles_de(req)
  local Z = req.zone
  local obs = {}
  local zx1, zy1 = Z.x + Z.l, Z.y + Z.h
  for _, b in ipairs(req.obstacles or {}) do
    local x0, y0 = max(b.x, Z.x), max(b.y, Z.y)
    local x1, y1 = min(b.x + b.l, zx1), min(b.y + b.h, zy1)
    if x1 > x0 and y1 > y0 then obs[#obs + 1] = { x0, y0, x1, y1 } end
  end
  local libre = req.libre
  if libre then
    local ouverts = {}
    for y = Z.y, zy1 - 1 do
      local suivants = {}
      local x = Z.x
      while x < zx1 do
        if libre(x, y) then
          x = x + 1
        else
          local xe = x + 1
          while xe < zx1 and not libre(xe, y) do xe = xe + 1 end
          local key = x * 65536 + xe
          local r = ouverts[key]
          if r and r[4] == y then
            r[4] = y + 1
            suivants[key] = r
          else
            r = { x, y, xe, y + 1 }
            obs[#obs + 1] = r
            suivants[key] = r
          end
          x = xe
        end
      end
      ouverts = suivants
    end
  end
  return obs
end

local function ajoute(liste, v)
  for i = 1, #liste do if liste[i] == v then return end end
  liste[#liste + 1] = v
end

--- Plus grand nombre de tuiles (≤ cap) qui tient avec le coin nord-ouest en (x, y) ; axe = "x" (rot 0, 4) ou "y" (rot 2, 6).
local function n_max(obs, Z, axe, x, y, perp, extra, periode, cap)
  local zx1, zy1 = Z.x + Z.l, Z.y + Z.h
  local limite
  if axe == "x" then
    if y < Z.y or y + perp > zy1 or x < Z.x then return 0 end
    limite = zx1
    for i = 1, #obs do
      local b = obs[i]
      if b[2] < y + perp and b[4] > y and b[3] > x then
        if b[1] < limite then limite = b[1] end   -- ancre dans l'obstacle : limite ≤ x, donc n ≤ 0
      end
    end
    local n = floor_eps((limite - x - extra) / periode)
    return n > cap and cap or (n < 0 and 0 or n)
  end
  if x < Z.x or x + perp > zx1 or y < Z.y then return 0 end
  limite = zy1
  for i = 1, #obs do
    local b = obs[i]
    if b[1] < x + perp and b[3] > x and b[4] > y then
      if b[2] < limite then limite = b[2] end
    end
  end
  local n = floor_eps((limite - y - extra) / periode)
  return n > cap and cap or (n < 0 and 0 or n)
end

-- Entrée de motif dans l'orientation T : côté (direction sortante), coordonnée monde le long du côté, relativement à l'ancre.
local function entree_oriente(e, L, H, T)
  local cx, cy, c = D.cellule_port(e, L, H)
  local x, y = D.rect_t(cx, cy, 1, 1, L, H, T)
  return D.dir_cote(c, T), x, y
end

local function sides_de(req)
  local s = {}
  for i, e in ipairs(req.entrees or {}) do
    if D.COTES[e.cote] == nil then error("Choix.choisir : entrée " .. i .. " sans côté valide (N, E, S ou O) : " .. tostring(e.cote), 0) end
    s[#s + 1] = { cote = D.COTES[e.cote], pos = e.pos, jetons = e.jetons or {} }
  end
  return s
end

--- Meilleur placement de m (n ≤ cap). Renvoie { n, x, y, T, l, h, faux, ecart } ou nil.
local function placer(m, cap, Z, obs, supplies)
  local tete = m.tete and m.tete.len or 0
  local queue = m.queue and m.queue.len or 0
  local extra = tete + queue
  local per, H = m.periode, m.h
  if not m.repetable then cap = 1 end
  local best
  local classes = { { axe = "x", rots = { 0, 4 } }, { axe = "y", rots = { 2, 6 } } }
  local zx1, zy1 = Z.x + Z.l, Z.y + Z.h
  local lmin = extra + per
  for _, cl in ipairs(classes) do
    local axe = cl.axe
    local w1 = (axe == "x") and lmin or H
    local h1 = (axe == "x") and H or lmin
    if w1 <= Z.l and h1 <= Z.h then   -- une tuile doit au moins tenir dans la zone
      local Ts = { { rot = cl.rots[1], miroir = false }, { rot = cl.rots[2], miroir = false }, { rot = cl.rots[1], miroir = true }, { rot = cl.rots[2], miroir = true } }
      -- ancres candidates (dans la zone) : coin, bord opposé, arêtes des obstacles, alignement sur les entrées
      local xs, ys = {}, {}
      local xmax, ymax = zx1 - w1, zy1 - h1
      local function ax(v) if v >= Z.x and v <= xmax then ajoute(xs, v) end end
      local function ay(v) if v >= Z.y and v <= ymax then ajoute(ys, v) end end
      ax(Z.x); ay(Z.y); ax(xmax); ay(ymax)
      for i = 1, #obs do
        local b = obs[i]
        ax(b[3]); ay(b[4]); ax(b[1] - w1); ay(b[2] - h1)
      end
      for _, s in ipairs(supplies) do
        if s.pos then
          for _, T in ipairs(Ts) do
            for _, e in ipairs(m.entrees or {}) do
              local cote, ex, ey = entree_oriente(e, lmin, H, T)
              if cote == s.cote then
                if s.cote == 6 or s.cote == 2 then ay(s.pos - ey) else ax(s.pos - ex) end
              end
            end
          end
        end
      end
      table.sort(xs); table.sort(ys)
      -- plus grand n (les valeurs sont gardées pour la suite)
      local bn = 0
      local nm = {}
      local premier   -- sans entrée donnée : la première ancre (y puis x) qui atteint la demande suffit, rien ne la départage
      for iy = 1, #ys do
        local y = ys[iy]
        local ligne = {}
        nm[iy] = ligne
        for ix = 1, #xs do
          local n = n_max(obs, Z, axe, xs[ix], y, H, extra, per, cap)
          ligne[ix] = n
          if n > bn then bn = n end
          if n >= cap and #supplies == 0 and not premier then premier = { xs[ix], y } end
        end
        if premier then break end
      end
      if bn >= 1 then
        local L = extra + bn * per
        local w, h = (axe == "x") and L or H, (axe == "x") and H or L
        local cands = {}
        if premier then cands[1] = premier end
        for iy = 1, #ys do
          if premier then break end
          for ix = 1, #xs do
            if nm[iy][ix] >= bn and (#cands == 0 or #supplies > 0) then cands[#cands + 1] = { xs[ix], ys[iy] } end
          end
        end
        if #supplies > 0 then
          -- collée aux bords de la zone, côté de l'arrivée de la matière
          local xf, yf = zx1 - w, zy1 - h
          local vus = {}
          for i = 1, #cands do vus[cands[i][1] * 65536 + cands[i][2]] = true end
          local function dedans(a) return vus[a[1] * 65536 + a[2]] == true end
          local extras = { { xf, yf } }
          for iy = 1, #ys do extras[#extras + 1] = { xf, ys[iy] } end
          for ix = 1, #xs do extras[#extras + 1] = { xs[ix], yf } end
          for _, a in ipairs(extras) do
            if not dedans(a) and n_max(obs, Z, axe, a[1], a[2], H, extra, per, bn) >= bn then cands[#cands + 1] = a; vus[a[1] * 65536 + a[2]] = true end
          end
        end
        local meilleur
        -- raccords hors côté par orientation (ne dépend pas de l'ancre) : seules les orientations qui en ont le moins sont essayées
        local fauxT, minfaux = {}, math.huge
        for ti, T in ipairs(Ts) do
          local nf = 0
          for _, e in ipairs(m.entrees or {}) do
            local cote = entree_oriente(e, L, H, T)
            local ok = false
            for _, s in ipairs(supplies) do
              if s.cote == cote then
                for tok in pairs(e.jetons) do
                  for _, t2 in ipairs(s.jetons) do if t2 == tok then ok = true end end
                end
              end
            end
            if not ok and #supplies > 0 then nf = nf + 1 end
          end
          fauxT[ti] = nf
          if nf < minfaux then minfaux = nf end
        end
        for ti, T in ipairs(Ts) do
         if fauxT[ti] == minfaux then
          local l, hh = D.dims(L, H, T)
          local es = {}
          for i, e in ipairs(m.entrees or {}) do
            local cote, ex, ey = entree_oriente(e, L, H, T)
            es[i] = { cote, ex, ey, e.jetons }
          end
          for _, a in ipairs(cands) do
            local faux, gap, ecart = 0, 0, 0
            for i = 1, #es do
              local cote, ex, ey, jetons = es[i][1], es[i][2], es[i][3], es[i][4]
              local ok = false
              for _, s in ipairs(supplies) do
                if s.cote == cote then
                  local partage = false
                  for tok in pairs(jetons) do
                    for _, t2 in ipairs(s.jetons) do if t2 == tok then partage = true end end
                  end
                  if partage then
                    ok = true
                    if cote == 2 then gap = gap + (zx1 - (a[1] + l))
                    elseif cote == 6 then gap = gap + (a[1] - Z.x)
                    elseif cote == 0 then gap = gap + (a[2] - Z.y)
                    else gap = gap + (zy1 - (a[2] + hh)) end
                    if s.pos then
                      local mon = (cote == 6 or cote == 2) and (a[2] + ey) or (a[1] + ex)
                      ecart = ecart + math.abs(mon - s.pos)
                    end
                  end
                end
              end
              if not ok and #supplies > 0 then faux = faux + 1 end
            end
            local cle = { faux, gap, ecart, a[2], a[1], T.miroir and 1 or 0, T.rot }
            local mieux = false
            if not meilleur then mieux = true
            else
              for i = 1, 7 do
                if cle[i] ~= meilleur.cle[i] then mieux = cle[i] < meilleur.cle[i]; break end
              end
            end
            if mieux then meilleur = { cle = cle, x = a[1], y = a[2], T = T, l = l, h = hh, faux = faux, ecart = gap + ecart } end
          end
         end
        end
        local cand = { n = bn, x = meilleur.x, y = meilleur.y, T = meilleur.T, l = meilleur.l, h = meilleur.h, faux = meilleur.faux, ecart = meilleur.ecart }
        if not best or cand.n > best.n then best = cand
        elseif cand.n == best.n and (cand.faux < best.faux or (cand.faux == best.faux and cand.ecart < best.ecart)) then best = cand end
      end
    end
  end
  return best
end

---------------------------------------------------------------------------------------------------
-- 3. Sélection
---------------------------------------------------------------------------------------------------
local function dans(liste, v)
  if not liste then return false end
  for i = 1, #liste do if liste[i] == v then return true end end
  return false
end

--- Cause d'écart tirée des données du client (rôles, tailles, poteau), ou nil.
local function cause_donnees(m, ctx)
  if ctx.dispo then
    for _, role in ipairs(m.roles) do
      if role == "poteau" and ctx.energie == false then
        -- aucune électricité : le poteau n'est pas requis
      elseif not ctx.dispo[role] then
        return "role_indisponible:" .. role
      end
    end
  end
  if ctx.taille then
    for _, g in ipairs(m.derive.noms) do
      local e = m.derive.groupes[g]
      local t = ctx.taille[e.role]
      if t ~= nil then
        local ok = false
        if type(t) == "table" then ok = dans(t, e.w) else ok = (t == e.w) end
        if not ok then return "taille:" .. e.role .. "=" .. e.w end
      end
    end
  end
  local spec = m.exige_poteau or { supply = 2.5, fil = 7.5 }
  local alim = false
  for _, p in ipairs(m.pieces) do if D.alimente(p.role, p) then alim = true; break end end
  if alim and ctx.energie ~= false and ctx.poteau then
    if ctx.poteau.supply + EPS < spec.supply or ctx.poteau.fil + EPS < spec.fil then return "poteau_insuffisant" end
  end
  return nil
end

local function recherches(m, ctx)
  local n = 0
  if ctx.dispo then
    for _, role in ipairs(m.roles) do if ctx.dispo[role] == "recherche" then n = n + 1 end end
  end
  return n
end

--- Jetons que les entrées disponibles ne fournissent pas, ou nil.
local function jeton_manquant(m, supplies)
  if #supplies == 0 then return nil end
  local dispo = {}
  for _, s in ipairs(supplies) do for _, t in ipairs(s.jetons) do dispo[t] = true end end
  local manque
  for _, e in ipairs(m.entrees or {}) do
    local toks = {}
    for tok in pairs(e.jetons) do toks[#toks + 1] = tok end
    table.sort(toks)
    for _, tok in ipairs(toks) do
      if not dispo[tok] and not manque then manque = tok end
    end
  end
  return manque
end

--- Choisit le motif, le nombre de tuiles et l'orientation. Voir l'en-tête pour req et la sortie.
function X.choisir(req)
  local ctx = req.ctx or {}
  local dem = req.demande or {}
  local Z = req.zone
  if type(Z) ~= "table" or not (Z.x and Z.y and Z.l and Z.h) or Z.l < 0 or Z.h < 0 then
    error("Choix.choisir : zone = { x, y, l, h } requise (tuiles entières, l et h positifs)", 0)
  end
  local obs = obstacles_de(req)
  local supplies = sides_de(req)
  local fams
  if req.familles then fams = req.familles elseif req.famille then fams = { req.famille } end
  local retenus, ecartes = {}, {}
  local max_n = min(req.max_n or X.MAX_N, X.MAX_N)

  for _, m in ipairs(Cat.MOTIFS) do
    local cause
    if fams and not dans(fams, m.famille) then cause = "hors_famille"
    elseif req.usage and not dans(m.usages, req.usage) then cause = "hors_usage" end
    local deb, n_besoin, transport
    if not cause then
      cause = cause_donnees(m, ctx)
    end
    if not cause then
      local j = jeton_manquant(m, supplies)
      if j then cause = "jeton_manquant:" .. j end
    end
    if not cause then
      if m.capacite then
        -- transport : bus (voies, longueur) ou équilibreur (entrees, sorties)
        transport = true
        local c = m.capacite
        if c.piquage or dem.piquage then
          if not (c.piquage and dem.piquage and dem.voies) then cause = "demande_incompatible"
          elseif c.voies < dem.voies then cause = "capacite_insuffisante" end
          n_besoin = 1
        elseif c.entrees then
          if not (dem.entrees and dem.sorties) then cause = "demande_incompatible"
          elseif (c.pas ~= nil) ~= (dem.pas ~= nil) then cause = "demande_incompatible"   -- tête de distribution : la demande donne le pas
          elseif c.pas and (c.pas ~= dem.pas or c.sorties ~= dem.sorties) then cause = "capacite_insuffisante"
          elseif c.entrees < dem.entrees or c.sorties < dem.sorties then cause = "capacite_insuffisante"
          end
          n_besoin = 1
        else
          if not (dem.voies and dem.longueur) then cause = "demande_incompatible"
          elseif c.voies < dem.voies then cause = "capacite_insuffisante"
          end
          n_besoin = dem.longueur
        end
      else
        if not (dem.jeton and dem.debit) then cause = "demande_incompatible"
        else
          local d, why = X.debit(m, ctx)
          if not d then cause = why
          else
            deb = d
            local q = d.sortie[dem.jeton] or 0
            if q <= EPS then cause = "pas_de_sortie:" .. dem.jeton
            else
              n_besoin = max(1, ceil(dem.debit / q - EPS))
            end
          end
        end
      end
    end
    if cause then
      ecartes[#ecartes + 1] = { id = m.id, cause = cause }
    else
      local cap = n_besoin
      local limite = "demande"
      if m.max_tuiles and m.max_tuiles < cap then cap = m.max_tuiles; limite = "borne" end   -- borne propre du motif (eau d'une pompe…)
      if deb and deb.n_tapis < cap then cap = max(0, deb.n_tapis); limite = "tapis" end
      if cap > max_n then cap = max_n end
      if cap < 1 then
        ecartes[#ecartes + 1] = { id = m.id, cause = "tapis_sature" }
      else
        local pl = placer(m, cap, Z, obs, supplies)
        if not pl then
          ecartes[#ecartes + 1] = { id = m.id, cause = "place_insuffisante" }
        else
          local n = pl.n
          if n < cap or (not m.repetable and n < 1) then limite = "place"
          elseif cap == max_n and cap < n_besoin then limite = "max_n" end
          local q = deb and (deb.sortie[dem.jeton] or 0) or 0
          local total = q * n
          local couvre
          if transport then couvre = (n >= n_besoin) else couvre = total + EPS >= dem.debit end
          retenus[#retenus + 1] = {
            id = m.id, n = n, x = pl.x, y = pl.y, orient = pl.T, l = pl.l, h = pl.h, couvre = couvre, limite = couvre and "demande" or limite,
            debit = deb and { tuile = deb.sortie, total = total } or nil, faux = pl.faux, ecart = pl.ecart,
            surface = pl.l * pl.h, recherches = recherches(m, ctx), capacite = m.capacite, famille = m.famille,
            n_besoin = n_besoin, util = deb and deb.util or nil, limites = deb and deb.limites or nil,
          }
        end
      end
    end
  end
  table.sort(ecartes, function(a, b) return a.id < b.id end)

  -- classement : couvre la demande ; puis, selon le cas, moins de raccords hors côté, moins de surface, moins de recherches
  local function avant(a, b)
    if a.couvre ~= b.couvre then return a.couvre end
    if a.capacite and b.capacite then
      local ca, cb = a.capacite, b.capacite
      if ca.repartiteurs and cb.repartiteurs and ca.repartiteurs ~= cb.repartiteurs then return ca.repartiteurs < cb.repartiteurs end
      if ca.voies and cb.voies and ca.voies ~= cb.voies then return ca.voies < cb.voies end
    end
    if not a.couvre then
      local ta, tb = a.debit and a.debit.total or 0, b.debit and b.debit.total or 0
      if math.abs(ta - tb) > EPS then return ta > tb end
    end
    if a.faux ~= b.faux then return a.faux < b.faux end
    if a.surface ~= b.surface then return a.surface < b.surface end
    if a.recherches ~= b.recherches then return a.recherches < b.recherches end
    if a.ecart ~= b.ecart then return a.ecart < b.ecart end
    return a.id < b.id
  end
  table.sort(retenus, avant)
  local res = { retenus = retenus, ecartes = ecartes }
  local top = retenus[1]
  if top then
    res.motif, res.n, res.orient, res.x, res.y, res.l, res.h = top.id, top.n, top.orient, top.x, top.y, top.l, top.h
    res.couvre, res.limite, res.debit = top.couvre, top.limite, top.debit
    for i = 2, #retenus do
      ecartes[#ecartes + 1] = { id = retenus[i].id, cause = "moins_bon:" .. (retenus[i].couvre and "couvre" or "ne_couvre_pas") }
    end
    table.sort(ecartes, function(a, b) return a.id < b.id end)
  end
  return res
end

return X
