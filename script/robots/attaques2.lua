--[[
  Lot DESIGN-ATTAQUES (5/11, nuit) : la 2e attaque (« grande attaque ») des 5 géants expérimentaux, en jeu. PROTOTYPE DE DESIGN : rien ne
  part dans le jeu livré sans le verdict visuel du DC. Règles pures : shared/robots/attaques2.lua ; images : script/robots/attaques2_effets.lua ;
  prototypes : prototypes/attaques2.lua (0 image neuve).

  - Lancée par la touche du joueur (Ctrl + Maj + H : vos géants à portée du curseur), l'interface « fo-att2 » (bancs), ou en automatique
    (stockage `auto`, éteint par défaut : jamais près d'un bâtiment de sa force, jamais sur une unité seule).
  - Une à la fois par géant ; recharge A.RECHARGE (30 s), A.RECHARGE_ORDRE (15 s) sur ordre.
  - Phases : charge (le corps s'allume ; Stylet et Trombe VOLENT jusqu'au départ), frappe (L'UNIQUE recherche d'entités de la salve, puis le
    plan : chaque cible reçoit son tick et sa part), puis tranches. Séquelles enregistrées (lave et verre qui refroidissent).
  - Dégâts : seulement aux forces ENNEMIES (force.is_enemy) ; damage() avec chute au bord (résistances comptées). Meurent d'office : ce que
    la lave recouvre, ce qui est sous une falaise, les poteaux grillés par la Surtension.
  - Jamais de falaise, de lave ni de verre sous un bâtiment qui n'est pas ennemi (marge d'une tuile), ni sur un sol posé (béton, dalles :
    tuile cachée dessous), ni sur l'eau.
  - Coût mesuré par salve (stats[id]) : recherches, candidats, opérations au pire tick.
  Déterminisme : listes triées par numéro d'unité, graine maison, aucun pairs, aucun hasard du moteur.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local Xp = require("shared.robots.experimentaux")
local A = require("shared.robots.attaques2")
local K = require("script.robots.experimentaux_commun")
local V = require("script.robots.attaques2_effets")

local M = {}

local GEANT = {}
for _, r in ipairs(Xp.GEANTS) do GEANT[r.name] = r end

Storage.declare("attaques2", function()
  return { auto = false, journal = false, jobs = {}, pret = {}, stats = {}, laves = {}, verres = {} }
end)

local function S()
  local s = Storage.ns("attaques2")
  if s and not s.verres then s.verres = {} end
  return s
end

local function stat(id)
  local s = S()
  local st = s.stats[id]
  if not st then
    st = { salves = 0, cibles = 0, tues = 0, degats = 0, falaises = 0, poteaux = 0, foudres = 0, tuiles = 0, rochers = 0, feux = 0,
      recherches = 0, candidats = 0, max_ops = 0 }
    s.stats[id] = st
  end
  return st
end

local function journal(fmt, ...)
  local s = S()
  if s and s.journal then log(A.LOG .. " " .. string.format(fmt, ...)) end
end

local function ops(j, n) j.ops = j.ops + (n or 1) end

---------------------------------------------------------------------------------------------------
-- Dégâts
---------------------------------------------------------------------------------------------------
--- Frappe une entité ennemie : morte d'office (tue), ou coup × mult × chute(f). Rend vrai si elle est morte.
local function toucher(j, r, a, ent, f, tue, mult)
  if not (ent and ent.valid and ent.health and ent.destructible) then return false end
  local force = game.forces[j.force]
  if not (force and force.is_enemy(ent.force)) then return false end
  local st = stat(j.id)
  local src = j.e.valid and j.e or nil
  st.cibles = st.cibles + 1
  ops(j)
  if tue then
    local hp = ent.health
    if src then ent.die(force, src) else ent.die(force) end
    st.tues = st.tues + 1
    st.degats = st.degats + hp
    return true
  end
  local d = A.chute(A.coup(r) * (mult or 1), f, a.bord)
  local dealt
  if src then dealt = ent.damage(d, force, r.dtype, src) else dealt = ent.damage(d, force, r.dtype) end
  st.degats = st.degats + (dealt or 0)
  if not ent.valid then
    st.tues = st.tues + 1
    return true
  end
  return false
end

--- Une entité neutre (arbre, rocher) sur le tracé : elle meurt.
local function abattre(j, ent)
  if ent and ent.valid and ent.health and ent.destructible then
    ent.die()
    ops(j)
  end
end

---------------------------------------------------------------------------------------------------
-- Frappe : l'unique recherche, puis le plan
---------------------------------------------------------------------------------------------------
local NEUTRES = { tree = true, ["simple-entity"] = true }
local PASSAGERS = { corpse = true, ["item-entity"] = true, fire = true, cliff = true, explosion = true, ["entity-ghost"] = true,
  ["tile-ghost"] = true, ["particle-source"] = true, stream = true, beam = true, projectile = true, ["deconstructible-tile-proxy"] = true }

--- Range une tranche des entités trouvées (au plus A.PREP par tick) : ennemies (candidats, planifiés aussitôt), neutres (arbres, rochers),
--- autres (à protéger : jamais de falaise, lave ni verre dessous). Ordre : celui du moteur (déterministe), sans tri.
local planifier
local function ranger(j)
  local enemy = {}
  for _, n in ipairs(j.forces) do enemy[n] = true end
  local cands, neutres, autres = j.cands, j.neutres, j.autres
  local found = j.found
  local fin = math.min(#found, j.fi + A.PREP - 1)
  for i = j.fi, fin do
    local e = found[i]
    if e.valid then
      local p = e.position
      local c = { x = p.x, y = p.y, id = e.unit_number or (1000000000 + i), e = e }
      local fn = e.force.name
      if enemy[fn] and e.health and e.destructible then
        c.mobile = (e.type == "unit" or e.type == "character")
        cands[#cands + 1] = c
        planifier(j, c, #cands)
      elseif NEUTRES[e.type] then
        neutres[#neutres + 1] = c
        if j.gn then A.grille_ajoute(j.gn, #neutres, c, 8) end
      elseif not PASSAGERS[e.type] then
        local bb = e.bounding_box
        c.bb = { bb.left_top.x - 1, bb.left_top.y - 1, bb.right_bottom.x + 1, bb.right_bottom.y + 1 }
        autres[#autres + 1] = c
        A.grille_ajoute(j.ga, #autres, c, 8)
      end
    end
    ops(j)
  end
  j.fi = fin + 1
  if j.fi > #found then j.found = nil end
end

local function boite_recouvre(bb, x0, y0, x1, y1)
  return bb[1] < x1 and bb[3] > x0 and bb[2] < y1 and bb[4] > y0
end

--- Le plan d'une cible, rangé par tick dans j.par (tableau dense par tick relatif), dès qu'elle est rangée.
planifier = function(j, c, i)
  if j.id == "trombe" then A.grille_ajoute(j.g, i, c, 8); return end
  if j.id == "cairn" then return end
  local l
  if j.id == "stylet" then
    l = A.plan_balayage(j.o, j.rayons, { c }, j.bal.demi, j.bal.ticks, j.bal.pas)
  else
    l = A.plan(j.id, j.p, { c }, true)
  end
  local it = l[1]
  if it then
    it.i = i
    if j.id == "ixion" then it.t = it.t + A.ATTAQUES.ixion.lance end
    local b = j.par[it.t]
    if not b then b = {}; j.par[it.t] = b end
    b[#b + 1] = it
  end
end

--- Au 1er tick de la charge : L'UNIQUE recherche de la salve, et la géométrie ; le rangement et le plan suivent par tranches.
local function preparer(j, r, a)
  local e = j.e
  local s = j.surface
  local st = stat(j.id)
  j.forces = K.enemy_forces(e.force)
  local c = j.c
  j.cands, j.neutres, j.autres, j.ga, j.par, j.k, j.kk = {}, {}, {}, {}, {}, 0, 1
  j.p = { c = c, R = j.R }
  if j.id == "trombe" then j.g, j.gn, j.vus, j.morts, j.attente, j.kq = {}, {}, {}, {}, {}, 1 end
  if j.id == "ixion" then
    j.rl = j.R * a.lave
    j.bords = A.bords_lave(j.rl, a.secteurs, j.graine)
    j.p.rl, j.p.bords = j.rl, j.bords
  elseif j.id == "tournesol" then
    j.U = j.R / a.pas
    j.p.U = j.U
  end
  local q
  if j.id == "trombe" then
    q = { area = A.boite_cyclone(c, j.w, j.o, a.duree, 4, a.souffle + 2) }
  elseif j.id == "stylet" then
    -- le secteur du balayage : la boîte des 11 bouts de rayon et de l'origine
    local x0, y0, x1, y1 = j.o.x, j.o.y, j.o.x, j.o.y
    for _, e in ipairs(j.rayons) do
      x0, y0, x1, y1 = math.min(x0, e.x), math.min(y0, e.y), math.max(x1, e.x), math.max(y1, e.y)
    end
    q = { area = { { x0 - 3, y0 - 3 }, { x1 + 3, y1 + 3 } } }
  elseif j.id == "cairn" then
    q = { position = c, radius = math.max(j.R, 25) }
  elseif j.id == "tournesol" then
    q = { position = c, radius = j.R + a.pas / 2 + 1 }
  else
    q = { position = c, radius = j.R + 1 }
  end
  -- toutes les forces, sans le minerai : arbres et bâtiments à protéger servent aux falaises, à la lave et au verre
  j.found = s.find_entities_filtered({ area = q.area, position = q.position, radius = q.radius, type = { "resource" }, invert = true })
  j.fi = 1
  st.recherches = st.recherches + 1
end

--- À la frappe : la fin du rangement s'il en reste (charge trop courte pour la base), puis ce qui demande toute la liste.
local function frappe(j, r, a)
  local st = stat(j.id)
  while j.found do ranger(j) end
  local c = j.c
  local cands, neutres = j.cands, j.neutres
  st.candidats = st.candidats + #cands
  if j.id == "cairn" then
    M.plan_cairn(j, r, a)
    return
  elseif j.id == "stylet" then
    local bl = j.bal
    j.feux_pas = 0
    -- arbres et rochers dans la bande : ils brûlent au passage
    local nn = {}
    for _, n in ipairs(neutres) do
      for k2, e in ipairs(j.rayons) do
        if A.Ech.dans_bande(n, j.o, e, bl.demi) then nn[#nn + 1] = { t = math.floor((k2 - 1) * bl.ticks / bl.pas), id = n.id, e = n.e }; break end
      end
    end
    table.sort(nn, A.par_id)
    j.arbres, j.ka = nn, 1
    return
  elseif j.id == "trombe" then
    return
  elseif j.id == "ixion" then
    j.anneau = 0
    j.feux = A.feux(c, j.rl, j.R, a.feux, j.graine)
    j.kfeu = 1
    local nn = {}
    for _, n in ipairs(neutres) do
      local fl = A.f_lave(c, j.bords, n.x, n.y)
      if fl <= 1 then nn[#nn + 1] = { t = a.lance + A.t_fonte(fl, j.rl, a.fonte), id = n.id, e = n.e } end
    end
    table.sort(nn, A.par_id)
    j.arbres, j.ka = nn, 1
  elseif j.id == "tournesol" then
    j.u_prec = j.U
  end
end

--- Cairn : le réseau (parcours en largeur par les fils de cuivre, depuis le poteau ennemi le plus proche du centre) ; sans poteau, de proche
--- en proche entre les bâtiments ennemis (nids). Puis l'orage.
function M.plan_cairn(j, r, a)
  local poles, autres = {}, {}
  for _, c in ipairs(j.cands) do
    if c.e.type == "electric-pole" then poles[#poles + 1] = c elseif not c.mobile then autres[#autres + 1] = c end
  end
  local force = game.forces[j.force]
  j.fusee, j.kf = {}, 1
  local depart = Xp.nearest(j.c, poles, nil)
  if depart then
    local ents = { [depart.id] = depart.e }
    local voisins = function(un)
      local pe = ents[un]
      local l = {}
      if pe and pe.valid then
        local nb = pe.neighbours
        for _, q in ipairs(nb and nb.copper or {}) do
          if q.valid and q.unit_number and force.is_enemy(q.force) then
            ents[q.unit_number] = q
            l[#l + 1] = q.unit_number
          end
        end
      end
      ops(j)
      return l
    end
    local niveaux, parent = A.surtension(depart.id, voisins, a.sauts)
    for k, niv in ipairs(niveaux) do
      for _, un in ipairs(niv) do
        j.fusee[#j.fusee + 1] = { t = (k - 1) * a.saut_ticks, e = ents[un], p = parent[un] and ents[parent[un]] or nil, poteau = true }
      end
    end
  elseif #autres > 0 then
    local d0, bi = nil, 1
    for i, c in ipairs(autres) do
      local dd = (c.x - j.c.x) ^ 2 + (c.y - j.c.y) ^ 2
      if not d0 or dd < d0 then d0, bi = dd, i end
    end
    local niveaux, parent = A.reseau_proche(autres, bi, a.proche, a.sauts)
    for k, niv in ipairs(niveaux) do
      for _, i in ipairs(niv) do
        j.fusee[#j.fusee + 1] = { t = (k - 1) * a.saut_ticks, e = autres[i].e, p = parent[i] and autres[parent[i]].e or nil, poteau = false }
      end
    end
  end
  j.climax = (#j.fusee > 0 and j.fusee[#j.fusee].t or 0) + a.tenue
  j.orage = {}
  for k, i in ipairs(A.foudres(#autres, a.foudres, j.graine)) do
    j.orage[k] = { t = (k - 1) * a.foudre_ticks + 2, e = autres[i].e }
  end
  j.ko = 1
end

---------------------------------------------------------------------------------------------------
-- Pas de chaque grande attaque (après la frappe)
---------------------------------------------------------------------------------------------------
local VIDE = { accumulator = true, ["electric-turret"] = true, roboport = true }

local function pas_cairn(j, r, a, rt)
  local st = stat(j.id)
  local force = game.forces[j.force]
  while j.fusee[j.kf] and j.fusee[j.kf].t <= rt do
    local h = j.fusee[j.kf]
    if h.e and h.e.valid then
      V.saut(j, h.p, h.e, j.kf == 1, j.climax - h.t)
      ops(j, 2)
    end
    j.kf = j.kf + 1
  end
  if rt >= j.climax and (j.kc or 1) <= #j.fusee then
    -- tous les poteaux atteints sautent en quelques ticks (A.POTEAUX par tick) ; les réserves du réseau sont vidées
    if rt == j.climax then V.climax_son(j) end
    local k0 = j.kc or 1
    local k1 = math.min(#j.fusee, k0 + A.POTEAUX - 1)
    for k = k0, k1 do
      local h = j.fusee[k]
      if h.e and h.e.valid then
        V.climax_poteau(j, h.e, k)
        if h.poteau then
          st.poteaux = st.poteaux + 1
          toucher(j, r, a, h.e, 0, true)
        else
          toucher(j, r, a, h.e, 0, false)
        end
      end
    end
    j.kc = k1 + 1
    if j.kc > #j.fusee then
      for _, c in ipairs(j.cands) do
        if c.e.valid and VIDE[c.e.type] then c.e.energy = 0; ops(j) end
      end
    end
  end
  while j.orage[j.ko] and j.orage[j.ko].t <= rt do
    local b = j.orage[j.ko]
    if b.e and b.e.valid and force and force.is_enemy(b.e.force) then
      V.foudre(j, b.e.position)
      ops(j, 2)
      st.foudres = st.foudres + 1
      toucher(j, r, a, b.e, 0, false, 0.5)
    end
    j.ko = j.ko + 1
  end
end

local function deplacer(j, x, y)
  if j.e.valid then j.e.teleport({ x, y }) end
end

--- Le balayage : le rayon tourne de 30° en 2 s ; à chaque pas (3°), du feu et du sol brûlé tous les 4 tuiles le long du rayon (au plus
--- 12 feux et 12 brûlures par pas, un pas tous les 12 ticks) ; les cibles de la bande prennent la salve au premier pas qui les touche.
local function pas_balayage(j, r, a, rt)
  local st = stat(j.id)
  local s = j.surface
  local bl = j.bal
  if rt > bl.ticks then V.balayage_fin(j, rt); return end
  local x, y, k = A.bout_balayage(j.rayons, rt, bl.ticks, bl.pas)
  while j.feux_pas < k do
    j.feux_pas = j.feux_pas + 1
    local e = j.rayons[j.feux_pas]
    for n, p in ipairs(A.Ech.feux(j.o, e, bl.feu_pas)) do
      if n <= 12 then
        s.create_entity({ name = A.PREFIX .. "brasier-court", position = { p.x, p.y }, initial_ground_flame_count = 2 })
        s.create_entity({ name = "medium-scorchmark", position = { p.x, p.y } })
        st.feux = st.feux + 1
        ops(j, 2)
      end
    end
  end
  while j.arbres[j.ka] and j.arbres[j.ka].t <= rt do
    abattre(j, j.arbres[j.ka].e)
    j.ka = j.ka + 1
  end
  V.balayage(j, rt, x, y)
end

local function pas_stylet(j, r, a, rt)
  local st = stat(j.id)
  local s = j.surface
  local nx, ny = A.vol_stylet(j.depart, j.traits, rt, a.charge, a.vitesse)
  deplacer(j, nx, ny + 0.5)
  while j.falaises[j.kf] and j.falaises[j.kf].t <= rt do
    local f = j.falaises[j.kf]
    j.kf = j.kf + 1
    local hx, hy = (f.axe == "h") and 2 or 1, (f.axe == "h") and 1.5 or 2
    local x0, y0, x1, y1 = f.x - hx, f.y - hy, f.x + hx, f.y + hy
    local libre = true
    for _, i in ipairs(A.voisinage(j.ga, f.x, f.y, 4, 8)) do
      local o = j.autres[i]
      if o.e.valid and boite_recouvre(o.bb, x0, y0, x1, y1) then libre = false end
    end
    local tile = s.get_tile(math.floor(f.x), math.floor(f.y))
    if libre and tile.valid and not tile.hidden_tile and not tile.collides_with("water-tile") then
      for _, i in ipairs(A.voisinage(j.gc, f.x, f.y, 4, 8)) do
        local c = j.cands[i]
        if c.e.valid then
          local bb = c.e.bounding_box
          if boite_recouvre({ bb.left_top.x, bb.left_top.y, bb.right_bottom.x, bb.right_bottom.y }, x0, y0, x1, y1) then
            toucher(j, r, a, c.e, 0, true)
          end
        end
      end
      for _, i in ipairs(A.voisinage(j.gn, f.x, f.y, 3, 8)) do
        local n = j.neutres[i]
        if n.e.valid and math.abs(n.x - f.x) <= hx + 0.5 and math.abs(n.y - f.y) <= hy + 0.5 then abattre(j, n.e) end
      end
      local cl = s.create_entity({ name = "cliff", position = { f.x, f.y }, cliff_orientation = f.o })
      ops(j, 3)
      if cl then st.falaises = st.falaises + 1 end
      V.falaise(j, f)
    end
  end
  V.pointe(j, rt, nx, ny)
end

local function pas_trombe(j, r, a, rt)
  local t = math.min(rt, a.duree)
  local x, y = A.cyclone(j.c, j.w, j.o, t, a.duree)
  deplacer(j, x, y)
  if rt <= a.duree and rt % a.pas == 0 then
    local st = stat(j.id)
    local s = j.surface
    for _, i in ipairs(A.voisinage(j.g, x, y, a.souffle, 8)) do
      local c = j.cands[i]
      local e = c.e
      if not j.morts[i] and e.valid then
        local p = c.mobile and e.position or c
        local dx, dy = p.x - x, p.y - y
        local d = math.sqrt(dx * dx + dy * dy)
        -- les coups vont en file (A.COUPS par tick, plus bas) : un passage sur un îlot dense ne tue pas tout dans le même tick
        if d <= a.rayon then
          j.morts[i] = true
          j.attente[#j.attente + 1] = { i = i, f = 0, m = a.coeur }
        elseif d <= a.souffle and not j.vus[i] then
          j.vus[i] = true
          j.attente[#j.attente + 1] = { i = i, f = (d - a.rayon) / (a.souffle - a.rayon), m = 1 }
        end
      end
    end
    for _, i in ipairs(A.voisinage(j.gn, x, y, a.rayon, 8)) do
      local n = j.neutres[i]
      if n.e.valid and (n.x - x) ^ 2 + (n.y - y) ^ 2 <= a.rayon * a.rayon then abattre(j, n.e) end
    end
  end
  local s, st = j.surface, stat(j.id)
  local fin = math.min(#j.attente, j.kq + A.COUPS - 1)
  for k = j.kq, fin do
    local h = j.attente[k]
    local c = j.cands[h.i]
    if toucher(j, r, a, c.e, h.f, false, h.m) and not c.mobile then
      local q = A.debris(c.id, j.graine, a.debris)
      if q then
        s.create_entity({ name = A.ROCHERS[q], position = { c.x, c.y } })
        st.rochers = st.rochers + 1
        ops(j)
      end
    end
  end
  j.kq = fin + 1
  V.cyclone(j, rt, x, y)
end

local EAU = { ["water"] = true, ["deepwater"] = true, ["water-green"] = true, ["deepwater-green"] = true, ["water-shallow"] = true,
  ["water-mud"] = true, ["out-of-map"] = true }

--- File de tuiles : au plus A.TUILES vérifiées et posées par tick (`q` : { surface, ga, autres, file = { { x, y, nom, seule } }, i }).
local function enfiler(q, liste, nom, seule)
  q.file = q.file or {}
  for _, t in ipairs(liste) do q.file[#q.file + 1] = { x = t.x, y = t.y, nom = nom, seule = seule } end
end

local poser_tuiles
local function vider_file(q)
  if not q.file or #q.file == 0 then return 0 end
  q.i = q.i or 1
  local fin = math.min(#q.file, q.i + A.TUILES - 1)
  local n = 0
  local paquets = {}
  for k = q.i, fin do
    local t = q.file[k]
    local cle = t.nom .. "|" .. (t.seule or "")
    local p = paquets[cle]
    if not p then p = { nom = t.nom, seule = t.seule, l = {} }; paquets[cle] = p; paquets[#paquets + 1] = p end
    p.l[#p.l + 1] = t
  end
  for _, p in ipairs(paquets) do n = n + poser_tuiles(q, p.l, p.nom, p.seule) end
  q.i = fin + 1
  if q.i > #q.file then q.file, q.i = {}, 1 end
  return n
end

--- Pose une tuile sur une liste de tuiles, sans l'eau, sans un sol posé (tuile cachée dessous), sans ce qui touche un bâtiment protégé ;
--- `seule` : ne remplacer que cette tuile-là (refroidissement). Rend le nombre posé.
poser_tuiles = function(j, liste, nom, seule)
  local s = j.surface
  local t = {}
  for _, q in ipairs(liste) do
    local tile = s.get_tile(q.x, q.y)
    local ok = tile.valid and (seule and tile.name == seule or (not seule and not EAU[tile.name] and not tile.hidden_tile))
    if ok and j.ga and not seule then
      for _, i in ipairs(A.voisinage(j.ga, q.x + 0.5, q.y + 0.5, 2, 8)) do
        local o = j.autres[i]
        if o.e.valid and boite_recouvre(o.bb, q.x, q.y, q.x + 1, q.y + 1) then ok = false end
      end
    end
    if ok then t[#t + 1] = { name = nom, position = { q.x, q.y } } end
  end
  -- sans retirer les entités : une cible ennemie sous la lave ou le verre meurt par le plan (ses ruines, sa mort comptée), au plus
  -- A.COUPS par tick ; jamais retirée sans bruit (F135)
  if #t > 0 then s.set_tiles(t, true, false, true, false) end
  return #t
end

local function pas_ixion(j, r, a, rt)
  local st = stat(j.id)
  local s = j.surface
  if rt < a.lance then V.lance(j, rt); return end
  if rt == a.lance then V.eruption(j, a) end
  while j.anneau < a.anneaux do
    local f1 = (j.anneau + 1) / a.anneaux
    if a.lance + A.t_fonte(f1, j.rl, a.fonte) > rt then break end
    local f0 = (j.anneau == 0) and -1 or j.anneau / a.anneaux
    enfiler(j, A.tuiles_lave(j.c, j.bords, f0, f1), A.PREFIX .. "lave", nil)
    j.anneau = j.anneau + 1
    V.anneau(j, f1)
    if j.anneau == a.anneaux then
      local L = S().laves
      L[#L + 1] = { si = s.index, c = j.c, bords = j.bords, rl = j.rl, debut = game.tick + a.tenue, n = 0, anneaux = a.anneaux }
      V.lac(j, a)
    end
  end
  local n = vider_file(j)
  st.tuiles = st.tuiles + n
  ops(j, math.ceil(n / 16))
  while j.arbres[j.ka] and j.arbres[j.ka].t <= rt do
    abattre(j, j.arbres[j.ka].e)
    j.ka = j.ka + 1
  end
  while j.feux[j.kfeu] do
    local p = j.feux[j.kfeu]
    local dx, dy = p.x - j.c.x, p.y - j.c.y
    if a.lance + math.floor(math.sqrt(dx * dx + dy * dy) / a.onde) > rt then break end
    s.create_entity({ name = A.PREFIX .. "brasier", position = { p.x, p.y }, initial_ground_flame_count = 4 })
    st.feux = st.feux + 1
    ops(j)
    j.kfeu = j.kfeu + 1
  end
  V.chaleur(j, rt)
end

local function pas_tournesol(j, r, a, rt)
  local st = stat(j.id)
  local n = vider_file(j)
  st.tuiles = st.tuiles + n
  ops(j, math.ceil(n / 16))
  if rt > a.duree then return end
  local u = A.u_zenith(rt, a.duree, j.U)
  enfiler(j, A.tuiles_zenith(j.c, a.pas, j.u_prec, u, a.pinceau), A.PREFIX .. "verre-chaud", nil)
  local x, y = A.point_zenith(j.c, a.pas, u)
  V.zenith(j, rt, x, y, j.u_prec, u)
  j.u_prec = u
  if rt == a.duree then
    V.zenith_fin(j)
    local L = S().verres
    L[#L + 1] = { si = j.surface.index, c = j.c, pas = a.pas, U = j.U, pinceau = a.pinceau, debut = game.tick + a.tenue, n = 0, tranches = a.tranches }
  end
end

-- Stylet : le balayage (idée du DC) ; pas_stylet (la Balafre, falaises) reste écrit, en variante non branchée
local PAS = { cairn = pas_cairn, stylet = pas_balayage, trombe = pas_trombe, ixion = pas_ixion, tournesol = pas_tournesol, balafre = pas_stylet }

---------------------------------------------------------------------------------------------------
-- Lancer, avancer, finir
---------------------------------------------------------------------------------------------------
--- Lance la grande attaque du géant `e` sur le point (x, y). ordre : par le joueur (recharge courte). Rend vrai, ou faux et la raison.
function M.lancer(e, x, y, ordre)
  if not (e and e.valid) then return false, "geant absent" end
  local r = GEANT[e.name]
  if not r then return false, "pas un geant" end
  local s = S()
  for _, j in ipairs(s.jobs) do
    if j.un == e.unit_number then return false, "deja en cours" end
  end
  local t = game.tick
  local pret = s.pret[e.unit_number]
  if pret and t < pret then return false, "recharge" end
  local a = A.ATTAQUES[r.id]
  local p0 = e.position
  local j = { id = r.id, un = e.unit_number, e = e, surface = e.surface, force = e.force.name, c = { x = x, y = y }, t0 = t + a.charge,
    graine = (t * 7919 + e.unit_number * 104729) % 2147483646 + 1, R = A.zone(r.age), vis = {}, ops = 0, depart = { x = p0.x, y = p0.y } }
  if r.id == "stylet" then
    -- le rayon part du nez (au sol) ; longueur : la portée de l'unité (Ech.balayage), au moins jusqu'au point visé
    j.o = { x = p0.x, y = p0.y - 0.5 }
    local dx, dy = x - j.o.x, y - j.o.y
    j.bal = A.Ech.balayage(r.age, math.max(r.range, math.sqrt(dx * dx + dy * dy) + 5))
    j.rayons = A.Ech.rayons(j.o, j.c, j.bal.longueur)
    if not j.rayons then return false, "cible sous le geant" end
  elseif r.id == "trombe" then
    j.w = a.boucle * j.R
    j.o = (j.graine % 16) / 16
  end
  if r.id == "trombe" then e.autopilot_destination = nil end
  -- pendant sa grande attaque, le géant ne tire pas sa 1re attaque (il est tout entier à la grande) : on repousse son prochain tir dans
  -- le registre de script/robots/experimentaux_geants.lua (seul champ écrit : `next`)
  local fin = t + A.duree(r.id, { traits = j.traits, rl = j.R * (a.lave or 0), R = j.R })
  local ks = K.S()
  for _, g in ipairs(ks and ks.giants or {}) do
    if g.un == e.unit_number and (g.next or 0) < fin then g.next = fin end
  end
  s.jobs[#s.jobs + 1] = j
  s.pret[e.unit_number] = t + a.charge + (ordre and A.RECHARGE_ORDRE or A.RECHARGE)
  local st = stat(r.id)
  st.salves = st.salves + 1
  V.debut(j, r, a)
  journal("%s %s lance #%d vers (%.1f, %.1f) zone %d, frappe au tick %d", r.id, a.nom, e.unit_number, x, y, j.R, j.t0)
  return true
end

local function fin_job(j, r, a)
  V.fin(j)
  local st = stat(j.id)
  journal("%s %s fin #%d : cibles %d, tues %d, degats %.0f, falaises %d, poteaux %d, foudres %d, tuiles %d, rochers %d, feux %d, max ops/tick %d",
    j.id, a.nom, j.un, st.cibles, st.tues, st.degats, st.falaises, st.poteaux, st.foudres, st.tuiles, st.rochers, st.feux, st.max_ops)
end

--- Un tick d'une grande attaque ; rend vrai quand elle est finie (ou abandonnée : géant détruit).
local function avancer(j, tick)
  local r = Xp.robot(j.id)
  local a = A.ATTAQUES[j.id]
  local rt = tick - j.t0
  j.ops = 0
  if not (j.e and j.e.valid) then
    V.fin(j)
    journal("%s %s abandonnee : geant detruit (tick %d)", j.id, a.nom, tick)
    return true
  end
  if rt < 0 then
    if not j.cands then preparer(j, r, a) elseif j.found then ranger(j) end
    V.charge(j, r, a, rt)
    if j.id == "trombe" then
      local u = 1 + rt / a.charge
      u = u * u * (3 - 2 * u)
      deplacer(j, j.depart.x + (j.c.x - j.depart.x) * u, j.depart.y + (j.c.y - j.depart.y) * u)
    end
    return false
  end
  if rt == 0 then
    if not j.cands then preparer(j, r, a) end
    frappe(j, r, a)
    V.frappe(j, r, a)
    j.fin_rt = A.duree(j.id, { traits = j.traits, rl = j.rl, R = j.R }) - a.charge
  end
  if j.par then
    -- dégâts des ticks échus, au plus A.COUPS par tick (le reste au tick suivant)
    local n = 0
    while j.k <= rt and n < A.COUPS do
      local b = j.par[j.k]
      if b and j.kk <= #b then
        local it = b[j.kk]
        local c = j.cands[it.i]
        if c then toucher(j, r, a, c.e, it.f, it.tue) end
        j.kk = j.kk + 1
        n = n + 1
      else
        j.par[j.k] = nil
        j.k, j.kk = j.k + 1, 1
      end
    end
  end
  PAS[j.id](j, r, a, rt)
  local st = stat(j.id)
  if j.ops > st.max_ops then st.max_ops = j.ops end
  if rt >= j.fin_rt and not (j.file and #j.file > 0) and (not j.par or j.k > rt) and not (j.attente and j.kq <= #j.attente) then
    fin_job(j, r, a)
    return true
  end
  return false
end

--- Séquelles qui refroidissent : la lave (anneaux, du bord vers le centre) et le verre chaud (tranches de spirale, du bord vers le centre).
local function refroidir(tick)
  local s = S()
  local keep = {}
  local ix = A.ATTAQUES.ixion
  for _, L in ipairs(s.laves) do
    local surf = game.surfaces[L.si]
    local pas = math.floor(ix.refroidit / L.anneaux)
    if surf and surf.valid then
      while L.n < L.anneaux and tick >= L.debut + L.n * pas do
        local k = L.anneaux - L.n
        local f0 = (k == 1) and -1 or (k - 1) / L.anneaux
        L.q = L.q or { surface = surf, ops = 0 }
        enfiler(L.q, A.tuiles_lave(L.c, L.bords, f0, k / L.anneaux), "nuclear-ground", A.PREFIX .. "lave")
        L.n = L.n + 1
        journal("ixion lave : anneau %d en file de refroidissement, tick %d", k, tick)
      end
      if L.n < L.anneaux or (L.q and #L.q.file > 0) then keep[#keep + 1] = L end
    end
  end
  s.laves = keep
  keep = {}
  local tz = A.ATTAQUES.tournesol
  for _, G in ipairs(s.verres) do
    local surf = game.surfaces[G.si]
    local pas = math.floor(tz.refroidit / G.tranches)
    if surf and surf.valid then
      while G.n < G.tranches and tick >= G.debut + G.n * pas do
        -- tranches qui se recouvrent, pinceau élargi : le tracé échantillonné par tick est couvert (seul le verre chaud est remplacé)
        local u1, u2 = G.U * (1 - G.n / G.tranches), G.U * (1 - (G.n + 1) / G.tranches)
        G.q = G.q or { surface = surf, ops = 0 }
        enfiler(G.q, A.tuiles_zenith(G.c, G.pas, math.min(G.U, u1 + 0.03), math.max(0, u2 - 0.03), G.pinceau + 0.6), A.PREFIX .. "verre", A.PREFIX .. "verre-chaud")
        G.n = G.n + 1
        journal("tournesol verre : tranche %d en file de refroidissement, tick %d", G.n, tick)
      end
      if G.n < G.tranches or (G.q and #G.q.file > 0) then keep[#keep + 1] = G end
    end
  end
  s.verres = keep
end

local function sur_tick(ev)
  local s = S()
  if not s then return end
  if #s.jobs > 0 then
    local keep = {}
    for _, j in ipairs(s.jobs) do
      if not avancer(j, ev.tick) then keep[#keep + 1] = j end
    end
    s.jobs = keep
  end
  if ev.tick % 30 == 0 and (#s.laves > 0 or #s.verres > 0) then refroidir(ev.tick) end
  -- refroidissement par tranches : une seule file servie par tick (A.TUILES tuiles au plus)
  for _, L in ipairs(s.laves) do if L.q and #L.q.file > 0 then vider_file(L.q); return end end
  for _, G in ipairs(s.verres) do if G.q and #G.q.file > 0 then vider_file(G.q); return end end
end

--- Les géants de cette famille d'une force, vivants, triés par numéro (lecture seule du registre de script/robots/experimentaux_geants.lua).
local function geants_de(force)
  local out = {}
  local ks = K.S()
  for _, g in ipairs(ks and ks.giants or {}) do
    if g.e.valid and g.e.force == force then out[#out + 1] = g end
  end
  return out
end

--- La touche : le plus proche de vos géants prêts, à portée du curseur, lance sa grande attaque vers le curseur.
local function touche(ev)
  local player = game.get_player(ev.player_index)
  if not (player and player.valid and ev.cursor_position) then return end
  local cx, cy = ev.cursor_position.x, ev.cursor_position.y
  local best, bd
  for _, g in ipairs(geants_de(player.force)) do
    local r = Xp.robot(g.id)
    local p = g.e.position
    local d = (p.x - cx) ^ 2 + (p.y - cy) ^ 2
    local pret = S().pret[g.e.unit_number]
    if d <= (r.range + 15) ^ 2 and (not pret or ev.tick >= pret) and (not bd or d < bd) then best, bd = g, d end
  end
  if best then M.lancer(best.e, cx, cy, true) end
end

--- Automatique (éteint par défaut) : un géant prêt qui voit un BÂTIMENT ennemi à portée, loin de tout bâtiment de sa force, le vise.
local function auto(ev)
  local s = S()
  if not (s and s.auto) then return end
  local ks = K.S()
  if not ks then return end
  for _, g in ipairs(ks.giants) do
    local e = g.e
    if e.valid then
      local r = Xp.robot(g.id)
      local pret = s.pret[e.unit_number]
      if not pret or ev.tick >= pret then
        local t = e.surface.find_nearest_enemy_entity_with_owner({ position = e.position, max_distance = r.range, force = e.force })
        if t and t.type ~= "unit" and t.type ~= "character" then
          local amis = e.surface.count_entities_filtered({ position = t.position, radius = A.zone(r.age) + 4, force = e.force, limit = 2 })
          if amis <= 1 then M.lancer(e, t.position.x, t.position.y, false) end
        end
      end
    end
  end
end

Events.on(defines.events.on_tick, sur_tick)
Events.on_nth_tick(60, auto)
Events.on(A.PREFIX .. "grande", touche)

remote.add_interface("fo-att2", {
  lancer = function(e, x, y, ordre) return M.lancer(e, x, y, ordre) end,
  auto = function(v) S().auto = v and true or false end,
  journal = function(v) S().journal = v and true or false end,
  stats = function() return S().stats end,
  en_cours = function() return #S().jobs end,
  laves = function() return #S().laves end,
  verres = function() return #S().verres end,
})

return M
