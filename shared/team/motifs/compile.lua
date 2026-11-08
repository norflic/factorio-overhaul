--[[
  Lot MOTIFS : compilation d'une DÉFINITION de motif (dessin + légende + déclarations) en motif prêt à servir, et calcul
  des données DÉRIVÉES de la géométrie (jamais écrites à la main : elles ne peuvent pas diverger du dessin).

  Définition (def) :
    id, famille, usages = { ... }, source = { url, ... }, ref (référence du DC), nom_fr, nom_en, note_fr,
    art, legende, periode (défaut : largeur du dessin), tete / queue = { art, legende } facultatifs,
    entrees = { { k, cote = "O"|"E", pos (rangée de la cellule), jetons = { jeton = { voies } } } },
    sorties = { ... },
    liens = { id = { groupe, io = "in"|"out", jetons = { ... } } },
    chaines = { { amont, aval, jeton } },           -- insertion directe entre deux groupes de machines
    exige_poteau = { supply, fil },                 -- plus petit poteau qui suffit
    repetable (défaut vrai) : faux = tuile unique (équilibreur, piquage) ;
    contraintes = { ... }.

  Dérivé (motif.derive) : par groupe de machines (rôle, taille, nombre par tuile) ; par lien (bras par rôle, machines
  servies, entrées et sorties touchées, prise sur tapis) ; rapports de machines des chaînes ; nombre de pièces par rôle.
]]

local function need(dotted, slashed)
  local ok, res = pcall(require, dotted)
  if ok and type(res) == "table" then return res end
  return require("__factorio-overhaul__/" .. slashed)
end
local D = need("shared.team.motifs.dsl", "shared/team/motifs/dsl")

local C = {}

--- Référence « role » ou « role:k » → (role, k).
function C.ref(s)
  if not s then return nil end
  local role, k = s:match("^([%w_]+):?(%d*)$")
  return role, (k ~= "" and tonumber(k)) or nil
end

--- La pièce `p` correspond-elle à la référence `s` ?
function C.correspond(p, s)
  local role, k = C.ref(s)
  if not p or not role then return false end
  if p.role ~= role then return false end
  if k and p.k ~= k then return false end
  return true
end

--- Cellules de prise et de dépôt d'un bras (cellules entières).
function C.prise_depot(p)
  local r = D.ROLES[p.role]
  local v = D.DV[p.dir]
  return { p.x + v[1] * r.portee, p.y + v[2] * r.portee }, { p.x - v[1] * r.portee, p.y - v[2] * r.portee }
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end
C.sorted_keys = sorted_keys

--- Données dérivées d'un motif compilé (instance de 3 tuiles, la tuile du milieu fait foi).
local function deriver(m)
  local inst = D.instancier(m, 3, { rot = 0, miroir = false })
  local occ = D.occupation(inst.pieces)
  local der = { groupes = {}, liens = {}, pieces = {}, chaines = {} }
  -- pièces par rôle (une tuile)
  for _, p in ipairs(m.pieces) do der.pieces[p.role] = (der.pieces[p.role] or 0) + 1 end
  -- groupes de machines
  for _, p in ipairs(m.pieces) do
    if D.ROLES[p.role] and D.ROLES[p.role].classe == "machine" then
      local g = p.groupe or "principal"
      local e = der.groupes[g]
      if not e then e = { role = p.role, w = p.w, h = p.h, n = 0 }; der.groupes[g] = e end
      e.n = e.n + 1
    end
  end
  -- liens : bras de la tuile du milieu
  for _, p in ipairs(inst.pieces) do
    local r = D.ROLES[p.role]
    if p.tuile == 2 and p.bloc == "tuile" and r and r.classe == "bras" and p.lien then
      local e = der.liens[p.lien]
      if not e then e = { bras = {}, machines = {}, entrees = {}, sorties = {}, prise_tapis = false, mg = {} }; der.liens[p.lien] = e end
      e.bras[p.role] = (e.bras[p.role] or 0) + 1
      local prise, depot = C.prise_depot(p)
      local a = inst.pieces[occ[D.cle(prise[1], prise[2])] or 0]
      local b = inst.pieces[occ[D.cle(depot[1], depot[2])] or 0]
      for _, q in ipairs({ a, b }) do
        if q then
          local rq = D.ROLES[q.role]
          if rq and rq.classe == "machine" then
            e.machines[q] = true
          end
        end
      end
      if a and a.role == "tapis_entree" then e.entrees[a.k] = true; e.prise_tapis = true end
      if a and D.est_tapis(a.role) and a.role ~= "tapis_entree" then e.prise_tapis = true end
      if b and b.role == "tapis_sortie" then e.sorties[b.k] = true end
    end
  end
  for _, id in ipairs(sorted_keys(der.liens)) do
    local e = der.liens[id]
    local n = 0
    for q in pairs(e.machines) do
      n = n + 1
      local g = q.groupe or "principal"
      e.mg[g] = (e.mg[g] or 0) + 1
    end
    e.machines = n
    local ent, sor = {}, {}
    for k in pairs(e.entrees) do ent[#ent + 1] = k end
    for k in pairs(e.sorties) do sor[#sor + 1] = k end
    table.sort(ent); table.sort(sor)
    e.entrees, e.sorties = ent, sor
    local d = (m.liens or {})[id]
    if d then e.groupe, e.io, e.jetons, e.interne, e.de, e.vers, e.jeton = d.groupe, d.io, d.jetons, d.interne, d.de, d.vers, d.jeton end
  end
  der.noms, der.ids = sorted_keys(der.groupes), sorted_keys(der.liens)
  m.derive = der
end

--- Compile une définition. Renvoie (motif) ou (nil, raison).
function C.compiler(def)
  local m = {}
  for k, v in pairs(def) do
    if k ~= "art" and k ~= "legende" and k ~= "tete" and k ~= "queue" then m[k] = v end
  end
  local pieces, err = D.lire(def.art, def.legende, def.id)
  if not pieces then return nil, err end
  m.pieces = pieces
  m.h = #def.art
  m.periode = def.periode or #def.art[1]
  m.l = m.periode
  m.emprise = { l = m.l, h = m.h }
  m.art = def.art
  m.legende = def.legende
  if m.repetable == nil then m.repetable = true end
  for _, nom in ipairs({ "tete", "queue" }) do
    local t = def[nom]
    if t then
      if #t.art ~= m.h then return nil, string.format("%s : %s de hauteur %d au lieu de %d", def.id, nom, #t.art, m.h) end
      local ps, e2 = D.lire(t.art, t.legende or def.legende, def.id .. "/" .. nom)
      if not ps then return nil, e2 end
      m[nom] = { len = #t.art[1], pieces = ps, art = t.art }
    end
  end
  m.roles = D.roles_utilises(m)
  local ok, e3 = pcall(deriver, m)
  if not ok then return nil, def.id .. " : dérivation impossible : " .. tostring(e3) end
  return m
end

return C
