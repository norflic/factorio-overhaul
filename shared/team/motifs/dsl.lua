--[[
  Lot MOTIFS : outils PURS de la base de motifs industriels (shared/team/motifs/catalogue.lua). Lua pur, aucune API du jeu.

  Un MOTIF est une TUILE qu'on répète le long d'un axe (« coller les modules en série ») : emprise l × h, période p
  (pas de répétition le long de x, dans l'orientation canonique), pièces par RÔLE (jamais par nom d'objet).
  Ce fichier : lecture d'un dessin en caractères (art), transformations (quarts de tour et miroir), instanciation de n
  tuiles, cellules occupées, vocabulaire des rôles.

  CONVENTIONS (celles de shared/team/modules.lua) :
    - coordonnées en TUILES entières, origine au coin nord-ouest de l'emprise, x vers l'est, y vers le sud ;
    - directions 1.1 : nord 0, est 2, sud 4, ouest 6 ;
    - un tapis va dans sa direction ; un bras de direction d PREND du côté d et DÉPOSE du côté opposé (un « bras
      dirigé vers le nord » prend au nord, dépose au sud) ; un bras long prend et dépose à 2 tuiles ;
    - un répartiteur (2 tuiles perpendiculaires à sa direction) va dans sa direction.
  Orientation canonique : la répétition se fait de gauche à droite (axe x). Les 8 orientations (4 quarts de tour × miroir)
  sont des transformations ENTIÈRES (aucune trigonométrie) : T = { rot = 0|2|4|6, miroir = bool } ; le miroir (y → −y,
  nord ↔ sud) s'applique d'abord, puis la rotation de rot/2 quarts de tour dans le sens des aiguilles d'une montre.

  Dessin (art) : une liste de chaînes de p caractères (une chaîne par rangée, de haut en bas). ' ' et '.' = vide. La
  légende associe un caractère à un modèle de pièce { role, k, dir, w, h, ... } ; une pièce plus grande que 1 × 1 est
  lue comme un bloc w × h (premier caractère non lu de haut en bas, de gauche à droite).

  Déterminisme : listes et tris seulement, aucun pairs décisionnel, aucune trigonométrie.
]]

local D = {}

D.N, D.E, D.S, D.W = 0, 2, 4, 6
local N, E, S, W = 0, 2, 4, 6
D.DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }
local DV = D.DV
D.COTES = { N = 0, E = 2, S = 4, O = 6, W = 6 }

--- Rôles connus : classe, tailles permises (côtés d'une machine carrée), alimentation électrique.
D.ROLES = {
  machine_fonte = { classe = "machine", tailles = { 2, 3 } },
  machine_asm = { classe = "machine", tailles = { 3 } },
  -- boîtes à fluide : cellules (dx, dy) RELATIVES au coin nord-ouest de la machine, tournée vers le nord, où un tuyau se
  -- raccorde (valeurs de shared/team/modules.lua : usine chimique, raffinerie, chevalet)
  machine_chimie = { classe = "machine", tailles = { 3 }, entrees_fluide = { { 0, -1 }, { 2, -1 } }, sorties_fluide = { { 0, 3 }, { 2, 3 } } },
  machine_raffinerie = { classe = "machine", tailles = { 5 }, entrees_fluide = { { 1, 5 }, { 3, 5 } },
    sorties_fluide = { { 0, -1 }, { 2, -1 }, { 4, -1 } } },
  foreuse = { classe = "machine", tailles = { 2, 3 } },
  chevalet = { classe = "machine", tailles = { 3 }, sorties_fluide = { { 2, -1 } },
    sorties_fluide_dir = { [0] = { { 2, -1 } }, [2] = { { 3, 0 } }, [4] = { { 0, 3 } }, [6] = { { -1, 2 } } } },
  bras = { classe = "bras", portee = 1, elec = true },
  bras_long = { classe = "bras", portee = 2, elec = true },
  tapis_entree = { classe = "tapis" },
  tapis_sortie = { classe = "tapis" },
  tapis = { classe = "tapis" },
  repartiteur = { classe = "repartiteur" },
  souterrain_entree = { classe = "souterrain" },
  souterrain_sortie = { classe = "souterrain" },
  poteau = { classe = "poteau" },
  tuyau = { classe = "tuyau" },
  tuyau_souterrain = { classe = "tuyau_souterrain" },
  coffre = { classe = "coffre" },
}

--- Rôles qui consomment de l'électricité (les machines, selon ce que le client y pose : voir ctx.energie).
function D.alimente(role, piece)
  local r = D.ROLES[role]
  if not r then return false end
  if piece and piece.combustion then return false end  -- machine ou bras à combustion : aucun poteau
  return r.classe == "machine" or r.classe == "bras"
end

function D.est_tapis(role)
  local r = D.ROLES[role]
  return r ~= nil and (r.classe == "tapis" or r.classe == "souterrain" or r.classe == "repartiteur")
end

---------------------------------------------------------------------------------------------------
-- Lecture d'un dessin
---------------------------------------------------------------------------------------------------
local function copy(t)
  local o = {}
  for k, v in pairs(t) do o[k] = v end
  return o
end
D.copy = copy

--- Pièces d'un dessin. Renvoie la liste (ordre : rangées puis colonnes) ou (nil, raison).
function D.lire(art, legende, nom)
  nom = nom or "?"
  local pieces = {}
  local vu = {}
  local largeur = #art[1]
  for y, ligne in ipairs(art) do
    if #ligne ~= largeur then return nil, string.format("%s : rangée %d de longueur %d au lieu de %d", nom, y, #ligne, largeur) end
  end
  for y0, ligne in ipairs(art) do
    for x0 = 1, #ligne do
      local c = ligne:sub(x0, x0)
      local key = (y0 - 1) * 4096 + (x0 - 1)
      if c ~= " " and c ~= "." and not vu[key] then
        local m = legende[c]
        if not m then return nil, string.format("%s : caractère « %s » sans légende (rangée %d, colonne %d)", nom, c, y0, x0) end
        local w, h = m.w or 1, m.h or 1
        for dy = 0, h - 1 do
          for dx = 0, w - 1 do
            local yy, xx = y0 + dy, x0 + dx
            local l2 = art[yy]
            if not l2 or xx > #l2 or l2:sub(xx, xx) ~= c then
              return nil, string.format("%s : bloc %d×%d de « %s » incomplet en (%d, %d)", nom, w, h, c, x0 - 1, y0 - 1)
            end
            local k2 = (yy - 1) * 4096 + (xx - 1)
            if vu[k2] then return nil, string.format("%s : bloc de « %s » recouvre une cellule déjà lue en (%d, %d)", nom, c, xx - 1, yy - 1) end
            vu[k2] = true
          end
        end
        local p = copy(m)
        p.x, p.y, p.w, p.h = x0 - 1, y0 - 1, w, h
        p.car = c
        pieces[#pieces + 1] = p
      end
    end
  end
  return pieces
end

---------------------------------------------------------------------------------------------------
-- Transformations
---------------------------------------------------------------------------------------------------
--- Dimensions d'une boîte L × H après la transformation T.
function D.dims(L, H, T)
  if T.rot == 2 or T.rot == 6 then return H, L end
  return L, H
end

--- Direction après T.
function D.dir_t(d, T)
  if T.miroir then
    if d == N then d = S elseif d == S then d = N end
  end
  return (d + T.rot) % 8
end

--- Rectangle (x, y, w, h) d'une boîte L × H après T.
function D.rect_t(x, y, w, h, L, H, T)
  if T.miroir then y = H - y - h end
  local r = T.rot
  if r == 0 then return x, y, w, h end
  if r == 2 then return H - y - h, x, h, w end
  if r == 4 then return L - x - w, H - y - h, w, h end
  if r == 6 then return y, L - x - w, h, w end
  error("rotation invalide : " .. tostring(r))
end

--- Côté (direction sortante) après T.
D.dir_cote = D.dir_t

D.ORIENTATIONS = {}
for _, m in ipairs({ false, true }) do
  for _, r in ipairs({ 0, 2, 4, 6 }) do D.ORIENTATIONS[#D.ORIENTATIONS + 1] = { rot = r, miroir = m } end
end

function D.nom_orientation(T) return (T.miroir and "m" or "") .. "r" .. T.rot end

---------------------------------------------------------------------------------------------------
-- Instanciation
---------------------------------------------------------------------------------------------------
--- Longueur totale (tuiles le long de l'axe canonique) de n tuiles, tête et queue comprises.
function D.longueur(motif, n)
  return (motif.tete and motif.tete.len or 0) + n * motif.periode + (motif.queue and motif.queue.len or 0)
end

--- Dimensions (l, h) de l'emprise de n tuiles dans l'orientation T.
function D.emprise(motif, n, T)
  return D.dims(D.longueur(motif, n), motif.h, T or { rot = 0, miroir = false })
end

--- Cellule (x, y) et côté (direction sortante) d'un port déclaré, dans une boîte L × H canonique. cote : O, E (pos = rangée),
--- N, S (pos = colonne ; motifs à tuile unique seulement).
function D.cellule_port(e, L, H)
  if e.cote == "O" or e.cote == "W" then return 0, e.pos, W end
  if e.cote == "E" then return L - 1, e.pos, E end
  if e.cote == "N" then return e.pos, 0, N end
  if e.cote == "S" then return e.pos, H - 1, S end
  error("côté invalide : " .. tostring(e.cote))
end

--- Instance de n tuiles : { pieces, l, h, n, ports } dans l'orientation T, origine au coin nord-ouest de l'emprise
--- transformée. opt.sans_poteaux : omet les poteaux.
function D.instancier(motif, n, T, opt)
  T = T or { rot = 0, miroir = false }
  opt = opt or {}
  local off = motif.tete and motif.tete.len or 0
  local L = D.longueur(motif, n)
  local H = motif.h
  local out = {}
  local function add(p, dx, bloc, i)
    if opt.sans_poteaux and p.role == "poteau" then return end
    local q = copy(p)
    q.x = p.x + dx
    q.bloc, q.tuile = bloc, i
    local x, y, w, h = D.rect_t(q.x, q.y, q.w, q.h, L, H, T)
    q.x, q.y, q.w, q.h = x, y, w, h
    if q.dir then q.dir = D.dir_t(q.dir, T) end
    out[#out + 1] = q
  end
  if motif.tete then for _, p in ipairs(motif.tete.pieces) do add(p, 0, "tete", 0) end end
  for i = 0, n - 1 do
    for _, p in ipairs(motif.pieces) do add(p, off + i * motif.periode, "tuile", i + 1) end
  end
  if motif.queue then for _, p in ipairs(motif.queue.pieces) do add(p, off + n * motif.periode, "queue", 0) end end
  local W2, H2 = D.dims(L, H, T)
  -- ports : cellules de bord déclarées par le motif (cote = O/E : bouts de la répétition), transformées
  local ports = {}
  local function port(io, e)
    local cx, cy, c = D.cellule_port(e, L, H)
    local x, y = D.rect_t(cx, cy, 1, 1, L, H, T)
    ports[#ports + 1] = { io = io, k = e.k, x = x, y = y, cote = D.dir_cote(c, T), jetons = e.jetons, voies = e.voies, fluide = e.fluide }
  end
  for _, e in ipairs(motif.entrees or {}) do port("in", e) end
  for _, e in ipairs(motif.sorties or {}) do port("out", e) end
  return { pieces = out, l = W2, h = H2, n = n, T = T, ports = ports, motif = motif.id }
end

--- Cellules occupées par une pièce : liste de { x, y }.
function D.cellules(p)
  local c = {}
  for dy = 0, (p.h or 1) - 1 do
    for dx = 0, (p.w or 1) - 1 do c[#c + 1] = { p.x + dx, p.y + dy } end
  end
  return c
end

--- Table des cellules occupées : key(x, y) → pièce (indice dans la liste). Renvoie (table, erreurs de recouvrement).
function D.occupation(pieces)
  local occ, err = {}, {}
  for i, p in ipairs(pieces) do
    for _, c in ipairs(D.cellules(p)) do
      local k = c[2] * 65536 + c[1] + 32768
      if occ[k] then
        err[#err + 1] = string.format("recouvrement en (%d, %d) : %s et %s", c[1], c[2], pieces[occ[k]].role, p.role)
      else
        occ[k] = i
      end
    end
  end
  return occ, err
end

function D.cle(x, y) return y * 65536 + x + 32768 end

--- Rôles utilisés par un motif (tête et queue comprises), triés.
function D.roles_utilises(motif)
  local vu, liste = {}, {}
  local function scan(ps)
    for _, p in ipairs(ps or {}) do
      if not vu[p.role] then vu[p.role] = true; liste[#liste + 1] = p.role end
    end
  end
  scan(motif.pieces)
  if motif.tete then scan(motif.tete.pieces) end
  if motif.queue then scan(motif.queue.pieces) end
  table.sort(liste)
  return liste
end

--- Compte des pièces d'un rôle dans une tuile.
function D.compte(motif, role)
  local n = 0
  for _, p in ipairs(motif.pieces) do if p.role == role then n = n + 1 end end
  return n
end

--- Rendu texte d'une instance (pour docs/MOTIFS.md et le débogage) : un caractère par cellule.
local GLYPHE_TAPIS = { [N] = "^", [E] = ">", [S] = "v", [W] = "<" }
local GLYPHE_BRAS = { [N] = "n", [E] = "e", [S] = "s", [W] = "o" }
function D.dessiner(inst)
  local g = {}
  for y = 1, inst.h do
    g[y] = {}
    for x = 1, inst.l do g[y][x] = "." end
  end
  local lettre = 0
  for _, p in ipairs(inst.pieces) do
    local r = D.ROLES[p.role] or {}
    local ch
    if r.classe == "tapis" then ch = GLYPHE_TAPIS[p.dir or E]
    elseif r.classe == "souterrain" then ch = (p.role == "souterrain_entree") and "u" or "U"
    elseif r.classe == "repartiteur" then ch = "="
    elseif r.classe == "bras" then ch = GLYPHE_BRAS[p.dir or N]; if p.role == "bras_long" then ch = ch:upper() end
    elseif r.classe == "poteau" then ch = "+"
    elseif r.classe == "tuyau" then ch = "~"
    elseif r.classe == "tuyau_souterrain" then ch = "t"
    elseif r.classe == "coffre" then ch = "#"
    else
      lettre = lettre + 1
      ch = string.char(string.byte("A") + (lettre - 1) % 26)
    end
    for _, c in ipairs(D.cellules(p)) do
      if g[c[2] + 1] and g[c[2] + 1][c[1] + 1] then g[c[2] + 1][c[1] + 1] = ch end
    end
  end
  local lignes = {}
  for y = 1, inst.h do lignes[y] = table.concat(g[y]) end
  return lignes
end

---------------------------------------------------------------------------------------------------
-- Constructeurs de légende (pour écrire les motifs sans répéter les champs)
---------------------------------------------------------------------------------------------------
D.h = {}
local h = D.h
function h.entree(k, dir) return { role = "tapis_entree", k = k, dir = dir } end
function h.sortie(k, dir) return { role = "tapis_sortie", k = k, dir = dir } end
function h.tapis(dir) return { role = "tapis", dir = dir } end
--- Bras : `dir` = côté où il PREND ; prend / depose = références de rôle « role » ou « role:k » ; lien = identifiant du
--- lien (motif.liens) dont il fait partie.
function h.bras(dir, prend, depose, lien) return { role = "bras", dir = dir, prend = prend, depose = depose, lien = lien } end
function h.bras_long(dir, prend, depose, lien) return { role = "bras_long", dir = dir, prend = prend, depose = depose, lien = lien } end
function h.machine(role, taille, groupe, extra)
  local m = { role = role, w = taille, h = taille, groupe = groupe or "principal" }
  for k, v in pairs(extra or {}) do m[k] = v end
  return m
end
h.poteau = { role = "poteau" }
function h.coffre(k) return { role = "coffre", k = k } end
function h.tuyau(fluide) return { role = "tuyau", fluide = fluide } end
function h.ptg(dir, fluide) return { role = "tuyau_souterrain", dir = dir, fluide = fluide } end
function h.ug_entree(dir) return { role = "souterrain_entree", dir = dir } end
function h.ug_sortie(dir) return { role = "souterrain_sortie", dir = dir } end
--- Répartiteur : 2 tuiles perpendiculaires à sa direction.
function h.repartiteur(dir)
  if dir == E or dir == W then return { role = "repartiteur", dir = dir, w = 1, h = 2 } end
  return { role = "repartiteur", dir = dir, w = 2, h = 1 }
end

return D
