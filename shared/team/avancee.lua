--[[
  POSTE AVANCÉ de VOTRE équipe (lot FORTIFY) : ce que ferait un joueur devant un gisement gardé par une meute ou un nid : il
  ne renvoie pas ses ouvriers à chaque pensée, il pose quelques tourelles au bord de la zone dangereuse, côté base, puis
  revient voir. Règle PURE (aucune API Factorio, aucun nom d'objet) ; le branchement est dans script/team/avancee.lua.

  Entrée : une destination refusée par la porte du danger (raison « but », « bloque » ou « marque ») et la menace qui la
  garde (centre, date de la dernière observation, FIXE ou MOBILE ; sans menace connue, la case mobile du but).
  Sortie : un POINT D'ARRÊT sur le segment menace -> QG, à A.PACK_BACK tuiles de la menace, où poser A.TURRETS tourelles.
  MOBILE seulement (meute, unités) : une tourelle (portée 18) y arrête ce qui vient. Une menace FIXE (ver de portée 30, nid)
  est refusée (« fixe ») : des tourelles ne l'atteignent pas, il faut des soldats (question n° 5 au DC).

  Bornes (aucune ne se contourne) : la menace doit avoir été revue il y a moins de A.FRESH ; le point est à A.MIN_HQ au moins
  et A.MAX_HQ au plus du QG (plus près, c'est la défense du QG) ; une seule demande ouverte à la fois ; A.MAX_POSTS postes au
  plus par partie ; une case de A.CELL tuiles n'est retentée qu'après A.COOLDOWN.

  État (global, nombres et chaînes seulement) : { reqs = { [clé] = { x, y, t } }, posts = { [clé] = tick }, made = n }.
]]

local A = {}

A.CELL = 32
A.FRESH = 2 * 3600       -- menace revue depuis moins de 2 min
A.PACK_BACK = 28         -- tuiles entre la meute et les tourelles : portée de tourelle 18 + 10, hors d'atteinte d'un ver
A.MIN_HQ = 30
A.MAX_HQ = 220
A.MAX_POSTS = 4
A.COOLDOWN = 15 * 3600
A.EXPIRE = 10 * 3600     -- une demande jamais prise est oubliée
A.TURRETS = 2
A.REASONS = { but = true, bloque = true, marque = true }

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

function A.new() return { reqs = {}, posts = {}, made = 0 } end

local function floor(v) return math.floor(v) end

function A.key(x, y) return floor(x / A.CELL) .. ":" .. floor(y / A.CELL) end

--- Point d'arrêt : sur le segment ancre -> QG, à `back` tuiles de l'ancre (défaut A.PACK_BACK), arrondi à la tuile. nil si
--- l'ancre est trop près du QG pour qu'il reste de la place (le point passerait de l'autre côté).
function A.stand(hq, anchor, back)
  local dx, dy = hq.x - anchor.x, hq.y - anchor.y
  local len = math.sqrt(dx * dx + dy * dy)
  back = back or A.PACK_BACK
  if len < back + A.MIN_HQ then return nil end
  local k = back / len
  return { x = floor(anchor.x + dx * k + 0.5), y = floor(anchor.y + dy * k + 0.5) }
end

--- Une demande. req = { x, y (ancre : centre de la menace ou but), fixed (menace fixe : refusée), seen (tick de la dernière
--- observation) }. Rend (clé, point) si la demande est ouverte (nouvelle ou déjà ouverte), sinon (nil, raison).
function A.note(st, hq, req, tick)
  if req.fixed then return nil, "fixe" end
  if tick - (req.seen or -1e9) > A.FRESH then return nil, "perimee" end
  local p = A.stand(hq, { x = req.x, y = req.y })
  if not p then return nil, "pres-du-QG" end
  local dh = math.sqrt((p.x - hq.x) ^ 2 + (p.y - hq.y) ^ 2)
  if dh > A.MAX_HQ then return nil, "loin" end
  local key = A.key(p.x, p.y)
  if st.reqs[key] then return key, st.reqs[key] end
  local at = st.posts[key]
  if at and tick - at < A.COOLDOWN then return nil, "deja-pose" end
  if (st.made or 0) >= A.MAX_POSTS then return nil, "plafond" end
  if #sorted_keys(st.reqs) >= 1 then return nil, "occupe" end
  st.reqs[key] = { x = p.x, y = p.y, t = tick }
  return key, st.reqs[key]
end

--- Demandes ouvertes (clés triées) ; les périmées sont retirées.
function A.open(st, tick)
  local out = {}
  for _, k in ipairs(sorted_keys(st.reqs)) do
    local r = st.reqs[k]
    if tick - r.t > A.EXPIRE then st.reqs[k] = nil else out[#out + 1] = { key = k, x = r.x, y = r.y } end
  end
  return out
end

--- Le poste a reçu `n` tourelles : demande close, case mémorisée. n = 0 : close sans compter (case retentée après COOLDOWN).
function A.done(st, key, tick, n)
  st.reqs[key] = nil
  st.posts[key] = tick
  if (n or 0) > 0 then st.made = (st.made or 0) + 1 end
end

return A
