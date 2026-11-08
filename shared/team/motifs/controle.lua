--[[
  Lot MOTIFS : contrôle de COHÉRENCE d'un motif compilé (Lua pur ; joué par tests/motifs_test.lua sur chaque motif, jamais
  en jeu). Sur une instance de 3 tuiles (tête et queue comprises), orientation canonique :
    - pièces qui ne se chevauchent pas ; rôles connus ; tailles de machine permises ;
    - période ≥ emprise utile ; emprise déclarée = période × hauteur ;
    - bras : cellule de prise et cellule de dépôt tombent sur la pièce annoncée (`prend`, `depose`), liens déclarés ;
    - tapis : chaque tapis alimente un tapis (jamais de face-à-face), souterrains appariés (écart de 4 tuiles au plus), un
      tapis de sortie atteint le bord par une sortie DÉCLARÉE, un tapis d'entrée par une entrée DÉCLARÉE ; entrées et
      sorties déclarées présentes, sur le bord, dans le bon sens ; jamais deux objets sur une voie (voies disjointes) ;
    - répartiteurs : deux tuiles, entrée derrière, sortie devant ;
    - fluides : aucun mélange (deux tuyaux voisins du même réseau portent le même fluide), tuyaux souterrains appariés,
      cellules de raccord des machines ;
    - électricité : chaque machine et chaque bras dans l'aire d'un poteau ; poteaux reliés (portée de fil) ;
    - rapports : lien → machines servies, groupes déclarés.
  Renvoie la liste des erreurs (vide = cohérent).
]]

local function need(dotted, slashed)
  local ok, res = pcall(require, dotted)
  if ok and type(res) == "table" then return res end
  return require("__factorio-overhaul__/" .. slashed)
end
local D = need("shared.team.motifs.dsl", "shared/team/motifs/dsl")
local Cp = need("shared.team.motifs.compile", "shared/team/motifs/compile")

local K = {}
local N, E, S, W = 0, 2, 4, 6
local DV = D.DV

K.POTEAU_PETIT = { supply = 2.5, fil = 7.5 }
K.ECART_SOUTERRAIN = 5       -- entrée et sortie d'un souterrain jaune : 5 tuiles au plus d'écart
K.ECART_TUYAU_SOUTERRAIN = 11

local function opposite(d) return (d + 4) % 8 end

function K.verifier(m, opt)
  opt = opt or {}
  local err = {}
  local function e(fmt, ...) err[#err + 1] = m.id .. " : " .. string.format(fmt, ...) end

  -- emprise et période
  if m.emprise.l ~= m.periode or m.emprise.h ~= m.h then e("emprise %d×%d ≠ période × hauteur %d×%d", m.emprise.l, m.emprise.h, m.periode, m.h) end
  local maxx = 0
  for _, p in ipairs(m.pieces) do if p.x + p.w > maxx then maxx = p.x + p.w end end
  if m.periode < maxx then e("période %d < emprise utile %d", m.periode, maxx) end
  if m.periode < 1 or m.h < 1 then e("période ou hauteur nulle") end

  local nrep = m.repetable and 3 or 1
  local inst = D.instancier(m, nrep, { rot = 0, miroir = false })
  local pieces = inst.pieces
  local L, H = D.longueur(m, nrep), m.h
  local occ, over = D.occupation(pieces)
  for _, s in ipairs(over) do e("%s", s) end
  local function at(x, y) return pieces[occ[D.cle(x, y)] or 0] end
  local function inside(x, y) return x >= 0 and y >= 0 and x < L and y < H end

  -- rôles et tailles
  for _, p in ipairs(pieces) do
    local r = D.ROLES[p.role]
    if not r then e("rôle inconnu « %s »", tostring(p.role))
    else
      if r.classe == "machine" then
        if p.w ~= p.h then e("machine %s non carrée (%d×%d)", p.role, p.w, p.h) end
        local ok = false
        for _, t in ipairs(r.tailles) do if t == p.w then ok = true end end
        if not ok then e("machine %s de taille %d non permise", p.role, p.w) end
      end
      if (r.classe == "tapis" or r.classe == "bras" or r.classe == "souterrain" or r.classe == "repartiteur") and p.dir == nil then
        e("pièce %s sans direction en (%d, %d)", p.role, p.x, p.y)
      end
    end
  end

  -- bras
  local liens_vus = {}
  for _, p in ipairs(pieces) do
    local r = D.ROLES[p.role]
    if r and r.classe == "bras" then
      if not p.prend or not p.depose then e("bras sans prend/depose en (%d, %d)", p.x, p.y)
      else
        local prise, depot = Cp.prise_depot(p)
        local a, b = at(prise[1], prise[2]), at(depot[1], depot[2])
        if not Cp.correspond(a, p.prend) then
          e("bras (%d, %d) %s : prise en (%d, %d) sur %s, attendu %s", p.x, p.y, D.nom_orientation({ rot = 0 }), prise[1], prise[2], a and a.role or "vide", p.prend)
        end
        if not Cp.correspond(b, p.depose) then
          e("bras (%d, %d) : dépôt en (%d, %d) sur %s, attendu %s", p.x, p.y, depot[1], depot[2], b and b.role or "vide", p.depose)
        end
      end
      if not p.lien then e("bras (%d, %d) sans lien", p.x, p.y)
      else
        liens_vus[p.lien] = true
        if not (m.liens and m.liens[p.lien]) then e("lien « %s » non déclaré", p.lien) end
      end
    end
  end
  for _, id in ipairs(Cp.sorted_keys(m.liens or {})) do
    if not liens_vus[id] then e("lien déclaré « %s » sans bras", id) end
  end

  -- tapis : suite de chaque cellule
  local function paire_souterrain(p)
    local v = DV[p.dir]
    for i = 1, K.ECART_SOUTERRAIN do
      local q = at(p.x + v[1] * i, p.y + v[2] * i)
      if q and (q.role == "souterrain_entree" or q.role == "souterrain_sortie") then
        if q.role == "souterrain_sortie" and q.dir == p.dir then return q, i end
        return nil
      end
    end
    return nil
  end
  local sorties_decl, entrees_decl = {}, {}
  for _, s in ipairs(m.sorties or {}) do sorties_decl[#sorties_decl + 1] = s end
  for _, s in ipairs(m.entrees or {}) do entrees_decl[#entrees_decl + 1] = s end

  local function cell_port(s)
    local cx, cy = D.cellule_port(s, L, H)
    return cx, cy
  end
  local function est_sortie_decl(p, x, y, io)
    local liste = (io == "out") and sorties_decl or entrees_decl
    for _, s in ipairs(liste) do
      local cx, cy = cell_port(s)
      if cx == x and cy == y and s.k == p.k then return true end
    end
    return false
  end

  local alimente = {}   -- cellule → vrai quand un tapis y mène
  local function marque(x, y) alimente[D.cle(x, y)] = true end
  for _, p in ipairs(pieces) do
    local r = D.ROLES[p.role]
    if r and (r.classe == "tapis" or r.classe == "souterrain" or r.classe == "repartiteur") then
      for _, c in ipairs(D.cellules(p)) do
        if p.role == "souterrain_entree" then
          local q = paire_souterrain(p)
          if q then marque(q.x, q.y) end
        elseif p.role ~= "souterrain_sortie" or true then
          local v = DV[p.dir]
          local nx, ny = c[1] + v[1], c[2] + v[2]
          if p.role ~= "souterrain_sortie" or true then marque(nx, ny) end
        end
      end
    end
  end
  for _, p in ipairs(pieces) do
    local r = D.ROLES[p.role]
    if r and (r.classe == "tapis" or r.classe == "souterrain" or r.classe == "repartiteur") then
      local v = DV[p.dir]
      if p.role == "souterrain_entree" then
        if not paire_souterrain(p) then e("souterrain d'entrée sans sortie appariée en (%d, %d)", p.x, p.y) end
      end
      for _, c in ipairs(D.cellules(p)) do
        local x, y = c[1], c[2]
        -- aval
        if p.role ~= "souterrain_entree" then
          local nx, ny = x + v[1], y + v[2]
          if inside(nx, ny) then
            local q = at(nx, ny)
            local rq = q and D.ROLES[q.role]
            if not (q and rq and (rq.classe == "tapis" or rq.classe == "souterrain" or rq.classe == "repartiteur")) then
              e("%s en (%d, %d) mène à %s en (%d, %d)", p.role, x, y, q and q.role or "du vide", nx, ny)
            elseif q.dir == opposite(p.dir) then
              e("%s en (%d, %d) fait face à %s en (%d, %d)", p.role, x, y, q.role, nx, ny)
            elseif q.role == "souterrain_sortie" then
              e("%s en (%d, %d) mène au dos d'une sortie de souterrain en (%d, %d)", p.role, x, y, nx, ny)
            end
          else
            if p.role == "tapis_sortie" then
              if not est_sortie_decl(p, x, y, "out") then e("tapis de sortie %d quitte l'emprise en (%d, %d) sans sortie déclarée", p.k or 0, x, y) end
            elseif p.role == "tapis" then
              e("tapis interne quitte l'emprise en (%d, %d)", x, y)
            end
          end
        end
        -- amont
        if p.role == "tapis_entree" or p.role == "tapis" or p.role == "souterrain_entree" or p.role == "repartiteur" then
          local bx, by = x - v[1], y - v[2]
          if not alimente[D.cle(x, y)] then
            if not inside(bx, by) then
              if p.role == "tapis_entree" then
                if not est_sortie_decl(p, x, y, "in") then e("tapis d'entrée %d démarre au bord en (%d, %d) sans entrée déclarée", p.k or 0, x, y) end
              elseif p.role == "tapis" then
                e("tapis interne démarre au bord en (%d, %d)", x, y)
              end
            else
              if p.role == "tapis" or p.role == "tapis_entree" then
                -- un tapis sans amont au milieu : permis seulement s'il est ALIMENTÉ PAR UN BRAS (collecteur)
                e("%s en (%d, %d) sans amont", p.role, x, y)
              end
            end
          end
        end
      end
    end
  end
  -- déclarations présentes
  for _, io in ipairs({ "in", "out" }) do
    local liste = (io == "out") and sorties_decl or entrees_decl
    for _, s in ipairs(liste) do
      local cx, cy = cell_port(s)
      local q = at(cx, cy)
      local role = (io == "out") and "tapis_sortie" or "tapis_entree"
      if not q or q.role ~= role or q.k ~= s.k then
        e("%s %d déclarée en (%d, %d) absente (%s)", role, s.k or 0, cx, cy, q and (q.role .. ":" .. tostring(q.k)) or "vide")
      else
        local _, _, sens = D.cellule_port(s, L, H)
        local attendu = (io == "in") and opposite(sens) or sens
        if q.dir ~= attendu then e("%s %d en (%d, %d) va vers %d, attendu %d", role, s.k or 0, cx, cy, q.dir, attendu) end
      end
      if s.jetons then
        local vus = {}
        for jeton, voies in pairs(s.jetons) do
          for _, v in ipairs(voies) do
            if vus[v] then e("%s %d : voie %d portée par deux jetons", role, s.k or 0, v) end
            vus[v] = jeton
          end
        end
      else
        e("%s %d sans jetons", role, s.k or 0)
      end
    end
  end

  -- répartiteurs : deux tuiles, bien formées
  for _, p in ipairs(pieces) do
    if p.role == "repartiteur" then
      local horiz = (p.dir == E or p.dir == W)
      if horiz and not (p.w == 1 and p.h == 2) or (not horiz and not (p.w == 2 and p.h == 1)) then
        e("répartiteur mal dimensionné en (%d, %d)", p.x, p.y)
      end
    end
  end

  -- fluides
  local function surface_ouverte(p, dx, dy)
    -- cellule p voisine de (dx, dy) : le tuyau s'y raccorde-t-il ?
    if p.role == "tuyau" then return true end
    if p.role == "tuyau_souterrain" then
      -- dir = côté du raccord de SURFACE (comme shared/team/modules.lua) ; le souterrain part du côté opposé
      local v = DV[p.dir]
      return v[1] == dx and v[2] == dy
    end
    return false
  end
  local boites = {}   -- cellule → { fluide attendu ou false }
  for _, p in ipairs(pieces) do
    local r = D.ROLES[p.role]
    if r and r.classe == "machine" and (r.entrees_fluide or r.sorties_fluide) then
      local function poser(liste, jetons)
        for i, b in ipairs(liste or {}) do
          local key = D.cle(p.x + b[1], p.y + b[2])
          boites[key] = { tok = jetons and jetons[i] or false, piece = p, cell = { p.x + b[1], p.y + b[2] } }
        end
      end
      poser(r.entrees_fluide, p.fluides_entree)
      poser((r.sorties_fluide_dir and r.sorties_fluide_dir[p.dir or 0]) or r.sorties_fluide, p.fluides_sortie)
    end
  end
  for key, b in pairs(boites) do
    local q = pieces[occ[key] or 0]
    if q and (q.role == "tuyau" or q.role == "tuyau_souterrain") then
      if not b.tok then e("tuyau sur le raccord inutilisé (%d, %d) de %s", b.cell[1], b.cell[2], b.piece.role)
      elseif q.fluide ~= b.tok then e("tuyau de %s sur le raccord de %s (%d, %d) qui attend %s", tostring(q.fluide), b.piece.role, b.cell[1], b.cell[2], tostring(b.tok)) end
    elseif b.tok and not (q and q.role == "tuyau") then
      -- raccord déclaré utilisé, sans tuyau : permis seulement si le motif le dit (raccord direct machine à machine)
      if not opt.raccords_libres then e("raccord (%d, %d) de %s attend %s, sans tuyau", b.cell[1], b.cell[2], b.piece.role, tostring(b.tok)) end
    end
  end
  for _, p in ipairs(pieces) do
    if p.role == "tuyau" or p.role == "tuyau_souterrain" then
      if not p.fluide then e("tuyau sans fluide en (%d, %d)", p.x, p.y) end
      for _, d in ipairs({ N, E, S, W }) do
        local v = DV[d]
        if surface_ouverte(p, v[1], v[2]) then
          local q = at(p.x + v[1], p.y + v[2])
          if q and (q.role == "tuyau" or q.role == "tuyau_souterrain") and surface_ouverte(q, -v[1], -v[2]) and q.fluide ~= p.fluide then
            e("mélange : tuyau de %s en (%d, %d) touche tuyau de %s en (%d, %d)", tostring(p.fluide), p.x, p.y, tostring(q.fluide), q.x, q.y)
          end
        end
      end
      if p.role == "tuyau_souterrain" then
        local v = DV[opposite(p.dir)]   -- le souterrain part à l'opposé du raccord de surface
        local trouve = false
        for i = 1, K.ECART_TUYAU_SOUTERRAIN do
          local q = at(p.x + v[1] * i, p.y + v[2] * i)
          if q and q.role == "tuyau_souterrain" then
            trouve = (q.dir == opposite(p.dir) and q.fluide == p.fluide)
            break
          end
        end
        if not trouve then e("tuyau souterrain en (%d, %d) sans partenaire du même fluide en face", p.x, p.y) end
      end
    end
  end

  -- électricité
  local spec = m.exige_poteau or K.POTEAU_PETIT
  local poteaux, propres = {}, {}
  local cible = m.repetable and 2 or 1   -- la tuile du milieu fait foi : elle doit se suffire (poteaux de SA tuile)
  for _, p in ipairs(pieces) do
    if p.role == "poteau" then
      poteaux[#poteaux + 1] = p
      if p.bloc == "tuile" and p.tuile == cible then propres[#propres + 1] = p end
    end
  end
  local alim = false
  for _, p in ipairs(pieces) do if D.alimente(p.role, p) then alim = true end end
  if alim then
    if #poteaux == 0 then e("aucun poteau")
    else
      for _, p in ipairs(pieces) do
        if D.alimente(p.role, p) and p.bloc == "tuile" and p.tuile == cible then
          local ok = false
          for _, q in ipairs(propres) do
            local cx, cy = q.x + 0.5, q.y + 0.5
            if p.x < cx + spec.supply and p.x + p.w > cx - spec.supply and p.y < cy + spec.supply and p.y + p.h > cy - spec.supply then ok = true; break end
          end
          if not ok then e("%s en (%d, %d) hors de l'aire d'un poteau (aire %.1f)", p.role, p.x, p.y, spec.supply) end
        end
      end
      -- poteaux reliés (distance entre centres ≤ fil)
      local reste, vu = { 1 }, { [1] = true }
      local nvu = 1
      while #reste > 0 do
        local i = table.remove(reste)
        for j, q in ipairs(poteaux) do
          if not vu[j] then
            local dx, dy = poteaux[i].x - q.x, poteaux[i].y - q.y
            if dx * dx + dy * dy <= spec.fil * spec.fil then vu[j] = true; nvu = nvu + 1; reste[#reste + 1] = j end
          end
        end
      end
      if nvu < #poteaux then e("poteaux non reliés : %d sur %d dans le même réseau (fil %.1f)", nvu, #poteaux, spec.fil) end
    end
  end

  -- raccords de fluide déclarés
  for _, f in ipairs(m.fluides or {}) do
    local q = at(f.x, f.y)
    if not (q and (q.role == "tuyau" or q.role == "tuyau_souterrain") and q.fluide == f.jeton) then
      e("raccord de fluide %s déclaré en (%d, %d) absent (%s)", tostring(f.jeton), f.x, f.y, q and (q.role .. ":" .. tostring(q.fluide)) or "vide")
    end
  end

  -- liens et groupes déclarés
  local der = m.derive
  for _, id in ipairs(Cp.sorted_keys(der.liens)) do
    local l = der.liens[id]
    if not l.groupe then e("lien %s sans déclaration", id)
    else
      if not der.groupes[l.groupe] then e("lien %s : groupe « %s » sans machine", id, l.groupe) end
      if l.machines < 1 then e("lien %s ne touche aucune machine", id) end
      if l.io == "in" and #l.entrees == 0 and not l.interne then e("lien %s (entrée) ne prend sur aucun tapis d'entrée", id) end
      if l.io == "out" and #l.sorties == 0 and not l.interne then e("lien %s (sortie) ne dépose sur aucun tapis de sortie", id) end
    end
  end
  for _, c in ipairs(m.chaines or {}) do
    if not der.groupes[c.amont] or not der.groupes[c.aval] then e("chaîne %s → %s : groupe inconnu", tostring(c.amont), tostring(c.aval)) end
  end
  return err
end

return K
