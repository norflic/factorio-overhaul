--[[
  Lot DEBUG-BLOCS (directive du DC du 8/11, partie 2 : « Affichez les liaisons [...] que l'algorithme a enregistrées. Si un coffre est défini comme
  un "buffer" lié à une ligne de production, cela doit être visuellement explicite ») : les LIGNES du plan directeur telles que le code les tient,
  leur état de projet et la cause d'une ligne refusée ou coupée. Règles PURES (tests/debug_liens_test.lua) ; entrées : tables de nombres et de
  chaînes prises dans f.build (jamais d'entité, rien n'est écrit).

  Genres (un projet du plan directeur = une ligne) :
    quai          spec.liaison (script/team/liaison.lua) : coffre de SORTIE d'un bloc (lc.src) -> coffre d'ENTRÉE d'un autre bloc (lc.dock) ;
    bus           le même avec lc.bus (script/team/bus.lua) ;
    piquage       lc.piquage (script/team/piquage.lua) : répartiteur (lc.geo, centre déjà calculé) -> coffre d'entrée (lc.dock) ; la suite après la
                  fin du projet est dans b.piquage.links[clé] (split, cut) et b.piquage.quais[clé] (verdict, cause : Pq.CAUSE_CODES) ;
    rapatriement  spec.rapatriement (script/team/rapatriement.lua:392) : coffre de sortie lointain (rp.src) -> coffre TAMPON (p.rap.tampon_x/y une fois
                  planifié, :675 ; avant : rp.reuse, sinon rp.point) ; b.rapatriement.lines[rp.key].arrived = objets arrivés par le tapis.
  Coordonnées : lc.src, lc.dock, rp.src, rp.point, rp.reuse et p.rap.tampon_* sont des TUILES (math.floor des relevés, liaison.lua:123, :135 ;
  piquage.lua:229 ; rapatriement.lua:163) : le centre du coffre est la tuile + 0,5. lc.geo.x/y est déjà un centre (Pq.geometry).

  État d'une ligne (Li.status), mots fixes :
    actif     projet « fini » (piquage : répartiteur posé et coffre livré) ;
    chantier  projet ni fini ni refusé, jamais fini ;
    attente   piquage fini sans répartiteur posé (cause : celle du relevé du piquage) ;
    inerte    piquage posé qui ne livre pas ;
    coupe     projet qui A ÉTÉ fini (p.finished, jamais remis à nil : build.lua:4256) et ne l'est plus, ou piquage « cut » ;
    refuse    projet « refuse » ou abandonné ; cause = p.reason (texte libre du plan directeur, jamais traduit).
  Cause rendue : { kind = "piquage", code } (clé fo-dbg-cerveau.pq-cause-<code>), { kind = "etat", code = état du projet }, { kind = "texte", text }.
  Les lignes refusées : au plus Li.REFUSED_MAX par genre, la plus récente par extrémité d'entrée, et aucune quand une ligne plus récente du même genre
  sert la même extrémité (une demande refusée puis redemandée ne laisse que la dernière).
]]

local Li = {}

Li.KINDS = { "quai", "bus", "piquage", "rapatriement" }
Li.REFUSED_MAX = 6
Li.ARROW = 0.9    -- longueur de la pointe de flèche (tuiles)
Li.SPREAD = 0.45  -- demi-largeur de la pointe
Li.MID = 16       -- une ligne plus longue (tuiles) porte aussi une flèche au milieu
Li.BROKEN = { coupe = true, refuse = true }
Li.WARN = { attente = true, inerte = true }

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge and v or nil end

--- Centre d'une TUILE { x, y } (ou nil).
function Li.center(t)
  if type(t) ~= "table" or not num(t.x) or not num(t.y) then return nil end
  return { x = math.floor(t.x) + 0.5, y = math.floor(t.y) + 0.5 }
end

local function point(t)
  if type(t) ~= "table" or not num(t.x) or not num(t.y) then return nil end
  return { x = t.x, y = t.y }
end

--- Genre d'une ligne d'après le spec d'un projet, ou nil (bloc, raccord, enceinte...).
function Li.kind(spec)
  if type(spec) ~= "table" then return nil end
  local lc = spec.liaison
  if type(lc) == "table" then
    if lc.piquage then return "piquage" end
    if lc.bus then return "bus" end
    return "quai"
  end
  if type(spec.rapatriement) == "table" then return "rapatriement" end
  return nil
end

--- Clé de l'extrémité d'entrée (quai ou sortie rapatriée) : sert au dédoublonnage des refus.
local function end_key(kind, spec)
  if kind == "rapatriement" then return "r:" .. tostring(spec.rapatriement.key) end
  return kind .. ":" .. tostring(spec.liaison.key)
end

--- État et cause d'une ligne. p = { state, finished, abandoned, reason } ; pq = { link = b.piquage.links[clé], quai = b.piquage.quais[clé] } (piquage).
function Li.status(kind, p, pq)
  local s = p.state
  if s == "refuse" or p.abandoned then
    local r = p.reason
    return "refuse", (r ~= nil and r ~= "") and { kind = "texte", text = tostring(r) } or nil
  end
  if s ~= "fini" then
    if p.finished ~= nil then return "coupe", { kind = "etat", code = tostring(s) } end
    return "chantier", nil
  end
  if kind == "piquage" then
    local link = pq and pq.link
    local q = pq and pq.quai
    local code = q and q.cause
    if link and link.cut then return "coupe", { kind = "piquage", code = code or "remplacement_refuse" } end
    if not (link and link.split) then return "attente", code and code ~= "ok" and { kind = "piquage", code = code } or nil end
    if q and q.verdict == "inerte" then return "inerte", { kind = "piquage", code = code or "ne_livre_pas" } end
  end
  return "actif", nil
end

--- Extrémités { from, to } d'une ligne, ou nil.
local function ends(kind, spec, rap)
  if kind == "rapatriement" then
    local rp = spec.rapatriement
    local to
    if type(rap) == "table" and num(rap.tampon_x) and num(rap.tampon_y) then to = Li.center({ x = rap.tampon_x, y = rap.tampon_y }) end
    to = to or Li.center(rp.reuse) or Li.center(rp.point)
    return Li.center(rp.src), to
  end
  local lc = spec.liaison
  if kind == "piquage" then return point(lc.geo), Li.center(lc.dock) end
  return Li.center(lc.src), Li.center(lc.dock)
end

local function src_pid(kind, spec)
  if kind == "rapatriement" then return spec.rapatriement.src and spec.rapatriement.src.pid or nil end
  if kind == "piquage" then return nil end
  return spec.liaison.src and spec.liaison.src.pid or nil
end

local function dock_pid(kind, spec)
  if kind == "rapatriement" then return nil end
  return spec.liaison.dock and spec.liaison.dock.pid or nil
end

--- Lignes enregistrées. projects : liste de { pid, state, finished, abandoned, reason, spec, rap } (p.rap : rapatriement planifié) ;
--- regs = { piquage = { links, quais }, rapatriement = { lines } } (tables de f.build, absentes permises). Rend, triées par pid :
--- { pid, kind, item, from, to, status, cause, src_pid, dock_pid, key, arrived }.
function Li.lines(projects, regs)
  regs = regs or {}
  local pq = regs.piquage or {}
  local rpl = (regs.rapatriement or {}).lines or {}
  local all = {}
  for _, p in ipairs(type(projects) == "table" and projects or {}) do
    local kind = type(p) == "table" and num(p.pid) and Li.kind(p.spec)
    if kind then
      local from, to = ends(kind, p.spec, p.rap)
      if from and to then
        local key = kind == "rapatriement" and p.spec.rapatriement.key or p.spec.liaison.key
        local status, cause = Li.status(kind, p, kind == "piquage" and { link = (pq.links or {})[key], quai = (pq.quais or {})[key] } or nil)
        local lc = p.spec.liaison or p.spec.rapatriement
        local rl = kind == "rapatriement" and rpl[key] or nil
        all[#all + 1] = { pid = p.pid, kind = kind, item = type(lc.item) == "string" and lc.item or nil, from = from, to = to, status = status, cause = cause,
          src_pid = src_pid(kind, p.spec), dock_pid = dock_pid(kind, p.spec), key = tostring(key), ek = end_key(kind, p.spec),
          arrived = rl and rl.pid == p.pid and num(rl.arrived) or nil }
      end
    end
  end
  table.sort(all, function(a, b) return a.pid < b.pid end)
  -- refus : le plus récent par extrémité, aucun si une ligne plus récente vit au même bout, au plus REFUSED_MAX par genre (les plus récents)
  local live_after, last_refused = {}, {}
  for _, l in ipairs(all) do
    if l.status == "refuse" then last_refused[l.ek] = l.pid else live_after[l.ek] = math.max(live_after[l.ek] or 0, l.pid) end
  end
  local keep_ref, per_kind = {}, {}
  for i = #all, 1, -1 do
    local l = all[i]
    if l.status == "refuse" and last_refused[l.ek] == l.pid and (live_after[l.ek] or 0) < l.pid then
      per_kind[l.kind] = (per_kind[l.kind] or 0) + 1
      if per_kind[l.kind] <= Li.REFUSED_MAX then keep_ref[l.pid] = true end
    end
  end
  local out = {}
  for _, l in ipairs(all) do
    if l.status ~= "refuse" or keep_ref[l.pid] then
      l.ek = nil
      out[#out + 1] = l
    end
  end
  return out
end

--- Coffres TAMPONS : l'extrémité d'arrivée de chaque ligne non refusée (tampon de rapatriement, coffre d'entrée d'une liaison, d'un tronc ou d'un
--- piquage), une fois par coffre. Rend { x, y, item, kinds = { genres triés }, sources = { pid de bloc triés }, tapis = bool (piquage), pids } triés par position.
function Li.buffers(lines)
  local by, order = {}, {}
  for _, l in ipairs(lines or {}) do
    if l.status ~= "refuse" then
      local k = string.format("%.1f:%.1f", l.to.x, l.to.y)
      local b = by[k]
      if not b then
        b = { x = l.to.x, y = l.to.y, item = l.item, kinds = {}, sources = {}, tapis = false, pids = {}, _k = {}, _s = {} }
        by[k] = b
        order[#order + 1] = b
      end
      if not b._k[l.kind] then b._k[l.kind] = true; b.kinds[#b.kinds + 1] = l.kind end
      if l.src_pid and not b._s[l.src_pid] then b._s[l.src_pid] = true; b.sources[#b.sources + 1] = l.src_pid end
      if l.kind == "piquage" then b.tapis = true end
      b.pids[#b.pids + 1] = l.pid
    end
  end
  for _, b in ipairs(order) do
    table.sort(b.kinds)
    table.sort(b.sources)
    b._k, b._s = nil, nil
  end
  table.sort(order, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
  return order
end

--- Pointe de flèche à `to` (vers to), longueur `len` : deux segments { {x0, y0, x1, y1}, ... } ; une ligne de longueur nulle n'en a pas.
function Li.arrow_head(from, to, len)
  local dx, dy = to.x - from.x, to.y - from.y
  local d = math.sqrt(dx * dx + dy * dy)
  if d < 1e-6 then return {} end
  len = math.min(len or Li.ARROW, d)
  local ux, uy = dx / d, dy / d
  local bx, by = to.x - ux * len, to.y - uy * len
  local w = Li.SPREAD * len / Li.ARROW
  return { { bx - uy * w, by + ux * w, to.x, to.y }, { bx + uy * w, by - ux * w, to.x, to.y } }
end

--- Pointes d'une ligne : une à l'arrivée, une de plus au milieu au-delà de Li.MID tuiles.
function Li.arrows(from, to)
  local segs = Li.arrow_head(from, to)
  local dx, dy = to.x - from.x, to.y - from.y
  if dx * dx + dy * dy > Li.MID * Li.MID then
    for _, s in ipairs(Li.arrow_head(from, { x = (from.x + to.x) / 2, y = (from.y + to.y) / 2 })) do segs[#segs + 1] = s end
  end
  return segs
end

--- Couleur (nom) d'une ligne : rouge cassée ou refusée, orange en attente ou inerte, sinon la couleur du genre.
function Li.color(l)
  if Li.BROKEN[l.status] then return "rouge" end
  if Li.WARN[l.status] then return "orange" end
  return l.kind
end

--- Trait plein (actif, coupé, refusé, inerte) ou pointillé (chantier, attente : la ligne n'existe pas encore en entier).
function Li.dashed(l) return l.status == "chantier" or l.status == "attente" end

return Li
